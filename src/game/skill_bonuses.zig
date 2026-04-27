// Byte-exact 64-byte contract between Swift skill tree and Zig gameplay.
// Swift parses node text + keystone names, sums into this struct, and pushes
// it via game_set_skill_bonuses. Zig reads it from player.bonuses.
//
// IMPORTANT: changing the layout breaks the Swift mirror — update both sides.

pub const SkillBonuses = extern struct {
    damage_flat:      f32 = 0, // 0
    damage_pct:       f32 = 0, // 4
    spell_damage_pct: f32 = 0, // 8
    cast_speed_pct:   f32 = 0, // 12
    crit_chance_pct:  f32 = 0, // 16
    crit_damage_pct:  f32 = 0, // 20
    hp_flat:          f32 = 0, // 24
    hp_pct:           f32 = 0, // 28
    armour_pct:       f32 = 0, // 32
    dmg_reduce_pct:   f32 = 0, // 36
    move_speed_pct:   f32 = 0, // 40
    mana_flat:        f32 = 0, // 44
    mana_pct:         f32 = 0, // 48
    mana_regen_pct:   f32 = 0, // 52
    cooldown_pct:     f32 = 0, // 56
    xp_gain_pct:      f32 = 0, // 60
};

comptime {
    if (@sizeOf(SkillBonuses) != 64) @compileError("SkillBonuses must be 64 bytes");
}
