// dlss_bridge.h — Thin C wrapper for NVIDIA DLSS (NGX) SDK
//
// Wraps the NGX C++ parameter interface into simple C functions
// callable from Haxe via @:native.
//
// Requires: NVIDIA DLSS SDK (include/nvsdk_ngx.h + lib/nvsdk_ngx*.lib)
// Platform: Windows (D3D11/D3D12/Vulkan), Linux (Vulkan)
// GPU:      NVIDIA RTX 20-series or newer
//
// IMPORTANT: DLSS requires an NVIDIA Application ID. Set via DLSS_BRIDGE_APP_ID
// or call dlss_bridge_set_app_id() before init.

#ifndef DLSS_BRIDGE_H
#define DLSS_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Result codes
#define DLSS_BRIDGE_RESULT_SUCCESS           0
#define DLSS_BRIDGE_RESULT_ERROR_UNKNOWN     -1
#define DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED -2
#define DLSS_BRIDGE_RESULT_ERROR_NOT_INIT    -3

// Quality / Performance modes
#define DLSS_BRIDGE_QUALITY_ULTRA_PERFORMANCE 0
#define DLSS_BRIDGE_QUALITY_PERFORMANCE       1
#define DLSS_BRIDGE_QUALITY_BALANCED          2
#define DLSS_BRIDGE_QUALITY_QUALITY           3
#define DLSS_BRIDGE_QUALITY_ULTRA_QUALITY     4
#define DLSS_BRIDGE_QUALITY_DLAA              5

// DLSS render preset values (matching NVSDK_NGX_DLSS_Hint_Render_Preset enum)
// A-D: removed from SDK enum but passable via raw integer values
// E-F: deprecated but still defined in SDK
// J-M: current, defined in SDK
#define DLSS_BRIDGE_PRESET_DEFAULT  0
#define DLSS_BRIDGE_PRESET_A        1
#define DLSS_BRIDGE_PRESET_B        2
#define DLSS_BRIDGE_PRESET_C        3
#define DLSS_BRIDGE_PRESET_D        4
#define DLSS_BRIDGE_PRESET_E        5
#define DLSS_BRIDGE_PRESET_F        6
#define DLSS_BRIDGE_PRESET_J       10
#define DLSS_BRIDGE_PRESET_K       11
#define DLSS_BRIDGE_PRESET_L       12
#define DLSS_BRIDGE_PRESET_M       13

// ================================================================
// Dynamic Preset Detection
// ================================================================

/**
 * Returns a 64-bit bitmask of supported DLSS presets.
 * Bit N = 1 means preset with enum value N is supported by the driver.
 *
 * Preset enum values (from NVSDK_NGX_DLSS_Hint_Render_Preset):
 *   0  = Default    5  = E (deprecated)  10 = J          15 = O
 *   1-4 = A-D (removed)  6  = F (deprecated)  11 = K    16+ = future
 *                        7  = G (no)          12 = L
 *                        8  = H (no)          13 = M
 *                        9  = I (no)          14 = N (no)
 *
 * A preset is "available" if it exists in the SDK enum and
 * is not marked as removed/no-use by NVIDIA.
 */
uint64_t dlss_bridge_get_available_presets(void);

/** Convert a preset enum value to its letter name. Returns NULL if invalid. */
const char* dlss_bridge_preset_to_name(int presetValue);

/** Convert a preset letter name ("K", "J", "L", etc.) to its enum value. */
int dlss_bridge_preset_from_name(const char* name);

// ================================================================
// Application ID (required by NVIDIA)
// ================================================================

/** Set the NGX application ID as a hex string (e.g. "DEADBEEF"). */
void dlss_bridge_set_app_id_string(const char* hexAppId);

/** Set the NGX application ID directly (for C callers). */
void dlss_bridge_set_app_id(uint64_t appId);

// ================================================================
// D3D12 backend (Windows)
// ================================================================

/** Initialize DLSS for D3D12. Uses app ID set via dlss_bridge_set_app_id_string(). */
int dlss_bridge_init_d3d12(
    void* d3d12Device,
    const wchar_t* dataPath,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset);

/** Create DLSS feature handle for D3D12. Returns 0 on failure. */
int dlss_bridge_create_feature_d3d12(
    void* d3d12CommandQueue,
    uint32_t inputWidth,
    uint32_t inputHeight,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset,
    bool autoExposure,
    bool hdr);

/** Evaluate (run) DLSS for one frame (D3D12). */
int dlss_bridge_evaluate_d3d12(
    void* d3d12CommandList,
    void* colorInput,       // Low-res color texture
    void* colorOutput,      // High-res output texture
    void* depthBuffer,      // Depth buffer
    void* motionVectors,    // Motion vector texture
    float jitterOffsetX,
    float jitterOffsetY,
    float sharpness,
    bool resetHistory,
    float frameTimeDelta,   // Frame time in milliseconds
    float preExposure,      // Pre-exposure value
    float exposureScale);   // Exposure scale multiplier

// ================================================================
// D3D11 backend (Windows)
// ================================================================

/** Initialize DLSS for D3D11. */
int dlss_bridge_init_d3d11(
    void* d3d11Device,
    const wchar_t* dataPath,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset);

/** Create DLSS feature handle for D3D11. */
int dlss_bridge_create_feature_d3d11(
    void* d3d11DeviceContext,
    uint32_t inputWidth,
    uint32_t inputHeight,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset,
    bool autoExposure,
    bool hdr);

/** Evaluate DLSS for one frame (D3D11). */
int dlss_bridge_evaluate_d3d11(
    void* d3d11DeviceContext,
    void* colorInput, void* colorOutput,
    void* depthBuffer, void* motionVectors,
    float jitterOffsetX, float jitterOffsetY,
    float sharpness, bool resetHistory,
    float frameTimeDelta, float preExposure, float exposureScale);

/** Release the active DLSS feature. */
int dlss_bridge_release_feature(void);

/** Shutdown D3D12 backend. */
int dlss_bridge_shutdown_d3d12(void);

/** Shutdown D3D11 backend. */
int dlss_bridge_shutdown_d3d11(void);

// ================================================================
// Vulkan backend (Windows + Linux)
// ================================================================

/** Initialize DLSS for Vulkan. */
int dlss_bridge_init_vk(
    uint64_t appId,
    void* vkInstance,
    void* vkPhysicalDevice,
    void* vkDevice,
    const char* dataPath,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset);

/** Create DLSS feature for Vulkan. */
int dlss_bridge_create_feature_vk(
    void* vkCommandBuffer,
    uint32_t inputWidth,
    uint32_t inputHeight,
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    int preset,
    bool autoExposure,
    bool hdr);

/** Evaluate DLSS for one frame (Vulkan). */
int dlss_bridge_evaluate_vk(
    void* vkCommandBuffer,
    void* colorInput,
    void* colorOutput,
    void* depthBuffer,
    void* motionVectors,
    float jitterOffsetX,
    float jitterOffsetY,
    float sharpness,
    bool resetHistory);

/** Shutdown DLSS (Vulkan). */
int dlss_bridge_shutdown_vk(void);

// ================================================================
// Common
// ================================================================

/** Check if DLSS is supported on this system. */
bool dlss_bridge_is_supported(void);

/** Get optimal input (render) resolution for given output and quality. */
int dlss_bridge_get_optimal_settings(
    uint32_t outputWidth,
    uint32_t outputHeight,
    int qualityMode,
    uint32_t* pRenderWidth,
    uint32_t* pRenderHeight);

#ifdef __cplusplus
}
#endif

#endif // DLSS_BRIDGE_H
