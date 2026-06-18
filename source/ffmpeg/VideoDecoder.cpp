/**
 * VideoDecoder.cpp — Native FFmpeg video decoder implementation.
 *
 * FFmpeg API used: avformat (demux), avcodec (decode), swscale (YUV→RGBA),
 *                  swresample (audio resample), avutil (frame/packet mgmt).
 *
 * Supported codecs: H.264 (MP4), VP9 (WebM) — extensible via FFmpeg build config.
 */

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/imgutils.h>
#include <libavutil/time.h>
#include <libavutil/opt.h>
}

// Force linker to include required system libraries and frameworks
#if defined(__APPLE__)
__asm__(".linker_option \"-lz\"");
__asm__(".linker_option \"-lbz2\"");
__asm__(".linker_option \"-liconv\"");
__asm__(".linker_option \"-framework\"");
__asm__(".linker_option \"CoreVideo\"");
__asm__(".linker_option \"-framework\"");
__asm__(".linker_option \"CoreMedia\"");
__asm__(".linker_option \"-framework\"");
__asm__(".linker_option \"VideoToolbox\"");
#endif

#include "VideoDecoder.h"
#include <cstring>

// ──────────────────────────────────────────────────────────────
// Utility: rational → double
// ──────────────────────────────────────────────────────────────
static inline double rationalToDouble(AVRational r) {
	return (r.den != 0) ? (double)r.num / (double)r.den : 0.0;
}

static inline double ptsToSeconds(int64_t pts, AVRational timeBase) {
	if (pts == AV_NOPTS_VALUE) return -1.0;
	return (double)pts * rationalToDouble(timeBase);
}

// ──────────────────────────────────────────────────────────────
// Constructor / Destructor
// ──────────────────────────────────────────────────────────────

VideoDecoder::VideoDecoder() {}

VideoDecoder::~VideoDecoder() {
	close();
}

