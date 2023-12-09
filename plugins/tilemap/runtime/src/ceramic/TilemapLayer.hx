package ceramic;

using ceramic.Extensions;

class TilemapLayer extends Visual {

    @event function tileQuadsChange();

    #if plugin_arcade

    /**
     * Shorthand to set `checkCollisionUp`, `checkCollisionRight`, `checkCollisionDown`, `checkCollisionLeft`
     */
    public extern inline overload function checkCollision(upDown:Bool, rightLeft:Bool) {
        _checkCollision(upDown, rightLeft, upDown, rightLeft);
    }

    /**
     * Shorthand to set `checkCollisionUp`, `checkCollisionRight`, `checkCollisionDown`, `checkCollisionLeft`
     */
    public extern inline overload function checkCollision(up:Bool, right:Bool, down:Bool, left:Bool) {
        _checkCollision(up, right, down, left);
    }

    private function _checkCollision(up:Bool, right:Bool, down:Bool, left:Bool) {
        checkCollisionUp = up;
        checkCollisionRight = right;
        checkCollisionDown = down;
        checkCollisionLeft = left;
    }

    /**
     * If this layer is collidable, this determines if it will collide `up`.
     * (when a body is going `downward` torward the tile)
     */
    public var checkCollisionUp:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `down`.
     * (when a body is going `upward` toward a tile)
     */
    public var checkCollisionDown:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `left`.
     * (when a body is going `rightward` toward the tile)
     */
    public var checkCollisionLeft:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide `right`.
     * (when a body is going `leftward` toward the tile)
     */
    public var checkCollisionRight:Bool = true;

    /**
     * If this layer is collidable, this determines if it will collide
     * using `tiles` or `computedTiles`
     */
    public var checkCollisionWithComputedTiles:Bool = false;

    /**
     * If this layer is collidable, it collides with any tiles
     * that have a value != 0, unless `checkCollisionValues` is provided.
     * In that case, it will collide when matching any value of the array.
     */
    public var checkCollisionValues:Array<Int> = null;

    /**
     * Internal flag used when walking through layers
     */
    @:allow(ceramic.Tilemap)
    public var collidable(default, null):Bool = false;

    @:allow(ceramic.Tilemap)
    function clearArcadeTiles():Void {

        for (i in 0...tileQuads.length) {
            var quad = tileQuads.unsafeGet(i);
            if (quad.arcade != null) {
                var arcade = quad.arcade;
                arcade.destroy();
                quad.arcade = null;
            }
        }

    }

    #end

    @:allow(ceramic.Tilemap)
    public var tilemap(default, null):Tilemap = null;

    public var layerData(default,set):TilemapLayerData = null;
    function set_layerData(layerData:TilemapLayerData):TilemapLayerData {
        if (this.layerData == layerData) return layerData;
        this.layerData = layerData;
        contentDirty = true;
        return layerData;
    }

    public var tileScale(default,set):Float = 1.0;
    function set_tileScale(tileScale:Float):Float {
        if (this.tileScale == tileScale) return tileScale;
        this.tileScale = tileScale;
        contentDirty = true;
        return tileScale;
    }

    public var tileQuads(default,null):Array<TilemapQuad> = [];

