package ffmpeg;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import backend.BgfxTextureManager;

/**
 * VideoSprite — FFmpeg-based video display via FlxSprite + BGFX textures.
 *
 * = Architecture =
 *   FFmpegVideoDecoder (native C++ decode thread)
 *          │
 *          ▼ RGBA frame bytes
 *   FFmpegVideoDecoder.update()  ──  BitmapData.setPixels()
 *          │
 *          ▼
 *   VideoTexture.updateFrame()   ──  BgfxTextureManager.updateTexture()
 *          │
 *          ▼
 *   FlxSprite.draw()             ──  Renders via BGFX pipeline
 *
 * = Thread Model =
 *   - Decode thread:   Runs in native C++ (avcodec), pushes frames to queue.
 *   - Render thread:   Haxe main loop calls update() → polls frame queue →
 *                      updates BitmapData → uploads to BGFX texture.
 *   No blocking:       Frame queue size limits prevent decoder from running
 *                      away; render thread polls without blocking.
 *
 * = Usage =
 *   var video = new ffmpeg.VideoSprite("videos/intro.mp4");
 *   video.finishCallback = () -> trace("Video ended!");
 *   add(video);
 *   video.play();
 *
 * = Supported Formats =
 *   - MP4  (H.264 video, AAC/MP3 audio)
 *   - WebM (VP9 video, Vorbis/Opus audio)
 *   - MKV  (various codecs)
 *
 * = Platform Requirements =
 *   - Windows:   FFmpeg DLLs in game directory or statically linked
 *   - macOS:     FFmpeg dylibs bundled in .app or statically linked
 *   - Linux:     System FFmpeg or bundled .so files
 */
class VideoSprite extends FlxSprite
{
	// ── Video decoder ──────────────────────────────────────────────
	public var decoder(default, null):FFmpegVideoDecoder;

	// ── Texture management ─────────────────────────────────────────
	public var videoTexture(default, null):VideoTexture;

	// ── Callbacks ──────────────────────────────────────────────────
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;
	public var onFormatSetup:Void->Void = null; // Called when video dimensions are known

	// ── State ──────────────────────────────────────────────────────
	public var videoName(default, null):String;
	public var paused(default, null):Bool = false;
	public var stopped(default, null):Bool = false;
	public var looping(default, null):Bool = false;

	// ── Skip (hold-to-skip) ────────────────────────────────────────
	public var canSkip(default, set):Bool = false;
	public var holdingTime:Float = 0;
	final skipDuration:Float = 1.0; // seconds to hold to skip

	// ── Internal ───────────────────────────────────────────────────
	var _initialized:Bool = false;
	var _firstFrame:Bool = true;
	var _alreadyDestroyed:Bool = false;
	var _playOnLoad:Bool = false;

	// Audio
	var _audioBuffer:haxe.io.Float32Array = null;
	var _audioSampleRate:Int = 0;
	var _audioChannels:Int = 0;

	/**
	 * Create a new VideoSprite.
	 *
	 * @param videoPath  Absolute path to the video file.
	 * @param shouldLoop Whether to loop the video when it reaches the end.
	 * @param playOnLoad Whether to start playing immediately after loading.
	 */
	public function new(videoPath:String, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true)
	{
		super(0, 0);

		videoName = videoPath;
		looping = shouldLoop;
		_playOnLoad = playOnLoad;

		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		// Initialize decoder
		decoder = new FFmpegVideoDecoder();
		videoTexture = new VideoTexture();

		// Set up end-of-video callback on the decoder
		decoder.onEndReached = function()
		{
			if (looping)
			{
				decoder.seek(0);
				decoder.play();
			}
			else
			{
				if (finishCallback != null)
					finishCallback();
				paused = false;
				stopped = true;
			}
		};

		// Open and load video
		if (videoPath != null && videoPath.length > 0)
		{
			loadVideo(videoPath);
		}
	}

	/**
	 * Load a video file. Can be called to switch videos.
	 */
	public function loadVideo(path:String):Void
	{
		videoName = path;

		if (!decoder.open(path))
		{
			trace('[VideoSprite] Failed to load video: $path');
			visible = false;
			alive = false; // prevent FlxGroup from updating/drawing
			return;
		}

		// Create the BitmapData-backed FlxSprite
		initializeSprite();

		if (_playOnLoad)
			play();
	}

	/**
	 * Set up the FlxSprite with the decoder's BitmapData.
	 */
	function initializeSprite():Void
	{
		if (decoder.bitmapData == null) return;

		// Set up texture for BGFX
		videoTexture.init(decoder.bitmapData, 'video_$videoName');

		// Load as the sprite's graphic
		if (videoTexture.graphic != null)
		{
			loadGraphic(videoTexture.graphic);
		}

		// Auto-scale to fill the screen while maintaining aspect ratio
		if (decoder.width > 0 && decoder.height > 0)
		{
			var scaleX = FlxG.width / decoder.width;
			var scaleY = FlxG.height / decoder.height;
			var scale = Math.max(scaleX, scaleY); // Fill screen (crop edges if needed)
			setGraphicSize(Std.int(decoder.width * scale), Std.int(decoder.height * scale));
			updateHitbox();
			screenCenter();
		}

		_initialized = true;

		if (onFormatSetup != null)
			onFormatSetup();
	}

