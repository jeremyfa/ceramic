package ceramic.macros;

/**
 * Utilities to access defines from code.
 * Original source: https://code.haxe.org/category/macros/get-compiler-define-value.html
 */
class DefinesMacro {

    /**
     * Shorthand for retrieving compiler flag values.
     */
    public static macro function getDefine(key:String):haxe.macro.Expr {
        return macro $v{haxe.macro.Context.definedValue(key)};
    }

    /**
     * Shorthand for retrieving compiler flag values that are double encoded to JSON.
     */
    public static macro function getJsonJsonDefine(key:String):haxe.macro.Expr {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? Json.parse(Json.parse(raw)) : null;
        return macro $v{value};
    }

    /**
     * Shorthand for retrieving compiler flag values that are single encoded to JSON.
     */
    public static macro function getJsonDefine(key:String):haxe.macro.Expr {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? Json.parse(raw) : null;
        return macro $v{value};
    }

    #if macro
    public static function jsonJsonDefinedValue(key:String):String {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? haxe.Json.parse(haxe.Json.parse(raw)) : null;
        return value;
    }

    public static function jsonDefinedValue(key:String):String {
        var raw = haxe.macro.Context.definedValue(key);
        var value = raw != null ? haxe.Json.parse(raw) : null;
        return value;
    }
    #end

    /**
     * Shorthand for retrieving compiler flag values as `Float`.
     */
    public static macro function getFloatDefine(key:String):haxe.macro.Expr {
        return macro $v{Std.parseFloat(haxe.macro.Context.definedValue(key))};
    }

    /**
     * Shorthand for retrieving compiler flag values as `Int`.
     */
    public static macro function getIntDefine(key:String):haxe.macro.Expr {
        return macro $v{Std.parseInt(haxe.macro.Context.definedValue(key))};
    }

    /**
     * Shorthand for retrieving compiler flag values as `Bool`.
     */
    public static macro function getBoolDefine(key:String):haxe.macro.Expr {
        return macro $v{_stringToBool(haxe.macro.Context.definedValue(key))};
    }

    static function _stringToBool(str:String):Bool {

        if (str == null)
            return false;
        str = str.toLowerCase();
        return str == 'true' || str == '1';

    }

    /**
     * Shorthand for checking if a compiler flag is defined.
     */
    public static macro function isDefined(key:String):haxe.macro.Expr {
        return macro $v{haxe.macro.Context.defined(key)};
    }

    /**
     * Shorthand for retrieving a map of all defined compiler flags.
     */
    public static macro function getDefines():haxe.macro.Expr {
        var defines : Map<String, String> = haxe.macro.Context.getDefines();
        // Construct map syntax so we can return it as an expression
        var map : Array<haxe.macro.Expr> = [];
        for (key in defines.keys()) {
            map.push(macro $v{key} => $v{Std.string(defines.get(key))});
        }
        return macro $a{map};
    }

}
