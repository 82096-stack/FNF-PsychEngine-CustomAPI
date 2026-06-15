package backend;

import lime.app.Application;
import openfl.events.Event;
import openfl.Lib;

/**
 * BgfxWindowManager — Handles window integration between Lime/OpenFL and bgfx.
 *
 * The C bridge auto-detects the SDL2 window via SDL_GL_GetCurrentWindow(),
 * so no manual window handle registration is needed from Haxe.
 *
 * Responsibilities:
 * - Track window dimensions for projection matrix and bgfx_reset
 * - Forward window resize events to RenderDevice
 */
class BgfxWindowManager
{
	public static var width(default, null):Int = 1280;
	public static var height(default, null):Int = 720;
	public static var initialized:Bool = false;

	/**
	 * Initialize window management.
	 * Must be called AFTER the Lime window is created (in Main.new() after FlxGame).
	 */
	public static function init():Void
	{
		if (initialized) return;

		var window = Application.current.window;
		if (window == null)
		{
			trace('BgfxWindowManager: no Lime window available yet');
			return;
		}

		width = window.width;
		height = window.height;

		// The C bridge (bgfx_bridge.cpp) auto-detects the SDL window
		// via SDL_GL_GetCurrentWindow(). No manual registration needed.

		// Listen for resize events
		Lib.current.stage.addEventListener(Event.RESIZE, onResize);

		initialized = true;
		trace('BgfxWindowManager: initialized (${width}x${height})');
	}

	static function onResize(event:Event):Void
	{
		var window = Application.current.window;
		if (window == null) return;

		var w = window.width;
		var h = window.height;
		if (w != width || h != height)
		{
			width = w; height = h;
			if (RenderDevice.initialized)
				RenderDevice.resize(width, height);
		}
	}

	public static function dispose():Void
	{
		Lib.current.stage.removeEventListener(Event.RESIZE, onResize);
		initialized = false;
	}
}
