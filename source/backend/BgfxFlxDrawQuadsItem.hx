package backend;

import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.math.FlxMatrix;
import openfl.geom.ColorTransform;
import openfl.Vector;
import haxe.io.Bytes;

/**
 * BgfxFlxDrawQuadsItem — Replaces FlxDrawQuadsItem.render() with bgfx.
 *
 * Converts Flixel's rect+transform+alpha+color arrays into bgfx
 * vertex data and submits via RenderDevice.
 *
 * Vertex format (20 bytes): position(2f), texcoord(2f), color(4u8)
 */
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
		buildVertexData(texWidth, texHeight, numQuads, vertexData);

		var viewId = RenderDevice.VIEW_CAM0 + FlxG.cameras.list.indexOf(camera);
		RenderDevice.submitQuads(viewId, texHandle, vertexData, numVertices, program, blend);
	}

	function buildVertexData(texWidth:Float, texHeight:Float, numQuads:Int, out:Bytes):Void
	{
		var hasColors = colored || hasColorOffsets;
		var pos = 0;

		for (q in 0...numQuads)
		{
			var rx = rects[q * 4 + 0], ry = rects[q * 4 + 1];
			var rw = rects[q * 4 + 2], rh = rects[q * 4 + 3];

			var a = transforms[q * 6 + 0],  b = transforms[q * 6 + 1];
			var c = transforms[q * 6 + 2],  d = transforms[q * 6 + 3];
			var tx = transforms[q * 6 + 4], ty = transforms[q * 6 + 5];

			// Corners in screen space
			var sx = [tx, a * rw + tx, a * rw + c * rh + tx, c * rh + tx];
			var sy = [ty, b * rw + ty, b * rw + d * rh + ty, d * rh + ty];

			var u0 = rx / texWidth,  v0 = ry / texHeight;
			var u1 = (rx + rw) / texWidth, v1 = (ry + rh) / texHeight;

			for (v in 0...VERTICES_PER_QUAD)
			{
				var alpha:Float = 1.0;
				if (alphas.length > q * VERTICES_PER_QUAD + v)
					alpha = alphas[q * VERTICES_PER_QUAD + v];

				var cr = 1.0, cg = 1.0, cb = 1.0;
				if (hasColors && colorMultipliers != null)
				{
					var ci = (q * VERTICES_PER_QUAD + v) * 4;
					if (colorMultipliers.length > ci + 3) {
						cr = colorMultipliers[ci + 0]; cg = colorMultipliers[ci + 1]; cb = colorMultipliers[ci + 2];
					}
				}

				out.setFloat(pos,     sx[v]);
				out.setFloat(pos + 4, sy[v]);
				out.setFloat(pos + 8,  (v == 0 || v == 3) ? u0 : u1);
				out.setFloat(pos + 12, (v < 2) ? v0 : v1);
				out.set(pos + 16, Std.int(cr * 255) & 0xFF);
				out.set(pos + 17, Std.int(cg * 255) & 0xFF);
				out.set(pos + 18, Std.int(cb * 255) & 0xFF);
				out.set(pos + 19, Std.int(alpha * 255) & 0xFF);
				pos += BYTES_PER_VERTEX;
			}
		}
	}
	#end
}
