package backend.upscale;

import backend.BgfxAPI;
import backend.RenderDevice;
import cpp.RawPointer;
import cpp.Pointer;

/**
 * XeSS (Intel Xe Super Sampling) Upscaler.
 *
 * Uses the Intel XeSS SDK via xess_bridge.cpp.
 * Works on all GPUs with DP4a support (NVIDIA GTX 10+, AMD RX 5000+, Intel Arc).
 *
 * Platform: Windows only (D3D12/Vulkan via the bridge).
 * Quality presets: Ultra Performance, Performance, Balanced, Quality, Ultra Quality, Ultra Quality Plus, AA
 */
class XeSSUpscaler implements IUpscaler
{
	var _context:cpp.RawPointer<cpp.Void> = null;   // xess_context_handle_t
	var _inputW:Int = 0;
	var _inputH:Int = 0;
	var _outputW:Int = 0;
	var _outputH:Int = 0;
	var _qualityMode:Int = 102;   // XESS_BRIDGE_QUALITY_BALANCED (fixed)
	var _initialized:Bool = false;
	var _backend:Int = 0;         // 0=D3D12, 1=Vulkan, 2=D3D11

	/** When false (default for FNF's LDR rendering), sets LDR_INPUT_COLOR init flag. */
	public var isHDR:Bool = false;

	public function new() {}

	// ================================================================
	// IUpscaler
	// ================================================================

	public function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool
	{
		#if !windows
		trace('XeSS: only supported on Windows');
		return false;
		#end

		if (BgfxAPI.xessIsSupported() != 0)
		{
			trace('XeSS: not supported on this system');
			return false;
		}

		_inputW = inputW; _inputH = inputH;
		_outputW = outputW; _outputH = outputH;

		// Route to correct backend based on active bgfx API
		var apiName = RenderDevice.activeAPI;
		trace('XeSS: active API is $apiName');

		var ok = switch(apiName)
		{
			case 'Vulkan':
				_backend = 1;
				initVK();
			case 'DirectX 12':
				_backend = 0;
				initD3D12();
			case 'DirectX 11':
				_backend = 2;
				initD3D11();
			default:
				trace('XeSS: Unsupported graphics API ($apiName). Intel only supports D3D12/Vulkan.');
				false;
		}

		if (!ok)
		{
			trace('XeSS: init failed');
			return false;
		}

		_initialized = true;
		trace('XeSS: ready (${inputW}x${inputH} -> ${outputW}x${outputH})');
		return true;
	}

	public function initVK():Bool
	{
		#if !windows
		return false;
		#end

		var inst = BgfxAPI.hxGetVkInstance();
		var phys = BgfxAPI.hxGetVkPhysDevice();
		var dev = BgfxAPI.hxGetVkDevice();
		if (inst == null || dev == null)
		{
			trace('XeSS: Vulkan device not available from bgfx');
			return false;
		}

		// Query required Vulkan extensions before creating XeSS context
		var vkExtCount:cpp.UInt32 = 0;
		var vkExtCountPtr:cpp.RawPointer<cpp.UInt32> = untyped __cpp__('&{0}', vkExtCount);
		var instResult = BgfxAPI.xessGetVkInstanceExtensions(vkExtCountPtr, null, null);
		if (instResult == 0 && vkExtCount > 0)
		{
			trace('XeSS: VK instance requires $vkExtCount extensions');
		}

		var devExtCount:cpp.UInt32 = 0;
		var devExtCountPtr:cpp.RawPointer<cpp.UInt32> = untyped __cpp__('&{0}', devExtCount);
		var devResult = BgfxAPI.xessGetVkDeviceExtensions(inst, phys, devExtCountPtr, null);
		if (devResult == 0 && devExtCount > 0)
		{
			trace('XeSS: VK device requires $devExtCount extensions');
		}

		var initFlags:Int = isHDR ? 0 : (1 << 6); // XESS_INIT_FLAG_LDR_INPUT_COLOR

		var ctxPtr:cpp.RawPointer<cpp.RawPointer<cpp.Void>> = untyped __cpp__('&{0}', _context);
		var result = BgfxAPI.xessInitVK(ctxPtr, inst, phys, dev,
			_outputW, _outputH, _qualityMode, initFlags);
		if (result != 0)
		{
			trace('XeSS: Vulkan init failed (result=$result)');
			return false;
		}

		trace('XeSS: Vulkan initialized (LDR=${!isHDR}, flags=$initFlags)');
		return true;
	}

