package ffmpeg;

#if cpp
import cpp.Pointer;
import cpp.RawPointer;
import haxe.io.Bytes;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;

/**
 * FFmpegVideoDecoder — Haxe CFFI bridge to the native FFmpeg video decoder.
 *
 * This class wraps the C ABI defined in VideoDecoder.h / VideoDecoder.cpp.
 * It manages an opaque native decoder handle and provides a Haxe-friendly
 * API for video playback.
 *
 * Thread model:
 *   - Native decode loop runs on its own thread (managed by C++ VideoDecoder)
 *   - Haxe update() is called on the main/render thread each frame
 *   - Frame data is copied into a Haxe-managed BitmapData for BGFX upload
 *
 * Usage:
 *   var dec = new FFmpegVideoDecoder();
 *   dec.open("videos/intro.mp4");
 *   dec.play();
 *   // In update loop:
 *   dec.update(elapsed);
 *   if (dec.frameChanged) {
 *       uploadToBGFX(dec.bitmapData);
 *   }
 *   // When done:
 *   dec.close();
 */
@:headerCode('
// C ABI forward declarations for native FFmpeg video decoder.
// Inlined to avoid include-path issues during hxcpp C++ compilation.
extern "C" {
	void*  ffmpeg_decoder_create();
	void   ffmpeg_decoder_destroy(void* dec);
	bool   ffmpeg_decoder_open(void* dec, const char* path);
	void   ffmpeg_decoder_close(void* dec);
	void   ffmpeg_decoder_play(void* dec);
	void   ffmpeg_decoder_pause(void* dec);
	void   ffmpeg_decoder_stop(void* dec);
	bool   ffmpeg_decoder_seek(void* dec, double seconds);
	bool   ffmpeg_decoder_is_playing(void* dec);
	bool   ffmpeg_decoder_has_ended(void* dec);
	double ffmpeg_decoder_get_duration(void* dec);
	double ffmpeg_decoder_get_current_time(void* dec);
	int    ffmpeg_decoder_get_width(void* dec);
	int    ffmpeg_decoder_get_height(void* dec);
	double ffmpeg_decoder_get_framerate(void* dec);
	bool   ffmpeg_decoder_has_audio(void* dec);
	int    ffmpeg_decoder_get_sample_rate(void* dec);
	int    ffmpeg_decoder_get_channels(void* dec);
	bool   ffmpeg_decoder_get_frame_rgba(void* dec, unsigned char* buffer, int bufferSize, double* outPts);
	bool   ffmpeg_decoder_get_audio_f32(void* dec, float* buffer, int maxSamples,
	                                    int* outChannels, int* outSampleRate,
	                                    int* outSamples, double* outPts);
}
')
@:buildXml('
<compilerflag value="-I../../../../source" />
<compilerflag value="-I../../../../include" />
<file name="../../../../source/ffmpeg/VideoDecoder.cpp" />
<target id="haxe">
	<lib name="../../../../libs/ffmpeg/lib/macos/libVideoDecoder.a" />
</target>
')
class FFmpegVideoDecoder
{
	// ── Native handle ──────────────────────────────────────────────
	var handle:Pointer<Void>;

	// ── Video properties ───────────────────────────────────────────
	public var width(default, null):Int = 0;
	public var height(default, null):Int = 0;
	public var framerate(default, null):Float = 30.0;
	public var duration(default, null):Float = 0.0;
	public var hasAudio(default, null):Bool = false;
	public var sampleRate(default, null):Int = 0;
	public var channels(default, null):Int = 0;

	// ── Playback state ────────────────────────────────────────────
	public var isPlaying(default, null):Bool = false;
	public var hasEnded(default, null):Bool = false;
	public var currentTime(default, null):Float = 0.0;
	public var frameChanged(default, null):Bool = false;

	// ── Pixel data ────────────────────────────────────────────────
	public var bitmapData(default, null):BitmapData = null;

	// ── Callbacks ────────────────────────────────────────────────
	public var onEndReached:Void->Void = null;

	// Internal
	var rgbaBytes:Bytes;
	var rgbaByteArray:ByteArray;
	var ptsBuf:Pointer<Float>;
	var lastPts:Float = -1.0;
	var endFired:Bool = false;

	// ══════════════════════════════════════════════════════════════
	// Native CFFI bindings
	// ══════════════════════════════════════════════════════════════

	@:native('ffmpeg_decoder_create')
	static function _create():Pointer<Void> return null;

	@:native('ffmpeg_decoder_destroy')
	static function _destroy(dec:Pointer<Void>):Void {}

	@:native('ffmpeg_decoder_open')
	static function _open(dec:Pointer<Void>, path:cpp.ConstCharStar):Bool return false;

	@:native('ffmpeg_decoder_close')
	static function _close(dec:Pointer<Void>):Void {}

	@:native('ffmpeg_decoder_play')
	static function _play(dec:Pointer<Void>):Void {}

	@:native('ffmpeg_decoder_pause')
	static function _pause(dec:Pointer<Void>):Void {}

	@:native('ffmpeg_decoder_stop')
	static function _stop(dec:Pointer<Void>):Void {}

	@:native('ffmpeg_decoder_seek')
	static function _seek(dec:Pointer<Void>, seconds:Float):Bool return false;

	@:native('ffmpeg_decoder_is_playing')
	static function _isPlaying(dec:Pointer<Void>):Bool return false;

	@:native('ffmpeg_decoder_has_ended')
	static function _hasEnded(dec:Pointer<Void>):Bool return false;

	@:native('ffmpeg_decoder_get_duration')
	static function _getDuration(dec:Pointer<Void>):Float return 0.0;

	@:native('ffmpeg_decoder_get_current_time')
	static function _getCurrentTime(dec:Pointer<Void>):Float return 0.0;

	@:native('ffmpeg_decoder_get_width')
	static function _getWidth(dec:Pointer<Void>):Int return 0;

	@:native('ffmpeg_decoder_get_height')
	static function _getHeight(dec:Pointer<Void>):Int return 0;

	@:native('ffmpeg_decoder_get_framerate')
	static function _getFramerate(dec:Pointer<Void>):Float return 30.0;

	@:native('ffmpeg_decoder_has_audio')
	static function _hasAudio(dec:Pointer<Void>):Bool return false;

	@:native('ffmpeg_decoder_get_sample_rate')
	static function _getSampleRate(dec:Pointer<Void>):Int return 0;

	@:native('ffmpeg_decoder_get_channels')
	static function _getChannels(dec:Pointer<Void>):Int return 0;

	@:native('ffmpeg_decoder_get_frame_rgba')
	static function _getFrameRGBA(dec:Pointer<Void>, buffer:RawPointer<cpp.UInt8>, bufferSize:Int, outPts:RawPointer<Float>):Bool return false;

	@:native('ffmpeg_decoder_get_audio_f32')
	static function _getAudioF32(dec:Pointer<Void>, buffer:RawPointer<cpp.Float32>, maxSamples:Int,
	                             outChannels:RawPointer<cpp.Int32>, outSampleRate:RawPointer<cpp.Int32>,
	                             outSamples:RawPointer<cpp.Int32>, outPts:RawPointer<Float>):Bool return false;

	// ══════════════════════════════════════════════════════════════
	// Public API
	// ══════════════════════════════════════════════════════════════

	public function new()
	{
		handle = _create();
		ptsBuf = cpp.Pointer.fromRaw(RawPointer.addressOf(lastPts));
	}

	/**
	 * Open a video file and start background decoding.
	 * @param path  Absolute path to the video file.
	 * @return true on success.
	 */
	public function open(path:String):Bool
	{
		if (handle == null) return false;

		if (!_open(handle, untyped path.c_str()))
		{
			trace('[FFmpegVideoDecoder] Failed to open: $path');
			return false;
		}

		width      = _getWidth(handle);
		height     = _getHeight(handle);
		framerate  = _getFramerate(handle);
		duration   = _getDuration(handle);
		hasAudio   = _hasAudio(handle);
		sampleRate = _getSampleRate(handle);
		channels   = _getChannels(handle);

		if (width <= 0 || height <= 0)
		{
			trace('[FFmpegVideoDecoder] Invalid video dimensions: ${width}x${height}');
			_close(handle);
			return false;
		}

		// Allocate RGBA pixel buffer
		var bufSize = width * height * 4;
		rgbaBytes = Bytes.alloc(bufSize);
		rgbaByteArray = ByteArray.fromBytes(rgbaBytes);

		// Create BitmapData (BGRA format for BGFX)
		bitmapData = new BitmapData(width, height, true, 0x00000000);

		endFired = false;
		frameChanged = false;

		trace('[FFmpegVideoDecoder] Opened: $path (${width}x${height}, ${framerate}fps, ${duration}s)');
		return true;
	}

	/**
	 * Close the decoder and free all resources.
	 */
	public function close():Void
	{
		if (handle != null)
		{
			_close(handle);
			_destroy(handle);
			handle = null;
		}

		if (bitmapData != null)
		{
			bitmapData.dispose();
			bitmapData = null;
		}

		rgbaBytes = null;
		rgbaByteArray = null;
		width = 0;
		height = 0;
		isPlaying = false;
		hasEnded = false;
		frameChanged = false;
		endFired = false;
	}

	/**
	 * Start or resume playback.
	 */
	public function play():Void
	{
		if (handle != null)
		{
			_play(handle);
			isPlaying = true;
			hasEnded = false;
			endFired = false;
		}
	}

	/**
	 * Pause playback. Decode thread continues but doesn't advance.
	 */
	public function pause():Void
	{
		if (handle != null)
		{
			_pause(handle);
			isPlaying = false;
		}
	}

	/**
	 * Stop playback and reset to beginning.
	 */
	public function stop():Void
	{
		if (handle != null)
		{
			_stop(handle);
			isPlaying = false;
			hasEnded = false;
			endFired = false;
			frameChanged = false;
			lastPts = -1.0;
		}
	}

	/**
	 * Seek to a specific time position.
	 * @param seconds  Target time in seconds.
	 * @return true if seek was initiated (seek happens asynchronously).
	 */
	public function seek(seconds:Float):Bool
	{
		if (handle != null)
		{
			var clamped = seconds;
			if (clamped < 0.0) clamped = 0.0;
			if (clamped > duration) clamped = duration;
			return _seek(handle, clamped);
		}
		return false;
	}

	/**
	 * Called every frame from the main/render thread.
	 * Polls for new decoded frames and updates bitmapData.
	 *
	 * @param elapsed  Time since last frame (unused; frame timing is PTS-driven).
	 */
	public function update(elapsed:Float):Void
	{
		if (handle == null) return;

		isPlaying  = _isPlaying(handle);
		hasEnded   = _hasEnded(handle);
		currentTime = _getCurrentTime(handle);
		frameChanged = false;

		if (bitmapData == null || rgbaBytes == null) return;

		// Try to get a new frame from the decode thread
		var rawPtr:RawPointer<cpp.UInt8> = untyped __cpp__('(unsigned char*){0}->b->Pointer()', rgbaBytes);
		var ptsPtr:RawPointer<Float> = untyped ptsBuf.raw;
		var gotFrame = _getFrameRGBA(handle, rawPtr, rgbaBytes.length, ptsPtr);

		if (gotFrame && lastPts != ptsBuf.ref)
		{
			lastPts = ptsBuf.ref;

			// Copy RGBA bytes into BitmapData
			// (OpenFL's BitmapData.setPixels expects BGRA byte order on native targets)
			#if (cpp && !openfl_disable_bgra_fix)
			// Swizzle RGBA → BGRA for BGFX
			swizzleRGBAToBGRA(rgbaBytes, width, height);
			#end

			rgbaByteArray.position = 0;
			bitmapData.setPixels(bitmapData.rect, rgbaByteArray);
			currentTime = lastPts;
			frameChanged = true;
		}
		else if (hasEnded && !endFired)
		{
			endFired = true;
			if (onEndReached != null)
				onEndReached();
		}
	}

	/**
	 * Called every frame for audio retrieval.
	 * @param outBuffer  Pre-allocated float buffer (interleaved samples).
	 * @param maxSamples Maximum sample frames the buffer can hold.
	 * @return Actual number of sample frames written (0 if none available).
	 */
	public function getAudio(outBuffer:haxe.io.Float32Array, maxSamples:Int):{samples:Int, pts:Float}
	{
		if (handle == null || outBuffer == null)
			return {samples: 0, pts: -1.0};

		var buf:Bytes = outBuffer.view.buffer;
		var off:Int = outBuffer.view.byteOffset;
		var rawBuf:RawPointer<cpp.Float32> = untyped __cpp__('(float*)((unsigned char*){0}->b->Pointer() + {1})', buf, off);
		var outCh:RawPointer<cpp.Int32> = untyped RawPointer.addressOf(channels);
		var outSr:RawPointer<cpp.Int32> = untyped RawPointer.addressOf(sampleRate);
		var _tmpSm:Int = 0;
		var outSm:RawPointer<cpp.Int32> = untyped RawPointer.addressOf(_tmpSm);
		var ptsRaw:RawPointer<Float> = untyped ptsBuf.raw;

		var got = _getAudioF32(handle, rawBuf, maxSamples,
		                        outCh, outSr,
		                        outSm,
		                        ptsRaw);

		var samplesWritten:Int = _tmpSm;
		return {samples: got ? samplesWritten : 0, pts: got ? ptsBuf.ref : -1.0};
	}

	// ══════════════════════════════════════════════════════════════
	// Internal
	// ══════════════════════════════════════════════════════════════

	/**
	 * Convert RGBA byte order to BGRA for BGFX texture format (BGRA8).
	 * Swaps R and B channels in-place.
	 */
	static function swizzleRGBAToBGRA(bytes:Bytes, w:Int, h:Int):Void
	{
		var len = w * h * 4;
		for (i in 0...len)
		{
			if (i % 4 == 0)
			{
				// Swap R (i) and B (i+2)
				var tmp = bytes.get(i);
				bytes.set(i, bytes.get(i + 2));
				bytes.set(i + 2, tmp);
			}
		}
	}

	/**
	 * @return true if the decoder handle is valid and a video is loaded.
	 */
	public function isValid():Bool
	{
		return handle != null && bitmapData != null;
	}
}
#else
/**
 * FFmpegVideoDecoder — stub implementation for non-CPP targets.
 * Video playback is only supported on native (CPP) platforms.
 */
class FFmpegVideoDecoder
{
	public var width(default, null):Int = 0;
	public var height(default, null):Int = 0;
	public var framerate(default, null):Float = 30.0;
	public var duration(default, null):Float = 0.0;
	public var hasAudio(default, null):Bool = false;
	public var sampleRate(default, null):Int = 0;
	public var channels(default, null):Int = 0;
	public var isPlaying(default, null):Bool = false;
	public var hasEnded(default, null):Bool = false;
	public var currentTime(default, null):Float = 0.0;
	public var frameChanged(default, null):Bool = false;
	public var bitmapData(default, null):openfl.display.BitmapData = null;
	public var onEndReached:Void->Void = null;

	public function new() {}
	public function open(path:String):Bool return false;
	public function close():Void {}
	public function play():Void {}
	public function pause():Void {}
	public function stop():Void {}
	public function seek(seconds:Float):Bool return false;
	public function update(elapsed:Float):Void {}
	public function getAudio(outBuffer:haxe.io.Float32Array, maxSamples:Int):{samples:Int, pts:Float} {
		return {samples: 0, pts: -1.0};
	}
	public function isValid():Bool return false;
}
#end
