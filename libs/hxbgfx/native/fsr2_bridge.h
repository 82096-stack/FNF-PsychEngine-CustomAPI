// fsr2_bridge.h — bgfx-based FSR 2/3.1 bridge
//
// Wraps the AMD FidelityFX SDK FSR 2/3.1 APIs via a bgfx FfxInterface
// backend, enabling cross-API support (D3D11/D3D12/Vulkan/Metal/OpenGL).
//
// The bridge implements the ~22 FfxInterface callbacks using bgfx APIs,
// and manages FSR context lifecycle (CreateContext → Dispatch → Destroy).

#ifndef FSR2_BRIDGE_H
#define FSR2_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define FSR2_BRIDGE_RESULT_SUCCESS           0
#define FSR2_BRIDGE_RESULT_ERROR_UNKNOWN     -1
#define FSR2_BRIDGE_RESULT_ERROR_UNSUPPORTED -2

// FSR version selection
#define FSR2_BRIDGE_VERSION_FSR2    2
#define FSR2_BRIDGE_VERSION_FSR31   31

// ================================================================
// Lifecycle
// ================================================================

/** Initialize FSR 2 or 3.1 with bgfx backend. */
int fsr2_bridge_init(
    void** outContext,
    int version,            // FSR2_BRIDGE_VERSION_FSR2 or FSR2_BRIDGE_VERSION_FSR31
    uint32_t maxRenderWidth,
    uint32_t maxRenderHeight,
    uint32_t displayWidth,
    uint32_t displayHeight,
    bool enableHDR,
    bool enableDepthInverted,
    bool enableAutoExposure);

/** Dispatch FSR upscaling for one frame. */
int fsr2_bridge_dispatch(
    void* context,
    void* commandList,      // bgfx encoder (null = use internal)
    void* colorTexture,     // Low-res input bgfx texture handle
    void* depthTexture,     // Depth buffer bgfx texture handle
    void* motionVectors,    // Motion vectors bgfx texture handle
    void* outputTexture,    // High-res output bgfx texture handle
    float jitterOffsetX,
    float jitterOffsetY,
    float motionVectorScaleX,
    float motionVectorScaleY,
    uint32_t renderWidth,
    uint32_t renderHeight,
    float sharpness,
    float frameTimeDelta,
    float preExposure,
    bool reset,
    float cameraNear,
    float cameraFar,
    float cameraFovAngleVertical);

/** Destroy FSR context and release all resources. */
int fsr2_bridge_destroy(void* context);

// ================================================================
// Utility
// ================================================================

/** Get jitter offset for temporal anti-aliasing. */
int fsr2_bridge_get_jitter_offset(
    void* context,
    int32_t index,
    int32_t phaseCount,
    float* pOutX,
    float* pOutY);

/** Get jitter phase count for given resolutions. */
int32_t fsr2_bridge_get_jitter_phase_count(
    int32_t renderWidth,
    int32_t displayWidth);

/** Get optimal render resolution from display resolution and quality. */
int fsr2_bridge_get_render_resolution(
    void* context,
    uint32_t displayWidth,
    uint32_t displayHeight,
    uint32_t* pRenderWidth,
    uint32_t* pRenderHeight);

#ifdef __cplusplus
}
#endif

#endif // FSR2_BRIDGE_H
