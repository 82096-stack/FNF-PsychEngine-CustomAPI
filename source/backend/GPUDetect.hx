package backend;

/**
 * GPUDetect — GPU Vendor and Architecture Detection
 *
 * Detects the GPU vendor and architecture for upscaler compatibility validation.
 *
 * Detection strategy (pragmatic, Haxe-first):
 *   - Platform macros: `#if mac` implies Apple Silicon or Intel Mac with Metal support
 *   - bgfx renderer type: Metal → Apple, DirectX → Windows GPU, Vulkan → varies
 *   - C bridge hooks for precise vendor/architecture queries (stub fallback to Unknown)
 *
 * Stub behavior: When the C bridge is unavailable, detectVendor() returns
 *   - Apple on macOS (safe — MetalFX works on both Apple Silicon and Intel Mac)
 *   - Unknown on Windows/Linux (conservative — DLSS/NIS blocked, FSR/XeSS allowed)
 */
class GPUDetect
{
	// ── GPU Vendor Enum ──────────────────────────────────────────────

	public static inline var VENDOR_UNKNOWN:String = "Unknown";
	public static inline var VENDOR_NVIDIA:String  = "NVIDIA";
	public static inline var VENDOR_AMD:String     = "AMD";
	public static inline var VENDOR_INTEL:String   = "Intel";
	public static inline var VENDOR_APPLE:String   = "Apple";

	// ── GPU Architecture Enum ────────────────────────────────────────

	public static inline var ARCH_UNKNOWN:String      = "Unknown";
	// NVIDIA
	public static inline var ARCH_MAXWELL:String      = "Maxwell";
	public static inline var ARCH_PASCAL:String        = "Pascal";
	public static inline var ARCH_TURING:String        = "Turing";
	public static inline var ARCH_AMPERE:String        = "Ampere";
	public static inline var ARCH_ADA_LOVELACE:String  = "AdaLovelace";
	public static inline var ARCH_BLACKWELL:String     = "Blackwell";
	// AMD
	public static inline var ARCH_GCN:String           = "GCN";
	public static inline var ARCH_RDNA1:String         = "RDNA1";
	public static inline var ARCH_RDNA2:String         = "RDNA2";
	public static inline var ARCH_RDNA3:String         = "RDNA3";
	public static inline var ARCH_RDNA4:String         = "RDNA4";
	// Apple
	public static inline var ARCH_M1:String            = "M1";
	public static inline var ARCH_M2:String            = "M2";
	public static inline var ARCH_M3:String            = "M3";
	public static inline var ARCH_M4:String            = "M4";

	// ── Cached results ───────────────────────────────────────────────

	static var _vendorCached:String = null;
	static var _archCached:String = null;

	// ── Vendor Detection ─────────────────────────────────────────────

	/**
	 * Detect the primary GPU vendor.
	 *
	 * macOS: Returns Apple (MetalFX-compatible on both Apple Silicon and Intel Mac).
	 * Windows/Linux: Tries C bridge `hxGetGPUVendor()`, falls back to bgfx renderer
	 * type heuristic, then Unknown.
	 */
	public static function detectVendor():String
	{
		if (_vendorCached != null)
			return _vendorCached;

		#if mac
		// macOS: Metal is the primary rendering API.
		// MetalFX upscaling works on both Apple Silicon (M1+) and Intel Mac (macOS 13+).
		_vendorCached = VENDOR_APPLE;
		#elseif windows
		// Try C bridge: hxGetGPUVendor() returns vendor index or -1 if unavailable
		if (BgfxAPI.nativeAvailable)
		{
			var vendorId = tryGetCGPUVendor();
			if (vendorId >= 0)
			{
				_vendorCached = vendorFromId(vendorId);
				return _vendorCached;
			}
		}
		// Heuristic: check active bgfx renderer
		_vendorCached = guessVendorFromRenderer();
		#elseif linux
		if (BgfxAPI.nativeAvailable)
		{
			var vendorId = tryGetCGPUVendor();
			if (vendorId >= 0)
			{
				_vendorCached = vendorFromId(vendorId);
				return _vendorCached;
			}
		}
		_vendorCached = guessVendorFromRenderer();
		#else
		_vendorCached = VENDOR_UNKNOWN;
		#end

		return _vendorCached;
	}

