// bgfx_bridge_impl.cpp — inline implementations for Haxe @:native bridge
// This file is #included via @:cppFileCode in BgfxAPI.hx.
// Declarations come from @:headerCode (no bgfx_bridge.h needed).
// Uses bgfx C99 API internally.
#include <bgfx/c99/bgfx.h>
#include <SDL.h>
#include <string.h>
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_MAC
#include <Cocoa/Cocoa.h>
#endif
#include <bgfx/bgfx.h>
#elif defined(__linux__)
#include <X11/Xlib.h>
#include <bgfx/bgfx.h>
#endif

// ── SDL window ────────────────────────────────────────────────────
static SDL_Window* get_sdl_window(void) {
    SDL_Window* win = SDL_GL_GetCurrentWindow();
    if (win != NULL) return win;
    win = SDL_GetWindowFromID(1);
    if (win != NULL) return win;
    return NULL;
}

// ── Platform native handles ───────────────────────────────────────
void* hxbgfx_get_native_window_handle(void) {
    SDL_Window* win = get_sdl_window();
    if (win == NULL) return NULL;
    SDL_SysWMinfo wmi;
    SDL_VERSION(&wmi.version);
    if (!SDL_GetWindowWMInfo(win, &wmi)) return NULL;
#ifdef _WIN32
    return (void*)wmi.info.win.window;
#elif defined(__APPLE__)
    return (void*)wmi.info.cocoa.window;
#elif defined(__linux__)
    return (void*)(uintptr_t)wmi.info.x11.window;
#else
    return NULL;
#endif
}

void* hxbgfx_get_native_display_handle(void) {
#ifdef _WIN32
    return GetDC((HWND)hxbgfx_get_native_window_handle());
#else
    return NULL;
#endif
}

// ── bgfx wrapped functions ────────────────────────────────────────
bool hxbgfx_wrapped_init(
    int rendererType, void* nwh, void* ndt,
    int width, int height, int format, int resetFlags,
    int numBackBuffers, int maxFrameLatency,
    int maxEncoders, int transientVbSize, int transientIbSize)
{
    bgfx_init_t init;
    bgfx_init_ctor(&init);
    init.type = (bgfx_renderer_type_t)rendererType;
    init.resolution.width = width;
    init.resolution.height = height;
    init.resolution.format = (bgfx_texture_format_t)format;
    init.resolution.reset = resetFlags;
    init.resolution.numBackBuffers = (uint8_t)numBackBuffers;
    init.resolution.maxFrameLatency = (uint8_t)maxFrameLatency;
    init.platformData.nwh = nwh;
    init.platformData.ndt = ndt;
    init.limits.maxEncoders = (uint16_t)maxEncoders;
    init.limits.transientVbSize = (uint32_t)transientVbSize;
    init.limits.transientIbSize = (uint32_t)transientIbSize;
    return bgfx_init(&init);
}

void hxbgfx_wrapped_shutdown(void) { bgfx_shutdown(); }

void hxbgfx_wrapped_reset(int w, int h, int flags, int fmt, int nbb, int mfl) {
    bgfx_reset((uint32_t)w, (uint32_t)h, (uint32_t)flags, (bgfx_texture_format_t)fmt);
}

uint32_t hxbgfx_wrapped_frame(bool capture) { return bgfx_frame(capture); }

void hxbgfx_wrapped_touch(uint16_t viewId) { bgfx_touch(viewId); }

void hxbgfx_wrapped_set_view_rect(uint16_t viewId, uint16_t x, uint16_t y,
    uint16_t width, uint16_t height) {
    bgfx_set_view_rect(viewId, x, y, width, height);
}

void hxbgfx_wrapped_set_view_clear(uint16_t viewId, uint16_t flags,
    uint32_t rgba, float depth, uint8_t stencil) {
    bgfx_set_view_clear(viewId, flags, rgba, depth, stencil);
}

void hxbgfx_wrapped_set_view_transform(uint16_t viewId,
    const float* viewMatrix, const float* projMatrix) {
    bgfx_set_view_transform(viewId, viewMatrix, projMatrix);
}

