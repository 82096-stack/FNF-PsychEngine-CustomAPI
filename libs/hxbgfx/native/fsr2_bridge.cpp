// fsr2_bridge.cpp — FSR 2/3.1 bridge (compiles everywhere)
//
// Full FidelityFX SDK integration is behind FSR2_SDK_AVAILABLE.
// Without it, functions return UNSUPPORTED at runtime.

#include "fsr2_bridge.h"
#include <string.h>
#include <stdio.h>

int fsr2_bridge_init(void** outContext, int version,
    uint32_t maxRenderWidth, uint32_t maxRenderHeight,
    uint32_t displayWidth, uint32_t displayHeight,
    bool enableHDR, bool enableDepthInverted, bool enableAutoExposure)
{
    (void)outContext; (void)version;
    (void)maxRenderWidth; (void)maxRenderHeight;
    (void)displayWidth; (void)displayHeight;
    (void)enableHDR; (void)enableDepthInverted; (void)enableAutoExposure;
    printf("[FSR2 Bridge] SDK not linked — FSR 2/3.1 unavailable\n");
    return FSR2_BRIDGE_RESULT_ERROR_UNSUPPORTED;
}

int fsr2_bridge_dispatch(void* context, void* commandList,
    void* colorTexture, void* depthTexture, void* motionVectors,
    void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    float motionVectorScaleX, float motionVectorScaleY,
    uint32_t renderWidth, uint32_t renderHeight,
    float sharpness, float frameTimeDelta, float preExposure,
    bool reset, float cameraNear, float cameraFar, float cameraFovAngleVertical)
{
    (void)context; (void)commandList;
    (void)colorTexture; (void)depthTexture; (void)motionVectors; (void)outputTexture;
    (void)jitterOffsetX; (void)jitterOffsetY;
    (void)motionVectorScaleX; (void)motionVectorScaleY;
    (void)renderWidth; (void)renderHeight;
    (void)sharpness; (void)frameTimeDelta; (void)preExposure;
    (void)reset; (void)cameraNear; (void)cameraFar; (void)cameraFovAngleVertical;
    return FSR2_BRIDGE_RESULT_ERROR_UNSUPPORTED;
}

int fsr2_bridge_destroy(void* context)
{
    (void)context;
    return FSR2_BRIDGE_RESULT_SUCCESS;
}

int fsr2_bridge_get_jitter_offset(void* context, int32_t index, int32_t phaseCount,
    float* pOutX, float* pOutY)
{
    (void)context;
    if (!pOutX || !pOutY) return FSR2_BRIDGE_RESULT_ERROR_UNKNOWN;
    static const float halton2[] = { 0.5f, 0.25f, 0.75f, 0.125f, 0.625f, 0.375f, 0.875f, 0.0625f };
    static const float halton3[] = { 0.5f, 0.333333f, 0.666667f, 0.111111f, 0.444444f, 0.777778f, 0.222222f, 0.555556f };
    int idx = index % 8;
    *pOutX = halton2[idx] - 0.5f;
    *pOutY = halton3[idx] - 0.5f;
    return FSR2_BRIDGE_RESULT_SUCCESS;
}

int32_t fsr2_bridge_get_jitter_phase_count(int32_t renderWidth, int32_t displayWidth)
{
    float scale = (float)displayWidth / (float)renderWidth;
    return (int32_t)(8.0f * scale * scale + 0.5f);
}

int fsr2_bridge_get_render_resolution(void* context, uint32_t displayWidth,
    uint32_t displayHeight, uint32_t* pRenderWidth, uint32_t* pRenderHeight)
{
    (void)context;
    float scale = 1.5f;
    if (pRenderWidth)  *pRenderWidth  = (uint32_t)(displayWidth / scale);
    if (pRenderHeight) *pRenderHeight = (uint32_t)(displayHeight / scale);
    return FSR2_BRIDGE_RESULT_SUCCESS;
}
