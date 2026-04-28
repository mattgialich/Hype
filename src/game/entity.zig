// Minimal ECS — flat arrays, no heap allocation per entity.
// Max 4096 entities. Archetype-free for simplicity on mobile.

const std = @import("std");
const Vec3 = @import("../math/vec.zig").Vec3;
const Vec2 = @import("../math/vec.zig").Vec2;

pub const MAX_ENTITIES: usize = 4096;

pub const EntityId = u16;
pub const INVALID_ENTITY: EntityId = std.math.maxInt(EntityId);

// Component arrays (SOA layout — cache friendly for iteration)
pub const World = struct {
    // Alive bitmask
    alive: [MAX_ENTITIES]bool = [_]bool{false} ** MAX_ENTITIES,

    // Transform
    pos:     [MAX_ENTITIES]Vec3 = undefined,
    rot_y:   [MAX_ENTITIES]f32  = undefined, // radians, yaw only for top-down
    scale:   [MAX_ENTITIES]f32  = undefined,

    // Physics
    vel:     [MAX_ENTITIES]Vec3 = undefined,
    radius:  [MAX_ENTITIES]f32  = undefined, // sphere collider radius

    // Health / combat
    hp:      [MAX_ENTITIES]f32  = undefined,
    hp_max:  [MAX_ENTITIES]f32  = undefined,
    team:    [MAX_ENTITIES]u8   = undefined, // 0=player, 1=enemy

    // Render
    mesh_id: [MAX_ENTITIES]u16  = undefined,
    fx_flags:[MAX_ENTITIES]u32  = undefined, // bitmask for active visual effects

    // Death state — 0 = alive. > 0 = seconds since killed. main.zig advances
    // this each frame for corpses; renderer reads it for fall/shrink animation.
    death_t: [MAX_ENTITIES]f32  = [_]f32{0} ** MAX_ENTITIES,
    // Brief flash on hit — > 0 = seconds remaining of red flash. Fades down
    // toward 0 each frame.
    hit_flash:[MAX_ENTITIES]f32 = [_]f32{0} ** MAX_ENTITIES,
    // Frozen lifetime — > 0 = seconds remaining of FX.FROZEN tint; the
    // FROZEN bit on fx_flags is cleared in main.zig when this hits 0.
    freeze_t:[MAX_ENTITIES]f32  = [_]f32{0} ** MAX_ENTITIES,

    // Free list
    next_free: EntityId = 0,
    count: u16 = 0,

    pub fn spawn(world: *World) EntityId {
        // Linear scan for free slot (good enough for 4k entities)
        var id: EntityId = world.next_free;
        while (id < MAX_ENTITIES and world.alive[id]) : (id += 1) {}
        if (id >= MAX_ENTITIES) return INVALID_ENTITY;

        world.alive[id]   = true;
        world.pos[id]     = Vec3.zero;
        world.rot_y[id]   = 0;
        world.scale[id]   = 1;
        world.vel[id]     = Vec3.zero;
        world.radius[id]  = 0.5;
        world.hp[id]      = 100;
        world.hp_max[id]  = 100;
        world.team[id]    = 1;
        world.mesh_id[id] = 0;
        world.fx_flags[id]= 0;
        world.death_t[id] = 0;
        world.hit_flash[id] = 0;
        world.freeze_t[id]  = 0;
        world.count      += 1;
        world.next_free   = id + 1;
        return id;
    }

    pub fn despawn(world: *World, id: EntityId) void {
        if (!world.alive[id]) return;
        world.alive[id] = false;
        world.count    -= 1;
        if (id < world.next_free) world.next_free = id;
    }

    pub fn is_alive(world: *const World, id: EntityId) bool {
        return id < MAX_ENTITIES and world.alive[id];
    }

    // Simple circle-circle collision (XZ plane, top-down)
    pub fn check_collision(world: *const World, a: EntityId, b: EntityId) bool {
        const dx = world.pos[a].x - world.pos[b].x;
        const dz = world.pos[a].z - world.pos[b].z;
        const dist2 = dx * dx + dz * dz;
        const r = world.radius[a] + world.radius[b];
        return dist2 < r * r;
    }
};

// FX bitmask flags
pub const FX = struct {
    pub const BURNING     : u32 = 1 << 0;
    pub const FROZEN      : u32 = 1 << 1;
    pub const LIGHTNING   : u32 = 1 << 2;
    pub const DEATH_BURST : u32 = 1 << 3;
    pub const LOW_HP_AURA : u32 = 1 << 4;
};

test "spawn and despawn" {
    var world = World{};
    const e1 = world.spawn();
    const e2 = world.spawn();
    try std.testing.expect(e1 != INVALID_ENTITY);
    try std.testing.expect(e2 != INVALID_ENTITY);
    try std.testing.expect(e1 != e2);
    world.despawn(e1);
    try std.testing.expect(!world.is_alive(e1));
    try std.testing.expect(world.is_alive(e2));
    const e3 = world.spawn(); // should reclaim e1's slot
    try std.testing.expectEqual(e1, e3);
}
