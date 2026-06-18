/**
 * VideoDecoder.h — Native FFmpeg-based video decoder for Psych Engine.
 *
 * Architecture:
 *   Decode thread  ──(frame queue)──>  Render thread
 *   (avcodec)                           (Haxe / BGFX)
 *
 * Supports: MP4 (H.264), WebM (VP9)
 * Output:   RGBA pixel buffer (8-bit per channel)
 *
 * Thread safety:
 *   - open/close/play/pause/stop/seek: call from main thread
 *   - getFrameRGBA: call from render thread (thread-safe with decode loop)
 *   - The decode loop runs on a dedicated thread, pushes frames into a
 *     mutex-protected queue consumed by getFrameRGBA.
 */

#pragma once

#include <cstdint>
#include <string>
#include <atomic>
#include <mutex>
#include <condition_variable>
#include <vector>
#include <queue>
#include <thread>

// ──────────────────────────────────────────────────────────────
// Frame queue entry
// ──────────────────────────────────────────────────────────────
struct DecodedFrame {
	std::vector<uint8_t> data;  // RGBA pixels (width * height * 4)
	double pts = 0.0;           // Presentation timestamp (seconds)
	int width = 0;
	int height = 0;
};

// ──────────────────────────────────────────────────────────────
// VideoDecoder — opaque handle, only accessed via C ABI below
// ──────────────────────────────────────────────────────────────
class VideoDecoder {
public:
	VideoDecoder();
	~VideoDecoder();

	bool open(const std::string& path);
	void close();

	void play();
	void pause();
	void stop();
	bool seek(double seconds);

	bool isPlaying()           const { return m_playing.load(); }
	bool hasEnded()            const { return m_ended.load(); }
	double getDuration()       const { return m_duration; }
	double getCurrentTime()    const { return m_currentTime.load(); }
	int  getWidth()            const { return m_width; }
	int  getHeight()           const { return m_height; }
	double getFramerate()      const { return m_framerate; }
	bool  hasAudio()           const { return m_hasAudio; }
	int   getSampleRate()      const { return m_sampleRate; }
	int   getChannels()        const { return m_channels; }

	/**
	 * Copy the latest decoded RGBA frame into a caller-provided buffer.
	 *
	 * @param outBuffer  Pre-allocated buffer (must hold width * height * 4 bytes)
	 * @param bufferSize Size of outBuffer in bytes (safety check)
	 * @param outPts     [out] Presentation timestamp of this frame (seconds),
	 *                   may be null.
	 * @return true if a new frame was copied, false if no new frame is available.
	 */
	bool getFrameRGBA(uint8_t* outBuffer, int bufferSize, double* outPts);

	/**
	 * Copy the latest decoded audio samples into a caller-provided buffer.
	 *
	 * @param outBuffer     Pre-allocated buffer (float planar: LRLRLR...)
	 * @param maxSamples    Maximum number of *sample frames* the buffer can hold
	 * @param outChannels   [out] Number of channels
	 * @param outSampleRate [out] Sample rate
	 * @param outSamples    [out] Number of sample frames actually written
	 * @param outPts        [out] PTS of first sample (seconds), may be null
	 * @return true if audio data was available
	 */
	bool getAudioF32(float* outBuffer, int maxSamples,
	                 int* outChannels, int* outSampleRate,
	                 int* outSamples, double* outPts);

private:
	void decodeLoop();
	bool decodePacket(void* packet);     // AVPacket*
	bool convertToRGBA(void* frame);     // AVFrame*
	bool decodeAudioFrame(void* frame);  // AVFrame*

	// FFmpeg types are forward-declared as opaque void* to avoid
	// exposing FFmpeg headers in this public header.
	// Actual types: AVFormatContext, AVCodecContext, SwsContext,
	//               AVFrame, SwrContext, AVPacket
	void* m_formatCtx = nullptr;
	void* m_codecCtx  = nullptr;
	void* m_swsCtx    = nullptr;
	void* m_frame     = nullptr;
	void* m_rgbaFrame = nullptr;
	void* m_audioCodecCtx = nullptr;
	void* m_swrCtx    = nullptr;
	void* m_audioFrame = nullptr;
	int m_videoStreamIndex = -1;
	int m_audioStreamIndex = -1;

	// ── State ──────────────────────────────────────────────
	std::atomic<bool> m_playing{false};
	std::atomic<bool> m_ended{false};
	std::atomic<bool> m_seeking{false};
	double m_seekTarget = 0.0;

	// ── Video properties ───────────────────────────────────
	int    m_width       = 0;
	int    m_height      = 0;
	double m_duration    = 0.0;
	std::atomic<double> m_currentTime{0.0};
	double m_framerate   = 30.0;
	bool   m_hasAudio    = false;
	int    m_sampleRate  = 0;
	int    m_channels    = 0;

	// PTS of latest frame delivered via getFrameRGBA
	double m_lastDeliveredPts = -1.0;

	// ── Frame queue (decode thread → render thread) ───────
	static constexpr int MAX_QUEUE_SIZE = 8;
	std::queue<DecodedFrame> m_frameQueue;
	std::queue<DecodedFrame> m_audioQueue;
	static constexpr int MAX_AUDIO_QUEUE = 16;
	mutable std::mutex m_queueMutex;
	std::condition_variable m_queueCV;   // signaled when queue not full
	std::condition_variable m_dataCV;    // signaled when queue not empty

	// ── Threading ─────────────────────────────────────────
	std::thread m_decodeThread;
	std::atomic<bool> m_running{false};
};

// ──────────────────────────────────────────────────────────────
// C ABI — called from Haxe via hxcpp CFFI (@:native)
// ──────────────────────────────────────────────────────────────
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

/**
 * Get the latest RGBA video frame.
 *
 * @param dec        Decoder handle
 * @param buffer     Pre-allocated output buffer (width * height * 4 bytes)
 * @param bufferSize Size of buffer in bytes
 * @param outPts     [out, nullable] Frame PTS in seconds
 * @return true if a new frame was copied into buffer
 */
bool   ffmpeg_decoder_get_frame_rgba(void* dec, uint8_t* buffer, int bufferSize, double* outPts);

/**
 * Get the latest audio samples.
 *
 * @param dec          Decoder handle
 * @param buffer       Pre-allocated float buffer
 * @param maxSamples   Max sample frames the buffer holds
 * @param outChannels  [out] Channel count
 * @param outSampleRate[out] Sample rate (Hz)
 * @param outSamples   [out] Actual sample frames written
 * @param outPts       [out, nullable] PTS of first sample
 * @return true if audio data was available
 */
bool   ffmpeg_decoder_get_audio_f32(void* dec, float* buffer, int maxSamples,
                                    int* outChannels, int* outSampleRate,
                                    int* outSamples, double* outPts);

} // extern "C"