	// ══════════════════════════════════════════════════════════════
	// Playback controls
	// ══════════════════════════════════════════════════════════════

	/** Start or resume playback. */
	public function play():Void
	{
		if (decoder == null || !decoder.isValid()) return;

		decoder.play();
		paused = false;
		stopped = false;
	}

	/** Pause playback. Frame remains on screen. */
	public function pause():Void
	{
		if (decoder == null || !decoder.isValid()) return;

		decoder.pause();
		paused = true;
	}

	/** Toggle between play and pause. */
	public function togglePlayPause():Void
	{
		if (paused) play() else pause();
	}

	/** Stop playback and reset to the beginning. */
	public function stop():Void
	{
		if (decoder == null || !decoder.isValid()) return;

		decoder.stop();
		paused = false;
		stopped = true;
		_firstFrame = true;
	}

	/**
	 * Seek to a specific time.
	 * @param seconds  Time in seconds from the start of the video.
	 */
	public function seek(seconds:Float):Void
	{
		if (decoder == null || !decoder.isValid()) return;
		decoder.seek(seconds);
	}

	/**
	 * @return Current playback position in seconds.
	 */
	public function getCurrentTime():Float
	{
		return decoder != null ? decoder.currentTime : 0.0;
	}

	/**
	 * @return Total video duration in seconds.
	 */
	public function getDuration():Float
	{
		return decoder != null ? decoder.duration : 0.0;
	}

	/**
	 * @return Playback progress as a fraction [0.0, 1.0].
	 */
	public function getProgress():Float
	{
		if (decoder == null || decoder.duration <= 0.0) return 0.0;
		return decoder.currentTime / decoder.duration;
	}

	/** Resume playback (alias for play). */
	public function resume():Void { play(); }

	// ══════════════════════════════════════════════════════════════
	// Skip logic (hold-to-skip)
	// ══════════════════════════════════════════════════════════════

	function set_canSkip(val:Bool):Bool
	{
		canSkip = val;
		if (!canSkip) holdingTime = 0;
		return canSkip;
	}

	function updateSkip(elapsed:Float):Void
	{
		if (!canSkip) return;

		// Check if accept key is held
		if (Controls.instance.pressed('accept'))
		{
			holdingTime = Math.min(skipDuration, holdingTime + elapsed);
		}
		else if (holdingTime > 0)
		{
			holdingTime = Math.max(0, holdingTime - elapsed * 3);
		}

		// Fire skip when held long enough
		if (holdingTime >= skipDuration)
		{
			if (onSkip != null)
				onSkip();
			else if (finishCallback != null)
				finishCallback();
			else
				destroy();
		}
	}

	// ══════════════════════════════════════════════════════════════
	// Audio
	// ══════════════════════════════════════════════════════════════

	/**
	 * Pull decoded audio samples from the decoder.
	 * Call this every frame to keep the audio buffer filled.
	 *
	 * @param targetBuffer  Output buffer (interleaved float samples).
	 * @param maxSamples    Max sample frames to read.
	 * @return Number of sample frames written.
	 */
	public function pullAudio(targetBuffer:haxe.io.Float32Array, maxSamples:Int):Int
	{
		if (decoder == null || !decoder.isValid() || !decoder.hasAudio) return 0;
		var result = decoder.getAudio(targetBuffer, maxSamples);
		return result.samples;
	}

	// ══════════════════════════════════════════════════════════════
	// Update loop
	// ══════════════════════════════════════════════════════════════

	override function update(elapsed:Float):Void
	{
		if (_alreadyDestroyed) return;

		// Handle skip logic
		updateSkip(elapsed);

		if (decoder == null || !decoder.isValid())
		{
			super.update(elapsed);
			return;
		}

		// Update decoder (polls for new frames from decode thread).
		// NOTE: decoder.onEndReached may fire inside this call and trigger
		// finishCallback → destroy(), so check _alreadyDestroyed after.
		decoder.update(elapsed);

		if (_alreadyDestroyed) return;

		// Upload new frame to BGFX texture if available
		if (decoder.frameChanged && videoTexture != null)
		{
			videoTexture.updateFrame();
			_firstFrame = false;
		}

		if (_alreadyDestroyed) return;
		super.update(elapsed);
	}

	// ══════════════════════════════════════════════════════════════
	// Lifecycle
	// ══════════════════════════════════════════════════════════════

	override function destroy():Void
	{
		if (_alreadyDestroyed) return;
		_alreadyDestroyed = true;

		finishCallback = null;
		onSkip = null;
		onFormatSetup = null;

		if (decoder != null)
		{
			decoder.close();
			decoder = null;
		}

		if (videoTexture != null)
		{
			videoTexture.dispose();
			videoTexture = null;
		}

		// Remove from current state
		if (FlxG.state != null)
		{
			if (FlxG.state.members != null && FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if (FlxG.state.subState != null
				&& FlxG.state.subState.members != null
				&& FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}

		super.destroy();
	}
}