// ──────────────────────────────────────────────────────────────
// open — open a video file and start the decode thread
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::open(const std::string& path) {
	close(); // ensure clean state

	// ── Open input ──────────────────────────────────────────
	if (avformat_open_input((AVFormatContext**)&m_formatCtx,
	                        path.c_str(), nullptr, nullptr) < 0) {
		return false;
	}

	auto* fmt = (AVFormatContext*)m_formatCtx;

	if (avformat_find_stream_info(fmt, nullptr) < 0) {
		close();
		return false;
	}

	// ── Find best video & audio streams ─────────────────────
	m_videoStreamIndex = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
	m_audioStreamIndex = av_find_best_stream(fmt, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);

	if (m_videoStreamIndex < 0) {
		close();
		return false; // no video stream
	}

	// ── Video codec ─────────────────────────────────────────
	AVStream* videoStream = fmt->streams[m_videoStreamIndex];
	const AVCodec* videoCodec = avcodec_find_decoder(videoStream->codecpar->codec_id);
	if (!videoCodec) { close(); return false; }

	m_codecCtx = avcodec_alloc_context3(videoCodec);
	if (!m_codecCtx) { close(); return false; }

	avcodec_parameters_to_context((AVCodecContext*)m_codecCtx, videoStream->codecpar);

	// Enable multi-threaded decoding
	AVCodecContext* vctx = (AVCodecContext*)m_codecCtx;
	vctx->thread_count = 0; // auto-detect optimal thread count

	if (avcodec_open2(vctx, videoCodec, nullptr) < 0) { close(); return false; }

	m_width     = vctx->width;
	m_height    = vctx->height;
	m_framerate = rationalToDouble(videoStream->avg_frame_rate);
	if (m_framerate <= 0.0 || m_framerate > 120.0) {
		m_framerate = rationalToDouble(videoStream->r_frame_rate);
	}
	if (m_framerate <= 0.0 || m_framerate > 120.0) {
		m_framerate = 30.0; // fallback
	}

	// ── Duration ────────────────────────────────────────────
	if (fmt->duration != AV_NOPTS_VALUE) {
		m_duration = (double)fmt->duration / (double)AV_TIME_BASE;
	} else if (videoStream->duration != AV_NOPTS_VALUE) {
		m_duration = ptsToSeconds(videoStream->duration, videoStream->time_base);
	}

	// ── Audio codec (if present) ────────────────────────────
	m_hasAudio = false;
	if (m_audioStreamIndex >= 0) {
		AVStream* audioStream = fmt->streams[m_audioStreamIndex];
		const AVCodec* audioCodec = avcodec_find_decoder(audioStream->codecpar->codec_id);
		if (audioCodec) {
			m_audioCodecCtx = avcodec_alloc_context3(audioCodec);
			avcodec_parameters_to_context((AVCodecContext*)m_audioCodecCtx, audioStream->codecpar);

			AVCodecContext* actx = (AVCodecContext*)m_audioCodecCtx;
			actx->thread_count = 0;

			if (avcodec_open2(actx, audioCodec, nullptr) < 0) {
				avcodec_free_context(&actx);
				m_audioCodecCtx = nullptr;
			} else {
				m_hasAudio   = true;
				m_sampleRate = actx->sample_rate;
				m_channels   = actx->ch_layout.nb_channels;
				if (m_channels <= 0) m_channels = 2; // fallback

				// Set up SwrContext for float planar → float interleaved
				AVChannelLayout outLayout = AV_CHANNEL_LAYOUT_STEREO;
				if (m_channels == 1)
					outLayout = AV_CHANNEL_LAYOUT_MONO;
				else if (m_channels > 2)
					outLayout = actx->ch_layout;

				AVChannelLayout inLayout = actx->ch_layout;
				swr_alloc_set_opts2((SwrContext**)&m_swrCtx,
				                    &outLayout, AV_SAMPLE_FMT_FLT, actx->sample_rate,
				                    &inLayout, actx->sample_fmt, actx->sample_rate,
				                    0, nullptr);
				if (m_swrCtx) swr_init((SwrContext*)m_swrCtx);
			}
		}
	}

	// ── Allocate frames ─────────────────────────────────────
	m_frame     = av_frame_alloc();
	m_rgbaFrame = av_frame_alloc();
	m_audioFrame = av_frame_alloc();

	if (!m_frame || !m_rgbaFrame) { close(); return false; }

	// Set up RGBA output frame
	AVFrame* rgba = (AVFrame*)m_rgbaFrame;
	rgba->format = AV_PIX_FMT_RGBA;
	rgba->width  = m_width;
	rgba->height = m_height;
	if (av_frame_get_buffer(rgba, 0) < 0) { close(); return false; }

	// ── Start decode thread ─────────────────────────────────
	m_running = true;
	m_ended   = false;
	m_playing = false;
	m_decodeThread = std::thread(&VideoDecoder::decodeLoop, this);

	return true;
}

// ──────────────────────────────────────────────────────────────
// close — stop decoding and free all resources
// ──────────────────────────────────────────────────────────────

void VideoDecoder::close() {
	// Stop decode thread
	m_running = false;
	m_playing = true;  // unblock decoder if it's waiting
	m_queueCV.notify_all();
	m_dataCV.notify_all();

	if (m_decodeThread.joinable()) {
		m_decodeThread.join();
	}

	// Free RGBA frame
	if (m_rgbaFrame) {
		av_frame_free((AVFrame**)&m_rgbaFrame);
		m_rgbaFrame = nullptr;
	}
	if (m_frame) {
		av_frame_free((AVFrame**)&m_frame);
		m_frame = nullptr;
	}
	if (m_audioFrame) {
		av_frame_free((AVFrame**)&m_audioFrame);
		m_audioFrame = nullptr;
	}

	// Free swscale
	if (m_swsCtx) {
		sws_freeContext((SwsContext*)m_swsCtx);
		m_swsCtx = nullptr;
	}

	// Free swresample
	if (m_swrCtx) {
		swr_free((SwrContext**)&m_swrCtx);
		m_swrCtx = nullptr;
	}

	// Free codec contexts
	if (m_codecCtx) {
		avcodec_free_context((AVCodecContext**)&m_codecCtx);
		m_codecCtx = nullptr;
	}
	if (m_audioCodecCtx) {
		avcodec_free_context((AVCodecContext**)&m_audioCodecCtx);
		m_audioCodecCtx = nullptr;
	}

	// Free format context
	if (m_formatCtx) {
		avformat_close_input((AVFormatContext**)&m_formatCtx);
		m_formatCtx = nullptr;
	}

	// Clear queues
	{
		std::lock_guard<std::mutex> lock(m_queueMutex);
		while (!m_frameQueue.empty()) m_frameQueue.pop();
		while (!m_audioQueue.empty()) m_audioQueue.pop();
	}

	m_videoStreamIndex = -1;
	m_audioStreamIndex = -1;
	m_width  = 0;
	m_height = 0;
	m_playing = false;
	m_ended   = false;
	m_seeking = false;
	m_currentTime = 0.0;
	m_lastDeliveredPts = -1.0;
	m_hasAudio = false;
}

