package backend;

import flixel.FlxG;
import openfl.display.BlendMode;

// Inline bgfx types
enum abstract BgfxRendererType(Int) to Int { var B_Noop=0; var B_Direct3D9=1; var B_Direct3D11=2; var B_Direct3D12=3; var B_Metal=5; var B_OpenGLES=7; var B_OpenGL=8; var B_Vulkan=9; }
enum abstract BgfxTextureFormat(Int) to Int { var Unknown=34; var BGRA8=66; var RGBA8=67; }
enum abstract BgfxResetFlags(Int) to Int { var None=0; var VSync=0x0080; var FlipAfterRender=0x0800; var HiDPI=0x4000; }
enum abstract BgfxClearFlags(Int) to Int { var None5=0; var Color0=1; var Depth=2; var Stencil=4; }
enum abstract BgfxAttrib(Int) to Int { var PositionC=0; var TexCoord0C=10; var Color0C=4; }
enum abstract BgfxAttribType(Int) to Int { var Uint8=0; var Float0=3; }

class BgfxInit {
	public var type:BgfxRendererType = B_OpenGL;
	public var platformData:Dynamic=null; public var resolution:Dynamic=null; public var limits:Dynamic=null;
	public function new() { platformData = new BgfxPlatformData(); }
}
class BgfxPlatformData {
	public var ndt:Dynamic; public var nwh:Dynamic; public var context:Dynamic; public var backBuffer:Dynamic; public var backBufferDS:Dynamic;
	public function new() {}
}
class BgfxResolution {
	public var format:BgfxTextureFormat = BGRA8; public var width:Int=1280; public var height:Int=720;
	public var reset:Int=0; public var numBackBuffers:Int=2; public var maxFrameLatency:Int=1;
	public function new() {}
}
class BgfxInitLimits {
	public var maxEncoders:Int=1; public var transientVbSize:Int=16777216; public var transientIbSize:Int=4194304;
	public function new() {}
}
class BgfxVertexLayout { public var hash:Int=0; public var stride:Int=0; public function new() {} }
class BgfxTransientVertexBuffer {
	public var data:Dynamic; public var size:Int=0; public var startVertex:Int=0; public var stride:Int=0;
	public function new() {}
}

/**
 * Result of a single-API GPU benchmark run.
 *
 * Captures both throughput (sustainedFPS) and frame time consistency
 * (avgFrameMs, maxFrameMs, frameTimeStdDev) so the caller can score
 * APIs on stability, not just raw speed.
 */
class BenchmarkResult
{
	/** Total frames completed divided by duration (frames/sec). */
	public var sustainedFPS:Float = 0;
	/** Mean frame time in milliseconds (lower is faster). */
	public var avgFrameMs:Float = 0;
	/** Worst single frame in milliseconds (spike / jitter indicator). */
	public var maxFrameMs:Float = 0;
	/** Standard deviation of frame times in ms (lower = more stable). */
	public var frameTimeStdDev:Float = 0;
	public function new() {}
}

class RenderDevice
{
	public static var initialized(default, null):Bool = false;
	public static var activeAPI:GraphicsAPIType = OpenGL;

	static var projMatrix:Array<Float> = [];
	static var viewProjections:Map<Int, Array<Float>> = new Map();
	public static inline var VIEW_CLEAR:Int = 0;
	public static inline var VIEW_MAIN:Int  = 1;
	public static inline var VIEW_CAM0:Int  = 2;

	// Cached vertex layout (avoids null check per draw call)
	static var _cachedLayout:BgfxVertexLayout = null;
	// Reusable transient vertex buffer (avoids allocation per draw call)
	static var _reusableTVB:BgfxTransientVertexBuffer = null;

