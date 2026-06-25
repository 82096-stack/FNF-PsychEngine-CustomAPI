// macos_stubs.cpp — Weak stub implementations for Windows-only functions on macOS
// These functions are only available on Windows (D3D12/Vulkan via dlss_bridge.cpp and xess_bridge.cpp).
// On macOS, we provide weak stubs that return "unsupported" codes.
// When linked with real bridge files, the linker prefers strong symbols.

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

extern "C" {

// ── DLSS weak stubs ────────────────────────────────────────────────
__attribute__((weak)) void  dlss_bridge_set_app_id_string(const char* hex) {}
__attribute__((weak)) bool  dlss_bridge_is_supported(void) { return false; }
__attribute__((weak)) uint64_t dlss_bridge_get_available_presets(void) { return 0; }
__attribute__((weak)) const char* dlss_bridge_preset_to_name(int v) { return NULL; }
__attribute__((weak)) int   dlss_bridge_preset_from_name(const char* name) { return -1; }
__attribute__((weak)) int   dlss_bridge_init_d3d12(void* d, const char* p, int ow, int oh, int q, int pr) { return -1; }
__attribute__((weak)) int   dlss_bridge_create_feature_d3d12(void* q, int iw, int ih, int ow, int oh, int qm, int pr, bool ae, bool hdr) { return -1; }
__attribute__((weak)) int   dlss_bridge_evaluate_d3d12(void* cl, void* ci, void* co, void* db, void* mv, float jx, float jy, float sh, bool rh) { return -1; }
__attribute__((weak)) int   dlss_bridge_release_feature(void) { return -1; }
__attribute__((weak)) int   dlss_bridge_shutdown_d3d12(void) { return -1; }
__attribute__((weak)) int   dlss_bridge_get_optimal_settings(int ow, int oh, int q, int* rw, int* rh) { return -1; }

// ── XeSS weak stubs ────────────────────────────────────────────────
__attribute__((weak)) int   xess_bridge_is_supported(void) { return -2; }
__attribute__((weak)) int   xess_bridge_init_vk(void** ctx, void* inst, void* pd, void* dev, int ow, int oh, int qs, int fl) { return -1; }
__attribute__((weak)) int   xess_bridge_get_input_resolution(void* ctx, int* w, int* h) { return -1; }
__attribute__((weak)) int   xess_bridge_execute_vk(void* ctx, void* cb, void* ct, void* vt, void* dt, void* ot, float jx, float jy, int iw, int ih, int rh) { return -1; }
__attribute__((weak)) int   xess_bridge_destroy_context(void* ctx) { return -1; }

}