void hxbgfx_wrapped_submit(uint16_t viewId, uint16_t programHandle,
    uint32_t depth, uint8_t flags) {
    bgfx_submit(viewId, programHandle, depth, flags);
}

void hxbgfx_wrapped_set_state(uint64_t state, uint32_t rgba) {
    bgfx_set_state(state, rgba);
}

void hxbgfx_wrapped_set_texture(uint8_t stage, uint16_t sampler,
    uint16_t textureHandle, uint32_t flags) {
    bgfx_set_texture(stage, sampler, textureHandle, flags);
}

void hxbgfx_wrapped_set_uniform(uint16_t uniformHandle, const void* data, uint32_t size) {
    bgfx_set_uniform((bgfx_uniform_handle_t){uniformHandle}, data, size);
}

void hxbgfx_wrapped_set_view_frame_buffer(uint16_t viewId, uint16_t fbHandle) {
    bgfx_set_view_frame_buffer(viewId, (bgfx_frame_buffer_handle_t){fbHandle});
}

void* hxbgfx_wrapped_alloc_transient_vertex_buffer(
    int numVertices, int layoutHash, int layoutStride, int* outNumVertices)
{
    bgfx_vertex_layout_t layout;
    layout.hash = (uint32_t)layoutHash;
    layout.stride = (uint16_t)layoutStride;
    bgfx_transient_vertex_buffer_t tvb;
    bgfx_alloc_transient_vertex_buffer(&tvb, (uint32_t)numVertices, &layout);
    if (outNumVertices) *outNumVertices = (int)tvb.size / layoutStride;
    return tvb.data;
}

uint16_t hxbgfx_wrapped_create_texture_2d(uint16_t w, uint16_t h,
    bool mips, uint16_t layers, uint64_t fmt, uint64_t flags) {
    bgfx_texture_handle_t h = bgfx_create_texture_2d(w, h, mips, layers,
        (bgfx_texture_format_t)fmt, flags, NULL);
    return h.idx;
}

uint16_t hxbgfx_wrapped_create_render_texture(uint16_t w, uint16_t h, uint64_t fmt) {
    bgfx_texture_handle_t h = bgfx_create_texture_2d(w, h, false, 1,
        (bgfx_texture_format_t)fmt, BGFX_TEXTURE_RT, NULL);
    return h.idx;
}

void hxbgfx_wrapped_destroy_texture(uint16_t handle) {
    bgfx_destroy_texture((bgfx_texture_handle_t){handle});
}

bool hxbgfx_read_texture_bytes(uint16_t texHandle, void* outBuf, uint32_t bufSize,
    uint32_t width, uint32_t height) {
    bgfx_texture_handle_t h = {texHandle};
    if (!bgfx_is_valid(h)) return false;
    return (bgfx_read_texture(h, outBuf, 0) > 0);
}

uint16_t hxbgfx_wrapped_create_frame_buffer(uint16_t texHandle) {
    bgfx_texture_handle_t th = {texHandle};
    if (!bgfx_is_valid(th)) return 0;
    bgfx_frame_buffer_handle_t fbh = bgfx_create_frame_buffer(1, &th, true);
    return fbh.idx;
}

void hxbgfx_wrapped_destroy_frame_buffer(uint16_t handle) {
    bgfx_destroy_frame_buffer((bgfx_frame_buffer_handle_t){handle});
}

uint16_t hxbgfx_wrapped_create_shader(const void* data, uint32_t size) {
    const bgfx_memory_t* mem = bgfx_make_ref(data, size);
    bgfx_shader_handle_t h = bgfx_create_shader(mem);
    return h.idx;
}

uint16_t hxbgfx_wrapped_create_program(uint16_t vs, uint16_t fs, bool destroyShaders) {
    bgfx_shader_handle_t vsh = {vs};
    bgfx_shader_handle_t fsh = {fs};
    bgfx_program_handle_t h = bgfx_create_program(vsh, fsh, destroyShaders);
    return h.idx;
}