	// ── Architecture Detection ───────────────────────────────────────

	/**
	 * Detect the GPU architecture generation.
	 *
	 * macOS: Uses hxGetAppleSiliconGeneration() via C bridge to determine M1/M2/M3/M4.
	 *        Falls back to M1 on macOS (conservative minimum for MetalFX).
	 * Windows/Linux: Uses C bridge, falls back to Unknown.
	 */
	public static function detectArchitecture():String
	{
		if (_archCached != null)
			return _archCached;

		#if mac
		// Try C bridge for precise Apple Silicon generation
		if (BgfxAPI.nativeAvailable)
		{
			var gen = tryGetAppleSiliconGen();
			if (gen > 0)
			{
				_archCached = appleGenToArch(gen);
				return _archCached;
			}
		}
		// Fallback: assume M1 minimum on macOS (all Apple Silicon Macs support MetalFX)
		_archCached = ARCH_M1;
		#elseif (windows || linux)
		if (BgfxAPI.nativeAvailable)
		{
			var archId = tryGetCGPUArchitecture();
			if (archId >= 0)
			{
				_archCached = archFromId(detectVendor(), archId);
				return _archCached;
			}
		}
		_archCached = ARCH_UNKNOWN;
		#else
		_archCached = ARCH_UNKNOWN;
		#end

		return _archCached;
	}

	// ── Upscaler Support Checks ──────────────────────────────────────

	/**
	 * DLSS requires NVIDIA RTX 20-series (Turing) or newer.
	 * GTX 16-series (Turing without Tensor Cores) is NOT supported.
	 *
	 * Since our architecture enum doesn't distinguish GTX Turing from RTX Turing
	 * without precise model detection, we accept Turing+ as DLSS-capable.
	 * The practical heuristic: all Turing NVIDIA GPUs with Tensor Cores are RTX-branded;
	 * GTX 16-series without Tensor Cores would need native C bridge detection to exclude.
	 */
	public static function supportsDLSS():Bool
	{
		#if !windows
		return false;
		#end

		var vendor = detectVendor();
		// On Windows, if bridge is active, trust the bridge's vendor detection
		// If Unknown (bridge not active), optimistically allow — init will fail if unsupported
		if (vendor == VENDOR_UNKNOWN && BgfxAPI.nativeAvailable) return true;
		if (vendor != VENDOR_NVIDIA && vendor != VENDOR_UNKNOWN) return false;

		var arch = detectArchitecture();
		if (arch == ARCH_UNKNOWN) return true; // Allow — bridge will validate at init

		return isArchAtLeastNVIDIARTX(arch);
	}

	/** FSR 1/2/3 are shader-based, works on virtually all modern GPUs. */
	public static function supportsFSR():Bool
	{
		return true;
	}

	/**
	 * FSR 4 requires AMD RDNA 4 (RX 9000 series) with 2nd-gen AI accelerators
	 * and FP8 WMMA instruction support. Exclusive to RDNA 4.
	 */
	public static function supportsFSR4():Bool
	{
		var vendor = detectVendor();
		if (vendor != VENDOR_AMD) return false;

		var arch = detectArchitecture();
		return arch == ARCH_RDNA4;
	}

	/**
	 * XeSS works cross-vendor via DP4a fallback path.
	 * XMX path (best quality) is Intel Arc only.
	 * DP4a works on: NVIDIA GTX 10+, AMD RX 5000+, Intel iGPUs with SM 6.4.
	 */
	public static function supportsXeSS():Bool
	{
		#if windows
		return true; // XeSS works on all modern GPUs via DP4a
		#else
		return false;
		#end
	}

	/**
	 * MetalFX works on all Apple Silicon (M1+) AND Intel Mac (macOS 13+).
	 * Spatial and Temporal upscaling both supported on both platforms.
	 * Metal 4 advanced features (frame interpolation, AI denoising) are M3+ only,
	 * but the basic upscaling is universal on Apple platforms.
	 */
	public static function supportsMetalFX():Bool
	{
		return detectVendor() == VENDOR_APPLE;
	}

