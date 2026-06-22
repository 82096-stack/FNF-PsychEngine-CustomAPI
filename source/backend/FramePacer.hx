package backend;

/**
 * High-precision frame pacer that bypasses SDL's 1ms timer granularity.
 *
 * On macOS, `haxe.Timer.stamp()` uses `mach_absolute_time()` (nanosecond precision).
 * On Windows, it uses `QueryPerformanceCounter()` (sub-microsecond precision).
 *
 * When bgfx is active, frame pacing is fully handed off to `BgfxAPI.frame()` and
 * the GPU driver's present engine — the SDL timer is not involved at all.
 *
 * When running on the OpenFL fallback path (bgfx not compiled), the pacer uses a
 * spin-wait loop with progressive backoff to achieve frame rates above 1000 FPS
 * where the OS scheduler and timer resolution allow.
 */
class FramePacer
{
	/** True when bgfx is driving the frame loop (SDL timer bypassed entirely). */
	public static var bgfxActive(default, null):Bool = false;

	/** Target frame time in milliseconds. 0 = uncapped (run as fast as possible). */
	public static var targetFrameTimeMs:Float = 0.0;

	/** Instantaneous FPS measured over the last second. Updated every frame. */
	public static var instantFPS(default, null):Int = 0;

	/** Average frame time in milliseconds over the last 60 frames. */
	public static var avgFrameTimeMs(default, null):Float = 0.0;

	/** Timestamp of the current frame start (seconds, high precision). */
	public static var frameStartTime(default, null):Float = 0.0;

	/** Timestamp of the previous frame start. */
	public static var lastFrameStartTime(default, null):Float = 0.0;

	// Internal sliding window for FPS calculation (last 1 second of frame timestamps)
	static var _frameTimestamps:Array<Float> = [];
	static var _frameTimeWindow:Array<Float> = []; // last 60 frame durations in ms

	/**
	 * High-precision timestamp in seconds.
	 * Uses platform-native timers (mach_absolute_time / QueryPerformanceCounter).
	 */
	public static inline function now():Float
	{
		return haxe.Timer.stamp();
	}

	/**
	 * Call at the START of every frame (before update logic).
	 * Records timing and updates FPS metrics.
	 */
	public static function beginFrame():Void
	{
		var t:Float = now();
		lastFrameStartTime = frameStartTime;
		frameStartTime = t;

		// Sliding window: keep timestamps from the last 1 second
		_frameTimestamps.push(t);
		while (_frameTimestamps.length > 0 && _frameTimestamps[0] < t - 1.0)
			_frameTimestamps.shift();
		instantFPS = _frameTimestamps.length;

		// Rolling average of frame durations (last 60 frames)
		if (lastFrameStartTime > 0)
		{
			var frameMs:Float = (t - lastFrameStartTime) * 1000.0;
			_frameTimeWindow.push(frameMs);
			if (_frameTimeWindow.length > 60)
				_frameTimeWindow.shift();

			var sum:Float = 0;
			for (dt in _frameTimeWindow)
				sum += dt;
			avgFrameTimeMs = sum / _frameTimeWindow.length;
		}
	}

	/**
	 * Call at the END of every frame.
	 * When bgfx is not active and targetFrameTimeMs > 0, spin-waits
	 * until the target frame time is met.
	 */
	public static function endFrame():Void
	{
		if (bgfxActive || targetFrameTimeMs <= 0)
			return;

		var elapsed:Float = (now() - frameStartTime) * 1000.0;
		var remaining:Float = targetFrameTimeMs - elapsed;

		if (remaining > 0.01)
		{
			// Progressive backoff: tight spin for first 0.5ms, then yield
			var target:Float = now() + remaining / 1000.0;
			var spinDeadline:Float = now() + 0.0005;

			while (now() < spinDeadline && now() < target)
			{
				// tight spin — 0.5ms max
			}

			#if sys
			while (now() < target)
			{
				Sys.sleep(0.0001); // 0.1ms sleep
			}
			#end
		}
	}

	/**
	 * Enable bgfx-driven frame pacing. When active, the SDL timer is irrelevant
	 * because bgfx's own presentation engine handles frame scheduling.
	 */
	public static function setBGFXMode(active:Bool):Void
	{
		bgfxActive = active;
		if (active)
		{
			// bgfx handles all pacing — no CPU-side waiting needed
			targetFrameTimeMs = 0.0;
		}
	}

	/**
	 * Reset all internal state (called on game restart / API switch).
	 */
	public static function reset():Void
	{
		_frameTimestamps = [];
		_frameTimeWindow = [];
		instantFPS = 0;
		avgFrameTimeMs = 0.0;
		frameStartTime = 0.0;
		lastFrameStartTime = 0.0;
	}
}