// ──────────────────────────────────────────────────────────────
// Playback control
// ──────────────────────────────────────────────────────────────

void VideoDecoder::play() {
	m_playing = true;
	m_dataCV.notify_all();  // wake up any waiting consumer
}

void VideoDecoder::pause() {
	m_playing = false;
}

void VideoDecoder::stop() {
	m_seeking = true;
	m_seekTarget = 0.0;
	m_ended = false;
	m_playing = false;
	m_lastDeliveredPts = -1.0;

	// Drain queues
	{
		std::lock_guard<std::mutex> lock(m_queueMutex);
		while (!m_frameQueue.empty()) m_frameQueue.pop();
		while (!m_audioQueue.empty()) m_audioQueue.pop();
	}
	m_queueCV.notify_all();
}

bool VideoDecoder::seek(double seconds) {
	if (seconds < 0.0) seconds = 0.0;
	if (seconds > m_duration) seconds = m_duration;

	m_seekTarget = seconds;
	m_seeking = true;
	m_ended = false;
	m_lastDeliveredPts = -1.0;

	// Drain queues so stale frames don't appear after seek
	{
		std::lock_guard<std::mutex> lock(m_queueMutex);
		while (!m_frameQueue.empty()) m_frameQueue.pop();
		while (!m_audioQueue.empty()) m_audioQueue.pop();
	}
	m_queueCV.notify_all();

	return true;
}

// ──────────────────────────────────────────────────────────────
// getFrameRGBA — thread-safe frame retrieval for render thread
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::getFrameRGBA(uint8_t* outBuffer, int bufferSize, double* outPts) {
	if (!outBuffer || bufferSize <= 0) return false;

	std::lock_guard<std::mutex> lock(m_queueMutex);

	if (m_frameQueue.empty()) {
		if (outPts) *outPts = -1.0;
		return false;
	}

	DecodedFrame& frame = m_frameQueue.front();

	// Safety check
	int requiredSize = frame.width * frame.height * 4;
	if (bufferSize < requiredSize) {
		m_frameQueue.pop();
		return false;
	}

	std::memcpy(outBuffer, frame.data.data(), requiredSize);
	if (outPts) *outPts = frame.pts;

	m_currentTime = frame.pts;
	m_lastDeliveredPts = frame.pts;

	m_frameQueue.pop();
	m_queueCV.notify_all();  // decoder may be blocked on full queue
	return true;
}

// ──────────────────────────────────────────────────────────────
// getAudioF32 — thread-safe audio retrieval
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::getAudioF32(float* outBuffer, int maxSamples,
                               int* outChannels, int* outSampleRate,
                               int* outSamples, double* outPts) {
	if (!outBuffer || maxSamples <= 0) return false;

	std::lock_guard<std::mutex> lock(m_queueMutex);

	if (m_audioQueue.empty()) {
		if (outSamples)  *outSamples = 0;
		if (outPts)     *outPts = -1.0;
		return false;
	}

	DecodedFrame& frame = m_audioQueue.front();

	int numFloats = (int)(frame.data.size() / sizeof(float));
	int samplesToCopy = (numFloats < maxSamples * m_channels)
	                    ? (numFloats / m_channels)
	                    : maxSamples;

	std::memcpy(outBuffer, frame.data.data(), samplesToCopy * m_channels * sizeof(float));

	if (outChannels)   *outChannels   = m_channels;
	if (outSampleRate) *outSampleRate = m_sampleRate;
	if (outSamples)    *outSamples    = samplesToCopy;
	if (outPts)        *outPts        = frame.pts;

	m_audioQueue.pop();
	m_queueCV.notify_all();
	return true;
}

