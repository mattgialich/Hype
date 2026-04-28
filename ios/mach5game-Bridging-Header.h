// Bridging header — exposes Zig's exported C symbols to Swift.
// Add this file to your Xcode target's "Objective-C Bridging Header" setting.

#pragma once
#include <stdint.h>
#include <stdbool.h>

// Called once on launch
void game_init(void);

// Called every frame — dt in seconds
void game_update(float dt);

// Writes FrameUniforms into out_ptr (caller allocates kUniformStride bytes)
void game_get_frame_uniforms(float aspect, float screen_w, float screen_h, uint8_t* out_ptr);

// Writes DrawCall array into buf; returns number of draw calls
uint32_t game_fill_draws(uint8_t* buf, uint32_t max_bytes);

// Returns pointer to emitter array and fills out_count
const uint8_t* game_get_emitters(uint32_t* out_count);

// Touch: world-space XZ coords, active=false to release
void game_touch_move(float world_x, float world_z, bool active);

// Trigger a skill toward world-space target
void game_touch_skill(uint8_t skill_idx, float world_x, float world_z);

// Player HP, mana, and XP fraction (0..1) for HUD
void game_get_player_stats(float* out_hp, float* out_hp_max,
                            float* out_mana, float* out_mana_max,
                            float* out_xp_frac);

// Player level (1-based)
uint32_t game_get_player_level(void);

// Enemy labels: fills buf with count × 16-byte EnemyLabel entries
// Layout per entry: float world_x, float world_y, float world_z,
//                   uint8 level, uint8 name_idx, uint8 pad[2]
void game_get_enemy_labels(uint8_t* buf, uint32_t* out_count);

// Returns 1 if the player is within ~4.5 m of the zone portal — Swift polls this
// each frame to decide when to surface the destination-map UI.
uint32_t game_player_at_portal(void);

// Push parsed skill-tree bonuses to Zig. buf must point to a 64-byte
// SkillBonuses struct: 16 × float in declaration order from skill_bonuses.zig.
void game_set_skill_bonuses(const uint8_t* buf);

// Switch active gameplay zone. zone_id: 0=forest, 1=desert, 2=isles.
// Updates the boundary clamp and any zone-aware logic in game_update.
void game_set_zone(uint32_t zone_id);

// Per-spell progression for the HUD. Fills buf with 4 × 12-byte SpellState
// entries (level, xp, xp_to_next) — order matches the 4 hotbar slots:
// 0=fireball, 1=lightning, 2=ice_nova, 3=dash.
void game_get_spell_state(uint8_t* buf);

// Player world position (used by the travel banner to confirm game_set_zone
// actually teleported the player — if the static lib is stale these stay at
// the pre-tap position instead of jumping to origin / Lantern Hold).
void game_get_player_pos(float* out_x, float* out_y, float* out_z);

// Current zone id (0=forest, 1=desert, 2=isles). Swift queries after
// game_set_zone to drive per-zone UI like the MTKView clear color.
uint32_t game_get_zone(void);
