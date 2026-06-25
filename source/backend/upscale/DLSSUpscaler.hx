package backend.upscale;

/**
 * DLSS (NVIDIA Deep Learning Super Sampling) Upscaler.
 *
 * Uses the NVIDIA DLSS NGX SDK via dlss_bridge.cpp.
 * Requires NVIDIA RTX 20-series or newer GPU.
 *
 * Supports: D3D11, D3D12, Vulkan (with patched bgfx)
 * Presets: A-M (dynamic detection from driver)
 */
class DLSSUpscaler implements IUpscaler
{
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _qualityMode:Int = 2;     // DLSS_BRIDGE_QUALITY_BALANCED (fixed)
	var _preset:Int = 11;         // DLSS_BRIDGE_PRESET_K (newest, default)
	var _sharpness:Float = 0.0;
	var _autoExposure:Bool = true;
	var _initialized:Bool = false;
	var _backend:Int = 0;         // 0=D3D12, 1=D3D11, 2=Vulkan

	public var isHDR:Bool = false;
	public var frameTimeDelta:Float = 16.67;

	public var preset(default, set):String = 'K';
	function set_preset(v:String):String
	{
		_preset = switch(v) {
			case 'A': 1; case 'B': 2; case 'C': 3; case 'D': 4;
			case 'E': 5; case 'F': 6; case 'J': 10; case 'K': 11;
			case 'L': 12; case 'M': 13;
			default: 11;
		}
		return preset = v;
	}

	public var sharpness(get, set):Float;
	function get_sharpness():Float { return _sharpness; }
	function set_sharpness(v:Float):Float { return _sharpness = clamp(v, -1.0, 1.0); }

	public function new() {}

	// ================================================================
	// IUpscaler
	// ================================================================

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		if (!BgfxAPI.dlssIsSupported())
		{
			trace('DLSS: not supported on this system (requires NVIDIA RTX 20+)');
			return false;
		}

		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;

		var apiName = RenderDevice.activeAPI;
		trace('DLSS: active API is $apiName');

		var ok = switch(apiName)
		{
			case 'DirectX 12':
				_backend = 0;
				initD3D12();
			case 'DirectX 11':
				_backend = 1;
				initD3D11();
			case 'Vulkan':
				_backend = 2;
				initVK();
			case 'Metal':
				trace('DLSS: Metal is not supported by NVIDIA.');
				false;
			case 'OpenGL':
				trace('DLSS: OpenGL is not supported by NVIDIA.');
				false;
			default:
				trace('DLSS: Unsupported graphics API ($apiName).');
				false;
		}