// ──────────────────────────────────────────────────────────────
// convertToRGBA — YUV/whatever → RGBA via swscale
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::convertToRGBA(void* framePtr) {
	AVFrame* src = (AVFrame*)framePtr;
	AVFrame* dst = (AVFrame*)m_rgbaFrame;

	if (!dst || !dst->data[0]) {
		// Re-allocate RGBA buffer (may be needed after resolution change)
		dst->format = AV_PIX_FMT_RGBA;
		dst->width  = m_width;
		dst->height = m_height;
		if (av_frame_get_buffer(dst, 0) < 0) return false;
	}

	// Create or update swscale context
	m_swsCtx = sws_getCachedContext(
		(SwsContext*)m_swsCtx,
		src->width, src->height, (AVPixelFormat)src->format,
		m_width, m_height, AV_PIX_FMT_RGBA,
		SWS_BILINEAR, nullptr, nullptr, nullptr
	);

	if (!m_swsCtx) return false;

	sws_scale((SwsContext*)m_swsCtx,
	          src->data, src->linesize, 0, src->height,
	          dst->data, dst->linesize);

	return true;
}

// ──────────────────────────────────────────────────────────────
// decodeAudioFrame
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::decodeAudioFrame(void* framePtr) {
	if (!m_audioCodecCtx) return false;

	AVFrame* af = (AVFrame*)framePtr;
	AVCodecContext* actx = (AVCodecContext*)m_audioCodecCtx;

	int outSamples = af->nb_samples;
	if (m_swrCtx) {
		outSamples = (int)av_rescale_rnd(
			swr_get_delay((SwrContext*)m_swrCtx, actx->sample_rate) + af->nb_samples,
			actx->sample_rate, actx->sample_rate, AV_ROUND_UP);
	}

	DecodedFrame outFrame;
	outFrame.data.resize(outSamples * m_channels * sizeof(float));
	outFrame.pts = ptsToSeconds(af->pts, ((AVFormatContext*)m_formatCtx)->streams[m_audioStreamIndex]->time_base);

	float* dst = (float*)outFrame.data.data();
	if (m_swrCtx) {
		const uint8_t** in = (const uint8_t**)af->data;
		uint8_t* out[1] = { (uint8_t*)dst };
		int converted = swr_convert((SwrContext*)m_swrCtx, out, outSamples, in, af->nb_samples);
		if (converted > 0) {
			outFrame.data.resize(converted * m_channels * sizeof(float));
		} else {
			return false;
		}
	} else {
		// No resampling needed — copy directly (unlikely, but handle it)
		int planeSize = af->nb_samples * sizeof(float);
		if (av_sample_fmt_is_planar((AVSampleFormat)af->format)) {
			for (int ch = 0; ch < m_channels && ch < 8; ch++) {
				for (int s = 0; s < af->nb_samples; s++) {
					dst[s * m_channels + ch] = ((float*)af->data[ch])[s];
				}
			}
		} else {
			std::memcpy(dst, af->data[0], planeSize * m_channels);
		}
		outFrame.data.resize(af->nb_samples * m_channels * sizeof(float));
	}

	std::unique_lock<std::mutex> lock(m_queueMutex);
	while ((int)m_audioQueue.size() >= MAX_AUDIO_QUEUE && m_running) {
		m_queueCV.wait_for(lock, std::chrono::milliseconds(10));
	}
	if (m_running) {
		m_audioQueue.push(std::move(outFrame));
	}
	return true;
}

// ──────────────────────────────────────────────────────────────
// decodePacket — send packet to decoder, receive frames
// ──────────────────────────────────────────────────────────────

