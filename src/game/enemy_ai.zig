// enemy_ai.zig — enemy behavior state machine
//
// States:  0=patrol  1=alert  2=chase  3=regroup
// Types:   mesh_id=3 → Gargoyle (fast flyer, swoops player)
//
// Adding a new enemy type:
//   1. Write a tick_<type>() function following the gargoyle pattern
//   2. Add `mesh_id => tick_<type>(...)` in EnemyAI.update()
//   3. Spawn entities with the new mesh_id and call enemy_ai.register()

const std          = @import("std");
const Vec3         = @import("../math/vec.zig").Vec3;
const World        = @import("entity.zig").World;
const EntityId     = @import("entity.zig").EntityId;
const enemy_config = @import("enemy_config.zig");

const MAX_E = @import("entity.zig").MAX_ENTITIES;

// Multiplier applied to all melee damage dealt to the player. Set by main.zig
// from player.bonuses (armour + dmg_reduce) when skill bonuses change.
pub var player_dmg_taken_mult: f32 = 1.0;

pub const PATROL  : u8 = 0;
pub const ALERT   : u8 = 1;
pub const CHASE   : u8 = 2;
pub const REGROUP : u8 = 3;

pub const EnemyAI = struct {
    state : [MAX_E]u8   = [_]u8{PATROL}    ** MAX_E,
    timer : [MAX_E]f32  = [_]f32{0}        ** MAX_E,
    home  : [MAX_E]Vec3 = [_]Vec3{Vec3.zero} ** MAX_E,

    // Call once when an enemy entity is spawned.
    pub fn register(self: *EnemyAI, id: EntityId, home_pos: Vec3) void {
        self.state[id] = PATROL;
        self.timer[id] = 0;
        self.home[id]  = home_pos;
    }

    pub fn update(self: *EnemyAI, world: *World, player_id: EntityId, dt: f32, t: f32) void {
        const pp = world.pos[player_id];

        // Per-entity behavior tick (dispatch by mesh_id)
        for (0..MAX_E) |i| {
            const id: u16 = @intCast(i);
            if (!world.alive[id] or world.team[id] != 1) continue;
            switch (world.mesh_id[id]) {
                3  => tick_gargoyle(self, world, id, player_id, pp, dt, t),
                25 => tick_wisp    (self, world, id, player_id, pp, dt, t),
                26 => tick_ent     (self, world, id, player_id, pp, dt, t),
                27 => tick_knight  (self, world, id, player_id, pp, dt, t),
                else => {},
            }
        }

        // Separation pass: push enemies apart so they don't stack on top of each other.
        // O(n²) over enemies only — with few enemies this is cheap.
        for (0..MAX_E) |i| {
            const a: u16 = @intCast(i);
            if (!world.alive[a] or world.team[a] != 1) continue;
            for (i + 1..MAX_E) |j| {
                const b: u16 = @intCast(j);
                if (!world.alive[b] or world.team[b] != 1) continue;
                const dx  = world.pos[a].x - world.pos[b].x;
                const dz  = world.pos[a].z - world.pos[b].z;
                const dsq = dx * dx + dz * dz;
                const MIN_SEP: f32 = 2.4;
                if (dsq < MIN_SEP * MIN_SEP and dsq > 0.001) {
                    const d    = std.math.sqrt(dsq);
                    const push = (MIN_SEP - d) * 3.5 * dt;
                    world.pos[a].x += (dx / d) * push;
                    world.pos[a].z += (dz / d) * push;
                    world.pos[b].x -= (dx / d) * push;
                    world.pos[b].z -= (dz / d) * push;
                }
            }
        }
    }

    // ── Gargoyle ─────────────────────────────────────────────────────────────
    // Fast flyer.  Orbits home while idle, swoops the player when aggroed,
    // gives up and reggroups if the player runs too far.
    fn tick_gargoyle(self: *EnemyAI, world: *World, id: EntityId,
                     player_id: EntityId, pp: Vec3, dt: f32, t: f32) void
    {
        const AGGRO_R    : f32 = 18.0; // enter alert when player is this close
        const LEASH_R    : f32 = 38.0; // give up chase when this far from home
        const MELEE_R    : f32 = 1.8;  // stop and lunge-pause at this distance
        const CHASE_SPD  : f32 = 5.5;
        const PATROL_SPD : f32 = 1.2;

        // Hover bob — always active regardless of state
        const phase = @as(f32, @floatFromInt(id)) * 1.3;
        world.pos[id].y = 1.5 + std.math.sin(t * 2.5 + phase) * 0.18;
        world.vel[id].y = 0;

        const dx      = pp.x - world.pos[id].x;
        const dz      = pp.z - world.pos[id].z;
        const dsq     = dx * dx + dz * dz;

        const hdx     = self.home[id].x - world.pos[id].x;
        const hdz     = self.home[id].z - world.pos[id].z;
        const home_dsq = hdx * hdx + hdz * hdz;

        switch (self.state[id]) {

            PATROL => {
                // Orbit home in a lazy circle unique to each gargoyle
                const idf        = @as(f32, @floatFromInt(id));
                const orbit_r    = 2.0 + std.math.sin(idf * 3.7) * 1.0;
                const orbit_spd  = 0.50 + @as(f32, @floatFromInt(id % 5)) * 0.09;
                const angle      = t * orbit_spd + idf * 2.09;
                const tx  = self.home[id].x + std.math.cos(angle) * orbit_r;
                const tz  = self.home[id].z + std.math.sin(angle) * orbit_r;
                const wdx = tx - world.pos[id].x;
                const wdz = tz - world.pos[id].z;
                const wd  = std.math.sqrt(wdx * wdx + wdz * wdz);
                if (wd > 0.3) {
                    world.vel[id].x = (wdx / wd) * PATROL_SPD;
                    world.vel[id].z = (wdz / wd) * PATROL_SPD;
                    world.rot_y[id] = std.math.atan2(wdx / wd, wdz / wd);
                }
                // Aggro: player wandered close
                if (dsq < AGGRO_R * AGGRO_R) {
                    self.state[id] = ALERT;
                    self.timer[id] = 0.40; // wind-up pause length
                    world.vel[id]  = Vec3.zero;
                }
            },

            ALERT => {
                // Stop, face player, wind up for 0.4 s then lunge
                world.vel[id].x *= (1.0 - dt * 10.0);
                world.vel[id].z *= (1.0 - dt * 10.0);
                if (dsq > 0.01) {
                    const d2 = std.math.sqrt(dsq);
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
                self.timer[id] -= dt;
                if (self.timer[id] <= 0) self.state[id] = CHASE;
            },

            CHASE => {
                if (home_dsq > LEASH_R * LEASH_R) {
                    // Ran too far — give up and go home
                    self.state[id] = REGROUP;
                    world.vel[id]  = Vec3.zero;
                } else if (dsq < MELEE_R * MELEE_R) {
                    // Melee hit — deal config damage to player once per stagger
                    if (enemy_config.get_by_mesh(world.mesh_id[id])) |cfg| {
                        world.hp[player_id] -= cfg.damage * player_dmg_taken_mult;
                    }
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = ALERT;
                    self.timer[id] = 0.45;
                } else if (dsq > 0.1) {
                    const d2 = std.math.sqrt(dsq);
                    world.vel[id].x = (dx / d2) * CHASE_SPD;
                    world.vel[id].z = (dz / d2) * CHASE_SPD;
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
            },

            REGROUP => {
                // Fly back toward home
                if (home_dsq > 2.0) {
                    const hd = std.math.sqrt(home_dsq);
                    world.vel[id].x = (hdx / hd) * PATROL_SPD * 2.0;
                    world.vel[id].z = (hdz / hd) * PATROL_SPD * 2.0;
                    world.rot_y[id] = std.math.atan2(hdx / hd, hdz / hd);
                } else {
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = PATROL;
                    self.timer[id] = 0;
                }
                // Re-aggro if player follows
                if (dsq < AGGRO_R * AGGRO_R) {
                    self.state[id] = CHASE;
                }
            },

            else => {},
        }
    }

    // ── Forest Wisp (mesh_id 25) ─────────────────────────────────────────────
    // Floats high, very fast, low HP — harasser archetype. Closer aggro range,
    // smaller melee distance, faster speed than gargoyle.
    fn tick_wisp(self: *EnemyAI, world: *World, id: EntityId,
                 player_id: EntityId, pp: Vec3, dt: f32, t: f32) void
    {
        const AGGRO_R    : f32 = 14.0;
        const LEASH_R    : f32 = 32.0;
        const MELEE_R    : f32 = 1.5;
        const CHASE_SPD  : f32 = 8.5;
        const PATROL_SPD : f32 = 2.2;

        // Higher hover than gargoyle, with bigger bob amplitude
        const phase = @as(f32, @floatFromInt(id)) * 1.7;
        world.pos[id].y = 2.5 + std.math.sin(t * 3.2 + phase) * 0.30;
        world.vel[id].y = 0;

        const dx  = pp.x - world.pos[id].x;
        const dz  = pp.z - world.pos[id].z;
        const dsq = dx * dx + dz * dz;

        const hdx = self.home[id].x - world.pos[id].x;
        const hdz = self.home[id].z - world.pos[id].z;
        const home_dsq = hdx * hdx + hdz * hdz;

        switch (self.state[id]) {
            PATROL => {
                // Tighter, faster orbit unique per wisp
                const idf       = @as(f32, @floatFromInt(id));
                const orbit_r   = 1.4 + std.math.sin(idf * 4.1) * 0.7;
                const orbit_spd = 0.85 + @as(f32, @floatFromInt(id % 5)) * 0.12;
                const angle     = t * orbit_spd + idf * 1.71;
                const tx  = self.home[id].x + std.math.cos(angle) * orbit_r;
                const tz  = self.home[id].z + std.math.sin(angle) * orbit_r;
                const wdx = tx - world.pos[id].x;
                const wdz = tz - world.pos[id].z;
                const wd  = std.math.sqrt(wdx * wdx + wdz * wdz);
                if (wd > 0.2) {
                    world.vel[id].x = (wdx / wd) * PATROL_SPD;
                    world.vel[id].z = (wdz / wd) * PATROL_SPD;
                    world.rot_y[id] = std.math.atan2(wdx / wd, wdz / wd);
                }
                if (dsq < AGGRO_R * AGGRO_R) {
                    self.state[id] = ALERT;
                    self.timer[id] = 0.20; // shorter wind-up than gargoyle
                    world.vel[id]  = Vec3.zero;
                }
            },
            ALERT => {
                world.vel[id].x *= (1.0 - dt * 12.0);
                world.vel[id].z *= (1.0 - dt * 12.0);
                if (dsq > 0.01) {
                    const d2 = std.math.sqrt(dsq);
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
                self.timer[id] -= dt;
                if (self.timer[id] <= 0) self.state[id] = CHASE;
            },
            CHASE => {
                if (home_dsq > LEASH_R * LEASH_R) {
                    self.state[id] = REGROUP;
                    world.vel[id]  = Vec3.zero;
                } else if (dsq < MELEE_R * MELEE_R) {
                    if (enemy_config.get_by_mesh(world.mesh_id[id])) |cfg| {
                        world.hp[player_id] -= cfg.damage * player_dmg_taken_mult;
                    }
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = ALERT;
                    self.timer[id] = 0.30;
                } else if (dsq > 0.1) {
                    const d2 = std.math.sqrt(dsq);
                    world.vel[id].x = (dx / d2) * CHASE_SPD;
                    world.vel[id].z = (dz / d2) * CHASE_SPD;
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
            },
            REGROUP => {
                if (home_dsq > 2.0) {
                    const hd = std.math.sqrt(home_dsq);
                    world.vel[id].x = (hdx / hd) * PATROL_SPD * 2.0;
                    world.vel[id].z = (hdz / hd) * PATROL_SPD * 2.0;
                    world.rot_y[id] = std.math.atan2(hdx / hd, hdz / hd);
                } else {
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = PATROL;
                    self.timer[id] = 0;
                }
                if (dsq < AGGRO_R * AGGRO_R) self.state[id] = CHASE;
            },
            else => {},
        }
    }

    // ── Tree Ent (mesh_id 26) ────────────────────────────────────────────────
    // Slow heavy tank. Stays grounded, large aggro and melee range, big damage.
    // Doesn't bother orbiting in patrol — drifts slowly around home.
    fn tick_ent(self: *EnemyAI, world: *World, id: EntityId,
                player_id: EntityId, pp: Vec3, dt: f32, t: f32) void
    {
        const AGGRO_R    : f32 = 22.0;
        const LEASH_R    : f32 = 50.0;
        const MELEE_R    : f32 = 3.2;
        const CHASE_SPD  : f32 = 2.6;
        const PATROL_SPD : f32 = 0.5;

        // Grounded
        world.pos[id].y = 0;
        world.vel[id].y = 0;

        const dx  = pp.x - world.pos[id].x;
        const dz  = pp.z - world.pos[id].z;
        const dsq = dx * dx + dz * dz;

        const hdx = self.home[id].x - world.pos[id].x;
        const hdz = self.home[id].z - world.pos[id].z;
        const home_dsq = hdx * hdx + hdz * hdz;

        switch (self.state[id]) {
            PATROL => {
                // Slow drift in lazy figure-8 around home
                const idf   = @as(f32, @floatFromInt(id));
                const angle = t * 0.18 + idf * 0.7;
                const tx = self.home[id].x + std.math.cos(angle) * 2.5;
                const tz = self.home[id].z + std.math.sin(angle * 2.0) * 1.8;
                const wdx = tx - world.pos[id].x;
                const wdz = tz - world.pos[id].z;
                const wd  = std.math.sqrt(wdx * wdx + wdz * wdz);
                if (wd > 0.4) {
                    world.vel[id].x = (wdx / wd) * PATROL_SPD;
                    world.vel[id].z = (wdz / wd) * PATROL_SPD;
                    world.rot_y[id] = std.math.atan2(wdx / wd, wdz / wd);
                }
                if (dsq < AGGRO_R * AGGRO_R) {
                    self.state[id] = ALERT;
                    self.timer[id] = 0.85;   // long wind-up — slow tank
                    world.vel[id]  = Vec3.zero;
                }
            },
            ALERT => {
                world.vel[id].x *= (1.0 - dt * 8.0);
                world.vel[id].z *= (1.0 - dt * 8.0);
                if (dsq > 0.01) {
                    const d2 = std.math.sqrt(dsq);
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
                self.timer[id] -= dt;
                if (self.timer[id] <= 0) self.state[id] = CHASE;
            },
            CHASE => {
                if (home_dsq > LEASH_R * LEASH_R) {
                    self.state[id] = REGROUP;
                    world.vel[id]  = Vec3.zero;
                } else if (dsq < MELEE_R * MELEE_R) {
                    if (enemy_config.get_by_mesh(world.mesh_id[id])) |cfg| {
                        world.hp[player_id] -= cfg.damage * player_dmg_taken_mult;
                    }
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = ALERT;
                    self.timer[id] = 1.10;   // slow recovery
                } else if (dsq > 0.1) {
                    const d2 = std.math.sqrt(dsq);
                    world.vel[id].x = (dx / d2) * CHASE_SPD;
                    world.vel[id].z = (dz / d2) * CHASE_SPD;
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
            },
            REGROUP => {
                if (home_dsq > 2.0) {
                    const hd = std.math.sqrt(home_dsq);
                    world.vel[id].x = (hdx / hd) * PATROL_SPD * 1.5;
                    world.vel[id].z = (hdz / hd) * PATROL_SPD * 1.5;
                    world.rot_y[id] = std.math.atan2(hdx / hd, hdz / hd);
                } else {
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = PATROL;
                    self.timer[id] = 0;
                }
                if (dsq < AGGRO_R * AGGRO_R) self.state[id] = CHASE;
            },
            else => {},
        }
    }

    // ── Skeleton Knight (mesh_id 27) ─────────────────────────────────────────
    // Medium speed, medium HP, balanced melee. Patrols a steady straight-line
    // back-and-forth march (rather than orbiting) — disciplined feel.
    fn tick_knight(self: *EnemyAI, world: *World, id: EntityId,
                   player_id: EntityId, pp: Vec3, dt: f32, t: f32) void
    {
        const AGGRO_R    : f32 = 17.0;
        const LEASH_R    : f32 = 42.0;
        const MELEE_R    : f32 = 2.2;
        const CHASE_SPD  : f32 = 4.2;
        const PATROL_SPD : f32 = 1.4;

        world.pos[id].y = 0;
        world.vel[id].y = 0;

        const dx  = pp.x - world.pos[id].x;
        const dz  = pp.z - world.pos[id].z;
        const dsq = dx * dx + dz * dz;

        const hdx = self.home[id].x - world.pos[id].x;
        const hdz = self.home[id].z - world.pos[id].z;
        const home_dsq = hdx * hdx + hdz * hdz;

        switch (self.state[id]) {
            PATROL => {
                // March: each knight has a fixed direction; reverses when too far from home
                const idf      = @as(f32, @floatFromInt(id));
                const heading  = idf * 1.234 + std.math.sin(t * 0.15 + idf) * 0.4;
                const dirx     = std.math.cos(heading);
                const dirz     = std.math.sin(heading);
                if (home_dsq > 25.0) {
                    // Turn back home
                    const hd = std.math.sqrt(home_dsq);
                    world.vel[id].x = (hdx / hd) * PATROL_SPD;
                    world.vel[id].z = (hdz / hd) * PATROL_SPD;
                    world.rot_y[id] = std.math.atan2(hdx / hd, hdz / hd);
                } else {
                    world.vel[id].x = dirx * PATROL_SPD;
                    world.vel[id].z = dirz * PATROL_SPD;
                    world.rot_y[id] = std.math.atan2(dirx, dirz);
                }
                if (dsq < AGGRO_R * AGGRO_R) {
                    self.state[id] = ALERT;
                    self.timer[id] = 0.55;   // mid-length wind-up
                    world.vel[id]  = Vec3.zero;
                }
            },
            ALERT => {
                world.vel[id].x *= (1.0 - dt * 10.0);
                world.vel[id].z *= (1.0 - dt * 10.0);
                if (dsq > 0.01) {
                    const d2 = std.math.sqrt(dsq);
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
                self.timer[id] -= dt;
                if (self.timer[id] <= 0) self.state[id] = CHASE;
            },
            CHASE => {
                if (home_dsq > LEASH_R * LEASH_R) {
                    self.state[id] = REGROUP;
                    world.vel[id]  = Vec3.zero;
                } else if (dsq < MELEE_R * MELEE_R) {
                    if (enemy_config.get_by_mesh(world.mesh_id[id])) |cfg| {
                        world.hp[player_id] -= cfg.damage * player_dmg_taken_mult;
                    }
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = ALERT;
                    self.timer[id] = 0.55;
                } else if (dsq > 0.1) {
                    const d2 = std.math.sqrt(dsq);
                    world.vel[id].x = (dx / d2) * CHASE_SPD;
                    world.vel[id].z = (dz / d2) * CHASE_SPD;
                    world.rot_y[id] = std.math.atan2(dx / d2, dz / d2);
                }
            },
            REGROUP => {
                if (home_dsq > 2.0) {
                    const hd = std.math.sqrt(home_dsq);
                    world.vel[id].x = (hdx / hd) * PATROL_SPD * 2.0;
                    world.vel[id].z = (hdz / hd) * PATROL_SPD * 2.0;
                    world.rot_y[id] = std.math.atan2(hdx / hd, hdz / hd);
                } else {
                    world.vel[id]  = Vec3.zero;
                    self.state[id] = PATROL;
                    self.timer[id] = 0;
                }
                if (dsq < AGGRO_R * AGGRO_R) self.state[id] = CHASE;
            },
            else => {},
        }
    }
};
