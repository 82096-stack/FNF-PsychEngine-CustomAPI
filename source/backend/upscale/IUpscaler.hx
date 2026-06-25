package backend.upscale;

/**
 * Base interface for upscaler implementations.
 *
 * Each upscaler:
 *   1. Receives a low-res input texture (rendered at internal resolution, e.g. 1080p)
 *   2. Outputs to the full-resolution backbuffer or output framebuffer
 *
 * All upscalers are initialized once and called each frame from RenderDevice.endFrame().
 */
interface IUpscaler
{
	/**
	 * Initialize the upscaler. Called once when the upscaler is selected
	 * or when resolution changes.
	 *
	 * @param inputW   Internal render resolution width (source)
	 * @param inputH   Internal render resolution height (source)
	 * @param outputW  Window/display resolution width (target)
	 * @param outputH  Window/display resolution height (target)
	 * @return true if initialization succeeded
	 */
	function init(inputW:Int, inputH:Int, outputW:Int, outputH:Int):Bool;

	/**
	 * Apply the upscaler. Called every frame from RenderDevice.endFrame().
	 *
	 * The input texture has already been rendered to by the game.
	 * This method should set up the output view and run the upscale pass(es).
	 *
	 * @param inputTextureHandle  bgfx texture handle of the low-res render target
	 * @param outputFBHandle      bgfx frame buffer handle of the output target (0 = backbuffer)
	 */
	function apply(inputTextureHandle:Int, outputFBHandle:Int):Void;

	/**
	 * Release any resources (textures, programs, etc.) held by this upscaler.
	 */
	function dispose():Void;

	/**
	 * Human-readable name of this upscaler for debugging.
	 */
	function getName():String;

	/**
	 * Set jitter offset for temporal anti-aliasing (FSR 2/3.1, DLSS, XeSS).
	 * Called each frame before apply(). Default no-op for spatial upscalers.
	 */
	function setJitterOffset(x:Float, y:Float):Void;

	/**
	 * Set frame time delta in milliseconds for temporal accumulation.
	 * Default no-op for spatial upscalers.
	 */
	function setFrameTimeDelta(dt:Float):Void;
}
