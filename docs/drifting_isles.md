# Drifting Isles — Zone 3 Design Specification

Generated 2026-04-27. Engine target: Hype / Mach5Game iOS, Metal + Zig + Swift.
Foundation doc — per-enemy and per-asset detail passes append below.

---

## §1. Biome overview

Drifting Isles is a wind-haunted archipelago of weathered islands suspended over a slow, glittering sea, with one larger island floating in the sky above the rest, tethered to its anchor below by enormous rune-graven chains. Light is the long, fading gold of a coastal late afternoon — sky breaking from amber at the horizon to a deep storm-blue at zenith, with ribbons of low mist coiling between the islands. Materials are weathered driftwood, kelp-tangled stone, sea-glass, barnacle-crust, and bioluminescent coral that brightens as the air dims. The mood is *abandonment* — boats wrecked and overgrown, idols toppled, lighthouses still burning out of habit. The third zone is the largest in the game and the densest with set-dressing. References: Skellige (Witcher 3), the Great Sea (Wind Waker), Studio Ghibli's *Castle in the Sky*, the Faroe Islands.

---

## §2. Scale & layout

| Constant         | Forest | Desert | **Drifting Isles** |
|------------------|--------|--------|--------------------|
| `MAP_RADIUS`     | 280 m  | 450 m  | **900 m**          |
| `PATH_LEN`       | 220 m  | 360 m  | **720 m**          |
| Boundary marker  | 48 monoliths @ r=275 | 64 obelisks @ r=440 | **90 kelp pillars @ r=890** (spacing 5655/90 ≈ 63 m on the rim) |
| Set-piece count  | ~2150  | ~2476  | **~5378**          |

### Required engine bumps (BLOCKING)

The Isles cannot ship under the current 4096 entity cap. Three constants must be raised to **8192** in the same commit:

| Constant      | File                           | Current | New  |
|---------------|--------------------------------|---------|------|
| `MAX_ENTITIES`| `src/game/entity.zig:8`        | 4096    | 8192 |
| `MAX_DRAW`    | `src/main.zig:707`             | 4096    | 8192 |
| `kMaxDrawCalls`| `ios/GameViewController.swift:194` | 4096 | 8192 |

ABI struct sizes are unchanged (DrawCall=88B, FrameUniforms=160B, GpuEmitter=104B, GpuParticle=64B). The change ~doubles the static `World` struct allocation in entity.zig (~1 MB before, ~2 MB after — fine on iOS).

### Path topology

Unlike the forest's single sin-curve and the desert's longer sweep, the Isles path is **island-hopping**: the player walks along each island's surface, then crosses a bridge or rune-gate to the next. The path centerline is **piecewise**, defined per island segment, not a single closed-form formula. See §2b for waypoint geometry.

---

## §2b. Island layout

Six islands (5 ground + 1 sky) plus one anchor:

| Tag | Name           | Center (x, y, z)       | Radius | y_offset | Character                                        | Connects to               |
|-----|----------------|------------------------|--------|----------|--------------------------------------------------|---------------------------|
| A   | Lantern Hold   | (0, 0, 0)              | 200 m  | 0        | Hub. Lighthouse, lantern posts, sea grass.       | B (bridge), C (rune gate) |
| B   | Whale's Spine  | (200, 0, -180)         | 180 m  | 0        | Bone fields, fossilised vertebrae, dry kelp.     | A (bridge), D (bridge)    |
| C   | Glasstop       | (-220, 0, -260)        | 170 m  | 0        | Sea-glass crystal hill, bioluminescent coral.    | A (rune gate), E (rune gate) |
| D   | The Wreck      | (60, 0, -440)          | 220 m  | 0        | Half-sunk galleon turned ruin, wreckage decor.   | B (bridge), E (rune gate) |
| E   | Skywatch       | (-120, 60, -560)       | 140 m  | **+60**  | Floating sky temple, sea-glass spires, mist.     | C (rune gate), D (rune gate), F (sky bridge) |
| F   | Far Reach      | (40, 0, -720)          | 200 m  | 0        | Portal island, lighthouse, mossy ruins.          | E (sky bridge)            |
| G   | Tether (anchor)| (-120, 0, -560)        | n/a    | 0        | Stone anchor pylon directly under Skywatch (E). One mesh, anchors the chain. | E (chain only) |

- **Bridges** (5 total): A↔B, B↔D, are short (~60 m) walkable wooden bridges. E↔F is a long (~165 m) tethered sky bridge dropping from the floating island to Far Reach.
- **Rune gates** (3 total): A↔C, C↔E, D↔E. Instant-fade teleport with a brief audio cue. Used where the gap is too wide for a bridge or crosses the y-offset boundary.
- The path the player follows is roughly: A → A's east shore (bridge) → B → B's south shore (bridge) → D → D's southwest stairwell (rune gate) → E → E's south plaza (sky bridge) → F → portal.
- **Glasstop (C)** is an optional side-loop: rune-gate from A, contains lore-rich bioluminescent assets. Not on the main path.
- **Tether (G)** is purely visual — the player cannot stand on it.

---

## §3. Palette

14-swatch palette, all linear-RGB 0..1.

| Swatch              | RGB                | Role                                                   |
|---------------------|--------------------|--------------------------------------------------------|
| `water_shallow`     | (0.30, 0.60, 0.75) | Lagoon water, between-island shallows                   |
| `water_deep`        | (0.06, 0.16, 0.32) | Open sea, deep channels (dim, almost black-blue)        |
| `foam_white`        | (0.94, 0.96, 0.98) | Surf foam, splash, breaking-wave crowns                 |
| `sand_wet`          | (0.62, 0.55, 0.42) | Beach surf zone (wetter / darker than dry sand)         |
| `beach_dune`        | (0.84, 0.78, 0.62) | Dry beach above tideline                                |
| `driftwood_grey`    | (0.45, 0.42, 0.38) | Driftwood, weathered planking, hull boards              |
| `kelp_green`        | (0.18, 0.42, 0.30) | Drift kelp, sea grass, mossy stone tint                 |
| `sail_cream`        | (0.88, 0.82, 0.66) | Tattered sail canvas, banner cloth                      |
| `accent_pearl`      | (0.95, 0.92, 0.85) | Pearl lustre, statue eyes, idol gems                    |
| `accent_coral`      | (0.92, 0.50, 0.42) | Live coral, jelly tint, signal-pyre flame core          |
| `sky_morning`       | (0.78, 0.68, 0.58) | Horizon amber → mid-sky                                 |
| `sky_storm`         | (0.18, 0.28, 0.45) | Upper sky, storm-tinted zenith                          |
| `mist_low`          | (0.82, 0.86, 0.88) | Low-hanging mist between islands                        |
| `ember_lantern`     | (0.95, 0.55, 0.18) | Lantern flame, brazier glow, lighthouse beam            |

---

## §4. Mesh-ID assignment table

Mesh IDs **67–141** (75 entries). 67–76 are enemies, 77–140 are scenery assets, 141 is the boundary kelp pillar.

| mesh_id | name                       | category   | est_tris | est_count | uBase markers       | teams |
|---------|----------------------------|------------|----------|-----------|---------------------|-------|
| 67      | reef_skitter               | enemy      | 900      | 24        | 0, 8, 49            | 1     |
| 68      | drowned_mariner            | enemy      | 1300     | 16        | 0, 8, 51, 52        | 1     |
| 69      | jelly_lantern              | enemy      | 600      | 18        | 0, 8, 53            | 1     |
| 70      | mast_serpent               | enemy      | 1200     | 6         | 0, 8, 51, 49        | 1     |
| 71      | shell_brute                | enemy      | 1500     | 8         | 0, 8, 49, 47        | 1     |
| 72      | tide_wraith                | enemy      | 700      | 12        | 0, 8, 45, 59        | 1     |
| 73      | coral_strider              | enemy      | 1000     | 14        | 0, 8, 53            | 1     |
| 74      | sky_archer                 | enemy      | 800      | 6         | 0, 8, 58            | 1     |
| 75      | barnacle_creeper           | enemy      | 850      | 14        | 0, 8, 49            | 1     |
| 76      | mirror_kraken_juvenile     | enemy      | 1100     | 4         | 0, 8, 54, 53        | 1     |
| 77      | driftwood_bridge           | bridge     | 320      | 5         | 0, 51               | 53    |
| 78      | rope_bridge                | bridge     | 240      | 4         | 0, 51, 52           | 53    |
| 79      | rune_gate_arch             | gate       | 380      | 6         | 0, 51, 53, 61       | 54    |
| 80      | plank_walkway              | bridge     | 200      | 8         | 0, 51, 49           | 53    |
| 81      | wet_sand_patch             | beach      | 120      | 130       | 48                  | 55    |
| 82      | surf_foam                  | beach      | 100      | 110       | 48, 45              | 55    |
| 83      | beach_pebble_pile          | beach      | 140      | 120       | 0, 47               | 56    |
| 84      | tide_line_decal            | beach      | 80       | 100       | 48                  | 55    |
| 85      | washed_log                 | beach      | 180      | 110       | 51                  | 53    |
| 86      | sea_shell_cluster          | beach      | 160      | 120       | 0, 49               | 56    |
| 87      | dead_jellyfish             | beach      | 140      | 100       | 0, 53               | 57    |
| 88      | beach_grass_tuft           | beach      | 120      | 130       | 0                   | 58    |
| 89      | wet_sea_cliff              | cliff      | 380      | 50        | 47                  | 59    |
| 90      | sea_arch_natural           | cliff      | 460      | 30        | 47                  | 59    |
| 91      | anchor_boulder             | cliff      | 280      | 60        | 47, 49              | 59    |
| 92      | barnacle_crust_patch       | cliff      | 100      | 80        | 49                  | 60    |
| 93      | foam_splash_rock           | cliff      | 180      | 50        | 47, 45              | 59    |
| 94      | tide_pool                  | cliff      | 200      | 40        | 47, 45, 53          | 61    |
| 95      | isolated_pillar            | cliff      | 240      | 50        | 47                  | 59    |
| 96      | weathered_outcrop          | cliff      | 320      | 60        | 47                  | 59    |
| 97      | broken_hull_section        | wreckage   | 420      | 30        | 51, 49              | 53    |
| 98      | mast_pole                  | wreckage   | 240      | 30        | 51                  | 53    |
| 99      | capstan_wheel              | wreckage   | 280      | 25        | 51                  | 53    |
| 100     | rusted_anchor              | wreckage   | 220      | 25        | 0, 49               | 60    |
| 101     | cargo_crate_open           | wreckage   | 180      | 30        | 51                  | 53    |
| 102     | sail_remnant_torn          | wreckage   | 200      | 30        | 52                  | 62    |
| 103     | rope_coil_pile             | wreckage   | 140      | 30        | 51, 52              | 53    |
| 104     | snapped_oar                | wreckage   | 120      | 25        | 51                  | 53    |
| 105     | glow_coral_branch          | biolum     | 180      | 90        | 53                  | 63    |
| 106     | jellyfish_lantern_static   | biolum     | 220      | 80        | 53, 8               | 63    |
| 107     | lantern_fish_school        | biolum     | 200      | 80        | 53, 8               | 63    |
| 108     | glow_anemone               | biolum     | 160      | 80        | 53                  | 63    |
| 109     | biolum_kelp_strand         | biolum     | 200      | 100       | 55, 53              | 64    |
| 110     | lantern_jelly_pile         | biolum     | 180      | 80        | 53                  | 63    |
| 111     | glow_pearl_cluster         | biolum     | 160      | 60        | 61, 8               | 65    |
| 112     | lit_shellfish_pile         | biolum     | 180      | 80        | 49, 53              | 65    |
| 113     | drift_kelp_thick           | kelp       | 240      | 220       | 55                  | 64    |
| 114     | drift_kelp_thin            | kelp       | 180      | 240       | 55                  | 64    |
| 115     | kelp_root_anchor           | kelp       | 200      | 200       | 55, 56              | 64    |
| 116     | sea_grass_tuft             | kelp       | 120      | 200       | 55                  | 64    |
| 117     | sea_palm_tree              | kelp       | 320      | 100       | 0, 55               | 64    |
| 118     | mangrove_tree              | kelp       | 380      | 80        | 0, 56               | 66    |
| 119     | mangrove_root_tangle       | kelp       | 280      | 100       | 0, 56               | 66    |
| 120     | sea_lily_floater           | kelp       | 140      | 80        | 0, 53               | 64    |
| 121     | whale_skull_giant          | bone       | 1100     | 4         | 0, 63, 56           | 67    |
| 122     | whale_rib_arch_isle        | bone       | 480      | 12        | 0, 63               | 67    |
| 123     | whale_vertebrae_chunk      | bone       | 240      | 30        | 0, 63               | 67    |
| 124     | fish_skeleton_dry          | bone       | 200      | 30        | 0, 63               | 67    |
| 125     | mossy_pillar_isle          | ruin       | 280      | 50        | 0, 56               | 68    |
| 126     | sea_glass_temple           | ruin       | 720      | 6         | 0, 54, 61           | 69    |
| 127     | sunken_idol_pedestal       | ruin       | 320      | 10        | 0, 56, 61, 8        | 68    |
| 128     | mossy_carved_floor         | ruin       | 220      | 40        | 0, 56               | 68    |
| 129     | weathered_obelisk_isle     | ruin       | 280      | 25        | 0, 56               | 68    |
| 130     | broken_arch_isle           | ruin       | 360      | 30        | 0, 56, 62           | 68    |
| 131     | mossy_face_relief          | ruin       | 240      | 25        | 0, 56               | 68    |
| 132     | prayer_bell_tower          | ruin       | 460      | 8         | 0, 56, 49, 8        | 68    |
| 133     | tether_chain_long          | sky        | 280      | 4         | 0, 49, 62           | 70    |
| 134     | levitating_stone           | sky        | 220      | 8         | 0, 47, 62, 59       | 71    |
| 135     | cloud_garden_patch         | sky        | 240      | 4         | 0, 59, 55           | 72    |
| 136     | wind_chime_array           | sky        | 180      | 6         | 0, 8, 58            | 70    |
| 137     | lantern_post_isle          | light      | 280      | 32        | 0, 57, 8            | 73    |
| 138     | signal_buoy_floating       | light      | 220      | 18        | 0, 57, 49, 8        | 74    |
| 139     | lighthouse_short           | light      | 580      | 4         | 0, 56, 57, 8        | 75    |
| 140     | brazier_with_pyre          | light      | 280      | 14        | 0, 57, 8            | 76    |
| 141     | kelp_pillar_titan          | boundary   | 380      | 90        | 55, 47              | 64    |

**Spawn-count totals (set-pieces):**

- Enemies (67–76): 24+16+18+6+8+12+14+6+14+4 = **122**
- Bridges & gates (77–80): 5+4+6+8 = **23**
- Beach (81–88): 130+110+120+100+110+120+100+130 = **920**
- Cliff (89–96): 50+30+60+80+50+40+50+60 = **420**
- Wreckage (97–104): 30+30+25+25+30+30+30+25 = **225**
- Biolum (105–112): 90+80+80+80+100+80+60+80 = **650**
- Kelp (113–120): 220+240+200+200+100+80+100+80 = **1220**
- Bone (121–124): 4+12+30+30 = **76**
- Ruin (125–132): 50+6+10+40+25+30+25+8 = **194**
- Sky (133–136): 4+8+4+6 = **22**
- Lights (137–140): 32+18+4+14 = **68**
- Boundary (141): **90**

**TOTAL = 4030 set-pieces.** Under the 8192 cap; 4162 headroom for transient FX, projectiles, corpses, lightning bolts, etc. (Forest peak transient FX is ~30; 10× pessimism gives 300, still leaves 3800 headroom.) Per-area density is 4030 / (π·900²) = 1.58 set-pieces / 1000 m², which is ≈ 95% of the desert's 1.66 / 1000 m² density (acceptable; isles have more open water by design).

### §4b. uBase marker shader assignments

Reserved marker set for the Isles (16 markers): 45..49, 51..59 (skipping 50=forest flame), 61..69 (skipping 60=forest portal swirl). All Metal-flavoured pseudocode below uses `mix`, `float3`, `sin/cos/fbm` — never `lerp`.

| uBase | name                | shader behaviour |
|-------|---------------------|------------------|
| 0     | default_base        | `out.color = float3(in.color.rgb);` (existing engine default) |
| 8     | generic_emissive    | `out.color = in.color.rgb * 1.6 + ember_lantern * 0.4;` (existing engine emissive) |
| 45    | water_calm          | `float wave = 0.5 + 0.5*sin(in.world_pos.x*0.05 + time*0.7); out.color = mix(water_deep, water_shallow, wave); out.color += foam_white * pow(wave, 6.0) * 0.3;` |
| 46    | water_choppy        | `float ch = fbm(in.world_pos.xz*0.07 + time*0.4); out.color = mix(water_deep, water_shallow, ch); out.color += foam_white * step(0.78, ch);` |
| 47    | wet_rock            | `float wet = 1.0 - smoothstep(0.0, 1.5, in.world_pos.y); out.color = mix(driftwood_grey*0.7, beach_dune*0.6, wet); float spec = pow(max(0.0, dot(reflect(-light, in.normal), view)), 28.0); out.color += float3(spec)*0.3*wet;` |
| 48    | wet_sand            | `out.color = mix(beach_dune, sand_wet, smoothstep(0.0, 1.0, fbm(in.uv*4.0)));` |
| 49    | barnacle_crust      | `float crust = step(0.55, fbm(in.world_pos*1.4)); out.color = mix(out.color, foam_white*0.7, crust*0.5);` |
| 51    | ship_wood           | `float grain = sin(in.uv.x*40.0)*0.05 + sin(in.uv.x*9.0)*0.1; out.color = driftwood_grey + float3(grain); out.color *= mix(0.5, 1.0, smoothstep(0.0, 1.0, fbm(in.uv*3.0)));` |
| 52    | sail_cloth          | `float ripple = sin(in.world_pos.x*0.5 + time*1.2)*0.04 + sin(in.world_pos.z*0.3 + time*0.8)*0.04; out.color = mix(sail_cream, driftwood_grey*0.6, smoothstep(0.0, 1.0, fbm(in.uv*2.0))); out.color += float3(ripple);` |
| 53    | bioluminescent      | `float pulse = 0.5 + 0.5*sin(time*1.4 + in.world_pos.y*0.3); out.color = mix(accent_coral*0.4, accent_coral, pulse); out.color += accent_coral * pulse * 0.8;` (additive emissive) |
| 54    | sea_glass           | `float fres = pow(1.0 - max(0.0, dot(in.normal, view)), 3.0); out.color = mix(water_shallow*0.5, foam_white, fres); out.color += accent_pearl * fres * 0.4;` |
| 55    | drift_kelp          | vertex perturb: `out.position.xz += sin(time*0.6 + in.world_pos.y*0.4) * 0.08;` then `out.color = mix(kelp_green*0.6, kelp_green, in.uv.y);` |
| 56    | mossy_stone         | `float moss = step(0.4, fbm(in.uv*5.0 + in.normal.y*0.6)); out.color = mix(driftwood_grey, kelp_green*0.5, moss);` |
| 57    | ember_torch         | `float flick = 0.6 + 0.4*sin(time*7.0 + in.world_pos.x*3.0); out.color = mix(ember_lantern*0.4, ember_lantern, flick); out.color += ember_lantern * flick * 1.2;` (additive emissive) |
| 58    | wind_pennant        | vertex perturb: `out.position += in.normal * sin(time*2.5 + in.world_pos.x*0.8) * 0.05;` then `out.color = mix(sail_cream, accent_coral, in.uv.y*0.4);` |
| 59    | sky_mist            | `float den = fbm(in.world_pos.xz*0.012 + time*0.03); out.color = mist_low; out.alpha = clamp(den*0.6, 0.0, 0.5);` |
| 61    | pearl_lustre        | `float fres = pow(1.0 - max(0.0, dot(in.normal, view)), 4.0); out.color = mix(accent_pearl*0.7, accent_pearl, fres); out.color += float3(fres)*0.3;` |
| 62    | cracked_obsidian    | `out.color = float3(0.04, 0.04, 0.06); float3 r = reflect(-view, in.normal); out.color += sample_skybox(r) * 0.5; float crack = step(0.85, fbm(in.uv*7.0)); out.color += accent_pearl * crack * 0.2;` |
| 63    | whale_bone          | `out.color = mix(accent_pearl*0.85, sand_wet, smoothstep(0.0, 1.0, fbm(in.uv*4.0))); float seam = step(0.92, fract(in.uv.y*8.0)); out.color *= mix(1.0, 0.65, seam);` |
| 64    | barnacle_glow       | `float crust = step(0.6, fbm(in.world_pos*1.2)); float pulse = 0.5 + 0.5*sin(time*1.0 + in.world_pos.x*0.6); out.color = mix(out.color, accent_coral*pulse*1.4, crust);` (additive emissive) |

(uBase 50, 60, 70, 80 are forest territory and intentionally skipped. uBase 65..69 are reserved for future use; this zone uses 45..49 + 51..59 + 61..64.)

---

## §5. Path landmark cadence (10 beats, distance from origin → portal)

| # | Distance (m) | Island | What the player sees                                           | Mesh IDs              | Mood shift                  |
|---|-------------:|--------|-----------------------------------------------------------------|-----------------------|-----------------------------|
| 1 | 0            | A      | Lantern Hold harbor: lighthouse, lantern_post array, sea grass | 137, 139, 88, 116     | Quiet anchorage             |
| 2 | 60           | A→B    | Driftwood bridge from A's east shore into Whale's Spine        | 77                    | Setting out                 |
| 3 | 180          | B      | Whale skull landmark and rib_arch chain through bone field      | 121, 122, 123         | Reverence, ancient quiet    |
| 4 | 320          | B→D    | Rope bridge over open swell to The Wreck                       | 78                    | Crossing risk               |
| 5 | 440          | D      | Galleon bow, broken_hull, rope_coils, mast pole leaning         | 97, 98, 103, 99       | Decay, story of who lost    |
| 6 | 540          | D→E    | Rune-gate arch in the Wreck's stern; flash → Skywatch deck     | 79                    | Threshold, awe              |
| 7 | 600          | E      | Sky temple plaza: sea_glass_temple, levitating_stone, mist     | 126, 134, 135, 59 (uBase) | Ascension, sacred       |
| 8 | 660          | E→F    | Long sky-bridge tethered down toward Far Reach (player walks)  | 78, 133               | Vertigo, descent            |
| 9 | 700          | F      | Far Reach lighthouse, brazier_with_pyre, prayer_bell_tower      | 139, 140, 132         | Arrival, weight             |
| 10| 720          | F      | The portal — same `mesh_id 13` as forest, framed by 4 kelp_pillars | 13, 141           | Departure                   |

**Side-loop**: rune-gating from A directly to Glasstop (C) takes the player into the bioluminescent grove (mesh 105–112). C is not on the main path; it's the lore-rich detour for players who explore.

---

## §6. Cross-references and gotchas

### Files to extend

- `src/game/entity.zig` — bump `MAX_ENTITIES` 4096 → 8192 (line 8).
- `src/main.zig`:
  - Bump `const MAX_DRAW = 4096;` → `8192` (line 707).
  - Add `spawn_isles_world()` that places the 6 islands' set-dressing, bridges, rune gates, enemies, and 90 boundary kelp pillars at r=890.
  - Add a `current_zone` enum so `game_init` can dispatch to forest / desert / isles spawners.
  - Extend the `world.team` switch in `game_fill_draws` (lines 572–603) to handle teams 53..76.
- `src/game/enemy_config.zig` — append 10 `EnemyType` rows for mesh IDs 67..76. Each needs a `name_idx` matching new entries appended to `kEnemyNames` in `ios/GameViewController.swift`.
- `src/game/enemy_ai.zig` — add 10 per-mesh tick functions; dispatch entries in `EnemyAI.update`.
- `shaders/world.metal` — add fragment-shader branches for uBase 45..49, 51..59, 61..64 per §4b. Two of these (55 drift_kelp, 58 wind_pennant) require small vertex-shader branches as well.
- `ios/GameViewController.swift`:
  - Bump `kMaxDrawCalls` 4096 → 8192 (line 194).
  - Append 10 enemy names to `kEnemyNames`: "Reef Skitter", "Drowned Mariner", "Jelly Lantern", "Mast Serpent", "Shell Brute", "Tide Wraith", "Coral Strider", "Sky Archer", "Barnacle Creeper", "Mirror Kraken Juvenile".
  - Extend the `meshId` switch (line 1215) to dispatch IDs 67..141 to new mesh buffers.
  - Add 75 `make<NewMesh>(device:)` declarations + buffer ivars + initialisation block.
- `ios/Mesh.swift` — add 75 new mesh-builder functions (`makeReefSkitter` through `makeKelpPillarTitan`).
- `ios/PortalMapView.swift` — flip the Drifting Isles tile from "Coming Soon" to available + wire the destination to load the isles zone.

### What could break

- **MAX_DRAW exhaustion** — under FX storm + corpses, peak transient could spike to ~500. Set-pieces 4030 + transient 500 = 4530 / 8192 cap. Comfortable margin.
- **Sky-island depth occlusion** — Skywatch (E) sits at y=60. Standard depth-write should handle it correctly, but the long sky-bridge from E to F crosses the inter-island fog volume. Verify the depth pre-pass isn't culled.
- **Bridge collision / water clamp — IMPLEMENTED in `src/main.zig`** (2026-04-27). `clamp_player_isles(prev_pos)` is called from `game_update` whenever `current_zone == .isles`. It tests the player's (x, z) against the 6 island circles (§2b) and 3 bridge corridors; if on safe ground it pins y to the local deck height (linearly interpolating along the sloping E↔F sky bridge between y=60 and y=0); if in water, it snaps the player back to the previous-frame position and zeros velocity. The forest's existing outer-ring clamp was generalised into `clamp_player_outer_ring(radius)` and the per-zone dispatch lives in a new `Zone` enum (forest=0, desert=1, isles=2). Swift switches zone with `game_set_zone(N)`. **Caveat:** spawning is still forest-only — calling `game_set_zone(2)` today applies the isles clamp to a forest-populated map, not the actual archipelago. Per-zone spawn functions are the remaining work.
- **uBase-range overflow** — Isles uses 16 markers in 45..49 + 51..59 + 61..64. Combined with forest (0..14, 20..21, 25, 50, 60, 70, 80) and desert (0, 8, 30..44), total uBase range used is 0..80 with gaps. uBase is uint8, room to spare.
- **Per-island spawn distribution** — see §8 spawn-radius reconciliation below for how to split each asset's count across the islands.

---

## §7. Self-check (mechanical)

- **Mesh IDs used:** 67..141 contiguous (75 IDs). No overlap with forest set {0..9, 13..28} or desert set {29..66}. ✓
- **uBase markers used:** {0, 8, 45..49, 51..59, 61..64}. No overlap with forest set {0,1,2,8,10..14,20,21,25,50,60,70,80} except for shared 0 and 8 (intentional). No overlap with desert set {0, 8, 30..44}. ✓
- **Color teams used:** {1, 53..76} (24 teams). No overlap with forest set {0..14, 30..32} or desert set {1, 40..52}. ✓
- **Spawn-budget total:** Enemies 122 + assets 3818 + boundary 90 = **4030**. Under MAX_DRAW (8192). ✓
- **Engine bump declared:** MAX_ENTITIES, MAX_DRAW, kMaxDrawCalls all flagged for 4096→8192 in §2 and §6. ✓
- **Free uBase headroom for future zones:** 65..69, 71..79, 81..89, 90..127. Plenty.

---

## §8. Spawn-radius reconciliation (overrides per-asset §10)

Per-asset detail sections will be generated independently and likely repeat the desert mistake of clumping all spawns near origin. **The table below supersedes any conflicting per-asset §10 spawn rule.** Each row pins an asset to one or more islands by reference to the §2b layout, with a count distribution.

`A=Lantern Hold (0,0,0; r=200)`, `B=Whale's Spine (200,0,-180; r=180)`, `C=Glasstop (-220,0,-260; r=170)`, `D=The Wreck (60,0,-440; r=220)`, `E=Skywatch (-120,60,-560; r=140)`, `F=Far Reach (40,0,-720; r=200)`. Counts shown as `island:count` lists; spawn locations are within that island's circular footprint, with min 4 m clearance from the bridge / rune-gate landings.

| mesh_id | name                       | spawn distribution                              | path-clear (m) |
|---------|----------------------------|--------------------------------------------------|----------------|
| 77      | driftwood_bridge           | exact: A↔B (1), B↔D (1), D-stairs (1), D↔E (1), E↔F (1) | 0 (defines path) |
| 78      | rope_bridge                | exact: B↔D auxiliary (1), D inner walkway (3)    | 0              |
| 79      | rune_gate_arch             | exact: A↔C (1), C↔E (1), D↔E (1), F↔portal (1), E side (2) | 0              |
| 80      | plank_walkway              | A:2, D:3, F:3                                    | 0              |
| 81–88   | beach assets               | per-island: A:30%, B:0, C:0, D:30%, F:30%, scatter:10% | 6              |
| 89–96   | cliff assets               | per-island: B:30%, C:25%, D:20%, F:25%           | 7              |
| 97–104  | wreckage assets            | concentrated D (70%), scattered B+F (30%)        | 6              |
| 105–112 | bioluminescence            | C:50% (its signature), E:20%, scattered A+F (30%) | 5              |
| 113–120 | kelp / vegetation          | even across A,B,C,D,F at ~20% each, none on E    | 5              |
| 121–124 | bones                      | concentrated B (70%), scattered F (30%)          | 7              |
| 125–132 | ruins / temples            | D:30%, E:35%, F:30%, A:5%                        | 7              |
| 133     | tether_chain_long          | exact: 4 chains anchoring E to G under-island    | n/a            |
| 134–136 | sky island flora           | exact: E only, in plaza around sea_glass_temple  | n/a            |
| 137     | lantern_post_isle          | A:14 (path-side), D:6, F:8, B:4                  | 0 (path-side)  |
| 138     | signal_buoy_floating       | exact: ringed around each island in shallow water (3 per island × 6 islands = 18) | n/a |
| 139     | lighthouse_short           | exact: A (1), D (1), F (1), E (1)                | 0              |
| 140     | brazier_with_pyre          | A:4, D:4, E:3, F:3                               | 7              |
| 141     | kelp_pillar_titan          | exact: 90 instances at r=890, spaced 5655/90 ≈ 63 m on the rim | n/a |

**Path landings:** every bridge endpoint must have a 6 m radius clear of all assets. Implementation should compute bridge endpoints in the spawn function and apply this exclusion programmatically.

---

# Per-enemy detail (10 × 30+ features)

## Enemy 67 — reef_skitter
### 1. One-line silhouette  
At 30m, the reef_skitter appears as a low, wide, flattened oval with four rapid-moving legs — instantly distinguishable from other enemies by its sea-creaturesque low-profile and leg cadence.

### 2. Mesh tri-budget breakdown  
Body: 400 tris, Legs: 300 tris, Props: 150 tris, FX: 50 tris. Total: 900 tris.

### 3. Body palette  
- **water_shallow** (0.30, 0.60, 0.75) — main body shell  
- **kelp_green** (0.18, 0.42, 0.30) — underside and leg undersides  
- **accent_coral** (0.92, 0.50, 0.42) — leg tips and head accent  
- **foam_white** (0.94, 0.96, 0.98) — head and belly highlights  

### 4. uBase marker assignments per body part  
| Body Part     | uBase Marker |
|---------------|--------------|
| Body Shell    | 49           |
| Legs          | 49           |
| Head          | 49           |
| Belly         | 0            |
| Eye Glow      | 8            |

(All chitin uses the barnacle_crust shader (49) — reef_skitter is reserved only for that marker. Eye spots use generic emissive 8; belly stays default 0. Per-vertex color hash provides leg/body tint variation.)

### 5. Idle animation  
A slow, rhythmic leg-shuffle with 2-second loop. Legs lift and drop in sync with a subtle head bob. No key beats, but subtle body sway.

### 6. Walk/move animation  
Fast, alternating gait with 0.6s cadence. Four legs move in pairs, with a subtle bounce to mimic crawling on a coral reef. Legs lift and land in a rhythmic 3D pattern.

### 7. Attack telegraph  
In the 0.6s before attack, the skitterer lifts its head and raises one front leg, glowing faintly in **accent_coral**. A subtle ripple of foam spreads from its body.

### 8. Attack execution  
A rapid swipe of the front leg with a **foam_white** glow trailing. Deals 22 damage via a 0.4m wide melee hitbox with a short knockback. No projectile or AoE.

### 9. Attack cooldown  
1.2 seconds at base difficulty.

### 10. Hit-react animation  
The enemy flinches with a 0.3s shake and head tilt. Legs stagger briefly. No death animation plays until the end of the hit-react.

### 11. Death animation  
The body curls inward and sinks into foam. A spray of **drip_seafoam** FX erupts from the body, and the legs collapse with a soft splash.

### 12. Aggro radius (m)  
6.5 meters.

### 13. Attack range (m)  
1.8 meters.

### 14. Movement speed (m/s)  
7.2 m/s (1.3x player speed).

### 15. Turn rate (rad/s)  
8.5 rad/s.

### 16. Y-offset / locomotion plane  
Ground-walker, y=0.5m above reef surface.

### 17. HP  
55 HP. Justified as a low-mid skitterer with a role similar to Desert Sand Scorpion (55 HP) but with higher speed and lower armor.

### 18. Damage  
22 damage per hit. Justified as consistent with low HP and fast attack rate, higher than Forest Wisp (10), but lower than Skeleton Knight (20).

### 19. XP reward  
23 XP. (55 × 0.3 + 22 × 1.5 = 16.5 + 33 = 49.5 → rounded to 23)

### 20. Group spawn pattern  
Loose-trio, with one skitterer spawning near another.

### 21. Spawn placement rules  
Spawns in **The_Wreck_D** and **Glasstop_C**, preferring coral patches or shallow tide pools.

### 22. Procedural variation  
Scale: 0.9–1.1x, Rotation: ±15°, Palette variant index: 0–3.

### 23. Sound design — idle  
Low, rhythmic chittering and scraping sounds like coral rubbing.

### 24. Sound design — telegraph  
A sharp, rasping click and a faint foam ripple sound.

### 25. Sound design — hit/strike  
A sharp crack and a splash.

### 26. Particle FX tied to entity  
`drip_seafoam` — a light mist that trails from the body during movement and erupts on death.

### 27. Special ability or unique mechanic  
Can leap up to 2m in a single bound, skipping over small obstacles and gaining a brief speed boost for 0.5s.

### 28. Player counter-strategy  
Lightning or ice nova work well due to its fast movement and low armor. Dash can be used to avoid the leg swipe.

### 29. Mass / collider radius (m)  
Collider radius: 0.8m. Mass: light. Light knockback, easy to push around.

### 30. Edge-case interaction with biome  
In tide pools, it moves slower but gains extra stealth. On sky-bridges, it avoids the edge and uses the bridge’s verticality to leap. Near rune gates, it becomes more aggressive.

### Implementation hooks  
- `src/game/enemy_config.zig` line 1200  
- `enemy_ai.zig` tick function: `tickReefSkitter`  
- `GameViewController.swift` index 67 in `kEnemyNames`  
- Metal fragment shader branches: `if (uBase == 49)` for shell color, `if (uBase == 50)` for leg, `if (uBase == 51)` for head, `if (uBase == 52)` for belly.
---

## Enemy 68 — drowned_mariner
### 1. **One-line silhouette** — The drowned_mariner presents a tall, angular humanoid silhouette with a curved sword arm, immediately distinguishable by its maritime-specific posture and lack of wings or spider legs.
### 2. **Mesh tri-budget breakdown** — Body: 600 tris, Limbs: 400 tris, Props (sword, helmet, cloak): 200 tris, FX (foam, mist): 100 tris.
### 3. **Body palette** — water_deep (0.06, 0.16, 0.32) for torso, kelp_green (0.18, 0.42, 0.30) for limbs, sail_cream (0.88, 0.82, 0.66) for belt and helmet, accent_coral (0.92, 0.50, 0.42) for sword blade and eye sockets.
### 4. **uBase marker assignments per body part** — Head: 51, Torso: 52, Arms: 51, Legs: 52, Sword: 51, Helmet: 52, Emissive: 8.
### 5. **Idle animation** — Loops every 4.2 seconds; idle stance with slight sway and sword held in ready position; head nods once at 1.2s, then arm gestures.
### 6. **Walk/move animation** — Steady gait with slight hip sway, footstep cadence every 0.7s; arms swing in opposition to legs.
### 7. **Attack telegraph** — Sword is raised high for 0.5s, then the enemy crouches slightly; a thin mist trail appears from the sword's tip at 0.3s.
### 8. **Attack execution** — A downward cleave with the sword; damage delivered via a short-range melee swipe; the sword glows with a faint ember_lantern (0.95, 0.55, 0.18) aura.
### 9. **Attack cooldown** — 1.8 seconds.
### 10. **Hit-react animation** — Enemy flinches back with a slight head tilt, then shakes sword and resumes stance; body part hit is highlighted with foam spray.
### 11. **Death animation** — Falls forward into sea foam with a splash, limbs splayed; foam particles rise and disperse.
### 12. **Aggro radius (m)** — 12 meters.
### 13. **Attack range (m)** — 2.8 meters.
### 14. **Movement speed (m/s)** — 3.6 m/s.
### 15. **Turn rate (rad/s)** — 3.2 rad/s.
### 16. **Y-offset / locomotion plane** — Ground-walker at y=0, but floats slightly above sea level due to sea spray.
### 17. **HP** — 160 HP. Justified by being a mid-tier melee enemy, stronger than a Forest Wisp but less than a Tree Ent or Desert Husk.
### 18. **Damage** — 22 per hit. Justified by HP and role, balancing with the 160 HP and 1.8s cooldown.
### 19. **XP reward** — 120 XP. (160 × 0.3 + 22 × 1.5 = 48 + 33 = 81, rounded up to 120 for balancing).
### 20. **Group spawn pattern** — Loose-trio, spawning near water edges.
### 21. **Spawn placement rules** — The_Wreck_D and Glasstop_C.
### 22. **Procedural variation** — Scale range 0.95 to 1.05; rotation freedom 10 degrees; palette variants 0–2 for kelp_green and sail_cream.
### 23. **Sound design — idle** — Low, bubbling sea noise with occasional sword clink.
### 24. **Sound design — telegraph** — Sharp, rising mist hiss.
### 25. **Sound design — hit/strike** — Heavy sword impact with splash.
### 26. **Particle FX tied to entity** — `drip_seafoam` — light, slow-falling droplets with slight glow; triggers on attack and movement.
### 27. **Special ability or unique mechanic** — Can briefly become partially transparent and gain a 0.5s speed boost when hit, mimicking water mist.
### 28. **Player counter-strategy** — Dash or lightning can interrupt the attack telegraph; ice nova slows it in place.
### 29. **Mass / collider radius (m)** — Collider radius 1.2 meters; mass is heavy (inertia for knockback).
### 30. **Edge-case interaction with biome** — In tide pools, it sinks slightly and moves slower; near rune gates, it becomes temporarily aggroed by nearby enemies; in mist, it becomes harder to see due to its blend with water fog.

### Implementation hooks
- `src/game/enemy_config.zig` row 68: `drowned_mariner`
- `enemy_ai.zig` tick function: `tick_drowned_mariner`
- GameViewController.swift `kEnemyNames` index: 68
- world.metal fragment shader branches: `if (uBase == 51)` and `if (uBase == 52)` for body part coloring, `if (uBase == 8)` for emissive lighting.
---

## Enemy 69 — jelly_lantern
### 1. One-line silhouette — what shape does the player read at 30m? Why is it instantly distinguishable from the other 14 enemies in the game?
At 30m, the jelly_lantern appears as a glowing, translucent orb with a faint bioluminescent pulse, easily distinguishable from other enemies due to its floating, orb-like silhouette, lack of limbs, and unique pulsating emission.

### 2. Mesh tri-budget breakdown — body / limbs / props / FX. Sum equals EST_TRIS.
Body: 400 tris, Limbs: 80 tris, Props: 80 tris, FX: 40 tris.

### 3. Body palette — 4 swatches drawn from the Isles palette + where on the body each is applied.
- `water_deep` (0.06, 0.16, 0.32) — base body core.
- `accent_coral` (0.92, 0.50, 0.42) — outer glow rim.
- `mist_low` (0.82, 0.86, 0.88) — inner translucent layer.
- `sky_storm` (0.18, 0.28, 0.45) — core shadowing.

### 4. uBase marker assignments per body part — table: body_part → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| Body Part     | uBase |
|---------------|-------|
| Core          | 53    |
| Rim Glow      | 53    |
| Inner Layer   | 53    |
| Shadow        | 53    |
| Emissive      | 8     |

### 5. Idle animation — 1–3 sentences. Frequency, loop length, key beats.
Idle animation is a slow, gentle rise-and-fall sway with a 3-second loop. It pulses every 1.5 seconds, with a subtle rotation on the Y-axis every 4 seconds to simulate floating. The rhythm is consistent and calming, mimicking a lantern in the water.

### 6. Walk/move animation — gait, frequency, foot/limb cadence.
Uses a smooth, undulating motion with no limbs. Movement is a continuous, slow wave-like sway with a 1.2-second cadence. No discrete footfalls — it glides with a slight hover effect.

### 7. Attack telegraph — what the player sees in the 0.4–0.8s before the hit lands. Visual cue must be unambiguous.
A bright flash of `accent_coral` glows around the body for 0.6 seconds before firing. The entire body pulses once and a faint light trail begins to form in the direction of the target.

### 8. Attack execution — the strike/hit moment. Damage delivery model (melee swipe, projectile, AoE).
Fires a glowing orb projectile that follows a parabolic arc. Upon impact, it creates a small AoE shockwave that damages nearby enemies. The projectile is a ranged attack.

### 9. Attack cooldown — seconds between attacks at base difficulty.
2.2 seconds.

### 10. Hit-react animation — what plays when player lands a strike on this enemy.
The enemy pulses with a white flash, then briefly stutters in place. A small ripple effect radiates from the point of impact, and its color shifts to `foam_white` for 0.3 seconds.

### 11. Death animation — 1–2 sentence description, including dust/spray/foam FX.
The jelly_lantern floats in place, then gradually fades out with a burst of `drip_seafoam` particles. It releases a few bioluminescent bubbles that rise and dissipate into the water.

### 12. Aggro radius (m) — how far away does it lock onto player.
12 meters.

### 13. Attack range (m) — distance at which step 7 telegraph triggers.
15 meters.

### 14. Movement speed (m/s) — base speed; reference player default 5.5 m/s.
3.0 m/s.

### 15. Turn rate (rad/s) — how snappy the rotation is.
1.0 rad/s.

### 16. Y-offset / locomotion plane — ground-walker (y=0), hovering (y=2.5), levitating from sea, on-mast climber, sky-walker on Skywatch (y=60), etc.
Floating at y=2.5m above sea level, with a slight sway motion.

### 17. HP — choose a value consistent with role (skitterer 35..70, harasser 35..90, tank 240..380, pack 60..120, illusion 1..50). Justify in one sentence vs forest+desert comparators.
60 HP. This is consistent with a bioluminescent ranged harasser, lighter than forest Gargoyle (80) or Desert Husk (320), but heavier than Forest Wisp (35) or Sand Wraith (80).

### 18. Damage — per hit, consistent with HP and role. Justify.
12 damage per hit. This is consistent with a ranged harasser that can hit from a distance, but not overwhelm a player in a single hit, unlike a tank or melee unit.

### 19. XP reward — proportional to (HP × 0.3 + damage × 1.5).
XP reward = (60 × 0.3) + (12 × 1.5) = 18 + 18 = 36 XP.

### 20. Group spawn pattern — lone / paired / loose-trio / dense-pack / ambush-from-water / ambush-from-mast.
Ambush-from-water, typically spawning in groups of 3–5.

### 21. Spawn placement rules — which island(s)? Hub_A, Whale's_Spine_B, Glasstop_C, The_Wreck_D, Skywatch_E, Far_Reach_F. Specify.
Spawns on The_Wreck_D, Far_Reach_F, and Glasstop_C — in water near floating debris or masts.

### 22. Procedural variation — scale range, rotation freedom, palette variant indices.
Scale: 0.9x to 1.1x. Rotation: ±10 degrees on Y-axis. Palette: 2–3 variants of `accent_coral` and `mist_low` for variation.

### 23. Sound design — idle — 1 line.
A low, bubbling hum with a gentle, rhythmic tone.

### 24. Sound design — telegraph — 1 line.
A sharp, resonant chime followed by a quick, low hum.

### 25. Sound design — hit/strike — 1 line.
A crackling, glowing pop with a brief spark of energy.

### 26. Particle FX tied to entity — emitter preset name (mirror existing styles like `forest_motes`, `embers`, or new like `drip_seafoam`, `lantern_motes`), what it looks like, when it triggers.
`lantern_motes` — a soft, glowing trail of particles that follow the enemy’s movement. Triggers during idle and movement.

### 27. Special ability or unique mechanic — what makes this enemy different from a vanilla melee/ranged unit.
It leaves a faint bioluminescent trail behind it while moving, which can be used by other enemies to track the player’s path.

### 28. Player counter-strategy — 1–2 lines on what skills work against it (fireball/lightning/ice_nova/dash).
Lightning or ice nova can disrupt its glow and slow its movement. Dash can avoid its projectiles.

### 29. Mass / collider radius (m) — body radius for collision, knockback inertia descriptor (light/medium/heavy).
Collider radius: 0.8m. Mass is light, allowing for easy knockback.

### 30. Edge-case interaction with biome — how does this enemy behave at a tide_pool, on a sky-bridge, near a rune_gate, in mist?
In tide pools, it hovers just above the water surface, leaving bubbles. On sky-bridges, it floats in place, unable to move. Near rune gates, it flickers erratically. In mist, its glow becomes dimmer and harder to see.

### Implementation hooks
- `src/game/enemy_config.zig` row: 69  
- `enemy_ai.zig` tick fn name: `tick_jelly_lantern`  
- GameViewController.swift `kEnemyNames` index: 69  
- world.metal fragment branches: `case 69` for `uBase == 53`, `case 8` for emissive rendering.
---

## Enemy 70 — mast_serpent
### 1. **One-line silhouette** — The mast_serpent's silhouette is a long, sinuous body with a coiled tail and a pair of prominent curved horns rising from its head, instantly distinguishable by its massive, mast-anchored posture and its vertical serpentine profile compared to the low-hanging skitters, hovering wisps, or tank-like ents and husks.
### 2. **Mesh tri-budget breakdown** — Body (600 tris), limbs (300 tris), props (200 tris), FX (100 tris). Total 1200 tris.
### 3. **Body palette** — Main body uses driftwood_grey (0.45, 0.42, 0.38) for its bark-like texture; accent scales in kelp_green (0.18, 0.42, 0.30) on belly and limbs; secondary highlights in sail_cream (0.88, 0.82, 0.66) on head and tail; and a splash of accent_coral (0.92, 0.50, 0.42) on its curved horns.
### 4. **uBase marker assignments per body part** —
| Body Part      | uBase |
|----------------|--------|
| Head           | 51     |
| Body           | 49     |
| Tail           | 51     |
| Horns          | 49     |
| Limbs          | 49     |
| Emissive parts | 8      |
### 5. **Idle animation** — Smooth, slow undulation with periodic head bobbing every 4 seconds. Loop length is 8 seconds. Key beat is a sudden head-lift at 2s to look around.
### 6. **Walk/move animation** — Slithering gait with body undulation, each limb pair moving in sync. Frequency is 0.8 Hz. Limb cadence follows a wave motion across the body.
### 7. **Attack telegraph** — The serpent coils its tail, raises its head, and emits a glowing trail of mist from its nostrils. The trail pulses and grows in size for 0.6 seconds before strike.
### 8. **Attack execution** — The serpent performs a sweeping tail strike that sends out a shockwave. Damage is delivered in a 120-degree cone, with a 1.5m radius AoE. The attack is a melee swipe.
### 9. **Attack cooldown** — 3.2 seconds at base difficulty.
### 10. **Hit-react animation** — A sharp body twist and head snap backward, with a splash of foam FX from the tail. Animation lasts 0.4 seconds.
### 11. **Death animation** — The serpent falls to the mast, its body convulsing once before going still. Foam and kelp particles spray out from the wound.
### 12. **Aggro radius (m)** — 25 meters.
### 13. **Attack range (m)** — 4 meters.
### 14. **Movement speed (m/s)** — 2.3 m/s.
### 15. **Turn rate (rad/s)** — 2.8 rad/s.
### 16. **Y-offset / locomotion plane** — Climbs masts, y-offset is 3.2 meters above ground; moves in vertical plane.
### 17. **HP** — 110 HP. This is in line with pack-leaders like the Carrion Spider (60 HP) but higher than Forest Wisp (35 HP) and Sand Scorpion (55 HP) due to its tank-like role in a group.
### 18. **Damage** — 18 per hit. Consistent with its HP and role as a pack-leader, it's stronger than skitterers but not as brutal as tanks like Desert Husk or Shell Brute.
### 19. **XP reward** — 63 XP. (110 × 0.3 + 18 × 1.5 = 33 + 27 = 60, rounded to 63).
### 20. **Group spawn pattern** — Loose-trio. Spawns in groups of 2–3, typically with one in the lead.
### 21. **Spawn placement rules** — Spawns only on islands with masts: Whale's_Spine_B, The_Wreck_D, Far_Reach_F.
### 22. **Procedural variation** — Scale range is 0.9 to 1.1; rotation freedom is ±15°; palette variants include 3 color indices for each body part.
### 23. **Sound design — idle** — Low gurgling and creaking of wood and rope.
### 24. **Sound design — telegraph** — High-pitched mist-sucking hiss.
### 25. **Sound design — hit/strike** — Heavy thud and crack of wood splitting.
### 26. **Particle FX tied to entity** — Emitter: `drip_seafoam`. Looks like small droplets of water and foam. Triggers on idle, attack, and hit-react.
### 27. **Special ability or unique mechanic** — Climbs masts using a unique limb system with gripping hooks and a serpentine body that wraps around the mast. Can drop from mast to attack.
### 28. **Player counter-strategy** — Dash or ice nova to interrupt the climb, fireball or lightning to damage the exposed body during climb.
### 29. **Mass / collider radius (m)** — Collider radius is 1.2 meters. Mass is medium, with moderate knockback inertia.
### 30. **Edge-case interaction with biome** — On a tide_pool, it climbs out of the water and anchors itself to the nearest mast. On a sky-bridge, it climbs the mast to the next platform. Near a rune_gate, it avoids the area, instead climbing higher. In mist, it uses the mist to conceal its approach and attack.

### Implementation hooks
- `src/game/enemy_config.zig` row: 1500
- `enemy_ai.zig` tick fn name: `tick_mast_serpent`
- GameViewController.swift `kEnemyNames` index: 12
- world.metal fragment branches: `#if defined(ENEMY_MAST_SERPENT)`
---

## Enemy 71 — shell_brute
### 1. One-line silhouette
A low, wide, and heavily armored turtle-like shape with a prominent shell and short stubby legs, instantly distinguishable from other enemies by its thick armor and slow, deliberate movement.
### 2. Mesh tri-budget breakdown
Body: 1000 tris, Limbs: 300 tris, Props: 150 tris, FX: 50 tris.
### 3. Body palette
- Water shallow (0.30, 0.60, 0.75) — main shell and lower body
- Kelp green (0.18, 0.42, 0.30) — internal shell structure and bristles
- Accent coral (0.92, 0.50, 0.42) — rim and hinge details
- Driftwood grey (0.45, 0.42, 0.38) — lower limbs and underbelly
### 4. uBase marker assignments per body part
| Body Part        | uBase |
|------------------|-------|
| Shell            | 49    |
| Limbs            | 47    |
| Internal shell   | 49    |
| Hinge details    | 47    |
| Underbelly       | 0     |
| Emissive         | 8     |
### 5. Idle animation
A slow 4-second loop with subtle breathing motion every 3 seconds. The head and limbs sway gently with a slow oscillation.
### 6. Walk/move animation
A slow, waddling gait with 1.5-second step cycles. Legs move in a staggered rhythm, with the front pair stepping first.
### 7. Attack telegraph
The shell glows faintly in amber, and a low rumble builds. The head raises 15 cm and the shell vibrates with a subtle pulse.
### 8. Attack execution
A heavy melee swipe with the front limb, generating a small shockwave. The attack is a single swipe with no projectile.
### 9. Attack cooldown
2.8 seconds at base difficulty.
### 10. Hit-react animation
A 0.3-second jolt of the shell and limbs, with a small puff of foam rising from impact point.
### 11. Death animation
The shell cracks open with a loud shatter, and foam sprays out in all directions. The body slowly sinks into the water.
### 12. Aggro radius (m)
12 meters.
### 13. Attack range (m)
3 meters.
### 14. Movement speed (m/s)
1.2 m/s.
### 15. Turn rate (rad/s)
0.8 rad/s.
### 16. Y-offset / locomotion plane
Ground-walker at y=0, gliding slightly above sea level.
### 17. HP
320 HP. This value reflects its tank role, higher than the Forest Tree Ent (280 HP) and Desert Husk (320 HP) but lower than the Desert Carrion Spider (60 HP).
### 18. Damage
70 per hit. This damage aligns with its high HP and tank role, ensuring it can take multiple hits while still being a threat.
### 19. XP reward
135 XP. Calculated as (320 × 0.3 + 70 × 1.5) = 96 + 105 = 201, rounded down to 135 for balance.
### 20. Group spawn pattern
Ambush-from-water.
### 21. Spawn placement rules
The_Wreck_D and Skywatch_E.
### 22. Procedural variation
Scale range: 0.9–1.1x, Rotation freedom: ±10°, Palette variant indices: 0–2 for each color swatch.
### 23. Sound design — idle
A low rumbling and soft bubbling sound, mimicking the ocean.
### 24. Sound design — telegraph
A deep, resonant growl.
### 25. Sound design — hit/strike
A heavy thud with a slight crackling sound.
### 26. Particle FX tied to entity
Emitter preset: `drip_seafoam`. Emits small droplets from shell surface. Triggers during idle, attack, and hit-react.
### 27. Special ability or unique mechanic
Shell can deflect projectiles and reduce incoming damage by 40% for 3 seconds after a hit.
### 28. Player counter-strategy
Fireball or lightning damage works well against its armor. Ice Nova can slow it down and disrupt its attack timing.
### 29. Mass / collider radius (m)
Collider radius: 1.4 meters. Mass: Heavy, affects knockback and collision physics.
### 30. Edge-case interaction with biome
At tide pools, it becomes slightly slower and may get stuck on rocks. On sky-bridges, it avoids stepping near edges. Near rune gates, it is immune to the gate’s effects but still attacks normally.

### Implementation hooks
- `src/game/enemy_config.zig` row: 71
- `enemy_ai.zig` tick fn name: `tick_shell_brute_ai`
- GameViewController.swift `kEnemyNames` index: 71
- world.metal fragment branches: `if (uBase == 49)` and `if (uBase == 47)`
---

## Enemy 72 — tide_wraith
### 1. **One-line silhouette** — At 30m, it appears as a pale, indistinct mist-shape with a few elongated appendages, clearly distinguishable from forest gargoyles or desert wraiths due to its translucent, oceanic aura and lack of solid limbs.
### 2. **Mesh tri-budget breakdown** — Body: 300 tris, limbs: 200 tris, props (floating tentacles): 100 tris, FX (mist trails): 100 tris.
### 3. **Body palette** — Mist-white (mist_low) for base skin, water-deep (water_deep) for internal shadows, kelp-green (kelp_green) for subtle vein-like patterns, and foam-white (foam_white) for mist accents.
### 4. **uBase marker assignments per body part** — Head → 45, Arms → 59, Body → 45, Legs → 59, Emissive → 8.
### 5. **Idle animation** — A slow, floating sway with gentle up-and-down motion; loop duration is 4 seconds, with a key beat at 2s where tentacles pulse with a subtle glow.
### 6. **Walk/move animation** — Levitates with a smooth, undulating motion; moves at 1.2 m/s with a 1.5s cadence, limb movement synchronized with a wave-like rhythm.
### 7. **Attack telegraph** — A glowing mist trail begins to trail behind the enemy, and its tentacles extend outward with a slow, pulsing animation lasting 0.6 seconds.
### 8. **Attack execution** — Fires a beam of misty energy in a 90-degree arc, dealing 12 damage; the beam is a short-range projectile with a slight delay before it strikes.
### 9. **Attack cooldown** — 3.2 seconds at base difficulty.
### 10. **Hit-react animation** — The body briefly flickers with a darkened glow, followed by a slight backward drift and a misty burst from its limbs.
### 11. **Death animation** — Explodes into a misty cloud that slowly disperses into the air, leaving behind a few scattered droplets of foam-white particles and a lingering shadow.
### 12. **Aggro radius (m)** — 15 meters.
### 13. **Attack range (m)** — 10 meters.
### 14. **Movement speed (m/s)** — 1.2 m/s.
### 15. **Turn rate (rad/s)** — 2.0 rad/s.
### 16. **Y-offset / locomotion plane** — Levitates at y=2.5m, hovering just above the sea surface or island platforms.
### 17. **HP** — 75 HP. This is mid-tier for a ranged ghostly enemy, lower than a forest Tree Ent but higher than a desert Sand Wraith, fitting a sea-based, ethereal threat.
### 18. **Damage** — 12 per hit. Balanced to match its HP, consistent with a ranged harasser but not overly threatening, unlike a melee Skeleton Knight.
### 19. **XP reward** — 36 XP (75 × 0.3 + 12 × 1.5).
### 20. **Group spawn pattern** — Ambush-from-water, appearing from ocean foam and mist.
### 21. **Spawn placement rules** — Spawns on Glasstop_C and The_Wreck_D, particularly near tide pools and sea platforms.
### 22. **Procedural variation** — Scale range: 0.9–1.1x, rotation freedom: ±15°, palette variant indices: 0–3 for skin, 0–2 for tentacles.
### 23. **Sound design — idle** — A low, gurgling hum like a tide pool, with intermittent misty whooshes.
### 24. **Sound design — telegraph** — A sharp, rising mist-snap followed by a slow, echoing chime.
### 25. **Sound design — hit/strike** — A sharp, sibilant mist-piercing sound with a low thud as the mist beam impacts.
### 26. **Particle FX tied to entity** — Emitter preset: `drip_seafoam`. Looks like tiny droplets of ocean mist that trail behind the enemy, triggers during movement and attack telegraph.
### 27. **Special ability or unique mechanic** — Its misty form makes it immune to direct melee attacks, and it can phase through solid obstacles for short durations.
### 28. **Player counter-strategy** — Ice Nova is effective for freezing its movement; lightning can disrupt its mist beam; dash and fireball are good for breaking its phasing.
### 29. **Mass / collider radius (m)** — Collider radius: 1.2m, mass: 0.8 (light), knockback inertia: light.
### 30. **Edge-case interaction with biome** — In tide pools, it gains a temporary speed boost and can phase through solid ground; on sky-bridges, it hovers higher and avoids falling; near rune gates, it becomes temporarily transparent and immune to damage.

### Implementation hooks
- `src/game/enemy_config.zig`: line 230
- `enemy_ai.zig`: `tick_tide_wraith`
- `GameViewController.swift`: `kEnemyNames` index 72
- `world.metal`: fragment shader branches for `uBase == 45`, `uBase == 59`, `uBase == 8`
---

## Enemy 73 — coral_strider
### 1. One-line silhouette
The coral_strider presents a long-legged, spider-like silhouette with a segmented body and six articulated legs, clearly distinguishable from other enemies by its high, wading stance and coral-encrusted shell.

### 2. Mesh tri-budget breakdown
Body: 400 tris, Legs: 400 tris, Props (shell, antennae): 150 tris, FX (foam trails, particle limbs): 50 tris.

### 3. Body palette
- kelp_green (0.18, 0.42, 0.30) — shell and legs
- accent_coral (0.92, 0.50, 0.42) — mid-body segments
- water_deep (0.06, 0.16, 0.32) — underbelly and leg joints
- foam_white (0.94, 0.96, 0.98) — leg tips and trail effects

### 4. uBase marker assignments per body part
| body_part     | uBase |
|---------------|--------|
| Head          | 53     |
| Thorax        | 53     |
| Abdomen       | 53     |
| Legs (6)      | 53     |
| Shell         | 53     |
| Antennae      | 53     |
| Emissive      | 8      |

### 5. Idle animation
The coral_strider performs a slow, rhythmic leg lift every 2 seconds, alternating between two legs. The animation lasts 4 seconds per loop and includes subtle torso sway.

### 6. Walk/move animation
It walks with a slow, deliberate gait, lifting legs in a staggered, wave-like motion. Legs move at 0.5 Hz cadence, with 30° leg lift at peak step.

### 7. Attack telegraph
Before striking, the coral_strider lifts one leg high, exposing a bright coral glow at the joint, lasting 0.6 seconds.

### 8. Attack execution
It performs a sweeping swipe with its elevated leg, dealing 25 damage in a 1.5m wide arc. The strike is a melee swipe with a short cooldown.

### 9. Attack cooldown
The attack has a 1.8-second cooldown at base difficulty.

### 10. Hit-react animation
Upon taking damage, the coral_strider jolts and briefly flickers its shell, with a 0.5-second hit-react loop that ends with a staggered leg lift.

### 11. Death animation
The coral_strider collapses with a splash, its legs twitching and foam erupting from its body. A small mist cloud rises from its shell.

### 12. Aggro radius (m)
The coral_strider has a 10m aggro radius, locking onto the player when they come within that distance.

### 13. Attack range (m)
It attacks at 1.8m range, triggering its telegraph when the player is within that distance.

### 14. Movement speed (m/s)
The coral_strider moves at 2.2 m/s, slower than the player’s default speed.

### 15. Turn rate (rad/s)
It rotates at 2.5 rad/s, allowing for snappy directional changes.

### 16. Y-offset / locomotion plane
The coral_strider is a ground-walker at y=0, but occasionally floats slightly above the coral surface.

### 17. HP
The coral_strider has 160 HP, consistent with a mid-tier tank-like enemy, higher than forest wisp or desert scorpion, but lower than a shell brute or tree ent.

### 18. Damage
Each hit deals 25 damage, consistent with its HP and role as a semi-tank with high endurance and moderate offense.

### 19. XP reward
The XP reward is 83, calculated as (160 × 0.3 + 25 × 1.5).

### 20. Group spawn pattern
It spawns in loose-trio patterns, typically with 1–3 per spawn, rarely alone or in dense packs.

### 21. Spawn placement rules
It spawns on The_Wreck_D and Glasstop_C, avoiding Skywatch_E and Far_Reach_F.

### 22. Procedural variation
Variation includes a 0.3m scale range, 15° leg rotation freedom, and 3 palette variant indices for shell coloration.

### 23. Sound design — idle
A low, gurgling hum, reminiscent of underwater wind and tide.

### 24. Sound design — telegraph
A sharp, crackling sound, like coral snapping.

### 25. Sound design — hit/strike
A heavy, wet thud followed by a splash.

### 26. Particle FX tied to entity
- `drip_seafoam` — bubbles and foam trail from leg steps
- Triggers on leg lift and impact

### 27. Special ability or unique mechanic
The coral_strider can “glide” slightly above the coral surface when moving, leaving a faint trail of seafoam.

### 28. Player counter-strategy
Fireball and ice nova are effective; dash can bypass its slow attack pattern.

### 29. Mass / collider radius (m)
Collider radius is 0.8m, with a light mass for moderate knockback.

### 30. Edge-case interaction with biome
In a tide_pool, it floats slightly higher and leaves more foam. On a sky-bridge, it moves slower and occasionally drops into mist. Near a rune_gate, it becomes more erratic, flickering between visible and obscured states.

### Implementation hooks
- `src/game/enemy_config.zig` row 73
- `enemy_ai.zig` tick function `tickCoralStrider`
- `GameViewController.swift` `kEnemyNames` index 73
- `world.metal` fragment shader branches: `if (uBase == 53)` and `if (uBase == 8)`
---

## Enemy 74 — sky_archer
### 1. **One-line silhouette** — At 30m, the sky_archer appears as a vertical stick-figure with a bow stretched over a shoulder, easily distinguishable from the other enemies due to its elevated position, distinctive bow stance, and lack of ground contact.
### 2. **Mesh tri-budget breakdown** — Body: 300 tris, limbs: 200 tris, bow/props: 250 tris, FX: 50 tris. Total: 800 tris.
### 3. **Body palette** — sail_cream (0.88, 0.82, 0.66) for upper body, driftwood_grey (0.45, 0.42, 0.38) for lower limbs, kelp_green (0.18, 0.42, 0.30) for quiver, foam_white (0.94, 0.96, 0.98) for bow limbs.
### 4. **uBase marker assignments per body part** — torso → 58, left arm → 58, right arm → 58, legs → 0, quiver → 58, bow → 0.
### 5. **Idle animation** — Idle loop lasts 4 seconds, with a 1.5s pause at the center of the bow draw. The bow remains drawn, then retracts to the shoulder with a subtle motion.
### 6. **Walk/move animation** — Slow gait with a slight sway, feet lifting minimally. Legs swing with a 1.2s cadence. Movement is smooth, matching the elevated skywatch environment.
### 7. **Attack telegraph** — The bow is drawn back and held in a tight arc, with the arm extending fully. Visual indicator is a brief glow on the bowstring and a flash of mist around the draw.
### 8. **Attack execution** — The arrow is launched as a straight projectile with a slight arc, hitting with a piercing sound and a trail of mist. Damage is applied on impact.
### 9. **Attack cooldown** — 2.5 seconds at base difficulty.
### 10. **Hit-react animation** — The enemy flinches slightly and steps back, with a flicker of mist in the air. The bow is briefly lowered, and a small particle puff appears where hit.
### 11. **Death animation** — The enemy falls slowly, with mist and foam swirling around the body. A final puff of mist and a splash of foam occur on impact with the skywatch platform.
### 12. **Aggro radius (m)** — 30 meters.
### 13. **Attack range (m)** — 25 meters.
### 14. **Movement speed (m/s)** — 2.2 m/s.
### 15. **Turn rate (rad/s)** — 3.0 rad/s.
### 16. **Y-offset / locomotion plane** — Skywatch elevated (y=60), hovering slightly above the platform with no contact with ground.
### 17. **HP** — 120 HP. Justified as mid-tier for a ranged unit, balancing between the low HP of skitterers and the high HP of tanks.
### 18. **Damage** — 18 per hit. Consistent with HP and role, as a ranged attacker with moderate HP.
### 19. **XP reward** — 75 XP. Calculated as (120 × 0.3 + 18 × 1.5) = 36 + 27 = 63, rounded to 75 for balancing.
### 20. **Group spawn pattern** — Loose-trio, with one archer on a Skywatch platform, others in nearby positions.
### 21. **Spawn placement rules** — Skywatch_E only. Preferably on platforms with a clear view of the player.
### 22. **Procedural variation** — Scale range: 0.95–1.05, rotation freedom: ±10° on Y-axis, palette variant indices: 0–2 for each color swatch.
### 23. **Sound design — idle** — Soft creaking of wood and a whisper of mist in the wind.
### 24. **Sound design — telegraph** — A deep bowstring stretch sound, followed by a misty whoosh.
### 25. **Sound design — hit/strike** — A sharp twang from the bow and a soft thud from the arrow’s impact.
### 26. **Particle FX tied to entity** — `lantern_motes` — soft glowing particles that follow the bowstring, triggered during telegraph and attack.
### 27. **Special ability or unique mechanic** — The sky_archer can fire arrows that split into two on hit, affecting two targets.
### 28. **Player counter-strategy** — Ice Nova is effective to freeze the archer mid-telegraph. Lightning can interrupt the bow draw and reduce damage.
### 29. **Mass / collider radius (m)** — Collider radius: 0.8m, mass descriptor: light — it can be knocked back easily, but not pushed off platforms.
### 30. **Edge-case interaction with biome** — On Skywatch, it behaves normally. Near mist, the archer's attacks become more erratic and slightly slower. In tide pools, it may be vulnerable to water-based attacks.

### Implementation hooks
- `src/game/enemy_config.zig` line 74: `sky_archer = EnemyConfig{...}`
- `enemy_ai.zig` function `tick_sky_archer`
- `GameViewController.swift` index 74 in `kEnemyNames`
- Metal fragment shader branch: `if (uBase == 58) { ... }` for body and limbs, `if (uBase == 0) { ... }` for bow.
---

## Enemy 75 — barnacle_creeper
### 1. One-line silhouette — what shape does the player read at 30m? Why is it instantly distinguishable from the other 14 enemies in the game?
At 30m, the barnacle creeper appears as a large, irregularly shaped boulder with subtle barnacle protrusions and a few small glowing eyes. It is instantly distinguishable from other enemies due to its deceptive static silhouette, unlike the skitterers, floaters, or pack hunters that are immediately identifiable by movement or form.

### 2. Mesh tri-budget breakdown — body / limbs / props / FX. Sum equals EST_TRIS.
Body: 500 tris, Limbs: 180 tris, Props: 120 tris, FX: 50 tris.

### 3. Body palette — 4 swatches drawn from the Isles palette + where on the body each is applied.
- **driftwood_grey (0.45, 0.42, 0.38)** — main body shell texture.
- **kelp_green (0.18, 0.42, 0.30)** — moss-like patches on body edges.
- **accent_coral (0.92, 0.50, 0.42)** — glowing eye sockets.
- **water_deep (0.06, 0.16, 0.32)** — under-surface shadows and barnacle clusters.

### 4. uBase marker assignments per body part — table: body_part → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| Body Part       | uBase |
|----------------|--------|
| Main Shell     | 49     |
| Moss Patches   | 49     |
| Eye Sockets    | 8      |
| Barnacle Clusters | 49  |

(Reserved for barnacle_creeper is uBase 49 only. Eye sockets glow via generic emissive (8). Moss tinting comes from per-vertex color hash, not a separate shader branch.)

### 5. Idle animation — 1–3 sentences. Frequency, loop length, key beats.
The creeper slowly rocks back and forth with a 3.2s loop, mimicking a floating boulder. It gently pulses its eyes once every 4 seconds. The animation is slow and subtle, matching its disguise as a still rock.

### 6. Walk/move animation — gait, frequency, foot/limb cadence.
It drags its body along with a slow, undulating gait, using 4 pseudo-legs. Movement cadence is 2.1s per step, with each leg lifting and placing in sequence.

### 7. Attack telegraph — what the player sees in the 0.4–0.8s before the hit lands. Visual cue must be unambiguous.
Its eyes glow intensely for 0.6s, and small foam rings expand outward from its base before it lunges. The visual cue is unmistakably aggressive and directional.

### 8. Attack execution — the strike/hit moment. Damage delivery model (melee swipe, projectile, AoE).
It performs a sudden forward swipe with one of its pseudo-legs, dealing melee damage. The attack is a short-range swipe with a wide arc, not a projectile.

### 9. Attack cooldown — seconds between attacks at base difficulty.
2.5 seconds.

### 10. Hit-react animation — what plays when player lands a strike on this enemy.
The creeper recoils slightly, with its body shaking and a burst of foam FX from its surface. It briefly flicks its eyes off and on.

### 11. Death animation — 1–2 sentence description, including dust/spray/foam FX.
It collapses with a slow, creaking sound, spraying foam and barnacle debris in all directions. The eyes fade out one by one as it sinks into the sea.

### 12. Aggro radius (m) — how far away does it lock onto player.
8 meters.

### 13. Attack range (m) — distance at which step 7 telegraph triggers.
3 meters.

### 14. Movement speed (m/s) — base speed; reference player default 5.5 m/s.
1.2 m/s.

### 15. Turn rate (rad/s) — how snappy the rotation is.
0.3 rad/s.

### 16. Y-offset / locomotion plane — ground-walker (y=0), hovering (y=2.5), levitating from sea, on-mast climber, sky-walker on Skywatch (y=60), etc.
It walks on the sea floor, with a y-offset of 0.2 meters, slightly elevated to mimic a boulder on sand.

### 17. HP — choose a value consistent with role (skitterer 35..70, harasser 35..90, tank 240..380, pack 60..120, illusion 1..50). Justify in one sentence vs forest+desert comparators.
160 HP. This value is consistent with a slow, ambush-style enemy, balancing against forest Tree Ent (280 HP) and desert Carrion Spider (60 HP), and aligns with its role as a mid-tier tank with stealth.

### 18. Damage — per hit, consistent with HP and role. Justify.
30 damage. This is moderate for a tank-like enemy, consistent with its HP and role as a slow, powerful melee attacker that can be a danger in close combat.

### 19. XP reward — proportional to (HP × 0.3 + damage × 1.5).
XP = (160 × 0.3) + (30 × 1.5) = 48 + 45 = 93 XP.

### 20. Group spawn pattern — lone / paired / loose-trio / dense-pack / ambush-from-water / ambush-from-mast.
Ambush-from-water.

### 21. Spawn placement rules — which island(s)? Hub_A, Whale's_Spine_B, Glasstop_C, The_Wreck_D, Skywatch_E, Far_Reach_F. Specify.
The_Wreck_D and Glasstop_C only, spawning near tide pools or along the sea floor.

### 22. Procedural variation — scale range, rotation freedom, palette variant indices.
Scale: 0.9 to 1.1x. Rotation: ±15 degrees on Y-axis. Palette variants: 0–2 for color indices.

### 23. Sound design — idle — 1 line.
Low, gurgling ambient noise from beneath the surface.

### 24. Sound design — telegraph — 1 line.
A low, rhythmic thrumming, like a heartbeat.

### 25. Sound design — hit/strike — 1 line.
A sharp crack and splintering sound, like breaking coral.

### 26. Particle FX tied to entity — emitter preset name (mirror existing styles like `forest_motes`, `embers`, or new like `drip_seafoam`, `lantern_motes`), what it looks like, when it triggers.
`drip_seafoam` — bubbles and foam particles drip from body when moving or hit. Triggers on movement and on hit.

### 27. Special ability or unique mechanic — what makes this enemy different from a vanilla melee/ranged unit.
It is a disguised ambush unit, appearing as a boulder until it attacks. Its disguise can last up to 5 seconds after aggro, during which it remains undetected by most players.

### 28. Player counter-strategy — 1–2 lines on what skills work against it (fireball/lightning/ice_nova/dash).
Lightning is effective due to its boulder disguise — it is vulnerable to AoE attacks. Dash and knockback can break its disguise and force early attack.

### 29. Mass / collider radius (m) — body radius for collision, knockback inertia descriptor (light/medium/heavy).
Collider radius: 1.1 meters. Mass: Heavy — causes significant knockback on hit.

### 30. Edge-case interaction with biome — how does this enemy behave at a tide_pool, on a sky-bridge, near a rune_gate, in mist?
- **Tide Pool**: Fully functional; it can move and ambush within tide pools.
- **Sky-bridge**: Cannot spawn or function, as it requires sea-floor movement.
- **Rune Gate**: No effect — it is immune to rune-based mechanics.
- **Mist**: Aggro behavior remains unchanged, but its disguise becomes harder to detect.

### Implementation hooks
- `src/game/enemy_config.zig` row: 275
- `enemy_ai.zig` tick fn name: `barnacle_creeper_tick`
- GameViewController.swift `kEnemyNames` index: 75
- world.metal fragment branches needed:
```metal
if (uBase == 49) { color = mix(water_deep, driftwood_grey, noise); }
if (uBase == 51) { color = mix(accent_coral, foam_white, fbm(pos * 2.0)); }
```
---

## Enemy 76 — mirror_kraken_juvenile
### 1. One-line silhouette
A low, wide, and angular sea-glass body with 6 tentacles protruding from its sides, distinguishable by its refractive, ghostly sheen and lack of any sharp edges or hard surfaces seen in other enemies.

### 2. Mesh tri-budget breakdown
Body: 600 tris, Limbs: 300 tris, Props: 150 tris, FX: 50 tris.

### 3. Body palette
- **water_shallow** (0.30, 0.60, 0.75) — base body shell and core.
- **kelp_green** (0.18, 0.42, 0.30) — tentacle undersides and small coral-like accents.
- **accent_coral** (0.92, 0.50, 0.42) — rim highlights and secondary tentacle bands.
- **mist_low** (0.82, 0.86, 0.88) — translucent highlights and foam edges.

### 4. uBase marker assignments per body part
| Body Part        | uBase |
|------------------|-------|
| Body Core        | 54    |
| Tentacle Base    | 53    |
| Tentacle Tips    | 54    |
| Body Rim         | 53    |
| Emissive Highlights | 8  |

### 5. Idle animation
Slow, rhythmic undulation of tentacles, synchronized with a subtle pulse of light from the body core, lasting 10 seconds with a 2-second key beat at mid-point.

### 6. Walk/move animation
Slow, slithering gait with a rolling motion; tentacles move in sync with body, each limb touches the ground in a 3-step cadence, 1.5 seconds per step.

### 7. Attack telegraph
Tentacles curl inward and emit a glowing pulse along their length, followed by a shimmering ripple across the body surface.

### 8. Attack execution
Tentacles lash outward in a wide arc, dealing area-of-effect damage with a wave-like motion; each hit is a 1.5m radius projectile with a soft impact FX.

### 9. Attack cooldown
5.0 seconds between attacks.

### 10. Hit-react animation
Body shimmers, tentacles curl inwards, and a flash of white light erupts from the point of impact.

### 11. Death animation
Body dissolves into a spray of sea foam and mist, tentacles collapse, and the core slowly fades to black with a final shimmer.

### 12. Aggro radius (m)
18 meters.

### 13. Attack range (m)
10 meters.

### 14. Movement speed (m/s)
3.0 m/s.

### 15. Turn rate (rad/s)
3.5 rad/s.

### 16. Y-offset / locomotion plane
Ground-walker, y = 0.5 meters; floats just above the sea floor and drifts slightly.

### 17. HP
220 HP. This is consistent with the elite rare role, higher than typical skitterers or harassers, but lower than a tank such as the shell_brute or mast_serpent.

### 18. Damage
42 per hit. This is proportional to its HP and reflects its role as a ranged tentacle attacker, balancing damage and survivability.

### 19. XP reward
111 XP. (220 × 0.3 + 42 × 1.5 = 66 + 63 = 129, rounded to 111).

### 20. Group spawn pattern
Ambush-from-water; spawns from tide pools or shallow sea areas, in loose-trio formations.

### 21. Spawn placement rules
Spawns in The_Wreck_D and Whale's_Spine_B only, preferring tide pools and coral areas.

### 22. Procedural variation
Scale range: 0.9 to 1.1x; rotation freedom: ±10 degrees; palette variant indices: 0–2 for all swatches.

### 23. Sound design — idle
Low, resonant oceanic hum with ambient tentacle flexing.

### 24. Sound design — telegraph
A sharp, resonant “squelch” sound that builds in frequency before attack.

### 25. Sound design — hit/strike
A sharp, crackling “snap” and a low, reverberating “thud” on impact.

### 26. Particle FX tied to entity
`drip_seafoam` — emits small droplets of translucent foam from body edges, triggered during idle and attack.

### 27. Special ability or unique mechanic
Refractive body that distorts light and occasionally reflects projectiles, reducing incoming damage by 20% if hit by a projectile.

### 28. Player counter-strategy
Ice Nova and Lightning are effective; Ice slows movement and reduces reflection chance, Lightning breaks the refractive shell.

### 29. Mass / collider radius (m)
Collider radius: 2.2 meters; mass descriptor: medium.

### 30. Edge-case interaction with biome
In tide pools, it becomes more aggressive and spawns additional tentacles. On a sky-bridge, it hovers slightly above and avoids the edges. Near rune_gates, it pulses more intensely. In mist, its body becomes semi-transparent and harder to track.

### Implementation hooks
- `src/game/enemy_config.zig`, row 76
- `enemy_ai.zig`, tick function `tick_mirror_kraken_juvenile`
- `GameViewController.swift`, `kEnemyNames` index 76
- `world.metal`, fragment shader branches: `if (uBase == 54)`, `if (uBase == 53)`
---

# Per-asset detail (64 × 30+ features)

## Asset 77 — driftwood_bridge
```
### 1. Silhouette at 30m
From a distance of 30 meters, the driftwood bridge presents as a long, low-lying structure with a slight upward arc, appearing as a narrow, weathered wooden path that bridges the gap between two islands, its form softened by natural decay and subtle environmental wear.

### 2. Tri-budget breakdown
The mesh is divided into 240 tris for the main body, 60 tris for decorative plank details, and 20 tris for small weathered supports and rope elements, summing to the EST_TRIS of 320.

### 3. Geometry construction
The bridge is built using a central mbCylinder for the main support structure, with tapered ends extending into mbSphere-based cap nodes for stability. Extruded wooden planks are layered over the main surface to simulate a walkable deck, and a fan of triangles is used for a thin rope railing on either side.

### 4. Body palette
The body uses driftwood_grey for the primary structure, sand_wet for the weathered plank surfaces, beach_dune for the under-deck texture, and accent_pearl for the highlights on rope and support posts.

### 5. uBase marker assignments per surface
| Surface             | uBase |
|---------------------|-------|
| Main support        | 0     |
| Plank deck          | 51    |
| Rope railing        | 0     |
| Support post caps   | 8     |

### 6. Base scale (scale_min, scale_max)
Scale is between 0.8 and 1.2. This range allows for natural variation in driftwood size and ensures the bridge doesn’t appear too uniform or too exaggerated.

### 7. Y rotation
Aligned-to-bridge. The asset rotates to match the directional vector between the two connected islands, ensuring natural alignment with the path of travel.

### 8. Ground anchor
The bridge sits partially on island surfaces (y=island_y), with its endpoints embedded into the island terrain to appear naturally rooted and stable.

### 9. Procedural variation method
Two instances differ by scale spread and a palette hash that adjusts the tint of driftwood_grey and sand_wet to reflect natural weathering variation.

### 10. Spawn placement rules — which island(s)
Spawns on islands A↔B, B↔D, D-stairs, D↔E, and E↔F. Within each island, spawn radius is 50–80m. Biome-zone is beach edge or boundary ring. Avoid-list includes any high-traffic or temple plaza zones.

### 11. Spawn count rationale
With an estimated radius of 900m and ISLAND_BIAS, 5 instances are sufficient to provide visual continuity across the lagoon without over-saturating the landscape or creating visual clutter.

### 12. Clustering pattern
Scattered-grid. Instances are spaced evenly across the lagoon, avoiding direct overlap and ensuring a natural flow.

### 13. Inter-asset spacing minimum (m)
Minimum 40 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
0 meters, as the bridge is designed to be fully walkable and integrated into the path system.

### 15. Team color reasoning
TEAM=53 is chosen to represent a neutral, walkable bridge in the context of the Drifting Isles. It resolves to driftwood_grey in the `game_fill_draws` switch, consistent with the material’s appearance.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob beneath to simulate the gap beneath the bridge. No vertex AO is used due to the low complexity of the mesh.

### 17. Distant-LOD strategy
Does not implement LOD; it remains visible at all distances, as it is a key architectural element that supports the visual flow of the islands.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side is tinted with a warm driftwood_grey hue, while shadow-side shows a cool sand_wet tone with faint mist-side coloration.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.8 to allow for natural path walking while preventing clipping.

### 22. Destructible
No.

### 23. Lore hook
A remnant of the ancient shipwreck that once connected the islands, now weathered into a natural footbridge.

### 24. Surface UV layout
Main support uses uBase 0, plank deck uses uBase 51, rope railing is default (0), and post caps use uBase 8 for emissive lighting.

### 25. Material specularity
Soft-glossy with subtle reflectivity to mimic aged wood, not overly shiny but with enough sheen to appear realistic under dynamic lighting.

### 26. Day/night appearance shift
During the day, the bridge appears warm and sun-warmed with driftwood_grey and sand_wet hues. At night, the shadow side takes on a cool, misty blue tint, and the rope posts emit a faint amber glow.

### 27. Silhouette test at 50 m
Yes, the silhouette remains clear and distinct at 50 meters, with enough contrast and shape definition to be visually recognizable.

### 28. Visual neighbours
Looks right next to forested island edges, rocky cliffs, and other wooden structures like driftwood posts or broken ship masts.

### 29. Visual conflicts
Should not be placed near dense forest zones or other wooden structures like bridges or platforms, as it may cause silhouette overlap or confusion.

### 30. Implementation hooks
- `src/main.zig`: Add case `53: .driftwood_bridge` to the `world.team` switch.
- `ios/Mesh.swift`: Add `makeDriftwoodBridge(device:)` function.
- `ios/GameViewController.swift`: Add dispatch case for `driftwood_bridge` in the mesh instantiation logic.
```
---

## Asset 78 — rope_bridge
### 1. **Silhouette at 30m** — From across the lagoon, the rope_bridge appears as a low, sinuous line of dark planks suspended between two islands, with the gentle sway of the ropes barely perceptible against the deep blue water.

### 2. **Tri-budget breakdown** — Body: 180 tris; Decorations: 40 tris; FX: 20 tris.

### 3. **Geometry construction** — The main body is built from a `mbCylinder` for the rope core, with a series of `mbCylinder` extrusions forming the plank walkway. The plank ends are capped with `mbSphere` for natural curvature. Additional decorative elements like rope tassels and plank joints are constructed from small `mbCylinder` segments, arranged in a fan of triangles to simulate woven rope.

### 4. **Body palette** — Uses `driftwood_grey`, `sail_cream`, `accent_coral`, and `kelp_green`. Driftwood grey covers the plank surfaces; sail cream is used for rope highlights; accent coral for the rope tassels; kelp green for the plank undersides to suggest wetness.

### 5. **uBase marker assignments per surface** — 
| Surface | uBase |
|--------|-------|
| Plank top | 51 |
| Rope core | 52 |
| Plank undersides | 0 |
| Tassels | 51 |

### 6. **Base scale (scale_min, scale_max)** — Scale range 0.8 to 1.2. This allows for visual variety without breaking the bridge's structural coherence or affecting gameplay.

### 7. **Y rotation** — Aligned-to-island-radial. The bridge aligns with the radial vector from the island center to its midpoint, creating a natural and immersive path.

### 8. **Ground anchor** — Sits on island surface (y=island_y) with the bridge’s ends securely anchored to each island’s edge, slightly embedded to simulate a natural, weathered connection.

### 9. **Procedural variation method** — Two instances differ by scale spread and color palette hash, using a deterministic palette generator to ensure visual uniqueness while maintaining cohesion.

### 10. **Spawn placement rules — which island(s)** — Spawns on islands B, C, D, and E. Radius within island is 10–30m. Biome-zone: beach edge or cliff face. Avoid-list: temple plaza, boundary ring.

### 11. **Spawn count rationale** — The `est_count = 4` is correct because the total radius of 900m across the islands allows for 4 distinct bridge placements, with sufficient spacing to avoid visual clutter and maintain path variety.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced evenly across the islands to avoid clumping while ensuring connectivity and visual interest.

### 13. **Inter-asset spacing minimum (m)** — 15m minimum distance from another rope_bridge instance.

### 14. **Path-clearance distance (m)** — 0m. Bridges are placed directly on the path and do not block or obstruct player movement.

### 15. **Team color reasoning** — TEAM=53 is chosen to reflect a muted, neutral color palette that blends with the drifting isles’ aesthetic, resolving to `accent_pearl` in the `game_fill_draws` switch.

### 16. **Shadow / contact AO strategy** — Casts shadow; uses a ground AO blob with soft falloff. No vertex AO due to the bridge’s low profile.

### 17. **Distant-LOD strategy** — Disappears at 100m distance. No LOD simplification, maintaining fidelity to the bridge’s detailed rope and plank structure.

### 18. **Animation, if any** — Static, no animation. The sway is simulated via procedural deformation in the vertex shader.

### 19. **Particle FX bound to entity** — None.

### 20. **Lighting interaction** — Sun-side warm tint from `sail_cream` and `accent_coral`, while shadow-side takes on a cooler, `kelp_green`-tinted tone.

### 21. **Collision** — Yes, blocks player movement. `world.radius` set to 0.8m, matching the bridge’s narrow plank width.

### 22. **Destructible** — No. The bridge is a permanent fixture of the island topology.

### 23. **Lore hook** — A relic of a bygone era, the bridge once connected two parts of the Drifting Isles before the sea claimed one side, now serving as a reminder of the islands’ fractured past.

### 24. **Surface UV layout** — Plank top uses uBase 51 for texture; rope core uses uBase 52; undersides default to uBase 0; tassels also use uBase 51 for consistency.

### 25. **Material specularity** — Soft-glossy. Reflects subtle highlights on the planks and ropes without appearing overly shiny.

### 26. **Day/night appearance shift** — Sun-side retains warm tones of `sail_cream` and `accent_coral`, while shadow-side shifts to a cooler `kelp_green`-tinted hue.

### 27. **Silhouette test at 50 m** — Yes, the bridge remains clearly visible and recognizable from 50m away, with its rope-and-plank structure distinct against the horizon.

### 28. **Visual neighbours** — Looks right next to `driftwood_log`, `tide_pool`, and `sea_urchin` — all part of the same drifting isles ecosystem.

### 29. **Visual conflicts** — Should not spawn near `lighthouse`, `portal_ring`, or `floating_island`, as these assets would compete for visual attention and silhouette clarity.

### 30. **Implementation hooks** — 
- In `src/main.zig`: Add case `53 => rope_bridge` to `world.team` switch.
- In `ios/Mesh.swift`: Add `makeRopeBridge(device:)` function.
- In `ios/GameViewController.swift`: Add dispatch case `case 78: return makeRopeBridge(device: device)`.

```metal
float3 sway(float3 pos, float time) {
    float sway_amount = sin(time * 0.5) * 0.1;
    return pos + float3(0, sway_amount, 0);
}
```
---

## Asset 79 — rune_gate_arch
1. **Silhouette at 30m** — From across the lagoon, the rune_gate_arch appears as a tall, curved arch with a glowing rune portal at its center, evoking a mystical gateway between worlds.

2. **Tri-budget breakdown** — Body: 240 tris, Decorations: 100 tris, FX: 40 tris.

3. **Geometry construction** — The main body is a large, slightly tapered cylinder (mbCylinder) with a ringed base and a top that narrows into a portal-like opening. Decorative runes are extruded from the arch face using a fan of triangles, and a spherical core is embedded at the center to represent the portal's glow. The structure is built in three major components: the main arch, the rune embellishments, and the inner portal core.

4. **Body palette** — The main body uses driftwood_grey for the arch surface, sand_wet for the base ring, and accent_pearl for the portal rim. The inner core uses ember_lantern for a warm, glowing effect.

5. **uBase marker assignments per surface** — 
| Surface | uBase |
|--------|-------|
| Arch body | 51 |
| Base ring | 53 |
| Portal core | 61 |
| Rune embellishments | 0 |

6. **Base scale (scale_min, scale_max)** — scale_min: 1.0, scale_max: 1.4. Slight variation ensures visual interest without breaking the architectural integrity of the structure.

7. **Y rotation** — aligned-to-island-radial. Rotates to face inward toward the center of the island it resides on, creating a directional entrance feel.

8. **Ground anchor** — sits on island surface (y=island_y). The base is fully planted and stable, ensuring no floating or partial-burial.

9. **Procedural variation method** — 2 instances differ by palette hash (color variation in runes and base ring) and scale spread (small size variation).

10. **Spawn placement rules — which island(s)** — Spawns on islands A, C, D, E, F (excluding B). Within each island, spawn radius is 5–10m from the island edge. Biome-zone: boundary ring or temple plaza. Avoid-list: near other large arch structures or teleport gates.

11. **Spawn count rationale** — `est_count = 6` is correct for a 900m radius zone because each instance is spaced approximately 150m apart, ensuring a good distribution of visual markers without overcrowding the landscape.

12. **Clustering pattern** — scattered-grid. Instances are spaced to avoid clustering while still maintaining a coherent architectural theme.

13. **Inter-asset spacing minimum (m)** — 25m minimum distance from another instance of the same mesh.

14. **Path-clearance distance (m)** — 6m. It is placed far enough from paths to avoid obstructing movement, while still being visually connected to the island's layout.

15. **Team color reasoning** — TEAM=54 is chosen to match the emissive rune effect. It resolves to ember_lantern in the `game_fill_draws` switch, ensuring consistent lighting and rendering with the glowing portal.

16. **Shadow / contact AO strategy** — casts shadow using a ground AO blob with a soft falloff. Vertex-AO is not used to avoid over-darkening the structure.

17. **Distant-LOD strategy** — does not undergo LOD. Forest assets do not simplify at distance, so this asset will remain at full resolution.

18. **Animation, if any** — static, no animation. The rune portal glows softly but does not animate.

19. **Particle FX bound to entity** — `lantern_glow` — emits a soft, warm light around the portal core.

20. **Lighting interaction** — sun-side warm tint with ember_lantern glow, mist-side cool tint with a blue-tinged ambient glow.

21. **Collision** — yes, it blocks player movement. `world.radius` is set to 1.0 to represent a solid structure.

22. **Destructible** — no. It is a permanent architectural element, not intended to break or be destroyed.

23. **Lore hook** — This ancient gate once opened to a forgotten realm, now serving as a beacon for those who seek the lost paths of the drifting isles.

24. **Surface UV layout** — uBase 51 covers the arch body, 53 the base ring, 61 the portal core, and 0 the runes. The core and runes are UV-mapped with a subtle noise pattern to simulate rune etchings.

25. **Material specularity** — soft-glossy. The main surfaces are slightly reflective, while the portal core is emissive-additive.

26. **Day/night appearance shift** — during the day, the gate appears warm with a golden tint from the runes; at night, it glows more intensely with a cool blue hue in the shadows.

27. **Silhouette test at 50 m** — yes, it still reads clearly at 50m, maintaining the arch's silhouette and portal glow.

28. **Visual neighbours** — looks right next to `forest_tower`, `beach_coral_reef`, and `island_temple`, creating a cohesive theme of ancient architecture and mystical landscapes.

29. **Visual conflicts** — should not be near `skywatch_lantern`, `sea_cave_entrance`, or `waterfall_hollow`, as these elements already dominate the visual field and would clash with the arch's presence.

30. **Implementation hooks** — 
- Add `case 54: return .rune_gate_arch` to `world.team` switch in `src/main.zig`.
- Add `func makeRuneGateArch(device: MTLDevice) -> [MTLBuffer]` to `ios/Mesh.swift`.
- Add `case .rune_gate_arch:` to `dispatch` in `ios/GameViewController.swift`.
---

## Asset 80 — plank_walkway
1. **Silhouette at 30m** — From across the lagoon, the plank walkway appears as a narrow, elongated platform extending from the shore, with a slight upward curve that suggests a bridge or elevated walkway over shallow water.

2. **Tri-budget breakdown** — Body: 160 tris; Decorations: 20 tris; FX: 20 tris.

3. **Geometry construction** — The main structure uses a `mbCylinder` to form the central plank body, with a slightly tapered design to mimic a weathered wooden beam. Two `mbSphere` elements are used for the end caps to add a rounded finish. Extruded rings are added to simulate plank edges and cross-supports.

4. **Body palette** — The primary surface uses `driftwood_grey` for a weathered wood appearance, with `sand_wet` applied to the base edges and `foam_white` for a subtle highlight on the top surface to simulate wetness and sun reflection.

5. **uBase marker assignments per surface** —
| Surface | uBase |
|---------|--------|
| Plank body | 51 |
| End caps | 49 |
| Cross supports | 0 |
| Highlighted top | 51 |

6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.2. This variation adds natural randomness to mimic different ages and wear of the planks without disrupting visual consistency or gameplay.

7. **Y rotation** — Aligned-to-shore-tangent. The walkway rotates to match the island’s shoreline, enhancing realism and integration with the terrain.

8. **Ground anchor** — Partially buried. The walkway sits on the island surface but is slightly embedded into the ground to simulate a natural transition from land to water.

9. **Procedural variation method** — Instances differ by palette hash and scale spread. The palette hash modifies the color tint slightly, while scale variation changes the plank length and width.

10. **Spawn placement rules — which island(s)** — Spawns on islands A, D, and F. Radius within island: 15–30m. Biome-zone: beach edge. Avoid-list: other walkways or bridge assets.

11. **Spawn count rationale** — With an estimated 900m radius and ISLAND_BIAS of A:2 D:3 F:3, 8 instances ensure adequate coverage across the beach edges while maintaining a sparse, natural density.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid clustering but maintain a sense of purposeful pathing or island access.

13. **Inter-asset spacing minimum (m)** — 8 meters minimum from another plank_walkway instance.

14. **Path-clearance distance (m)** — 6 meters from the ISLAND-LOCAL path. This ensures safe passage while maintaining visual presence.

15. **Team color reasoning** — TEAM=53 is chosen to distinguish the walkway from other wooden assets in the biome, aligning with the `game_fill_draws` switch to provide a unique team color. It resolves to `driftwood_grey`.

16. **Shadow / contact AO strategy** — Casts shadow. Uses vertex-AO to simulate contact with ground, enhancing realism without heavy performance cost.

17. **Distant-LOD strategy** — No LOD. The forest mesh system does not implement LODs; this asset will remain at full resolution across all distances.

18. **Animation, if any** — Static, no animation.

19. **Particle FX bound to entity** — None. The asset does not require particle effects.

20. **Lighting interaction** — Sun-side warm tint with a slight amber hue, shadow-side cool tint with a blue cast, reflecting the interplay of light and wet wood.

21. **Collision** — Yes. Blocks player movement. `world.radius` set to 0.6.

22. **Destructible** — No. The walkway is not destructible; it represents a permanent island feature.

23. **Lore hook** — Once used by island explorers to cross shallow waters to gather kelp and driftwood.

24. **Surface UV layout** — uBase 51 covers the plank body, 49 covers the end caps, 0 covers cross supports, and 51 is used for the top highlight.

25. **Material specularity** — Soft-glossy. Slight sheen to simulate the weathered wood surface.

26. **Day/night appearance shift** — During the day, sun-side appears warm and amber, while shadow-side cools to a blue-gray. At night, the walkway glows faintly with a warm undertone.

27. **Silhouette test at 50 m** — Yes. The walkway remains clearly visible at 50 meters, with a strong contrast between the plank body and water.

28. **Visual neighbours** — Looks right next to `driftwood_pile`, `kelp_cluster`, and `beach_dune`.

29. **Visual conflicts** — Should not be near `tall_palm`, `stone_cairn`, or `portal_halo` as these would visually clash or overpower the platform.

30. **Implementation hooks** — 
- Add `case 53` in `world.team` switch in `src/main.zig`.
- Add `makePlankWalkway(device:)` function in `ios/Mesh.swift`.
- Add dispatch case in `ios/GameViewController.swift` to call `makePlankWalkway` for instances of this mesh.
---

## Asset 81 — wet_sand_patch
### 1. Silhouette at 30m
From across the lagoon, a wet sand patch appears as a low, diffuse discoid mass, slightly darker than the surrounding dune, with no sharp edges or elevation contrast to draw attention.

### 2. Tri-budget breakdown
Body: 90 tris, Decorations: 20 tris, FX: 10 tris. Total: 120 tris.

### 3. Geometry construction
The base geometry uses a `mbCylinder` with a tapered profile to simulate a shallow, flattened sand mound, approximately 1.5 meters in diameter and 0.3 meters in height. The top surface is slightly concave to mimic water pooling, and a few `mbSphere` elements are added for minor textural bumps. Extrusions include a few small sand ripples, created with a fan of triangles radiating from the base.

### 4. Body palette
Uses `sand_wet`, `beach_dune`, `water_shallow`, and `driftwood_grey` to simulate a wet sand patch near the tideline, where sand meets shallow water and driftwood.

### 5. uBase marker assignments per surface
| Surface | uBase |
|---------|-------|
| Base sand | 48 |
| Ripple detail | 48 |
| Water pooling | 48 |
| Driftwood clump | 0 |

(All wet-sand surfaces use uBase=48 — wet_sand_patch is reserved only for that marker. Driftwood embedded in the patch uses default 0 since this isn't a wood-shader asset.)

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. Justification: To create natural variation in size while staying within the beach edge scale range, avoiding overly large or dwarfed instances.

### 7. Y rotation
Random `0..2π`. Each instance is rotated independently to simulate natural drift.

### 8. Ground anchor
Partially buried, sitting on the island surface with y=island_y + 0.05, and 10% of the volume below the surface to suggest immersion.

### 9. Procedural variation method
Each instance varies in scale and color tint using a hash of the instance position, creating unique, non-repetitive patches.

### 10. Spawn placement rules — which island(s)
Spawn on islands A, D, F. Radius: 30–60m from island center. Biome-zone: beach edge. Avoid-list: no other wet sand patches, no dense forest elements, no islands with active bridges.

### 11. Spawn count rationale
With an estimated 900m radius and ISLAND_BIAS, 130 instances provide even distribution across beach edges, with 43 patches per island, matching visual density without overcrowding.

### 12. Clustering pattern
Scattered-grid. Instances spaced to avoid visual clustering but maintain a natural beach patch look.

### 13. Inter-asset spacing minimum (m)
Minimum 1.2 meters to another instance of the same mesh.

### 14. Path-clearance distance (m)
8 meters from any island-local path (bridges excluded).

### 15. Team color reasoning
TEAM=55 chosen to align with `sand_wet` and `beach_dune` color family for consistency in beach biome rendering. Resolves to `sand_wet` in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts shadow. Ground AO blob used with a soft falloff to simulate sand settling into the terrain.

### 17. Distant-LOD strategy
Does not simplify or disappear at distance. Matches forest asset behavior: no LOD.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side: warm tint with slight glow from `sand_wet`. Shadow-side: cooler, muted tones, blending into `water_shallow`.

### 21. Collision
Blocks player movement. `world.radius` set to 0.6 to simulate a solid, albeit low-lying, terrain patch.

### 22. Destructible
No.

### 23. Lore hook
A recent tide has left a wet patch of sand, still warm from the sun, where small crabs scurry beneath.

### 24. Surface UV layout
uBase 48 covers base sand, 49 covers ripple details, 50 covers water pooling, 51 covers driftwood clump.

### 25. Material specularity
Soft-glossy. Reflects light softly, mimicking wet sand.

### 26. Day/night appearance shift
Sun-side: warm, golden tint from `sand_wet`. Shadow-side: cool, blue-gray from `water_shallow`.

### 27. Silhouette test at 50 m
Yes, the low, rounded silhouette still reads clearly at half the average view distance.

### 28. Visual neighbours
Looks right next to `driftwood_clump`, `kelp_fan`, and `seaweed_tendril`.

### 29. Visual conflicts
Should not appear near `shell_cluster`, `rock_pile`, or `tidepool` — these would cause silhouette clashing or visual overload.

### 30. Implementation hooks
In `src/main.zig`: Add `case 55 =>` in `world.team` switch. In `ios/Mesh.swift`: Add `makeWetSandPatch(device:)` function. In `ios/GameViewController.swift`: Add `case 81:` dispatch case.
---

## Asset 82 — surf_foam
1. **Silhouette at 30m** — A thin, ring-shaped foam structure with a soft, curling edge that blends into the beach's wet sand, resembling a delicate sea spray arc.
2. **Tri-budget breakdown** — Body: 80 tris, Decorations: 15 tris, FX: 5 tris.
3. **Geometry construction** — Constructed using a mbCylinder for the main ring shape with a tapering radius from 1.0 to 0.3, followed by a mbSphere for a soft, rounded top cap. Additional extrusions of fan triangles create a wavy foam edge effect to simulate ocean foam movement.
4. **Body palette** — foam_white, sand_wet, beach_dune, and accent_pearl — covering the main body and soft edges, with the latter two used for subtle texture variation on the sand contact surface.
5. **uBase marker assignments per surface** —  
| Surface | uBase |
|--------|-------|
| Foam ring body | 48 |
| Sand contact | 45 |
| Wave tip | 0 |
| Emissive edge | 8 |
6. **Base scale (scale_min, scale_max)** — (0.8, 1.4). Slight variation to prevent repetition and maintain a natural, organic look across the beach edge.
7. **Y rotation** — aligned-to-shore-tangent.
8. **Ground anchor** — sits on island surface (y=island_y).
9. **Procedural variation method** — 2 instances differ by scale spread and minor UV offset.
10. **Spawn placement rules — which island(s)** — A, D, F only. Spawn radius within 10–20m of island edge. Biome-zone: beach edge. Avoid-list: island temple zones.
11. **Spawn count rationale** — With 110 instances, the total coverage of the 900m radius beach edge is adequately filled, especially along A, D, and F where the tide line is most active.
12. **Clustering pattern** — scattered-grid.
13. **Inter-asset spacing minimum (m)** — 1.2m.
14. **Path-clearance distance (m)** — 6m.
15. **Team color reasoning** — TEAM=55 maps to the foam_white palette, chosen to align with the light, airy nature of the asset. It’s a clean, neutral color for the `game_fill_draws` switch.
16. **Shadow / contact AO strategy** — casts shadow? Yes, ground AO blob.
17. **Distant-LOD strategy** — at 80m it disappears. Forest does no LOD; this asset matches that approach.
18. **Animation, if any** — static, no animation.
19. **Particle FX bound to entity** — `drip_seafoam` emitter for subtle floating particles at the foam tip.
20. **Lighting interaction** — sun-side warm tint with a slight glow, mist-side cool tint with a desaturated hue.
21. **Collision** — does it block player movement? No. `world.radius` = 0.2.
22. **Destructible** — no.
23. **Lore hook** — A remnant of a storm’s fury, left behind to whisper of the ocean’s power.
24. **Surface UV layout** — uBase 48 covers the main foam ring, 45 covers the sand contact, 0 is used for the tip edge, and 8 is used for the emissive edge glow.
25. **Material specularity** — soft-glossy.
26. **Day/night appearance shift** — sun-side warm tint with slight orange glow, shadow-side cool tint with a bluish hue.
27. **Silhouette test at 50 m** — yes, it still reads clearly as a thin, curling ring shape.
28. **Visual neighbours** — looks right next to `surf_sand`, `surf_rock`, and `surf_kelp` for a cohesive beach edge composition.
29. **Visual conflicts** — should not spawn near `surf_wreck` or `surf_driftwood` as it would visually clash with their heavier, darker silhouettes.
30. **Implementation hooks** —  
- Add `case 55:` in `src/main.zig` under `world.team` switch  
- Add `makeSurfFoam(device:)` in `ios/Mesh.swift`  
- Add `case 82:` in `ios/GameViewController.swift` dispatch for `makeMesh()`  

```metal
float3 color = mix(foam_white, accent_pearl, fbm(pos * 2.0, 3));
```
---

## Asset 83 — beach_pebble_pile
### 1. **Silhouette at 30m** — From a distance of 30 meters, the pebble pile appears as a soft, rounded blob with a slightly raised rim, suggesting a small, natural accumulation of smooth stones.

### 2. **Tri-budget breakdown** — Body: 100 tris. Decorations: 30 tris. FX: 10 tris. Total: 140 tris.

### 3. **Geometry construction** — The core geometry is built using a `mbSphere` for the main pebble mass, with a `mbCylinder` for a subtle protruding base. Additional pebble details are modeled using a fan of triangles around the top surface to simulate a scattered, rounded texture. The shape is static and does not require extrusions or complex morphing.

### 4. **Body palette** — The main body uses `sand_wet`, `beach_dune`, and `foam_white` to simulate a wet, rounded pebble pile with light surface highlights and sand-like texture.

### 5. **uBase marker assignments per surface** — Surface 1 (main pebble mass): uBase 0; Surface 2 (top scatter): uBase 47; Surface 3 (base): uBase 0.

### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.2. This range allows for subtle variation in size, keeping the pebbles visually cohesive while maintaining the illusion of random natural accumulation.

### 7. **Y rotation** — Random `0..2π`. Each instance is rotated independently to avoid repetitive alignment.

### 8. **Ground anchor** — Partially buried, with y_offset = -0.2. This gives a natural look of pebbles sitting just below the surface of the sand.

### 9. **Procedural variation method** — Instances vary by scale spread and surface color palette, derived from a hash of the instance’s position. This ensures no two pebble piles look exactly alike.

### 10. **Spawn placement rules — which island(s)** — Spawns on islands A, D, and F. Radius within island: 100–180 m. Zone: beach edge or boundary ring. Avoid-list: bridges, temple plazas, and high-traffic paths.

### 11. **Spawn count rationale** — With 120 instances across 3 islands and a 900 m radius, the density ensures a natural distribution without over-saturating any single area, particularly along the beach edges where pebbles would naturally accumulate.

### 12. **Clustering pattern** — Scattered-grid. Instances are distributed in a loose grid to mimic natural accumulation but not in rigid groups.

### 13. **Inter-asset spacing minimum (m)** — 2.5 meters. This ensures pebble piles don’t visually crowd each other.

### 14. **Path-clearance distance (m)** — 6 meters. Instances will not spawn within 6 meters of any path, including bridge walkways.

### 15. **Team color reasoning** — TEAM=56 corresponds to `accent_pearl` in the `game_fill_draws` switch. This team color allows the pebble pile to blend subtly with the beach environment while still being distinct in a group of objects.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow with a small ground AO blob to simulate contact with the sand. No vertex AO is used to preserve performance.

### 17. **Distant-LOD strategy** — No LOD. The asset will remain visible at all distances, consistent with the forest asset strategy.

### 18. **Animation, if any** — Static, no animation. The pebbles do not move or change appearance over time.

### 19. **Particle FX bound to entity** — None. The asset does not emit particles.

### 20. **Lighting interaction** — On the sun-facing side, the pebble pile takes on a warm, golden tint from the `accent_pearl` palette. On the shadowed side, it adopts a cooler, bluish tint from `water_deep`.

### 21. **Collision** — Does not block movement. The `world.radius` is set to 0.3, allowing the player to walk through the pebble pile without obstruction.

### 22. **Destructible** — No. This asset is not destructible and will not break or change appearance on impact.

### 23. **Lore hook** — The pile is a remnant of a recent tide that brought smooth stones from the deeper lagoon to the shore.

### 24. **Surface UV layout** — uBase 0 covers the main body, uBase 47 covers the top scatter pebbles, and uBase 0 is also assigned to the base to maintain consistent shading.

### 25. **Material specularity** — Soft-glossy. The surface reflects light gently to simulate wet sand and pebble interaction.

### 26. **Day/night appearance shift** — During the day, sun-facing pebbles are warm and bright. At night, they shift to a cooler, dimmer tone with a slight ambient glow.

### 27. **Silhouette test at 50 m** — Yes. At 50 meters, the pebble pile remains distinguishable as a rounded blob, maintaining its silhouette and visual impact.

### 28. **Visual neighbours** — Looks best next to `driftwood`, `kelp`, and `sand_dune` assets. These complement the beach environment and maintain the natural aesthetic.

### 29. **Visual conflicts** — Should not be placed near `forest_tower`, `temple_statue`, or `bridge_railing`, as these elements would visually overpower the pebble pile and reduce its subtle presence.

### 30. **Implementation hooks** — In `src/main.zig`, add case `56: .pebble_pile` to `world.team` switch. In `ios/Mesh.swift`, add `makePebblePile(device:)` function. In `ios/GameViewController.swift`, add dispatch case for `pebble_pile` in the `spawnMesh` logic.
---

## Asset 84 — tide_line_decal
### 1. Silhouette at 30m
From across the lagoon, the tide_line_decal appears as a thin, curved dark stain along the beach, barely distinct from the sand’s texture but clearly indicating where water once lapped.

### 2. Tri-budget breakdown
Body: 60 tris. Decorations: 15 tris. FX: 5 tris. Total: 80 tris.

### 3. Geometry construction
The body is a flat, elongated ring constructed using a single mbCylinder with zero height and a thin radial profile, tapering slightly to simulate the waterline’s edge. It’s complemented with a few mbSphere instances to add small wet patches or foam edges. Extrusions are minimal, just enough to give depth to the stain without breaking the flat decal nature.

### 4. Body palette
Uses sand_wet, water_shallow, foam_white, and beach_dune to simulate a wet sand line with shallow water and foam remnants.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|--------|
| Main body     | 48     |
| Foam edge     | 48     |
| Wet sand      | 48     |
| Background    | 0      |

(All decal surfaces use uBase=48 — tide_line_decal is reserved only for that marker. Per-vertex color hash provides the foam-edge vs wet-sand contrast.)

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. Justification: This ensures visual variation without making the decal look out of place or overly repetitive in a natural beach setting.

### 7. Y rotation
Random `0..2π`. The decal is rotated randomly to simulate natural drift of tide lines and avoid patterned repetition.

### 8. Ground anchor
Sits on island surface (y=island_y). It is aligned to the local island terrain and slightly inset from the beach edge to avoid clipping into the waterline.

### 9. Procedural variation method
Two instances differ by scale and uBase index, simulating a natural variance in tide line intensity and texture.

### 10. Spawn placement rules — which island(s)
Spawn on islands A, D, F. Radius within island: 40–100m. Biome-zone: beach edge. Avoid-list: temple plaza, cliff face, boundary ring.

### 11. Spawn count rationale
With an estimated 900m radius and ISLAND_BIAS of A, D, F, 100 instances provide adequate coverage while avoiding over-density in any single zone.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to avoid clustering, creating a natural distribution across the beach.

### 13. Inter-asset spacing minimum (m)
Minimum 3.5 meters to another instance of the same mesh. Ensures visual variety and avoids overcrowding.

### 14. Path-clearance distance (m)
5 meters. It avoids spawning too close to island paths to allow for player movement and avoid collision.

### 15. Team color reasoning
TEAM=55 is chosen to align with a neutral, natural-looking sand-based color scheme. In `game_fill_draws`, it resolves to sand_wet.

### 16. Shadow / contact AO strategy
Casts shadow. Ground AO blob is used to simulate the wet sand’s shadowing effect. No vertex-AO.

### 17. Distant-LOD strategy
No LOD. The asset remains constant in detail across all distances, consistent with the forest’s no-LOD policy.

### 18. Animation, if any
Static, no animation. The decal is designed to appear static to reflect the stillness of the tide line.

### 19. Particle FX bound to entity
None. The decal is purely visual with no attached particle effects.

### 20. Lighting interaction
Sun-side warm tint with a slight orange hue; mist-side cool tint with a blueish hue, simulating real-world lighting.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.1 to avoid collision interference.

### 22. Destructible
No. It is a static environment element and not destructible.

### 23. Lore hook
A ghost of the last tide, left behind like a memory on the sand.

### 24. Surface UV layout
Main body (uBase 48) maps to the core stain. Foam edge (uBase 49) is mapped to the outer foam layer. Wet sand (uBase 50) maps to the inner sand texture. Background (uBase 0) covers the flat base.

### 25. Material specularity
Matte. The surface appears soft and natural, mimicking wet sand.

### 26. Day/night appearance shift
During the day, the stain appears warm and slightly orange due to sunlight. At night, it takes on a cooler, blueish tint, matching ambient lighting.

### 27. Silhouette test at 50 m
Yes, the decal remains distinguishable at 50m, maintaining its shape and contrast against the sand.

### 28. Visual neighbours
Looks right next to driftwood_grey, kelp_green, and sail_cream assets, as they are all part of a cohesive beach environment.

### 29. Visual conflicts
Should not be near large, solid rock formations or dense vegetation, as these elements can overwhelm or obscure the subtle stain.

### 30. Implementation hooks
- `src/main.zig`: Add `case 55` to `world.team` switch.
- `ios/Mesh.swift`: Add `makeTideLineDecal(device:)` function.
- `ios/GameViewController.swift`: Add dispatch case for `tide_line_decal` in `loadAsset()`.

```metal
float3 color = mix(sand_wet, foam_white, smoothstep(0.0, 0.2, uv.y));
```
---

## Asset 85 — washed_log
### 1. **Silhouette at 30m** — From across the lagoon, a washed_log appears as a long, curved, weathered plank, slightly tilted and partially sunken into shallow sand, with a gentle arc suggesting it was once part of a larger structure or tree.
### 2. **Tri-budget breakdown** — Body: 150 tris, Decorations: 20 tris, FX: 10 tris.
### 3. **Geometry construction** — The body is a tapered mbCylinder with a slight twist to simulate driftwood's irregular shape. Two mbSphere caps are added at each end for rounded ends. Extrusions include a few small nubs and grooves to mimic sea-worn texture and embedded shells or barnacles. The mesh is composed using stacked plates for the surface irregularities, and a fan of triangles for the internal structure.
### 4. **Body palette** — The log's main body uses `driftwood_grey`, with `sand_wet` on the base for contact with wet sand, `foam_white` on the top for sun bleaching, and `accent_pearl` for subtle highlights and shell-like textures.
### 5. **uBase marker assignments per surface** —  
| Surface       | uBase |
|---------------|-------|
| Body          | 51    |
| Sand Contact  | 52    |
| Bleach Top    | 53    |
| Shell Highlights | 54 |
| Emissive      | 8     |
### 6. **Base scale (scale_min, scale_max)** — (0.8, 1.4). The range allows for variety in log sizes while maintaining realism and visual consistency across the beach.
### 7. **Y rotation** — Random `0..2π`. The log's orientation is fully randomized to simulate natural drift and settling.
### 8. **Ground anchor** — Partially buried, sitting at y = -0.4 to simulate a log half-submerged in the sand and shallow water.
### 9. **Procedural variation method** — Sub-mesh subset variation. Each instance uses a different set of surface detail meshes (nubs, grooves, shell fragments) to reduce repetition.
### 10. **Spawn placement rules — which island(s)** — Spawns on islands A, B, C, D, F (excluding E). Within a radius of 150m from island center. Biome zone: beach edge and inland zones. Avoid-list: temple plaza, boundary ring.
### 11. **Spawn count rationale** — With a radius of 900m and EST_COUNT = 110, the density is consistent with a sparse beach driftwood distribution, matching the natural occurrence and low frequency of such objects.
### 12. **Clustering pattern** — Scattered-grid. Instances are spaced in a grid-like fashion to avoid clumping while maintaining visual cohesion.
### 13. **Inter-asset spacing minimum (m)** — 2.5 meters.
### 14. **Path-clearance distance (m)** — 6 meters from the local path.
### 15. **Team color reasoning** — TEAM=53 is selected to align with the `driftwood_grey` palette swatch, matching the color scheme of the asset. It resolves to `driftwood_grey` in the `game_fill_draws` switch.
### 16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob is used to simulate sand contact and subtle depth.
### 17. **Distant-LOD strategy** — No LOD. The asset does not simplify at distance and remains at full resolution for consistent visual fidelity.
### 18. **Animation, if any** — Static, no animation.
### 19. **Particle FX bound to entity** — None.
### 20. **Lighting interaction** — Sun-side warm tint from `driftwood_grey` and `accent_pearl`, shadow-side cool tint from `sand_wet` and `water_shallow`.
### 21. **Collision** — Does not block player movement. world.radius = 0.3.
### 22. **Destructible** — No.
### 23. **Lore hook** — A log from a shipwreck that washed ashore, now weathered and worn smooth by the tide.
### 24. **Surface UV layout** — uBase 51 covers the main body, 52 the sand contact area, 53 the bleach top, 54 for shell highlights, and 8 for emissive glows if any.
### 25. **Material specularity** — Soft-glossy. Reflects some light but not in a mirror-like way.
### 26. **Day/night appearance shift** — Sun-side warm tint with a slight amber hue, shadow-side cool tint with a blue undertone.
### 27. **Silhouette test at 50 m** — Yes, it maintains a clear silhouette at 50m, reading as a curved, elongated form.
### 28. **Visual neighbours** — Looks right next to `sea_shell`, `driftwood_pile`, and `sand_dune` — all beach-related assets.
### 29. **Visual conflicts** — Should not be near `lava_boulder`, `firefly_spark`, or `kelp_cluster`, as these would overwhelm its subtle, muted aesthetic.
### 30. **Implementation hooks** —  
- `src/main.zig`: Add case `53` to `world.team` switch.  
- `ios/Mesh.swift`: Add `makeWashedLog(device:)` function.  
- `ios/GameViewController.swift`: Add dispatch case `case 85:` for `washed_log` instantiation.
---

## Asset 86 — sea_shell_cluster
### 1. Silhouette at 30m
From across the lagoon, the sea_shell_cluster appears as a scattered cluster of irregular, flattened shells and conches, with barnacles forming a crusty, weathered surface texture that suggests both time and marine life.

### 2. Tri-budget breakdown
Body: 120 tris; Decorations: 30 tris; FX: 10 tris. Total: 160 tris.

### 3. Geometry construction
The base shell geometry is constructed using a `mbCylinder` with a tapering radius and a vertical axis to simulate a conch shell, then a `mbSphere` to form a clam shell, both connected with extruded ring segments to add barnacle crust details. The entire cluster is built using a static cluster approach with no procedural variation per instance.

### 4. Body palette
The body uses sand_wet (for shell base), beach_dune (for barnacle crust), driftwood_grey (for weathered edge), and accent_pearl (for shell gloss).

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Shell Body    | 0     |
| Barnacle Crust| 49    |
| Shell Rim     | 0     |
| Emissive      | 8     |

### 6. Base scale (scale_min, scale_max)
0.8 to 1.4. Scales are varied to give visual diversity while maintaining a cohesive beach look.

### 7. Y rotation
Random `0..2π`. Each instance is independently rotated for natural scatter.

### 8. Ground anchor
Sits on island surface (y=island_y), partially buried in sand to simulate natural erosion.

### 9. Procedural variation method
Sub-mesh subset variation — each instance randomly chooses between a conch and a clam shell body type, with optional barnacle crust.

### 10. Spawn placement rules — which island(s)
Islands A, D, F. Spawn radius within island: 20–50m. Biome-zone: beach edge / boundary ring. Avoid-list: bridges, temple plaza, cliff face.

### 11. Spawn count rationale
With a 900m radius and ISLAND_BIAS of A, D, F, 120 instances provide a dense yet natural scatter to support the beach environment without overcrowding.

### 12. Clustering pattern
Scattered-grid. Instances are placed in a loose grid, spaced to avoid visual clutter while maintaining a natural feel.

### 13. Inter-asset spacing minimum (m)
1.5 meters from any other instance of the same mesh.

### 14. Path-clearance distance (m)
5 meters from ISLAND-LOCAL path. Bridges are exempt.

### 15. Team color reasoning
TEAM=56 resolves to `accent_pearl`. This color is chosen to blend into the beach palette while providing a visual anchor for team-based interactions.

### 16. Shadow / contact AO strategy
Casts shadow. Uses ground AO blob for contact shadowing, with vertex AO for soft self-shadowing.

### 17. Distant-LOD strategy
Does not use LOD; the asset remains at full detail even at 200m.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side warm tint with sand_wet and beach_dune colors; shadow-side cool tint with accent_pearl and driftwood_grey.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.3.

### 22. Destructible
No. Default static asset.

### 23. Lore hook
The shells are remnants of ancient sea creatures, now weathered into beach treasures.

### 24. Surface UV layout
Shell Body (uBase 0) covers main shell surface; Barnacle Crust (uBase 49) covers protruding barnacle segments; Shell Rim (uBase 0) is the edge; Emissive (uBase 8) is used on small barnacle clusters for subtle glow.

### 25. Material specularity
Soft-glossy. Reflects ambient light softly to simulate wet sand and shell polish.

### 26. Day/night appearance shift
Sun-side warm tint with sand_wet and accent_pearl; shadow-side cool tint with driftwood_grey and beach_dune.

### 27. Silhouette test at 50 m
Yes, the cluster maintains a recognizable silhouette at 50m, with clear shell shapes and barnacle texture.

### 28. Visual neighbours
Looks right next to `driftwood_log`, `kelp_cluster`, and `beach_sand_dune`.

### 29. Visual conflicts
Should not appear near `forest_boulder`, `temple_pillar`, or `skywatch_crane` as it would clash with their silhouette and scale.

### 30. Implementation hooks
- Add `case 56:` to `world.team` switch in `src/main.zig`
- Add `makeSeaShellCluster(device:)` to `ios/Mesh.swift`
- Add `case 86:` to dispatch in `ios/GameViewController.swift`
---

## Asset 87 — dead_jellyfish
### 1. **Silhouette at 30m** — A dead jellyfish is a soft, translucent, bell-shaped form that tapers toward the base, appearing as a faint, glowing blob on the sandy beach with a gentle ripple of tentacles trailing beneath.

### 2. **Tri-budget breakdown** — Body: 100 tris, Decorations: 20 tris, FX: 20 tris. Total = 140 tris.

### 3. **Geometry construction** — The main body is a mbCylinder with a tapered bottom, forming a bell-like shape. The top is capped with a mbSphere to simulate the jellyfish’s dome. Tentacles are extruded from the base using a fan of triangles, with each tentacle having a slight curve to appear organic. The entire mesh is constructed from a single mesh buffer with layered sub-meshes.

### 4. **Body palette** — Uses sand_wet (for base), driftwood_grey (for tentacles), foam_white (for rim glow), and accent_coral (for subtle internal trace).

### 5. **uBase marker assignments per surface** —  
| Surface | uBase |
|---------|-------|
| Body    | 0     |
| Tentacles | 53    |
| Glow trace | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range 0.7 to 1.3. Justification: Varying scale simulates different sizes of jellyfish washed ashore, with smaller ones being more common.

### 7. **Y rotation** — Random `0..2π`. Ensures natural, non-uniform orientation across beach zones.

### 8. **Ground anchor** — Partially buried, with 20% of the mesh submerged in sand to simulate a jellyfish washed up onto the beach.

### 9. **Procedural variation method** — Variations are driven by a palette hash that selects a combination of sand_wet, driftwood_grey, foam_white, and accent_coral.

### 10. **Spawn placement rules — which island(s)** — Spawns on A, D, F. Radius within each island is 10–40m. Biome-zone: beach edge and boundary ring. Avoid-list: temple plaza, cliff face.

### 11. **Spawn count rationale** — `est_count = 100` is appropriate for a 900m radius zone with 3 islands, ensuring density without over-cluttering the beach environment.

### 12. **Clustering pattern** — Scattered-grid. Instances spaced in a grid-like pattern but with randomized offsets to avoid perfect symmetry.

### 13. **Inter-asset spacing minimum (m)** — 1.5 meters minimum distance from another instance.

### 14. **Path-clearance distance (m)** — 6 meters from any island-local path, ensuring it doesn’t interfere with player navigation.

### 15. **Team color reasoning** — TEAM=57 resolves to a soft coral tint (accent_coral), matching the subtle glow trace and emphasizing its stranded, fragile nature.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow with a small AO blob beneath the body. Vertex-AO is used for contact shading.

### 17. **Distant-LOD strategy** — No LOD is implemented. Asset is rendered at full detail across all distances, consistent with forest assets.

### 18. **Animation, if any** — Static, no animation. No movement or sway.

### 19. **Particle FX bound to entity** — None. FX is purely visual with no particle attachment.

### 20. **Lighting interaction** — Sun-side is warm with a slight glow, shadow-side is cool with a faint blue tint due to ambient water influence.

### 21. **Collision** — Does not block player movement. `world.radius` is set to 0.3 to allow passage underneath.

### 22. **Destructible** — No. Does not break or change form under any circumstance.

### 23. **Lore hook** — A jellyfish that washed ashore, its body now soft and pale, still holding a faint trace of the ocean's glow.

### 24. **Surface UV layout** — uBase 0 covers the main body, uBase 53 covers tentacles, and uBase 8 covers the internal glow trace.

### 25. **Material specularity** — Soft-glossy. Reflects light subtly, with a matte finish to mimic wet sand.

### 26. **Day/night appearance shift** — During the day, sun-side is warm and glowing, shadow-side is cool. At night, the glow trace becomes more prominent, with a faint amber hue.

### 27. **Silhouette test at 50 m** — Yes, the silhouette is still recognizable at 50m, especially due to the glow trace and soft shape.

### 28. **Visual neighbours** — Looks best next to kelp_green or driftwood_grey assets, creating a cohesive oceanic theme.

### 29. **Visual conflicts** — Should not be near dense forests or tall cliffs, as these would overpower the soft, glowing silhouette of the jellyfish.

### 30. **Implementation hooks** —  
- Add `case 57: return .dead_jellyfish` to `world.team` switch in `src/main.zig`  
- Add `func makeDeadJellyfish(device: MTLDevice) -> (MTLBuffer, MTLBuffer)` in `ios/Mesh.swift`  
- Add `case 87: self.mesh = makeDeadJellyfish(device: device)` in `ios/GameViewController.swift`
---

## Asset 88 — beach_grass_tuft
### 1. Silhouette at 30m
From across the lagoon, a beach_grass_tuft appears as a dry, pale tuft of grass that tapers upward from a rounded base, creating a soft, vertical silhouette that blends into the coastal dunes.

### 2. Tri-budget breakdown
The mesh is composed of 90 tris for the body, 20 tris for decorative grass strands, and 10 tris for subtle FX elements, totaling EST_TRIS = 120.

### 3. Geometry construction
The base is constructed using `mbCylinder` with a tapered top to simulate a grass tuft. A `mbSphere` is added at the top to provide a rounded tip. Additional extruded rings and fan triangles are used to define individual grass blades, with some of the blades slightly offset and rotated to simulate natural variation.

### 4. Body palette
The body uses `beach_dune`, `sand_wet`, and `accent_pearl` for the tuft base, with `sail_cream` for the grass tips to reflect the dry, sun-warmed tone of beach grass.

### 5. uBase marker assignments per surface
| Surface      | uBase |
|--------------|-------|
| Tuft base    | 0     |
| Grass tips   | 0     |
| Root base    | 0     |

(All grass surfaces use uBase=0 — beach_grass_tuft is reserved only for the default branch. Tuft variation comes from per-vertex color hash and the team-color tint.)

### 6. Base scale (scale_min, scale_max)
Scale is between `0.7` and `1.3`. This range allows for natural variation in tuft size while maintaining visual consistency across zones.

### 7. Y rotation
Rotations are aligned to shore tangent, ensuring that each tuft appears to grow naturally along the beach’s edge and direction.

### 8. Ground anchor
The base of each tuft sits partially buried into the sand at y = -0.1, with the tip extending above the surface to simulate dry, scattered grass.

### 9. Procedural variation method
Two instances differ by a combination of scale spread and palette hash, ensuring each tuft has a slightly unique look while maintaining the overall aesthetic.

### 10. Spawn placement rules — which island(s)
Spawns occur on islands A, D, and F. Within each island, the spawn radius is within 100m of the coastline. The biome-zone is beach edge and inland edges. Avoid-list includes areas near bridges and temple plazas.

### 11. Spawn count rationale
The estimated 130 instances are appropriate for a 900m radius zone, with a density that ensures visual texture without overcrowding, especially in the beach and inland edge zones.

### 12. Clustering pattern
Scattered-grid clustering, with tufts spaced to appear naturally distributed along the beach and near dune edges.

### 13. Inter-asset spacing minimum (m)
Minimum 1.5 meters between instances of the same mesh to prevent visual clutter and ensure natural spread.

### 14. Path-clearance distance (m)
Spawns are kept at least 6 meters from ISLAND-LOCAL paths to avoid interference with movement and to allow passage.

### 15. Team color reasoning
TEAM=58 is chosen to represent a neutral, sun-warmed palette that blends into the beach biome. It resolves to `accent_pearl` in the `game_fill_draws` switch, giving it a soft, pastel appearance.

### 16. Shadow / contact AO strategy
Casts a soft shadow and uses vertex-AO to simulate contact with the sand, giving a natural depth to the base of the tuft.

### 17. Distant-LOD strategy
No LOD is applied, as the asset is designed to be visible at all distances, matching the forest’s static asset approach.

### 18. Animation, if any
Static, no animation. The asset is designed to remain fixed in place, mimicking natural, weathered grass tufts.

### 19. Particle FX bound to entity
None. The asset does not have any bound particle effects.

### 20. Lighting interaction
Sun-side appears warm with a slight tint of `sail_cream`, while shadow-side takes on a cooler tone of `mist_low`.

### 21. Collision
Does not block player movement. The `world.radius` is set to 0.2 to allow passage through the tuft.

### 22. Destructible
No. The asset is static and not intended to be destroyed.

### 23. Lore hook
These grass tufts are remnants of a once-thriving dune ecosystem, now dry and scattered by the island’s shifting tides.

### 24. Surface UV layout
The tuft base uses uBase 0, the grass tips use uBase 1, and the root base uses uBase 8 to differentiate textures and allow for material variation.

### 25. Material specularity
Soft-glossy, with slight reflectivity to simulate the dry, sun-warmed texture of beach grass.

### 26. Day/night appearance shift
During the day, the tuft appears warm and sun-warmed with `sail_cream` tones. At night, the color shifts to a cooler `mist_low` tone, enhancing the contrast with ambient lighting.

### 27. Silhouette test at 50 m
Yes, the silhouette remains readable at 50 meters, with the vertical taper and soft edge maintaining its distinct form.

### 28. Visual neighbours
This asset looks right next to `driftwood`, `kelp_tendrils`, and `sand_dunes`, as they all contribute to a cohesive coastal landscape.

### 29. Visual conflicts
It should not appear near `sea_urchin`, `coral_clump`, or `floating_seaweed`, as these would visually clash with the dry, pale tone of the grass tuft.

### 30. Implementation hooks
- Add case `58` to `world.team` switch in `src/main.zig`.
- Add `makeBeachGrassTuft(device:)` to `ios/Mesh.swift`.
- Add dispatch case for `beach_grass_tuft` in `ios/GameViewController.swift`.
---

## Asset 89 — wet_sea_cliff
1. **Silhouette at 30m** — The cliff rises like a fluted column, its face etched with spray-streaked grooves that catch the light and cast a deep, vertical shadow.
2. **Tri-budget breakdown** — Body: 300 tris; Decorations: 60 tris; FX: 20 tris.
3. **Geometry construction** — The main cliff is built from a tall mbCylinder with a tapering radius to simulate a fluted cliff face. The top of the cylinder is capped with an mbSphere to create a rounded overhang. Extrusions are added to simulate spray-weathered ledges and small caves. A fan of triangles is used to create a spray-impact pattern on the base.
4. **Body palette** — sand_wet, driftwood_grey, kelp_green, and accent_coral. Sand_wet covers the base, driftwood_grey is used for weathered ledges, kelp_green for mossy crevices, and accent_coral for occasional coral patches.
5. **uBase marker assignments per surface** —  
| Surface | uBase |
|---------|-------|
| Base    | 47    |
| Ledges  | 47    |
| Overhang| 47    |
| Crevices| 0     |

(All cliff surfaces use uBase=47 — wet_sea_cliff is reserved only for that marker. Crevices use default 0; per-vertex color hash adds depth contrast.)
6. **Base scale (scale_min, scale_max)** — 1.2 to 1.8. Scales are chosen to allow variation in height without breaking the visual rhythm of the lagoon's shoreline.
7. **Y rotation** — aligned-to-island-radial. Instances face inward toward the island’s center to maintain contextual flow.
8. **Ground anchor** — sits on island surface (y=island_y). Anchored at base to match island elevation.
9. **Procedural variation method** — sub-mesh subset variation. Different instances use a random subset of the full mesh, such as omitting some spray-effect triangles or ledges.
10. **Spawn placement rules — which island(s)** — B, C, D, F only. Spawn radius within island is 20–40 m. Zone is beach edge or cliff face. Avoid-list: E (sky island), A (lantern hold).
11. **Spawn count rationale** — With a 900 m radius, 50 instances provide a dense enough coverage to give a sense of continuity and scale, without overwhelming the environment.
12. **Clustering pattern** — scattered-grid. Instances are spaced to avoid visual clumping, creating a more organic feel.
13. **Inter-asset spacing minimum (m)** — 12 m. Ensures visual clarity and avoids overlapping silhouette.
14. **Path-clearance distance (m)** — 6 m. Instances are kept away from the path to allow passage.
15. **Team color reasoning** — TEAM=59 is chosen to reflect a color in the palette that blends warm and cool tones — it resolves to driftwood_grey in `game_fill_draws`, which allows for visual cohesion with the surrounding rocky terrain.
16. **Shadow / contact AO strategy** — casts shadow. Ground AO blob is used to simulate contact with the island.
17. **Distant-LOD strategy** — asset disappears at 150 m. No LOD is used, matching the forest asset strategy.
18. **Animation, if any** — static, no animation. The cliff is a static, weathered structure.
19. **Particle FX bound to entity** — drip_seafoam. A light particle emitter is bound to the base of the cliff to simulate spray dripping.
20. **Lighting interaction** — sun-side warm tint is a soft amber from sand_wet and driftwood_grey, while shadow-side cool tint is a muted blue from water_deep and kelp_green.
21. **Collision** — yes. Blocks movement. `world.radius` is set to 0.8.
22. **Destructible** — no. The cliff is a permanent structure.
23. **Lore hook** — The cliff once held a shipwrecked anchor, now weathered into the rock, its chain still visible in a shallow crevice.
24. **Surface UV layout** — uBase 47 covers the base; 48 covers ledges; 49 covers overhang; 50 covers crevices.
25. **Material specularity** — soft-glossy. Reflects a subtle sheen of spray.
26. **Day/night appearance shift** — sun-side warm tint is a soft amber from sand_wet and driftwood_grey, while shadow-side cool tint is a muted blue from water_deep and kelp_green.
27. **Silhouette test at 50 m** — yes, the cliff still reads clearly with its fluted silhouette and vertical form.
28. **Visual neighbours** — looks right next to `sea_coral_reef`, `driftwood_log`, and `wave_rock`.
29. **Visual conflicts** — should not be placed near `skywatch_tower`, `lantern_hall`, or `pyre_burnt_stone` — these would overwhelm its silhouette.
30. **Implementation hooks** —  
- In `src/main.zig`, add case `59 => wet_sea_cliff` to `world.team` switch.  
- In `ios/Mesh.swift`, add `makeWetSeaCliff(device:)` function.  
- In `ios/GameViewController.swift`, add dispatch case for `89` to `makeMesh()` with `makeWetSeaCliff`.

```metal
float3 baseColor = mix(sand_wet, driftwood_grey, smoothstep(0.0, 1.0, sin(uv.x * 5.0) * 0.5 + 0.5));
float3 edgeColor = mix(kelp_green, accent_coral, smoothstep(0.0, 1.0, fbm(uv * 2.0) * 0.5 + 0.5));
```
---

## Asset 90 — sea_arch_natural
### 1. **Silhouette at 30m** — From across the lagoon, the arch appears as a dramatic, curved stone gateway, its upper edge gently tapering toward the sky, with a broad base that narrows into a natural tunnel.

### 2. **Tri-budget breakdown** — Body: 380 tris; Decorations: 60 tris; FX: 20 tris. Total: 460 tris.

### 3. **Geometry construction** — The main body is constructed from a large `mbCylinder` with a tapering inner radius to form the arch’s tunnel, followed by extruded vertical slabs on both ends to simulate erosion and weathering. Additional `mbSphere` elements are placed atop and beneath to represent moss and lichen growth. The structure uses a combination of fan-of-triangles for small surface details and stacked plates for textural variation.

### 4. **Body palette** — Uses `water_shallow`, `sand_wet`, `driftwood_grey`, and `kelp_green` to reflect the oceanic and weathered appearance of a cliffside arch.

### 5. **uBase marker assignments per surface** — 

| Surface       | uBase |
|---------------|-------|
| Arch inner    | 47    |
| Arch outer    | 47    |
| Moss patches  | 47    |
| Driftwood     | 0     |
| Emissive      | 8     |

(Cliff surfaces use uBase=47 — sea_arch_natural is reserved only for that marker. Driftwood inserts use default 0; per-vertex color hash gives moss vs bare stone contrast.)

### 6. **Base scale (scale_min, scale_max)** — (1.0, 1.4). Justifies realism of natural variation and visual presence without over-scaling.

### 7. **Y rotation** — Random `0..2π`. Allows varied orientations for visual interest and natural placement.

### 8. **Ground anchor** — Partially buried, sitting on the island surface with 30% of its base below the y=island_y level to simulate erosion and stability.

### 9. **Procedural variation method** — Sub-mesh subset variation. Some instances feature additional driftwood or moss clusters, altering visual density and realism.

### 10. **Spawn placement rules — which island(s)** — Spawn on islands B, C, F. Within each island, radius is 40–120m. Biome-zone is beach edge or cliff face. Avoid-list: bridges, temples, and other large structures.

### 11. **Spawn count rationale** — With a 900m radius and rare outer edge spawns (ISLAND_BIAS B,C,F), 30 instances provide a natural density that avoids over-cluttering while maintaining visual impact.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed with slight spacing to allow for natural flow and path navigation.

### 13. **Inter-asset spacing minimum (m)** — 10 meters. Ensures visual separation and avoids overlapping.

### 14. **Path-clearance distance (m)** — 6 meters. Allows room for player passage while maintaining visual cohesion.

### 15. **Team color reasoning** — TEAM=59 resolves to `accent_coral` in `game_fill_draws`, matching the warm, natural tones of the rock arch’s color palette and providing clear team distinction.

### 16. **Shadow / contact AO strategy** — Casts shadow, with a ground AO blob for contact with the island surface. No vertex-AO to preserve performance.

### 17. **Distant-LOD strategy** — Asset disappears at 120 meters distance, matching forest's no-LOD behavior for consistent visual fidelity.

### 18. **Animation, if any** — Static, no animation. The asset is a fixed environmental feature.

### 19. **Particle FX bound to entity** — None. Does not require particle emission.

### 20. **Lighting interaction** — Sun-side features a warm, golden tint; shadow-side takes on a cooler, bluish hue, accentuating the rock’s texture and natural lighting.

### 21. **Collision** — Yes, it blocks player movement. `world.radius` set to 1.0 for a balanced hitbox.

### 22. **Destructible** — No. This is a static environmental asset with no breakable elements.

### 23. **Lore hook** — Ancient sailors once called it the "Gateway of the Deep," a sacred passage where the sea and sky meet.

### 24. **Surface UV layout** — Arch inner (uBase 47), outer (uBase 48), moss patches (uBase 49), driftwood (uBase 50). Emissive portion (uBase 8) used for subtle glow.

### 25. **Material specularity** — Soft-glossy. Reflects ambient light subtly without being overly shiny.

### 26. **Day/night appearance shift** — Sun-side appears warm and golden, while shadow-side takes on a cooler, blue-tinged tone.

### 27. **Silhouette test at 50 m** — Yes, the arch still reads clearly at half the average view distance, maintaining its strong form and presence.

### 28. **Visual neighbours** — Looks best next to `cliff_boulder` and `island_tree`, creating a cohesive coastal scene.

### 29. **Visual conflicts** — Should not spawn near `tower`, `bridge`, or `temple`, as those structures would overpower or visually clash with the arch’s natural silhouette.

### 30. **Implementation hooks** — Add `case 59:` to `world.team` switch in `src/main.zig`. Add `makeSeaArch(device:)` in `ios/Mesh.swift`. Add dispatch case in `ios/GameViewController.swift` for `90` under `world.meshId`.
---

## Asset 91 — anchor_boulder
### 1. Silhouette at 30m
From 30 meters away, the anchor_boulder appears as a rounded, flattened dome with a slightly irregular rim, suggesting a weathered sea anchor or ancient stone formation that has been shaped by long exposure to ocean spray and wind.

### 2. Tri-budget breakdown
The total triangle count of 280 is split as follows: body = 200 tris, barnacle crust = 50 tris, and FX = 30 tris (for small particle effects on the base).

### 3. Geometry construction
The main body uses `mbCylinder` to form a gently tapered, rounded sphere-like structure with a base radius of 1.0 and a top radius of 0.75, with 12 rings and 24 sides. A `mbSphere` is appended to the bottom to simulate barnacle crust, using 8 rings and 16 sides. The crust is slightly extruded outward, with a 0.15m offset along the Y-axis to simulate barnacles growing from the base. This is followed by a small ring extrusion to enhance surface texture and depth.

### 4. Body palette
The primary color palette uses: sand_wet (0.62, 0.55, 0.42) for the main body, driftwood_grey (0.45, 0.42, 0.38) for the barnacle crust, kelp_green (0.18, 0.42, 0.30) for subtle shading, and foam_white (0.94, 0.96, 0.98) for highlights on the rim.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|------------------|-------|
| Main body        | 47    |
| Barnacle crust   | 49    |
| FX surface       | 0     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.3. The variation allows for natural-looking size differences across the islands, while maintaining visual consistency with other rock assets.

### 7. Y rotation
Random `0..2π` — fully randomized orientation to avoid repetition and ensure natural clustering.

### 8. Ground anchor
Sits on island surface (y=island_y), partially buried 0.2 meters to simulate erosion and stability.

### 9. Procedural variation method
Variation is achieved via scale spread and random palette hash on the barnacle crust, allowing for subtle uniqueness across instances.

### 10. Spawn placement rules — which island(s)
Spawns on islands B, C, D, F only. Radius within island: 40–100 meters. Biome zone: cliff face. Avoid-list: bridge zones, temple plazas, and high-traffic areas.

### 11. Spawn count rationale
With an estimated 900m radius and 60 instances, the spawn density allows for 1 instance per ~150m² area, maintaining visual presence without overcrowding in large biome zones.

### 12. Clustering pattern
Dense-cluster — typically 3–5 boulders grouped closely to simulate natural erosion and coastal rock formations.

### 13. Inter-asset spacing minimum (m)
Minimum 3 meters from another instance of the same mesh to avoid visual clutter.

### 14. Path-clearance distance (m)
5 meters from the ISLAND-LOCAL path — enough to avoid obstructing player movement but close enough to contribute to the natural environment.

### 15. Team color reasoning
TEAM=59 is chosen to align with the "cliff" category, visually distinct from beach or forest elements. It resolves to accent_coral (0.92, 0.50, 0.42) in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts shadow using a ground AO blob to simulate the contact area with the island surface. Vertex AO is not used to maintain performance.

### 17. Distant-LOD strategy
No LOD — this asset is too small to benefit from simplification and maintains detail at all distances.

### 18. Animation, if any
Static, no animation — the asset remains motionless to maintain realism and avoid distraction.

### 19. Particle FX bound to entity
None — the asset does not use particle FX, relying on surface texture and lighting for visual detail.

### 20. Lighting interaction
Sun-side warms to sand_wet and driftwood_grey; shadow-side cools to kelp_green and foam_white, enhancing contrast and realism in varying light conditions.

### 21. Collision
Yes — blocks player movement. `world.radius` set to 0.6 to allow for tight placement near paths and bridges.

### 22. Destructible
No — the asset is not destructible; it is a static environmental piece.

### 23. Lore hook
This ancient anchor boulder once held a ship’s keel during a storm, now worn smooth by salt spray and time.

### 24. Surface UV layout
uBase 47 covers the main body, 49 covers the barnacle crust, and 0 is used for FX (if any) or default UVs.

### 25. Material specularity
Soft-glossy — the surface reflects ambient light softly, enhancing realism without over-shininess.

### 26. Day/night appearance shift
During the day, the surface appears warm with sand_wet and driftwood_grey tints; at night, the shadow side cools to kelp_green and foam_white, enhancing contrast and mood.

### 27. Silhouette test at 50 m
Yes — at 50 meters, the rounded silhouette remains clear and distinct, especially against the sky and ocean.

### 28. Visual neighbours
Looks right next to `island_boulder`, `sea_sculpture`, and `driftwood_pile` — all contributing to a cohesive coastal environment.

### 29. Visual conflicts
Should not spawn near `seaweed_cluster`, `tide_pool`, or `sail_raft` — as they would visually compete and reduce the clarity of the boulder's form.

### 30. Implementation hooks
- Zig: Add `case 59` in `world.team` switch in `src/main.zig`
- Swift: Add `makeAnchorBoulder(device:)` function in `ios/Mesh.swift`
- GameViewController: Add `case 91` in `dispatchMesh` in `ios/GameViewController.swift`
---

## Asset 92 — barnacle_crust_patch
### 1. **Silhouette at 30m** — From across the lagoon, the barnacle crust patch appears as a flat, textured rectangle with irregular edges, resembling a weathered stone slab partially covered in barnacles.

### 2. **Tri-budget breakdown** — Body: 70 tris; Decorations: 20 tris; FX: 10 tris.

### 3. **Geometry construction** — The body is constructed using a `mbCylinder` with slightly tapered ends, forming a flat, elongated rock slab. Decorative barnacle protrusions are modeled with small `mbSphere` elements. Additional surface texture is achieved through extruded ring structures and stacked plates, simulating crusty barnacle buildup.

### 4. **Body palette** — Uses `sand_wet`, `driftwood_grey`, `kelp_green`, and `accent_pearl` to simulate the weathered, moist rock surface with barnacle encrustation.

### 5. **uBase marker assignments per surface** — 
| Surface     | uBase |
|-------------|-------|
| Main body   | 49    |
| Barnacle    | 49    |
| Moss        | 49    |
| Emissive    | 8     |

(All barnacle surfaces use uBase=49 — barnacle_crust_patch is reserved only for that marker. Moss vs barnacle vs base contrast comes from per-vertex color hash.)

### 6. **Base scale (scale_min, scale_max)** — 0.7 to 1.2. Justification: Varying scale adds realism to barnacle distribution and surface variation.

### 7. **Y rotation** — Random `0..2π`. Rotation is fully randomized to simulate natural rock exposure.

### 8. **Ground anchor** — Sits on island surface (y=island_y). Anchored to the cliff or boulder surface it decorates.

### 9. **Procedural variation method** — Two instances differ by scale and palette hash, simulating varied barnacle growth and surface weathering.

### 10. **Spawn placement rules — which island(s)** — Spawns on islands A, B, C, D, F only. Radius: 20–60m within island. Biome zone: cliff face or beach edge. Avoid-list: temple plaza, boundary ring.

### 11. **Spawn count rationale** — With an estimated 900m radius and ISLAND_BIAS, 80 instances provide a visually rich but sparse coverage that avoids clutter.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid dense clustering but not isolated.

### 13. **Inter-asset spacing minimum (m)** — 2.5 meters. Prevents visual overlap and maintains variety.

### 14. **Path-clearance distance (m)** — 7 meters. Instances must not interfere with island paths or bridges.

### 15. **Team color reasoning** — TEAM=60 is chosen to represent a neutral, earth-toned object that blends with rock and cliff surfaces. It resolves to `sand_wet` in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts shadow and uses vertex AO for soft contact highlights on the rock surface.

### 17. **Distant-LOD strategy** — No LOD; the asset remains visible at all distances like forest meshes.

### 18. **Animation, if any** — Static, no animation. The barnacle crust patch is purely decorative.

### 19. **Particle FX bound to entity** — None. The asset is self-contained with no bound particle effects.

### 20. **Lighting interaction** — Sun-side is tinted warm with `kelp_green` and `sand_wet`, while shadow-side takes on a cooler `water_deep` tone.

### 21. **Collision** — Does not block movement; `world.radius` set to 0.3.

### 22. **Destructible** — No. This asset is purely visual and non-interactive.

### 23. **Lore hook** — A relic of a long-sunk ship, its surface encrusted with barnacles and sea moss, marking the edge of an ancient wreck.

### 24. **Surface UV layout** — uBase 49 covers the main rock surface; uBase 50 covers barnacle clusters; uBase 51 covers moss patches; uBase 8 for emissive glow on barnacles in low-light.

### 25. **Material specularity** — Soft-glossy. Reflects light subtly, simulating a moist, weathered stone surface.

### 26. **Day/night appearance shift** — During the day, it appears warm and earthy; at night, the emissive barnacles glow faintly with a `ember_lantern` hue.

### 27. **Silhouette test at 50 m** — Yes. The patch remains clearly readable from 50 meters, with a distinct outline of the rock slab and barnacle protrusions.

### 28. **Visual neighbours** — Looks right next to `ship_wreck` and `cliff_boulder` assets, forming a cohesive, coastal cliffside environment.

### 29. **Visual conflicts** — Should not spawn near `lava_vent` or `tropical_fern`, as the contrasting colors would clash with the muted, mossy tone.

### 30. **Implementation hooks** — 
- Add `case 60:` to `world.team` switch in `src/main.zig`.
- Add `makeBarnacleCrustPatch(device:)` to `ios/Mesh.swift`.
- Add dispatch case for `barnacle_crust_patch` in `ios/GameViewController.swift`.
---

## Asset 93 — foam_splash_rock
### 1. Silhouette at 30m
From 30 meters away, the foam_splash_rock appears as a vertical, irregularly shaped column with a small splash spray effect, resembling a weathered stone protruding from shallow water.

### 2. Tri-budget breakdown
The mesh is composed of 120 tris for the main body, 40 tris for decorative foam accents, and 20 tris for FX spray geometry, summing to EST_TRIS = 180.

### 3. Geometry construction
The base is a mbCylinder with tapered ends, representing the main rocky protrusion. A small mbSphere is added at the top to simulate a weathered cap. Extruded rings are placed around the mid-section to suggest erosion and spray interaction. The entire mesh uses a fan of triangles for the foam spray effect.

### 4. Body palette
The primary color palette includes sand_wet (for base rock), beach_dune (for weathered top), foam_white (for spray), and kelp_green (for mossy patches near base). These colors cover the main body, top cap, foam spray, and base.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|----------------|-------|
| Base rock      | 47    |
| Top cap        | 45    |
| Foam spray     | 47    |
| Moss patches   | 45    |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This variation allows for visual diversity while maintaining the illusion of a solid, grounded rock with consistent splash interaction.

### 7. Y rotation
Aligned-to-island-radial — instances rotate to face inward toward the center of their island, enhancing the cohesive island aesthetic.

### 8. Ground anchor
Partially buried, with 20% of the mesh below the island surface to suggest it is rooted in the seabed and interacts with the splash.

### 9. Procedural variation method
Variation is driven by palette hash, which changes the base color and foam accent swatch per instance, creating a natural appearance across clusters.

### 10. Spawn placement rules — which island(s)
Spawn on islands B, F (outer rocks) only. Radius within island is 20–40m. Biome-zone is beach edge or cliff face. Avoid-list includes: towers, lighthouses, and any large structures.

### 11. Spawn count rationale
With an estimated 900m radius and ISLAND_BIAS on B and F, 50 instances are sufficient to create a natural distribution across the outer rock zones without overcrowding or visual monotony.

### 12. Clustering pattern
Scattered-grid — instances are placed with slight spacing to avoid clustering, but not so far as to appear isolated.

### 13. Inter-asset spacing minimum (m)
Minimum 3 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
Path clearance is 6 meters from the island-local path, allowing for safe navigation while maintaining the splash effect near the edge.

### 15. Team color reasoning
TEAM=59 is selected to align with the “splash rock” theme and is mapped to accent_coral in the `game_fill_draws` switch, which provides a warm, oceanic contrast.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a contact AO blob at the base to enhance the illusion of weight and immersion.

### 17. Distant-LOD strategy
No LOD is implemented — the asset is designed to remain visible and detailed at all distances, matching the forest’s static LOD behavior.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
A `drip_seafoam` emitter is bound to the mesh, simulating persistent spray and droplets at the splash zone.

### 20. Lighting interaction
Sun-side is tinted with a warm, amber foam_white, while shadow-side takes a cool, bluish mist_low tint to simulate sea spray and depth.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.5 to allow passage around the base while preventing walking through the splash zone.

### 22. Destructible
No.

### 23. Lore hook
The rock is said to have been carved by the sea’s fury, leaving behind only the remnants of its once-splendid spray.

### 24. Surface UV layout
uBase 47 covers the base rock and foam spray; uBase 45 covers the top cap and moss patches. Surface mapping ensures seamless transitions between materials.

### 25. Material specularity
Soft-glossy — the rock surface has a subtle sheen, and the foam spray is glossy to reflect ambient light.

### 26. Day/night appearance shift
During the day, sun-side appears warm and bright with a golden foam_white tint. At night, shadow-side takes on a cool, blue-green hue, mimicking the sea’s dim reflection.

### 27. Silhouette test at 50 m
Yes, the silhouette remains distinct and recognizable at 50 meters, even with the spray effect.

### 28. Visual neighbours
Looks best next to `cliff_rock`, `sea_coral`, and `shallow_tidepool` assets, which share the same oceanic aesthetic.

### 29. Visual conflicts
Should not be placed near `tower`, `lighthouse`, or `dune_boulder` assets, as these would dominate the silhouette and reduce the splash effect’s prominence.

### 30. Implementation hooks
- Add `case 59: return makeFoamSplashRock(device:)` to `world.team` switch in `src/main.zig`.
- Add `func makeFoamSplashRock(device: MTLDevice) -> (vertices: [Vertex], indices: [UInt32])` in `ios/Mesh.swift`.
- Add `case 59: self.sceneRenderer.drawFoamSplashRock(instance)` in `ios/GameViewController.swift`.
---

## Asset 94 — tide_pool
### 1. Silhouette at 30m
The tide_pool presents a low, circular rim with a bioluminescent algae edge, appearing as a small glowing ring against the water's surface.

### 2. Tri-budget breakdown
Body: 140 tris. Decorations: 40 tris. FX: 20 tris. Total: 200 tris.

### 3. Geometry construction
The base is constructed using a `mbCylinder` for the main pool shape, with a radius of 1.2m and a height of 0.1m. A smaller `mbSphere` is added on top to represent a reflective cap, with a radius of 0.3m. The bioluminescent rim is modeled as an extruded ring around the top edge using a fan of triangles with 16 sides.

### 4. Body palette
The pool's water surface uses `water_shallow` and `water_deep` for gradient blending. The rim uses `accent_coral` and `ember_lantern` for its glowing effect.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|----------------|-------|
| Pool water     | 47    |
| Rim            | 45    |
| Cap            | 53    |
| Emissive rim   | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.9 to 1.1. Justification: Maintains visual consistency across varied island terrain while allowing subtle natural variation.

### 7. Y rotation
Random `0..2π`. This ensures natural-looking distribution and avoids repetitive alignment.

### 8. Ground anchor
Sits on island surface (y=island_y). Partially embedded into the sand, with 0.05m of the pool's base below surface level to simulate wet sand.

### 9. Procedural variation method
Variation is achieved by palette hash, scaling the rim color slightly and adjusting the UV offset for the bioluminescent edge.

### 10. Spawn placement rules — which island(s)
Spawn on islands C and F. Within each island, radius is 20–40m. Biome-zone: beach edge. Avoid-list: temple plaza, boundary ring.

### 11. Spawn count rationale
With a 900m radius and ISLAND_BIAS of C, F, 40 instances are sufficient to ensure visual presence without overcrowding, especially on smaller islands like F.

### 12. Clustering pattern
Scattered-grid. Instances are placed in a grid pattern with slight offsets to prevent perfect alignment.

### 13. Inter-asset spacing minimum (m)
Minimum distance: 4m from any other tide_pool instance.

### 14. Path-clearance distance (m)
Path clearance: 6m from ISLAND-LOCAL path. Bridges are ignored.

### 15. Team color reasoning
TEAM=61 is chosen to align with the `accent_coral` and `ember_lantern` palette, providing a warm, glowing contrast in the scene. It resolves to `accent_coral` in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts a soft shadow. Ground AO blob is used to simulate the pool's contact with sand, with low intensity.

### 17. Distant-LOD strategy
No LOD. The asset remains detailed up to 100m, consistent with the forest's static strategy.

### 18. Animation, if any
Static, no animation. The pool remains still to enhance the sense of stillness in the environment.

### 19. Particle FX bound to entity
No bound particle FX.

### 20. Lighting interaction
Sun-side is tinted with `accent_coral` and `ember_lantern` for warmth. Mist-side uses a cool tint of `mist_low` and `water_deep`.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.5 to allow passage.

### 22. Destructible
No. The pool is a static environmental feature.

### 23. Lore hook
The tide_pool is a sacred resting spot for the island's sea spirits, where their light can be seen reflected in the water.

### 24. Surface UV layout
uBase 47 covers the water surface, 45 covers the rim, 53 covers the cap, and 8 is used for the emissive rim.

### 25. Material specularity
Soft-glossy. Reflects light gently without being overly shiny.

### 26. Day/night appearance shift
During day, the rim glows with `ember_lantern`. At night, the glow intensifies and shifts to a cooler `mist_low` tint.

### 27. Silhouette test at 50 m
Yes, the tide_pool still reads clearly as a glowing ring at 50m, maintaining its identity in distant view.

### 28. Visual neighbours
Looks right next to `driftwood`, `kelp_cluster`, and `sail_raft`, composing a cohesive coastal scene.

### 29. Visual conflicts
Should not spawn near `cave_entrance`, `tower`, or `temple`, as these would overpower the subtle glow of the pool.

### 30. Implementation hooks
- Add `case 61: return makeTidePool(device:)` in `src/main.zig` under `world.team` switch.
- Add `func makeTidePool(device: MTLDevice) -> (MTLBuffer, MTLBuffer)` to `ios/Mesh.swift`.
- Add `case 94: makeTidePool(device:)` in `ios/GameViewController.swift` dispatch.
---

## Asset 95 — isolated_pillar
1. **Silhouette at 30m** — From across the lagoon, the isolated pillar appears as a sharp, vertical spike rising from the shallow water, its silhouette defined by a tall, narrow taper and a flat top that glints with reflected light.

2. **Tri-budget breakdown** — The mesh is constructed with 180 tris for the body, 40 for surface decorations, and 20 for FX elements — totaling exactly EST_TRIS=240.

3. **Geometry construction** — The main structure is built using `mbCylinder` to form a tall, tapered shaft, with a `mbSphere` atop to represent the flat, weathered summit. A few extruded rings are added for texture and structural detail, and a small conical cap is appended to simulate erosion.

4. **Body palette** — The main body uses `sand_wet`, `beach_dune`, and `driftwood_grey` to reflect its rocky, weathered, and ocean-slicked appearance. The summit is shaded with `accent_pearl` and `kelp_green` to suggest moss and lichen.

5. **uBase marker assignments per surface** —
   | Surface         | uBase |
   |----------------|-------|
   | Shaft          | 47    |
   | Summit         | 48    |
   | Decorations    | 49    |
   | Emissive cap   | 8     |

6. **Base scale (scale_min, scale_max)** — Scale ranges from 0.9 to 1.2 — this allows for subtle variation in height and girth, making each pillar feel unique while maintaining a cohesive group presence.

7. **Y rotation** — Random `0..2π` rotation ensures that the pillar does not align predictably with other elements and appears naturally placed.

8. **Ground anchor** — The pillar sits fully on the island surface, with a slight y-offset to simulate a base buried in sand or shallow water, at y = −0.4.

9. **Procedural variation method** — Two instances differ by scale and palette hash, with the latter modifying the surface color swatch via a hash-based lookup to simulate erosion and weathering.

10. **Spawn placement rules — which island(s)** — Spawns are restricted to islands B, C, and F, with a 100–150m radius from island center. Biome zones are beach edge or cliff face, and it avoids zones near bridges or temples.

11. **Spawn count rationale** — With EST_COUNT = 50 and 900m radius, each pillar is spaced to avoid overcrowding, yet still provide a sufficient number to create an immersive, scattered presence across the outer edges.

12. **Clustering pattern** — Scattered-grid, with instances spaced to appear natural and avoid visual clustering, especially in outer edge zones.

13. **Inter-asset spacing minimum (m)** — Minimum 12 meters to another instance of the same mesh to avoid visual clashing or over-saturation.

14. **Path-clearance distance (m)** — 8 meters from island-local paths to ensure player movement is not obstructed, and to allow for safe traversal.

15. **Team color reasoning** — TEAM=59 is chosen to match a warm, sandy tone that reflects its coastal origin; it resolves to `sand_wet` in the `game_fill_draws` switch.

16. **Shadow / contact AO strategy** — Casts a soft shadow, and uses a vertex-based AO blob to simulate the interaction with the surrounding sand and shallow water.

17. **Distant-LOD strategy** — No LOD — the asset is kept at full resolution across all distances, as its vertical silhouette is important for navigation and immersion.

18. **Animation, if any** — Static, no animation — its presence is meant to be stable and iconic.

19. **Particle FX bound to entity** — No bound FX — the asset relies on natural lighting and ambient particle effects from the environment.

20. **Lighting interaction** — Sun-side is tinted with a warm, sandy hue; shadow-side cools to a misty, blue-gray tone to reflect its interaction with sea mist and ambient light.

21. **Collision** — Yes, it blocks player movement. `world.radius` is set to 0.8 to allow for fine navigation around it.

22. **Destructible** — No — it is a permanent fixture, symbolizing the timeless nature of the sea-stack.

23. **Lore hook** — Once a lighthouse beacon, now a relic of the old Drifting Isles, its summit now hosts only the occasional seabird.

24. **Surface UV layout** — uBase 47 covers the shaft, 48 covers the summit, 49 covers the decorative rings, and 8 covers the emissive cap.

25. **Material specularity** — Soft-glossy — the surface reflects ambient light softly, with some highlights on the weathered edges.

26. **Day/night appearance shift** — During the day, it appears warm and golden; at night, it shifts to a cooler, slightly glowing tone, especially around the top where it glows faintly like an old beacon.

27. **Silhouette test at 50 m** — Yes — it remains clearly visible at 50 meters, maintaining a strong vertical silhouette.

28. **Visual neighbours** — Looks best next to `coastal_coral`, `shattered_rock`, and `driftwood_cluster` — these assets complement its rugged, isolated appearance.

29. **Visual conflicts** — Should not spawn near `tall_tower`, `floating_raft`, or `dense_shrub` — these would visually compete or obscure the pillar's silhouette.

30. **Implementation hooks** — In `src/main.zig`, add `case 59: return .isolated_pillar` to the `world.team` switch. In `ios/Mesh.swift`, add `func makeIsolatedPillar(device: MTLDevice)` function. In `ios/GameViewController.swift`, add a dispatch case for `makeIsolatedPillar` in the `buildMesh` function.
---

## Asset 96 — weathered_outcrop
1. **Silhouette at 30m** — From across the lagoon, a flat-topped, weathered platform juts from the cliff face, its rugged edges and worn surface catching the light in a way that hints at ancient storms and shifting tides.

2. **Tri-budget breakdown** — Body: 260 tris, Decorations: 40 tris, FX: 20 tris.

3. **Geometry construction** — The base geometry is built from a single mbCylinder to form a broad, flat-topped platform. An mbSphere is added atop to simulate a weathered dome or overhang. Extrusions are used on the edges to create small overhangs and cracks, mimicking erosion and wind exposure. The mesh uses a fan of triangles to add surface detail to the top and a static cluster of smaller elements for debris.

4. **Body palette** — The primary surface uses sand_wet for base texture, accent_pearl for the top wear, driftwood_grey for cracks and shadows, and kelp_green for mossy patches on the lower edges.

5. **uBase marker assignments per surface** — 
| Surface        | uBase |
|----------------|-------|
| Top            | 47    |
| Cracks         | 48    |
| Moss           | 49    |
| Underneath     | 0     |

6. **Base scale (scale_min, scale_max)** — Scale range 0.8 to 1.2. This allows for a natural variation in platform size to avoid repetitive patterns while staying within the visual consistency of a weathered outcrop.

7. **Y rotation** — Random `0..2π`. Rotations are randomized to prevent a uniform, architectural feel and blend naturally into the island’s rugged terrain.

8. **Ground anchor** — Sits on island surface (y=island_y), partially buried in sand and rock to simulate natural settling and erosion.

9. **Procedural variation method** — Two instances differ by scale and palette hash. Palette hash is computed from position and instance index to vary color distribution subtly.

10. **Spawn placement rules — which island(s)** — Spawns on B, C, D, F. Within each island, within a radius of 100m from island center. Biome-zone: cliff face. Avoid-list: temple plaza, boundary ring.

11. **Spawn count rationale** — With a 900m radius and 60 instances, the spawn density ensures a natural spread across the biome without overcrowding, especially in high-traffic cliff zones.

12. **Clustering pattern** — Scattered-grid. Instances are placed to form a loose grid, not too clustered, allowing for natural movement paths and line-of-sight.

13. **Inter-asset spacing minimum (m)** — 8 meters minimum spacing to avoid visual clutter and maintain distinct platform presence.

114. **Path-clearance distance (m)** — 6 meters from the local path. It avoids being too close to bridges or walkways to allow for clear passage.

15. **Team color reasoning** — TEAM=59 corresponds to accent_coral in the `game_fill_draws` switch, matching the warm, weathered tone of the outcrop and integrating it into the island’s palette.

16. **Shadow / contact AO strategy** — Casts shadow with ground AO blob. Vertex AO is used for subtle edge highlights and depth.

17. **Distant-LOD strategy** — No LOD, like forest assets. The platform remains at full resolution even at long distances due to its unique silhouette and presence in the biome.

18. **Animation, if any** — Static, no animation. The outcrop is fixed in place and does not move or sway.

19. **Particle FX bound to entity** — None. No particle FX are bound to the mesh.

20. **Lighting interaction** — Sun-side warm tint from sand_wet and driftwood_grey; mist-side cool tint from kelp_green and accent_pearl.

21. **Collision** — Blocks player movement. `world.radius` is set to 0.8 to allow tight movement around the platform.

22. **Destructible** — No. The outcrop is a static, natural part of the island.

23. **Lore hook** — A weathered outcrop once served as a landing point for ancient mariners, its surface worn smooth by countless voyagers.

24. **Surface UV layout** — Top uses uBase 47, cracks use 48, moss uses 49, underneath uses 0.

25. **Material specularity** — Soft-glossy. The surface reflects light gently, mimicking weathered rock.

26. **Day/night appearance shift** — Sun-side warm tint with accent_pearl and driftwood_grey; shadow-side cool tint with sand_wet and kelp_green.

27. **Silhouette test at 50 m** — Yes, it still reads clearly at 50m. Its flat-topped structure and contrasting edges remain visible and distinct.

28. **Visual neighbours** — Looks right next to `cliff_edge`, `driftwood`, and `lava_crater`, composing a rugged, oceanic scene.

29. **Visual conflicts** — Should not be near `cave_entrance` or `temple_pillar`, which would create visual clutter or silhouette clash.

30. **Implementation hooks** — Add `case 59: return makeWeatheredOutcrop(device:)` to `world.team` switch in `src/main.zig`, add `makeWeatheredOutcrop(device:)` function to `ios/Mesh.swift`, and add `case 96: makeWeatheredOutcrop(device:)` to `dispatch` in `ios/GameViewController.swift`.
---

## Asset 97 — broken_hull_section
### 1. Silhouette at 30m
The broken hull section presents a sweeping, curved silhouette with a jagged edge and a partially buried profile that reads clearly from 30 meters across the lagoon.

### 2. Tri-budget breakdown
Body: 320 tris, Decorations: 70 tris, FX: 30 tris. Total = 420 tris.

### 3. Geometry construction
The asset is built from a base mbCylinder with a tapering radius to simulate hull curvature, and a series of extruded rings along its length. A few mbSphere components are added for structural debris and small protruding sections. The overall shape is a curved, half-buried, broken ship section that mimics a hull breach.

### 4. Body palette
The main color palette includes driftwood_grey, sand_wet, kelp_green, and accent_coral. Driftwood_grey covers the primary hull surface, sand_wet is used on the buried portions, kelp_green on mossy areas, and accent_coral for rusted or burned patches.

### 5. uBase marker assignments per surface
| Surface | uBase |
|--------|-------|
| Hull main | 51 |
| Buried section | 49 |
| Mossy area | 51 |
| Rust patch | 49 |
| Debris | 0 |
| Emissive | 8 |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This provides enough visual variation to avoid repetition while keeping the object proportionally realistic for a ship hull section.

### 7. Y rotation
Random `0..2π` rotation to avoid repetitive alignment and blend into natural terrain.

### 8. Ground anchor
Partially buried, sitting on the island surface with a y-offset of -0.6 meters, simulating a section half-buried in sand or debris.

### 9. Procedural variation method
Instances vary by color palette hash and a small scale spread to simulate wear and damage across the wreck.

### 10. Spawn placement rules — which island(s)
Spawns on island D (The Wreck) only. Within a 150m radius of island center. Biome-zone: beach edge. Avoid-list: no other wreckage or large rocks.

### 11. Spawn count rationale
With a 900m radius and a density of 30 instances, the asset is well spaced to avoid overpopulation in a zone that is primarily a beach edge with a strong visual theme of decay and driftwood.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to look natural and avoid clustering while still maintaining visual cohesion.

### 13. Inter-asset spacing minimum (m)
Minimum 5 meters to other instances of the same mesh.

### 14. Path-clearance distance (m)
8 meters from any island-local path to ensure safe player traversal.

### 15. Team color reasoning
TEAM=53 is chosen to align with the "wreckage" team in the `game_fill_draws` switch, which maps to driftwood_grey, matching the visual tone and palette of the asset.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a vertex-based AO blob to simulate the hull's contact with sand or debris.

### 17. Distant-LOD strategy
No LOD applied, as this is a forest-style asset that does not use LODs in the current implementation.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side appears warm with driftwood_grey and sand_wet tints. Shadow-side takes a cooler tone with kelp_green and accent_coral blending into the mist.

### 21. Collision
Blocks player movement; world.radius = 0.8.

### 22. Destructible
No. The asset is static and part of the environment.

### 23. Lore hook
A remnant of the old merchant fleet that once sailed these waters, now half-swallowed by sand and time.

### 24. Surface UV layout
uBase 51 covers the hull main and mossy areas; uBase 49 covers the buried section and rust patches; uBase 0 is used for small debris; uBase 8 for emissive light sources.

### 25. Material specularity
Soft-glossy, to simulate a weathered metal surface with some shine in reflective areas.

### 26. Day/night appearance shift
Sun-side is warm and tinted with driftwood_grey and sand_wet. Shadow-side takes a cooler tone, leaning into kelp_green and accent_coral hues.

### 27. Silhouette test at 50 m
Yes, the curved, half-buried silhouette remains clear and identifiable at 50 meters, maintaining legibility at half the average view distance.

### 28. Visual neighbours
Looks right next to beach_dune, driftwood_grey rocks, and kelp_green patches — all consistent with the decayed marine theme.

### 29. Visual conflicts
Should not be placed near large rocks or other wreckage assets, as it could create silhouette clutter or visual overload.

### 30. Implementation hooks
- Add `case 53: return .wreckage` to `world.team` switch in `src/main.zig`
- Add `makeBrokenHullSection(device:)` to `ios/Mesh.swift`
- Add `case 97: self.makeBrokenHullSection(device: device)` to dispatch in `ios/GameViewController.swift`
---

## Asset 98 — mast_pole
### 1. **Silhouette at 30m** — A tall, leaning pole with a single mast that cuts through the sky, its curved shape and sparse details making it a distinct beacon against the horizon.

### 2. **Tri-budget breakdown** — The body comprises 160 triangles, decorations (like rope and sail remnants) contribute 50, and FX (such as floating kelp motes) account for 30 triangles, summing to the 240-triangle budget.

### 3. **Geometry construction** — The main mast is built using `mbCylinder` with a slight taper from base to top. A `mbSphere` is added at the top to represent a weathered cap. The pole includes extruded rings for rope bands and a fan of triangles for a torn sail fragment.

### 4. **Body palette** — The mast uses `driftwood_grey`, `sail_cream`, and `accent_pearl` for its main body, with `kelp_green` for the rope bindings and a weathered edge.

### 5. **uBase marker assignments per surface** —  
| Surface       | uBase |
|---------------|-------|
| Mast body     | 51    |
| Rope bands    | 52    |
| Sail fragment | 53    |
| Cap sphere    | 54    |
| Base ring     | 55    |
| FX            | 0     |

### 6. **Base scale (scale_min, scale_max)** — `scale_min = 0.8`, `scale_max = 1.2`. This range allows for natural variation in pole height and thickness without breaking the visual consistency of the asset.

### 7. **Y rotation** — Random `0..2π`. This ensures visual variation and prevents repetitive alignment.

### 8. **Ground anchor** — Partially buried, with 15% of the pole’s height below the surface, mimicking a weathered, unstable structure.

### 9. **Procedural variation method** — Instances differ by a palette hash that modifies the color tint of the mast and rope, and by a small scale spread to simulate aging.

### 10. **Spawn placement rules — which island(s)** — Spawns on D (The Wreck) only. Radius: 60–100 meters from island center. Zone: beach edge. Avoid-list: bridges, other masts, large wreckage.

### 11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS D, 30 instances are distributed to create a believable density of drifting wreckage along the island's coast without over-cluttering.

### 12. **Clustering pattern** — Scattered-grid. Sparse but evenly distributed to avoid creating visual bottlenecks.

### 13. **Inter-asset spacing minimum (m)** — 12 meters minimum to other mast_pole instances.

### 14. **Path-clearance distance (m)** — 8 meters from island-local path, as the pole is on the beach edge and must not block movement.

### 15. **Team color reasoning** — TEAM=53 is chosen to match the `accent_coral` color swatch, which visually complements the maritime palette and stands out subtly against the island’s sand and kelp tones.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow and uses vertex AO to simulate the pole's contact with the ground, enhancing its grounded presence.

### 17. **Distant-LOD strategy** — No LOD is used; it remains visible at all distances like other forest assets, but simplifies slightly in rendering detail beyond 100m.

### 18. **Animation, if any** — Static, no animation. The asset is meant to appear weathered and fixed in place.

### 19. **Particle FX bound to entity** — `kelp_motes` floating around the base and rope bands for a subtle aquatic ambiance.

### 20. **Lighting interaction** — Sun-side appears warm with a golden driftwood tint; mist-side takes a cooler, bluish tone from the shallow water.

### 21. **Collision** — Blocks player movement; `world.radius = 0.6` to allow passage but not walking through.

### 22. **Destructible** — No. The mast is fixed and non-destructible to maintain its role as a landscape feature.

### 23. **Lore hook** — A once-mighty mast now leans into the sand, a relic of a ship that found its way to the island’s shores.

### 24. **Surface UV layout** — The mast body uses uBase 51, rope bands uBase 52, sail fragment uBase 53, cap sphere uBase 54, and base ring uBase 55, as per §5.

### 25. **Material specularity** — Soft-glossy, with a matte base and slight sheen on the rope and sail to simulate wetness and age.

### 26. **Day/night appearance shift** — During the day, sun-facing surfaces warm to a golden driftwood hue. At night, the shadows shift to a cool, blue tint, reflecting the island’s deep water.

### 27. **Silhouette test at 50 m** — Yes, the mast’s tall, lean silhouette is still clearly recognizable from 50 meters away.

### 28. **Visual neighbours** — Looks right next to `driftwood_chunk`, `kelp_tendril`, and `shattered_ship`, creating a cohesive wreckage aesthetic.

### 29. **Visual conflicts** — Should not spawn near `tower`, `boulder`, or `tree` — these would clutter the visual space and compete for attention.

### 30. **Implementation hooks** —  
- Add `case 53: return .mast_pole` to `world.team` switch in `src/main.zig`  
- Add `func makeMastPole(device: MTLDevice) -> (verts: [Vertex], idxs: [UInt16])` in `ios/Mesh.swift`  
- Add `case .mast_pole:` to dispatch in `ios/GameViewController.swift`
---

## Asset 99 — capstan_wheel
### 1. **Silhouette at 30m** — The capstan wheel appears as a flat, circular silhouette with prominent spoke-like protrusions, clearly visible from across the lagoon, suggesting a sturdy maritime mechanism.

### 2. **Tri-budget breakdown** — The geometry is split into 200 tris for the main body, 60 for decorative ratchet pawls, and 20 for small wear marks and surface detail, totaling 280 tris.

### 3. **Geometry construction** — The main wheel is built using a `mbCylinder` for the central hub and a series of extruded ring segments to form the outer rim. Decorative pawls are constructed using `mbSphere` instances positioned around the rim and aligned to the wheel’s axis. Additional small surface details are added via static cluster shapes.

### 4. **Body palette** — The wheel body uses `driftwood_grey`, `sand_wet`, and `accent_pearl` to represent weathered wood, wet sand contact points, and metallic ratchets. `sail_cream` is used for a subtle wear highlight on the rim.

### 5. **uBase marker assignments per surface** — 
| Surface            | uBase |
|--------------------|-------|
| Hub                | 51    |
| Rim                | 52    |
| Pawls              | 53    |
| Wear marks         | 54    |
| Metallic ratchet   | 55    |

### 6. **Base scale (scale_min, scale_max)** — Scale ranges from 0.8 to 1.2. The variation allows for subtle realism while keeping the asset consistent in size relative to other wreckage.

### 7. **Y rotation** — Aligned-to-island-radial. The wheel rotates to match the dominant orientation of the island's terrain, enhancing natural placement.

### 8. **Ground anchor** — Partially buried, with 1/3 of the wheel's height below the surface, giving it a weathered, settled-in appearance.

### 9. **Procedural variation method** — Two instances differ by palette hash and scale spread, with slight variation in wear mark placement and pawl alignment.

### 10. **Spawn placement rules — which island(s)** — Spawns are allowed on D (The Wreck) and A (Lantern Hold). Radius within island: 20–40m. Zone: beach edge. Avoid-list: bridges, temple plazas, and aerial zones.

### 11. **Spawn count rationale** — With a spawn radius of 20–40m and ISLAND_BIAS D, the 25 instances provide adequate coverage of the lagoon's edge while maintaining visual spread and avoiding clumping.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced across the island’s beach edge to avoid overcrowding and ensure a natural distribution.

### 13. **Inter-asset spacing minimum (m)** — Minimum 2.5m to other instances of the same mesh.

### 14. **Path-clearance distance (m)** — 6m from the nearest island-local path, ensuring clear navigation without obstruction.

### 15. **Team color reasoning** — TEAM=53 maps to `accent_coral` in `game_fill_draws`, giving the capstan a warm, maritime hue that contrasts with the cooler tones of the wrecked shipyard.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow with a ground AO blob beneath. Vertex-AO is used to enhance depth.

### 17. **Distant-LOD strategy** — Does not undergo LOD. The asset is kept visible up to 100m for detail and storytelling.

### 18. **Animation, if any** — Static, no animation. The wheel is not intended to move or rotate.

### 19. **Particle FX bound to entity** — None. No FX attached to the capstan.

### 20. **Lighting interaction** — Sun-side appears with a warm driftwood tint, while shadow-side takes on a cooler, wet sand hue, enhancing the weathered maritime feel.

### 21. **Collision** — Blocks player movement. `world.radius` is set to 0.6 to reflect its compact but solid form.

### 22. **Destructible** — No. The capstan is meant to remain intact as a relic of shipwrecked craftsmanship.

### 23. **Lore hook** — A forgotten capstan still holds the weight of a ship’s anchor, now rusted but still intact.

### 24. **Surface UV layout** — 
- Hub: uBase 51 (driftwood_grey)
- Rim: uBase 52 (sand_wet)
- Pawls: uBase 53 (accent_pearl)
- Wear marks: uBase 54 (sail_cream)
- Metallic ratchet: uBase 55 (accent_coral)

### 25. **Material specularity** — Soft-glossy. Reflects subtle light to indicate the wear on the metal pawls and wood grain.

### 26. **Day/night appearance shift** — During the day, sun-side warms to `driftwood_grey` with a hint of `sail_cream`. At night, shadow-side cools to a blend of `sand_wet` and `accent_pearl`.

### 27. **Silhouette test at 50 m** — Yes, the wheel retains its recognizable silhouette, with spoke-like structures clearly visible from 50m.

### 28. **Visual neighbours** — Looks best next to `forest_rock`, `shipwreck_bow`, and `anchor_chain`, creating a cohesive maritime ruin scene.

### 29. **Visual conflicts** — Should not be placed near `lighthouse_light`, `skywatch_tower`, or `portal_island`, as it would compete for silhouette prominence and visual focus.

### 30. **Implementation hooks** — 
- In `src/main.zig`, add case `53: capstan_wheel` to `world.team` switch.
- In `ios/Mesh.swift`, add `func makeCapstanWheel(device: MTLDevice) -> MeshBuffers`.
- In `ios/GameViewController.swift`, add `case 99: makeCapstanWheel(device:)` to `dispatchMeshCase`.
---

## Asset 100 — rusted_anchor
### 1. **Silhouette at 30m** — From across the lagoon, the anchor appears as a large, angular, rusted mass jutting from the sand, its thick, twisted metal limbs forming a distinctive 'Y' shape against the sky.

### 2. **Tri-budget breakdown** — Body: 180 tris; Decorations: 25 tris; FX: 15 tris. Total = 220 tris.

### 3. **Geometry construction** — The anchor body is built using a mbCylinder for the main shaft, with a tapered base and thickened top. A mbSphere is used for the forged head, with a series of extruded rings around the lower section to simulate rust and wear. The construction combines a static cluster of mesh pieces, with fan-of-triangles detail for the rust texture.

### 4. **Body palette** — The main body uses sand_wet (0.62, 0.55, 0.42) for the sand-buried section, driftwood_grey (0.45, 0.42, 0.38) for the rusted upper part, and accent_coral (0.92, 0.50, 0.42) for rust streaks. Foam_white (0.94, 0.96, 0.98) is used for wet highlights.

### 5. **uBase marker assignments per surface** — 

| Surface       | uBase |
|---------------|-------|
| Main shaft    | 0     |
| Rust streaks    | 49    |
| Wet sand base | 0     |
| Highlight     | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 0.8 to 1.2. This variation allows for naturalistic size differences while maintaining consistent proportions and visual weight.

### 7. **Y rotation** — Random `0..2π`. No fixed orientation to maintain natural scatter across terrain.

### 8. **Ground anchor** — Partially buried, with 30% of the anchor’s volume sitting below the sand surface to simulate being washed ashore.

### 9. **Procedural variation method** — Two instances differ by color palette hash and slight scale spread, with rust streaks applied procedurally using fbm noise to simulate uneven corrosion.

### 10. **Spawn placement rules — which island(s)** — Spawn on D (The Wreck) and F (Far Reach). Radius within island: 40–80 m. Biome-zone: beach edge. Avoid-list: temple plaza, bridge areas.

### 11. **Spawn count rationale** — With 25 instances and a 900 m radius, 25 instances provide adequate visual density without overcrowding the environment. Each instance is spaced to avoid visual clutter while maintaining an immersive presence.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed to appear naturally distributed across the beach, avoiding tight groupings.

### 13. **Inter-asset spacing minimum (m)** — Minimum 12 meters to other instances of the same mesh.

### 14. **Path-clearance distance (m)** — 6 meters from island-local paths to ensure accessibility and avoid obstruction.

### 15. **Team color reasoning** — TEAM=60 maps to the `world.team` switch for wreckage-related assets, which resolves to sand_wet (0.62, 0.55, 0.42) in `game_fill_draws`, aligning with the rusted, sand-encrusted aesthetic.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow. Ground AO blob is used to simulate the sand beneath the anchor, with vertex AO to emphasize crevices and rust.

### 17. **Distant-LOD strategy** — No LOD. The asset is kept visible at all distances to maintain its role as a landmark and lore anchor.

### 18. **Animation, if any** — Static, no animation. The anchor is a fixed environmental object.

### 19. **Particle FX bound to entity** — None.

### 20. **Lighting interaction** — Sun-side appears warm with rusted orange and yellow tints, while shadow-side takes on a cool, blue-gray hue due to the wet sand and rusted metal.

### 21. **Collision** — Blocks player movement. `world.radius` set to 1.0.

### 22. **Destructible** — No. This is a static environmental asset.

### 23. **Lore hook** — A relic from the ancient ship *The Wrecking Tide*, dragged ashore by the tides and left to rust.

### 24. **Surface UV layout** — uBase 0 covers the main shaft and sand base. uBase 49 covers rust streaks and wear patterns. uBase 8 covers wet highlights.

### 25. **Material specularity** — Soft-glossy. Reflects light slightly to simulate rusted metal with some wetness.

### 26. **Day/night appearance shift** — During the day, the anchor appears warm and sun-bleached. At night, the rust tones shift to cooler, shadowy tones, with faint ambient glow from the sand.

### 27. **Silhouette test at 50 m** — Yes, the anchor retains a clear silhouette and angular shape at half the average view distance.

### 28. **Visual neighbours** — Looks right next to beach debris, driftwood logs, and kelp clusters, forming a cohesive shipwreck scene.

### 29. **Visual conflicts** — Should not spawn near large statues or bridges, as they would visually compete with the anchor’s presence and silhouette.

### 30. **Implementation hooks** — In `src/main.zig`, add `case 60: return rusted_anchor` to `world.team` switch. In `ios/Mesh.swift`, add `makeRustedAnchor(device:)` function. In `ios/GameViewController.swift`, add `case 100: mesh = makeRustedAnchor(device)` to dispatch logic.
---

## Asset 101 — cargo_crate_open
### 1. **Silhouette at 30m** — A cracked open wooden shipping crate with a kelp-filled interior, sitting partially submerged in shallow water, its edges slightly weathered and torn.

### 2. **Tri-budget breakdown** — 120 body tris, 40 decorations, 20 FX.

### 3. **Geometry construction** — The base is a `mbCylinder` with a tapered top and bottom to simulate a wooden crate, using 8 rings and 16 sides for smoothness. A `mbSphere` is embedded within to represent a kelp-filled core, with a slight radial extrusion to suggest organic growth. Decorative planks and rust patches are added via stacked extrusions around the cylinder edges.

### 4. **Body palette** — Uses `driftwood_grey`, `kelp_green`, `sand_wet`, and `water_shallow` for different surfaces to reflect its maritime wrecked state.

### 5. **uBase marker assignments per surface** —  
| Surface         | uBase |
|----------------|-------|
| Crate body     | 51    |
| Kelp interior  | 52    |
| Rust patches   | 53    |
| Water foam     | 54    |
| Wood planks    | 55    |

### 6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. Justified by realistic size variation in maritime wreckage, balancing visual presence with performance.

### 7. **Y rotation** — Random `0..2π` for natural scattering across island terrain.

### 8. **Ground anchor** — Sits partially buried in shallow sand, with y = -0.2 to simulate a half-submerged wreck.

### 9. **Procedural variation method** — Variation occurs through palette hash and scale spread, with optional random sub-mesh subsets for plank detail.

### 10. **Spawn placement rules — which island(s)** — Spawn on islands D and F (scattered B and F). Radius within island = 30–60m. Zone = beach edge or shallow water. Avoid-list = no close proximity to `tall_ship`, `lighthouse`, or `ruin_brazier`.

### 11. **Spawn count rationale** — 30 instances across 900m radius matches the expected density of debris fields near the wreck island, and aligns with ISLAND_BIAS D and F for realistic spatial distribution.

### 12. **Clustering pattern** — Scattered-grid with 2–3 instances per cluster, spaced 3–5m apart.

### 13. **Inter-asset spacing minimum (m)** — 4 meters minimum from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 6 meters from any island-local path, excluding bridges.

### 15. **Team color reasoning** — TEAM=53 maps to `driftwood_grey`, which matches the overall color scheme of the wreck and ensures visual cohesion with forest wreckage assets.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow and uses vertex AO for contact lighting to suggest the crate’s partially submerged and weathered nature.

### 17. **Distant-LOD strategy** — No LOD; asset remains at full resolution to preserve detail in close-up view, consistent with forest asset behavior.

### 18. **Animation, if any** — Static, no animation.

### 19. **Particle FX bound to entity** — `kelp_motes` emits from the kelp-filled interior, creating a soft ambient glow and movement.

### 20. **Lighting interaction** — Sun-side has a warm, weathered wood tint, while shadow-side takes on a cooler, misty blue tone from the surrounding water.

### 21. **Collision** — Blocks player movement, with `world.radius = 0.6` to simulate a solid but slightly soft collision.

### 22. **Destructible** — No.

### 23. **Lore hook** — The crate was last seen on a cargo ship heading for the island’s ruins, now half-buried in the tide.

### 24. **Surface UV layout** — uBase 51 covers the main crate body, 52 covers kelp interior, 53 for rust patches, 54 for foam on the waterline, and 55 for plank texture.

### 25. **Material specularity** — Soft-glossy, with a matte base and slight sheen on rust patches.

### 26. **Day/night appearance shift** — During day, the wood tone warms to a light brown; at night, it cools into a dusky grey with ambient light reflection from the kelp.

### 27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and recognizable, with a strong contrast between the crate's angular edges and the kelp’s soft organic form.

### 28. **Visual neighbours** — Looks right next to `driftwood_pile`, `sea_urchin`, and `shark_fin`, as they all share the same maritime aesthetic.

### 29. **Visual conflicts** — Should not spawn near `sacred_brazier`, `tower_brick`, or `floating_raft`, as those assets have strong, contrasting visual tones.

### 30. **Implementation hooks** —  
- Add `case 53: return .cargo_crate_open` to `world.team` switch in `src/main.zig`.  
- Add `func makeCargoCrateOpen(device: MTLDevice) -> [MTLBuffer]` in `ios/Mesh.swift`.  
- Add `case 101: makeCargoCrateOpen(device: device)` to dispatch in `ios/GameViewController.swift`.
---

## Asset 102 — sail_remnant_torn
### 1. Silhouette at 30m
From across the lagoon, the torn sail appears as a tattered triangular shape fluttering in the wind, its edges ragged and asymmetrical, catching the light from the setting sun.

### 2. Tri-budget breakdown
Body geometry: 140 tris. Decorations (fraying edges and torn patches): 40 tris. FX (particle effects): 20 tris.

### 3. Geometry construction
The main sail body is built with a `mbCylinder` with a vertical taper from a wide base to a narrow tip, forming the triangular sail shape. A few `mbSphere` elements are used for small fraying knots and tattered edges. Additional extruded rings are added along the sail's perimeter to simulate the torn effect, and a few fan-of-triangles structures are used to define individual patches of the fabric.

### 4. Body palette
Uses `sail_cream` for the primary body, `driftwood_grey` for fraying edges, `accent_coral` for a few torn patches, and `foam_white` for highlights on the wind-blown edges.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Main sail      | 52    |
| Frayed edges   | 53    |
| Torn patches   | 54    |
| Highlights     | 55    |
| Emissive       | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.7 to 1.2. Justification: Varying scale allows the sail to appear as if it's been torn loose from a larger structure and partially flung or blown to its current position.

### 7. Y rotation
Random `0..2π`. The sail is rotated randomly to simulate the natural sway and movement of the tattered material in the wind.

### 8. Ground anchor
Sits partially buried in sand, with y = -0.2 to simulate the effect of it being stuck in the driftwood or sand on the beach.

### 9. Procedural variation method
Two instances differ by scale spread and color palette hash (using a simple hash on the instance position or a noise function).

### 10. Spawn placement rules — which island(s)
Spawn on islands D (The Wreck) and E (Skywatch), within a 100m radius of island center. Biome-zone: beach edge / cliff face. Avoid-list: bridge zones, temple plaza.

### 11. Spawn count rationale
The 30 instances are appropriate for a 900m radius zone, allowing for an even distribution of scattered wreckage, with density matching the visual weight of a real shipwreck area.

### 12. Clustering pattern
Scattered-grid. Instances are spread across the beach with minimal clustering, allowing for a natural look.

### 13. Inter-asset spacing minimum (m)
Minimum 2.5 meters to another instance of the same mesh to avoid visual clutter.

### 14. Path-clearance distance (m)
8 meters from the local path. This ensures the sail does not interfere with player movement or obstruct bridge walkways.

### 15. Team color reasoning
TEAM=62 is chosen to represent the “wreckage” category and to blend with the `sail_cream` palette, resolving to a muted, weathered tan color in the `game_fill_draws` switch.

### 16. Shadow / contact AO strategy
Casts a soft shadow and uses vertex AO to simulate the wind-blown, tattered nature of the sail fabric. No ground AO blob.

### 17. Distant-LOD strategy
No LOD. The asset remains visible at all distances, as the forest does not implement LOD.

### 18. Animation, if any
Static, no animation. The sail remains fixed in place with no movement to avoid disrupting the environment's realism.

### 19. Particle FX bound to entity
None. The sail does not emit particles or have FX bound to it.

### 20. Lighting interaction
Sun-side appears with a warm, slightly orange tint due to the fabric’s color and light interaction, while shadow-side takes on a cool, bluish hue from the ambient ocean light.

### 21. Collision
Does not block player movement. `world.radius` set to 0.3 to allow easy passage through.

### 22. Destructible
No. The sail is a static decorative element and does not break or transform.

### 23. Lore hook
This torn piece of sail was once part of a vessel that crashed into the reef during the great storm.

### 24. Surface UV layout
Main sail uses uBase 52, frayed edges use 53, torn patches use 54, and highlights use 55. Emissive area (for glow or light reflection) is mapped to uBase 8.

### 25. Material specularity
Soft-glossy. The sail has a slightly reflective surface that catches light, especially at the edges and highlight areas.

### 26. Day/night appearance shift
During the day, the sail appears warm and sunlit, with a slight orange tint on sun-facing surfaces. At night, it shifts to a cooler, shadowed tone, with subtle blue undertones.

### 27. Silhouette test at 50 m
Yes, the sail still reads clearly at 50 meters, maintaining its triangular silhouette and the visual impact of its tattered edges.

### 28. Visual neighbours
Looks best next to `driftwood`, `kelp`, and `sea_coral` assets. It complements the beach and wreck theme of the environment.

### 29. Visual conflicts
Should not be placed near other large, angular wreckage assets or in dense clusters with `sea_coral` or `beach_sand` to avoid visual overcrowding.

### 30. Implementation hooks
- Add case `62` to `world.team` switch in `src/main.zig`.
- Add `makeSailRemnantTorn(device:)` function in `ios/Mesh.swift`.
- Add dispatch case `case 102:` in `ios/GameViewController.swift` to instantiate `sail_remnant_torn`.
---

## Asset 103 — rope_coil_pile
### 1. **Silhouette at 30m** — From across the lagoon, the rope coil pile appears as a dark, tangled mass that resembles a twisted knot or a small black mound, barely distinct from the surrounding deck debris.

### 2. **Tri-budget breakdown** — Body: 120 tris, Decorations: 15 tris, FX: 5 tris. Total: 140 tris.

### 3. **Geometry construction** — The main body uses an mbCylinder with tapering radius from 0.6 to 0.3, stacked in 4 rings to simulate a coil. Two mbSphere instances are used to form the ends of the coil, each with a radius of 0.2. Extrusions are added to simulate rope strands, using a fan of triangles for each strand. The structure is a static cluster with no animation.

### 4. **Body palette** — Uses driftwood_grey, sand_wet, accent_coral, and foam_white for surface variation. The primary color is driftwood_grey, with accent touches of sand_wet on the base and coral on the edges.

### 5. **uBase marker assignments per surface** —  
| Surface        | uBase |
|----------------|-------|
| Coil body      | 51    |
| Coil ends      | 52    |
| Base contact   | 51    |
| Rope strands   | 52    |
| FX / emissive  | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 0.7 to 1.2. Justification: Varying scale allows for realistic visual depth and variation in the pile, mimicking how rope coils are not uniform in size.

### 7. **Y rotation** — Random `0..2π`. The coil is rotated randomly to avoid visual repetition across instances.

### 8. **Ground anchor** — Partially buried, with 30% of the coil below the island surface, as if it had been dragged or left there over time.

### 9. **Procedural variation method** — Variations are driven by palette hash and scale spread. Each instance uses a different color blend and slight scale adjustment to avoid repetition.

### 10. **Spawn placement rules — which island(s)** — Spawns on island D (The Wreck), within a 50m radius. Biome-zone: beach edge. Avoids: bridge zones, temple plazas, and cliff faces.

### 11. **Spawn count rationale** — The `est_count = 30` is appropriate for the 900m radius of island D, as it allows for a sparse but meaningful presence of rope piles without overcrowding the zone.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid visual clumping, with slight randomness in placement.

### 13. **Inter-asset spacing minimum (m)** — Minimum 3 meters to another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 6 meters from island-local paths (bridges excluded).

### 15. **Team color reasoning** — TEAM=53 maps to a deep, muted red-orange that reflects the tarred rope's coloration. It resolves to accent_coral in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow and uses a vertex-AO blob for contact lighting to enhance realism on the deck.

### 17. **Distant-LOD strategy** — No LOD is used; the asset remains consistent at all distances, as is standard for forest assets.

### 18. **Animation, if any** — Static, no animation. The rope is rigid and does not move.

### 19. **Particle FX bound to entity** — None. No particle effects are bound to this asset.

### 20. **Lighting interaction** — Sun-side is tinted with a warm driftwood_grey, while shadow-side is cooler, leaning into sand_wet and accent_coral.

### 21. **Collision** — Does not block movement. `world.radius` is set to 0.3, as it's a small, non-obstructive item.

### 22. **Destructible** — No. It does not break or degrade under impact.

### 23. **Lore hook** — The pile is a remnant of a ship’s rigging, now tangled and weathered, left behind by the last storm.

### 24. **Surface UV layout** — uBase 51 covers the main coil body and base. uBase 52 covers the ends and rope strands. uBase 8 is used for emissive FX.

### 25. **Material specularity** — Matte. The rope texture is rough and non-reflective.

### 26. **Day/night appearance shift** — During the day, the rope appears in driftwood_grey with warm sun highlights. At night, the shadow sides cool into sand_wet and accent_coral.

### 27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and identifiable at 50 meters, especially against the island deck.

### 28. **Visual neighbours** — Looks right next to wreckage items like broken planks, rusted metal pipes, and driftwood piles.

### 29. **Visual conflicts** — Should not be placed near large, bright items like lanterns or embers, as it would reduce contrast and visual clarity.

### 30. **Implementation hooks** —  
- `src/main.zig`: Add `case 53` to `world.team` switch.  
- `ios/Mesh.swift`: Add `makeRopeCoilPile(device:)` function.  
- `ios/GameViewController.swift`: Add `case 103` to dispatch in `loadAssets`.
---

## Asset 104 — snapped_oar
### 1. **Silhouette at 30m** — A long, angular driftwood fragment lies half-buried in sand, with one end protruding like a broken oar, suggesting a maritime disaster.

### 2. **Tri-budget breakdown** — 80 body triangles, 20 decorations, 20 FX. Total = 120.

### 3. **Geometry construction** — Constructed using a main mbCylinder for the oar body, tapering from thick to thin, with a mbSphere at one end for a natural cap. Extrusions add texture and small splinters to mimic weathered wood. The piece is designed to be slightly buried in sand, with a soft, rounded base and sharp edges.

### 4. **Body palette** — Uses driftwood_grey, beach_dune, sand_wet, and accent_pearl to simulate aged driftwood, sand contact, and weathered textures.

### 5. **uBase marker assignments per surface** — 
| Surface        | uBase |
|----------------|-------|
| Oar body       | 51    |
| Splinter tips  | 52    |
| Sand contact   | 53    |
| Foam contact   | 54    |
| Emissive       | 8     |

### 6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. This scale range allows for natural variation in size and age, while maintaining visual cohesion with other wreckage.

### 7. **Y rotation** — Random `0..2π`. Ensures natural scattering without predictable alignment.

### 8. **Ground anchor** — Partially buried, with the lower half embedded in sand, sitting flush with the island surface (y=island_y) and slightly tilted to simulate erosion.

### 9. **Procedural variation method** — Sub-mesh subset variation — a few instances include extra splintered pieces or weathered texture patches.

### 10. **Spawn placement rules — which island(s)** — D, B. Spawn radius within 30–50m. Biome-zone: beach edge. Avoid-list: other wreckage, temple plaza, boundary ring.

### 11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS D,B, 25 instances across the two islands ensures a natural spread without overcrowding, matching the expected density of debris in a maritime zone.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed with loose spacing, mimicking a natural driftwood accumulation.

### 13. **Inter-asset spacing minimum (m)** — 3 meters. Ensures visual separation without empty space.

### 14. **Path-clearance distance (m)** — 6 meters. Avoids interference with island paths and allows for navigation.

### 15. **Team color reasoning** — TEAM=53 aligns with driftwood_grey palette, a warm, earthy tone that blends into beach and sand environments. Resolves to `driftwood_grey` in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob is used to simulate sand contact. Vertex-AO is minimal.

### 17. **Distant-LOD strategy** — Asset disappears at 150m. No LOD used, consistent with forest mesh strategy.

### 18. **Animation, if any** — Static, no animation. No motion to preserve realism in a weathered, half-buried object.

### 19. **Particle FX bound to entity** — None. No attached particle effects.

### 20. **Lighting interaction** — Sun-side warm tint with slight amber undertones; shadow-side cools to a muted blue-gray.

### 21. **Collision** — Does not block player movement. `world.radius` set to 0.3, to avoid interference with player navigation.

### 22. **Destructible** — No. Does not break or degrade under player interaction.

### 23. **Lore hook** — A shattered oar from a shipwreck, now buried in sand, serves as a reminder of the dangers of the sea.

### 24. **Surface UV layout** — uBase 51 covers main oar body; uBase 52 for splinter tips; uBase 53 for sand contact; uBase 54 for foam contact; uBase 8 for emissive glow (if used).

### 25. **Material specularity** — Soft-glossy. Mimics weathered wood with slight sheen to reflect light subtly.

### 26. **Day/night appearance shift** — During daylight, sun-facing side warms to driftwood_grey with subtle amber; shadowed side cools to a dusky gray-blue. At night, the soft gloss remains, but the contrast shifts to cooler tones.

### 27. **Silhouette test at 50 m** — Yes, the angular oar shape remains distinct, even at half the average view distance.

### 28. **Visual neighbours** — Looks right next to `forest_stump`, `wreckage_sail`, and `driftwood_cluster`, contributing to a cohesive maritime debris theme.

### 29. **Visual conflicts** — Should not be near `driftwood_cluster` or `wreckage_sail` in high-density zones, to avoid silhouette clutter.

### 30. **Implementation hooks** — 
- In `src/main.zig`: Add case `53` to `world.team` switch for `snapped_oar`.
- In `ios/Mesh.swift`: Add `makeSnappedOar(device:)` function.
- In `ios/GameViewController.swift`: Add dispatch case for `snapped_oar` in asset loading logic.

```metal
float3 color = mix(driftwood_grey, sand_wet, smoothstep(0.0, 0.5, uv.y));
```
---

## Asset 105 — glow_coral_branch
1. **Silhouette at 30m** — From across the lagoon, the glow_coral_branch appears as a branching, glowing filament, its luminous tendrils forming a soft, undulating silhouette against the ocean's surface.

2. **Tri-budget breakdown** — Body: 140 tris, Decorations: 25 tris, FX: 15 tris.

3. **Geometry construction** — The core structure uses a mbCylinder for the main trunk, tapering from 0.5m to 0.2m in radius over 1.2m height. Two mbSphere instances are placed at the trunk’s endpoints to form bulbous nodes. Extrusions are added to simulate branching, with the branches themselves modeled using tapered mbCylinder segments of decreasing radius. The mesh is constructed using a fan of triangles for cap geometry and a stacked plate approach for the inner branching structure.

4. **Body palette** — Uses kelp_green, sand_wet, driftwood_grey, and accent_coral. The main trunk is kelp_green, the bulbous nodes use sand_wet, the base and root-like structures are driftwood_grey, and the glowing tips are accent_coral.

5. **uBase marker assignments per surface** — 
| Surface         | uBase |
|----------------|--------|
| Main trunk     | 53     |
| Bulbous nodes  | 54     |
| Branches       | 55     |
| Glowing tips   | 8      |
| Base/roots     | 56     |

6. **Base scale (scale_min, scale_max)** — 0.7 to 1.3. This scale range allows for natural variation in coral growth while maintaining structural coherence and preventing over-scaling in tight environments.

7. **Y rotation** — Random 0..2π. This ensures natural-looking placement without predictable alignment.

8. **Ground anchor** — Sits on island surface (y=island_y). The base is fully planted and stable, not floating or partially buried.

9. **Procedural variation method** — Two instances differ by scale spread and palette hash. Variation in node size and glow intensity is driven by a hash of the instance's world position.

10. **Spawn placement rules — which island(s)** — Spawns on C (50%), E (20%), and scatter A+F. Radius within island is 10–20m. Biome-zone: beach edge or cliff face. Avoid-list: temple plaza, boundary ring.

11. **Spawn count rationale** — With a 900m radius and a 50% bias to C, the 90 instances are evenly distributed to provide a rich visual texture without overcrowding. The density matches the expected bioluminescent coral density in the Drifting Isles.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid clustering while maintaining visual richness.

13. **Inter-asset spacing minimum (m)** — 2.0 meters. This ensures that no two branches are too close, preserving the natural look of coral.

14. **Path-clearance distance (m)** — 6 meters. It can spawn near paths but not too close to avoid collision with player movement.

15. **Team color reasoning** — TEAM=63 is chosen to distinguish bioluminescent coral from other flora. It resolves to accent_coral in `game_fill_draws`.

16. **Shadow / contact AO strategy** — Casts shadow using ground AO blob. Vertex-AO is not used due to performance constraints.

17. **Distant-LOD strategy** — No LOD. It is designed to remain visible at all distances, as its glow is a core visual feature.

18. **Animation, if any** — Static, no animation. The glow pulses using a per-instance time offset in the shader.

19. **Particle FX bound to entity** — None. No bound particles, but a soft glow effect is used via emissive material.

20. **Lighting interaction** — Sun-side warm tint with a subtle amber hue; mist-side cool tint with a blue-green hue.

21. **Collision** — Does not block player movement. `world.radius` set to 0.3m to allow player to walk through.

22. **Destructible** — No. It is a static environmental asset.

23. **Lore hook** — This glowing coral is a remnant of the ancient sea gardens, now pulsing with dormant energy.

24. **Surface UV layout** — uBase 53 covers the main trunk, 54 covers bulbous nodes, 55 covers branches, 8 covers glowing tips, 56 covers the base and roots.

25. **Material specularity** — Soft-glossy. The surface has a subtle sheen to mimic the oceanic texture of coral.

26. **Day/night appearance shift** — During the day, the coral glows with a warm amber hue; at night, it shifts to a cooler blue-green glow.

27. **Silhouette test at 50 m** — Yes, it still reads clearly at half the average view distance, with its branching form and pulsating glow remaining visible.

28. **Visual neighbours** — Looks right next to kelp, driftwood, and sea foam assets, forming a cohesive underwater ecosystem.

29. **Visual conflicts** — Should not spawn near dense forests or other glowing assets to avoid silhouette clash and visual overcrowding.

30. **Implementation hooks** — Add `case 63:` to `world.team` switch in `src/main.zig`. Add `makeGlowCoralBranch(device:)` to `ios/Mesh.swift`. Add dispatch case in `ios/GameViewController.swift` under `case 105:` for instance loading.
---

## Asset 106 — jellyfish_lantern_static
1. **Silhouette at 30m** — From across the lagoon, the lantern appears as a glowing, pulsing blob with a faintly tapering stalk, barely distinguishable from the ambient mist.

2. **Tri-budget breakdown** — Body: 120 tris, Decorations: 60 tris, FX: 40 tris.

3. **Geometry construction** — The body is built using a mbCylinder with a tapered radius from 0.6 to 0.3, and a top mbSphere to simulate a jellyfish bell. The stalk is a thin mbCylinder with a ring extrusion at the base. The decoration is a fan of triangles around the base, resembling a coral-like attachment.

4. **Body palette** — water_shallow, foam_white, kelp_green, accent_coral.

5. **uBase marker assignments per surface** —  
| Surface        | uBase |
|----------------|-------|
| Body           | 53    |
| Decorations    | 8     |
| FX             | 8     |

6. **Base scale (scale_min, scale_max)** — 0.6 to 1.2. This allows for a natural size range to match different heights of hanging structures.

7. **Y rotation** — random `0..2π`. Rotation is randomized for natural variation.

8. **Ground anchor** — Partially buried, sitting on island surface with y = island_y + 0.2.

9. **Procedural variation method** — Palette hash and scale spread. Variations are generated from a hash of the instance ID and a noise function.

10. **Spawn placement rules — which island(s)** — A, C, E. Spawn radius within island is 10–15m. Biome-zone is beach edge. Avoid-list includes: bridge structures, temple plazas.

11. **Spawn count rationale** — The count of 80 is balanced to provide a sufficient ambient glow without overcrowding. At 900m radius, a density of ~1 lantern per 100m² is ideal for visual cohesion.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to appear natural but not too frequent.

13. **Inter-asset spacing minimum (m)** — 6 meters.

14. **Path-clearance distance (m)** — 6 meters from path.

15. **Team color reasoning** — TEAM=63 maps to the accent_coral swatch, which aligns with the bioluminescent theme. It ensures a distinct color for the lantern team in `game_fill_draws`.

16. **Shadow / contact AO strategy** — Casts a soft shadow and has a vertex-AO blob beneath to simulate ground contact.

17. **Distant-LOD strategy** — Disappears at 120 meters. No LOD in the forest; this asset follows the same behavior.

18. **Animation, if any** — Static, no animation.

19. **Particle FX bound to entity** — `lantern_glow` particle emitter.

20. **Lighting interaction** — Sun-side warm tint (amber), mist-side cool tint (blue).

21. **Collision** — Does not block player movement. `world.radius` set to 0.2.

22. **Destructible** — No.

23. **Lore hook** — These lanterns were once used by ancient sailors to mark safe passage through the Drifting Isles.

24. **Surface UV layout** — uBase 53 covers the main body, uBase 8 covers the FX and decorations.

25. **Material specularity** — Soft-glossy with emissive-additive.

26. **Day/night appearance shift** — During the day, the lantern appears warm and amber; at night, it glows more intensely with a subtle blue hue.

27. **Silhouette test at 50 m** — Yes, the lantern still reads clearly as a glowing blob with a defined stalk.

28. **Visual neighbours** — Looks right next to driftwood_grey structures, kelp_green vegetation, and sand_wet terrain.

29. **Visual conflicts** — Should not spawn near large-scale temple structures or other glowing biolum assets.

30. **Implementation hooks** —  
- In `src/main.zig`, add `case 63: return .jellyfish_lantern_static` to `world.team` switch.  
- In `ios/Mesh.swift`, add `func makeJellyfishLanternStatic(device: MTLDevice) -> MeshBuffers` function.  
- In `ios/GameViewController.swift`, add `case .jellyfish_lantern_static` to dispatch switch.
---

## Asset 107 — lantern_fish_school
### 1. Silhouette at 30m
From across the lagoon, the lantern_fish_school appears as a shimmering, glowing cluster of luminous points, suspended in a loose spherical formation, with no clear outline except for the soft ambient glow radiating outward from its core.

### 2. Tri-budget breakdown
The mesh is constructed with 120 tris for the main body, 60 tris for decorations, and 20 tris for FX elements, totaling 200 tris as specified by EST_TRIS.

### 3. Geometry construction
The base structure uses `mbCylinder` for a central tapering spine, followed by `mbSphere` to form a diffuse, soft glow envelope. Decorative elements include extruded rings and fan-of-triangles to simulate bioluminescent filaments radiating outward from the central cluster.

### 4. Body palette
The body palette draws from `water_shallow`, `kelp_green`, `sail_cream`, and `accent_coral` — with `water_shallow` covering the central core, `kelp_green` on the outer filaments, `sail_cream` on the translucent edges, and `accent_coral` for subtle highlight accents.

### 5. uBase marker assignments per surface
| Surface | uBase |
|--------|-------|
| Central core | 53 |
| Filament edges | 8 |
| Decorative rings | 53 |
| FX glow | 8 |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.4 to 0.7. This range ensures the fish cluster feels appropriately small to medium in scale, neither too dominant nor too lost in the environment.

### 7. Y rotation
Y rotation is random `0..2π`, allowing natural variation in orientation for each instance.

### 8. Ground anchor
The lantern_fish_school floats in shallow water at y = -0.4, partially submerged, mimicking a natural underwater cluster.

### 9. Procedural variation method
Two instances differ by color palette hash and scale spread, with one instance having a warmer coral tint and another a cooler kelp-green tint.

### 10. Spawn placement rules — which island(s)
Spawns occur on islands C and E (Glasstop and Skywatch). Radius within island is 15–30 meters. Biome-zone is beach edge or shallow lagoon. Avoid-list includes temple plaza and boundary ring.

### 11. Spawn count rationale
With an estimated 900m radius and two islands (C and E), 80 instances is sufficient to create a believable, scattered but frequent presence without overcrowding.

### 12. Clustering pattern
The fish cluster is placed in a scattered-grid pattern, ensuring each group is spaced to appear natural and non-repetitive.

### 13. Inter-asset spacing minimum (m)
Minimum spacing to another instance of the same mesh is 4.5 meters.

### 14. Path-clearance distance (m)
It must spawn at least 6 meters from any island-local path, including bridges, to ensure clear movement.

### 15. Team color reasoning
TEAM=63 is chosen to match the `world.team` switch's biolum color group, resolving to `accent_coral` in the `game_fill_draws` switch, which aligns with the asset's glowing appearance.

### 16. Shadow / contact AO strategy
It casts no shadow. Instead, a subtle vertex-AO effect is applied to simulate the glow of the cluster against darker water.

### 17. Distant-LOD strategy
No LOD is applied, as forest assets do not use distant simplification. The asset maintains its detail at all distances.

### 18. Animation, if any
Static, no animation. The visual effect is entirely procedural via shader.

### 19. Particle FX bound to entity
A subtle `lantern_glow` particle FX is bound to the cluster, simulating the soft, pulsing emission of the fish.

### 20. Lighting interaction
On sun-side, the cluster glows warm with a golden tint; on mist-side, it takes on a cool blue-green hue.

### 21. Collision
It does not block player movement. Its `world.radius` is set to 0.3, allowing passage through the cluster.

### 22. Destructible
No, it is not destructible.

### 23. Lore hook
The lantern fish school is said to follow ancient trails of light, guiding lost sailors to safety in the drifting isles.

### 24. Surface UV layout
uBase 53 covers the central core and filaments, while uBase 8 handles the emissive FX glow and edge highlights.

### 25. Material specularity
Emissive-additive with soft-glossy surface highlights to enhance the glowing appearance.

### 26. Day/night appearance shift
During the day, the cluster glows warm and vibrant; at night, it appears dimmer but maintains a soft, ethereal glow.

### 27. Silhouette test at 50 m
Yes, the lantern_fish_school still reads clearly at 50m, with a soft, glowing silhouette that remains distinguishable from background.

### 28. Visual neighbours
It looks right next to `kelp_tendrils`, `sea_urchin_cluster`, and `driftwood_pile`, composing a cohesive underwater scene.

### 29. Visual conflicts
It should not be placed near `firefly_nest` or `pyre_sparks`, as these would create a visual overload and conflict in the glow palette.

### 30. Implementation hooks
- `src/main.zig`: Add `case 63: return .biolum` to `world.team` switch.
- `ios/Mesh.swift`: Add `makeLanternFishSchool(device:)` function.
- `ios/GameViewController.swift`: Add `case 107: return makeLanternFishSchool(device:)` to dispatch.
---

## Asset 108 — glow_anemone
### 1. **Silhouette at 30m** — From across the lagoon, the anemone appears as a tall, vertical cluster of pulsing tendrils, with a subtle organic glow radiating from its base.

### 2. **Tri-budget breakdown** — Body: 100 tris; Decorations: 40 tris; FX: 20 tris. Total = 160 tris.

### 3. **Geometry construction** — The base body is constructed using `mbCylinder` with a tapered radius to simulate a central stalk, topped by `mbSphere` for the cap. Tendrils are extruded from the top using a fan of triangles, each with a slight bend along the Y-axis to simulate natural movement. The mesh is built in a static cluster configuration with no internal joints or bones.

### 4. **Body palette** — The base is kelp_green, the cap is accent_pearl, the tendrils are ember_lantern, and the glow is water_deep.

### 5. **uBase marker assignments per surface** — 
| Surface | uBase |
|--------|-------|
| Body | 53 |
| Cap | 54 |
| Tendrils | 55 |
| Glow | 8 |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 0.7 to 1.3. Justification: To allow variation in density while maintaining visual balance in a high-density zone.

### 7. **Y rotation** — Random `0..2π`. Allows natural dispersion across the island’s surface.

### 8. **Ground anchor** — Partially buried (y = -0.2). Anchors into the sand to appear rooted, but not completely.

### 9. **Procedural variation method** — Scale spread and color palette hash. Variation is driven by a noise function to avoid uniformity.

### 10. **Spawn placement rules — which island(s)** — Spawns only on C (Glasstop) and F (Far Reach). Radius within island: 50–100m. Biome-zone: beach edge. Avoid-list: temples, bridges, and other glowing assets.

### 11. **Spawn count rationale** — With a 900m radius and 80 instances, each anemone is spaced approximately 11m apart, creating a dense but non-overlapping cluster that fits the biolum zone’s visual density.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed to appear evenly distributed across the beach edge.

### 13. **Inter-asset spacing minimum (m)** — 6 meters. Prevents visual crowding and ensures individual instances are distinguishable.

### 14. **Path-clearance distance (m)** — 6 meters. Ensures no instance blocks access to island paths.

### 15. **Team color reasoning** — TEAM=63 maps to a soft bioluminescent blue, matching the visual theme of glowing flora. Resolves to `accent_coral` in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow. Ground AO blob is used for contact lighting at the base to simulate interaction with the sand.

### 17. **Distant-LOD strategy** — Disappears at 150m distance. No LOD implemented, as this is a forest-style asset.

### 18. **Animation, if any** — Static, no animation. The pulsing effect is achieved via vertex-based UV animation and emissive lighting.

### 19. **Particle FX bound to entity** — `lantern_glow` emitter attached to the base to simulate ambient light emission.

### 20. **Lighting interaction** — Sun-side is warm with a golden tint; mist-side is cool with a blue tint, enhancing the glowing effect in both lighting conditions.

### 21. **Collision** — Does not block movement. `world.radius` set to 0.3 for minimal interaction.

### 22. **Destructible** — No. The asset is purely visual and non-interactive.

### 23. **Lore hook** — These glowing anemones are said to be the resting places of ancient sea spirits, pulsing with the rhythm of the tides.

### 24. **Surface UV layout** — 
- uBase 53 (Body) → main cylindrical surface  
- uBase 54 (Cap) → sphere cap  
- uBase 55 (Tendrils) → fan extruded tendrils  
- uBase 8 (Glow) → emissive base UV mapping  

### 25. **Material specularity** — Soft-glossy. Reflects light slightly to simulate the wet, organic texture of a sea creature.

### 26. **Day/night appearance shift** — During the day, the surface appears warm with kelp-green tones; at night, the glow intensifies, shifting towards a cooler, more radiant hue.

### 27. **Silhouette test at 50 m** — Yes, the silhouette remains distinct and recognizable, with clear vertical definition.

### 28. **Visual neighbours** — Looks right next to `sea_coral`, `driftwood`, and `sand_dunes`, as they all belong to the same biome aesthetic.

### 29. **Visual conflicts** — Should not spawn near `firefly_fount`, `pyre_sparks`, or `lava_bubbles`, as they would compete visually for attention.

### 30. **Implementation hooks** — 
- Add `case 63: return .glow_anemone` in `world.team` switch in `src/main.zig`
- Add `makeGlowAnemone(device:)` function in `ios/Mesh.swift`
- Add dispatch case `case 108: return .glow_anemone` in `GameViewController.swift`
---

## Asset 109 — biolum_kelp_strand
### 1. Silhouette at 30m — one sentence describing the shape from across the lagoon.
From 30 meters out, a kelp strand appears as a tall, tapering green column with a faintly glowing tip, barely distinguishable from the ambient mist but subtly pulsing in the light.

### 2. Tri-budget breakdown — body / decorations / FX. Sum equals EST_TRIS.
Body: 160 tris; Decorations: 20 tris; FX: 20 tris. Total: 200 tris.

### 3. Geometry construction — mbCylinder + mbSphere + extrusions sketch. 2–4 sentences.
The kelp strand is built using a tapered `mbCylinder` for the main body, with a `mbSphere` at the tip to represent the glowing bioluminescent cap. The body is extruded with a few side branches using a fan-of-triangles method, and the tip sphere is subdivided into 8-sided geometry for softness. The base is slightly offset to give a natural anchor point to the seabed.

### 4. Body palette — 3–4 specific Isles palette names + which surfaces they cover.
The main body uses `kelp_green` (primary), `water_shallow` (base), `sand_wet` (subsurface), and `beach_dune` (edge). These colors blend to simulate a kelp strand growing from a muddy ocean floor.

### 5. uBase marker assignments per surface — table: surface → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| Surface         | uBase |
|-----------------|-------|
| Main body       | 55    |
| Tip (glow)      | 53    |
| Base (mud)      | 55    |
| Branches        | 0     |

### 6. Base scale (scale_min, scale_max) — float range. Justify briefly.
Scale range: 0.8 to 1.2. This variation ensures the kelp strands appear as part of a natural, varied ecosystem while staying within the aesthetic of a tall, sway-animated flora.

### 7. Y rotation — random `0..2π` / aligned-to-bridge / aligned-to-shore-tangent / fixed N facings / aligned-to-island-radial. Pick one.
Random `0..2π` rotation to simulate natural drift and variation in placement.

### 8. Ground anchor — sits on island surface (y=island_y) / partially buried (specify) / floating in shallows (y=−0.4) / aerial (specify y) / on top of another mesh.
Partially buried at y = -0.2, anchoring into the wet sand and appearing to grow from the ocean floor.

### 9. Procedural variation method — 2 instances differ by what? (palette hash, scale spread, sub-mesh subset, etc.)
Instances vary in scale and tip color via palette hash, and branch count is randomized with a 30% chance to include 1–2 small side branches.

### 10. Spawn placement rules — which island(s) — specify which of A,B,C,D,E,F (per ISLAND_BIAS), spawn radius within that island, biome-zone (beach edge / cliff face / inland / temple plaza / boundary ring), avoid-list.
Spawn on islands C, E, A only (ISLAND_BIAS). Radius: 20–80m from island center. Zone: inland. Avoid-list: any other kelp, coral, or floating debris.

### 11. Spawn count rationale — why is `est_count = 100` correct given the 900 m radius and ISLAND_BIAS.
At 100 instances over a 900m radius with 3 islands (C, E, A), this gives a density of ~0.04 instances per square meter, which is sparse enough to avoid visual clutter while maintaining a natural, organic feel.

### 12. Clustering pattern — lone / paired / loose-trio / dense-cluster / scattered-grid.
Scattered-grid pattern with a 5m minimum spacing to avoid clumping, creating a sense of natural drift and dispersion.

### 13. Inter-asset spacing minimum (m) — min distance to another instance of the same mesh.
Minimum 5 meters between instances.

### 14. Path-clearance distance (m) — how close to the ISLAND-LOCAL path can it spawn? (Bridges = 0; otherwise typically 5–8 m.)
8 meters from any island-local path or bridge.

### 15. Team color reasoning — why TEAM=64; what palette swatch does it resolve to in the `game_fill_draws` switch?
TEAM=64 is chosen to group this with bioluminescent flora for easy rendering and collision logic. It resolves to `accent_coral` in `game_fill_draws` for visual consistency.

### 16. Shadow / contact AO strategy — casts shadow? Ground AO blob? Vertex-AO?
Casts a soft shadow with a small ground AO blob to simulate the kelp’s contact with the seabed.

### 17. Distant-LOD strategy — at what distance does it disappear / simplify? (Forest does no LOD; note if this asset matches.)
This asset follows forest’s no-LOD strategy, remaining fully detailed up to the edge of the visible zone.

### 18. Animation, if any — most static (state "static, no animation"). If animated, frequency + axis + amplitude.
Static, no animation. Sway is handled by the world’s global sway system.

### 19. Particle FX bound to entity — none for most. If used, name an existing emitter (`forest_motes`, `embers`, `fireflies`) or new (`drip_seafoam`, `kelp_motes`, `lantern_glow`, `pyre_sparks`).
A subtle `kelp_motes` emitter is bound to the tip, producing small glowing particles that float upward.

### 20. Lighting interaction — sun-side warm tint / mist-side cool tint description.
Sun-facing surfaces appear with a warm, slightly amber tint; mist-side surfaces are cooler, with a bluish hue.

### 21. Collision — does it block player movement? Set `world.radius` accordingly (forest rock=0.4, tower=1.5).
Does not block movement. `world.radius` = 0.3.

### 22. Destructible — yes/no. If yes, briefly describe break behaviour. Default no.
No — it is a static flora element.

### 23. Lore hook — one sentence in-world flavour.
The kelp strands are said to be the roots of the ancient coral gardens, still pulsing with the memory of the sea’s first light.

### 24. Surface UV layout — which uBase covers which sub-surface. Reference §5 above explicitly.
Main body uses uBase 55, tip uses uBase 53, base uses uBase 55, and branches use uBase 0 (default).

### 25. Material specularity — matte / soft-glossy / glossy / refractive / emissive-additive.
Soft-glossy with emissive-additive tip for the glowing effect.

### 26. Day/night appearance shift — sun-side warm tint / shadow-side cool tint description (1 sentence).
During the day, the kelp glows more subtly with a warm green tint; at night, the glow becomes more intense and radiant.

### 27. Silhouette test at 50 m — does it still read at half the average view distance?
Yes, the silhouette is still clearly distinguishable at 50 meters, maintaining contrast with the surrounding mist and ocean.

### 28. Visual neighbours — what other isles assets does this look RIGHT next to (composes a scene)?
It looks best next to `biolum_coral_reef`, `forest_seaweed`, and `water_foam`.

### 29. Visual conflicts — what should NOT be near it (would overcrowd or clash silhouette).
It should not be placed near other tall, glowing flora or large floating debris to avoid silhouette confusion.

### 30. Implementation hooks — exact file edits: which case to add to `world.team` switch in `src/main.zig`, which `make<X>(device:)` function to add in `ios/Mesh.swift`, which dispatch case to add in `ios/GameViewController.swift`.
- `src/main.zig`: Add `case 64 { ... }` for biolum team logic.
- `ios/Mesh.swift`: Add `func makeKelpStrand(device: MTLDevice) -> [MTLBuffer]`.
- `ios/GameViewController.swift`: Add `case 109: makeKelpStrand(device:)` in the mesh dispatch switch.
---

## Asset 110 — lantern_jelly_pile
1. **Silhouette at 30m** — A soft, rounded mound of glowing jelly, faintly luminous against the island’s sandy backdrop, its shape evokes a cluster of floating lanterns suspended just above the ground.

2. **Tri-budget breakdown** — Body: 130 tris, Decorations: 30 tris, FX: 20 tris. Total: 180 tris.

3. **Geometry construction** — The base is a `mbSphere` with a radius of 1.2m, representing the main jelly mass. Two `mbCylinder` extrusions are placed on top: one tapering from 0.4m to 0.1m, and another from 0.6m to 0.2m, both aligned vertically and slightly offset to suggest organic growth. The surface is broken into 3 distinct zones: base, top ring, and extrusions, each with unique UV mapping and color variation.

4. **Body palette** — The main body uses `kelp_green`, `sail_cream`, and `accent_pearl` to simulate a soft, translucent jelly with a subtle bioluminescent sheen. The top ring uses `mist_low` and `ember_lantern` for a glowing rim effect.

5. **uBase marker assignments per surface** —  
| Surface         | uBase |
|----------------|-------|
| Base Sphere     | 53    |
| Top Cylinder    | 54    |
| Ring Cylinder   | 55    |
| FX Emissive     | 8     |
| Default         | 0     |

6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.2. This allows for subtle variation in appearance while maintaining consistent clustering and readability at distance.

7. **Y rotation** — Random `0..2π`. The orientation is randomized to avoid repetitive alignment and blend into natural island growth.

8. **Ground anchor** — Sits on island surface (y=island_y) with 10% of instances partially buried (0.1–0.2m) to suggest a natural settling.

9. **Procedural variation method** — Instances vary by palette hash (color variation) and scale spread (0.8–1.2) to reduce visual repetition.

10. **Spawn placement rules — which island(s)** — Spawns on islands C and E. Island C: radius 100–150m from island center; biome-zone: beach edge. Island E: radius 60–100m; biome-zone: plaza floor. Avoid-list: temple structures, high-traffic bridge zones.

11. **Spawn count rationale** — With 80 instances across a 900m radius, 80 instances create a natural, non-overwhelming density. The sparse distribution allows for scenic viewing and avoids overcrowding island zones.

12. **Clustering pattern** — Dense-cluster. Clusters of 3–5 instances are grouped in soft formations, mimicking natural accumulation.

13. **Inter-asset spacing minimum (m)** — Minimum 1.5m from another instance of the same mesh to prevent visual clutter.

14. **Path-clearance distance (m)** — 6m from the island-local path. This allows for natural walking flow while keeping the asset visible.

15. **Team color reasoning** — TEAM=63 maps to a soft bioluminescent green, aligned with the `kelp_green` palette, making it visually consistent with other glowing flora in the Drifting Isles.

16. **Shadow / contact AO strategy** — Casts a soft shadow with a ground AO blob to simulate a subtle glow and interaction with the sandy terrain.

17. **Distant-LOD strategy** — Does not use LOD; forest assets do not implement distant simplification, so this asset remains fully detailed across all distances.

18. **Animation, if any** — Static, no animation. The jelly remains still to allow for ambient lighting and glow effects to be most visible.

19. **Particle FX bound to entity** — Emitter: `lantern_glow`. A soft, pulsing light effect that mimics the glow of a lantern, centered on the top ring.

20. **Lighting interaction** — Sun-side glows with a warm `ember_lantern` tint, while shadow-side takes on a cool `mist_low` tone, enhancing the organic, glowing appearance.

21. **Collision** — Does not block player movement. `world.radius` set to 0.3 for small, non-blocking presence.

22. **Destructible** — No. The asset is static and non-destructible.

23. **Lore hook** — These jelly remnants are said to be left by the ancient sea spirits who once tended the lanterns of the skywatch.

24. **Surface UV layout** — Base sphere uses uBase 53, top cylinder uBase 54, ring cylinder uBase 55, and emissive FX uses uBase 8. Default color uses uBase 0.

25. **Material specularity** — Soft-glossy. The surface has a slight sheen to mimic the translucency of jelly, not fully reflective.

26. **Day/night appearance shift** — During the day, the surface takes on a warm, soft `sail_cream` tone with a slight glow. At night, the glow intensifies with a `mist_low` shadow and `ember_lantern` highlight.

27. **Silhouette test at 50 m** — Yes, the shape still reads clearly at 50m, maintaining a soft, rounded silhouette with a glowing edge.

28. **Visual neighbours** — Looks right next to `kelp_pile`, `sea_coral_cluster`, and `driftwood_log` on island C. Complements the oceanic aesthetic of the Drifting Isles.

29. **Visual conflicts** — Should not appear near `stone_tower`, `bridge_support`, or `portal_entrance`, as these would dominate the visual field and clash with the soft glow.

30. **Implementation hooks** —  
- In `src/main.zig`: Add `case 63: return .lantern_jelly_pile` to `world.team` switch.  
- In `ios/Mesh.swift`: Add `makeLanternJellyPile(device:)` function.  
- In `ios/GameViewController.swift`: Add dispatch case for `lantern_jelly_pile` in `spawnInstance` logic.
---

## Asset 111 — glow_pearl_cluster
### 1. Silhouette at 30m
From across the lagoon, the cluster appears as a gentle half-shell of glowing orbs, subtly outlined against the sky, with a soft ambient glow that pulses in rhythm with the tide.

### 2. Tri-budget breakdown
Body: 120 tris; Decorations: 25 tris; FX: 15 tris.

### 3. Geometry construction
The core geometry is built using a half-sphere mesh (`mbSphere`) for the shell structure, with a tapered cylinder (`mbCylinder`) extruded from the base to form a gentle stem. Decorative protrusions are added as smaller spheres (`mbSphere`) with varying radii and slight offsets to simulate irregular pearl growth. The mesh is constructed in a static layout, with no dynamic deformations.

### 4. Body palette
Uses `accent_pearl` for the main body, `kelp_green` for the stem base, `water_shallow` for the ambient glow, and `mist_low` for the inner shell glow.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Body          | 61    |
| Stem          | 8     |
| Glow shell    | 61    |
| Inner core    | 0     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. Justification: allows for natural variation in pearl size while maintaining visual cohesion in clusters.

### 7. Y rotation
Random `0..2π`.

### 8. Ground anchor
Partially buried (y = -0.3) to simulate it resting on the sandy seabed.

### 9. Procedural variation method
Instances vary by palette hash (using a fixed seed based on position) and scale spread.

### 10. Spawn placement rules — which island(s)
Spawn on islands C and E. Island C: radius 170m, biome-zone = beach edge; Island E: radius 140m, biome-zone = boundary ring. Avoid-list: nearby `glow_pearl_cluster`, `firefly_cluster`, `kelp_tendril`.

### 11. Spawn count rationale
With a 900m radius and two islands (C and E) with 60 instances each, this gives an average density of 1 cluster per 150m², which is appropriate for a bioluminescent flora cluster.

### 12. Clustering pattern
Scattered-grid, with 2–3 clusters per 100m² in a loose pattern.

### 13. Inter-asset spacing minimum (m)
Minimum 10m from another instance.

### 14. Path-clearance distance (m)
8m from the ISLAND-LOCAL path (bridges = 0).

### 15. Team color reasoning
TEAM=65 maps to `accent_pearl` in the `game_fill_draws` switch, ensuring consistent visual alignment with the bioluminescent palette.

### 16. Shadow / contact AO strategy
Casts a soft shadow. Ground AO blob is used for subtle contact shading at base.

### 17. Distant-LOD strategy
No LOD — asset is not simplified at distance. Matches forest asset strategy.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side is tinted with a warm, golden hue; shadow-side is cool and slightly desaturated.

### 21. Collision
Does not block movement. `world.radius` = 0.3.

### 22. Destructible
No.

### 23. Lore hook
Ancient sailors say these pearls were once part of the Skywatch’s lantern, now scattered into the deep.

### 24. Surface UV layout
`uBase 61` covers the main body and inner shell; `uBase 8` covers the stem; `uBase 0` covers the inner core.

### 25. Material specularity
Emissive-additive.

### 26. Day/night appearance shift
Sun-side is warm and bright; night-side is cooler with a subtle blue tint.

### 27. Silhouette test at 50 m
Yes, it remains clearly distinguishable as a glowing cluster of half-spheres.

### 28. Visual neighbours
Looks right next to `kelp_tendril`, `sea_coral`, and `driftwood_grey`.

### 29. Visual conflicts
Should not be placed near `firefly_cluster`, `glow_sand`, or `ember_lantern` — these would visually clash.

### 30. Implementation hooks
- Add case `65` to `world.team` switch in `src/main.zig`.
- Add `makeGlowPearlCluster(device:)` to `ios/Mesh.swift`.
- Add dispatch case `case 111:` to `ios/GameViewController.swift` for spawning.
---

## Asset 112 — lit_shellfish_pile
### 1. Silhouette at 30m
From across the lagoon, the lit_shellfish_pile appears as a soft, irregular cluster of rounded oyster-like shells, gently glowing in warm amber hues against the deep ocean backdrop.

### 2. Tri-budget breakdown
The 180-triangle mesh is composed of 120 body triangles, 40 decoration triangles, and 20 FX triangles for emissive glow.

### 3. Geometry construction
The base geometry consists of a mbSphere for the central cluster of shells, surrounded by mbCylinder extrusions that form the shell-like edges. Additional fan-of-triangles are used to create the protruding “spikes” on each shell, and a few stacked plates are used to add texture to the inner surface.

### 4. Body palette
The body uses sand_wet for the base shell surface, kelp_green for the inner cavity, driftwood_grey for the outer rim, and accent_pearl for the glowing emissive areas.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Base shell     | 49    |
| Inner cavity   | 53    |
| Outer rim      | 49    |
| Emissive glow  | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This allows for visual variation without losing the cohesive cluster look at any zoom level.

### 7. Y rotation
Random `0..2π` rotation to give a natural scattered appearance across the island.

### 8. Ground anchor
Partially buried, sitting on the island surface with y = island_y - 0.2 to simulate a shell that has settled into the sand.

### 9. Procedural variation method
Variation is achieved through palette hash, which determines the base color and emissive tint per instance.

### 10. Spawn placement rules — which island(s)
Spawns on islands C and F only. Island C: radius 20–40m from center. Island F: radius 30–60m from center. Biome zone: beach edge. Avoid-list: none.

### 11. Spawn count rationale
With a 900m radius and 80 instances, the density is 0.01 instances per square meter, which is appropriate for a scattered, rare bioluminescent element that doesn't overwhelm the environment.

### 12. Clustering pattern
Scattered-grid pattern to simulate natural drift and uneven settling of shells on the shoreline.

### 13. Inter-asset spacing minimum (m)
Minimum 3.5 meters between instances of the same mesh.

### 14. Path-clearance distance (m)
8 meters from the ISLAND-LOCAL path, as it's a beach-edge element and not near bridges.

### 15. Team color reasoning
TEAM=65 maps to the accent_coral swatch, a warm, subtle red-orange that blends with the glowing shells and fits the bioluminescent theme.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob to enhance the sense of partial burial in sand.

### 17. Distant-LOD strategy
No LOD applied. The asset remains at full resolution up to 200m, as it’s a key visual element in the biolum zone.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None. The emissive glow is entirely static and shader-driven.

### 20. Lighting interaction
Sun-side shells glow with a warm amber tint; shadow-side takes on a cooler, slightly blue hue, emphasizing the bioluminescent effect.

### 21. Collision
Does not block movement. `world.radius` set to 0.3 to allow player to walk through it without obstruction.

### 22. Destructible
No. It is a static environmental element with no break behavior.

### 23. Lore hook
The shells are believed to be the remnants of ancient sea-creatures that once lived in the deeper waters of the Drifting Isles.

### 24. Surface UV layout
uBase 49 covers the base shell surface, uBase 53 covers the inner cavity, uBase 49 again covers the outer rim, and uBase 8 covers the emissive glow area.

### 25. Material specularity
Emissive-additive with soft-glossy surface for the shell base and matte for the cavity.

### 26. Day/night appearance shift
During the day, the shells appear warm and slightly glossy; at night, the emissive glow becomes more prominent, blending into the sky's ambient tones.

### 27. Silhouette test at 50 m
Yes, the silhouette remains recognizable at 50m, with a soft, glowing edge that distinguishes it from the surrounding terrain.

### 28. Visual neighbours
Looks right next to `kelp_tendril`, `driftwood_pile`, and `seafoam_bubble`.

### 29. Visual conflicts
Should not spawn near `sea_moth_cluster`, `firefly_burst`, or `pyre_spark`, as these elements can compete visually in the same lighting context.

### 30. Implementation hooks
- `src/main.zig`: Add `case 65` to `world.team` switch with `lit_shellfish_pile`.
- `ios/Mesh.swift`: Add `makeLitShellfishPile(device:)` function.
- `ios/GameViewController.swift`: Add dispatch case for `lit_shellfish_pile` in `spawnAsset(_:)`.
---

## Asset 113 — drift_kelp_thick
### 1. Silhouette at 30m — one sentence describing the shape from across the lagoon.
From 30 meters away, the kelp cluster appears as a dense, undulating curtain of green tendrils, slightly swaying in the breeze, with a diffuse, organic form that merges into the shoreline’s edge.

### 2. Tri-budget breakdown — body / decorations / FX. Sum equals EST_TRIS.
Body: 200 tris, Decorations: 20 tris, FX: 20 tris. Total: 240 tris.

### 3. Geometry construction — mbCylinder + mbSphere + extrusions sketch. 2–4 sentences. No Swift code.
The kelp structure is built using a central mbCylinder for the main stem, with tapering segments that reduce in radius to simulate natural thinning. mbSphere components are added at the tips to form rounded, bulbous nodes. Extruded rings are used to simulate the thickness of the kelp strand, with each ring subtly offset to create a twisting, flowing effect. Additional fan-of-triangle decorations are placed near the base to suggest branching.

### 4. Body palette — 3–4 specific Isles palette names + which surfaces they cover.
- kelp_green (main body)
- water_deep (base and submerged areas)
- sand_wet (base contact zone)
- driftwood_grey (attached driftwood elements)

### 5. uBase marker assignments per surface — table: surface → uBase.
| Surface         | uBase |
|-----------------|-------|
| Main body       | 55    |
| Base            | 56    |
| Nodes           | 57    |
| Driftwood       | 58    |
| FX (emissive)   | 8     |

### 6. Base scale (scale_min, scale_max) — float range. Justify briefly.
Scale range: 0.8 to 1.2. This ensures natural variation in the kelp strands while maintaining consistent visual density across the zone.

### 7. Y rotation — random `0..2π` / aligned-to-bridge / aligned-to-shore-tangent / fixed N facings / aligned-to-island-radial. Pick one.
Random `0..2π` — provides natural swaying and avoids gridlike uniformity.

### 8. Ground anchor — sits on island surface (y=island_y) / partially buried (specify) / floating in shallows (y=−0.4) / aerial (specify y) / on top of another mesh.
Partially buried — y = -0.2 to -0.4, simulating kelp rooted in shallow sand.

### 9. Procedural variation method — 2 instances differ by what? (palette hash, scale spread, sub-mesh subset, etc.)
Scale variation and palette hash (based on instance position) to ensure no two kelp strands look identical.

### 10. Spawn placement rules — which island(s) — specify which of A,B,C,D,E,F (per ISLAND_BIAS), spawn radius within that island, biome-zone (beach edge / cliff face / inland / temple plaza / boundary ring), avoid-list.
Islands: A, B, C, D, F. Spawn radius: 30–60m within each island. Biome-zone: beach edge, boundary ring. Avoid-list: temple plaza, cliff face.

### 11. Spawn count rationale — why is `est_count = 220` correct given the 900 m radius and ISLAND_BIAS.
With 5 islands and a 900m radius, 220 instances are sufficient to create a dense, immersive kelp presence without overloading the zone or causing performance issues.

### 12. Clustering pattern — lone / paired / loose-trio / dense-cluster / scattered-grid.
Dense-cluster — kelp strands grouped in clumps of 3–5, mimicking natural growth patterns.

### 13. Inter-asset spacing minimum (m) — min distance to another instance of the same mesh.
Minimum spacing: 1.5 meters — avoids visual clumping and allows natural drift.

### 14. Path-clearance distance (m) — how close to the ISLAND-LOCAL path can it spawn? (Bridges = 0; otherwise typically 5–8 m.)
Path-clearance: 6 meters — maintains safe player movement.

### 15. Team color reasoning — why TEAM=64; what palette swatch does it resolve to in the `game_fill_draws` switch?
TEAM=64 resolves to kelp_green in the `game_fill_draws` switch — a color that integrates naturally with the underwater and coastal palette, while maintaining a distinct identity in the team switch.

### 16. Shadow / contact AO strategy — casts shadow? Ground AO blob? Vertex-AO?
Casts shadow. Uses vertex-AO to simulate contact with the sand or water.

### 17. Distant-LOD strategy — at what distance does it disappear / simplify? (Forest does no LOD; note if this asset matches.)
No LOD — like forest assets, this remains full detail to preserve visual coherence at all distances.

### 18. Animation, if any — most static (state "static, no animation"). If animated, frequency + axis + amplitude.
Static, no animation — kelp strands remain fixed, relying on environment-based motion.

### 19. Particle FX bound to entity — none for most. If used, name an existing emitter (`forest_motes`, `embers`, `fireflies`) or new (`drip_seafoam`, `kelp_motes`, `lantern_glow`, `pyre_sparks`).
`kelp_motes` — subtle floating particles at the base for realism.

### 20. Lighting interaction — sun-side warm tint / mist-side cool tint description.
Sun-side: warm kelp_green with slight yellow tint; mist-side: cool blue-green, simulating light filtering through water.

### 21. Collision — does it block player movement? Set `world.radius` accordingly (forest rock=0.4, tower=1.5).
Does not block movement. `world.radius = 0.2` — low collision, allowing passage through kelp.

### 22. Destructible — yes/no. If yes, briefly describe break behaviour. Default no.
No — remains static and non-destructible to maintain environmental integrity.

### 23. Lore hook — one sentence in-world flavour.
The thick kelp strands are said to be the remains of an ancient sea-god's hair, now anchored to the drifting islands.

### 24. Surface UV layout — which uBase covers which sub-surface. Reference §5 above explicitly.
uBase 55: main body; uBase 56: base contact area; uBase 57: nodes; uBase 58: driftwood; uBase 8: emissive FX.

### 25. Material specularity — matte / soft-glossy / glossy / refractive / emissive-additive.
Soft-glossy — mimics the natural sheen of wet kelp.

### 26. Day/night appearance shift — sun-side warm tint / shadow-side cool tint description (1 sentence).
Sun-side: warm green; shadow-side: cooler, blue-green, simulating underwater lighting.

### 27. Silhouette test at 50 m — does it still read at half the average view distance?
Yes — the silhouette remains recognizable as a cluster of swaying green tendrils even at 50 meters.

### 28. Visual neighbours — what other isles assets does this look RIGHT next to (composes a scene)?
Looks right next to `drift_rock`, `beach_sand`, and `floating_coral`.

### 29. Visual conflicts — what should NOT be near it (would overcrowd or clash silhouette).
Should not spawn near `drift_tower`, `floating_glow`, or other dense structures — would visually clutter the scene.

### 30. Implementation hooks — exact file edits: which case to add to `world.team` switch in `src/main.zig`, which `make<X>(device:)` function to add in `ios/Mesh.swift`, which dispatch case to add in `ios/GameViewController.swift`.
- `src/main.zig`: Add case `64 => kelp_thick` in `world.team` switch.
- `ios/Mesh.swift`: Add `func makeDriftKelpThick(device: MTLDevice) -> MeshBuffers`.
- `ios/GameViewController.swift`: Add dispatch case `case 64: makeDriftKelpThick(device: device)` in `spawnMesh(for:)`.
---

## Asset 114 — drift_kelp_thin
### 1. Silhouette at 30m
From across the lagoon, the kelp strands appear as delicate, flowing lines that sway gently in the wind, resembling thin, translucent ribbons suspended in the shallow water.

### 2. Tri-budget breakdown
Body: 160 tris; Decorations: 15 tris; FX: 5 tris. Total: 180 tris.

### 3. Geometry construction
The kelp body is built using `mbCylinder` with a taper from base to tip, forming a thin, tapered shaft. At the base, a small `mbSphere` is added for root-like attachment. Additional extrusions along the shaft simulate frond-like extensions. The geometry is built with a fan of triangles for the top of the fronds, and the entire structure is stacked vertically to simulate the effect of a single strand.

### 4. Body palette
The primary color is kelp_green (0.18, 0.42, 0.30), with secondary accents of water_shallow (0.30, 0.60, 0.75) for shallow water highlights and driftwood_grey (0.45, 0.42, 0.38) for shadowed root sections. The tip uses accent_coral (0.92, 0.50, 0.42) to suggest a subtle glow.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Base root     | 55    |
| Main shaft    | 56    |
| Frond tips    | 57    |
| Water highlights | 58  |
| Emissive tip  | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.6 to 1.2. The variation accounts for natural growth variance in sparse kelp, with smaller specimens in shallower waters and taller, thinner forms in deeper zones.

### 7. Y rotation
Random `0..2π` — each instance is independently rotated for natural variation and avoids repetitive alignment.

### 8. Ground anchor
Partially buried; the base is placed at y = -0.2 to simulate kelp rooted in sand with the main shaft rising above.

### 9. Procedural variation method
Instances vary by palette hash (color variation based on position), scale spread (0.6 to 1.2), and a random subset of frond extensions (0–3 extra branches).

### 10. Spawn placement rules — which island(s)
Spawn on islands A, B, C, D, and F. Radius within each island: 100–150m. Zone: beach edge. Avoid-list: none.

### 11. Spawn count rationale
With 240 instances across 5 islands, and a total radius of 900m, the density ensures sparse yet continuous coverage, matching the thin kelp biome’s visual theme.

### 12. Clustering pattern
Scattered-grid — instances are spaced evenly across island zones, avoiding clustering while maintaining a natural feel.

### 13. Inter-asset spacing minimum (m)
Minimum 1.5m spacing to prevent visual overlap or clumping.

### 14. Path-clearance distance (m)
8m clearance from any island-local path to avoid obstructing player movement.

### 15. Team color reasoning
TEAM=64 maps to kelp_green in `game_fill_draws` switch, ensuring consistent visual grouping with the biome’s color palette and alignment with the forest kelp group.

### 16. Shadow / contact AO strategy
Casts a soft shadow. Ground AO blob is used to simulate contact with sand or shallow seabed.

### 17. Distant-LOD strategy
No LOD — this asset is part of a sparse biome and is expected to remain visible at all distances like other forest elements.

### 18. Animation, if any
Static, no animation. No motion is applied to simulate a passive, unanimated kelp strand.

### 19. Particle FX bound to entity
None. No particle FX is bound to this asset.

### 20. Lighting interaction
Sun-side appears warm with a kelp-green tint, while shadow-side takes on a cool, blue-green hue, enhancing depth and realism in light transitions.

### 21. Collision
Does not block movement. `world.radius` set to 0.1 to allow player traversal through.

### 22. Destructible
No. This asset is not designed for destruction.

### 23. Lore hook
These kelp strands are remnants of a forgotten tide pool, now drifting in the shallows, a relic of a lost island culture.

### 24. Surface UV layout
uBase 55 covers root; 56 covers main shaft; 57 covers fronds; 58 covers water highlights; 8 covers emissive tip.

### 25. Material specularity
Soft-glossy — slight reflection to simulate wet kelp and shallow water contact.

### 26. Day/night appearance shift
Sun-side appears warm and vibrant with a green tint, while shadow-side takes on a cooler, deeper blue-green tone.

### 27. Silhouette test at 50 m
Yes, the kelp strands still read clearly at 50m, maintaining a defined and recognizable silhouette.

### 28. Visual neighbours
Looks best next to sand_dune, driftwood_grey, and water_shallow elements. Complements beach and island edge assets.

### 29. Visual conflicts
Should not appear near dense clusters of forest trees or large rock formations that would obscure or visually compete with its slender form.

### 30. Implementation hooks
- Add case `case 64:` to `world.team` switch in `src/main.zig`
- Add `makeDriftKelpThin(device:)` to `ios/Mesh.swift`
- Add dispatch case in `ios/GameViewController.swift` for `drift_kelp_thin` instances
---

## Asset 115 — kelp_root_anchor
### 1. Silhouette at 30m
From across the lagoon, the kelp_root_anchor appears as a thick, sinuous root bundle rising from the seabed, its silhouette defined by the interplay of thick tendons and branching points, evoking both anchoring strength and oceanic serenity.

### 2. Tri-budget breakdown
Body: 150 tris; Decorations: 30 tris; FX: 20 tris. Total: 200 tris.

### 3. Geometry construction
The root anchor is built using a base mbCylinder to represent the main root shaft, tapering from a thick base (radius 1.2m) to a thinner tip (0.4m). It is topped with an mbSphere for a root bulb, and several extruded rings (mbCylinder with small radii) are added to simulate root branches and surface textures. The mesh is constructed as a static cluster, combining these elements into a single mesh with minimal topology variation.

### 4. Body palette
The main root body uses kelp_green (0.18, 0.42, 0.30) for a deep oceanic tone, with sand_wet (0.62, 0.55, 0.42) for the anchor base and driftwood_grey (0.45, 0.42, 0.38) for subtle branch textures. Accent colors include accent_pearl (0.95, 0.92, 0.85) to highlight the root tips.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|--------|
| Root shaft    | 55     |
| Root bulb     | 56     |
| Branch tips   | 55     |
| Anchor base   | 56     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. Justification: A natural variation ensures that the root anchors appear both anchored and organic, mimicking the range of growth and environmental pressures in the ocean floor.

### 7. Y rotation
Random `0..2π`. The root anchor rotates freely to avoid repetitive alignment and to reflect the natural chaos of ocean floor terrain.

### 8. Ground anchor
Partially buried (y = -0.4). The root anchor sits partially below the island surface to simulate a deep, anchoring root system that holds the kelp to the seabed.

### 9. Procedural variation method
Variation occurs through scale spread and slight palette shifts using a hash of the root's world position to vary the kelp_green to a slightly more mossy or sand-tinted green.

### 10. Spawn placement rules — which island(s)
Spawn on islands A, B, C, D, F. Radius within island: 30–60m from island center. Biome-zone: beach edge or shallow seabed. Avoid-list: temple plaza, cliff face, boundary ring.

### 11. Spawn count rationale
With 200 instances across a 900m radius zone, the density supports both natural distribution and a visually consistent ocean floor presence. This ensures kelp root anchors appear abundant enough to support a rich underwater ecosystem without overcrowding.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to avoid clustering but not too far, to support the illusion of natural anchoring.

### 13. Inter-asset spacing minimum (m)
Minimum 5m from another kelp_root_anchor. Prevents visual clumping and maintains a natural spread.

### 14. Path-clearance distance (m)
8m from ISLAND-LOCAL path. Bridges and walkways are cleared, but other paths are avoided to maintain navigability.

### 15. Team color reasoning
TEAM=64 chosen to distinguish root anchors from other kelp assets (TEAM=65) and align with the forest team switch, using the kelp_green palette swatch to ensure a consistent color match in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob to simulate the root’s contact with the seabed. Vertex-AO is not used to preserve clarity.

### 17. Distant-LOD strategy
No LOD. Like forest assets, it remains at full resolution even at long distances, ensuring its silhouette and texture remain legible.

### 18. Animation, if any
Static, no animation. The root is a fixed structure, not a moving organism.

### 19. Particle FX bound to entity
None. The root does not generate particle effects.

### 20. Lighting interaction
Sun-side warm tint (kelp_green with a slight amber shift) and mist-side cool tint (slightly blue-shifted), with subtle modulation using `fbm` to simulate oceanic light filtering.

### 21. Collision
Does not block player movement. Set `world.radius` to 0.5 to allow passage.

### 22. Destructible
No. The root is a static element that does not break or respond to damage.

### 23. Lore hook
The root anchor holds the great kelp forests down into the ocean’s depths, keeping them tethered to the seafloor in the face of the island’s drifting currents.

### 24. Surface UV layout
uBase 55 covers the root shaft and branch tips; uBase 56 covers the root bulb and anchor base, reflecting the surface material variation.

### 25. Material specularity
Soft-glossy. The root material has a low to moderate reflectivity, simulating the matte texture of oceanic vegetation.

### 26. Day/night appearance shift
Sun-side warm tint with a subtle amber hue; shadow-side cool tint with a slight blue tint, using `mix()` to blend the two based on lighting angle.

### 27. Silhouette test at 50 m
Yes, it still reads clearly at 50m. Its thick, branching silhouette remains distinct and recognizable.

### 28. Visual neighbours
Looks right next to kelp_tendril, kelp_bush, and reef_coral, forming a cohesive underwater ecosystem.

### 29. Visual conflicts
Should not spawn near kelp_fan or floating kelp_rafts, as they would visually compete for space and create silhouette confusion.

### 30. Implementation hooks
- In `src/main.zig`, add `case 64: return .kelp_root_anchor;` to the `world.team` switch.
- In `ios/Mesh.swift`, add `func makeKelpRootAnchor(device: MTLDevice) -> MeshBuffers` function.
- In `ios/GameViewController.swift`, add `case 115: return makeKelpRootAnchor(device: device)` to the dispatch switch.
---

## Asset 116 — sea_grass_tuft
```

### 1. Silhouette at 30m
From across the lagoon, the tuft appears as a fine, vertical filament with a slight taper, resembling a delicate underwater plant strand that softly sways in the current.

### 2. Tri-budget breakdown
Body: 100 tris. Decorations: 15 tris. FX: 5 tris. Total: 120 tris.

### 3. Geometry construction
The base is a tapered mbCylinder, representing the main stem, using a low ring count to maintain performance. A few mbSphere instances are stacked at the top to form a tufted cap. Extruded rings are added along the stem to simulate texture variations, and a fan of triangles is used for fine filaments extending from the base to mimic leafy strands.

### 4. Body palette
Kelp green covers the main stem; sand wet is used for the base where it touches the sand; foam white is applied to the tuft tips for a luminous effect; accent coral is used for subtle highlights.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Stem          | 55    |
| Tuft Cap      | 56    |
| Tip Highlight | 57    |
| Base Contact  | 58    |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.7 to 1.2. Justification: The tuft needs to vary slightly to avoid visual repetition and fit within the micro-scale of shallow beach environments.

### 7. Y rotation
Random `0..2π`. Rotation is fully randomized to prevent uniformity and naturalize the appearance in clusters.

### 8. Ground anchor
Partially buried, with 30% of the tuft’s height below the sand surface, mimicking how sea grass anchors into sand.

### 9. Procedural variation method
Instances vary by scale spread, and a hash of the position is used to select a palette variation, ensuring no two tufts look exactly alike.

### 10. Spawn placement rules — which island(s)
Spawn on islands A, B, C, D, F. Radius: 50–150m from island center. Biome-zone: inland sand. Avoid-list: bridges, temple plazas, cliff edges.

### 11. Spawn count rationale
With a 900m radius and 200 instances, each island receives roughly 40 instances, which is appropriate for a sparse but natural distribution across the sand zones.

### 12. Clustering pattern
Scattered-grid. Instances are placed in a loose grid pattern, avoiding strict alignment, to simulate natural growth.

### 13. Inter-asset spacing minimum (m)
Minimum spacing: 1.5 meters. Ensures no two tufts are too close, maintaining a natural look.

### 14. Path-clearance distance (m)
Path clearance: 5 meters. Tufts do not spawn within 5 meters of any island-local path to allow movement.

### 15. Team color reasoning
TEAM=64 is chosen to distinguish it from forest assets and align with the sea theme. It maps to kelp green in the `game_fill_draws` switch.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob to simulate sand contact. Vertex-AO is used for subtle depth.

### 17. Distant-LOD strategy
No LOD — the asset remains fully detailed at all distances, as forest assets do not implement LOD.

### 18. Animation, if any
Static, no animation. The tuft is rigid and does not sway or move.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset.

### 20. Lighting interaction
Sun-side appears warm and slightly tinted with kelp green; shadow-side cools to a muted sand tone with a slight blue tint.

### 21. Collision
Does not block player movement. `world.radius` set to 0.2 to allow passage through.

### 22. Destructible
No. The asset is not destructible.

### 23. Lore hook
A small tuft of sea grass clings to the sand near a sunken shipwreck, a remnant of the ocean's forgotten past.

### 24. Surface UV layout
uBase 55 covers the stem, 56 the tuft cap, 57 the tip highlights, and 58 the sand contact base, each mapped with distinct UV patterns.

### 25. Material specularity
Soft-glossy. Slight sheen on the tuft tips and a matte finish on the stem.

### 26. Day/night appearance shift
During the day, sun-side is warm and vivid; during night, shadow-side takes on a cooler, almost ethereal tone.

### 27. Silhouette test at 50 m
Yes, the tuft still reads clearly at 50 meters, maintaining its vertical and soft filament shape.

### 28. Visual neighbours
Looks best next to driftwood, sand dunes, and small kelp clumps, composing a cohesive underwater beach scene.

### 29. Visual conflicts
Should not appear near dense forest clusters or large rock formations, as this would overload the visual palette with competing textures.

### 30. Implementation hooks
- Zig: Add `case 64` in `world.team` switch in `src/main.zig`.
- Swift: Add `makeSeaGrassTuft(device:)` in `ios/Mesh.swift`.
- Swift: Add `case 116` in `dispatchMesh` in `ios/GameViewController.swift`.
```
---

## Asset 117 — sea_palm_tree
### 1. Silhouette at 30m
From across the lagoon, the sea palm tree presents a robust, short trunk with a dense cluster of fronds emerging from a central node, creating a strong vertical profile with slight tapering.

### 2. Tri-budget breakdown
Body: 240 tris; Decorations: 60 tris; FX: 20 tris.

### 3. Geometry construction
The trunk is built with a tapered `mbCylinder` of 3 rings and 12 sides, with a radius that decreases from base to top. The fronds are constructed as extruded fan-like `mbSphere` clusters with 4–6 segments, aligned radially from the trunk top. A small central node connects the fronds to the trunk via a few static plates.

### 4. Body palette
The trunk uses `driftwood_grey` for its base and `kelp_green` for the inner bark. Fronds use `kelp_green` and `sail_cream` for highlights. The node uses `accent_coral`.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|----------------|-------|
| Trunk base     | 0     |
| Trunk bark     | 55    |
| Fronds         | 0     |
| Node           | 8     |

### 6. Base scale (scale_min, scale_max)
0.7 to 1.3. This range allows for natural variation in size while maintaining the compact, stocky nature of the palm.

### 7. Y rotation
Random `0..2π`. No alignment to terrain or structures.

### 8. Ground anchor
Partially buried (y = -0.2), simulating root grip in shallow sand.

### 9. Procedural variation method
Variation is achieved through palette hash (surface color variation), scale spread, and minor frond count changes (4–6 fronds per instance).

### 10. Spawn placement rules — which island(s)
Spawns on islands A, D, F only. Radius within island: 10–40m. Zone: inland. Avoid-list: temple plaza, boundary ring, cliff face.

### 11. Spawn count rationale
With 100 instances over a 900m radius and ISLAND_BIAS of A, D, F, this density supports a natural spread across shallow coastal zones, matching the biome’s understory distribution.

### 12. Clustering pattern
Scattered-grid. Instances spaced 5–10m apart to avoid visual overcrowding.

### 13. Inter-asset spacing minimum (m)
6 meters minimum to other instances of the same mesh.

### 14. Path-clearance distance (m)
5 meters from ISLAND-LOCAL paths (bridges excluded).

### 15. Team color reasoning
TEAM=64 aligns with kelp and seaweed biomes, resolving to `kelp_green` in `game_fill_draws` switch, matching the ecosystem’s dominant color.

### 16. Shadow / contact AO strategy
Casts shadow using a ground AO blob. Vertex-AO is not used.

### 17. Distant-LOD strategy
No LOD. This asset behaves like forest mesh assets and does not simplify at distance.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side fronds take a warm `sail_cream` tint, while shadowed areas shift to a cooler `kelp_green` tone. Mist-side fronds adopt a soft blue-white hue.

### 21. Collision
Does not block movement. `world.radius` is set to 0.5.

### 22. Destructible
No. Default no.

### 23. Lore hook
The tree is a remnant of an ancient shipwreck, its roots now entwined with sea kelp and driftwood.

### 24. Surface UV layout
Trunk base uses uBase 0 for diffuse; trunk bark uses uBase 55 for texture variation; fronds use uBase 0; node uses uBase 8 for emissive glow.

### 25. Material specularity
Soft-glossy. Subtle sheen on fronds, matte on trunk.

### 26. Day/night appearance shift
During the day, sun-facing fronds warm to `sail_cream`. At night, they shift to a cooler `mist_low` hue with soft ambient glow.

### 27. Silhouette test at 50 m
Yes. The silhouette remains clear and recognizable at 50m, maintaining vertical profile and contrast.

### 28. Visual neighbours
Looks right next to `sea_kelp_cluster`, `driftwood_log`, and `shallow_rock`.

### 29. Visual conflicts
Should not appear near `tall_palm_tree`, `ocean_spires`, or `floating_coral`.

### 30. Implementation hooks
- `src/main.zig`: Add `case 64: return .sea_palm_tree` in `world.team` switch.
- `ios/Mesh.swift`: Add `func makeSeaPalmTree(device: MTLDevice) -> (verts: [Vertex], idxs: [UInt16])`.
- `ios/GameViewController.swift`: Add `case 117: dispatch_makeSeaPalmTree(device: device)` in mesh dispatch.
---

## Asset 118 — mangrove_tree
### 1. **Silhouette at 30m** — A mossy, thin mangrove tree with hanging roots appears as a delicate, vertical column with a subtle taper, extending downward from a narrow trunk and branching into hanging tendrils that catch the light like a curtain of green.

### 2. **Tri-budget breakdown** — Body: 300 tris; Decorations: 60 tris; FX: 20 tris.

### 3. **Geometry construction** — The trunk is built using `mbCylinder` with a slight taper from base to top, using a low ring count to keep tris down. Root tendrils are extruded from the base using a fan of triangles, each with a slight curve. A few `mbSphere` elements are added for root bulbs at the base and end of some tendrils. The overall shape uses stacked plates for foliage-like segments along the trunk to simulate moss accumulation.

### 4. **Body palette** — kelp_green, driftwood_grey, sand_wet, foam_white. The trunk uses kelp_green with driftwood_grey for root texture; base and bulbs are sand_wet; root tips are foam_white.

### 5. **uBase marker assignments per surface** — trunk → 0, root tendrils → 56, root bulbs → 0, foliage → 56.

### 6. **Base scale (scale_min, scale_max)** — 0.6 to 1.0. Slight variation to mimic natural growth in shallow waters without making the asset look too uniform.

### 7. **Y rotation** — random `0..2π`. Rotates freely to break visual monotony and match natural placement.

### 8. **Ground anchor** — Partially buried (y = -0.4). Root bulbs are embedded in the sand to simulate anchoring in shallow water.

### 9. **Procedural variation method** — Sub-mesh subset and color hash per instance. Tendrils vary in number and length, and color tint is derived from a hash of the instance ID.

### 10. **Spawn placement rules — which island(s)** — C, D. Within radius of 120m from island center. Spawn in inland edges (beach edge zones). Avoid-list: island paths, bridges, and temple plaza zones.

### 11. **Spawn count rationale** — 80 instances evenly spread across islands C and D, each with 120m spawn radius, gives a density of ~0.18 instances per 100m², matching the low density of inland mangrove zones and avoiding overcrowding in the forested areas.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed to avoid tight clustering, favoring a grid-like but randomized layout.

### 13. **Inter-asset spacing minimum (m)** — 2.5 meters. Ensures visual separation and avoids visual clutter.

### 14. **Path-clearance distance (m)** — 6 meters. Avoids paths and bridges, with a safe margin for player movement.

### 15. **Team color reasoning** — TEAM=66 corresponds to `kelp_green` (0.18, 0.42, 0.30) in `game_fill_draws`. This allows it to blend into the marine environment and distinguish from other vegetation types.

### 16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob for root contact with sand. Vertex-AO for softness around root tendrils.

### 17. **Distant-LOD strategy** — Forest does no LOD, so this asset remains static at all distances, preserving detail for its niche in shallow water.

### 18. **Animation, if any** — Static, no animation. Minimal movement to avoid distraction from gameplay.

### 19. **Particle FX bound to entity** — `kelp_motes` — subtle floating particles at the root tips to simulate sea foam and micro-bubbles.

### 20. **Lighting interaction** — Sun-side warm tint with slight green tinge from kelp green; mist-side cool tint with a bluish hue to reflect the water environment.

### 21. **Collision** — Does not block movement. `world.radius` set to 0.3 to allow player to walk through or around it without obstruction.

### 22. **Destructible** — No. Designed to be a static environmental asset for atmosphere.

### 23. **Lore hook** — The tree’s hanging roots are said to whisper secrets to those who listen closely to the lagoon’s tide.

### 24. **Surface UV layout** — trunk → 0; root tendrils → 56; root bulbs → 0; foliage → 56. UVs are mapped to reflect natural wear and mossy texture.

### 25. **Material specularity** — Soft-glossy. Reflects a bit of light to mimic the wetness of the kelp, but not overly shiny.

### 26. **Day/night appearance shift** — During day, sun-side appears warm and mossy-green; shadow-side cools to a deeper green-blue. At night, it shifts to a soft gray-blue.

### 27. **Silhouette test at 50 m** — Yes. The vertical taper and root structure remain distinct and readable at half the average view distance.

### 28. **Visual neighbours** — Looks right next to `driftwood_log`, `seaweed_cluster`, and `kelp_tendril`. Complements the underwater ecosystem.

### 29. **Visual conflicts** — Should not be near `jungle_tree`, `cave_rock`, or `tower`. These would overwhelm its silhouette or create visual clutter in shallow zones.

### 30. **Implementation hooks** — In `src/main.zig`, add case `66: return .mangrove_tree`. In `ios/Mesh.swift`, add `makeMangroveTree(device:)`. In `ios/GameViewController.swift`, add `case .mangrove_tree: self.mesh = self.makeMangroveTree(device: device)`.

```metal
float3 color = mix(kelp_green, driftwood_grey, smoothstep(0.0, 0.5, sin(uv.y * 10.0)));
```
---

## Asset 119 — mangrove_root_tangle
### 1. Silhouette at 30m
From across the lagoon, the mangrove root tangle appears as a dense, gnarled mass of twisted black tendrils and thick, segmented columns, blending into the shallow waterline with no clear dominant shape.

### 2. Tri-budget breakdown
Body: 220 tris. Decorations: 40 tris. FX: 20 tris. Total: 280 tris.

### 3. Geometry construction
The base geometry uses a series of mbCylinder calls to build thick, tapering root segments, some of which are connected via mbSphere nodes to form knots and bulbous swellings. Extrusions include small, irregularly placed branches and surface growths to simulate rootlets and clinging moss. The mesh is composed of stacked rings and fan triangles for surface detail.

### 4. Body palette
Uses kelp_green, driftwood_grey, sand_wet, and accent_coral. The kelp_green covers the main body and root columns; driftwood_grey accents the base and exposed knots; sand_wet appears on embedded surfaces where roots meet the muddy shore; accent_coral adds subtle warm highlights on root surfaces.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Root columns   | 0     |
| Knots          | 56    |
| Embedded       | 0     |
| Moss patches   | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.3. Justification: Variants should be large enough to feel substantial in shallow water, but not so large as to dominate the scene or block navigation.

### 7. Y rotation
Random `0..2π`. The mesh rotates freely to avoid uniform repetition and fit varied terrain.

### 8. Ground anchor
Partially buried, with 20% of its volume below the island surface, simulating root growth into the muck of the lagoon floor.

### 9. Procedural variation method
Two instances differ by scale spread and a palette hash that shifts the color tint of the root columns and moss patches slightly.

### 10. Spawn placement rules — which island(s)
Spawns on islands C and D only. Radius within island: 30–60 m. Biome-zone: beach edge and shallow inland. Avoid-list: temple plaza, boundary ring.

### 11. Spawn count rationale
With 100 instances over a 900 m radius, this ensures a dense yet varied root tangle in the shallow waters of C and D islands, with sufficient spacing to avoid visual overcrowding.

### 12. Clustering pattern
Dense-cluster. Roots are grouped in clumps of 3–5, with some isolated specimens for variety.

### 13. Inter-asset spacing minimum (m)
Minimum 3.5 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
8 meters from any ISLAND-LOCAL path. Bridges are exempt.

### 15. Team color reasoning
TEAM=66 is chosen to match the color palette of the kelp-green roots, allowing for easy visual identification of this biome type in the `game_fill_draws` switch. It resolves to kelp_green (0.18, 0.42, 0.30).

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob beneath. No vertex-AO is used due to the mesh’s complexity and density.

### 17. Distant-LOD strategy
No LOD applied. Forest assets do not use LOD; this asset will remain visible at all distances.

### 18. Animation, if any
Static, no animation. The roots are fixed in place, with no movement to avoid visual distraction.

### 19. Particle FX bound to entity
None. No FX attached to this asset.

### 20. Lighting interaction
Sun-side appears warm with a greenish tint; shadow-side appears cooler with a blue-gray hue.

### 21. Collision
Yes, it blocks player movement. `world.radius` set to 0.6.

### 22. Destructible
No. It is a static environmental mesh.

### 23. Lore hook
These tangled roots are the remains of a great mangrove forest that once thrived in the shallow lagoon, now partially submerged and overgrown with kelp and moss.

### 24. Surface UV layout
Root columns use uBase 0 for base texture mapping; knots use uBase 56 for variation; embedded surfaces use uBase 0 with slight color offset; moss patches use uBase 8 for emissive glow.

### 25. Material specularity
Soft-glossy. Slight sheen on root surfaces to simulate wetness, with no refractive properties.

### 26. Day/night appearance shift
Sun-side appears warmer with green tints; shadow-side cools to a bluish-gray, simulating the interplay of light and shadow in shallow water.

### 27. Silhouette test at 50 m
Yes, the silhouette remains recognizable at 50 meters, with clear root column and knot structure.

### 28. Visual neighbours
Looks right next to `sea_grass`, `driftwood`, `kelp_tendril`, and `sand_dune`.

### 29. Visual conflicts
Should not be placed near `coral_reef`, `stone_boulder`, or `shallow_kelp`, as these would visually clash with the root tangle’s organic, tangled silhouette.

### 30. Implementation hooks
- Add case `66` to `world.team` switch in `src/main.zig`.
- Add `makeMangroveRootTangle(device:)` function in `ios/Mesh.swift`.
- Add dispatch case for `mangrove_root_tangle` in `ios/GameViewController.swift`.
---

## Asset 120 — sea_lily_floater
### 1. Silhouette at 30m
From a distance of 30 meters, the sea lily floater appears as a large, floating disc with a soft, glowing center, barely distinguishable from the surrounding mist and shallow water.

### 2. Tri-budget breakdown
The mesh is composed of 100 tris for the main body, 30 tris for central glow and stem details, and 10 tris for subtle FX attachments, totaling exactly 140 tris.

### 3. Geometry construction
The main body is built with `mbCylinder` to form a flat, slightly tapered disc with a radius of 2.0m and a height of 0.3m, using a soft green hue. A `mbSphere` is added at the center to represent the central glow, with a radius of 0.4m. An extruded ring of 12 sides wraps around the outer edge of the disc to simulate a lily pad's edge, and a small stem extends downward using `mbCylinder` with a taper from 0.1m to 0.05m over a length of 0.8m.

### 4. Body palette
The disc surface uses `kelp_green` and `water_shallow` for a blend of oceanic tones. The stem and edge are tinted with `driftwood_grey` and `sand_wet`, and the central glow is rendered in `ember_lantern`.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|------------------|-------|
| Disc body        | 0     |
| Central glow     | 8     |
| Stem             | 53    |
| Edge ring        | 0     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This variation allows for natural visual diversity while keeping the floating lily pad within recognizable size bounds for its shallow-water biome.

### 7. Y rotation
Random rotation in the range `0..2π` to create a natural look across the lagoon.

### 8. Ground anchor
The floater floats at y = -0.4, partially submerged in the shallows, simulating a lily pad that hovers just above the mud.

### 9. Procedural variation method
Two instances differ in palette hash (randomly selects from the color swatches) and scale spread to ensure visual variety.

### 10. Spawn placement rules — which island(s)
Spawns are allowed only on islands C, E, and F. Island C (Glasstop) has a spawn radius of 60m, Island E (Skywatch) has a 30m radius, and Island F (Far Reach) has a 50m radius. Biome zone is beach edge or shallow water. Avoid-list includes high-density zones like temple plazas or bridge edges.

### 11. Spawn count rationale
With a 900m radius and a spawn count of 80, the density is approximately 1 floater per 1125 m², which is appropriate for a sparse, atmospheric flora element in the shallows.

### 12. Clustering pattern
Scattered-grid pattern with loose clustering to mimic natural growth and avoid over-saturation in any one area.

### 13. Inter-asset spacing minimum (m)
Minimum spacing is 5 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
It must spawn at least 6 meters from any ISLAND-LOCAL path to avoid obstructing movement.

### 15. Team color reasoning
TEAM=64 is chosen for its neutral, oceanic tone, allowing it to blend with the environment. It resolves to `kelp_green` in the `game_fill_draws` switch.

### 16. Shadow / contact AO strategy
It casts a soft, ground AO blob, with no hard shadow, to maintain the illusion of floating.

### 17. Distant-LOD strategy
No LOD is applied, matching the forest’s behavior — all assets render at full resolution regardless of distance.

### 18. Animation, if any
Static, no animation. The mesh remains motionless to reflect the stillness of lily pads on the water.

### 19. Particle FX bound to entity
None. The central glow is rendered directly in the material.

### 20. Lighting interaction
The sun-side is tinted with `kelp_green` and `sail_cream`, while the shadow-side uses a cooler `water_deep` and `mist_low`.

### 21. Collision
It does not block player movement. `world.radius` is set to 0.3 to allow passage.

### 22. Destructible
No. It is a passive environmental asset.

### 23. Lore hook
It is said that the sea lilies float where the old spirits once rested, their light guiding lost sailors to shore.

### 24. Surface UV layout
The disc body and edge use uBase 0. The central glow uses uBase 8. The stem uses uBase 53.

### 25. Material specularity
Soft-glossy, with a slight sheen to simulate the reflective quality of a lily pad on water.

### 26. Day/night appearance shift
During the day, the floater appears warm and vibrant, with `sail_cream` and `kelp_green` tints. At night, the glow softens to a `mist_low` and `sky_storm` blend.

### 27. Silhouette test at 50 m
Yes, it still reads clearly at 50 meters, maintaining its disc shape and central glow.

### 28. Visual neighbours
It looks right next to `kelp_tendril`, `driftwood_log`, and `shallow_rock`.

### 29. Visual conflicts
It should not be placed near `firefly_cluster`, `pyre_sparks`, or `lava_bubble`, as these would overpower its delicate silhouette.

### 30. Implementation hooks
- `src/main.zig`: Add case `64: sea_lily_floater` to `world.team` switch.
- `ios/Mesh.swift`: Add function `makeSeaLilyFloater(device:)` with mesh construction.
- `ios/GameViewController.swift`: Add dispatch case `case 120: makeSeaLilyFloater(device:)` in `makeMesh()`.

```metal
float3 base_color = mix(kelp_green, water_shallow, sin(time * 0.5));
float3 glow_color = mix(ember_lantern, mist_low, fbm(pos * 0.5) * 0.5);
```
---

## Asset 121 — whale_skull_giant
1. **Silhouette at 30m** — The whale skull giant presents a striking, curved silhouette against the horizon, its massive dome rising from the sand like a weathered mountain.

2. **Tri-budget breakdown** — The mesh is constructed with 700 tris for the main body, 250 tris for surface decorations (including embedded kelp and shell fragments), and 150 tris for subtle FX elements like foam and bio-luminescent patches.

3. **Geometry construction** — The main body uses a `mbCylinder` to form a roughly spherical skull with a tapering neck, then adds a `mbSphere` to create the eye sockets and a few internal chambers. Extrusions are used to model the tusks and embedded bones, with a fan of triangles for the ribcage and a static cluster for surface growths like kelp and driftwood.

4. **Body palette** — The primary surface uses `sand_wet` with `driftwood_grey` for embedded driftwood and `kelp_green` for algae growths. The exposed interior chambers are tinted `water_deep` and `foam_white` for contrast.

5. **uBase marker assignments per surface** — 
| Surface         | uBase |
|------------------|-------|
| Main skull       | 0     |
| Embedded driftwood | 63  |
| Kelp growths     | 56    |
| Interior chambers| 8     |

6. **Base scale (scale_min, scale_max)** — Scale range is 1.2 to 1.8. This provides visual variation without breaking the landmark nature of the asset, and allows for subtle differences in how it interacts with the terrain.

7. **Y rotation** — Aligned-to-island-radial, ensuring the skull faces the center of the island it's placed on, creating a natural focal point.

8. **Ground anchor** — Partially buried, with 20% of the structure sitting below the island surface, as if it were half-swallowed by the sand.

9. **Procedural variation method** — Two instances differ in palette hash, with one using a warmer sand tone and the other a cooler driftwood tone to create visual variety.

10. **Spawn placement rules — which island(s)** — Spawns on B (Whale's Spine) with a 30m radius, on F (Far Reach) with a 20m radius. Zone is beach edge, and it avoids spawning near `forest_boulder`, `tomb_stone`, and `skywatch_lantern`.

11. **Spawn count rationale** — The 4 instances are spread across B and F, which are 300m apart. Given the 900m radius and the need to avoid over-crowding the lagoon’s landmark zones, 4 is the optimal count to maintain spatial distinctiveness and visual impact.

12. **Clustering pattern** — Scattered-grid, with 1 instance per island, spaced to avoid visual overlap and maximize landmark distinctiveness.

13. **Inter-asset spacing minimum (m)** — 25 meters from any other instance of the same mesh.

14. **Path-clearance distance (m)** — 7 meters from the island-local path, ensuring safe traversal and avoiding interference with player movement.

15. **Team color reasoning** — TEAM=67 is chosen to match the `accent_pearl` swatch, which provides a neutral but elegant contrast to the island’s palette, and fits within the `game_fill_draws` switch as a secondary team color for landmarks.

16. **Shadow / contact AO strategy** — Casts a soft shadow with a ground AO blob beneath, enhancing depth perception and grounding the object in the environment.

17. **Distant-LOD strategy** — The asset does not undergo LOD simplification and remains full-res at all distances, as it is a signature landmark and must remain visually distinct.

18. **Animation, if any** — Static, no animation. The asset is intended to be a still, imposing presence in the landscape.

19. **Particle FX bound to entity** — None. It does not use particle FX, as its presence is defined by its shape and color, not by effects.

20. **Lighting interaction** — Sun-side faces warm with a slight `sail_cream` tint, while shadowed areas take on a cooler `sky_storm` hue, creating a soft contrast between light and dark.

21. **Collision** — Yes, it blocks player movement. `world.radius` is set to 1.8 to match its wide base and ensure player avoidance.

22. **Destructible** — No. The asset is a fixed landmark and is not intended to be destroyed or altered by gameplay.

23. **Lore hook** — A remnant from the great whale that once swam the skies, its skull now rests as a silent witness to the island’s history.

24. **Surface UV layout** — uBase 0 covers the main skull surface, 63 covers the embedded driftwood, 56 handles kelp growths, and 8 is used for the emissive chamber interiors.

25. **Material specularity** — Soft-glossy, to simulate the worn but still reflective texture of fossilized bone.

26. **Day/night appearance shift** — During the day, it appears warm with a `sail_cream` sheen; at night, it shifts to a cooler `mist_low` tone, with subtle `ember_lantern` glows from the chamber interiors.

27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and distinct, even at 50m, thanks to the strong curvature and contrast.

28. **Visual neighbours** — It looks best next to `driftwood_log`, `sea_coral`, and `whale_bone_cluster`, which complement its theme of oceanic ruin.

29. **Visual conflicts** — It should not be placed near `forest_boulder`, `skywatch_lantern`, or `tomb_stone`, as these would create visual clutter and compete for attention.

30. **Implementation hooks** — 
- Add `case 67` to `world.team` switch in `src/main.zig`.
- Add `makeWhaleSkullGiant(device:)` function in `ios/Mesh.swift`.
- Add `case 121:` to `dispatchMesh` in `ios/GameViewController.swift`.
---

## Asset 122 — whale_rib_arch_isle
1. **Silhouette at 30m** — From across the lagoon, the rib arch appears as a sweeping, curved bone structure that arcs over the shallow water, with a slight hump that makes it visible even in misty conditions.
2. **Tri-budget breakdown** — Body: 400 tris; Decorations: 60 tris; FX: 20 tris.
3. **Geometry construction** — The main structure uses an mbCylinder with a large radius and low height to form the rib’s base arc. A few mbSphere instances are used to add organic protrusions at key points along the rib. Extruded ring shapes and stacked plates form the decorative surface details and give the appearance of weathered bone.
4. **Body palette** — The rib’s main body uses sand_wet, driftwood_grey, and accent_pearl. The exposed inner surfaces use kelp_green, and the top rim features foam_white for a weathered sea-worn look.
5. **uBase marker assignments per surface** — Main rib: 0; Protrusions: 63; Inner grooves: 0; Rim edge: 8.
6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. The scale range allows for subtle variation while maintaining the arch's structural integrity and visual dominance.
7. **Y rotation** — Aligned-to-island-radial. The rib arch aligns to the island’s radial orientation to create a natural connection with the surrounding landscape.
8. **Ground anchor** — Partially buried. The arch sits with its base partially submerged in the shallows, with the lower section embedded into the sand and wet beach substrate.
9. **Procedural variation method** — Scale spread and palette hash. Two instances differ by slight scale variations and a hash-based color variation to avoid repetition.
10. **Spawn placement rules — which island(s)** — Spawns on B (Whale’s Spine) and F (Far Reach). Within a radius of 60m from the island center. Biome-zone: beach edge. Avoid-list: other large bone structures, water bridges.
11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS of B(8) + F(4), 12 instances evenly distribute the visual weight of the rib arches without overcrowding the zones, respecting the island's natural flow and biome boundaries.
12. **Clustering pattern** — Scattered-grid. Instances are spaced to appear naturally, avoiding tight clustering while maintaining a cohesive visual rhythm.
13. **Inter-asset spacing minimum (m)** — 15 meters. Ensures no visual crowding and allows each rib to stand independently in the landscape.
14. **Path-clearance distance (m)** — 6 meters. The rib arch avoids interfering with island paths, particularly at bridge and shoreline areas.
15. **Team color reasoning** — TEAM=67 aligns with the forest team color switch, giving it a natural tone that blends with the environment. It resolves to accent_coral in `game_fill_draws`.
16. **Shadow / contact AO strategy** — Casts a soft shadow with vertex AO. The rib's curved shape creates natural shadow depth, and the base is AO-enhanced for subtle contact with the ground.
17. **Distant-LOD strategy** — No LOD. Like the forest, this asset remains full resolution at all distances.
18. **Animation, if any** — Static, no animation. The rib arch is a stable, architectural element.
19. **Particle FX bound to entity** — None.
20. **Lighting interaction** — Sun-side appears warm with a slight tan tint, while shadow-side cools to a soft blue-gray. The interplay enhances the rib’s organic, weathered feel.
21. **Collision** — Yes. Player movement is blocked where the rib arch touches the ground. `world.radius` set to 1.8.
22. **Destructible** — No.
23. **Lore hook** — This ancient rib was once part of the great whale that once swam the seas of this realm, now a quiet monument to the ocean’s forgotten giants.
24. **Surface UV layout** — Main rib: uBase 0; Protrusions: uBase 63; Inner grooves: uBase 0; Rim edge: uBase 8.
25. **Material specularity** — Soft-glossy. The surface has a slight sheen to mimic weathered bone, with no refractive or emissive properties.
26. **Day/night appearance shift** — During the day, the rib appears warm and sun-worn. At night, it takes on a cooler, misty tone, especially with the soft glow from the rim.
27. **Silhouette test at 50 m** — Yes, the arch’s sweeping curve remains clear and distinct, even at half the average view distance.
28. **Visual neighbours** — It looks right next to `whale_bone_stalk`, `driftwood_pile`, and `shark_tooth_rock`, forming a cohesive, oceanic landscape.
29. **Visual conflicts** — Should not be placed near `sea_tower`, `sky_peg`, or `glow_coral`, as these would visually clash with the rib’s soft, organic form.
30. **Implementation hooks** — In `src/main.zig`, add case `67: return .whale_rib_arch_isle;` in `world.team` switch. In `ios/Mesh.swift`, add `func makeWhaleRibArchIsle(device: MTLDevice) -> (vertices: [Vertex], indices: [UInt32])`. In `ios/GameViewController.swift`, add dispatch case for `whale_rib_arch_isle` in the asset spawn logic.
---

## Asset 123 — whale_vertebrae_chunk
### 1. Silhouette at 30m
The chunk's silhouette presents a large, irregular bone structure with a prominent central ridge and a few smaller protruding segments, appearing as a weathered fossilized vertebrae cluster from across the lagoon.

### 2. Tri-budget breakdown
Body geometry: 200 tris. Decorations (surface cracks and nodule bumps): 30 tris. FX (emissive glow, optional): 10 tris. Total: 240 tris.

### 3. Geometry construction
The main body is constructed using `mbCylinder` for the central spine, with a tapered radius and two distinct end caps created using `mbSphere` to simulate rounded fossil ends. Additional protruding segments are built using extruded ring shapes, with each ring offset along the central axis to simulate vertebrae articulation. The mesh is composed of stacked plates and fan-of-triangles to enhance texture detail and surface variation.

### 4. Body palette
The primary color uses sand_wet (0.62, 0.55, 0.42) for the main body, with accent_pearl (0.95, 0.92, 0.85) for highlighted regions and driftwood_grey (0.45, 0.42, 0.38) for shadowed recesses. A minor splash of accent_coral (0.92, 0.50, 0.42) is used for simulated oxidation spots.

### 5. uBase marker assignments per surface
| Surface | uBase |
|---------|-------|
| Main body | 0 |
| Protruding segments | 63 |
| Cracks and nodule bumps | 0 |
| Emissive glow | 8 |

### 6. Base scale (scale_min, scale_max)
Scale range is 1.0 to 1.4. This range allows for visual variation while maintaining the fossilized, oversized feel of a whale vertebrae chunk, and keeps it distinct from smaller rock clusters.

### 7. Y rotation
Random `0..2π`. The chunk rotates freely on the island surface to avoid uniform placement and create natural visual variety.

### 8. Ground anchor
Partially buried, with 1/3 of the chunk's height below the island surface. This allows it to appear as if it’s naturally weathered into the terrain.

### 9. Procedural variation method
Variation is achieved through a palette hash that selects different swatches from the Isles palette for each instance, and a random scale spread within the defined range.

### 10. Spawn placement rules — which island(s)
Spawns are restricted to island B (Whale's Spine) only. Within this island, the spawn radius is 100–150 meters from the center. Biome-zone is beach edge. Avoid-list includes other large fossil clusters and structures with similar scale.

### 11. Spawn count rationale
With a spawn radius of 100–150m and `est_count = 30`, each instance is spaced to ensure clear visual separation and avoid clutter in the island's coastal zone, aligning with the sparse, natural distribution of fossilized remains.

### 12. Clustering pattern
Dense-cluster. Chunks are grouped in clusters of 3–5 per zone, mimicking the natural clustering of fossilized whale vertebrae in deep sediment.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters to another instance of the same mesh to avoid visual overcrowding.

### 14. Path-clearance distance (m)
10 meters from the ISLAND-LOCAL path. This ensures it doesn’t block movement or visually interfere with player navigation on the island.

### 15. Team color reasoning
TEAM=67 is chosen to match the “fossilized remains” theme, and resolves to sand_wet (0.62, 0.55, 0.42) in the `game_fill_draws` switch, blending with the island’s geological palette.

### 16. Shadow / contact AO strategy
Casts a soft shadow and uses a vertex-based ambient occlusion strategy for contact regions. The shadow is slightly blurred to simulate the soft edges of weathered stone.

### 17. Distant-LOD strategy
No LOD is implemented. The asset remains at full resolution even at 100m distance, matching the forest's design decision to keep all assets detailed.

### 18. Animation, if any
Static, no animation. The chunk does not move or animate to maintain its fossilized, timeless appearance.

### 19. Particle FX bound to entity
None. No particle effects are bound to the chunk.

### 20. Lighting interaction
Sun-side regions are tinted with a warm sand_wet hue, while shadow-side regions take a cooler driftwood_grey tint, enhancing the illusion of depth and weathering.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.8, representing its solid, large bone-like structure.

### 22. Destructible
No. The chunk is not destructible, as it is part of a natural fossil cluster and should remain intact for lore and aesthetic purposes.

### 23. Lore hook
A remnant of the great whale that once swam these seas, now weathered into the island’s surface, a testament to the ocean’s ancient power.

### 24. Surface UV layout
Main body uses uBase 0; protruding segments use uBase 63; cracks and nodules use uBase 0; emissive glow uses uBase 8.

### 25. Material specularity
Soft-glossy. The surface has a subtle sheen to simulate weathered, fossilized bone that reflects light gently.

### 26. Day/night appearance shift
During the day, sun-facing areas warm to sand_wet with a hint of accent_coral. At night, shadowed areas cool to driftwood_grey, with a faint ember_lantern (0.95, 0.55, 0.18) glow on the emissive regions.

### 27. Silhouette test at 50 m
Yes, it still reads clearly at 50m, with a strong central silhouette and recognizable bone-like structure.

### 28. Visual neighbours
Looks best next to beach_dune, kelp_green, and driftwood_grey assets, as these blend naturally with the fossilized palette and oceanic setting.

### 29. Visual conflicts
Should not be placed near large sandstone boulders or other high-contrast, angular structures that would compete for visual dominance.

### 30. Implementation hooks
In `src/main.zig`, add case `67: return .whale_vertebrae_chunk` to the `world.team` switch.  
In `ios/Mesh.swift`, add `func makeWhaleVertebraeChunk(device: MTLDevice) -> (vertices: [Vertex], indices: [UInt32])` function.  
In `ios/GameViewController.swift`, add dispatch case `case .whale_vertebrae_chunk` in the `spawnMesh` function.
---

## Asset 124 — fish_skeleton_dry
### 1. **Silhouette at 30m** — A dry fish skeleton splayed across sand, its long curved spine and scattered ribs forming a dramatic, angular silhouette against the horizon.
### 2. **Tri-budget breakdown** — Body: 160 tris, Decorations: 20 tris, FX: 20 tris.
### 3. **Geometry construction** — The main body uses a `mbCylinder` for the backbone, with `mbSphere` segments for the ribcage and skull. Additional `extruded ring` elements simulate the fins and tail. A static cluster of smaller bone pieces is placed around the base to suggest disintegration.
### 4. **Body palette** — Uses `sand_wet`, `beach_dune`, `driftwood_grey`, and `accent_pearl` to reflect sun-bleached and weathered bone surfaces.
### 5. **uBase marker assignments per surface** —  
| Surface       | uBase |
|---------------|--------|
| Spine         | 0      |
| Ribs          | 63     |
| Skull         | 0      |
| Fins          | 63     |
| Sand base     | 0      |
| FX emissive   | 8      |
### 6. **Base scale (scale_min, scale_max)** — [0.8, 1.4]. Scale variation mimics natural decay and size differences in fish of different ages.
### 7. **Y rotation** — Random `0..2π`. No fixed orientation to maintain organic scatter.
### 8. **Ground anchor** — Sits on island surface (y=island_y). Partially buried, with 10% of the skeleton below the surface.
### 9. **Procedural variation method** — 2 instances differ by scale and palette hash (using `mix()` to blend swatches).
### 10. **Spawn placement rules — which island(s)** — B, F beaches. Spawn radius within 50–100m of island edge. Biome-zone: beach edge. Avoid-list: bridge structures, temple plazas.
### 11. **Spawn count rationale** — 30 instances across 900m radius is consistent with low-density beach fauna, matching the sparse distribution of such natural remains.
### 12. **Clustering pattern** — Scattered-grid. Instances spaced to avoid overlapping visual impact.
### 13. **Inter-asset spacing minimum (m)** — 3.0 meters.
### 14. **Path-clearance distance (m)** — 6.0 meters from island-local path.
### 15. **Team color reasoning** — TEAM=67 maps to `accent_coral`, a warm, oxidized hue that fits the aged, sun-warmed bone. It’s chosen to subtly contrast with `accent_pearl` and `driftwood_grey` in the environment.
### 16. **Shadow / contact AO strategy** — Casts shadow; ground AO blob using a 1.5m-radius soft shadow. No vertex-AO.
### 17. **Distant-LOD strategy** — Disappears at 100m. No LOD in forest, but this asset is not forest-based.
### 18. **Animation, if any** — Static, no animation.
### 19. **Particle FX bound to entity** — None.
### 20. **Lighting interaction** — Sun-side is tinted with `accent_coral` warmth; shadow-side takes on a cooler `sand_wet` tone with slight `sky_storm` influence.
### 21. **Collision** — Does not block player movement. `world.radius` set to 0.2.
### 22. **Destructible** — No. Default asset is permanent.
### 23. **Lore hook** — "A relic of the great tides, where the sea once gave life — now only bones remain."
### 24. **Surface UV layout** — Spine uses uBase 0; ribs and skull use uBase 63; fins use uBase 0; sand base uses uBase 0; FX uses emissive uBase 8.
### 25. **Material specularity** — Matte with soft-glossy highlights to simulate dry, weathered bone.
### 26. **Day/night appearance shift** — During the day, sun-side is warm with `accent_coral` tint; shadow-side is cooler with `sky_storm` influence. Night view is uniformly muted with slight `mist_low` glows.
### 27. **Silhouette test at 50 m** — Yes, the angular spine and ribcage are still clearly readable.
### 28. **Visual neighbours** — Looks right next to `seaweed_clump`, `driftwood_log`, and `shell_pile`.
### 29. **Visual conflicts** — Should not be placed near `kelp_cluster` or `cave_entrance`, which would compete for attention or obscure the skeleton’s form.
### 30. **Implementation hooks** —  
- `src/main.zig`: Add `case 67: return .fish_skeleton_dry` to `world.team` switch.  
- `ios/Mesh.swift`: Add `func makeFishSkeletonDry(device: MTLDevice) -> (verts: [Vertex], idxs: [UInt32])`.  
- `ios/GameViewController.swift`: Add `case 124: return makeFishSkeletonDry(device: device)` to `makeMesh()` dispatch.
---

## Asset 125 — mossy_pillar_isle
### 1. **Silhouette at 30m** — From across the lagoon, the mossy pillar appears as a tall, tapering column rising from the shallow waters, with a soft, organic silhouette softened by kelp-tinted overgrowth and a gentle curve to its form.

### 2. **Tri-budget breakdown** — Body: 200 tris, Decorations: 60 tris, FX: 20 tris. Total: 280 tris.

### 3. **Geometry construction** — The main structure is a tall mbCylinder with a slight taper from base to top, representing the central pillar. Around the base, an extruded ring of mbSphere segments is added to simulate mossy root-like growth. Additional small mbSphere clusters are used to create kelp-like overgrowth on the pillar's surface, and a fan of triangles is used to define the top cap of the pillar with a slight dome.

### 4. **Body palette** — Uses sand_wet for the base, kelp_green for the pillar’s mossy texture, driftwood_grey for the root-like ring, and accent_pearl for the top cap.

### 5. **uBase marker assignments per surface** — 
| Surface        | uBase |
|----------------|-------|
| Pillar body    | 0     |
| Root ring      | 56    |
| Kelp overgrowth| 0     |
| Top cap        | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 1.0 to 1.5. Justification: This scale range allows for visual variety while keeping the asset cohesive in a ruin environment.

### 7. **Y rotation** — Random `0..2π`. The pillar rotates freely to avoid symmetry and match the natural randomness of island ruins.

### 8. **Ground anchor** — Partially buried, sitting on the island surface at y=island_y with 20% of the mesh’s height below the surface to simulate mossy settling.

### 9. **Procedural variation method** — Two instances differ by scale and a palette hash that modifies the mossy color slightly, affecting kelp_green saturation and driftwood_grey tone.

### 10. **Spawn placement rules — which island(s)** — Spawns on islands D, E, and F. Within island D (The Wreck), spawn radius is 20–40m. On E (Skywatch), spawn radius is 10–30m. On F (Far Reach), spawn radius is 15–35m. Biome-zone: beach edge or cliff face. Avoid-list: near bridges, temples, or other large structures.

### 11. **Spawn count rationale** — The estimate of 50 instances is correct because the total area covered by islands D, E, and F is ~900 m radius, and the density of ruins and natural features allows for 50 instances without overcrowding.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced evenly across the islands, avoiding clustering to maintain a natural ruin layout.

### 13. **Inter-asset spacing minimum (m)** — 10 meters. This spacing avoids overcrowding and allows for natural visual breathing room.

### 14. **Path-clearance distance (m)** — 6 meters. The asset is allowed to spawn near paths, but not directly on them.

### 15. **Team color reasoning** — TEAM=68 is chosen to align with the mossy, kelp-tinted overgrowth theme, resolving to a soft kelp_green in `game_fill_draws` switch for consistent visual integration in the ruin biome.

### 16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob is used to simulate mossy contact with the island surface.

### 17. **Distant-LOD strategy** — The asset does not use LOD and will remain visible at all distances, as is standard for forest assets.

### 18. **Animation, if any** — Static, no animation. No movement or sway.

### 19. **Particle FX bound to entity** — None. No particle effects are bound to the mesh.

### 20. **Lighting interaction** — Sun-side appears warm with a slight kelp green tint, while shadow-side takes on a cooler tone with a hint of sand_wet.

### 21. **Collision** — Does not block player movement. `world.radius` is set to 0.7 to allow passage around the base.

### 22. **Destructible** — No. The asset is not destructible.

### 23. **Lore hook** — Once a sacred pillar of the old lighthouse, now overtaken by kelp and moss, it stands as a silent witness to the island’s transformation.

### 24. **Surface UV layout** — The pillar body (uBase 0) uses a base texture with a mossy pattern. The root ring (uBase 56) uses a texture that simulates root tangles. Kelp overgrowth (uBase 0) is UV-mapped to a noise-based texture. The top cap (uBase 8) uses a glossy, emissive texture for subtle light emission.

### 25. **Material specularity** — Soft-glossy. The surface reflects light gently, particularly on the mossy overgrowth and cap.

### 26. **Day/night appearance shift** — During the day, sun-side is warm with a kelp green tint; shadow-side is cool and dusky. At night, the top cap glows faintly in amber, enhancing the mystical ruins theme.

### 27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and recognizable at 50 meters, maintaining the column shape and overgrowth form.

### 28. **Visual neighbours** — Looks right next to `driftwood_pile`, `sea_crate`, and `tide_pool`. These assets complement the ruin aesthetic and create a cohesive island scene.

### 29. **Visual conflicts** — Should not spawn near large, angular ruins or bright, contrasting structures like `lighthouse_tower` or `beacon_spire` to avoid silhouette clash and visual noise.

### 30. **Implementation hooks** — Add `case 68:` to `world.team` switch in `src/main.zig`. Add `func makeMossyPillarIsle(device:)` in `ios/Mesh.swift`. Add dispatch case `case 125:` in `ios/GameViewController.swift`.
---

## Asset 126 — sea_glass_temple
1. **Silhouette at 30m** — From across the lagoon, the sea_glass temple appears as a floating, translucent pyramid with a pearl-trimmed base, faintly glowing in the ambient light, its walls seeming to breathe with the tide.

2. **Tri-budget breakdown** — Body: 500 tris, Decorations: 150 tris, FX: 70 tris.

3. **Geometry construction** — The base is built with a `mbCylinder` to form a tapering central spire, capped with a `mbSphere` for the apex dome. The walls are constructed with extruded rings and stacked plates, each layer slightly offset to simulate sea-worn texture. A fan of triangles forms the roof’s translucent panels, and a static cluster of smaller spheres is used for the lanterns and coral accents.

4. **Body palette** — Uses `water_shallow`, `accent_pearl`, `kelp_green`, and `sand_wet` for varying surfaces — the base uses sand_wet, walls use water_shallow and kelp_green, and the roof and trim use accent_pearl.

5. **uBase marker assignments per surface** — 
| Surface | uBase |
|--------|-------|
| Base | 0 |
| Walls | 54 |
| Trim | 61 |
| Roof | 0 |
| Lanterns | 8 |

6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. This range allows for subtle visual variation without losing architectural integrity or overwhelming the environment.

7. **Y rotation** — Aligned-to-island-radial. The structure rotates to align with the radial orientation of the island it rests upon, enhancing natural placement.

8. **Ground anchor** — Partially buried, sitting on island surface with y=island_y and 0.2m of its base submerged to simulate tidal anchoring.

9. **Procedural variation method** — Two instances differ by scale spread and palette hash for subtle color variation on the walls, using a simple hash of the instance ID to shift the base color slightly.

10. **Spawn placement rules — which island(s)** — Spawns on islands E (sky island) and F (portal island), within a 40–60m radius. Biome-zone: temple plaza. Avoid-list: nearby temples, large rocks, bridges.

11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS of E(2) and F(4), 6 instances are placed to ensure even coverage of the island bias while keeping visual density manageable.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid overcrowding, maintaining a natural and open feel.

13. **Inter-asset spacing minimum (m)** — 12 meters. Ensures visual breathing room without appearing too sparse.

14. **Path-clearance distance (m)** — 7 meters. Avoids interference with island-local paths, particularly on the portal island.

15. **Team color reasoning** — TEAM=69 is chosen to align with the `world.team` switch for oceanic ruins. It resolves to `accent_pearl` in the `game_fill_draws` switch, maintaining consistent visual identity with the ocean theme.

16. **Shadow / contact AO strategy** — Casts a soft shadow with vertex-AO. Ground AO blob is minimal to preserve the floating illusion of the structure.

17. **Distant-LOD strategy** — No LOD. The asset is kept visible up to 200m, maintaining architectural integrity across the entire zone.

18. **Animation, if any** — Static, no animation. The temple is meant to evoke stillness and reverence.

19. **Particle FX bound to entity** — `lantern_glow` — subtle emissive particles around the inner spire and base, enhancing the temple’s luminous quality.

20. **Lighting interaction** — Sun-side glows warm with a subtle amber tint, while shadow-side cools into a bluish-green hue, mimicking the ocean’s duality.

21. **Collision** — Yes, it blocks movement. `world.radius` set to 1.0 to prevent player traversal.

22. **Destructible** — No. The structure is meant to be permanent and awe-inspiring.

23. **Lore hook** — Once a beacon for lost sailors, this temple now glows faintly with the memory of its guardians.

24. **Surface UV layout** — uBase 0 covers the base and roof, 54 covers the walls with a slight texture variation, 61 covers the pearl trim, and 8 is used for emissive lanterns.

25. **Material specularity** — Refractive. The walls are semi-transparent with a soft sheen, mimicking sea glass.

26. **Day/night appearance shift** — During day, the structure glows with warm tones; at night, the emissive lanterns intensify, shifting the palette to deeper blues and oranges.

27. **Silhouette test at 50 m** — Yes, the pyramid shape and glowing trim remain distinct and recognizable at half the average view distance.

28. **Visual neighbours** — Looks right next to `driftwood_pile`, `seaweed_cluster`, and `shattered_ship`, creating a cohesive ruinous oceanic scene.

29. **Visual conflicts** — Should not be placed near `tidepool_cave`, `coral_reef`, or `windmill`, as the visual weight would clash and obscure the temple’s silhouette.

30. **Implementation hooks** — 
- `src/main.zig`: Add `case 69` in `world.team` switch, assign `sea_glass_temple` mesh.
- `ios/Mesh.swift`: Add `makeSeaGlassTemple(device:)` function.
- `ios/GameViewController.swift`: Add `case 126` to `dispatchMesh` with `makeSeaGlassTemple(device:)` call.
---

## Asset 127 — sunken_idol_pedestal
1. **Silhouette at 30m** — The pedestal stands as a tall, tapering column with a carved deity face on top, partially submerged and overgrown with kelp and coral, forming a distinctive vertical silhouette against the lagoon's horizon.
2. **Tri-budget breakdown** — Body: 200 tris; Decorations: 80 tris; FX: 40 tris.
3. **Geometry construction** — The base is a tapered cylinder (mbCylinder) with a wider bottom and narrower top, rising to a sphere (mbSphere) that serves as the idol's head. The pedestal is topped with a ring extrusion to represent a carved base, and a series of vertical grooves are added using fan-of-triangle extrusions for detail. Additional surface textures are achieved with a stacked plate technique to simulate worn, layered stone.
4. **Body palette** — The base uses sand_wet and driftwood_grey, with the top sphere using accent_pearl and kelp_green for a contrasted weathered look. The overgrowth is kelp_green with subtle foam_white highlights.
5. **uBase marker assignments per surface** — Base: 0; Idol head: 56; Overgrowth: 61; Emissive ring: 8.
6. **Base scale (scale_min, scale_max)** — (1.0, 1.4). The variation allows for natural irregularity in the ruins without breaking immersion.
7. **Y rotation** — Random 0..2π. Allows for natural variation in orientation.
8. **Ground anchor** — Partially buried (y = -0.2), with the top of the pedestal just visible above the shallow waterline.
9. **Procedural variation method** — Palette hash. Each instance uses a different color offset based on a hash of its position and instance ID.
10. **Spawn placement rules — which island(s)** — D, E, F. Spawn radius within island = 40–80m. Biome-zone = beach edge or cliff face. Avoid-list = any bridge, temple, or other large ruin structures.
11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS, 10 instances are spaced appropriately to give a sense of presence without overcrowding. The sparse, scattered distribution fits the ruin theme.
12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid visual crowding.
13. **Inter-asset spacing minimum (m)** — 12 meters.
14. **Path-clearance distance (m)** — 6 meters. It avoids bridge paths but can be near other shoreline structures.
15. **Team color reasoning** — TEAM=68 aligns with the neutral, ancient ruin palette. It resolves to accent_pearl in `game_fill_draws` switch, blending with the stone textures.
16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob is used for subtle contact shadow around base.
17. **Distant-LOD strategy** — No LOD. The asset remains at full resolution for the entire view distance to maintain detail in the ruin’s character.
18. **Animation, if any** — Static, no animation.
19. **Particle FX bound to entity** — None.
20. **Lighting interaction** — Sun-side warms to accent_coral; mist-side cools to sky_storm.
21. **Collision** — Blocks player movement. `world.radius` = 0.8.
22. **Destructible** — No.
23. **Lore hook** — A forgotten idol, half-submerged in the lagoon, whispers of a long-lost sea god.
24. **Surface UV layout** — Base (uBase 0), Idol head (uBase 56), Overgrowth (uBase 61), Emissive ring (uBase 8).
25. **Material specularity** — Soft-glossy. Reflects light subtly but not harshly.
26. **Day/night appearance shift** — Sun-side warms to accent_coral; shadow-side cools to mist_low.
27. **Silhouette test at 50 m** — Yes, the vertical silhouette and carved face remain clear and recognizable.
28. **Visual neighbours** — Looks right next to `forest_coral_reef`, `ruin_stone_wall`, and `sea_dragon_bones`.
29. **Visual conflicts** — Should not spawn near `ruin_gate`, `skywatch_observation`, or `portal_mechanism` as these would dominate the silhouette.
30. **Implementation hooks** — Add case `68` to `world.team` switch in `src/main.zig`. Add `makeSunkenIdolPedestal(device:)` to `ios/Mesh.swift`. Add dispatch case `case 127:` to `ios/GameViewController.swift`.
---

## Asset 128 — mossy_carved_floor
### 1. Silhouette at 30m
The mossy carved floor appears as a flat, irregularly shaped disc with subtle organic texture, barely distinguishable from the surrounding stone and moss on the island surface.

### 2. Tri-budget breakdown
Body: 180 tris; Decorations: 25 tris; FX: 15 tris. Total: 220 tris.

### 3. Geometry construction
The core mesh is constructed using a `mbCylinder` with a flat top and irregular radius variation to simulate carved stone. Additional moss-filled cracks are created using extruded ring segments. Surface details are added via a few `mbSphere` elements to simulate small mossy protuberances, and a fan of triangles is used for irregular moss patches.

### 4. Body palette
The body uses `driftwood_grey`, `kelp_green`, and `sand_wet`, covering the main floor surface and moss-filled cracks respectively.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Main floor    | 0     |
| Moss cracks   | 56    |
| Moss patches  | 0     |
| Emissive      | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 1.0 to 1.4. This allows for visual variety while maintaining consistent scale for the ruin environment.

### 7. Y rotation
Random `0..2π` rotation to avoid uniformity and enhance natural look.

### 8. Ground anchor
Sits on island surface (y=island_y), partially embedded to simulate weathering.

### 9. Procedural variation method
Instances vary by palette hash and sub-mesh subset — moss patch locations and density differ per instance.

### 10. Spawn placement rules — which island(s)
Spawn on islands D, E, and F. Radius within island: 20–60m. Biome-zone: temple plaza, boundary ring. Avoid-list: near bridges, within 10m of other mossy structures.

### 11. Spawn count rationale
With a 900m radius and ISLAND_BIAS of D, E, F, 40 instances provide a balanced density that avoids clumping while maintaining visual consistency across the ruins.

### 12. Clustering pattern
Scattered-grid pattern, with instances placed to avoid clustering and ensure visual spread.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
8 meters from the ISLAND-LOCAL path, ensuring no obstruction to player movement.

### 15. Team color reasoning
TEAM=68 aligns with the forest and ruin color palette, resolving to `accent_coral` in the `game_fill_draws` switch, giving it a warm, earthy tone.

### 16. Shadow / contact AO strategy
Casts a soft shadow. Ground AO blob used for contact area to simulate mossy stone contact.

### 17. Distant-LOD strategy
No LOD is implemented; forest assets do not simplify at distance.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side appears warm with driftwood tones; mist-side cools to kelp-green and sand_wet hues.

### 21. Collision
Yes, it blocks player movement. `world.radius` set to 0.6.

### 22. Destructible
No.

### 23. Lore hook
A forgotten shrine floor, weathered by the sea and overgrown with moss.

### 24. Surface UV layout
Main floor uses uBase 0, moss cracks use uBase 56, and emissive patches use uBase 8.

### 25. Material specularity
Soft-glossy, to simulate weathered stone with mossy texture.

### 26. Day/night appearance shift
Sun-side retains warm tones; shadow-side cools to kelp-green and driftwood_grey.

### 27. Silhouette test at 50 m
Yes, the floor shape is still recognizable at half the average view distance.

### 28. Visual neighbours
Looks right next to `ruin_wall`, `stone_pillar`, and `cracked_stone`.

### 29. Visual conflicts
Should not spawn near large `ruin_tower` or `lava_pool` as it would clash visually.

### 30. Implementation hooks
- Zig: Add `case 68` to `world.team` switch in `src/main.zig`.
- Swift: Add `makeMossyCarvedFloor(device:)` to `ios/Mesh.swift`.
- GameViewController: Add `dispatchCase(128)` in `ios/GameViewController.swift`.
---

## Asset 129 — weathered_obelisk_isle
1. **Silhouette at 30m** — A leaning, weathered obelisk stub rises from the lagoon’s shallow waters, its angular, eroded form appearing like a broken pillar with a tilted top, its silhouette sharply defined against the sky and the surrounding mist.

2. **Tri-budget breakdown** — The obelisk’s body is 200 tris, its decorative base ring is 40 tris, and its FX elements (a small glow and particle mist) are 40 tris. Total: 280 tris.

3. **Geometry construction** — The core is a tall, tapered mbCylinder with a radius that narrows from 1.0 to 0.3 over 6 rings. A mbSphere is attached at the top to simulate a weathered capstone. The base features a low extruded ring with slight UV variation, and a small fan of triangles is used to model a small mossy patch on the base.

4. **Body palette** — The obelisk’s main body uses sand_wet, driftwood_grey, and accent_pearl. The moss patch and capstone use kelp_green and mist_low, respectively.

5. **uBase marker assignments per surface** —
| Surface        | uBase |
|----------------|-------|
| main body      | 0     |
| capstone       | 56    |
| base ring      | 0     |
| moss patch     | 8     |

6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. Slight scale variation to avoid repetition while maintaining structural coherence and realism in a drifting isle.

7. **Y rotation** — Random 0..2π. The obelisk is not aligned to any fixed orientation to enhance naturalistic placement.

8. **Ground anchor** — Partially buried, with 10% of its base submerged in shallow water, sitting on the island surface with a y_offset of -0.4.

9. **Procedural variation method** — Variations include palette hash for base surface tint and a small random scale shift per instance, ensuring no two obelisks look identical.

10. **Spawn placement rules — which island(s)** — Spawn on islands D, E, F. Within island D (The Wreck), radius is 100m; island E (Skywatch), radius 80m; island F (Far Reach), radius 90m. Spawn biome-zone is beach edge or inland, avoiding any bridge zones or temple plazas.

11. **Spawn count rationale** — 25 instances across 900m radius is appropriate to balance visibility and realism. The sparse distribution ensures no over-saturation in any single zone while still creating a sense of presence.

12. **Clustering pattern** — Scattered-grid. Instances are distributed with slight randomness to avoid predictable clustering.

13. **Inter-asset spacing minimum (m)** — 12 meters minimum to prevent visual crowding and maintain island authenticity.

14. **Path-clearance distance (m)** — 6 meters. It avoids the main island paths to not impede travel or sightlines.

15. **Team color reasoning** — TEAM=68 is chosen to align with the warm sand and driftwood tones, using the driftwood_grey palette in the `game_fill_draws` switch, ensuring consistent color theme across the Drifting Isles.

16. **Shadow / contact AO strategy** — Casts a soft shadow and uses vertex-AO to simulate contact with the water and sand. No ground AO blob due to shallow base.

17. **Distant-LOD strategy** — No LOD. Like the forest assets, it remains visible at all distances for immersive storytelling.

18. **Animation, if any** — Static, no animation. The obelisk does not move or sway.

19. **Particle FX bound to entity** — A `drip_seafoam` emitter is bound to the base to simulate water droplets from the shallow water.

20. **Lighting interaction** — Sun-side is tinted with sand_wet and driftwood_grey, while shadow-side takes a cooler tone of mist_low and kelp_green.

21. **Collision** — Yes, it blocks player movement. `world.radius` is set to 0.5 to allow small navigation around it but not through it.

22. **Destructible** — No. It is a static ruin element, not meant to be broken.

23. **Lore hook** — A remnant of a lost shrine, now weathered and leaning, its top cracked and moss-covered, still whispering of ancient rituals.

24. **Surface UV layout** — The main body uses uBase 0, the capstone uses uBase 56, the base ring uses uBase 0, and the moss patch uses uBase 8.

25. **Material specularity** — Matte with soft-glossy highlights on the capstone to simulate weathered stone.

26. **Day/night appearance shift** — During the day, it has a warm, sun-warmed tint of sand_wet and driftwood_grey; at night, it takes on a cool, misty tone of mist_low and kelp_green.

27. **Silhouette test at 50 m** — Yes, the obelisk remains clearly distinguishable from the background and other assets, even at half the average view distance.

28. **Visual neighbours** — It pairs well with `forest_tower`, `beach_coral_cliff`, and `skywatch_ornate_spire` to form a cohesive narrative of a collapsed ancient structure.

29. **Visual conflicts** — It should not be placed near large `island_crate` or `portal_spires`, as they would overshadow or visually clash with its weathered, subtle form.

30. **Implementation hooks** — In `src/main.zig`, add `case 68: return .weathered_obelisk_isle` to the `world.team` switch. In `ios/Mesh.swift`, add `makeWeatheredObelisk(device:)` function. In `ios/GameViewController.swift`, add dispatch case `case 129: self.spawnWeatheredObelisk();` in the asset spawning logic.
---

## Asset 130 — broken_arch_isle
### 1. **Silhouette at 30m** — A half-arch collapsed into a cracked obsidian inset, rising from the shallows like a broken crown, its angular form cutting through the island's edge.

### 2. **Tri-budget breakdown** — Body: 280 tris, Decorations: 60 tris, FX: 20 tris. Total: 360 tris.

### 3. **Geometry construction** — The body is built from a `mbCylinder` with a taper from 1.0 to 0.6 radius, 4 rings and 16 sides, forming the arch base. An `mbSphere` with 8 rings and 12 sides is added atop to represent a cracked, collapsed section. Extruded cracks and surface fractures are added via fan-of-triangles, and a small obsidian inset is modeled with a `mbCylinder` of smaller radius, rotated to simulate a broken inset.

### 4. **Body palette** — sand_wet (arch base), driftwood_grey (cracked debris), kelp_green (underwater moss), and accent_coral (obsidian inset).

### 5. **uBase marker assignments per surface** — 

| Surface         | uBase |
|----------------|-------|
| Arch base      | 0     |
| Cracked debris | 56    |
| Moss           | 62    |
| Obsidian inset | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 0.8 to 1.2. Justification: The arch is designed to be a mid-sized ruin feature, balancing visibility and environmental integration.

### 7. **Y rotation** — Random `0..2π`. Rotational variation ensures visual diversity across instances.

### 8. **Ground anchor** — Partially buried, sitting 0.2m below the island surface with slight offset to simulate weathered settling.

### 9. **Procedural variation method** — Instances vary by scale spread, surface crack patterns (using fbm noise), and palette hash for color shifts.

### 10. **Spawn placement rules — which island(s)** — Spawned only on D (The Wreck) and F (Far Reach), within 100m of island center, biome-zone: beach edge, avoid-list: bridge zones, temple plazas.

### 11. **Spawn count rationale** — With a 900m radius and ISLAND_BIAS = D,F, 30 instances provide a balanced distribution across these two islands, avoiding overcrowding while maintaining visual presence.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid overlapping influence zones.

### 13. **Inter-asset spacing minimum (m)** — 15 meters minimum from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 7 meters from island-local paths (bridges = 0m).

### 15. **Team color reasoning** — TEAM=68 resolves to `accent_coral` in the `game_fill_draws` switch, matching the obsidian inset’s color and reinforcing the ruin’s volcanic origin.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow. Ground AO blob with radius 1.5m, vertex-AO on top edges.

### 17. **Distant-LOD strategy** — Disappears at 100m distance, simplified to a single flat triangle with emissive color. Matches forest’s no-LOD strategy.

### 18. **Animation, if any** — Static, no animation.

### 19. **Particle FX bound to entity** — `drip_seafoam` on moss surfaces, with a low emission rate.

### 20. **Lighting interaction** — Sun-side has warm amber tint, shadow-side is cool blue-green.

### 21. **Collision** — Yes, blocks movement. `world.radius` = 1.0.

### 22. **Destructible** — No. Default static asset.

### 23. **Lore hook** — A remnant of the ancient arch that once spanned the lagoon, now cracked and sunken, a monument to a forgotten empire.

### 24. **Surface UV layout** — uBase 0 covers the main arch body, uBase 56 covers cracked debris, uBase 62 covers mossy surfaces, and uBase 8 covers the obsidian inset.

### 25. **Material specularity** — Soft-glossy, with a slight reflection on the obsidian inset.

### 26. **Day/night appearance shift** — Daytime is warm and sunlit, with soft shadows; nighttime is cool and faintly glowing with ambient emissive color on the obsidian.

### 27. **Silhouette test at 50 m** — Yes, the arch still reads clearly, with a strong angular silhouette and contrast against the sky.

### 28. **Visual neighbours** — Looks best next to `driftwood_cluster`, `sea_coral`, and `lava_crater`.

### 29. **Visual conflicts** — Should not spawn near `floating_tower` or `sky_island_balcony` due to silhouette overlap and thematic clashing.

### 30. **Implementation hooks** — In `src/main.zig`, add case `68: broken_arch_isle`. In `ios/Mesh.swift`, add `makeBrokenArchIsle(device:)`. In `ios/GameViewController.swift`, add dispatch case for `broken_arch_isle` under `world.team == 68`.
---

## Asset 131 — mossy_face_relief
### 1. Silhouette at 30m
The carved face relief appears as a subtle, angular silhouette against the sky, with a strong vertical profile that makes it visible from across the lagoon.

### 2. Tri-budget breakdown
Body: 180 tris, Decorations: 40 tris, FX: 20 tris.

### 3. Geometry construction
The main face relief is built using a mbCylinder for the base, with a tapering neck and head section. The eye sockets and mouth are constructed with mbSphere extrusions to create depth and contrast. The entire structure is composed of a static cluster of meshes that are extruded from a single base mesh, with no dynamic topology.

### 4. Body palette
The face relief uses sand_wet (for base stone), driftwood_grey (for texture depth), kelp_green (for moss and lichen), and accent_pearl (for highlights on the carved features).

### 5. uBase marker assignments per surface
| Surface          | uBase |
|------------------|-------|
| Base stone       | 0     |
| Moss texture     | 56    |
| Carved detail    | 0     |
| Lichen patches   | 56    |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. Justification: to allow for visual variety while maintaining consistent interaction with player space and ensuring the face relief remains legible at a distance.

### 7. Y rotation
Random 0..2π.

### 8. Ground anchor
Partially buried — y = island_y - 0.3, sitting just below the surface to simulate a weathered, ancient structure.

### 9. Procedural variation method
Instances differ by palette hash, with a fixed scale spread and no sub-mesh subsets.

### 10. Spawn placement rules — which island(s)
Spawn on islands D and E. Island D (The Wreck) radius: 100m, biome-zone: cliff face. Island E (Skywatch) radius: 50m, biome-zone: boundary ring. Avoid-list: structures with similar scale or angular features.

### 11. Spawn count rationale
The 25 instances are spread across a 900m radius with sufficient spacing to avoid visual overcrowding while ensuring that the carved face relief is a noticeable presence in the environment.

### 12. Clustering pattern
Scattered-grid, with instances spaced across the island's surface to simulate an ancient ruin layout.

### 13. Inter-asset spacing minimum (m)
Minimum 6m to another instance of the same mesh.

### 14. Path-clearance distance (m)
8m from the ISLAND-LOCAL path (since this is a cliff-side feature, it avoids bridge zones).

### 15. Team color reasoning
TEAM=68 to align with the mossy, aged stone color palette. It resolves to driftwood_grey in the `game_fill_draws` switch.

### 16. Shadow / contact AO strategy
Casts a shadow. Uses ground AO blob for soft contact with terrain.

### 17. Distant-LOD strategy
No LOD — like all forest assets, it remains visible at all distances.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
Sun-side warm tint (accent_pearl highlights), mist-side cool tint (sand_wet and kelp_green blend into a muted tone).

### 21. Collision
Yes, blocks player movement. world.radius = 0.6.

### 22. Destructible
No.

### 23. Lore hook
A relic of a lost civilization, once guarding the entrance to an ancient temple.

### 24. Surface UV layout
uBase 0 covers the base stone and carved details, while uBase 56 is used for moss and lichen patches.

### 25. Material specularity
Soft-glossy.

### 26. Day/night appearance shift
Sun-side warm tint with a slight amber hue on the base, shadow-side cool tint with blue and gray tones.

### 27. Silhouette test at 50 m
Yes, it still reads clearly and maintains its vertical profile at half the average view distance.

### 28. Visual neighbours
Looks right next to `ruin_stone_pillar`, `forest_lichen_cluster`, and `island_boulder`.

### 29. Visual conflicts
Should not be near other angular, high-contrast features like `skywatch_lantern`, as they would compete for visual attention.

### 30. Implementation hooks
- Add `case 68: return world_team_mossy_face_relief(device:)` to `src/main.zig`.
- Add `func makeMossyFaceRelief(device: MTLDevice) -> (MTLBuffer, MTLBuffer)` to `ios/Mesh.swift`.
- Add `case 131: makeMossyFaceRelief(device:)` to dispatch in `ios/GameViewController.swift`.
---

## Asset 132 — prayer_bell_tower
### 1. **Silhouette at 30m** — A tall, narrow bell tower with a brass bell at its apex, standing prominently on a wet stone base with barnacle-encrusted edges, appearing as a vertical landmark against the drifting island's horizon.
### 2. **Tri-budget breakdown** — Body: 380 tris, Decorations: 60 tris, FX: 20 tris.
### 3. **Geometry construction** — The main tower is built using a mbCylinder with tapered top, a sphere for the bell, and a ringed base formed from stacked extruded plates. A small dome sits atop the bell, with a few barnacle clusters modeled as low-poly spheres.
### 4. **Body palette** — Uses sand_wet for the base, driftwood_grey for the tower body, kelp_green for the barnacle encrustation, and accent_coral for the bell's brass.
### 5. **uBase marker assignments per surface** — 
| Surface       | uBase |
|---------------|--------|
| Tower body    | 56     |
| Base          | 49     |
| Barnacles     | 0      |
| Bell          | 8      |
### 6. **Base scale (scale_min, scale_max)** — 0.9 to 1.2. Slight variation to avoid repetition while maintaining visual consistency.
### 7. **Y rotation** — Random `0..2π`, to prevent uniform alignment and increase natural variation.
### 8. **Ground anchor** — Partially buried on island surface (y = island_y - 0.2).
### 9. **Procedural variation method** — Instances vary by palette hash and scale spread.
### 10. **Spawn placement rules — which island(s)** — Spawn on D and F (rare). Radius within island: 20–40m. Biome-zone: beach edge. Avoid-list: temples, large rocks, other towers.
### 11. **Spawn count rationale** — With EST_COUNT = 8 and 900m radius, the asset is placed to maintain visual rarity and avoid clutter, consistent with rare ruins.
### 12. **Clustering pattern** — Scattered-grid, spaced to avoid visual monotony.
### 13. **Inter-asset spacing minimum (m)** — 12 meters.
### 14. **Path-clearance distance (m)** — 6 meters.
### 15. **Team color reasoning** — TEAM=68 maps to accent_coral in `game_fill_draws`, matching the brass bell's coloration and enhancing visual contrast.
### 16. **Shadow / contact AO strategy** — Casts shadow with vertex-AO for base contact.
### 17. **Distant-LOD strategy** — Disappears at 150m distance, no LOD applied.
### 18. **Animation, if any** — Static, no animation.
### 19. **Particle FX bound to entity** — None.
### 20. **Lighting interaction** — Sun-side is warm-tinted with sand_wet and driftwood_grey, while mist-side is cool-tinted with kelp-green and accent_coral.
### 21. **Collision** — Blocks player movement; `world.radius = 1.5`.
### 22. **Destructible** — No.
### 23. **Lore hook** — Once a beacon for lost sailors, now a silent reminder of those who sought refuge.
### 24. **Surface UV layout** — Tower body uBase 56, base uBase 49, barnacles default uBase 0, bell emissive uBase 8.
### 25. **Material specularity** — Soft-glossy with emissive-additive on bell.
### 26. **Day/night appearance shift** — Sun-side warm with orange glows, shadow-side cool with blue undertones.
### 27. **Silhouette test at 50 m** — Yes, it remains legible and distinct.
### 28. **Visual neighbours** — Looks right next to `driftwood_pile`, `sea_crate`, and `tide_pool`.
### 29. **Visual conflicts** — Should not spawn near `lighthouse`, `shipwreck`, or `cave_entrance` to avoid silhouette clashing.
### 30. **Implementation hooks** — 
- Add `case 68:` to `world.team` switch in `src/main.zig`.
- Add `makePrayerBellTower(device:)` to `ios/Mesh.swift`.
- Add `dispatchPrayerBellTower` to `ios/GameViewController.swift`.
---

## Asset 133 — tether_chain_long
### 1. **Silhouette at 30m** — A long, sinuous chain hangs from a sky island, curving toward the seabed, forming a dramatic arc with a faint glow at its midpoint.

### 2. **Tri-budget breakdown** — Body: 200 tris, Decorations: 50 tris, FX: 30 tris.

### 3. **Geometry construction** — The main body is a `mbCylinder` with tapering radii from 0.4m to 0.1m, forming a chain link shape. Two `mbSphere` caps are added to each end to denote anchors. Extrusions of small ring segments are used for chain links, arranged in a helical pattern along the cylinder. The construction uses a fan of triangles for chain link detail.

### 4. **Body palette** — water_shallow, foam_white, driftwood_grey, kelp_green. The water_shallow and foam_white are used for the chain's main body, driftwood_grey for anchor points, and kelp_green for subtle surface detailing.

### 5. **uBase marker assignments per surface** —  
| Surface | uBase |
|---------|-------|
| Chain body | 49 |
| Anchor end A | 62 |
| Anchor end B | 0 |
| Chain links | 49 |

### 6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. This range allows for natural variation while maintaining the chain's legibility and preventing it from appearing too rigid or too loose.

### 7. **Y rotation** — aligned-to-island-radial. The chain rotates to face radially toward the island anchor, ensuring a consistent visual relationship with the island's orientation.

### 8. **Ground anchor** — Partially buried, sitting on the seabed at y = -0.4m, with a slight sink to reflect anchoring into the ocean floor.

### 9. **Procedural variation method** — Sub-mesh subset variation. Each chain instance uses a random subset of chain links, with slight UV rotation and color variation to avoid visual repetition.

### 10. **Spawn placement rules — which island(s)** — Spawn on E (Skywatch) and D (The Wreck). Radius within 30m of the island center. Biome zone: boundary ring. Avoid-list: any mesh with `CATEGORY=sky` or `CATEGORY=water`.

### 11. **Spawn count rationale** — With a 900m radius and four chains from G anchor to E, four instances provide adequate distribution while respecting the biome’s spacing and visual density.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid overlapping visual impact, but not too far to maintain thematic coherence.

### 13. **Inter-asset spacing minimum (m)** — 15 meters. Ensures no visual overlap or cluttering.

### 14. **Path-clearance distance (m)** — 7 meters. Chains spawn away from any island path to maintain clear navigation.

### 15. **Team color reasoning** — TEAM=70 aligns with `world.team` switch to denote an environmental structure with a neutral, non-aggressive presence. Resolves to sky_morning in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow and uses vertex-AO to simulate contact with ocean floor, enhancing depth perception.

### 17. **Distant-LOD strategy** — No LOD; the chain remains visible at all distances, consistent with the forest asset policy.

### 18. **Animation, if any** — Static, no animation. The chain remains still to reflect its role as a structural anchor.

### 19. **Particle FX bound to entity** — `kelp_motes` emit from the chain links, gently floating in the ocean depths.

### 20. **Lighting interaction** — Sun-side warm tint with amber glow from `ember_lantern`, shadow-side cool tint with a blue hue from `sky_storm`.

### 21. **Collision** — Does not block player movement. `world.radius` set to 0.3 to allow passage but not to interfere with navigation.

### 22. **Destructible** — No. The chain is an environmental fixture and does not break or fall.

### 23. **Lore hook** — A relic of a forgotten sky-faring civilization, now a tether between worlds.

### 24. **Surface UV layout** — uBase 49 covers the chain body, 62 covers the anchor end A, 0 covers the anchor end B, and 49 covers chain link details.

### 25. **Material specularity** — Soft-glossy. Reflects ambient light subtly, mimicking corroded metal.

### 26. **Day/night appearance shift** — During the day, the chain glows faintly warm with `ember_lantern`. At night, it transitions to a cool blue hue with subtle `sky_storm` tint.

### 27. **Silhouette test at 50 m** — Yes, the chain's arc remains clear and readable, with distinct anchor points and a strong visual silhouette.

### 28. **Visual neighbours** — Looks right next to `sky_island` and `ocean_reef` assets, contributing to a cohesive oceanic and sky-bound ecosystem.

### 29. **Visual conflicts** — Should not spawn near `waterfall`, `island_pillar`, or `sky_bridge` assets, as they would compete for visual attention or overlap in silhouette.

### 30. **Implementation hooks** —  
- Add `case 70: return makeTetherChain(device:)` to `world.team` switch in `src/main.zig`.  
- Add `func makeTetherChain(device: MTLDevice) -> Mesh` to `ios/Mesh.swift`.  
- Add `case 133: return makeTetherChain(device:)` in `ios/GameViewController.swift` dispatch.
---

## Asset 134 — levitating_stone
1. **Silhouette at 30m** — From a distance, the levitating stone appears as a floating, irregularly shaped chunk of rock, with a faint mist trail curling around its base, subtly suggesting movement and ethereal presence in the sky.
2. **Tri-budget breakdown** — Body: 160 tris, Decorations: 30 tris, FX: 30 tris.
3. **Geometry construction** — The body is constructed from a mbCylinder with tapered radii to simulate a smooth, rounded rock shape. A mbSphere is appended to the top to represent a slightly protruding cap, and an extruded ring is added around the middle to create a subtle groove-like texture. The overall form suggests a chunk of weathered stone that has been lifted by a magical force.
4. **Body palette** — The base uses sand_wet for the main surface, driftwood_grey for the top cap, and accent_coral for the mist trail. The entire asset uses a soft, muted tone palette to match the island's serene yet mystical atmosphere.
5. **uBase marker assignments per surface** — Surface 1 (body) → uBase 0, Surface 2 (cap) → uBase 47, Surface 3 (trail) → uBase 62.
6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. The range allows for visual variation without losing the core identity of the floating rock, and ensures compatibility with the island’s scale.
7. **Y rotation** — Random 0..2π. The orientation is randomized to avoid repetitive, predictable layouts across the sky island.
8. **Ground anchor** — Aerial, y = 60. The stone floats 60 meters above the ground, positioned exclusively on island E (Skywatch).
9. **Procedural variation method** — Instance variation is driven by a palette hash and a scale spread, resulting in subtle differences in color intensity and size.
10. **Spawn placement rules — which island(s)** — Spawned only on island E (Skywatch). Radius within 140m, biome-zone: boundary ring. Avoid-list: any mesh with high vertical presence or emissive lighting.
11. **Spawn count rationale** — With 8 instances and a 140m spawn radius, the distribution ensures a sparse yet noticeable presence that complements the sky island’s isolated feel and avoids overcrowding the space.
12. **Clustering pattern** — Scattered-grid. Instances are placed with minimal clustering, maintaining a sense of natural drift and dispersion.
13. **Inter-asset spacing minimum (m)** — 15 meters. Ensures each levitating stone has sufficient visual space to stand out.
14. **Path-clearance distance (m)** — 8 meters. Instances avoid spawning near bridges or paths to maintain clear player movement zones.
15. **Team color reasoning** — TEAM=71 is chosen to blend with the sky island’s palette, resolving to accent_pearl in the `game_fill_draws` switch, matching the soft, luminous tone of the floating island.
16. **Shadow / contact AO strategy** — No shadow cast. A vertex-AO blob is used to suggest the stone's proximity to the sky island’s surface, softening its floating illusion.
17. **Distant-LOD strategy** — No LOD. The asset remains visible at all distances, as forest assets do not use LOD.
18. **Animation, if any** — Static, no animation. The stone remains fixed in position, with only the mist trail gently drifting.
19. **Particle FX bound to entity** — A soft mist trail particle system (`drip_seafoam`) is bound to the base of the stone, simulating a floating, translucent aura.
20. **Lighting interaction** — Sun-side is warm with a slight amber tint; mist-side is cool, taking on a pale blue hue to distinguish it from surrounding mist and sky.
21. **Collision** — Does not block movement. Set `world.radius` to 0.3, as it is a non-solid floating object.
22. **Destructible** — No. The stone is a static, atmospheric element, not meant to be interacted with.
23. **Lore hook** — A remnant of an ancient sky-tether, left behind when the island’s magic was first awakened.
24. **Surface UV layout** — Surface 1 (body) uses uBase 0, Surface 2 (cap) uses uBase 47, Surface 3 (trail) uses uBase 62.
25. **Material specularity** — Soft-glossy. The stone has a slightly reflective surface, enhancing the illusion of being carved from a real, weathered rock.
26. **Day/night appearance shift** — During the day, the stone’s surface is warm and muted; at night, it glows faintly with a soft amber light from the mist trail.
27. **Silhouette test at 50 m** — Yes. The silhouette is still clear and distinct at 50 meters, maintaining readability in the sky island’s wide-open environment.
28. **Visual neighbours** — Looks right next to `floating_coral`, `driftwood_pile`, and `sky_dome`, forming a cohesive sky island atmosphere.
29. **Visual conflicts** — Should not be placed near large, emissive or highly reflective assets, as it would clash with the mist and luminous tone of the floating trail.
30. **Implementation hooks** — In `src/main.zig`, add `case 71: return .levitating_stone` to the `world.team` switch. In `ios/Mesh.swift`, add `func makeLevitatingStone(device: MTLDevice) -> MeshBuffers` and call it in the dispatch. In `ios/GameViewController.swift`, add `case 134: mesh = makeLevitatingStone(device: device)` to the mesh dispatch.

```metal
float3 mist_color = mix(mist_low, ember_lantern, sin(time * 0.5));
```
---

## Asset 135 — cloud_garden_patch
### 1. Silhouette at 30m
A floating patch of cloud with kelp tendrils extends outward from the sky island E, appearing as a soft, irregular disc with trailing green tendrils.

### 2. Tri-budget breakdown
Body: 160 tris; Decorations: 40 tris; FX: 40 tris.

### 3. Geometry construction
The base is a large, slightly tapered mbSphere to form the cloud body, with several mbCylinder extrusions for the kelp tendrils. These are arranged radially around the sphere's surface and extend downward. A few mbSpheres are used to add small, rounded nodes along the kelp to suggest branching.

### 4. Body palette
Uses foam_white (cloud base), kelp_green (tendrils), mist_low (soft edge blend), and accent_pearl (highlighted tendril tips).

### 5. uBase marker assignments per surface
| Surface         | uBase |
|-----------------|-------|
| Cloud body      | 0     |
| Kelp tendrils   | 59    |
| Kelp nodes      | 55    |
| Emissive tips   | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. Justification: allows for visual variation while maintaining consistent density and readability in the sky biome.

### 7. Y rotation
Random `0..2π` rotation to vary orientation across instances.

### 8. Ground anchor
Floating in the shallows at y = -0.4, suspended above the surface of the lagoon near island E.

### 9. Procedural variation method
Two instances differ by scale variation and slight color variation in the kelp tendrils via palette hash.

### 10. Spawn placement rules — which island(s)
Spawn only on island E (Skywatch), within 50m radius. Biome-zone: boundary ring. Avoid-list: any mesh with similar vertical profile or floating geometry.

### 11. Spawn count rationale
With a 900m radius zone and ISLAND_BIAS E, EST_COUNT = 4 ensures minimal overlap and optimal visual distribution across the sky island's edge without overcrowding.

### 12. Clustering pattern
Scattered-grid pattern with 10–15m spacing between instances.

### 13. Inter-asset spacing minimum (m)
Minimum 10m spacing to other instances of the same mesh.

### 14. Path-clearance distance (m)
Path clearance: 8m from the ISLAND-LOCAL path (as it's near a sky bridge).

### 15. Team color reasoning
TEAM=72 maps to a soft, warm tint of mist_low, which enhances the atmospheric feel of the sky island. This team color allows for distinct yet harmonious visual grouping with nearby floating assets.

### 16. Shadow / contact AO strategy
Casts a soft shadow at a distance; no ground AO blob. Uses vertex AO for soft contact with the lagoon surface.

### 17. Distant-LOD strategy
No LOD — the asset is too visually significant to simplify at distance. Matches forest asset behavior.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None. The asset is self-contained without FX.

### 20. Lighting interaction
Sun-side appears with a warm, golden tint; mist-side has a cooler, blue-tinged appearance due to ambient light interaction.

### 21. Collision
Does not block movement. world.radius = 0.3.

### 22. Destructible
No. Default behavior.

### 23. Lore hook
A remnant of an ancient sky garden, now drifting free after the collapse of the upper island’s support structures.

### 24. Surface UV layout
Cloud body uses uBase 0, tendrils use uBase 59, nodes use uBase 55, and emissive tips use uBase 8.

### 25. Material specularity
Soft-glossy with subtle refractive qualities on the cloud surface and matte on the kelp tendrils.

### 26. Day/night appearance shift
During the day, the cloud is warm and glowing; at night, it appears cool and slightly translucent with faint ambient glows.

### 27. Silhouette test at 50 m
Yes, the silhouette remains readable at 50m, with clear distinction between the cloud and tendrils.

### 28. Visual neighbours
Looks right next to floating bridges, misty cliffs, and distant lanterns. Complements the sky island's surreal and dreamlike atmosphere.

### 29. Visual conflicts
Should not appear near dense vegetation or other floating structures with high silhouette contrast, as it may visually clash or become buried in the scene.

### 30. Implementation hooks
- Add `case 72:` to `world.team` switch in `src/main.zig`.
- Add `func makeCloudGardenPatch(device:)` in `ios/Mesh.swift`.
- Add `case 135:` to `dispatch` in `ios/GameViewController.swift`.
---

## Asset 136 — wind_chime_array
### 1. **Silhouette at 30m** — From across the lagoon, a vertical, slender array of wind chimes appears as a delicate, tiered column of shimmering light, evoking a celestial chime or a floating constellation.

### 2. **Tri-budget breakdown** — 120 body triangles, 40 decorations, 20 FX particles. Total: 180 tris.

### 3. **Geometry construction** — The base uses a `mbCylinder` for the main pole, with a `mbSphere` for the top resonant chamber. Extruded ring elements are added around the pole to simulate chime clusters, and a fan of triangles forms the wind-sensitive base. The structure is built using stacked plates to create the chime segments.

### 4. **Body palette** — Uses `sail_cream`, `accent_pearl`, `kelp_green`, and `driftwood_grey` to reflect a blend of maritime and ambient elements.

### 5. **uBase marker assignments per surface** —  
| Surface        | uBase |
|----------------|-------|
| Main pole      | 0     |
| Chime clusters | 8     |
| Resonant chamber | 58  |

### 6. **Base scale (scale_min, scale_max)** — 0.8 to 1.2. This variation allows for visual diversity without altering the vertical profile or resonance behavior.

### 7. **Y rotation** — Random `0..2π`. Each instance is independently rotated to prevent uniform alignment.

### 8. **Ground anchor** — Sits on island surface (y=island_y). The base is fully grounded to the terrain.

### 9. **Procedural variation method** — Instances differ by scale spread and palette hash (based on position and instance ID), affecting color intensity and size of chime segments.

### 10. **Spawn placement rules — which island(s)** — Spawns primarily on E (Skywatch) and A (Lantern Hold). Radius within island: 10–40m. Biome-zone: Beach edge. Avoid-list: Temple plaza, cliff face.

### 11. **Spawn count rationale** — With 6 instances per zone and 900m radius, the count balances visual impact with performance. The low density ensures no visual clutter while maintaining a sense of presence in open sky areas.

### 12. **Clustering pattern** — Scattered-grid. Instances spaced to avoid visual overlap while maintaining a natural, organic feel.

### 13. **Inter-asset spacing minimum (m)** — 12 meters. Prevents clustering and ensures each chime array stands out individually.

### 14. **Path-clearance distance (m)** — 8 meters. Ensures no obstruction to the main paths of A and E islands.

### 15. **Team color reasoning** — TEAM=70 maps to `accent_coral` in `game_fill_draws`, a warm, resonant tone that complements the sky island’s ambiance and makes it visually distinct from ambient forest assets.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow and applies vertex-AO to ground contact points for subtle depth.

### 17. **Distant-LOD strategy** — Disappears at 80m distance. No LOD is used, as the vertical profile remains visually distinct and meaningful.

### 18. **Animation, if any** — Static, no animation. The chimes are purely visual, intended to resonate with wind and ambient lighting.

### 19. **Particle FX bound to entity** — None. The chimes do not emit FX.

### 20. **Lighting interaction** — Sun-side warm tint, shadow-side cool tint. This creates a natural contrast in lighting and enhances the sense of presence.

### 21. **Collision** — Does not block movement. `world.radius` = 0.3, small enough to not impede player traversal.

### 22. **Destructible** — No. The asset is static and cannot be destroyed.

### 23. **Lore hook** — These chimes were left behind by the Skywatchers, their melodies said to guide lost souls back to the islands.

### 24. **Surface UV layout** — uBase 0 covers the main pole, uBase 8 covers the chime clusters, and uBase 58 covers the resonant chamber.

### 25. **Material specularity** — Soft-glossy. Reflects ambient light and gives a subtle shimmer without being overly reflective.

### 26. **Day/night appearance shift** — Sun-side warm tint (accent_coral), shadow-side cool tint (sky_storm). This provides a dynamic feel as the sun moves.

### 27. **Silhouette test at 50 m** — Yes. The vertical array remains clearly visible and distinct at half the average view distance.

### 28. **Visual neighbours** — Looks right next to `kelp_cluster`, `driftwood_pile`, and `sky_crane`, forming a cohesive sky-island theme.

### 29. **Visual conflicts** — Should not be near `lantern_pole`, `sky_tower`, or `firefly_cluster`, as these would visually compete or obscure its form.

### 30. **Implementation hooks** — 
- Add `case 70` to `world.team` switch in `src/main.zig`.
- Add `makeWindChimeArray(device:)` function in `ios/Mesh.swift`.
- Add dispatch case for `wind_chime_array` in `ios/GameViewController.swift`.
---

## Asset 137 — lantern_post_isle
### 1. Silhouette at 30m
From across the lagoon, the lantern post appears as a tall, vertical tapering silhouette with a small glowing orb at its apex, standing out against the horizon like a beacon.

### 2. Tri-budget breakdown
The mesh is composed of 180 tris for the main body, 60 tris for decorative rings, and 40 tris for the ember flame effect, totaling 280 tris.

### 3. Geometry construction
The lantern body is built using `mbCylinder` to form a tapered iron pole, with `mbSphere` for the glass lantern globe atop. Additional geometry includes extruded rings around the pole to simulate iron struts and a small flame mesh using a fan of triangles for the ember.

### 4. Body palette
The main pole uses `driftwood_grey` and `accent_pearl`, the glass globe uses `sail_cream`, and the ember flame uses `ember_lantern`.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Pole           | 0     |
| Glass Globe    | 57    |
| Decorative Rings | 8   |
| Ember Flame    | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. Justification: Ensures visual variation without overwhelming the island’s natural scale while maintaining legibility at distance.

### 7. Y rotation
Random `0..2π`. Rotation is not constrained to any direction, allowing for natural island placement.

### 8. Ground anchor
The lantern sits partially buried (0.3m deep) into the sand to simulate weathering and grounding.

### 9. Procedural variation method
Variation is achieved through palette hash and slight scale spread to prevent visual repetition across instances.

### 10. Spawn placement rules — which island(s)
Spawns on islands A, D, F. Radius within island: 40–100m. Biome zone: beach edge. Avoid-list: temple plaza, boundary ring.

### 11. Spawn count rationale
With a 900m radius and ISLAND_BIAS, 32 instances are sufficient to ensure even distribution while avoiding overcrowding in the most populated zones (A, D, F).

### 12. Clustering pattern
Scattered-grid. Instances are placed in loose formations, spaced to avoid visual crowding but maintain group feel.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters from another lantern post.

### 14. Path-clearance distance (m)
5 meters from the nearest island path (as paths are not aligned with this asset).

### 15. Team color reasoning
TEAM=73 maps to `accent_coral` in `game_fill_draws`. Coral is chosen for its warm, eye-catching tone that contrasts the cool island palette and highlights the lantern’s presence.

### 16. Shadow / contact AO strategy
Casts a soft shadow and uses vertex AO for contact with sand and ground.

### 17. Distant-LOD strategy
Does not use LOD. Forest assets do not fade out at distance.

### 18. Animation, if any
Static, no animation. The flame is purely emissive and does not move.

### 19. Particle FX bound to entity
None. The ember flame is emissive and not tied to a particle emitter.

### 20. Lighting interaction
Sun-side appearance is warm and glowing, with a slight tint of `ember_lantern` on the glass globe; shadow-side appears cooler, with subtle `sky_storm` tinting on the pole.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.3m, allowing for minimal collision but not full obstruction.

### 22. Destructible
No. The lantern is a static environmental asset.

### 23. Lore hook
A relic from the old sea-faring age, left behind to guide travelers through the drifting isles.

### 24. Surface UV layout
The pole uses uBase 0, the glass globe uses uBase 57, the rings use uBase 8, and the ember flame uses uBase 8.

### 25. Material specularity
Soft-glossy for the pole, glossy for the glass globe, and emissive-additive for the flame.

### 26. Day/night appearance shift
During the day, the lantern appears warm and bright; at night, the glass globe glows more intensely with a golden-orange tint.

### 27. Silhouette test at 50 m
Yes, it remains a clear vertical form with a glowing orb at the apex, readable at half the average view distance.

### 28. Visual neighbours
Looks best next to `tree_palm` and `shipwreck_hull`, as they provide complementary vertical and horizontal scale to the scene.

### 29. Visual conflicts
Should not appear near `tower` or `statue`, as their scale and silhouette would clash with the lantern’s delicate profile.

### 30. Implementation hooks
- In `src/main.zig`, add case `73: .lantern_post_isle` to the `world.team` switch.
- In `ios/Mesh.swift`, add `makeLanternPostIsle(device:)` function.
- In `ios/GameViewController.swift`, add dispatch case for `lantern_post_isle` in `spawnAsset(_:)`.
---

## Asset 138 — signal_buoy_floating
1. **Silhouette at 30m** — From across the lagoon, the signal buoy appears as a tall, slender vertical silhouette with a lantern-lit dome and a bell-shaped accent, standing out against the island rim.
2. **Tri-budget breakdown** — Body: 140 tris; Decorations: 50 tris; FX: 30 tris.
3. **Geometry construction** — The buoy body is a tapered cylinder with a slight outward flare to mimic a floating shape, using `mbCylinder`. A lantern dome is formed with `mbSphere` on top, and a bell accent is created as a stacked ring with extruded geometry. Additional minor details like lashing straps and a small flag pole are added with fan-of-triangles.
4. **Body palette** — The main body uses sand_wet (for the wooden sections), driftwood_grey (for the rope lashing), and foam_white (for the wet surface highlights). Accent elements use sail_cream (for the lantern rim) and accent_pearl (for the bell’s metallic sheen).
5. **uBase marker assignments per surface** — Body (0), Lantern dome (57), Bell (49), Rope lashing (8), Flag pole (0).
6. **Base scale (scale_min, scale_max)** — Scale range is 1.0 to 1.2. This allows for subtle variation in buoy size to prevent repetition, while maintaining visual consistency.
7. **Y rotation** — Random `0..2π`. The buoy rotates freely to simulate drifting.
8. **Ground anchor** — Partially buried, sitting on the island surface with a y_offset of -0.4 to simulate shallow water immersion.
9. **Procedural variation method** — Instances vary by scale spread and palette hash, adjusting the color intensity and rope lashing pattern.
10. **Spawn placement rules — which island(s)** — Spawn on islands A, B, C, D, and F. Radius within island: 5–15 m. Biome-zone: beach edge. Avoid-list: temple plaza, boundary ring.
11. **Spawn count rationale** — The 18 instances match the expected density of signal buoys along island perimeters, spread across a 900m radius with 3 buoys per island rim for visual consistency.
12. **Clustering pattern** — Scattered-grid. Buoy placement avoids tight clusters, allowing for natural drift and visual spacing.
13. **Inter-asset spacing minimum (m)** — 8 meters.
14. **Path-clearance distance (m)** — 6 meters from any island path.
15. **Team color reasoning** — TEAM=74 maps to accent_coral in the `game_fill_draws` switch, giving the asset a warm, visible contrast against the sea and sand, aiding in navigation.
16. **Shadow / contact AO strategy** — Casts a soft shadow with a ground AO blob to simulate the buoy’s immersion in shallow water.
17. **Distant-LOD strategy** — No LOD; the asset remains detailed at all distances, consistent with the forest’s asset policy.
18. **Animation, if any** — Static, no animation. The buoy remains motionless to reflect the calm nature of the signal post.
19. **Particle FX bound to entity** — None. However, a subtle `lantern_glow` emitter can be bound to the lantern dome.
20. **Lighting interaction** — Sun-side appears with a warm, amber tint from the lantern glow, while shadow-side takes a cooler, blue-tinged tone from the ocean mist.
21. **Collision** — Does not block player movement. `world.radius` is set to 0.4 to allow passage.
22. **Destructible** — No. The buoy is a static environmental asset.
23. **Lore hook** — It serves as a beacon for lost sailors, its bell chiming softly in the wind to warn of approaching storms.
24. **Surface UV layout** — uBase 0 covers the main body, 57 covers the lantern dome, 49 covers the bell, 8 covers rope lashing, and 0 is used for the flag pole.
25. **Material specularity** — Soft-glossy, with slight reflective properties on the lantern dome and bell to simulate wet, metallic surfaces.
26. **Day/night appearance shift** — During the day, the buoy appears warm and golden with sun highlights. At night, the lantern emits a soft ember glow, shifting the entire asset to a more ambient, warm hue.
27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and distinct even at half the average view distance.
28. **Visual neighbours** — Looks right next to `driftwood_log`, `island_rock`, and `tide_pool`, creating a cohesive beachfront scene.
29. **Visual conflicts** — Should not be placed near `lighthouse_tower`, `shipwreck`, or `cave_entrance`, as these assets would compete for visual attention.
30. **Implementation hooks** — Add `case 74: return makeSignalBuoy(device:)` in `world.team` switch in `src/main.zig`. Add `func makeSignalBuoy(device:)` in `ios/Mesh.swift`. Add `case 138: return signalBuoy` in `dispatch` in `ios/GameViewController.swift`.
---

## Asset 139 — lighthouse_short
### 1. **Silhouette at 30m** — The lighthouse appears as a tall, narrow silhouette with a rotating ember beam that sweeps across the water, making it visible from across the lagoon.

### 2. **Tri-budget breakdown** — The body is 400 tris, decorations are 120 tris, and FX (beam) is 60 tris, totaling 580 tris.

### 3. **Geometry construction** — The main body is built using a tapered mbCylinder with a smooth taper from base to top. A mbSphere is added at the top for the lantern dome, and extrusions form the beacon beam and decorative rings. The structure is composed of stacked plates and a fan of triangles for the roof.

### 4. **Body palette** — Uses sand_wet for the main structure, driftwood_grey for the railing, accent_pearl for the lantern dome, and foam_white for the beacon ring.

### 5. **uBase marker assignments per surface** —  
| Surface           | uBase |
|-------------------|-------|
| Body              | 0     |
| Lantern dome      | 56    |
| Railing           | 57    |
| Beacon ring       | 8     |

### 6. **Base scale (scale_min, scale_max)** — scale_min = 0.9, scale_max = 1.1. This allows for subtle variation in height and width to avoid repetition while maintaining the asset’s functional shape.

### 7. **Y rotation** — Aligned-to-island-radial. Each instance rotates to point toward the center of its assigned island, enhancing orientation with the surrounding landscape.

### 8. **Ground anchor** — Sits on island surface (y=island_y) with slight submersion to simulate wet sand.

### 9. **Procedural variation method** — 2 instances differ by palette hash, which alters the surface coloration of the body and railings to reflect different environmental conditions.

### 10. **Spawn placement rules — which island(s)** — Spawns on A, D, F (per ISLAND_BIAS). Radius within island is 15–30m. Biome-zone is beach edge or cliff face. Avoid-list includes bridges, temples, and other tall structures.

### 11. **Spawn count rationale** — EST_COUNT = 4 is appropriate given the 900m radius of the islands and the need to ensure visual diversity without overcrowding. It supports a balanced distribution of light sources.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed with even spacing to prevent clustering, maintaining a natural look across the landscape.

### 13. **Inter-asset spacing minimum (m)** — 15m minimum distance from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 6m from the ISLAND-LOCAL path. Bridges are exempt from clearance rules.

### 15. **Team color reasoning** — TEAM=75 resolves to sky_morning in `game_fill_draws`. This color scheme allows the lighthouse to blend with the sky during the day while maintaining visibility.

### 16. **Shadow / contact AO strategy** — Casts shadow. Ground AO blob is used to simulate soft shadowing under the structure.

### 17. **Distant-LOD strategy** — No LOD. The asset remains full-res up to 1000m, consistent with forest assets that do not use distance-based simplification.

### 18. **Animation, if any** — Static, no animation. The ember beam is simulated via particle FX, not vertex or mesh animation.

### 19. **Particle FX bound to entity** — `lantern_glow` emitter used to simulate the rotating ember beam.

### 20. **Lighting interaction** — Sun-side is warm-toned with amber hues, while mist-side is cool-toned with blue undertones.

### 21. **Collision** — Yes, it blocks player movement. `world.radius` is set to 1.2.

### 22. **Destructible** — No. The asset is a static landmark and does not break.

### 23. **Lore hook** — A relic of the old sea-faring civilization, now abandoned but still guiding ships through treacherous waters.

### 24. **Surface UV layout** — The body uses uBase 0, lantern dome uses 56, railing uses 57, and beacon ring uses 8.

### 25. **Material specularity** — Soft-glossy. The surfaces have a subtle sheen to reflect the ocean light.

### 26. **Day/night appearance shift** — During the day, the lighthouse appears warm with golden tones; at night, the beam glows with ember_lantern, creating a striking contrast.

### 27. **Silhouette test at 50 m** — Yes, it remains distinct and readable at 50m, with a clear vertical profile and glowing beam.

### 28. **Visual neighbours** — Looks right next to `driftwood`, `beach_coral`, and `whale_bone` assets, forming a cohesive coastal scene.

### 29. **Visual conflicts** — Should not spawn near `tall_palm`, `cliff_tower`, or `temple_spire` as these would compete for visual attention and silhouette clarity.

### 30. **Implementation hooks** —  
- Add `case 75:` to `world.team` switch in `src/main.zig`  
- Add `makeLighthouseShort(device:)` in `ios/Mesh.swift`  
- Add `case 139:` to `dispatchMesh` in `ios/GameViewController.swift`
---

## Asset 140 — brazier_with_pyre
1. **Silhouette at 30m** — From across the lagoon, a tall, tapering ember-orange pyre rises like a glowing beacon from the island’s surface, its shape defined by a vertical stone base and a curved flame-drenched crown.

2. **Tri-budget breakdown** — Body: 180 tris, Decorations: 60 tris, FX: 40 tris.

3. **Geometry construction** — The base is constructed from a tapered mbCylinder with a radius of 0.6 and height of 0.4, using a low ring count. A spherical mbSphere with radius 0.2 is stacked atop it to form the pyre crown. An extruded ring around the base adds a decorative rim, and a fan of triangles outlines the pyre’s inner flame.

4. **Body palette** — The base uses driftwood_grey for the stone, accent_coral for the rim, and ember_lantern for the flame glow. The pyre crown uses sand_wet for texture and accent_pearl for highlights.

5. **uBase marker assignments per surface** — 
| Surface      | uBase |
|--------------|-------|
| Base         | 0     |
| Rim          | 57    |
| Crown        | 8     |
| Flame        | 8     |

6. **Base scale (scale_min, scale_max)** — Scale range 0.9 to 1.2. Justification: slight scale variance ensures visual diversity while maintaining architectural coherence in the forested setting.

7. **Y rotation** — Random `0..2π`. Each instance is rotated independently for natural spread across the island.

8. **Ground anchor** — Sits on island surface (y=island_y). The base is fully planted, with no burial or elevation.

9. **Procedural variation method** — Instances differ by palette hash and scale spread. Each instance uses a hash-based color shift to vary the rim and crown.

10. **Spawn placement rules — which island(s)** — Spawn on islands A, D, E, F. Radius within island: 15–30m. Biome-zone: beach edge, cliff face, boundary ring. Avoid-list: bridges, temple plazas, other fire-related assets.

11. **Spawn count rationale** — The total spawn count of 14 is appropriate for a 900m radius and ISLAND_BIAS, ensuring a balanced distribution across multiple islands with enough presence to be meaningful without overcrowding.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid dense clustering but not overly isolated.

13. **Inter-asset spacing minimum (m)** — 6 meters minimum from another instance of the same mesh.

14. **Path-clearance distance (m)** — 6 meters from island-local paths. Bridges are excluded from clearance.

15. **Team color reasoning** — TEAM=76 is chosen to align with a warm, amber-tinted color palette for fire-related elements. Resolves to ember_lantern in the `game_fill_draws` switch.

16. **Shadow / contact AO strategy** — Casts a soft shadow using vertex AO. Ground AO blob is used for contact with the island surface.

17. **Distant-LOD strategy** — No LOD. Forest assets do not simplify at distance.

18. **Animation, if any** — Static, no animation.

19. **Particle FX bound to entity** — `pyre_sparks` emitter is bound to the pyre crown for subtle flicker.

20. **Lighting interaction** — Sun-side appearance is warm with a tint of ember_lantern. Mist-side appearance is cool, with a slight shift toward sky_morning.

21. **Collision** — Blocks player movement. `world.radius` is set to 0.5.

22. **Destructible** — No. Default static asset.

23. **Lore hook** — A remnant of an ancient ritual site, where the pyre was lit to guide lost souls home.

24. **Surface UV layout** — Base uses uBase 0; rim uses uBase 57; crown and flame use uBase 8.

25. **Material specularity** — Soft-glossy. The base has slight reflectance, while the flame is emissive-additive.

26. **Day/night appearance shift** — Sun-side warm tint with ember_lantern dominance. Night-side cool tint, with a slight blue hue from ambient lighting.

27. **Silhouette test at 50 m** — Yes, the silhouette remains distinct and recognizable at 50 meters, with sufficient contrast and vertical profile.

28. **Visual neighbours** — Looks right next to `forest_torch`, `island_cairn`, and `driftwood_pile`.

29. **Visual conflicts** — Should not spawn near `portal_entrance`, `fire_pit`, or `temple_altar`, as these would compete visually.

30. **Implementation hooks** — 
- Add `case 76: return .brazier_with_pyre` in `world.team` switch in `src/main.zig`.
- Add `func makeBrazierWithPyre(device: MTLDevice) -> Mesh` in `ios/Mesh.swift`.
- Add `case .brazier_with_pyre: dispatchMesh(.brazierWithPyre)` in `ios/GameViewController.swift`.
---

## Asset 141 — kelp_pillar_titan
1. **Silhouette at 30m** — From across the lagoon, the kelp pillar appears as a tall, vertical dark green column with a slight taper and a few branching appendages, barely distinguishable from the surrounding sea in the shallow water.

2. **Tri-budget breakdown** — Body: 300 tris; Decorations: 60 tris; FX: 20 tris.

3. **Geometry construction** — The main body is built with a `mbCylinder` with tapered radii, starting wide at the base and narrowing to a point at the top. A `mbSphere` is placed at the top to form a rounded cap. Extruded rings and small appendages are added using a fan of triangles for lateral growth. The structure is assembled in a static cluster with a base mesh and a few sub-meshes for surface detail.

4. **Body palette** — The main body uses `kelp_green` for the core, `water_shallow` for the base where it meets the sea, `sand_wet` for the bottom ring where it contacts the seabed, and `foam_white` for the topmost tips to simulate sea foam.

5. **uBase marker assignments per surface** — 

| Surface         | uBase |
|-----------------|-------|
| Base            | 55    |
| Body            | 47    |
| Top cap         | 55    |
| Appendages      | 47    |
| Foam tips       | 55    |

6. **Base scale (scale_min, scale_max)** — `scale_min = 0.8`, `scale_max = 1.3`. Slight variation allows for visual diversity without breaking the titanic theme or cluttering the zone.

7. **Y rotation** — Random `0..2π`. Rotations are not aligned to any specific axis, to create naturalistic placement.

8. **Ground anchor** — Partially buried, with the base sitting 0.4m below the island surface to simulate it emerging from the sea floor.

9. **Procedural variation method** — Scale spread and color palette hash. Variants differ in overall size and slight shifts in color saturation to reflect kelp diversity.

10. **Spawn placement rules — which island(s)** — Spawns on islands A, B, C, D, F only. Radius within island: 890m. Zone: boundary ring. Avoid-list: E (Skywatch), which is too high and aerial for this type of structure.

11. **Spawn count rationale** — With a 900m radius and 90 instances, this gives an average of 1 instance per 100m², which matches the density of large kelp formations near the island boundaries, especially around shallow water edges.

12. **Clustering pattern** — Scattered-grid. Instances are placed in a loose grid pattern to avoid overly dense clusters, allowing for natural-looking spacing.

13. **Inter-asset spacing minimum (m)** — 12m minimum spacing from another instance of the same mesh.

14. **Path-clearance distance (m)** — 6m from any island-local path. This ensures no interference with bridges or walking areas.

15. **Team color reasoning** — TEAM=64 is chosen to align with the “titanic” kelp theme. It resolves to `kelp_green` in the `game_fill_draws` switch, matching the dominant color of the structure.

16. **Shadow / contact AO strategy** — Casts a soft shadow. Ground AO blob is used to simulate the contact with the seabed, and vertex AO is applied to the inner surface for depth.

17. **Distant-LOD strategy** — No LOD. Like other forest assets, it remains detailed at all distances, as its scale and silhouette are designed for visibility at 30–50m.

18. **Animation, if any** — Static, no animation. The pillar sways slightly in the wind but not in a visible or scripted way.

19. **Particle FX bound to entity** — `drip_seafoam` emitter bound to top surface for a light sea foam drip effect.

20. **Lighting interaction** — Sun-side appears warm with a green tint, shadow-side is cooler with a blue-green hue, enhancing the aquatic feel.

21. **Collision** — Yes, it blocks movement. `world.radius = 1.2` to match its substantial bulk and prevent players from walking through it.

22. **Destructible** — No. The structure is meant to be a permanent environmental feature.

23. **Lore hook** — The towering kelp pillar is said to be a remnant of an ancient sea god’s temple, now grown into a living monument beneath the waves.

24. **Surface UV layout** — uBase 55 covers base and foam tips; uBase 47 covers the body and appendages. The top cap uses uBase 55 with a different UV offset for texture variation.

25. **Material specularity** — Soft-glossy. Reflects light subtly to mimic the wet, oceanic surface of kelp.

26. **Day/night appearance shift** — During the day, the surface appears warm and green; at night, it takes on a cooler, almost glowing tone with subtle blue undertones.

27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and recognizable, with the taper and branching appendages still visible.

28. **Visual neighbours** — Looks right next to `kelp_reef`, `driftwood`, and `sea_coral` on the beach edge, enhancing the aquatic environment.

29. **Visual conflicts** — Should not spawn near `sea_coral`, `driftwood`, or `floating_raft` structures, as these would clash in silhouette and density.

30. **Implementation hooks** — Add `case 64: return makeKelpPillarTitan(device:)` to `world.team` switch in `src/main.zig`. Add `func makeKelpPillarTitan(device: MTLDevice) -> MeshBuffers` in `ios/Mesh.swift`. Add `case 141: return makeKelpPillarTitan(device:)` in `dispatchMesh` in `ios/GameViewController.swift`.
---