	public static function init(width:Int, height:Int, api:GraphicsAPIType, vsync:Bool = false):Bool
	{
		if (initialized) return true;
		BgfxVertexLayoutManager.invalidate();
		_cachedLayout = null;
		var init = new BgfxInit();
		init.type = apiToRendererType(api);
		init.platformData.nwh = BgfxAPI.hxGetNativeWindowHandle();
		init.platformData.ndt = BgfxAPI.hxGetNativeDisplayHandle();
		var res = new BgfxResolution();
		res.width = width; res.height = height; res.format = BGRA8;
		res.reset = vsync ? VSync : 0;
		res.reset |= FlipAfterRender;
		res.numBackBuffers = 2;
		// Allow CPU to pipeline up to 2 frames ahead of GPU (Metal / Vulkan / D3D12)
		res.maxFrameLatency = 2;
		init.resolution = res;
		var limits = new BgfxInitLimits();
		limits.transientVbSize = 16 * 1024 * 1024;
		limits.transientIbSize = 4 * 1024 * 1024;
		// Enable multi-threaded command recording when bgfx supports it
		limits.maxEncoders = 2;
		init.limits = limits;
		if (!BgfxAPI.init(init)) { trace('RenderDevice: init failed'); return false; }
		initialized = true; activeAPI = api;
		setupView(width, height);
		trace('RenderDevice: initialized with ${api}');
		FramePacer.setBGFXMode(true);
		return true;
	}

	public static function shutdown():Void
	{
		if (!initialized) return;
		BgfxTextureManager.invalidateAll();
		BgfxShaderManager.invalidateAll();
		viewProjections.clear();
		BgfxAPI.shutdown();
		initialized = false;
	}

	public static function fullShutdown():Void
	{
		if (!initialized) return;
		BgfxTextureManager.disposeAll();
		BgfxShaderManager.disposeAll();
		viewProjections.clear();
		BgfxAPI.shutdown();
		initialized = false;
	}

	/**
	 * Called at the start of each frame (via FlxG.signals.preDraw).
	 * Touches VIEW_CLEAR, resets the draw batcher, and records frame timing.
	 */
	public static function beginFrame():Void
	{
		if (!initialized) return;
		FramePacer.beginFrame();
		BgfxDrawBatcher.beginFrame();
		BgfxAPI.touch(VIEW_CLEAR);
	}

	/**
	 * Called at the end of each frame (via FlxG.signals.postDraw).
	 * Flushes all batched draws and submits the bgfx frame to the GPU.
	 */
	public static function endFrame():Void
	{
		if (!initialized) return;
		BgfxDrawBatcher.flushAll();
		BgfxAPI.frame(false);
		FramePacer.endFrame();
	}

	public static function switchAPI(newAPI:GraphicsAPIType, width:Int, height:Int):Bool
	{
		if (newAPI == activeAPI) return true;
		BgfxShaderManager.invalidateAll();
		BgfxTextureManager.invalidateAll();
		viewProjections.clear();
		BgfxAPI.shutdown();
		initialized = false;
		activeAPI = newAPI;
		BgfxVertexLayoutManager.invalidate();
		if (!init(width, height, newAPI))
		{
			if (newAPI != OpenGL && init(width, height, OpenGL))
			{
				BgfxTextureManager.restoreAll();
				return true;
			}
			return false;
		}
		BgfxTextureManager.restoreAll();
		return true;
	}

