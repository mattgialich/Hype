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
            albedo = float3(0.50, 0.07, 0.68);              // robe: torso/waist/skirt + hat brim
        } else if (in.uv.x < 4.0) {
            albedo = float3(0.22, 0.03, 0.36);              // hat cone: deep indigo
        } else if (in.uv.x < 24.0) {
            albedo = float3(0.42, 0.06, 0.60);              // arms: medium purple sleeves
        } else if (in.uv.x < 25.0) {
            albedo = float3(0.52, 0.33, 0.12);              // staff shaft: warm wood
        } else {
            albedo = float3(0.80, 0.38, 1.00);              // staff orb: bright magic crystal
            float pulse = 0.5 + 0.5 * sin(frame.time * 3.5);
            emissive += float3(0.55, 0.12, 0.90) * pulse * 1.4;
        }
        // Subtle shimmer on robe + hat parts only
        if (in.uv.x >= 1.0 && in.uv.x < 24.0) {
            float shimmer = 0.5 + 0.5 * sin(frame.time * 2.3 + in.world_pos.y * 4.0);
            emissive += albedo * float3(0.6, 0.1, 0.9) * shimmer * 0.09;
        }
    }

    // Gargoyle: stone body + dark wing membrane
    if (mesh_frag == 3u) {
        if (in.uv.x < 30.0) {
            albedo = float3(0.30, 0.28, 0.32); // stone gray body
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

    float3 L    = normalize(float3(0.4, 1.0, 0.25));
    float3 N    = normalize(in.normal);
    float  diff = max(dot(N, L), 0.0);
    float  back = max(dot(N, -L), 0.0);

    // Forest: cool green canopy ambient + warm dappled sun + subtle green backlit
    float3 ambient = albedo * float3(0.10, 0.22, 0.11);
    float3 diffuse = albedo * float3(1.5, 1.35, 0.90) * diff;
    float3 rimback = albedo * float3(0.02, 0.18, 0.06) * back;

    return float4(ambient + diffuse + rimback + emissive, 1.0);
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
