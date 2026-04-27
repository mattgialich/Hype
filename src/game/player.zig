// Player system — touch input → movement, skills, camera follow

const std  = @import("std");
const Vec2 = @import("../math/vec.zig").Vec2;
const Vec3 = @import("../math/vec.zig").Vec3;
const World = @import("entity.zig").World;
const EntityId = @import("entity.zig").EntityId;
const SkillBonuses = @import("skill_bonuses.zig").SkillBonuses;
const renderer_mod = @import("../renderer/metal.zig");

pub const PLAYER_SPEED: f32 = 10.0; // units/sec
pub const PLAYER_RADIUS: f32 = 0.4;
pub const BASE_HP_MAX:   f32 = 200;
pub const BASE_MANA_MAX: f32 = 100;
pub const BASE_MANA_REGEN: f32 = 5.0; // MP/sec

// ── Per-spell base values ────────────────────────────────────────────────────
// The damage / cost / cooldown / aoe before any modifiers (skill tree, spell
// level). Order matches the Skill enum: fireball, lightning, ice_nova, dash.
pub const BASE_LIGHTNING_DMG:    f32 = 30;
pub const BASE_FIREBALL_DMG:     f32 = 22;   // per-enemy hit; AoE compensates
pub const BASE_FIREBALL_RADIUS:  f32 = 4.0;  // metres
pub const BASE_MANA_COSTS = [4]f32{ 30, 15, 35, 10 };  // fireball, lightning, ice_nova, dash
pub const BASE_COOLDOWNS  = [4]f32{ 1.2, 0.0, 5.0, 2.0 };

// ── Spell level system ───────────────────────────────────────────────────────
// Each spell tracks its own XP and level (1..SPELL_MAX_LEVEL). Spell XP is
// accumulated as damage dealt with that spell. Level scales the spell's intrinsic
// power; skill-tree bonuses still apply on top. Two progression axes (player
// level + per-spell level) keep the late game varied: a player who grinds with
// only one spell maxes that spell fast but the others stay low.
pub const SPELL_MAX_LEVEL:             u8  = 10;
pub const SPELL_LEVEL_DMG_PCT:         f32 = 0.20;  // +20%/lvl on base damage
pub const SPELL_LEVEL_MANA_REDUCE_PCT: f32 = 0.03;  // -3%/lvl mana cost
pub const SPELL_LEVEL_CD_REDUCE_PCT:   f32 = 0.02;  // -2%/lvl cooldown
pub const SPELL_LEVEL_AOE_PCT:         f32 = 0.05;  // +5%/lvl aoe radius

