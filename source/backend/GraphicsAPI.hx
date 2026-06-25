package backend;

import flixel.FlxG;
import lime.app.Application;
import lime.system.DisplayMode;

/**
 * Graphics Rendering API abstraction layer.
 *
 * Powered by bgfx — all six backends (Metal, Vulkan, DirectX 12/11/9, OpenGL)
 * are compiled into a single binary and switchable at runtime.
 */
class GraphicsAPI
{
	/**
	 * Time window (in seconds) for benchmarking each graphics API.
	 *
	 * Each API gets the same fixed time budget — frame timestamps are
	 * recorded within this window to compute sustained FPS and frame time
	 * consistency. 3 seconds × 5 APIs (Windows) = ~15 s total.
	 */
	public static inline var BENCHMARK_DURATION_SEC:Float = 3.0;

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
		if (apis.contains(DirectX11)) return DirectX11;
		if (apis.contains(Vulkan)) return Vulkan;
		return OpenGL;
	}

	/**
	 * Benchmark all supported graphics APIs and return the one with the
	 * best balance of sustained FPS and frame time stability.
	 *
	 * For each API, a 3-second time-window benchmark records per-frame
	 * timestamps. The scoring formula penalizes jitter:
	 *
	 *   consistencyScore = 1 / (1 + stdDev / avg)
	 *   score = sustainedFPS × consistencyScore
	 *
	 * An API with 10,000 FPS and 0.5 ms jitter still wins over 5,000 FPS
	 * with 0.05 ms jitter (the jitter is negligible at that speed). But
	 * when two APIs are close in FPS, the more stable one wins.
	 *
	 * If called when the renderer is not initialized (e.g., at startup),
	 * falls back to the fast platform heuristic (detectBestAPI).
	 *
	 * @return The most stable graphics API for this GPU.
	 */
	public static function benchmarkBestAPI():GraphicsAPIType
	{
		if (!RenderDevice.initialized)
		{
			trace('GraphicsAPI.benchmarkBestAPI: renderer not initialized, using heuristic');
			return detectBestAPI();
		}

		var supported = RenderDevice.getSupportedAPIs();
		if (supported.length == 0) return OpenGL;

		var w = BgfxWindowManager.width;
		var h = BgfxWindowManager.height;

		var bestAPI:GraphicsAPIType = OpenGL;
		var bestScore:Float = -1.0;
		var benchmarkedAny:Bool = false;
		var originalAPI:GraphicsAPIType = RenderDevice.activeAPI;

		for (api in supported)
		{
			if (api == Auto) continue;

			var r = RenderDevice.benchmarkAPI(api, w, h, BENCHMARK_DURATION_SEC);
			if (r == null)
			{
				trace('Benchmark: ${api} SKIPPED (init failed)');
				continue;
			}

			benchmarkedAny = true;

			// Consistency score: penalize jitter
			// coeffOfVariation = stdDev / avg  (0 = perfect)
			// consistencyScore = 1 / (1 + cv)  → range (0, 1]
			var cv = r.frameTimeStdDev / r.avgFrameMs;
			var consistencyScore = 1.0 / (1.0 + cv);
			var score = r.sustainedFPS * consistencyScore;

			trace('Benchmark: ${api} — sustained ${Std.int(r.sustainedFPS)} FPS, '
				+ 'avg ${Std.int(r.avgFrameMs * 100) / 100} ms, '
				+ 'max ${Std.int(r.maxFrameMs * 100) / 100} ms, '
				+ 'stddev ${Std.int(r.frameTimeStdDev * 100) / 100} ms → '
				+ 'score ${Std.int(score)}');

			if (score > bestScore)
			{
				bestScore = score;
				bestAPI = api;
			}
		}

		// Recovery: ensure the renderer is in a working state
		if (!benchmarkedAny)
		{
			// All APIs failed. Re-init with the original API.
			trace('Benchmark: all APIs failed, restoring ${originalAPI}');
			BgfxShaderManager.invalidateAll();
			BgfxTextureManager.invalidateAll();
			RenderDevice.shutdown();
			RenderDevice.init(w, h, originalAPI, false);
			BgfxTextureManager.restoreAll();
			bestAPI = originalAPI;
		}
		else if (bestAPI != RenderDevice.activeAPI || !RenderDevice.initialized)
		{
			// Switch to the winning API (handles shutdown → init → restoreAll)
			RenderDevice.switchAPI(bestAPI, w, h);
		}
		else
		{
			// Already on the best API, just restore textures (invalidated by benchmarkAPI)
			BgfxTextureManager.restoreAll();
		}

		// Persist the result
		ClientPrefs.data.graphicsAPI = cast bestAPI;
		ClientPrefs.saveSettings();

		trace('Benchmark: Best API is ${bestAPI} (score ${Std.int(bestScore)})');
		return bestAPI;
	}

	public static function getActiveAPI():GraphicsAPIType
	{
		#if GRAPHICS_API_DIRECTX12
		return DirectX12;
		#elseif GRAPHICS_API_DIRECTX11
		return DirectX11;
		#elseif GRAPHICS_API_VULKAN
		return Vulkan;
		#elseif GRAPHICS_API_METAL
		return Metal;
		#elseif GRAPHICS_API_OPENGL
		return OpenGL;
		#else
		if (RenderDevice.initialized)
			return RenderDevice.activeAPI;
		return getUserPreferredAPI();
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

	/**
	 * Apply VSync setting with API-specific strategies.
	 *
	 * VSync ON:
	 *   - Standard: locks framerate to display refresh rate.
	 *   - Metal: supports adaptive refresh (ProMotion 24-120Hz). Uses display
	 *     refresh rate but allows FramePacer to measure actual achieved rate.
	 *   - Vulkan: prefers MAILBOX present mode (lowest latency, no tearing).
	 *     Falls back to FIFO_RELAXED if MAILBOX not available.
	 *   - Direct3D: allows tearing (DXGI_PRESENT_ALLOW_TEARING) when supported.
	 *
	 * VSync OFF:
	 *   - bgfx active: frame pacing handled entirely by GPU driver
	 *     (VK_PRESENT_MODE_IMMEDIATE / D3D ALLOW_TEARING / Metal no vsync).
	 *     FramePacer.bgfxActive=true ensures no CPU-side throttling.
	 *   - OpenFL fallback: SDL timer caps at 1000 FPS (1ms granularity).
	 *     FramePacer provides high-precision measurement even in fallback.
	 */
	public static function applyVSync(vsyncEnabled:Bool, ?refreshRate:Null<Int>):Void
	{
		if (vsyncEnabled)
		{
			if (refreshRate == null) refreshRate = getDisplayRefreshRate();
			FlxG.drawFramerate = refreshRate;
			FlxG.updateFramerate = refreshRate;
			FlxG.game.focusLostFramerate = refreshRate;
			FramePacer.targetFrameTimeMs = 1000.0 / refreshRate;
		}
		else
		{
			// 1000 FPS is the SDL timer hardware limit (1ms granularity).
			// Setting frameRate to 0 disables the render timer entirely in
			// Lime/OpenFL, which is why the game drops to 1-2 FPS.
			// When bgfx is active, FramePacer bypasses SDL entirely.
			FlxG.drawFramerate = 1000;
			FlxG.updateFramerate = 1000;
			FlxG.game.focusLostFramerate = 60;
			FramePacer.targetFrameTimeMs = 0.0; // uncapped
		}
	}

	/**
	 * Effective frame rate cap: 0 = uncapped, positive = capped to N FPS.
	 * Used by game logic that needs to know the current rate limit.
	 */
	public static function getEffectiveFrameRateCap():Int
	{
		return ClientPrefs.data.vsync ? getDisplayRefreshRate() : 0;
	}

	public static function getDisplayRefreshRate():Int
	{
		#if !html5
		var dm = Application.current.window.displayMode;
		if (dm != null && dm.refreshRate > 0) return dm.refreshRate;
		#end
		return 60;
	}

	/**
	 * One-line description: the actual rendering API.
	 * Reads from persisted save data (only changes on ENTER, not LEFT/RIGHT),
	 * and resolves "Auto" to the real best API — so "Auto" is never shown.
	 */
	public static function getActiveAPIDescription():String
	{
		var saved = FlxG.save.data.graphicsAPI;
		var api = (saved != null) ? cast(saved, GraphicsAPIType) : GraphicsAPIType.Auto;
		return resolveAPI(api);
	}
}