void hxbgfx_wrapped_destroy_program(uint16_t handle) {
    bgfx_destroy_program((bgfx_program_handle_t){handle});
}

uint16_t hxbgfx_wrapped_create_uniform(const char* name, uint16_t type, uint16_t num) {
    bgfx_uniform_handle_t h = bgfx_create_uniform(name, (bgfx_uniform_type_t)type, num);
    return h.idx;
}

int hxbgfx_wrapped_get_renderer_type(void) {
    return (int)bgfx_get_renderer_type();
}

const char* hxbgfx_wrapped_get_renderer_name(int type, char* buffer, int bufferSize) {
    return bgfx_get_renderer_name((bgfx_renderer_type_t)type);
}

// ── GPU queries ──────────────────────────────────────────────────
int hxbgfx_get_gpu_vendor(void) {
#ifdef __APPLE__
    return 4;
#else
    return 0;
#endif
}

int hxbgfx_get_gpu_architecture(void) { return 0; }
int hxbgfx_get_apple_silicon_generation(void) { return 0; }

// ── Native handle extraction ────────────────────────────────────
void* hxbgfx_get_d3d12_device(void) {
#ifdef _WIN32
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal != NULL) return internal->context;
#endif
    return NULL;
}

void* hxbgfx_get_d3d12_command_queue(void) {
#ifdef _WIN32
    return NULL;
#else
    return NULL;
#endif
}

void* hxbgfx_get_vk_instance(void) { return NULL; }
void* hxbgfx_get_vk_physical_device(void) { return NULL; }
void* hxbgfx_get_vk_device(void) { return NULL; }

void* hxbgfx_get_mtl_device(void) {
#ifdef __APPLE__
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal != NULL) return internal->context;
#endif
    return NULL;
}

void* hxbgfx_get_native_texture(uint16_t texHandle) { return NULL; }
void* hxbgfx_get_native_framebuffer_texture(uint16_t fbHandle) { return NULL; }

// ── Platform-specific stubs ─────────────────────────────────────

#if defined(__APPLE__) || defined(__linux__)
// DLSS stubs (Windows only)
void  dlss_bridge_set_app_id_string(const char* hex) {}
bool  dlss_bridge_is_supported(void) { return false; }
uint64_t dlss_bridge_get_available_presets(void) { return 0; }
const uint8_t* dlss_bridge_preset_to_name(int v) { return NULL; }
int   dlss_bridge_init_d3d12(void* d, const char* p, int ow, int oh, int q, int pr) { return -1; }
int   dlss_bridge_create_feature_d3d12(void* q, int iw, int ih, int ow, int oh, int qm, int pr, bool ae, bool hdr) { return -1; }
int   dlss_bridge_evaluate_d3d12(void* cl, void* ci, void* co, void* db, void* mv, float jx, float jy, float sh, bool rh) { return -1; }
int   dlss_bridge_release_feature(void) { return -1; }
int   dlss_bridge_shutdown_d3d12(void) { return -1; }
int   dlss_bridge_get_optimal_settings(int ow, int oh, int q, int* rw, int* rh) { return -1; }

// XeSS stubs (Windows only)
int   xess_bridge_is_supported(void) { return -2; }
int   xess_bridge_init_vk(void** ctx, void* inst, void* pd, void* dev, int ow, int oh, int qs, int fl) { return -1; }
int   xess_bridge_get_input_resolution(void* ctx, int* w, int* h) { return -1; }
int   xess_bridge_execute_vk(void* ctx, void* cb, void* ct, void* vt, void* dt, void* ot, float jx, float jy, int iw, int ih, int rh) { return -1; }
int   xess_bridge_destroy_context(void* ctx) { return -1; }

// MetalFX stubs (ObjC .mm cannot be included from C++)
bool  metalfx_init(int iw, int ih, int ow, int oh, int mode) { return false; }
bool  metalfx_apply(const void* pixels, int size) { return false; }
bool  metalfx_get_output_pixels(void* buf, int size) { return false; }
void  metalfx_dispose(void) {}
#endif
