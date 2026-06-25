package backend.upscale;

import backend.BgfxAPI;
import backend.RenderDevice;

class DirectEnlargeUpscaler implements IUpscaler
{
	var _prog:Int = 0;
	var _sampler:Int = 0;
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _initialized:Bool = false;

	// bgfx sampler flag constants (from bgfx/defines.h)
	static inline var BGFX_SAMPLER_MIN_POINT:Int       = 0x00000040;
	static inline var BGFX_SAMPLER_MAG_POINT:Int       = 0x00000100;
	static inline var BGFX_SAMPLER_MIN_ANISOTROPIC:Int = 0x00000080;
	static inline var BGFX_SAMPLER_MAG_ANISOTROPIC:Int = 0x00000200;

	var _samplerFlags:Int = 0; // default = Bilinear (bgfx default linear sampling)

	/**
	 * Filter mode: 'Nearest' (pixel art), 'Bilinear' (smooth, default),
	 * or 'Bicubic' (anisotropic approximation).
	 */
	public var filterMode(default, set):String = 'Bilinear';

	function set_filterMode(v:String):String
	{
		_samplerFlags = switch(v) {
			case 'Nearest':  BGFX_SAMPLER_MIN_POINT | BGFX_SAMPLER_MAG_POINT;
			case 'Bicubic':  BGFX_SAMPLER_MIN_ANISOTROPIC | BGFX_SAMPLER_MAG_ANISOTROPIC;
			default:         0; // Bilinear (bgfx default)
		}
		return filterMode = v;
	}

	public function new() {}

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		if (_initialized)
		{
			_inputW = inputW; _inputH = inputH;
			_outputW = outputW; _outputH = outputH;
			return true;
		}

		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;

		var vsData = loadShaderData('fullscreenBlit.vert');
		var fsData = loadShaderData('fullscreenBlit.frag');
		if (vsData == null || fsData == null)
		{
			trace('DirectEnlarge: failed to load shader data');
			return false;
		}

		var vs = BgfxAPI.createShader(vsData);
		var fs = BgfxAPI.createShader(fsData);
		if (vs == 0 || fs == 0)
		{
			trace('DirectEnlarge: failed to create shaders');
			return false;
		}

		_prog = BgfxAPI.createProgram(vs, fs, true);
		if (_prog == 0)
		{
			trace('DirectEnlarge: failed to create program');
			return false;
		}

		_sampler = BgfxAPI.createUniform('s_inputTexture', 1, 1);

		_initialized = true;
		trace('DirectEnlarge: ready (${inputW}x${inputH} -> ${outputW}x${outputH})');
		return true;
	}

	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		if (!_initialized || _prog == 0) return;

		if (outputFBHandle != 0)
			BgfxAPI.setViewFrameBuffer(RenderDevice.VIEW_MAIN, outputFBHandle);

		BgfxAPI.setViewRect(RenderDevice.VIEW_MAIN, 0, 0, _outputW, _outputH);
		BgfxAPI.setTexture(0, _sampler, inputTextureHandle, _samplerFlags);
		BgfxAPI.setState(0, 0);
		BgfxAPI.submit(RenderDevice.VIEW_MAIN, _prog, 0, 0);
	}

	public function dispose():Void
	{
		if (_prog != 0) { BgfxAPI.destroyProgram(_prog); _prog = 0; }
		_sampler = 0;
		_initialized = false;
	}

	public function getName():String { return 'Directly Enlarge'; }

	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}

	static function loadShaderData(name:String):Dynamic
	{
		try
		{
			var path = 'assets/shaders/bgfx/$name.bin';
			if (openfl.Assets.exists(path))
				return openfl.Assets.getBytes(path);
		}
		catch (e:Dynamic) { trace('DirectEnlarge: failed to load shader $name — $e'); }
		return null;
	}
}
