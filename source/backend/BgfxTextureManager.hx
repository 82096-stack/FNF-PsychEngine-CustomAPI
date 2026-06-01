package backend;

import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
// All bgfx types in same package (backend) — no import needed

class BgfxTextureManager
{
	static var textures:Map<String, Int> = new Map();
	static var cachedBitmaps:Map<String, BitmapData> = new Map();

	public static function get(graphic:FlxGraphic):Int
	{
		if (graphic == null || graphic.bitmap == null) return 0;
		var key = graphic.key;
		if (textures.exists(key)) return textures.get(key);
		var h = createFromBitmap(graphic.bitmap);
		if (h != 0) { textures.set(key, h); cachedBitmaps.set(key, graphic.bitmap); }
		return h;
	}

	static function createFromBitmap(bmp:BitmapData):Int
	{
		if (bmp == null) return 0;
		var pixels = bmp.getPixels(bmp.rect);
		if (pixels == null) return 0;
		var mem = BgfxAPI.copy(pixels, bmp.width * bmp.height * 4);
		if (mem == null) return 0;
		return BgfxAPI.createTexture2D(bmp.width, bmp.height, false, 1, 66 /*BGRA8*/, 0, mem);
	}

	public static function dispose(key:String):Void
	{
		var h = textures.get(key);
		if (h != 0) BgfxAPI.destroyTexture(h);
		textures.remove(key); cachedBitmaps.remove(key);
	}

	public static function disposeAll():Void
	{
		for (h in textures) BgfxAPI.destroyTexture(h);
		textures.clear(); cachedBitmaps.clear();
	}

	public static function invalidateAll():Void
	{
		for (h in textures) BgfxAPI.destroyTexture(h);
		textures.clear();
	}

	public static function restoreAll():Void
	{
		for (key => bmp in cachedBitmaps)
			if (!textures.exists(key)) textures.set(key, createFromBitmap(bmp));
	}

	public static function cacheOnGPU(key:String, bmp:BitmapData):Void
	{
		if (!textures.exists(key) && bmp != null) {
			var h = createFromBitmap(bmp);
			if (h != 0) { textures.set(key, h); cachedBitmaps.set(key, bmp); }
		}
	}
}
