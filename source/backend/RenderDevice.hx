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
		BgfxAPI.shutdown();
		initialized = false;
	}

	public static function fullShutdown():Void
	{
		if (!initialized) return;
		BgfxTextureManager.disposeAll();
		BgfxShaderManager.disposeAll();
		BgfxAPI.shutdown();
		initialized = false;
	}

	public static function beginFrame():Void {}
	public static function endFrame():Void { BgfxAPI.frame(false); }

	public static function switchAPI(newAPI:GraphicsAPIType, width:Int, height:Int):Bool
	{
		if (newAPI == activeAPI) return true;
		BgfxShaderManager.invalidateAll();
		BgfxTextureManager.invalidateAll();
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
		ortho(projMatrix, 0, width, height, 0, -1, 1);
		BgfxAPI.reset(width, height, FlipAfterRender, BGRA8);
		BgfxAPI.setViewRect(VIEW_MAIN, 0, 0, width, height);
	}

	public static function submitQuads(viewId:Int, tex:Int,
		vertices:haxe.io.Bytes, numVertices:Int, prog:Int, blend:BlendMode):Void
	{
		if (!initialized || numVertices == 0) return;
		var layout = BgfxVertexLayoutManager.get2DLayout();
		if (layout == null) return;
		var tvb = new BgfxTransientVertexBuffer();
		BgfxAPI.allocTransientVertexBuffer(tvb, numVertices, layout);
		if (tvb.size == 0) return;
		// TODO: memcpy vertex data into transient buffer when bgfx CFFI is wired
		BgfxAPI.setState(blendState(blend), 0);
		if (tex != 0) BgfxAPI.setTexture(0, BgfxShaderManager.getTextureSampler(), tex, 0);
		BgfxAPI.touch(viewId);
		BgfxAPI.submit(viewId, prog, 0, 0);
	}

	public static function getRendererName():String { return if (!initialized) 'Not initialized' else '$activeAPI'; }

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

	static function blendState(blend:BlendMode):Int
	{
		var WR:Int = 1, WA:Int = 2, BA:Int = 0x00100000, BAdd:Int = 0x00200000;
		return switch(blend) { case ADD: WR | WA | BAdd; default: WR | WA | BA; }
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
