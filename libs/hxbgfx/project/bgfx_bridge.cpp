// bgfx_bridge.cpp — Haxe CFFI bridge for bgfx + upscaling support
//
// Provides wrapped bgfx C99 API functions that take individual primitive
// parameters instead of struct pointers, so Haxe can call them via @:native.
// Also provides GPU vendor detection for upscaler validation.

#include "bgfx_bridge.h"
#include <SDL.h>
#include <string.h>
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#include <dxgi1_2.h>    // IDXGIFactory1 for GPU detection
#elif defined(__APPLE__)
#include <TargetConditionals.h>
#include <sys/sysctl.h> // sysctlbyname for Apple Silicon detection
#if TARGET_OS_MAC
#include <Cocoa/Cocoa.h>
#endif
#elif defined(__linux__)
#include <X11/Xlib.h>
#endif

// ================================================================
// SDL window auto-detection
// ================================================================
static SDL_Window* get_sdl_window(void)
{
    SDL_Window* win = SDL_GL_GetCurrentWindow();
    if (win != NULL) return win;
    win = SDL_GetWindowFromID(1);
    if (win != NULL) return win;
    return NULL;
}

extern "C" void hxbgfx_set_sdl_window(void* window) { (void)window; }

void* hxbgfx_get_native_window_handle(void)
{
    SDL_Window* win = get_sdl_window();
    if (win == NULL) return NULL;
    SDL_SysWMinfo wmInfo;
    SDL_VERSION(&wmInfo.version);
    if (!SDL_GetWindowWMInfo(win, &wmInfo)) return NULL;
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
    if (!SDL_GetWindowWMInfo(win, &wmInfo)) return NULL;
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

// ================================================================
// bgfx_init wrapper
// ================================================================
bool hxbgfx_wrapped_init(
    int rendererType, void* nwh, void* ndt,
    int width, int height, int format, int resetFlags,
    int numBackBuffers, int maxFrameLatency,
    int maxEncoders, int transientVbSize, int transientIbSize)
{
    bgfx_init_t init;
    memset(&init, 0, sizeof(init));

    init.type = (bgfx_renderer_type_t)rendererType;

    if (nwh != NULL) {
        init.platformData.nwh = nwh;
    }
    if (ndt != NULL) {
        init.platformData.ndt = ndt;
    }

    init.resolution.width = (uint32_t)width;
    init.resolution.height = (uint32_t)height;
    init.resolution.format = (bgfx_texture_format_t)format;
    init.resolution.reset = (uint32_t)resetFlags;
    init.resolution.numBackBuffers = (uint8_t)numBackBuffers;
    init.resolution.maxFrameLatency = (uint8_t)maxFrameLatency;

    init.limits.maxEncoders = (uint16_t)maxEncoders;
    init.limits.transientVbSize = (uint32_t)transientVbSize;
    init.limits.transientIbSize = (uint32_t)transientIbSize;

    return bgfx_init(&init);
}

// ================================================================
// Core lifecycle
// ================================================================
void hxbgfx_wrapped_shutdown(void)
{
    bgfx_shutdown();
}

void hxbgfx_wrapped_reset(int width, int height, int resetFlags, int format,
    int numBackBuffers, int maxFrameLatency)
{
    bgfx_reset((uint32_t)width, (uint32_t)height, (uint32_t)resetFlags,
               (bgfx_texture_format_t)format);
}

uint32_t hxbgfx_wrapped_frame(bool capture)
{
    return bgfx_frame(capture);
}

void hxbgfx_wrapped_touch(uint16_t viewId)
{
    bgfx_touch((bgfx_view_id_t)viewId);
}

// ================================================================
// View management
// ================================================================
void hxbgfx_wrapped_set_view_rect(uint16_t viewId, uint16_t x, uint16_t y,
    uint16_t width, uint16_t height)
{
    bgfx_set_view_rect((bgfx_view_id_t)viewId, x, y, width, height);
}

void hxbgfx_wrapped_set_view_clear(uint16_t viewId, uint16_t flags,
    uint32_t rgba, float depth, uint8_t stencil)
{
    bgfx_set_view_clear((bgfx_view_id_t)viewId, (uint16_t)flags, rgba, depth, stencil);
}

void hxbgfx_wrapped_set_view_transform(uint16_t viewId,
    const float* viewMatrix, const float* projMatrix)
{
    bgfx_set_view_transform((bgfx_view_id_t)viewId, viewMatrix, projMatrix);
}

// ================================================================
// Render state & submit
// ================================================================
void hxbgfx_wrapped_submit(uint16_t viewId, uint16_t programHandle,
    uint32_t depth, uint8_t flags)
{
    bgfx_submit((bgfx_view_id_t)viewId, (bgfx_program_handle_t){programHandle},
                depth, (uint8_t)flags);
}

void hxbgfx_wrapped_set_state(uint64_t state, uint32_t rgba)
{
    bgfx_set_state(state, rgba);
}

void hxbgfx_wrapped_set_texture(uint8_t stage, uint16_t sampler,
    uint16_t textureHandle, uint32_t flags)
{
    bgfx_set_texture(stage, (bgfx_uniform_handle_t){sampler},
                     (bgfx_texture_handle_t){textureHandle}, flags);
}

void hxbgfx_wrapped_set_uniform(uint16_t uniformHandle, const void* data, uint32_t size)
{
    if (data != NULL && size > 0)
        bgfx_set_uniform((bgfx_uniform_handle_t){uniformHandle}, data, (uint16_t)size);
}

// ================================================================
// Transient vertex buffer
// ================================================================
void* hxbgfx_wrapped_alloc_transient_vertex_buffer(
    int numVertices, int layoutHash, int layoutStride, int* outNumVertices)
{
    if (numVertices <= 0 || outNumVertices == NULL) return NULL;

    bgfx_vertex_layout_t layout;
    layout.hash = (uint32_t)layoutHash;
    layout.stride = (uint16_t)layoutStride;

    bgfx_transient_vertex_buffer_t tvb;
    bgfx_alloc_transient_vertex_buffer(&tvb, (uint32_t)numVertices, &layout);

    if (tvb.size == 0) {
        *outNumVertices = 0;
        return NULL;
    }

    *outNumVertices = (int)(tvb.size / layoutStride);
    return tvb.data;
}

// ================================================================
// Textures
// ================================================================
uint16_t hxbgfx_wrapped_create_texture_2d(uint16_t width, uint16_t height,
    bool hasMips, uint16_t numLayers, uint64_t format, uint64_t flags)
{
    bgfx_texture_handle_t handle = bgfx_create_texture_2d(
        width, height, hasMips, numLayers,
        (bgfx_texture_format_t)format, flags, NULL);
    return handle.idx;
}

uint16_t hxbgfx_wrapped_create_texture_2d_with_data(uint16_t width, uint16_t height,
    bool hasMips, uint16_t numLayers, uint64_t format, uint64_t flags,
    const void* data, uint32_t dataSize)
{
    if (data == NULL || dataSize == 0) {
        return hxbgfx_wrapped_create_texture_2d(width, height, hasMips, numLayers, format, flags);
    }
    const bgfx_memory_t* mem = bgfx_make_ref(data, dataSize);
    bgfx_texture_handle_t handle = bgfx_create_texture_2d(
        width, height, hasMips, numLayers,
        (bgfx_texture_format_t)format, flags, mem);
    return handle.idx;
}

uint16_t hxbgfx_wrapped_create_render_texture(uint16_t width, uint16_t height,
    uint64_t format)
{
    uint64_t flags = BGFX_TEXTURE_RT | BGFX_SAMPLER_U_CLAMP | BGFX_SAMPLER_V_CLAMP;
    bgfx_texture_handle_t handle = bgfx_create_texture_2d(
        width, height, false, 1, (bgfx_texture_format_t)format, flags, NULL);
    return handle.idx;
}

// ================================================================
// Frame buffers
// ================================================================
uint16_t hxbgfx_wrapped_create_frame_buffer(uint16_t textureHandle)
{
    bgfx_texture_handle_t tex = {textureHandle};
    bgfx_frame_buffer_handle_t fb = bgfx_create_frame_buffer(1, &tex, true);
    return fb.idx;
}

void hxbgfx_wrapped_set_view_frame_buffer(uint16_t viewId, uint16_t frameBufferHandle)
{
    bgfx_frame_buffer_handle_t fb = {frameBufferHandle};
    bgfx_set_view_frame_buffer((bgfx_view_id_t)viewId, fb);
}

// ================================================================
// Destroy
// ================================================================
bool hxbgfx_read_texture_bytes(uint16_t texHandle, void* outBuf, uint32_t bufSize,
    uint32_t width, uint32_t height)
{
    if (outBuf == NULL || bufSize == 0) return false;

    // Use bgfx C++ API for texture readback
    // bgfx::readTexture is available in the internal C++ API
    bgfx_texture_handle_t handle = {texHandle};
    uint32_t expectedSize = width * height * 4; // BGRA8
    if (bufSize < expectedSize) return false;

    // bgfx::readTexture copies texture data to CPU memory
    // This is a synchronous read — call after bgfx::frame() to ensure GPU is done
    bgfx::readTexture(handle, outBuf, 0);
    return true;
}

void hxbgfx_wrapped_destroy_texture(uint16_t handle)
{
    if (handle != 0) {
        bgfx_texture_handle_t tex = {handle};
        bgfx_destroy_texture(tex);
    }
}

void hxbgfx_wrapped_destroy_frame_buffer(uint16_t handle)
{
    if (handle != 0) {
        bgfx_frame_buffer_handle_t fb = {handle};
        bgfx_destroy_frame_buffer(fb);
    }
}

// ================================================================
// Shaders & programs
// ================================================================
uint16_t hxbgfx_wrapped_create_shader(const void* data, uint32_t size)
{
    if (data == NULL || size == 0) return 0;
    const bgfx_memory_t* mem = bgfx_make_ref(data, size);
    bgfx_shader_handle_t handle = bgfx_create_shader(mem);
    return handle.idx;
}

uint16_t hxbgfx_wrapped_create_program(uint16_t vs, uint16_t fs, bool destroyShaders)
{
    bgfx_shader_handle_t vsHandle = {vs};
    bgfx_shader_handle_t fsHandle = {fs};
    bgfx_program_handle_t handle = bgfx_create_program(vsHandle, fsHandle, destroyShaders);
    return handle.idx;
}

void hxbgfx_wrapped_destroy_program(uint16_t handle)
{
    if (handle != 0) {
        bgfx_program_handle_t prog = {handle};
        bgfx_destroy_program(prog);
    }
}

uint16_t hxbgfx_wrapped_create_uniform(const char* name, uint16_t type, uint16_t num)
{
    bgfx_uniform_handle_t handle = bgfx_create_uniform(name, (bgfx_uniform_type_t)type, num);
    return handle.idx;
}

// ================================================================
// Renderer info
// ================================================================
int hxbgfx_wrapped_get_renderer_type(void)
{
    bgfx_renderer_type_t type = bgfx_get_renderer_type();
    return (int)type;
}

const char* hxbgfx_wrapped_get_renderer_name(int type, char* buffer, int bufferSize)
{
    if (buffer == NULL || bufferSize <= 0) return NULL;
    const char* name = bgfx_get_renderer_name((bgfx_renderer_type_t)type);
    if (name == NULL) {
        buffer[0] = '\0';
        return buffer;
    }
    strncpy(buffer, name, (size_t)bufferSize - 1);
    buffer[bufferSize - 1] = '\0';
    return buffer;
}

// ================================================================
// GPU vendor / architecture queries (real platform implementations)
// ================================================================

// Helper: parse PCI vendor ID into vendor enum
static int vendorFromPCID(unsigned int vendorId)
{
    switch (vendorId) {
        case 0x10DE: return 1; // NVIDIA
        case 0x1002: return 2; // AMD
        case 0x8086: return 3; // Intel
        default:     return 0; // Unknown
    }
}

// Helper: NVIDIA architecture from PCI device ID
static int nvidiaArchFromDevID(unsigned int devId)
{
    if (devId >= 0x2000) return 5; // Blackwell (RTX 50xx)
    if (devId >= 0x2700) return 4; // Ada Lovelace (RTX 40xx)
    if (devId >= 0x2200) return 3; // Ampere (RTX 30xx)
    if (devId >= 0x1E00) return 2; // Turing (RTX 20xx / GTX 16xx)
    if (devId >= 0x1B00) return 1; // Pascal (GTX 10xx)
    if (devId >= 0x1300) return 0; // Maxwell (GTX 9xx)
    return 0;
}

// Helper: AMD architecture from PCI device ID
static int amdArchFromDevID(unsigned int devId)
{
    if (devId >= 0x7500) return 4; // RDNA4 (RX 9000)
    if (devId >= 0x7400) return 3; // RDNA3 (RX 7000)
    if (devId >= 0x7300) return 2; // RDNA2 (RX 6000)
    if (devId >= 0x7310) return 1; // RDNA1 (RX 5000)
    return 0; // GCN or older
}

int hxbgfx_get_gpu_vendor(void)
{
#ifdef __APPLE__
    return 4; // Apple
#elif defined(_WIN32)
    IDXGIFactory1* factory = NULL;
    HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory);
    if (FAILED(hr)) return 0;
    IDXGIAdapter1* adapter = NULL;
    hr = factory->EnumAdapters1(0, &adapter);
    factory->Release();
    if (FAILED(hr)) return 0;
    DXGI_ADAPTER_DESC1 desc;
    adapter->GetDesc1(&desc);
    adapter->Release();
    return vendorFromPCID(desc.VendorId);
#elif defined(__linux__)
    FILE* f = fopen("/sys/class/drm/card0/device/vendor", "r");
    if (!f) return 0;
    unsigned int vendor = 0;
    fscanf(f, "0x%x", &vendor);
    fclose(f);
    return vendorFromPCID(vendor);
#else
    return 0;
#endif
}

