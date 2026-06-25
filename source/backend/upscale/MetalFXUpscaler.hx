package backend.upscale;

#if mac
import backend.BgfxAPI;
#end

/**
 * MetalFX Upscaler — Apple's built-in upscaling framework.
 *
 * Uses the official MTLFXSpatialScaler (mode=Spatial) or
 * MTLFXTemporalScaler (mode=Temporal) via metalfx_bridge.mm.
 *
 * Operates on native Metal textures — no CPU readback.
 * Shares bgfx's MTLDevice for zero-copy GPU pipeline.
 *
 * Spatial:  Single-frame upscale. No depth/motion needed. Best for 2D.
 * Temporal: Multi-frame upscale with anti-aliasing.
 *           Uses flat depth (1.0) + zero motion for 2D games.
 *
 * Requires macOS 13.0+ (Ventura), MetalFX.framework.
 */
class MetalFXUpscaler implements IUpscaler
{
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _mode:Int = 0; // 0=Spatial, 1=Temporal
	var _initialized:Bool = false;

	/** Mode: 'Spatial' (default) or 'Temporal'. Changes require re-init. */
	public var mode(default, set):String = 'Spatial';

	function set_mode(v:String):String
	{
		_mode = (v == 'Temporal') ? 1 : 0;
		return mode = v;
	}

	public function new() {}

	// ================================================================
	// IUpscaler
	// ================================================================

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		#if !mac
		return false;
		#end

		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;

		// Get bgfx's MTLDevice
		var device = BgfxAPI.hxGetMTLDevice();
		if (device == null)
		{
			trace('MetalFX: bgfx MTLDevice not available');
			return false;
		}

		// Check device support
		if (!BgfxAPI.metalFXIsSupported(device))
		{
			trace('MetalFX: device does not support MetalFX');
			return false;
		}

		var ok = BgfxAPI.metalFXInit(device, inputW, inputH, outputW, outputH, _mode);
		if (!ok)
		{
			trace('MetalFX: init failed');
			return false;
		}

		// Reset temporal history on fresh init
		if (_mode == 1)
			BgfxAPI.metalFXReset();

		_initialized = true;
		trace('MetalFX: initialized (${inputW}x${inputH} → ${outputW}x${outputH}, mode=${mode})');
		return true;
	}

	/**
	 * Apply MetalFX upscaling.
	 * Uses native MTLTexture handles from bgfx — zero CPU copies.
	 *
	 * @param inputTextureHandle  bgfx texture handle of the low-res render target
	 * @param outputFBHandle      bgfx framebuffer handle of the output target (0 = backbuffer)
	 */
	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		#if !mac
		return;
		#end

		if (!_initialized) return;

		// Get native Metal textures from bgfx handles
		var inputTex = BgfxAPI.hxGetNativeTexture(inputTextureHandle);
		if (inputTex == null)
		{
			trace('MetalFX: cannot get native texture for handle $inputTextureHandle');
			return;
		}

		// For output, try the framebuffer texture first, fall back to backbuffer
		var outputTex:cpp.RawPointer<cpp.Void> = null;
		if (outputFBHandle != 0)
			outputTex = BgfxAPI.hxGetNativeFBTexture(outputFBHandle);
		// If still null, the apply will fail gracefully

		if (outputTex == null)
			return;

		BgfxAPI.metalFXApply(inputTex, outputTex);
	}

	public function dispose():Void
	{
		#if mac
		BgfxAPI.metalFXDispose();
		#end
		_initialized = false;
	}

	public function getName():String
	{
		return 'MetalFX ${mode}';
	}

	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}

	/**
	 * Reset temporal history (only effective in Temporal mode).
	 * Call after resolution changes or scene transitions.
	 */
	public function reset():Void
	{
		#if mac
		if (_initialized && _mode == 1)
			BgfxAPI.metalFXReset();
		#end
	}
}