	/**
	 * NIS (NVIDIA Image Scaling) works on NVIDIA Maxwell (GTX 900) and newer.
	 * Spatial upscaler with adaptive sharpening, no AI/ML hardware needed.
	 */
	public static function supportsNIS():Bool
	{
		var vendor = detectVendor();
		if (vendor != VENDOR_NVIDIA) return false;

		var arch = detectArchitecture();
		if (arch == ARCH_UNKNOWN) return false;

		return isArchAtLeastNVIDIAMaxwell(arch);
	}

	/**
	 * Check if a specific upscaler is supported on this GPU.
	 */
	public static function supportsUpscaler(name:String):Bool
	{
		return switch(name)
		{
			case 'Directly Enlarge': true;
			case 'DLSS':             supportsDLSS();
			case 'FSR':              supportsFSR();
			case 'XeSS':             supportsXeSS();
			case 'MetalFX':          supportsMetalFX();
			case 'NIS':              supportsNIS();
			default:                 false;
		}
	}

	/**
	 * Check if a specific upscaler preset is available on this GPU.
	 * Currently only FSR 4 has a GPU-gated preset.
	 */
	public static function supportsPreset(upscaler:String, preset:String):Bool
	{
		if (upscaler == 'FSR' && preset == 'FSR 4')
			return supportsFSR4();
		return true; // All other presets are always available if upscaler is supported
	}

	// ── Private Helpers ──────────────────────────────────────────────

	static function vendorFromId(id:Int):String
	{
		return switch(id)
		{
			case 1: VENDOR_NVIDIA;
			case 2: VENDOR_AMD;
			case 3: VENDOR_INTEL;
			case 4: VENDOR_APPLE;
			default: VENDOR_UNKNOWN;
		}
	}

	static function guessVendorFromRenderer():String
	{
		if (!RenderDevice.initialized)
			return VENDOR_UNKNOWN;

		var renderer = RenderDevice.activeAPI;
		return switch(renderer)
		{
			case 'Metal': VENDOR_APPLE;
			default: VENDOR_UNKNOWN;
		}
	}

	static function isArchAtLeastNVIDIARTX(arch:String):Bool
	{
		return switch(arch)
		{
			case ARCH_TURING, ARCH_AMPERE, ARCH_ADA_LOVELACE, ARCH_BLACKWELL: true;
			default: false;
		}
	}

	static function isArchAtLeastNVIDIAMaxwell(arch:String):Bool
	{
		return switch(arch)
		{
			case ARCH_MAXWELL, ARCH_PASCAL, ARCH_TURING, ARCH_AMPERE,
			     ARCH_ADA_LOVELACE, ARCH_BLACKWELL: true;
			default: false;
		}
	}

	static function appleGenToArch(gen:Int):String
	{
		return switch(gen)
		{
			case 1: ARCH_M1;
			case 2: ARCH_M2;
			case 3: ARCH_M3;
			case 4: ARCH_M4;
			default: ARCH_M1; // fallback
		}
	}

	static function archFromId(vendor:String, id:Int):String
	{
		if (vendor == VENDOR_NVIDIA)
		{
			return switch(id)
			{
				case 0: ARCH_MAXWELL;
				case 1: ARCH_PASCAL;
				case 2: ARCH_TURING;
				case 3: ARCH_AMPERE;
				case 4: ARCH_ADA_LOVELACE;
				case 5: ARCH_BLACKWELL;
				default: ARCH_UNKNOWN;
			}
		}
		else if (vendor == VENDOR_AMD)
		{
			return switch(id)
			{
				case 0: ARCH_GCN;
				case 1: ARCH_RDNA1;
				case 2: ARCH_RDNA2;
				case 3: ARCH_RDNA3;
				case 4: ARCH_RDNA4;
				default: ARCH_UNKNOWN;
			}
		}
		return ARCH_UNKNOWN;
	}

	// ── C Bridge Stubs (overridden by native library when available) ─

	/**
	 * Try to query GPU vendor via C bridge.
	 * Returns vendor index (1=NVIDIA, 2=AMD, 3=Intel, 4=Apple) or -1 if unavailable.
	 */
	static function tryGetCGPUVendor():Int
	{
		return BgfxAPI.hxGetGpuVendor();
	}

	static function tryGetCGPUArchitecture():Int
	{
		return BgfxAPI.hxGetGpuArchitecture();
	}

	static function tryGetAppleSiliconGen():Int
	{
		return BgfxAPI.hxGetAppleSiliconGeneration();
	}
}