    public var tilesColor(default,set):Color = Color.WHITE;
    function set_tilesColor(tilesColor:Color):Color {
        if (this.tilesColor != tilesColor) {
            this.tilesColor = tilesColor;
            var layerColor = layerData != null ? layerData.color : Color.WHITE;
            var mergedColor = Color.multiply(tilesColor, layerColor);
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                tileQuad.color = mergedColor;
            }
        }
        return tilesColor;
    }

    /**
     * If `true`, removing (assign null) or replacing a tilesFilter will destroy it.
     * Note that a tilesFilter will be destroyed if assigned when
     * (parent) layer is destroyed, regardless of this setting.
     */
    public var destroyTilesFilterOnRemove:Bool = true;

    /**
     * Set to `false` if you need to assign a tiles filter but want to keep control
     * on how it is layouted (size, position...)
     */
    public var autoSizeTilesFilter:Bool = true;

    /**
     * A filter that will be applied to every tile of this layer.
     * If `autoSizeTilesFilter` is `true` (default), filter size will be set to layer content size.
     * Existing filter is automatically destroyed if `tilesFilter` is set to `null` or the layer destroyed,
     * unless you set `destroyTilesFilterOnRemove` to `false`.
     */
    public var tilesFilter(default,set):Filter = null;
    function set_tilesFilter(tilesFilter:Filter):Filter {
        if (this.tilesFilter == tilesFilter) return tilesFilter;
        if (this.tilesFilter != null) {
            var tilesFilterContent = this.tilesFilter.content;
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                if (tileQuad.parent == tilesFilterContent) {
                    tilesFilterContent.remove(tileQuad);
                }
            }
            if (destroyTilesFilterOnRemove) {
                this.tilesFilter.destroy();
            }
            else if (this.tilesFilter.parent == this) {
                remove(this.tilesFilter);
            }
            this.tilesFilter = null;
        }
        this.tilesFilter = tilesFilter;
        if (tilesFilter != null) {

            var tilesFilterContent = tilesFilter.content;
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                tilesFilterContent.add(tileQuad);
            }

            add(tilesFilter);
        }
        else {
            for (i in 0...tileQuads.length) {
                var tileQuad = tileQuads.unsafeGet(i);
                add(tileQuad);
            }
        }
        contentDirty = true;
        return tilesFilter;
    }

    /**
     * A mapping to retrieve an existing tileQuad from its index
     */
    var tileQuadMapping:IntIntMap = new IntIntMap();

/// Overrides

    override function get_width():Float {
        if (contentDirty) computeContent();
        return super.get_width();
    }

    override function get_height():Float {
        if (contentDirty) computeContent();
        return super.get_height();
    }

/// Lifecycle

    public function new() {

        super();

    }

