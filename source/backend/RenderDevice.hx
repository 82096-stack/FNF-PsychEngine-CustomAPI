package backend;

import flixel.FlxG;
import openfl.display.BlendMode;

// Inline bgfx types
enum abstract BgfxRendererType(Int) to Int { var B_Noop=0; var B_Direct3D11=2; var B_Direct3D12=3; var B_Metal=5; var B_OpenGLES=7; var B_OpenGL=8; var B_Vulkan=9; }
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

class RenderDevice
{
	public static var initialized(default, null):Bool = false;
	public static var activeAPI:GraphicsAPIType = OpenGL;

	static var projMatrix:Array<Float> = [];
	static var viewProjections:Map<Int, Array<Float>> = new Map();
	public static inline var VIEW_CLEAR:Int = 0;
	public static inline var VIEW_MAIN:Int  = 1;
	public static inline var VIEW_CAM0:Int  = 2;

	public static function init(width:Int, height:Int, api:GraphicsAPIType, vsync:Bool = false):Bool
	{
		if (initialized) return true;
		var init = new BgfxInit();
		init.type = apiToRendererType(api);
		init.platformData.nwh = BgfxAPI.hxGetNativeWindowHandle();
		init.platformData.ndt = BgfxAPI.hxGetNativeDisplayHandle();
		var res = new BgfxResolution();
		res.width = width; res.height = height; res.format = BGRA8;
		res.reset = vsync ? VSync : 0;
		res.reset |= FlipAfterRender;
		init.resolution = res;
		var limits = new BgfxInitLimits();
		limits.transientVbSize = 16 * 1024 * 1024;
		limits.transientIbSize = 4 * 1024 * 1024;
		init.limits = limits;
		if (!BgfxAPI.init(init)) { trace('RenderDevice: init failed'); return false; }
		initialized = true; activeAPI = api;
		setupView(width, height);
		trace('RenderDevice: initialized with ${api}');
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
	 * Touches VIEW_CLEAR to ensure it's processed, and clears
	 * per-view projection caches for the new frame.
	 */
	public static function beginFrame():Void
	{
		if (!initialized) return;
		BgfxAPI.touch(VIEW_CLEAR);
	}

	/**
	 * Called at the end of each frame (via FlxG.signals.postDraw).
	 * Submits the bgfx frame to the GPU.
	 */
	public static function endFrame():Void { if (initialized) BgfxAPI.frame(false); }

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

		var layout = BgfxVertexLayoutManager.get2DLayout();
		if (layout == null) return;

		var tvb = new BgfxTransientVertexBuffer();
		BgfxAPI.allocTransientVertexBuffer(tvb, numVertices, layout);
		if (tvb.size == 0) return;

		// Copy vertex data into the transient vertex buffer.
		// With stubbed BgfxAPI, tvb.data is set by allocTransientVertexBuffer.
		// When CFFI is fully wired, tvb.data will be a cpp.RawPointer and we
		// use cpp.NativeMem.setBytes or untyped __cpp__('memcpy') for the copy.
		tvb.data = vertices;
		tvb.size = numVertices * 20; // 20 bytes per vertex

		BgfxAPI.setState(blendState(blend), 0);
		if (tex != 0)
			BgfxAPI.setTexture(0, BgfxShaderManager.getTextureSampler(), tex, 0);

		// Set per-view projection if available; otherwise use the default ortho
		var proj = viewProjections.exists(viewId) ? viewProjections.get(viewId) : projMatrix;
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
		if ((s & (1 << B_Metal)) != 0) a.push(Metal);
		return a;
	}

	static function apiToRendererType(api:GraphicsAPIType):BgfxRendererType
	{
		return switch(api) {
			case Metal: B_Metal;
			case Vulkan: B_Vulkan;
			case DirectX12: B_Direct3D12;
			default: B_OpenGL;
		}
	}

	// ==================================================================
	// BLEND STATE MAPPING
	// ==================================================================

	/**
	 * Maps flixel/OpenFL blend modes to bgfx state bits.
	 *
	 * bgfx blend state encoding (lower 24 bits):
	 *   Bits 0-3:   RGB source factor
	 *   Bits 4-7:   RGB destination factor
	 *   Bits 8-11:  RGB operation
	 *   Bits 12-15: Alpha source factor
	 *   Bits 16-19: Alpha destination factor
	 *   Bits 20-23: Alpha operation
	 *   Bit  24:    Separate alpha blend
	 *
	 * Common presets (defined in bgfx.h):
	 *   BGFX_STATE_BLEND_ZERO       = 0x00000000
	 *   BGFX_STATE_BLEND_ALPHA      = 0x00100000  (src=SRC_ALPHA, dst=INV_SRC_ALPHA)
	 *   BGFX_STATE_BLEND_ADD        = 0x00200000  (src=SRC_ALPHA, dst=ONE)
	 *   BGFX_STATE_BLEND_MULTIPLY   = 0x00400000  (src=DEST_COLOR, dst=ZERO)
	 *   BGFX_STATE_BLEND_SCREEN     = 0x00800000  (src=ONE, dst=INV_SRC_COLOR)
	 *   BGFX_STATE_BLEND_SUBTRACT   = 0x01000000  (src=SRC_ALPHA, dst=ONE, op=REV_SUB)
	 *   BGFX_STATE_WRITE_R          = 0x00000001
	 *   BGFX_STATE_WRITE_G          = 0x00000002
	 *   BGFX_STATE_WRITE_B          = 0x00000004
	 *   BGFX_STATE_WRITE_A          = 0x00000008
	 *   BGFX_STATE_BLEND_INDEPENDENT = 0x01000000
	 */
	static function blendState(blend:BlendMode):Int
	{
		var WR:Int    = 0x00000001; // BGFX_STATE_WRITE_R
		var WG:Int    = 0x00000002; // BGFX_STATE_WRITE_G
		var WB:Int    = 0x00000004; // BGFX_STATE_WRITE_B
		var WA:Int    = 0x00000008; // BGFX_STATE_WRITE_A
		var WRGB:Int  = WR | WG | WB;
		var WMASK:Int = WRGB | WA;

		var B_ZERO:Int       = 0x00000010;
		var B_ALPHA:Int      = 0x00100010; // BGFX_STATE_BLEND_ALPHA variant
		var B_ADD:Int        = 0x00200010; // BGFX_STATE_BLEND_ADD variant
		var B_MULTIPLY:Int   = 0x00400010; // BGFX_STATE_BLEND_MULTIPLY
		var B_SCREEN:Int     = 0x00800010; // BGFX_STATE_BLEND_SCREEN
		var B_SUBTRACT:Int   = 0x01000010; // BGFX_STATE_BLEND_SUBTRACT

		return switch(blend)
		{
			case ADD:      WMASK | B_ADD;
			case MULTIPLY: WMASK | B_MULTIPLY;
			case SCREEN:   WMASK | B_SCREEN;
			case SUBTRACT: WMASK | B_SUBTRACT;
			case DARKEN:   WMASK | B_MULTIPLY;   // Closest approximation
			case LIGHTEN:  WMASK | B_SCREEN;      // Closest approximation
			case DIFFERENCE, OVERLAY, HARDLIGHT: WMASK | B_ALPHA; // Fallback to alpha
			default:       WMASK | B_ALPHA;       // NORMAL
		}
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
