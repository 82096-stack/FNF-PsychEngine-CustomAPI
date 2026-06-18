package objects;

import flixel.addons.display.FlxPieDial;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import ffmpeg.FFmpegVideoDecoder;
import ffmpeg.VideoTexture;
import ffmpeg.VideoSprite as FFmpegVideoSprite;

/**
 * VideoSprite — BGGFX-compatible video wrapper for Psych Engine.
 *
 * Fully replaces the hxvlc-based video system with a native FFmpeg backend.
 * No external players (VLC, system codecs) required — FFmpeg is statically
 * linked or bundled with the game.
 *
 * = Architecture =
 *   FFmpegVideoDecoder (native C++ decode thread)
 *        │ YUV → RGBA via swscale
 *        ▼
 *   ffmpeg.VideoSprite  (FlxSprite with BitmapData + BGFX texture)
 *        │
 *        ▼
 *   objects.VideoSprite (FlxSpriteGroup wrapper with skip UI + callbacks)
 *
 * = Backward Compatible API =
 *   Same constructor and method signatures as the hxvlc version:
 *     new VideoSprite(path, isWaiting, canSkip, shouldLoop)
 *     video.play() / .pause() / .resume()
 *     video.finishCallback / video.onSkip
 *     video.canSkip / video.holdingTime
 */
class VideoSprite extends FlxSpriteGroup
{
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;
	public var holdingTime:Float = 0;
	public var videoSprite:FFmpegVideoSprite; // The actual FFmpeg-backed video display
	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;

	private var videoName:String;
	public var waiting:Bool = false;

	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false)
	{
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if (!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// Create the FFmpeg-backed video sprite
		videoSprite = new FFmpegVideoSprite(videoName, shouldLoop == true, false);
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(videoSprite);

		if (canSkip)
			this.canSkip = true;

		// Wire up format setup callback
		videoSprite.onFormatSetup = function()
		{
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
		};

		// Wire up end-of-video callback
		if (shouldLoop != true)
		{
			videoSprite.finishCallback = finishVideo;
		}
	}

	var alreadyDestroyed:Bool = false;

	override function destroy()
	{
		if (alreadyDestroyed) return;

		trace('Video destroyed');
		if (cover != null)
		{
			remove(cover);
			cover.destroy();
		}

		finishCallback = null;
		onSkip = null;

		if (FlxG.state != null)
		{
			if (FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if (FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}

		super.destroy();
		alreadyDestroyed = true;
	}

	function finishVideo()
	{
		if (!alreadyDestroyed)
		{
			if (finishCallback != null)
				finishCallback();
			destroy();
		}
	}

	override function update(elapsed:Float)
	{
		// Skip logic
		if (canSkip)
		{
			if (Controls.instance.pressed('accept'))
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if (holdingTime >= _timeToSkip)
			{
				if (onSkip != null) onSkip();
				finishCallback = null;
				finishVideo();
				trace('Skipped video');
				return;
			}
		}

		super.update(elapsed);
	}

	function set_canSkip(newValue:Bool):Bool
	{
		canSkip = newValue;
		if (canSkip)
		{
			if (skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				add(skipSprite);
			}
		}
		else if (skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if (skipSprite == null) return;
		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	// ── Playback controls (delegated to FFmpegVideoSprite) ──────

	public function play():Void   { videoSprite?.play(); }
	public function resume():Void { videoSprite?.resume(); }
	public function pause():Void  { videoSprite?.pause(); }

	/** Seek to a specific time position in seconds. */
	public function seek(seconds:Float):Void { videoSprite?.seek(seconds); }

	/** Get current playback position in seconds. */
	public function getCurrentTime():Float { return videoSprite != null ? videoSprite.getCurrentTime() : 0.0; }

	/** Get total video duration in seconds. */
	public function getDuration():Float { return videoSprite != null ? videoSprite.getDuration() : 0.0; }

	#end
}
