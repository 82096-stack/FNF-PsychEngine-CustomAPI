$input v_texcoord0

/*
 * FidelityFX FSR 1.0 RCAS (Robust Contrast Adaptive Sharpening)
 * Faithful port of the original AMD FSR1 RCAS from ffx_fsr1.h (MIT License)
 *
 * Algorithm:
 *   - 5-tap cross pattern (top, left, center, right, bottom)
 *   - Anti-clipping lobe calculation (hitMin/hitMax per channel)
 *   - Noise detection (FSR_RCAS_DENOISE)
 *   - Luma: R*0.5 + G + B*0.5 (original FSR1 formula)
 *
 * Uniforms:
 *   u_fsrRCASConst0.xy = 1/outputW, 1/outputH   (output texel size)
 *   u_fsrRCASConst0.z  = sharpness (0.0 to 1.0, higher = more sharpening)
 *   u_fsrRCASConst0.w  = 0 (unused)
 */

#include <bgfx_shader.sh>

SAMPLER2D(s_inputTexture, 0);
uniform vec4 u_fsrRCASConst0;

// Original FSR1 RCAS limit (controls maximum sharpening before clipping)
#define FSR_RCAS_LIMIT (0.25-(1.0/16.0)) // = 0.1875, official AMD FSR1 value

void main()
{
    vec2 ts = u_fsrRCASConst0.xy;
    // Convert 0-1 slider to original FSR1 sharpness range via exp2(-sharpness)
    float sharpness = exp2(-u_fsrRCASConst0.z * 4.0);

    // 5-tap cross pattern (original FSR1 RCAS)
    //    b(top)
    // d(left) e(center) f(right)
    //    h(bottom)
    vec3 b = texture2D(s_inputTexture, v_texcoord0 + vec2( 0.0, -ts.y)).rgb; // top
    vec3 d = texture2D(s_inputTexture, v_texcoord0 + vec2(-ts.x,  0.0)).rgb; // left
    vec3 e = texture2D(s_inputTexture, v_texcoord0).rgb;                     // center
    vec3 f = texture2D(s_inputTexture, v_texcoord0 + vec2( ts.x,  0.0)).rgb; // right
    vec3 h = texture2D(s_inputTexture, v_texcoord0 + vec2( 0.0,  ts.y)).rgb; // bottom

    // Luma (original FSR1 formula: R*0.5 + G + B*0.5 = luma*2)
    float bL = dot(b, vec3(0.5, 1.0, 0.5));
    float dL = dot(d, vec3(0.5, 1.0, 0.5));
    float eL = dot(e, vec3(0.5, 1.0, 0.5));
    float fL = dot(f, vec3(0.5, 1.0, 0.5));
    float hL = dot(h, vec3(0.5, 1.0, 0.5));

    // Noise detection (FSR_RCAS_DENOISE from original FSR1)
    // nz detects isolated pixel difference; range is local dynamic range
    float nz = 0.25 * (bL + dL + fL + hL) - eL;
    float range = max(max(bL, dL), max(eL, max(fL, hL))) - min(min(bL, dL), min(eL, min(fL, hL)));
    range = max(range, 0.0001); // avoid div by zero
    nz = clamp(abs(nz) / range, 0.0, 0.5); // abs(nz) per original FSR1
    nz = -0.5 * nz + 1.0; // nz = 0.5 at isolated pixels, 1.0 at uniform areas

    // Per-channel min/max of ring (4 outer taps)
    vec3 mn4 = min(min(b, d), min(f, h));
    vec3 mx4 = max(max(b, d), max(f, h));

    // Anti-clipping lobe calculation (original FSR1 hitMin/hitMax)
    // hitMin: how much sharpening before the signal clips to black
    vec3 hitMin = mn4 / max(4.0 * mx4, 0.0001);
    // hitMax: how much sharpening before the signal clips to white (should be negative)
    vec3 hitMax = (mx4 - vec3(1.0)) / max(4.0 * mn4 - vec3(4.0), 0.0001);

    // Lobe is the maximum sharpening before clipping, shaped by sharpness
    vec3 lobe = max(-hitMin, hitMax);
    lobe = clamp(lobe, vec3(-FSR_RCAS_LIMIT), vec3(0.0));
    lobe *= sharpness;

    // Resolve: sharpened = (lobe * sum_ring + center) / (4 * lobe + 1)
    vec3 result = (lobe * (b + d + f + h) + e) / (4.0 * lobe + vec3(1.0));

    // Apply noise reduction: multiply lobe by nz (original FSR1 multiplicative approach)
    lobe *= nz;
    result = (lobe * (b + d + f + h) + e) / (4.0 * lobe + vec3(1.0));

    gl_FragColor = vec4(result, 1.0);
}
