package backend;

/**
 * BgfxFallback — bgfx initialization with graceful failure handling.
 *
 * Attempts to initialize bgfx. If the preferred API fails, tries OpenGL
 * as a fallback. If both fail, the game cannot render — but this should
 * never happen on a properly configured system with bgfx libraries.
 */
class BgfxFallback
{
	public static var isActive(default, null):Bool = false;
	public static var failureReason(default, null):String = null;

	/**
	 * Initialize bgfx with the selected API.
	 * Falls back to OpenGL if the preferred API fails.
	 *
	 * @return true if bgfx initialized successfully
	 */
	public static function tryInit(width:Int, height:Int, api:GraphicsAPIType, vsync:Bool = false):Bool
	{
		if (isActive) return true;

		// Register window with the C bridge
		BgfxWindowManager.init();

		// Attempt init with the preferred API
		var result = RenderDevice.init(width, height, api, vsync);
		if (result)
		{
			isActive = true;
			trace('BgfxFallback: initialized with ${api}');
			return true;
		}

		// If preferred API failed and it wasn't OpenGL, try OpenGL
		if (api != OpenGL)
		{
			trace('BgfxFallback: ${api} failed, trying OpenGL...');
			result = RenderDevice.init(width, height, OpenGL, vsync);
			if (result)
			{
				isActive = true;
				RenderDevice.activeAPI = OpenGL;
				trace('BgfxFallback: OpenGL fallback succeeded');
				return true;
			}
		}

		// Both failed
		failureReason = 'bgfx init failed for ${api} and OpenGL';
		trace('BgfxFallback: FATAL — ${failureReason}');
		isActive = false;
		return false;
	}

	public static function shutdown():Void
	{
		if (isActive)
		{
			BgfxWindowManager.dispose();
			RenderDevice.shutdown();
			isActive = false;
		}
	}

	public static function isAPISupported(api:GraphicsAPIType):Bool
	{
		var supported = RenderDevice.getSupportedAPIs();
		return supported.contains(api);
	}

	public static function getSupportedAPIs():Array<GraphicsAPIType>
	{
		return RenderDevice.getSupportedAPIs();
	}
}
