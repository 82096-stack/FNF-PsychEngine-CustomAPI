// bgfx_bridge.cpp — Platform window handle acquisition for hxbgfx
//
// Auto-detects the SDL2 window that Lime creates (Lime uses SDL2
// on all desktop platforms) and extracts the native window handle
// for bgfx's PlatformData.
//
// No Haxe-side window registration is needed — this finds the window
// automatically when hxbgfx_get_native_window_handle() is called.

#include "bgfx_bridge.h"
#include <SDL.h>

#ifdef _WIN32
#include <windows.h>
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_MAC
#include <Cocoa/Cocoa.h>
#endif
#elif defined(__linux__)
#include <X11/Xlib.h>
#endif

// Auto-detect the SDL window — Lime creates exactly one
static SDL_Window* get_sdl_window(void)
{
	// Try GL context window first (works for OpenGL backend)
	SDL_Window* win = SDL_GL_GetCurrentWindow();
	if (win != NULL) return win;

	// Fallback for Vulkan/D3D12/Metal backends:
	// Iterate SDL windows. Lime always creates exactly one.
	Uint32 windowCount = 0;
	SDL_Window* windows[1];
	// SDL 2.0 doesn't have SDL_GetWindows(), use the hack:
	// SDL stores windows in a global list. Window ID 1 is the first window.
	win = SDL_GetWindowFromID(1);
	if (win != NULL) return win;

	return NULL;
}

// Called by Haxe side (optional, for explicit registration)
extern "C" void hxbgfx_set_sdl_window(void* window)
{
	// No longer needed — auto-detection handles this
	(void)window;
}

void* hxbgfx_get_native_window_handle(void)
{
	SDL_Window* win = get_sdl_window();
	if (win == NULL) return NULL;

	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);

	if (!SDL_GetWindowWMInfo(win, &wmInfo))
		return NULL;

#ifdef _WIN32
	return (void*)wmInfo.info.win.window;
#elif defined(__APPLE__)
	return (void*)wmInfo.info.cocoa.window;
#elif defined(__linux__)
	return (void*)(uintptr_t)wmInfo.info.x11.window;
#else
	return NULL;
#endif
}

void* hxbgfx_get_native_display_handle(void)
{
	SDL_Window* win = get_sdl_window();
	if (win == NULL) return NULL;

	SDL_SysWMinfo wmInfo;
	SDL_VERSION(&wmInfo.version);

	if (!SDL_GetWindowWMInfo(win, &wmInfo))
		return NULL;

#ifdef _WIN32
	return (void*)wmInfo.info.win.hinstance;
#elif defined(__APPLE__)
	return NULL;
#elif defined(__linux__)
	return (void*)wmInfo.info.x11.display;
#else
	return NULL;
#endif
}

bgfx_renderer_type_t hxbgfx_get_best_renderer(void)
{
#ifdef _WIN32
	return BGFX_RENDERER_TYPE_DIRECT3D12;
#elif defined(__APPLE__)
	return BGFX_RENDERER_TYPE_METAL;
#elif defined(__linux__)
	return BGFX_RENDERER_TYPE_VULKAN;
#else
	return BGFX_RENDERER_TYPE_OPENGL;
#endif
}

uint64_t hxbgfx_get_supported_renderers(void)
{
	uint64_t supported = 0;

#ifdef _WIN32
	supported |= (1ULL << BGFX_RENDERER_TYPE_DIRECT3D11);
	supported |= (1ULL << BGFX_RENDERER_TYPE_DIRECT3D12);
	supported |= (1ULL << BGFX_RENDERER_TYPE_VULKAN);
	supported |= (1ULL << BGFX_RENDERER_TYPE_OPENGL);
#elif defined(__APPLE__)
	supported |= (1ULL << BGFX_RENDERER_TYPE_METAL);
	supported |= (1ULL << BGFX_RENDERER_TYPE_OPENGL);
#elif defined(__linux__)
	supported |= (1ULL << BGFX_RENDERER_TYPE_VULKAN);
	supported |= (1ULL << BGFX_RENDERER_TYPE_OPENGL);
#else
	supported |= (1ULL << BGFX_RENDERER_TYPE_OPENGL);
	supported |= (1ULL << BGFX_RENDERER_TYPE_OPENGLES);
#endif

	return supported;
}