bool VideoDecoder::decodePacket(void* packetPtr) {
	AVPacket* pkt = (AVPacket*)packetPtr;
	AVCodecContext* vctx = (AVCodecContext*)m_codecCtx;

	// Determine which stream this packet belongs to
	bool isVideo = (pkt->stream_index == m_videoStreamIndex);
	bool isAudio = (pkt->stream_index == m_audioStreamIndex && m_audioCodecCtx);
	AVCodecContext* ctx = isVideo ? vctx : (isAudio ? (AVCodecContext*)m_audioCodecCtx : nullptr);
	if (!ctx) return false;

	int ret = avcodec_send_packet(ctx, pkt);
	if (ret < 0) return false;

	while (ret >= 0) {
		AVFrame* frame = (isVideo ? (AVFrame*)m_frame : (AVFrame*)m_audioFrame);
		av_frame_unref(frame);
		ret = avcodec_receive_frame(ctx, frame);

		if (ret == AVERROR(EAGAIN)) {
			break; // need more packets
		} else if (ret == AVERROR_EOF) {
			// Flush remaining frames
			avcodec_send_packet(ctx, nullptr);
			continue;
		} else if (ret < 0) {
			break;
		}

		if (isVideo) {
			// Convert YUV → RGBA
			if (!convertToRGBA(frame)) continue;

			AVFrame* rgba = (AVFrame*)m_rgbaFrame;
			double pts = ptsToSeconds(frame->pts,
				((AVFormatContext*)m_formatCtx)->streams[m_videoStreamIndex]->time_base);
			if (pts < 0.0 && rgba->pkt_dts != AV_NOPTS_VALUE) {
				pts = ptsToSeconds(rgba->pkt_dts,
					((AVFormatContext*)m_formatCtx)->streams[m_videoStreamIndex]->time_base);
			}

			// Build frame entry
			DecodedFrame df;
			df.width  = m_width;
			df.height = m_height;
			df.pts    = pts;

			int dataSize = m_width * m_height * 4;
			df.data.resize(dataSize);

			// Copy from AVFrame's lines (with stride) into contiguous buffer
			uint8_t* dst = df.data.data();
			for (int y = 0; y < m_height; y++) {
				std::memcpy(dst + y * m_width * 4,
				            rgba->data[0] + y * rgba->linesize[0],
				            m_width * 4);
			}

			// Push to queue (block if full)
			{
				std::unique_lock<std::mutex> lock(m_queueMutex);
				while ((int)m_frameQueue.size() >= MAX_QUEUE_SIZE && m_running) {
					m_queueCV.wait_for(lock, std::chrono::milliseconds(10));
				}
				if (m_running) {
					m_frameQueue.push(std::move(df));
					m_dataCV.notify_one();
				}
			}
		} else if (isAudio) {
			decodeAudioFrame(frame);
		}
	}

	return true;
}

// ──────────────────────────────────────────────────────────────
// decodeLoop — runs on dedicated thread
// ──────────────────────────────────────────────────────────────

void VideoDecoder::decodeLoop() {
	AVFormatContext* fmt = (AVFormatContext*)m_formatCtx;

	while (m_running) {
		// ── Handle seek ────────────────────────────────────
		if (m_seeking.exchange(false)) {
			double targetSec = m_seekTarget;

			// Seek to keyframe before target in video stream
			int ret = av_seek_frame(fmt, m_videoStreamIndex,
			                        (int64_t)(targetSec * rationalToDouble(
			                            fmt->streams[m_videoStreamIndex]->time_base)),
			                        AVSEEK_FLAG_BACKWARD);
			if (ret >= 0) {
				avcodec_flush_buffers((AVCodecContext*)m_codecCtx);
				if (m_audioCodecCtx) avcodec_flush_buffers((AVCodecContext*)m_audioCodecCtx);
			}

			// Drain queues
			{
				std::lock_guard<std::mutex> lock(m_queueMutex);
				while (!m_frameQueue.empty()) m_frameQueue.pop();
				while (!m_audioQueue.empty()) m_audioQueue.pop();
			}
			m_queueCV.notify_all();

			// Decode forward to target timestamp
			AVPacket* seekPkt = av_packet_alloc();
			bool seekDone = false;
			while (!seekDone && m_running && !m_seeking) {
				int readRet = av_read_frame(fmt, seekPkt);
				if (readRet < 0) { seekDone = true; break; }
				if (seekPkt->stream_index == m_videoStreamIndex) {
					double pktTime = ptsToSeconds(seekPkt->pts,
						fmt->streams[m_videoStreamIndex]->time_base);
					if (pktTime >= targetSec - 0.1) {
						decodePacket(seekPkt);
						seekDone = true;
					}
				}
				av_packet_unref(seekPkt);
			}
			av_packet_free(&seekPkt);
			continue;
		}

		// ── If paused, sleep briefly ───────────────────────
		if (!m_playing) {
			std::this_thread::sleep_for(std::chrono::milliseconds(16));
			continue;
		}

		// ── Read next packet ───────────────────────────────
		AVPacket* pkt = av_packet_alloc();
		int readRet = av_read_frame(fmt, pkt);

		if (readRet < 0) {
			av_packet_free(&pkt);
			if (readRet == AVERROR_EOF) {
				// Flush decoders
				AVPacket* nullPkt = av_packet_alloc();
				nullPkt->stream_index = m_videoStreamIndex;
				nullPkt->data = nullptr;
				nullPkt->size = 0;
				decodePacket(nullPkt);
				av_packet_free(&nullPkt);

				if (m_audioCodecCtx) {
					nullPkt = av_packet_alloc();
					nullPkt->stream_index = m_audioStreamIndex;
					nullPkt->data = nullptr;
					nullPkt->size = 0;
					decodePacket(nullPkt);
					av_packet_free(&nullPkt);
				}

				m_ended = true;
				m_playing = false;
			}
			break;
		}

		// Only process video and audio streams
		if (pkt->stream_index == m_videoStreamIndex ||
		    (pkt->stream_index == m_audioStreamIndex && m_audioCodecCtx)) {
			decodePacket(pkt);
		}

		av_packet_unref(pkt);
		av_packet_free(&pkt);
	}
}

