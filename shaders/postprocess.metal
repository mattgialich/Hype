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

// Simple hash function for deterministic screen-space noise
uint hash(uint seed) {
    seed = (seed << 13) ^ seed;
    seed = (seed << 15) ^ seed;
    seed = (seed << 17) ^ seed;
    return seed;
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
    // Threshold: only bloom bright regions, with a warmer tint
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    color *= smoothstep(0.7, 1.3, luma);
    // Warm bloom tint
    color *= float3(1.15, 1.0, 0.65);
    return float4(color, 1.0);
}

// Helper function for golden-hour grading with tri-stop curve
float3 goldenHourGrade(float3 color) {
    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
    
    // Tri-stop curve: shadows (cool), midtones (warm), highlights (warm golden)
    float3 shadowTint = float3(0.65, 0.85, 0.80);  // Cool mossy teal-green
    float3 midTint = float3(1.0, 0.9, 0.75);       // Earthy warm
    float3 highlightTint = float3(1.25, 1.1, 0.85); // Warm golden sunbeam
    
    // Smooth transition using a sigmoid curve
    float t = smoothstep(0.0, 1.0, luma);
    float t1 = smoothstep(0.2, 0.4, luma);
    float t2 = smoothstep(0.6, 0.8, luma);
    
    float3 graded = mix(shadowTint, midTint, t1);
    graded = mix(graded, highlightTint, t2);
    
    return color * graded;
}

// Helper function for atmospheric haze
float3 applyHaze(float3 color, float2 uv, float3 bloom3) {
    // Approximate depth-based haze using UV coordinates
    float altitude = saturate(1.0 - uv.y);
    
    // Haze tint: slightly warm and desaturated
    float3 hazeTint = float3(0.95, 0.85, 0.75);
    
    // Mix haze based on bloom intensity
    float hazeIntensity = dot(bloom3, float3(0.33, 0.33, 0.33));
    hazeIntensity = smoothstep(0.1, 0.5, hazeIntensity);
    
    // Apply haze
    float3 haze = mix(float3(1.0, 1.0, 1.0), hazeTint, hazeIntensity * 0.3);
    color = mix(color, color * haze, altitude * 0.5);
    
    return color;
}

// Helper function for sunbeam/godray effect
float3 applySunbeams(float3 color, float2 uv, texture2d<float> bloom, sampler samp, float3 bloom3) {
    // Sun position in upper-right (based on UV convention)
    float2 sunPos = float2(0.8, 0.2);
    
    // Radial blur with 6 taps
    float3 sunbeam = float3(0.0);
    const int taps = 6;
    for (int i = 0; i < taps; i++) {
        float t = float(i) / float(taps - 1);
        float2 sampleUV = mix(uv, sunPos, t);
        float3 sample = bloom.sample(samp, sampleUV).rgb * 0.5;
        // Weight by distance from sun
        float weight = 1.0 - t;
        sunbeam += sample * weight * 0.5;
    }
    
    // Warm gold tint for sunbeams
    float3 sunbeamTint = float3(1.2, 1.0, 0.6);
    sunbeam = sunbeam * sunbeamTint;
    
    // Only apply sunbeams to bright areas
    float bright = dot(color, float3(0.33, 0.33, 0.33));
    sunbeam *= smoothstep(0.5, 1.0, bright);
    
    return color + sunbeam;
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

    // Apply golden-hour grading
    mapped = goldenHourGrade(mapped);

    // Apply atmospheric haze
    mapped = applyHaze(mapped, in.uv, bloom3);

    // Apply sunbeams
    mapped = applySunbeams(mapped, in.uv, bloom, samp, bloom3);

    // Vignette - tighter and warmer
    float2 uv     = in.uv * 2.0 - 1.0;
    float  vignette = 1.0 - dot(uv, uv) * 0.40;  // Stronger falloff
    vignette = saturate(vignette);
    // Warm vignette edge
    float3 vignetteColor = float3(0.8, 0.7, 0.6);
    mapped = mix(mapped, mapped * vignetteColor, 1.0 - vignette);

    // Add subtle film grain
    uint seed = hash(uint(in.uv.x * 1920.0) * 1973u + uint(in.uv.y * 1080.0) * 9277u);
    float grain = (seed % 1000) / 1000.0;
    grain = grain * 0.002 - 0.001;  // Very subtle noise
    mapped += grain;

    return float4(mapped, 1.0);
}
