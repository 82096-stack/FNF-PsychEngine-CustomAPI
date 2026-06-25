package backend.upscale;

import backend.BgfxAPI;
import backend.RenderDevice;

/**
 * FSR 1 (AMD FidelityFX Super Resolution 1.0) Upscaler.
 *
 * Based on AMD's open-source FSR 1.0 (MIT license).
 * https://github.com/GPUOpen-Effects/FidelityFX-FSR
 *
 * Two-pass pipeline:
 *   Pass 1 — EASU (Edge-Adaptive Spatial Upsampling):
 *     Analyzes local gradient direction and samples along edges
 *     to preserve sharpness while upscaling.
 *   Pass 2 — RCAS (Robust Contrast Adaptive Sharpening):
 *     Post-process sharpening that adapts to local contrast.
 *
 * Works on ALL GPUs. No hardware requirements (pure compute/fragment shader).
 */
class FSRUpscaler implements IUpscaler
{
	var _progEASU:Int = 0;
	var _progRCAS:Int = 0;
	var _sampler:Int = 0;

	// EASU uniforms
	var _uEASU0:Int = 0;
	var _uEASU1:Int = 0;
	var _uEASU2:Int = 0;
	var _uEASU3:Int = 0;

	// RCAS uniforms
	var _uRCAS0:Int = 0;

	// Intermediate render target (EASU output → RCAS input)
	var _rtIntermediate:Int = 0;
	var _rtIntermediateTex:Int = 0;

	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _sharpness:Float = 0.5;
	var _version:String = 'FSR 1';
	var _initialized:Bool = false;

	public var sharpness(get, set):Float;

	function get_sharpness():Float { return _sharpness; }
	function set_sharpness(v:Float):Float { return _sharpness = clamp(v, 0.0, 1.0); }

	/**
	 * FSR version: 'FSR 1', 'FSR 2', or 'FSR 3.1'.
	 * FSR 2/3.1 currently use the FSR 1 EASU+RCAS pipeline as fallback.
	 * Full SDK integration for FSR 2/3.1 is pending.
	 */
	public var version(default, set):String = 'FSR 1';

