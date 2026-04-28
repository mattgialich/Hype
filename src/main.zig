// Game entry point — all exported symbols are called by Swift MTKView delegate.
// Swift owns the Metal device, command queue, and render pass descriptor.
// Zig owns all game state, camera, and produces DrawCall lists each frame.

const std          = @import("std");
const Vec3         = @import("math/vec.zig").Vec3;
const World        = @import("game/entity.zig").World;
const Player       = @import("game/player.zig").Player;
const renderer_mod_main = @import("renderer/metal.zig");
const Renderer     = @import("renderer/metal.zig").Renderer;
const Particles    = @import("renderer/particles.zig");
const FX           = @import("game/entity.zig").FX;
const enemy_ai_mod = @import("game/enemy_ai.zig");
const EnemyAI      = enemy_ai_mod.EnemyAI;
const enemy_config = @import("game/enemy_config.zig");
const SkillBonuses = @import("game/skill_bonuses.zig").SkillBonuses;

// ── Global game state (static, no allocator needed for core loop) ────────────

var world:      World           = .{};
var player:     Player          = undefined;
var renderer:   Renderer        = .{};
var psys:       Particles.ParticleSystem = .{};
var enemy_ai:   EnemyAI         = .{};
var time:       f32  = 0;
var walk_phase: f32  = 0;
var inited:     bool = false;

// ── Zone selector ────────────────────────────────────────────────────────────
// The active gameplay zone. Swift calls `game_set_zone(N)` from PortalMapView
// before re-initialising. The boundary-clamp logic in `game_update` dispatches
// on this. Spawning is still forest-only until per-zone spawn_*_world functions
// land; switching zones today just changes the player-clamp behaviour.
pub const Zone = enum(u32) { forest = 0, desert = 1, isles = 2 };
var current_zone: Zone = .forest;

export fn game_set_zone(zone_id: u32) void {
    if (zone_id > 2 or !inited) return;
    const new_zone: Zone = @enumFromInt(zone_id);
    current_zone = new_zone;

    // Tear down the old zone's entities + emitters, then re-spawn from scratch.
    despawn_world();

    // Drop the player in the zone's start spot (origin on land for forest /
    // desert; centre of Lantern Hold for the isles since the rest is water).
    const start_pos: Vec3 = switch (new_zone) {
        .forest => Vec3.zero,
        .desert => Vec3.zero,
        .isles  => Vec3{ .x = isles_islands[0].cx, .y = isles_islands[0].y_deck, .z = isles_islands[0].cz },
    };
    world.pos[player.entity] = start_pos;
    world.vel[player.entity] = Vec3.zero;
    // Heal-on-travel — nicer feel than carrying low HP into a fresh zone.
    world.hp[player.entity]  = world.hp_max[player.entity];

    switch (new_zone) {
        .forest => spawn_world_forest(),
        .desert => spawn_world_desert(),
        .isles  => spawn_world_isles(),
    }
}

// ── Simple xorshift32 PRNG — seeded at compile time, deterministic but random-looking ──
var _rng: u32 = 0xA3B7C1D9;
fn rng_u32() u32 { _rng ^= _rng << 13; _rng ^= _rng >> 17; _rng ^= _rng << 5; return _rng; }
fn rng_f32() f32 { return @as(f32, @floatFromInt(rng_u32() & 0xFFFF)) / 65535.0; }
fn rng_range(lo: f32, hi: f32) f32 { return lo + rng_f32() * (hi - lo); }
// Area-uniform radius in annulus: sample r² uniformly so outer ring isn't under-populated
fn rng_radius(r_min: f32, r_max: f32) f32 {
    return std.math.sqrt(rng_range(r_min * r_min, r_max * r_max));
}

// ── Path geometry — MUST match the curve formula in shaders/world.metal ──────
// Path runs from origin (0, 0, 0) to portal at (0, 0, -PATH_LEN). Two large
// superimposed waves (one sin, one cos at different freqs) make a richly
// winding centerline; the bell-curve envelope pinches it to x=0 at both
// endpoints so the player and the gate are always perfectly on-axis.
const PATH_LEN: f32 = 220.0;

fn path_center_x(z: f32) f32 {
    const t = std.math.clamp(-z / PATH_LEN, 0.0, 1.0);
    const env = 4.0 * t * (1.0 - t);
    return env * (20.0 * std.math.sin(z * 0.045) + 8.0 * std.math.cos(z * 0.075));
}

fn dist_to_path(x: f32, z: f32) f32 {
    if (z > 4.0 or z < -(PATH_LEN + 4.0)) return 9999.0;
    return @abs(x - path_center_x(z));
}

// ── Drifting Isles geometry ──────────────────────────────────────────────────
// Six islands plus walkable bridges between them. The water-clamp logic snaps
// the player back to last frame's position whenever they leave land, so the
// player can only traverse the archipelago via bridges and rune-gates.
// Numerical layout matches docs/drifting_isles.md §2b.

const Island = struct {
    cx: f32,
    cz: f32,
    radius: f32,
    y_deck: f32, // walkable deck height (0 for ground islands, 60 for Skywatch)
};

const isles_islands = [_]Island{
    .{ .cx =    0.0, .cz =    0.0, .radius = 200.0, .y_deck =  0.0 }, // A Lantern Hold
    .{ .cx =  200.0, .cz = -180.0, .radius = 180.0, .y_deck =  0.0 }, // B Whale's Spine
    .{ .cx = -220.0, .cz = -260.0, .radius = 170.0, .y_deck =  0.0 }, // C Glasstop
    .{ .cx =   60.0, .cz = -440.0, .radius = 220.0, .y_deck =  0.0 }, // D The Wreck
    .{ .cx = -120.0, .cz = -560.0, .radius = 140.0, .y_deck = 60.0 }, // E Skywatch (sky)
    .{ .cx =   40.0, .cz = -720.0, .radius = 200.0, .y_deck =  0.0 }, // F Far Reach
};

// Walkable bridges as line-segment corridors with a perpendicular tolerance.
// `a_y` and `b_y` are the deck heights at each endpoint — the sky-bridge from
// Skywatch (y=60) to Far Reach (y=0) interpolates linearly between them so
// the player walks down a smooth slope.
const Bridge = struct {
    ax: f32, az: f32,
    bx: f32, bz: f32,
    half_width: f32,
    a_y: f32, b_y: f32,
};

const isles_bridges = [_]Bridge{
    // A↔B (driftwood — Lantern Hold east shore to Whale's Spine north shore)
    .{ .ax = 200.0, .az =  -10.0, .bx =  30.0, .bz = -160.0, .half_width = 3.0, .a_y =  0.0, .b_y =  0.0 },
    // B↔D (rope bridge — Whale's Spine south shore to Wreck north shore)
    .{ .ax = 220.0, .az = -340.0, .bx =  80.0, .bz = -380.0, .half_width = 3.0, .a_y =  0.0, .b_y =  0.0 },
    // E↔F (long sky bridge — Skywatch south plaza dropping to Far Reach north shore)
    .{ .ax = -100.0, .az = -580.0, .bx =  40.0, .bz = -700.0, .half_width = 3.5, .a_y = 60.0, .b_y =  0.0 },
};

// Squared distance from a point to a 2D line segment, plus the projection
// parameter t in [0, 1] for slope interpolation along the bridge.
fn segment_dist_sq_t(px: f32, pz: f32, ax: f32, az: f32, bx: f32, bz: f32) struct { d2: f32, t: f32 } {
    const dx = bx - ax;
    const dz = bz - az;
    const len_sq = dx * dx + dz * dz;
    if (len_sq < 0.0001) {
        const ex = px - ax;
        const ez = pz - az;
        return .{ .d2 = ex * ex + ez * ez, .t = 0.0 };
    }
    const t_raw = ((px - ax) * dx + (pz - az) * dz) / len_sq;
    const t = std.math.clamp(t_raw, 0.0, 1.0);
    const cx = ax + t * dx;
    const cz = az + t * dz;
    const ex = px - cx;
    const ez = pz - cz;
    return .{ .d2 = ex * ex + ez * ez, .t = t };
}

