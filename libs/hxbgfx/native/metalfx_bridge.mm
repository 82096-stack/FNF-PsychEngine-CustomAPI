// metalfx_bridge.mm — MetalFX bridge using official Apple API
//
// Uses MTLFXSpatialScaler and MTLFXTemporalScaler from MetalFX.framework.
// Operates on native Metal textures (no CPU readback).
// Shares bgfx's MTLDevice via hxbgfx_get_mtl_device().
//
// Requirements: macOS 13.0+ (Ventura), MetalFX.framework
//
// Mode 0 = Spatial:  single-frame upscale, no depth/motion needed
// Mode 1 = Temporal:  multi-frame upscale with flat depth + zero motion for 2D

#import <Metal/Metal.h>
#import <MetalFX/MetalFX.h>
#import <Foundation/Foundation.h>

// ── Global state ─────────────────────────────────────────────────

static id<MTLDevice>                  _device = nil;
static id<MTLCommandQueue>            _queue = nil;
static id<MTLFXSpatialScaler>         _spatialScaler = nil;
static id<MTLFXTemporalScaler>       _temporalScaler = nil;

// Helper textures for Temporal mode (2D defaults: flat depth, no motion)
static id<MTLTexture>                 _flatDepthTex = nil;
static id<MTLTexture>                 _zeroMotionTex = nil;

static int _inputW = 0, _inputH = 0;
static int _outputW = 0, _outputH = 0;
static int _mode = 0;       // 0 = Spatial, 1 = Temporal
static bool _initialized = false;

// ── Helpers ──────────────────────────────────────────────────────

static id<MTLTexture> createFlat1x1Texture(MTLPixelFormat format, float value)
{
    MTLTextureDescriptor* desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:format
        width:1 height:1 mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    id<MTLTexture> tex = [_device newTextureWithDescriptor:desc];
    if (!tex) return nil;

    // Upload single-pixel value via blit
    id<MTLBuffer> staging = [_device newBufferWithLength:(size_t)sizeof(float)
        options:MTLResourceStorageModeShared];
    *(float*)[staging contents] = value;

    id<MTLCommandBuffer> cb = [_queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
    [blit copyFromBuffer:staging sourceOffset:0
        sourceBytesPerRow:sizeof(float)
        sourceBytesPerImage:sizeof(float)
        sourceSize:MTLSizeMake(1,1,1)
        toTexture:tex destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0,0,0)];
    [blit endEncoding];
    [cb commit];
    [cb waitUntilCompleted];

    return tex;
}

static bool createSpatialScaler(void)
{
    MTLFXSpatialScalerDescriptor* desc = [[MTLFXSpatialScalerDescriptor alloc] init];
    desc.inputWidth  = (NSUInteger)_inputW;
    desc.inputHeight = (NSUInteger)_inputH;
    desc.outputWidth  = (NSUInteger)_outputW;
    desc.outputHeight = (NSUInteger)_outputH;
    desc.colorTextureFormat = MTLPixelFormatBGRA8Unorm;
    desc.outputTextureFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorProcessingMode = MTLFXSpatialScalerColorProcessingModePerceptual;

    if (![MTLFXSpatialScalerDescriptor supportsDevice:_device]) {
        NSLog(@"[MetalFX] Spatial scaler not supported on this device");
        return false;
    }

    _spatialScaler = [desc newSpatialScalerWithDevice:_device];
    if (!_spatialScaler) {
        NSLog(@"[MetalFX] Failed to create spatial scaler");
        return false;
    }

    NSLog(@"[MetalFX] Spatial scaler created: %dx%d → %dx%d",
        _inputW, _inputH, _outputW, _outputH);
    return true;
}

static bool createTemporalScaler(void)
{
    MTLFXTemporalScalerDescriptor* desc = [[MTLFXTemporalScalerDescriptor alloc] init];
    desc.inputWidth  = (NSUInteger)_inputW;
    desc.inputHeight = (NSUInteger)_inputH;
    desc.outputWidth  = (NSUInteger)_outputW;
    desc.outputHeight = (NSUInteger)_outputH;
    desc.colorTextureFormat = MTLPixelFormatBGRA8Unorm;
    desc.depthTextureFormat = MTLPixelFormatR32Float;
    desc.motionTextureFormat = MTLPixelFormatRG16Float;
    desc.outputTextureFormat = MTLPixelFormatBGRA8Unorm;
    desc.isAutoExposure = NO;
    desc.isDepthReversed = NO;

    _temporalScaler = [desc newTemporalScalerWithDevice:_device];
    if (!_temporalScaler) {
        NSLog(@"[MetalFX] Temporal scaler not supported on this device");
        return false;
    }

    // Create helper textures for 2D: flat depth (all at max = 1.0), zero motion
    _flatDepthTex = createFlat1x1Texture(MTLPixelFormatR32Float, 1.0f);
    _zeroMotionTex = createFlat1x1Texture(MTLPixelFormatRG16Float, 0.0f);

    if (!_flatDepthTex || !_zeroMotionTex) {
        NSLog(@"[MetalFX] Failed to create temporal helper textures");
        _temporalScaler = nil;
        return false;
    }

    _temporalScaler.reset = YES; // start with clean history

    NSLog(@"[MetalFX] Temporal scaler created: %dx%d → %dx%d (2D mode: flat depth + zero motion)",
        _inputW, _inputH, _outputW, _outputH);
    return true;
}