int hxbgfx_get_gpu_architecture(void)
{
#ifdef __APPLE__
    return hxbgfx_get_apple_silicon_generation() > 0 ? 1 : 0; // M1+ = 1
#elif defined(_WIN32)
    IDXGIFactory1* factory = NULL;
    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), (void**)&factory)))
        return 0;
    IDXGIAdapter1* adapter = NULL;
    HRESULT hr = factory->EnumAdapters1(0, &adapter);
    factory->Release();
    if (FAILED(hr)) return 0;
    DXGI_ADAPTER_DESC1 desc;
    adapter->GetDesc1(&desc);
    adapter->Release();
    int vendor = vendorFromPCID(desc.VendorId);
    if (vendor == 1) return nvidiaArchFromDevID(desc.DeviceId);
    if (vendor == 2) return amdArchFromDevID(desc.DeviceId);
    return 0;
#elif defined(__linux__)
    int vendor = hxbgfx_get_gpu_vendor();
    if (vendor == 0) return 0;
    FILE* f = fopen("/sys/class/drm/card0/device/device", "r");
    if (!f) return 0;
    unsigned int devId = 0;
    fscanf(f, "0x%x", &devId);
    fclose(f);
    if (vendor == 1) return nvidiaArchFromDevID(devId);
    if (vendor == 2) return amdArchFromDevID(devId);
    return 0;