// Returns the deck Y at (x, z) if the player is on land or on a bridge,
// otherwise null. Sloping bridges interpolate between endpoint heights.
fn isles_safe_deck_y(x: f32, z: f32) ?f32 {
    inline for (isles_islands) |isl| {
        const dx = x - isl.cx;
        const dz = z - isl.cz;
        if (dx * dx + dz * dz <= isl.radius * isl.radius) return isl.y_deck;
    }
    inline for (isles_bridges) |br| {
        const r = segment_dist_sq_t(x, z, br.ax, br.az, br.bx, br.bz);
        if (r.d2 <= br.half_width * br.half_width) {
            return br.a_y * (1.0 - r.t) + br.b_y * r.t;
        }
    }
    return null;
}

// Pin the player to the local deck height when on safe ground; if they walked
// off into water, snap back to last frame's position. Called once per frame
// after position integration when current_zone == .isles.
fn clamp_player_isles(prev_pos: Vec3) void {
    const pp = world.pos[player.entity];
    if (isles_safe_deck_y(pp.x, pp.z)) |y_deck| {
        // ARPG has no jump, so pinning y to the deck every frame is fine.
        world.pos[player.entity].y = y_deck;
    } else {
        world.pos[player.entity] = prev_pos;
        world.vel[player.entity] = Vec3.zero;
    }
}

// Outer-ring boundary clamp shared by all three zones — pushes the player
// back inside `radius` from the world origin in the (x, z) plane.
fn clamp_player_outer_ring(radius: f32) void {
    const pp = world.pos[player.entity];
    const dist_sq = pp.x * pp.x + pp.z * pp.z;
    if (dist_sq > radius * radius) {
        const dist = std.math.sqrt(dist_sq);
        world.pos[player.entity] = Vec3{
            .x = pp.x / dist * radius,
            .y = pp.y,
            .z = pp.z / dist * radius,
        };
        world.vel[player.entity] = Vec3.zero;
    }
}

// Generic scatter spawner for the new asset types (mesh_id 15..24).
// Rejects positions inside the path corridor with retries.
fn spawn_scatter_assets(
    mesh_id: u16,
    count: usize,
    scale_min: f32,
    scale_max: f32,
    radius_min: f32,
    radius_max: f32,
    path_clear: f32,
    team: u8,
) void {
    var n: usize = 0;
    while (n < count) : (n += 1) {
        var angle = rng_f32() * 2.0 * std.math.pi;
        var rr    = rng_radius(radius_min, radius_max);
        var px = std.math.cos(angle) * rr;
        var pz = std.math.sin(angle) * rr;
        var attempts: u32 = 0;
        while (dist_to_path(px, pz) < path_clear and attempts < 8) : (attempts += 1) {
            angle = rng_f32() * 2.0 * std.math.pi;
            rr    = rng_radius(radius_min, radius_max);
            px = std.math.cos(angle) * rr;
            pz = std.math.sin(angle) * rr;
        }
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = px, .y = 0, .z = pz };
        world.mesh_id[e] = mesh_id;
        world.scale[e]   = rng_range(scale_min, scale_max);
        world.team[e]    = team;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.4;
        world.vel[e]     = Vec3.zero;
        world.rot_y[e]   = rng_f32() * 2.0 * std.math.pi;
    }
}

// ── C-exported API (Swift calls these) ───────────────────────────────────────

export fn game_init() void {
    if (inited) return;
    player  = Player.init(&world);
    inited  = true;
    spawn_world_forest();
}

// ── Zone (re)spawn helpers ───────────────────────────────────────────────────
// Called by game_set_zone after despawn_world() clears the previous zone.
// Each function repopulates the world from scratch: ambient particle emitters,
// scenery, then enemies. Emitter slot 0 is always the player-attached
// ambient_sparks (game_update syncs its position via psys.sync_emitter_pos(0)).

// Despawn every entity except the player and reset the particle emitter pool
// so the next spawn_world_*() starts from a clean slate. Bursts (one-shot
// emitters with active=0) and pending mailbox entries are dropped too.
fn despawn_world() void {
    const MAX_E = @import("game/entity.zig").MAX_ENTITIES;
    for (0..MAX_E) |i| {
        const id: u16 = @intCast(i);
        if (!world.alive[id]) continue;
        if (id == player.entity) continue;
        world.despawn(id);
        world.death_t[id]   = 0;
        world.hit_flash[id] = 0;
        world.freeze_t[id]  = 0;
        world.fx_flags[id]  = 0;
    }
    psys.emitter_count = 0;
    Particles.pending_burst = null;
}

