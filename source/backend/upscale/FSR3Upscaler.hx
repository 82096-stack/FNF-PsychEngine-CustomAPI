package backend.upscale;

import backend.BgfxAPI;

/**
 * FSR 3.1 (AMD FidelityFX Super Resolution 3.1) Upscaler.
 *
 * Enhanced temporal upscaling with shading change detection via fsr2_bridge.cpp.
 * Works on ALL GPUs and graphics APIs (cross-API via bgfx).
 */
class FSR3Upscaler implements IUpscaler
{
	var _context:cpp.RawPointer<cpp.Void> = null;
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _sharpness:Float = 0.5;
	var _frameTimeDelta:Float = 16.67;
	var _jitterX:Float = 0.0;
	var _jitterY:Float = 0.0;
	var _jitterIndex:Int = 0;
	var _jitterPhaseCount:Int = 8;
	var _initialized:Bool = false;

	public var sharpness(get, set):Float;
	function get_sharpness():Float { return _sharpness; }
	function set_sharpness(v:Float):Float { return _sharpness = v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v); }

	public function new() {}

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;
		_jitterPhaseCount = BgfxAPI.fsr2GetJitterPhaseCount(inputW, outputW);

		var ctxPtr = untyped __cpp__('&{0}', _context);
		var result = BgfxAPI.fsr2Init(ctxPtr, 31,
			_outputW, _outputH, _outputW, _outputH, false, false, false);
		if (result != 0) { trace('FSR 3.1: SDK not linked — falling back to FSR 1'); return false; }
		_initialized = true;
		trace('FSR 3.1: ready (${inputW}x${inputH} → ${outputW}x${outputH})');
		return true;
	}

	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		if (!_initialized || _context == null) return;
		var colorIn = BgfxAPI.hxGetNativeTexture(inputTextureHandle);
		var colorOut = outputFBHandle != 0 ? BgfxAPI.hxGetNativeFBTexture(outputFBHandle) : null;
		if (colorIn == null) return;

		_jitterIndex = (_jitterIndex + 1) % _jitterPhaseCount;
		var jxPtr = cpp.Pointer.addressOf(_jitterX);
		var jyPtr = cpp.Pointer.addressOf(_jitterY);
		BgfxAPI.fsr2GetJitterOffset(null, _jitterIndex, _jitterPhaseCount, cast jxPtr, cast jyPtr);

		BgfxAPI.fsr2Dispatch(_context, null, colorIn, null, null, colorOut,
			_jitterX, _jitterY, 1.0, 1.0, _inputW, _inputH, _sharpness,
			_frameTimeDelta, 1.0, false, 0.1, 1000.0, 1.0);
	}

	public function dispose():Void
	{
		if (_context != null) { BgfxAPI.fsr2Destroy(_context); _context = null; }
		_initialized = false;
	}

	public function getName():String { return 'FSR 3.1'; }
	public function setJitterOffset(x:Float, y:Float):Void { _jitterX = x; _jitterY = y; }
	public function setFrameTimeDelta(dt:Float):Void { _frameTimeDelta = dt; }
}