		if (!ok) { trace('DLSS: init failed'); return false; }
		_initialized = true;
		trace('DLSS: ready (${_inputW}x${_inputH} -> ${_outputW}x${_outputH}, preset=${preset})');
		return true;
	}

	// ---------- D3D12 ----------

	public function initD3D12():Bool
	{
		#if !windows
		return false;
		#end

		var device = BgfxAPI.hxGetD3D12Device();
		if (device == null) { trace('DLSS: bgfx D3D12 device not available'); return false; }

		BgfxAPI.dlssSetAppId('DEADBEEF');

		var result = BgfxAPI.dlssInitD3D12(device, 'libs/dlss/lib',
			_outputW, _outputH, _qualityMode, _preset);
		if (result != 0) { trace('DLSS: D3D12 init failed (result=$result)'); return false; }

		var cmdQueue = BgfxAPI.hxGetD3D12CmdQueue();
		result = BgfxAPI.dlssCreateFeature(cmdQueue,
			_inputW, _inputH, _outputW, _outputH,
			_qualityMode, _preset, true, isHDR);
		if (result != 0) { trace('DLSS: D3D12 feature creation failed (result=$result)'); return false; }

		trace('DLSS: D3D12 initialized, render=${_inputW}x${_inputH}');
		return true;
	}

	// ---------- D3D11 ----------

	public function initD3D11():Bool
	{
		#if !windows
		return false;
		#end

		var device = BgfxAPI.hxGetD3D11Device();
		if (device == null) { trace('DLSS: bgfx D3D11 device not available'); return false; }

		BgfxAPI.dlssSetAppId('DEADBEEF');

		var result = BgfxAPI.dlssInitD3D11(device, 'libs/dlss/lib',
			_outputW, _outputH, _qualityMode, _preset);
		if (result != 0) { trace('DLSS: D3D11 init failed (result=$result)'); return false; }

		var ctx:cpp.RawPointer<cpp.Void> = null;
		result = BgfxAPI.dlssCreateFeatureD3D11(ctx,
			_inputW, _inputH, _outputW, _outputH,
			_qualityMode, _preset, true, isHDR);
		if (result != 0) { trace('DLSS: D3D11 feature creation failed (result=$result)'); return false; }

		trace('DLSS: D3D11 initialized, render=${_inputW}x${_inputH}');
		return true;
	}

	// ---------- Vulkan ----------

	public function initVK():Bool
	{
		#if !windows
		return false;
		#end

		var inst = BgfxAPI.hxGetVkInstance();
		var phys = BgfxAPI.hxGetVkPhysDevice();
		var dev = BgfxAPI.hxGetVkDevice();
		if (inst == null || phys == null || dev == null)
		{
			trace('DLSS: Vulkan device not available (requires patched bgfx with VK handle patches)');
			return false;
		}

		BgfxAPI.dlssSetAppId('DEADBEEF');

		var result = BgfxAPI.dlssInitVK(untyped __cpp__('0xDEADBEEFULL'), inst, phys, dev,
			'libs/dlss/lib', _outputW, _outputH, _qualityMode, _preset);
		if (result != 0) { trace('DLSS: Vulkan init failed (result=$result)'); return false; }

		var cmdBuf:cpp.RawPointer<cpp.Void> = null;
		result = BgfxAPI.dlssCreateFeatureVK(cmdBuf,
			_inputW, _inputH, _outputW, _outputH,
			_qualityMode, _preset, true, isHDR);
		if (result != 0) { trace('DLSS: Vulkan feature creation failed (result=$result)'); return false; }

		trace('DLSS: Vulkan initialized, render=${_inputW}x${_inputH}');
		return true;
	}

	// ---------- Per-frame ----------

	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		#if !windows
		return;
		#end

		if (!_initialized) return;

		var colorIn = BgfxAPI.hxGetNativeTexture(inputTextureHandle);
		var colorOut = outputFBHandle != 0 ? BgfxAPI.hxGetNativeFBTexture(outputFBHandle) : null;
		if (colorIn == null) return;

		switch(_backend)
		{
			case 0: // D3D12
				BgfxAPI.dlssEvaluate(null, colorIn, colorOut,
					null, null, 0.0, 0.0,
					_sharpness, false,
					frameTimeDelta, 1.0, 1.0);
			case 1: // D3D11
				BgfxAPI.dlssEvaluateD3D11(null, colorIn, colorOut,
					null, null, 0.0, 0.0,
					_sharpness, false,
					frameTimeDelta, 1.0, 1.0);
			case 2: // Vulkan
				BgfxAPI.dlssEvaluateVK(null, colorIn, colorOut,
					null, null, 0.0, 0.0,
					_sharpness, false,
					frameTimeDelta, 1.0, 1.0);
		}
	}

	public function dispose():Void
	{
		BgfxAPI.dlssReleaseFeature();
		if (_backend == 1) BgfxAPI.dlssShutdownD3D11();
		else BgfxAPI.dlssShutdown();
		_initialized = false;
	}

	public function getName():String { return 'DLSS'; }


	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}
	public static function getAvailablePresets():Array<String>
	{
		var result:Array<String> = [];
		#if windows
		var mask = BgfxAPI.dlssGetPresets();
		for (i in 0...64)
		{
			var low:Int = i < 32 ? (untyped __cpp__('(int)({0} & 0xFFFFFFFF)', mask) : 0) : 0;
			var high:Int = i >= 32 ? (untyped __cpp__('(int)(({0} >> 32) & 0xFFFFFFFF)', mask) : 0) : 0;
			var bit:Int = i < 32 ? (low >> i) & 1 : (high >> (i - 32)) & 1;
			if (bit != 0)
			{
				var name = untyped __cpp__('dlss_bridge_preset_to_name({0})', i);
				if (name != null)
				{
					var s:String = new String(name);
					if (s != 'Default') result.push(s);
				}
			}
		}
		result.reverse();
		#end
		return result;
	}

	static inline function clamp(v:Float, lo:Float, hi:Float):Float
	{
		return v < lo ? lo : (v > hi ? hi : v);
	}
}