// XP-to-next-level table. Threshold[L-1] is the spell-XP needed to go from L → L+1.
// Spell XP = damage dealt rounded down. Total to max level 10: sum = 9000 dmg.
const SPELL_XP_THRESHOLDS = [9]u32{
    200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800,
};

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

    // Per-spell level progression (independent of player level).
    spell_level: [4]u8  = [_]u8{1}  ** 4,
    spell_xp:    [4]u32 = [_]u32{0} ** 4,

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

    // ── Spell-level multipliers ──────────────────────────────────────────────
    // All read spell_level[idx] - 1 as the "level above 1" so a level-1 spell
    // gets a 1.0× multiplier (no scaling). Saturating max() floor keeps mana /
    // cooldown reductions from going below half their base — late-game spells
    // are stronger but never trivialise the resource cost.

    inline fn lvl_above_one(self: *const Player, idx: usize) f32 {
        return @as(f32, @floatFromInt(self.spell_level[idx] - 1));
    }

    pub fn spell_dmg_mult(self: *const Player, idx: usize) f32 {
        return 1.0 + lvl_above_one(self, idx) * SPELL_LEVEL_DMG_PCT;
    }

    pub fn spell_mana_cost(self: *const Player, idx: usize) f32 {
        const reduction = lvl_above_one(self, idx) * SPELL_LEVEL_MANA_REDUCE_PCT;
        return BASE_MANA_COSTS[idx] * @max(0.5, 1.0 - reduction);
    }

    pub fn spell_cooldown(self: *const Player, idx: usize) f32 {
        const reduction = lvl_above_one(self, idx) * SPELL_LEVEL_CD_REDUCE_PCT;
        return BASE_COOLDOWNS[idx] * @max(0.5, 1.0 - reduction);
    }

    pub fn spell_aoe_mult(self: *const Player, idx: usize) f32 {
        return 1.0 + lvl_above_one(self, idx) * SPELL_LEVEL_AOE_PCT;
    }

    // Award spell XP after a successful hit. Damage dealt → spell XP (rounded).
    // Auto-levels the spell while the threshold is met. Cap at SPELL_MAX_LEVEL.
    pub fn add_spell_xp(self: *Player, skill: Skill, dmg_dealt: f32) void {
        if (dmg_dealt < 1.0) return;
        const idx = @intFromEnum(skill);
        if (self.spell_level[idx] >= SPELL_MAX_LEVEL) return;
        self.spell_xp[idx] += @as(u32, @intFromFloat(@max(0, dmg_dealt)));
        while (self.spell_level[idx] < SPELL_MAX_LEVEL) {
            const threshold = SPELL_XP_THRESHOLDS[self.spell_level[idx] - 1];
            if (self.spell_xp[idx] < threshold) break;
            self.spell_xp[idx] -= threshold;
            self.spell_level[idx] += 1;
        }
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

        // Spell level reduces both mana cost and cooldown — the per-spell
        // helpers honour the SPELL_LEVEL_*_REDUCE_PCT constants and floor at 50%.
        const mana_cost = self.spell_mana_cost(idx);
        if (self.mana < mana_cost) return false;
        self.mana -= mana_cost;

        const cd_base = self.spell_cooldown(idx);
        const cd_mult = @max(0.1, 1.0 - self.bonuses.cast_speed_pct - self.bonuses.cooldown_pct);
        self.skill_cd[idx] = cd_base * cd_mult;

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
                    self.mana += mana_cost;
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

                // Impact ring — flat disc that expands and fades at the strike
                // point. Mesh id 28 is the ring; main.zig animates it via the
                // hp-as-lifetime convention and the shader scales it from uv.x.
                const ring = world.spawn();
                world.pos[ring]      = Vec3{ .x = hit_x, .y = enemy_y + 0.05, .z = hit_z };
                world.mesh_id[ring]  = 28;
                world.scale[ring]    = 1.0;
                world.team[ring]     = 10;
                world.hp[ring]       = 0.45;
                world.hp_max[ring]   = 0.45;
                world.fx_flags[ring] = 0;
                world.rot_y[ring]    = 0;
                world.radius[ring]   = 0.1;

                // Request a lightning particle burst at the strike point.
                // main.zig drains the mailbox each frame.
                @import("../renderer/particles.zig").pending_burst = .{
                    .kind = .lightning,
                    .pos  = Vec3{ .x = hit_x, .y = enemy_y, .z = hit_z },
                };

                // Spell damage with crit roll. Lightning is a spell, so both
                // damage_pct and spell_damage_pct apply. Spell-level multiplier
                // boosts the base damage BEFORE the global skill-tree percentages
                // so the two scaling axes compound properly (multiplicative).
                const spell_mult = self.spell_dmg_mult(idx);
                var dmg = (BASE_LIGHTNING_DMG * spell_mult + self.bonuses.damage_flat) *
                    (1.0 + self.bonuses.damage_pct + self.bonuses.spell_damage_pct);
                var was_crit = false;
                if (crit_roll_unit() < self.bonuses.crit_chance_pct) {
                    dmg *= 1.5 + self.bonuses.crit_damage_pct;
                    was_crit = true;
                }
                world.hp[best_enemy] -= dmg;
                self.add_spell_xp(skill, dmg);
                // Crits get a longer red flash and bigger camera kick.
                const flash_t: f32 = if (was_crit) 0.28 else 0.18;
                const kick_t:  f32 = if (was_crit) 0.40 else 0.18;
                world.hit_flash[best_enemy] = flash_t;
                renderer_mod.pending_kick = @max(renderer_mod.pending_kick, kick_t);
                // Outward knockback from caster + tiny upward bounce
                {
                    const e_pos = world.pos[best_enemy];
                    const c_pos = world.pos[self.entity];
                    var kx = e_pos.x - c_pos.x;
                    var kz = e_pos.z - c_pos.z;
                    const klen = std.math.sqrt(kx * kx + kz * kz);
                    if (klen > 0.01) { kx /= klen; kz /= klen; }
                    world.vel[best_enemy].x += kx * 6.0;
                    world.vel[best_enemy].z += kz * 6.0;
                    world.vel[best_enemy].y += 4.0;
                }
                if (world.hp[best_enemy] <= 0 and world.death_t[best_enemy] == 0) {
                    const cfg = @import("enemy_config.zig").get_by_mesh(world.mesh_id[best_enemy]);
                    self.on_kill(if (cfg) |c| c.xp_reward else 10);
                    // Mark as dying corpse — main.zig animates the fall, AI skips them.
                    // team=99 takes the entity out of "team==1 enemy" iteration filters.
                    world.death_t[best_enemy] = 0.001;
                    world.team[best_enemy]    = 99;
                    world.vel[best_enemy].y   = 6.0;     // pop upward then fall
                    // Stronger camera kick for kills.
                    renderer_mod.pending_kick = @max(renderer_mod.pending_kick, 0.45);
                    // Replace the lightning burst with a more dramatic death burst.
                    @import("../renderer/particles.zig").pending_burst = .{
                        .kind = .death_burst,
                        .pos  = world.pos[best_enemy],
                    };
                }
            },
            .fireball => {
                // AoE explosion at the target Vec3. Hits every enemy within the
                // (level-scaled) radius. Each enemy rolls crit independently so
                // a fireball into a pack can have a couple of crit-flagged hits.
                const MAX_E = @import("entity.zig").MAX_ENTITIES;
                const radius = BASE_FIREBALL_RADIUS * self.spell_aoe_mult(idx);
                const radius_sq = radius * radius;
                const spell_mult = self.spell_dmg_mult(idx);
                const base_dmg = (BASE_FIREBALL_DMG * spell_mult + self.bonuses.damage_flat) *
                    (1.0 + self.bonuses.damage_pct + self.bonuses.spell_damage_pct);

                // Visual impact ring at the explosion point — reuses mesh 28
                // (the lightning impact ring) which the shader already animates
                // as an expanding disc tied to its hp-as-lifetime.
                const ring = world.spawn();
                world.pos[ring]      = Vec3{ .x = target.x, .y = 0.05, .z = target.z };
                world.mesh_id[ring]  = 28;
                world.scale[ring]    = radius * 0.5;
                world.team[ring]     = 10;
                world.hp[ring]       = 0.5;
                world.hp_max[ring]   = 0.5;
                world.fx_flags[ring] = 0;
                world.rot_y[ring]    = 0;
                world.radius[ring]   = 0.1;

                // Particle burst at the impact point — main.zig drains the
                // single-slot mailbox each frame; we'll over-write it for the
                // most recent kill below if we get one.
                @import("../renderer/particles.zig").pending_burst = .{
                    .kind = .fire,
                    .pos  = Vec3{ .x = target.x, .y = 0.5, .z = target.z },
                };

                var any_hit = false;
                var total_dmg_dealt: f32 = 0;
                var killed_pos: Vec3 = Vec3.zero;
                var any_kill = false;
                for (0..MAX_E) |i| {
                    const eid: u16 = @intCast(i);
                    if (!world.alive[eid] or world.team[eid] != 1) continue;
                    const ex = world.pos[eid].x - target.x;
                    const ez = world.pos[eid].z - target.z;
                    const dsq = ex * ex + ez * ez;
                    if (dsq > radius_sq) continue;

                    var dmg = base_dmg;
                    var was_crit = false;
                    if (crit_roll_unit() < self.bonuses.crit_chance_pct) {
                        dmg *= 1.5 + self.bonuses.crit_damage_pct;
                        was_crit = true;
                    }
                    world.hp[eid] -= dmg;
                    total_dmg_dealt += dmg;
                    any_hit = true;

                    const flash_t: f32 = if (was_crit) 0.28 else 0.18;
                    world.hit_flash[eid] = flash_t;

                    // Outward knockback from explosion centre, plus a pop up.
                    const klen = std.math.sqrt(dsq);
                    var kx: f32 = 0; var kz: f32 = 0;
                    if (klen > 0.01) { kx = ex / klen; kz = ez / klen; }
                    world.vel[eid].x += kx * 5.0;
                    world.vel[eid].z += kz * 5.0;
                    world.vel[eid].y += 3.0;

                    if (world.hp[eid] <= 0 and world.death_t[eid] == 0) {
                        const cfg = @import("enemy_config.zig").get_by_mesh(world.mesh_id[eid]);
                        self.on_kill(if (cfg) |c| c.xp_reward else 10);
                        world.death_t[eid] = 0.001;
                        world.team[eid]    = 99;
                        world.vel[eid].y   = 6.0;
                        any_kill   = true;
                        killed_pos = world.pos[eid];
                    }
                }

                if (any_hit) {
                    self.add_spell_xp(skill, total_dmg_dealt);
                    const kick_t: f32 = if (any_kill) 0.45 else 0.30;
                    renderer_mod.pending_kick = @max(renderer_mod.pending_kick, kick_t);
                    if (any_kill) {
                        @import("../renderer/particles.zig").pending_burst = .{
                            .kind = .death_burst,
                            .pos  = killed_pos,
                        };
                    }
                } else {
                    // Whiffed — refund partial mana so the player isn't punished
                    // for tapping near no enemies.
                    self.mana += mana_cost * 0.5;
                }
            },
            else => {
                // ice_nova and dash not yet implemented — refund mana + cd so
                // the player isn't penalised for misclicking on an unwired skill.
                self.mana += mana_cost;
                self.skill_cd[idx] = 0;
                return false;
            },
        }

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