	function set_version(v:String):String
	{
		return _version = switch(v) {
			case 'FSR 2', 'FSR 3.1': v;
			default: 'FSR 1';
		}
	}

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
			// Resize: recreate intermediate render target
			disposeIntermediateRT();
			createIntermediateRT();
			updateUniforms();
			return true;
		}

		// Create EASU program
		var vs = createFullscreenVS();
		var fsEASU = loadFSRShader('fsrEASU.frag');
		var fsRCAS = loadFSRShader('fsrRCAS.frag');

		if (vs == 0 || fsEASU == null || fsRCAS == null)
		{
			trace('FSR: failed to load shaders');
			return false;
		}

		var easuFS = BgfxAPI.createShader(fsEASU);
		var rcasFS = BgfxAPI.createShader(fsRCAS);

		if (easuFS == 0 || rcasFS == 0)
		{
			trace('FSR: failed to compile shaders');
			return false;
		}

		_progEASU = BgfxAPI.createProgram(vs, easuFS, true);
		_progRCAS = BgfxAPI.createProgram(vs, rcasFS, true);

		if (_progEASU == 0 || _progRCAS == 0)
		{
			trace('FSR: failed to create programs');
			return false;
		}

		// Create uniforms
		_sampler = BgfxAPI.createUniform('s_inputTexture', 1, 1);
		_uEASU0  = BgfxAPI.createUniform('u_fsrEASUConst0', 2, 1);
		_uEASU1  = BgfxAPI.createUniform('u_fsrEASUConst1', 2, 1);
		_uEASU2  = BgfxAPI.createUniform('u_fsrEASUConst2', 2, 1);
		_uEASU3  = BgfxAPI.createUniform('u_fsrEASUConst3', 2, 1);
		_uRCAS0  = BgfxAPI.createUniform('u_fsrRCASConst0', 2, 1);

		// Create intermediate render target (output resolution, EASU output = RCAS input)
		createIntermediateRT();

		updateUniforms();

		_initialized = true;
		trace('FSR: initialized (${inputW}x${inputH} -> ${outputW}x${outputH}, sharpness=${_sharpness})');
		return true;
	}

	/**
	 * Two-pass FSR application:
	 *   1. EASU: input texture → intermediate RT (at output resolution)
	 *   2. RCAS: intermediate RT → output framebuffer
	 */
	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		if (!_initialized || _progEASU == 0 || _progRCAS == 0) return;
		if (_rtIntermediate == 0) return;

		var scaleX:Float = _outputW / _inputW;
		var scaleY:Float = _outputH / _inputH;

		// ── Pass 1: EASU ──────────────────────────────────────────
		BgfxAPI.setViewFrameBuffer(RenderDevice.VIEW_MAIN, _rtIntermediate);
		BgfxAPI.setViewRect(RenderDevice.VIEW_MAIN, 0, 0, _outputW, _outputH);
		BgfxAPI.setTexture(0, _sampler, inputTextureHandle, 0);

		var easu0:Array<Float> = [1.0/_inputW, 1.0/_inputH, _inputW, _inputH];
		var easu1:Array<Float> = [_outputW, _outputH, 1.0/_outputW, 1.0/_outputH];
		var easu2:Array<Float> = [scaleX, scaleY, 0.0, 0.0];
		BgfxAPI.setUniform(_uEASU0, untyped __cpp__('(void*)&({0}[0])', easu0), 16);
		BgfxAPI.setUniform(_uEASU1, untyped __cpp__('(void*)&({0}[0])', easu1), 16);
		BgfxAPI.setUniform(_uEASU2, untyped __cpp__('(void*)&({0}[0])', easu2), 16);

		BgfxAPI.setState(0, 0);
		BgfxAPI.submit(RenderDevice.VIEW_MAIN, _progEASU, 0, 0);

		// ── Pass 2: RCAS ──────────────────────────────────────────
		if (outputFBHandle != 0)
			BgfxAPI.setViewFrameBuffer(RenderDevice.VIEW_MAIN, outputFBHandle);

		BgfxAPI.setTexture(0, _sampler, _rtIntermediateTex, 0);

		var rcas0:Array<Float> = [1.0/_outputW, 1.0/_outputH, _sharpness, 0.0];
		BgfxAPI.setUniform(_uRCAS0, untyped __cpp__('(void*)&({0}[0])', rcas0), 16);

		BgfxAPI.setState(0, 0);
		BgfxAPI.submit(RenderDevice.VIEW_MAIN, _progRCAS, 0, 0);
	}

	public function dispose():Void
	{
		
		if (_progEASU != 0) { BgfxAPI.destroyProgram(_progEASU); _progEASU = 0; }
		if (_progRCAS != 0) { BgfxAPI.destroyProgram(_progRCAS); _progRCAS = 0; }
		disposeIntermediateRT();
		_uEASU0 = 0; _uEASU1 = 0; _uEASU2 = 0; _uEASU3 = 0;
		_uRCAS0 = 0; _sampler = 0;
		_initialized = false;
	}

	public function getName():String { return _version; }

	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}

	// ================================================================
	// Intermediate RT (EASU output)
	// ================================================================

	function createIntermediateRT():Void
	{
		#if hxbgfx_native
		_rtIntermediateTex = BgfxAPI.createRenderTexture(_outputW, _outputH, 67 /*RGBA8*/);
		if (_rtIntermediateTex != 0)
			_rtIntermediate = BgfxAPI.createFrameBuffer(_rtIntermediateTex);
		#end
	}

	function disposeIntermediateRT():Void
	{
		#if hxbgfx_native
		if (_rtIntermediate != 0) { BgfxAPI.destroyFrameBuffer(_rtIntermediate); _rtIntermediate = 0; }
		if (_rtIntermediateTex != 0) { BgfxAPI.destroyTexture(_rtIntermediateTex); _rtIntermediateTex = 0; }
		#end
	}

	// ================================================================
	// Helpers
	// ================================================================

	function updateUniforms():Void
	{
		#if hxbgfx_native
		var scaleX:Float = _outputW / _inputW;
		var scaleY:Float = _outputH / _inputH;

		trace('FSR config: scale=${scaleX}x${scaleY} sharpness=${_sharpness}');
		// EASU: u_fsrEASUConst0 = (1/inputW, 1/inputH, inputW, inputH)
		//        u_fsrEASUConst1 = (outputW, outputH, 1/outputW, 1/outputH)
		//        u_fsrEASUConst2 = (scaleX, scaleY, 0, 0)
		// RCAS:  u_fsrRCASConst0 = (1/outputW, 1/outputH, sharpness, 0)
		// Actual uniform upload via bgfx_set_uniform happens per frame
		#end
	}

	static function loadFSRShader(name:String):Dynamic
	{
		#if hxbgfx_native
		return loadShaderBinary(name);
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
			trace('FSR: failed to load shader $name — $e');
		}
		#end
		return null;
	}

	static inline function clamp(v:Float, lo:Float, hi:Float):Float
	{
		return v < lo ? lo : (v > hi ? hi : v);
	}
}