// ══════════════════════════════════════════════════════════════
// C ABI Implementation
// ══════════════════════════════════════════════════════════════

extern "C" {

void* ffmpeg_decoder_create() {
	return new VideoDecoder();
}

void ffmpeg_decoder_destroy(void* dec) {
	if (dec) delete (VideoDecoder*)dec;
}

bool ffmpeg_decoder_open(void* dec, const char* path) {
	if (!dec || !path) return false;
	return ((VideoDecoder*)dec)->open(std::string(path));
}

void ffmpeg_decoder_close(void* dec) {
	if (dec) ((VideoDecoder*)dec)->close();
}

void ffmpeg_decoder_play(void* dec) {
	if (dec) ((VideoDecoder*)dec)->play();
}

void ffmpeg_decoder_pause(void* dec) {
	if (dec) ((VideoDecoder*)dec)->pause();
}

void ffmpeg_decoder_stop(void* dec) {
	if (dec) ((VideoDecoder*)dec)->stop();
}

bool ffmpeg_decoder_seek(void* dec, double seconds) {
	if (!dec) return false;
	return ((VideoDecoder*)dec)->seek(seconds);
}

bool ffmpeg_decoder_is_playing(void* dec) {
	if (!dec) return false;
	return ((VideoDecoder*)dec)->isPlaying();
}

bool ffmpeg_decoder_has_ended(void* dec) {
	if (!dec) return true;
	return ((VideoDecoder*)dec)->hasEnded();
}

double ffmpeg_decoder_get_duration(void* dec) {
	if (!dec) return 0.0;
	return ((VideoDecoder*)dec)->getDuration();
}

double ffmpeg_decoder_get_current_time(void* dec) {
	if (!dec) return 0.0;
	return ((VideoDecoder*)dec)->getCurrentTime();
}

int ffmpeg_decoder_get_width(void* dec) {
	if (!dec) return 0;
	return ((VideoDecoder*)dec)->getWidth();
}

int ffmpeg_decoder_get_height(void* dec) {
	if (!dec) return 0;
	return ((VideoDecoder*)dec)->getHeight();
}

double ffmpeg_decoder_get_framerate(void* dec) {
	if (!dec) return 30.0;
	return ((VideoDecoder*)dec)->getFramerate();
}

bool ffmpeg_decoder_has_audio(void* dec) {
	if (!dec) return false;
	return ((VideoDecoder*)dec)->hasAudio();
}

int ffmpeg_decoder_get_sample_rate(void* dec) {
	if (!dec) return 0;
	return ((VideoDecoder*)dec)->getSampleRate();
}

int ffmpeg_decoder_get_channels(void* dec) {
	if (!dec) return 0;
	return ((VideoDecoder*)dec)->getChannels();
}

bool ffmpeg_decoder_get_frame_rgba(void* dec, uint8_t* buffer, int bufferSize, double* outPts) {
	if (!dec || !buffer) return false;
	return ((VideoDecoder*)dec)->getFrameRGBA(buffer, bufferSize, outPts);
}

bool ffmpeg_decoder_get_audio_f32(void* dec, float* buffer, int maxSamples,
                                  int* outChannels, int* outSampleRate,
                                  int* outSamples, double* outPts) {
	if (!dec || !buffer) return false;
	return ((VideoDecoder*)dec)->getAudioF32(buffer, maxSamples,
	                                         outChannels, outSampleRate,
	                                         outSamples, outPts);
}

} // extern "C"