	/**
	 * Benchmark a single graphics API by initializing bgfx and measuring
	 * frame time consistency over a fixed time window.
	 *
	 * Instead of counting how fast N empty frames complete (peak throughput),
	 * this method records per-frame timestamps over `durationSec` seconds
	 * and returns both sustained FPS and frame time distribution — so the
	 * caller can score APIs on stability, not just raw speed.
	 *
	 * Side effects:
	 *   - Calls shutdown on the current bgfx context (if any).
	 *   - Calls init with `api` (VSync off). If init fails, returns null.
	 *   - Textures and shaders are invalidated; caller is responsible for
	 *     calling BgfxTextureManager.restoreAll() after settling on a final API.
	 *
	 * @param api          The API to benchmark. Must not be `Auto`.
	 * @param width        Window width for bgfx init.
	 * @param height       Window height for bgfx init.
	 * @param durationSec  Time window in seconds (default 3.0).
	 * @return BenchmarkResult with FPS + frame time stats, or null if init failed.
	 */
	public static function benchmarkAPI(api:GraphicsAPIType, width:Int, height:Int,
		durationSec:Float = 3.0):BenchmarkResult
	{
		// 1. Tear down current bgfx context (invalidate, don't dispose)
		BgfxShaderManager.invalidateAll();
		BgfxTextureManager.invalidateAll();
		viewProjections.clear();
		BgfxAPI.shutdown();
		initialized = false;
		BgfxVertexLayoutManager.invalidate();

		// 2. Try to initialize bgfx with the target API (VSync off)
		if (!init(width, height, api, false))
		{
			trace('RenderDevice.benchmarkAPI: ${api} init failed');
			return null;
		}

		// 3. Warm-up: let GPU pipeline / driver / PSO creation stabilize
		for (i in 0...10)
		{
			BgfxAPI.touch(VIEW_CLEAR);
			BgfxAPI.frame(false);
		}

		// 4. Timed benchmark — record per-frame timestamps
		var timestamps:Array<Float> = [];
		var start = haxe.Timer.stamp();
		var deadline = start + durationSec;
		var now = start;
		while (now < deadline)
		{
			BgfxAPI.touch(VIEW_CLEAR);
			BgfxAPI.frame(false);
			now = haxe.Timer.stamp();
			timestamps.push(now);
		}

		// 5. Compute statistics
		var frameCount = timestamps.length;
		if (frameCount < 2)
		{
			trace('RenderDevice.benchmarkAPI: too few frames (${frameCount}), returning null');
			return null;
		}

		var elapsed = now - start;
		var frameTimes:Array<Float> = [];
		var sum:Float = 0;
		var maxDt:Float = 0;
		var prev = start;
		for (t in timestamps)
		{
			var dt = (t - prev) * 1000.0; // ms
			frameTimes.push(dt);
			sum += dt;
			if (dt > maxDt) maxDt = dt;
			prev = t;
		}

		var avg = sum / frameCount;
		var variance:Float = 0;
		for (dt in frameTimes)
		{
			var diff = dt - avg;
			variance += diff * diff;
		}
		variance /= frameCount;
		var stdDev = Math.sqrt(variance);

		var result = new BenchmarkResult();
		result.sustainedFPS = frameCount / elapsed;
		result.avgFrameMs = avg;
		result.maxFrameMs = maxDt;
		result.frameTimeStdDev = stdDev;
		return result;
	}

	/**
	 * Set up the clear view
	/**
	 * Set up the clear view (VIEW_CLEAR, ID 0) and main view (VIEW_MAIN, ID 1).
	 * Individual camera views start from VIEW_CAM0 (ID 2).
	 */
	static function setupView(width:Int, height:Int):Void
	{
		ortho(projMatrix, 0, width, height, 0, -1, 1);
		BgfxAPI.setViewRect(VIEW_CLEAR, 0, 0, width, height);
		BgfxAPI.setViewClear(VIEW_CLEAR, Color0 | Depth, 0x000000ff, 1, 0);
		BgfxAPI.setViewRect(VIEW_MAIN, 0, 0, width, height);
		BgfxAPI.touch(VIEW_MAIN);
	}

	public static function resize(width:Int, height:Int):Void
	{
		if (!initialized) return;
		viewProjections.clear();
		ortho(projMatrix, 0, width, height, 0, -1, 1);
		BgfxAPI.reset(width, height, FlipAfterRender, BGRA8);
		BgfxAPI.setViewRect(VIEW_MAIN, 0, 0, width, height);
	}

	// ==================================================================
	// VIEW CLEAR SETUP
	// ==================================================================

	/**
	 * Set the clear color for a specific camera view.
	 * Called from PsychCamera.render() before submitting draw items.
	 *
	 * @param viewId  bgfx view ID (VIEW_CAM0 + camera ID)
	 * @param color   ARGB packed color (e.g., 0xff000000 for black)
	 */
	public static function setupViewClear(viewId:Int, color:Int):Void
	{
		BgfxAPI.setViewClear(viewId, Color0 | Depth, color, 1, 0);
	}

