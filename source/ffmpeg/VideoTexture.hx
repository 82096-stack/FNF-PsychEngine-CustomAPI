package ffmpeg;

import openfl.display.BitmapData;
import flixel.graphics.FlxGraphic;
import backend.BgfxTextureManager;

/**
 * VideoTexture — manages a BGFX GPU texture for video frame display.
 *
 * Since video frames change every frame (unlike static sprites), we need a
 * dedicated texture that can be updated in-place. This class:
 *
 *   1. Creates a FlxGraphic from the video's BitmapData (once, at init)
 *   2. Provides updateFrame() to re-upload latest pixels to GPU each frame
 *   3. Handles cleanup when the video ends
 *
 * The texture key is deterministic ("video_" + hashCode), so the same
 * texture is reused across frame updates rather than creating new ones.
 *
 * Integration: VideoSprite creates a VideoTexture, calls init() once, then
 * updateFrame() each frame the decoder has new data. BGFX rendering picks
 * up the updated texture automatically via the FlxGraphic's cache key.
 */
class VideoTexture
{
	/** Auto-incrementing counter for unique texture key generation. */
	static var _nextId:Int = 0;

	/** The FlxGraphic that wraps the video BitmapData. */
	public var graphic(default, null):FlxGraphic = null;

	/** Cache key used for BGFX texture lookup. */
	public var key(default, null):String = null;

	/** Current width/height of the texture. */
	public var width(get, never):Int;
	public var height(get, never):Int;

	var currentBmp:BitmapData = null;

	public function new() {}

	function get_width():Int  return currentBmp != null ? currentBmp.width  : 0;
	function get_height():Int return currentBmp != null ? currentBmp.height : 0;

	/**
	 * Initialize the texture with a BitmapData.
	 * Creates the FlxGraphic and uploads to BGFX.
	 *
	 * @param bmp       The video's BitmapData (will be updated in-place by decoder).
	 * @param textureId Optional unique identifier for the texture key.
	 *                  Defaults to a hash of the bitmap.
	 */
	public function init(bmp:BitmapData, ?textureId:String):Void
	{
		if (bmp == null) return;

		currentBmp = bmp;

		// Create FlxGraphic from the BitmapData (does NOT copy pixels)
		graphic = FlxGraphic.fromBitmapData(bmp, false, null, false);

		// Generate a stable cache key
		key = textureId != null ? 'video_$textureId' : 'video_${bmp.width}x${bmp.height}_${_nextId++}';

		// Upload to GPU via BgfxTextureManager
		BgfxTextureManager.cacheOnGPU(key, bmp);

		#if debug
		trace('[VideoTexture] Initialized ${bmp.width}x${bmp.height}, key=$key');
		#end
	}

	/**
	 * Update the GPU texture with the latest pixel data from the BitmapData.
	 * Call this once per frame when the decoder has produced a new frame.
	 *
	 * The BitmapData should already have been updated via setPixels() before
	 * calling this method.
	 */
	public function updateFrame():Void
	{
		if (currentBmp == null || key == null) return;

		BgfxTextureManager.updateTexture(key, currentBmp);
	}

	/**
	 * Check whether the current frame's BitmapData has already been uploaded.
	 * Returns false if updateFrame() hasn't been called yet or if the texture
	 * was invalidated (e.g., after a BGFX API switch).
	 */
	public function isOnGPU():Bool
	{
		return key != null && BgfxTextureManager.has(key);
	}

	/**
	 * Dispose the BGFX texture and release the FlxGraphic.
	 * Safe to call multiple times.
	 */
	public function dispose():Void
	{
		if (key != null)
		{
			BgfxTextureManager.dispose(key);
			key = null;
		}

		if (graphic != null)
		{
			graphic.destroy();
			graphic = null;
		}

		currentBmp = null;
	}

	/**
	 * Re-create the BGFX texture from the cached BitmapData.
	 * Used after a BGFX API switch (e.g., Metal → Vulkan) when all
	 * GPU resources are invalidated and need restoration.
	 */
	public function restore():Void
	{
		if (currentBmp != null && key != null)
		{
			BgfxTextureManager.cacheOnGPU(key, currentBmp);
		}
	}
}
