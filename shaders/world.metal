// world.metal — main geometry pass (opaque 3D meshes, PBR-lite)
// Deferred: writes to GBuffer (albedo, normal, depth), resolved in postprocess.metal

#include <metal_stdlib>
using namespace metal;

// Must match renderer/metal.zig FrameUniforms (160 bytes, packed layout)
struct FrameUniforms {
    float4x4      view_proj;
    float4x4      view_proj_inv;
    packed_float3 camera_pos;   // packed = 4-byte aligned, matches Zig [3]f32
    float         time;
    float2        resolution;
    float         walk_phase; // advances only while player moves
    float         _pad;
};

// Must match renderer/metal.zig DrawCall (88 bytes, 4-byte aligned).
// float4x4 has 16-byte alignment in Metal → sizeof = 96 (wrong).
// Use four packed_float4 columns instead: 4-byte aligned → sizeof = 88 (correct).
struct DrawCall {
    packed_float4 model_c0;  // column 0  (offset  0)
    packed_float4 model_c1;  // column 1  (offset 16)
    packed_float4 model_c2;  // column 2  (offset 32)
    packed_float4 model_c3;  // column 3  (offset 48)
    packed_float4 color;     //            (offset 64)
    uint          fx_flags;  //            (offset 80)
    ushort        mesh_id;   //            (offset 84)
    uchar2        _pad;      //            (offset 86)
};  // 88 bytes, align 4

struct VertIn {
    float3 pos     [[attribute(0)]];
    float3 normal  [[attribute(1)]];
    float2 uv      [[attribute(2)]];
};

struct VertOut {
    float4 clip_pos [[position]];
    float3 world_pos;
    float3 object_pos;   // original vertex (pre-anim, pre-model) — stable mesh-frame coords for body-attached patterns
    float3 normal;
    float2 uv;
    float4 color;
    uint   fx_flags;
};

// GBuffer outputs
struct GBuffer {
    float4 albedo  [[color(0)]]; // rgb=albedo, a=roughness
    float4 normal  [[color(1)]]; // rgb=world normal (encoded), a=metallic
    float4 emissive[[color(2)]]; // rgb=emissive, a=unused
};

