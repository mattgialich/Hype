// Game entry point — all exported symbols are called by Swift MTKView delegate.
// Swift owns the Metal device, command queue, and render pass descriptor.
// Zig owns all game state, camera, and produces DrawCall lists each frame.

const std          = @import("std");
const Vec3         = @import("math/vec.zig").Vec3;
const World        = @import("game/entity.zig").World;
const Player       = @import("game/player.zig").Player;
const Renderer     = @import("renderer/metal.zig").Renderer;
const Particles    = @import("renderer/particles.zig");
const FX           = @import("game/entity.zig").FX;
const EnemyAI      = @import("game/enemy_ai.zig").EnemyAI;
const enemy_config = @import("game/enemy_config.zig");

// ── Global game state (static, no allocator needed for core loop) ────────────

var world:      World           = .{};
var player:     Player          = undefined;
var renderer:   Renderer        = .{};
var psys:       Particles.ParticleSystem = .{};
var enemy_ai:   EnemyAI         = .{};
var time:       f32  = 0;
var walk_phase: f32  = 0;
var inited:     bool = false;

// ── Simple xorshift32 PRNG — seeded at compile time, deterministic but random-looking ──
var _rng: u32 = 0xA3B7C1D9;
fn rng_u32() u32 { _rng ^= _rng << 13; _rng ^= _rng >> 17; _rng ^= _rng << 5; return _rng; }
fn rng_f32() f32 { return @as(f32, @floatFromInt(rng_u32() & 0xFFFF)) / 65535.0; }
fn rng_range(lo: f32, hi: f32) f32 { return lo + rng_f32() * (hi - lo); }
// Area-uniform radius in annulus: sample r² uniformly so outer ring isn't under-populated
fn rng_radius(r_min: f32, r_max: f32) f32 {
    return std.math.sqrt(rng_range(r_min * r_min, r_max * r_max));
}

// ── C-exported API (Swift calls these) ───────────────────────────────────────

export fn game_init() void {
    if (inited) return;
    player  = Player.init(&world);
    inited  = true;

    // Spawn some ambient sparks on the player as a permanent emitter
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

    // Inner forest: truly random positions in annulus r=[20, 128]
    // rng_radius samples r² uniformly so density is even across the area
    for (0..140) |ti| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const r     = rng_radius(20.0, 128.0);
        const te    = world.spawn();
        world.pos[te]    = Vec3{ .x = std.math.cos(angle) * r, .y = 0, .z = std.math.sin(angle) * r };
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

    // Border wall: random positions in thick annulus r=[132, 158]
    for (0..220) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(132.0, 158.0);
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
    for (0..70) |_| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const rr    = rng_radius(6.0, 125.0);
        const re    = world.spawn();
        world.pos[re]    = Vec3{ .x = std.math.cos(angle) * rr, .y = 0, .z = std.math.sin(angle) * rr };
        world.mesh_id[re]= 5;
        world.vel[re]    = Vec3.zero;
        world.radius[re] = 0.4;
        world.hp[re]     = 9999;
        world.team[re]   = 9;
        world.scale[re]  = rng_range(0.35, 1.1);
    }

    // Flowers: random scatter
    for (0..60) |fi2| {
        const angle = rng_f32() * 2.0 * std.math.pi;
        const fr    = rng_radius(5.0, 120.0);
        const fe    = world.spawn();
        world.pos[fe]    = Vec3{ .x = std.math.cos(angle) * fr, .y = 0, .z = std.math.sin(angle) * fr };
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
        world.pos[e]     = Vec3{ .x = 0, .y = 0, .z = -100 };
        world.mesh_id[e] = 13;
        world.scale[e]   = 2.5;
        world.team[e]    = 13;
        world.hp[e]      = 9999;
        world.radius[e]  = 1.5;
        world.vel[e]     = Vec3.zero;
    }

    // Monolith ring at the map edge — 24 stone obelisks evenly spaced around r=128.
    // Visually marks the boundary that the hard wall in game_update enforces at r=130.
    const N_MONOLITHS: usize = 24;
    const MONO_RADIUS: f32 = 128.0;
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
}

export fn game_update(dt: f32) void {
    time += dt;
    player.update(&world, dt);
    renderer.camera.smooth_follow(world.pos[player.entity], dt);

    // Advance walk_phase only when player is actually moving so legs stop when idle
    const pv  = world.vel[player.entity];
    const spd = std.math.sqrt(pv.x * pv.x + pv.z * pv.z);
    if (spd > 0.5) walk_phase += dt * spd * 0.55;

    // Integrate velocity + expire temporary entities (iterate full pool, not just count)
    for (0..@import("game/entity.zig").MAX_ENTITIES) |i| {
        const id: u16 = @intCast(i);
        if (!world.alive[id]) continue;
        world.pos[id] = world.pos[id].add(world.vel[id].scale(dt));
        // Lightning bolts: hp repurposed as lifetime — despawn when expired
        if (world.mesh_id[id] == 7) {
            world.hp[id] -= dt;
            if (world.hp[id] <= 0) world.despawn(id);
        }
    }

    // Enemy AI (all types — dispatched by mesh_id inside enemy_ai.update)
    enemy_ai.update(&world, player.entity, dt, time);

    // Circular map boundary — hard wall at r=63, stops player dead at the tree line
    const MAP_RADIUS: f32 = 130.0;
    const pp = world.pos[player.entity];
    const dist_sq = pp.x * pp.x + pp.z * pp.z;
    if (dist_sq > MAP_RADIUS * MAP_RADIUS) {
        const dist = std.math.sqrt(dist_sq);
        world.pos[player.entity] = Vec3{
            .x = pp.x / dist * MAP_RADIUS,
            .y = pp.y,
            .z = pp.z / dist * MAP_RADIUS,
        };
        world.vel[player.entity] = Vec3.zero;
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
    const target = Vec3{ .x = world_x, .y = 0, .z = world_z };
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
            10 => .{ 0.80, 0.90, 1.0,  1.0 },                                        // lightning bolt
            11 => .{ 0.45 + hf * 0.18, 0.42 + hf * 0.16, 0.38 + hf * 0.14, 1.0 },     // tower: warm gray stone
            12 => .{ 0.32 + hf * 0.12, 0.20 + hf * 0.08, 0.10 + hf * 0.04, 1.0 },     // torch: dark wood
            13 => .{ 0.40, 0.45, 0.55, 1.0 },                                          // portal: cool enchanted stone (single entity, no variation)
            14 => .{ 0.40 + hf * 0.18, 0.38 + hf * 0.14, 0.34 + hf * 0.12, 1.0 },     // monolith: ancient gray-brown stone
            else => .{ 0.5, 0.5, 0.5, 1.0 },
        };

        renderer.push_draw(.{
            .model_matrix = model.m,
            .color        = color,
            .fx_flags     = world.fx_flags[id],
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
        if (!world.alive[id] or world.team[id] != 1) continue;
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

// Returns pointer and count for emitter buffer upload
export fn game_get_emitters(out_count: *u32) [*]const u8 {
    out_count.* = @intCast(psys.emitter_count);
    return @ptrCast(&psys.emitters[0]);
}

const MAX_DRAW = 1024;
