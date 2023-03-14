package ceramic;

import ceramic.Shortcuts.*;

class ImageAsset extends Asset {

/// Events

    @event function replaceTexture(newTexture:Texture, prevTexture:Texture);

/// Properties

    //public var pixels:Pixels = null;

    @observe public var texture:Texture = null;

/// Internal

    @:allow(ceramic.Assets)
    var defaultImageOptions:AssetOptions = null;

    var reloadBecauseOfDensityChange:Bool = false;

/// Lifecycle

    override public function new(name:String, ?options:AssetOptions #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end) {

        super('image', name, options #if ceramic_debug_entity_allocs , pos #end);
        handleTexturesDensityChange = true;

    }

    override public function load() {

        status = LOADING;

        var reloadBecauseOfDensityChange = this.reloadBecauseOfDensityChange;
        this.reloadBecauseOfDensityChange = false;

        if (path == null) {
            log.warning('Cannot load image asset if path is undefined.');
            status = BROKEN;
            emitComplete(false);
            return;
        }

        var loadOptions:AssetOptions = {};
        if (owner != null) {
            loadOptions.immediate = owner.immediate;
            loadOptions.loadMethod = owner.loadMethod;
        }
        if (defaultImageOptions != null) {
            for (key in Reflect.fields(defaultImageOptions)) {
                Reflect.setField(loadOptions, key, Reflect.field(defaultImageOptions, key));
            }
        }
        if (options != null) {
            for (key in Reflect.fields(options)) {
                Reflect.setField(loadOptions, key, Reflect.field(options, key));
            }
        }

        // Add reload count if any
        var backendPath = path;
        var realPath = Assets.realAssetPath(backendPath, runtimeAssets);
        var assetReloadedCount = Assets.getReloadCount(realPath);
        if (app.backend.textures.supportsHotReloadPath() && assetReloadedCount > 0) {
            realPath += '?hot=' + assetReloadedCount;
            backendPath += '?hot=' + assetReloadedCount;
        }

        log.info('Load image $backendPath (density=$density)');
        app.backend.textures.load(realPath, loadOptions, function(image) {

            if (image != null) {

                var prevTexture = this.texture;
                var newTexture = new Texture(image, density);
                newTexture.id = 'texture:' + backendPath;
                this.texture = newTexture;

                // Link the texture to this asset so that
                // destroying one will destroy the other
                this.texture.asset = this;

                if (prevTexture != null) {

                    // Use same filter as previous texture
                    this.texture.filter = prevTexture.filter;

                    // When replacing the texture, emit an event to notify about it
                    emitReplaceTexture(this.texture, prevTexture);

                    // Texture was reloaded. Update related visuals
                    for (visual in [].concat(app.visuals)) {
                        if (!visual.destroyed) {
                            if (visual.asQuad != null) {
                                var quad = visual.asQuad;
                                if (quad.texture == prevTexture) {

                                    // Update texture but keep same frame
                                    //
                                    var frameX = quad.frameX;
                                    var frameY = quad.frameY;
                                    var frameWidth = quad.frameWidth;
                                    var frameHeight = quad.frameHeight;

                                    quad.texture = this.texture;

                                    // We keep the frame, unless image
                                    // is being hot-reloaded and its frame is all texture area
                                    if (reloadBecauseOfDensityChange
                                        || frameX != 0 || frameY != 0
                                        || frameWidth != prevTexture.width
                                        || frameHeight != prevTexture.height
                                    ) {
                                        // Frame was reset by texture assign.
                                        // Put it back to what it was.
                                        quad.frameX = frameX;
                                        quad.frameY = frameY;
                                        quad.frameWidth = frameWidth;
                                        quad.frameHeight = frameHeight;
                                    }
                                }
                            }
                            else if (visual.asMesh != null) {
                                var mesh = visual.asMesh;
                                if (mesh.texture == prevTexture) {
                                    mesh.texture = this.texture;
                                }
                            }
                        }
                    }

                    // Set asset to null because we don't want it
                    // to be destroyed when destroying the texture.
                    prevTexture.asset = null;
                    // Destroy texture
                    prevTexture.destroy();
                }

                status = READY;
                emitComplete(true);
                if (handleTexturesDensityChange) {
                    checkTexturesDensity();
                }
            }
            else {
                status = BROKEN;
                log.error('Failed to load texture at path: $path');
                emitComplete(false);
            }

        });

    }

    override function texturesDensityDidChange(newDensity:Float, prevDensity:Float):Void {

        if (status == READY) {
            // Only check if the asset is already loaded.
            // If it is currently loading, it will check
            // at load end anyway.
            checkTexturesDensity();
        }

    }

    function checkTexturesDensity():Void {

        if (owner == null || !owner.reloadOnTextureDensityChange)
            return;

        var prevPath = path;
        computePath();

        if (prevPath != path) {
            log.info('Reload texture ($prevPath -> $path)');
            reloadBecauseOfDensityChange = true;
            load();
        }

    }

    override function assetFilesDidChange(newFiles:ReadOnlyMap<String, Float>, previousFiles:ReadOnlyMap<String, Float>):Void {

        if (!app.backend.textures.supportsHotReloadPath())
            return;

        var previousTime:Float = -1;
        if (previousFiles.exists(path)) {
            previousTime = previousFiles.get(path);
        }
        var newTime:Float = -1;
        if (newFiles.exists(path)) {
            newTime = newFiles.get(path);
        }

        if (newTime > previousTime) {
            log.info('Reload texture (file has changed)');
            load();
        }

    }

    override function destroy():Void {

        super.destroy();

        if (texture != null) {
            texture.destroy();
            texture = null;
        }

    }

}