/// Display

    override function computeContent() {

        if (layerData == null) {
            width = 0;
            height = 0;
            contentDirty = false;
            return;
        }

        var tilemap:Tilemap = this.tilemap;
        var tilemapData:TilemapData = tilemap.tilemapData;

        computePosAndSize();
        computeTileQuads(tilemap, tilemapData);

        contentDirty = false;

    }

    function computePosAndSize() {

        var layerData = this.layerData;

        pos(
            layerData.x * layerData.tileWidth + layerData.offsetX,
            layerData.y * layerData.tileHeight + layerData.offsetY
        );

        size(
            layerData.columns * layerData.tileWidth,
            layerData.rows * layerData.tileHeight
        );

    }

    function computeTileQuads(tilemap:Tilemap, tilemapData:TilemapData) {

        var usedQuads = 0;
        var roundTilesTranslation = tilemap.roundTilesTranslation;
        var layerData = this.layerData;

        if (layerData.shouldRenderTiles && layerData.hasTiles) {

            var width = _width;
            var height = _height;
            var layerColumns = layerData.columns;
            var layerRows = layerData.rows;

            var hasClipping = false;
            var clipTilesX = tilemap.clipTilesX;
            var clipTilesY = tilemap.clipTilesY;
            var clipTilesWidth = tilemap.clipTilesWidth;
            var clipTilesHeight = tilemap.clipTilesHeight;
            if (clipTilesX != -1 || clipTilesY != -1 || clipTilesWidth != -1 || clipTilesHeight != -1) {
                hasClipping = true;
            }

            // Computing depth from render order
            var startDepthX = 0;
            var startDepthY = 0;
            var depthXStep = 1;
            var depthYStep = layerColumns;
            switch (tilemapData.renderOrder) {
                case RIGHT_DOWN:
                case RIGHT_UP:
                    startDepthY = layerColumns * (layerRows - 1);
                    depthYStep = -layerColumns;
                case LEFT_DOWN:
                    startDepthX = layerColumns - 1;
                    depthXStep = -1;
                case LEFT_UP:
                    startDepthX = layerColumns - 1;
                    depthXStep = -1;
                    startDepthY = layerColumns * (layerRows - 1);
                    depthYStep = -layerColumns;
            }

            var offsetX = layerData.offsetX + layerData.x * layerData.tileWidth;
            var offsetY = layerData.offsetY + layerData.y * layerData.tileHeight;

            var filterX:Float = 0.0;
            var filterY:Float = 0.0;
            if (tilesFilter != null) {
                var filterWidth = width;
                var filterHeight = height;
                if (hasClipping) {
                    filterX = Math.floor(clipTilesX / layerData.tileWidth) * layerData.tileWidth - offsetX;
                    filterY = Math.floor(clipTilesY / layerData.tileHeight) * layerData.tileHeight - offsetY;
                    tilesFilter.pos(
                        filterX,
                        filterY
                    );
                    filterWidth = Math.ceil(clipTilesWidth / layerData.tileWidth) * layerData.tileWidth + layerData.tileWidth;
                    filterHeight = Math.ceil(clipTilesHeight / layerData.tileHeight) * layerData.tileHeight + layerData.tileHeight;
                }
                else {
                    tilesFilter.pos(0, 0);
                }
                if (autoSizeTilesFilter && filterWidth > 0 && filterHeight > 0) {
                    tilesFilter.size(filterWidth, filterHeight);
                }
            }

            if (layerData.visible) {
                var tiles = layerData.computedTiles;
                var tilesAlpha = layerData.computedTilesAlpha;
                var tilesOffsetX = layerData.computedTilesOffsetX;
                var tilesOffsetY = layerData.computedTilesOffsetY;
                if (tiles == null) {
                    tiles = layerData.tiles;
                    tilesAlpha = layerData.tilesAlpha;
                    tilesOffsetX = layerData.tilesOffsetX;
                    tilesOffsetY = layerData.tilesOffsetY;
                }
                if (tiles != null) {

                    var minColumn = 0;
                    var maxColumn = layerColumns - 1;
                    var minRow = 0;
                    var maxRow = layerRows - 1;
                    var tilesPerLayer = layerColumns * layerRows;

                    if (hasClipping) {
                        minColumn = Math.floor((clipTilesX - offsetX) / layerData.tileWidth);
                        maxColumn = Math.ceil((clipTilesX + clipTilesWidth - offsetX) / layerData.tileWidth);
                        minRow = Math.floor((clipTilesY - offsetY) / layerData.tileHeight);
                        maxRow = Math.ceil((clipTilesY + clipTilesHeight - offsetY) / layerData.tileHeight);
                    }

                    var numTiles = tiles.length;
                    var c = minColumn;
                    while (c <= maxColumn) {
                        var r = minRow;
                        while (r <= maxRow) {
                            var t = r * layerColumns + c;

                            if (t < 0 || t >= numTiles) {
                                r++;
                                continue;
                            }

                            while (t < numTiles) {

                                var tile = tiles.unsafeGet(t);

                                if (tile == 0) {
                                    t += tilesPerLayer;
                                    continue;
                                }

                                var gid = tile.gid;

                                var tileset = tilemapData.tilesetForGid(gid);

                                if (tileset != null && tileset.image != null && tileset.columns > 0) {
                                    var index = gid - tileset.firstGid;

                                    var column = (t % layerColumns);
                                    var row = Math.floor(t / layerColumns);
                                    var depthExtra = 0.0;
                                    var color = Color.multiply(layerData.color, tilesColor);
                                    var alpha = layerData.opacity;
                                    var blending = layerData.blending;
                                    if (row >= layerRows) {
                                        row -= layerRows;
                                        depthExtra += 0.1;
                                        blending = layerData.extraBlending;
                                        alpha = layerData.extraOpacity;
                                    }
                                    while (row >= layerRows) {
                                        row -= layerRows;
                                        depthExtra += 0.1;
                                    }
                                    if (tilesAlpha != null) {
                                        alpha *= tilesAlpha.unsafeGet(t);
                                    }

                                    var tileLeft = column * tileset.tileWidth;
                                    if (tilesOffsetX != null) {
                                        tileLeft += tilesOffsetX.unsafeGet(t);
                                    }

                                    var tileTop = row * tileset.tileWidth;
                                    if (tilesOffsetY != null) {
                                        tileTop += tilesOffsetY.unsafeGet(t);
                                    }

                                    var tileWidth = tileset.tileWidth;
                                    var tileHeight = tileset.tileHeight;

                                    var quad:TilemapQuad = usedQuads < tileQuads.length ? tileQuads[usedQuads] : null;
                                    if (quad == null) {
                                        quad = TilemapQuad.get();
                                        quad.anchor(0.5, 0.5);
                                        quad.inheritAlpha = true;
                                        tileQuads.push(quad);
                                        if (tilesFilter != null) {
                                            tilesFilter.content.add(quad);
                                        }
                                        else {
                                            add(quad);
                                        }
                                    }
                                    usedQuads++;

                                    if (quad.index != -1 && quad.index != t && tileQuadMapping.get(quad.index) == usedQuads) {
                                        tileQuadMapping.set(quad.index, 0);
                                    }
                                    tileQuadMapping.set(t, usedQuads);

                                    quad.tilemapTile = tile;
                                    quad.roundTranslation = roundTilesTranslation;
                                    quad.color = color;
                                    quad.index = t;
                                    quad.column = column;
                                    quad.row = row;
                                    quad.alpha = alpha;
                                    quad.blending = blending;
                                    quad.visible = true;
                                    quad.texture = tileset.image.texture;
                                    quad.frameX = (index % tileset.columns) * (tileset.tileWidth + tileset.margin * 2 + tileset.spacing) + tileset.margin;
                                    quad.frameY = Math.floor(index / tileset.columns) * (tileset.tileHeight + tileset.margin * 2) + tileset.spacing;
                                    quad.frameWidth = tileset.tileWidth;
                                    quad.frameHeight = tileset.tileHeight;
                                    quad.depth = startDepthX + column * depthXStep + startDepthY + row * depthYStep + depthExtra;
                                    quad.x = tileWidth * 0.5 + tileLeft - filterX;
                                    quad.y = tileHeight * 0.5 + tileTop - filterY;

                                    if (tile.diagonalFlip) {

                                        if (tile.verticalFlip)
                                            quad.scaleX = -1.0 * tileScale;
                                        else
                                            quad.scaleX = tileScale;

                                        if (tile.horizontalFlip)
                                            quad.scaleY = tileScale;
                                        else
                                            quad.scaleY = -1.0 * tileScale;

                                        quad.rotateFrame = true;
                                    }
                                    else {

                                        if (tile.horizontalFlip)
                                            quad.scaleX = -1.0 * tileScale;
                                        else
                                            quad.scaleX = tileScale;

                                        if (tile.verticalFlip)
                                            quad.scaleY = -1.0 * tileScale;
                                        else
                                            quad.scaleY = tileScale;

                                        quad.rotateFrame = false;
                                    }

                                }

                                t += tilesPerLayer;
                            }

                            r++;
                        }
                        c++;
                    }
                }
            }
        }

        // Remove unused quads
        while (usedQuads < tileQuads.length) {
            var quad = tileQuads.pop();
            quad.recycle();
        }

        emitTileQuadsChange();

    }

