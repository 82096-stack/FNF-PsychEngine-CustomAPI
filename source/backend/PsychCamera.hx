package backend;

import flixel.graphics.FlxGraphic;
import flixel.graphics.tile.FlxDrawBaseItem.FlxDrawItemType;
import flixel.graphics.tile.FlxDrawQuadsItem;
import flixel.math.FlxMatrix;
import openfl.display.BlendMode;
import openfl.geom.ColorTransform;
import haxe.io.Bytes;

/**
 * PsychCamera — custom FlxCamera with lerp-based follow and bgfx support.
 *
 * The bgfx render() override is disabled by default because:
 *   1. FlxCamera.render() uses @:allow(flixel.system.frontEnds.CameraFrontEnd)
 *      which prevents subclass override dispatch in Haxe.
 *   2. The bgfx C library is not yet compiled/linked.
 *
 * When the bgfx library is available:
 *   - Enable FUTURE_BGFX_OVERRIDE define
 *   - Change BgfxAPI.init() to return real bgfx_init() result
 *   - The game will switch from OpenFL to bgfx rendering
 *
 * bgfx vertex building helpers (buildBgfxVertices) and RenderDevice
 * infrastructure remain available for use when bgfx is active.
 */
@:access(flixel.FlxCamera)
class PsychCamera extends FlxCamera
{
	static inline var BYTES_PER_VERTEX:Int = 20;
	static inline var VERTICES_PER_QUAD:Int = 4;

	override public function update(elapsed:Float):Void
	{
		if (target != null)
			updateFollowDelta(elapsed);

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
	}

	public function updateFollowDelta(?elapsed:Float = 0):Void
	{
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - width * 0.5, _point.y - height * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= viewRight)
					_scrollTarget.x += viewWidth;
				else if (targetX + target.width < viewLeft)
					_scrollTarget.x -= viewWidth;

				if (targetY >= viewBottom)
					_scrollTarget.y += viewHeight;
				else if (targetY + target.height < viewTop)
					_scrollTarget.y -= viewHeight;

				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge) _scrollTarget.x = edge;
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge) _scrollTarget.x = edge;

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge) _scrollTarget.y = edge;
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge) _scrollTarget.y = edge;
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
					_lastTargetPosition = FlxPoint.get(target.x, target.y);
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;
				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		var mult:Float = 1 - Math.exp(-elapsed * followLerp / (1/60));
		scroll.x += (_scrollTarget.x - scroll.x) * mult;
		scroll.y += (_scrollTarget.y - scroll.y) * mult;
	}

	override function set_followLerp(value:Float)
	{
		return followLerp = value;
	}

	// ==================================================================
	// BGFX VERTEX BUILDING (available for future bgfx rendering)
	// ==================================================================

	public static function buildBgfxVertices(texWidth:Float, texHeight:Float, numQuads:Int,
		rects:Dynamic, transforms:Dynamic,
		alphas:Array<Float>, colors:Array<Float>,
		colored:Bool, hasColorOffsets:Bool, out:Bytes):Void
	{
		var pos = 0;

		for (q in 0...numQuads)
		{
			var rx = rects[q * 4 + 0], ry = rects[q * 4 + 1];
			var rw = rects[q * 4 + 2], rh = rects[q * 4 + 3];

			var a  = transforms[q * 6 + 0], b  = transforms[q * 6 + 1];
			var c  = transforms[q * 6 + 2], d  = transforms[q * 6 + 3];
			var tx = transforms[q * 6 + 4], ty = transforms[q * 6 + 5];

			var sx0 = tx,              sy0 = ty;
			var sx1 = a * rw + tx,     sy1 = b * rw + ty;
			var sx2 = a * rw + c * rh + tx, sy2 = b * rw + d * rh + ty;
			var sx3 = c * rh + tx,     sy3 = d * rh + ty;

			var sx = [sx0, sx1, sx2, sx3];
			var sy = [sy0, sy1, sy2, sy3];

			var u0 = rx / texWidth,  v0 = ry / texHeight;
			var u1 = (rx + rw) / texWidth, v1 = (ry + rh) / texHeight;

			for (v in 0...VERTICES_PER_QUAD)
			{
				var alpha:Float = 1.0;
				if (alphas.length > q * VERTICES_PER_QUAD + v)
					alpha = alphas[q * VERTICES_PER_QUAD + v];

				var cr = 1.0, cg = 1.0, cb = 1.0;
				if (colored && colors != null)
				{
					var ci = (q * VERTICES_PER_QUAD + v) * 4;
					if (colors.length > ci + 3)
					{
						cr = colors[ci + 0]; cg = colors[ci + 1]; cb = colors[ci + 2];
					}
				}

				out.setFloat(pos,      sx[v]);
				out.setFloat(pos + 4,  sy[v]);
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
}