// ── C bridge functions ───────────────────────────────────────────

extern "C" {

/// Check if MetalFX is supported on the given Metal device.
bool metalfx_is_supported(void* mtlDevice)
{
    if (!mtlDevice) return false;
    id<MTLDevice> dev = (__bridge id<MTLDevice>)mtlDevice;
    return [MTLFXSpatialScalerDescriptor supportsDevice:dev];
}

/// Initialize MetalFX scaler.
/// @param mtlDevice  bgfx's MTLDevice (from hxbgfx_get_mtl_device())
/// @param mode       0 = Spatial, 1 = Temporal
bool metalfx_init(void* mtlDevice, int inputW, int inputH, int outputW, int outputH, int mode)
{
    if (!mtlDevice) {
        NSLog(@"[MetalFX] No MTLDevice provided");
        return false;
    }

    // Dispose previous state
    if (_initialized) {
        _spatialScaler = nil;
        _temporalScaler = nil;
        _flatDepthTex = nil;
        _zeroMotionTex = nil;
        _queue = nil;
        _device = nil;
        _initialized = false;
    }

    _device = (__bridge id<MTLDevice>)mtlDevice;
    _inputW = inputW; _inputH = inputH;
    _outputW = outputW; _outputH = outputH;
    _mode = mode;

    // Create command queue
    _queue = [_device newCommandQueue];
    if (!_queue) {
        NSLog(@"[MetalFX] Failed to create command queue");
        _device = nil;
        return false;
    }

    bool ok = (mode == 0) ? createSpatialScaler() : createTemporalScaler();
    if (!ok) {
        _queue = nil;
        _device = nil;
        return false;
    }

    _initialized = true;
    return true;
}

/// Apply MetalFX upscaling. Operates directly on GPU textures — no CPU roundtrip.
/// @param inputMTLTexture   Low-res input texture (id<MTLTexture> from bgfx)
/// @param outputMTLTexture  High-res output texture (id<MTLTexture> target)
bool metalfx_apply(void* inputMTLTexture, void* outputMTLTexture)
{
    if (!_initialized) return false;

    id<MTLTexture> input = (__bridge id<MTLTexture>)inputMTLTexture;
    id<MTLTexture> output = (__bridge id<MTLTexture>)outputMTLTexture;
    if (!input || !output) return false;

    if (_mode == 0) {
        // ── Spatial: single-pass upscale ──────────────────────────
        _spatialScaler.colorTexture = input;
        _spatialScaler.outputTexture = output;

        id<MTLCommandBuffer> cb = [_queue commandBuffer];
        [_spatialScaler encodeToCommandBuffer:cb];
        [cb commit];
    } else {
        // ── Temporal: multi-frame with depth + motion ─────────────
        _temporalScaler.colorTexture = input;
        _temporalScaler.outputTexture = output;
        _temporalScaler.depthTexture = _flatDepthTex;
        _temporalScaler.motionTexture = _zeroMotionTex;
        _temporalScaler.jitterOffsetX = 0.0f;
        _temporalScaler.jitterOffsetY = 0.0f;

        id<MTLCommandBuffer> cb = [_queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [_temporalScaler encodeToCommandBuffer:cb];
        if (encoder) [encoder endEncoding];
        [cb commit];
    }

    return true;
}

/// Reset temporal history (only effective in Temporal mode).
/// Must be called on the first frame and after resolution changes.
void metalfx_reset(void)
{
    if (_temporalScaler) {
        _temporalScaler.reset = YES;
        NSLog(@"[MetalFX] Temporal history reset");
    }
}

/// Release all MetalFX resources.
void metalfx_dispose(void)
{
    _spatialScaler = nil;
    _temporalScaler = nil;
    _flatDepthTex = nil;
    _zeroMotionTex = nil;
    _queue = nil;
    _device = nil;
    _initialized = false;
    NSLog(@"[MetalFX] Disposed");
}

} // extern "C"
