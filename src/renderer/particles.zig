// GPU particle system — emitters feed a persistent Metal buffer.
// The actual GPU simulation runs in a Metal compute shader.
// This file manages the CPU-side emitter state and buffer updates.

const std = @import("std");
const Vec3 = @import("../math/vec.zig").Vec3;
const Vec4 = @import("../math/vec.zig").Vec4;

pub const MAX_EMITTERS: usize = 256;
pub const MAX_PARTICLES: usize = 65536; // 64k particles in one GPU buffer

// Must match ParticleEmitter struct in particles.metal
pub const GpuEmitter = extern struct {
    pos:          [3]f32,
    emit_rate:    f32,      // particles/sec
    vel_min:      [3]f32,
    vel_max:      [3]f32,
    color_start:  [4]f32,  // RGBA
    color_end:    [4]f32,
    size_start:   f32,
    size_end:     f32,
    lifetime:     f32,      // particle lifetime seconds
    active:       u32,      // 0 = inactive, 1 = active
    spawn_accum:  f32,      // fractional spawn accumulator
    _pad:         [3]f32 = .{0,0,0},
};

// Must match Particle struct in particles.metal
pub const GpuParticle = extern struct {
    pos:      [3]f32,
    age:      f32,
    vel:      [3]f32,
    lifetime: f32,
    color:    [4]f32,
    size:     f32,
    emitter_idx: u32,
    _pad:     [2]f32 = .{0, 0},
};

pub const EmitterPreset = enum {
    fire,
    ice_nova,
    lightning,
    death_burst,
    ground_impact,
    ambient_sparks,
    forest_motes,
    fireflies,
    embers,
};

