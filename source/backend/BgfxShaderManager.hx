package backend;

import flixel.system.FlxAssets.FlxShader;

class BgfxShaderManager
{
	static var programs:Map<String, Int> = new Map();
	static var defaultProgram:Int = 0;
	static var s_tex:Int = 0;

	public static function getDefaultProgram():Int
	{
		if (defaultProgram != 0) return defaultProgram;
		var vs = BgfxAPI.createShader(null);
		var fs = BgfxAPI.createShader(null);
		if (vs != 0 && fs != 0) defaultProgram = BgfxAPI.createProgram(vs, fs, true);
		return defaultProgram != 0 ? defaultProgram : 1;
	}

	public static function getTextureSampler():Int
	{
		if (s_tex == 0) s_tex = BgfxAPI.createUniform("s_tex", 0, 1);
		return s_tex;
	}

	public static function get(shader:FlxShader):Int
	{
		return shader != null ? getDefaultProgram() : getDefaultProgram();
	}

	public static function disposeAll():Void { programs.clear(); defaultProgram = 0; }
	public static function invalidateAll():Void { programs.clear(); defaultProgram = 0; }
}