#else
    return 0;
#endif
}

int hxbgfx_get_apple_silicon_generation(void)
{
#ifdef __APPLE__
    // Try sysctl brand string first (simplest, works on all macOS versions)
    char brand[256] = {0};
    size_t len = sizeof(brand);
    if (sysctlbyname("machdep.cpu.brand_string", brand, &len, NULL, 0) == 0) {
        if (strstr(brand, "M4")) return 4;
        if (strstr(brand, "M3")) return 3;
        if (strstr(brand, "M2")) return 2;
        if (strstr(brand, "M1")) return 1;
    }
    // Try CPU family as fallback
    int family = 0;
    len = sizeof(family);
    if (sysctlbyname("hw.cpufamily", &family, &len, NULL, 0) == 0) {
        // Apple CPU family IDs (approximate)
        if (family >= 0xFA33415F) return 4; // M4+
        if (family >= 0xFA33415E) return 3; // M3
        if (family >= 0xDA33D83D) return 2; // M2
        if (family >= 0x1B588BB3) return 1; // M1
    }
    return 0; // Intel Mac or unknown
#else
    return 0;
#endif
}

// ================================================================
// Native handle extraction (bgfx C++ internal API)
// ================================================================

#include <bgfx/bgfx.h>

void* hxbgfx_get_d3d12_device(void)
{
#ifdef _WIN32
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal != NULL) return internal->context; // ID3D12Device* on D3D12
#endif
    return NULL;
}

