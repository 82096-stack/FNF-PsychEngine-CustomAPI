package backend;

import cpp.RawPointer;
import cpp.RawConstPointer;
import cpp.ConstCharStar;
import cpp.UInt8;
import cpp.UInt16;
import cpp.UInt32;
import cpp.UInt64;
import cpp.Float32;
import backend.RenderDevice.BgfxVertexLayout;
import backend.RenderDevice.BgfxTransientVertexBuffer;

/**
 * bgfx CFFI bridge — Haxe bindings for bgfx + upscaling.
 *
 * Uses @:native to call wrapped C functions in bgfx_bridge.cpp.
 * All pointer types use hxcpp built-in cpp.RawPointer<T> which
 * maps directly to T* in generated C++ code.
 */
@:headerCode('
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
void* hxbgfx_get_native_window_handle(void);
void* hxbgfx_get_native_display_handle(void);
bool  hxbgfx_wrapped_init(int,void*,void*,int,int,int,int,int,int,int,int,int);
void  hxbgfx_wrapped_shutdown(void);
void  hxbgfx_wrapped_reset(int,int,int,int,int,int);
uint32_t hxbgfx_wrapped_frame(bool);
void  hxbgfx_wrapped_touch(uint16_t);
void  hxbgfx_wrapped_set_view_rect(uint16_t,uint16_t,uint16_t,uint16_t,uint16_t);
void  hxbgfx_wrapped_set_view_clear(uint16_t,uint16_t,uint32_t,float,uint8_t);
void  hxbgfx_wrapped_set_view_transform(uint16_t,const float*,const float*);
void  hxbgfx_wrapped_set_view_frame_buffer(uint16_t,uint16_t);
void  hxbgfx_wrapped_submit(uint16_t,uint16_t,uint32_t,uint8_t);
void  hxbgfx_wrapped_set_state(uint64_t,uint32_t);
void  hxbgfx_wrapped_set_texture(uint8_t,uint16_t,uint16_t,uint32_t);
void  hxbgfx_wrapped_set_uniform(uint16_t,const void*,uint32_t);
void* hxbgfx_wrapped_alloc_transient_vertex_buffer(int,int,int,int*);
uint16_t hxbgfx_wrapped_create_texture_2d(uint16_t,uint16_t,bool,uint16_t,uint64_t,uint64_t);
uint16_t hxbgfx_wrapped_create_render_texture(uint16_t,uint16_t,uint64_t);
void  hxbgfx_wrapped_destroy_texture(uint16_t);
bool  hxbgfx_read_texture_bytes(uint16_t,void*,uint32_t,uint32_t,uint32_t);
uint16_t hxbgfx_wrapped_create_frame_buffer(uint16_t);
void  hxbgfx_wrapped_destroy_frame_buffer(uint16_t);
uint16_t hxbgfx_wrapped_create_shader(const void*,uint32_t);
uint16_t hxbgfx_wrapped_create_program(uint16_t,uint16_t,bool);
void  hxbgfx_wrapped_destroy_program(uint16_t);
uint16_t hxbgfx_wrapped_create_uniform(const char*,uint16_t,uint16_t);
int   hxbgfx_wrapped_get_renderer_type(void);
int   hxbgfx_get_gpu_vendor(void);
int   hxbgfx_get_gpu_architecture(void);
int   hxbgfx_get_apple_silicon_generation(void);
bool  metalfx_init(void* mtlDevice, int iw, int ih, int ow, int oh, int mode);
bool  metalfx_apply(void* inputMTLTexture, void* outputMTLTexture);
void  metalfx_reset(void);
bool  metalfx_is_supported(void* mtlDevice);
void  metalfx_dispose(void);
void  dlss_bridge_set_app_id_string(const char*);
bool  dlss_bridge_is_supported(void);
uint64_t dlss_bridge_get_available_presets(void);
uint8_t* dlss_bridge_preset_to_name(int);
int   dlss_bridge_init_d3d12(void*,const char*,int,int,int,int);
int   dlss_bridge_create_feature_d3d12(void*,int,int,int,int,int,int,bool,bool);
int   dlss_bridge_evaluate_d3d12(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float);
int   dlss_bridge_release_feature(void);
int   dlss_bridge_shutdown_d3d12(void);
	int   dlss_bridge_init_d3d11(void*,const char*,int,int,int,int);
	int   dlss_bridge_create_feature_d3d11(void*,int,int,int,int,int,int,bool,bool);
	int   dlss_bridge_evaluate_d3d11(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float);
	int   dlss_bridge_shutdown_d3d11(void);
	int   dlss_bridge_init_vk(uint64_t,void*,void*,void*,const char*,uint32_t,uint32_t,int,int);
	int   dlss_bridge_create_feature_vk(void*,uint32_t,uint32_t,uint32_t,uint32_t,int,int,bool,bool);
	int   dlss_bridge_evaluate_vk(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float);
	int   dlss_bridge_shutdown_vk(void);

	// FSR 2/3.1 bridge
	int   fsr2_bridge_init(void**,int,uint32_t,uint32_t,uint32_t,uint32_t,bool,bool,bool);
	int   fsr2_bridge_dispatch(void*,void*,void*,void*,void*,void*,float,float,float,float,uint32_t,uint32_t,float,float,float,bool,float,float,float);
	int   fsr2_bridge_destroy(void*);
	int   fsr2_bridge_get_jitter_offset(void*,int32_t,int32_t,float*,float*);
	int32_t fsr2_bridge_get_jitter_phase_count(int32_t,int32_t);
	int   fsr2_bridge_get_render_resolution(void*,uint32_t,uint32_t,uint32_t*,uint32_t*);
int   dlss_bridge_get_optimal_settings(int,int,int,int*,int*);
int   xess_bridge_is_supported(void);
int   xess_bridge_init_vk(void**,void*,void*,void*,int,int,int,int);
int   xess_bridge_get_input_resolution(void*,uint32_t,uint32_t,int,uint32_t*,uint32_t*);
	int   xess_bridge_get_vk_instance_extensions(uint32_t*,const char**,uint32_t*);
	int   xess_bridge_get_vk_device_extensions(void*,void*,uint32_t*,const char**);
	int   xess_bridge_init_d3d12(void**,void*,uint32_t,uint32_t,int,uint32_t);
	int   xess_bridge_execute_d3d12(void*,void*,void*,void*,void*,void*,float,float,uint32_t,uint32_t,int);
	int   xess_bridge_init_d3d11(void**,void*,uint32_t,uint32_t,int,uint32_t);
	int   xess_bridge_execute_d3d11(void*,void*,void*,void*,void*,void*,float,float,uint32_t,uint32_t,int);

int   xess_bridge_execute_vk(void*,void*,void*,void*,void*,void*,float,float,int,int,int);
int   xess_bridge_destroy_context(void*);
void* hxbgfx_get_d3d12_device(void);
	void* hxbgfx_get_d3d11_device(void);
	void* hxbgfx_get_d3d11_immediate_context(void);
void* hxbgfx_get_d3d12_command_queue(void);
void* hxbgfx_get_vk_instance(void);
void* hxbgfx_get_vk_physical_device(void);
void* hxbgfx_get_vk_device(void);
void* hxbgfx_get_mtl_device(void);
void* hxbgfx_get_native_texture(uint16_t);
void* hxbgfx_get_native_framebuffer_texture(uint16_t);
#ifdef __cplusplus
}
#endif
')
@:cppFileCode('

// ── bgfx C99 forward declarations (matching libbgfx.a symbols) ──
// These are the C99 API types and functions that exist in the compiled bgfx library.
// Verified via: nm libbgfx.a | grep " T _bgfx_"
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <stddef.h>
#ifdef __APPLE__
#include "/opt/homebrew/include/SDL2/SDL.h"
#include "/opt/homebrew/include/SDL2/SDL_syswm.h"
#elif defined(_WIN32)
#include <SDL.h>
#include <SDL_syswm.h>
#else
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#endif

typedef uint32_t bgfx_renderer_type_t;
typedef uint32_t bgfx_texture_format_t;
typedef uint32_t bgfx_uniform_type_t;
typedef struct { uint16_t idx; } bgfx_texture_handle_t;
typedef struct { uint16_t idx; } bgfx_frame_buffer_handle_t;
typedef struct { uint16_t idx; } bgfx_shader_handle_t;
typedef struct { uint16_t idx; } bgfx_program_handle_t;
typedef struct { uint16_t idx; } bgfx_uniform_handle_t;
typedef struct { uint32_t hash; uint16_t stride; } bgfx_vertex_layout_t;
typedef struct { void* data; uint32_t size; } bgfx_transient_vertex_buffer_t;
typedef struct { void* data; uint32_t size; } bgfx_memory_t;
typedef struct { void* nwh; void* ndt; void* context; void* backBuffer; void* backBufferDS; } bgfx_platform_data_t;
typedef struct {
   uint32_t type; uint16_t vendorId; uint16_t deviceId;
   uint64_t capabilities;
   void* callback; void* allocator;
   struct { uint32_t width; uint32_t height; uint32_t reset; bgfx_texture_format_t format; } resolution;
   struct { uint16_t maxEncoders; uint32_t transientVbSize; uint32_t transientIbSize; } limits;
   bgfx_platform_data_t platformData;
} bgfx_init_t;

#define BGFX_TEXTURE_RT_MASK UINT64_C(0x0000000000000020)
#define BGFX_TEXTURE_RT BGFX_TEXTURE_RT_MASK
#define BGFX_CLEAR_COLOR UINT16_C(0x0001)
#define BGFX_CLEAR_DEPTH UINT16_C(0x0002)

extern "C" {
void bgfx_init_ctor(bgfx_init_t* _init);
bool bgfx_init(const bgfx_init_t* _init);
void bgfx_shutdown(void);
void bgfx_reset(uint32_t _width, uint32_t _height, uint32_t _flags, bgfx_texture_format_t _format);
uint32_t bgfx_frame(bool _capture);
void bgfx_touch(uint16_t _id);
void bgfx_set_view_rect(uint16_t _id, uint16_t _x, uint16_t _y, uint16_t _width, uint16_t _height);
void bgfx_set_view_clear(uint16_t _id, uint16_t _flags, uint32_t _rgba, float _depth, uint8_t _stencil);
void bgfx_set_view_transform(uint16_t _id, const void* _view, const void* _proj);
void bgfx_submit(uint16_t _id, bgfx_program_handle_t _program, uint32_t _depth, uint8_t _flags);
void bgfx_set_state(uint64_t _state, uint32_t _rgba);
void bgfx_set_texture(uint8_t _stage, bgfx_uniform_handle_t _sampler, bgfx_texture_handle_t _handle, uint32_t _flags);
void bgfx_set_uniform(bgfx_uniform_handle_t _handle, const void* _value, uint16_t _num);
void bgfx_set_view_frame_buffer(uint16_t _id, bgfx_frame_buffer_handle_t _handle);
void bgfx_alloc_transient_vertex_buffer(bgfx_transient_vertex_buffer_t* _tvb, uint32_t _numVertices, const bgfx_vertex_layout_t* _layout);
bgfx_texture_handle_t bgfx_create_texture_2d(uint16_t _width, uint16_t _height, bool _hasMips, uint16_t _numLayers, bgfx_texture_format_t _format, uint64_t _flags, const bgfx_memory_t* _mem);
void bgfx_destroy_texture(bgfx_texture_handle_t _handle);
uint32_t bgfx_read_texture(bgfx_texture_handle_t _handle, void* _data, uint8_t _mip);
bgfx_frame_buffer_handle_t bgfx_create_frame_buffer(uint8_t _num, const bgfx_texture_handle_t* _handles, bool _destroyTextures);
void bgfx_destroy_frame_buffer(bgfx_frame_buffer_handle_t _handle);
bool bgfx_is_texture_valid(bgfx_texture_handle_t _handle);
const bgfx_memory_t* bgfx_make_ref(const void* _data, uint32_t _size);
bgfx_shader_handle_t bgfx_create_shader(const bgfx_memory_t* _mem);
bgfx_program_handle_t bgfx_create_program(bgfx_shader_handle_t _vsh, bgfx_shader_handle_t _fsh, bool _destroyShaders);
void bgfx_destroy_program(bgfx_program_handle_t _handle);
bgfx_uniform_handle_t bgfx_create_uniform(const char* _name, bgfx_uniform_type_t _type, uint16_t _num);
bgfx_renderer_type_t bgfx_get_renderer_type(void);
}
#include <string.h>
#include <stdio.h>
#ifdef __APPLE__
#include "/opt/homebrew/include/SDL2/SDL.h"
#include "/opt/homebrew/include/SDL2/SDL_syswm.h"
#elif defined(_WIN32)
#include <SDL.h>
#include <SDL_syswm.h>
#else
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>
#endif

// ── SDL window detection ──────────────────────────────────────────
static SDL_Window* _hx_sdl_window(void) {
    SDL_Window* w = SDL_GL_GetCurrentWindow();
    return w ? w : SDL_GetWindowFromID(1);
}

void* hxbgfx_get_native_window_handle(void) {
    SDL_Window* win = _hx_sdl_window();
    if (!win) return NULL;
    SDL_SysWMinfo wmi; SDL_VERSION(&wmi.version);
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

// ── bgfx wrapped API (C99 thin wrappers) ─────────────────────────
bool hxbgfx_wrapped_init(int rendererType, void* nwh, void* ndt,
    int width, int height, int format, int resetFlags,
    int numBackBuffers, int maxFrameLatency,
    int maxEncoders, int transientVbSize, int transientIbSize)
{
    bgfx_init_t init; bgfx_init_ctor(&init);
    init.type              = (bgfx_renderer_type_t)rendererType;
    init.resolution.width  = (uint32_t)width;
    init.resolution.height = (uint32_t)height;
    init.resolution.format = (bgfx_texture_format_t)format;
    init.resolution.reset  = (uint32_t)resetFlags;
    init.platformData.nwh  = nwh;
    init.platformData.ndt  = ndt;
    init.limits.maxEncoders      = (uint16_t)maxEncoders;
    init.limits.transientVbSize  = (uint32_t)transientVbSize;
    init.limits.transientIbSize  = (uint32_t)transientIbSize;
    return bgfx_init(&init);
}

void hxbgfx_wrapped_shutdown(void) { bgfx_shutdown(); }
void hxbgfx_wrapped_reset(int w, int h, int flags, int fmt, int nbb, int mfl) {
    bgfx_reset((uint32_t)w, (uint32_t)h, (uint32_t)flags, (bgfx_texture_format_t)fmt);
}
uint32_t hxbgfx_wrapped_frame(bool capture) { return bgfx_frame(capture); }
void hxbgfx_wrapped_touch(uint16_t vid) { bgfx_touch(vid); }
void hxbgfx_wrapped_set_view_rect(uint16_t v, uint16_t x, uint16_t y, uint16_t w, uint16_t h) {
    bgfx_set_view_rect(v,x,y,w,h);
}
void hxbgfx_wrapped_set_view_clear(uint16_t v, uint16_t f, uint32_t c, float d, uint8_t s) {
    bgfx_set_view_clear(v,f,c,d,s);
}
void hxbgfx_wrapped_set_view_transform(uint16_t v, const float* vm, const float* pm) {
    bgfx_set_view_transform(v,vm,pm);
}
void hxbgfx_wrapped_submit(uint16_t v, uint16_t p, uint32_t d, uint8_t f) {
    bgfx_submit(v,(bgfx_program_handle_t){p},d,f);
}
void hxbgfx_wrapped_set_state(uint64_t s, uint32_t c) { bgfx_set_state(s,c); }
void hxbgfx_wrapped_set_texture(uint8_t st, uint16_t sm, uint16_t th, uint32_t f) {
    bgfx_set_texture(st,(bgfx_uniform_handle_t){sm},(bgfx_texture_handle_t){th},f);
}
void hxbgfx_wrapped_set_uniform(uint16_t uh, const void* d, uint32_t s) {
    bgfx_set_uniform((bgfx_uniform_handle_t){uh},d,s);
}
void hxbgfx_wrapped_set_view_frame_buffer(uint16_t v, uint16_t fb) {
    bgfx_set_view_frame_buffer(v,(bgfx_frame_buffer_handle_t){fb});
}
void* hxbgfx_wrapped_alloc_transient_vertex_buffer(int nv, int lh, int ls, int* outNum) {
    bgfx_vertex_layout_t lo = {(uint32_t)lh,(uint16_t)ls};
    bgfx_transient_vertex_buffer_t tvb;
    bgfx_alloc_transient_vertex_buffer(&tvb,(uint32_t)nv,&lo);
    if (outNum) *outNum = (int)tvb.size / ls;
    return tvb.data;
}
uint16_t hxbgfx_wrapped_create_texture_2d(uint16_t w, uint16_t h, bool mips, uint16_t layers, uint64_t fmt, uint64_t flags) {
    return bgfx_create_texture_2d(w,h,mips,layers,(bgfx_texture_format_t)fmt,flags,NULL).idx;
}
uint16_t hxbgfx_wrapped_create_render_texture(uint16_t w, uint16_t h, uint64_t fmt) {
    return bgfx_create_texture_2d(w,h,false,1,(bgfx_texture_format_t)fmt,BGFX_TEXTURE_RT,NULL).idx;
}
void hxbgfx_wrapped_destroy_texture(uint16_t h) { bgfx_destroy_texture((bgfx_texture_handle_t){h}); }
bool hxbgfx_read_texture_bytes(uint16_t th, void* buf, uint32_t sz, uint32_t w, uint32_t h) {
    bgfx_texture_handle_t ht = {th};
    return bgfx_is_texture_valid(ht) ? bgfx_read_texture(ht,buf,0) > 0 : false;
}
uint16_t hxbgfx_wrapped_create_frame_buffer(uint16_t th) {
    bgfx_texture_handle_t ht = {th};
    return bgfx_is_texture_valid(ht) ? bgfx_create_frame_buffer(1,&ht,true).idx : 0;
}
void hxbgfx_wrapped_destroy_frame_buffer(uint16_t h) { bgfx_destroy_frame_buffer((bgfx_frame_buffer_handle_t){h}); }
uint16_t hxbgfx_wrapped_create_shader(const void* d, uint32_t s) {
    return bgfx_create_shader(bgfx_make_ref(d,s)).idx;
}
uint16_t hxbgfx_wrapped_create_program(uint16_t vs, uint16_t fs, bool ds) {
    return bgfx_create_program((bgfx_shader_handle_t){vs},(bgfx_shader_handle_t){fs},ds).idx;
}
void hxbgfx_wrapped_destroy_program(uint16_t h) {
    bgfx_destroy_program((bgfx_program_handle_t){h});
}
uint16_t hxbgfx_wrapped_create_uniform(const char* n, uint16_t t, uint16_t num) {
    return bgfx_create_uniform(n,(bgfx_uniform_type_t)t,num).idx;
}
int hxbgfx_wrapped_get_renderer_type(void) { return (int)bgfx_get_renderer_type(); }

// ── GPU queries ──────────────────────────────────────────────────
__attribute__((weak)) int hxbgfx_get_gpu_vendor(void) {
#ifdef __APPLE__
    return 4;
#else
    return 0;
#endif
}
__attribute__((weak)) int hxbgfx_get_gpu_architecture(void) { return 0; }
__attribute__((weak)) int hxbgfx_get_apple_silicon_generation(void) { return 0; }

// ── Native handle extraction (return NULL for now) ────────────────
__attribute__((weak)) void* hxbgfx_get_d3d12_device(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_d3d12_command_queue(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_vk_instance(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_vk_physical_device(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_vk_device(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_mtl_device(void) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_native_texture(uint16_t th) { return NULL; }
__attribute__((weak)) void* hxbgfx_get_native_framebuffer_texture(uint16_t fbh) { return NULL; }

// ── DLSS stubs ───────────────────────────────────────────────────
__attribute__((weak)) void  dlss_bridge_set_app_id_string(const char* hex) {}
__attribute__((weak)) bool  dlss_bridge_is_supported(void) { return false; }
__attribute__((weak)) uint64_t dlss_bridge_get_available_presets(void) { return 0; }
__attribute__((weak)) uint8_t* dlss_bridge_preset_to_name(int v) { return NULL; }
__attribute__((weak)) int   dlss_bridge_init_d3d12(void*,const char*,int,int,int,int) { return -1; }
__attribute__((weak)) int   dlss_bridge_create_feature_d3d12(void*,int,int,int,int,int,int,bool,bool) { return -1; }
__attribute__((weak)) int   dlss_bridge_evaluate_d3d12(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float) { return -1; }
__attribute__((weak)) int   dlss_bridge_release_feature(void) { return -1; }
__attribute__((weak)) int   dlss_bridge_shutdown_d3d12(void) { return -1; }
__attribute__((weak)) int   dlss_bridge_init_d3d11(void*,const char*,int,int,int,int) { return -1; }
__attribute__((weak)) int   dlss_bridge_create_feature_d3d11(void*,int,int,int,int,int,int,bool,bool) { return -1; }
__attribute__((weak)) int   dlss_bridge_evaluate_d3d11(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float) { return -1; }
__attribute__((weak)) int   dlss_bridge_shutdown_d3d11(void) { return -1; }
__attribute__((weak)) int   dlss_bridge_init_vk(uint64_t,void*,void*,void*,const char*,uint32_t,uint32_t,int,int) { return -1; }
__attribute__((weak)) int   dlss_bridge_create_feature_vk(void*,uint32_t,uint32_t,uint32_t,uint32_t,int,int,bool,bool) { return -1; }
__attribute__((weak)) int   dlss_bridge_evaluate_vk(void*,void*,void*,void*,void*,float,float,float,bool,float,float,float) { return -1; }
__attribute__((weak)) int   dlss_bridge_shutdown_vk(void) { return -1; }


__attribute__((weak)) int   fsr2_bridge_init(void**,int,uint32_t,uint32_t,uint32_t,uint32_t,bool,bool,bool) { return -1; }
__attribute__((weak)) int   fsr2_bridge_dispatch(void*,void*,void*,void*,void*,void*,float,float,float,float,uint32_t,uint32_t,float,float,float,bool,float,float,float) { return -1; }
__attribute__((weak)) int   fsr2_bridge_destroy(void*) { return -1; }
__attribute__((weak)) int   fsr2_bridge_get_jitter_offset(void*,int32_t,int32_t,float*,float*) { return -1; }
__attribute__((weak)) int32_t fsr2_bridge_get_jitter_phase_count(int32_t,int32_t) { return 8; }
__attribute__((weak)) int   fsr2_bridge_get_render_resolution(void*,uint32_t,uint32_t,uint32_t*,uint32_t*) { return -1; }
__attribute__((weak)) int   dlss_bridge_get_optimal_settings(int,int,int,int*,int*) { return -1; }

// ── XeSS stubs ──────────────────────────────────────────────────
__attribute__((weak)) int xess_bridge_is_supported(void) { return -2; }
__attribute__((weak)) int xess_bridge_init_vk(void**,void*,void*,void*,int,int,int,int) { return -1; }
__attribute__((weak)) int xess_bridge_get_input_resolution(void*,uint32_t,uint32_t,int,uint32_t*,uint32_t*) { return -1; }
__attribute__((weak)) int xess_bridge_execute_vk(void*,void*,void*,void*,void*,void*,float,float,int,int,int) { return -1; }
__attribute__((weak)) int xess_bridge_destroy_context(void*) { return -1; }
__attribute__((weak)) int xess_bridge_get_vk_instance_extensions(uint32_t* pCount, const char** ppExt, uint32_t* pMinVer) { return -2; }
__attribute__((weak)) int xess_bridge_get_vk_device_extensions(void* inst, void* phys, uint32_t* pCount, const char** ppExt) { return -2; }
__attribute__((weak)) int xess_bridge_init_d3d12(void**,void*,uint32_t,uint32_t,int,uint32_t) { return -1; }
__attribute__((weak)) int xess_bridge_execute_d3d12(void*,void*,void*,void*,void*,void*,float,float,uint32_t,uint32_t,int) { return -1; }
__attribute__((weak)) int xess_bridge_init_d3d11(void**,void*,uint32_t,uint32_t,int,uint32_t) { return -1; }
__attribute__((weak)) int xess_bridge_execute_d3d11(void*,void*,void*,void*,void*,void*,float,float,uint32_t,uint32_t,int) { return -1; }


// ── MetalFX weak stubs (overridden by metalfx_bridge.mm if linked) ─
__attribute__((weak)) bool metalfx_init(void*,int,int,int,int,int) { return false; }
__attribute__((weak)) bool metalfx_apply(void*,void*) { return false; }
__attribute__((weak)) void metalfx_reset(void) {}
__attribute__((weak)) bool metalfx_is_supported(void*) { return false; }
__attribute__((weak)) void metalfx_dispose(void) {}

')

class BgfxAPI
{
	public static var nativeAvailable(default, null):Bool = false;

	public static function probeNativeAvailability():Bool
	{
		nativeAvailable = true;
		return true;
	}

	// ── Lifecycle ──────────────────────────────────────────────────

	@:native('hxbgfx_wrapped_init')
	public static function init(rendererType:Int, nwh:RawPointer<cpp.Void>,
		ndt:RawPointer<cpp.Void>, width:Int, height:Int, format:Int,
		resetFlags:Int, numBackBuffers:Int, maxFrameLatency:Int,
		maxEncoders:Int, transientVbSize:Int, transientIbSize:Int):Bool
	{ return false; }

	@:native('hxbgfx_wrapped_shutdown')
	public static function shutdown():Void {}

	@:native('hxbgfx_wrapped_reset')
	public static function reset(w:Int, h:Int, flags:Int, fmt:Int,
		numBackBuffers:Int, maxFrameLatency:Int):Void {}

	@:native('hxbgfx_wrapped_frame')
	public static function frame(capture:Bool):UInt32 { return 0; }

	// ── View ───────────────────────────────────────────────────────

	@:native('hxbgfx_wrapped_touch')
	public static function touch(id:Int):Void {}

	@:native('hxbgfx_wrapped_set_view_rect')
	public static function setViewRect(id:Int, x:Int, y:Int, w:Int, h:Int):Void {}

	@:native('hxbgfx_wrapped_set_view_clear')
	public static function setViewClear(id:Int, flags:Int, rgba:Int, depth:Float, stencil:Int):Void {}

	@:native('hxbgfx_wrapped_set_view_transform')
	public static function setViewTransform(id:Int, view:RawPointer<Float32>,
		proj:RawPointer<Float32>):Void {}

	@:native('hxbgfx_wrapped_set_view_frame_buffer')
	public static function setViewFrameBuffer(viewId:Int, fbHandle:Int):Void {}

	// ── Render state ───────────────────────────────────────────────

	@:native('hxbgfx_wrapped_set_state')
	public static function setState(state:UInt64, rgba:UInt32):Void {}

	@:native('hxbgfx_wrapped_set_texture')
	public static function setTexture(stage:Int, sampler:Int, tex:Int, flags:Int):Void {}

	@:native('hxbgfx_wrapped_set_uniform')
	public static function setUniform(handle:Int, data:RawPointer<cpp.Void>, size:Int):Void {}

	// ── Transient VB ───────────────────────────────────────────────

	@:native('hxbgfx_wrapped_alloc_transient_vertex_buffer')
	public static function allocTransientVB(numVertices:Int, layoutHash:Int,
		layoutStride:Int, outNum:cpp.RawPointer<Int>):RawPointer<cpp.Void>
	{ return null; }

	// ── Submit ─────────────────────────────────────────────────────

	@:native('hxbgfx_wrapped_submit')
	public static function submit(id:Int, prog:Int, depth:Int, flags:Int):Void {}

	// ── Textures ───────────────────────────────────────────────────

	@:native('hxbgfx_wrapped_create_texture_2d')
	public static function createTexture2D(w:Int, h:Int, mips:Bool, layers:Int,
		fmt:Int, flags:Int):UInt16 { return 0; }

	@:native('hxbgfx_wrapped_create_render_texture')
	public static function createRenderTexture(w:Int, h:Int, fmt:Int):UInt16 { return 0; }

	@:native('hxbgfx_wrapped_destroy_texture')
	public static function destroyTexture(h:Int):Void {}

	@:native('hxbgfx_read_texture_bytes')
	public static function readTextureBytes(texHandle:Int, outBuf:RawPointer<cpp.Void>,
		bufSize:Int, width:Int, height:Int):Bool { return false; }

	// ── Frame buffers ──────────────────────────────────────────────

	@:native('hxbgfx_wrapped_create_frame_buffer')
	public static function createFrameBuffer(texHandle:Int):UInt16 { return 0; }

	@:native('hxbgfx_wrapped_destroy_frame_buffer')
	public static function destroyFrameBuffer(h:Int):Void {}

	// ── Shaders ────────────────────────────────────────────────────

	@:native('hxbgfx_wrapped_create_shader')
	public static function createShaderRaw(data:RawPointer<cpp.Void>, size:Int):UInt16 { return 0; }

	public static function createShader(mem:Dynamic):UInt16
	{
		if (mem == null) return 0;
		var bytes:haxe.io.Bytes = cast mem;
		var ptr:RawPointer<cpp.Void> = untyped __cpp__('(void*)&({0}->b[0])', bytes);
		var size:Int = bytes.length;
		return createShaderRaw(ptr, size);
	}

	@:native('hxbgfx_wrapped_create_program')
	public static function createProgram(vs:Int, fs:Int, destroy:Bool):UInt16 { return 0; }

	@:native('hxbgfx_wrapped_destroy_program')
	public static function destroyProgram(h:Int):Void {}

	@:native('hxbgfx_wrapped_create_uniform')
	public static function createUniform(name:ConstCharStar, t:Int, n:Int):UInt16 { return 0; }

	public static function destroyUniform(h:Int):Void {}

	// ── Renderer info ──────────────────────────────────────────────

	@:native('hxbgfx_wrapped_get_renderer_type')
	public static function getRendererType():Int { return 8; }

	// ── Native handles ─────────────────────────────────────────────

	@:native('hxbgfx_get_native_window_handle')
	public static function hxGetNativeWindowHandle():RawPointer<cpp.Void> { return null; }

	@:native('hxbgfx_get_native_display_handle')
	public static function hxGetNativeDisplayHandle():RawPointer<cpp.Void> { return null; }

	public static function hxGetBestRenderer():Int {
		#if mac return 5; #elseif windows return 3; #else return 9; #end
	}

	public static function hxGetSupportedRenderers():Int {
		#if mac return (1 << 5) | (1 << 8);
		#elseif windows return (1 << 1) | (1 << 2) | (1 << 3) | (1 << 9) | (1 << 8);
		#else return (1 << 8); #end
	}

	// ── GPU queries ────────────────────────────────────────────────

	@:native('hxbgfx_get_gpu_vendor')
	public static function hxGetGpuVendor():Int { return 0; }

	@:native('hxbgfx_get_gpu_architecture')
	public static function hxGetGpuArchitecture():Int { return 0; }

	@:native('hxbgfx_get_apple_silicon_generation')
	public static function hxGetAppleSiliconGeneration():Int { return 0; }

	// ── MetalFX bridge ─────────────────────────────────────────────

	@:native('metalfx_init')
	public static function metalFXInit(device:RawPointer<cpp.Void>, iw:Int, ih:Int, ow:Int, oh:Int, mode:Int):Bool { return false; }

	@:native('metalfx_apply')
	public static function metalFXApply(inputTex:RawPointer<cpp.Void>, outputTex:RawPointer<cpp.Void>):Bool { return false; }

	@:native('metalfx_reset')
	public static function metalFXReset():Void {}

	@:native('metalfx_is_supported')
	public static function metalFXIsSupported(device:RawPointer<cpp.Void>):Bool { return false; }

	@:native('metalfx_dispose')
	public static function metalFXDispose():Void {}

	// ── DLSS bridge ────────────────────────────────────────────────

	@:native('dlss_bridge_set_app_id_string')
	public static function dlssSetAppId(hex:ConstCharStar):Void {}

	@:native('dlss_bridge_is_supported')
	public static function dlssIsSupported():Bool { return false; }

	@:native('dlss_bridge_get_available_presets')
	public static function dlssGetPresets():UInt64 { return 0; }

	@:native('dlss_bridge_preset_to_name')
	public static function dlssPresetToName(v:Int):cpp.RawPointer<cpp.UInt8> { return null; }

	@:native('dlss_bridge_init_d3d12')
	public static function dlssInitD3D12(device:RawPointer<cpp.Void>, dataPath:ConstCharStar,
		outW:Int, outH:Int, quality:Int, preset:Int):Int { return -1; }

	@:native('dlss_bridge_create_feature_d3d12')
	public static function dlssCreateFeature(cmdQueue:RawPointer<cpp.Void>,
		inW:Int, inH:Int, outW:Int, outH:Int,
		quality:Int, preset:Int, autoExp:Bool, hdr:Bool):Int { return -1; }

	@:native('dlss_bridge_evaluate_d3d12')
	public static function dlssEvaluate(cmdList:RawPointer<cpp.Void>,
		colorIn:RawPointer<cpp.Void>, colorOut:RawPointer<cpp.Void>,
		depth:RawPointer<cpp.Void>, mvecs:RawPointer<cpp.Void>,
		jx:Float, jy:Float, sharpness:Float, reset:Bool,
		frameTimeDelta:Float, preExposure:Float, exposureScale:Float):Int { return -1; }

	@:native('dlss_bridge_release_feature')
	public static function dlssReleaseFeature():Int { return -1; }

	@:native('dlss_bridge_shutdown_d3d12')
	public static function dlssShutdown():Int { return -1; }

		@:native('dlss_bridge_init_d3d11')
		public static function dlssInitD3D11(device:RawPointer<cpp.Void>, dataPath:ConstCharStar,
		outW:Int, outH:Int, quality:Int, preset:Int):Int { return -1; }
		
		@:native('dlss_bridge_create_feature_d3d11')
		public static function dlssCreateFeatureD3D11(ctx:RawPointer<cpp.Void>,
		inW:Int, inH:Int, outW:Int, outH:Int,
		quality:Int, preset:Int, autoExp:Bool, hdr:Bool):Int { return -1; }
		
		@:native('dlss_bridge_evaluate_d3d11')
		public static function dlssEvaluateD3D11(ctx:RawPointer<cpp.Void>,
		colorIn:RawPointer<cpp.Void>, colorOut:RawPointer<cpp.Void>,
		depth:RawPointer<cpp.Void>, mvecs:RawPointer<cpp.Void>,
		jx:Float, jy:Float, sharpness:Float, reset:Bool,
		frameTimeDelta:Float, preExposure:Float, exposureScale:Float):Int { return -1; }
		
		@:native('dlss_bridge_shutdown_d3d11')
		public static function dlssShutdownD3D11():Int { return -1; }


		// DLSS Vulkan wrappers
		@:native('dlss_bridge_init_vk')
		public static function dlssInitVK(appId:cpp.UInt64, inst:RawPointer<cpp.Void>,
			phys:RawPointer<cpp.Void>, dev:RawPointer<cpp.Void>, dataPath:ConstCharStar,
			outW:Int, outH:Int, quality:Int, preset:Int):Int { return -1; }

		@:native('dlss_bridge_create_feature_vk')
		public static function dlssCreateFeatureVK(cmdBuf:RawPointer<cpp.Void>,
			inW:Int, inH:Int, outW:Int, outH:Int,
			quality:Int, preset:Int, autoExp:Bool, hdr:Bool):Int { return -1; }

		@:native('dlss_bridge_evaluate_vk')
		public static function dlssEvaluateVK(cmdBuf:RawPointer<cpp.Void>,
			colorIn:RawPointer<cpp.Void>, colorOut:RawPointer<cpp.Void>,
			depth:RawPointer<cpp.Void>, mvecs:RawPointer<cpp.Void>,
			jx:Float, jy:Float, sharpness:Float, reset:Bool,
			frameTimeDelta:Float, preExposure:Float, exposureScale:Float):Int { return -1; }

		@:native('dlss_bridge_shutdown_vk')
		public static function dlssShutdownVK():Int { return -1; }


	@:native('dlss_bridge_get_optimal_settings')
	public static function dlssGetOptimalSettings(outW:Int, outH:Int, quality:Int,
		outRenderW:cpp.RawPointer<Int>, outRenderH:cpp.RawPointer<Int>):Int { return -1; }

	// ── XeSS bridge ────────────────────────────────────────────────

	@:native('xess_bridge_is_supported')
	public static function xessIsSupported():Int { return -2; }

	@:native('xess_bridge_init_vk')
	public static function xessInitVK(ctx:cpp.RawPointer<cpp.RawPointer<cpp.Void>>,
		instance:RawPointer<cpp.Void>, physDevice:RawPointer<cpp.Void>,
		device:RawPointer<cpp.Void>, outW:Int, outH:Int,
		quality:Int, flags:Int):Int { return -1; }

	@:native('xess_bridge_get_input_resolution')
	public static function xessGetInputRes(ctx:RawPointer<cpp.Void>,
		outputW:Int, outputH:Int, quality:Int,
		outW:cpp.RawPointer<cpp.UInt32>, outH:cpp.RawPointer<cpp.UInt32>):Int { return -1; }

	@:native('xess_bridge_execute_vk')
	public static function xessExecute(ctx:RawPointer<cpp.Void>, cmdBuf:RawPointer<cpp.Void>,
		color:RawPointer<cpp.Void>, vel:RawPointer<cpp.Void>,
		depth:RawPointer<cpp.Void>, output:RawPointer<cpp.Void>,
		jx:Float, jy:Float, inW:Int, inH:Int, reset:Int):Int { return -1; }

	@:native('xess_bridge_destroy_context')
	public static function xessDestroyContext(ctx:RawPointer<cpp.Void>):Int { return -1; }

		@:native('xess_bridge_init_d3d12')
		public static function xessInitD3D12(ctx:cpp.RawPointer<cpp.RawPointer<cpp.Void>>,
			device:RawPointer<cpp.Void>, outW:Int, outH:Int,
			quality:Int, flags:Int):Int { return -1; }

		@:native('xess_bridge_execute_d3d12')
		public static function xessExecuteD3D12(ctx:RawPointer<cpp.Void>, cmdList:RawPointer<cpp.Void>,
			color:RawPointer<cpp.Void>, vel:RawPointer<cpp.Void>,
			depth:RawPointer<cpp.Void>, output:RawPointer<cpp.Void>,
			jx:Float, jy:Float, inW:Int, inH:Int, reset:Int):Int { return -1; }

		@:native('xess_bridge_init_d3d11')
		public static function xessInitD3D11(ctx:cpp.RawPointer<cpp.RawPointer<cpp.Void>>,
			device:RawPointer<cpp.Void>, outW:Int, outH:Int,
			quality:Int, flags:Int):Int { return -1; }

		@:native('xess_bridge_execute_d3d11')
		public static function xessExecuteD3D11(ctx:RawPointer<cpp.Void>, ctx2:RawPointer<cpp.Void>,
			color:RawPointer<cpp.Void>, vel:RawPointer<cpp.Void>,
			depth:RawPointer<cpp.Void>, output:RawPointer<cpp.Void>,
			jx:Float, jy:Float, inW:Int, inH:Int, reset:Int):Int { return -1; }

		@:native('xess_bridge_get_vk_instance_extensions')
		public static function xessGetVkInstanceExtensions(outCount:cpp.RawPointer<cpp.UInt32>,
			outExtensions:cpp.RawPointer<cpp.ConstCharStar>,
			outMinVersion:cpp.RawPointer<cpp.UInt32>):Int { return -2; }

		@:native('xess_bridge_get_vk_device_extensions')
		public static function xessGetVkDeviceExtensions(instance:RawPointer<cpp.Void>,
			physDevice:RawPointer<cpp.Void>,
			outCount:cpp.RawPointer<cpp.UInt32>,
			outExtensions:cpp.RawPointer<cpp.ConstCharStar>):Int { return -2; }

		// ── bgfx native handle extraction (for DLSS/XeSS) ──────────────

		@:native('hxbgfx_get_d3d12_device')
		public static function hxGetD3D12Device():RawPointer<cpp.Void> { return null; }

		@:native('hxbgfx_get_d3d11_device')
		public static function hxGetD3D11Device():RawPointer<cpp.Void> { return null; }

		@:native('hxbgfx_get_d3d11_immediate_context')
		public static function hxGetD3D11ImmediateContext():RawPointer<cpp.Void> { return null; }

		@:native('hxbgfx_get_d3d12_command_queue')
		public static function hxGetD3D12CmdQueue():RawPointer<cpp.Void> { return null; }

		@:native('hxbgfx_get_vk_instance')
		public static function hxGetVkInstance():RawPointer<cpp.Void> { return null; }

		@:native('hxbgfx_get_vk_physical_device')
		public static function hxGetVkPhysDevice():RawPointer<cpp.Void> { return null; }

	@:native('hxbgfx_get_vk_device')
	public static function hxGetVkDevice():RawPointer<cpp.Void> { return null; }

	@:native('hxbgfx_get_mtl_device')
	public static function hxGetMTLDevice():RawPointer<cpp.Void> { return null; }

	@:native('hxbgfx_get_native_texture')
	public static function hxGetNativeTexture(texHandle:Int):RawPointer<cpp.Void> { return null; }

	@:native('hxbgfx_get_native_framebuffer_texture')
	public static function hxGetNativeFBTexture(fbHandle:Int):RawPointer<cpp.Void> { return null; }

	// ── Back-compat stubs (called by existing code, not @:native) ──

	/** Wraps new createTexture2D for old callers that pass ByteArray */
	public static function createTexture2DCompat(w:Int, h:Int, mips:Bool, layers:Int,
		fmt:Int, flags:Int, mem:Dynamic):Int
	{
		if (mem == null) return createTexture2D(w, h, mips, layers, fmt, flags);
		var bytes:haxe.io.Bytes = cast mem;
		var size = bytes.length;
		var ptr:RawPointer<cpp.Void> = untyped __cpp__('(void*)&({0}->b[0])', bytes);
		return createTexture2D(w, h, mips, layers, fmt, flags); // fallback, no data path
	}

	public static function copy(data:Dynamic, sz:Int):Dynamic { return data; } // identity on native path

	public static function vertexLayoutBegin(l:Dynamic, r:Int):Void {}
	public static function vertexLayoutAdd(l:Dynamic, a:Int, n:Int, t:Int, norm:Bool, asInt:Bool):Void {}
	public static function vertexLayoutEnd(l:Dynamic):Void {}

	public static function allocTransientVertexBuffer(tvb:Dynamic, n:Int, layout:Dynamic):Void
	{
		var outNum:Int = 0;
		var l:BgfxVertexLayout = cast layout;
		var hash = untyped __cpp__('{0}->hash', l);
		var stride = untyped __cpp__('{0}->stride', l);
		var ptr = allocTransientVB(n, hash, stride, cast cpp.Pointer.addressOf(outNum));
		var t:BgfxTransientVertexBuffer = cast tvb;
		untyped __cpp__('{0}->data = {1}; {0}->size = {2} * {3}', t, ptr, outNum, stride);
	}




		// ── FSR 2/3.1 bridge ────────────────────────────────────────────

		@:native('fsr2_bridge_init')
		public static function fsr2Init(ctx:cpp.RawPointer<cpp.RawPointer<cpp.Void>>,
		version:Int, maxRW:Int, maxRH:Int, dispW:Int, dispH:Int,
		hdr:Bool, depthInv:Bool, autoExp:Bool):Int { return -1; }

		@:native('fsr2_bridge_dispatch')
		public static function fsr2Dispatch(ctx:cpp.RawPointer<cpp.Void>, cmdList:cpp.RawPointer<cpp.Void>,
		color:cpp.RawPointer<cpp.Void>, depth:cpp.RawPointer<cpp.Void>, mv:cpp.RawPointer<cpp.Void>,
		output:cpp.RawPointer<cpp.Void>,
		jx:Float, jy:Float, mvScaleX:Float, mvScaleY:Float,
		renderW:Int, renderH:Int, sharpness:Float,
		frameTimeDelta:Float, preExposure:Float, reset:Bool,
		cameraNear:Float, cameraFar:Float, cameraFov:Float):Int { return -1; }

		@:native('fsr2_bridge_destroy')
		public static function fsr2Destroy(ctx:cpp.RawPointer<cpp.Void>):Int { return -1; }

		@:native('fsr2_bridge_get_jitter_offset')
		public static function fsr2GetJitterOffset(ctx:cpp.RawPointer<cpp.Void>,
		index:Int, phaseCount:Int, outX:cpp.RawPointer<cpp.Float32>, outY:cpp.RawPointer<cpp.Float32>):Int { return -1; }

		@:native('fsr2_bridge_get_jitter_phase_count')
		public static function fsr2GetJitterPhaseCount(renderW:Int, displayW:Int):Int { return 8; }

		@:native('fsr2_bridge_get_render_resolution')
		public static function fsr2GetRenderResolution(ctx:cpp.RawPointer<cpp.Void>,
		dispW:Int, dispH:Int, outRW:cpp.RawPointer<cpp.UInt32>, outRH:cpp.RawPointer<cpp.UInt32>):Int { return -1; }
}
