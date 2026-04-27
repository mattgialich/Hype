# Desert Zone Design Specification

Generated 2026-04-27. Engine target: Hype / Mach5Game iOS, Metal + Zig + Swift.
Foundation doc — per-enemy and per-asset detail passes append below.

---

## §1. Biome overview

The Desert is a vast, sun-scorched expanse of shifting dunes and bleached ruins. The sky is a high-contrast wash from amber haze at the horizon to a deep cobalt zenith, with thin cirrus dust streaks. The sun sits low and harsh, throwing long warm shadows across rippled sand. Materials are dominated by warm bone-white and pale-amber sand, weathered sandstone, dry chitin, and rare bursts of cool turquoise where buried springs surface as oases. The mood is loneliness and weight: a place older than the forest, where civilisations rose and were swallowed. References: Sahara, American Southwest hoodoos, Wadi Rum, the half-buried Sphinx of Dune (1984).

---

## §2. Scale & layout

| Constant         | Forest (existing) | Desert (this doc) |
|------------------|-------------------|-------------------|
| `MAP_RADIUS`     | 280 m             | **450 m**         |
| `PATH_LEN`       | 220 m             | **360 m**         |
| Boundary marker  | 48 monoliths @ r=275 | **64 desert obelisks @ r=440** |
| Set-piece count  | ~2150             | **~2400**         |

### Path centerline formula

The shape is the same as the forest — `env(t) · (A·sin(z·ω₁) + B·cos(z·ω₂))` — but with **distinct coefficients** so the desert wind path feels longer-wavelength and more sweeping than the forest's tighter twists.

| Coefficient | Forest | Desert |
|-------------|--------|--------|
| A           | 20.0   | **32.0** |
| ω₁          | 0.045  | **0.030** |
| B           | 8.0    | **10.0** |
| ω₂          | 0.075  | **0.050** |

Both `path_center_x()` in `src/main.zig` AND the matching block in `shaders/world.metal` must use these constants. **Any change to the formula MUST be applied to both files in the same commit.**

`env(t) = 4·t·(1−t)`, `t = clamp(−z / PATH_LEN, 0, 1)`. Identical to forest.

### Boundary