	// ==================================================================
	// SUBMIT QUADS
	// ==================================================================

	/**
	 * Submit quads for rendering through bgfx.
	 *
	 * Builds a transient vertex buffer, allocates memory via bgfx,
	 * copies the Haxe Bytes vertex data into it, and submits the draw call.
	 *
	 * When bgfx CFFI is fully wired, the `tvb.data` pointer is used for
	 * a direct memcpy from the Haxe vertex bytes to the GPU-visible buffer.
	 * With the current stubs, vertex data is passed through to the stub layer.
	 *
	 * @param viewId      bgfx view ID for this draw call
	 * @param tex          bgfx texture handle (0 = no texture, for solid color)
	 * @param vertices     Pre-built vertex data (20 bytes per vertex)
	 * @param numVertices  Number of vertices (must be multiple of 4 for quads)
	 * @param prog         bgfx program handle
	 * @param blend        OpenFL blend mode (mapped to bgfx state bits)
	 */
	public static function submitQuads(viewId:Int, tex:Int,
		vertices:haxe.io.Bytes, numVertices:Int, prog:Int, blend:BlendMode):Void
	{
		if (!initialized || numVertices == 0) return;

		// Cached vertex layout (built once, reused every draw call)
		if (_cachedLayout == null)
			_cachedLayout = BgfxVertexLayoutManager.get2DLayout();
		if (_cachedLayout == null) return;

		// Reusable transient vertex buffer (pool, avoid per-call allocation)
		if (_reusableTVB == null)
			_reusableTVB = new BgfxTransientVertexBuffer();
		var tvb = _reusableTVB;
		BgfxAPI.allocTransientVertexBuffer(tvb, numVertices, _cachedLayout);
		if (tvb.size == 0) return;

		// Copy vertex data into the transient vertex buffer
		tvb.data = vertices;
		tvb.size = numVertices * 20; // 20 bytes per vertex

		// O(1) map lookup — faster than switch branching for hot path
		BgfxAPI.setState(BLEND_MAP.get(blend), 0);
		if (tex != 0)
			BgfxAPI.setTexture(0, BgfxShaderManager.getTextureSampler(), tex, 0);

		// Single map lookup (get() returns null if missing, avoiding exists()+get()
		var proj = viewProjections.get(viewId);
		if (proj == null) proj = projMatrix;
		BgfxAPI.setViewTransform(viewId, null, proj);

		BgfxAPI.touch(viewId);
		BgfxAPI.submit(viewId, prog, 0, 0);
	}

	// ==================================================================
	// PROJECTION
	// ==================================================================

	/**
	 * Store a camera-specific projection matrix for the given view.
	 * Called from PsychCamera.render() to set up the orthographic projection.
	 */
	public static function setViewProjection(viewId:Int, cam:flixel.FlxCamera, vpW:Int, vpH:Int):Void
	{
		var m:Array<Float> = [];
		// Build orthographic projection accounting for camera scroll
		ortho(m,
			cam.scroll.x * cam.totalScaleX,
			cam.scroll.x * cam.totalScaleX + vpW,
			cam.scroll.y * cam.totalScaleY + vpH,
			cam.scroll.y * cam.totalScaleY,
			-1, 1);
		viewProjections.set(viewId, m);
	}

	// ==================================================================
	// UTILITIES
	// ==================================================================

	public static function getRendererName():String
	{
		return if (!initialized) 'Not initialized' else '$activeAPI';
	}

	public static function getSupportedAPIs():Array<GraphicsAPIType>
	{
		var a:Array<GraphicsAPIType> = [];
		var s = BgfxAPI.hxGetSupportedRenderers();
		if ((s & (1 << B_OpenGL)) != 0) a.push(OpenGL);
		if ((s & (1 << B_Vulkan)) != 0) a.push(Vulkan);
		if ((s & (1 << B_Direct3D12)) != 0) a.push(DirectX12);
		if ((s & (1 << B_Direct3D11)) != 0) a.push(DirectX11);
		if ((s & (1 << B_Direct3D9)) != 0) a.push(DirectX9);
		if ((s & (1 << B_Metal)) != 0) a.push(Metal);
		return a;
	}

