package backend;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import openfl.Vector;
import haxe.io.Bytes;

/**
 * BgfxFlxDrawQuadsItem — [DEPRECATED]
 *
 * This class previously attempted to replace FlxDrawQuadsItem.render()
 * by overriding it with bgfx submission. However, flixel's rendering
 * pipeline creates `FlxDrawQuadsItem` instances directly via the private
 * typedef `FlxDrawItem` in `FlxCamera.startQuadBatch()`, making
 * class substitution impossible from outside the flixel library.
 *
 * **Replaced by:** `PsychCamera.render()` override.
 * The render override walks the draw stack directly and submits all
 * draw items through bgfx without needing to replace the draw item class.
 *
 * The vertex building logic has been extracted to
 * `PsychCamera.buildBgfxVertices()` as a static helper.
 *
 * This file is kept for reference only and is not used at runtime.
 */
@:deprecated("Replaced by PsychCamera.render() override")
class BgfxFlxDrawQuadsItem extends FlxDrawQuadsItem
{
	static inline var BYTES_PER_VERTEX:Int = 20;
	static inline var VERTICES_PER_QUAD:Int = 4;

	public function new() { super(); }

	#if !flash
	override public function render(camera:FlxCamera):Void
	{
		if (rects.length == 0) return;

		var numQuads = Std.int(rects.length / 4);
		var numVertices = numQuads * VERTICES_PER_QUAD;

		var texHandle = BgfxTextureManager.get(graphics);
		if (texHandle == 0) return;

		var program = BgfxShaderManager.get(shader);
		if (program == 0) return;

		var texWidth:Float = graphics.bitmap.width;
		var texHeight:Float = graphics.bitmap.height;
		if (texWidth <= 0 || texHeight <= 0) return;

		var vertexData = Bytes.alloc(numVertices * BYTES_PER_VERTEX);

		// Reuse the static helper from PsychCamera
		PsychCamera.buildBgfxVertices(texWidth, texHeight, numQuads,
			rects, transforms,
			alphas, colorMultipliers,
			colored, hasColorOffsets, vertexData);

		var viewId = RenderDevice.VIEW_CAM0 + FlxG.cameras.list.indexOf(camera);
		RenderDevice.submitQuads(viewId, texHandle, vertexData, numVertices, program, blend);
	}
	#end
}
