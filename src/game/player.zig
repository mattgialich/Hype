// Player system — touch input → movement, skills, camera follow

const std  = @import("std");
const Vec2 = @import("../math/vec.zig").Vec2;
const Vec3 = @import("../math/vec.zig").Vec3;
const World = @import("entity.zig").World;
const EntityId = @import("entity.zig").EntityId;
const SkillBonuses = @import("skill_bonuses.zig").SkillBonuses;

pub const PLAYER_SPEED: f32 = 10.0; // units/sec
pub const PLAYER_RADIUS: f32 = 0.4;
pub const BASE_HP_MAX:   f32 = 200;
pub const BASE_MANA_MAX: f32 = 100;
pub const BASE_MANA_REGEN: f32 = 5.0; // MP/sec
pub const BASE_LIGHTNING_DMG: f32 = 30;

// Tiny xorshift32 for crit rolls (independent stream from main.zig's rng).
var _crit_rng: u32 = 0x517CC1B7;
fn crit_roll_unit() f32 {
    _crit_rng ^= _crit_rng << 13;
    _crit_rng ^= _crit_rng >> 17;
    _crit_rng ^= _crit_rng << 5;
    return @as(f32, @floatFromInt(_crit_rng & 0xFFFFFF)) / @as(f32, 0x1000000);
}

pub const TouchState = struct {
    active: bool = false,
    world_x: f32 = 0,   // projected to world XZ plane
    world_z: f32 = 0,
};

pub const Skill = enum(u8) {
    fireball,
    lightning_strike,
    ice_nova,
    dash,
};

