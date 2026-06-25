$input v_texcoord0

/*
 * FidelityFX FSR 1.0 EASU (Edge-Adaptive Spatial Upsampling)
 * Ported from AMD FidelityFX SDK ffx_fsr1.h (MIT License)
 *
 * 12-tap Lanczos2-like edge-directed upscaling with directional
 * gradient analysis and min/max neighborhood deringing.
 *
 * Uniforms (float vec4 — compatible with existing Haxe FSRUpscaler.hx):
 *   u_fsrEASUConst0.xy = 1/inputW, 1/inputH   (input texel size)
 *   u_fsrEASUConst0.zw = inputW, inputH        (input viewport size)
 *   u_fsrEASUConst1.xy = outputW, outputH       (output size)
 *   u_fsrEASUConst1.zw = 1/outputW, 1/outputH   (output texel size)
 *   u_fsrEASUConst2.xy = scaleX, scaleY         (outputW/inputW, outputH/inputH)
 *   u_fsrEASUConst2.zw = 0, 0                   (unused)
 *   u_fsrEASUConst3    = 0, 0, 0, 0             (unused)
 */

#include <bgfx_shader.sh>

SAMPLER2D(s_inputTexture, 0);

uniform vec4 u_fsrEASUConst0;
uniform vec4 u_fsrEASUConst1;
uniform vec4 u_fsrEASUConst2;
uniform vec4 u_fsrEASUConst3;

// Original AMD FSR1 Lanczos2-like weight function from ffx_fsr1.h
// w = (25/16 * (2/5 * d2 - 1)^2 - (25/16 - 1)) * (lob * d2 - 1)^2
float FsrEasuTapWeight(float d2, float lob)
{
    float wB = 0.4 * d2 - 1.0;
    wB = wB * wB;
    float wA = lob * d2 - 1.0;
    wA = wA * wA;
    return (1.5625 * wB - 0.5625) * wA;
}

