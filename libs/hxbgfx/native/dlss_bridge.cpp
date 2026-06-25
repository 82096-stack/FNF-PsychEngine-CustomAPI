// dlss_bridge.cpp — Thin C wrapper for NVIDIA DLSS (NGX) SDK
// Supports D3D12, D3D11, and Vulkan backends.

#include "dlss_bridge.h"
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <nvsdk_ngx.h>
#include <nvsdk_ngx_vk.h>
#include <vulkan/vulkan.h>

static uint64_t   g_appId         = 0x00000000DEADBEEFULL;
static bool       g_initialized   = false;
static int        g_activeBackend = 0; // 0=D3D12, 1=D3D11, 2=VK
static NVSDK_NGX_Handle*    g_featureHandle = NULL;
static NVSDK_NGX_Parameter* g_params        = NULL;

// Helpers ----------------------------------------------------------

static int presetToDLSSPreset(int preset) {
    switch (preset) {
        case DLSS_BRIDGE_PRESET_A: return 1; case DLSS_BRIDGE_PRESET_B: return 2;
        case DLSS_BRIDGE_PRESET_C: return 3; case DLSS_BRIDGE_PRESET_D: return 4;
        case DLSS_BRIDGE_PRESET_E: return NVSDK_NGX_DLSS_Hint_Render_Preset_E;
        case DLSS_BRIDGE_PRESET_F: return NVSDK_NGX_DLSS_Hint_Render_Preset_F;
        case DLSS_BRIDGE_PRESET_J: return NVSDK_NGX_DLSS_Hint_Render_Preset_J;
        case DLSS_BRIDGE_PRESET_K: return NVSDK_NGX_DLSS_Hint_Render_Preset_K;
        case DLSS_BRIDGE_PRESET_L: return NVSDK_NGX_DLSS_Hint_Render_Preset_L;
        case DLSS_BRIDGE_PRESET_M: return NVSDK_NGX_DLSS_Hint_Render_Preset_M;
        default: return NVSDK_NGX_DLSS_Hint_Render_Preset_Default;
    }
}

static NVSDK_NGX_PerfQuality_Value qualityToNGX(int q) {
    switch (q) {
        case 0: return NVSDK_NGX_PerfQuality_Value_UltraPerformance;
        case 1: return NVSDK_NGX_PerfQuality_Value_MaxPerf;
        case 2: return NVSDK_NGX_PerfQuality_Value_Balanced;
        case 3: return NVSDK_NGX_PerfQuality_Value_MaxQuality;
        case 4: return NVSDK_NGX_PerfQuality_Value_UltraQuality;
        case 5: return NVSDK_NGX_PerfQuality_Value_DLAA;
        default: return NVSDK_NGX_PerfQuality_Value_Balanced;
    }
}

static unsigned int buildFeatureFlags(bool hdr, bool autoExposure) {
    unsigned int flags = NVSDK_NGX_DLSS_Feature_Flags_MVLowRes
                       | NVSDK_NGX_DLSS_Feature_Flags_MVJittered;
    if (hdr)          flags |= NVSDK_NGX_DLSS_Feature_Flags_IsHDR;
    if (autoExposure) flags |= NVSDK_NGX_DLSS_Feature_Flags_AutoExposure;
    return flags;
}

// App ID ------------------------------------------------------------

void dlss_bridge_set_app_id_string(const char* hexAppId) {
    if (hexAppId) g_appId = strtoull(hexAppId, NULL, 16);
}
void dlss_bridge_set_app_id(uint64_t appId) { g_appId = appId; }

// ================================================================
// D3D12 backend
// ================================================================