extern "C" void* hxbgfx_get_d3d11_device(void)
{
#ifdef _WIN32
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal != NULL) return internal->context; // ID3D11Device* on D3D11
#endif
    return NULL;
}

extern "C" void* hxbgfx_get_d3d11_immediate_context(void)
{
#ifdef _WIN32
    ID3D11Device* device = (ID3D11Device*)hxbgfx_get_d3d11_device();
    if (device != NULL) {
        ID3D11DeviceContext* ctx = NULL;
        device->GetImmediateContext(&ctx);
        return (void*)ctx;
    }
#endif
    return NULL;
}

void* hxbgfx_get_d3d12_command_queue(void)
{
#ifdef _WIN32
    // bgfx InternalData doesn't directly expose command queue
    // DLSS can use the device to create its own command queue
    return NULL;
#else
    return NULL;
#endif
}

extern "C" void* hxbgfx_get_vk_instance(void)
{
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal == NULL) return NULL;
    // On Vulkan backend, internal data has VkInstance
    // Access through platform-specific cast
    return NULL; // VK instance not available on macOS
}

extern "C" void* hxbgfx_get_vk_physical_device(void)
{
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal == NULL) return NULL;
    return NULL; // VK physical device not available on macOS
}

extern "C" void* hxbgfx_get_vk_device(void)
{
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal == NULL) return NULL;
    return internal->context; // VkDevice on Vulkan backend
}