	static function apiToRendererType(api:GraphicsAPIType):BgfxRendererType
	{
		return switch(api) {
			case Metal: B_Metal;
			case Vulkan: B_Vulkan;
			case DirectX12: B_Direct3D12;
			case DirectX11: B_Direct3D11;
			case DirectX9: B_Direct3D9;
			default: B_OpenGL;
		}
	}

	// ==================================================================
	// BLEND STATE MAPPING — precomputed O(1) array lookup
	// ==================================================================
	// bgfx blend state encoding:
	//   BGFX_STATE_BLEND_ALPHA      = 0x00100010  (src=SRC_ALPHA, dst=INV_SRC_ALPHA)
	//   BGFX_STATE_BLEND_ADD        = 0x00200010
	//   BGFX_STATE_BLEND_MULTIPLY   = 0x00400010
	//   BGFX_STATE_BLEND_SCREEN     = 0x00800010
	//   BGFX_STATE_BLEND_SUBTRACT   = 0x01000010
	//   BGFX_STATE_WRITE_RGBA       = 0x0000000F
	static final WRMASK:Int   = 0x0000000F; // WRITE_R | WRITE_G | WRITE_B | WRITE_A
	static final B_ALPHA:Int  = 0x00100010;
	static final B_ADD:Int    = 0x00200010;
	static final B_MULTIPLY:Int = 0x00400010;
	static final B_SCREEN:Int = 0x00800010;
	static final B_SUBTRACT:Int = 0x01000010;

	/** Precomputed blend state map — O(1) lookup, avoids switch branching in hot path. */
	static final BLEND_MAP:Map<BlendMode, Int> = [
		ADD       => WRMASK | B_ADD,
		MULTIPLY  => WRMASK | B_MULTIPLY,
		SCREEN    => WRMASK | B_SCREEN,
		SUBTRACT  => WRMASK | B_SUBTRACT,
		DARKEN    => WRMASK | B_MULTIPLY,
		LIGHTEN   => WRMASK | B_SCREEN,
		DIFFERENCE => WRMASK | B_ALPHA,
		OVERLAY   => WRMASK | B_ALPHA,
		HARDLIGHT => WRMASK | B_ALPHA,
		NORMAL    => WRMASK | B_ALPHA,
	];

	/** Fallback blend state for unmapped modes. */
	static inline function blendState(blend:BlendMode):Int
	{
		return BLEND_MAP.exists(blend) ? BLEND_MAP.get(blend) : (WRMASK | B_ALPHA);
	}

	static function ortho(r:Array<Float>, l:Float, rt:Float, b:Float, t:Float, n:Float, f:Float):Void
	{
		while (r.length < 16) r.push(0);
		var rl = rt - l, tb = t - b, fn = f - n;
		r[0] = 2/rl; r[5] = 2/tb; r[10] = -2/fn;
		r[12] = -(rt+l)/rl; r[13] = -(t+b)/tb; r[14] = -(f+n)/fn; r[15] = 1;
	}
}

class BgfxVertexLayoutManager
{
	static var layout2D:BgfxVertexLayout = null;
	public static function get2DLayout():BgfxVertexLayout
	{
		if (layout2D != null) return layout2D;
		layout2D = new BgfxVertexLayout();
		BgfxAPI.vertexLayoutBegin(layout2D, BgfxAPI.getRendererType());
		BgfxAPI.vertexLayoutAdd(layout2D, PositionC, 2, Float0, false, false);
		BgfxAPI.vertexLayoutAdd(layout2D, TexCoord0C, 2, Float0, false, false);
		BgfxAPI.vertexLayoutAdd(layout2D, Color0C, 4, Uint8, true, false);
		BgfxAPI.vertexLayoutEnd(layout2D);
		return layout2D;
	}
	public static function invalidate():Void { layout2D = null; }
}
