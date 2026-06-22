package debug;

import backend.GraphicsAPI;
import backend.FramePacer;
import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * FPS overlay — uses openfl.text.TextField (renders via OpenFL native text,
 * bypassing the bgfx / Flixel draw stack for availability during early init).
 *
 * Unlike the original Psych Engine, the FPS display is:
 * - Updated every frame (no 50ms throttle) — TextField.setText() is cheap.
 * - Not capped to updateFramerate — shows the TRUE achieved frame rate.
 * - Optionally shows microsecond frame times when highPerfMode is enabled.
 */
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;

	/** When true, displays frame time in microseconds instead of just FPS count. */
	public static var highPerfMode:Bool = false;

	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		this.x = x;
		this.y = y;

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 14, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		// High-precision timestamp (mach_absolute_time / QueryPerformanceCounter)
		final now:Float = FramePacer.now() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		// True measured FPS — not capped at updateFramerate
		currentFPS = times.length;
		updateText();
	}

	public dynamic function updateText():Void
	{
		if (highPerfMode)
		{
			var avgUs:Float = (currentFPS > 0) ? (1000000.0 / currentFPS) : 0;
			text = 'FPS: ${currentFPS} (${Std.int(avgUs)}us)'
				+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}'
				+ '\nAPI: ${GraphicsAPI.getActiveAPIDescription()}';
		}
		else
		{
			text = 'FPS: ${currentFPS}'
				+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}'
				+ '\nAPI: ${GraphicsAPI.getActiveAPIDescription()}';
		}
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