int dlss_bridge_init_d3d12(void* d3d12Device, const wchar_t* dataPath,
    uint32_t outputWidth, uint32_t outputHeight, int qualityMode, int preset)
{
    if (g_initialized) return DLSS_BRIDGE_RESULT_SUCCESS;
    g_activeBackend = 0;

    NVSDK_NGX_FeatureCommonInfo featureInfo;
    memset(&featureInfo, 0, sizeof(featureInfo));

    NVSDK_NGX_Result r = NVSDK_NGX_D3D12_Init(g_appId, dataPath,
        (ID3D12Device*)d3d12Device, &featureInfo);
    if (r != NVSDK_NGX_Result_Success) return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED;

    r = NVSDK_NGX_D3D12_GetCapabilityParameters(&g_params);
    if (r != NVSDK_NGX_Result_Success) { NVSDK_NGX_D3D12_Shutdown1(nullptr); return DLSS_BRIDGE_RESULT_ERROR_UNKNOWN; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    int p = presetToDLSSPreset(preset);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_DLAA, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Quality, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Balanced, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Performance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraPerformance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraQuality, p);

    g_initialized = true;
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

int dlss_bridge_create_feature_d3d12(void* d3d12CommandQueue,
    uint32_t inputWidth, uint32_t inputHeight,
    uint32_t outputWidth, uint32_t outputHeight,
    int qualityMode, int preset, bool autoExposure, bool hdr)
{
    if (!g_initialized || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;

    if (g_featureHandle) { NVSDK_NGX_D3D12_ReleaseFeature(g_featureHandle); g_featureHandle = NULL; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  inputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, inputHeight);
    g_params->Set(NVSDK_NGX_Parameter_OutWidth,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_OutHeight, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Feature_Create_Flags, buildFeatureFlags(hdr, autoExposure));

    NVSDK_NGX_Result r = NVSDK_NGX_D3D12_CreateFeature(
        (ID3D12GraphicsCommandList*)d3d12CommandQueue,
        NVSDK_NGX_Feature_SuperSampling, g_params, &g_featureHandle);
    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_evaluate_d3d12(void* d3d12CommandList,
    void* colorInput, void* colorOutput, void* depthBuffer, void* motionVectors,
    float jitterOffsetX, float jitterOffsetY, float sharpness, bool resetHistory,
    float frameTimeDelta, float preExposure, float exposureScale)
{
    if (!g_initialized || !g_featureHandle || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;

    g_params->Set(NVSDK_NGX_Parameter_Color,          (ID3D12Resource*)colorInput);
    g_params->Set(NVSDK_NGX_Parameter_Output,         (ID3D12Resource*)colorOutput);
    g_params->Set(NVSDK_NGX_Parameter_Depth,          (ID3D12Resource*)depthBuffer);
    g_params->Set(NVSDK_NGX_Parameter_MotionVectors,  (ID3D12Resource*)motionVectors);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_X, jitterOffsetX);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_Y, jitterOffsetY);
    g_params->Set(NVSDK_NGX_Parameter_Sharpness,       sharpness);
    g_params->Set(NVSDK_NGX_Parameter_Reset,           resetHistory ? 1 : 0);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_X,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_Y,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Pre_Exposure, preExposure);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Exposure_Scale, exposureScale);
    g_params->Set(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, frameTimeDelta);

    NVSDK_NGX_Result r = NVSDK_NGX_D3D12_EvaluateFeature(
        (ID3D12GraphicsCommandList*)d3d12CommandList, g_featureHandle, g_params, NULL);
    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_release_feature(void) {
    if (g_featureHandle) {
        if (g_activeBackend == 0) NVSDK_NGX_D3D12_ReleaseFeature(g_featureHandle);
        if (g_activeBackend == 1) NVSDK_NGX_D3D11_ReleaseFeature(g_featureHandle);
        if (g_activeBackend == 2) NVSDK_NGX_VULKAN_ReleaseFeature(g_featureHandle);
        g_featureHandle = NULL;
    }
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

int dlss_bridge_shutdown_d3d12(void) {
    dlss_bridge_release_feature();
    if (g_initialized) { NVSDK_NGX_D3D12_Shutdown1(nullptr); g_initialized = false; g_params = NULL; }
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

// ================================================================
// D3D11 backend
// ================================================================

int dlss_bridge_init_d3d11(void* d3d11Device, const wchar_t* dataPath,
    uint32_t outputWidth, uint32_t outputHeight, int qualityMode, int preset)
{
    if (g_initialized) return DLSS_BRIDGE_RESULT_SUCCESS;
    g_activeBackend = 1;

    NVSDK_NGX_FeatureCommonInfo featureInfo;
    memset(&featureInfo, 0, sizeof(featureInfo));

    NVSDK_NGX_Result r = NVSDK_NGX_D3D11_Init(g_appId, dataPath,
        (ID3D11Device*)d3d11Device, &featureInfo);
    if (r != NVSDK_NGX_Result_Success) return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED;

    r = NVSDK_NGX_D3D11_GetCapabilityParameters(&g_params);
    if (r != NVSDK_NGX_Result_Success) { NVSDK_NGX_D3D11_Shutdown1(nullptr); return DLSS_BRIDGE_RESULT_ERROR_UNKNOWN; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    int p = presetToDLSSPreset(preset);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_DLAA, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Quality, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Balanced, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Performance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraPerformance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraQuality, p);

    g_initialized = true;
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

int dlss_bridge_create_feature_d3d11(void* d3d11DeviceContext,
    uint32_t inputWidth, uint32_t inputHeight,
    uint32_t outputWidth, uint32_t outputHeight,
    int qualityMode, int preset, bool autoExposure, bool hdr)
{
    if (!g_initialized || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;
    if (g_featureHandle) { NVSDK_NGX_D3D11_ReleaseFeature(g_featureHandle); g_featureHandle = NULL; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  inputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, inputHeight);
    g_params->Set(NVSDK_NGX_Parameter_OutWidth,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_OutHeight, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Feature_Create_Flags, buildFeatureFlags(hdr, autoExposure));

    NVSDK_NGX_Result r = NVSDK_NGX_D3D11_CreateFeature(
        (ID3D11DeviceContext*)d3d11DeviceContext,
        NVSDK_NGX_Feature_SuperSampling, g_params, &g_featureHandle);
    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_evaluate_d3d11(void* d3d11DeviceContext,
    void* colorInput, void* colorOutput, void* depthBuffer, void* motionVectors,
    float jitterOffsetX, float jitterOffsetY, float sharpness, bool resetHistory,
    float frameTimeDelta, float preExposure, float exposureScale)
{
    if (!g_initialized || !g_featureHandle || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;

    g_params->Set(NVSDK_NGX_Parameter_Color,          (ID3D11Resource*)colorInput);
    g_params->Set(NVSDK_NGX_Parameter_Output,         (ID3D11Resource*)colorOutput);
    g_params->Set(NVSDK_NGX_Parameter_Depth,          (ID3D11Resource*)depthBuffer);
    g_params->Set(NVSDK_NGX_Parameter_MotionVectors,  (ID3D11Resource*)motionVectors);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_X, jitterOffsetX);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_Y, jitterOffsetY);
    g_params->Set(NVSDK_NGX_Parameter_Sharpness,       sharpness);
    g_params->Set(NVSDK_NGX_Parameter_Reset,           resetHistory ? 1 : 0);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_X,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_Y,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Pre_Exposure, preExposure);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Exposure_Scale, exposureScale);
    g_params->Set(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, frameTimeDelta);

    NVSDK_NGX_Result r = NVSDK_NGX_D3D11_EvaluateFeature(
        (ID3D11DeviceContext*)d3d11DeviceContext, g_featureHandle, g_params, NULL);
    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_shutdown_d3d11(void) {
    dlss_bridge_release_feature();
    if (g_initialized) { NVSDK_NGX_D3D11_Shutdown1(nullptr); g_initialized = false; g_params = NULL; }
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

// ================================================================
// Vulkan backend
// ================================================================

static PFN_vkCreateImageView  g_pfnCreateImageView  = NULL;
static PFN_vkDestroyImageView g_pfnDestroyImageView = NULL;

static VkImageView createSimpleImageView(VkDevice device, VkImage image, VkFormat format, uint32_t w, uint32_t h)
{
    if (!g_pfnCreateImageView) {
        g_pfnCreateImageView  = (PFN_vkCreateImageView)vkGetDeviceProcAddr(device, "vkCreateImageView");
        g_pfnDestroyImageView = (PFN_vkDestroyImageView)vkGetDeviceProcAddr(device, "vkDestroyImageView");
    }
    if (!g_pfnCreateImageView || !image) return VK_NULL_HANDLE;

    VkImageViewCreateInfo info = {};
    info.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    info.image = image;
    info.viewType = VK_IMAGE_VIEW_TYPE_2D;
    info.format = format;
    info.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
    info.subresourceRange.levelCount = 1;
    info.subresourceRange.layerCount = 1;

    VkImageView view = VK_NULL_HANDLE;
    g_pfnCreateImageView(device, &info, NULL, &view);
    return view;
}

int dlss_bridge_init_vk(uint64_t appId, void* vkInstance, void* vkPhysicalDevice, void* vkDevice,
    const char* dataPath, uint32_t outputWidth, uint32_t outputHeight, int qualityMode, int preset)
{
    if (g_initialized) return DLSS_BRIDGE_RESULT_SUCCESS;
    g_activeBackend = 2;

    wchar_t wPath[MAX_PATH];
    MultiByteToWideChar(CP_UTF8, 0, dataPath, -1, wPath, MAX_PATH);

    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_Init(appId, wPath,
        (VkInstance)vkInstance, (VkPhysicalDevice)vkPhysicalDevice,
        (VkDevice)vkDevice, NULL, NULL, NULL);
    if (r != NVSDK_NGX_Result_Success) return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED;

    r = NVSDK_NGX_VULKAN_GetCapabilityParameters(&g_params);
    if (r != NVSDK_NGX_Result_Success) { NVSDK_NGX_VULKAN_Shutdown1((VkDevice)vkDevice); return DLSS_BRIDGE_RESULT_ERROR_UNKNOWN; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    int p = presetToDLSSPreset(preset);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_DLAA, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Quality, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Balanced, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_Performance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraPerformance, p);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Hint_Render_Preset_UltraQuality, p);

    g_initialized = true;
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

int dlss_bridge_create_feature_vk(void* vkCommandBuffer,
    uint32_t inputWidth, uint32_t inputHeight,
    uint32_t outputWidth, uint32_t outputHeight,
    int qualityMode, int preset, bool autoExposure, bool hdr)
{
    if (!g_initialized || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;
    if (g_featureHandle) { NVSDK_NGX_VULKAN_ReleaseFeature(g_featureHandle); g_featureHandle = NULL; }

    g_params->Set(NVSDK_NGX_Parameter_Width,  inputWidth);
    g_params->Set(NVSDK_NGX_Parameter_Height, inputHeight);
    g_params->Set(NVSDK_NGX_Parameter_OutWidth,  outputWidth);
    g_params->Set(NVSDK_NGX_Parameter_OutHeight, outputHeight);
    g_params->Set(NVSDK_NGX_Parameter_PerfQualityValue, qualityToNGX(qualityMode));
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Feature_Create_Flags, buildFeatureFlags(hdr, autoExposure));

    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_CreateFeature(
        (VkCommandBuffer)vkCommandBuffer,
        NVSDK_NGX_Feature_SuperSampling, g_params, &g_featureHandle);
    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_evaluate_vk(void* vkCommandBuffer,
    void* colorInput, void* colorOutput, void* depthBuffer, void* motionVectors,
    float jitterOffsetX, float jitterOffsetY, float sharpness, bool resetHistory,
    float frameTimeDelta, float preExposure, float exposureScale)
{
    if (!g_initialized || !g_featureHandle || !g_params) return DLSS_BRIDGE_RESULT_ERROR_NOT_INIT;

    VkDevice device = (VkDevice)bgfx::getInternalData()->context;

    // Read dimensions from stored params
    uint32_t inW = 1280, inH = 720, outW = 1920, outH = 1080;
    g_params->Get(NVSDK_NGX_Parameter_Width, &inW);
    g_params->Get(NVSDK_NGX_Parameter_Height, &inH);
    g_params->Get(NVSDK_NGX_Parameter_OutWidth, &outW);
    g_params->Get(NVSDK_NGX_Parameter_OutHeight, &outH);

    VkImageView colorInView  = createSimpleImageView(device, (VkImage)colorInput,  VK_FORMAT_B8G8R8A8_UNORM, inW, inH);
    VkImageView colorOutView = createSimpleImageView(device, (VkImage)colorOutput, VK_FORMAT_B8G8R8A8_UNORM, outW, outH);

    NVSDK_NGX_Resource_VK colorInRes  = NVSDK_NGX_Create_ImageView_Resource_VK(colorInView,  (VkImage)colorInput,  VK_FORMAT_B8G8R8A8_UNORM, inW,  inH,  false);
    NVSDK_NGX_Resource_VK colorOutRes = NVSDK_NGX_Create_ImageView_Resource_VK(colorOutView, (VkImage)colorOutput, VK_FORMAT_B8G8R8A8_UNORM, outW, outH, true);

    g_params->Set(NVSDK_NGX_Parameter_Color,          &colorInRes);
    g_params->Set(NVSDK_NGX_Parameter_Output,         &colorOutRes);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_X, jitterOffsetX);
    g_params->Set(NVSDK_NGX_Parameter_Jitter_Offset_Y, jitterOffsetY);
    g_params->Set(NVSDK_NGX_Parameter_Sharpness,       sharpness);
    g_params->Set(NVSDK_NGX_Parameter_Reset,           resetHistory ? 1 : 0);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_X,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_MV_Scale_Y,  1.0f);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Pre_Exposure, preExposure);
    g_params->Set(NVSDK_NGX_Parameter_DLSS_Exposure_Scale, exposureScale);
    g_params->Set(NVSDK_NGX_Parameter_FrameTimeDeltaInMsec, frameTimeDelta);

    NVSDK_NGX_Result r = NVSDK_NGX_VULKAN_EvaluateFeature(
        (VkCommandBuffer)vkCommandBuffer, g_featureHandle, g_params, NULL);

    if (colorInView)  g_pfnDestroyImageView(device, colorInView,  NULL);
    if (colorOutView) g_pfnDestroyImageView(device, colorOutView, NULL);

    return (r == NVSDK_NGX_Result_Success) ? DLSS_BRIDGE_RESULT_SUCCESS : DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
}

int dlss_bridge_shutdown_vk(void) {
    dlss_bridge_release_feature();
    if (g_initialized) {
        VkDevice device = (VkDevice)bgfx::getInternalData()->context;
        NVSDK_NGX_VULKAN_Shutdown1(device);
        g_initialized = false;
        g_params = NULL;
    }
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

// ================================================================
// Common
// ================================================================

bool dlss_bridge_is_supported(void) { return true; }

int dlss_bridge_get_optimal_settings(uint32_t outputWidth, uint32_t outputHeight, int qualityMode,
    uint32_t* pRenderWidth, uint32_t* pRenderHeight)
{
    if (!pRenderWidth || !pRenderHeight) return DLSS_BRIDGE_RESULT_ERROR_UNKNOWN;
    float scale;
    switch (qualityMode) {
        case 0: scale = 3.0f; break; case 1: scale = 2.0f; break;
        case 2: scale = 1.72f; break; case 3: scale = 1.5f; break;
        case 4: scale = 1.3f; break; case 5: scale = 1.0f; break;
        default: scale = 1.5f; break;
    }
    *pRenderWidth  = (uint32_t)(outputWidth  / scale);
    *pRenderHeight = (uint32_t)(outputHeight / scale);
    return DLSS_BRIDGE_RESULT_SUCCESS;
}

// Preset lookup ------------------------------------------------------

static const char* preset_names[] = {
    "Default", "A", "B", "C", "D", "E", "F", NULL, NULL, NULL, "J", "K", "L", "M", NULL, "O"
};
#define PRESET_COUNT (sizeof(preset_names)/sizeof(preset_names[0]))

uint64_t dlss_bridge_get_available_presets(void) {
    uint64_t mask = 0;
    for (int i = 0; i < (int)PRESET_COUNT; i++)
        if (preset_names[i]) mask |= (1ULL << i);
    return mask;
}

const char* dlss_bridge_preset_to_name(int v) {
    return (v >= 0 && v < (int)PRESET_COUNT) ? preset_names[v] : NULL;
}

int dlss_bridge_preset_from_name(const char* name) {
    if (!name) return -1;
    for (int i = 0; i < (int)PRESET_COUNT; i++)
        if (preset_names[i] && strcmp(preset_names[i], name) == 0) return i;
    return -1;
}

#else
// ================================================================
// Non-Windows stubs
// ================================================================
void dlss_bridge_set_app_id_string(const char* hexAppId) {}
void dlss_bridge_set_app_id(uint64_t appId) {}
int dlss_bridge_init_d3d12(void* d, const wchar_t* p, uint32_t ow, uint32_t oh, int q, int pr) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_create_feature_d3d12(void* q, uint32_t iw, uint32_t ih, uint32_t ow, uint32_t oh, int qu, int pr, bool ae, bool h) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_evaluate_d3d12(void* cl, void* ci, void* co, void* db, void* mv, float jx, float jy, float sh, bool rh, float ftd, float pe, float es) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_release_feature(void) { return DLSS_BRIDGE_RESULT_SUCCESS; }
int dlss_bridge_shutdown_d3d12(void) { return DLSS_BRIDGE_RESULT_SUCCESS; }
int dlss_bridge_init_d3d11(void* d, const wchar_t* p, uint32_t ow, uint32_t oh, int q, int pr) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_create_feature_d3d11(void* dc, uint32_t iw, uint32_t ih, uint32_t ow, uint32_t oh, int qu, int pr, bool ae, bool h) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_evaluate_d3d11(void* dc, void* ci, void* co, void* db, void* mv, float jx, float jy, float sh, bool rh, float ftd, float pe, float es) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_shutdown_d3d11(void) { return DLSS_BRIDGE_RESULT_SUCCESS; }
int dlss_bridge_init_vk(uint64_t appId, void* inst, void* pd, void* dev, const char* dp, uint32_t ow, uint32_t oh, int q, int pr) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_create_feature_vk(void* cb, uint32_t iw, uint32_t ih, uint32_t ow, uint32_t oh, int qu, int pr, bool ae, bool h) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_evaluate_vk(void* cb, void* ci, void* co, void* db, void* mv, float jx, float jy, float sh, bool rh, float ftd, float pe, float es) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
int dlss_bridge_shutdown_vk(void) { return DLSS_BRIDGE_RESULT_SUCCESS; }
bool dlss_bridge_is_supported(void) { return false; }
int dlss_bridge_get_optimal_settings(uint32_t ow, uint32_t oh, int q, uint32_t* rw, uint32_t* rh) { return DLSS_BRIDGE_RESULT_ERROR_UNSUPPORTED; }
uint64_t dlss_bridge_get_available_presets(void) { return 0; }
const char* dlss_bridge_preset_to_name(int v) { return NULL; }
int dlss_bridge_preset_from_name(const char* n) { return -1; }
#endif // _WIN32