/// Helpers

    public function tileQuadByColumnAndRow(column:Int, row:Int):TilemapQuad {

        var index = row * layerData.columns + column;
        return inline tileQuadByIndex(index);

    }

    public function tileQuadByIndex(index:Int):TilemapQuad {

        var arrayIndex = tileQuadMapping.get(index);
        return arrayIndex != -1 ? tileQuads[arrayIndex - 1] : null;

    }

    /**
     * Retrieve surrounding tile quads (that could collide within the given area).
     * The area is relative to this layer and does not take into account any offset or layer position.
     * @param left
     * @param top
     * @param right
     * @param bottom
     * @param result
     * @return Array<TilemapQuad>
     */
    public function surroundingTileQuads(left:Float, top:Float, right:Float, bottom:Float, ?result:Array<TilemapQuad>):Array<TilemapQuad> {

        if (result == null) {
            result = [];
        }

        if (parent != null) {

            var layerData = this.layerData;
            var tileWidth = layerData.tileWidth;
            var tileHeight = layerData.tileHeight;

            var minColumn = Math.floor(left / tileWidth);
            var maxColumn = Math.ceil(right / tileWidth);
            var minRow = Math.floor(top / tileHeight);
            var maxRow = Math.ceil(bottom / tileHeight);

            var column = minColumn;
            while (column <= maxColumn) {
                var row = minRow;
                while (row <= maxRow) {
                    var tileQuad = inline tileQuadByColumnAndRow(column, row);
                    if (tileQuad != null) {
                        result.push(tileQuad);
                    }
                    row++;
                }
                column++;
            }
        }

        return result;

    }

}
