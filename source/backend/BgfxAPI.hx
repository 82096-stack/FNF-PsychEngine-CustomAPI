package backend;

/** bgfx API stubs — replaced with CFFI @:native bindings when bgfx libs are linked. */

class BgfxAPI
{
	public static function init(init:Dynamic):Bool { return true; }
	public static function shutdown():Void {}
	public static function reset(w:Int, h:Int, flags:Int, fmt:Int):Void {}
	public static function frame(capture:Bool):Int { return 0; }
	public static function setViewRect(id:Int, x:Int, y:Int, w:Int, h:Int):Void {}
	public static function setViewClear(id:Int, flags:Int, rgba:Int, depth:Float, stencil:Int):Void {}
	public static function touch(id:Int):Void {}
	public static function setState(state:Int, rgba:Int):Void {}
	public static function setTexture(stage:Int, s:Int, t:Int, flags:Int):Void {}
	public static function allocTransientVertexBuffer(tvb:Dynamic, n:Int, layout:Dynamic):Void {}
	public static function submit(id:Int, prog:Int, depth:Int, flags:Int):Void {}
	public static function createTexture2D(w:Int, h:Int, mips:Bool, layers:Int, fmt:Int, flags:Int, mem:Dynamic):Int { return 0; }
	public static function destroyTexture(h:Int):Void {}
	public static function createShader(mem:Dynamic):Int { return 0; }
	public static function destroyShader(h:Int):Void {}
	public static function createProgram(vs:Int, fs:Int, destroy:Bool):Int { return 0; }
	public static function destroyProgram(h:Int):Void {}
	public static function createUniform(name:String, t:Int, n:Int):Int { return 0; }
	public static function destroyUniform(h:Int):Void {}
	public static function copy(data:Dynamic, sz:Int):Dynamic { return null; }
	public static function alloc(sz:Int):Dynamic { return null; }
	public static function vertexLayoutBegin(l:Dynamic, r:Int):Void {}
	public static function vertexLayoutAdd(l:Dynamic, a:Int, n:Int, t:Int, norm:Bool, asInt:Bool):Void {}
	public static function vertexLayoutEnd(l:Dynamic):Void {}
	public static function getRendererType():Int { return 8; /*B_OpenGL*/ }
	public static function getRendererName(t:Int):String { return "OpenGL"; }
	public static function hxGetNativeWindowHandle():Dynamic { return null; }
	public static function hxGetNativeDisplayHandle():Dynamic { return null; }
	public static function hxGetBestRenderer():Int {
		#if mac return 5; /*Metal*/ #elseif windows return 3; /*D3D12*/ #else return 9; /*Vulkan*/ #end
	}
	public static function hxGetSupportedRenderers():Int {
		// Report all APIs that bgfx can support on this platform
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