fn spawn_world_forest() void {
    // Spawn some ambient sparks on the player as a permanent emitter
    // (slot 0 — game_update syncs its position to the player every frame).
    const spark_e = Particles.preset_emitter(.ambient_sparks, Vec3.zero);
    _ = psys.spawn_emitter(spark_e);

    // Atmospheric ambient emitters scattered through the forest.
    // Static positions — no entity binding, no per-frame sync.
    const mote_positions = [_][2]f32{
        .{  12.0,   8.0 }, .{ -10.0,  18.0 }, .{  20.0, -14.0 }, .{ -22.0, -10.0 },
    };
    for (mote_positions) |mp| {
        const e = Particles.preset_emitter(.forest_motes, Vec3{ .x = mp[0], .y = 0, .z = mp[1] });
        _ = psys.spawn_emitter(e);
    }
    const firefly_positions = [_][2]f32{
        .{  35.0,  20.0 }, .{ -28.0,  32.0 }, .{  18.0, -36.0 }, .{ -34.0, -22.0 },
    };
    for (firefly_positions) |fp| {
        const e = Particles.preset_emitter(.fireflies, Vec3{ .x = fp[0], .y = 0, .z = fp[1] });
        _ = psys.spawn_emitter(e);
    }
    const ember_positions = [_][2]f32{
        .{  26.0,  10.0 }, .{ -22.0,  20.0 }, .{  18.0, -28.0 }, .{ -30.0,  -8.0 },
    };
    for (ember_positions) |ep| {
        const e = Particles.preset_emitter(.embers, Vec3{ .x = ep[0], .y = 0.2, .z = ep[1] });
        _ = psys.spawn_emitter(e);
    }

    // Inner forest: truly random positions in annulus r=[25, 270].
    // Reject positions that fall inside the path clearing (within 8m of the
    // path centerline) so the trail to the portal stays open.
    for (0..600) |ti| {
        var angle = rng_f32() * 2.0 * std.math.pi;
        var r     = rng_radius(25.0, 270.0);
        var px = std.math.cos(angle) * r;
        var pz = std.math.sin(angle) * r;
        var attempts: u32 = 0;
        while (dist_to_path(px, pz) < 8.0 and attempts < 8) : (attempts += 1) {
            angle = rng_f32() * 2.0 * std.math.pi;
            r     = rng_radius(20.0, 128.0);
            px = std.math.cos(angle) * r;
            pz = std.math.sin(angle) * r;
        }
        const te    = world.spawn();
        world.pos[te]    = Vec3{ .x = px, .y = 0, .z = pz };
        world.mesh_id[te]= if (rng_u32() % 3 == 0) 4 else 2;
        world.vel[te]    = Vec3.zero;
        world.radius[te] = 0.9;
        world.hp[te]     = 9999;
        const team_roll = rng_u32() % 10;
        if (team_roll < 2) {
            world.team[te]  = 3;
            world.scale[te] = rng_range(2.0, 3.2);
        } else if (team_roll < 4) {
            world.team[te]  = 4;
            world.scale[te] = rng_range(1.4, 2.4);
        } else {
            world.team[te]  = 2;
            world.scale[te] = rng_range(1.1, 2.2);
        }
        _ = ti;
    }

    // Border wall: random positions in thick annulus r=[280, 320]
    for (0..600) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(280.0, 320.0);
        const te    = world.spawn();
        world.pos[te]    = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[te]= 2;
        world.vel[te]    = Vec3.zero;
        world.radius[te] = 0.9;
        world.hp[te]     = 9999;
        const team_roll  = rng_u32() % 3;
        if (team_roll == 0) {
            world.team[te]  = 3;
            world.scale[te] = rng_range(2.4, 3.8);
        } else if (team_roll == 1) {
            world.team[te]  = 4;
            world.scale[te] = rng_range(2.1, 3.4);
        } else {
            world.team[te]  = 2;
            world.scale[te] = rng_range(2.0, 3.2);
        }
    }

    // Rocks: random scatter across the map, avoid the very center clearing
    // and the path corridor.
    for (0..280) |_| {
        var angle = rng_f32() * 2.0 * std.math.pi;
        var rr    = rng_radius(6.0, 270.0);
        var px = std.math.cos(angle) * rr;
        var pz = std.math.sin(angle) * rr;
        var attempts: u32 = 0;
        while (dist_to_path(px, pz) < 6.0 and attempts < 6) : (attempts += 1) {
            angle = rng_f32() * 2.0 * std.math.pi;
            rr    = rng_radius(6.0, 125.0);
            px = std.math.cos(angle) * rr;
            pz = std.math.sin(angle) * rr;
        }
        const re    = world.spawn();
        world.pos[re]    = Vec3{ .x = px, .y = 0, .z = pz };
        world.mesh_id[re]= 5;
        world.vel[re]    = Vec3.zero;
        world.radius[re] = 0.4;
        world.hp[re]     = 9999;
        world.team[re]   = 9;
        world.scale[re]  = rng_range(0.35, 1.1);
    }

    // Flowers: random scatter. Stay slightly off the path so they don't
    // get walked over visually.
    for (0..240) |fi2| {
        var angle = rng_f32() * 2.0 * std.math.pi;
        var fr    = rng_radius(5.0, 265.0);
        var px = std.math.cos(angle) * fr;
        var pz = std.math.sin(angle) * fr;
        var attempts: u32 = 0;
        while (dist_to_path(px, pz) < 5.0 and attempts < 6) : (attempts += 1) {
            angle = rng_f32() * 2.0 * std.math.pi;
            fr    = rng_radius(5.0, 120.0);
            px = std.math.cos(angle) * fr;
            pz = std.math.sin(angle) * fr;
        }
        const fe    = world.spawn();
        world.pos[fe]    = Vec3{ .x = px, .y = 0, .z = pz };
        world.mesh_id[fe]= 6;
        world.vel[fe]    = Vec3.zero;
        world.radius[fe] = 0.2;
        world.hp[fe]     = 9999;
        world.team[fe]   = @intCast(6 + rng_u32() % 3); // pink / gold / lavender
        world.scale[fe]  = rng_range(0.45, 0.90);
        _ = fi2;
    }

    // Zone-transition portal — single entity at the back of the map.
    // Player walks toward this to "exit" the zone. Tall light beacon makes it
    // visible from anywhere; ground-shader path leads here from the start.
    {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = 0, .y = 0, .z = -PATH_LEN };
        world.mesh_id[e] = 13;
        world.scale[e]   = 2.8;
        world.team[e]    = 13;
        world.hp[e]      = 9999;
        world.radius[e]  = 1.5;
        world.vel[e]     = Vec3.zero;
    }

    // Monolith ring at the map edge — 48 stone obelisks evenly spaced around r=275.
    // Visually marks the boundary that the hard wall in game_update enforces at r=280.
    const N_MONOLITHS: usize = 48;
    const MONO_RADIUS: f32 = 275.0;
    var i: usize = 0;
    while (i < N_MONOLITHS) : (i += 1) {
        const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(N_MONOLITHS));
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = std.math.cos(angle) * MONO_RADIUS, .y = 0, .z = std.math.sin(angle) * MONO_RADIUS };
        world.mesh_id[e] = 14;
        world.scale[e]   = rng_range(2.0, 2.6);
        world.team[e]    = 14;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.6;
        world.vel[e]     = Vec3.zero;
        // Random Y-rotation so adjacent monoliths don't all align identically
        world.rot_y[e]   = rng_f32() * 2.0 * std.math.pi;
    }

    // Towers: ring of stone towers around the perimeter for set dressing
    const tower_positions = [_][2]f32{
        .{   80.0,    0.0 }, .{  -80.0,    0.0 },
        .{    0.0,   80.0 }, .{    0.0,  -80.0 },
        .{   55.0,   55.0 }, .{  -55.0,   55.0 },
        .{   55.0,  -55.0 }, .{  -55.0,  -55.0 },
    };
    for (tower_positions) |tp| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = tp[0], .y = 0, .z = tp[1] };
        world.mesh_id[e] = 8;
        world.scale[e]   = rng_range(2.4, 3.2);
        world.team[e]    = 11;            // tower stone (no existing team uses 11)
        world.hp[e]      = 9999;
        world.radius[e]  = 1.5;
        world.vel[e]     = Vec3.zero;
    }

    // Path-side lantern torches — alternate sides along the curving path
    // every ~13m so the player has lit waypoints leading them toward the gate.
    const lantern_count: usize = 18;
    var li: usize = 0;
    while (li < lantern_count) : (li += 1) {
        const t = (@as(f32, @floatFromInt(li)) + 0.5) / @as(f32, @floatFromInt(lantern_count));
        const z = -PATH_LEN * t;
        const cx = path_center_x(z);
        const side: f32 = if (li % 2 == 0) 1.0 else -1.0;
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = cx + side * 5.5, .y = 0, .z = z };
        world.mesh_id[e] = 9;          // existing torch mesh
        world.scale[e]   = rng_range(1.1, 1.3);
        world.team[e]    = 12;          // dark wood color
        world.hp[e]      = 9999;
        world.radius[e]  = 0.2;
        world.vel[e]     = Vec3.zero;
    }

    // Torches: scattered near gargoyle positions for atmospheric lighting
    const torch_positions = [_][2]f32{
        .{  22.0,   8.0 }, .{  30.0,  12.0 }, .{ -18.0,  18.0 }, .{ -26.0,  22.0 },
        .{  16.0, -24.0 }, .{  22.0, -32.0 }, .{ -28.0,  -6.0 }, .{ -32.0, -10.0 },
        .{  36.0, -10.0 }, .{ -12.0, -22.0 }, .{   8.0,  34.0 }, .{ -32.0,  20.0 },
    };
    for (torch_positions) |tp| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = tp[0], .y = 0, .z = tp[1] };
        world.mesh_id[e] = 9;
        world.scale[e]   = rng_range(1.0, 1.4);
        world.team[e]    = 12;            // torch (no existing team uses 12)
        world.hp[e]      = 9999;
        world.radius[e]  = 0.2;
        world.vel[e]     = Vec3.zero;
    }

    // ── 10 new asset types (mesh_id 15..24) — set dressing scattered around the map.
    // Each loop rejects positions inside the path corridor (within 6m of centerline).
    spawn_scatter_assets(15, 8,  1.4, 1.9, 30.0, 260.0, 6.0, 15);   // stone_circle (rare landmarks)
    spawn_scatter_assets(16, 50, 1.0, 1.5, 18.0, 270.0, 6.0, 16);   // fallen_log
    spawn_scatter_assets(17, 80, 0.9, 1.4, 18.0, 270.0, 5.0, 16);   // tree_stump
    spawn_scatter_assets(18, 24, 1.2, 2.0, 25.0, 265.0, 6.0, 18);   // crystal_cluster
    spawn_scatter_assets(19, 7,  1.0, 1.4, 35.0, 240.0, 8.0, 19);   // bonfire
    spawn_scatter_assets(20, 45, 1.3, 2.0, 22.0, 268.0, 6.0, 20);   // dead_tree
    spawn_scatter_assets(21, 30, 0.9, 1.6, 20.0, 265.0, 5.0, 21);   // giant_mushroom
    // Banners: 3 spawns per color (crimson/indigo/gold) — varied team palette
    spawn_scatter_assets(22, 4,  1.0, 1.3, 28.0, 250.0, 7.0, 30);   // banner crimson
    spawn_scatter_assets(22, 4,  1.0, 1.3, 28.0, 250.0, 7.0, 31);   // banner indigo
    spawn_scatter_assets(22, 4,  1.0, 1.3, 28.0, 250.0, 7.0, 32);   // banner gold
    spawn_scatter_assets(23, 80, 0.8, 1.2, 14.0, 270.0, 5.0, 23);   // berry_bush
    spawn_scatter_assets(24, 5,  1.2, 1.6, 40.0, 235.0, 9.0, 24);   // shrine

    // Gargoyle enemies: scattered near player's starting area
    const gargoyle_positions = [_][2]f32{
        .{  26.0,  10.0 }, .{ -22.0,  20.0 }, .{  18.0, -28.0 }, .{ -30.0,  -8.0 },
        .{  32.0, -14.0 }, .{ -16.0, -26.0 }, .{  10.0,  30.0 }, .{ -28.0,  16.0 },
    };
    const gargoyle_cfg = enemy_config.get_by_mesh(3).?;
    for (gargoyle_positions) |gp| {
        const ge = world.spawn();
        world.pos[ge]     = Vec3{ .x = gp[0], .y = 1.5, .z = gp[1] };
        world.mesh_id[ge] = 3;
        world.scale[ge]   = 3.0;
        world.team[ge]    = 1;
        world.hp[ge]      = gargoyle_cfg.hp_max;
        world.hp_max[ge]  = gargoyle_cfg.hp_max;
        world.radius[ge]  = 0.35;
        world.vel[ge]     = Vec3.zero;
        enemy_ai.register(ge, world.pos[ge]);
    }

    // Forest Wisps: scattered, faster harassers — spawn at varied positions
    const wisp_positions = [_][2]f32{
        .{  14.0,  -8.0 }, .{ -12.0, -32.0 }, .{  40.0, -20.0 }, .{ -38.0, -45.0 },
        .{  20.0, -60.0 }, .{ -25.0, -78.0 }, .{  35.0, -95.0 }, .{ -42.0, -110.0 },
        .{  50.0, -130.0 }, .{ -30.0, -150.0 }, .{  60.0,  20.0 }, .{ -55.0,   8.0 },
        .{  -10.0, 50.0 }, .{  45.0,  60.0 },
    };
    const wisp_cfg = enemy_config.get_by_mesh(25).?;
    for (wisp_positions) |wp| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = wp[0], .y = 2.5, .z = wp[1] };
        world.mesh_id[e] = 25;
        world.scale[e]   = rng_range(1.4, 2.0);
        world.team[e]    = 1;
        world.hp[e]      = wisp_cfg.hp_max;
        world.hp_max[e]  = wisp_cfg.hp_max;
        world.radius[e]  = 0.30;
        world.vel[e]     = Vec3.zero;
        enemy_ai.register(e, world.pos[e]);
    }

    // Tree Ents: rare slow tanks — placed near forest clusters away from path
    const ent_positions = [_][2]f32{
        .{  60.0, -55.0 }, .{ -65.0, -75.0 }, .{  55.0, -130.0 }, .{ -50.0, -170.0 },
    };
    const ent_cfg = enemy_config.get_by_mesh(26).?;
    for (ent_positions) |ep| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = ep[0], .y = 0, .z = ep[1] };
        world.mesh_id[e] = 26;
        world.scale[e]   = rng_range(2.4, 3.0);
        world.team[e]    = 1;
        world.hp[e]      = ent_cfg.hp_max;
        world.hp_max[e]  = ent_cfg.hp_max;
        world.radius[e]  = 0.80;
        world.vel[e]     = Vec3.zero;
        enemy_ai.register(e, world.pos[e]);
    }

    // Skeleton Knights: balanced melee units — patrol along the path zone
    const knight_positions = [_][2]f32{
        .{  18.0, -40.0 }, .{ -20.0, -65.0 }, .{  25.0, -90.0 }, .{ -28.0, -115.0 },
        .{  30.0, -140.0 }, .{ -22.0, -160.0 }, .{  15.0, -185.0 }, .{ -18.0, -200.0 },
    };
    const knight_cfg = enemy_config.get_by_mesh(27).?;
    for (knight_positions) |kp| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = kp[0], .y = 0, .z = kp[1] };
        world.mesh_id[e] = 27;
        world.scale[e]   = rng_range(1.7, 2.0);
        world.team[e]    = 1;
        world.hp[e]      = knight_cfg.hp_max;
        world.hp_max[e]  = knight_cfg.hp_max;
        world.radius[e]  = 0.40;
        world.vel[e]     = Vec3.zero;
        enemy_ai.register(e, world.pos[e]);
    }
}