pub const Player = struct {
    entity: EntityId,
    move_touch: TouchState = .{},
    skill_touch: [4]TouchState = [_]TouchState{.{}} ** 4,
    skill_cd:  [4]f32 = [_]f32{0} ** 4, // seconds remaining
    mana:      f32   = BASE_MANA_MAX,
    mana_max:  f32   = BASE_MANA_MAX,
    xp: u32 = 0,
    level: u8 = 1,
    bonuses: SkillBonuses = .{},

    pub fn init(world: *World) Player {
        const e = world.spawn();
        world.pos[e]     = Vec3{ .x = 0, .y = 0, .z = 0 };
        world.radius[e]  = PLAYER_RADIUS;
        world.hp[e]      = BASE_HP_MAX;
        world.hp_max[e]  = BASE_HP_MAX;
        world.team[e]    = 0;
        world.mesh_id[e] = 1; // mesh slot 1 = hero model
        world.scale[e]   = 2.0;
        return .{ .entity = e };
    }

    // Recompute hp_max / mana_max from bonuses, preserving the *delta* on
    // current hp/mana so the player is rewarded with healing when allocating
    // a new node (POE-style, not POE2-style fractional-scale).
    pub fn apply_bonuses(self: *Player, world: *World) void {
        const new_hp_max   = (BASE_HP_MAX   + self.bonuses.hp_flat)   * (1.0 + self.bonuses.hp_pct);
        const new_mana_max = (BASE_MANA_MAX + self.bonuses.mana_flat) * (1.0 + self.bonuses.mana_pct);

        const dh = new_hp_max - world.hp_max[self.entity];
        world.hp_max[self.entity] = new_hp_max;
        world.hp[self.entity] = @min(new_hp_max, @max(0, world.hp[self.entity] + dh));

        const dm = new_mana_max - self.mana_max;
        self.mana_max = new_mana_max;
        self.mana     = @min(new_mana_max, @max(0, self.mana + dm));
    }

    pub fn update(self: *Player, world: *World, dt: f32) void {
        const e = self.entity;

        const speed_mult = 1.0 + self.bonuses.move_speed_pct;

        // Joystick: world_x/z are direction components in [-1, 1]
        if (self.move_touch.active) {
            const dx = self.move_touch.world_x;
            const dz = self.move_touch.world_z;
            const len_sq = dx * dx + dz * dz;
            if (len_sq > 0.01) {
                const len = std.math.sqrt(len_sq);
                const spd = @min(len, 1.0) * PLAYER_SPEED * speed_mult;
                world.vel[e] = Vec3{ .x = (dx / len) * spd, .y = 0, .z = (dz / len) * spd };
                world.rot_y[e] = std.math.atan2(dx / len, dz / len);
            } else {
                world.vel[e] = Vec3.zero;
            }
        } else {
            world.vel[e] = world.vel[e].scale(1.0 - dt * 12.0);
        }

        // Mana regen: BASE_MANA_REGEN MP/sec, scaled by mana_regen_pct
        const regen = BASE_MANA_REGEN * (1.0 + self.bonuses.mana_regen_pct);
        self.mana = @min(self.mana_max, self.mana + regen * dt);

        // Cooldown tick
        // Note: position integration is handled by game_update for all entities.
        for (&self.skill_cd) |*cd| {
            cd.* = @max(0, cd.* - dt);
        }
    }

    // Returns true if skill was cast
    pub fn try_cast(self: *Player, world: *World, skill: Skill, target: Vec3) bool {
        const idx = @intFromEnum(skill);
        if (self.skill_cd[idx] > 0) return false;

        const mana_costs = [4]f32{ 20, 15, 35, 10 };
        if (self.mana < mana_costs[idx]) return false;
        self.mana -= mana_costs[idx];

        const cooldowns = [4]f32{ 0.8, 0.0, 5.0, 2.0 }; // lightning has no cooldown — MP-gated only
        const cd_mult = @max(0.1, 1.0 - self.bonuses.cast_speed_pct - self.bonuses.cooldown_pct);
        self.skill_cd[idx] = cooldowns[idx] * cd_mult;

        switch (skill) {
            .lightning_strike => {
                const ppos = world.pos[self.entity];
                const MAX_E = @import("entity.zig").MAX_ENTITIES;

                // Seek the nearest enemy within 30 units
                var hit_x: f32 = 0;
                var hit_z: f32 = 0;
                var best_dsq: f32 = 30.0 * 30.0;
                var best_enemy: u16 = std.math.maxInt(u16);
                for (0..MAX_E) |i| {
                    const eid: u16 = @intCast(i);
                    if (!world.alive[eid] or world.team[eid] != 1) continue;
                    const dx = world.pos[eid].x - ppos.x;
                    const dz = world.pos[eid].z - ppos.z;
                    const dsq = dx * dx + dz * dz;
                    if (dsq < best_dsq) {
                        best_dsq   = dsq;
                        best_enemy = eid;
                        hit_x      = world.pos[eid].x;
                        hit_z      = world.pos[eid].z;
                    }
                }

                // No enemy in range — refund mana and cooldown, skip
                if (best_enemy == std.math.maxInt(u16)) {
                    self.mana += mana_costs[idx];
                    self.skill_cd[idx] = 0;
                    return false;
                }

                // Visual bolt rooted at the enemy's y so the strike visibly
                // ends on the target rather than floating above it. The mesh
                // extends upward from y=0..16 in local space.
                const bolt = world.spawn();
                const enemy_y = world.pos[best_enemy].y;
                world.pos[bolt]      = Vec3{ .x = hit_x, .y = enemy_y, .z = hit_z };
                world.mesh_id[bolt]  = 7;
                world.scale[bolt]    = 1.0;
                world.team[bolt]     = 10;
                world.hp[bolt]       = 0.45; // lifetime seconds
                world.hp_max[bolt]   = 0.45;
                world.fx_flags[bolt] = 0;
                world.rot_y[bolt]    = 0;
                world.radius[bolt]   = 0.1;

                // Spell damage with crit roll. Lightning is a spell, so both
                // damage_pct and spell_damage_pct apply.
                var dmg = (BASE_LIGHTNING_DMG + self.bonuses.damage_flat) *
                    (1.0 + self.bonuses.damage_pct + self.bonuses.spell_damage_pct);
                if (crit_roll_unit() < self.bonuses.crit_chance_pct) {
                    dmg *= 1.5 + self.bonuses.crit_damage_pct;
                }
                world.hp[best_enemy] -= dmg;
                if (world.hp[best_enemy] <= 0) {
                    const cfg = @import("enemy_config.zig").get_by_mesh(world.mesh_id[best_enemy]);
                    self.on_kill(if (cfg) |c| c.xp_reward else 10);
                    world.despawn(best_enemy);
                }
            },
            else => {},
        }

        _ = target;
        return true;
    }

    pub fn on_kill(self: *Player, xp_gain: u32) void {
        const scaled = @as(f32, @floatFromInt(xp_gain)) * (1.0 + self.bonuses.xp_gain_pct);
        self.xp += @as(u32, @intFromFloat(@max(0, scaled)));
        const xp_threshold = @as(u32, self.level) * 100;
        if (self.xp >= xp_threshold) {
            self.xp -= xp_threshold;
            self.level += 1;
        }
    }
};