void main()
{
    vec2 inputSize  = u_fsrEASUConst0.zw;
    vec2 outputSize = u_fsrEASUConst1.xy;
    vec2 texel      = u_fsrEASUConst0.xy;

    // Output pixel center in input texture space (sub-pixel position of 'f' tap)
    vec2 ip = v_texcoord0 * outputSize;
    vec2 pp = ip * texel - 0.5;
    vec2 fp = floor(pp);
    vec2 sub = pp - fp;

    // 12-tap kernel layout around center tap 'f':
    //     b(0,-1)  c(1,-1)
    // e(-1,0)  f(0,0)  g(1,0)  h(2,0)
    // i(-1,1)  j(0,1)  k(1,1)  l(2,1)
    //     n(0,2)  o(1,2)
    #define SAMPLE(x,y) texture2D(s_inputTexture, (fp + vec2(x,y) + 0.5) * texel).rgb

    vec3 bC = SAMPLE( 0.0,-1.0); vec3 cC = SAMPLE( 1.0,-1.0);
    vec3 eC = SAMPLE(-1.0, 0.0); vec3 fC = SAMPLE( 0.0, 0.0);
    vec3 gC = SAMPLE( 1.0, 0.0); vec3 hC = SAMPLE( 2.0, 0.0);
    vec3 iC = SAMPLE(-1.0, 1.0); vec3 jC = SAMPLE( 0.0, 1.0);
    vec3 kC = SAMPLE( 1.0, 1.0); vec3 lC = SAMPLE( 2.0, 1.0);
    vec3 nC = SAMPLE( 0.0, 2.0); vec3 oC = SAMPLE( 1.0, 2.0);

    #undef SAMPLE

    // Approximate luma: R*0.5 + G + B*0.5
    #define LUMA(c) dot(c, vec3(0.5, 1.0, 0.5))
    float bL = LUMA(bC); float cL = LUMA(cC);
    float eL = LUMA(eC); float fL = LUMA(fC);
    float gL = LUMA(gC); float hL = LUMA(hC);
    float iL = LUMA(iC); float jL = LUMA(jC);
    float kL = LUMA(kC); float lL = LUMA(lC);
    float nL = LUMA(nC); float oL = LUMA(oC);
    #undef LUMA

    // Directional gradient analysis (original FSR pattern)
    // Accumulate direction from 4-axis luma gradients
    vec2 dir = vec2(0.0);
    float wsum = 0.0;

    // Axis 0: horizontal through f-g center (e→f→g→h)
    float d0 = abs(eL - fL) + abs(fL - gL) + abs(gL - hL);
    float l0 = 1.0 / (d0 + 0.0001);
    dir += vec2(2.0, 0.0) * l0 * (eL - hL);
    wsum += l0;

    // Axis 1: diagonal ↘ through f-g (b→f→g→k)
    float d1 = abs(bL - fL) + abs(fL - gL) + abs(gL - kL);
    float l1 = 1.0 / (d1 + 0.0001);
    dir += vec2(1.0, 1.0) * l1 * (bL - kL);
    wsum += l1;

    // Axis 2: vertical through f-j (f→j→k)
    float d2 = abs(fL - iL) + abs(iL - jL) + abs(jL - nL);
    float l2 = 1.0 / (d2 + 0.0001);
    dir += vec2(0.0, 2.0) * l2 * (fL - nL);
    wsum += l2;

    // Axis 3: diagonal ↖ through f-j (c→f→j→o)
    float d3 = abs(cL - fL) + abs(fL - jL) + abs(jL - oL);
    float l3 = 1.0 / (d3 + 0.0001);
    dir += vec2(-1.0, 1.0) * l3 * (cL - oL);
    wsum += l3;

    // Normalize direction
    dir /= max(wsum, 0.0001);
    float dirLen = length(dir);
    float zro = float(dirLen < 1.0 / 32768.0);
    dir = zro > 0.5 ? vec2(1.0, 0.0) : dir / max(dirLen, 0.0001);

    // Edge strength (0 = no edge, 1 = strong edge)
    // Reference: len measures directional coherence via fsrEasuSetFloat
    // We approximate as: max direction magnitude / total gradient sum
    // This gives: high on directional edges, low on flats and diagonals
    float totalGrad = d0 + d1 + d2 + d3 + 0.0001;
    float len = length(dir) / totalGrad;
    len = clamp(len * 4.0, 0.0, 1.0); // scale and clamp to [0,1]
    len = len * len;                    // square for sharper transition

    // Kernel stretch: 1.0 on pure axis, ~1.414 on diagonal
    float stretch = dot(dir, dir) / max(abs(dir.x), abs(dir.y));

    // Anisotropic length after rotation
    vec2 len2 = vec2(1.0 + (stretch - 1.0) * len, 1.0 - 0.5 * len);

    // Lobe (window size) shrinks with edge strength
    float lob = 0.5 + (0.25 - 0.04 - 0.5) * len;

    // Clipping distance (reciprocal of lobe)
    float clp = 1.0 / max(lob, 0.0001);

    // Min/Max of 4 nearest taps (f, g, j, k) for deringing
    vec3 min4 = min(min(fC, gC), min(jC, kC));
    vec3 max4 = max(max(fC, gC), max(jC, kC));

    // Accumulate weighted contributions from all 12 taps
    vec3 accum = vec3(0.0);
    float aW = 0.0;

    #define TAP(offX, offY, col) { \
        vec2 o = vec2(offX, offY) - sub; \
        /* Rotate offset by gradient direction (key FSR1 innovation) */ \
        vec2 rotated = vec2(o.x * dir.x + o.y * dir.y, o.x * (-dir.y) + o.y * dir.x); \
        /* Apply anisotropic length scaling */ \
        rotated *= len2; \
        float d2 = dot(rotated, rotated); \
        d2 = min(d2, clp); \
        float w = FsrEasuTapWeight(d2, lob); \
        accum += col * w; aW += w; }

    TAP( 0.0,-1.0, bC) TAP( 1.0,-1.0, cC)
    TAP(-1.0, 0.0, eC) TAP( 0.0, 0.0, fC) TAP(1.0, 0.0, gC) TAP(2.0, 0.0, hC)
    TAP(-1.0, 1.0, iC) TAP( 0.0, 1.0, jC) TAP(1.0, 1.0, kC) TAP(2.0, 1.0, lC)
    TAP( 0.0, 2.0, nC) TAP( 1.0, 2.0, oC)

    #undef TAP

    // Normalize and clamp to neighborhood min/max (deringing)
    vec3 result = accum / max(aW, 1e-10);
    result = clamp(result, min4, max4);

    gl_FragColor = vec4(result, 1.0);
}
