package backend;

/**
 * bgfx CFFI bridge — Haxe stubs for the bgfx C rendering library.
 *
 * When the bgfx native library is compiled and linked (via
 * libs/hxbgfx/project/Build.xml), replace each stub with:
 *
 *   #if cpp
 *   @:native('bgfx_<function_name>')
 *   public static function <name>(...):ReturnType { return untyped __cpp__('...'); }
 *   #else
 *   // current stub body
 *   #end
 *
 * Native function names match the bgfx C API:
 *   bgfx_init, bgfx_shutdown, bgfx_reset, bgfx_frame,
 *   bgfx_set_view_rect, bgfx_set_view_clear, bgfx_set_view_transform, bgfx_touch,
 *   bgfx_set_state, bgfx_set_texture,
 *   bgfx_alloc_transient_vertex_buffer, bgfx_submit,
 *   bgfx_create_texture_2d, bgfx_destroy_texture,
 *   bgfx_create_shader, bgfx_destroy_shader,
 *   bgfx_create_program, bgfx_destroy_program,
 *   bgfx_create_uniform, bgfx_destroy_uniform,
 *   bgfx_copy, bgfx_alloc,
 *   bgfx_vertex_layout_begin, bgfx_vertex_layout_add, bgfx_vertex_layout_end,
 *   bgfx_get_renderer_type, bgfx_get_renderer_name
 *
 * Bridge functions (defined in libs/hxbgfx/project/bgfx_bridge.cpp):
 *   hxGetNativeWindowHandle, hxGetNativeDisplayHandle,
 *   hxGetBestRenderer, hxGetSupportedRenderers, hxSetSDLCppWindow
 */
class BgfxAPI
{
	// ============================================================
	// bgfx lifecycle
	// ============================================================
	// Returns false in stub mode so RenderDevice.init() fails and
	// PsychCamera falls back to OpenFL rendering via super.render().
	// When the real bgfx C library is linked, bgfx_init returns the
	// actual GPU initialization result.
	public static function init(init:Dynamic):Bool { return false; }
	public static function shutdown():Void {}
	public static function reset(w:Int, h:Int, flags:Int, fmt:Int):Void {}
	public static function frame(capture:Bool):Int { return 0; }

	// ============================================================
	// View management
	// ============================================================
	public static function setViewRect(id:Int, x:Int, y:Int, w:Int, h:Int):Void {}
	public static function setViewClear(id:Int, flags:Int, rgba:Int, depth:Float, stencil:Int):Void {}
	public static function setViewTransform(id:Int, view:Dynamic, proj:Dynamic):Void {}
	public static function touch(id:Int):Void {}

	// ============================================================
	// Render state
	// ============================================================
	public static function setState(state:Int, rgba:Int):Void {}
	public static function setTexture(stage:Int, s:Int, t:Int, flags:Int):Void {}

	// ============================================================
	// Transient vertex buffer
	// ============================================================
	public static function allocTransientVertexBuffer(tvb:Dynamic, n:Int, layout:Dynamic):Void {}

	// ============================================================
	// Submit
	// ============================================================
	public static function submit(id:Int, prog:Int, depth:Int, flags:Int):Void {}

	// ============================================================
	// Textures
	// ============================================================
	public static function createTexture2D(w:Int, h:Int, mips:Bool, layers:Int, fmt:Int, flags:Int, mem:Dynamic):Int { return 0; }
	public static function destroyTexture(h:Int):Void {}

	// ============================================================
	// Shaders & Programs
	// ============================================================
	public static function createShader(mem:Dynamic):Int { return 0; }
	public static function destroyShader(h:Int):Void {}
	public static function createProgram(vs:Int, fs:Int, destroy:Bool):Int { return 0; }
	public static function destroyProgram(h:Int):Void {}

	// ============================================================
	// Uniforms
	// ============================================================
	public static function createUniform(name:String, t:Int, n:Int):Int { return 0; }
	public static function destroyUniform(h:Int):Void {}

	// ============================================================
	// Memory management
	// ============================================================
	public static function copy(data:Dynamic, sz:Int):Dynamic { return null; }
	public static function alloc(sz:Int):Dynamic { return null; }

	// ============================================================
	// Vertex layout
	// ============================================================
	public static function vertexLayoutBegin(l:Dynamic, r:Int):Void {}
	public static function vertexLayoutAdd(l:Dynamic, a:Int, n:Int, t:Int, norm:Bool, asInt:Bool):Void {}
	public static function vertexLayoutEnd(l:Dynamic):Void {}

	// ============================================================
	// Renderer info
	// ============================================================
	public static function getRendererType():Int { return 8; /*B_OpenGL*/ }
	public static function getRendererName(t:Int):String { return "OpenGL"; }

	// ============================================================
	// Native platform handles (bridge functions in bgfx_bridge.cpp)
	// ============================================================
	public static function hxGetNativeWindowHandle():Dynamic { return null; }
	public static function hxGetNativeDisplayHandle():Dynamic { return null; }
	public static function hxGetBestRenderer():Int {
		#if mac return 5; /*Metal*/ #elseif windows return 3; /*D3D12*/ #else return 9; /*Vulkan*/ #end
	}
	public static function hxGetSupportedRenderers():Int {
		#if mac
		return (1 << 5) | (1 << 8); // Metal + OpenGL
		#elseif windows
		return (1 << 3) | (1 << 9) | (1 << 8); // D3D12 + Vulkan + OpenGL
		#elseif linux
		return (1 << 9) | (1 << 8); // Vulkan + OpenGL
		#else
		return (1 << 8);
		#end
	}
	public static function hxSetSDLCppWindow(w:Dynamic):Void {}
}
