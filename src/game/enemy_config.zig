// enemy_config.zig — enemy type definitions.
// Edit this file to tune all enemy stats without touching game logic.
//
// When adding a new enemy type:
//   1. Append an EnemyType entry to the `types` array below.
//   2. Add the matching name string to kEnemyNames in GameViewController.swift
//      at the same array index (name_idx).

pub const EnemyType = struct {
    mesh_id:   u16,
    name_idx:  u8,    // matches kEnemyNames index in GameViewController.swift
    level:     u8,
    hp_max:    f32,
    damage:    f32,   // damage dealt per melee hit to the player
    xp_reward: u32,   // XP awarded to player on kill
};

// ── Enemy Roster ─────────────────────────────────────────────────────────────
// name_idx must match the position in kEnemyNames (GameViewController.swift).
// ┌─────────────┬──────────┬───────┬──────┬────────┬───────────┐
// │   mesh_id   │ name_idx │ level │  hp  │ damage │ xp_reward │
// └─────────────┴──────────┴───────┴──────┴────────┴───────────┘
pub const types = [_]EnemyType{
    .{ .mesh_id = 3, .name_idx = 0, .level = 1, .hp_max = 80, .damage = 12, .xp_reward = 25 },
};

pub fn get_by_mesh(mesh_id: u16) ?*const EnemyType {
    for (&types) |*t| {
        if (t.mesh_id == mesh_id) return t;
    }
    return null;
}
