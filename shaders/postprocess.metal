// postprocess.metal — fullscreen bloom + color grading + vignette
// Input: GBuffer albedo+emissive + HDR particle layer
// Output: final LDR swapchain image

#include <metal_stdlib>
using namespace metal;

struct QuadVert {
    float4 pos [[position]];
    float2 uv;
};

// Fullscreen triangle (no vertex buffer needed)
vertex QuadVert vert_fullscreen(uint vid [[vertex_id]]) {
    float2 positions[3] = {
        float2(-1, -1), float2(3, -1), float2(-1, 3)
    };
    float2 uvs[3] = {
        float2(0, 1), float2(2, 1), float2(0, -1)
    };
    QuadVert out;
    out.pos = float4(positions[vid], 0, 1);
    out.uv  = uvs[vid];
    return out;
}

// Gaussian downsample for bloom
fragment float4 frag_bloom_downsample(
    QuadVert             in      [[stage_in]],
    texture2d<float>     hdr     [[texture(0)]],
    sampler              samp    [[sampler(0)]]
) {
    float2 texel = 1.0 / float2(hdr.get_width(), hdr.get_height());
    float3 color = float3(0);
    // 4x4 tent filter
    for (int x = -1; x <= 2; x++) {
        for (int y = -1; y <= 2; y++) {
            color += hdr.sample(samp, in.uv + float2(x, y) * texel).rgb;
        }
    }
    color /= 16.0;
    // Threshold: only bloom bright regions
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    color *= smoothstep(0.8, 1.2, luma);
    return float4(color, 1.0);
}

// Final composite + tone map
fragment float4 frag_composite(
    QuadVert             in       [[stage_in]],
    texture2d<float>     hdr      [[texture(0)]],  // scene + particles
    texture2d<float>     bloom    [[texture(1)]],  // blurred bright layer
    texture2d<float>     emissive [[texture(2)]]   // emissive GBuffer
) {
    constexpr sampler samp(filter::linear, address::clamp_to_edge);
    float3 scene   = hdr.sample(samp, in.uv).rgb;
    float3 glow    = emissive.sample(samp, in.uv).rgb;
    float3 bloom3  = bloom.sample(samp, in.uv).rgb;

    // HDR accumulate
    float3 hdr_color = scene + glow * 1.5 + bloom3 * 0.8;

    // ACES tone mapping (filmic)
    float3 x = hdr_color;
    float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    float3 mapped = saturate((x * (a * x + b)) / (x * (c * x + d) + e));

    // Vignette
    float2 uv     = in.uv * 2.0 - 1.0;
    float  vignette = 1.0 - dot(uv, uv) * 0.35;
    mapped *= vignette;

    // Forest grading: cool green shadows, warm golden dappled highlights
    float luma    = dot(mapped, float3(0.2126, 0.7152, 0.0722));
    float3 grade  = mix(
        float3(0.82, 1.08, 0.76),  // shadow tint: mossy green
        float3(1.14, 0.98, 0.70),  // highlight tint: warm sunbeam gold
        luma
    );
    mapped *= grade;

    return float4(mapped, 1.0);
}