// ── Desert (Sunburnt Wastes) ──────────────────────────────────────────────────
// 64 bone obelisks at r=440 mark the boundary the clamp enforces at r=445.
// Sparser scenery than the forest: rocks, dead trees, crystal clusters, a few
// shrines and stone circles. No path/lantern row — the desert is open.
fn spawn_world_desert() void {
    const spark_e = Particles.preset_emitter(.ambient_sparks, Vec3.zero);
    _ = psys.spawn_emitter(spark_e);

    // Ember motes drifting across the heat shimmer
    const ember_positions = [_][2]f32{
        .{  60.0,  40.0 }, .{ -80.0,  50.0 }, .{  90.0, -60.0 }, .{ -70.0, -80.0 },
        .{ 120.0,   0.0 }, .{    0.0, 120.0 }, .{ -120.0,   0.0 }, .{    0.0, -120.0 },
    };
    for (ember_positions) |ep| {
        const e = Particles.preset_emitter(.embers, Vec3{ .x = ep[0], .y = 0.2, .z = ep[1] });
        _ = psys.spawn_emitter(e);
    }

    // Scattered rocks — many, small. The desert reads as broken stone and bone.
    for (0..520) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(8.0, 430.0);
        const re    = world.spawn();
        world.pos[re]    = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[re]= 5;
        world.vel[re]    = Vec3.zero;
        world.radius[re] = 0.4;
        world.hp[re]     = 9999;
        world.team[re]   = 9;
        world.scale[re]  = rng_range(0.40, 1.4);
    }

    // Dead trees — bleached driftwood-style stumps, sparse.
    for (0..120) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(20.0, 425.0);
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[e] = 20;
        world.scale[e]   = rng_range(1.5, 2.4);
        world.team[e]    = 20;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.6;
        world.vel[e]     = Vec3.zero;
    }

    // Crystal clusters — desert geodes, more common than in the forest.
    for (0..60) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(30.0, 420.0);
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[e] = 18;
        world.scale[e]   = rng_range(1.2, 2.2);
        world.team[e]    = 18;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.5;
        world.vel[e]     = Vec3.zero;
    }

    // Tree stumps for low set dressing
    for (0..80) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(15.0, 425.0);
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[e] = 17;
        world.scale[e]   = rng_range(0.9, 1.5);
        world.team[e]    = 17;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.4;
        world.vel[e]     = Vec3.zero;
    }

    // Boundary obelisk ring — 64 monoliths at r=440 (clamp at 445).
    const N_OBELISKS: usize = 64;
    const OBELISK_R:  f32 = 440.0;
    var i: usize = 0;
    while (i < N_OBELISKS) : (i += 1) {
        const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(N_OBELISKS));
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = std.math.cos(angle) * OBELISK_R, .y = 0, .z = std.math.sin(angle) * OBELISK_R };
        world.mesh_id[e] = 14;
        world.scale[e]   = rng_range(2.6, 3.4);
        world.team[e]    = 14;
        world.hp[e]      = 9999;
        world.radius[e]  = 0.6;
        world.vel[e]     = Vec3.zero;
        world.rot_y[e]   = rng_f32() * 2.0 * std.math.pi;
    }

    // Stone circles + shrines — rare landmarks across the dunes.
    spawn_scatter_assets(15, 12, 1.5, 2.2, 60.0, 410.0, 6.0, 15);
    spawn_scatter_assets(24,  8, 1.4, 1.8, 80.0, 400.0, 9.0, 24);
    // A few crystal-eyed bonfires for atmosphere
    spawn_scatter_assets(19,  5, 1.0, 1.4, 50.0, 380.0, 8.0, 19);

    // Zone-transition portal at the back of the larger map
    {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = 0, .y = 0, .z = -PATH_LEN };
        world.mesh_id[e] = 13;
        world.scale[e]   = 2.8;
        world.team[e]    = 13;
        world.hp[e]      = 9999;
        world.radius[e]  = 1.5;
        world.vel[e]     = Vec3.zero;
    }

    // Enemies — gargoyles + skeleton knights patrolling, no wisps/ents.
    const gargoyle_positions = [_][2]f32{
        .{  40.0,   20.0 }, .{ -45.0,   30.0 }, .{  60.0,  -50.0 }, .{ -70.0,  -30.0 },
        .{  90.0,   10.0 }, .{ -85.0,   45.0 }, .{ 100.0,  -90.0 }, .{ -95.0, -100.0 },
        .{ 150.0,    0.0 }, .{ -160.0,    0.0 }, .{    0.0, 150.0 }, .{    0.0, -150.0 },
    };
    const gargoyle_cfg = enemy_config.get_by_mesh(3).?;
    for (gargoyle_positions) |gp| {
        const ge = world.spawn();
        world.pos[ge]     = Vec3{ .x = gp[0], .y = 1.5, .z = gp[1] };
        world.mesh_id[ge] = 3;
        world.scale[ge]   = 3.0;
        world.team[ge]    = 1;
        world.hp[ge]      = gargoyle_cfg.hp_max;
        world.hp_max[ge]  = gargoyle_cfg.hp_max;
        world.radius[ge]  = 0.35;
        world.vel[ge]     = Vec3.zero;
        enemy_ai.register(ge, world.pos[ge]);
    }
    const knight_positions = [_][2]f32{
        .{  30.0,  -50.0 }, .{ -25.0,  -85.0 }, .{  60.0, -130.0 }, .{ -55.0, -160.0 },
        .{  80.0, -200.0 }, .{ -70.0, -240.0 }, .{ 110.0, -280.0 }, .{ -100.0, -320.0 },
    };
    const knight_cfg = enemy_config.get_by_mesh(27).?;
    for (knight_positions) |kp| {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = kp[0], .y = 0, .z = kp[1] };
        world.mesh_id[e] = 27;
        world.scale[e]   = rng_range(1.7, 2.0);
        world.team[e]    = 1;
        world.hp[e]      = knight_cfg.hp_max;
        world.hp_max[e]  = knight_cfg.hp_max;
        world.radius[e]  = 0.40;
        world.vel[e]     = Vec3.zero;
        enemy_ai.register(e, world.pos[e]);
    }
}

