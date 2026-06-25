package backend.upscale;

import backend.BgfxAPI;
import backend.RenderDevice;

/**
 * NIS (NVIDIA Image Scaling) Upscaler.
 *
 * Based on NVIDIA's open-source NIS SDK (MIT license).
 * https://github.com/NVIDIAGameWorks/NVIDIAImageScaling
 *
 * Single-pass fragment shader that combines:
 *   - 4-directional Lanczos-like upscaling
 *   - Adaptive contrast-aware sharpening
 *
 * Works on ALL GPUs (pure shader, no hardware dependency).
 * NVIDIA Maxwell (GTX 900) or newer recommended but not required.
 */
class NISUpscaler implements IUpscaler
{
	var _prog:Int = 0;
	var _sampler:Int = 0;
	var _uConfig:Int = 0;
	var _uConfig1:Int = 0;
	var _uScale:Int = 0;
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _sharpness:Float = 0.5;
	var _initialized:Bool = false;

	public var sharpness(get, set):Float;

	function get_sharpness():Float { return _sharpness; }
	function set_sharpness(v:Float):Float { return _sharpness = clamp(v, 0.0, 1.0); }

	public function new() {}

	// ================================================================
	// IUpscaler
	// ================================================================

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		
		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;

		if (_initialized)
		{
			updateUniforms();
			return true;
		}

		// Load and compile NIS shader
		var fsData = loadNISShader();
		if (fsData == null)
		{
			trace('NIS: failed to load shader data');
			return false;
		}

		var vs = createFullscreenVS();
		var fs = BgfxAPI.createShader(fsData);
		if (vs == 0 || fs == 0)
		{
			trace('NIS: failed to create shaders');
			return false;
		}

		_prog = BgfxAPI.createProgram(vs, fs, true);
		if (_prog == 0)
		{
			trace('NIS: failed to create program');
			return false;
		}

		// Create uniforms
		_sampler    = BgfxAPI.createUniform('s_inputTexture', 1, 1);
		_uConfig    = BgfxAPI.createUniform('u_nisConfig',    2, 1); // Vec4
		_uConfig1   = BgfxAPI.createUniform('u_nisConfig1',   2, 1);
		_uScale     = BgfxAPI.createUniform('u_nisScale',     2, 1);

		updateUniforms();

		_initialized = true;
		trace('NIS: initialized (${inputW}x${inputH} -> ${outputW}x${outputH}, sharpness=${_sharpness})');
		return true;
	}

	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		if (!_initialized || _prog == 0) return;

		if (outputFBHandle != 0)
			BgfxAPI.setViewFrameBuffer(RenderDevice.VIEW_MAIN, outputFBHandle);

		BgfxAPI.setViewRect(RenderDevice.VIEW_MAIN, 0, 0, _outputW, _outputH);
		BgfxAPI.setTexture(0, _sampler, inputTextureHandle, 0);

		// Upload NIS uniforms
		var scaleX:Float = _outputW / _inputW;
		var scaleY:Float = _outputH / _inputH;
		var config:Array<Float> = [_sharpness, _inputW, _inputH, _outputW];
		var config1:Array<Float> = [_outputH, scaleX, scaleY, 0.0];
		var nisScale:Array<Float> = [1.0/_inputW, 1.0/_inputH, 1.0/_outputW, 1.0/_outputH];

		BgfxAPI.setUniform(_uConfig,  untyped __cpp__('(void*)&({0}[0])', config),  16);
		BgfxAPI.setUniform(_uConfig1, untyped __cpp__('(void*)&({0}[0])', config1), 16);
		BgfxAPI.setUniform(_uScale,   untyped __cpp__('(void*)&({0}[0])', nisScale), 16);

		BgfxAPI.setState(0, 0);
		BgfxAPI.submit(RenderDevice.VIEW_MAIN, _prog, 0, 0);
	}

	public function dispose():Void
	{
		
		if (_prog != 0) { BgfxAPI.destroyProgram(_prog); _prog = 0; }
		_uConfig = 0; _uConfig1 = 0; _uScale = 0; _sampler = 0;
		_initialized = false;
	}

	public function getName():String { return 'NIS'; }

	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}

	// ================================================================
	// Helpers
	// ================================================================

	function updateUniforms():Void
	{
		#if hxbgfx_native
		// Set uniform values via bgfx (uniforms are set per-draw, stored as ref data)
		// For now, uniforms are set via bgfx_set_uniform in the bridge
		// The shader reads: u_nisConfig.xyzw = sharpness, inputW, inputH, outputW
		//                  u_nisConfig1.xyzw = outputH, scaleX, scaleY, 0
		//                  u_nisScale.xyzw = 1/inputW, 1/inputH, 1/outputW, 1/outputH
		var scaleX:Float = _outputW / _inputW;
		var scaleY:Float = _outputH / _inputH;

		trace('NIS config: sharpness=${_sharpness} scale=${scaleX}x${scaleY}');
		// Actual uniform upload happens in apply() via bgfx uniform API
		#end
	}

	static function loadNISShader():Dynamic
	{
		#if hxbgfx_native
		return loadShaderBinary('nisUpscale.frag');
		#end
		return null;
	}

	static function createFullscreenVS():Int
	{
		#if hxbgfx_native
		var data = loadShaderBinary('fullscreenBlit.vert');
		return data != null ? BgfxAPI.createShader(data) : 0;
		#end
		return 0;
	}

	static function loadShaderBinary(name:String):Dynamic
	{
		#if hxbgfx_native
		try
		{
			var path = 'assets/shaders/bgfx/$name.bin';
			if (openfl.Assets.exists(path))
				return openfl.Assets.getBytes(path);
		}
		catch (e:Dynamic)
		{
			trace('NIS: failed to load shader $name — $e');
		}
		#end
		return null;
	}

	static inline function clamp(v:Float, lo:Float, hi:Float):Float
	{
		return v < lo ? lo : (v > hi ? hi : v);
	}
}