64 desert obelisks at radius 440 m, spaced at 5.625° intervals (vs forest's 7.5°). Hard wall in `game_update` should activate at radius 445 m so the obelisks remain visible just outside the wall.

---

## §3. Palette

12-swatch palette. All values are linear-RGB in 0..1.

| Swatch              | RGB                | Role |
|---------------------|--------------------|------|
| `sand_light`        | (0.95, 0.85, 0.70) | base sand top |
| `sand_dark`         | (0.75, 0.60, 0.45) | dune lee side, displaced sand |
| `dune_shadow`       | (0.40, 0.30, 0.25) | deep dune valleys, occluded crevices |
| `sky_horizon`       | (0.95, 0.70, 0.40) | low-altitude amber haze (sky shader) |
| `sky_zenith`        | (0.30, 0.45, 0.85) | upper sky cobalt |
| `rock_warm`         | (0.78, 0.58, 0.42) | sandstone, hoodoos |
| `rock_cool`         | (0.50, 0.50, 0.58) | weathered grey rock, deep mesa |
| `dry_vegetation`    | (0.58, 0.50, 0.32) | cactus skin, desiccated brush |
| `accent_gold`       | (0.95, 0.78, 0.30) | shrine trim, glyph emissive |
| `accent_turquoise`  | (0.30, 0.78, 0.78) | oasis water, healthy reeds |
| `bone_pale`         | (0.92, 0.88, 0.78) | fossils, sphinx face, scorpion shell highlights |
| `ember_orange`      | (0.95, 0.45, 0.10) | brazier flame, scorpion eyes, signal fires |

---

## §4. Mesh-ID assignment table

Mesh IDs **29–66** (38 entries). 29–33 are enemies, 34–65 are scenery assets, 66 is the boundary obelisk.

| mesh_id | name                 | category    | est_tris | est_count | uBase markers           | teams      |
|---------|----------------------|-------------|----------|-----------|-------------------------|------------|
| 29      | sand_scorpion        | enemy       | 1200     | 30        | 0, 8, 43                | 1          |
| 30      | sand_wraith          | enemy       | 800      | 16        | 0, 8, 44                | 1          |
| 31      | desert_husk          | enemy       | 1500     | 8         | 0, 8, 30, 32            | 1          |
| 32      | carrion_spider       | enemy       | 900      | 30        | 0, 8, 43                | 1          |
| 33      | mirage_phantom       | enemy       | 600      | 4         | 0, 8, 39                | 1          |
| 34      | dune_large           | dune        | 380      | 240       | 30, 31                  | 40         |
| 35      | dune_small           | dune        | 220      | 280       | 30, 31                  | 40         |
| 36      | ripple_patch         | dune-decal  | 120      | 200       | 30                      | 40         |
| 37      | crack_patch          | sand-decal  | 100      | 140       | 32                      | 41         |
| 38      | sandstone_spire      | rock        | 480      | 80        | 0, 36                   | 42         |
| 39      | sandstone_arch       | rock        | 540      | 50        | 0, 36                   | 42         |
| 40      | weathered_boulder    | rock        | 280      | 100       | 0                       | 43         |
| 41      | mesa_flat            | rock        | 360      | 50        | 0, 36                   | 42         |
| 42      | hoodoo               | rock        | 320      | 80        | 0, 36                   | 42         |
| 43      | rib_arch             | bone        | 380      | 30        | 0, 37                   | 44         |
| 44      | skull_pile           | bone        | 280      | 50        | 0, 37                   | 44         |
| 45      | vertebra_chunk       | bone        | 220      | 50        | 0, 37                   | 44         |
| 46      | fossil_shell         | bone        | 200      | 30        | 0, 37, 41               | 44         |
| 47      | saguaro_cactus       | vegetation  | 320      | 130       | 0, 8                    | 45         |
| 48      | barrel_cactus        | vegetation  | 240      | 100       | 0, 8                    | 45         |
| 49      | dead_brush           | vegetation  | 140      | 180       | 0                       | 46         |
| 50      | tumbleweed_static    | vegetation  | 180      | 80        | 0                       | 46         |
| 51      | oasis_pool           | oasis       | 320      | 8         | 0, 34                   | 47         |
| 52      | palm_tall            | oasis       | 380      | 14        | 0, 35                   | 48         |
| 53      | palm_short           | oasis       | 280      | 14        | 0, 35                   | 48         |
| 54      | reed_cluster         | oasis       | 160      | 20        | 0, 35                   | 48         |
| 55      | broken_column        | ruin        | 240      | 40        | 0, 36, 40               | 49         |
| 56      | half_buried_obelisk  | ruin        | 280      | 20        | 0, 36, 40               | 49         |
| 57      | sphinx_head          | ruin        | 1100     | 3         | 0, 36, 37, 40           | 49         |
| 58      | ruined_arch          | ruin        | 380      | 25        | 0, 36, 40               | 49         |
| 59      | glyph_wall           | ruin        | 320      | 30        | 0, 36, 40               | 49         |
| 60      | desert_shrine        | shrine      | 460      | 4         | 0, 36, 40, 42, 8        | 50         |
| 61      | idol_pedestal        | shrine      | 320      | 8         | 0, 36, 42, 8            | 50         |
| 62      | signal_brazier       | shrine      | 280      | 8         | 0, 36, 42, 8            | 50         |
| 63      | sand_drift           | decor       | 140      | 200       | 30                      | 40         |
| 64      | lantern_post         | decor       | 280      | 40        | 0, 42, 8                | 51         |
| 65      | travelers_cairn      | decor       | 180      | 20        | 0                       | 43         |
| 66      | desert_obelisk       | boundary    | 360      | 64        | 0, 36, 40               | 52         |

**Spawn-count summary:** 32 assets = 2324, boundary obelisks = 64, enemies = 88. **Total = 2476.** Headroom under MAX_DRAW (4096) = 1620 for FX, projectiles, lightning bolts, corpses. (Forest peak set-piece use is ~2150; desert lands ~15% denser to match the 2.6× larger area without exceeding draw budget.)

### §4b. uBase marker assignment (desert-only)

| uBase | name                | shader behaviour (Metal-flavoured) |
|-------|---------------------|------------------------------------|
| 0     | default_base        | `out.color = float3(in.color.rgb);` (existing forest default — reused) |
| 8     | generic_emissive    | `out.color = in.color.rgb * 1.6 + glow;` (existing forest emissive — reused) |
| 30    | sand_grading        | `out.color = mix(sand_light, sand_dark, smoothstep(0.0, 1.0, fract(in.world_pos.x*0.04 + in.world_pos.z*0.04) + dune_noise(in.world_pos)));` |
| 31    | dune_sculpt         | adds `float ripple = 0.04*sin(in.world_pos.x*1.4) + 0.025*sin(in.world_pos.z*0.9);` to fragment normal before lighting |
| 32    | sand_decal          | `float crack = step(0.92, fbm(in.uv*8.0)); out.color = mix(out.color, dune_shadow, crack);` |
| 33    | heat_shimmer        | post-pass on world.metal: vertex shader perturbs `out.position.xy += sin(time*4.0 + in.world_pos.z*0.3)*0.005` for entities tagged uBase=33 in their attribute |
| 34    | oasis_water         | `float wave = sin(in.world_pos.x*0.6 + time*0.8) * sin(in.world_pos.z*0.7 + time*0.9); out.color = mix(accent_turquoise*0.6, accent_turquoise, 0.5 + 0.5*wave);` |
| 35    | oasis_foliage       | tinted leaves: `out.color = mix(out.color, dry_vegetation, 0.3); float fres = pow(1.0 - max(0.0, dot(in.normal, view)), 3.0); out.color += accent_gold * fres * 0.25;` |
| 36    | polished_sandstone  | `out.color = mix(rock_warm, sand_light, 0.3); float spec = pow(max(0.0, dot(reflect(-light, in.normal), view)), 32.0); out.color += float3(spec*0.4);` |
| 37    | bleached_bone       | `out.color = mix(bone_pale, sand_light, 0.4); out.color += sand_dark * step(0.6, fract(in.uv.y*9.0))*0.2;` (cracks) |
| 38    | sandstorm_volume    | screen-space pass: `float den = fbm(uv*3.0 + time*0.05); out.color = mix(scene, sand_light, smoothstep(0.4, 0.9, den)*storm_intensity);` |
| 39    | mirage_glass        | `float2 wob = sin(in.uv*6.0 + time*1.5)*0.02; float3 bg = sample_bg(in.uv + wob); out.color = mix(bg, accent_turquoise*0.4, 0.3);` |
| 40    | ruin_glyphs         | `float carve = step(0.8, fbm(in.uv*12.0)); float pulse = 0.5 + 0.5*sin(time*0.6); out.color += accent_gold * carve * pulse * 1.4;` (emissive) |
| 41    | obsidian            | `out.color = float3(0.05, 0.04, 0.07); float3 r = reflect(-view, in.normal); out.color += textureSample(skybox, r) * 0.5;` |
| 42    | gilded_metal        | `out.color = accent_gold; float spec = pow(max(0.0, dot(reflect(-light, in.normal), view)), 64.0); out.color += float3(spec*0.7);` |
| 43    | scorpion_chitin     | `float3 c = mix(rock_warm, dune_shadow, in.uv.y); float fres = pow(1.0-dot(in.normal, view), 4.0); out.color = c + ember_orange * fres * 0.3;` |
| 44    | wraith_smoke        | `float a = fbm(in.uv*4.0 + time*0.3); out.color = bone_pale * (0.4 + a*0.6); out.alpha = a * smoke_density;` |

All uBase values 30..44 are within the desert-allocated free range (30..49) and do **not** collide with the forest set (0,1,2,8,10..14,20,21,25,50,60,70,80).

---

## §5. Path landmark cadence (10 beats, 0–360 m)

| Distance (m) | Visible landmark(s)                           | Mesh IDs           | Mood shift |
|--------------|-----------------------------------------------|--------------------|------------|
| 0            | Spawn pad: low ripple sands, two lantern_posts framing the trailhead | 36, 64           | Setting out — calm, anticipatory |
| 36           | First sand drifts and a saguaro cluster       | 47, 63             | Drying air; the forest is gone |
| 72           | Half-buried obelisk + scattered glyph_wall    | 56, 59             | First sign of ancient civilisation |
| 108          | Hoodoo grove and a fossilised rib_arch        | 42, 43             | Awe, isolation |
| 144          | Oasis: pool, palms, reeds, three lantern_posts on the rim | 51, 52, 53, 54, 64 | Relief — rare life |
| 180          | The Sphinx Head, half-toppled, gazing east    | 57, 55             | Mythic gravity, midpoint |
| 216          | Desert shrine on a mesa with two idol_pedestals and a lit signal_brazier | 60, 61, 62, 41 | Spiritual purpose, watching eyes |
| 252          | Bone field: rib_arch chain, skull_piles, vertebra_chunks | 43, 44, 45     | Whatever lived here is dead |
| 288          | Sandstorm-frame: the ground shader ramps in heat_shimmer + sandstorm_volume; ruined_arch silhouette | 58, 38, 33 | Disorientation, danger |
| 324          | Mirage_phantom encounter zone in front of the gate | 33                 | Threshold of unreality |
| 360          | The portal — same `mesh_id 13` as forest, framed by 4 desert_obelisks at the gate's rim | 13, 66           | Arrival, transition out |

---

## §6. Cross-references and gotchas

### Files to extend (no code in this doc — just the hooks)

- `src/game/enemy_config.zig` — append 5 entries to the `types` array, mesh_id 29..33. Each needs `name_idx` matching new entries appended to `kEnemyNames` in `ios/GameViewController.swift`.
- `src/game/enemy_ai.zig` — add per-mesh tick functions for IDs 29..33; dispatch entry in `EnemyAI.update`.
- `src/main.zig` — branch the `game_init` body on a `current_zone` enum; add a `spawn_desert_world` function that mirrors the forest spawn structure (paths, monoliths→obelisks, scatter assets, enemies). Add desert path constants (`PATH_LEN_DESERT = 360`, `MAP_RADIUS_DESERT = 450`).
- `shaders/world.metal` — add fragment shader branches for uBase 30..44 (see §4b). Add a parallel `path_center_x_desert` block matching the new coefficients (see §2). The vertex shader for heat_shimmer (uBase=33) needs a tiny new branch.
- `ios/GameViewController.swift`:
  - Append 5 enemy names to `kEnemyNames`: "Sand Scorpion", "Sand Wraith", "Desert Husk", "Carrion Spider", "Mirage Phantom".
  - Extend the `meshId` switch to dispatch IDs 29..66 to new mesh buffers.
  - Add 38 `make<NewMesh>(device:)` declarations + buffer ivars + initialisation block.
- `ios/Mesh.swift` — add 38 new mesh-builder functions (sand_scorpion through desert_obelisk).
- `ios/PortalMapView.swift` — flip the Desert tile from "Coming Soon" to available + wire the destination to load the desert zone.

### What could break

- **MAX_DRAW exhaustion.** Desert peak is 2476 set-pieces + transient FX (lightning bolts, impact rings, projectiles, corpses). Forest peak FX during a fight is ~30. Even with 10× pessimism (300 transient entities), we sit at 2776, well under 4096. Margin is 1320 — fine.
- **Path centerline desync.** The Zig formula in `path_center_x()` and the Metal block in `world.metal` MUST share constants A=32, ω₁=0.030, B=10, ω₂=0.050 for the desert. The self-check rig parses both and fails on mismatch.
- **uBase-range overflow.** uBase is a uint8 sub-field of the uv attribute. Forest uses 0..80 with gaps. Desert adds 30..44 contiguously, so total is now 0..80 with new entries in 30..44. No overflow risk.
- **Team-color expansion.** New teams 40..52 must be added to the `world.team` switch in `game_fill_draws` (`src/main.zig:572-603`). 13 new cases. Each needs a `[4]f32` colour with optional per-instance hash variation.
- **mesh_id → builder fan-out.** With desert added, the Swift dispatch switch grows from ~25 cases to ~63. Consider a `[MTLBuffer]` array keyed by mesh_id at some point; not blocking.
- **Boundary-marker count.** Forest used 48 monoliths at r=275; desert uses 64 obelisks at r=440. Spacing is 5.625° vs forest's 7.5°. Both visually well-spaced for their radius.

---

## §7. Self-check (mechanical)

- **Mesh IDs used:** 29..66 contiguous (38 IDs). No overlap with forest set {0,1,2,3,4,5,6,7,8,9,13..28}. Gap at 10..12 left intact. ✓
- **uBase markers used:** {0, 8, 30..44}. No overlap with forest set {0,1,2,8,10..14,20,21,25,50,60,70,80}. ✓
- **Color teams used:** {40..52} (13 teams). No overlap with forest set {0,1,2,3,4,6,7,8,9,10,11,12,13,14,15..24,30,31,32}. ✓
- **Path coefficients distinct from forest:** A 32 vs 20, ω₁ 0.030 vs 0.045, B 10 vs 8, ω₂ 0.050 vs 0.075. ✓
- **Spawn-budget total:** 32 assets × counts = 2324 + 64 obelisks + 88 enemies = 2476. Under MAX_DRAW (4096). ✓
- **Free uBase headroom for future zones:** 45..49, 51..59, 61..69, 71..79, 81..89, 90..127. Plenty.

---

## §8. Spawn-radius reconciliation (overrides per-asset §10)

Per-asset detail sections were generated independently and many specify spawn rings narrower than the 450 m desert (e.g. "15–40 m from origin"). That would clump everything near the player spawn. **The table below supersedes any conflicting per-asset §10 spawn rule.** Implementations should treat these radii as authoritative.

| mesh_id | name                | r_min (m) | r_max (m) | placement bias                            | path-clear (m) |
|---------|---------------------|-----------|-----------|-------------------------------------------|----------------|
| 34      | dune_large          | 30        | 440       | open dunes, fewer near oases              | 8              |
| 35      | dune_small          | 20        | 440       | open dunes                                | 6              |
| 36      | ripple_patch        | 15        | 440       | flat sand zones                           | 5              |
| 37      | crack_patch         | 25        | 440       | dry/cracked terrain, away from oases      | 6              |
| 38      | sandstone_spire     | 40        | 430       | open dunes, scatter                       | 8              |
| 39      | sandstone_arch      | 60        | 420       | rare landmark, well-spaced                | 10             |
| 40      | weathered_boulder   | 15        | 440       | open dunes, near bone fields              | 6              |
| 41      | mesa_flat           | 80        | 420       | open dunes, paired with shrines/spires    | 10             |
| 42      | hoodoo              | 50        | 430       | clusters of 3–5 in dune lows              | 7              |
| 43      | rib_arch            | 40        | 430       | bone-field clusters                       | 7              |
| 44      | skull_pile          | 25        | 440       | bone-field clusters and scatter           | 5              |
| 45      | vertebra_chunk      | 25        | 440       | bone fields                               | 5              |
| 46      | fossil_shell        | 30        | 430       | bone-fields, exposed strata               | 5              |
| 47      | saguaro_cactus      | 20        | 440       | open dunes, scatter                       | 6              |
| 48      | barrel_cactus       | 20        | 440       | open dunes, scatter                       | 5              |
| 49      | dead_brush          | 15        | 440       | open dunes                                | 5              |
| 50      | tumbleweed_static   | 15        | 440       | open dunes                                | 4              |
| 51      | oasis_pool          | 80        | 380       | rare; defines an oasis cluster            | 14             |
| 52      | palm_tall           | r_oasis   | r_oasis+8 | within 8 m of an oasis_pool               | n/a            |
| 53      | palm_short          | r_oasis   | r_oasis+10| within 10 m of an oasis_pool              | n/a            |
| 54      | reed_cluster        | r_oasis   | r_oasis+5 | rim of an oasis_pool                      | n/a            |
| 55      | broken_column       | 70        | 410       | ruin clusters                             | 7              |
| 56      | half_buried_obelisk | 90        | 400       | ruin clusters, isolated                   | 9              |
| 57      | sphinx_head         | 140       | 200       | mid-path, on either side of centerline    | 14             |
| 58      | ruined_arch         | 60        | 400       | ruin clusters                             | 8              |
| 59      | glyph_wall          | 70        | 410       | ruin clusters                             | 7              |
| 60      | desert_shrine       | 100       | 400       | rare; on a mesa or atop a hoodoo cluster  | 11             |
| 61      | idol_pedestal       | 90        | 410       | near shrines or sphinx_head               | 9              |
| 62      | signal_brazier      | 90        | 410       | near shrines, path-side                   | 9              |
| 63      | sand_drift          | 15        | 440       | against rocks/walls/cacti                 | 5              |
| 64      | lantern_post        | 0         | 360       | path-side every ~13 m, alternating sides  | 0 (on path)    |
| 65      | travelers_cairn     | 30        | 420       | scatter, occasional path-side at offsets  | 6              |
| 66      | desert_obelisk      | 440       | 440       | exact boundary ring                       | n/a            |

**`r_oasis`** = the radius of the oasis_pool a given oasis-tile asset is bound to. Palms, palm_short, and reed_cluster spawn relative to their parent oasis_pool, not from world origin.

**Sphinx Head Mid-Path bias:** the 3 sphinx_head instances should sit at z ≈ -160, -180, -200 to anchor the path's mythic-grandeur beat (§5).

**Lantern Post path-side rule:** spawn ~28 lantern_posts in two staggered rows along the path centerline, like the forest's torch lanterns at mesh_id 9 — count is 40 because the desert path is 1.6× longer.

---

# Per-enemy detail (5 × 30+ features)

## Enemy 29 — sand_scorpion
### 1. **One-line silhouette** — What shape does the player read at 30m? Why is it instantly distinguishable from the other 8 enemies in the game?
The sand scorpion appears as a low, wide, segmented body with a long curved tail that tapers to a stinger, instantly differentiating it from the tall, angular gargoyle, the hovering wisp, and the slow, blocky tree ent.

### 2. **Mesh tri-budget breakdown** — body / limbs / props / FX. Sum equals EST_TRIS.
Body: 400 tris, Legs: 450 tris, Tail: 200 tris, FX: 150 tris.

### 3. **Body palette** — 4 RGB swatches drawn from the desert palette (sand_light, sand_dark, dune_shadow, rock_warm, rock_cool, dry_vegetation, accent_gold, accent_turquoise, bone_pale, ember_orange) plus where on the body each is applied.
- **sand_dark** (120, 100, 80) on body segments and tail base
- **dune_shadow** (90, 75, 60) on underbelly and leg undersides
- **rock_warm** (140, 110, 80) on scorpion's carapace and tail tip
- **accent_gold** (220, 180, 70) on stinger and mandibles

### 4. **uBase marker assignments per body part** — table: body_part → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| Body Part     | uBase |
|---------------|-------|
| Body          | 43    |
| Legs          | 43    |
| Tail          | 43    |
| Stinger       | 43    |
| Emissive      | 8     |

### 5. **Idle animation** — 1–3 sentences. Frequency, loop length, key beats.
Idle cycle loops every 6 seconds. Every 2 seconds, it lifts its tail briefly, then lowers it back. The legs subtly sway to simulate restlessness.

### 6. **Walk/move animation** — gait, frequency, foot/limb cadence.
Moves in a fast, skittering gait with 4 legs moving in pairs. Each leg cycle lasts 0.4 seconds, with 2 legs moving forward, then 2, then 2 back, then 2, with alternating steps.

### 7. **Attack telegraph** — what the player sees in the 0.4–0.8s before the hit lands. Visual cue must be unambiguous.
The scorpion raises its tail up high, flicking it back and forth in a warning motion. A faint glow appears on the stinger tip 0.3s before impact.

### 8. **Attack execution** — the strike/hit moment. Damage delivery model (melee swipe, projectile, AoE).
Melee swipe attack with a stinger strike. The scorpion lunges forward, driving its stinger into the target with a sharp snap.

### 9. **Attack cooldown** — seconds between attacks at base difficulty.
1.2 seconds.

### 10. **Hit-react animation** — what plays when player lands a strike on this enemy.
The scorpion flinches backward, its legs stuttering. Tail jerks slightly, and a brief hit flash appears on the carapace.

### 11. **Death animation** — 1–2 sentence description, including dust/bone/smoke FX.
It collapses with a loud crack, the body shattering into sand. Dust clouds rise as its body disintegrates.

### 12. **Aggro radius (m)** — how far away does it lock onto player.
12 meters.

### 13. **Attack range (m)** — distance at which step 7 telegraph triggers.
3 meters.

### 14. **Movement speed (m/s)** — base speed; reference player default 5.5 m/s.
6.2 m/s.

### 15. **Turn rate (rad/s)** — how snappy the rotation is.
4.5 rad/s.

### 16. **Y-offset / locomotion plane** — ground-walker (y=0), hovering (y=2.5), burrowing emergent, etc.
Ground walker, y=0.

### 17. **HP** — choose a value consistent with role (skitterer 30..70, harasser 35..90, tank 240..360, pack 60..120, illusion 1..50). Justify in one sentence vs forest comparators.
55 HP. Higher than forest wisps and gargoyles but lower than skeleton knights, fitting a low-mid skitterer archetype.

### 18. **Damage** — per hit, consistent with HP and role. Justify.
12 damage. Matches the scorpion's low HP, making it dangerous to hit in groups but not overpowered.

### 19. **XP reward** — proportional to (HP × 0.3 + damage × 1.5).
55 × 0.3 + 12 × 1.5 = 16.5 + 18 = 34.5 XP.

### 20. **Group spawn pattern** — lone / paired / loose-trio / dense-pack / ambush-from-burrow. Match the est_count distribution.
Dense-pack. Spawned in groups of 3–5 across zones.

### 21. **Spawn placement rules** — where in the desert (near oases, near ruins, deep dunes, near sphinx_head, sandstorm_volume zones, anywhere).
Deep dunes, near ruins, and sandstorm_volume zones.

### 22. **Procedural variation** — scale range, rotation freedom, palette variant indices, etc.
Scale: 0.9 to 1.1x. Rotation: ±10°. Palette variants: 3 different sand-dark tones.

### 23. **Sound design — idle** — 1 line.
A dry, rasping hiss with intermittent clicks.

### 24. **Sound design — telegraph** — 1 line.
A sharp, scraping sound as the tail lifts.

### 25. **Sound design — hit/strike** — 1 line.
A sharp crack, like a dry twig snapping.

### 26. **Particle FX tied to entity** — emitter preset name (mirror style of `forest_motes`, `embers`, `fireflies`), what it looks like, when it triggers.
`sand_dust` — small, fine sand particles rise from body when walking, triggered by footfalls.

### 27. **Special ability or unique mechanic** — what makes this enemy different from a vanilla melee/ranged unit.
It burrows slightly underground when idle, only exposing its head and tail for scanning.

### 28. **Player counter-strategy** — 1–2 lines on what skills work against it (fireball/lightning/ice_nova/dash).
Ice nova is effective; it slows the scorpion and prevents its stinger from reaching full speed.

### 29. **Mass / collider radius (m)** — body radius for collision, knockback inertia descriptor (light/medium/heavy).
Collider radius: 0.8m. Mass: Medium.

### 30. **Edge-case interaction with biome** — how does this enemy behave when standing inside heat_shimmer / sandstorm_volume / oasis_water tile?
In heat_shimmer: speed increases by 10%. In sandstorm_volume: movement speed reduced by 25%, but attack frequency increases. In oasis_water: takes damage over time.

### Implementation hooks
- `src/game/enemy_config.zig` row 29
- `enemy_ai.zig` tick fn `updateSandScorpionAI`
- `GameViewController.swift` index 29 in `kEnemyNames`
- `world.metal` fragment shader branch: `if (uBase == 43)` and `if (uBase == 8)`
---

## Enemy 30 — sand_wraith
### 1. One-line silhouette — what shape does the player read at 30m? Why is it instantly distinguishable from the other 8 enemies in the game?
At 30m, the sand_wraith appears as a hovering, ethereal, glowing orb with a faintly translucent, swirling smoke body — instantly distinguishable from the gargoyle’s angular wings, the wisp’s tiny fluttering form, or the ent’s tree-like bulk.

### 2. Mesh tri-budget breakdown — body / limbs / props / FX. Sum equals EST_TRIS.
Body: 700 tris, limbs: 0 tris, props: 0 tris, FX: 100 tris (for volumetric smoke effect and eye glow).

### 3. Body palette — 4 RGB swatches drawn from the desert palette (sand_light, sand_dark, dune_shadow, rock_warm, rock_cool, dry_vegetation, accent_gold, accent_turquoise, bone_pale, ember_orange) plus where on the body each is applied.
- `sand_light`: applied to the main smoke body’s outer edge to simulate a soft glow
- `dune_shadow`: used for internal shadowing within the smoke body to give depth
- `accent_gold`: for the eye glow (uBase=8)
- `rock_cool`: subtle accent on the edge of the smoke to simulate dust particles

### 4. uBase marker assignments per body part — table: body_part → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| body_part | uBase |
|----------|-------|
| smoke body | 44 |
| eye glow | 8 |
| default fade | 0 |

### 5. Idle animation — 1–3 sentences. Frequency, loop length, key beats.
The wraith gently pulses and swirls in place with a slow, hypnotic rhythm. Loop length is 6 seconds, with a key beat every 2 seconds where the smoke body pulses outward.

### 6. Walk/move animation — gait, frequency, foot/limb cadence.
Smooth hovering movement with no limbs. Movement is fluid and undulating, with a cadence of 1.2 seconds per direction change.

### 7. Attack telegraph — what the player sees in the 0.4–0.8s before the hit lands. Visual cue must be unambiguous.
The wraith’s eye glow intensifies and pulses in sync with a subtle wind-up swirl of its smoke body.

### 8. Attack execution — the strike/hit moment. Damage delivery model (melee swipe, projectile, AoE).
AoE attack — the wraith releases a swirling shockwave of sand and smoke that expands outward, dealing damage to anything within a 3m radius.

### 9. Attack cooldown — seconds between attacks at base difficulty.
2.5 seconds.

### 10. Hit-react animation — what plays when player lands a strike on this enemy.
The wraith briefly flinches, its smoke body distorts and darkens, and the eye glow flickers.

### 11. Death animation — 1–2 sentence description, including dust/bone/smoke FX.
The wraith dissipates into a swirling vortex of sand and smoke, leaving behind a small puff of dust and a faint ember trail.

### 12. Aggro radius (m) — how far away does it lock onto player.
12 meters.

### 13. Attack range (m) — distance at which step 7 telegraph triggers.
8 meters.

### 14. Movement speed (m/s) — base speed; reference player default 5.5 m/s.
3.2 m/s.

### 15. Turn rate (rad/s) — how snappy the rotation is.
3.0 rad/s.

### 16. Y-offset / locomotion plane — ground-walker (y=0), hovering (y=2.5), burrowing emergent, etc.
Hovering at y = 3.0 meters.

### 17. HP — choose a value consistent with role (skitterer 30..70, harasser 35..90, tank 240..360, pack 60..120, illusion 1..50). Justify in one sentence vs forest comparators.
120 HP. This is consistent with its mid-range, floating role; higher than the Forest Wisp (35 HP) but lower than the Tree Ent (280 HP).

### 18. Damage — per hit, consistent with HP and role. Justify.
14 damage. Matches its HP and floating role, allowing it to be a consistent mid-tier threat without being overpowered.

### 19. XP reward — proportional to (HP × 0.3 + damage × 1.5).
XP = (120 × 0.3) + (14 × 1.5) = 36 + 21 = 57 XP.

### 20. Group spawn pattern — lone / paired / loose-trio / dense-pack / ambush-from-burrow. Match the est_count distribution.
Loose-trio. Spawned in small groups to avoid overwhelming the player.

### 21. Spawn placement rules — where in the desert (near oases, near ruins, deep dunes, near sphinx_head, sandstorm_volume zones, anywhere).
Spawned near ruins and deep dunes, avoiding oases and sandstorm_volume zones.

### 22. Procedural variation — scale range, rotation freedom, palette variant indices, etc.
Scale range: 0.9–1.1x. Rotation freedom: 0.2 rad. Palette variant indices: 0–2 for color shifts in smoke and eye glow.

### 23. Sound design — idle — 1 line.
A low, echoing whisper of wind through sand.

### 24. Sound design — telegraph — 1 line.
A rising, howling wind sound before the attack.

### 25. Sound design — hit/strike — 1 line.
A sharp, sibilant crack like sand being torn apart.

### 26. Particle FX tied to entity — emitter preset name (mirror style of `forest_motes`, `embers`, `fireflies`), what it looks like, when it triggers.
`sand_vortex` — swirls of fine sand and smoke, triggered on attack and death.

### 27. Special ability or unique mechanic — what makes this enemy different from a vanilla melee/ranged unit.
Its ability to hover and move smoothly, and its AoE shockwave attack that can catch multiple players or allies in one blast.

### 28. Player counter-strategy — 1–2 lines on what skills work against it (fireball/lightning/ice_nova/dash).
Fireball or ice nova will disrupt the wraith’s smoke body, while dash or lightning can quickly close the distance for melee attacks.

### 29. Mass / collider radius (m) — body radius for collision, knockback inertia descriptor (light/medium/heavy).
Collider radius: 1.5m. Mass: light.

### 30. Edge-case interaction with biome — how does this enemy behave when standing inside heat_shimmer / sandstorm_volume / oasis_water tile?
In heat_shimmer: slight distortion in smoke body visuals. In sandstorm_volume: no effect, continues to hover normally. In oasis_water: slows movement and reduces attack frequency.

### Implementation hooks
- `src/game/enemy_config.zig`: row 30
- `enemy_ai.zig`: tick function `tickSandWraith`
- `GameViewController.swift`: `kEnemyNames` index 30
- `world.metal`: fragment shader branches for uBase=44 and uBase=8
---

## Enemy 31 — desert_husk
### 1. One-line silhouette
At 30m, the desert_husk appears as a low, wide, sand-encrusted golem with a hunched, heavy stance, instantly distinguishable by its broad, flattened body and lack of wings or limbs that suggest agility.

### 2. Mesh tri-budget breakdown
Body: 1000 tris, limbs: 300 tris, props (sand encrustation): 150 tris, FX (dust particles): 50 tris.

### 3. Body palette
- **sand_light** (RGB: 220, 180, 120) — main body shell and head
- **sand_dark** (RGB: 150, 100, 60) — limbs, feet, armor plating
- **dune_shadow** (RGB: 100, 80, 50) — underbody, crevices, joints
- **rock_warm** (RGB: 180, 120, 90) — exposed bone patches and armor accents

### 4. uBase marker assignments per body part
| Body Part        | uBase |
|------------------|-------|
| Head             | 30    |
| Upper Body       | 32    |
| Lower Body       | 30    |
| Limbs            | 32    |
| Feet             | 30    |
| Sand Encrustation| 0     |
| Emissive FX      | 8     |

### 5. Idle animation
The desert_husk sways gently with a slow 3-second loop, with no key beats, emphasizing its slow, ponderous nature. A few sand grains fall from its encrustation every 2 seconds.

### 6. Walk/move animation
Slow, shuffling gait with 1.5-second step cycle. Each foot hits the ground in sequence with a slight dust puff.

### 7. Attack telegraph
The enemy raises its massive arm, sand particles fly off it in a 1.5-second buildup. The arm begins glowing with a faint ember-orange hue.

### 8. Attack execution
A powerful forward swipe with both fists, delivering a melee AoE damage. Sand and dust burst outward in a wide arc.

### 9. Attack cooldown
3.2 seconds at base difficulty.

### 10. Hit-react animation
The enemy recoils slightly, sand and dust explode from its body surface, and a brief red flash pulses along its limbs.

### 11. Death animation
The golem collapses with a loud crash. Sand and bone fragments explode, followed by a long-lasting dust cloud that obscures its body for 2 seconds.

### 12. Aggro radius (m)
12 meters.

### 13. Attack range (m)
3.5 meters.

### 14. Movement speed (m/s)
1.2 m/s.

### 15. Turn rate (rad/s)
0.8 rad/s.

### 16. Y-offset / locomotion plane
Ground-walker at y=0.

### 17. HP
320 HP. This is consistent with the tank role and higher than the Tree Ent (280 HP) but lower than a mid-tier boss, reflecting its high durability and slow speed.

### 18. Damage
28 damage per hit. This is consistent with its high HP and slow attack speed, ensuring it's a durable but not overwhelming threat.

### 19. XP reward
135 XP (320 × 0.3 + 28 × 1.5).

### 20. Group spawn pattern
Loose-trio. Spawns in groups of 2–3, rarely alone, mimicking desert scavenging behavior.

### 21. Spawn placement rules
Near ruins, in sandstorm_volume zones, and around oasis_water tile edges — places where sand accumulation is common.

### 22. Procedural variation
Scale: 0.9–1.1x, rotation: ±15°, palette variant indices: 0–2, sand encrustation variation: 0–3.

### 23. Sound design — idle
A deep rumble, with occasional sand sifting and creaking.

### 24. Sound design — telegraph
A slow, low growl and sand scraping.

### 25. Sound design — hit/strike
A loud, thudding impact and a crackling sand burst.

### 26. Particle FX tied to entity
- **sand_storm** — sand swirls around feet and limbs, triggers on movement.
- **ember_glow** — faint orange glow on limbs, triggers during attack telegraph.

### 27. Special ability or unique mechanic
Sand encrustation that slowly regenerates HP over time, but only when idle. It also provides immunity to knockback during the regen phase.

### 28. Player counter-strategy
Fireball or ice_nova can interrupt the regen phase and reduce its HP quickly. Dash and lightning are also effective for avoiding its swipe attacks.

### 29. Mass / collider radius (m)
Collider radius: 1.8 m, mass: heavy.

### 30. Edge-case interaction with biome
When standing in heat_shimmer or sandstorm_volume, the desert_husk's sand encrustation becomes more pronounced and its movement speed slightly increases. In oasis_water, it takes damage over time and its encrustation begins to erode.

### Implementation hooks
- `src/game/enemy_config.zig` row: 31
- `enemy_ai.zig` tick fn name: `tick_desert_husk`
- GameViewController.swift `kEnemyNames` index: 31
- world.metal fragment branches: `if (uBase == 30 || uBase == 32)` for sand encrustation rendering
---

## Enemy 32 — carrion_spider
### 1. One-line silhouette
A low, wide, multi-legged arachnid silhouette with a bulbous abdomen and long, spindly limbs, instantly distinguishable by its distinctive hump and spider-like posture amid the desert flora.

### 2. Mesh tri-budget breakdown
Body: 300 tris, Legs: 400 tris, Props: 100 tris, FX: 100 tris.

### 3. Body palette
- **sand_light** (210, 180, 140) — abdomen, legs
- **sand_dark** (160, 130, 100) — thorax, head
- **dune_shadow** (100, 80, 60) — underside, inner limbs
- **bone_pale** (220, 210, 200) — mandibles, eye highlights

### 4. uBase marker assignments per body part
| body_part   | uBase |
|-------------|-------|
| head        | 43    |
| thorax      | 0     |
| abdomen     | 43    |
| legs        | 0     |
| mandibles   | 43    |
| eyes        | 8     |

### 5. Idle animation
Loops every 2.5s, with subtle head bob and leg twitch. Key beat: legs lift slightly on 0.5s.

### 6. Walk/move animation
Caterpillar gait, 4 limbs on ground at once. Frequency 0.8s per step, 8 limbs cadenced in pairs.

### 7. Attack telegraph
Head lifts, mandibles clack, and 4 front legs extend forward. Visual cue is a 0.6s flicker of eye emissive.

### 8. Attack execution
Front legs swipe in a wide arc, dealing 10 damage. No projectile, purely melee.

### 9. Attack cooldown
1.2 seconds at base difficulty.

### 10. Hit-react animation
All legs tuck inward, body jolts slightly, with a 0.2s flicker on the head uBase.

### 11. Death animation
Body collapses with a dust puff, limbs splay outward. Bone dust FX erupts from abdomen.

### 12. Aggro radius (m)
12 meters.

### 13. Attack range (m)
3.5 meters.

### 14. Movement speed (m/s)
6.2 m/s.

### 15. Turn rate (rad/s)
5.0 rad/s.

### 16. Y-offset / locomotion plane
Ground-walker, y=0.

### 17. HP
90 HP. Justified as a mid-tier pack hunter with low-mid health, higher than a skitterer but lower than a tank, consistent with its fast, agile role.

### 18. Damage
10 damage per hit. Justified to match its HP and role as a fast, low-mid damage pack hunter.

### 19. XP reward
112 XP. (90 × 0.3 + 10 × 1.5 = 27 + 15 = 42, then scaled for difficulty).

### 20. Group spawn pattern
Dense-pack, 3–5 per group, typically 2–3 in a tight cluster.

### 21. Spawn placement rules
Spawn near ruins and sandstorm_volume zones, rarely near oases.

### 22. Procedural variation
Scale range: 0.9–1.1, rotation freedom: ±15°, palette variant indices: 0–3.

### 23. Sound design — idle
A low, rhythmic hiss and leg scraping sound.

### 24. Sound design — telegraph
A sharp, clicking sound from mandibles as legs extend.

### 25. Sound design — hit/strike
A crackling, meaty impact sound with a slight pop.

### 26. Particle FX tied to entity
`carrion_dust` — small, dry particles that trail from limbs, triggered on movement and hit.

### 27. Special ability or unique mechanic
Can burrow into sand for 2s to evade damage, reappearing nearby.

### 28. Player counter-strategy
Fireball and lightning work well — fireball burns the burrowed spider out, lightning stuns and deals damage.

### 29. Mass / collider radius (m)
Collider radius: 0.8m, mass: medium, knockback inertia: light.

### 30. Edge-case interaction with biome
When standing in heat_shimmer, its body glows faintly with thermal distortion. In sandstorm_volume, its legs are partially obscured but movement remains unhindered. In oasis_water, it moves slower and its legs splay out slightly due to wet sand.

### Implementation hooks
- `src/game/enemy_config.zig` row: 32  
- `enemy_ai.zig` tick fn: `tick_carrion_spider`  
- `GameViewController.swift` `kEnemyNames` index: 32  
- `world.metal` fragment branches: `if (uBase == 43)` and `if (uBase == 8)`
---

## Enemy 33 — mirage_phantom
### 1. One-line silhouette — what shape does the player read at 30m? Why is it instantly distinguishable from the other 8 enemies in the game?
At 30m, the mirage_phantom appears as a shifting, translucent humanoid form with a faint golden outline that flickers like heat distortion. It's instantly distinguishable from other enemies by its semi-transparent body, lack of solid edges, and the shimmering aura that makes it appear to "breathe" with the environment.

### 2. Mesh tri-budget breakdown — body / limbs / props / FX. Sum equals EST_TRIS.
Body: 300 tris; Limbs: 180 tris; Props: 60 tris; FX: 60 tris.

### 3. Body palette — 4 RGB swatches drawn from the desert palette (sand_light, sand_dark, dune_shadow, rock_warm, rock_cool, dry_vegetation, accent_gold, accent_turquoise, bone_pale, ember_orange) plus where on the body each is applied.
sand_dark (body core), dune_shadow (limbs), accent_gold (outline), rock_warm (glow accents). The body core is dark sand, limbs are shaded with dune shadow, the outline is golden with rock_warm glow.

### 4. uBase marker assignments per body part — table: body_part → uBase. Use ONLY markers from the reserved list above + 0 (default) and 8 (emissive).
| Body Part    | uBase |
|--------------|-------|
| Head         | 39    |
| Torso        | 0     |
| Arms         | 39    |
| Legs         | 0     |
| Glow         | 8     |

### 5. Idle animation — 1–3 sentences. Frequency, loop length, key beats.
Idle animation loops every 4 seconds, with a 0.5s pause at the start. The phantom slowly floats up and down, with a subtle rotation of the limbs every 2 seconds. The body flickers in and out of visibility every 3 seconds.

### 6. Walk/move animation — gait, frequency, foot/limb cadence.
Smooth floating gait, no feet. Movement is synchronized with a subtle limb sway every 0.8 seconds, matching the body's translucency and the way it appears to "slide" across sand.

### 7. Attack telegraph — what the player sees in the 0.4–0.8s before the hit lands. Visual cue must be unambiguous.
A brief golden pulse radiates from the phantom’s center, accompanied by a subtle distortion in the air around it. The body flickers rapidly for 0.3 seconds before the attack.

### 8. Attack execution — the strike/hit moment. Damage delivery model (melee swipe, projectile, AoE).
Melee swipe attack with a short-range arc. The phantom extends a translucent arm that lashes out with a glowing golden trail, dealing a single hit with a visual trail of sand particles.

### 9. Attack cooldown — seconds between attacks at base difficulty.
2.5 seconds.

### 10. Hit-react animation — what plays when player lands a strike on this enemy.
The phantom flickers and pulses violently, with a temporary glow effect around the hit point. It briefly becomes fully opaque before fading again.

### 11. Death animation — 1–2 sentence description, including dust/bone/smoke FX.
The phantom disintegrates into a shimmering cloud of golden dust, accompanied by a small puff of sand and a crackling sound. A few glowing fragments scatter in all directions.

### 12. Aggro radius (m) — how far away does it lock onto player.
12m.

### 13. Attack range (m) — distance at which step 7 telegraph triggers.
3.5m.

### 14. Movement speed (m/s) — base speed; reference player default 5.5 m/s.
4.2 m/s.

### 15. Turn rate (rad/s) — how snappy the rotation is.
2.8 rad/s.

### 16. Y-offset / locomotion plane — ground-walker (y=0), hovering (y=2.5), burrowing emergent, etc.
Hovering at y=2.2m, with slight vertical drift.

### 17. HP — choose a value consistent with role (skitterer 30..70, harasser 35..90, tank 240..360, pack 60..120, illusion 1..50). Justify in one sentence vs forest comparators.
28 HP. This is low for an illusion enemy, consistent with its role as a deceptive, fast attacker rather than a durable front-line threat, unlike the Forest Wisp or Gargoyle.

### 18. Damage — per hit, consistent with HP and role. Justify.
14 damage. Balanced with low HP, it’s a quick, high-crit enemy that can be dangerous in groups, unlike the slow but high-damage Tree Ent.

### 19. XP reward — proportional to (HP × 0.3 + damage × 1.5).
XP = 28 × 0.3 + 14 × 1.5 = 8.4 + 21 = 29.4 → 30 XP.

### 20. Group spawn pattern — lone / paired / loose-trio / dense-pack / ambush-from-burrow. Match the est_count distribution.
Loose-trio. Spawns in small groups of 3, with 1 or 2 more in the zone.

### 21. Spawn placement rules — where in the desert (near oases, near ruins, deep dunes, near sphinx_head, sandstorm_volume zones, anywhere).
Near ruins, deep dunes, and sandstorm_volume zones, where the visual distortion matches its appearance.

### 22. Procedural variation — scale range, rotation freedom, palette variant indices, etc.
Scale range: 0.9 to 1.1; Rotation freedom: ±0.2 radians; Palette variants: 3 indices for sand_dark, dune_shadow, and accent_gold.

### 23. Sound design — idle — 1 line.
A low, ethereal hum like wind through a dune.

### 24. Sound design — telegraph — 1 line.
A sharp, crackling distortion sound like sand shifting.

### 25. Sound design — hit/strike — 1 line.
A high-pitched, metallic ring followed by a whispery fade.

### 26. Particle FX tied to entity — emitter preset name (mirror style of `forest_motes`, `embers`, `fireflies`), what it looks like, when it triggers.
`mirage_essence` — glowing, translucent particles that follow the phantom’s movement and flicker when attacking.

### 27. Special ability or unique mechanic — what makes this enemy different from a vanilla melee/ranged unit.
It can phase in and out of visibility, becoming partially transparent for 1.5 seconds after a hit or attack. This makes it harder to track and counter.

### 28. Player counter-strategy — 1–2 lines on what skills work against it (fireball/lightning/ice_nova/dash).
Dash or ice nova can interrupt its phase-out animation. Lightning or fireball can deal consistent damage before it phases.

### 29. Mass / collider radius (m) — body radius for collision, knockback inertia descriptor (light/medium/heavy).
Collider radius: 0.6m; Mass: light.

### 30. Edge-case interaction with biome — how does this enemy behave when standing inside heat_shimmer / sandstorm_volume / oasis_water tile?
Inside heat_shimmer, it becomes more transparent and flickers faster. In sandstorm_volume, it moves faster and blends in better with the environment. In oasis_water, it becomes unstable and moves erratically.

### Implementation hooks
- `src/game/enemy_config.zig` row 333
- `enemy_ai.zig` tick function `tick_mirage_phantom`
- `GameViewController.swift` `kEnemyNames` index 33
- `world.metal` fragment shader branches for `uBase == 39`, `uBase == 8`
---

# Per-asset detail (32 × 30+ features)

*(populated by subsequent passes — appended below)*

---


---

## Asset 34 — dune_large
### 1. Silhouette at 30m
The dune_large appears as a broad, sweeping S-curve that dominates the horizon, its form defined by a gentle rolling elevation that creates a strong visual arc.

### 2. Tri-budget breakdown
The mesh is split as follows: 300 tris for the main body (cylinder-based shape), 60 tris for decorative sand ripples and surface details, and 20 tris for optional FX elements like subtle wind trails or particle emitters.

### 3. Geometry construction
The main body is constructed using a `mbCylinder` with a tapering profile to simulate a natural dune shape. It uses `mbSphere` elements at both ends to create rounded termini. Surface details are added via extruded ring segments that follow the contour of the main mesh, creating realistic sand ridges and dune faces.

### 4. Body palette
The primary surface uses `sand_light` for the main sand body, `sand_dark` for the shadowed flanks, and `dune_shadow` for the deepest recesses. Accent elements incorporate `accent_gold` for sparse patches of mineral-rich sand.

### 5. uBase marker assignments per surface
| Surface | uBase |
|--------|--------|
| Main sand body | 30 |
| Shadowed flanks | 31 |
| Sand ridges | 30 |
| Mineral patches | 31 |
| Emissive wind trails | 8 |

### 6. Base scale (scale_min, scale_max)
Scale range is 1.2 to 1.8. The minimum is chosen to ensure visual clarity at distance; the maximum allows for variety in dune size while preserving the sweeping curve's character.

### 7. Y rotation
Y rotation is fixed-N facings, aligned to a random axis of the dune's orientation to create varied visual flow across the landscape.

### 8. Ground anchor
The dune is partially buried, sitting with its base 0.2 meters below y=0, to simulate a natural sand accumulation.

### 9. Procedural variation method
Variation is achieved through a combination of palette hash (to determine sand color blend) and scale spread (0.8 to 1.2x) with slight Y-rotation adjustments.

### 10. Spawn placement rules
Spawns occur within a radius of 15–40 meters from the origin. Preferred zones are open dunes, avoiding paths and oases. Instances must not spawn within 6 meters of the path centerline.

### 11. Spawn count rationale
With a 450 m radius zone and EST_COUNT = 240, the asset is distributed sparsely enough to allow for clear visibility of individual dunes while still maintaining a strong dune field presence.

### 12. Clustering pattern
Instances are arranged in a scattered-grid pattern, spaced 15–20 meters apart to avoid visual clumping and enhance natural randomness.

### 13. Inter-asset spacing minimum (m)
Minimum spacing is 12 meters from other instances of the same mesh.

### 14. Path-clearance distance (m)
The asset may spawn within 7 meters of the path centerline, but is placed to avoid direct contact with the path’s geometry.

### 15. Team color reasoning
TEAM=40 is selected to group dunes with other rolling terrain features. In the `game_fill_draws` switch, this resolves to `dune_shadow`.

### 16. Shadow / contact AO strategy
The dune casts a soft shadow with a subtle contact AO blob at its base to enhance depth perception. It does not use ambient-occluded vertex colors.

### 17. Distant-LOD strategy
It remains visible up to 200 meters, with no LOD simplification currently planned. The visual fidelity is maintained even at distance.

### 18. Animation, if any
Static, no animation. The asset remains motionless to preserve the illusion of solid, timeless sand.

### 19. Particle FX bound to entity
No particle FX are bound to the dune itself.

### 20. Lighting interaction
The dune catches warm sunlight on its east-facing slope, casting a long shadow to the west. The sun-side is tinted with `accent_gold` to emphasize the desert warmth.

### 21. Collision
The asset blocks player movement, with a `world.radius` of 1.0 to simulate a solid sand barrier.

### 22. Destructible
No. This asset is not destructible in v1.

### 23. Lore hook
This dune is a remnant of an ancient sandstorm that shaped the region, its shape preserved by the slow drift of the wind.

### 24. Surface UV layout
The main sand body uses `uBase=30`, shadowed flanks use `uBase=31`, and surface ridges use `uBase=30`. Mineral patches use `uBase=31`.

### 25. Material specularity
Matte, with no gloss or reflection to maintain realism.

### 26. Day/night appearance shift
The sun-side appears warm with a `accent_gold` tint, while the shadow-side takes on a cooler `dune_shadow` hue, creating a strong day/night contrast.

### 27. Silhouette test at 50 m
The dune still reads clearly at 50 meters, with the sweeping curve remaining visible. Minimum scale required is 0.9 to maintain fidelity.

### 28. Visual neighbours
It looks right next to `rock_warm`, `dry_vegetation`, and `bone_pale` structures, enhancing the desert landscape's cohesion.

### 29. Visual conflicts
It should not be placed near `oasis_pool` or `brazier_flame`, as those elements would clash with the dune’s natural, arid tone.

### 30. Implementation hooks
- Add `case 40:` to `world.team` switch in `src/main.zig`
- Add `makeDuneLarge(device:)` function in `ios/Mesh.swift`
- Add `case 34:` dispatch case in `ios/GameViewController.swift`
---

## Asset 35 — dune_small
### 1. **Silhouette at 30m** — From 30 meters away, the dune_small appears as a gently rolling, crescent-shaped mound of sand, with subtle shadowing that hints at its elevation and rounded edges.

### 2. **Tri-budget breakdown** — Body: 180 tris, Decorations: 20 tris, FX: 20 tris. Total: 220 tris.

### 3. **Geometry construction** — The mesh is built using a combination of `mbCylinder` for the central mound, which is tapered and slightly flattened at the top to mimic a natural dune shape. A small `mbSphere` is added at the top to simulate a soft peak, and an extruded ring is added around the base to create a subtle lip. The geometry uses a stacked plate technique for the dune’s internal structure to simulate sand layers.

### 4. **Body palette** — The main surface uses `sand_light` for the top and `sand_dark` for the sides to create a natural gradient from sun-facing to shadowed areas. `dune_shadow` is used for the deepest shadowed crevices. `rock_warm` is used for a small rock-like outcrop on the top, contributing to the natural texture.

### 5. **uBase marker assignments per surface** — 

| Surface         | uBase |
|----------------|-------|
| Sand Top       | 30    |
| Sand Sides     | 31    |
| Rock Outcrop   | 0     |
| Shadow         | 8     |

### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.2. This spread allows for small variation in size to prevent visual repetition while maintaining a consistent dune-like appearance.

### 7. **Y rotation** — Random `0..2π`. Instances are rotated randomly to avoid uniformity and create a more natural dune field.

### 8. **Ground anchor** — Sits flat on y=0 with no y-offset, fully grounded to the terrain surface.

### 9. **Procedural variation method** — Instances vary in scale, rotation, and a palette hash for the `sand_light` and `sand_dark` colors, with a small chance of a `rock_warm` outcrop.

### 10. **Spawn placement rules** — Spawn radius is 15–45 m from origin. Prefers open dunes and avoids spawning within 6 m of path centerline or near oases or ruins.

### 11. **Spawn count rationale** — With an EST_COUNT of 280 and a 450 m radius zone, the density is appropriate to simulate a natural dune field with sparse but frequent mounds, avoiding a “cluttered” or “sparse” feel.

### 12. **Clustering pattern** — Scattered-grid. Instances are distributed across the zone with a minimum spacing to avoid visual repetition and maintain a natural feel.

### 13. **Inter-asset spacing minimum (m)** — Minimum 8 meters to another instance of the same mesh to prevent overlap and maintain the illusion of a natural dune field.

### 14. **Path-clearance distance (m)** — 7 meters from path centerline to ensure no visual conflict with paths while allowing for natural flow.

### 15. **Team color reasoning** — TEAM=40 to align with a warm, desert-based team color that resolves to `sand_light` in the `game_fill_draws` switch, consistent with the overall desert theme.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow on the ground and uses ambient-occluded vertex colors to simulate the shadowed areas, especially on the leeward side.

### 17. **Distant-LOD strategy** — No LOD currently. Asset remains visible at full detail up to the map’s maximum distance, consistent with the forest’s approach.

### 18. **Animation, if any** — Static, no animation. The asset remains motionless to reflect the stillness of desert terrain.

### 19. **Particle FX bound to entity** — None. The asset does not carry any particle effects.

### 20. **Lighting interaction** — The sun-facing side catches warm sunlight, tinted with `accent_gold`, while the shadowed side cools to `dune_shadow` or `rock_cool`. The asset casts a long shadow to the east.

### 21. **Collision** — Does not block player movement. `world.radius` is set to 0.8 to allow passage through the mound without obstruction.

### 22. **Destructible** — No. This asset is not destructible in v1.

### 23. **Lore hook** — A remnant of a once-larger dune that has eroded over time, leaving this small, rounded mound as a testament to the desert’s ever-shifting landscape.

### 24. **Surface UV layout** — The top surface uses uBase 30, the side uses uBase 31, the rock outcrop uses uBase 0, and the shadowed area uses uBase 8 for emissive shading.

### 25. **Material specularity** — Matte. The surface has no glossy or reflective properties to maintain realism.

### 26. **Day/night appearance shift** — During the day, sun-facing surfaces appear warm and golden (`accent_gold`), while shadowed areas shift to a cooler `dune_shadow`. At night, the coloration remains consistent with a soft ambient tint.

### 27. **Silhouette test at 50 m** — At 50 meters, the asset still reads clearly as a rounded dune. A minimum scale of 0.6 is sufficient to maintain silhouette clarity.

### 28. **Visual neighbours** — Looks right next to `dune_large`, `rock_cool`, `dry_vegetation`, and `oasis_pool`, contributing to a cohesive desert ecosystem.

### 29. **Visual conflicts** — Should not spawn near `cactus`, `brazier`, or `ruin_arch`, as these would visually overpower or clash with the soft silhouette of the dune.

### 30. **Implementation hooks** — 
- Add `case 40: return makeDuneSmall(device:)` to `world.team` switch in `src/main.zig`.
- Add `func makeDuneSmall(device: MTLDevice) -> Mesh` to `ios/Mesh.swift`.
- Add `case 35: mesh = makeDuneSmall(device:)` to `dispatch` in `ios/GameViewController.swift`.
---

## Asset 36 — ripple_patch
### 1. **Silhouette at 30m** — From 30 meters away, the ripple_patch appears as a slightly undulating, flat, circular surface with a subtle ripple effect, making it appear like a gentle wave in the dune sand.

### 2. **Tri-budget breakdown** — Body: 100 tris, Decorations: 15 tris, FX: 5 tris. Total: 120 tris.

### 3. **Geometry construction** — The mesh is built using a `mbCylinder` with a flattened top and a tapered, low-radius bottom to simulate the ripple effect. A series of extruded rings are stacked vertically to form a smooth ripple texture, and a small `mbSphere` is added at the center to define the pivot point and aid in vertex blending for wind animations.

### 4. **Body palette** — Uses sand_light for the base, dune_shadow for the ripple crests, sand_dark for the troughs, and accent_gold for subtle highlights on the ripple edges.

### 5. **uBase marker assignments per surface** — 
| Surface          | uBase |
|------------------|-------|
| Base (sand_light)| 30    |
| Ripple crests    | 31    |
| Ripple troughs   | 32    |
| Highlights       | 33    |

### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.7 to 1.3. The variation allows for subtle visual diversity without disrupting the uniformity of the dune texture.

### 7. **Y rotation** — Random `0..2π`. Ensures no predictable orientation for natural-looking distribution.

### 8. **Ground anchor** — Sits flat on y=0 with slight random offset to simulate a natural ripple alignment in the sand.

### 9. **Procedural variation method** — Variations include palette hash for color shifts, scale spread within the 0.7–1.3 range, and slight Y-axis rotation to break up repetitive patterns.

### 10. **Spawn placement rules** — Spawns within 10–25 m from origin, prefers open dunes and avoids within 6 m of path centerline. Does not spawn near oases or ruins.

### 11. **Spawn count rationale** — With `est_count = 200` in a 450 m radius zone, the asset provides sufficient coverage to imply a continuous dune surface texture without overloading the system or causing visual clutter.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed in a grid pattern with random offsets to avoid perfect alignment and maintain natural spread.

### 13. **Inter-asset spacing minimum (m)** — 3 meters minimum spacing from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 6 meters minimum distance from path centerline to ensure visual separation from paths.

### 15. **Team color reasoning** — TEAM=40 is chosen to align with the warm, sand-based desert team. It maps to `sand_light` in the `game_fill_draws` switch.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow with a subtle AO blob beneath to suggest it’s partially embedded in sand. No vertex color occlusion is used.

### 17. **Distant-LOD strategy** — No LOD currently implemented, as forest assets do not use LOD. This asset will remain at full resolution across all distances.

### 18. **Animation, if any** — Static, no animation. The ripple effect is simulated via vertex displacement and UV mapping, not animation.

### 19. **Particle FX bound to entity** — None. The ripple effect is purely visual and not tied to particle effects.

### 20. **Lighting interaction** — The surface catches warm sunlight on the east-facing edges and casts a long shadow to the west. It has a soft self-shadowing effect to emphasize the ripple shape.

### 21. **Collision** — Does not block player movement. `world.radius = 0.2` to allow passage through.

### 22. **Destructible** — No. This asset is purely decorative and will not be destructible in v1.

### 23. **Lore hook** — These wind-rippled patterns are remnants of ancient dune shifts, left by the passage of time and the wind’s persistent force.

### 24. **Surface UV layout** — uBase 30 covers the base surface, uBase 31 the ripple crests, uBase 32 the troughs, and uBase 33 the highlights, all mapped to respective color swatches in the desert palette.

### 25. **Material specularity** — Matte with soft-glossy highlights on ripple edges to simulate light reflection off the sand surface.

### 26. **Day/night appearance shift** — Sun-side is warm-toned (accent_gold) and shadow-side is cool-toned (dune_shadow). The sun-side reflects more warm hues, while the shadow-side takes on a cooler, darker tone.

### 27. **Silhouette test at 50 m** — Yes, the ripple_patch still reads clearly as a textured flat surface at 50 meters. A minimum scale of 0.6 is required to maintain clarity.

### 28. **Visual neighbours** — Looks right next to `sand_stone`, `dune_rock`, `sand_drift`, and `dry_vegetation`. Complements the sandy terrain with a subtle texture contrast.

### 29. **Visual conflicts** — Should not be placed near `sand_drift` or `dune_rock` in dense clusters, as this would cause silhouette overlap or visual confusion.

### 30. **Implementation hooks** — 
- Add case `40: .ripple_patch` to `world.team` switch in `src/main.zig`.
- Add `makeRipplePatch(device:)` to `ios/Mesh.swift`.
- Add dispatch case in `ios/GameViewController.swift` for `ripple_patch` in `spawnMesh`.
---

## Asset 37 — crack_patch
### 1. **Silhouette at 30m** — From a distance, the crack patch appears as a subtle, irregular darkened area with a few thin, linear grooves that suggest dry, weathered ground. It blends into the sand dunes, yet its shape is clearly not random, evoking the feeling of a desert's skin cracking under heat and time.

### 2. **Tri-budget breakdown** — The 100-triangle mesh is split as follows: 70 triangles for the main body (the crack pattern), 20 for decorative surface detail (smaller fractures), and 10 for low-poly FX (dust particles or shadow blob).

### 3. **Geometry construction** — The mesh is built using a combination of `mbCylinder` and `mbSphere` helpers to form the base crack pattern, with a few extruded rings to simulate depth and texture. The core shape is an extruded ring that's slightly tapered, with a few overlapping cylinders forming the finer cracks. A few small spheres are placed at the crack junctions to add softening and realism.

### 4. **Body palette** — The primary colors are sand_dark, dune_shadow, and accent_gold, used for the main body and deeper cracks. A subtle overlay of dry_vegetation is used on some edge regions to simulate sand encrustation.

### 5. **uBase marker assignments per surface** — 

| Surface         | uBase |
|----------------|-------|
| Main crack     | 32    |
| Fine fractures | 33    |
| Sand encrust   | 34    |
| Shadow area    | 0     |

### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.6 to 1.2. The variation allows for natural appearance across the dune field, where some patches are more prominent and others are subtle. The range is chosen to reflect real-world crack sizes.

### 7. **Y rotation** — Random `0..2π` rotation to avoid repetitive alignment and increase visual diversity.

### 8. **Ground anchor** — Partially buried, with the base sitting at y = -0.05 to simulate a slight depression in the sand, giving a natural look.

### 9. **Procedural variation method** — Instances vary in rotation, scale, and slight UV offsets to avoid repetition. A palette hash is used to assign the color variation per instance.

### 10. **Spawn placement rules** — Spawns within a 10–25 m radius from a zone center, preferentially placed in open dunes and away from ruins or oases. Avoids within 6 m of path centerline.

### 11. **Spawn count rationale** — With a 450 m radius zone and 140 instances, each patch is spaced approximately 3.5 m apart on average. This ensures visual density without overcrowding, while maintaining the desert’s sense of vastness and dryness.

### 12. **Clustering pattern** — Scattered-grid pattern. Instances are placed in a loose grid, but with slight offsets to avoid perfect symmetry and give a more natural feel.

### 13. **Inter-asset spacing minimum (m)** — Minimum 2.5 m from another instance of the same mesh to ensure visual distinction and prevent clumping.

### 14. **Path-clearance distance (m)** — Must not spawn within 6 m of any path centerline. This allows the cracks to blend naturally into the dunes while not interfering with player movement.

### 15. **Team color reasoning** — TEAM=41 is chosen to group it with other dried-mud and cracked terrain assets. It resolves to sand_dark in the `game_fill_draws` switch, giving it consistent color behavior with other desert terrain.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow, and uses ambient-occluded vertex colors to simulate the crack depth and contact with sand. No additional AO blob is needed.

### 17. **Distant-LOD strategy** — No LOD currently implemented. The asset will remain visible at full detail up to the full map view distance, matching forest’s current strategy.

### 18. **Animation, if any** — Static, no animation. The asset does not move or change visually over time.

### 19. **Particle FX bound to entity** — None. The asset does not spawn any attached particle effects.

### 20. **Lighting interaction** — The crack patch catches warm sunlight on its western face and casts a soft shadow to the east. It does not self-shadow, as its depth is minimal.

### 21. **Collision** — Does not block player movement. `world.radius` is set to 0.1, allowing players to walk through it without obstruction.

### 22. **Destructible** — No. This asset is not destructible in v1.

### 23. **Lore hook** — These cracks mark where the desert’s surface once gave way to hidden underground water sources, now long dry.

### 24. **Surface UV layout** — The main crack surface uses uBase 32, fine fractures use 33, sand encrustation uses 34, and the shadowed regions default to 0.

### 25. **Material specularity** — Matte. The surface is intentionally rough and non-reflective to match the texture of dried mud and sand.

### 26. **Day/night appearance shift** — Sun-side is warm and tanned, with accent_gold highlights. Shadow-side is cool and dusky, using dune_shadow to simulate the cooler tone.

### 27. **Silhouette test at 50 m** — Yes, the asset still reads clearly at 50 m. It maintains a recognizable crack pattern at this distance, with minimal scale reduction required.

### 28. **Visual neighbours** — Looks best next to sand-dunes, bone_pale rocks, and dry_vegetation. It complements the overall desert aesthetic by reinforcing the idea of weathered terrain.

### 29. **Visual conflicts** — Should not be placed near large, bright sandstone outcrops or in areas with high particle density, as it would clash visually with the bright and clean textures.

### 30. **Implementation hooks** — 

- In `src/main.zig`, add `case 41: return .crack_patch` to the `world.team` switch.
- In `ios/Mesh.swift`, add a `makeCrackPatch(device:)` function.
- In `ios/GameViewController.swift`, add a `dispatchCrackPatch()` case to the spawn logic.
---

## Asset 38 — sandstone_spire
### 1. Silhouette at 30m
From 30 meters away, the sandstone spire appears as a tall, vertical tapering column that cuts through the dune landscape, with a weathered, slightly flared top that suggests erosion by wind and sand over time.

### 2. Tri-budget breakdown
The mesh is allocated as follows: 380 tris for the main body, 80 for surface details and minor weathering, and 20 for any small decorative elements or cracks — totaling exactly 480 tris.

### 3. Geometry construction
The core of the spire is constructed using a `mbCylinder` with a vertical taper from base to top, using 20 rings and 24 sides for smoothness. A `mbSphere` is added to the top to simulate a worn and rounded weathered cap. Optional extruded ring elements are placed at mid-height to suggest natural stratification or ancient weathering lines. The mesh is built using a stack of slightly offset plates or fan of triangles for fine surface texture.

### 4. Body palette
The primary color palette uses `rock_warm`, `sand_light`, and `dune_shadow` to represent the main body, while `accent_gold` is used sparingly on top surfaces to simulate mineral deposits or sun-bleached highlights.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Main body      | 0     |
| Top cap        | 36    |
| Cracks & edges | 0     |
| Weathering     | 36    |

### 6. Base scale (scale_min, scale_max)
Scale ranges from 1.2 to 1.8. This spread ensures visual variety without losing the structural integrity of the column, and allows for both smaller desert outcroppings and taller spires to coexist in the same zone.

### 7. Y rotation
Random `0..2π` rotation to avoid repetitive alignment and give a natural, organic feel to the placement across the dunes.

### 8. Ground anchor
The spire sits flat on y=0 with a slight portion (5%) of the base partially buried to simulate natural settling into the sand.

### 9. Procedural variation method
Variation is achieved through a palette hash based on the instance’s world position, which determines the exact color tint of the surface. Additionally, a random scale spread of ±0.15 and slight rotation variance (±0.1 radians) are applied.

### 10. Spawn placement rules
Spawns are allowed within a 5–45m radius from origin. Prefers open dunes, avoiding oases and ruins. Must not be placed within 8m of the centerline of any path.

### 11. Spawn count rationale
With an 80-instance estimate in a 450m radius zone, and a role of "tall vertical stone column", the count ensures a strong visual presence without overwhelming the terrain. The spires are rare enough to be memorable but frequent enough to suggest a geological feature.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to appear naturally, with no tight clustering. This avoids a sense of artificiality while still maintaining the impression of a geological formation.

### 13. Inter-asset spacing minimum (m)
Minimum 10m spacing from any other instance of the same mesh.

### 14. Path-clearance distance (m)
Can spawn within 6m of a path centerline, but only if the terrain allows for it and does not visually conflict with the path’s structure.

### 15. Team color reasoning
TEAM=42 is chosen to align with desert stone team colors in the `world.team` switch. The team resolves to `rock_cool` in `game_fill_draws`, which gives a consistent and visually cohesive look across desert rock assets.

### 16. Shadow / contact AO strategy
The spire casts a long, soft shadow that extends 3–4x its height. It does not have a ground AO blob; instead, it relies on ambient occlusion in the vertex colors to simulate subtle contact with the sand.

### 17. Distant-LOD strategy
No LOD is planned for v1. The asset is designed to be visually distinct even at far distances. It should remain visible at 100m or beyond, but with no simplification.

### 18. Animation, if any
Static, no animation. The asset is intended to be a timeless, weathered structure.

### 19. Particle FX bound to entity
None. No particle effects are bound to the asset.

### 20. Lighting interaction
The spire catches warm sunlight on its western face, casting a long shadow to the east. The sun-side is tinted with `accent_gold`, while the shadow-side uses `rock_cool` to create a cool contrast.

### 21. Collision
Yes, it blocks player movement. The `world.radius` is set to 1.0 to allow for a tight but realistic collision envelope around the spire.

### 22. Destructible
No. This asset is not intended to be destructible in v1.

### 23. Lore hook
This spire is a remnant of an ancient sandstone formation that once stood as a beacon for caravans crossing the desert, now weathered and worn by centuries of sandstorms.

### 24. Surface UV layout
Main body uses `uBase=0`, top cap uses `uBase=36`, and cracks and fine weathering are also mapped to `uBase=0` to preserve continuity in material sampling.

### 25. Material specularity
Matte with soft-glossy highlights on top surfaces to simulate sun-bleaching and mineral deposits.

### 26. Day/night appearance shift
The sun-side of the spire takes on a warm `accent_gold` tint during the day, while the shadow-side shifts toward `rock_cool`. At night, the entire structure retains a muted, earthy tone.

### 27. Silhouette test at 50 m
At 50m, the spire still reads clearly as a vertical column. Its silhouette is distinct and recognizable, even at half the map's average view distance, with a minimum scale of 0.9 to maintain legibility.

### 28. Visual neighbours
This spire looks best next to `desert_rock_cluster`, `sand_dune`, and `cactus_solo`, which complement its barren, dry environment and provide a natural visual context.

### 29. Visual conflicts
It should not be placed near large `bone_pile` or `oasis_tree` assets, as these would clash with its dry, weathered silhouette and could overcrowd the visual space.

### 30. Implementation hooks
- Add `case 42:` to `world.team` switch in `src/main.zig`
- Add `func makeSandstoneSpire(device: MTLDevice) -> Mesh` to `ios/Mesh.swift`
- Add `case 38:` to `dispatchMesh` in `ios/GameViewController.swift`
---

## Asset 39 — sandstone_arch
### 1. Silhouette at 30m
The archway presents a clean, arched silhouette that cuts through the dune horizon, offering a clear visual anchor for players navigating the desert terrain.

### 2. Tri-budget breakdown
Body: 480 tris, Decorations: 40 tris, FX: 20 tris. Total: 540 tris.

### 3. Geometry construction
The main body is constructed from a single `mbCylinder` with a taper from top to bottom, forming the archway's outer shell. The inner void is created by a smaller, concentric cylinder, producing a solid ring structure. A few `mbSphere` elements are added for small rock nubs and texture detail on the arch’s edge. The arch is extruded with a consistent ring thickness and capped with a few fan-of-triangles segments for visual depth.

### 4. Body palette
The main body uses `rock_warm` for the primary surface, `sand_dark` for the shadowed under-sides, and `accent_gold` for subtle highlights on the outer edge. A small portion of `dune_shadow` is used on the bottom to simulate erosion or sand accumulation.

### 5. uBase marker assignments per surface
| Surface | uBase |
|--------|-------|
| Arch outer shell | 0 |
| Inner void | 36 |
| Edge nubs | 0 |
| Shadowed base | 8 |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.9 to 1.3. The lower bound ensures the arch isn't too fragile, while the upper bound allows for visual variation without losing structural integrity.

### 7. Y rotation
Random `0..2π` rotation to prevent the arches from feeling aligned or uniform.

### 8. Ground anchor
Partially buried, sitting at y = -0.2, to give a natural, weathered look and anchor the structure into the sand.

### 9. Procedural variation method
Variation is driven by a palette hash derived from the instance’s world position and a fixed seed, affecting surface coloration and small-scale geometry offsets.

### 10. Spawn placement rules
Spawns within a 35–45m radius of the zone origin, preferentially near dune ridges and away from oases or ruins. Avoids placement within 6m of any path centerline to preserve clear movement routes.

### 11. Spawn count rationale
With a 450m zone radius and a role as a navigational landmark, 50 instances are enough to provide visual interest and structure without overloading the space or creating a cluttered feel.

### 12. Clustering pattern
Scattered-grid. Instances are distributed to avoid tight clustering, allowing for a natural desert feel with clear sightlines between arches.

### 13. Inter-asset spacing minimum (m)
Minimum 15m from another instance of the same mesh.

### 14. Path-clearance distance (m)
Can spawn as close as 8m from a path centerline.

### 15. Team color reasoning
TEAM=42 aligns with the desert’s natural color palette and ensures the archway fits within the team’s visual grouping, resolving to `rock_warm` in the `game_fill_draws` switch.

### 16. Shadow / contact AO strategy
It casts a soft shadow and uses ambient-occluded vertex colors to enhance depth and realism, especially on the inner arch.

### 17. Distant-LOD strategy
No LOD currently. The asset is kept visible at all distances to maintain visual anchor in the desert.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None.

### 20. Lighting interaction
The arch catches warm sunlight on its western face, casting a long shadow to the east. The sun-side surface is tinted with `rock_warm`, while the shaded side leans into `rock_cool`.

### 21. Collision
Yes, it blocks movement. `world.radius` is set to 1.2 to allow passage underneath.

### 22. Destructible
No.

### 23. Lore hook
The arch was formed by centuries of wind and sand erosion, marking the site of an ancient caravan route that once crossed the dunes.

### 24. Surface UV layout
`uBase=0` covers the outer shell and edge nubs; `uBase=36` covers the inner void; `uBase=8` covers the shadowed base.

### 25. Material specularity
Soft-glossy, with subtle reflectivity to mimic sandstone’s natural texture.

### 26. Day/night appearance shift
Sun-side surfaces warm to `rock_warm` with a hint of `accent_gold`, while shadow-side surfaces shift to a cooler `rock_cool` tint.

### 27. Silhouette test at 50 m
Yes, it maintains a clear silhouette at 50m, and no scale adjustment is needed to ensure readability.

### 28. Visual neighbours
Looks best next to `sandstone_boulder`, `dune_ripple`, and `cactus_spine` — all desert elements that complement its rugged aesthetic.

### 29. Visual conflicts
Should not be placed near `bone_pile` or `desert_tower`, as the combination would create visual clutter or compete for attention in the same space.

### 30. Implementation hooks
- In `src/main.zig`, add `case 42: return "sandstone_arch";` to the `world.team` switch.
- In `ios/Mesh.swift`, add `func makeSandstoneArch(device: MTLDevice) -> MeshBuffers` function.
- In `ios/GameViewController.swift`, add `case 39: self.spawnSandstoneArch(device: device)` to the mesh dispatch.
---

## Asset 40 — weathered_boulder
### 1. Silhouette at 30m
The weathered boulder presents a rounded, irregular mass that sits partially embedded in the sand, with a slightly domed top and a flat base, giving it a distinctively weathered, ancient appearance.

### 2. Tri-budget breakdown
Body: 240 tris, Decorations: 30 tris, FX: 10 tris. Total: 280 tris.

### 3. Geometry construction
The core of the boulder is constructed from a single `mbSphere` with a soft, rounded edge. A tapered `mbCylinder` is then used to create a slight neck-like narrowing near the base. Decorative surface details are added using a series of extruded rings and small plate stacks to simulate weathering, cracks, and embedded minerals.

### 4. Body palette
The main body uses `rock_warm` for the bulk of the surface, with `sand_dark` applied to the lower, partially buried regions. `dune_shadow` and `accent_gold` are used for subtle highlights and mineral streaks.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Main body     | 0     |
| Partially buried | 0  |
| Cracks        | 0     |
| Mineral streaks | 0   |
| Highlight     | 0     |

(All surfaces use uBase=0 — the boulder is a single-shader asset; surface variation comes from per-vertex color hash and lighting, not uBase branching, since this asset only has uBase 0 reserved.)

### 6. Base scale (scale_min, scale_max)
Scale range: 0.9 to 1.4. The range allows for natural variation in size while maintaining the asset’s “rounded large boulder” role and ensuring it doesn’t look disproportionately small or massive in the desert environment.

### 7. Y rotation
Random `0..2π`. Rotation is fully random to avoid uniformity and add natural variation to the boulder field.

### 8. Ground anchor
Partially buried, with 20% of its volume below the y=0 plane. This allows it to look naturally integrated into the dunes.

### 9. Procedural variation method
Variation is achieved through a combination of scale spread (0.9–1.4), random rotation (0..2π), and a palette hash-based variation of accent colors (e.g., `accent_gold`, `accent_turquoise`, `bone_pale`) to simulate natural weathering and mineral exposure.

### 10. Spawn placement rules
Spawn radius from origin: 10–450m. Prefers open dunes or near bone fields. Avoids spawning within 6m of path centerline. Should not appear near other large rocks or clusters.

### 11. Spawn count rationale
With `est_count = 100` in a 450m zone, the boulder is placed sparsely enough to not overcrowd the environment, yet sufficiently to act as a natural landmark and visual anchor in the desert.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to avoid forming clusters, ensuring each boulder is visually distinct and contributes to the overall desert landscape.

### 13. Inter-asset spacing minimum (m)
Minimum spacing: 8 meters from any other instance of the same mesh. Ensures visual separation and natural spread.

### 14. Path-clearance distance (m)
Can spawn as close as 6 meters from a path centerline. This allows it to contribute to the desert’s natural texture near trails, but avoids cluttering the path itself.

### 15. Team color reasoning
TEAM=43 is chosen to align with “rocky terrain” in the game's color switch. The team color resolves to `rock_warm` in `game_fill_draws`, consistent with the asset’s color scheme and biome.

### 16. Shadow / contact AO strategy
Casts a soft shadow, with contact AO blob at the base to simulate the sand beneath. No vertex color AO is used, as the asset’s shape and lighting are handled via material and light setup.

### 17. Distant-LOD strategy
No LOD implemented at this time. The asset is designed to be visually rich even at a distance and aligns with the forest’s current no-LOD policy.

### 18. Animation, if any
Static, no animation. The boulder is meant to remain immovable and stable, reinforcing its role as a natural terrain feature.

### 19. Particle FX bound to entity
None. No FX is bound to the boulder, as it is not a source of environmental effects.

### 20. Lighting interaction
The boulder catches warm sunlight on its west-facing side, with a cooler shadow cast to the east. Its surface is slightly self-shadowed due to its rounded form, giving a natural appearance under desert sun.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.6 to reflect its physical size and prevent the player from walking through it.

### 22. Destructible
No. The boulder is not destructible in v1. It serves as a static terrain feature.

### 23. Lore hook
A remnant of an ancient sandstorm that carved this massive boulder from the dune’s core, now weathered smooth by centuries of wind and time.

### 24. Surface UV layout
Main body uses `uBase = 0`. Partially buried surface uses `uBase = 1`. Cracks and surface details use `uBase = 2`. Accent mineral streaks use `uBase = 3`. Highlights use `uBase = 4`.

### 25. Material specularity
Soft-glossy. The surface has a slight sheen to simulate weathered rock that reflects ambient light softly.

### 26. Day/night appearance shift
The sun-facing side is tinted with a warm `rock_warm` and `accent_gold`, while the shadowed side takes on a cooler `dune_shadow` and `rock_cool` hue, enhancing the desert’s diurnal contrast.

### 27. Silhouette test at 50 m
Yes, it still reads as a distinct boulder at 50m. The rounded silhouette is preserved, and no scale adjustment is needed to maintain legibility.

### 28. Visual neighbours
Looks right next to `desert_cactus`, `bone_field`, and `sand_dune`. These assets complement the boulder’s appearance and reinforce the desert’s barren, ancient texture.

### 29. Visual conflicts
Should not appear near large clusters of `sand_stone`, as it would create silhouette clutter. Also avoids proximity to `oasis_palm` or `brazier` to maintain desert realism and avoid over-ornamentation.

### 30. Implementation hooks
- Add `case 43: return .weathered_boulder` in `src/main.zig`
- Add `makeWeatheredBoulder(device:)` in `ios/Mesh.swift`
- Add `case 40:` in `dispatchMesh` in `ios/GameViewController.swift` to call `makeWeatheredBoulder`
---

## Asset 41 — mesa_flat
### 1. Silhouette at 30m
From 30 meters away, the mesa_flat appears as a low, flat-topped plateau with a gently sloping rim, resembling a weathered sandstone outcrop. Its broad, smooth top surface makes it easy to distinguish from the surrounding dunes.

### 2. Tri-budget breakdown
The mesh is constructed with 240 triangles for the body, 100 for decorations (small rock protrusions), and 20 for FX (dust particles or ambient lighting effects). Total: 360 triangles.

### 3. Geometry construction
The core geometry is built using an `mbCylinder` with a wide base and shallow taper to form the flat-topped mesa. The rim is constructed with a series of extruded rings to add subtle elevation. Decorative elements are added using `mbSphere` to place small rock nubs or sand bumps around the surface. No complex procedural generation is used; it is a static cluster of primitive shapes.

### 4. Body palette
The primary color is `rock_warm`, covering the main body. `sand_light` is used for the top surface to simulate sun-warmed sand. `dune_shadow` adds contrast on the lower slopes. Accent colors like `accent_gold` appear on small protruding rocks to suggest mineral deposits.

### 5. uBase marker assignments per surface
| Surface             | uBase |
|---------------------|-------|
| Main body           | 0     |
| Top flat surface    | 36    |
| Rim edges           | 0     |
| Decorative rocks    | 36    |
| Emissive (if used)  | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.9 to 1.2. The range is chosen to maintain visual variation without losing the flat-top character of the mesa. Smaller instances would be lost in the dune terrain, while larger ones would dominate the scene.

### 7. Y rotation
Random `0..2π` rotation to ensure natural-looking placement across the terrain and avoid repetitive alignments.

### 8. Ground anchor
The mesh is partially buried, sitting with its base 0.1–0.2 meters below the ground plane to simulate weathered erosion and natural settling into the dune.

### 9. Procedural variation method
Variation is achieved through palette hashing and a small scale spread. A hash-based system adjusts the color intensity of rock_warm and sand_light, and each instance has a random scale within the 0.9–1.2 range.

### 10. Spawn placement rules
Spawns occur within 3–20 meters of a dune’s center point, preferring open dune areas. They are avoided within 6 meters of any path centerline and not placed near large vegetation or ruins.

### 11. Spawn count rationale
With a 450m biome zone radius and EST_COUNT = 50, this asset is placed sparsely enough to avoid cluttering the dune landscape, yet frequent enough to support the "flat-topped low mesa formation" role in the desert.

### 12. Clustering pattern
Scattered-grid pattern with a loose clustering of 2–3 instances per cluster. Instances are not strictly aligned but placed in a visually cohesive manner to suggest natural erosion and weathering.

### 13. Inter-asset spacing minimum (m)
Minimum 10 meters from another instance of the same mesh to ensure visual separation and avoid overcrowding.

### 14. Path-clearance distance (m)
Must be at least 8 meters from the path centerline to avoid conflict with walkable areas and maintain player movement clarity.

### 15. Team color reasoning
TEAM=42 is chosen to group this rock formation with warm, desert-toned assets in the `world.team` switch. It resolves to `rock_warm` in the `game_fill_draws` switch, ensuring consistent visual treatment with other desert rock formations.

### 16. Shadow / contact AO strategy
Casts a soft shadow due to its flat-top and low profile. No ground AO blob is used; instead, vertex colors are slightly darkened in shadowed areas for ambient occlusion.

### 17. Distant-LOD strategy
No LOD is implemented at this time, following the forest asset model. The mesh is rendered at full detail across all distances.

### 18. Animation, if any
Static, no animation. The mesh does not move or pulse to maintain its grounded, natural feel.

### 19. Particle FX bound to entity
None. The asset does not include particle effects.

### 20. Lighting interaction
The west-facing side of the mesa catches warm sunlight, tinted with `accent_gold`. The east-facing side is cool and shadowed, with `dune_shadow` tones. It is self-shadowed on the lower slopes.

### 21. Collision
Yes, it blocks player movement. Collision radius is set to `world.radius = 0.75` to reflect its solid, flat-top structure.

### 22. Destructible
No. This asset is not destructible in v1.

### 23. Lore hook
This mesa was once the base of a collapsed sandstone tower, eroded by centuries of wind and rain into a flat, stable plateau.

### 24. Surface UV layout
- `uBase = 0`: Main body and rim edges.
- `uBase = 36`: Top flat surface and decorative rocks.
- `uBase = 8`: Emissive elements, if used.

### 25. Material specularity
Matte. The surface is rough and lacks any reflective properties, consistent with weathered sandstone.

### 26. Day/night appearance shift
The sun-facing side appears warm with `rock_warm` and `accent_gold` tints, while the shadowed side shifts to `dune_shadow` and `rock_cool`. The contrast enhances the natural dune lighting.

### 27. Silhouette test at 50 m
Yes, the silhouette remains clearly recognizable at 50 meters. The flat top and rim profile are still distinct even at this distance, with no need for increased scale.

### 28. Visual neighbours
This asset looks right next to `dune_crest`, `sandstone_rock`, and `dry_vegetation` clusters. It complements the soft, rolling terrain of the desert.

### 29. Visual conflicts
It should not be placed near `oasis_pool`, `brazier`, or `ruins_entrance` as these would visually compete for attention and disrupt the natural dune composition.

### 30. Implementation hooks
- `src/main.zig`: Add `case 42` to `world.team` switch.
- `ios/Mesh.swift`: Add `makeMesaFlat(device:)` function.
- `ios/GameViewController.swift`: Add `case 41` dispatch to `spawnMesh()`.

```metal
// Pseudocode for vertex shader behavior
vertex float4 vertexShader(VertexIn in [[stage_in]], constant float4x4& modelViewProjectionMatrix [[matrix_projection]]) {
    float4 position = float4(in.position, 1.0);
    return modelViewProjectionMatrix * position;
}
```
---

## Asset 42 — hoodoo
### 1. Silhouette at 30m
From 30 meters away, the hoodoo appears as a tall, thin, vertical pillar with a slight tapering toward its summit, giving it a delicate, almost ethereal profile that rises dramatically from the dune surface.

### 2. Tri-budget breakdown
Body: 280 tris; Decorations: 20 tris; FX: 20 tris. Total: 320 tris.

### 3. Geometry construction
The base of the hoodoo is built as a tall, slightly tapered cylinder using `mbCylinder`, with a radius that decreases from base to top to simulate a natural erosion effect. A small spherical cap is added atop the cylinder to represent the stone's weathered top. The surface is then refined with a few extruded rings near the base to suggest subtle vertical striations.

### 4. Body palette
The main body uses `rock_warm`, `dune_shadow`, and `sand_dark` for its primary surfaces. A small accent of `accent_gold` is used on the top-facing surface to simulate sun-warmed stone.

### 5. uBase marker assignments per surface
| Surface        | uBase |
|----------------|-------|
| Base cylinder  | 0     |
| Top sphere     | 36    |
| Striation rings| 0     |
| Accent top     | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.3. The lower bound ensures it remains visually integrated with dune terrain, while the upper bound allows for variation without becoming too imposing or losing its thin, vertical character.

### 7. Y rotation
Random `0..2π` rotation to break monotony and simulate natural placement across the desert.

### 8. Ground anchor
Partially buried — the base sits at y=0, but the bottom 10% of the cylinder is offset below ground level to simulate erosion and root-like settling.

### 9. Procedural variation method
Variations are driven by a combination of palette hash (for color variation), scale spread (0.8–1.3), and random Y-axis rotation. No sub-mesh subsets are used.

### 10. Spawn placement rules
Spawn radius: 5–10 m from origin. Prefers open dunes and avoids areas near oases or ruins. Must not spawn within 6 m of path centerline.

### 11. Spawn count rationale
With a 450 m radius and role as a tall, vertical landmark, 80 instances ensure enough visual variety and presence to anchor the dune landscape without overcrowding. The asset is sparse enough to stand out but frequent enough to create a sense of environmental storytelling.

### 12. Clustering pattern
Scattered-grid. Instances are placed in a loose grid, avoiding strict alignment, to simulate natural erosion and drift.

### 13. Inter-asset spacing minimum (m)
Minimum 12 m spacing from other instances of the same mesh.

### 14. Path-clearance distance (m)
Must be at least 8 m from path centerline.

### 15. Team color reasoning
TEAM=42 is chosen to represent the "stone" faction in the game’s color team system. The team color resolves to `rock_warm` in the `game_fill_draws` switch, aligning with the desert stone aesthetic.

### 16. Shadow / contact AO strategy
Casts a soft, long shadow due to its tall, thin profile. Uses ambient-occluded vertex colors to simulate subtle contact AO on the base and lower sides.

### 17. Distant-LOD strategy
No LOD currently implemented. The asset should follow the forest’s current no-LOD policy unless performance issues arise.

### 18. Animation, if any
Static, no animation. The asset is intended to remain motionless to maintain its mythic, weathered appearance.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset.

### 20. Lighting interaction
The west-facing surface catches warm sunlight and glows slightly, while the east-facing side is in shadow, giving it a subtle, directional warmth that shifts with the sun.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.5 to reflect its solid, vertical form.

### 22. Destructible
No. The asset is not destructible in v1.

### 23. Lore hook
The hoodoo was once a sacred pillar, carved by ancient hands to mark the location of a lost temple.

### 24. Surface UV layout
uBase 0 covers the main body and striation rings; uBase 36 covers the top sphere; uBase 8 covers the golden accent on the top.

### 25. Material specularity
Soft-glossy — slightly reflective to simulate weathered stone, but not overly shiny.

### 26. Day/night appearance shift
Sun-facing surfaces are warm-toned with a golden tint, while shadowed sides take on a cool, blue-gray hue. The overall character remains consistent but shifts in warmth with the sun.

### 27. Silhouette test at 50 m
Yes, the asset still reads clearly as a tall, thin pillar at 50 m. Minimum scale required is 0.6 to maintain readability at this distance.

### 28. Visual neighbours
Looks right next to `dune_boulder`, `cactus_fan`, and `ruin_stone`. These assets complement the desert aesthetic and create a natural grouping.

### 29. Visual conflicts
Should not be placed near other tall, thin structures like `tall_cactus` or `bone_tower`, as they would visually compete and dilute the silhouette of both.

### 30. Implementation hooks
- Add `case 42: return .hoodoo` in `src/main.zig` in the `world.team` switch.
- Add `func makeHoodoo(device: MTLDevice) -> Mesh` to `ios/Mesh.swift`.
- Add `case 42: mesh = makeHoodoo(device: device)` in `ios/GameViewController.swift`.
---

## Asset 43 — rib_arch
### 1. Silhouette at 30m
The rib_arch presents a sweeping, curving arc of fossilized bone that reads as a long-dead beast's ribcage rising from the dunes, with a prominent, sinuous profile that catches the eye from a distance and evokes ancient, sprawling death.

### 2. Tri-budget breakdown
The mesh is split as follows: body = 300 tris, decorations = 50 tris, FX = 30 tris. This allocation accounts for the large, flowing structure of the rib, its subtle surface details, and minimal particle effects.

### 3. Geometry construction
The core structure is built using a single `mbCylinder` with a tapering radius along its length to simulate a curved rib, with a slight inward curve. Additional segments are added via extruded ring geometry to form a ribbed surface effect. The ends are capped with `mbSphere` primitives to give the structure a more organic, worn edge, mimicking weathered bone.

### 4. Body palette
The primary color scheme is bone_pale (0.92, 0.88, 0.78) for the main surface, with sand_light (0.95, 0.85, 0.70) for high-contrast areas and dune_shadow (0.40, 0.30, 0.25) for shaded valleys. Accent_gold (0.95, 0.78, 0.30) is used for a subtle sheen on top-facing surfaces to simulate weathering and light reflection.

### 5. uBase marker assignments per surface
| Surface             | uBase |
|---------------------|-------|
| Main rib body       | 0     |
| Curved edges        | 37    |
| Shaded crevices     | 0     |
| Top-facing sheen    | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.9 to 1.3. This allows for variation in size without altering the structural integrity of the rib, and supports visual diversity while maintaining consistent silhouette and scale at 30m.

### 7. Y rotation
Random `0..2π` rotation is used to provide visual variety and ensure the rib doesn't look uniform across spawns, while preserving its arc shape.

### 8. Ground anchor
The rib is partially buried, sitting with 20% of its volume below the y=0 plane, allowing it to rest naturally in the dune surface, with the curve pointing toward the horizon.

### 9. Procedural variation method
Variation is achieved through a combination of random scale and rotation, as well as a palette hash to determine accent colors, ensuring no two instances look identical.

### 10. Spawn placement rules
Instances are placed with a 10–20 m radius from the zone origin, preferably in open dunes, avoiding any area within 6 m of a path centerline. Preference is given to areas with low vegetation and high sand exposure.

### 11. Spawn count rationale
With a 450 m radius zone and EST_COUNT=30, the rib_arch is spaced to provide a sparse, evocative presence. This number allows the asset to appear significant and rare without overcrowding the space or creating visual fatigue.

### 12. Clustering pattern
Scattered-grid. Instances are spaced widely to avoid visual clashing, with a tendency to cluster near the edges of zones to suggest a long-dead creature's remains scattered over a large area.

### 13. Inter-asset spacing minimum (m)
Minimum spacing is 15 meters from another instance of the same mesh to ensure individual presence and avoid silhouette overlap.

### 14. Path-clearance distance (m)
Can spawn within 5 meters of the path centerline, as its shape is not disruptive and the silhouette is clearly distinct from path features.

### 15. Team color reasoning
TEAM=44 is chosen to distinguish it from other bone-type assets and align with a neutral, weathered, fossilized aesthetic. It resolves to bone_pale (0.92, 0.88, 0.78) in `game_fill_draws`.

### 16. Shadow / contact AO strategy
It casts a soft shadow with ambient-occluded vertex colors, giving the impression of weight and age. The ground AO blob is minimal, relying on natural dune contouring.

### 17. Distant-LOD strategy
No LOD is implemented at this time, following the forest’s current behavior. The asset is intended to remain visible and recognizable up to the full map distance.

### 18. Animation, if any
Static, no animation. The asset is designed to be a still, imposing relic that doesn’t require movement to convey its narrative.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset. Future optional additions could include `embers` or `oasis_droplets` for ambient storytelling, but none are required for v1.

### 20. Lighting interaction
The rib is self-shadowed on the lower side, and the sun-facing side catches warm sunlight with an amber tint, especially in the early or late hours. The accent_gold highlights respond to sun direction, enhancing the weathered character.

### 21. Collision
Collision is enabled with `world.radius` = 0.6. It blocks player movement but not significantly, as the rib is more of a visual landmark than a physical obstacle.

### 22. Destructible
No. This asset is not destructible in v1, as it is meant to be a static relic and not a dynamic element of gameplay.

### 23. Lore hook
This rib is the remnant of a massive, ancient creature that once roamed the desert, now fossilized and buried under shifting sands, its bones a testament to the world’s forgotten past.

### 24. Surface UV layout
The main body uses uBase 0 for the primary surface. The curved edges and crevices are assigned uBase 37. The top-facing sheen area uses uBase 8 for emissive or highlight effects.

### 25. Material specularity
Soft-glossy. The surface has a slight sheen to simulate weathering, but not enough to appear metallic or reflective, maintaining the natural fossilized look.

### 26. Day/night appearance shift
During the day, the sun-facing side is warm-toned with an amber tint, while the shadowed side cools to a muted gray-blue. At night, the entire structure appears desaturated, blending into the ambient desert hue.

### 27. Silhouette test at 50 m
Yes, the rib_arch still reads clearly at 50m. Its curving arc and scale are sufficient to maintain visual identity, even at half the average map view distance.

### 28. Visual neighbours
This asset looks right next to `bone_pile`, `sand_dune`, and `cracked_rock`, which all share a fossilized or weathered desert theme and support its narrative presence.

### 29. Visual conflicts
This asset should not be placed near `brazier`, `oasis_spring`, or `desert_tower`, as these elements would overpower or visually clash with the rib’s subtle, ancient tone.

### 30. Implementation hooks
- Add `case 44:` to `world.team` switch in `src/main.zig`.
- Add `func makeRibArch(device:)` to `ios/Mesh.swift`.
- Add `case 43:` to dispatch in `ios/GameViewController.swift` to call `makeRibArch(device:)`.
---

## Asset 44 — skull_pile
1. **Silhouette at 30m** — From a distance of 30 meters, the skull pile appears as a roughly cylindrical, haphazard heap of bleached bone fragments, with a vague suggestion of a human spine emerging from its center.

2. **Tri-budget breakdown** — Body: 240 tris, Decorations: 30 tris, FX: 10 tris. Total = 280 tris, matching EST_TRIS.

3. **Geometry construction** — The mesh is constructed from a central, tapered cylindrical spine (mbCylinder) representing the partial vertebrae, surrounded by a cluster of irregular skull fragments and bone segments (mbSphere) that are arranged in a static, clustered pattern. The base of the pile is formed with a few stacked, slightly offset rings (extruded ring) to suggest an unstable, weathered pile.

4. **Body palette** — The main body uses `bone_pale` for the majority of the skull and spine surfaces, `sand_light` for the outer edges where sand has settled, `rock_warm` for the base and some angular bone edges, and `accent_gold` for subtle highlights on the most weathered or sun-bleached parts.

5. **uBase marker assignments per surface** — 

| Surface      | uBase |
|--------------|-------|
| Main spine   | 0     |
| Skulls       | 37    |
| Sand edges   | 0     |
| Base rings   | 0     |
| Highlights   | 8     |

6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.2. This variation allows for a natural, slightly irregular appearance across the desert, and supports the illusion of weathering and partial burial without making the pile look too uniform or artificial.

7. **Y rotation** — Random `0..2π`. Instances are not aligned to any axis or path, giving the impression of a natural, unstructured accumulation.

8. **Ground anchor** — Partially buried, with a y-offset of -0.15 to 0.05, so that the base of the pile sits slightly below ground level, giving it a weathered, desert-eroded look.

9. **Procedural variation method** — Variation is achieved via a combination of scale spread (0.8–1.2), random rotation, and palette hashing (for subtle color shifts on skull segments). The number of skull fragments and their arrangement is randomized within a fixed set of submeshes.

10. **Spawn placement rules** — Spawn radius range from origin: 2–10 meters. Prefers bone field or open dunes. Avoids within 6 meters of any path centerline and within 3 meters of other skull piles.

11. **Spawn count rationale** — With a 450 m zone radius and a role as a desolate, scattered heap, 50 instances provide a visually meaningful but not overwhelming density that supports a sparse, haunting desert atmosphere.

12. **Clustering pattern** — Scattered-grid. Instances are distributed evenly but not in strict clusters, with occasional pairing or small groupings to imply natural accumulation.

13. **Inter-asset spacing minimum (m)** — 4 meters minimum spacing from another skull_pile instance.

14. **Path-clearance distance (m)** — 6 meters from path centerline. This ensures it does not interfere with movement or sightlines on paths.

15. **Team color reasoning** — TEAM=44 is chosen to group this asset with other desert skeletal or weathered structures. The team color resolves to `bone_pale` in `game_fill_draws`, allowing it to blend with its environment while maintaining a unique visual identity.

16. **Shadow / contact AO strategy** — Casts a soft shadow with a ground AO blob. Uses ambient-occluded vertex colors to enhance the appearance of weathering and depth.

17. **Distant-LOD strategy** — No LOD currently. This asset is not expected to disappear or simplify at any distance, following the current forest strategy.

18. **Animation, if any** — Static, no animation. No movement or motion is intended.

19. **Particle FX bound to entity** — None. The asset is not intended to have active particle effects.

20. **Lighting interaction** — The asset catches warm sunlight on the western face, casting a long shadow to the east. The sun-side is tinted with `accent_gold` and `sand_light`, while the shadow-side takes on a cooler, `rock_cool` hue.

21. **Collision** — Does not block player movement. world.radius = 0.3.

22. **Destructible** — No. It is not intended to be destructible in v1.

23. **Lore hook** — A forgotten shrine’s remains, now a silent testament to the desert’s ancient guardians.

24. **Surface UV layout** — Main spine uses uBase 0, skull fragments use uBase 37, sand edges use uBase 0, base rings use uBase 0, and highlights (emissive) use uBase 8.

25. **Material specularity** — Matte with soft gloss on skull highlights.

26. **Day/night appearance shift** — Sun-side is warm-tinted with `accent_gold` and `sand_light`, while shadow-side is cool with `rock_cool` and `dune_shadow`. The sun-side appears to glow subtly in daylight.

27. **Silhouette test at 50 m** — Yes, the silhouette is still recognizable at 50 meters, even with the base scale at 0.8. The geometry is robust enough to maintain identity at this distance.

28. **Visual neighbours** — Looks right next to `cactus_cluster`, `stone_formation`, and `desert_wreckage`, all of which evoke a similar sense of ancient, weathered ruin.

29. **Visual conflicts** — Should not be near `oasis_palm`, `brazier`, or `water_pool`, as it would clash with lush or clean environments and diminish the desert’s harshness.

30. **Implementation hooks** — 
- `src/main.zig`: Add `case 44 => .skull_pile` to `world.team` switch.
- `ios/Mesh.swift`: Add `makeSkullPile(device:)` function.
- `ios/GameViewController.swift`: Add `case 44` to the dispatch switch for `spawnEntity`.
---

## Asset 45 — vertebra_chunk
### 1. **Silhouette at 30m** — From a distance, the vertebra chunk appears as a large, irregularly shaped bone structure rising from the sand, its jagged edges and ridges creating a strong silhouette against the desert sky.
### 2. **Tri-budget breakdown** — Body: 180 tris, Decorations: 25 tris, FX: 15 tris. Total: 220 tris.
### 3. **Geometry construction** — The main body is constructed from a series of stacked tapered cylinders to simulate the layered vertebrae, each with slight variation in radius and length. Decorative protrusions are added using small spheres at key points, and the top surface is capped with a flat ring to mimic a natural break or joint.
### 4. **Body palette** — The main body uses `bone_pale` for the core structure, `sand_light` for the top surface to reflect sunlight, `rock_warm` for the bottom to suggest buried depth, and `dune_shadow` for the shaded crevices.
### 5. **uBase marker assignments per surface** —
| Surface         | uBase |
|----------------|-------|
| Core body      | 0     |
| Top cap        | 37    |
| Protrusions    | 0     |
| Shaded crevices| 8     |
### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.8 to 1.3. This ensures visual variety while maintaining the chunk’s large, imposing presence in the dunes.
### 7. **Y rotation** — Random 0..2π rotation. Allows natural variation in how the piece sits in the sand.
### 8. **Ground anchor** — Partially buried, with 20% of the total height below ground level. This gives the illusion of a fossilized bone that has been exposed by sand erosion.
### 9. **Procedural variation method** — Variation is achieved through a palette hash that selects different combinations of `bone_pale`, `rock_warm`, and `dune_shadow` for each instance, and small random offsets in the cylinder radii and sphere placements.
### 10. **Spawn placement rules** — Spawns within 100–450 m radius of origin. Prefers bone field biome. Avoids areas within 6 m of path centerline and within 10 m of water features.
### 11. **Spawn count rationale** — With a 450 m radius and a role as a cluster of large vertebrae, 50 instances provides enough visual density to suggest a fossil field without overwhelming the space or causing occlusion issues.
### 12. **Clustering pattern** — Dense-cluster. Instances are grouped in clusters of 3–5, spaced 8–15 m apart to suggest a natural bone field.
### 13. **Inter-asset spacing minimum (m)** — Minimum 5 meters from another instance of the same mesh.
### 14. **Path-clearance distance (m)** — Cannot spawn closer than 6 meters to path centerline.
### 15. **Team color reasoning** — TEAM=44 is chosen to align with the desert biome's bone and fossil color palette. It resolves to `bone_pale` in `game_fill_draws`, consistent with the asset’s appearance.
### 16. **Shadow / contact AO strategy** — Casts a soft shadow using ambient-occluded vertex colors to suggest the piece's bulk. No ground AO blob is used.
### 17. **Distant-LOD strategy** — No LOD currently. Will disappear at 200 m distance in future, or be replaced with a simplified mesh if implemented.
### 18. **Animation, if any** — Static, no animation.
### 19. **Particle FX bound to entity** — None.
### 20. **Lighting interaction** — The asset catches warm sunlight on its western-facing ridges, casting long shadows to the east. The shaded side takes on a cool, gray tone.
### 21. **Collision** — Blocks player movement. `world.radius` set to 0.8.
### 22. **Destructible** — No.
### 23. **Lore hook** — This chunk is a remnant of a prehistoric creature that once roamed the ancient desert, now exposed after centuries of wind erosion.
### 24. **Surface UV layout** — Core body uses uBase 0, top cap uses uBase 37, protrusions use uBase 0, and shaded crevices use uBase 8.
### 25. **Material specularity** — Soft-glossy, to reflect the worn, sun-weathered texture of a fossil.
### 26. **Day/night appearance shift** — During the day, the sun-side appears warm and golden, while the shadow-side takes on a cooler, grayish hue. At night, the entire piece retains a subtle, muted glow.
### 27. **Silhouette test at 50 m** — Yes, the silhouette remains recognizable at 50 m. The minimum scale required to maintain legibility is 0.7.
### 28. **Visual neighbours** — Looks right next to `sandstone_rock`, `dune_ripple`, and `bone_sculpture` — all desert textures that complement its fossilized feel.
### 29. **Visual conflicts** — Should not spawn near `cactus_cluster`, `oasis_pool`, or `ruins_pillar` as these would create silhouette congestion and visual noise.
### 30. **Implementation hooks** — 
- In `src/main.zig`, add `case 44: return .vertebra_chunk` to `world.team` switch.
- In `ios/Mesh.swift`, add `func makeVertebraChunk(device: MTLDevice) -> MeshBuffers` function.
- In `ios/GameViewController.swift`, add `case 45: self.mesh = makeVertebraChunk(device: device)` to dispatch switch.
---

## Asset 46 — fossil_shell
### 1. **Silhouette at 30m** — The fossil_shell appears as a tall, gently tapered cylinder with a slightly bulging middle, standing like a weathered bone against the dunes, its surface marked by subtle ridges and grooves that catch the light.

### 2. **Tri-budget breakdown** — Body: 170 tris, Decorations: 20 tris, FX: 10 tris. Total = 200 tris, matching EST_TRIS.

### 3. **Geometry construction** — The mesh is built using a central `mbCylinder` with a taper from base to top, representing the fossil's main body. At both ends, `mbSphere` caps are added to simulate the rounded, worn ends of the ammonite shell. A series of extruded rings are added to represent the internal chamber walls and the fossil's spiral structure. A few small fan-of-triangles elements simulate surface texture and cracks.

### 4. **Body palette** — The primary body uses `bone_pale` for the main shell surface, with `dune_shadow` on the shaded sides, `sand_light` for the sun-facing areas, and `accent_gold` for minor texture highlights.

### 5. **uBase marker assignments per surface** —
| Surface        | uBase |
|----------------|-------|
| Main shell     | 37    |
| Interior rings | 0     |
| Cracks         | 41    |
| Top cap        | 0     |
| Bottom cap     | 41    |

### 6. **Base scale (scale_min, scale_max)** — scale_min = 0.8, scale_max = 1.4. This spread allows for natural variation in size while preserving the fossil’s recognizable proportions and ensuring it remains a focal point without overwhelming the environment.

### 7. **Y rotation** — Random `0..2π`. The mesh is not aligned to any axis or path and rotates freely to create a natural look across the dunes.

### 8. **Ground anchor** — Partially buried, sitting with 20% of its height below the ground level (y = -0.15 * scale). This gives it a weathered, exposed look, as if it were half-buried in the sand.

### 9. **Procedural variation method** — Instances vary in scale, surface color tint, and rotation. A hash-based palette offset is used for surface coloring, and the rotation is randomized to prevent grid-like repetition.

### 10. **Spawn placement rules** — Spawn radius from origin: 5–45 m. Prefers bone field biome-zone. Avoids spawning within 6 m of path centerline and near large structures or oases.

### 11. **Spawn count rationale** — With a zone radius of 450 m, the 30 instances ensure that the fossil_shell is rare enough to stand out but frequent enough to support a cohesive, immersive bone field theme.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed with a loose grid pattern to avoid clustering, but not perfectly uniform, to simulate natural erosion and exposure.

### 13. **Inter-asset spacing minimum (m)** — 8 m minimum distance to another instance of the same mesh. This spacing allows for visual breathing room and prevents overloading the desert landscape.

### 14. **Path-clearance distance (m)** — 6 m from path centerline. This ensures the asset does not interfere with player movement or sightlines along the path.

### 15. **Team color reasoning** — TEAM=44 is chosen to align with the `bone` category for consistency. In the `game_fill_draws` switch, this resolves to `bone_pale` (0.92, 0.88, 0.78), which matches the shell’s overall tone.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow using standard directional light. No ground AO blob is used; instead, ambient occlusion is baked into vertex colors for subtle depth.

### 17. **Distant-LOD strategy** — No LOD currently. The asset is static and detailed enough that simplification is not needed at any distance.

### 18. **Animation, if any** — Static, no animation. The fossil is meant to be a still, ancient relic, not a moving object.

### 19. **Particle FX bound to entity** — None. The asset is not intended to emit particles or interact with FX systems.

### 20. **Lighting interaction** — The fossil catches warm sunlight on the west-facing side, casting a long shadow to the east. It is self-shadowed with subtle shading to enhance its three-dimensionality.

### 21. **Collision** — Does not block player movement. `world.radius` set to 0.3 to allow passage through without physical interference.

### 22. **Destructible** — No. The asset is not intended to be destructible in v1.

### 23. **Lore hook** — A remnant of a prehistoric ocean, buried in the desert sands for millennia, now partially exposed by the shifting dunes, a silent testament to the world’s ancient seas.

### 24. **Surface UV layout** — Main shell surface uses uBase 37, interior rings use uBase 0, cracks use uBase 41, and both caps use uBase 0 for consistency and visual coherence.

### 25. **Material specularity** — Soft-glossy. The shell surface has a matte base with subtle gloss highlights to simulate a weathered, mineralized surface.

### 26. **Day/night appearance shift** — The sun-facing side is warm-toned with a subtle orange tint, while the shadowed side is cooler, leaning toward a muted gray-blue. This mimics how desert textures shift under different lighting conditions.

### 27. **Silhouette test at 50 m** — Yes, the asset still reads as a fossil at 50 m. The silhouette remains distinct, and the scale is sufficient to maintain readability at this distance.

### 28. **Visual neighbours** — Looks right next to `sandstone_rock`, `dune_boulder`, `cactus_cluster`, and `bone_shard`. These assets complement its desert, fossilized theme.

### 29. **Visual conflicts** — Should not be placed near `oasis_pool`, `palm_tree`, or `ruin_arch`, as these would create visual clutter or silhouette confusion in the desert setting.

### 30. **Implementation hooks** — 
- In `src/main.zig`, add `case 44: return .fossil_shell` to the `world.team` switch.
- In `ios/Mesh.swift`, add `func makeFossilShell(device: MTLDevice) -> Mesh` function.
- In `ios/GameViewController.swift`, add `case .fossil_shell: dispatchFossilShell()` to the `dispatch` switch.
---

## Asset 47 — saguaro_cactus
### 1. Silhouette at 30m
The saguaro cactus presents a strong, angular silhouette defined by its multi-armed, segmented arms that rise vertically from a thick, central trunk, forming a distinctive desert landmark.

### 2. Tri-budget breakdown
The mesh is divided into 220 triangles for the main body, 60 for decorative spines, and 40 for optional FX such as glowing nodes or leaf-like appendages, summing to exactly 320 triangles.

### 3. Geometry construction
The body is constructed using a tall, tapered `mbCylinder` with 4 rings and 12 sides, representing the central trunk. Multiple `mbCylinder` arms are extruded radially from the trunk’s top, each with a different radius and rotation. Decorative spines are modeled using small `mbSphere` components. A static cluster of 5–8 small segments at the top of the trunk adds the signature "bottlebrush" appearance.

### 4. Body palette
The primary body uses `sand_light`, `sand_dark`, and `dune_shadow` for the trunk, while the spines use `dry_vegetation` and `rock_warm` to differentiate from the ground tone.

### 5. uBase marker assignments per surface
| Surface          | uBase |
|------------------|-------|
| Main trunk       | 0     |
| Arm segments     | 8     |
| Spines           | 0     |
| Top cap          | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 1.0 to 1.6. This allows for natural variation while maintaining the cactus’s silhouette. The minimum ensures it doesn’t appear too fragile or lost in scale, while the max provides enough variation for visual interest.

### 7. Y rotation
Random `0..2π` rotation around the Y-axis to avoid repetitive alignment and ensure natural-looking placement in the dunes.

### 8. Ground anchor
Partially buried, with the base sitting at y = -0.15 to simulate a root-like anchor into the sand, giving a grounded yet organic feel.

### 9. Procedural variation method
Variation is achieved through random scale, spine density, and a palette hash for color shifts between instances, ensuring no two cacti look exactly alike.

### 10. Spawn placement rules
Spawns within a 20–40m radius of origin, preferably in open dunes or near bone fields, avoiding spawning within 6m of any path centerline to preserve navigability.

### 11. Spawn count rationale
With a 450m radius and a role as a signature desert silhouette, 130 instances provide enough visual presence to define the biome without overwhelming or clustering too densely.

### 12. Clustering pattern
Scattered-grid pattern. Instances are spaced to form a sparse, natural look, avoiding tight clusters and mimicking the desert’s irregularity.

### 13. Inter-asset spacing minimum (m)
Minimum 3.5 meters from another instance of the same mesh to prevent visual clutter and maintain distinct silhouette definition.

### 14. Path-clearance distance (m)
Must be placed at least 8 meters from the path centerline to allow for clear sightlines and avoid obstructing movement or visual flow.

### 15. Team color reasoning
TEAM=45 is chosen to align with desert vegetation teams, using `rock_cool` as the base color in the `game_fill_draws` switch, providing a neutral but warm team identity for desert flora.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a small AO blob at its base to suggest contact with the ground, enhancing the realism of its desert placement.

### 17. Distant-LOD strategy
No LOD currently. The asset maintains its full complexity at all distances, consistent with forest’s current policy, as its silhouette remains strong at distance.

### 18. Animation, if any
Static, no animation. The asset is designed to be a still, grounded presence in the world, allowing it to serve as a visual anchor.

### 19. Particle FX bound to entity
None. No particle FX are bound to this asset, as the cactus’s aesthetic is defined by its form and surface texture.

### 20. Lighting interaction
The cactus catches warm sunlight on its west-facing side, casting a long shadow to the east. Its surface texture is designed to reflect sun-warmed tones, enhancing its desert character.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 0.6 to allow for interaction but not walking through, fitting the role of a solid, natural obstacle.

### 22. Destructible
No. This is a static environmental asset, not meant to be destroyed in v1.

### 23. Lore hook
This cactus marks the edge of an ancient settlement, where the last inhabitants once stored water and sheltered from the sun.

### 24. Surface UV layout
The main trunk uses uBase 0 for base color, arms use uBase 8 for emissive highlights, spines use uBase 0 for texture, and the top cap uses uBase 8 for subtle glow.

### 25. Material specularity
Soft-glossy. The surface reflects light gently, enhancing the sandy texture without over-sharpening the edges or appearing too artificial.

### 26. Day/night appearance shift
During the day, the sun-facing side warms with `accent_gold` tones, while the shadow side takes on a cooler `sky_zenith` tint, reinforcing the desert’s contrast and time-of-day character.

### 27. Silhouette test at 50 m
At 50m, the silhouette remains clearly distinguishable, even at half the map’s average view distance. The scale is sufficient to maintain its signature "tall multi-arm" profile.

### 28. Visual neighbours
Looks right next to `sandstone_rock`, `dune_boulder`, and `oasis_palm`, as these assets complement its desert environment and provide contrast in scale and texture.

### 29. Visual conflicts
Should not be placed near `oasis_coral`, `desert_willow`, or `bone_pile`, as these would clutter the silhouette or cause visual overload in the desert landscape.

### 30. Implementation hooks
- `src/main.zig`: Add `case 45: return .saguaro_cactus` in `world.team` switch.
- `ios/Mesh.swift`: Add `func makeSaguaroCactus(device: MTLDevice) -> MeshBuffers` function.
- `ios/GameViewController.swift`: Add `case 47: dispatchMesh(47)` to mesh dispatch logic.
---

## Asset 48 — barrel_cactus
### 1. Silhouette at 30m
From 30 meters away, the barrel_cactus appears as a short, rounded vertical column with a series of evenly spaced ribs, forming a distinctive barrel-like profile that stands out against the flat desert horizon.

### 2. Tri-budget breakdown
The mesh is divided into 180 triangles for the main body, 40 for the crown, and 20 for optional decorative spines, totaling exactly 240 triangles as required.

### 3. Geometry construction
The cactus body is constructed using a single `mbCylinder` with vertical tapering to simulate the natural narrowing at the top, and a series of horizontal rings added to define ribs. A small `mbSphere` is used to form the crown at the top, and optional spines are extruded from the main body using a fan of triangles for each rib.

### 4. Body palette
The main body uses `sand_light`, `sand_dark`, and `dune_shadow` for surface variation. The crown is rendered with `accent_gold` for a warm highlight, and the ribs are subtly shaded with `rock_warm` to emphasize the vertical structure.

### 5. uBase marker assignments per surface
| Surface     | uBase |
|-------------|--------|
| Body        | 0      |
| Crown       | 8      |
| Ribs        | 0      |

### 6. Base scale (scale_min, scale_max)
Scale ranges from 0.6 to 1.0. This ensures the cactus appears appropriately scaled across the desert, with smaller instances for distant visual variety and larger ones for prominence.

### 7. Y rotation
Random `0..2π` rotation to prevent uniform alignment and add natural randomness to placement.

### 8. Ground anchor
Partially buried, with the base sitting at y = -0.1 to simulate the way cacti settle into sand dunes.

### 9. Procedural variation method
Variation is driven by a combination of palette hash (to determine rib coloration), scale spread (0.6–1.0), and a small random rotation on the Y-axis to prevent repetition.

### 10. Spawn placement rules
Spawned within 200–450m radius from origin. Prefers open dune areas, avoiding paths and oases. Avoids spawning within 6 meters of path centerline.

### 11. Spawn count rationale
With an estimated zone radius of 450 meters and a density that allows for 100 instances, this number ensures a visually rich desert environment without overloading the space with similar assets.

### 12. Clustering pattern
Scattered-grid pattern with loose clustering of 2–3 instances per cluster, mimicking natural desert cactus grouping.

### 13. Inter-asset spacing minimum (m)
Minimum 3 meters from any other instance of the same mesh to maintain visual distinction and prevent overcrowding.

### 14. Path-clearance distance (m)
Can spawn within 8 meters of the path centerline, as the cactus is low enough to not obstruct player movement.

### 15. Team color reasoning
TEAM=45 is chosen to align with desert vegetation team, which maps to `dry_vegetation` in `game_fill_draws`. This ensures consistent color tone with other flora in the biome.

### 16. Shadow / contact AO strategy
Casts a soft shadow using directional lighting. Has no ground AO blob, but uses ambient-occluded vertex colors to enhance depth perception.

### 17. Distant-LOD strategy
No LOD is currently implemented, following the forest strategy. Will remain visible up to 200 meters, with possible future simplification at 300m.

### 18. Animation, if any
Static, no animation. The cactus remains motionless to preserve realism and performance.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset in its current design.

### 20. Lighting interaction
The cactus catches warm sunlight on its west-facing side and casts a long shadow to the east. The ribbed texture enhances the effect of directional lighting.

### 21. Collision
Does not block player movement. Collision radius is set to 0.2 to allow passage through the cactus without obstruction.

### 22. Destructible
No. The asset is not destructible in v1, as it is a static environmental element.

### 23. Lore hook
A relic of a once-lush oasis, now preserved in the dunes as a reminder of the desert’s harsh evolution.

### 24. Surface UV layout
The body and ribs are mapped to `uBase=0`, while the crown uses `uBase=8` to enable emissive lighting or material differentiation.

### 25. Material specularity
Matte. No gloss or reflection is applied to maintain a natural desert texture.

### 26. Day/night appearance shift
During the day, the sun-facing side is warmed with `accent_gold` and the shadow side cools to `rock_cool`. At night, the cactus appears uniformly `dune_shadow`.

### 27. Silhouette test at 50 m
Yes, the silhouette remains clear at 50 meters, with a minimum scale of 0.7 to ensure readability at half the map’s average view distance.

### 28. Visual neighbours
Looks best next to `sandstone_rock`, `dune_boulder`, and `cactus_spine`, which all share a similar desert aesthetic and scale.

### 29. Visual conflicts
Should not spawn near `oasis_palm` or `brazier`, as these assets have conflicting visual weight and color palette.

### 30. Implementation hooks
- Add case `45: .barrel_cactus` to `world.team` switch in `src/main.zig`.
- Add function `makeBarrelCactus(device:)` in `ios/Mesh.swift`.
- Add dispatch case `case .barrel_cactus` in `ios/GameViewController.swift`.
---

## Asset 49 — dead_brush
### 1. Silhouette at 30m
The dead brush appears as a sparse, angular cluster of brittle stems and dry twigs, forming a low, irregular silhouette that reads as a desiccated shrub with minimal vertical extension.

### 2. Tri-budget breakdown
The mesh is composed of 100 tris for the body, 30 tris for decorative twigs and leafy appendages, and 10 tris for optional FX elements like small dust particles or ember glows. Total: 140 tris.

### 3. Geometry construction
The core body is built from a series of `mbCylinder` segments stacked vertically with decreasing radius to simulate a tapered trunk. Additional `mbSphere` elements are used to form small nodules at branch junctions. Decorative twigs are extruded as thin cylinders with slight tapering and random orientation, built using fan-of-triangles construction techniques.

### 4. Body palette
The primary color of the trunk and main branches is `dry_vegetation`, while the twigs and small appendages use `sand_dark` for contrast. The leafless tips are tinted with `bone_pale` to simulate dried-out bark and twigs. Accent color `accent_gold` is used sparingly to highlight sun-warmed edges.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|------------------|-------|
| trunk            | 0     |
| branchlets       | 0     |
| leafless tips    | 0     |
| dust/ember glows | 0     |

(All surfaces use uBase=0 — dead_brush is reserved only for that branch; per-vertex color hash handles trunk-vs-twig contrast.)

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This allows for natural variation in growth while maintaining the shrub's recognizable low profile. The slight scale spread mimics the irregular growth patterns of desert flora.

### 7. Y rotation
Rotation is random `0..2π` to ensure instances are not aligned in predictable patterns, enhancing natural appearance in the dunes.

### 8. Ground anchor
Instances sit flat on y=0, partially embedded into the sand to simulate root anchoring and provide a sense of grounding in the desert terrain.

### 9. Procedural variation method
Variation is achieved through a combination of random scale spread (±0.2), rotation (0–2π), and vertex color shifts based on a hash of instance position and team. Some branches are randomly omitted to create a more organic look.

### 10. Spawn placement rules
Spawns within a 10–45m radius from origin. Prefers open dunes and avoids areas within 6m of any path centerline. Not placed near oases or ruins to maintain the desolate, decaying nature of the environment.

### 11. Spawn count rationale
With a zone radius of 450m and 180 instances, each instance is spaced approximately 3.5m apart, creating a sparse but consistent density. This supports the role of desiccated shrub as a background flora element, not overwhelming the player’s visual attention.

### 12. Clustering pattern
Instances are arranged in loose clusters of 2–4, with spacing that avoids rigid alignment or grid patterns. This mimics natural desert vegetation distribution.

### 13. Inter-asset spacing minimum (m)
Minimum 3.5 meters from another instance of the same mesh to ensure natural spread and avoid overcrowding.

### 14. Path-clearance distance (m)
Must not spawn within 6 meters of any path centerline, to ensure clear visibility and avoid blocking traversal.

### 15. Team color reasoning
TEAM=46 is chosen to distinguish this asset from other vegetation types. In the `game_fill_draws` switch, this resolves to `dune_shadow`, a color that subtly blends with the desert’s low light conditions and shadows.

### 16. Shadow / contact AO strategy
Casts a soft shadow using ground AO blob technique. The shadow is not overly sharp, to maintain a natural, weathered appearance. No ambient-occluded vertex colors are used to keep the asset lightweight.

### 17. Distant-LOD strategy
No LOD currently. It is intended to remain visible at all distances for consistency with the desert’s stark, open environment.

### 18. Animation, if any
Static, no animation. This aligns with the desiccated nature of the asset and keeps performance consistent with other low-detail flora.

### 19. Particle FX bound to entity
None. The asset is intentionally static and does not include any bound particle effects.

### 20. Lighting interaction
The asset catches warm sunlight on the east-facing sides and casts a long, soft shadow to the west. The sun-side is tinted with `accent_gold` to emphasize the dry, sun-warmed character.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.2, to avoid interfering with traversal while maintaining a minimal collision footprint.

### 22. Destructible
No. This asset is not intended to be destructible in v1. It represents a background element, not a resource or interactive object.

### 23. Lore hook
A remnant of a once-lush dune, now stripped of its moisture and vitality by the desert’s relentless heat.

### 24. Surface UV layout
The trunk uses uBase 0, branchlets use uBase 1, leafless tips use uBase 2. The dust/ember glows use uBase 8 to enable emissive effects if needed in future.

### 25. Material specularity
Matte. The surface lacks shininess to reinforce its dry, weathered, and desiccated character.

### 26. Day/night appearance shift
Sun-side is tinted with `accent_gold` to simulate the warm glow of sunlight on the exposed bark. Shadow-side uses `dune_shadow` to reflect the cooler, darker tones of the desert’s twilight.

### 27. Silhouette test at 50 m
Yes, the silhouette remains recognizable at 50m. The low, angular form and minimal vertical extension allow it to maintain its identity even at half the map’s average view distance.

### 28. Visual neighbours
Looks right next to `sandstone_rock`, `dune_boulder`, and `dry_cactus`, which all contribute to the same arid, sun-warmed aesthetic.

### 29. Visual conflicts
Should not be placed near `oasis_palm` or `water_pool`, as their lush, green tones would clash with the dry, muted palette of this asset.

### 30. Implementation hooks
- Add case `46: return .dead_brush` in `world.team` switch in `src/main.zig`
- Add `makeDeadBrush(device:)` function in `ios/Mesh.swift`
- Add dispatch case in `ios/GameViewController.swift` to instantiate `.dead_brush` with `makeDeadBrush(device:)`
---

## Asset 50 — tumbleweed_static
### 1. **Silhouette at 30m** — From a distance, the tumbleweed appears as a low, rounded, irregular disc-like object with a soft, billowing form that blends into the dunes. The shape is slightly flattened in the middle, suggesting a resting tumbleweed with a gentle, rolling silhouette.

### 2. **Tri-budget breakdown** — The mesh is split into 130 tris for the main body, 40 for decorations (smaller twigs and leaves), and 10 for optional FX (e.g., subtle particle emission area). Total: 180 tris.

### 3. **Geometry construction** — The main body is built using a stacked series of `mbCylinder` segments with tapering radius and height to simulate a flattened, rounded tumbleweed. A few `mbSphere` elements are added at the tips for soft, rounded ends. An extruded ring structure is used for a central core, and a fan of triangles is added to suggest small leafy appendages or debris. The entire mesh is built using `mbBuffers()` to finalize.

### 4. **Body palette** — The primary color is `dry_vegetation`, used on the main body. A secondary `sand_light` is used for the top-facing side to simulate sun exposure. `dune_shadow` is used for the bottom-facing side to indicate shade. `accent_gold` is used for small highlights or debris on the surface.

### 5. **uBase marker assignments per surface** —  
| Surface | uBase |
|---------|-------|
| Main body | 0 |
| Top-facing sun side | 0 |
| Shadow-facing side | 0 |
| Decorations | 0 |

(All surfaces use uBase=0 — tumbleweed_static is reserved only for that branch; sun/shadow contrast comes from the global lighting pass.)

### 6. **Base scale (scale_min, scale_max)** — Scale range is 0.7 to 1.2. This allows for variation in visual size to break up repetition in clusters, while keeping the tumbleweed recognizable and proportionally consistent across the desert.

### 7. **Y rotation** — Random `0..2π`. The tumbleweed is not aligned to any specific axis and can face any direction to simulate natural scatter.

### 8. **Ground anchor** — Partially buried, with 20% of its height below the ground plane. This gives a grounded, organic feel, as if it's been rolled into the sand.

### 9. **Procedural variation method** — Instances vary in scale, color tint (via a palette hash), and a small number of random rotations on the Y axis. The geometry of the decorations is also randomized (subset of leafy elements) to avoid visual repetition.

### 10. **Spawn placement rules** — Spawn within a 450m radius from origin, in open dune areas, avoiding within 6m of any path centerline. Instances should not spawn near oases or ruins, as they're not naturally found there.

### 11. **Spawn count rationale** — With an estimated 80 instances per zone, the density is appropriate to create a believable desert environment without overwhelming the player or causing visual clutter. It balances the need for environmental detail with performance.

### 12. **Clustering pattern** — Scattered-grid. Instances are placed in a loose grid pattern, with some variation to avoid perfect symmetry and maintain realism.

### 13. **Inter-asset spacing minimum (m)** — 2.5 meters minimum from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — 6 meters from the center of any path. This ensures the tumbleweeds don’t impede movement or become visually jarring near walkable areas.

### 15. **Team color reasoning** — TEAM=46 is chosen to group this vegetation with desert flora, aligning it with `bone_pale` in the `game_fill_draws` switch, which gives it a consistent visual tone in the desert ecosystem.

### 16. **Shadow / contact AO strategy** — It casts a soft shadow and uses ambient-occluded vertex colors to simulate contact with the sand. No additional AO blob is used to keep performance low.

### 17. **Distant-LOD strategy** — It does not simplify or disappear at a distance, following the forest’s current no-LOD strategy. This is to maintain environmental fidelity and avoid sudden disappearances in desert scenes.

### 18. **Animation, if any** — Static, no animation. No movement or visual animation is applied to the tumbleweed.

### 19. **Particle FX bound to entity** — None. The asset is purely visual, with no built-in FX.

### 20. **Lighting interaction** — The tumbleweed catches warm sunlight on its top-facing side, with a subtle shift to `dune_shadow` on its underside. It casts a long shadow to the east in the morning and a short shadow in the afternoon.

### 21. **Collision** — It does not block movement. It has a `world.radius` of 0.3, small enough to avoid obstructing the player's path.

### 22. **Destructible** — No. The tumbleweed is not destructible in v1, remaining a static environment element.

### 23. **Lore hook** — This tumbleweed is a remnant of a past storm, rolled and buried in the sand, a quiet testament to the desert’s shifting nature.

### 24. **Surface UV layout** — The main body uses uBase 0. The top-facing sun side uses uBase 1. The shadow-facing side uses uBase 2. Decorations use uBase 3.

### 25. **Material specularity** — Matte. No gloss or reflectivity is applied to maintain a natural, earthy appearance.

### 26. **Day/night appearance shift** — The sun-facing side takes on a warm, golden tint in daylight, while the shadow-facing side appears cooler and more muted. The overall appearance is consistent with desert sun and shade behavior.

### 27. **Silhouette test at 50 m** — Yes, the tumbleweed still reads as a low, rounded silhouette at 50m. The minimum scale required is 0.6 to maintain visibility and shape.

### 28. **Visual neighbours** — It looks right next to `cactus_spine`, `sandstone_rock`, and `dune_boulder`, all of which are common desert flora or geology.

### 29. **Visual conflicts** — It should not appear near large clusters of `oasis_palm` or `bone_rib`, as this would overcrowd the silhouette or clash with the desert’s sparse aesthetic.

### 30. **Implementation hooks** —  
- Add `case 46: return .tumbleweed_static` to `world.team` switch in `src/main.zig`  
- Add `func makeTumbleweed(device: MTLDevice) -> Mesh` to `ios/Mesh.swift`  
- Add `case .tumbleweed_static: return makeTumbleweed(device: device)` to dispatch in `ios/GameViewController.swift`
---

## Asset 51 — oasis_pool
### 1. Silhouette at 30m
The asset appears as a shallow, circular, reflective patch of water sitting within a sand depression, giving the impression of a small oasis pool in the middle of a dune field.

### 2. Tri-budget breakdown
Body: 280 tris; Decorations: 20 tris; FX: 20 tris. Total: 320 tris.

### 3. Geometry construction
The mesh is constructed using a `mbCylinder` for the main pool base, with a slightly tapered top to simulate a shallow depression. The water surface is modeled as a flat disc using a `mbSphere` with a very low radius, placed just above the pool base. The pool's edges are built with an extruded ring to define a subtle rim and provide a smooth transition from sand to water. A small cluster of sedimentary deposits is added around the edges using a static cluster of small spheres.

### 4. Body palette
The main pool body uses `sand_light` for the sand depression, `sand_dark` for the rim, and `dune_shadow` for the water’s reflective surface. The sedimentary deposits use `rock_warm` for texture contrast.

### 5. uBase marker assignments per surface
| Surface          | uBase |
|------------------|-------|
| Pool base        | 0     |
| Pool rim         | 0     |
| Sedimentary clumps | 0   |
| Water surface    | 34    |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This range allows for natural variation in pool size while maintaining consistent visual impact and fit within the desert biome’s scale expectations.

### 7. Y rotation
Random 0..2π. The pool is not aligned to any axis or path, allowing for organic variation in placement.

### 8. Ground anchor
Sits flat on y=0, with a slight depression in the sand surface to simulate a natural water basin.

### 9. Procedural variation method
Variation is achieved through a combination of scale spread (±0.2) and color palette hash for the rim and sedimentary clumps. The sedimentary clusters are also randomized in position using a noise function.

### 10. Spawn placement rules
Spawns within a 20–45 m radius of the zone origin. Prefers locations near oases or sand depressions, avoiding areas within 6 m of the path centerline and not spawning within 10 m of other water features.

### 11. Spawn count rationale
With a zone radius of 450 m, 8 instances provide optimal visual coverage while avoiding overcrowding. The role of a circular, reflective water patch suggests it should be rare and special, not a frequent occurrence.

### 12. Clustering pattern
Scattered-grid. Instances are distributed to avoid direct clustering, but still appear in visually coherent groups of 1–2 per region.

### 13. Inter-asset spacing minimum (m)
Minimum 12 m from any other instance of the same mesh to avoid visual clutter.

### 14. Path-clearance distance (m)
Must be at least 8 m from the path centerline to avoid blocking gameplay or visual path clarity.

### 15. Team color reasoning
TEAM=47 is chosen to differentiate this asset from typical sand or vegetation elements. The team color resolves to `accent_gold` in the `game_fill_draws` switch, making it stand out subtly against the desert palette.

### 16. Shadow / contact AO strategy
The pool casts no shadow, but its base has ambient-occluded vertex colors to enhance the illusion of a water-filled depression. The rim has a subtle shadow effect to define its shape.

### 17. Distant-LOD strategy
No LOD currently. The asset is visually important at all distances, and the desert’s low resolution environment does not benefit from simplification.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
No particle FX.

### 20. Lighting interaction
The pool surface reflects warm sunlight on the east side and cools in the shadow of the rim. It is self-shadowed and subtly changes color under the sun's angle.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.5 to allow passage through the pool.

### 22. Destructible
No.

### 23. Lore hook
This pool is a remnant of an ancient underground aquifer, now mostly dry, but still holding a thin layer of water that wildlife relies on.

### 24. Surface UV layout
| Surface          | uBase |
|------------------|-------|
| Pool base        | 0     |
| Pool rim         | 0     |
| Sedimentary clumps | 0   |
| Water surface    | 34    |

### 25. Material specularity
Soft-glossy, with a slightly reflective surface that mimics water without being overly shiny.

### 26. Day/night appearance shift
During the day, the pool surface appears warm and reflective on the sun-facing side, with cool shadows on the opposite side. At night, the reflective quality is reduced and the surface appears more neutral.

### 27. Silhouette test at 50 m
Yes, it still reads clearly as a circular water patch at 50 m. The minimum scale required is 0.8 to maintain legibility.

### 28. Visual neighbours
Looks right next to `desert_rock`, `sand_dune`, and `cactus_cluster`, as these elements complement the dry, arid environment and create a cohesive desert scene.

### 29. Visual conflicts
Should not be placed near `brazier`, `water_source`, or `ancient_stone`, as these would visually overpower or conflict with the soft, natural look of the pool.

### 30. Implementation hooks
- `src/main.zig`: Add case `47 => oasis_pool` in `world.team` switch.
- `ios/Mesh.swift`: Add function `makeOasisPool(device:)` that constructs the mesh.
- `ios/GameViewController.swift`: Add dispatch case for `oasis_pool` in the entity placement logic.
---

## Asset 52 — palm_tall
1. **Silhouette at 30m** — From 30 meters away, the palm appears as a tall, narrow column with a distinctive crown of fronds that frames the top, making it identifiable as a desert palm even when obscured by sand drifts or dune shadows.

2. **Tri-budget breakdown** — The mesh allocates 300 tris to the trunk, 60 to the frond cluster, and 20 to the base root structure, totaling 380 tris as specified in EST_TRIS.

3. **Geometry construction** — The trunk is built using a `mbCylinder` with tapered radii to simulate the natural narrowing of the palm, and a `mbSphere` is used for the frond crown. The base is constructed from a series of stacked plates that simulate root flares, and the fronds are modeled as a fan of triangles extending outward from the crown.

4. **Body palette** — The trunk uses `sand_light` and `sand_dark`, the fronds are `dry_vegetation`, and the root base uses `rock_warm`.

5. **uBase marker assignments per surface** — 
| Surface         | uBase |
|------------------|-------|
| Trunk            | 0     |
| Frond crown      | 35    |
| Root base        | 0     |

6. **Base scale (scale_min, scale_max)** — Scale ranges from 1.2 to 1.8. This spread allows variation in visual impact while maintaining the palm’s dominant silhouette in the desert.

7. **Y rotation** — Randomized `0..2π` to ensure natural-looking placement across the dune surface without predictable alignment.

8. **Ground anchor** — The base of the palm is partially buried (y-offset of -0.25) to simulate a natural root system embedded in sand.

9. **Procedural variation method** — Instances vary in scale and color palette via a hash-based randomization of `sand_light` and `sand_dark` hues, and frond density is adjusted using a simple random integer to alter the number of frond triangles.

10. **Spawn placement rules** — Spawns within 50–120 m of oasis center; prefers zones near water sources; avoids spawning within 6 meters of path centerline to prevent collision and maintain player flow.

11. **Spawn count rationale** — With a 450 m radius and an est_count of 14, each instance has approximately 32 m² of unique zone space, which is sufficient for visual distinction and avoids overcrowding in the desert’s sparse ecosystem.

12. **Clustering pattern** — Scattered-grid, with instances placed in loose groups of 1–3, spaced to avoid visual monotony while still implying a desert oasis environment.

13. **Inter-asset spacing minimum (m)** — 10 meters minimum from another instance of the same mesh to prevent visual clashing and maintain spacing in the environment.

14. **Path-clearance distance (m)** — Must be at least 8 meters from path centerline to avoid obstructing gameplay or creating collision hazards for player traversal.

15. **Team color reasoning** — TEAM=48 is chosen to align with the desert's warm, earthy palette; it maps to `rock_warm` in the `game_fill_draws` switch, reinforcing its integration into the dune landscape.

16. **Shadow / contact AO strategy** — Casts a soft shadow using a directional light, and includes ambient occlusion in vertex colors to simulate the sand beneath the roots and fronds.

17. **Distant-LOD strategy** — No LOD currently; the asset remains visible up to 100 meters. A future version may simplify fronds to 20 tris at 150 meters.

18. **Animation, if any** — Static, no animation. The palm remains fixed in orientation and does not sway in wind or other environmental effects.

19. **Particle FX bound to entity** — None. No particle effects are bound to this asset in v1.

20. **Lighting interaction** — Sun-facing side receives a warm tint with `accent_gold`, while the shadow side shows a cool `dune_shadow` tint. It casts a long shadow to the east in the afternoon.

21. **Collision** — Does not block movement. The `world.radius` is set to 0.5 to allow player passage through the trunk without collision.

22. **Destructible** — No. The palm is static and not meant to be destroyed in v1.

23. **Lore hook** — This palm survived the last great sandstorm and now serves as a landmark for travelers seeking the hidden oasis beyond.

24. **Surface UV layout** — The trunk uses uBase 0 for both base and taper; the frond crown uses uBase 35 for its leafy surface; root base uses uBase 0 for its textured sand-buried surface.

25. **Material specularity** — Matte for trunk and root base; soft-glossy for frond crown to simulate a slightly reflective leaf surface.

26. **Day/night appearance shift** — During the day, the sun-facing side is warm with `accent_gold` tint; shadow side takes on a `dune_shadow` tone. At night, the entire asset appears in a muted `sand_dark` with no lighting effect.

27. **Silhouette test at 50 m** — The silhouette remains clear and recognizable at 50 meters. The trunk's verticality and frond crown are still distinct even at this distance, with a minimum scale of 1.0 required to maintain legibility.

28. **Visual neighbours** — Looks best next to `cactus_cluster`, `bone_pile`, and `oasis_pool` to suggest a thriving but isolated desert ecosystem.

29. **Visual conflicts** — Should not be placed near `tall_rock` or `tower`, as these would compete for visual dominance and clutter the desert’s sparse, open feel.

30. **Implementation hooks** — 
- Add case `48: palm_tall` to `world.team` switch in `src/main.zig`
- Add `makePalmTall(device:)` function in `ios/Mesh.swift`
- Add `case 52: makePalmTall(device:)` to dispatch in `ios/GameViewController.swift`
---

## Asset 53 — palm_short
### 1. Silhouette at 30m
The palm_short presents a tall, tapering trunk with a low, dense crown, forming a clear vertical silhouette against the dune horizon, easily distinguishable from other desert flora at 30 meters.

### 2. Tri-budget breakdown
Body: 220 tris, Decorations: 40 tris, FX: 20 tris. Total: 280 tris.

### 3. Geometry construction
The trunk is built using a `mbCylinder` with a slight taper from base to top, forming a smooth, vertical taper. The crown is constructed using a series of stacked `mbSphere` instances at varying radii to simulate dense foliage, connected by a fan of triangles for leaf-like texture. The base of the trunk is capped with a flat disk to anchor it to the ground.

### 4. Body palette
The trunk uses `sand_light` for its main surface, with `dune_shadow` for its base and shadowed areas. The crown uses `dry_vegetation` and `accent_gold` for highlights, creating a natural contrast between the trunk and foliage.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Trunk         | 0     |
| Crown         | 35    |
| Ground base   | 0     |
| Leaf highlights | 8   |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.2. This range allows for subtle variation without losing the visual identity of the palm, and maintains consistent spacing in the desert environment.

### 7. Y rotation
Random `0..2π` rotation to provide natural-looking variation across instances.

### 8. Ground anchor
Partially buried — the base sits at y=-0.15 to simulate the palm's root system embedding into the sand.

### 9. Procedural variation method
Variation is achieved through random scale within the defined range, slight rotation, and a palette hash for color shifts in the crown, ensuring no two instances look identical.

### 10. Spawn placement rules
Spawns within 30–50 meters of the zone origin, preferring oasis zones, with a minimum distance of 6 meters from the path centerline. Avoids spawning near large rock formations or other dense vegetation.

### 11. Spawn count rationale
With an estimated 450m radius zone and role as a supporting visual element, 14 instances are sufficient to provide a natural spread without overcrowding, while maintaining a sense of desert solitude.

### 12. Clustering pattern
Scattered-grid. Instances are spaced to appear naturally distributed, not clustered, with a soft density in the center of the zone.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters from any other instance of the same mesh to avoid visual clutter.

### 14. Path-clearance distance (m)
Can spawn within 6 meters of the path centerline, as it's low enough to not block player view or movement.

### 15. Team color reasoning
TEAM=48 is chosen to group this asset with similar desert flora, and it resolves to `accent_turquoise` in the `game_fill_draws` switch, giving it a cool, reflective appearance under sunlight.

### 16. Shadow / contact AO strategy
Casts a soft shadow, and uses ambient-occluded vertex colors for subtle contact AO, enhancing the realism of the sand beneath the palm.

### 17. Distant-LOD strategy
No LOD currently — follows the forest asset strategy of keeping detail consistent at all distances, but may be revisited if performance demands arise.

### 18. Animation, if any
Static, no animation. The palm does not sway or move, maintaining a grounded, timeless presence.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset.

### 20. Lighting interaction
The palm catches warm sunlight on its eastern face, casting a long shadow to the west. Its surface is sun-side tinted with a warm gold hue, and shadow-side tones shift subtly to a cooler sand tone.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.5, allowing players to pass through or around it with ease.

### 22. Destructible
No. This asset is not destructible in v1.

### 23. Lore hook
This palm stands as a relic of an ancient oasis, surviving long after the water source dried up, a quiet testament to the desert’s resilience.

### 24. Surface UV layout
Trunk surface uses uBase 0 for base color, Crown uses uBase 35 for foliage, Ground base uses uBase 0, and leaf highlights use uBase 8 for emissive effects.

### 25. Material specularity
Soft-glossy. The trunk has a matte surface, while the crown has a subtle glossy sheen to simulate leaf texture.

### 26. Day/night appearance shift
Sun-side faces are warm-toned with a golden tint, while shadow-side areas shift to a cooler sand tone, enhancing the contrast and realism of the desert environment.

### 27. Silhouette test at 50 m
Yes, the palm still reads clearly at 50 meters, maintaining its vertical profile and distinct crown shape. A minimum scale of 0.75 is sufficient for full silhouette recognition.

### 28. Visual neighbours
Looks right next to `cactus_tall`, `rock_rough`, and `bush_dry`, forming a natural desert composition with varied textures and heights.

### 29. Visual conflicts
Should not spawn near `tree_sapling` or `boulder_large`, as they would compete visually for space and silhouette clarity.

### 30. Implementation hooks
- Add `case 48: return .palm_short` in `src/main.zig` in the `world.team` switch.
- Add `func makePalmShort(device: MTLDevice) -> (vertices: [Vertex], indices: [UInt16])` to `ios/Mesh.swift`.
- Add `case 53: self.mesh = makePalmShort(device: device)` in `ios/GameViewController.swift`.
---

## Asset 54 — reed_cluster
### 1. Silhouette at 30m
From 30 meters away, the reed cluster appears as a soft, upright tuft with a slight tapering form, resembling a small, vertical grassy brush against the warm desert background.

### 2. Tri-budget breakdown
Body: 140 tris; Decorations: 15 tris; FX: 5 tris. Total: 160 tris.

### 3. Geometry construction
The reed cluster is built from a central `mbCylinder` with a tapered shape, representing the main stem, topped with a `mbSphere` for the leafy cap. A few thin extruded cylinders are added for secondary reed strands. The geometry is constructed using a fan of triangles for the leafy cap and stacked plates for the base to give a natural, layered appearance.

### 4. Body palette
The body uses sand_light (0.95, 0.85, 0.70) for the stem, dry_vegetation (0.58, 0.50, 0.32) for the base, and accent_gold (0.95, 0.78, 0.30) for highlights. The leaf cap uses a subtle blend of accent_turquoise and sand_light for a soft contrast.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|----------------|-------|
| Stem           | 0     |
| Base           | 35    |
| Leaf Cap       | 0     |
| Highlights     | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.8 to 1.4. This range allows for natural variation in reed height while maintaining the asset’s visual identity and preventing overcrowding in dense areas.

### 7. Y rotation
Random `0..2π` rotation. This allows natural, non-uniform placement and avoids grid-like clustering.

### 8. Ground anchor
Partially buried, with the base sitting at y = -0.15 to simulate the reed root system sitting in soft sand.

### 9. Procedural variation method
Variation occurs via scale spread (0.8–1.4), random rotation (0–2π), and a palette hash-based color shift in the highlights, which gives a subtle but perceptible difference between instances.

### 10. Spawn placement rules
Spawn radius: 10–15 m from origin. Prefers oasis zones, avoids direct proximity to paths and water sources. Must not spawn within 6 meters of path centerline.

### 11. Spawn count rationale
With a 450m radius zone and EST_COUNT=20, this gives a distribution of approximately 1 instance per 22.5m², aligning with the role of a sparse, naturalistic tuft at the oasis rim.

### 12. Clustering pattern
Scattered-grid. Instances are placed to appear naturally distributed, avoiding tight clustering while ensuring a sense of continuity across the zone.

### 13. Inter-asset spacing minimum (m)
Minimum 3 meters from another reed_cluster instance to prevent visual clutter and maintain a sense of individuality.

### 14. Path-clearance distance (m)
Must not spawn within 6 meters of path centerline. This ensures clear sightlines and avoids collision with player movement.

### 15. Team color reasoning
TEAM=48 is chosen to align with a warm, desert-tinted vegetation team. The color resolves to sand_light (0.95, 0.85, 0.70) in the `game_fill_draws` switch, consistent with the desert palette.

### 16. Shadow / contact AO strategy
Casts a soft shadow using ambient occlusion on the base. No dedicated AO blob, but vertex colors are adjusted to provide subtle shadowing under the reed cap.

### 17. Distant-LOD strategy
No LOD currently. The asset will remain visible up to the full map distance, consistent with forest assets’ behavior.

### 18. Animation, if any
Static, no animation. The asset does not move or sway.

### 19. Particle FX bound to entity
None. No particle effects are bound to this asset.

### 20. Lighting interaction
The reed cluster catches warm sunlight on its western side, with a cool shadow on its eastern face. The leaf cap reflects ambient light softly, giving a sun-drenched look.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.25 to allow passage through the cluster without obstruction.

### 22. Destructible
No. The asset is not destructible in v1.

### 23. Lore hook
These reeds are a remnant of ancient waterways that once flowed through this dune, now preserved as a quiet testament to the oasis’s fading past.

### 24. Surface UV layout
The stem and leaf cap use uBase 0. The base uses uBase 35. Highlights use uBase 8 for emissive glow.

### 25. Material specularity
Soft-glossy. The surface reflects ambient light subtly, enhancing the natural feel without over-sharpening.

### 26. Day/night appearance shift
During the day, the sun-side of the reed is warm-toned (accent_gold), while the shadow-side takes on a cool, muted tone (dry_vegetation). At night, the entire structure fades to a neutral, ambient tone.

### 27. Silhouette test at 50 m
Yes, the reed cluster still reads as a distinct upright tuft at 50 meters. The minimum scale required to maintain silhouette clarity is 0.75.

### 28. Visual neighbours
Looks right next to dry_vegetation, small rock formations, and sparse bone_pale grass tufts. It complements the desert’s dry, minimalistic palette.

### 29. Visual conflicts
Should not be placed near dense clusters of fireflies or embers, as these would overpower the soft, natural feel of the reed cluster.

### 30. Implementation hooks
- `src/main.zig`: Add `case 48: return "reed_cluster"` in `world.team` switch.
- `ios/Mesh.swift`: Add `makeReedCluster(device:)` function.
- `ios/GameViewController.swift`: Add `case 54: dispatchReedCluster(device:)` in dispatch table.
---

## Asset 55 — broken_column
### 1. **Silhouette at 30m** — The broken_column presents a clean, angular silhouette with a pronounced toppling lean, clearly visible against the horizon, suggesting an ancient ruin collapsed by sand or time.

### 2. **Tri-budget breakdown** — Body: 180 tris; Decorations: 40 tris; FX: 20 tris. Total: 240 tris.

### 3. **Geometry construction** — The main body is a tall, tapered cylinder built with `mbCylinder`, representing the column's shaft. The broken top is modeled as a partially detached sphere with a flat break edge, created using `mbSphere`. A small carved capital is added as a stacked plate structure atop the column. The base includes a shallow ring extrusion for stability and to simulate sand erosion.

### 4. **Body palette** — The primary column uses `rock_warm` for the shaft, `rock_cool` for the lower sand-eroded section, and `sand_light` for the toppling surface. Accent gold (`accent_gold`) is used for subtle carved details on the capital.

### 5. **uBase marker assignments per surface** — 
| Surface             | uBase |
|---------------------|-------|
| Column shaft        | 0     |
| Sand-eroded base    | 36    |
| Capital             | 40    |
| Toppling surface    | 0     |
| Ground AO blob      | 8     |

### 6. **Base scale (scale_min, scale_max)** — scale_min = 0.9, scale_max = 1.3. This range allows for natural variation in column height and sand accumulation, while maintaining visual consistency across the desert biome.

### 7. **Y rotation** — Random `0..2π`. Instances are fully rotationally randomized to avoid repetitive alignment and blend into the natural chaos of the dunes.

### 8. **Ground anchor** — Partially buried, with 30% of the column's height below the y=0 surface. This simulates gradual sand burial and adds to the ruin's weathered appearance.

### 9. **Procedural variation method** — Variation is driven by a hash of the instance’s world position and a random seed, which determines the color palette, scale, and rotation. The capital’s carving depth and orientation also vary.

### 10. **Spawn placement rules** — Spawns within 10–30 m from origin. Prefers near ruins or bone fields, and avoids placement within 6 m of the path centerline. It should not appear in open dunes or near oases.

### 11. **Spawn count rationale** — The 40 instances are distributed across a 450 m radius zone, providing a subtle but effective ruin presence. This count ensures visual density without overcrowding, and reflects the desert's sparse architectural remains.

### 12. **Clustering pattern** — Scattered-grid. Instances are arranged in a loose grid to simulate a once-ordered ruin, with occasional lone columns to imply abandonment and decay.

### 13. **Inter-asset spacing minimum (m)** — 5.5 m. Ensures visual separation from other broken columns and prevents over-saturation of ruin elements in the same area.

### 14. **Path-clearance distance (m)** — 6.5 m. The asset is kept far enough from paths to avoid cluttering player movement and maintain the illusion of a distant ruin.

### 15. **Team color reasoning** — TEAM=49 maps to `rock_cool` in the `game_fill_draws` switch. This color aligns with the column’s weathered lower section and reinforces the desert’s cool-toned geological character.

### 16. **Shadow / contact AO strategy** — Casts a long, soft shadow to the east; includes a ground AO blob for enhanced realism. Vertex colors are ambient-occluded to simulate sand accumulation and weathering.

### 17. **Distant-LOD strategy** — No LOD is implemented at this time. The asset remains visible and detailed up to the map’s full view distance, as it is part of a low-density, scenic ruin set.

### 18. **Animation, if any** — Static, no animation. The asset is intentionally still to emphasize its ruinous state.

### 19. **Particle FX bound to entity** — None. The asset does not emit FX, though it may be enhanced with ambient dust motes in future visual updates.

### 20. **Lighting interaction** — The column catches warm sunlight on its west-facing side, casting a long shadow to the east. The toppling face is self-shadowed to emphasize the collapse.

### 21. **Collision** — Yes, it blocks player movement. `world.radius` is set to 0.6 to reflect the column's solid, obstructive form without being overly restrictive.

### 22. **Destructible** — No. The asset is static and non-destructible in v1, as it represents a fixed ruin element.

### 23. **Lore hook** — A once-proud column now toppled by the shifting sands, a silent witness to the desert's relentless passage.

### 24. **Surface UV layout** — The shaft uses uBase 0 (default). The sand-eroded base uses uBase 36. The capital uses uBase 40. The ground AO blob uses uBase 8.

### 25. **Material specularity** — Soft-glossy. The surface has a subtle sheen to simulate weathered stone, not overly reflective or matte.

### 26. **Day/night appearance shift** — During the day, the sun-facing side appears warm with a `rock_warm` tint, while the shadowed side takes on a cooler `rock_cool` tone. At night, the contrast is muted but still present, emphasizing the column's angular, weathered form.

### 27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and identifiable at 50 m. The angular break and toppling lean ensure visibility even at half the average map distance. A minimum scale of 0.7 is sufficient to maintain readability.

### 28. **Visual neighbours** — Adjacent assets include `sandstone_boulder`, `worn_arch`, and `weathered_pillar`. These assets compose a cohesive desert ruin scene, enhancing the architectural narrative.

### 29. **Visual conflicts** — Should not appear near `brazier`, `oasis_well`, or `ancient_tomb`, as these elements would visually compete with the ruin’s quiet, weathered tone.

### 30. **Implementation hooks** — Add `case 49: return makeBrokenColumn(device:)` to the `world.team` switch in `src/main.zig`. Add `func makeBrokenColumn(device:)` to `ios/Mesh.swift`. Add `case 55: mesh = makeBrokenColumn(device:)` in `ios/GameViewController.swift`.
---

## Asset 56 — half_buried_obelisk
1. **Silhouette at 30m** — The obelisk presents a sharp, tall pyramidal silhouette with a leaning, partial burial effect, creating a dramatic profile that stands out against the dunes' rolling horizon.
2. **Tri-budget breakdown** — Body: 220 tris, Decorations: 40 tris, FX: 0 tris.
3. **Geometry construction** — The main body is built using a tapered cylinder with a slight lean, constructed from 4 rings and 16 sides. A small pyramidal cap is formed with a fan of triangles at the top. A ring of weathered details is extruded from the base, and the partial burial effect is achieved by cutting the lower portion of the mesh along a Y-axis plane, with a few stacked plates simulating sand accumulation.
4. **Body palette** — The main surface uses sand_light for the exposed upper part, sand_dark for the lower section, dune_shadow for the shadowed base, and accent_gold for the pyramidal tip.
5. **uBase marker assignments per surface** —
| Surface           | uBase |
|-------------------|-------|
| Main body (upper) | 36    |
| Main body (lower) | 40    |
| Pyramidal tip     | 0     |
| Sand accumulation | 36    |
| Ground contact    | 0     |
6. **Base scale (scale_min, scale_max)** — 0.9 to 1.3. This spread allows for variation in height and girth while maintaining the asset's iconic appearance across the desert.
7. **Y rotation** — Random `0..2π`. The asset rotates freely in the horizontal plane to avoid repetitive alignment.
8. **Ground anchor** — Partially buried, with 30% of the base below y=0 to simulate the obelisk's settling into the sand.
9. **Procedural variation method** — Instances vary in scale, Y-rotation, and color palette via hash-based randomization of the `world.team` color, with slight variations in surface UV offsetting.
10. **Spawn placement rules** — Spawns within 10–45 m radius of origin, preferably in open dunes or near ruins, avoiding placement within 6 m of path centerline to prevent occlusion.
11. **Spawn count rationale** — With a 450 m radius and role as a notable ruin landmark, 20 instances provide sufficient variety and visual impact without overcrowding the zone.
12. **Clustering pattern** — Scattered-grid. Instances are spread out to avoid visual repetition, with a loose clustering effect in ruins or oasis areas.
13. **Inter-asset spacing minimum (m)** — 12 m from another instance of the same mesh.
14. **Path-clearance distance (m)** — 8 m from path centerline.
15. **Team color reasoning** — TEAM=49 is chosen to match a specific desert ruin color scheme; the team color resolves to sand_dark in `game_fill_draws`.
16. **Shadow / contact AO strategy** — Casts a strong shadow due to its height and lean; uses ambient-occluded vertex colors for the sand-accumulated base.
17. **Distant-LOD strategy** — No LOD currently — asset is small enough to maintain detail at 450m, so no simplification is needed.
18. **Animation, if any** — Static, no animation.
19. **Particle FX bound to entity** — None.
20. **Lighting interaction** — Sun-facing side is warm-toned, especially in the morning, while shadowed side takes on a cooler, dune-shadow tint. The obelisk catches light on the west face and casts a long shadow to the east.
21. **Collision** — Blocks player movement; `world.radius = 0.8`.
22. **Destructible** — No.
23. **Lore hook** — A remnant of an ancient civilization's sacred observatory, left behind after a sandstorm buried the rest of the complex.
24. **Surface UV layout** — Main body (upper) uses uBase 36; main body (lower) uses uBase 40; pyramidal tip uses uBase 0; sand accumulation uses uBase 36; ground contact uses uBase 0.
25. **Material specularity** — Soft-glossy with matte base, especially on the sand-accumulated surfaces.
26. **Day/night appearance shift** — Sun-side is warm and golden, while shadow-side is cool and dusky, with a subtle gradient transition.
27. **Silhouette test at 50 m** — Yes, the silhouette remains clear and recognizable even at 50 m. Minimum scale required is 0.7 to maintain legibility.
28. **Visual neighbours** — Looks right next to `desert_rock`, `oasis_cairn`, and `ancient_pillar`, forming a cohesive ruin landscape.
29. **Visual conflicts** — Should not spawn near `desert_cactus` or `sand_dune_boulder`, as their silhouettes clash with the obelisk's clean profile.
30. **Implementation hooks** — Add `case 49: return makeHalfBuriedObelisk(device:)` to `world.team` switch in `src/main.zig`; add `func makeHalfBuriedObelisk(device:)` to `ios/Mesh.swift`; add dispatch case `case 56: makeHalfBuriedObelisk(device: device)` to `ios/GameViewController.swift`.
---

## Asset 57 — sphinx_head
### 1. **Silhouette at 30m** — The head’s massive, weathered profile dominates the dune horizon, with a wide, flat brow and deep, sunken eyes that catch the light. It reads clearly as a monumental face emerging from sand, even at that distance.

### 2. **Tri-budget breakdown** — Body: 900 tris, Decorations: 150 tris, FX: 50 tris. The body is the main structural form, decorations include small cracks and erosion lines, and FX includes optional emissive particle effects at the eye sockets.

### 3. **Geometry construction** — The head is built as a combination of a large, flattened sphere (base mesh) with a cylindrical neck extruded downward, and a series of tapering, irregular protrusions for weathered features. The face is modeled with a fan of triangles for eye sockets and a static cluster for the snout. The entire mesh is constructed using `mbSphere` and `mbCylinder` with manual vertex adjustments for erosion and asymmetry.

### 4. **Body palette** — The body uses `sand_light`, `sand_dark`, `dune_shadow`, and `rock_warm`. `sand_light` covers the top and brow, `sand_dark` the sides, `dune_shadow` for the lower face and base, and `rock_warm` for the neck and protruding boulders.

### 5. **uBase marker assignments per surface** —
| Surface         | uBase |
|----------------|-------|
| Head top       | 36    |
| Head side      | 37    |
| Neck           | 40    |
| Base           | 0     |
| Emissive eyes  | 8     |

### 6. **Base scale (scale_min, scale_max)** — 1.1 to 1.4. This scale range allows the asset to appear imposing without becoming overbearing or unrealistic in its scale relative to a player’s view or dune terrain.

### 7. **Y rotation** — Random `0..2π`. The asset is allowed to rotate freely around its Y-axis to prevent repetitive alignment across spawns.

### 8. **Ground anchor** — Partially buried, sitting 0.3 meters into the sand. This gives the impression of a weathered relic emerging from a dune, not a floating or upright statue.

### 9. **Procedural variation method** — Instance variation is driven by a hash of the instance’s world position to determine color offsets and slight scale variance. No sub-mesh subsets are used.

### 10. **Spawn placement rules** — Spawn within 10–40m radius from origin. Prefers open dunes, avoids within 6 meters of path centerline. Must not spawn near oases or in areas with existing large rocks or trees.

### 11. **Spawn count rationale** — With a 450m zone radius and `est_count = 3`, this ensures each instance has adequate visual isolation, contributing to a sparse desert landscape where such a relic feels rare and impactful.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid clustering, with a minimum of 10 meters between each.

### 13. **Inter-asset spacing minimum (m)** — 10 meters. Ensures that no other sphinx_head or similar-scale ruin asset appears too close, maintaining visual breathing room.

### 14. **Path-clearance distance (m)** — Must be at least 6 meters from path centerline. This avoids visual conflict with player movement and path-following.

### 15. **Team color reasoning** — TEAM=49 is chosen to align with the desert ruin color scheme, representing a neutral-to-warm, eroded structure. It resolves to `rock_warm` in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — Casts a soft shadow with a subtle AO blob on the ground, using ambient-occluded vertex colors for deeper shading under the neck and brow.

### 17. **Distant-LOD strategy** — No LOD currently. It is expected to remain visible at full resolution until the player is within 100 meters. This aligns with the current forest asset behavior, but future updates may introduce a low-res proxy.

### 18. **Animation, if any** — Static, no animation. No movement or subtle motion is applied to maintain the relic’s solemn presence.

### 19. **Particle FX bound to entity** — None. The asset does not use particle FX in its base state. Optional emissive particles can be added for eye sockets in a future upgrade.

### 20. **Lighting interaction** — The head catches warm sunlight on the west-facing brow and casts a long shadow to the east. The sun-side face is warm-toned, while the shadow-side is cool, creating a strong directional contrast.

### 21. **Collision** — Yes, it blocks player movement. `world.radius` set to 1.2 to match the scale of a large, irregular rock.

### 22. **Destructible** — No. The asset is not destructible in v1.

### 23. **Lore hook** — A forgotten monument to an ancient civilization, half-swallowed by sand, left to weather and erode under the desert sun.

### 24. **Surface UV layout** — The head top uses `uBase=36`, head side uses `uBase=37`, neck uses `uBase=40`, base uses `uBase=0`, and emissive eyes use `uBase=8`.

### 25. **Material specularity** — Soft-glossy. The surface is matte with a slight sheen, especially on exposed rock faces and near the eyes.

### 26. **Day/night appearance shift** — The sun-side faces warm with a golden tint, while the shadow-side takes on a cooler blue-gray hue, mimicking the desert’s natural light shift.

### 27. **Silhouette test at 50 m** — Yes, it still reads clearly as a sphinx head at 50m. The silhouette remains distinct and recognizable even at this distance. A minimum scale of 1.0 is sufficient to maintain readability.

### 28. **Visual neighbours** — It looks right next to `sandy_boulder`, `dune_crest`, and `ancient_tomb`, as these desert structures complement its worn, eroded appearance.

### 29. **Visual conflicts** — Should not spawn near `oasis_palm`, `water_pond`, or `cactus_cluster`, as these would visually compete with the desolate, weathered tone of the sphinx.

### 30. **Implementation hooks** — 
- In `src/main.zig`, add case `49: return .sphinx_head` to `world.team` switch.
- In `ios/Mesh.swift`, add `func makeSphinxHead(device: MTLDevice) -> (verts: [Vertex], idxs: [UInt16])` function.
- In `ios/GameViewController.swift`, add dispatch case for `case .sphinx_head` in `spawnAsset` method.
---

## Asset 58 — ruined_arch
### 1. **Silhouette at 30m** — From 30 meters away, the ruined arch appears as a strong, angular silhouette with one side leaning inward, suggesting collapse. It’s a vertical, arch-like structure with a clear horizontal gap, easily distinguishable from background terrain.
### 2. **Tri-budget breakdown** — Body: 300 tris, Decorations: 60 tris, FX: 20 tris. Total: 380 tris.
### 3. **Geometry construction** — The main structure is built from a vertical extruded ring with a slight inward taper, constructed using stacked plates. A single cylinder represents the collapsed side of the arch, and a small sphere is placed at the top to simulate a broken keystone. The body is composed of a mesh of triangles with vertical ribs to add structural depth.
### 4. **Body palette** — The main body uses `rock_warm`, `sand_light`, and `dune_shadow`. The collapsed side uses `rock_cool` for contrast.
### 5. **uBase marker assignments per surface** —
| Surface        | uBase |
|----------------|-------|
| Arch body      | 36    |
| Collapsed side | 40    |
| Keystone       | 0     |
| Ground contact | 36    |
### 6. **Base scale (scale_min, scale_max)** — Scale range: 1.0 to 1.4. Justification: A range of 1.0–1.4 allows for visual variation without affecting gameplay or spawning density.
### 7. **Y rotation** — Random 0..2π. This allows for natural variation in orientation across the desert.
### 8. **Ground anchor** — Partially buried, with 20% of the structure below y=0. This gives the illusion of long-term weathering and integration with the terrain.
### 9. **Procedural variation method** — Variation is based on a palette hash that selects a random color tint from the desert palette, a random scale within the 1.0–1.4 range, and a random Y rotation.
### 10. **Spawn placement rules** — Spawn radius: 10–15 m from origin. Preferred biome: open dunes. Avoid-list: not within 8 m of path centerline.
### 11. **Spawn count rationale** — The `est_count = 25` is appropriate for a 450 m radius zone because the arch is a distinctive landmark that should be visible from afar, yet not overly frequent to cause visual fatigue.
### 12. **Clustering pattern** — Scattered-grid. Instances are spaced to avoid clustering, with some variation in elevation and orientation to avoid repetition.
### 13. **Inter-asset spacing minimum (m)** — 12 meters. This ensures that each arch is visually distinct and does not crowd nearby structures.
### 14. **Path-clearance distance (m)** — 8 meters from path centerline. This allows for natural path traversal while maintaining visual integrity.
### 15. **Team color reasoning** — TEAM=49 is chosen to differentiate this ruin from other desert structures. The team color resolves to `rock_cool` in the `game_fill_draws` switch, giving it a distinct look under team-based shaders.
### 16. **Shadow / contact AO strategy** — It casts a strong, angular shadow. Ground AO blob is included to simulate contact with the sand. Vertex colors use ambient occlusion to enhance depth.
### 17. **Distant-LOD strategy** — No LOD currently. The asset is designed to be visually effective at all distances, and the current forest strategy of no LOD is followed.
### 18. **Animation, if any** — Static, no animation. The asset is meant to be a fixed relic.
### 19. **Particle FX bound to entity** — None. The asset does not emit or interact with particle systems.
### 20. **Lighting interaction** — It catches warm sunlight on the west-facing side, casting a long shadow to the east. The sun-side is tinted with `accent_gold`, while the shadow-side uses `dune_shadow`.
### 21. **Collision** — Yes, it blocks player movement. `world.radius` set to 1.2 to allow for safe traversal around the structure.
### 22. **Destructible** — No. The structure is meant to be a permanent ruin and not subject to destruction in v1.
### 23. **Lore hook** — This collapsed gateway arch once marked the entrance to a long-forgotten oasis, now only a remnant of a once-thriving civilization.
### 24. **Surface UV layout** — `uBase 36` covers the main arch body, `uBase 40` covers the collapsed side, `uBase 0` covers the keystone, and `uBase 36` also covers the ground contact area.
### 25. **Material specularity** — Matte. The surface is designed to look weathered and dull, with no glossy reflections.
### 26. **Day/night appearance shift** — During the day, the sun-side is warm with `accent_gold` and `sand_light` tones. The shadow-side is cool with `dune_shadow` and `rock_cool` tints. At night, the warm tones fade into neutral grays.
### 27. **Silhouette test at 50 m** — Yes, it still reads as a distinct arch at 50 meters. The silhouette is strong enough to be recognized at this distance, and no scaling is needed.
### 28. **Visual neighbours** — It looks best next to `desert_rock`, `dune_stone`, and `oasis_boulder`—assets that are similarly weathered and grounded.
### 29. **Visual conflicts** — It should not be placed near `sand_dune` or `oasis_pool`, as these would visually clash with its weathered and collapsed form.
### 30. **Implementation hooks** — Add case `58: ruined_arch` to `world.team` switch in `src/main.zig`. Add `makeRuinedArch(device:)` function in `ios/Mesh.swift`. Add dispatch case in `ios/GameViewController.swift` for `ruined_arch`.
---

## Asset 59 — glyph_wall
### 1. Silhouette at 30m
From 30 meters away, the glyph_wall appears as a low, rectangular wall fragment with subtle raised golden glyphs, its sandstone-like structure blending into the dunes with a flat, carved silhouette that hints at ancient runes.

### 2. Tri-budget breakdown
The mesh is split into three parts: body (240 tris), glyphs (60 tris), and FX (20 tris). The body forms the main wall structure, glyphs are the raised rune elements, and FX covers small emissive particles or ambient lighting effects.

### 3. Geometry construction
The core geometry is built using a single `mbCylinder` to form the main wall body, with a slight taper to simulate weathered edges. Raised golden glyphs are added via extruded ring structures with fan-of-triangle topologies. Optional small spheres are used for weathering details, and a static cluster of small, flat plates is used to define the base of the structure.

### 4. Body palette
The body uses `sand_light`, `sand_dark`, and `dune_shadow`. These colors are applied to the main wall surface, with `sand_light` on the top and `dune_shadow` on the bottom to simulate sun and shadow exposure. `sand_dark` is used for mid-surface variations to add depth.

### 5. uBase marker assignments per surface
| Surface     | uBase |
|-------------|-------|
| Wall body   | 36    |
| Glyphs      | 40    |
| Ground AO   | 0     |
| Emissive FX | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This spread ensures natural variation in size, with smaller instances appearing more fragile and larger ones more imposing. It supports visual variety while preserving the asset’s core shape.

### 7. Y rotation
Random `0..2π` rotation to provide natural-looking orientation across the desert landscape, avoiding any artificial alignment.

### 8. Ground anchor
Partially buried, with the bottom 10% of the mesh embedded in the ground (y = -0.15) to simulate weathered erosion and blending with the terrain.

### 9. Procedural variation method
Variation is achieved through a combination of random scale spread, color palette hash based on instance ID, and slight rotation variance. Glyphs may be partially hidden or emphasized based on a per-instance random flag.

### 10. Spawn placement rules
Spawns within a 40–50 meter radius of the zone origin. Prefers locations near ruins or near bone fields to enhance the lore. Avoids spawning within 6 meters of the main path centerline to preserve visual clarity and player movement flow.

### 11. Spawn count rationale
With a 450m radius and `est_count = 30`, each instance covers approximately 200 m² of space. This spacing ensures that the asset appears as a scattered but meaningful presence across the biome without overcrowding, supporting a narrative of ancient ruins in a desolate desert.

### 12. Clustering pattern
Scattered-grid. Instances are placed to avoid forming tight clusters, instead appearing at regular intervals to suggest a pattern of decay and forgotten history.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters to other instances of the same mesh. Ensures visual separation and prevents the appearance of artificial grouping.

### 14. Path-clearance distance (m)
Must not spawn within 7 meters of the path centerline. This ensures the asset doesn’t interfere with player movement or sightlines.

### 15. Team color reasoning
TEAM=49 is chosen to distinguish this ruin from the general sandstone team (TEAM=10) and align it with a deeper, more ancient, and slightly more mystical palette. The team color resolves to `rock_warm` in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts a soft shadow with a ground AO blob. Vertex colors are ambient-occluded to simulate weathering and subtle shadowing in crevices, enhancing realism.

### 17. Distant-LOD strategy
No LOD is implemented. The asset remains visible and detailed up to the full map radius, consistent with the current forest behavior.

### 18. Animation, if any
Static, no animation. The asset is intended to be a still relic, enhancing the mood of abandonment.

### 19. Particle FX bound to entity
None. The asset is self-contained, with no particle effects attached.

### 20. Lighting interaction
The wall catches warm sunlight on its west-facing side, giving it a golden tint that shifts to a cooler hue on the east-facing side. It casts a long shadow to the east, especially during midday, and is self-shadowed in the grooves and crevices.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.3 to allow passage through the structure without obstruction.

### 22. Destructible
No. The asset is not destructible in v1, to maintain visual consistency and gameplay flow.

### 23. Lore hook
This wall fragment was once part of a great observatory, where ancient glyphs were used to track celestial movements and mark the passage of time.

### 24. Surface UV layout
The wall body uses uBase 36, glyphs use uBase 40, ground AO uses uBase 0, and emissive FX uses uBase 8. Each surface is UV-mapped to support distinct material properties and lighting.

### 25. Material specularity
Soft-glossy. The sandstone body has a matte finish with slight sheen to simulate weathering and sun exposure, while the glyphs are glossy with a golden sheen.

### 26. Day/night appearance shift
During the day, the sun-facing side of the wall is warmed with a golden tint, while the shadow side takes on a cooler, slightly bluish hue. At night, the glyphs softly glow with an amber light, simulating the effect of ancient runes.

### 27. Silhouette test at 50 m
Yes, the silhouette remains distinct and recognizable at 50 meters. The asset requires no scaling to maintain clarity at this distance.

### 28. Visual neighbours
This asset looks best next to `stone_pillar`, `cracked_rock`, and `ruin_arch`, as these complement the ancient ruin aesthetic and create a cohesive desert ruin environment.

### 29. Visual conflicts
This asset should not be placed near `brazier`, `firepit`, or `oasis_pool`, as these elements would compete visually and disrupt the desolate, weathered theme.

### 30. Implementation hooks
- In `src/main.zig`, add case `49: glyph_wall` to the `world.team` switch.
- In `ios/Mesh.swift`, add a `makeGlyphWall(device:)` function to build the mesh.
- In `ios/GameViewController.swift`, add a `dispatchGlyphWall()` case in the spawn dispatcher to support instantiation.
---

## Asset 60 — desert_shrine
### 1. Silhouette at 30m
From 30 meters away, the desert shrine appears as a tall, vertical structure with a broad, flat roof supported by a central pillar, giving it a distinctive open-air, stone temple silhouette against the dunes.

### 2. Tri-budget breakdown
The mesh is broken down into: Body (300 tris), Decorations (100 tris), FX (60 tris). Total: 460 tris.

### 3. Geometry construction
The shrine is built with a central tapered cylinder for the main pillar, a flat top plate for the roof, and a series of extruded rings for the golden trim. A spherical dome sits atop the pillar to represent the relic chamber. Additional decorative elements include small stone blocks and a fan of triangles for the canopy slats.

### 4. Body palette
The body uses sand_light (0.95, 0.85, 0.70) for the main pillars, sand_dark (0.75, 0.60, 0.45) for the roof slab, rock_warm (0.78, 0.58, 0.42) for the trim, and accent_gold (0.95, 0.78, 0.30) for the golden trim.

### 5. uBase marker assignments per surface
| Surface          | uBase |
|------------------|-------|
| Main pillar      | 0     |
| Roof slab        | 36    |
| Trim bands       | 40    |
| Dome             | 42    |
| Canopy slats     | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.8 to 1.2. This range allows for visual variation without breaking the shrine's architectural integrity or causing scale issues in tight dune environments.

### 7. Y rotation
Y rotation is fixed at 0 radians (aligned to world axis), providing consistent orientation for the shrine across the desert.

### 8. Ground anchor
The shrine sits flat on y=0, with no y-offset, ensuring it rests directly on the sand dune surface.

### 9. Procedural variation method
Variation is achieved through a palette hash that modifies the trim and dome colors slightly, and a small random scale spread of ±0.05.

### 10. Spawn placement rules
Spawn radius is 20–40 meters from origin. Prefers open dunes with no biome preference. Must avoid spawning within 6 meters of the path centerline.

### 11. Spawn count rationale
With an EST_COUNT of 4 and a 450m zone radius, the shrine’s count allows for a scattered, rare presence that does not overwhelm the environment, matching its role as a relic site.

### 12. Clustering pattern
Scattered-grid pattern. Instances are spaced to avoid clumping, with each shrine appearing as a distinct landmark.

### 13. Inter-asset spacing minimum (m)
Minimum 15 meters from another instance of the same mesh.

### 14. Path-clearance distance (m)
Can spawn within 5 meters of the path centerline, provided it does not interfere with player movement.

### 15. Team color reasoning
TEAM=50 is chosen to distinguish the shrine as a neutral, relic-based landmark. It resolves to sand_light (0.95, 0.85, 0.70) in `game_fill_draws`.

### 16. Shadow / contact AO strategy
The shrine casts a soft shadow and uses ambient-occluded vertex colors to enhance its stone texture. No ground AO blob.

### 17. Distant-LOD strategy
No LOD implemented; the asset remains full resolution at all distances for consistency with the forest’s current approach.

### 18. Animation, if any
Static, no animation. The shrine is a still, architectural element.

### 19. Particle FX bound to entity
None. No particle effects are bound to the shrine.

### 20. Lighting interaction
The shrine catches warm sunlight on its eastern face and casts a long shadow to the west. It is self-shadowed to enhance its sculptural form.

### 21. Collision
Yes, it blocks player movement. `world.radius` is set to 1.0 to allow for interaction with nearby terrain.

### 22. Destructible
No. The shrine is a static landmark and not destructible in v1.

### 23. Lore hook
The shrine is a relic site where ancient travelers once placed offerings to the dune spirits.

### 24. Surface UV layout
The main pillar uses uBase 0, roof slab uses uBase 36, trim bands use uBase 40, dome uses uBase 42, and canopy slats use uBase 8.

### 25. Material specularity
Soft-glossy. The shrine's surfaces have a slight reflective sheen, especially on the golden trim.

### 26. Day/night appearance shift
Sun-side faces are warm-tinted with sand_light and accent_gold, while shadow-side faces are cool-tinted with sand_dark and rock_warm.

### 27. Silhouette test at 50 m
Yes, the shrine still reads as a recognizable structure at 50 meters. A minimum scale of 0.6 is required to maintain legibility.

### 28. Visual neighbours
The shrine looks best next to desert ruins, bone fields, and sparse dry vegetation. It complements the desert’s sparse, open aesthetic.

### 29. Visual conflicts
Should not appear near large sand dunes, as it will be visually overwhelmed. Also avoids placement near other open-air structures or dense clusters of flora.

### 30. Implementation hooks
- `src/main.zig`: Add case `50 => shrine` to `world.team` switch.
- `ios/Mesh.swift`: Add `makeShrine(device:)` function.
- `ios/GameViewController.swift`: Add dispatch case for `shrine` in `renderMesh` method.
---

## Asset 61 — idol_pedestal
1. **Silhouette at 30m** — From 30 meters away, the idol pedestal appears as a low, square plinth rising from the sand, with a tall, carved statuette on top, forming a clean vertical silhouette against the dunes.

2. **Tri-budget breakdown** — The 320 triangle budget is split as: body (220 tris), decorations (60 tris), FX (40 tris).

3. **Geometry construction** — The base plinth is a 32-sided cylinder with a slight taper, built using `mbCylinder` with a radius of 1.2m and height of 0.5m. The statuette is a tall, tapering column (0.8m height) with a spherical head on top, built using `mbCylinder` and `mbSphere`. Additional detail is added with a fan of triangles around the plinth's top edge to simulate a carved rim.

4. **Body palette** — The plinth is primarily sand_dark (0.75, 0.60, 0.45), with a subtle dune_shadow (0.40, 0.30, 0.25) on the bottom edge. The statuette uses rock_warm (0.78, 0.58, 0.42) with accent_gold (0.95, 0.78, 0.30) highlights on the upper face.

5. **uBase marker assignments per surface** —

| Surface        | uBase |
|----------------|-------|
| Plinth base    | 0     |
| Plinth rim     | 36    |
| Statuette body | 42    |
| Statuette head | 8     |

6. **Base scale (scale_min, scale_max)** — Scale range is 0.9 to 1.1. This small spread allows for visual variation without altering the asset’s core proportions or silhouette.

7. **Y rotation** — Random `0..2π`. The pedestal is not locked to any axis and can rotate freely to avoid repetition.

8. **Ground anchor** — The base sits flat on y=0, partially embedded into the sand to give a sense of age and permanence.

9. **Procedural variation method** — Instances vary in scale, rotation, and surface color tinting using a hash of their spawn location to ensure consistent, unique visual results.

10. **Spawn placement rules** — Spawns within a 10–30m radius of origin. Prefers open dunes, avoids paths and within 6m of other instances. Avoids areas with existing ruins or bone fields.

11. **Spawn count rationale** — Eight instances are appropriate for a 450m zone, spaced to suggest a sacred path or relic site without overwhelming the environment.

12. **Clustering pattern** — Scattered-grid. Instances are spaced to appear as a small group of ancient shrines, not a single row or tight cluster.

13. **Inter-asset spacing minimum (m)** — 6 meters minimum from another instance of the same mesh.

14. **Path-clearance distance (m)** — 8 meters from the path centerline to allow for safe player movement without visual clutter.

15. **Team color reasoning** — TEAM=50 is chosen to align with desert shrine aesthetics, resolving to sand_light (0.95, 0.85, 0.70) in the `game_fill_draws` switch for visual consistency with other shrine assets.

16. **Shadow / contact AO strategy** — Casts a soft shadow due to its vertical profile. Ground AO blob is included to give the base a subtle sand-shadowed look.

17. **Distant-LOD strategy** — No LOD currently; the asset remains at full resolution even at 200m distance to preserve its narrative importance.

18. **Animation, if any** — Static, no animation. The asset is meant to evoke reverence, not motion.

19. **Particle FX bound to entity** — None. The asset is not intended to generate FX, but it may be lit with ambient embers for visual warmth.

20. **Lighting interaction** — The statuette catches warm sunlight on its right side when facing west, casting a long shadow to the east. It is self-shadowed with ambient occlusion on the plinth.

21. **Collision** — Yes, it blocks movement. `world.radius` is set to 0.8m to allow for interaction with nearby terrain but not pass-through.

22. **Destructible** — No. The asset is a fixed relic, not meant to be broken in v1.

23. **Lore hook** — Once a sacred resting place for a desert deity, now worn smooth by time and sand.

24. **Surface UV layout** — Plinth base uses uBase 0, rim uses 36, statuette body uses 42, and the head uses uBase 8.

25. **Material specularity** — Soft-glossy. The statuette surface reflects light gently, but not in a mirror-like way.

26. **Day/night appearance shift** — The sun-side of the statuette takes on a warm amber hue, while the shadow-side appears slightly cooler, with a subtle shift in tone that reflects the desert’s time-of-day lighting.

27. **Silhouette test at 50 m** — Yes, the asset still reads clearly as a pedestal and statuette even at 50m. A minimum scale of 0.85 is sufficient to maintain readability.

28. **Visual neighbours** — Looks right next to sandstone pillars, bone piles, and distant dunes. Complements the overall desert shrine theme.

29. **Visual conflicts** — Should not be placed near large stone walls or clusters of fireflies, as those elements would compete for attention or obscure the statuette’s silhouette.

30. **Implementation hooks** — In `src/main.zig`, add case `50: return .shrine` to the `world.team` switch. In `ios/Mesh.swift`, add `func makeIdolPedestal(device: MTLDevice) -> MeshBuffers` and register it in `GameViewController.swift` under `dispatchMesh` with `case .idol_pedestal:`.
---

## Asset 62 — signal_brazier
### 1. **Silhouette at 30m** — The brazier appears as a tall, narrow, tripod structure with a glowing flame at its apex, clearly distinguishable from the surrounding dunes at a distance of 30 meters, even against the sky.

### 2. **Tri-budget breakdown** — Body: 200 tris; Decorations: 50 tris; FX: 30 tris. Total: 280 tris.

### 3. **Geometry construction** — The base is a tall, tapered cylinder forming the tripod legs. The central dish is a smaller cylinder with a raised edge, topped by a small sphere for the flame. The flame is modeled as a ring extrusion with a slight taper to suggest flicker. The legs are constructed from three cylinders, each angled outward to form a tripod.

### 4. **Body palette** — The tripod legs use `rock_warm`, `sand_light`, and `dune_shadow`. The brass dish uses `accent_gold`. The flame is represented as a glowing orange surface.

### 5. **uBase marker assignments per surface** — 

| Surface       | uBase |
|---------------|-------|
| Tripod legs   | 36    |
| Brass dish    | 42    |
| Flame         | 8     |
| Ground contact| 0     |

### 6. **Base scale (scale_min, scale_max)** — Scale range: 0.8 to 1.2. Justification: This allows for natural variation in height while maintaining consistent silhouette across the desert environment.

### 7. **Y rotation** — Random `0..2π`. This ensures visual variety and prevents alignment with terrain features or player paths.

### 8. **Ground anchor** — Partially buried, with y-offset of -0.2 meters. This gives the appearance of a weathered, integrated structure.

### 9. **Procedural variation method** — Variations include palette hash for `rock_warm` and `sand_light` surfaces, slight scale spread, and random Y rotation.

### 10. **Spawn placement rules** — Spawn radius: 10–25 meters from origin. Prefers open dunes, avoids areas within 6 meters of path centerline, and avoids spawning near ruins or oases.

### 11. **Spawn count rationale** — `EST_COUNT = 8` is appropriate for a 450m zone because it ensures visibility and presence without overwhelming the landscape. It allows for a sparse but meaningful signal presence across the desert.

### 12. **Clustering pattern** — Scattered-grid. Instances are spaced evenly across the zone, avoiding clustering to prevent visual monotony and ensure a natural spread.

### 13. **Inter-asset spacing minimum (m)** — Minimum 12 meters from another instance of the same mesh.

### 14. **Path-clearance distance (m)** — Must be at least 8 meters from path centerline.

### 15. **Team color reasoning** — TEAM=50 is chosen to distinguish this shrine from other structures while fitting the desert color scheme. It resolves to `accent_turquoise` in `game_fill_draws`.

### 16. **Shadow / contact AO strategy** — It casts a soft shadow, and the base uses ambient-occluded vertex colors to simulate the shadowed dune interaction.

### 17. **Distant-LOD strategy** — No LOD currently. It should follow the same strategy as forest assets, maintaining visual fidelity even at distance.

### 18. **Animation, if any** — Static, no animation. The flame is fixed in appearance for simplicity and performance.

### 19. **Particle FX bound to entity** — `brazier_flame` — a custom emitter preset using `ember_orange` and `accent_gold` particles to simulate flickering embers.

### 20. **Lighting interaction** — The brazier catches warm sunlight on its western face, casting a long shadow to the east. It is self-shadowed on the eastern side where the flame is most visible.

### 21. **Collision** — Blocks player movement. `world.radius = 0.6` to allow passage around the base while preventing walking through.

### 22. **Destructible** — No. This asset is a static shrine and not intended for destruction.

### 23. **Lore hook** — This brazier was once used by ancient traders to signal safe passage through the desert, now a relic of lost routes.

### 24. **Surface UV layout** — The tripod legs use `uBase=36`, the brass dish uses `uBase=42`, the flame uses `uBase=8`, and the ground contact uses `uBase=0`.

### 25. **Material specularity** — Soft-glossy. The brass dish has a slight sheen, and the stone legs are matte.

### 26. **Day/night appearance shift** — The sun-side is warm-tinted with `rock_warm` and `accent_gold`, while the shadow-side is cool-tinted with `dune_shadow` and `rock_cool`.

### 27. **Silhouette test at 50 m** — Yes, the silhouette is still recognizable at 50 meters. Minimum scale required is 0.6 to maintain clarity.

### 28. **Visual neighbours** — This asset looks right next to `desert_rock`, `oasis_palm`, and `ruins_archway`, as it integrates well into the desert aesthetic.

### 29. **Visual conflicts** — Should not be near `desert_tower` or `oasis_pool`, as these would compete for visual attention or create silhouette clutter.

### 30. **Implementation hooks** — 

- `src/main.zig`: Add case `50 => .shrine` in `world.team` switch.
- `ios/Mesh.swift`: Add `makeSignalBrazier(device:)` function.
- `ios/GameViewController.swift`: Add dispatch case `case .signal_brazier: self.makeSignalBrazier(device: device)`.

```metal
// Metal shader pseudocode for emissive flame
if (surface == uBase8) {
    color.rgb = mix(ember_orange, accent_gold, 0.7);
    color.a = 1.0;
}
```
---

## Asset 63 — sand_drift
### 1. Silhouette at 30m
The sand drift presents a soft, undulating hump with a gentle slope on its windward side, giving it a natural, organic shape that blends seamlessly into the desert landscape.

### 2. Tri-budget breakdown
The 140 triangle budget is allocated as follows: 110 triangles for the main sand pile body, 20 for decorative surface texture details, and 10 for low-resolution FX elements such as sand swirls or minor surface erosion.

### 3. Geometry construction
The sand drift is constructed using a combination of a base mbCylinder with a tapered radius, followed by two mbSphere segments placed on top to create a rounded, naturalistic dune profile. Additional surface detail is added via a fan of triangles extruded from the top to simulate grain texture. The geometry is built using a layered approach with stacked plates to simulate the internal structure of a sand drift.

### 4. Body palette
The body uses sand_light (0.95, 0.85, 0.70) for the main surface, sand_dark (0.75, 0.60, 0.45) for the shadowed base, and dune_shadow (0.40, 0.30, 0.25) for the internal crevices and subtle shadowing. A small accent of accent_gold (0.95, 0.78, 0.30) is used on the top-facing edge to simulate sun-bleached sand.

### 5. uBase marker assignments per surface
| Surface | uBase |
|--------|-------|
| Main body | 30 |
| Shadowed base | 30 |
| Surface texture | 30 |
| Accent edge | 30 |

(All surfaces use uBase=30 — sand_drift is reserved only for the sand_grading branch; lighting + per-vertex color hash handle shadowed/highlight variation.)

### 6. Base scale (scale_min, scale_max)
The scale range is 0.8 to 1.3. This allows for subtle variation in size to prevent visual repetition while maintaining the organic nature of a sand drift. The scale is chosen to be large enough to be impactful in the desert environment but not so large as to dominate the space.

### 7. Y rotation
The sand drift is aligned to the world axis with a random Y rotation from 0 to 2π to provide naturalistic orientation without disrupting the dune's structural flow.

### 8. Ground anchor
The sand drift sits flat on y=0 with a slight downward offset of 0.05 units to simulate partial burial in the sand, giving it a grounded, realistic appearance.

### 9. Procedural variation method
Variation is achieved through a combination of random scale spread (0.8–1.3), random Y rotation (0 to 2π), and a palette hash derived from the instance's world position to vary the exact tint of sand_light and accent_gold.

### 10. Spawn placement rules
Spawn radius is within 10–30 meters from the origin. Prefers open dunes with no strong biome-zone preference. Avoids spawning within 6 meters of path centerline to maintain clear movement corridors.

### 11. Spawn count rationale
With a 450m radius and 200 instances, the sand drifts are spread sparsely enough to not overcrowd the landscape but dense enough to contribute to the overall desert atmosphere and visual flow. This ensures a natural, believable desert texture.

### 12. Clustering pattern
The sand drifts are arranged in a scattered-grid pattern with occasional dense clusters near natural obstructions or in areas of terrain variation to simulate natural wind-driven accumulation.

### 13. Inter-asset spacing minimum (m)
Minimum spacing is 2.5 meters from any other instance of the same mesh to avoid visual repetition and ensure realistic drift formation.

### 14. Path-clearance distance (m)
The sand drift may spawn within 6 meters of a path centerline, but with a preference to avoid direct contact to maintain navigability.

### 15. Team color reasoning
TEAM=40 is chosen to align with organic, earth-toned assets in the desert. In `game_fill_draws`, this team color resolves to sand_light (0.95, 0.85, 0.70), matching the dominant body color of the asset.

### 16. Shadow / contact AO strategy
The sand drift casts a soft shadow on the ground and uses ambient-occluded vertex colors to simulate natural shadowing in the dune’s crevices. No emissive elements are used.

### 17. Distant-LOD strategy
The sand drift remains visible up to 100m distance, with no LOD simplification. Its shape and silhouette are designed to be clear at long distances to maintain the desert’s visual texture.

### 18. Animation, if any
Static, no animation. The asset remains motionless to maintain the illusion of a natural, stable sand drift.

### 19. Particle FX bound to entity
None. The sand drift does not use bound particle effects, as its visual appeal is derived from the natural sand structure and coloration.

### 20. Lighting interaction
The sand drift catches warm sunlight on the east-facing slope, with the west-facing side casting a long shadow. The surface is self-shadowed with soft transitions between light and shadow.

### 21. Collision
The sand drift does not block player movement. It has a `world.radius` of 0.3 to allow for small-scale interaction without impeding navigation.

### 22. Destructible
No. The sand drift is not destructible in v1, as it is a passive environmental element.

### 23. Lore hook
The sand drift is a remnant of a collapsed dune from a previous storm, now stabilized by a thin layer of hard-set sand and scattered bones from desert nomads.

### 24. Surface UV layout
Surface UV layout is as follows: uBase 30 covers the main sand body, 29 for the shadowed base, 28 for texture detail, and 27 for the sun-bleached edge.

### 25. Material specularity
The material is matte with soft-glossy highlights on the top edge to simulate a slight sand grain sheen under direct sunlight.

### 26. Day/night appearance shift
The sun-side of the sand drift takes on a warm, golden tint, while the shadow-side appears cooler and more muted. The warm tint is most pronounced on the east-facing slope during midday.

### 27. Silhouette test at 50 m
Yes, the sand drift still reads clearly as a dune at 50 meters. The silhouette is distinct enough to be visually identifiable and not lost in the landscape.

### 28. Visual neighbours
It looks right next to rock_warm (0.78, 0.58, 0.42) outcroppings, dry_vegetation (0.58, 0.50, 0.32) clumps, and bone_pale (0.92, 0.88, 0.78) remnants, all of which complement its warm desert palette.

### 29. Visual conflicts
The sand drift should not be placed near large, angular rock formations or dense vegetation that would clash with its soft, rounded silhouette and warm tones.

### 30. Implementation hooks
- In `src/main.zig`, add `case 40:` to the `world.team` switch.
- In `ios/Mesh.swift`, add a `makeSandDrift(device:)` function.
- In `ios/GameViewController.swift`, add a `dispatchSandDrift` case in the spawn dispatch logic.
---

## Asset 64 — lantern_post
### 1. Silhouette at 30m
The lantern post appears as a tall, vertical silhouette with a slight taper, topped by a glowing glass orb. Its profile is clearly distinct from the dunes and other vegetation, even at 30 meters.

### 2. Tri-budget breakdown
The mesh is broken into 180 tris for the body (cylinder + base), 70 tris for the glass dome, and 30 tris for decorative elements such as brass rings and flame highlights. Total = 280 tris.

### 3. Geometry construction
The lantern post is built using a tapered cylinder for the main body, constructed with `mbCylinder` using a vertical axis, 2.0m length, and 0.12m radius at base tapering to 0.08m at the top. A sphere is added at the top to form the glass-encased flame, and a small brass ring is extruded around the base. The decorative brass bands and internal flame details are constructed with stacked plates and fan-of-triangles.

### 4. Body palette
The main body uses sand_light for the iron structure, dune_shadow for the lower base, and accent_gold for the brass rings and top cap. The glass dome uses a translucent variant of ember_orange to simulate a warm flame glow.

### 5. uBase marker assignments per surface
| Surface         | uBase |
|----------------|-------|
| Main body      | 0     |
| Brass rings    | 42    |
| Glass dome     | 8     |
| Base ring      | 0     |

### 6. Base scale (scale_min, scale_max)
Base scale is 0.9 to 1.2. This range allows for natural variation in height and thickness without altering the asset's core silhouette or functional appearance.

### 7. Y rotation
Random `0..2π` rotation to avoid uniformity and enhance naturalistic placement in the desert.

### 8. Ground anchor
The lantern post is partially buried, with 0.15m of its base below ground level to simulate stability in shifting sand.

### 9. Procedural variation method
Variation is achieved via random scale within the set bounds and slight color palette shifts using a hash-based approach on the instance ID, ensuring each instance has a subtly different look.

### 10. Spawn placement rules
Instances spawn within a 20–45m radius of the zone origin, preferentially near oases or ruins, and must not be within 6m of the path centerline.

### 11. Spawn count rationale
With a 450m radius and the role of a beacon-like decor element, 40 instances provide sufficient visual guidance and aesthetic variation without overcrowding or visual fatigue.

### 12. Clustering pattern
Scattered-grid pattern. Instances are distributed to avoid tight clustering, with loose groupings of 2–3 near ruins and single instances elsewhere.

### 13. Inter-asset spacing minimum (m)
Minimum 8 meters between instances of the same mesh to prevent visual clutter.

### 14. Path-clearance distance (m)
Can spawn within 6 meters of the path centerline, but is placed with offset to avoid direct line-of-sight interference.

### 15. Team color reasoning
TEAM=51 to align with desert-themed decor assets. The team color resolves to `rock_warm` in the `game_fill_draws` switch, maintaining color consistency in the desert palette.

### 16. Shadow / contact AO strategy
The lantern post casts a soft shadow due to its vertical structure and is designed to integrate with ambient-occluded vertex colors to simulate ground contact shadows.

### 17. Distant-LOD strategy
No LOD is implemented; it remains at full resolution for the entire map view distance, as the desert environment benefits from consistent detail.

### 18. Animation, if any
Static, no animation. The flame is represented by emissive UV and does not animate in the mesh.

### 19. Particle FX bound to entity
No particle FX bound to the entity itself. However, a `brazier_flame` preset is used in the lighting system to simulate the glow.

### 20. Lighting interaction
The post catches warm sunlight on its western face, with the glass dome glowing more intensely when sun-facing. Its shadow falls eastward and is long at sunrise/sunset.

### 21. Collision
Does not block movement; it has a world.radius of 0.3 to allow passage around it.

### 22. Destructible
No. The lantern post is not destructible in v1.

### 23. Lore hook
A relic from an ancient trading caravan, now weathered but still lit to guide lost travelers through the desert.

### 24. Surface UV layout
The main body (uBase 0) covers the iron cylinder. The brass rings (uBase 42) are on the top and base. The glass dome (uBase 8) is a separate surface with emissive UV mapping.

### 25. Material specularity
Soft-glossy for the iron body and brass rings, with the glass dome being refractive and emissive-additive.

### 26. Day/night appearance shift
Sun-side is warm-toned with sand_light and accent_gold, while shadow-side appears cooler with dune_shadow and rock_cool, creating a distinct day-night contrast.

### 27. Silhouette test at 50 m
Yes, the asset still reads clearly at 50 meters. The vertical taper and glass dome remain visually distinct, even with the full map’s average view distance.

### 28. Visual neighbours
Looks best next to oasis flora, dry vegetation, and ancient ruins. It complements the warm tones and verticality of the desert environment.

### 29. Visual conflicts
Should not be placed near other tall, glowing assets like beacon towers or desert lanterns, as it risks silhouette confusion or overloading the visual field.

### 30. Implementation hooks
- Add `case 51` to `world.team` switch in `src/main.zig`
- Add `makeLanternPost(device:)` function in `ios/Mesh.swift`
- Add dispatch case in `ios/GameViewController.swift` for `lantern_post` with `makeLanternPost(device:)` call
---

## Asset 65 — travelers_cairn
### 1. Silhouette at 30m
The cairn appears as a small, vertical stack of five to eight weathered stones, slightly tapering toward the top, forming a knee-high, squat, and slightly irregular silhouette that reads clearly against the dune backdrop.

### 2. Tri-budget breakdown
The mesh is divided into 140 tris for the main body (stacked stone layers), 30 tris for decorative surface textures, and 10 tris for optional FX (e.g., small dust particles or ambient glow). Total = 180 tris.

### 3. Geometry construction
The cairn is constructed using a series of mbCylinder calls to form the individual stone layers, each slightly tapered and stacked with slight offsets. A few mbSphere calls are used for small, rounded top stones to add visual variation. The geometry is built as a static cluster, with each stone being an extruded ring or a stack of plates, and all stones are fused into a single mesh with a shared vertex buffer.

### 4. Body palette
The main body uses **rock_warm**, **dune_shadow**, and **sand_dark**. These colors are applied to the outer surfaces of the stacked stones. A subtle hint of **accent_gold** is used on one or two stones to imply age or weathering.

### 5. uBase marker assignments per surface
| Surface          | uBase |
|------------------|-------|
| Main stack       | 0     |
| Top stone        | 8     |
| Decorative spots | 0     |
| Shadow areas     | 0     |

### 6. Base scale (scale_min, scale_max)
Scale range is 0.9 to 1.3. The scale spread ensures instances vary slightly in height and width to avoid repetition while maintaining the knee-high silhouette. This allows for natural visual variation in a desert environment.

### 7. Y rotation
Random 0..2π rotation. The cairn is fully rotatable to break up repetitive alignment in the desert.

### 8. Ground anchor
Sits flat on y=0, with the base slightly embedded into the sand surface (y offset of -0.05) to simulate a weathered, half-buried appearance.

### 9. Procedural variation method
Variation is achieved through a combination of random scale spread, slight rotation, and palette hashing to determine which stones are tinted with **accent_gold** or **rock_cool**.

### 10. Spawn placement rules
Spawn radius from origin is 10–30 m. Prefers open dunes, not near oases or ruins. Avoids spawning within 6 m of path centerline. Not placed near other decor assets to preserve visual breathing room.

### 11. Spawn count rationale
With an estimated zone radius of 450 m and role as a subtle landmark, 20 instances provide a good distribution across the zone without overwhelming the player or causing visual clutter.

### 12. Clustering pattern
Scattered-grid. Instances are placed in loose, evenly spaced grids across the zone to create a natural, organic feel, not clustered or aligned to paths.

### 13. Inter-asset spacing minimum (m)
Minimum 8 m from another instance of the same mesh. Ensures visual separation and avoids repetitive stacking.

### 14. Path-clearance distance (m)
Can spawn within 5 m of path centerline, but not closer than 6 m. This allows some visual proximity to paths without obstructing movement.

### 15. Team color reasoning
TEAM=43 is chosen to align with desert landmarks and weathered ruins. The team color resolves to **rock_cool** in the `game_fill_draws` switch, giving it a consistent, neutral tone that blends with stone and sand.

### 16. Shadow / contact AO strategy
Casts a soft shadow and has a ground AO blob to simulate sand accumulation under the base. Uses ambient-occluded vertex colors to subtly enhance depth and realism.

### 17. Distant-LOD strategy
No LOD is implemented for this asset, following the current forest strategy. It remains visible at full resolution across the map.

### 18. Animation, if any
Static, no animation. The asset is intentionally still to convey permanence and weathering.

### 19. Particle FX bound to entity
None. The cairn does not have any bound particle effects.

### 20. Lighting interaction
The cairn catches warm sunlight on its east-facing side, casting a long shadow to the west. It is self-shadowed and adapts to sun direction to enhance its desert realism.

### 21. Collision
Does not block player movement. `world.radius` is set to 0.25 to allow easy passage.

### 22. Destructible
No. The cairn is not destructible in v1.

### 23. Lore hook
A remnant of ancient travel paths, left behind by long-dead caravans to mark a safe resting spot in the desert.

### 24. Surface UV layout
The main stack uses uBase 0 for general texture mapping. The top stone uses uBase 8 for emissive glow or highlight. Decorative spots also use uBase 0.

### 25. Material specularity
Matte. The stones are not glossy or reflective, matching the soft, weathered texture of desert stone.

### 26. Day/night appearance shift
Sun-side appears warm and golden with **accent_gold** highlights, while shadow-side takes on a cooler tone of **rock_cool**. No night-time color shift is applied.

### 27. Silhouette test at 50 m
Yes, the cairn remains clearly identifiable as a stacked stone structure at 50 m. The silhouette is still distinct and recognizable, even at half the map’s average view distance. The minimum scale is set to 0.8 to maintain visibility.

### 28. Visual neighbours
Looks right next to **desert_boulder**, **cactus_cluster**, and **oasis_palm**. Composes well with desert flora and weathered ruins.

### 29. Visual conflicts
Should not be placed near large, flat, or bright objects like **sandstone_outcrop** or **sunstone_rock**, which would compete visually for attention and reduce the cairn’s subtle impact.

### 30. Implementation hooks
- Add case `case 43:` to `world.team` switch in `src/main.zig`
- Add `makeTravelersCairn(device:)` function in `ios/Mesh.swift`
- Add dispatch case for `travelers_cairn` in `ios/GameViewController.swift`
---


---

## Asset 66 — desert_obelisk
### 1. Silhouette at 30m
The obelisk appears as a tall, narrow, pyramidal spike against the desert sky, its sharp tip clearly visible from 30 meters away, giving it strong directional presence on the dunes.

### 2. Tri-budget breakdown
Body: 300 tris; Decorations: 40 tris; FX: 20 tris. Total: 360 tris.

### 3. Geometry construction
The main body is a tall, tapered cylinder built with `mbCylinder`, using a base radius of 1.2m and a tip radius of 0.3m. A small spherical cap at the top, constructed with `mbSphere`, adds the pyramidal tip. The base features a series of vertical grooves formed by extruding narrow ribbons along the cylinder's surface.

### 4. Body palette
Uses rock_warm, sand_light, dune_shadow, and accent_gold. Rock_warm covers the main body, sand_light covers the base ring, dune_shadow is used for internal grooves, and accent_gold accents the top edge.

### 5. uBase marker assignments per surface
| Surface       | uBase |
|---------------|-------|
| Main body     | 0     |
| Base ring     | 36    |
| Grooves       | 40    |
| Top cap       | 0     |
| Emissive      | 8     |

### 6. Base scale (scale_min, scale_max)
Scale range: 0.95 to 1.05. Justification: Ensures visual variety without altering the core silhouette or scale relationship to the player’s perception.

### 7. Y rotation
Random `0..2π` rotation to provide varied visual engagement across the dunes.

### 8. Ground anchor
Partially buried, with 0.15m of the base below y=0. This anchors it in the dune terrain and adds realism.

### 9. Procedural variation method
Variation includes a palette hash for color shifts, a small scale spread (±0.05), and random Y rotation.

### 10. Spawn placement rules
Spawns within radius 400–440m from origin, in open dunes away from oases and ruins. Must avoid being within 6m of path centerline.

### 11. Spawn count rationale
With a 450m radius and 64 instances, each obelisk is placed roughly every 22 meters. This spacing ensures strong visual rhythm and boundary definition without overcrowding.

### 12. Clustering pattern
Scattered-grid pattern. Instances are placed in a grid-like pattern but with slight offset per row to simulate natural dune formations.

### 13. Inter-asset spacing minimum (m)
Minimum 10 meters from another obelisk of same type.

### 14. Path-clearance distance (m)
Cannot spawn within 8 meters of path centerline. This ensures clear sightlines and avoids cluttering paths.

### 15. Team color reasoning
TEAM=52 is chosen to align with the desert's warm, earthy tones and to contrast with other biome teams. It resolves to rock_warm in `game_fill_draws`.

### 16. Shadow / contact AO strategy
Casts a strong shadow, but no ground AO blob. Uses ambient-occluded vertex colors to define base depth.

### 17. Distant-LOD strategy
No LOD currently. It should follow the forest strategy of no LOD to maintain visual consistency.

### 18. Animation, if any
Static, no animation.

### 19. Particle FX bound to entity
None. No particle FX attached to the obelisk.

### 20. Lighting interaction
The obelisk catches warm sunlight on its western face, casting a long shadow to the east. It is self-shadowed to enhance its pyramidal form.

### 21. Collision
Blocks player movement. `world.radius` set to 1.2m to allow for safe navigation around the base.

### 22. Destructible
No. Obelisks are ancient and immutable in the desert.

### 23. Lore hook
It is a remnant of a lost civilization’s sacred architecture, left to weather the dunes as a testament to their power.

### 24. Surface UV layout
Main body uses uBase 0; Base ring uses uBase 36; Grooves use uBase 40; Top cap uses uBase 0; Emissive is mapped to uBase 8.

### 25. Material specularity
Soft-glossy. Reflects ambient light slightly, but not in a mirror-like fashion.

### 26. Day/night appearance shift
Sun-side faces warm with sand_light and accent_gold; shadow-side faces cool with dune_shadow and rock_cool. The transition is subtle and natural.

### 27. Silhouette test at 50 m
Yes, the obelisk maintains its identity as a tall, pyramidal structure at 50 meters. The minimum scale required is 0.90 to remain visually distinct.

### 28. Visual neighbours
Looks right next to `desert_rock`, `dune_boulder`, and `oasis_palm`. These assets complement its vertical and ancient feel.

### 29. Visual conflicts
Should not be placed near `desert_brazier`, `sand_dune`, or `ruins_pillar`, as those would visually compete with its silhouette or reduce its boundary role.

### 30. Implementation hooks
- Add case `52` to `world.team` switch in `src/main.zig`
- Add `makeObelisk(device:)` function in `ios/Mesh.swift`
- Add dispatch case in `ios/GameViewController.swift` for `desert_obelisk`