// ── Drifting Isles ────────────────────────────────────────────────────────────
// Six islands chained by walkable bridges. The water-clamp in game_update
// snaps the player back to land if they leave a deck/bridge. Each island gets
// a small cluster of trees, rocks, and a landmark; bridges are kept clear.
fn spawn_world_isles() void {
    const spark_e = Particles.preset_emitter(.ambient_sparks, Vec3.zero);
    _ = psys.spawn_emitter(spark_e);

    // Firefly motes drifting over the water near each island
    for (isles_islands) |isl| {
        const e = Particles.preset_emitter(.fireflies, Vec3{ .x = isl.cx, .y = isl.y_deck + 1.0, .z = isl.cz });
        _ = psys.spawn_emitter(e);
    }

    // Per-island scatter: trees, rocks, stumps, with a few crystal landmarks
    // and a shrine on the largest island. Bridges stay clear (2.5m halo around
    // each segment) so players don't get blocked walking between islands.
    for (isles_islands) |isl| {
        // Trees — scatter inside a band [0.30 * r, 0.85 * r] from island centre.
        const tree_count: u32 = @intFromFloat(@floor(isl.radius * 0.55));
        var ti: u32 = 0;
        while (ti < tree_count) : (ti += 1) {
            const angle = rng_f32() * 2.0 * std.math.pi;
            const rr    = rng_radius(isl.radius * 0.30, isl.radius * 0.85);
            const px = isl.cx + std.math.cos(angle) * rr;
            const pz = isl.cz + std.math.sin(angle) * rr;
            // Skip if too close to a bridge (bridges are walkable corridors).
            if (near_isles_bridge(px, pz, 5.0)) continue;
            const e = world.spawn();
            world.pos[e]     = Vec3{ .x = px, .y = isl.y_deck, .z = pz };
            world.mesh_id[e] = if (rng_u32() % 3 == 0) 4 else 2;
            world.vel[e]     = Vec3.zero;
            world.radius[e]  = 0.9;
            world.hp[e]      = 9999;
            world.team[e]    = @intCast(2 + rng_u32() % 3); // green / teal / violet
            world.scale[e]   = rng_range(1.6, 2.6);
        }
        // Rocks — small scatter
        const rock_count: u32 = @intFromFloat(@floor(isl.radius * 0.20));
        var ri: u32 = 0;
        while (ri < rock_count) : (ri += 1) {
            const angle = rng_f32() * 2.0 * std.math.pi;
            const rr    = rng_radius(isl.radius * 0.10, isl.radius * 0.90);
            const px = isl.cx + std.math.cos(angle) * rr;
            const pz = isl.cz + std.math.sin(angle) * rr;
            if (near_isles_bridge(px, pz, 3.0)) continue;
            const e = world.spawn();
            world.pos[e]     = Vec3{ .x = px, .y = isl.y_deck, .z = pz };
            world.mesh_id[e] = 5;
            world.vel[e]     = Vec3.zero;
            world.radius[e]  = 0.4;
            world.hp[e]      = 9999;
            world.team[e]    = 9;
            world.scale[e]   = rng_range(0.40, 1.0);
        }
        // Crystal cluster centerpiece per island
        {
            const e = world.spawn();
            world.pos[e]     = Vec3{ .x = isl.cx, .y = isl.y_deck, .z = isl.cz + isl.radius * 0.3 };
            world.mesh_id[e] = 18;
            world.scale[e]   = rng_range(1.6, 2.4);
            world.team[e]    = 18;
            world.hp[e]      = 9999;
            world.radius[e]  = 0.5;
            world.vel[e]     = Vec3.zero;
        }
    }

    // Zone-transition portal on the FINAL (Far Reach) island
    {
        const isl = isles_islands[isles_islands.len - 1];
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = isl.cx, .y = isl.y_deck, .z = isl.cz - isl.radius * 0.3 };
        world.mesh_id[e] = 13;
        world.scale[e]   = 2.8;
        world.team[e]    = 13;
        world.hp[e]      = 9999;
        world.radius[e]  = 1.5;
        world.vel[e]     = Vec3.zero;
    }

    // Enemies — wisps over the water/decks (they can fly), gargoyles roam.
    const gargoyle_cfg = enemy_config.get_by_mesh(3).?;
    for (isles_islands) |isl| {
        if (isl.radius < 150.0) continue; // skip the small Skywatch
        const ge = world.spawn();
        world.pos[ge]     = Vec3{ .x = isl.cx, .y = isl.y_deck + 1.5, .z = isl.cz };
        world.mesh_id[ge] = 3;
        world.scale[ge]   = 3.0;
        world.team[ge]    = 1;
        world.hp[ge]      = gargoyle_cfg.hp_max;
        world.hp_max[ge]  = gargoyle_cfg.hp_max;
        world.radius[ge]  = 0.35;
        world.vel[ge]     = Vec3.zero;
        enemy_ai.register(ge, world.pos[ge]);
    }
    const wisp_cfg = enemy_config.get_by_mesh(25).?;
    for (isles_islands) |isl| {
        var wi: u32 = 0;
        while (wi < 2) : (wi += 1) {
            const angle = rng_f32() * 2.0 * std.math.pi;
            const rr    = rng_radius(isl.radius * 0.4, isl.radius * 0.85);
            const e = world.spawn();
            world.pos[e]     = Vec3{ .x = isl.cx + std.math.cos(angle) * rr, .y = isl.y_deck + 2.5, .z = isl.cz + std.math.sin(angle) * rr };
            world.mesh_id[e] = 25;
            world.scale[e]   = rng_range(1.4, 2.0);
            world.team[e]    = 1;
            world.hp[e]      = wisp_cfg.hp_max;
            world.hp_max[e]  = wisp_cfg.hp_max;
            world.radius[e]  = 0.30;
            world.vel[e]     = Vec3.zero;
            enemy_ai.register(e, world.pos[e]);
        }
    }
}