extern "C" void* hxbgfx_get_mtl_device(void)
{
#ifdef __APPLE__
    const bgfx::InternalData* internal = bgfx::getInternalData();
    if (internal != NULL) return internal->context; // id<MTLDevice> on Metal
#endif
    return NULL;
}

extern "C" void* hxbgfx_get_native_texture(uint16_t texHandle)
{
    bgfx::TextureHandle handle = { texHandle };
    if (!bgfx::isValid(handle)) return NULL;
    // bgfx::getInternal(TextureHandle) returns uintptr_t — the native GPU texture pointer
    // On Metal: returns MTL::Texture* (id<MTLTexture>)
    // On D3D12: returns ID3D12Resource*
    // On Vulkan: returns 0 (not implemented in this bgfx version)
    return (void*)bgfx::getInternal(handle);
}

extern "C" void* hxbgfx_get_native_framebuffer_texture(uint16_t fbHandle)
{
    bgfx::FrameBufferHandle handle = { fbHandle };
    if (!bgfx::isValid(handle)) return NULL;
    // bgfx::getTexture(FrameBufferHandle, attachment) — public C++ API
    bgfx::TextureHandle tex = bgfx::getTexture(handle, 0);
    if (!bgfx::isValid(tex)) return NULL;
    return (void*)bgfx::getInternal(tex);
}