pub fn preset_emitter(kind: EmitterPreset, pos: Vec3) GpuEmitter {
    return switch (kind) {
        .fire => GpuEmitter{
            .pos          = .{ pos.x, pos.y, pos.z },
            .emit_rate    = 120,
            .vel_min      = .{ -0.5, 1.0, -0.5 },
            .vel_max      = .{  0.5, 3.5,  0.5 },
            .color_start  = .{ 1.0, 0.6, 0.1, 1.0 },
            .color_end    = .{ 0.8, 0.1, 0.0, 0.0 },
            .size_start   = 0.3,
            .size_end     = 0.05,
            .lifetime     = 0.9,
            .active       = 1,
            .spawn_accum  = 0,
        },
        .ice_nova => GpuEmitter{
            .pos          = .{ pos.x, pos.y, pos.z },
            .emit_rate    = 400,
            .vel_min      = .{ -6, 0.2, -6 },
            .vel_max      = .{  6, 2.0,  6 },
            .color_start  = .{ 0.5, 0.85, 1.0, 1.0 },
            .color_end    = .{ 0.2, 0.5,  1.0, 0.0 },
            .size_start   = 0.15,
            .size_end     = 0.02,
            .lifetime     = 0.6,
            .active       = 1,
            .spawn_accum  = 0,
        },
        .lightning => GpuEmitter{
            .pos          = .{ pos.x, pos.y + 8, pos.z },
            .emit_rate    = 800,
            .vel_min      = .{ -1, -12, -1 },
            .vel_max      = .{  1,  -4,  1 },
            .color_start  = .{ 0.9, 0.9, 1.0, 1.0 },
            .color_end    = .{ 0.4, 0.4, 1.0, 0.0 },
            .size_start   = 0.08,
            .size_end     = 0.02,
            .lifetime     = 0.25,
            .active       = 1,
            .spawn_accum  = 0,
        },
        .death_burst => GpuEmitter{
            .pos          = .{ pos.x, pos.y, pos.z },
            .emit_rate    = 2000, // one-shot burst — caller disables after 1 frame
            .vel_min      = .{ -5, 0.5, -5 },
            .vel_max      = .{  5, 8.0,  5 },
            .color_start  = .{ 1.0, 0.3, 0.0, 1.0 },
            .color_end    = .{ 0.2, 0.0, 0.0, 0.0 },
            .size_start   = 0.4,
            .size_end     = 0.0,
            .lifetime     = 1.2,
            .active       = 1,
            .spawn_accum  = 0,
        },
        .ground_impact => GpuEmitter{
            .pos          = .{ pos.x, 0.05, pos.z },
            .emit_rate    = 300,
            .vel_min      = .{ -3, 0.2, -3 },
            .vel_max      = .{  3, 1.5,  3 },
            .color_start  = .{ 0.6, 0.5, 0.4, 0.9 },
            .color_end    = .{ 0.3, 0.25, 0.2, 0.0 },
            .size_start   = 0.2,
            .size_end     = 0.0,
            .lifetime     = 0.5,
            .active       = 1,
            .spawn_accum  = 0,
        },
        .ambient_sparks => GpuEmitter{
            .pos          = .{ pos.x, pos.y, pos.z },
            .emit_rate    = 20,
            .vel_min      = .{ -0.3, 0.5, -0.3 },
            .vel_max      = .{  0.3, 1.5,  0.3 },
            .color_start  = .{ 1.0, 0.9, 0.3, 1.0 },
            .color_end    = .{ 1.0, 0.5, 0.0, 0.0 },
            .size_start   = 0.06,
            .size_end     = 0.0,
            .lifetime     = 1.5,
            .active       = 1,
            .spawn_accum  = 0,
        },
        // Slow drifting dust motes — long-lived, near-zero gravity, soft cream
        .forest_motes => GpuEmitter{
            .pos          = .{ pos.x, pos.y + 1.5, pos.z },
            .emit_rate    = 4,
            .vel_min      = .{ -0.15, 0.05, -0.15 },
            .vel_max      = .{  0.15, 0.30,  0.15 },
            .color_start  = .{ 0.95, 0.92, 0.78, 0.55 },
            .color_end    = .{ 0.85, 0.80, 0.65, 0.0 },
            .size_start   = 0.05,
            .size_end     = 0.02,
            .lifetime     = 6.0,
            .active       = 1,
            .spawn_accum  = 0,
        },
        // Fireflies — yellow-green twinkly, slow lateral drift
        .fireflies => GpuEmitter{
            .pos          = .{ pos.x, pos.y + 1.0, pos.z },
            .emit_rate    = 3,
            .vel_min      = .{ -0.4, 0.1, -0.4 },
            .vel_max      = .{  0.4, 0.5,  0.4 },
            .color_start  = .{ 0.85, 1.0, 0.35, 0.85 },
            .color_end    = .{ 0.55, 0.85, 0.20, 0.0 },
            .size_start   = 0.08,
            .size_end     = 0.04,
            .lifetime     = 4.5,
            .active       = 1,
            .spawn_accum  = 0,
        },
        // Embers — warm orange-red rising slowly, medium lifetime
        .embers => GpuEmitter{
            .pos          = .{ pos.x, pos.y + 0.4, pos.z },
            .emit_rate    = 8,
            .vel_min      = .{ -0.2, 0.4, -0.2 },
            .vel_max      = .{  0.2, 1.0,  0.2 },
            .color_start  = .{ 1.0, 0.55, 0.15, 0.95 },
            .color_end    = .{ 0.7, 0.18, 0.0,  0.0 },
            .size_start   = 0.07,
            .size_end     = 0.0,
            .lifetime     = 2.5,
            .active       = 1,
            .spawn_accum  = 0,
        },
    };
}

// CPU-side emitter table (mirrored on GPU as MTLBuffer)
pub const ParticleSystem = struct {
    emitters: [MAX_EMITTERS]GpuEmitter = undefined,
    emitter_count: usize = 0,

    pub fn spawn_emitter(self: *ParticleSystem, e: GpuEmitter) u16 {
        for (0..MAX_EMITTERS) |i| {
            if (self.emitters[i].active == 0) {
                self.emitters[i] = e;
                if (i >= self.emitter_count) self.emitter_count = i + 1;
                return @intCast(i);
            }
        }
        return std.math.maxInt(u16); // full
    }

    pub fn kill_emitter(self: *ParticleSystem, idx: u16) void {
        if (idx < MAX_EMITTERS) self.emitters[idx].active = 0;
    }

    // Call once per frame — moves emitter positions if entity moves
    pub fn sync_emitter_pos(self: *ParticleSystem, idx: u16, pos: Vec3) void {
        if (idx >= MAX_EMITTERS) return;
        self.emitters[idx].pos = .{ pos.x, pos.y, pos.z };
    }
};
