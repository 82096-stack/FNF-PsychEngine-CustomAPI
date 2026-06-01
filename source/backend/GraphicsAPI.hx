package backend;

import flixel.FlxG;
import lime.app.Application;
import lime.system.DisplayMode;

/**
 * Graphics Rendering API abstraction layer.
 *
 * Powered by bgfx — all four backends (Metal, Vulkan, DirectX 12, OpenGL)
 * are compiled into a single binary and switchable at runtime.
 */
class GraphicsAPI
{
	public static function getAvailableAPIs():Array<GraphicsAPIType>
	{
		var apis:Array<GraphicsAPIType> = [Auto];
		var supported = RenderDevice.getSupportedAPIs();
		for (api in supported) apis.push(api);
		return apis;
	}

	public static function detectBestAPI():GraphicsAPIType
	{
		var apis = RenderDevice.getSupportedAPIs();
		if (apis.length == 0) return OpenGL;
		if (apis.contains(Metal)) return Metal;
		if (apis.contains(DirectX12)) return DirectX12;
		if (apis.contains(Vulkan)) return Vulkan;
		return OpenGL;
	}

	public static function getActiveAPI():GraphicsAPIType
	{
		#if GRAPHICS_API_DIRECTX12
		return DirectX12;
		#elseif GRAPHICS_API_VULKAN
		return Vulkan;
		#elseif GRAPHICS_API_METAL
		return Metal;
		#elseif GRAPHICS_API_OPENGL
		return OpenGL;
		#else
		if (RenderDevice.initialized)
			return RenderDevice.activeAPI;
		return detectBestAPI();
		#end
	}

	public static function switchAPI(newAPI:GraphicsAPIType):Bool
	{
		if (!RenderDevice.initialized) return false;
		if (newAPI == RenderDevice.activeAPI) return true;

		var w = BgfxWindowManager.width;
		var h = BgfxWindowManager.height;
		var ok = RenderDevice.switchAPI(newAPI, w, h);

		if (ok)
		{
			ClientPrefs.data.graphicsAPI = cast newAPI;
			ClientPrefs.saveSettings();
		}
		return ok;
	}

	public static function getUserPreferredAPI():GraphicsAPIType
	{
		return resolveAPI(cast ClientPrefs.data.graphicsAPI);
	}

	public static function isAPIMismatched():Bool
	{
		return getActiveAPI() != getUserPreferredAPI();
	}

	public static function isAPISupported(api:GraphicsAPIType):Bool
	{
		return getAvailableAPIs().contains(api);
	}

	public static function resolveAPI(preferred:GraphicsAPIType):GraphicsAPIType
	{
		if (preferred == Auto) return detectBestAPI();
		if (!isAPISupported(preferred))
		{
			trace('Warning: $preferred not supported. Falling back to Auto.');
			return detectBestAPI();
		}
		return preferred;
	}

	public static function applyVSync(vsyncEnabled:Bool, ?refreshRate:Null<Int>):Void
	{
		if (vsyncEnabled)
		{
			if (refreshRate == null) refreshRate = getDisplayRefreshRate();
			FlxG.drawFramerate = refreshRate;
			FlxG.updateFramerate = refreshRate;
			FlxG.game.focusLostFramerate = refreshRate;
		}
		else
		{
			FlxG.drawFramerate = 999;
			FlxG.updateFramerate = 999;
			FlxG.game.focusLostFramerate = 60;
		}
	}

	public static function getDisplayRefreshRate():Int
	{
		#if !html5
		var dm = Application.current.window.displayMode;
		if (dm != null && dm.refreshRate > 0) return dm.refreshRate;
		#end
		return 60;
	}

	public static function getActiveAPIDescription():String
	{
		var api = getActiveAPI();
		var desc = switch(api : String)
		{
			case "Auto": 'Auto (${detectBestAPI()})';
			case "DirectX 12": 'DirectX 12';
			case "Vulkan": 'Vulkan';
			case "Metal": 'Metal';
			case "OpenGL": 'OpenGL';
			default: 'Unknown ($api)';
		};

		if (RenderDevice.initialized)
			desc += ' | ${RenderDevice.getRendererName()}';

		return desc;
	}
}
