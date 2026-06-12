// bgfx_bridge.h — Haxe CFFI bridge for platform window handle acquisition
// Used by hxbgfx to get native window/display handles from Lime/OpenFL/SDL

#ifndef HXBGFX_BRIDGE_H
#define HXBGFX_BRIDGE_H

#include <bgfx/c99/bgfx.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Get the native window handle for the current Lime/OpenFL window.
 * On Windows: returns HWND
 * On macOS:   returns NSWindow*
 * On Linux:   returns X11 Window (unsigned long)
 */
void* hxbgfx_get_native_window_handle(void);

/**
 * Get the native display handle for the current platform.
 * On Windows: returns HINSTANCE
 * On macOS:   returns NULL (not needed)
 * On Linux:   returns X11 Display*
 */
void* hxbgfx_get_native_display_handle(void);

/**
 * Get the best bgfx renderer type for the current platform.
 * Returns one of bgfx_renderer_type_t values.
 */
bgfx_renderer_type_t hxbgfx_get_best_renderer(void);

/**
 * Get a bitmask of all supported renderer types on the current platform.
 */
uint64_t hxbgfx_get_supported_renderers(void);

#ifdef __cplusplus
}
#endif

#endif // HXBGFX_BRIDGE_H