	public function initD3D12():Bool
	{
		#if !windows
		return false;
		#end

		var device = BgfxAPI.hxGetD3D12Device();
		if (device == null)
		{
			trace('XeSS: D3D12 device not available from bgfx');
			return false;
		}

		var initFlags:Int = isHDR ? 0 : (1 << 6); // XESS_INIT_FLAG_LDR_INPUT_COLOR

		var ctxPtr:cpp.RawPointer<cpp.RawPointer<cpp.Void>> = untyped __cpp__('&{0}', _context);
		var result = BgfxAPI.xessInitD3D12(ctxPtr, device,
			_outputW, _outputH, _qualityMode, initFlags);
		if (result != 0)
		{
			trace('XeSS: D3D12 init failed (result=$result)');
			return false;
		}

		trace('XeSS: D3D12 initialized (LDR=${!isHDR}, flags=$initFlags)');
		return true;
	}

	public function initD3D11():Bool
	{
		#if !windows
		return false;
		#end

		var device = BgfxAPI.hxGetD3D11Device();
		if (device == null)
		{
			trace('XeSS: D3D11 device not available (Intel Arc only)');
			return false;
		}

		var initFlags:Int = isHDR ? 0 : (1 << 6);
		var ctxPtr:cpp.RawPointer<cpp.RawPointer<cpp.Void>> = untyped __cpp__('&{0}', _context);
		var result = BgfxAPI.xessInitD3D11(ctxPtr, device,
			_outputW, _outputH, _qualityMode, initFlags);
		if (result != 0)
		{
			trace('XeSS: D3D11 init failed (result=$result)');
			return false;
		}

		trace('XeSS: D3D11 initialized (Intel Arc only, LDR=${!isHDR})');
		return true;
	}

	public function apply(inputTextureHandle:Int, outputFBHandle:Int):Void
	{
		#if !windows
		return;
		#end

		if (!_initialized) return;

		// Get native textures from bgfx handles (works for both D3D12 and Vulkan)
		var colorIn = BgfxAPI.hxGetNativeTexture(inputTextureHandle);
		var colorOut = outputFBHandle != 0 ? BgfxAPI.hxGetNativeFBTexture(outputFBHandle) : null;

		if (colorIn == null)
		{
			return;
		}

		switch(_backend)
		{
			case 0: // D3D12
				BgfxAPI.xessExecuteD3D12(_context, null,
					colorIn, null, null, colorOut,
					0.0, 0.0, _inputW, _inputH, 0);
			case 1: // Vulkan
				BgfxAPI.xessExecute(_context, null,
					colorIn, null, null, colorOut,
					0.0, 0.0, _inputW, _inputH, 0);
			case 2: // D3D11
				var d3d11Ctx = BgfxAPI.hxGetD3D11ImmediateContext();
				BgfxAPI.xessExecuteD3D11(_context, d3d11Ctx,
					colorIn, null, null, colorOut,
					0.0, 0.0, _inputW, _inputH, 0);
		}
	}

	public function dispose():Void
	{
		BgfxAPI.xessDestroyContext(_context);
		_initialized = false;
	}

	public function getName():String { return 'XeSS'; }

	public function setJitterOffset(x:Float, y:Float):Void {}
	public function setFrameTimeDelta(dt:Float):Void {}
}