// True if (px, pz) is within `halo` metres of any walkable bridge segment.
fn near_isles_bridge(px: f32, pz: f32, halo: f32) bool {
    inline for (isles_bridges) |br| {
        const r = segment_dist_sq_t(px, pz, br.ax, br.az, br.bx, br.bz);
        const hw = br.half_width + halo;
        if (r.d2 <= hw * hw) return true;
    }
    return false;
}

export fn game_update(dt: f32) void {
    time += dt;
    // Capture last frame's safe player position BEFORE any movement this frame.
    // The isles water-clamp uses this to roll back if the player walks off land.
    const player_prev_pos = world.pos[player.entity];
    player.update(&world, dt);
    renderer.camera.smooth_follow(world.pos[player.entity], dt);
    // Drain pending camera kick from gameplay events
    if (renderer_mod_main.pending_kick > 0) {
        renderer.camera.kick(renderer_mod_main.pending_kick);
        renderer_mod_main.pending_kick = 0;
    }
    // Drain pending particle burst (one-shot fire-and-forget emitter).
    if (Particles.pending_burst) |pb| {
        var em = Particles.preset_emitter(pb.kind, pb.pos);
        _ = psys.spawn_emitter(em);
        em.active = 0; // one-shot
        Particles.pending_burst = null;
    }

    // Advance walk_phase only when player is actually moving so legs stop when idle
    const pv  = world.vel[player.entity];
    const spd = std.math.sqrt(pv.x * pv.x + pv.z * pv.z);
    if (spd > 0.5) walk_phase += dt * spd * 0.55;

    // Integrate velocity + expire temporary entities (iterate full pool, not just count)
    const MAX_E_iter = @import("game/entity.zig").MAX_ENTITIES;
    const GRAVITY: f32 = 18.0;
    for (0..MAX_E_iter) |i| {
        const id: u16 = @intCast(i);
        if (!world.alive[id]) continue;
        world.pos[id] = world.pos[id].add(world.vel[id].scale(dt));
        // Hit-flash decay (every alive entity)
        if (world.hit_flash[id] > 0) {
            world.hit_flash[id] = @max(0, world.hit_flash[id] - dt);
        }
        // Freeze-tint decay — clear the FROZEN bit when the timer expires so
        // ice-nova-tagged enemies don't keep their blue tint forever.
        if (world.freeze_t[id] > 0) {
            world.freeze_t[id] -= dt;
            if (world.freeze_t[id] <= 0) {
                world.freeze_t[id] = 0;
                world.fx_flags[id] &= ~@as(u32, FX.FROZEN);
            }
        }
        // Lightning bolts: hp repurposed as lifetime — despawn when expired
        if (world.mesh_id[id] == 7) {
            world.hp[id] -= dt;
            if (world.hp[id] <= 0) world.despawn(id);
        }
        // Lightning impact ring (mesh_id 28): expanding ring + fade — despawn at 0.45s
        if (world.mesh_id[id] == 28) {
            world.hp[id] -= dt;
            if (world.hp[id] <= 0) world.despawn(id);
        }
        // Corpse animation: death_t > 0 means the entity is dying. Apply gravity,
        // settle to ground, spin while falling. After 1.5s the corpse stays
        // permanently at the ground as a marker that something died here.
        if (world.death_t[id] > 0) {
            world.death_t[id] += dt;
            // Apply gravity to the corpse so it falls back down after the pop-up
            world.vel[id].y -= GRAVITY * dt;
            // Tumble rotation while in the air
            if (world.pos[id].y > 0.05) {
                world.rot_y[id] += dt * 6.0;
            } else {
                // Settled — clamp to ground, kill velocity, freeze
                world.pos[id].y = 0.05;
                world.vel[id]   = Vec3.zero;
            }
            // Shrink down to 70% of original scale over the first second
            const t = @min(1.0, world.death_t[id]);
            const target_scale = 1.0 - 0.30 * t;
            // Multiply by per-mesh scale baked in mesh_id field — keep scale[id] but
            // remember we modify it once. Use a "scale_factor" via repeated multiply
            // would drift; instead snap to final once at t=1 and skip thereafter.
            if (world.death_t[id] < 1.05) {
                // We don't have an "original scale" field, so apply multiplicatively
                // using a per-step delta. Compute the step that yields the target.
                const prev_t = world.death_t[id] - dt;
                const prev_clamped = @max(0, @min(1.0, prev_t));
                const prev_target = 1.0 - 0.30 * prev_clamped;
                if (prev_target > 0.001) world.scale[id] *= target_scale / prev_target;
            }
        }
    }

    // Enemy AI (all types — dispatched by mesh_id inside enemy_ai.update)
    enemy_ai.update(&world, player.entity, dt, time);

    // Per-zone player boundary clamp.
    //   forest — outer hard wall just inside the 48-monolith ring (r=280).
    //   desert — outer hard wall just inside the 64-obelisk ring (r=445).
    //   isles  — outer wall at r=890 PLUS per-island/bridge water clamp;
    //            if the player crossed off land into open water this frame,
    //            snap them back to last frame's safe position.
    switch (current_zone) {
        .forest => clamp_player_outer_ring(280.0),
        .desert => clamp_player_outer_ring(445.0),
        .isles  => {
            clamp_player_outer_ring(890.0);
            clamp_player_isles(player_prev_pos);
        },
    }

    // Sync spark emitter to player
    psys.sync_emitter_pos(0, world.pos[player.entity]);
}

// Touch in normalized screen coords [0..1]. Swift projects to world XZ.
export fn game_touch_move(world_x: f32, world_z: f32, active: bool) void {
    player.move_touch.world_x = world_x;
    player.move_touch.world_z = world_z;
    player.move_touch.active  = active;
}

export fn game_touch_skill(skill_idx: u8, world_x: f32, world_z: f32) void {
    if (skill_idx >= 4) return;
    const skills = [4]@import("game/player.zig").Skill{
        .fireball, .lightning_strike, .ice_nova, .dash,
    };
    var target = Vec3{ .x = world_x, .y = 0, .z = world_z };
    // Hotbar buttons pass (0, 0). Auto-aim fireball at the nearest enemy in
    // range so the on-screen button is useful without a separate ground tap;
    // fall back to a point ~12m forward of the player if nothing is in range.
    if (skill_idx == 0 and world_x == 0 and world_z == 0) {
        const ppos = world.pos[player.entity];
        const MAX_E = @import("game/entity.zig").MAX_ENTITIES;
        var best_dsq: f32 = 30.0 * 30.0;
        var best_x: f32 = ppos.x - std.math.sin(world.rot_y[player.entity]) * 12.0;
        var best_z: f32 = ppos.z - std.math.cos(world.rot_y[player.entity]) * 12.0;
        for (0..MAX_E) |i| {
            const eid: u16 = @intCast(i);
            if (!world.alive[eid] or world.team[eid] != 1 or world.death_t[eid] > 0) continue;
            const dx = world.pos[eid].x - ppos.x;
            const dz = world.pos[eid].z - ppos.z;
            const dsq = dx * dx + dz * dz;
            if (dsq < best_dsq) { best_dsq = dsq; best_x = world.pos[eid].x; best_z = world.pos[eid].z; }
        }
        target = Vec3{ .x = best_x, .y = 0, .z = best_z };
    }
    _ = player.try_cast(&world, skills[skill_idx], target);
}

