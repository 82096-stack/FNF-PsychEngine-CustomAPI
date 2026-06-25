// bgfx_bridge.h — Haxe CFFI bridge for bgfx + upscaling support
//
// Provides wrapped bgfx C99 API functions that take individual primitive
// parameters instead of struct pointers, so Haxe can call them via @:native
// without complex struct marshaling.
//
// Also provides GPU vendor/architecture queries for upscaler validation.

#ifndef HXBGFX_BRIDGE_H
#define HXBGFX_BRIDGE_H

#include <bgfx/c99/bgfx.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Platform window/display handles (existing)
void* hxbgfx_get_native_window_handle(void);
void* hxbgfx_get_native_display_handle(void);
bgfx_renderer_type_t hxbgfx_get_best_renderer(void);
uint64_t hxbgfx_get_supported_renderers(void);

// bgfx_init — wrapped to take individual params
bool hxbgfx_wrapped_init(
	int rendererType, void* nwh, void* ndt,
	int width, int height, int format, int resetFlags,
	int numBackBuffers, int maxFrameLatency,
	int maxEncoders, int transientVbSize, int transientIbSize);

// Core lifecycle
void hxbgfx_wrapped_shutdown(void);
void hxbgfx_wrapped_reset(int width, int height, int resetFlags, int format,
	int numBackBuffers, int maxFrameLatency);
uint32_t hxbgfx_wrapped_frame(bool capture);
void hxbgfx_wrapped_touch(uint16_t viewId);

// View management
void hxbgfx_wrapped_set_view_rect(uint16_t viewId, uint16_t x, uint16_t y,
	uint16_t width, uint16_t height);
void hxbgfx_wrapped_set_view_clear(uint16_t viewId, uint16_t flags,
	uint32_t rgba, float depth, uint8_t stencil);
void hxbgfx_wrapped_set_view_transform(uint16_t viewId,
	const float* viewMatrix, const float* projMatrix);

// Render state & submit
void hxbgfx_wrapped_submit(uint16_t viewId, uint16_t programHandle,
	uint32_t depth, uint8_t flags);
void hxbgfx_wrapped_set_state(uint64_t state, uint32_t rgba);
void hxbgfx_wrapped_set_texture(uint8_t stage, uint16_t sampler,
	uint16_t textureHandle, uint32_t flags);
void hxbgfx_wrapped_set_uniform(uint16_t uniformHandle, const void* data, uint32_t size);

// Transient vertex buffer — returns data pointer or NULL
void* hxbgfx_wrapped_alloc_transient_vertex_buffer(
	int numVertices, int layoutHash, int layoutStride, int* outNumVertices);

// Textures
uint16_t hxbgfx_wrapped_create_texture_2d(uint16_t width, uint16_t height,
	bool hasMips, uint16_t numLayers, uint64_t format, uint64_t flags);
uint16_t hxbgfx_wrapped_create_render_texture(uint16_t width, uint16_t height,
	uint64_t format);

// Frame buffers
uint16_t hxbgfx_wrapped_create_frame_buffer(uint16_t textureHandle);
void hxbgfx_wrapped_set_view_frame_buffer(uint16_t viewId, uint16_t frameBufferHandle);

// Texture readback (for MetalFX / upscaler output)
bool hxbgfx_read_texture_bytes(uint16_t texHandle, void* outBuf, uint32_t bufSize,
	uint32_t width, uint32_t height);

// Destroy
void hxbgfx_wrapped_destroy_texture(uint16_t handle);
void hxbgfx_wrapped_destroy_frame_buffer(uint16_t handle);

// Shaders & programs
uint16_t hxbgfx_wrapped_create_shader(const void* data, uint32_t size);
uint16_t hxbgfx_wrapped_create_program(uint16_t vs, uint16_t fs, bool destroyShaders);
void hxbgfx_wrapped_destroy_program(uint16_t handle);
uint16_t hxbgfx_wrapped_create_uniform(const char* name, uint16_t type, uint16_t num);

// Renderer info
int hxbgfx_wrapped_get_renderer_type(void);
const char* hxbgfx_wrapped_get_renderer_name(int type, char* buffer, int bufferSize);

// GPU vendor / architecture queries
int hxbgfx_get_gpu_vendor(void);
int hxbgfx_get_gpu_architecture(void);
int hxbgfx_get_apple_silicon_generation(void);

// Native handle extraction (for DLSS/XeSS/MetalFX integration)
// Returns NULL if the backend doesn't support native handle access
void* hxbgfx_get_d3d12_device(void);
void* hxbgfx_get_d3d12_command_queue(void);
void* hxbgfx_get_vk_instance(void);
void* hxbgfx_get_vk_physical_device(void);
void* hxbgfx_get_vk_device(void);
void* hxbgfx_get_mtl_device(void);
// Get native texture pointer from bgfx texture handle
void* hxbgfx_get_native_texture(uint16_t texHandle);
// Get native framebuffer texture from bgfx framebuffer handle
void* hxbgfx_get_native_framebuffer_texture(uint16_t fbHandle);

#ifdef __cplusplus
}
#endif

#endif // HXBGFX_BRIDGE_H
