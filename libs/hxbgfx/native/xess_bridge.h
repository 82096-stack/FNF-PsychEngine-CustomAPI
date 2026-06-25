// xess_bridge.h — Thin C wrapper for Intel XeSS SDK
//
// Wraps the XeSS C API into individual primitive-parameter functions
// callable from Haxe via @:native.
//
// Requires: Intel XeSS SDK (inc/xess/xess.h + lib/libxess.lib or libxess.dll)
// Platform: Windows (D3D11/D3D12/Vulkan)
//
// Usage from Haxe:
//   @:native('xess_bridge_init_vk')  static function initVK(...):Int { return -1; }

#ifndef XESS_BRIDGE_H
#define XESS_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Result codes matching xess_result_t
#define XESS_BRIDGE_RESULT_SUCCESS           0
#define XESS_BRIDGE_RESULT_ERROR_UNKNOWN     -1
#define XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED -2

// Quality settings
#define XESS_BRIDGE_QUALITY_ULTRA_PERFORMANCE  100
#define XESS_BRIDGE_QUALITY_PERFORMANCE        101
#define XESS_BRIDGE_QUALITY_BALANCED           102
#define XESS_BRIDGE_QUALITY_QUALITY            103
#define XESS_BRIDGE_QUALITY_ULTRA_QUALITY      104
#define XESS_BRIDGE_QUALITY_ULTRA_QUALITY_PLUS 105
#define XESS_BRIDGE_QUALITY_AA                 106

// Init flags
#define XESS_BRIDGE_INIT_FLAG_NONE              0
#define XESS_BRIDGE_INIT_FLAG_LDR_INPUT_COLOR   (1 << 6)  // 64 — XESS_INIT_FLAG_LDR_INPUT_COLOR

// ================================================================
// Vulkan backend
// ================================================================

/** Query required instance extensions before creating VkInstance. */
int xess_bridge_get_vk_instance_extensions(
    uint32_t* pCount,
    const char** ppExtensions,
    uint32_t* pMinVkApiVersion);

/** Query required device extensions before creating VkDevice. */
int xess_bridge_get_vk_device_extensions(
    void* vkInstance,
    void* vkPhysicalDevice,
    uint32_t* pCount,
    const char** ppExtensions);

/** Create XeSS context for Vulkan. */
int xess_bridge_init_vk(
    void** outContext,
    void* vkInstance,
    void* vkPhysicalDevice,
    void* vkDevice,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualitySetting,
    uint32_t initFlags);

/** Get input (render) resolution for a given output resolution and quality. */
int xess_bridge_get_input_resolution(
    void* context,
    uint32_t outputWidth, uint32_t outputHeight,
    int qualitySetting,
    uint32_t* pInputWidth,
    uint32_t* pInputHeight);

/** Get jitter offset for temporal anti-aliasing. */
int xess_bridge_get_jitter_scale(
    void* context,
    float* pX,
    float* pY);

/** Execute XeSS upscaling for a frame (Vulkan). */
int xess_bridge_execute_vk(
    void* context,
    void* vkCommandBuffer,
    void* colorTexture,       // Low-res input
    void* velocityTexture,    // Motion vectors
    void* depthTexture,       // Depth buffer
    void* outputTexture,      // High-res output
    float jitterOffsetX,
    float jitterOffsetY,
    uint32_t inputWidth,
    uint32_t inputHeight,
    int resetHistory);

// ================================================================
// D3D12 backend
// ================================================================

/** Create XeSS context for D3D12. */
int xess_bridge_init_d3d12(
    void** outContext,
    void* d3d12Device,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualitySetting,
    uint32_t initFlags);

/** Execute XeSS upscaling for a frame (D3D12). */
int xess_bridge_execute_d3d12(
    void* context,
    void* d3d12CommandList,
    void* colorTexture,       // ID3D12Resource* low-res input
    void* velocityTexture,    // ID3D12Resource* motion vectors (optional for 2D)
    void* depthTexture,       // ID3D12Resource* depth (optional for 2D)
    void* outputTexture,      // ID3D12Resource* high-res output
    float jitterOffsetX,
    float jitterOffsetY,
    uint32_t inputWidth,
    uint32_t inputHeight,
    int resetHistory);

// ================================================================

// ================================================================
// D3D11 backend (Intel Arc only)
// ================================================================

/** Create XeSS context for D3D11. */
int xess_bridge_init_d3d11(
    void** outContext,
    void* d3d11Device,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualitySetting,
    uint32_t initFlags);

/** Execute XeSS upscaling for a frame (D3D11). */
int xess_bridge_execute_d3d11(
    void* context,
    void* d3d11DeviceContext,
    void* colorTexture,
    void* velocityTexture,
    void* depthTexture,
    void* outputTexture,
    float jitterOffsetX,
    float jitterOffsetY,
    uint32_t inputWidth,
    uint32_t inputHeight,
    int resetHistory);


// Common
// ================================================================

/** Destroy XeSS context. */
int xess_bridge_destroy_context(void* context);

/** Check if XeSS is supported on this system. */
int xess_bridge_is_supported(void);

#ifdef __cplusplus
}
#endif

#endif // XESS_BRIDGE_H