// Returns pointer to FrameUniforms struct for Swift to memcpy into MTLBuffer
export fn game_get_frame_uniforms(
    aspect: f32,
    screen_w: f32,
    screen_h: f32,
    out_ptr: [*]u8,
) void {
    var frame = renderer.build_frame(aspect, time, screen_w, screen_h, &psys);
    frame.uniforms.walk_phase = walk_phase;
    const bytes = std.mem.asBytes(&frame.uniforms);
    @memcpy(out_ptr[0..bytes.len], bytes);
}

// Fills Swift-allocated buffer with DrawCall array; returns count
export fn game_fill_draws(buf: [*]u8, max_bytes: u32) u32 {
    renderer.begin_frame();

    // Emit a draw call per alive entity
    for (0..MAX_DRAW) |i| {
        const id: u16 = @intCast(i);
        if (i >= @import("game/entity.zig").MAX_ENTITIES) break;
        if (!world.alive[id]) continue;

        const p = world.pos[id];
        var model = @import("math/vec.zig").Mat4.identity;
        model.m[12] = p.x;
        model.m[13] = p.y;
        model.m[14] = p.z;
        // scale + Y-rotation
        const s   = world.scale[id];
        const ry  = world.rot_y[id];
        const cy  = std.math.cos(ry);
        const sy_val = std.math.sin(ry);
        model.m[0]  = s * cy;
        model.m[2]  = s * (-sy_val);
        model.m[5]  = s;
        model.m[8]  = s * sy_val;
        model.m[10] = s * cy;

        // Per-entity hash (0..1) for color variation — no RNG needed
        const h: u32 = @as(u32, id) *% 2246822519 +% 3266489917;
        const hf: f32 = @as(f32, @floatFromInt(h % 256)) / 255.0;

        const color: [4]f32 = switch (world.team[id]) {
            0 => .{ 0.2,  0.55, 1.0,  1.0 }, // player:  azure blue (no variation)
            1 => .{ 1.0,  0.15, 0.1,  1.0 }, // enemy:   crimson (no variation)
            // Trees: wide variation so each tree has a clearly distinct color
            2 => .{ 0.02 + hf * 0.40,  0.55 + hf * 0.45, 0.05 + hf * 0.50, 1.0 }, // greens: dark moss→bright lime
            3 => .{ 0.00 + hf * 0.50,  0.55 + hf * 0.45, 0.35 + hf * 0.65, 1.0 }, // teals:  deep teal→vivid cyan
            4 => .{ 0.30 + hf * 0.65,  0.00 + hf * 0.35, 0.55 + hf * 0.45, 1.0 }, // violets: indigo→hot magenta
            9 => .{ 0.40 + hf * 0.20,  0.38 + hf * 0.18, 0.34 + hf * 0.14, 1.0 }, // rock: warm gray→tan
            6 => .{ 0.95, 0.30 + hf * 0.40, 0.55 + hf * 0.30, 1.0 },              // flower: pink family
            7 => .{ 0.95, 0.80 + hf * 0.18, 0.10 + hf * 0.35, 1.0 },              // flower: gold/cream
            8  => .{ 0.60 + hf * 0.30, 0.45 + hf * 0.30, 0.90 + hf * 0.10, 1.0 }, // flower: lavender
            10 => .{ 0.80, 0.90, 1.0,  1.0 },                                        // lightning bolt + impact ring
            11 => .{ 0.45 + hf * 0.18, 0.42 + hf * 0.16, 0.38 + hf * 0.14, 1.0 },     // tower: warm gray stone
            12 => .{ 0.32 + hf * 0.12, 0.20 + hf * 0.08, 0.10 + hf * 0.04, 1.0 },     // torch: dark wood
            13 => .{ 0.40, 0.45, 0.55, 1.0 },                                          // portal: cool enchanted stone (single entity, no variation)
            14 => .{ 0.40 + hf * 0.18, 0.38 + hf * 0.14, 0.34 + hf * 0.12, 1.0 },     // monolith: ancient gray-brown stone
            15 => .{ 0.45 + hf * 0.18, 0.42 + hf * 0.14, 0.38 + hf * 0.12, 1.0 },     // stone circle (warm gray)
            16 => .{ 0.45 + hf * 0.20, 0.30 + hf * 0.10, 0.15 + hf * 0.08, 1.0 },     // log/stump (default — overridden by bark shader)
            17 => .{ 0.45 + hf * 0.20, 0.30 + hf * 0.10, 0.15 + hf * 0.08, 1.0 },     // tree stump
            18 => .{ 0.7, 0.4, 1.0, 1.0 },                                              // crystal cluster (override anyway)
            19 => .{ 0.42 + hf * 0.10, 0.40 + hf * 0.08, 0.36 + hf * 0.06, 1.0 },     // bonfire (gray for stone ring; logs use bark shader)
            20 => .{ 0.30, 0.24, 0.18, 1.0 },                                          // dead tree (overridden by shader)
            21 => .{ 0.82, 0.74, 0.60, 1.0 },                                          // giant mushroom stem
            22 => .{ 0.5, 0.5, 0.5, 1.0 },                                             // banner pole (cloth gets per-team color below)
            23 => .{ 0.10, 0.24, 0.07, 1.0 },                                          // berry bush foliage (overridden)
            24 => .{ 0.42 + hf * 0.08, 0.40 + hf * 0.06, 0.36 + hf * 0.06, 1.0 },     // shrine (gray for stone plate; wood uses bark shader)
            // Banner cloth color teams (read by mesh_frag==22 cloth branch)
            30 => .{ 0.85, 0.20, 0.18, 1.0 },                                          // crimson banner
            31 => .{ 0.30, 0.25, 0.85, 1.0 },                                          // indigo banner
            32 => .{ 0.95, 0.75, 0.30, 1.0 },                                          // gold banner
            else => .{ 0.5, 0.5, 0.5, 1.0 },
        };

        // Death darken — corpses fade from full colour to ~30% brightness over
        // their first second of falling, so the kill reads visually without
        // making the body abruptly switch to the gray fallback colour.
        var final_color = color;
        if (world.death_t[id] > 0) {
            const t = @min(1.0, world.death_t[id]);
            const fade = 1.0 - 0.70 * t;
            final_color[0] *= fade;
            final_color[1] *= fade;
            final_color[2] *= fade;
        }

        renderer.push_draw(.{
            .model_matrix = model.m,
            .color        = final_color,
            // Pack hit-flash intensity (0..1, decaying from 0.18s lifetime) into
            // bits 8-15 of fx_flags so the fragment shader can tint enemies red
            // for a single frame on hit. Bits 0-7 stay for the FX bitmask;
            // bits 16-31 are populated by the vertex shader from mesh_id.
            .fx_flags = world.fx_flags[id] | (@as(u32, @intFromFloat(
                @min(1.0, world.hit_flash[id] * 5.55) * 255.0
            )) << 8),
            .mesh_id      = world.mesh_id[id],
        });
    }

    const bytes = std.mem.sliceAsBytes(renderer.draw_buf[0..renderer.draw_count]);
    const copy_len = @min(bytes.len, max_bytes);
    @memcpy(buf[0..copy_len], bytes[0..copy_len]);
    return renderer.draw_count;
}

// Fills player HP, mana, and XP fraction for HUD
export fn game_get_player_stats(
    out_hp:       *f32,
    out_hp_max:   *f32,
    out_mana:     *f32,
    out_mana_max: *f32,
    out_xp_frac:  *f32,
) void {
    out_hp.*       = world.hp[player.entity];
    out_hp_max.*   = world.hp_max[player.entity];
    out_mana.*     = player.mana;
    out_mana_max.* = player.mana_max;
    const xp_max: f32 = @floatFromInt(@as(u32, player.level) * 100);
    out_xp_frac.*  = @as(f32, @floatFromInt(player.xp)) / xp_max;
}

// Returns current player level (1-based)
export fn game_get_player_level() u32 {
    return player.level;
}

