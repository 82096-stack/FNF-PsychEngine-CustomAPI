// xess_bridge.cpp — Thin C wrapper for Intel XeSS SDK
//
// Links against libxess.lib / libxess.dll.
// Only compiles on Windows. Stub implementations for other platforms.

#include "xess_bridge.h"

#ifdef _WIN32
#include <xess/xess.h>
#include <xess/xess_vk.h>
#include <xess/xess_d3d12.h>
#include <xess/xess_d3d11.h>

// ================================================================
// Vulkan backend
// ================================================================

int xess_bridge_get_vk_instance_extensions(
    uint32_t* pCount, const char** ppExtensions, uint32_t* pMinVkApiVersion)
{
    xess_result_t r = xessVKGetRequiredInstanceExtensions(pCount, ppExtensions, pMinVkApiVersion);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int xess_bridge_get_vk_device_extensions(
    void* vkInstance, void* vkPhysicalDevice, uint32_t* pCount, const char** ppExtensions)
{
    xess_result_t r = xessVKGetRequiredDeviceExtensions(
        (VkInstance)vkInstance, (VkPhysicalDevice)vkPhysicalDevice, pCount, ppExtensions);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int xess_bridge_init_vk(
    void** outContext, void* vkInstance, void* vkPhysicalDevice, void* vkDevice,
    uint32_t outputWidth, uint32_t outputHeight, int qualitySetting, uint32_t initFlags)
{
    if (outContext == NULL) return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;

    xess_context_handle_t ctx = NULL;
    xess_result_t r = xessVKCreateContext(
        (VkInstance)vkInstance, (VkPhysicalDevice)vkPhysicalDevice,
        (VkDevice)vkDevice, &ctx);

    if (r != XESS_RESULT_SUCCESS) {
        return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    }

    xess_vk_init_params_t initParams;
    memset(&initParams, 0, sizeof(initParams));
    initParams.outputResolution.x = outputWidth;
    initParams.outputResolution.y = outputHeight;
    initParams.qualitySetting = (xess_quality_setting_t)qualitySetting;
    initParams.initFlags = initFlags;

    r = xessVKInit(ctx, &initParams);
    if (r != XESS_RESULT_SUCCESS) {
        xessDestroyContext(ctx);
        return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    }

    *outContext = (void*)ctx;
    return XESS_BRIDGE_RESULT_SUCCESS;
}

int xess_bridge_get_input_resolution(void* context,
    uint32_t outputWidth, uint32_t outputHeight,
    int qualitySetting, uint32_t* pInputWidth, uint32_t* pInputHeight)
{
    xess_2d_t outputRes;
    outputRes.x = outputWidth;
    outputRes.y = outputHeight;
    xess_2d_t inputRes;
    xess_result_t r = xessGetInputResolution((xess_context_handle_t)context, &outputRes,
        (xess_quality_settings_t)qualitySetting, &inputRes);
    if (r != XESS_RESULT_SUCCESS) return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    if (pInputWidth)  *pInputWidth  = inputRes.x;
    if (pInputHeight) *pInputHeight = inputRes.y;
    return XESS_BRIDGE_RESULT_SUCCESS;
}

int xess_bridge_get_jitter_scale(void* context, float* pX, float* pY)
{
    xess_result_t r = xessGetJitterScale((xess_context_handle_t)context, pX, pY);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int xess_bridge_execute_vk(
    void* context, void* vkCommandBuffer,
    void* colorTexture, void* velocityTexture, void* depthTexture, void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    uint32_t inputWidth, uint32_t inputHeight, int resetHistory)
{
    xess_vk_execute_params_t params;
    memset(&params, 0, sizeof(params));

    // Populate image view info from bgfx VkImage handles (requires patched bgfx)
    if (colorTexture) {
        params.colorTexture.imageView = VK_NULL_HANDLE;
        params.colorTexture.image = (VkImage)colorTexture;
        params.colorTexture.format = VK_FORMAT_B8G8R8A8_UNORM;
        params.colorTexture.width = inputWidth;
        params.colorTexture.height = inputHeight;
        params.colorTexture.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
    }
    if (outputTexture) {
        params.outputTexture.imageView = VK_NULL_HANDLE;
        params.outputTexture.image = (VkImage)outputTexture;
        params.outputTexture.format = VK_FORMAT_B8G8R8A8_UNORM;
        params.outputTexture.width = inputWidth;
        params.outputTexture.height = inputHeight;
        params.outputTexture.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
    }
    params.jitterOffsetX     = jitterOffsetX;
    params.jitterOffsetY     = jitterOffsetY;
    params.exposureScale     = 1.0f;
    params.resetHistory      = (resetHistory != 0);
    params.inputWidth        = inputWidth;
    params.inputHeight       = inputHeight;

    xess_result_t r = xessVKExecute((xess_context_handle_t)context,
                                     (VkCommandBuffer)vkCommandBuffer, &params);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

// ================================================================
// D3D12 backend
// ================================================================

int xess_bridge_init_d3d12(
    void** outContext, void* d3d12Device,
    uint32_t outputWidth, uint32_t outputHeight, int qualitySetting, uint32_t initFlags)
{
    if (outContext == NULL) return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;

    xess_context_handle_t ctx = NULL;
    xess_result_t r = xessD3D12CreateContext((ID3D12Device*)d3d12Device, &ctx);

    if (r != XESS_RESULT_SUCCESS) {
        return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    }

    xess_d3d12_init_params_t initParams;
    memset(&initParams, 0, sizeof(initParams));
    initParams.outputResolution.x = outputWidth;
    initParams.outputResolution.y = outputHeight;
    initParams.qualitySetting = (xess_quality_settings_t)qualitySetting;
    initParams.initFlags = initFlags;

    r = xessD3D12Init(ctx, &initParams);
    if (r != XESS_RESULT_SUCCESS) {
        xessDestroyContext(ctx);
        return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    }

    *outContext = (void*)ctx;
    return XESS_BRIDGE_RESULT_SUCCESS;
}

int xess_bridge_execute_d3d12(
    void* context, void* d3d12CommandList,
    void* colorTexture, void* velocityTexture, void* depthTexture, void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    uint32_t inputWidth, uint32_t inputHeight, int resetHistory)
{
    xess_d3d12_execute_params_t params;
    memset(&params, 0, sizeof(params));
    params.pColorTexture   = (ID3D12Resource*)colorTexture;
    params.pVelocityTexture = (ID3D12Resource*)velocityTexture;
    params.pDepthTexture   = (ID3D12Resource*)depthTexture;
    params.pOutputTexture  = (ID3D12Resource*)outputTexture;
    params.jitterOffsetX   = jitterOffsetX;
    params.jitterOffsetY   = jitterOffsetY;
    params.exposureScale   = 1.0f;
    params.resetHistory    = (resetHistory != 0);
    params.inputWidth      = inputWidth;
    params.inputHeight     = inputHeight;

    xess_result_t r = xessD3D12Execute((xess_context_handle_t)context,
        (ID3D12GraphicsCommandList*)d3d12CommandList, &params);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

// ================================================================
// D3D11 backend (Intel Arc only)
// ================================================================

int xess_bridge_init_d3d11(
    void** outContext, void* d3d11Device,
    uint32_t outputWidth, uint32_t outputHeight, int qualitySetting, uint32_t initFlags)
{
    if (outContext == NULL) return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    xess_context_handle_t ctx = NULL;
    xess_result_t r = xessD3D11CreateContext((ID3D11Device*)d3d11Device, &ctx);
    if (r != XESS_RESULT_SUCCESS) return XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
    xess_d3d11_init_params_t initParams;
    memset(&initParams, 0, sizeof(initParams));
    initParams.outputResolution.x = outputWidth;
    initParams.outputResolution.y = outputHeight;
    initParams.qualitySetting = (xess_quality_settings_t)qualitySetting;
    initParams.initFlags = initFlags;
    r = xessD3D11Init(ctx, &initParams);
    if (r != XESS_RESULT_SUCCESS) { xessDestroyContext(ctx); return XESS_BRIDGE_RESULT_ERROR_UNKNOWN; }
    *outContext = (void*)ctx;
    return XESS_BRIDGE_RESULT_SUCCESS;
}

int xess_bridge_execute_d3d11(
    void* context, void* d3d11DeviceContext,
    void* colorTexture, void* velocityTexture, void* depthTexture, void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    uint32_t inputWidth, uint32_t inputHeight, int resetHistory)
{
    xess_d3d11_execute_params_t params;
    memset(&params, 0, sizeof(params));
    params.pColorTexture   = (ID3D11Resource*)colorTexture;
    params.pVelocityTexture = (ID3D11Resource*)velocityTexture;
    params.pDepthTexture   = (ID3D11Resource*)depthTexture;
    params.pOutputTexture  = (ID3D11Resource*)outputTexture;
    params.jitterOffsetX   = jitterOffsetX;
    params.jitterOffsetY   = jitterOffsetY;
    params.exposureScale   = 1.0f;
    params.resetHistory    = (resetHistory != 0);
    params.inputWidth      = inputWidth;
    params.inputHeight     = inputHeight;
    xess_result_t r = xessD3D11Execute((xess_context_handle_t)context,
        (ID3D11DeviceContext*)d3d11DeviceContext, &params);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}


int xess_bridge_destroy_context(void* context)
{
    if (context == NULL) return XESS_BRIDGE_RESULT_SUCCESS;
    xess_result_t r = xessDestroyContext((xess_context_handle_t)context);
    return (r == XESS_RESULT_SUCCESS) ? XESS_BRIDGE_RESULT_SUCCESS : XESS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int xess_bridge_is_supported(void)
{
    // XeSS works on all GPUs with DP4a support (NVIDIA GTX 10+, AMD RX 5000+, Intel Arc)
    // On Windows with D3D12/Vulkan, this is virtually all modern systems
    return XESS_BRIDGE_RESULT_SUCCESS;
}

#else
// ================================================================
// Stub implementations for non-Windows platforms
// ================================================================

int xess_bridge_get_vk_instance_extensions(
    uint32_t* pCount, const char** ppExtensions, uint32_t* pMinVkApiVersion)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_get_vk_device_extensions(
    void* vkInstance, void* vkPhysicalDevice, uint32_t* pCount, const char** ppExtensions)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_init_vk(
    void** outContext, void* vkInstance, void* vkPhysicalDevice, void* vkDevice,
    uint32_t outputWidth, uint32_t outputHeight, int qualitySetting, uint32_t initFlags)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_get_input_resolution(void* context, uint32_t* pInputWidth, uint32_t* pInputHeight)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_get_jitter_scale(void* context, float* pX, float* pY)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_execute_vk(
    void* context, void* vkCommandBuffer,
    void* colorTexture, void* velocityTexture, void* depthTexture, void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    uint32_t inputWidth, uint32_t inputHeight, int resetHistory)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_init_d3d12(
    void** outContext, void* d3d12Device,
    uint32_t outputWidth, uint32_t outputHeight, int qualitySetting, uint32_t initFlags)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_execute_d3d12(
    void* context, void* d3d12CommandList,
    void* colorTexture, void* velocityTexture, void* depthTexture, void* outputTexture,
    float jitterOffsetX, float jitterOffsetY,
    uint32_t inputWidth, uint32_t inputHeight, int resetHistory)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

int xess_bridge_destroy_context(void* context)
{ return XESS_BRIDGE_RESULT_SUCCESS; }

int xess_bridge_is_supported(void)
{ return XESS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }

#endif // _WIN32
