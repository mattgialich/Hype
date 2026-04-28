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
        // Staff (parts 4+): swings with the right arm. Clamp the envelope at
        // the shoulder so the staff TOP doesn't scissor in the opposite
        // direction of the base — keeps it visibly held in one piece.
        if (part >= 4) { float d = max(1.68 - pos.y, 0.0) / 0.78; pos.z -= walk * 0.20 * d; }
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

    // ── Forest floor (mesh_id 0 — only the ground draw call uses this) ────────
    // Patch-based procedural ground: moss / dirt / fallen leaves with dappled
    // sunlight, root cracks, and rare dew sparkles. Early-return its own
    // lighting so the moss-bias / specular / rim passes don't muddy it.
    if (mesh_frag == 0u) {
        float2 wxz = in.world_pos.xz;

        // Layer A: large-scale biome patches (which floor type at this spot)
        float patch = valueNoise3(float3(wxz.x * 0.05, 0.0, wxz.y * 0.05));
        // Layer B: medium-scale variation (within-biome bias)
        float bias  = valueNoise3(float3(wxz.x * 0.18, 1.0, wxz.y * 0.18));
        // Layer C: fine multi-octave grass detail
        float grass = fbm3(float3(wxz.x * 1.5, 0.0, wxz.y * 1.5));

        // Region tint — large-scale (~45m) noise that shifts the moss palette
        // by region so different parts of the forest read as different sub-biomes
        // (cool teal moss in some areas, warm yellow-green moss in others).
        float region = valueNoise3(float3(wxz.x * 0.022, 3.0, wxz.y * 0.022));

        // Floor palette: dark moss / bright moss / damp earth / fallen leaves
        float3 mossDark  = mix(float3(0.04, 0.16, 0.05),
                                float3(0.04, 0.13, 0.10),
                                region);
        float3 mossLight = mix(float3(0.10, 0.30, 0.08),
                                float3(0.07, 0.28, 0.18),
                                region);
        float3 earthDark = float3(0.12, 0.08, 0.04);
        float3 leaves    = mix(float3(0.42, 0.22, 0.06),
                                float3(0.50, 0.30, 0.08),
                                region);   // warm rust → ochre

        // Continuously blend palette using patch as the primary driver
        float3 col = mix(mossDark, mossLight, bias);
        col = mix(col, earthDark, smoothstep(0.45, 0.65, patch));
        col = mix(col, leaves,    smoothstep(0.72, 0.92, patch) * bias);

        // Apply grass detail — darken valleys, brighten bumps
        col *= 0.85 + 0.30 * grass;

        // Pebble scatter: high-freq hashed darker spots, cheap and adds tooth.
        // Skips path/paved areas via gating below (multiplied by 1 - pathBlend).
        float pebbleHash = hash21(floor(wxz * 6.0));
        float pebble     = smoothstep(0.74, 0.88, pebbleHash);
        col *= 1.0 - pebble * 0.16;

        // Rare mushroom patches — warm-reddish spots where bias is low (mossier
        // cells tend toward mushrooms), only appear in mossy/leaf zones (patch < 0.7).
        float shroomHash = hash21(floor(wxz * 1.3));
        float shroomMask = smoothstep(0.985, 0.997, shroomHash)
                         * (1.0 - smoothstep(0.55, 0.75, patch));
        float3 shroomCol = float3(0.75, 0.28, 0.22);
        col = mix(col, shroomCol, shroomMask * 0.7);

        // Root cracks: dark valleys at zero-crossings of mid-freq noise
        float crackN = abs(valueNoise3(float3(wxz.x * 0.6, 2.0, wxz.y * 0.6)) - 0.5);
        float crack  = 1.0 - smoothstep(0.0, 0.05, crackN);
        col *= 1.0 - crack * 0.45;

        // Dappled sunlight through canopy — slowly drifts with time
        float dapple = valueNoise3(float3(wxz.x * 0.3 + frame.time * 0.05, 5.0, wxz.y * 0.3));
        dapple = smoothstep(0.55, 0.78, dapple);
        col += float3(0.55, 0.45, 0.28) * dapple * 0.20;

        // Rare dew sparkles (very few, very bright — feeds bloom)
        float sparkleHash = hash21(floor(wxz * 60.0));
        float sparkleMask = smoothstep(0.992, 0.998, sparkleHash);
        float3 sparkle    = float3(0.6, 0.7, 0.9) * sparkleMask;

        // ── Winding curved path from start (0,0) to the portal at (0,-180) ──
        // Two superimposed waves (one sin, one cos at different frequencies)
        // produce a richly winding line; the bell-curve envelope pinches it
        // to x=0 at both endpoints so player and gate are always on-axis.
        float pz         = wxz.y;
        float PATH_LEN   = 220.0;
        float t_along    = saturate(-pz / PATH_LEN);                      // 0 at start, 1 at portal
        float envelope   = 4.0 * t_along * (1.0 - t_along);               // bell curve, 0 at endpoints
        float center_x   = envelope * (20.0 * sin(pz * 0.045) + 8.0 * cos(pz * 0.075));
        float across     = abs(wxz.x - center_x);

        // Width: wide at endpoints (4.7m radius), narrow in the middle (2.6m radius).
        // Each endpoint widening fades over its first/last 12m of the longer path.
        float wideStart = 1.0 - smoothstep(0.0, 12.0, t_along * PATH_LEN);
        float wideEnd   = 1.0 - smoothstep(0.0, 12.0, (1.0 - t_along) * PATH_LEN);
        float pathRadius = mix(2.6, 4.7, max(wideStart, wideEnd));
        // Organic edge wobble — slightly bigger amplitude on the longer path
        pathRadius += (valueNoise3(float3(wxz.x * 0.55, 8.0, wxz.y * 0.55)) - 0.5) * 1.1;

        // Active path range — explicitly fade out beyond the endpoints in world Z
        // (4m soft edges beyond z=0 and z=-PATH_LEN). Without this the path
        // extends infinitely behind the player and beyond the portal.
        float inSegment = saturate((-pz + 2.0) * 0.5) * saturate((pz + PATH_LEN + 2.0) * 0.5);
        float pathBlend = (1.0 - smoothstep(pathRadius, pathRadius + 0.8, across)) * inSegment;

        // CLEARING ZONE around the path — biases toward moss/leaves (no dark earth)
        // and adds a faint warm ambient glow that suggests a sunlit cleared trail.
        float clearingRadius = pathRadius + 8.0;
        float clearingBlend  = (1.0 - smoothstep(clearingRadius - 4.0, clearingRadius, across)) * inSegment;
        float3 clearingCol   = mix(mossLight, leaves, smoothstep(0.55, 0.85, patch) * bias);
        clearingCol         *= 0.90 + 0.25 * grass;
        col = mix(col, clearingCol, clearingBlend * 0.75);
        col += float3(0.09, 0.06, 0.03) * clearingBlend * 0.45;

        // PATH DIRT — warm trodden brown with dark centerline rut, picks up grass detail.
        // Cool earth tone at the start; warms toward rust as it approaches the portal.
        float3 dirtCool   = float3(0.28, 0.20, 0.10);    // damp cool earth (start)
        float3 dirtWarm   = float3(0.38, 0.20, 0.06);    // warm rust (near gate)
        float3 pathDirt   = mix(dirtCool, dirtWarm, smoothstep(0.40, 0.95, t_along));
        float  centerWear = 1.0 - smoothstep(0.0, 0.9, across);            // 1 at center, 0 past 0.9m
        pathDirt         *= 1.0 - centerWear * 0.30;                       // darker rut down the middle
        pathDirt         *= 0.85 + 0.30 * grass;
        // Path-edge stones: darker speckle right at the path edge (suggesting
        // bordering rocks worn smooth by passers-by). Band peaks ~0.6m from edge.
        float edgeBand    = smoothstep(pathRadius - 1.2, pathRadius - 0.6, across)
                          * (1.0 - smoothstep(pathRadius - 0.3, pathRadius, across));
        float edgeStoneH  = hash21(floor(wxz * 3.0));
        float edgeStone   = smoothstep(0.55, 0.78, edgeStoneH) * edgeBand;
        pathDirt          *= 1.0 - edgeStone * 0.30;

        // PAVED COBBLESTONE near the portal (last 12m of the path)
        float pavingMask = smoothstep(0.93, 1.0, t_along);                // 0..1 over the last ~12m
        float2 slabCoord = floor(wxz * 2.0);                              // 0.5m grid
        float  slabHash  = hash21(slabCoord);
        float3 slabBase  = float3(0.30, 0.31, 0.34);
        slabBase        *= 0.85 + 0.30 * slabHash;                        // per-slab tone variation
        // Subtle dark grout between slabs
        float2 slabFrac  = fract(wxz * 2.0);
        float  grout     = step(slabFrac.x, 0.06) + step(0.94, slabFrac.x)
                         + step(slabFrac.y, 0.06) + step(0.94, slabFrac.y);
        slabBase        *= 1.0 - saturate(grout) * 0.35;

        float3 surface = mix(pathDirt, slabBase, pavingMask);
        col = mix(col, surface, pathBlend);

        // Forest lighting (matches what other meshes use at the bottom of the function)
        float3 L = normalize(float3(0.4, 1.0, 0.25));
        float3 N = normalize(in.normal);
        float  diff = max(dot(N, L), 0.0);
        float  back = max(dot(N, -L), 0.0);
        float3 ambient = col * float3(0.10, 0.22, 0.11);
        float3 diffuse = col * float3(1.5, 1.35, 0.90) * diff;
        float3 rimback = col * float3(0.02, 0.18, 0.06) * back;
        return float4(ambient + diffuse + rimback + sparkle, 1.0);
    }

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
        // Fast flicker for crackling effect
        float fastFlicker = sin(frame.time * 60.0 + in.world_pos.y * 10.0);
        float slowFlicker = sin(frame.time * 12.0);
        float flicker = saturate(fastFlicker * slowFlicker * 0.5 + 0.5);
        // Clamp minimum flicker to 0.55 to ensure bolt is always visible
        flicker = max(flicker, 0.55);
        
        // Vertical banding for noisy detail
        float banding = sin(in.world_pos.y * 20.0) * 0.2 + 0.8;
        
        // Core: white hot center with subtle magenta tint under peak flicker
        float coreMask = smoothstep(0.35, 0.15, abs(in.uv.x - 0.5));
        float flickerPeak = step(0.85, flicker);
        float3 core = float3(6.0, 6.0, 6.0) * coreMask;
        core = core - float3(0.0, 0.6, 0.0) * flickerPeak;  // magenta tint during peak
        
        // Edge: blue plasma
        float edgeMask = smoothstep(0.20, 0.50, abs(in.uv.x - 0.5));
        float3 edge = float3(0.25, 0.45, 1.00) * (1.0 - edgeMask) * 2.8;
        
        // Sparkle effect on edges
        float sparkHash = hash21(float2(in.world_pos.y * 10.0, frame.time * 5.0));
        float spark = step(0.96, sparkHash) * 0.8;
        float3 sparkCol = float3(0.5, 1.0, 1.0) * spark * 6.0;  // stronger flashes
        
        // Vertical discharge pulse
        float dischargePos = fract(frame.time * 1.8);
        float dischargeMask = smoothstep(0.04, 0.0, abs(in.uv.y - dischargePos));
        float3 discharge = float3(2.0, 2.0, 2.0) * dischargeMask;
        
        // Combine all elements
        float3 color = core + edge + sparkCol + discharge;

        // Base flare boost: the bottom portion (uv.y near 0) is the strike point.
        // Multiply brightness sharply there so the impact reads as the loudest
        // moment of the bolt. Falls off above uv.y ~0.25.
        float baseBoost = 1.0 + 3.5 * smoothstep(0.30, 0.0, in.uv.y);
        return float4(color * flicker * banding * baseBoost, 1.0);
    }

    // Lightning impact ring: annulus + low dome at strike point
    if (mesh_frag == 28u) {
        if (in.uv.x < 1.5) {
            // Annulus ring: dynamic shockwave with energy spikes
            float brightness = 1.0 - in.uv.x;
            
            // Inner bright ring
            if (in.uv.x < 0.15) {
                brightness = 1.0;
                float3 inner = float3(7.0, 7.0, 9.0);
                return float4(inner * brightness, 1.0);
            }
            
            // Hash-driven energy spikes
            float spikeHash = hash21(float2(in.uv.y * 10.0, frame.time * 15.0));
            float spike = step(0.95, spikeHash);
            brightness *= 1.0 + spike * 2.0;
            
            // Fast crackling radial pattern
            float crackle = step(0.7, sin(in.uv.y * 60.0 + frame.time * 50.0));
            brightness *= 1.0 + crackle * 1.5;
            
            // Outer glow falloff
            if (in.uv.x > 0.85) {
                float3 outer = float3(0.5, 1.5, 2.0);
                float falloff = smoothstep(0.85, 1.0, in.uv.x);
                float3 base = float3(2.0, 3.0, 4.5) * brightness;
                return float4(mix(base, outer, falloff), 1.0);
            }
            
            float3 color = float3(2.0, 3.0, 4.5) * brightness;
            return float4(color, 1.0);
        } else {
            // Dome: white-hot core with blue base tint
            float3 color = float3(8.0, 8.0, 10.0);
            // Blue tint near base
            if (in.uv.y < 0.3) {
                float blueTint = smoothstep(0.0, 0.3, in.uv.y);
                color = mix(color, float3(1.0, 1.5, 3.0), blueTint * 0.5);
            }
            float falloff = 0.5 + 0.5 * in.uv.y;
            return float4(color * falloff, 1.0);
        }
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

    // Zone-transition portal: enchanted stone arch + animated swirl disc + light beacon
    if (mesh_frag == 13u) {
        if (in.uv.x >= 80.0) {
            // FINIAL LANTERN — warm orange-amber emissive sphere on top of pillars,
            // with a subtle two-frequency flicker. Early-return.
            float flicker = 0.85 + 0.15 * sin(frame.time * 3.0 + in.object_pos.y * 5.0)
                                 + 0.10 * sin(frame.time * 7.5);
            float3 core   = float3(1.6, 0.85, 0.30);    // warm amber
            return float4(core * flicker * 1.4, 1.0);
        }
        if (in.uv.x >= 70.0) {
            // BEACON — tall thin emissive light pillar, visible from anywhere on the map.
            // Vertical falloff: brightest at the base (where the swirl is), dimmer up high.
            float t = saturate((in.object_pos.y - 4.0) / 14.0);     // 0 at beacon base, 1 at top
            float fade = 1.0 - t * 0.6;                              // never fully fades — still visible against sky
            float pulse = 0.85 + 0.15 * sin(frame.time * 1.4);
            return float4(float3(0.6, 1.4, 2.4) * fade * pulse * 1.6, 1.0);
        }
        if (in.uv.x >= 60.0) {
            // Multi-layer animated portal swirl. Opaque (no discard) — outside
            // the active swirl radius the disc renders as deep void so geometry
            // behind the gate is fully occluded.
            // ~20 design passes condensed:
            //  1 polar coord setup
            //  2 OPAQUE dark frame outside r=1.45
            //  3 fast 3-arm spiral
            //  4 counter-rotating 2-arm slow gate
            //  5 stationary 8-pointed star burst
            //  6 outward expanding ring pulse #1
            //  7 second offset-phase ring pulse #2
            //  8 inner glowing core hotspot
            //  9 center dark void eye
            // 10 hash-driven sparkle dots
            // 11 distortion-offset warble (uv warping)
            // 12 secondary fine spiral overlay
            // 13 slow color cycle (blue ↔ magenta ↔ cyan)
            // 14 hue shift per angular position
            // 15 vertical "tear" subtle gradient
            // 16 outward radial spokes
            // 17 strong base glow fill
            // 18 brightness pulse global
            // 19 anti-aliased rim fade
            // 20 final HDR composition for bloom feed
            float2 c = in.object_pos.xy - float2(0.0, 1.85);
            float r = length(c);
            float a = atan2(c.y, c.x);

            // 2 — OUTER FRAME: opaque deep void with subtle radial gradient
            if (r > 1.45) {
                float frameG = smoothstep(2.4, 1.45, r);
                float3 frame = float3(0.05, 0.03, 0.12) * frameG + float3(0.02, 0.01, 0.06);
                // Very faint inner-edge glow leaking past the swirl into the frame
                frame += float3(0.10, 0.18, 0.45) * smoothstep(1.45, 1.45 + 0.04, r) * 0.2;
                return float4(frame, 1.0);
            }

            // 11 — distortion: offset polar coords slightly so spirals shimmer
            float warp = sin(r * 8.0 + frame.time * 1.3) * 0.04;
            float aw   = a + warp;

            // 3 — fast 3-arm spiral
            float spiral1 = sin(aw * 3.0 + frame.time * 2.5 - r * 5.5);
            float energy  = 0.5 + 0.5 * spiral1;
            // 4 — counter-rotating 2-arm slow gate
            float spiral2 = sin(aw * 2.0 - frame.time * 1.2 + r * 4.0);
            float gate    = 0.5 + 0.5 * spiral2;
            // 12 — fine secondary spiral overlay
            float spiral3 = sin(aw * 7.0 + frame.time * 3.5 - r * 9.0);
            float fine    = 0.5 + 0.5 * spiral3;
            // 5 — 8-pointed star burst (stationary)
            float star    = pow(abs(cos(a * 4.0)), 6.0);
            // 16 — radial spokes (subtle)
            float spokes  = pow(abs(sin(a * 6.0)), 12.0) * 0.6;
            // 6 — outward expanding ring #1
            float pR1   = fract(frame.time * 0.40);
            float ring1 = exp(-pow((r / 1.35 - pR1) * 7.0, 2.0)) * 0.7;
            // 7 — outward expanding ring #2 (offset phase)
            float pR2   = fract(frame.time * 0.30 + 0.5);
            float ring2 = exp(-pow((r / 1.35 - pR2) * 8.0, 2.0)) * 0.5;
            // 8 — inner core hotspot
            float core  = exp(-pow(r * 3.5, 2.0));
            // 9 — center dark void eye (small)
            float voidE = exp(-pow(r * 14.0, 2.0));
            // 10 — sparkle dots (hashed, drift slowly)
            float2 sparkleCell = floor(in.object_pos.xy * 8.0 + frame.time * 0.4);
            float sparkH = hash21(sparkleCell);
            float sparkM = smoothstep(0.965, 0.99, sparkH);
            // 18 — global brightness pulse
            float gPulse = 0.85 + 0.15 * sin(frame.time * 0.9);

            // 13/14 — color cycle (slow) + per-angle hue shift
            float hueT = 0.5 + 0.5 * sin(frame.time * 0.55 + a * 0.5);
            float3 colA = float3(0.30, 0.70, 1.50);   // deep sky-blue
            float3 colB = float3(1.10, 0.30, 1.50);   // electric magenta
            float3 colC = float3(0.45, 0.95, 1.10);   // cyan highlight
            float3 portal = mix(mix(colA, colB, hueT), colC, gate * 0.4);

            // 15 — vertical tear: brighten slightly along the central vertical line
            float tear = exp(-pow(c.x * 5.0, 2.0)) * 0.20;

            // 19 — anti-aliased rim fade
            float fade = 1.0 - smoothstep(1.05, 1.45, r);

            // Combine intensity (3+4+12 layers + core + spokes), with void carving the center
            float intensity = mix(energy, energy * gate, 0.5) * 1.10;
            intensity = mix(intensity, intensity * (0.6 + 0.4 * fine), 0.45);
            intensity += core * 0.45 + spokes * 0.25;
            intensity *= (1.0 - voidE * 0.55);
            intensity *= gPulse;

            // 17 — strong base glow that keeps even the dim cells luminous
            float3 baseGlow = float3(0.20, 0.45, 0.95) * fade;
            // Star burst contribution (warmer)
            float3 starCol  = float3(1.30, 1.10, 1.55) * star * 0.45 * fade;
            // Sparkle highlights (white-violet)
            float3 spark    = float3(1.50, 1.55, 1.75) * sparkM * fade;
            // Tear highlight (warm-cyan vertical line)
            float3 tearCol  = float3(0.90, 1.40, 1.60) * tear * fade;

            // 20 — final HDR composition (deliberately overbright so bloom catches it)
            float3 final = portal * intensity * 2.8 * fade
                         + baseGlow
                         + starCol
                         + spark
                         + tearCol
                         + float3(1.40, 1.60, 2.00) * ring1 * fade
                         + float3(0.85, 1.45, 1.90) * ring2 * fade
                         + float3(0.18, 0.06, 0.40) * voidE * 1.4;
            return float4(final, 1.0);
        }
        // Stone columns of the arch — cooler enchanted-stone tint
        float fbm = fbm3(in.world_pos * 1.2);
        float noise = valueNoise3(in.world_pos * 9.0);
        float brightness = 0.85 + 0.30 * fbm;
        albedo = float3(0.30, 0.34, 0.40) * brightness;
        albedo *= (0.95 + 0.10 * noise);
        // Subtle blue tint suggesting enchanted stone
        albedo = mix(albedo, albedo * float3(0.85, 0.95, 1.20), 0.35);
        // Soft magic emissive on the inner-facing surfaces (low-freq glow tied to portal proximity)
        emissive += float3(0.08, 0.18, 0.30) * 0.4;
    }

    // Monolith: ancient weathered stone, used as the perimeter ring
    if (mesh_frag == 14u) {
        float fbm = fbm3(in.world_pos * 1.1);
        float noise = valueNoise3(in.world_pos * 8.0);
        float brightness = 0.75 + 0.30 * fbm;
        albedo = in.color.rgb * brightness;
        albedo *= (0.92 + 0.12 * noise);
        // Heavier moss — these stones have stood for ages
        float mossBias = smoothstep(0.45, 0.18, fbm);
        albedo = mix(albedo, float3(0.18, 0.30, 0.16), mossBias * 0.8);
    }

    // ═══ NEW ASSETS (mesh_id 15..24) ═══════════════════════════════════════════

    // Stone Circle — same ancient-stone treatment as monolith
    if (mesh_frag == 15u) {
        float fbm15 = fbm3(in.world_pos * 1.2);
        float n15   = valueNoise3(in.world_pos * 9.0);
        albedo = in.color.rgb * (0.78 + 0.30 * fbm15);
        albedo *= (0.92 + 0.12 * n15);
        float moss15 = smoothstep(0.42, 0.15, fbm15);
        albedo = mix(albedo, float3(0.18, 0.32, 0.16), moss15 * 0.85);
    }

    // (mesh_id 16 — Fallen Log — uBase=10 falls through to the tree-bark branch above)

    // Tree Stump — bark via uBase=10/11 above; small mushroom stalk at uBase=8 here.
    if (mesh_frag == 17u && in.uv.x >= 8.0 && in.uv.x < 9.0) {
        // tiny toadstool mushroom on the stump
        albedo = float3(0.78, 0.30, 0.22);
        emissive += float3(0.55, 0.10, 0.05) * 0.4;
    }

    // Crystal Cluster — full mesh is emissive crystal, early-return.
    if (mesh_frag == 18u) {
        // Hash cluster placement for hue variation (quantized to avoid vertex discontinuity)
        float2 clusterPos = floor(in.world_pos.xz * 0.5);
        float clusterHash = hash21(clusterPos);
        float hueIndex = floor(clusterHash * 6.0);
        
        // Select hue family (violet, cyan, magenta, mint, amber, rose)
        float3 col;
        if (hueIndex < 1.0) col = float3(0.45, 0.25, 1.40);   // deep violet
        else if (hueIndex < 2.0) col = float3(0.30, 0.70, 1.30);   // cyan
        else if (hueIndex < 3.0) col = float3(1.30, 0.30, 1.50);   // magenta
        else if (hueIndex < 4.0) col = float3(0.30, 1.00, 0.80);   // mint
        else if (hueIndex < 5.0) col = float3(1.20, 0.70, 0.20);   // amber
        else col = float3(1.40, 0.40, 0.60);   // rose
        
        // Add intra-cluster variation
        float intraHash = hash21(in.object_pos.xz);
        col *= 0.9 + 0.2 * intraHash;
        
        // Faceted shading with 3-tone faceting
        float3 lightDir = normalize(float3(0.4, 1.0, 0.25));
        float3 viewDir = normalize(float3(0.0, 0.4, 1.0));
        float3 N = normalize(in.normal);
        
        // 3-tone faceted lighting: shadow / mid / highlight
        float lightDot = dot(N, lightDir);
        float facet = 0.45 + 0.30 * step(0.0, lightDot) + 0.30 * step(0.55, lightDot);
        col *= facet;
        
        // Rim highlight
        float rim = 1.0 - saturate(dot(N, viewDir));
        rim = pow(rim, 3.0);
        col += float3(0.8, 1.0, 1.2) * rim * 0.8;
        
        // Inner-core glow (when normal points upward)
        float upness = dot(N, float3(0, 1, 0));
        col += float3(0.3, 0.4, 0.5) * upness * 0.3;
        
        // Pulse with cluster-specific phase offset
        float pulse = 0.65 + 0.35 * sin(frame.time * 1.6 + clusterHash * 6.28);
        
        // Tiny sparkle effect
        float sparkleHash = hash21(in.object_pos.xz + float2(frame.time * 0.3, 0.0));
        float sparkle = step(0.95, sparkleHash);
        col += float3(1.5, 1.5, 1.5) * sparkle * 0.8;
        
        // Final emissive color (keep base color stable, add pulsing shimmer)
        return float4(col * pulse * 2.0, 1.0);
    }

    // Bonfire — flame emissive (uBase=50), logs use bark above, stones use default
    if (mesh_frag == 19u && in.uv.x >= 50.0) {
        float flicker = 0.5 + 0.5 * sin(frame.time * 18.0 + in.world_pos.y * 7.0)
                          + 0.25 * sin(frame.time * 33.0 + in.world_pos.x * 9.0);
        float vBlend = saturate((in.object_pos.y - 0.4) / 1.05);
        float3 core  = mix(float3(1.0, 0.55, 0.10), float3(1.0, 0.95, 0.50), 1.0 - vBlend);
        float3 glow  = float3(2.4, 1.05, 0.30) * flicker;
        return float4(core + glow * (1.0 - vBlend) * 1.6, 1.0);
    }

    // Dead Tree — pale gray-brown bare wood with high-freq grain
    if (mesh_frag == 20u) {
        float grain = valueNoise3(in.world_pos * float3(28.0, 4.0, 28.0));
        albedo = float3(0.30, 0.24, 0.18) * mix(0.80, 1.10, grain);
    }

    // Giant Mushroom — cream stem; cap (uBase=8) glows soft purple-magenta
    if (mesh_frag == 21u) {
        if (in.uv.x >= 8.0 && in.uv.x < 9.0) {
            // Cap — gradient toward the top, soft inner glow
            float capT  = saturate((in.object_pos.y - 0.95) / 0.55);
            float3 capA = float3(0.55, 0.10, 0.22);   // deep magenta base
            float3 capB = float3(1.10, 0.35, 0.55);   // bright pink top
            float3 capC = mix(capA, capB, capT);
            albedo   = capC * 0.6;
            emissive += capC * 0.45;
        } else {
            // Stem — cream off-white
            albedo = float3(0.82, 0.74, 0.60);
        }
    }

    // Banner Pole — pole/crossbar use bark (uBase=10) above; cloth (uBase=25) here.
    if (mesh_frag == 22u && in.uv.x >= 25.0 && in.uv.x < 26.0) {
        // Cloth uses team color for variety; subtle wave pattern in object Y
        float wave = sin(in.object_pos.y * 6.0 + frame.time * 0.6) * 0.06;
        albedo = in.color.rgb * (1.10 + wave);
        // Soft warm glow on banners (firelight catching them)
        emissive += in.color.rgb * 0.10;
    }

    // Berry Bush — foliage default; berries (uBase=8) glow.
    if (mesh_frag == 23u) {
        if (in.uv.x >= 8.0 && in.uv.x < 9.0) {
            albedo = float3(0.80, 0.10, 0.10);
            emissive += float3(0.85, 0.10, 0.05) * 0.45;
        } else {
            // Forest-green foliage with grass-noise variation
            float n = valueNoise3(in.object_pos * 6.0);
            albedo = float3(0.10, 0.24, 0.07) * (0.85 + 0.30 * n);
        }
    }

    // Shrine — wood beams via bark above; offering plate (uBase=0) keeps team color;
    // glowing offering at uBase=8 here.
    if (mesh_frag == 24u && in.uv.x >= 8.0 && in.uv.x < 9.0) {
        float pulse = 0.7 + 0.3 * sin(frame.time * 1.8);
        albedo = float3(0.85, 0.75, 0.50);
        emissive += float3(1.40, 1.10, 0.55) * pulse * 0.9;
    }

    // ═══ 3 NEW ENEMIES (mesh_id 25..27) ════════════════════════════════════════

    // Forest Wisp — full mesh is emissive ethereal cyan-purple, early-return.
    // uBase=0 → softer outer parts; uBase=1 → bright inner core/crown/belt;
    // uBase=2 → orbiting shards with hash-driven phase shift.
    if (mesh_frag == 25u) {
        float verticalGlow = saturate((in.object_pos.y - 0.10) / 0.85);
        float pulse = 0.65 + 0.35 * sin(frame.time * 2.4 + in.object_pos.y * 5.0);
        // Color cycle: cyan → violet over a slow period
        float hue = 0.5 + 0.5 * sin(frame.time * 0.7);
        float3 colA = float3(0.30, 0.85, 1.50);   // cyan
        float3 colB = float3(0.85, 0.40, 1.50);   // violet
        float3 base = mix(colA, colB, hue);
        // Brightness varies by uBase
        float brightness = 1.6;
        if (in.uv.x >= 0.95 && in.uv.x < 1.95) brightness = 2.6;     // core/crown/belt
        else if (in.uv.x >= 1.95 && in.uv.x < 2.95) {                // orbiting shards
            float shardPhase = sin(frame.time * 3.0 + in.object_pos.x * 7.0 + in.object_pos.z * 7.0);
            brightness = 2.0 + 0.8 * shardPhase;
        }
        float3 final = base * pulse * brightness * (0.6 + 0.4 * verticalGlow)
                     + float3(0.10, 0.20, 0.55);
        return float4(final, 1.0);
    }

    // Tree Ent — bark via existing branch (uBase=10/14); foliage uBase=20-21
    // gets dense forest green; eye sockets uBase=8 glow amber.
    if (mesh_frag == 26u) {
        if (in.uv.x >= 8.0 && in.uv.x < 9.0) {
            float pulse = 0.75 + 0.25 * sin(frame.time * 1.4);
            albedo = float3(0.20, 0.10, 0.0);
            emissive += float3(2.4, 1.30, 0.30) * pulse;
        } else if (in.uv.x >= 20.0 && in.uv.x < 22.0) {
            // Foliage / mossy growth (uBase=20 outer cluster, uBase=21 inner)
            float n = valueNoise3(in.object_pos * 5.0);
            float3 deep   = float3(0.04, 0.16, 0.05);
            float3 fresh  = float3(0.10, 0.30, 0.09);
            albedo = mix(deep, fresh, n);
            // Slight darker tint on the secondary cluster (uBase=21)
            if (in.uv.x >= 21.0) albedo *= 0.85;
        }
        // else falls to existing bark branch (uBase=10/14 handled above)
    }

    // Skeleton Knight — bone uBase=0, eye sockets uBase=8 (red glow),
    // steel uBase=20, shield boss uBase=21 (faint rune emissive).
    if (mesh_frag == 27u) {
        if (in.uv.x >= 8.0 && in.uv.x < 9.0) {
            // Eye sockets — pulsing crimson
            float pulse = 0.7 + 0.3 * sin(frame.time * 4.5);
            albedo = float3(0.05, 0.0, 0.0);
            emissive += float3(2.4, 0.35, 0.18) * pulse;
        } else if (in.uv.x >= 20.0 && in.uv.x < 21.0) {
            // Steel: sword, shield, pauldrons — cool gray with subtle high-freq noise
            float n = valueNoise3(in.object_pos * 12.0);
            albedo = float3(0.55, 0.58, 0.62) * (0.92 + 0.10 * n);
        } else if (in.uv.x >= 21.0 && in.uv.x < 22.0) {
            // Shield boss — faint warm-amber rune emissive
            float pulse = 0.7 + 0.3 * sin(frame.time * 1.2);
            albedo = float3(0.40, 0.36, 0.30);
            emissive += float3(1.10, 0.85, 0.30) * pulse * 0.4;
        } else {
            // Bones — cream off-white with subtle yellowing per noise cell
            float n = valueNoise3(in.object_pos * 7.0);
            albedo = float3(0.85, 0.82, 0.72) * (0.93 + 0.10 * n);
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

    float3 final = ambient + diffuse + rimback + emissive + specular;

    // Hit-flash: bits 8-15 of fx_flags pack a u8 (0..255) intensity. Mix the
    // final color toward bright red while the flash is active. Decays in Zig.
    float hit = float((in.fx_flags >> 8u) & 0xFFu) / 255.0;
    final = mix(final, float3(2.0, 0.30, 0.20), hit * 0.85);

    return float4(final, 1.0);
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
