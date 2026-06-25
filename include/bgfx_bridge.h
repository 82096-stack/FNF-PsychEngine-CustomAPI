// Lightweight declarations for Haxe @:native — no bgfx header dependencies
#ifndef HXBGFX_BRIDGE_LIGHT_H
#define HXBGFX_BRIDGE_LIGHT_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif

// ── bgfx core (wrapped) ──────────────────────────────────────────
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
const char* hxbgfx_wrapped_get_renderer_name(int,char*,int);

// ── GPU queries ───────────────────────────────────────────────────
int   hxbgfx_get_gpu_vendor(void);
int   hxbgfx_get_gpu_architecture(void);
int   hxbgfx_get_apple_silicon_generation(void);

// ── bgfx native handle extraction ─────────────────────────────────
void* hxbgfx_get_d3d12_device(void);
void* hxbgfx_get_d3d12_command_queue(void);
void* hxbgfx_get_vk_instance(void);
void* hxbgfx_get_vk_physical_device(void);
void* hxbgfx_get_vk_device(void);
void* hxbgfx_get_mtl_device(void);
void* hxbgfx_get_native_texture(uint16_t);
void* hxbgfx_get_native_framebuffer_texture(uint16_t);

// ── MetalFX bridge ────────────────────────────────────────────────
bool  metalfx_init(void* mtlDevice, int iw, int ih, int ow, int oh, int mode);
bool  metalfx_apply(void* inputMTLTexture, void* outputMTLTexture);
bool  metalfx_is_supported(void* mtlDevice);
void  metalfx_reset(void);
void  metalfx_dispose(void);

// ── DLSS bridge ───────────────────────────────────────────────────
void  dlss_bridge_set_app_id_string(const char*);
bool  dlss_bridge_is_supported(void);
uint64_t dlss_bridge_get_available_presets(void);
const uint8_t* dlss_bridge_preset_to_name(int);
int   dlss_bridge_preset_from_name(const char*);
int   dlss_bridge_init_d3d12(void*,const char*,int,int,int,int);
int   dlss_bridge_create_feature_d3d12(void*,int,int,int,int,int,int,bool,bool);
int   dlss_bridge_evaluate_d3d12(void*,void*,void*,void*,void*,float,float,float,bool);
int   dlss_bridge_release_feature(void);
int   dlss_bridge_shutdown_d3d12(void);
int   dlss_bridge_get_optimal_settings(int,int,int,int*,int*);

// ── XeSS bridge ──────────────────────────────────────────────────
int   xess_bridge_is_supported(void);
int   xess_bridge_init_vk(void**,void*,void*,void*,int,int,int,int);
int   xess_bridge_get_input_resolution(void*,int*,int*);
int   xess_bridge_execute_vk(void*,void*,void*,void*,void*,void*,float,float,int,int,int);
int   xess_bridge_destroy_context(void*);

#ifdef __cplusplus
}
#endif
#endif