// Procedural noise functions
float hash21(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float hash31(float3 p) {
    return fract(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float valueNoise3(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float c000 = hash31(i + float3(0.0, 0.0, 0.0));
    float c100 = hash31(i + float3(1.0, 0.0, 0.0));
    float c010 = hash31(i + float3(0.0, 1.0, 0.0));
    float c110 = hash31(i + float3(1.0, 1.0, 0.0));
    float c001 = hash31(i + float3(0.0, 0.0, 1.0));
    float c101 = hash31(i + float3(1.0, 0.0, 1.0));
    float c011 = hash31(i + float3(0.0, 1.0, 1.0));
    float c111 = hash31(i + float3(1.0, 1.0, 1.0));

    float x00 = mix(c000, c100, f.x);
    float x10 = mix(c010, c110, f.x);
    float x01 = mix(c001, c101, f.x);
    float x11 = mix(c011, c111, f.x);

    float y0 = mix(x00, x10, f.y);
    float y1 = mix(x01, x11, f.y);

    return mix(y0, y1, f.z);
}

float fbm3(float3 p) {
    float f = 0.0;
    f += 0.5000 * valueNoise3(p * 1.0);
    f += 0.2500 * valueNoise3(p * 2.0);
    f += 0.1250 * valueNoise3(p * 4.0);
    f += 0.0625 * valueNoise3(p * 8.0);
    return f;
}

vertex VertOut vert_world(
    VertIn                   in    [[stage_in]],
    constant FrameUniforms&  frame [[buffer(0)]],
    constant DrawCall&       draw  [[buffer(1)]]
) {
    // Walking animation for hero (mesh_id==1): limb/staff parts encoded in uv.x 20–25
    float3 pos = in.pos;
    if (draw.mesh_id == 1 && in.uv.x >= 20.0 && in.uv.x < 26.0) {
        int   part = int(in.uv.x - 20.0);
        float walk = sin(frame.walk_phase);
        if (part == 2) { float d = max(1.68 - pos.y, 0.0) / 0.78; pos.z -= walk * 0.28 * d; }
        if (part == 3) { float d = max(1.68 - pos.y, 0.0) / 0.78; pos.z += walk * 0.28 * d; }
        // Staff (parts 4+): full rotation about shoulder — no clamp so top swings opposite bottom
        if (part >= 4) { float d = (1.68 - pos.y) / 0.78; pos.z -= walk * 0.28 * d; }
    }
    // Gargoyle wing flap (mesh_id==3): uv.x>=30, uv.y=extension t (0=root, 1=tip)
    if (draw.mesh_id == 3 && in.uv.x >= 30.0) {
        float t    = in.uv.y;
        float flap = sin(frame.time * 6.5) * 0.24;
        pos.y += t * flap;
    }

    // Reconstruct float4x4 from packed columns (column-major, matches Zig Mat4)
    float4x4 model = float4x4(float4(draw.model_c0),
                               float4(draw.model_c1),
                               float4(draw.model_c2),
                               float4(draw.model_c3));
    float4 world_pos4 = model * float4(pos, 1.0);
    VertOut out;
    out.clip_pos  = frame.view_proj * world_pos4;
    out.world_pos = world_pos4.xyz;
    out.object_pos = in.pos;  // original vertex (pre-anim, pre-model) — patterns stay glued to the surface even when limbs swing
    out.normal    = normalize((model * float4(in.normal, 0.0)).xyz);
    out.uv        = in.uv;
    out.color     = float4(draw.color);
    // Pack mesh_id into upper 16 bits so frag shader can read it without extra buffer binding
    out.fx_flags  = draw.fx_flags | (uint(draw.mesh_id) << 16);
    return out;
}

// Forward rendering: single rgba16Float HDR output — used in the geometry pass
fragment float4 frag_world_forward(
    VertOut                  in    [[stage_in]],
    constant FrameUniforms&  frame [[buffer(0)]]
) {
    float3 albedo   = in.color.rgb;
    float3 emissive = float3(0);

    // Hero mage coloring: mesh_id packed into upper 16 bits of fx_flags
    uint mesh_frag = in.fx_flags >> 16;
    if (mesh_frag == 1u) {
        if (in.uv.x < 1.0) {
            albedo = float3(0.92, 0.74, 0.56);              // skin: head + neck
        } else if (in.uv.x < 2.0) {
            // Robe body + hat brim
            albedo = float3(0.50, 0.07, 0.68);              // base purple
            
            // Vertical gradient: darken at hem, brighten at chest
            float yFactor = (in.object_pos.y - 0.0) / (1.6 - 0.0);
            float brightness = 0.85 + 0.25 * yFactor;
            albedo *= brightness;
            
            // Cross-hatch fabric weave
            float weave = sin(in.object_pos.x * 90.0) * sin(in.object_pos.y * 90.0);
            albedo *= 1.0 + weave * 0.04;
            
            // Celestial runes
            float runeField = valueNoise3(in.object_pos * 6.0 + float3(0, 0, frame.time * 0.05));
            float runeMask = smoothstep(0.78, 0.85, runeField);
            float runePulse = 0.6 + 0.4 * sin(frame.time * 1.6 + in.object_pos.y * 3.0);
            emissive += float3(0.85, 0.65, 1.20) * runeMask * runePulse * 0.7;
            
            // Stronger shimmer biased toward runes
            float shimmer = 0.5 + 0.5 * sin(frame.time * 2.3 + in.object_pos.y * 4.0);
            emissive += albedo * float3(0.6, 0.1, 0.9) * shimmer * 0.09 * (1.0 + runeMask * 1.5);
        } else if (in.uv.x < 4.0) {
            // Hat cone
            albedo = float3(0.22, 0.03, 0.36);              // base deep indigo
            
            // Vertical gradient: darker at tip, brighter at base
            float yFactor = (in.object_pos.y - 0.0) / (1.6 - 0.0);
            float brightness = 0.85 + 0.15 * yFactor;
            albedo *= brightness;
            
            // Starfield
            float starHash = hash31(floor(in.object_pos * 50.0));
            float starMask = smoothstep(0.985, 0.995, starHash);
            float twinkle = 0.5 + 0.5 * sin(frame.time * 4.0 + starHash * 31.0);
            emissive += float3(1.0, 0.95, 0.85) * starMask * twinkle * 1.5;
            
            // Cool ambient glow
            emissive += float3(0.1, 0.15, 0.3) * 0.2;
        } else if (in.uv.x < 24.0) {
            // Arms / sleeves
            albedo = float3(0.42, 0.06, 0.60);              // base purple sleeves
            
            // Cross-hatch fabric weave (subtler)
            float weave = sin(in.object_pos.x * 90.0) * sin(in.object_pos.y * 90.0);
            albedo *= 1.0 + weave * 0.03;
            
            // Rarer rune set on sleeves
            float runeField = valueNoise3(in.object_pos * 6.0 + float3(0, 0, frame.time * 0.05));
            float runeMask = smoothstep(0.83, 0.90, runeField);
            float runePulse = 0.6 + 0.4 * sin(frame.time * 1.6 + in.object_pos.y * 3.0);
            emissive += float3(0.85, 0.65, 1.20) * runeMask * runePulse * 0.3;
        } else if (in.uv.x < 25.0) {
            // Staff shaft
            albedo = float3(0.52, 0.33, 0.12);              // base warm wood
            
            // Wood grain
            float grain = valueNoise3(in.object_pos * float3(40.0, 8.0, 40.0));
            albedo *= mix(0.85, 1.10, grain);
            
            // Carved runes
            float yBand = step(1.4, in.object_pos.y) * step(in.object_pos.y, 1.65);
            float runeField = valueNoise3(in.object_pos * 6.0 + float3(0, 0, frame.time * 0.05));
            float runeMask = smoothstep(0.83, 0.90, runeField);
            float runePulse = 0.6 + 0.4 * sin(frame.time * 1.6 + in.object_pos.y * 3.0);
            emissive += float3(1.1, 0.9, 0.5) * runeMask * runePulse * 0.6 * yBand;
        } else {
            // Staff orb
            albedo = float3(0.80, 0.38, 1.00);              // bright magic crystal
            float pulse = 0.5 + 0.5 * sin(frame.time * 3.5);
            emissive += float3(0.55, 0.12, 0.90) * pulse * 1.4;
            
            // Concentric energy rings
            float r = fract(length(in.object_pos) * 4.0 - frame.time * 0.8);
            float ring = smoothstep(0.0, 0.05, r) * (1.0 - smoothstep(0.05, 0.10, r));
            emissive += float3(0.9, 0.5, 1.2) * ring * 0.8;
        }
        // Subtle shimmer on robe + hat parts only
        if (in.uv.x >= 1.0 && in.uv.x < 24.0) {
            float shimmer = 0.5 + 0.5 * sin(frame.time * 2.3 + in.object_pos.y * 4.0);
            emissive += albedo * float3(0.6, 0.1, 0.9) * shimmer * 0.09;
        }
    }

    // Gargoyle: glowing eye gems + stone body + dark wing membrane
    if (mesh_frag == 3u) {
        if (in.uv.x >= 8.0 && in.uv.x < 9.0) {
            // Glowing eye gems (uv.x marker = 8): dark stone backing + bright crimson emissive
            albedo = float3(0.08, 0.02, 0.02);
            float pulse = 0.7 + 0.3 * sin(frame.time * 2.0);
            emissive += float3(2.6, 0.40, 0.15) * pulse;
        } else if (in.uv.x < 30.0) {
            // Stone treatment with noise variation and moss
            float fbm = fbm3(in.object_pos * 1.8);
            float noise = valueNoise3(in.object_pos * 12.0);
            
            // Modulate albedo brightness ±20%
            float brightness = 0.8 + 0.4 * fbm;
            albedo = float3(0.30, 0.28, 0.32) * brightness;
            
            // Add high-frequency speckle/grain (±5% lightness)
            float grain = 0.95 + 0.1 * noise;
            albedo *= grain;
            
            // Bias toward moss in low-noise crevices
            float mossBias = smoothstep(0.35, 0.15, fbm);
            albedo = mix(albedo, float3(0.20, 0.32, 0.18), mossBias);
        } else {
            albedo = float3(0.15, 0.11, 0.20); // dark purple-gray wing membrane
        }
    }

    // Lightning bolt: pure emissive, rapid flicker, early return (no normal lighting)
    if (mesh_frag == 7u) {
        float flicker = 0.5 + 0.5 * sin(frame.time * 40.0 + in.world_pos.y * 1.5);
        float3 core  = float3(0.80, 0.90, 1.00);
        float3 glow  = float3(0.45, 0.70, 1.00) * flicker * 5.5
                     + float3(0.25, 0.45, 1.00) * (1.0 - flicker) * 2.8;
        return float4(core + glow, 1.0);
    }

    // Trunk geometry: u in [10, 20) is a bark marker; int(u - 10) = trunk index 0..2
    if (in.uv.x >= 10.0 && in.uv.x < 20.0) {
        int tid = int(in.uv.x - 10.0);  // 0, 1, or 2
        // Three distinct bark browns — amber, mahogany, dark root
        float3 barks[3] = { float3(0.52, 0.28, 0.10),
                             float3(0.32, 0.16, 0.06),
                             float3(0.18, 0.09, 0.03) };
        albedo  = barks[tid % 3];
        emissive = float3(0);
        
        // Add moss patches on shaded sides
        float upness = saturate(dot(normalize(in.normal), float3(0, 1, 0)));
        float mossN = valueNoise3(in.world_pos * 0.8);
        albedo = mix(albedo, float3(0.20, 0.36, 0.18), smoothstep(0.55, 0.75, mossN) * (1.0 - upness) * 0.6);
        
        // Simple bark lighting (reuse same L/N below)
        float3 L = normalize(float3(0.4, 1.0, 0.25));
        float3 N = normalize(in.normal);
        float diff = max(dot(N, L), 0.0);
        float back = max(dot(N, -L), 0.0);
        float3 ambient = albedo * float3(0.12, 0.09, 0.06);
        float3 diffuse = albedo * float3(1.2, 1.1, 0.9) * diff;
        float3 rim     = albedo * float3(0.05, 0.03, 0.01) * back;
        return float4(ambient + diffuse + rim, 1.0);
    }

    // Rock treatment
    if (mesh_frag == 5u) {
        // Stone treatment with noise variation and moss
        float fbm = fbm3(in.world_pos * 1.8);
        float noise = valueNoise3(in.world_pos * 12.0);
        
        // Modulate albedo brightness ±20%
        float brightness = 0.8 + 0.4 * fbm;
        albedo = float3(0.30, 0.28, 0.32) * brightness;
        
        // Add high-frequency speckle/grain (±5% lightness)
        float grain = 0.95 + 0.1 * noise;
        albedo *= grain;
        
        // Bias toward moss in low-noise crevices
        float mossBias = smoothstep(0.35, 0.15, fbm);
        albedo = mix(albedo, float3(0.20, 0.32, 0.18), mossBias);
    }

    // Tower: same stone treatment as gargoyle/rock, slightly cooler base
    if (mesh_frag == 8u) {
        float fbm = fbm3(in.world_pos * 1.4);
        float noise = valueNoise3(in.world_pos * 10.0);
        float brightness = 0.85 + 0.30 * fbm;
        albedo = in.color.rgb * brightness;        // base from team color (warm gray)
        albedo *= (0.95 + 0.10 * noise);
        // Heavier moss bias on towers — they've been there a while
        float mossBias = smoothstep(0.42, 0.20, fbm);
        albedo = mix(albedo, float3(0.20, 0.34, 0.18), mossBias * 0.65);
    }

    // Torch: pole / bowl / emissive flame distinguished by uv.x
    if (mesh_frag == 9u) {
        if (in.uv.x >= 50.0) {
            // FLAME — pure emissive flickering warm orange, early return.
            float flicker = 0.5 + 0.5 * sin(frame.time * 18.0 + in.world_pos.y * 7.0)
                              + 0.25 * sin(frame.time * 33.0 + in.world_pos.x * 9.0);
            float vBlend = saturate((in.world_pos.y - 1.5) / 0.6);  // 0 at base, 1 at tip
            float3 core  = mix(float3(1.0, 0.55, 0.10), float3(1.0, 0.95, 0.50), 1.0 - vBlend);
            float3 glow  = float3(2.0, 0.9, 0.25) * flicker;
            return float4(core + glow * (1.0 - vBlend) * 1.4, 1.0);
        } else if (in.uv.x >= 1.0 && in.uv.x < 2.0) {
            // BOWL — dark iron-gray with subtle stone noise
            float fbm = fbm3(in.world_pos * 6.0);
            albedo = float3(0.18, 0.16, 0.18) * (0.8 + 0.4 * fbm);
        } else {
            // POLE — base is dark wood from team color, add wood grain
            float grain = valueNoise3(in.world_pos * float3(35.0, 6.0, 35.0));
            albedo = in.color.rgb * mix(0.85, 1.10, grain);
        }
    }

    // FX: burning — add fiery emissive pulse
    if (in.fx_flags & 1u) { // BURNING
        float pulse = 0.5 + 0.5 * sin(in.world_pos.y * 4.0 + frame.time * 3.0);
        emissive += float3(2.0, 0.4, 0.0) * pulse;
        albedo   *= float3(0.4, 0.1, 0.0);
    }
    if (in.fx_flags & 2u) { // FROZEN
        albedo = mix(albedo, float3(0.6, 0.8, 1.0), 0.7);
    }
    if (in.fx_flags & 16u) { // LOW_HP_AURA
        float pulse = 0.5 + 0.5 * sin(frame.time * 6.0);
        emissive += float3(1.2, 0.0, 0.0) * pulse * 0.3;
    }

    // Moss bias on shaded surfaces (apply to all opaque geometry except hero mage and tree bark)
    if (mesh_frag != 1u && !(in.uv.x >= 10.0 && in.uv.x < 20.0)) {
        float upness = saturate(dot(normalize(in.normal), float3(0, 1, 0)));
        float mossAmount = (1.0 - upness) * fbm3(in.world_pos * 0.7) * 0.45;
        albedo = mix(albedo, float3(0.18, 0.30, 0.16), mossAmount);
    }

    // Specular highlights
    float3 L = normalize(float3(0.4, 1.0, 0.25));
    float3 N = normalize(in.normal);
    float3 V = normalize(frame.camera_pos - in.world_pos);
    float3 H = normalize(L + V);
    float specPow = max(dot(N, H), 0.0);
    
    // Default specular
    float shininess = 8.0;
    float specStrength = 0.05;
    float3 specColor = float3(1.0, 0.95, 0.85);
    
    // Mage staff orb
    if (mesh_frag == 1u && in.uv.x >= 25.0) {
        shininess = 64.0;
        specStrength = 0.8;
        specColor = float3(1.0, 0.7, 1.2);
    }
    
    // Frozen objects
    if (in.fx_flags & 2u) {
        shininess = 120.0;
        specStrength = 0.6;
        specColor = float3(0.85, 0.95, 1.0);
    }
    
    float3 specular = pow(specPow, shininess) * specStrength * specColor;
    
    // Cinematic rim light
    float rim = 1.0 - saturate(dot(N, V));
    rim = pow(rim, 2.5);
    
    if (mesh_frag == 1u) {
        emissive += rim * float3(0.30, 0.20, 0.50) * 0.4;  // soft purple magic rim
    } else if (mesh_frag == 3u) {
        emissive += rim * float3(0.40, 0.50, 0.55) * 0.3;  // cool stone rim
    }

    // Forest: cool green canopy ambient + warm dappled sun + subtle green backlit
    float3 ambient = albedo * float3(0.10, 0.22, 0.11);
    float3 diffuse = albedo * float3(1.5, 1.35, 0.90) * max(dot(N, L), 0.0);
    float3 rimback = albedo * float3(0.02, 0.18, 0.06) * max(dot(N, -L), 0.0);

    return float4(ambient + diffuse + rimback + emissive + specular, 1.0);
}

fragment GBuffer frag_world(VertOut in [[stage_in]]) {
    GBuffer gb;

    float3 albedo = in.color.rgb;
    float roughness = 0.6;
    float metallic  = 0.0;

    // FX: burning — add fiery emissive pulse
    float3 emissive = float3(0);
    if (in.fx_flags & 1u) { // BURNING
        float pulse = 0.5 + 0.5 * sin(in.world_pos.y * 4.0);
        emissive += float3(2.0, 0.4, 0.0) * pulse;
        albedo   *= float3(0.4, 0.1, 0.0);
    }
    // FX: frozen — blue-white tint
    if (in.fx_flags & 2u) { // FROZEN
        albedo   = mix(albedo, float3(0.6, 0.8, 1.0), 0.7);
        roughness = 0.05;
        metallic  = 0.8;
    }
    // FX: low HP — red aura pulse
    if (in.fx_flags & 16u) { // LOW_HP_AURA
        float pulse = 0.5 + 0.5 * sin(in.world_pos.y * 8.0);
        emissive += float3(1.2, 0.0, 0.0) * pulse * 0.4;
    }

    gb.albedo   = float4(albedo, roughness);
    gb.normal   = float4(in.normal * 0.5 + 0.5, metallic);
    gb.emissive = float4(emissive, 1.0);
    return gb;
}