// SpellState — packed per-spell progression + readiness for the HUD.
// 4 spells × 12 bytes = 48 bytes. Index order matches the Skill enum:
// 0=fireball, 1=lightning_strike, 2=ice_nova, 3=dash.
const SpellState = extern struct {
    level:       u32, // 1..SPELL_MAX_LEVEL
    xp:          u32, // current xp toward next level
    xp_to_next:  u32, // threshold for level → level+1; 0 if maxed
};

// Fills 4 SpellState entries (48 bytes total) for the HUD's spell-level display.
export fn game_get_spell_state(buf: [*]u8) void {
    const player_mod = @import("game/player.zig");
    const states: [*]SpellState = @ptrCast(@alignCast(buf));
    for (0..4) |i| {
        const lvl = player.spell_level[i];
        const xp  = player.spell_xp[i];
        const to_next: u32 = if (lvl >= player_mod.SPELL_MAX_LEVEL)
            0
        else
            // Threshold table is private — recompute the same formula:
            // SPELL_XP_THRESHOLDS[lvl - 1] from player.zig (200, 400, ..., 1800)
            200 * @as(u32, lvl);
        states[i] = .{
            .level      = @intCast(lvl),
            .xp         = xp,
            .xp_to_next = to_next,
        };
    }
}

// Swift pushes the parsed total of all allocated skill-tree bonuses here.
// Layout: 64-byte SkillBonuses struct (16 × f32). See skill_bonuses.zig.
export fn game_set_skill_bonuses(buf: [*]const u8) void {
    if (!inited) return;
    var b: SkillBonuses = .{};
    const dst = std.mem.asBytes(&b);
    @memcpy(dst, buf[0..@sizeOf(SkillBonuses)]);
    player.bonuses = b;
    player.apply_bonuses(&world);
    enemy_ai_mod.player_dmg_taken_mult =
        @max(0.1, 1.0 - b.armour_pct - b.dmg_reduce_pct);
}

// Enemy label struct: 16 bytes per entry
// Offsets: world_x(0) world_y(4) world_z(8) level(12) name_idx(13) pad(14-15)
const EnemyLabel = extern struct {
    world_x:  f32,
    world_y:  f32,
    world_z:  f32,
    level:    u8,
    name_idx: u8,
    _pad:     [2]u8 = .{0, 0},
};

// Fills buf with one EnemyLabel per alive enemy; sets out_count
export fn game_get_enemy_labels(buf: [*]u8, out_count: *u32) void {
    const labels: [*]EnemyLabel = @ptrCast(@alignCast(buf));
    var count: u32 = 0;
    for (0..@import("game/entity.zig").MAX_ENTITIES) |i| {
        const id: u16 = @intCast(i);
        if (!world.alive[id] or world.team[id] != 1 or world.death_t[id] > 0) continue;
        const cfg = enemy_config.get_by_mesh(world.mesh_id[id]) orelse continue;
        labels[count] = .{
            .world_x  = world.pos[id].x,
            .world_y  = world.pos[id].y + 3.5, // float label above entity
            .world_z  = world.pos[id].z,
            .level    = cfg.level,
            .name_idx = cfg.name_idx,
        };
        count += 1;
    }
    out_count.* = count;
}

// Returns 1 if the player is within `r` meters of the zone-portal at (0, 0, -PATH_LEN).
// Swift polls this each frame to decide when to surface the destination map UI.
export fn game_player_at_portal() u32 {
    const pp = world.pos[player.entity];
    const dx = pp.x;
    const dz = pp.z + PATH_LEN;
    const dsq = dx * dx + dz * dz;
    const R: f32 = 4.5;
    return if (dsq < R * R) 1 else 0;
}

// Returns pointer and count for emitter buffer upload
export fn game_get_emitters(out_count: *u32) [*]const u8 {
    out_count.* = @intCast(psys.emitter_count);
    return @ptrCast(&psys.emitters[0]);
}

const MAX_DRAW = 4096;

// ── Tests ────────────────────────────────────────────────────────────────────
// Integration tests for game_init + game_set_zone. These exercise the full
// despawn / respawn / player-teleport flow with the real Zig globals so any
// regression where game_set_zone silently fails to rebuild the world will be
// caught at `zig build test` time instead of only on-device.

fn count_alive_non_player() u32 {
    const MAX_E = @import("game/entity.zig").MAX_ENTITIES;
    var n: u32 = 0;
    for (0..MAX_E) |i| {
        const id: u16 = @intCast(i);
        if (world.alive[id] and id != player.entity) n += 1;
    }
    return n;
}

// True if any alive entity has the given mesh_id. Used to check that
// zone-specific scenery actually shows up after a switch (e.g. lanterns
// only spawn in the forest).
fn any_with_mesh(mesh: u16) bool {
    const MAX_E = @import("game/entity.zig").MAX_ENTITIES;
    for (0..MAX_E) |i| {
        const id: u16 = @intCast(i);
        if (world.alive[id] and world.mesh_id[id] == mesh) return true;
    }
    return false;
}

test "game_init populates the forest" {
    // Reset globals so re-running the test suite from a fresh process is safe.
    inited = false;
    world  = .{};
    psys   = .{};
    enemy_ai = .{};

    game_init();
    try std.testing.expect(inited);
    try std.testing.expect(world.count > 100);          // ~2400 entities expected
    try std.testing.expect(any_with_mesh(13));          // portal
    try std.testing.expect(any_with_mesh(14));          // monolith ring
    try std.testing.expect(any_with_mesh(9));           // path lanterns
    try std.testing.expectEqual(@as(f32, 0), world.pos[player.entity].x);
    try std.testing.expectEqual(@as(f32, 0), world.pos[player.entity].z);
}

test "game_set_zone(desert) tears down forest and rebuilds desert" {
    inited = false;
    world  = .{};
    psys   = .{};
    enemy_ai = .{};

    game_init();
    const forest_count = count_alive_non_player();
    try std.testing.expect(forest_count > 100);

    game_set_zone(1); // desert
    try std.testing.expectEqual(Zone.desert, current_zone);
    // World was wiped and rebuilt — entity count is non-zero and the player
    // is back at origin with full HP. Forest-specific lanterns should be gone.
    try std.testing.expect(count_alive_non_player() > 100);
    try std.testing.expectEqual(@as(f32, 0), world.pos[player.entity].x);
    try std.testing.expectEqual(@as(f32, 0), world.pos[player.entity].z);
    try std.testing.expectEqual(world.hp_max[player.entity], world.hp[player.entity]);
    // Lanterns (mesh 9) only spawn in the forest's path-side row + torch
    // scatter. Desert spawns no torches, so this should be false.
    try std.testing.expect(!any_with_mesh(9));
}

test "game_set_zone(isles) puts player on Lantern Hold" {
    inited = false;
    world  = .{};
    psys   = .{};
    enemy_ai = .{};

    game_init();
    game_set_zone(2);
    try std.testing.expectEqual(Zone.isles, current_zone);
    try std.testing.expect(count_alive_non_player() > 50);
    try std.testing.expectEqual(isles_islands[0].cx, world.pos[player.entity].x);
    try std.testing.expectEqual(isles_islands[0].cz, world.pos[player.entity].z);
    try std.testing.expectEqual(isles_islands[0].y_deck, world.pos[player.entity].y);
}

test "game_set_zone round-trips forest -> desert -> isles -> forest" {
    inited = false;
    world  = .{};
    psys   = .{};
    enemy_ai = .{};

    game_init();
    try std.testing.expect(any_with_mesh(9));   // forest has lanterns

    game_set_zone(1);
    try std.testing.expect(!any_with_mesh(9));  // desert clears them

    game_set_zone(2);
    try std.testing.expect(!any_with_mesh(9));  // isles also clears them

    game_set_zone(0);
    try std.testing.expect(any_with_mesh(9));   // forest's lanterns are back
}

test "game_set_zone ignores invalid zone ids" {
    inited = false;
    world  = .{};
    psys   = .{};
    enemy_ai = .{};

    game_init();
    const before = current_zone;
    game_set_zone(99);
    try std.testing.expectEqual(before, current_zone);
}
