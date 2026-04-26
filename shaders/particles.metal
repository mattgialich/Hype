// particles.metal
// Compute shader: simulate particles on GPU.
// Vertex+Fragment: billboard them toward camera (additive blend for glow).

#include <metal_stdlib>
using namespace metal;

// packed_ types give 4-byte alignment, matching Zig extern struct / C layout.

// Must match particles.zig GpuEmitter (104 bytes)
struct Emitter {
    packed_float3 pos;          // offset  0
    float         emit_rate;    // offset 12
    packed_float3 vel_min;      // offset 16
    packed_float3 vel_max;      // offset 28
    packed_float4 color_start;  // offset 40
    packed_float4 color_end;    // offset 56
    float         size_start;   // offset 72
    float         size_end;     // offset 76
    float         lifetime;     // offset 80
    uint          active;       // offset 84
    float         spawn_accum;  // offset 88
    packed_float3 _pad;         // offset 92
};  // 104 bytes

// Must match particles.zig GpuParticle (64 bytes)
struct Particle {
    packed_float3 pos;          // offset  0
    float         age;          // offset 12
    packed_float3 vel;          // offset 16
    float         lifetime;     // offset 28
    packed_float4 color;        // offset 32
    float         size;         // offset 48
    uint          emitter_idx;  // offset 52
    float2        _pad;         // offset 56
};  // 64 bytes

// Must match metal.zig FrameUniforms (160 bytes)
struct FrameUniforms {
    float4x4      view_proj;     // offset   0
    float4x4      view_proj_inv; // offset  64
    packed_float3 camera_pos;    // offset 128 (packed = no 16-byte padding)
    float         time;          // offset 140
    float2        resolution;    // offset 144
    float2        _pad;          // offset 152
};  // 160 bytes

// ── Compute: simulate ────────────────────────────────────────────────────────

kernel void simulate_particles(
    device Particle*        particles [[buffer(0)]],
    constant Emitter*       emitters  [[buffer(1)]],
    constant uint&          em_count  [[buffer(2)]],
    constant float&         dt        [[buffer(3)]],
    uint                    pid       [[thread_position_in_grid]]
) {
    device Particle& p = particles[pid];

    if (p.age >= p.lifetime) {
        if (em_count == 0) return;
        // Dead — attempt respawn from a random active emitter
        uint seed    = pid * 2654435761u ^ uint(p.age * 1000.0);
        uint em_idx  = seed % em_count;
        constant Emitter& em = emitters[em_idx];
        if (!em.active) return;

        float r0 = fract(float(seed ^ 0xDEADu) * 2.3283064e-10f);
        float r1 = fract(float(seed ^ 0xBEEFu) * 2.3283064e-10f);
        float r2 = fract(float(seed ^ 0xCAFEu) * 2.3283064e-10f);

        p.pos         = em.pos;
        p.vel         = mix(float3(em.vel_min), float3(em.vel_max), float3(r0, r1, r2));
        p.age         = 0.0;
        p.lifetime    = em.lifetime;
        p.color       = em.color_start;
        p.size        = em.size_start;
        p.emitter_idx = em_idx;
        return;
    }

    // Integrate: gravity + drag
    p.vel.y -= 2.8 * dt;
    p.vel   *= (1.0 - dt * 0.8);
    p.pos   += p.vel * dt;
    p.age   += dt;

    // Subtle horizontal wobble for organic drift — phase varies per particle
    float wobble = sin(p.age * 1.7 + float(p.emitter_idx) * 0.7) * 0.15;
    p.pos.x += wobble * dt;
    p.pos.z += cos(p.age * 1.3 + float(p.emitter_idx) * 1.1) * 0.12 * dt;

    float t = saturate(p.age / p.lifetime);
    constant Emitter& em = emitters[p.emitter_idx];
    p.color = mix(float4(em.color_start), float4(em.color_end), t);
    p.size  = mix(em.size_start, em.size_end, t);
}

// ── Vertex: billboard ────────────────────────────────────────────────────────

struct PVertOut {
    float4 clip_pos [[position]];
    float2 uv;
    float4 color;
    float  size;
};

vertex PVertOut vert_particle(
    uint                    vid   [[vertex_id]],
    constant Particle*      parts [[buffer(0)]],
    constant FrameUniforms& frame [[buffer(1)]]
) {
    // 6 verts per particle: two CCW triangles forming a screen-aligned quad
    //   tri0: corners 0,1,2  tri1: corners 2,1,3
    uint pid = vid / 6u;
    uint ci  = vid % 6u;
    constant Particle& p = parts[pid];

    const uint corner_map[6] = {0, 1, 2, 2, 1, 3};
    uint c = corner_map[ci];

    const float2 offsets[4] = {
        float2(-1, -1), float2( 1, -1),
        float2(-1,  1), float2( 1,  1),
    };
    const float2 uvs[4] = {
        float2(0, 0), float2(1, 0),
        float2(0, 1), float2(1, 1),
    };

    float2 off = offsets[c] * p.size * 0.5;

    // Extract camera right/up from rows 0 and 1 of the view-projection matrix.
    // Row i of VP = row i of (P*V). Since P only scales rows 0 and 1 of V,
    // normalizing recovers the exact view right and up world-space vectors.
    float3 right = normalize(float3(frame.view_proj[0][0],
                                    frame.view_proj[1][0],
                                    frame.view_proj[2][0]));
    float3 up    = normalize(float3(frame.view_proj[0][1],
                                    frame.view_proj[1][1],
                                    frame.view_proj[2][1]));

    float3 world = float3(p.pos) + right * off.x + up * off.y;

    PVertOut out;
    out.clip_pos = frame.view_proj * float4(world, 1.0);
    out.uv       = uvs[c];
    out.color    = float4(p.color);
    
    // Twinkle: low-frequency alpha pulse, phase per emitter — only meaningful for ambient (long-lived) particles
    float twinklePhase = float(p.emitter_idx) * 1.7 + p.age * 2.4;
    float twinkle      = 0.85 + 0.15 * sin(twinklePhase);
    out.color.a       *= twinkle;
    
    out.size     = p.size;
    return out;
}

fragment float4 frag_particle(PVertOut in [[stage_in]]) {
    // Soft circular particle with overbright core (beautiful with additive blend)
    float2 uv   = in.uv * 2.0 - 1.0;
    float  dist = length(uv);
    if (dist > 1.0) discard_fragment();

    float alpha = smoothstep(1.0, 0.0, dist);
    float core  = pow(alpha, 3.0) * 2.0;
    float4 color = in.color;
    color.rgb   *= (1.0 + core);
    color.a     *= alpha;
    
    // TODO: 4-point sparkle for fireflies — only emitters whose color_start.a is exactly 1.0 AND blue >= 0.1 AND red < blue
    // (a way for the host to encode "this is a magical/firefly particle" without struct changes).
    // Actually, simpler: derive from in.color directly — if the alpha after twinkle is below 0.85 and the green channel is dominant, draw cross-shaped instead of round.
    
    return color;
}
