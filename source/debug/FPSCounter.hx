package debug;

import backend.GraphicsAPI;
import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;

/**
 * FPS overlay — uses openfl.text.TextField (renders via OpenFL native text).
 *
 * This is intentionally NOT routed through the flixel draw stack / bgfx
 * because it needs to be available before the game fully initializes,
 * and adding FlxText to flixel states during early startup causes crashes.
 */
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;

	public var memoryMegas(get, never):Float;

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

	var deltaTimeout:Float = 0.0;

	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();

		if (deltaTimeout < 50) {
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length;
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void {
		text = 'FPS: ${currentFPS}'
		+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}'
		+ '\nAPI: ${GraphicsAPI.getActiveAPIDescription()}';

		textColor = 0xFFFFFFFF;
		var fpsThreshold:Float = FlxG.drawFramerate >= 500 ? 30 : FlxG.drawFramerate * 0.5;
		if (currentFPS < fpsThreshold)
			textColor = 0xFFFF0000;
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
