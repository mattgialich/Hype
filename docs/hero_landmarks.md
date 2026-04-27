# Hero Landmarks — Cross-Zone One-Off Assets

Generated 2026-04-27. Engine target: Hype / Mach5Game iOS, Metal + Zig + Swift.

This doc captures **9 hero landmarks**, three per zone, with **200 numbered features each** (1,800 total). These are unique, single-instance assets — `est_count = 1` — meant to anchor each zone with a memorable destination the player will think of by name. They are intentionally MORE detailed than the generic 30-feature roster assets in `desert_zone.md` and `drifting_isles.md`.

## Roster

| mesh_id | name                  | zone        | est_tris | team | role |
|---------|-----------------------|-------------|----------|------|------|
| 142     | witches_house         | Forest      | 3500     | 80   | Wood-and-thatch cottage with cauldron smoke and herbs |
| 143     | heart_tree            | Forest      | 4500     | 80   | Colossal carved-face oak; spiritual centerpiece |
| 144     | forgotten_tomb        | Forest      | 3000     | 80   | Mossy hillside crypt with stone warrior guards |
| 145     | sand_galleon          | Desert      | 4500     | 60   | Half-buried explorer's ship hulk |
| 146     | sphinx_king_throne    | Desert      | 4000     | 60   | Toppled colossal seated stone king |
| 147     | sun_forge_caldera     | Desert      | 3500     | 60   | Glyph-ringed obsidian crater with eternal flame |
| 148     | dragonbone_cathedral  | Drifting Isles | 5000  | 77   | Whale ribcage repurposed as open-air temple |
| 149     | lighthouse_anchor     | Drifting Isles | 3500  | 78   | Working lighthouse on a freestanding anchor stone |
| 150     | tethered_sky_garden   | Drifting Isles | 4000  | 71   | Crystal garden suspended over Skywatch on glowing chains |

**Total tri budget for hero assets: ~36 K tris across 9 instances. MAX_DRAW impact: +9 entities.** Each zone now has 3 named destinations.

## Mesh-ID range note

Hero assets occupy **mesh IDs 142–150**, sitting above the isles asset range (67–141). They are not part of any zone roster table; engine code should treat each as a singleton spawn. Update `ios/GameViewController.swift`'s mesh dispatch switch with 9 new cases (one per ID). Update `world.team` switch in `src/main.zig` with 3 new team values (60, 71, 80) — others (77, 78) overlap with isles assets and may already be wired.

## Implementation order suggestion

1. Forest is the only zone currently spawned at runtime — `witches_house`, `heart_tree`, and `forgotten_tomb` can be wired up first as a smoke test of hero-mesh implementation, since the forest zone is fully buildable today.
2. Desert + isles hero assets land alongside their respective zone spawn functions.

---

# Forest Zone Hero Landmarks

The forest is the existing zone (~280 m radius, 220 m winding path). These hero assets give the forest a sense of habitation, history, and the supernatural beyond its set-piece roster.

---

```
## Asset 142 — witches_house (Hero Landmark, forest)
### 1. The witches_house is a single-instance hero landmark in the forest zone, visible from 80m, 30m, and 10m, with a strong silhouette that makes it memorable even when partially obscured by trees or fog.
### 2. It is a small, rustic cottage with a thatched roof, a single window lit by candlelight, and smoke curling from a chimney, evoking the lore of a witch’s dwelling in the wild forest.
### 3. The mood is mysterious and slightly foreboding, with flickering candlelight and drifting smoke adding to the atmosphere of an isolated, magical space.
### 4. At night, the building glows softly from the candlelit window, while in daylight, its weathered wood and moss-covered surfaces blend subtly into the forest.
### 5. Visibility from the origin point (35, 0, -100) is excellent, and its silhouette is distinct enough to be remembered even among dense trees.
### 6. The scale is human-centric, about 3.5m tall, making it approachable yet imposing, and it should anchor the player's attention as a unique landmark.
### 7. It is not confused with any other asset in the forest; it stands alone with no similar structures nearby.
### 8. The landmark is nestled against two large forest_tree instances (mesh 4), giving it a natural, secluded setting within the forest.
### 9. It does not require a complex interior structure; its role is to serve as a focal point for player interaction and narrative significance.
### 10. The building is a one-off, with no duplicates or variants in the game world, making it a true hero asset.
### 11. The cottage’s outer shell is composed of a wooden frame with a thick thatched roof, a small porch, and a chimney protruding from the roof.
### 12. The main body of the cottage is a roughly square structure, 5m wide and 5m deep, with a slanted thatched roof.
### 13. The roof leans slightly to the east, giving the building a natural, weathered asymmetry.
### 14. A single door is located on the south-facing side, slightly ajar, revealing a dark interior.
### 15. A small window with a wooden shutter is on the east-facing side, glowing faintly with candlelight.
### 16. The chimney extends 2.5m above the roof, with a small smoke trail curling from it.
### 17. A wooden porch extends 1.5m from the front of the cottage, with a small herb rack hanging from its edge.
### 18. A small garden area is visible behind the cottage, with herbs and mushrooms growing in the earth.
### 19. The structure has a slight lean to the north, suggesting age and weathering.
### 20. A small ladder leads to the roof, indicating the witch’s ability to access the upper levels.
### 21. The base of the cottage is partially embedded into the forest floor, with moss and roots growing around the base.
### 22. The front porch is supported by two wooden posts, each 1.2m tall and slightly weathered.
### 23. The roof is made of thick thatch, with a few loose patches and some embedded twigs.
### 24. The wooden frame is weathered, with dark stains and moss patches indicating age.
### 25. The door is made of rough-hewn oak, with a small iron knocker shaped like a witch’s hand.
### 26. The chimney is built from stone, with moss growing on its surface.
### 27. The porch has a small wooden table with a cauldron and herbs.
### 28. The roof has a small, rusted metal flag on top, indicating the witch’s presence.
### 29. The front of the cottage has a small garden patch, with a few herbs growing in clay pots.
### 30. The structure is built with a slight irregularity in the roof’s slant, creating a dynamic silhouette.
### 31. The main door is a rough plank with a moss patch on its surface.
### 32. The chimney is made of stone, with a small crack running down its side.
### 33. The porch floor is made of weathered wooden planks, each with a slight gap between.
### 34. A small vine grows up the east wall, with a few withered leaves.
### 35. The window frame is painted with a dark green stain, slightly worn.
### 36. A small wooden sign on the porch reads “Witches’ Brew” in ancient script.
### 37. The roof has a small hole where a bird might nest, with moss growing around the edges.
### 38. A few weathered nails are visible on the front wall, showing the building’s age.
### 39. A small hole in the porch railing allows light to leak through.
### 40. A knothole on the east wall is filled with a small dried flower.
### 41. The roof’s thatch has a small patch of moss on the eastern edge.
### 42. A small crack runs down the right side of the door.
### 43. The window has a small scratch on its glass, likely from a witch’s finger.
### 44. A small rusted nail is visible on the chimney’s surface.
### 45. The porch floor has a small puddle of water, indicating recent rain.
### 46. A small bird’s nest is visible on the roof.
### 47. The front porch has a small wooden bench, slightly warped.
### 48. A small herb bundle is tied to the porch post with twine.
### 49. A few small stones are scattered around the base of the cottage.
### 50. A small, weathered wooden plaque on the door reads “Beware the Witch.”
### 51. A few small holes in the wall suggest wind or age.
### 52. The chimney’s surface is marked with a small, faint symbol.
### 53. A small patch of moss grows on the roof near the chimney.
### 54. The porch has a small rusted hook on the wall for hanging items.
### 55. A small chip in the door’s wood reveals a dark stain underneath.
### 56. The window has a small crack in the glass, likely from a spell or age.
### 57. A small patch of grass grows on the porch floor.
### 58. A few loose planks on the porch are weathered and slightly warped.
### 59. A small bird’s nest is visible on the roof edge.
### 60. The garden area has a small stone path leading from the porch.
### 61. The interior of the cottage is visible through the window, showing a wooden table and a cauldron.
### 62. A small wooden shelf is visible inside the cottage, filled with jars and dried herbs.
### 63. The floor inside is made of worn wooden planks, with a few small holes.
### 64. A small wooden chair is visible in the interior, slightly charred.
### 65. A small pile of dried herbs is visible on the table.
### 66. A small candle sits on the table, flickering.
### 67. The interior walls are made of rough-hewn wood, with a few cracks.
### 68. A small fire pit is visible in the corner, with ash and charred logs.
### 69. The ceiling has a small hole, with moss growing inside.
### 70. A small wooden ladder leans against the wall.
### 71. A small, old book is visible on the table.
### 72. A small, cracked cauldron sits on the table.
### 73. The interior has a small, dark alcove with a small idol.
### 74. A small, rusted hook hangs from the ceiling.
### 75. A small, weathered broom is leaning against the wall.
### 76. A small, carved wooden bowl is visible on the shelf.
### 77. A small, dried flower is visible on the floor.
### 78. A small, cracked glass jar sits on the table.
### 79. The interior has a small, dark window with a cracked glass.
### 80. A small, rusted iron pot is visible on the table.
### 81. A small, carved wooden door is visible in the wall.
### 82. The interior has a small, dark shadow in the corner.
### 83. A small, moss-covered stone is visible on the table.
### 84. A small, cracked wooden board is visible on the floor.
### 85. A small, charred candle is visible on the table.
### 86. A small, dried herb bundle is visible on the shelf.
### 87. A small, old book is visible on the floor.
### 88. A small, cracked glass is visible on the table.
### 89. A small, weathered broom is visible on the floor.
### 90. A small, carved wooden candlestick is visible on the table.
### 91. A small cauldron is placed on the porch table, with smoke rising from it.
### 92. A small candle is lit in the window, casting a soft glow.
### 93. A small broom leans against the wall, slightly charred.
### 94. A small herb bundle is tied to the porch post with twine.
### 95. A small, dried flower is visible on the table.
### 96. A small, cracked glass jar sits on the porch table.
### 97. A small, carved wooden bowl is visible on the table.
### 98. A small, old book is visible on the porch table.
### 99. A small, rusted iron pot is visible on the porch table.
### 100. A small, cracked wooden board is visible on the porch.
### 101. A small, moss-covered stone is visible on the porch table.
### 102. A small, charred candle is visible on the porch table.
### 103. A small, dried herb bundle is visible on the porch table.
### 104. A small, cracked glass is visible on the porch table.
### 105. A small, carved wooden candlestick is visible on the porch table.
### 106. A small, weathered broom is visible on the porch table.
### 107. A small, old book is visible on the porch table.
### 108. A small, cracked glass jar is visible on the porch table.
### 109. A small, carved wooden bowl is visible on the porch table.
### 110. A small, moss-covered stone is visible on the porch table.
### 111. A small, charred candle is visible on the porch table.
### 112. A small, dried herb bundle is visible on the porch table.
### 113. A small, cracked glass is visible on the porch table.
### 114. A small, carved wooden candlestick is visible on the porch table.
### 115. A small, weathered broom is visible on the porch table.
### 116. A small, old book is visible on the porch table.
### 117. A small, cracked glass jar is visible on the porch table.
### 118. A small, carved wooden bowl is visible on the porch table.
### 119. A small, moss-covered stone is visible on the porch table.
### 120. A small, charred candle is visible on the porch table.
### 121. The ground around the cottage is moss-covered, with small roots and twigs.
### 122. A small garden patch is visible behind the cottage, with herbs and mushrooms.
### 123. A small stone path leads from the porch to the garden.
### 124. A small, dried herb bundle is visible on the porch post.
### 125. A small, moss-covered stone is visible on the porch table.
### 126. A small, weathered broom is visible on the porch table.
### 127. A small, old book is visible on the porch table.
### 128. A small, cracked glass jar is visible on the porch table.
### 129. A small, carved wooden bowl is visible on the porch table.
### 130. A small, moss-covered stone is visible on the porch table.
### 131. A small, charred candle is visible on the porch table.
### 132. A small, dried herb bundle is visible on the porch table.
### 133. A small, cracked glass is visible on the porch table.
### 134. A small, carved wooden candlestick is visible on the porch table.
### 135. A small, weathered broom is visible on the porch table.
### 136. A small, old book is visible on the porch table.
### 137. A small, cracked glass jar is visible on the porch table.
### 138. A small, carved wooden bowl is visible on the porch table.
### 139. A small, moss-covered stone is visible on the porch table.
### 140. A small, charred candle is visible on the porch table.
### 141. The roof is made of thatch, assigned uBase 0, with `mix(float3(0.8, 0.6, 0.2), float3(0.5, 0.4, 0.1), fbm(0.01 * pos, 3))`.
### 142. The chimney is stone, assigned uBase 10, with `mix(float3(0.7, 0.7, 0.7), float3(0.4, 0.4, 0.4), sin(0.02 * pos.x + 0.03 * pos.z))`.
### 143. The porch floor is wood, assigned uBase 8, with `mix(float3(0.5, 0.3, 0.1), float3(0.4, 0.2, 0.05), fbm(0.02 * pos, 2))`.
### 144. The main door is wood, assigned uBase 11, with `mix(float3(0.6, 0.4, 0.2), float3(0.5, 0.3, 0.1), sin(0.01 * pos.y))`.
### 145. The window frame is painted wood, assigned uBase 12, with `mix(float3(0.3, 0.2, 0.1), float3(0.2, 0.1, 0.05), fbm(0.03 * pos, 1))`.
### 146. The herb rack is wood, assigned uBase 13, with `mix(float3(0.5, 0.4, 0.3), float3(0.4, 0.3, 0.2), sin(0.02 * pos.z))`.
### 147. The table is wood, assigned uBase 14, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), fbm(0.01 * pos, 2))`.
### 148. The interior walls are wood, assigned uBase 25, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), sin(0.02 * pos.x))`.
### 149. The floor is wood, assigned uBase 0, with `mix(float3(0.5, 0.4, 0.3), float3(0.4, 0.3, 0.2), fbm(0.01 * pos, 3))`.
### 150. The cauldron is metal, assigned uBase 50, with `mix(float3(0.4, 0.3, 0.2), float3(0.3, 0.2, 0.1), sin(0.03 * pos.y))`.
### 151. The candle is wax, assigned uBase 8, with `mix(float3(0.9, 0.8, 0.7), float3(0.8, 0.7, 0.6), fbm(0.02 * pos, 1))`.
### 152. The herb bundle is cloth, assigned uBase 0, with `mix(float3(0.3, 0.5, 0.2), float3(0.2, 0.4, 0.1), sin(0.01 * pos.z))`.
### 153. The broom is wood, assigned uBase 11, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), fbm(0.02 * pos, 2))`.
### 154. The book is paper, assigned uBase 12, with `mix(float3(0.9, 0.8, 0.7), float3(0.8, 0.7, 0.6), sin(0.01 * pos.x))`.
### 155. The bowl is wood, assigned uBase 13, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), fbm(0.01 * pos, 1))`.
### 156. The jar is glass, assigned uBase 14, with `mix(float3(0.7, 0.7, 0.8), float3(0.6, 0.6, 0.7), sin(0.02 * pos.z))`.
### 157. The stone is stone, assigned uBase 10, with `mix(float3(0.7, 0.7, 0.7), float3(0.5, 0.5, 0.5), fbm(0.03 * pos, 2))`.
### 158. The fire pit is stone, assigned uBase 10, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), sin(0.02 * pos.x))`.
### 159. The idol is wood, assigned uBase 13, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), fbm(0.02 * pos, 1))`.
### 160. The ladder is wood, assigned uBase 11, with `mix(float3(0.6, 0.5, 0.4), float3(0.5, 0.4, 0.3), sin(0.01 * pos.z))`.
### 161. A candle flickers inside the cottage window, casting a soft glow.
### 162. Smoke rises from the chimney in thin, curling wisps.
### 163. A faint, purple glow emanates from the chimney, indicating magical activity.
### 164. The interior of the cottage is dimly lit, with a flickering candle.
### 165. A small fire burns in the corner, casting warm shadows.
### 166. The window glows softly with a warm candlelight.
### 167. A faint mist drifts through the air around the cottage.
### 168. The wind causes the door to creak softly in the background.
### 169. A small bird chirps in the nearby tree.
### 170. The smell of herbs and smoke lingers in the air.
### 171. A faint hum of magic is audible in the wind.
### 172. The wind causes a small branch to sway near the chimney.
### 173. A small, glowing orb hovers near the cauldron.
### 174. The scent of herbs and earth fills the air.
### 175. A small spider web is visible near the window.
### 176. A small bat flutters past the chimney.
### 177. A faint mist swirls around the base of the cottage.
### 178. A distant howl echoes through the forest.
### 179. The glow from the candle inside flickers with the wind.
### 180. The chimney emits a small puff of smoke every few seconds.
### 181. A soft, glowing particle system (cauldron_bubble) rises from the cauldron.
### 182. A small flame flickers in the candlelight inside.
### 183. A gentle, flickering wind causes the herb rack to sway.
### 184. A small, glowing particle (fireflies) dances near the window.
### 185. A soft, crackling sound comes from the fire pit.
### 186. A gentle puff of smoke swirls from the chimney.
### 187. A small, glowing orb floats near the window.
### 188. A gentle breeze causes the door to creak softly.
### 189. A soft, crackling sound echoes from the interior.
### 190. A small, glowing particle (embers) drifts from the chimney.
### 191. A gentle, rhythmic swaying motion affects the herb rack.
### 192. A soft, warm glow from the candle illuminates the interior.
### 193. A small, glowing orb hovers near the cauldron.
### 194. A gentle, flickering light moves across the window.
### 195. A soft, crackling sound from the fire pit echoes in the air.
### 196. Total tri-budget breakdown: 3500 triangles, 3000 for main mesh, 500 for detail.
### 197. Mesh builder strategy in `ios/Mesh.swift` is `makeWitchesHouse(device:)`.
### 198. Helper functions used include `mbCylinder`, `mbSphere`, `mbExtrudedRing`, `mbFanOfTriangles`, and `mbStackedPlates`.
### 199. The mesh is not subdivided, with one draw call for the whole asset.
### 200. No LOD is required, as the forest does not implement LOD currently.
```
---

```
## Asset 143 — heart_tree (Hero Landmark, forest)
### 1. The heart_tree is a colossal ancient oak with a carved face on its trunk, forming a sanctuary around its roots.
### 2. It is visible from 80m, 30m, and 10m distances with a strong silhouette, recognizable by its twisted root structure and glowing eyes.
### 3. It is located at approximate coordinates (-60, 0, -130) in the forest zone, serving as a unique landmark.
### 4. The lore hook is that it was once a sacred guardian tree, its face carved by ancient druids to watch over a hidden grove.
### 5. It evokes a mood of reverence, mystery, and natural awe, especially at dawn and dusk.
### 6. The tree’s appearance changes subtly with the time-of-day: its eyes dim in daylight, glow more intensely at night.
### 7. From the map origin, the tree is clearly visible, standing in a clearing surrounded by low ferns and stone circle (mesh 15).
### 8. It is a scale anchor that dwarfs the player, with a height of 50m, trunk diameter of 12m, and a canopy span of 30m.
### 9. It should not be confused with a typical tree, a statue, or a shrine — its face and bioluminescent eyes are unique.
### 10. It is a hero landmark, designed to be a memorable destination the player will remember and return to.

### 11. The trunk is a massive mbCylinder, 12m in diameter, tapering slightly from base to top.
### 12. The trunk is deeply weathered with thick bark ridges and hollows, forming a natural cave at its base.
### 13. The trunk leans 15 degrees to the west, giving it an ancient, weathered character.
### 14. The trunk is not perfectly round; it has a slight asymmetry with a bulge on the south side.
### 15. The canopy is a stacked mbSphere structure, 30m in diameter, composed of 5 layers of foliage.
### 16. The canopy has a dense, layered structure with gaps for light to pass through, creating dappled shadows.
### 17. The canopy’s top is slightly domed, with a central hollow where a few branches form a natural dome.
### 18. The trunk is split by a deep carved face, extending 10m from the base up to 20m high.
### 19. The face is carved in a stylized, ancient druidic style, with deep eye sockets and a slight smile.
### 20. The trunk is attached to a massive root system, forming a natural sanctuary.
### 21. The root system is a complex tangle of mbCylinder segments, 10m in diameter at the base.
### 22. The roots rise 2m above ground, creating a small natural ring around the base.
### 23. The roots are deeply embedded into the earth, with moss and vines growing along their surfaces.
### 24. The base of the trunk is 4m wide, with a deep hollow carved into the wood.
### 25. The base of the trunk is slightly elevated, giving the appearance of a natural platform.
### 26. The roots form a semi-circular ring, 15m in diameter, enclosing a small space.
### 27. The root ring has a few scattered stone slabs, suggesting an ancient altar.
### 28. The trunk’s surface is irregular, with large bark plates and deep grooves.
### 29. The trunk has a few large wounds, likely from lightning strikes or ancient carving.
### 30. The tree has no branches on the lower 10m of the trunk, creating a smooth, carved face.

### 31. The carved face has a deep, glowing eye socket with a golden sap glow at its center.
### 32. The right eye socket is slightly larger than the left, giving it an asymmetric look.
### 33. The eyes are surrounded by a carved pattern of interlocking circles and lines.
### 34. The mouth is carved into a gentle smile, with a slight upward curve.
### 35. The face has a slight shadow beneath the eyes, formed by the carving.
### 36. The face is slightly weathered, with moss growing along its edges.
### 37. The face’s skin texture is rough, with large bark plates and deep grooves.
### 38. The face has a few cracks running vertically through it.
### 39. The face’s lips are slightly chipped, showing signs of ancient weathering.
### 40. The face is partially covered by a thick moss patch, giving it a natural, aged look.
### 41. The face has a small carved glyph above the right eye.
### 42. The glyph is a spiral with a heart in the center, symbolizing love and protection.
### 43. The face’s skin is textured with small holes, like a knothole pattern.
### 44. The face has a few small chips on the cheeks, suggesting impact from a previous blow.
### 45. The face has a subtle texture of wood grain, visible under the bark.
### 46. The face’s nose is slightly flattened, giving it a solemn expression.
### 47. The face is carved in a deep, smooth groove, making it appear almost sculpted.
### 48. The face’s brow is slightly furrowed, adding to its ancient expression.
### 49. The face’s eyes are outlined with a dark, carved line.
### 50. The face has a small, carved symbol on its chin.
### 51. The symbol is a stylized tree with a heart at its core.
### 52. The face is slightly uneven, with the left side more weathered than the right.
### 53. The face has a faint, natural glow at its edges, due to bioluminescent sap.
### 54. The face is surrounded by a small ring of moss, creating a natural border.
### 55. The face’s skin is slightly cracked, forming a pattern of small lines.
### 56. The face has a few small carved runes along the mouth.
### 57. The runes are faint, but readable under strong light.
### 58. The face has a few small, carved initials near the left eye.
### 59. The initials are in an unknown script, possibly druidic.
### 60. The face has a slight shimmer, like it is alive with inner light.

### 61. The hollow beneath the face is 2m deep and 3m wide.
### 62. The hollow has a small, carved seat, shaped like a crescent.
### 63. The seat is carved from the trunk’s inner wood, with a smooth finish.
### 64. The seat is slightly raised, giving it a throne-like feel.
### 65. The hollow is lined with moss and small roots.
### 66. The hollow is partially filled with a small pile of stones.
### 67. The stones are arranged in a spiral pattern, forming a small altar.
### 68. The hollow has a small, carved niche in the back wall.
### 69. The niche holds a small, carved idol of a deer.
### 70. The idol is made from a single piece of wood, polished to a shine.
### 71. The idol is 20cm tall, with a serene expression.
### 72. The hollow is slightly damp, with small droplets of sap on the walls.
### 73. The walls of the hollow are slightly carved, forming a small, natural dome.
### 74. The hollow has a small, carved handle near the back.
### 75. The handle is shaped like a small spiral, possibly used for hanging a lantern.
### 76. The hollow is filled with a soft moss carpet, giving it a cozy feel.
### 77. The hollow has a small, carved shelf, holding a few dried herbs.
### 78. The herbs are a mix of wild thyme, rosemary, and sage.
### 79. The hollow is slightly warm, with a faint smell of sap and earth.
### 80. The hollow is partially lit by a glowing sap from the face’s eyes.
### 81. The hollow has a small, carved symbol on the floor.
### 82. The symbol is a heart with a tree growing from it.
### 83. The hollow is slightly cooler than the surrounding area.
### 84. The hollow has a few small cracks in the wood, filled with moss.
### 85. The hollow has a small, carved door, barely visible.
### 86. The door is carved from a single piece of wood, with a simple latch.
### 87. The door is slightly ajar, showing a small, dark space beyond.
### 88. The door leads to a small, hidden chamber.
### 89. The chamber is filled with a faint, golden mist.
### 90. The chamber has a small, carved altar, lit by glowing sap.

### 91. A small cauldron, carved from a single piece of oak, sits near the base of the tree.
### 92. The cauldron is 30cm tall, with a diameter of 40cm.
### 93. It is filled with a mixture of glowing, golden sap and moss.
### 94. The cauldron has a small, carved lid with a heart-shaped handle.
### 95. The lid is slightly tarnished, but still functional.
### 96. The cauldron is positioned near the root ring, at the edge of the sanctuary.
### 97. A small, carved broom is leaning against the cauldron.
### 98. The broom is made from a mix of birch and oak.
### 99. It is 60cm long, with a long handle and a small, curved head.
### 100. The broom is slightly worn, with moss covering the bristles.
### 101. A small herb bundle, tied with a vine, sits near the base of the tree.
### 102. The bundle contains sage, thyme, and rosemary.
### 103. It is tied with a thin vine, knotted in a simple pattern.
### 104. The bundle is slightly wilted, but still fragrant.
### 105. A small stone circle is placed around the base of the tree.
### 106. The stones are arranged in a perfect circle, 12 stones in total.
### 107. The stones are roughly 10cm tall, with a smooth, polished surface.
### 108. A small idol of a deer, carved from a single piece of wood, sits on a stone slab.
### 109. The idol is 15cm tall, with a serene expression.
### 110. The idol is positioned near the root ring, on a small altar.
### 111. A small lantern, carved from a single piece of oak, hangs from a root.
### 112. The lantern is 20cm tall, with a small, round glass dome.
### 113. The lantern is filled with glowing, golden sap, giving off a soft light.
### 114. A small, carved candlestick holds a single candle, lit with glowing sap.
### 115. The candlestick is 10cm tall, with a carved base and a small, upward-facing flame.
### 116. A small, carved banner, made from birch bark, is hung from a branch.
### 117. The banner is 20cm wide and 40cm tall, with a simple pattern.
### 118. The pattern is a spiral with a heart at the center.
### 119. A small, carved herb jar, made from oak, sits near the base of the tree.
### 120. The jar is 15cm tall, with a small, carved lid and a small handle.

### 121. The ground beneath the tree is a mix of moss and small stones.
### 122. The ground is slightly damp, with a few small puddles of water.
### 123. The ground is covered in a soft, mossy carpet, 5cm thick.
### 124. The ground is slightly uneven, with a few small roots protruding.
### 125. The ground is surrounded by a small circle of low ferns, 2m in diameter.
### 126. The ferns are a mix of oak fern and bracken.
### 127. The ferns are slightly wilted, but still green.
### 128. The ground has a few small, carved stones embedded in it.
### 129. The stones are arranged in a small, circular pattern.
### 130. The ground is slightly cooler than the surrounding area.
### 131. The ground is slightly disturbed, with a few small footprints.
### 132. The ground is slightly soft, with a few small indentations.
### 133. The ground is slightly scuffed, with a few small scratches.
### 134. The ground is slightly uneven, with a few small bumps.
### 135. The ground is slightly mossy, with a few small patches of lichen.
### 136. The ground is slightly cracked, with a few small fissures.
### 137. The ground is slightly muddy, with a few small puddles.
### 138. The ground is slightly rocky, with a few small stones.
### 139. The ground is slightly sandy, with a few small grains of sand.
### 140. The ground is slightly warm, with a faint smell of earth and moss.

### 141. The trunk surface uses uBase 0 with a mix of canopy green and root brown.
### 142. The trunk bark uses uBase 8 with a mix of leaf-light dapple and golden sap glow.
### 143. The face surface uses uBase 10 with a mix of golden sap glow and ash grey.
### 144. The eyes use uBase 11 with a mix of leaf-light dapple and golden sap glow.
### 145. The face’s skin uses uBase 12 with a mix of canopy green and oak bark.
### 146. The root system uses uBase 13 with a mix of root brown and ash grey.
### 147. The moss patches use uBase 14 with a mix of deep moss and leaf-light dapple.
### 148. The base of the trunk uses uBase 20 with a mix of root brown and oak bark.
### 149. The hollow interior uses uBase 21 with a mix of golden sap glow and leaf-light dapple.
### 150. The carved seat uses uBase 0 with a mix of canopy green and leaf-light dapple.
### 151. The altar stones use uBase 8 with a mix of ash grey and root brown.
### 152. The cauldron uses uBase 10 with a mix of golden sap glow and ash grey.
### 153. The broom uses uBase 11 with a mix of canopy green and oak bark.
### 154. The herb bundle uses uBase 12 with a mix of deep moss and canopy green.
### 155. The idol uses uBase 13 with a mix of oak bark and leaf-light dapple.
### 156. The lantern uses uBase 14 with a mix of golden sap glow and ash grey.
### 157. The candlestick uses uBase 20 with a mix of golden sap glow and canopy green.
### 158. The banner uses uBase 21 with a mix of leaf-light dapple and ash grey.
### 159. The herb jar uses uBase 0 with a mix of deep moss and oak bark.
### 160. The stone circle uses uBase 8 with a mix of ash grey and root brown.

### 161. The tree’s eyes glow with a soft, pulsing light, synchronized with the heartbeat of the forest.
### 162. The glow is strongest at night, with a subtle flicker.
### 163. The glow is dimmed during daylight, but still visible.
### 164. The glow has a slight blue hue, indicating a mystical energy.
### 165. The glow is strongest at the base of the trunk, where the face is carved.
### 166. The glow has a slight red tinge at the edges, suggesting warmth.
### 167. The glow is slightly uneven, creating a subtle pattern.
### 168. The glow is visible from a distance of 100m.
### 169. The glow has a soft, ambient quality, like a fire in the distance.
### 170. The glow is slightly pulsing, with a 3-second cycle.
### 171. The glow is visible through the canopy, creating a soft spotlight.
### 172. The glow is slightly brighter when the player approaches.
### 173. The glow is slightly dimmer during storms.
### 174. The glow is slightly more intense during dawn and dusk.
### 175. The glow is visible from all sides, creating a soft, ambient light.
### 176. The glow is slightly brighter when the player stands directly beneath the face.
### 177. The glow is slightly dimmer when the player is inside the hollow.
### 178. The glow is slightly brighter when the player approaches the root ring.
### 179. The glow is slightly more intense during full moon nights.
### 180. The glow is slightly softer than a typical fire, with a natural warmth.

### 181. A small firefly mote, `fireflies`, floats near the tree’s eyes, pulsing gently.
### 182. The mote is 5cm in diameter, with a soft, golden glow.
### 183. The mote floats in a slow, circular motion around the face.
### 184. The mote is slightly larger during nightfall, with a brighter glow.
### 185. The mote pulses with a 2-second cycle, matching the heartbeat of the tree.
### 186. The mote is slightly smaller during daylight, with a fainter glow.
### 187. The mote is slightly more intense when the player is near the base.
### 188. The mote is slightly dimmer when inside the hollow.
### 189. The mote is slightly brighter during full moon nights.
### 190. The mote is slightly less frequent during storms.
### 191. A small `cauldron_bubble` particle rises from the cauldron, gently floating upward.
### 192. The bubble is 10cm in diameter, with a soft, golden glow.
### 193. The bubble floats slowly, rising from the surface of the cauldron.
### 194. The bubble pulses with a 3-second cycle, matching the heartbeat of the tree.
### 195. The bubble is slightly larger when the player is near the base.

### 196. The total tri-budget is 4500 tris, with 2500 tris for the trunk and canopy.
### 197. The remaining 2000 tris are allocated to the root system, face, and hollow interior.
### 198. The mesh builder strategy uses `makeHeartTree(device:)` in `ios/Mesh.swift`.
### 199. The mesh is subdivided into 3 parts: trunk, canopy, and root system.
### 200. No LOD is implemented, as the forest currently does not support LOD.
```
---

## Asset 144 — forgotten_tomb (Hero Landmark, forest)
### A. Concept & Silhouette (features 1–10)
### 1. The forgotten_tomb is a moss-covered crypt sunk into a hillside, with a weathered entrance flanked by two carved stone warrior statues holding broken spears.
### 2. From 80m away, it appears as a low, angular silhouette with a dark entrance and two tall, weathered statues on either side.
### 3. From 30m, the entrance is visible as a cracked, moss-draped door with a faint candle glow through the cracks.
### 4. From 10m, the entrance is clearly a stone archway with broken spears, and the surrounding hillside is partially covered in moss and dead trees.
### 5. The landmark is designed to be discovered by players who have ventured into a hidden hollow at (-90, 0, -190) in the forest zone.
### 6. The mood is one of ancient mystery and decay, with a faint candlelight suggesting a presence or recent activity.
### 7. The tomb's appearance changes with time-of-day, with shadows deepening at dusk and candlelight becoming more prominent at night.
### 8. Visibility from the origin point is limited by a screen of dead trees (mesh 20) that must be passed through to see the tomb.
### 9. The scale anchor is a 4m-high entrance, with the statues standing at 5m tall.
### 10. The tomb should not be confused with a regular ruin or a simple tree hollow — it’s a significant landmark with lore.

### B. Form & Major Mass (features 11–30)
### 11. The main structure is a roughly rectangular stone crypt, embedded into a hillside at a 10-degree angle.
### 12. The crypt's entrance is 3m wide and 4m high, with a curved top arch and cracked stone blocks.
### 13. The entrance is flanked by two warrior statues, each 5m tall, carved from a single block of stone.
### 14. The statues lean slightly outward, with their arms extended but broken at the elbows, and their spears shattered.
### 15. The front of the structure is partially covered with moss and lichen, creating a weathered, ancient appearance.
### 16. The side facing the player is slightly asymmetrical, with one statue being more weathered than the other.
### 17. The entrance is surrounded by a small platform, 1m in height, that slopes slightly toward the hillside.
### 18. The hillside has a gradual incline, with a 3m rise from the entrance to the back of the crypt.
### 19. A small drainage channel runs along the base of the entrance, carved into the hillside.
### 20. The front of the crypt is partially hollowed out, forming a recessed area where the statues stand.
### 21. The statue bases are 1.5m tall, each carved with a unique pattern of ancient runes.
### 22. The back of the crypt is solid, with a flat stone wall that blends into the hillside.
### 23. The entrance arch is supported by two stone columns, 1.2m in diameter, that taper slightly inward.
### 24. The overall volume of the structure is 30m³, with a surface area of 100m².
### 25. The entrance is slightly offset from the center of the structure, creating an unbalanced silhouette.
### 26. The hillside slope is consistent, with a 12-degree incline from the entrance to the back.
### 27. The statues have no visible feet, but are embedded in the base of the entrance.
### 28. The structure has a slight lean to the right, as if it's settling into the hillside.
### 29. The entrance is partially blocked by a moss-covered stone slab, which has cracked and fallen slightly.
### 30. The structure is built from multiple stone blocks, some of which are clearly from different ages.

### C. Exterior Surface Detail (features 31–60)
### 31. The entrance arch is carved with a series of spiral motifs that fade into the stone.
### 32. Moss grows in thick patches on the entrance slab, covering 70% of its surface.
### 33. The left statue’s chest has a large crack running from top to bottom, revealing dark stone underneath.
### 34. The right statue’s arm is broken at the elbow, with a small chipped piece of stone missing.
### 35. The base of the entrance is covered in lichen, creating a dark green pattern.
### 36. A small vine has grown over the entrance, curling around the arch.
### 37. The statue’s eyes are carved as deep, black holes with no visible pupils.
### 38. The statue’s face is weathered, with features barely recognizable.
### 39. The door is cracked along its center, with a 20cm gap where a candle flame shines.
### 40. The door is painted with a rust-colored stain, fading into a dark brown.
### 41. A small glyph is carved into the stone next to the entrance, resembling an ancient symbol.
### 42. The hillside behind the entrance is dotted with moss and small cracks.
### 43. The surface of the entrance slab is rough, with sharp stones protruding in places.
### 44. The statue’s spear shaft is carved with a pattern of small circles.
### 45. A small spider’s web is visible on the statue’s shoulder, with dew drops on the strands.
### 46. The statue’s left hand is missing a small finger, leaving a jagged hole.
### 47. The statue’s helmet is cracked, with a small piece missing from the top.
### 48. A thin layer of moss covers the statue’s feet, making them almost invisible.
### 49. The entrance door is slightly warped, with a 1cm gap on the right side.
### 50. The surface of the entrance is covered with a thin layer of water that reflects the surrounding environment.
### 51. The top of the arch is carved with a small, intricate pattern of vines and leaves.
### 52. A small crack runs down the left side of the entrance, barely visible.
### 53. The entrance is surrounded by a small pool of water that reflects the sky.
### 54. A piece of old metal is embedded in the wall near the entrance, rusted and corroded.
### 55. The statue’s back is smooth, with no visible carvings.
### 56. The statue’s hands are clenched in a fist, with no visible detail.
### 57. A small chipped piece of stone is visible on the entrance slab, about 2cm in size.
### 58. The surface of the entrance is slightly uneven, with a 0.5cm height difference.
### 59. The hillside is partially covered with dead grass, giving a dry, withered look.
### 60. The entrance slab is covered with a thin layer of moss, which glows faintly in low light.

### D. Internal / Sub-Volume Detail (features 61–90)
### 61. The entrance interior is a narrow passage, 2m wide, that leads into the crypt.
### 62. The floor of the passage is uneven, with a 10cm rise in the center.
### 63. The passage walls are lined with ancient runes, carved into the stone.
### 64. A small crack in the ceiling lets in a faint beam of sunlight.
### 65. The passage is 2.5m long and 1.5m high, with a 30cm wide gap between the walls.
### 66. The floor is covered with a thin layer of moss, which gives a dark green hue.
### 67. A small niche is carved into the left wall, containing a broken candle holder.
### 68. The passage has a slight downward slope, leading to the interior of the crypt.
### 69. The walls are slightly concave, giving the passage a tunnel-like feel.
### 70. The ceiling is 1.2m high, with a small drip of water visible near the center.
### 71. A small shelf is carved into the right wall, with a few broken pottery shards.
### 72. The passage ends in a 90-degree turn to the left, leading to a wider chamber.
### 73. The turn is lined with moss and small cracks, giving a sense of decay.
### 74. A small pool of water is visible in the floor near the turn.
### 75. The chamber beyond the turn is 4m by 3m, with a 2m ceiling.
### 76. The chamber has a small stone table in the center, with a cracked stone lid.
### 77. The chamber walls are lined with ancient paintings, now faded and cracked.
### 78. A small hole in the wall allows a faint light to enter from the outside.
### 79. The chamber floor is covered with a thin layer of dust and old leaves.
### 80. The chamber has a small niche on the left wall, with a broken statue’s head.
### 81. The chamber is partially lit by a candle that flickers in the entrance.
### 82. A small stone seat is carved into the right wall, with no visible backrest.
### 83. A small crack in the ceiling allows a thin stream of water to drip.
### 84. The chamber has a slight upward slope, making it feel like a natural cave.
### 85. A small stone door is visible in the back wall, slightly ajar.
### 86. The chamber is filled with a faint, musty smell.
### 87. The chamber has a small, broken mirror on the left wall.
### 88. A small stone bench is carved into the floor, slightly raised.
### 89. The chamber is partially filled with a thin layer of fog.
### 90. A small crack in the wall shows a faint glow, as if from a fire inside.

### E. Decoration & Props (features 91–120)
### 91. A small candle is placed in a broken holder on the left wall of the passage.
### 92. A small stone jar is placed on the right wall of the chamber, cracked and empty.
### 93. A small skull is placed on the stone table in the chamber, with a blackened eye socket.
### 94. A broken spear is leaning against the wall near the entrance, with a rusted tip.
### 95. A small bone pile is visible in the corner of the chamber, with a few bones missing.
### 96. A small idol is placed on the stone table, with a cracked face and glowing eyes.
### 97. A small herb bundle is tied with a vine and placed on the table.
### 98. A small banner is attached to the right wall, torn and faded.
### 99. A small book is placed on the stone table, with a cracked leather cover.
### 100. A small cauldron is placed in the chamber, filled with old, dark water.
### 101. A small broom is leaning against the wall near the entrance.
### 102. A small bell is placed on the table, with a rusted clapper inside.
### 103. A small torch holder is embedded in the wall, with no torch.
### 104. A small vase is placed on the stone table, with a broken stem.
### 105. A small mirror is placed on the wall, with a cracked surface.
### 106. A small piece of parchment is placed on the table, with no readable text.
### 107. A small crystal is placed on the table, with a faint glow.
### 108. A small key is placed in a niche, with a rusted surface.
### 109. A small lantern is placed on the table, with a cracked glass dome.
### 110. A small stone tablet is placed on the wall, with ancient runes.
### 111. A small sword is placed on the table, with a broken hilt.
### 112. A small shield is placed on the wall, with a cracked surface.
### 113. A small helmet is placed on the table, with a missing visor.
### 114. A small scroll is placed on the table, with a torn edge.
### 115. A small bone is placed on the table, with a glowing mark.
### 116. A small skull is placed in a niche, with a glowing eye.
### 117. A small stone statue is placed in the chamber, with a cracked face.
### 118. A small stone bowl is placed on the table, with a cracked edge.
### 119. A small stone plate is placed on the table, with a broken handle.
### 120. A small stone cup is placed on the table, with a cracked rim.

### F. Surrounding Environment (features 121–140)
### 121. The ground around the tomb is covered in moss and dead grass.
### 122. A small path leads from the entrance to the front of the tomb.
### 123. The ground is slightly sloped, with a 5-degree incline toward the entrance.
### 124. A few small rocks are scattered around the entrance, some moss-covered.
### 125. The surrounding area is mostly dead trees, with no undergrowth.
### 126. A small stream of water flows near the entrance, with a thin layer of moss on its banks.
### 127. A few fallen logs are scattered around the base of the tomb.
### 128. A small pile of bones is visible near the entrance.
### 129. A few dead birds are scattered around the base of the tomb.
### 130. The area is covered in a thin layer of fog, especially at dawn.
### 131. A small pile of leaves is visible near the entrance.
### 132. A few small spider webs are visible on the ground.
### 133. A small crack in the ground allows a thin stream of water to drip.
### 134. The ground is slightly soft, with a thin layer of moss and mud.
### 135. A small pool of water is visible near the entrance.
### 136. A few small mushrooms grow around the base of the tomb.
### 137. The ground is slightly uneven, with a few small holes.
### 138. A few small insects are visible on the ground.
### 139. The area is covered in a thin layer of dust.
### 140. The ground is slightly wet, with a thin layer of moss and mud.

### G. Materials & Shaders (features 141–160)
### 141. The entrance slab uses uBase 0, with a shader that blends stone and moss using `mix(stoneColor, mossColor, fbm(float3(0.1, 0.2, 0.3)))`.
### 142. The left statue uses uBase 8, with a shader that blends ancient bronze with rust using `mix(bronze, rust, sin(time) * 0.5 + 0.5)`.
### 143. The right statue uses uBase 10, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.05, 0.1, 0.15)))`.
### 144. The entrance arch uses uBase 14, with a shader that blends ancient stone with moss using `mix(stone, moss, sin(time * 0.5) * 0.3 + 0.7)`.
### 145. The hillside uses uBase 20, with a shader that blends earth with moss using `mix(earth, moss, fbm(float3(0.2, 0.3, 0.4)))`.
### 146. The statue bases use uBase 21, with a shader that blends stone with runes using `mix(stone, runes, sin(time * 0.3) * 0.4 + 0.6)`.
### 147. The door uses uBase 0, with a shader that blends wood with moss using `mix(wood, moss, fbm(float3(0.1, 0.1, 0.2)))`.
### 148. The entrance floor uses uBase 8, with a shader that blends stone with water using `mix(stone, water, sin(time * 0.2) * 0.3 + 0.7)`.
### 149. The passage walls use uBase 10, with a shader that blends stone with runes using `mix(stone, runes, fbm(float3(0.05, 0.1, 0.15)))`.
### 150. The chamber walls use uBase 14, with a shader that blends stone with moss using `mix(stone, moss, sin(time * 0.4) * 0.3 + 0.7)`.
### 151. The chamber floor uses uBase 20, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.1, 0.2, 0.3)))`.
### 152. The statue arms use uBase 21, with a shader that blends bronze with rust using `mix(bronze, rust, sin(time * 0.6) * 0.4 + 0.6)`.
### 153. The statue helmets use uBase 0, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.05, 0.1, 0.15)))`.
### 154. The entrance ceiling uses uBase 8, with a shader that blends stone with moss using `mix(stone, moss, sin(time * 0.5) * 0.3 + 0.7)`.
### 155. The chamber ceiling uses uBase 10, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.1, 0.2, 0.3)))`.
### 156. The passage ceiling uses uBase 14, with a shader that blends stone with moss using `mix(stone, moss, sin(time * 0.3) * 0.3 + 0.7)`.
### 157. The entrance slab uses uBase 20, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.05, 0.1, 0.15)))`.
### 158. The hillside base uses uBase 21, with a shader that blends earth with moss using `mix(earth, moss, sin(time * 0.4) * 0.3 + 0.7)`.
### 159. The statue feet use uBase 0, with a shader that blends stone with moss using `mix(stone, moss, fbm(float3(0.1, 0.2, 0.3)))`.
### 160. The entrance platform uses uBase 8, with a shader that blends stone with moss using `mix(stone, moss, sin(time * 0.5) * 0.3 + 0.7)`.

### H. Lighting & Atmosphere (features 161–180)
### 161. The entrance emits a soft candle glow that penetrates the cracks in the door.
### 162. The interior of the passage is dimly lit, with a faint flicker of candlelight.
### 163. The chamber is lit by a flickering candle, casting dancing shadows on the walls.
### 164. A faint glow from a crack in the wall gives a sense of a fire inside.
### 165. The light from the entrance is filtered through the moss, creating a greenish hue.
### 166. The atmosphere is thick with fog, especially at dawn and dusk.
### 167. The interior of the crypt is slightly darker than the outside, with a subtle glow.
### 168. A small light source inside the chamber creates a warm, amber glow.
### 169. The light from the candle is reflected off the moss, creating a soft, warm glow.
### 170. The entrance is partially shadowed, with a slight glow from the inside.
### 171. A small beam of sunlight filters through a crack in the ceiling.
### 172. The chamber is slightly illuminated by a faint glow from the walls.
### 173. The light from the entrance is slightly distorted by the moss and cracks.
### 174. A small stream of water inside the chamber reflects the candlelight.
### 175. The atmosphere is filled with a faint mist, creating a sense of mystery.
### 176. A soft glow from the candle reflects off the stone, casting subtle shadows.
### 177. The light inside the chamber is slightly cooler than the outside.
### 178. A faint glow from a crack in the wall creates a sense of warmth.
### 179. The light from the entrance is slightly dimmed by the moss and cracks.
### 180. The atmosphere is thick with a soft, greenish mist, enhancing the ancient feel.

### I. Animation, FX, and Sound Design (features 181–195)
### 181. A candle flickers inside the entrance, emitting a soft, warm glow.
### 182. A small pool of water in the passage drips slowly, creating a soft drip sound.
### 183. A faint light from the chamber flickers, as if from a fire inside.
### 184. A soft breeze causes the moss to sway slightly, creating a gentle rustling sound.
### 185. A small stream of water drips from the ceiling, creating a soft splash.
### 186. A faint crackling sound comes from the candle, as if it's burning low.
### 187. A soft wind causes the vines to sway slightly, creating a gentle rustling.
### 188. A distant howl echoes from the forest, adding to the atmosphere.
### 189. A soft drip sound comes from a crack in the wall, creating a subtle ambiance.
### 190. A faint glow from the candle flickers in the wind, creating a soft shadow play.
### 191. A small stream of water flows through a crack in the ground, creating a soft gurgle.
### 192. A soft crackling sound comes from the candle, as if it's burning low.
### 193. A gentle breeze causes the moss to sway slightly, creating a subtle rustling sound.
### 194. A faint light flickers from the crack in the wall, as if from a fire.
### 195. A soft drip sound comes from the entrance, creating a subtle ambient noise.

### J. Implementation & Engine Hooks (features 196–200)
### 196. Tri-budget breakdown: entrance 1000 tris, statues 1000 tris, chamber 800 tris, passage 200 tris.
### 197. Mesh builder strategy: `makeForgottenTomb(device:)` using `mbCylinder` for the door, `mbSphere` for the entrance arch, `mbRing` for the base.
### 198. Draw-call decomposition: single mesh with instanced statue rendering using `drawIndexedInstanced`.
### 199. Required additions to `world.team` switch: add `case 80: return "forgotten_tomb"`.
### 200. LOD strategy: no LOD currently in forest zone; future implementation may use a single mesh with dynamic draw calls.
---


# Desert Zone Hero Landmarks

The Sunburnt Wastes (450 m radius, 360 m path) get three hero landmarks marking different beats of the player's traverse. See `desert_zone.md` for the foundation.

---

## Asset 145 — sand_galleon (Hero Landmark, desert)
### A. Concept & Silhouette (features 1–10)
### 1. The sand_galleon is a half-buried wooden hulk, standing in the desert as a haunting monument to an ancient maritime catastrophe, its three masts like skeletal arms reaching skyward.
### 2. Silhouette is clearly visible from 80m, with a dominant horizontal profile that tapers slightly upward from the keel to the broken mast tops, forming a dramatic, weathered arc.
### 3. From 30m, the silhouette shows the galleon’s hull as a low, flat ridge with a pronounced keel, interrupted by the broken masts and a partially intact crow's nest.
### 4. At 10m, the silhouette reveals the full asymmetry of the hull, with the bow partially buried and the stern showing a sharp, weathered edge.
### 5. The galleon's lore hook is tied to a shipwreck that once carried treasure from a lost island, now only remembered by fossilized shells surrounding the site.
### 6. The mood is one of forgotten grandeur, a tragic relic of a lost civilization, evoking themes of time, loss, and the sea's power.
### 7. Appearance changes subtly with time-of-day: during sunrise, the sand is bathed in gold, casting long shadows; at sunset, the hull glows amber with ember tones.
### 8. Visibility from the player origin (60, 0, -180) is strong due to the open dune field, with no obstructions between the player and the asset.
### 9. The asset acts as a scale anchor, standing 18 feet tall at its highest point, with the hull at about 2.5 feet above the dune surface.
### 10. The galleon is not confused with any other asset — it's a unique, singular shipwreck in a desert setting, with no other structures nearby to resemble it.

### B. Form & Major Mass (features 11–30)
### 11. The main hull is an extruded, curved, wooden plank structure, 60 feet in length, 12 feet in width, and 4 feet in height at its center.
### 12. The hull is slightly tilted forward, leaning at a 12-degree angle toward the east, as if it crashed into the sand.
### 13. The hull is asymmetrical, with the stern higher than the bow due to sand burial and structural collapse.
### 14. A central hollow runs the length of the hull, 3 feet wide and 2 feet deep, visible through cracks and sand.
### 15. The bow is half-buried, with only the tip protruding from the sand, showing the remains of a carved wooden prow.
### 16. The stern is more intact, with a broken ladder leading up to a partially intact crow's nest, 8 feet above the deck.
### 17. The three masts are positioned unevenly: the main mast is centered, the foremast is to the left, and the mizzen mast is to the right.
### 18. The main mast is 30 feet tall, with a 3-foot diameter at its base, tapering to 0.5 feet at the top.
### 19. The foremast is 25 feet tall, with a 2.5-foot diameter, leaning at 10 degrees toward the bow.
### 20. The mizzen mast is 20 feet tall, 2-foot diameter, and stands upright, though it’s partially cracked.
### 21. A rope rigging system is partially visible, connecting the masts to a deck beam, with 20 lines of varying thickness.
### 22. The hull contains a large cargo hold, accessible through a broken section of the bow, with a 4-foot-wide opening.
### 23. A small cabin is partially embedded in the hull’s side, with a door that is half-buried in sand.
### 24. The deck planks are irregular in size, with some broken, warped, and weathered, creating a natural, uneven surface.
### 25. A large anchor is embedded in the sand near the bow, 3 feet in diameter, rusted and cracked.
### 26. A weathered wooden wheel is partially visible on the deck, 2 feet in diameter, with a cracked spoke.
### 27. A broken chain link hangs from the main mast, 10 feet in length, attached to a rusted hook.
### 28. The hull’s outer surface is not smooth — it's pitted, cracked, and scarred by sand and wind erosion.
### 29. A large section of the hull is missing, revealing the internal structure of the wooden frame.
### 30. The asset’s dominant axis runs from the bow to the stern, with a slight horizontal lean to the right.

### C. Exterior Surface Detail (features 31–60)
### 31. The bow plank is 6 feet long, 1 foot wide, and 0.5 feet thick, with a carved dragon’s head at the tip.
### 32. The main deck planks are 3 feet long, 0.5 feet wide, and 0.2 feet thick, with a weathered gold stripe painted along the edge.
### 33. A small hole in the hull’s side, 3 inches in diameter, is filled with sand and shows signs of a previous nail.
### 34. A weathered ship’s bell is mounted on the main mast, 1 foot in diameter, rusted and cracked.
### 35. The hull’s side has a 2-foot wide patch of sand that has been blown away, revealing the inner wood.
### 36. A rope ladder is partially embedded in the hull, with 12 rungs, each 1 foot long and 1.5 inches thick.
### 37. A broken ship’s wheel is partially exposed, 2 feet in diameter, with a cracked spoke and a missing hub.
### 38. The hull’s bow is decorated with a carved wooden figure, 2 feet tall, with a cracked face and missing eyes.
### 39. A section of the deck has a small patch of pale sand, likely due to a recent wind gust.
### 40. A rusted iron hook, 6 inches long, is embedded in the main mast.
### 41. The hull has a large crack running from the bow to the mid-section, 1 foot wide.
### 42. A section of the deck is covered in pale sand, 2 feet wide, with a smooth, wind-polished texture.
### 43. A wooden plank is broken in half, with a jagged edge, 3 feet long and 1 foot wide.
### 44. A rope is wrapped around a broken mast, 3 feet long, with a knotted end.
### 45. The hull is painted in a faded blue, with a gold trim, now mostly worn off.
### 46. A piece of driftwood, 1 foot long, is embedded in the sand near the bow.
### 47. A small metal plate is embedded in the hull, 3 inches by 3 inches, with a faded inscription.
### 48. The hull’s side is scarred with a deep gouge, 4 feet long and 2 inches wide.
### 49. A small wooden chest is half-buried in the sand, 1 foot in width, with a cracked lid.
### 50. A broken ship’s compass is embedded in the deck, 2 inches in diameter, rusted and cracked.
### 51. A section of the hull is covered in pale sand, 2 feet wide, with a smooth, wind-polished texture.
### 52. A wooden beam is exposed in the hull, 2 feet long, with a rough, knotted surface.
### 53. A section of the deck is cracked, revealing a dark, weathered wood underneath.
### 54. A rope is partially embedded in the deck, 1 foot long, with a frayed end.
### 55. A small section of the hull is painted in a bright red, likely from a spilled paint bucket.
### 56. A large sand drift covers the stern, 4 feet in width, and 2 feet in depth.
### 57. A section of the deck has a small patch of sand, 1 foot wide, with a smooth, wind-polished texture.
### 58. A broken ship’s flag is mounted on the main mast, 3 feet long, with a faded red and gold design.
### 59. The hull has a large section of rusted metal, 2 feet wide, embedded in the wood.
### 60. A small wooden bird is mounted on the main mast, 6 inches tall, with a cracked wing.

### D. Internal / Sub-Volume Detail (features 61–90)
### 61. The cargo hold is 10 feet wide, 12 feet long, and 6 feet high, filled with sand and broken wooden crates.
### 62. The hold has a wooden beam, 2 feet in diameter, running the length of the space.
### 63. A broken crate, 2 feet wide, 2 feet long, and 1 foot tall, lies on its side in the hold.
### 64. A small section of the hold is filled with broken glass, 3 feet wide, and 2 feet deep.
### 65. A wooden box, 1 foot wide, 1 foot long, and 1 foot tall, is buried in sand in the hold.
### 66. A section of the hold has a large crack in the floor, revealing a dark, wooden beam underneath.
### 67. The hold is partially filled with a small pile of bones, 3 feet wide, 2 feet long.
### 68. A broken anchor chain, 3 feet long, is embedded in the floor of the hold.
### 69. A section of the hold has a wooden floor, 2 feet wide, 3 feet long, and 1 foot deep.
### 70. A large sand drift covers the hold’s back wall, 4 feet in width, 3 feet in depth.
### 71. A small wooden chest, 1 foot wide, 1 foot long, and 1 foot tall, is half-buried in the hold.
### 72. A section of the hold is filled with broken pottery, 2 feet wide, 1 foot deep.
### 73. A large piece of driftwood, 3 feet long, is embedded in the hold’s floor.
### 74. A section of the hold is filled with a small pile of sand, 2 feet wide, 1 foot deep.
### 75. A broken ship’s wheel is embedded in the hold’s floor, 2 feet in diameter.
### 76. A small section of the hold has a wooden beam, 2 feet wide, 1 foot deep.
### 77. A broken ship’s compass is embedded in the hold’s floor, 2 inches in diameter.
### 78. A section of the hold is filled with a small pile of bones, 2 feet wide, 1 foot deep.
### 79. A broken anchor is embedded in the hold, 3 feet in diameter.
### 80. A section of the hold has a wooden floor, 2 feet wide, 3 feet long.
### 81. A small wooden bird is embedded in the hold’s floor, 6 inches tall.
### 82. A section of the hold is filled with a small pile of sand, 1 foot wide, 1 foot deep.
### 83. A broken ship’s bell is embedded in the hold, 1 foot in diameter.
### 84. A section of the hold is filled with broken glass, 2 feet wide, 1 foot deep.
### 85. A section of the hold has a wooden beam, 2 feet wide, 1 foot deep.
### 86. A broken crate, 2 feet wide, 1 foot long, and 1 foot tall, lies on its side in the hold.
### 87. A small wooden box, 1 foot wide, 1 foot long, and 1 foot tall, is buried in sand in the hold.
### 88. A broken anchor chain, 3 feet long, is embedded in the floor of the hold.
### 89. A section of the hold is filled with a small pile of bones, 2 feet wide, 1 foot deep.
### 90. A large sand drift covers the hold’s back wall, 4 feet in width, 3 feet in depth.

### E. Decoration & Props (features 91–120)
### 91. A small wooden chest, 1 foot wide, 1 foot long, and 1 foot tall, is half-buried in the sand near the bow.
### 92. A broken ship’s wheel, 2 feet in diameter, is partially exposed on the deck.
### 93. A section of the deck has a small patch of sand, 1 foot wide, with a smooth, wind-polished texture.
### 94. A broken anchor chain, 3 feet long, is embedded in the deck.
### 95. A wooden bird, 6 inches tall, is mounted on the main mast.
### 96. A broken ship’s compass, 2 inches in diameter, is embedded in the deck.
### 97. A section of the hull is painted in a bright red, likely from a spilled paint bucket.
### 98. A small wooden box, 1 foot wide, 1 foot long, and 1 foot tall, is buried in sand in the hold.
### 99. A broken ship’s bell, 1 foot in diameter, is mounted on the main mast.
### 100. A small section of the deck has a wooden beam, 2 feet wide, 1 foot deep.
### 101. A broken crate, 2 feet wide, 2 feet long, and 1 foot tall, lies on its side in the hold.
### 102. A section of the hold is filled with a small pile of bones, 2 feet wide, 1 foot deep.
### 103. A large sand drift covers the stern, 4 feet in width, and 2 feet in depth.
### 104. A small wooden chest, 1 foot wide, 1 foot long, and 1 foot tall, is buried in sand in the hold.
### 105. A broken anchor chain, 3 feet long, is embedded in the floor of the hold.
### 106. A small wooden bird is embedded in the hold’s floor, 6 inches tall.
### 107. A broken ship’s compass is embedded in the hold’s floor, 2 inches in diameter.
### 108. A section of the hold is filled with broken glass, 2 feet wide, 1 foot deep.
### 109. A broken ship’s bell is embedded in the hold, 1 foot in diameter.
### 110. A broken anchor is embedded in the hold, 3 feet in diameter.
### 111. A small wooden box, 1 foot wide, 1 foot long, and 1 foot tall, is half-buried in the sand.
### 112. A section of the deck is cracked, revealing a dark, weathered wood underneath.
### 113. A broken rope is partially embedded in the deck, 1 foot long, with a frayed end.
### 114. A broken ship’s wheel is embedded in the hold’s floor, 2 feet in diameter.
### 115. A small wooden chest, 1 foot wide, 1 foot long, and 1 foot tall, is buried in sand in the hold.
### 116. A large piece of driftwood, 3 feet long, is embedded in the hold’s floor.
### 117. A broken ship’s flag is mounted on the main mast, 3 feet long, with a faded red and gold design.
### 118. A section of the hold is filled with broken pottery, 2 feet wide, 1 foot deep.
### 119. A broken anchor chain, 3 feet long, is embedded in the floor of the hold.
### 120. A small wooden chest, 1 foot wide, 1 foot long, and 1 foot tall, is half-buried in the sand.

### F. Surrounding Environment (features 121–140)
### 121. The ground texture is a mix of sand and fine gravel, with a 10-foot radius of exposed sand.
### 122. A ring of fossil_shell (mesh 46) surrounds the galleon, 30 feet in diameter, with 12 shells arranged in a circle.
### 123. The dune field is flat, with no significant elevation changes within 15 meters.
### 124. A small pile of sand, 2 feet in diameter, is visible near the bow.
### 125. A section of the sand is wind-polished, 3 feet wide, with a smooth, reflective surface.
### 126. A small drift of sand, 2 feet wide, is visible near the stern.
### 127. A section of the sand is covered in a small patch of pale sand, 1 foot wide.
### 128. A broken piece of driftwood, 1 foot long, is embedded in the sand near the bow.
### 129. A section of the sand is covered in a small patch of sand, 1 foot wide, with a smooth, wind-polished texture.
### 130. A small section of the sand is cracked, revealing a dark, weathered surface underneath.
### 131. A small pile of bones, 2 feet wide, is visible near the stern.
### 132. A section of the sand is covered in a small patch of sand, 1 foot wide, with a smooth, wind-polished texture.
### 133. A broken ship’s compass, 2 inches in diameter, is embedded in the sand near the bow.
### 134. A small section of the sand is cracked, revealing a dark, weathered surface underneath.
### 135. A broken ship’s bell, 1 foot in diameter, is embedded in the sand near the stern.
### 136. A small drift of sand, 2 feet wide, is visible near the bow.
### 137. A section of the sand is covered in a small patch of sand, 1 foot wide, with a smooth, wind-polished texture.
### 138. A small pile of sand, 2 feet in diameter, is visible near the stern.
### 139. A broken ship’s wheel, 2 feet in diameter, is partially exposed in the sand.
### 140. A small drift of sand, 2 feet wide, is visible near the bow.

### G. Materials & Shaders (features 141–160)
### 141. Hull surface (uBase 0) — `mix(sand_light, sand_dark, fbm(float3(0.1,0.2,0.3)))`.
### 142. Mast surface (uBase 8) — `mix(dune_shadow, rock_warm, sin(float3(0.5,0.6,0.7)))`.
### 143. Deck planks (uBase 30) — `mix(bone_pale, driftwood_grey, fbm(float3(0.3,0.4,0.5)))`.
### 144. Broken plank (uBase 31) — `mix(sand_light, sand_dark, sin(float3(0.2,0.3,0.4)))`.
### 145. Crow’s nest (uBase 32) — `mix(ember_orange, accent_gold, fbm(float3(0.4,0.5,0.6)))`.
### 146. Anchor (uBase 36) — `mix(rock_warm, bone_pale, sin(float3(0.6,0.7,0.8)))`.
### 147. Wheel (uBase 37) — `mix(driftwood_grey, sand_light, fbm(float3(0.1,0.2,0.3)))`.
### 148. Bow carving (uBase 40) — `mix(ember_orange, accent_gold, sin(float3(0.5,0.6,0.7)))`.
### 149. Cargo hold (uBase 0) — `mix(sand_dark, dune_shadow, fbm(float3(0.2,0.3,0.4)))`.
### 150. Rope (uBase 8) — `mix(rock_warm, bone_pale, sin(float3(0.3,0.4,0.5)))`.
### 151. Broken mast (uBase 30) — `mix(sand_light, sand_dark, fbm(float3(0.1,0.2,0.3)))`.
### 152. Hull cracks (uBase 31) — `mix(dune_shadow, sand_dark, sin(float3(0.4,0.5,0.6)))`.
### 153. Deck beam (uBase 32) — `mix(driftwood_grey, sand_light, fbm(float3(0.2,0.3,0.4)))`.
### 154. Hull planks (uBase 36) — `mix(sand_light, sand_dark, sin(float3(0.5,0.6,0.7)))`.
### 155. Masts (uBase 37) — `mix(dune_shadow, rock_warm, fbm(float3(0.1,0.2,0.3)))`.
### 156. Sand drifts (uBase 40) — `mix(sand_light, sand_dark, sin(float3(0.3,0.4,0.5)))`.
### 157. Cargo hold floor (uBase 0) — `mix(dune_shadow, sand_dark, fbm(float3(0.2,0.3,0.4)))`.
### 158. Sand patches (uBase 8) — `mix(sand_light, sand_dark, sin(float3(0.6,0.7,0.8)))`.
### 159. Rope rigging (uBase 30) — `mix(bone_pale, driftwood_grey, fbm(float3(0.1,0.2,0.3)))`.
### 160. Hull surface (uBase 31) — `mix(sand_dark, dune_shadow, sin(float3(0.4,0.5,0.6)))`.

### H. Lighting & Atmosphere (features 161–180)
### 161. During sunrise, the hull glows in a golden hue, casting long shadows toward the dunes.
### 162. At sunset, the hull is bathed in amber light, with the sand glowing with ember tones.
### 163. A faint haze of sand particles lingers in the air, especially during midday.
### 164. The sun creates a sharp contrast between the hull and the sand, with a strong, direct light.
### 165. A faint shimmer in the air gives the scene a heat-wave effect in the afternoon.
### 166. The asset casts a large shadow, 20 feet long, on the sand.
### 167. The hull glows faintly in the evening, due to a subtle ambient light source.
### 168. A few fireflies hover near the galleon, creating a magical, ethereal effect.
### 169. The scene is illuminated by a bright sun, with no clouds in the sky.
### 170. The asset is bathed in a soft, warm light at dawn, with a slight blue tint.
### 171. A subtle wind gust causes sand to swirl around the galleon.
### 172. The sand around the galleon is slightly glowing in the evening, due to ambient light.
### 173. A soft fog rolls in from the east, partially obscuring the galleon.
### 174. A distant storm is visible on the horizon, casting dark clouds over the dunes.
### 175. The scene is illuminated by a dim, ambient light, giving the galleon a mysterious tone.
### 176. A gentle breeze causes the broken flag to flap slightly in the wind.
### 177. The galleon is surrounded by a faint ring of light, as if lit by a lantern.
### 178. A small fire burns in the cargo hold, casting flickering shadows.
### 179. The scene is filled with a soft, ambient wind sound.
### 180. A subtle glow radiates from the broken mast, as if a ghostly light lingers.

### I. Animation, FX, and Sound Design (features 181–195)
### 181. A gentle breeze causes the broken mast to sway slightly, with a creaking sound.
### 182. The broken flag flutters in the wind, with a faint rustling sound.
### 183. A small fire burns in the cargo hold, emitting soft embers and a crackling sound.
### 184. Sand particles swirl in the air around the galleon, with a soft whooshing sound.
### 185. A few fireflies hover near the galleon, creating a gentle glow and a soft buzzing sound.
### 186. The broken mast creaks occasionally, with a low groan sound.
### 187. The wind whistles through the broken hull, creating a haunting sound.
### 188. A soft drip sound comes from the hull, as if water is seeping through.
### 189. The galleon’s deck creaks under the wind, with a low groan.
### 190. A soft, rhythmic wind sound echoes across the dunes.
### 191. A few birds fly overhead, creating a distant chattering sound.
### 192. A distant howl echoes from the dunes, adding to the eerie mood.
### 193. A soft, crackling fire sounds from the cargo hold.
### 194. A gentle breeze causes the sand to shift, creating a soft whispering sound.
### 195. The galleon’s broken masts sway slightly, with a creaking and groaning sound.

### J. Implementation & Engine Hooks (features 196–200)
### 196. Total tri count: 4500 triangles.
### 197. Mesh builder function in `ios/Mesh.swift` is named `makeSandGalleon(device:)`.
### 198. Mesh is built using `mbCylinder` for masts, `mbSphere` for the wheel, and `extruded ring` for the hull.
### 199. Draw calls are decomposed into one mesh with multiple submeshes for material switching.
### 200. Required additions to `world.team` switch in `src/main.zig` include a case for team 60, and a dispatch case in `ios/GameViewController.swift` for `sand_galleon` with `drawMesh(145)` call.
---

```
## Asset 146 — sphinx_king_throne (Hero Landmark, desert)
### A. Concept & Silhouette (features 1–10)
### 1. The sphinx_king_throne is a colossal seated statue of a desert king, weathered by centuries of sandstorms and sun, with one gauntleted hand buried in the dunes and a broken crown.
### 2. From 80m away, the silhouette is a powerful, slightly tilted sphinx with a throne-like base and an outstretched hand, easily recognizable as a landmark.
### 3. From 30m, the silhouette reveals the throne's carved glyphs, the broken crown, and the face's partial features.
### 4. From 10m, the statue’s weathered face, hand, and throne details are clearly visible, with a distinct, eerie presence.
### 5. The throne’s back has carved glyphs, and the face is weathered to half-features, with only the nose and a slanted eye visible.
### 6. The statue’s mood is one of ancient power and tragic decay, symbolizing the fall of a once-great ruler.
### 7. The appearance at dusk is moody, with sharp shadows cast by the throne’s carved back and the sandstone crown’s fragments.
### 8. The statue is visible from the origin point (0, 0, -260) with clear line-of-sight from the path leading to it.
### 9. The statue's scale is 40m tall, making it a massive anchor in the desert landscape, dwarfing the player character.
### 10. It should not be confused with a sandstone ruin, a sandstorm, or a natural dune — it is a deliberate, sculpted monument.

### B. Form & Major Mass (features 11–30)
### 11. The sphinx_king_throne is built from a large, stacked, cylindrical base with a roughly 22m diameter.
### 12. The body is a sphinx-like structure, 18m tall, with a head and front paws, and a slightly slanted posture.
### 13. The torso leans forward, as if it was toppled by a sandstorm, giving a dynamic and unstable silhouette.
### 14. The head is weathered, with only the nose and one slanted eye visible, and the mouth is cracked and open.
### 15. The throne is a high-backed chair, 5m in height, built into the base of the sphinx.
### 16. The throne’s back is carved with 24 glyphs, some partially worn away.
### 17. One hand is buried in the dunes, with only the gauntlet visible, the rest disappearing beneath the sand.
### 18. The left paw is partially cracked, with sand filling the gap.
### 19. The crown is a broken sandstone structure, 3m tall, with jagged edges and missing fragments.
### 20. The throne's front edge is smooth, with a carved rim that curves inward.
### 21. The back of the throne has a series of carved rings that appear to be a glyph set.
### 22. The body has a hollowed-out section where the sand has eroded the sandstone.
### 23. The head is slightly tilted, with the right eye partially cracked and sunken.
### 24. The body is composed of stacked layers of sandstone, each with a different texture and hue.
### 25. The throne’s seat is 3m wide and 1.5m deep, with a curved edge and smooth sandstone.
### 26. The front paws are broad and cracked, with no visible feet or claws.
### 27. The right hand is embedded in the dunes, with sand covering 2/3 of it.
### 28. The left arm is broken off at the elbow, with sand and debris in the hollow.
### 29. The base of the statue is a 4m-high cylindrical platform, 20m in diameter.
### 30. The statue is asymmetric, leaning slightly to the left, and has an irregular, ancient appearance.

### C. Exterior Surface Detail (features 31–60)
### 31. The throne’s back is carved with a ring of 24 glyphs, some cracked and faded.
### 32. The crown’s surface is covered in sand and moss, with one golden fragment embedded.
### 33. The right eye is cracked, revealing a black void, and a sandstone chip has fallen out.
### 34. The throne seat is smooth, with a slight wear pattern, and a few small pebbles embedded in it.
### 35. The left paw has a large crack running from the top to the base.
### 36. The head’s left cheek is worn smooth, with a few sandblasted lines.
### 37. The crown’s rim is chipped, with a few loose fragments.
### 38. The throne’s edge is slightly jagged, with sand filling the gaps.
### 39. The face has a sandstone streak from the brow to the chin.
### 40. The right arm is cracked along the middle, with sand filling the gap.
### 41. The back of the throne is covered in moss, which is slightly green.
### 42. The base of the statue has a series of small cracks, creating a textured surface.
### 43. The throne’s front is polished, showing wear from ancient hands.
### 44. The crown’s top is worn, with a small hole in the center.
### 45. The left hand’s knuckles are smooth, with sand embedded in the crevices.
### 46. The face’s nose is broken, with a jagged edge.
### 47. The back of the throne has a small carved symbol of a sun.
### 48. The sandstone surface has a fine grain, with some weathering lines.
### 49. The throne’s edge is slightly eroded, with sand filling in small indentations.
### 50. The face’s mouth is cracked and sunken, with sand filling the gap.
### 51. The right foot is partially buried, with sand covering 2/3 of it.
### 52. The throne’s back is slightly tilted, with a sandstone ring worn smooth.
### 53. The crown’s front is slightly cracked, with sand filling the gap.
### 54. The throne’s seat has a small carved symbol of a bird.
### 55. The head’s left ear is cracked, with sand embedded in the crevice.
### 56. The throne’s side is carved with a series of small glyphs.
### 57. The face’s right eye socket is cracked, with a small hole in the center.
### 58. The back of the throne is partially moss-covered, with sand mixed in.
### 59. The left arm’s shoulder is cracked, with sand filling in.
### 60. The throne’s edge is slightly eroded, with a few sandstones worn smooth.

### D. Internal / Sub-Volume Detail (features 61–90)
### 61. The throne’s interior is hollow, with a carved seat and backrest.
### 62. The throne’s back has a small hollow, with sand filling the space.
### 63. The throne’s front is hollowed, with a smooth sandstone surface.
### 64. The base of the throne has a small crack, with sand filling the space.
### 65. The throne’s seat is slightly hollow, with a carved rim around it.
### 66. The throne’s back is carved with a series of small glyphs.
### 67. The throne’s front is slightly cracked, with sand filling in.
### 68. The throne’s interior is smooth, with a worn sandstone surface.
### 69. The throne’s seat is slightly cracked, with sand filling in.
### 70. The throne’s back is hollow, with a carved rim.
### 71. The throne’s front is carved with a small symbol of a bird.
### 72. The throne’s seat is slightly worn, with sand embedded in the cracks.
### 73. The throne’s back is slightly cracked, with sand filling in.
### 74. The throne’s interior is hollowed out, with a carved seat.
### 75. The throne’s front is slightly worn, with sand embedded.
### 76. The throne’s seat is carved with a small ring.
### 77. The throne’s back is hollowed, with a carved symbol of a sun.
### 78. The throne’s front is slightly eroded, with sand filling in.
### 79. The throne’s seat is slightly cracked, with sand embedded.
### 80. The throne’s back is carved with a series of glyphs.
### 81. The throne’s front is slightly worn, with sand embedded.
### 82. The throne’s seat is hollowed, with a carved rim.
### 83. The throne’s back is slightly cracked, with sand filling in.
### 84. The throne’s interior is carved with a series of symbols.
### 85. The throne’s front is slightly eroded, with sand filling in.
### 86. The throne’s seat is carved with a small ring.
### 87. The throne’s back is hollowed, with a carved symbol of a bird.
### 88. The throne’s front is slightly cracked, with sand embedded.
### 89. The throne’s seat is slightly worn, with sand filling in.
### 90. The throne’s back is carved with a series of glyphs.

### E. Decoration & Props (features 91–120)
### 91. A small golden coin is embedded in the throne’s seat.
### 92. A broken sandstone sword is partially buried in the dunes near the throne.
### 93. A small idol of a falcon is placed on the throne’s back.
### 94. A bone pile is located beside the throne, with scattered fragments.
### 95. A sandstone jar is placed near the throne, cracked and empty.
### 96. A small candle is placed on the throne’s front edge.
### 97. A broken crown fragment is embedded in the throne’s back.
### 98. A sandstone tablet is placed near the throne, with glyphs carved into it.
### 99. A small bone ornament is placed on the throne’s seat.
### 100. A weathered banner is draped across the throne’s back.
### 101. A broken sword is embedded in the throne’s front.
### 102. A small sandstone cup is placed beside the throne.
### 103. A broken crown is placed on the throne’s seat.
### 104. A sandstone lamp is placed on the throne’s back.
### 105. A small bone shard is placed on the throne’s edge.
### 106. A spilled coin pouch lies beside the throne’s left foot, with sandstone-pale coins half-buried in the dune.
### 107. A jeweled scepter rests against the throne’s base, its crowning gem prised from the setting and replaced by a fossilised tooth.
### 108. A clay urn lies cracked open near the right armrest, an unfinished offering of dried pomegranate seeds spilling toward the player’s line of approach.
### 109. A frayed silk tassel still clings to the throne’s right armrest, sun-bleached from accent_gold to bone_pale and stiff with dune dust.
### 110. A broken sandstone tablet is placed beside the throne.
### 111. A small golden ring is embedded in the throne’s seat.
### 112. A broken sandstone shield is placed beside the throne.
### 113. A sandstone amulet is placed on the throne’s back.
### 114. A small bone ornament is placed on the throne’s front.
### 115. A broken sandstone sword is placed on the throne’s seat.
### 116. A small golden coin is placed on the throne’s front edge.
### 117. A sandstone jar is placed on the throne’s back.
### 118. A small bone shard is placed on the throne’s edge.
### 119. A broken sandstone tablet is placed on the throne’s front.
### 120. A small golden ring is placed on the throne’s back.

### F. Surrounding Environment (features 121–140)
### 121. The ground around the statue is a mix of sand and fine gravel.
### 122. The dunes are soft and shifting, with a fine layer of sand covering the base.
### 123. A small sandstone path leads to the statue from the origin point.
### 124. The area is free of vegetation, with only sand and stone.
### 125. A few scorch marks are visible on the dunes near the statue.
### 126. The sand is slightly compacted around the base of the statue.
### 127. A small pile of bones is scattered near the throne.
### 128. The dunes are slightly eroded, with sand forming a small pool.
### 129. The area is quiet, with no ambient creatures.
### 130. A few sandstone rocks are scattered around the statue.
### 131. The sand is slightly damp in places, indicating recent rain.
### 132. The area is covered in a fine layer of sand.
### 133. A few broken sandstone fragments are scattered near the base.
### 134. The area is mostly flat, with no large rocks or obstacles.
### 135. The dunes are soft and shifting, with a fine layer of sand covering the base.
### 136. The sand is slightly compacted around the base of the statue.
### 137. A few scorch marks are visible on the dunes near the statue.
### 138. The area is free of vegetation, with only sand and stone.
### 139. A small pile of bones is scattered near the throne.
### 140. The area is mostly flat, with no large rocks or obstacles.

### G. Materials & Shaders (features 141–160)
### 141. Throne seat — uBase 0 — `mix(float3(0.6, 0.4, 0.2), float3(0.8, 0.6, 0.4), sin(fbm(pos * 0.5) * 0.5));`
### 142. Throne back — uBase 8 — `mix(float3(0.7, 0.5, 0.3), float3(0.9, 0.7, 0.5), fbm(pos * 0.3));`
### 143. Throne front — uBase 30 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), sin(fbm(pos * 0.4) * 0.3));`
### 144. Throne edge — uBase 36 — `mix(float3(0.8, 0.6, 0.4), float3(0.9, 0.7, 0.5), fbm(pos * 0.2));`
### 145. Throne seat — uBase 37 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), sin(fbm(pos * 0.3) * 0.4));`
### 146. Throne back — uBase 40 — `mix(float3(0.7, 0.6, 0.5), float3(0.8, 0.7, 0.6), fbm(pos * 0.4));`
### 147. Throne front — uBase 42 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), sin(fbm(pos * 0.5) * 0.3));`
### 148. Throne edge — uBase 0 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), fbm(pos * 0.3));`
### 149. Throne seat — uBase 8 — `mix(float3(0.7, 0.6, 0.5), float3(0.8, 0.7, 0.6), sin(fbm(pos * 0.4) * 0.5));`
### 150. Throne back — uBase 30 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), fbm(pos * 0.2));`
### 151. Throne front — uBase 36 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), sin(fbm(pos * 0.3) * 0.4));`
### 152. Throne edge — uBase 37 — `mix(float3(0.7, 0.6, 0.5), float3(0.8, 0.7, 0.6), fbm(pos * 0.4));`
### 153. Throne seat — uBase 40 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), sin(fbm(pos * 0.5) * 0.3));`
### 154. Throne back — uBase 42 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), fbm(pos * 0.3));`
### 155. Throne front — uBase 0 — `mix(float3(0.7, 0.6, 0.5), float3(0.8, 0.7, 0.6), sin(fbm(pos * 0.4) * 0.4));`
### 156. Throne edge — uBase 8 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), fbm(pos * 0.2));`
### 157. Throne seat — uBase 30 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), sin(fbm(pos * 0.3) * 0.5));`
### 158. Throne back — uBase 36 — `mix(float3(0.7, 0.6, 0.5), float3(0.8, 0.7, 0.6), fbm(pos * 0.4));`
### 159. Throne front — uBase 37 — `mix(float3(0.6, 0.5, 0.4), float3(0.7, 0.6, 0.5), sin(fbm(pos * 0.5) * 0.3));`
### 160. Throne edge — uBase 40 — `mix(float3(0.5, 0.4, 0.3), float3(0.6, 0.5, 0.4), fbm(pos * 0.3));`

### H. Lighting & Atmosphere (features 161–180)
### 161. The statue is lit by a single, strong sun, casting sharp shadows.
### 162. The shadows from the throne’s back are long and sharp.
### 163. The sandstone surface is slightly glowing, with a warm, golden hue.
### 164. The throne’s interior is slightly dark, with a few faint light rays.
### 165. The atmosphere is dry, with no visible moisture or mist.
### 166. The statue’s surface is slightly reflective, with sand particles catching light.
### 167. The area is slightly foggy, with a fine layer of sand in the air.
### 168. The throne’s back is slightly illuminated, with a soft glow.
### 169. The statue casts a large shadow across the dunes.
### 170. The area is slightly warm, with a dry, desert heat.
### 171. The throne’s front is slightly illuminated, with a soft glow.
### 172. The statue’s face is slightly illuminated, with a soft glow.
### 173. The area is slightly dusty, with sand particles in the air.
### 174. The throne’s seat is slightly glowing, with a warm, golden hue.
### 175. The throne’s back is slightly illuminated, with a soft glow.
### 176. The area is slightly foggy, with a fine layer of sand in the air.
### 177. The statue’s surface is slightly reflective, with sand particles catching light.
### 178. The throne’s front is slightly illuminated, with a soft glow.
### 179. The throne’s seat is slightly glowing, with a warm, golden hue.
### 180. The area is slightly warm, with a dry, desert heat.

### I. Animation, FX, and Sound Design (features 181–195)
### 181. A faint sandstorm swirls around the throne’s base.
### 182. A few fireflies flutter near the throne’s front edge.
### 183. A small gust of wind causes the sandstone tablet to rattle.
### 184. The throne emits a soft, golden light from within.
### 185. A faint wind whistles through the throne’s hollow.
### 186. A few embers float from the throne’s seat.
### 187. A soft crackling sound comes from the throne’s back.
### 188. A few sand particles swirl in the air around the throne.
### 189. The throne’s edge glows faintly with a golden hue.
### 190. A soft, distant howl echoes from the dunes.
### 191. A few small particles of sand fall from the throne’s seat.
### 192. A few glowing motes float around the throne’s base.
### 193. The throne’s front edge flickers with a warm glow.
### 194. A soft, dry crackling sound emanates from the throne’s back.
### 195. A few sandstone chips fall from the throne’s edge.

### J. Implementation & Engine Hooks (features 196–200)
### 196. Tri-budget breakdown: throne base 1500 tris, throne back 1000 tris, throne seat 1000 tris, throne front 1000 tris, throne edge 1000 tris.
### 197. `makeSphinxKingThrone(device:)` in `ios/Mesh.swift`, uses `mbCylinder` and `mbSphere`.
### 198. Mesh is a single draw call with multiple submeshes.
### 199. Add case `60` to `world.team` switch in `src/main.zig`.
### 200. No LOD — forest does no LOD currently.
```
---

```
## Asset 147 — sun_forge_caldera (Hero Landmark, desert)
### 1. The sun_forge_caldera is a hero landmark in the desert zone, designed to read clearly from 80m, 30m, and 10m distances, with a silhouette that anchors the player's attention.
### 2. It is a cracked-obsidian volcanic caldera ringed by glyph-walls, a central stone fire pit holds a perpetually burning ember-orange flame, and the crater rim is studded with weathered idol pedestals.
### 3. The landmark’s lore hook is that it was once a sacred forge, where the sun god's hammer was forged and imbued with divine fire.
### 4. The mood is one of ancient mystery and eternal heat, evoking the power of the desert sun and the remnants of a divine creation.
### 5. At midday, the caldera’s surface glows with a subtle heat shimmer, and at dusk, the ember-orange fire pit pulses with light.
### 6. Visibility from the origin site is excellent, with the caldera’s rim clearly visible from a distance, even in the harsh desert light.
### 7. The caldera’s scale is anchored to the player's height — it feels immense, with a rim that looms over the player like a natural amphitheater.
### 8. The exact map coordinates are approximately (-30, 0, -310), located in a slight depression.
### 9. It should not be confused with a regular volcanic crater, a mesa, or a sand dune — it is uniquely a site of divine forge-work.
### 10. The silhouette from 80m is defined by a circular ring of cracked obsidian, with a central fire pit and glyph walls rising from the rim.

### 11. The caldera’s outer rim is a circular ring of 3500 tris, with a 30m diameter and 2.5m height, built as a mbCylinder with a beveled edge.
### 12. The rim leans slightly inward at 10 degrees, giving it a collapsed, weathered look.
### 13. The rim is 2.5m thick, with a vertical surface and a 1.5m high inner lip that holds the fire pit.
### 14. The rim has a slight asymmetry, with one side slightly higher than the other, indicating ancient collapse.
### 15. The rim is composed of stacked plates, each with a different crack pattern, and is segmented into 6 major sections.
### 16. The rim features a hollow space in the center, approximately 10m in diameter, creating a void for the fire pit.
### 17. The rim is topped with a ring of 12 weathered idol pedestals, evenly spaced, each 1.2m tall.
### 18. The rim’s surface is not uniform — it is a mixture of flat and curved sections, with some areas showing signs of erosion.
### 19. The rim is partially covered with a thin layer of sand and ash, with visible wind erosion patterns.
### 20. The rim is composed of cracked obsidian, with visible fractures running in a radial pattern.
### 21. The rim’s base is 10m wide and 1.5m high, rising from the desert floor.
### 22. The rim is connected to the fire pit through a 2m wide channel, forming a continuous circular flow.
### 23. The rim features 3 large, carved glyph-walls, each 2.5m wide and 3m high, arranged in a triangular pattern.
### 24. The rim is slightly tilted, creating a subtle inward slope that enhances the caldera’s bowl shape.
### 25. The rim’s surface is not entirely solid — it contains 8 large cracks, each 2m wide, running along the outer edge.
### 26. The rim has a rough, unfinished texture, as if it was never fully shaped by the forge.
### 27. The rim’s upper surface is covered with a thin layer of sand and debris, giving it a worn, ancient look.
### 28. The rim is surrounded by a small ring of cracked obsidian blocks, 0.5m high, forming a barrier.
### 29. The rim’s edges are worn down, showing signs of long-term exposure to sand and wind.
### 30. The rim has a dominant axis aligned with the northern direction, suggesting a directional alignment.

### 31. The rim’s outer surface is covered with a mixture of cracked obsidian and sand, with a fine, granular texture.
### 32. The surface has 15 distinct crack patterns, each 10–15cm wide, radiating from the center.
### 33. The surface is carved with 24 large glyphs, each 20cm wide, arranged in a circular pattern.
### 34. The glyphs are etched deeply, with 3mm depth, and show signs of wear and fading.
### 35. A small patch of heat shimmer is visible in the center, where the fire pit sits.
### 36. A large chip in the rim’s edge, 15cm wide, reveals the inner structure of the obsidian.
### 37. The rim’s surface is slightly reflective, showing a subtle metallic sheen in the right light.
### 38. A small piece of sandstone is embedded in the rim, 20cm wide, with a dark streak running through it.
### 39. A small area of the rim is covered in a dark, smooth layer, likely a hardened ash deposit.
### 40. A small section of the rim has a raised texture, forming a pattern of small ridges.
### 41. The rim has a visible wear pattern, with a 30cm wide groove running along the edge.
### 42. A small portion of the rim is covered in a dark, almost black, lustrous coating.
### 43. The rim’s surface shows a pattern of small, rounded bumps, 5–8mm in diameter.
### 44. A small patch of the rim is covered in a fine layer of ash, giving it a soft, matte look.
### 45. The rim’s surface has a series of small, irregular holes, 1cm in diameter, forming a scattered pattern.
### 46. A thin layer of sand has accumulated in a 2m wide area, forming a shallow depression.
### 47. A section of the rim has a faint, pale red streak, indicating a mineral deposit.
### 48. A small area of the rim is covered with a smooth, glossy layer, likely from the heat of the fire.
### 49. The rim shows signs of erosion, with a 50cm wide channel carved by wind.
### 50. A small section of the rim has a soft, powdery texture, suggesting recent weathering.
### 51. The rim’s surface is marked with a series of shallow, curved scratches, 10cm long.
### 52. A small area of the rim is covered in a fine layer of crushed stone, giving it a gritty texture.
### 53. The rim’s surface is partially covered with a thin, transparent film, giving it a glassy look.
### 54. A small patch of the rim is covered in a dark, cracked layer, possibly from fire exposure.
### 55. A small area of the rim shows signs of a recent impact, with a 10cm wide crater.
### 56. A small section of the rim is smooth and polished, likely from a long period of wind erosion.
### 57. The rim’s surface is marked with a series of shallow, V-shaped grooves.
### 58. A patch of the rim has a slight upward slope, forming a small ridge.
### 59. The rim’s surface is covered in a fine, dark sand, giving it a uniform, dull appearance.
### 60. A small area of the rim is covered in a white, powdery layer, possibly salt or mineral deposits.

### 61. The caldera’s interior is a hollow space, 10m in diameter, with a floor that slopes inward.
### 62. The floor is composed of 12 cracked obsidian slabs, each 1.5m wide, arranged in a radial pattern.
### 63. The floor has a central fire pit, 4m in diameter, carved into the obsidian.
### 64. The fire pit is filled with a red-hot ember-orange flame, 1.5m high.
### 65. The fire pit is surrounded by a ring of 8 smaller, carved stones, each 0.5m tall.
### 66. The floor of the caldera has a slight depression in the center, forming a basin for the fire.
### 67. The fire pit’s walls are smooth and polished, with a faint reflective sheen.
### 68. The floor is covered with a thin layer of ash and sand, giving it a soft texture.
### 69. The fire pit’s base is composed of a single, large obsidian stone, 3m wide.
### 70. The fire pit’s sides are carved with a series of concentric rings, each 20cm wide.
### 71. A small area of the floor is covered in a fine, dark sand, forming a patchwork pattern.
### 72. The floor’s surface is slightly uneven, with a series of small bumps and dips.
### 73. The floor has a series of small, shallow holes, each 2cm wide, forming a scattered pattern.
### 74. A small section of the floor is covered in a thin layer of ash, giving it a matte look.
### 75. The floor has a raised edge around the fire pit, 20cm high, forming a lip.
### 76. A small patch of the floor is covered in a fine, gritty texture, giving it a coarse feel.
### 77. The floor’s texture is a mixture of smooth and rough areas, with some sections polished.
### 78. The floor is partially covered with a thin layer of sand and debris.
### 79. A small section of the floor is covered in a smooth, glossy surface, likely from heat.
### 80. The floor’s surface is marked with a series of shallow, V-shaped grooves, forming a radial pattern.
### 81. The floor has a slight upward slope near the fire pit, directing heat outward.
### 82. A small area of the floor is covered in a fine, powdery layer, possibly from mineral deposits.
### 83. The floor’s surface is marked with a series of shallow, curved scratches, 5cm long.
### 84. A small section of the floor is covered in a dark, cracked layer, possibly from fire.
### 85. The floor is composed of a single, large obsidian slab, 10m wide, with a smooth texture.
### 86. The floor’s surface is slightly reflective, giving it a subtle sheen.
### 87. The floor is partially covered in a thin layer of sand, with a few small rocks scattered.
### 88. The fire pit’s base is slightly raised, forming a small platform.
### 89. The floor’s surface is composed of a mixture of smooth and cracked sections.
### 90. A small area of the floor is covered in a thin, dark film, possibly from heat exposure.

### 91. A central idol pedestal, 1.2m tall, is positioned at the fire pit’s center.
### 92. The idol pedestal is carved from a single piece of obsidian, with a smooth, polished surface.
### 93. The idol is a stylized sun god figure, 0.8m tall, with a radiant crown.
### 94. The idol’s surface is covered with a fine layer of ash, giving it a matte finish.
### 95. The idol pedestal is surrounded by a small ring of 6 smaller stones, each 0.3m tall.
### 96. A small cauldron, 0.5m in diameter, is placed on the pedestal’s base.
### 97. The cauldron is made of cracked obsidian and has a black, matte finish.
### 98. A small, glowing ember-orange flame burns inside the cauldron, 0.2m high.
### 99. The cauldron is surrounded by a ring of 4 small, carved glyphs.
### 100. A small, cracked obsidian shard is embedded in the pedestal, 5cm wide.
### 101. The pedestal’s base is surrounded by a ring of 8 small, round stones.
### 102. A small, glowing firefly is perched on the pedestal, 0.1m tall.
### 103. The pedestal’s surface is marked with a series of shallow, curved scratches.
### 104. A small patch of the pedestal is covered in a fine, dark sand.
### 105. The pedestal’s base is carved with a series of small, circular holes.
### 106. A small, glowing ember-orange light is embedded in the pedestal, 0.1m wide.
### 107. The pedestal’s surface is slightly reflective, giving it a subtle sheen.
### 108. A small, carved glyph is visible on the pedestal’s side, 10cm wide.
### 109. A small, cracked obsidian piece is placed near the pedestal, 20cm wide.
### 110. The pedestal is surrounded by a thin layer of ash, giving it a soft texture.
### 111. A small, round, black stone is placed on the pedestal’s base, 0.2m wide.
### 112. The pedestal’s surface is covered with a thin, dark film, possibly from heat.
### 113. A small section of the pedestal is smooth and polished, likely from wear.
### 114. A small, glowing firefly is perched on the cauldron’s rim.
### 115. The pedestal’s base is slightly elevated, forming a small platform.
### 116. A small, carved symbol is visible on the pedestal’s top, 5cm wide.
### 117. A small patch of the pedestal is covered in a fine, powdery layer.
### 118. The pedestal’s surface is marked with a series of shallow, V-shaped grooves.
### 119. A small, glowing ember-orange flame is visible on the pedestal’s base.
### 120. The pedestal’s surface is slightly cracked, showing signs of age.

### 121. The ground around the caldera is covered with a fine layer of sand, 5cm deep.
### 122. A small patch of cracked obsidian blocks is scattered around the caldera’s edge.
### 123. The ground is partially covered with a thin layer of ash, giving it a matte look.
### 124. A small, cracked obsidian shard is embedded in the ground, 10cm wide.
### 125. The ground has a series of small, shallow holes, 1cm wide, forming a scattered pattern.
### 126. A small, glowing firefly is perched on a nearby rock.
### 127. The ground is covered with a fine layer of sand and debris, giving it a soft texture.
### 128. A small, round, black stone is placed near the caldera’s rim, 0.2m wide.
### 129. A small, glowing ember-orange flame is visible near the caldera’s edge.
### 130. The ground is partially covered with a thin layer of ash and sand.
### 131. A small, carved glyph is visible on a nearby rock, 10cm wide.
### 132. A thin layer of sand has accumulated in a 2m wide area, forming a shallow depression.
### 133. The ground is marked with a series of shallow, curved scratches.
### 134. A small, cracked obsidian piece is placed on the ground, 15cm wide.
### 135. The ground is slightly uneven, with a series of small bumps and dips.
### 136. A small patch of the ground is covered in a fine, dark sand.
### 117. A small, glowing ember-orange light is visible on the ground, 0.1m wide.
### 138. The ground is covered with a thin layer of ash, giving it a matte look.
### 139. A small, round, black stone is placed near the fire pit, 0.2m wide.
### 140. A small, glowing firefly is perched on a nearby obsidian block.

### 141. The rim’s surface is assigned uBase marker 0, with a shader that mixes `float3(0.3, 0.2, 0.1)` and `float3(0.1, 0.1, 0.1)` using `fbm` for texture variation.
### 142. The fire pit’s base is assigned uBase marker 8, with a shader that mixes `float3(0.9, 0.3, 0.1)` and `float3(0.8, 0.2, 0.1)` using `sin` for a flickering effect.
### 143. The idol pedestal is assigned uBase marker 30, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `mix(a,b,t)` with a time-based t.
### 144. The cauldron is assigned uBase marker 32, with a shader that mixes `float3(0.1, 0.1, 0.1)` and `float3(0.3, 0.1, 0.1)` using `fbm` for a rough texture.
### 145. The glyph-walls are assigned uBase marker 33, with a shader that mixes `float3(0.5, 0.4, 0.3)` and `float3(0.4, 0.3, 0.2)` using `mix(a,b,t)` with a t that varies based on vertex position.
### 146. The floor is assigned uBase marker 36, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `sin` for a subtle wave.
### 147. The idol’s surface is assigned uBase marker 40, with a shader that mixes `float3(0.8, 0.6, 0.4)` and `float3(0.7, 0.5, 0.3)` using `fbm` for a fine grain.
### 148. The fire pit’s walls are assigned uBase marker 42, with a shader that mixes `float3(0.9, 0.3, 0.1)` and `float3(0.8, 0.2, 0.1)` using `mix(a,b,t)` with a time-based t.
### 149. The rim’s inner lip is assigned uBase marker 0, with a shader that mixes `float3(0.3, 0.2, 0.1)` and `float3(0.1, 0.1, 0.1)` using `sin` for a subtle texture.
### 150. The fire pit’s base is assigned uBase marker 8, with a shader that mixes `float3(0.9, 0.3, 0.1)` and `float3(0.8, 0.2, 0.1)` using `fbm` for a flickering effect.
### 151. The glyph-walls are assigned uBase marker 33, with a shader that mixes `float3(0.5, 0.4, 0.3)` and `float3(0.4, 0.3, 0.2)` using `mix(a,b,t)` with a t that varies based on vertex position.
### 152. The floor is assigned uBase marker 36, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `sin` for a subtle wave.
### 153. The idol pedestal is assigned uBase marker 30, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `mix(a,b,t)` with a time-based t.
### 154. The cauldron is assigned uBase marker 32, with a shader that mixes `float3(0.1, 0.1, 0.1)` and `float3(0.3, 0.1, 0.1)` using `fbm` for a rough texture.
### 155. The rim’s surface is assigned uBase marker 0, with a shader that mixes `float3(0.3, 0.2, 0.1)` and `float3(0.1, 0.1, 0.1)` using `fbm` for texture variation.
### 156. The fire pit’s base is assigned uBase marker 8, with a shader that mixes `float3(0.9, 0.3, 0.1)` and `float3(0.8, 0.2, 0.1)` using `sin` for a flickering effect.
### 157. The idol pedestal is assigned uBase marker 30, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `mix(a,b,t)` with a time-based t.
### 158. The cauldron is assigned uBase marker 32, with a shader that mixes `float3(0.1, 0.1, 0.1)` and `float3(0.3, 0.1, 0.1)` using `fbm` for a rough texture.
### 159. The glyph-walls are assigned uBase marker 33, with a shader that mixes `float3(0.5, 0.4, 0.3)` and `float3(0.4, 0.3, 0.2)` using `mix(a,b,t)` with a t that varies based on vertex position.
### 160. The floor is assigned uBase marker 36, with a shader that mixes `float3(0.2, 0.2, 0.2)` and `float3(0.1, 0.1, 0.1)` using `sin` for a subtle wave.

### 161. The fire pit emits a soft ember-orange glow, visible from 20m.
### 162. The glow is accompanied by a subtle heat shimmer that distorts the air around the fire pit.
### 163. A faint, flickering light is visible on the rim, casting shadows in the caldera.
### 164. The rim’s surface reflects a warm, orange hue under direct sunlight.
### 165. A small ring of fireflies surrounds the caldera, glowing in sync with the fire.
### 166. The caldera’s interior is illuminated by a soft, glowing fire that reflects off the walls.
### 167. The fire pit’s flame casts long, flickering shadows on the rim.
### 168. The caldera is surrounded by a subtle, warm glow that extends 10m in all directions.
### 169. A faint, golden light shines through the glyph-walls, illuminating the interior.
### 170. The caldera emits a soft, ambient light that dims at night.
### 171. A warm, orange glow is visible on the idol pedestal, casting a small shadow.
### 172. The cauldron emits a faint, red glow, visible from 5m.
### 173. The fire pit’s flame flickers with a subtle, rhythmic motion.
### 174. The caldera’s glow is strongest at dusk, when the sun sets.
### 175. The rim’s surface reflects a faint, red glow, especially during sunset.
### 176. The fire pit’s glow is visible from 30m away, even in daylight.
### 177. A soft, orange light shines through the glyphs, creating a subtle halo effect.
### 178. The caldera’s light is accompanied by a slight heat distortion in the air.
### 179. The glow from the fire pit is visible in the center of the caldera, 15m away.
### 180. The caldera’s surface glows softly under moonlight, with a subtle orange hue.

### 181. A particle emitter creates a slow, steady stream of embers rising from the fire pit.
### 182. The embers are rendered using a custom `embers` preset, with a 10cm size variation.
### 183. A soft, flickering light effect is visible on the idol pedestal, mimicking firelight.
### 184. A subtle smoke trail rises from the cauldron, using the `forest_motes` preset.
### 185. A small, glowing firefly orbits the fire pit, emitting a soft light.
### 186. The fire pit emits a continuous, low-pitched crackling sound.
### 187. A faint, high-pitched hum is heard from the glyph-walls.
### 188. The cauldron bubbles gently, producing a low bubbling sound.
### 189. A soft, rhythmic crackling sound is heard from the rim’s surface.
### 190. The caldera emits a low, ambient drone, especially at night.
### 191. A soft, low sound of wind echoes around the caldera.
### 192. A distant, howling wind is heard from the caldera’s rim.
### 193. A soft, rhythmic thud is heard from the idol pedestal.
### 194. The fire pit emits a slight, rhythmic hiss as the flame burns.
### 195. A soft, crackling sound is heard from the cauldron’s rim.

### 196. The total tri-budget is 3500 tris, distributed across 1 main mesh and 3 submeshes.
### 197. The mesh builder strategy is `makeSunForgeCaldera(device:)` in `ios/Mesh.swift`.
### 198. The mesh is composed of a single `mbCylinder` for the rim, and `mbSphere` for the fire pit.
### 199. The draw-call decomposition is one main mesh with 4 submeshes for different sections.
### 200. No LOD strategy is required; the caldera is a hero asset and is always fully rendered.
```
---


# Drifting Isles Zone Hero Landmarks

The Drifting Isles (900 m radius, 720 m path across 6 islands) get three hero landmarks anchoring the archipelago's beats. See `drifting_isles.md` for the foundation.

---

```
## Asset 148 — dragonbone_cathedral (Hero Landmark, isles)
### 1. The dragonbone_cathedral is a massive whale-or-dragon ribcage repurposed into an open-air cathedral on Whale's Spine island B.
### 2. From 80m away, it appears as a great arching rib structure with scattered lanterns and banners.
### 3. From 30m, the silhouette reveals the central altar and a series of curved pillars.
### 4. From 10m, the cathedral's ribbed ceiling and hanging lanterns are clearly visible.
### 5. The cathedral's mood is one of ancient reverence and weathered grandeur.
### 6. The cathedral is best viewed at dawn or dusk, when amber lanterns glow against the deepening sky.
### 7. Visibility from the player’s starting point is excellent, with the cathedral forming a clear landmark.
### 8. The cathedral's scale anchors to the player’s height, appearing as a monumental, almost godlike structure.
### 9. Exact map coordinates are (200, 0, -180) on Whale's Spine island B.
### 10. The cathedral is NOT to be confused with any other building or natural landmark in the zone.
### 11. The cathedral's main structure is a large, curved rib, 120m long, 30m wide, and 20m tall.
### 12. The rib is bowed inward, creating a central nave with a vaulted ceiling.
### 13. The cathedral leans slightly toward the player's approach path, as if guiding them.
### 14. The rib is asymmetrical, with the left side slightly higher than the right.
### 15. The cathedral has no roof, creating an open-air interior with a view of the sky.
### 16. The rib is hollow, with a central passage running down its spine.
### 17. The cathedral has three major openings: the main entrance at the base, and two smaller alcoves.
### 18. The cathedral’s surface is weathered with moss, barnacles, and erosion.
### 19. The cathedral’s exterior is mostly smooth except for carved glyphs and weathered patches.
### 20. The rib is composed of multiple stacked, curved plates, each slightly offset.
### 21. The cathedral’s lower section has a thick, barnacle-covered texture.
### 22. The cathedral’s mid-section has a smooth, polished bone surface with carved symbols.
### 23. The cathedral’s upper section is weathered with moss and lichen.
### 24. The cathedral’s rib is supported by 12 stone pillars, evenly spaced along its length.
### 25. The pillars are embedded in the rib at varying angles, leaning slightly inward.
### 26. The cathedral has no windows, but features a series of hanging lanterns.
### 27. The cathedral has a large, central altar in the middle of the rib.
### 28. The cathedral has a series of tattered prayer banners hanging from its ribs.
### 29. The cathedral has no interior doors or barriers, only open passageways.
### 30. The cathedral’s structure is composed of multiple interlocking rib segments.
### 31. The main surface of the cathedral is a pale bone texture with subtle green moss patches.
### 32. A large barnacle cluster covers the lower left section of the rib.
### 33. A mossy patch covers the center of the cathedral's rib, forming a natural carpet.
### 34. A large crack runs vertically down the center of the rib, revealing dark underlayers.
### 35. A carved glyph is visible on the left pillar, glowing faintly in the dark.
### 36. A tattered banner is hung from the rib, flapping in the wind.
### 37. A small moss patch is embedded in the rib near the altar.
### 38. A series of small barnacles are clustered on the rib’s right side.
### 39. A deep shadowed niche is carved into the rib, housing a small lantern.
### 40. A carved face is visible on the lower right section of the rib.
### 41. A rusted iron hook is embedded in the rib, used for hanging banners.
### 42. A small crack in the rib's surface allows light to seep through.
### 43. A vine grows across the rib’s top surface, partially obscuring a glyph.
### 44. A weathered plaque is carved into the rib, barely readable.
### 45. A small pool of stagnant water collects in the rib's lowest section.
### 46. A glowing rune is carved into the rib’s surface near the altar.
### 47. A series of small cracks run horizontally across the rib.
### 48. A patch of lichen grows across the rib’s surface near the altar.
### 49. A carved dragon symbol is visible on the right pillar.
### 50. A small hole is drilled into the rib, likely used for hanging objects.
### 51. A large barnacle cluster covers the lower right section of the rib.
### 52. A moss patch is visible on the rib's backside, near the entrance.
### 53. A deep gouge is visible on the rib, possibly from ancient shipwrecks.
### 54. A small crack in the rib reveals a blackened core.
### 55. A small piece of bone is embedded in the rib, possibly a relic.
### 56. A small glowing crystal is embedded in the rib near the altar.
### 57. A large, worn glyph is carved into the rib’s center.
### 58. A tattered cloth is draped over a pillar, flapping in the wind.
### 59. A carved symbol is visible near the entrance, slightly weathered.
### 60. A small pool of blood-like fluid is visible in a crack in the rib.
### 61. The central altar is a large, carved stone structure, 3m wide and 1.5m tall.
### 62. The altar has a series of carved symbols around its base.
### 63. The altar is embedded in a circular depression in the rib.
### 64. The altar has a small fire pit in its center.
### 65. The altar is surrounded by a ring of small stone tablets.
### 66. The altar has a large, cracked crystal in its center.
### 67. The altar is surrounded by a ring of moss-covered stones.
### 68. The altar is carved with a large, glowing glyph.
### 69. The altar has a small niche for holding a candle.
### 70. The altar is flanked by two small pillars.
### 71. The altar has a small pool of water in its center.
### 72. The altar has a series of carved runes in a spiral pattern.
### 73. The altar is surrounded by a ring of small, carved bones.
### 74. The altar has a small, glowing orb resting on its surface.
### 75. The altar has a small, carved dragon symbol on its front.
### 76. The altar has a small, cracked mirror in its base.
### 77. The altar has a small, carved heart symbol on its side.
### 78. The altar has a small, glowing crystal in its base.
### 79. The altar has a small, carved feather in its center.
### 80. The altar has a small, carved snake symbol on its side.
### 81. The altar has a small, glowing orb in its center.
### 82. The altar has a small, carved skull in its base.
### 83. The altar has a small, glowing flame in its center.
### 84. The altar has a small, carved leaf in its base.
### 85. The altar has a small, glowing symbol in its center.
### 86. The altar has a small, carved moon in its base.
### 87. The altar has a small, glowing crystal in its center.
### 88. The altar has a small, carved sun in its base.
### 89. The altar has a small, glowing symbol in its center.
### 90. The altar has a small, carved star in its base.
### 91. A large brass lantern hangs from the rib's center, emitting amber light.
### 92. A small, cracked lantern is suspended from a pillar near the altar.
### 93. A large, tattered banner is hung from the rib's left side.
### 94. A small, glowing lantern is embedded in the rib's surface.
### 95. A large, weathered idol is placed in front of the altar.
### 96. A small, carved bone is embedded in the rib near the entrance.
### 97. A large, carved dragon head is placed on a pillar.
### 98. A small, glowing crystal is embedded in the rib’s surface.
### 99. A large, moss-covered bone pile is placed near the altar.
### 100. A small, glowing rune is carved into the rib's surface.
### 101. A large, cracked skull is placed on a pillar.
### 102. A small, carved symbol is embedded in the rib near the altar.
### 103. A large, hanging banner is flapping in the wind.
### 104. A small, glowing glyph is carved into the rib's surface.
### 105. A large, moss-covered bone is embedded in the rib's surface.
### 106. A small, carved dragon symbol is embedded in the rib.
### 107. A large, cracked crystal is placed on the altar.
### 108. A small, glowing orb is embedded in the rib's surface.
### 109. A large, carved symbol is embedded in the rib.
### 110. A small, glowing crystal is placed near the altar.
### 111. A large, moss-covered banner is hung from the rib.
### 112. A small, carved skull is placed near the altar.
### 113. A large, weathered idol is placed near the altar.
### 114. A small, glowing rune is carved into the rib's surface.
### 115. A large, carved dragon symbol is placed on a pillar.
### 116. A small, glowing crystal is embedded in the rib's surface.
### 117. A large, cracked bone is placed near the altar.
### 118. A small, carved feather is placed near the altar.
### 119. A large, glowing orb is placed on the altar.
### 120. A small, glowing crystal is placed near the altar.
### 121. The ground around the cathedral is a mixture of moss, bone fragments, and sand.
### 122. The ground is slightly sloped, leading toward the cathedral’s entrance.
### 123. The ground is covered in a thin layer of barnacles and lichen.
### 124. The ground around the cathedral is mostly flat, with small bumps.
### 125. The ground is covered in a mixture of moss and small bones.
### 126. The ground is slightly wet, with a small puddle near the altar.
### 127. The ground is covered in a mixture of sand and moss.
### 128. The ground around the cathedral is mostly dry, with scattered bones.
### 129. The ground is covered in a thin layer of lichen.
### 130. The ground is slightly uneven, with small ridges.
### 131. The ground is covered in a mixture of sand and barnacles.
### 132. The ground is slightly muddy, with a small stream near the altar.
### 133. The ground is covered in a mixture of moss and bone chips.
### 134. The ground is slightly cracked, with small fissures.
### 135. The ground is covered in a mixture of sand and lichen.
### 136. The ground is slightly rough, with small pebbles.
### 137. The ground is covered in a mixture of moss and sand.
### 138. The ground is slightly dry, with scattered bone fragments.
### 139. The ground is covered in a mixture of barnacles and sand.
### 140. The ground is slightly wet, with a small puddle near the entrance.
### 141. The cathedral's main rib surface uses uBase marker 0, with a bone texture.
### 142. The cathedral's barnacle-covered sections use uBase marker 8, with a mossy texture.
### 143. The cathedral's moss patches use uBase marker 47, with a soft green surface.
### 144. The cathedral's glyph areas use uBase marker 49, with a glowing texture.
### 145. The cathedral's lanterns use uBase marker 56, with an amber glow.
### 146. The cathedral's banners use uBase marker 57, with a tattered texture.
### 147. The cathedral's altar uses uBase marker 61, with a carved stone surface.
### 148. The cathedral's inner surfaces use uBase marker 63, with a weathered texture.
### 149. The cathedral's moss patches use uBase marker 64, with a dark green hue.
### 150. The cathedral's crack areas use uBase marker 0, with a darkened surface.
### 151. The cathedral's lanterns use a mix of `mix(float3(1.0, 0.8, 0.2), float3(0.8, 0.5, 0.1), sin(time))`.
### 152. The cathedral's moss patches use a mix of `mix(float3(0.2, 0.5, 0.2), float3(0.1, 0.3, 0.1), fbm(pos))`.
### 153. The cathedral's glyphs use a mix of `mix(float3(1.0, 0.8, 0.4), float3(0.8, 0.6, 0.2), sin(time))`.
### 154. The cathedral's banners use a mix of `mix(float3(0.7, 0.6, 0.5), float3(0.4, 0.3, 0.2), fbm(pos))`.
### 155. The cathedral's inner surfaces use a mix of `mix(float3(0.4, 0.3, 0.2), float3(0.2, 0.1, 0.05), sin(time))`.
### 156. The cathedral's altar uses a mix of `mix(float3(0.8, 0.7, 0.6), float3(0.5, 0.4, 0.3), fbm(pos))`.
### 157. The cathedral's barnacles use a mix of `mix(float3(0.6, 0.5, 0.4), float3(0.3, 0.2, 0.1), sin(time))`.
### 158. The cathedral's main rib uses a mix of `mix(float3(0.9, 0.8, 0.7), float3(0.6, 0.5, 0.4), fbm(pos))`.
### 159. The cathedral's cracks use a mix of `mix(float3(0.1, 0.1, 0.1), float3(0.05, 0.05, 0.05), sin(time))`.
### 160. The cathedral's inner surfaces use a mix of `mix(float3(0.3, 0.2, 0.1), float3(0.2, 0.1, 0.05), fbm(pos))`.
### 161. The cathedral emits a soft amber glow from its lanterns.
### 162. The cathedral casts a long shadow at sunrise and sunset.
### 163. The cathedral has a soft blue glow from its glyphs at night.
### 164. The cathedral's lanterns flicker gently in the wind.
### 165. The cathedral has a soft mist hovering near the altar.
### 166. The cathedral's banners sway in the wind, creating a rhythmic motion.
### 167. The cathedral's inner surfaces are slightly dimmed by ambient light.
### 168. The cathedral's altar glows faintly when approached.
### 169. The cathedral's surface reflects the sky, especially at dusk.
### 170. The cathedral has a faint green glow from its moss patches.
### 171. The cathedral’s ambient light is slightly dimmed at night.
### 172. The cathedral’s inner surfaces are slightly illuminated by lanterns.
### 173. The cathedral’s glyphs glow softly in the dark.
### 174. The cathedral’s banners emit a subtle glow when lit.
### 175. The cathedral’s altar emits a warm, golden light.
### 176. The cathedral’s lanterns cast a soft, amber glow.
### 177. The cathedral’s moss patches reflect ambient light.
### 178. The cathedral’s inner surfaces glow faintly with a blue hue.
### 179. The cathedral’s banners cast a flickering shadow.
### 180. The cathedral’s glyphs emit a soft, pulsing light.
### 181. The cathedral’s lanterns flicker with a soft fire effect.
### 182. The cathedral’s banners sway gently, producing a soft rustling sound.
### 183. The cathedral’s altar emits a low, resonant hum.
### 184. The cathedral’s inner surfaces produce a soft wind chime sound.
### 185. The cathedral’s moss patches emit a gentle, bubbling sound.
### 186. The cathedral’s glyphs glow softly with a pulsing rhythm.
### 187. The cathedral’s banners produce a distant, howling sound.
### 188. The cathedral’s lanterns emit a low crackling sound.
### 189. The cathedral’s altar emits a soft, harmonic tone.
### 190. The cathedral’s inner surfaces produce a distant, echoing sound.
### 191. The cathedral’s moss patches emit a bubbling, gurgling sound.
### 192. The cathedral’s lanterns produce a soft, crackling sound.
### 193. The cathedral’s banners flutter softly in the wind.
### 194. The cathedral’s altar glows with a pulsing rhythm.
### 195. The cathedral’s glyphs emit a soft, pulsing glow.
### 196. Estimated triangle count: 5000 triangles.
### 197. The mesh is built using `makeDragonboneCathedral(device:)` in `ios/Mesh.swift`.
### 198. The mesh uses `mbCylinder`, `mbSphere`, and `stacked-plates` to build the rib.
### 199. The mesh is not subdivided; it uses a single draw call.
### 200. The asset is added to `world.team` switch with case 77.
```
---

## Asset 149 — lighthouse_anchor (Hero Landmark, isles)
### A. Concept & Silhouette (features 1–10)

### 1. The lighthouse_anchor is a weathered beacon in shallow water, built into an anchor stone and standing 12.5 meters above sea level.
### 2. From 80m away, it appears as a vertical, tapering structure with a rotating amber beam and a distinctive conical roof.
### 3. At 30m, the silhouette is defined by its verticality, a large lantern window, and a dark wooden spiral staircase.
### 4. At 10m, the asset reveals its full texture and details including barnacles, a cracked glass lantern, and a mossy anchor base.
### 5. The lore hook involves a shipwrecked sailor who used this beacon to guide lost vessels to safety, now lost to time.
### 6. The mood is one of resilience and memory — a beacon for the forgotten, with an air of ancient watchfulness.
### 7. It glows with an ember-orange beam visible from the center of Lantern Hold, a 400m distance.
### 8. The asset is positioned at exact map coordinates (140, 0, 50), standing in the shallows just offshore.
### 9. It should not be confused with a regular lighthouse, as it lacks a full tower structure and instead sits atop an anchor.
### 10. The scale is such that a player standing at the base is 2.5 times its height, creating a strong vertical focal point.

### B. Form & Major Mass (features 11–30)

### 11. The main structure is a vertical cylinder with a 3.2-meter diameter, tapering slightly from base to top.
### 12. The base is a 1.5-meter-high cylindrical anchor stone, embedded into the shallow seabed.
### 13. The lighthouse body is 10 meters tall with a 2-meter diameter at the top and 3.2 meters at the base.
### 14. The lantern window is a circular opening 1.8 meters in diameter, located at 9 meters above the ground.
### 15. The roof is a conical structure with a 2.5-meter diameter, 1.5 meters high, and a 0.2-meter thick wall.
### 16. A spiral wooden staircase winds up the inner wall, 1.2 meters wide, with 2.5-meter diameter steps.
### 17. The outer wall has 8 evenly spaced horizontal planks, each 1.2 meters long, 0.08 meters thick, and 0.1 meters wide.
### 18. The structure leans 3 degrees away from the east shore, giving a slight dynamic appearance.
### 19. A small platform extends from the base, 0.8 meters wide and 1.5 meters long, for a narrow plank walkway.
### 20. The entire structure has a 1.2-meter wide hollow column inside the base, for a water drain.
### 21. The base is carved with an intricate anchor motif, visible at 10m distance.
### 22. The lantern window is surrounded by a 0.3-meter wide metal frame, with rusted rivets every 0.15 meters.
### 23. The outer wall is made of stacked horizontal plates, each 0.2 meters tall, creating a layered texture.
### 24. The roof is constructed from 12 triangular metal plates arranged in a circular fan.
### 25. The top of the structure has a small, weathered bell, 0.3 meters in diameter, hanging 0.2 meters below the peak.
### 26. The structure has no internal doors or windows, only the lantern window and the staircase.
### 27. The base has a 0.4-meter wide hollow in the center, filled with a small collection of seashells.
### 28. The staircase is built with 12 steps, each 0.2 meters wide and 0.15 meters deep.
### 29. The outer wall is asymmetrical, with a 0.1-meter bulge on the left side due to wind erosion.
### 30. The overall silhouette is that of a vertical beacon, distinct from any other landmark on the island.

### C. Exterior Surface Detail (features 31–60)

### 31. The base is covered in barnacles, 0.03 meters in diameter, arranged in clusters.
### 32. The wooden planks are painted with a weathered red-brown hue, with 10% of the surface cracked.
### 33. The lantern window frame is a dark metal, rusted, with rivets spaced 0.15 meters apart.
### 34. A small carved symbol of a shipwrecked anchor is embedded in the base, 0.1 meters in diameter.
### 35. The roof has a layer of moss, 0.02 meters thick, patchy in appearance.
### 36. A cracked glass panel, 0.5 meters wide, is mounted in the lantern window.
### 37. The staircase is made of weathered oak, with 30% of the steps worn smooth.
### 38. A banner, 0.8 meters long and 0.1 meters wide, is mounted on the base with a metal rod.
### 39. The outer wall has a small rusted metal patch, 0.05 meters square, with a 0.02-meter diameter hole.
### 40. A small seashell collection is embedded in the base, 0.05 meters deep.
### 41. The roof’s metal plates have a slight dent on one side, 0.02 meters deep.
### 42. A small rusted metal hook, 0.05 meters in length, is mounted near the base.
### 43. A few cracks run vertically down the main cylinder, 0.01 meters wide, 2.5 meters long.
### 44. A small carved face, 0.1 meters in diameter, is visible on the base near the anchor symbol.
### 45. The base has a 0.2-meter wide groove filled with sand and algae.
### 46. The lantern window is surrounded by a metal ring, 0.03 meters thick, with a 0.1-meter diameter.
### 47. The staircase has a handrail made of rough wood, 0.04 meters thick, 1.2 meters long.
### 48. A small bronze plaque, 0.08 meters wide, is mounted near the base.
### 49. The top of the roof has a small metal rod, 0.02 meters thick, 0.5 meters long.
### 50. The structure has a few small holes, 0.02 meters in diameter, in the base, filled with sand.
### 51. The outer wall has a small patch of green moss, 0.05 meters wide, 0.1 meters long.
### 52. A small carved glyph, 0.05 meters in diameter, is visible near the lantern window.
### 53. The staircase steps have small metal nails, 0.01 meters long, protruding at the edge.
### 54. The base has a small embedded compass rose, 0.04 meters in diameter.
### 55. The base has a small patch of green algae, 0.02 meters wide, 0.05 meters long.
### 56. The roof’s metal plates are partially oxidized, with a 0.01-meter thick rust layer.
### 57. A small piece of driftwood is embedded in the base, 0.05 meters in diameter.
### 58. A small metal rod, 0.01 meters thick, is embedded near the lantern window.
### 59. The outer wall has a 0.02-meter wide crack, 0.3 meters long, running horizontally.
### 60. The lantern window has a small piece of cracked glass, 0.01 meters thick, 0.05 meters wide.

### D. Internal / Sub-Volume Detail (features 61–90)

### 61. The interior of the main cylinder is hollow, 0.8 meters in diameter, with a 0.2-meter thick wall.
### 62. The spiral staircase is 1.2 meters wide, with 12 evenly spaced steps.
### 63. The staircase is made of rough oak, 0.03 meters thick, and 0.15 meters deep.
### 64. A small metal rod, 0.01 meters thick, is embedded in the inner wall of the staircase.
### 65. The lantern window is 1.8 meters in diameter, with a 0.05-meter thick glass panel.
### 66. The interior of the base has a 0.2-meter wide hollow, filled with seashells.
### 67. A small metal rod, 0.02 meters thick, is mounted in the center of the base.
### 68. The staircase has a small metal hook, 0.01 meters thick, for hanging tools.
### 69. A small wooden shelf, 0.2 meters wide, 0.05 meters deep, is mounted in the wall.
### 70. A small metal box, 0.05 meters wide, 0.05 meters deep, is mounted near the base.
### 71. The base has a 0.05-meter wide hollow, filled with sand.
### 72. The staircase has a 0.03-meter wide gap between steps, allowing water to drain.
### 73. The inner wall of the main cylinder has a small carved symbol, 0.03 meters in diameter.
### 74. A small wooden rod, 0.01 meters thick, is mounted on the inner wall.
### 75. The lantern window has a small metal frame, 0.01 meters thick, with a 0.02-meter wide opening.
### 76. The base has a small metal rod, 0.02 meters thick, embedded in the center.
### 77. A small metal plate, 0.03 meters in diameter, is embedded in the inner wall.
### 78. A small wooden rod, 0.02 meters thick, is mounted on the staircase.
### 79. The inner wall of the main cylinder has a small hole, 0.01 meters in diameter, for air circulation.
### 80. A small metal rod, 0.01 meters thick, is mounted on the inner wall near the lantern window.
### 81. The staircase has a 0.03-meter wide gap between steps for drainage.
### 82. The lantern window is surrounded by a metal ring, 0.02 meters thick, with a 0.03-meter diameter.
### 83. A small wooden rod, 0.01 meters thick, is embedded in the base.
### 84. A small metal plate, 0.02 meters in diameter, is mounted in the inner wall.
### 85. The staircase has a small metal hook, 0.01 meters thick, for hanging a lantern.
### 86. The base has a small metal rod, 0.02 meters thick, mounted near the center.
### 87. A small wooden rod, 0.01 meters thick, is mounted on the base.
### 88. The lantern window has a 0.02-meter thick metal frame with a 0.03-meter wide opening.
### 89. The staircase has a small metal rod, 0.01 meters thick, mounted on the wall.
### 90. The inner wall has a small carved symbol, 0.03 meters in diameter, visible at 5 meters.

### E. Decoration & Props (features 91–120)

### 91. A small bronze plaque, 0.08 meters wide, is mounted near the base.
### 92. A wooden lantern, 0.2 meters wide, 0.1 meters deep, is mounted near the base.
### 93. A small metal hook, 0.05 meters long, is mounted near the base.
### 94. A wooden shelf, 0.2 meters wide, 0.05 meters deep, is mounted in the wall.
### 95. A small metal box, 0.05 meters wide, 0.05 meters deep, is mounted near the base.
### 96. A small driftwood piece, 0.05 meters in diameter, is embedded in the base.
### 97. A small metal rod, 0.01 meters thick, is mounted near the lantern window.
### 98. A small metal plate, 0.03 meters in diameter, is mounted in the inner wall.
### 99. A small wooden rod, 0.02 meters thick, is mounted on the base.
### 100. A small metal hook, 0.01 meters thick, is mounted on the staircase.
### 101. A small wooden rod, 0.01 meters thick, is mounted on the inner wall.
### 102. A small metal rod, 0.02 meters thick, is mounted in the base.
### 103. A small wooden shelf, 0.1 meters wide, 0.03 meters deep, is mounted near the lantern window.
### 104. A small metal plate, 0.02 meters in diameter, is mounted on the base.
### 105. A small wooden rod, 0.01 meters thick, is embedded in the base.
### 106. A small metal rod, 0.02 meters thick, is mounted near the lantern window.
### 107. A small wooden lantern, 0.1 meters wide, 0.05 meters deep, is mounted on the base.
### 108. A small metal hook, 0.01 meters thick, is mounted on the inner wall.
### 109. A small metal rod, 0.01 meters thick, is mounted on the staircase.
### 110. A small wooden rod, 0.02 meters thick, is mounted on the inner wall.
### 111. A small metal plate, 0.03 meters in diameter, is mounted on the staircase.
### 112. A small wooden shelf, 0.2 meters wide, 0.04 meters deep, is mounted on the base.
### 113. A small metal rod, 0.02 meters thick, is mounted near the base.
### 114. A small wooden lantern, 0.15 meters wide, 0.06 meters deep, is mounted on the staircase.
### 115. A small metal hook, 0.01 meters thick, is mounted near the lantern window.
### 116. A small wooden rod, 0.01 meters thick, is mounted on the base.
### 117. A small metal plate, 0.02 meters in diameter, is mounted on the base.
### 118. A small wooden shelf, 0.1 meters wide, 0.03 meters deep, is mounted on the inner wall.
### 119. A small metal rod, 0.02 meters thick, is mounted in the staircase.
### 120. A small wooden lantern, 0.1 meters wide, 0.05 meters deep, is mounted on the inner wall.

### F. Surrounding Environment (features 121–140)

### 121. The ground beneath the lighthouse is a mix of sand and pebbles, 0.05 meters deep.
### 122. A narrow plank walkway, 0.1 meters wide, connects the lighthouse to Lantern Hold.
### 123. The walkway is made of weathered wood, 0.02 meters thick, 0.1 meters wide.
### 124. A small pile of driftwood, 0.1 meters in diameter, is located near the base.
### 125. A small metal rod, 0.02 meters thick, is embedded in the walkway.
### 126. The surrounding water is calm, with occasional ripples from the wind.
### 127. A small metal hook, 0.01 meters thick, is mounted on the walkway.
### 128. A small wooden shelf, 0.1 meters wide, 0.03 meters deep, is mounted on the walkway.
### 129. A small metal plate, 0.02 meters in diameter, is mounted on the walkway.
### 130. A small driftwood piece, 0.05 meters in diameter, is embedded in the walkway.
### 131. A small metal rod, 0.01 meters thick, is mounted on the walkway.
### 132. A small wooden lantern, 0.1 meters wide, 0.05 meters deep, is mounted on the walkway.
### 133. A small metal hook, 0.01 meters thick, is mounted on the walkway.
### 134. A small wooden shelf, 0.1 meters wide, 0.03 meters deep, is mounted on the walkway.
### 135. A small metal plate, 0.02 meters in diameter, is mounted on the walkway.
### 136. A small driftwood piece, 0.05 meters in diameter, is embedded in the walkway.
### 137. A small metal rod, 0.01 meters thick, is mounted on the walkway.
### 138. A small wooden lantern, 0.1 meters wide, 0.05 meters deep, is mounted on the walkway.
### 139. A small metal hook, 0.01 meters thick, is mounted on the walkway.
### 140. A small wooden shelf, 0.1 meters wide, 0.03 meters deep, is mounted on the walkway.

### G. Materials & Shaders (features 141–160)

### 141. The base uses uBase marker 0 with a shader that mixes `mix(rock_warm, rock_cool, sin(time * 0.5))`.
### 142. The outer wall uses uBase marker 47 with a shader that mixes `mix(mossy_stone, accent_pearl, fbm(pos, 0.5))`.
### 143. The lantern window uses uBase marker 8 with a shader that mixes `mix(ember_lantern, glass, sin(time * 0.3))`.
### 144. The roof uses uBase marker 49 with a shader that mixes `mix(rock_warm, rock_cool, fbm(pos, 0.8))`.
### 145. The staircase uses uBase marker 0 with a shader that mixes `mix(wood_brown, wood_dark, sin(time * 0.2))`.
### 146. The base uses uBase marker 8 with a shader that mixes `mix(rock_warm, mossy_stone, fbm(pos, 0.3))`.
### 147. The outer wall uses uBase marker 56 with a shader that mixes `mix(rock_cool, accent_pearl, sin(time * 0.4))`.
### 148. The lantern window uses uBase marker 0 with a shader that mixes `mix(glass, ember_lantern, sin(time * 0.6))`.
### 149. The roof uses uBase marker 57 with a shader that mixes `mix(rock_cool, rock_warm, fbm(pos, 0.7))`.
### 150. The staircase uses uBase marker 8 with a shader that mixes `mix(wood_dark, wood_brown, fbm(pos, 0.4))`.
### 151. The base uses uBase marker 47 with a shader that mixes `mix(mossy_stone, rock_warm, sin(time * 0.1))`.
### 152. The outer wall uses uBase marker 0 with a shader that mixes `mix(rock_cool, rock_warm, fbm(pos, 0.6))`.
### 153. The lantern window uses uBase marker 49 with a shader that mixes `mix(glass, ember_lantern, fbm(pos, 0.2))`.
### 154. The roof uses uBase marker 56 with a shader that mixes `mix(rock_warm, mossy_stone, sin(time * 0.5))`.
### 155. The staircase uses uBase marker 57 with a shader that mixes `mix(wood_brown, wood_dark, sin(time * 0.3))`.
### 156. The base uses uBase marker 49 with a shader that mixes `mix(rock_cool, rock_warm, fbm(pos, 0.9))`.
### 157. The outer wall uses uBase marker 8 with a shader that mixes `mix(mossy_stone, accent_pearl, sin(time * 0.7))`.
### 158. The lantern window uses uBase marker 0 with a shader that mixes `mix(ember_lantern, glass, sin(time * 0.8))`.
### 159. The roof uses uBase marker 57 with a shader that mixes `mix(rock_warm, rock_cool, fbm(pos, 0.4))`.
### 160. The staircase uses uBase marker 47 with a shader that mixes `mix(wood_dark, wood_brown, fbm(pos, 0.5))`.

### H. Lighting & Atmosphere (features 161–180)

### 161. The lighthouse beam is visible from 400 meters away, with a rotating amber-orange hue.
### 162. The beam is 10 meters wide at 400 meters, 2 meters wide at 100 meters.
### 163. The beam flickers every 0.5 seconds with a 0.1-second duration of light.
### 164. The beam is strongest at 10 meters, fading out to 0.1 at 400 meters.
### 165. The lantern window emits a soft inner glow, 0.2 meters wide, 0.3 meters high.
### 166. The base has a small glow, 0.1 meters wide, 0.2 meters high, with a blue-green hue.
### 167. The outer wall has a subtle shimmer, 0.05 meters wide, 0.1 meters high, with a mossy green hue.
### 168. The roof has a soft glow, 0.1 meters wide, 0.15 meters high, with a rusted metal hue.
### 169. The staircase has a warm glow, 0.1 meters wide, 0.1 meters high, with a wooden hue.
### 170. The beam is affected by fog, with a 0.3-meter radius of diffusion.
### 171. The beam is visible during both day and night, with a 0.5-second delay during dusk.
### 172. The lantern window has a soft inner glow, 0.2 meters wide, 0.3 meters high, with a flickering effect.
### 173. The base has a subtle glow, 0.1 meters wide, 0.2 meters high, with a mossy green hue.
### 174. The outer wall has a soft shimmer, 0.05 meters wide, 0.1 meters high, with a rusted metal hue.
### 175. The roof has a warm glow, 0.1 meters wide, 0.15 meters high, with a wooden hue.
### 176. The staircase has a soft inner glow, 0.1 meters wide, 0.1 meters high, with a blue-green hue.
### 177. The beam is visible in all weather, with a 0.2-meter radius of diffusion during rain.
### 178. The beam is affected by wind, with a 0.1-meter sway every 2 seconds.
### 179. The base has a soft inner glow, 0.1 meters wide, 0.2 meters high, with a wooden hue.
### 180. The lantern window has a soft inner glow, 0.2 meters wide, 0.3 meters high, with a flickering effect.

### I. Animation, FX, and Sound Design (features 181–195)

### 181. The lighthouse beam rotates 360 degrees every 10 seconds with a 0.5-second transition.
### 182. The beam flickers with a 0.1-second pulse every 0.5 seconds.
### 183. A small ember particle system emits from the lantern window every 0.2 seconds.
### 184. A gentle wind causes the base to sway 0.05 meters every 3 seconds.
### 185. A soft creaking sound comes from the wooden staircase every 5 seconds.
### 186. A gentle rustling sound comes from the roof every 2 seconds.
### 187. A low hum from the base sounds every 10 seconds.
### 188. A light splash sound occurs when waves hit the base every 15 seconds.
### 189. A soft whispering sound comes from the wind through the lantern window.
### 190. A low crackling sound comes from the lantern window every 3 seconds.
### 191. A gentle dripping sound from the staircase every 4 seconds.
### 192. A soft wind chime sound comes from the bell every 10 seconds.
### 193. A distant howl sound occurs every 20 seconds.
### 194. A soft splash sound occurs when water drips from the roof.
### 195. A gentle creaking sound comes from the base every 7 seconds.

### J. Implementation & Engine Hooks (features 196–200)

### 196. The mesh uses 3500 triangles, with 2000 in the main cylinder and 1500 in the roof.
### 197. The mesh is built in `ios/Mesh.swift` using the function `makeLighthouseAnchor(device:)`.
### 198. The mesh is a single draw call with no subdivision.
### 199. The asset requires an addition to `world.team` switch in `src/main.zig` with `case 78`.
### 200. The dispatch case in `ios/GameViewController.swift` is `case 78: return lighthouseAnchorMesh`.
---

## Asset 150 — tethered_sky_garden (Hero Landmark, isles)
### A. Concept & Silhouette (features 1–10)
### 1. This is a floating crystal garden suspended 30 meters above the Skywatch plaza, visible from 80m distance, designed to be memorable and distinct from other landmarks.
### 2. The silhouette from 30m shows a complex spiral staircase leading upward with a central pearl sphere fountain, surrounded by glowing chains and bioluminescent vines.
### 3. From 10m, the full form includes a circular platform with a large central sphere, glowing chains, and a spiraling staircase, all visible from all angles.
### 4. The lore hook is that this garden is a sacred site of the skywatchers, where they meditate and perform rituals under the stars.
### 5. The mood is one of serene wonder, with an ethereal quality that makes it feel otherworldly and magical.
### 6. It appears in the skywatcher's time-of-day cycle with a soft blue glow during dusk and a faint golden hue during dawn.
### 7. The visibility from Skywatch's origin point (-120, 60, -560) is strong, and it should not be confused with any other floating structure.
### 8. The scale anchor is the central pearl sphere fountain, which is 3.2 meters in diameter, and is roughly 1.5x player height.
### 9. Exact map coordinates are approximately (-120, 150, -560), with a y_offset of +90 from Skywatch's base.
### 10. It should not be confused with the Skywatch's main tower or any other floating structures in the isles zone.

### B. Form & Major Mass (features 11–30)
### 11. The primary volume is a circular platform made of interlocking crystal slabs, approximately 20 meters in diameter.
### 12. The platform is slightly tilted, with a 3-degree lean toward the north, giving it a dynamic feel.
### 13. A central pearl-sphere fountain is embedded in the platform, rising 3.2 meters high from the surface.
### 14. The platform has a raised edge that is 0.8 meters high, forming a barrier to prevent items from falling off.
### 15. A spiral staircase wraps around the central fountain, 1.8 meters wide, leading upward to the top.
### 16. The staircase is made of interwoven crystal strands, each strand 0.15 meters wide, forming a spiraling staircase.
### 17. The staircase is composed of 12 segments, each 20 degrees in rotation, forming a full 240-degree spiral.
### 18. The platform is connected to the skywatch by a series of glowing chains, 3 in total, spaced evenly around the platform.
### 19. The chains are made of crystal links, each 0.3 meters in length, with a total length of 25 meters each.
### 20. The chains are suspended 1.2 meters below the platform, creating a dramatic visual effect.
### 21. The chains are connected to a central crystal anchor, 1.5 meters in diameter, embedded into the skywatch.
### 22. The platform has several small openings, each 0.5 meters in diameter, with carved edges.
### 23. The platform is hollowed out in the center, forming a circular depression 1.2 meters in diameter.
### 24. The outer edge of the platform has a series of 16 evenly spaced holes, each 0.2 meters in diameter.
### 25. The platform is decorated with bioluminescent vines that drape down from the edges, 0.3 meters in width.
### 26. The vines are made of interwoven crystal strands, each 0.1 meters wide, forming a continuous drape.
### 27. The vines are attached to the platform at 0.8 meters from the edge, creating a natural curtain.
### 28. The platform has a central hollow, 2.5 meters in diameter, with a depth of 1.5 meters.
### 29. The platform has a series of 8 small crystal pillars, 0.4 meters in diameter, arranged in a circle.
### 30. The pillars are 1.2 meters high, and are evenly spaced 2.5 meters apart.

### C. Exterior Surface Detail (features 31–60)
### 31. The platform is made of interlocking crystal slabs, each 0.8 meters in width and 0.4 meters in height.
### 32. The slabs are arranged in a spiral pattern, with each slab rotated 15 degrees relative to the previous one.
### 33. The surface of the slabs has a fine, crystalline texture with visible growth patterns.
### 34. A carved glyph is embedded in the center of each slab, 0.1 meters in diameter, glowing faintly.
### 35. The edges of the slabs are beveled, creating a subtle 10-degree angle.
### 36. A series of small cracks run along the edges of the slabs, 0.05 meters deep.
### 37. The surface of the platform is covered with a fine layer of moss, 0.02 meters thick.
### 38. The moss is of varying shades of kelp_green and sea-glass clear.
### 39. A series of small holes are scattered across the surface, 0.05 meters in diameter.
### 40. The holes are filled with glowing crystals, 0.03 meters in diameter.
### 41. The platform’s surface is polished to a high shine, reflecting ambient light.
### 42. A series of small carved symbols are arranged in a spiral pattern on the surface.
### 43. Each symbol is 0.1 meters in diameter, and is embedded in the crystal.
### 44. The platform has a series of small bumps, 0.03 meters in height, arranged randomly.
### 45. The bumps are evenly spaced 0.2 meters apart.
### 46. The surface of the platform is covered with a thin layer of mist, 0.01 meters thick.
### 47. The mist is concentrated in the center, gradually thinning toward the edges.
### 48. The platform is surrounded by a series of small crystal shards, 0.05 meters in length.
### 49. The shards are embedded in the edges of the platform, creating a jagged border.
### 50. The platform has a series of small carved spirals, 0.05 meters in width, etched into the surface.
### 51. The spirals are 1.5 meters in diameter and are evenly spaced 0.5 meters apart.
### 52. The surface of the platform has a series of small indentations, 0.02 meters in depth.
### 53. The indentations are arranged in a radial pattern, 0.3 meters from the center.
### 54. The platform has a series of small holes, 0.03 meters in diameter, arranged in a circular pattern.
### 55. The holes are evenly spaced 0.4 meters apart.
### 56. The platform has a series of small carved lines, 0.02 meters in width, running across the surface.
### 57. The lines are arranged in a zig-zag pattern, 0.1 meters in height.
### 58. The platform has a series of small carved circles, 0.05 meters in diameter, arranged in a spiral.
### 59. The circles are 0.5 meters in diameter and are evenly spaced 0.3 meters apart.
### 60. The platform has a series of small carved triangles, 0.03 meters in width, arranged in a fan pattern.

### D. Internal / Sub-Volume Detail (features 61–90)
### 61. The central fountain is hollow, with a 1.8-meter diameter cavity in the center.
### 62. The cavity is filled with a swirling mist that glows faintly in the center.
### 63. The fountain has a series of small crystal channels, 0.03 meters in width, running from the base to the top.
### 64. The channels are connected to a small reservoir at the base of the fountain.
### 65. The fountain has a series of small carved glyphs, 0.1 meters in diameter, arranged in a spiral.
### 66. The glyphs are embedded in the crystal walls of the fountain.
### 67. The fountain has a small opening at the top, 0.2 meters in diameter, from which mist escapes.
### 68. The opening is surrounded by a series of small crystals, 0.02 meters in diameter.
### 69. The fountain has a series of small carved spirals, 0.05 meters in width, etched into the walls.
### 70. The spirals are 1.2 meters in diameter and are evenly spaced 0.3 meters apart.
### 71. The fountain is surrounded by a small crystal ring, 0.2 meters in width, embedded in the platform.
### 72. The ring is 1.5 meters in diameter and is evenly spaced 0.3 meters from the edge.
### 73. The fountain has a small reservoir at the base, 0.5 meters in diameter.
### 74. The reservoir is filled with a mixture of glowing crystals and mist.
### 75. The fountain has a series of small holes, 0.03 meters in diameter, arranged in a radial pattern.
### 76. The holes are evenly spaced 0.3 meters apart.
### 77. The fountain has a series of small carved lines, 0.02 meters in width, running vertically.
### 78. The lines are arranged in a spiral pattern, 0.2 meters in height.
### 79. The fountain has a small crystal anchor, 0.3 meters in diameter, embedded in the base.
### 80. The anchor is connected to the platform by a series of crystal chains.
### 81. The fountain has a small cavity, 0.3 meters in diameter, at the top.
### 82. The cavity is filled with glowing mist and small crystals.
### 83. The fountain has a small carved spiral, 0.05 meters in width, etched into the walls.
### 84. The spiral is 0.8 meters in diameter and is evenly spaced 0.2 meters apart.
### 85. The fountain has a small hole, 0.03 meters in diameter, at the base.
### 86. The hole is connected to a small crystal reservoir.
### 87. The fountain has a small carved circle, 0.05 meters in diameter, arranged in a radial pattern.
### 88. The circle is 0.5 meters in diameter and is evenly spaced 0.3 meters apart.
### 89. The fountain has a small carved triangle, 0.03 meters in width, arranged in a fan pattern.
### 90. The triangle is 0.2 meters in height and is evenly spaced 0.2 meters apart.

### E. Decoration & Props (features 91–120)
### 91. A small crystal lantern is mounted on the edge of the platform, 0.1 meters in diameter.
### 92. The lantern is positioned 0.8 meters from the edge of the platform.
### 93. The lantern emits a soft blue glow, 1.5 meters in radius.
### 94. A small crystal vase is placed on the platform, 0.2 meters in diameter.
### 95. The vase is positioned 0.5 meters from the center of the platform.
### 96. The vase is filled with glowing crystals, 0.05 meters in diameter.
### 97. A small crystal bowl is placed on the platform, 0.15 meters in diameter.
### 98. The bowl is positioned 0.3 meters from the center of the platform.
### 99. The bowl is filled with a mixture of glowing mist and small crystals.
### 100. A small crystal statue is placed on the platform, 0.3 meters in height.
### 101. The statue is positioned 1 meter from the edge of the platform.
### 102. The statue is carved from a single piece of crystal, with a glowing core.
### 103. A small crystal chalice is placed on the platform, 0.1 meters in diameter.
### 104. The chalice is positioned 0.6 meters from the center of the platform.
### 105. The chalice is filled with glowing mist.
### 106. A small crystal bell is placed on the platform, 0.1 meters in diameter.
### 107. The bell is positioned 0.4 meters from the edge of the platform.
### 108. The bell emits a soft chime when touched.
### 109. A small crystal book is placed on the platform, 0.1 meters in diameter.
### 110. The book is positioned 0.7 meters from the center of the platform.
### 111. The book is carved from a single piece of crystal, with glowing text.
### 112. A small crystal candle is placed on the platform, 0.05 meters in diameter.
### 113. The candle is positioned 0.2 meters from the edge of the platform.
### 114. The candle emits a soft glow, 1 meter in radius.
### 115. A small crystal flower is placed on the platform, 0.05 meters in diameter.
### 116. The flower is positioned 0.3 meters from the center of the platform.
### 117. The flower is carved from a single piece of crystal, with a glowing core.
### 118. A small crystal shell is placed on the platform, 0.1 meters in diameter.
### 119. The shell is positioned 0.4 meters from the center of the platform.
### 120. The shell is filled with glowing mist and small crystals.

### F. Surrounding Environment (features 121–140)
### 121. The ground texture around the asset is a soft moss-covered stone.
### 122. The moss is of varying shades of kelp_green and sea-glass clear.
### 123. The ground is slightly uneven, with small bumps and dips.
### 124. A series of small crystal shards are scattered around the base of the platform.
### 125. The shards are 0.05 meters in length and are embedded in the ground.
### 126. A small crystal anchor is embedded in the ground, 0.3 meters in diameter.
### 127. The anchor is connected to the platform by a series of crystal chains.
### 128. A series of small crystal pillars, 0.2 meters in diameter, are arranged in a circle.
### 129. The pillars are 0.8 meters high and are evenly spaced 0.5 meters apart.
### 130. The pillars are carved with glowing glyphs, 0.1 meters in diameter.
### 131. A small crystal ring, 0.2 meters in width, is embedded in the ground.
### 132. The ring is 1.5 meters in diameter and is evenly spaced 0.3 meters from the edge.
### 133. The ground is covered with a thin layer of mist, 0.01 meters thick.
### 134. The mist is concentrated near the base of the platform, gradually thinning outward.
### 135. A series of small holes, 0.05 meters in diameter, are scattered across the ground.
### 136. The holes are filled with glowing crystals, 0.03 meters in diameter.
### 137. A small crystal statue is placed on the ground, 0.3 meters in height.
### 138. The statue is positioned 1 meter from the edge of the platform.
### 139. The statue is carved from a single piece of crystal, with a glowing core.
### 140. The ground is surrounded by a series of small crystal shards, 0.05 meters in length.

### G. Materials & Shaders (features 141–160)
### 141. The main platform surface uses uBase marker 0, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.5, 0.9, 0.8)` using `sin(time)` for a subtle shimmer.
### 142. The central fountain uses uBase marker 8, with a shader that mixes `float3(0.8, 0.9, 0.9)` and `float3(0.2, 0.8, 0.9)` using `fbm(pos * 2.0)` for a flowing texture.
### 143. The spiral staircase uses uBase marker 47, with a shader that mixes `float3(0.2, 0.7, 0.9)` and `float3(0.3, 0.8, 0.9)` using `mix(sin(pos.x * 3.0), cos(pos.y * 3.0), 0.5)` for a dynamic glow.
### 144. The glowing chains use uBase marker 53, with a shader that mixes `float3(0.1, 0.9, 0.9)` and `float3(0.9, 0.9, 0.2)` using `sin(pos.z * 2.0)` for a pulsing effect.
### 145. The bioluminescent vines use uBase marker 54, with a shader that mixes `float3(0.1, 0.8, 0.7)` and `float3(0.2, 0.9, 0.8)` using `fbm(pos * 3.0)` for a subtle bioluminescence.
### 146. The crystal pillars use uBase marker 55, with a shader that mixes `float3(0.3, 0.8, 0.9)` and `float3(0.1, 0.9, 0.9)` using `mix(cos(pos.x), sin(pos.y), 0.3)` for a reflective shimmer.
### 147. The crystal slabs use uBase marker 56, with a shader that mixes `float3(0.2, 0.8, 0.8)` and `float3(0.4, 0.9, 0.8)` using `sin(pos.z * 2.0)` for a subtle ripple.
### 148. The crystal shards use uBase marker 59, with a shader that mixes `float3(0.5, 0.9, 0.9)` and `float3(0.1, 0.9, 0.9)` using `fbm(pos * 4.0)` for a rough texture.
### 149. The crystal anchors use uBase marker 61, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.2, 0.9, 0.8)` using `mix(sin(pos.x * 2.0), cos(pos.z * 2.0), 0.4)` for a dynamic shine.
### 150. The crystal reservoirs use uBase marker 62, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.3, 0.9, 0.9)` using `sin(pos.y * 3.0)` for a glowing core.
### 151. The lanterns use uBase marker 0, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.2, 0.9, 0.9)` using `fbm(pos * 2.0)` for a soft glow.
### 152. The crystal vases use uBase marker 8, with a shader that mixes `float3(0.2, 0.8, 0.9)` and `float3(0.3, 0.9, 0.9)` using `mix(cos(pos.x), sin(pos.z), 0.5)` for a flowing texture.
### 153. The crystal bowls use uBase marker 47, with a shader that mixes `float3(0.1, 0.9, 0.9)` and `float3(0.2, 0.8, 0.9)` using `sin(pos.y * 2.0)` for a subtle ripple.
### 154. The crystal statues use uBase marker 53, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.3, 0.9, 0.9)` using `fbm(pos * 3.0)` for a reflective shimmer.
### 155. The crystal chalices use uBase marker 54, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.2, 0.9, 0.9)` using `mix(sin(pos.x), cos(pos.y), 0.3)` for a dynamic glow.
### 156. The crystal bells use uBase marker 55, with a shader that mixes `float3(0.1, 0.9, 0.9)` and `float3(0.2, 0.8, 0.9)` using `sin(pos.z * 2.0)` for a subtle ripple.
### 157. The crystal books use uBase marker 56, with a shader that mixes `float3(0.2, 0.8, 0.9)` and `float3(0.3, 0.9, 0.9)` using `fbm(pos * 4.0)` for a rough texture.
### 158. The crystal candles use uBase marker 59, with a shader that mixes `float3(0.1, 0.8, 0.9)` and `float3(0.2, 0.9, 0.9)` using `mix(cos(pos.x), sin(pos.z), 0.5)` for a glowing core.
### 159. The crystal flowers use uBase marker 61, with a shader that mixes `float3(0.1, 0.9, 0.9)` and `float3(0.2, 0.8, 0.9)` using `sin(pos.y * 2.0)` for a subtle shimmer.
### 160. The crystal shells use uBase marker 62, with a shader that mixes `float3(0.2, 0.8, 0.9)` and `float3(0.1, 0.9, 0.9)` using `fbm(pos * 3.0)` for a flowing texture.

### H. Lighting & Atmosphere (features 161–180)
### 161. The platform emits a soft blue glow, 1.5 meters in radius, from the central fountain.
### 162. The glowing chains cast a soft blue glow, 2 meters in radius, around the platform.
### 163. The bioluminescent vines cast a faint green glow, 1 meter in radius, around the edges.
### 164. The mist clings to the underside of the platform, creating a soft, ethereal haze.
### 165. The atmosphere is thick with a soft, blue mist that gradually fades toward the edges.
### 166. A gentle light beam projects from the top of the platform, 2 meters in radius, with a soft blue hue.
### 167. The platform’s surface reflects ambient light from the sky, creating a soft, shimmering effect.
### 168. A subtle light arc emanates from the base of the platform, 1 meter in radius, with a soft blue hue.
### 169. The glowing glyphs on the platform emit a soft, pulsing light, 0.5 meters in radius.
### 170. The air around the platform is filled with soft, floating particles, 0.02 meters in diameter.
### 171. The particles glow faintly with a blue hue and move slowly in the air.
### 172. A soft, blue light flickers across the platform, with a frequency of 0.5 Hz.
### 173. The platform is surrounded by a soft, golden glow during dawn, 1.5 meters in radius.
### 174. The platform is surrounded by a soft, blue glow during dusk, 2 meters in radius.
### 175. The mist on the platform’s surface changes color subtly from blue to green as the time of day progresses.
### 176. The platform emits a soft, golden light from the central fountain during dawn.
### 177. The platform emits a soft, blue light from the central fountain during dusk.
### 178. The platform is surrounded by a soft, white light that flickers gently in the air.
### 179. The platform’s surface reflects light from the surrounding environment, creating a shimmering effect.
### 180. A soft, blue light beam projects from the top of the platform, 1.5 meters in radius, during night.

### I. Animation, FX, and Sound Design (features 181–195)
### 181. The central fountain emits a soft, swirling mist that gently moves and changes shape.
### 182. The glowing chains pulse gently with a soft blue light, 0.3 Hz.
### 183. The bioluminescent vines sway gently in the wind, 0.2 Hz.
### 184. Soft particle emitters generate `sky_garden_motes` from the platform’s surface, 100 particles per second.
### 185. The mist clings to the platform’s surface, gently flowing and changing shape.
### 186. The glowing glyphs on the platform flicker gently, 0.5 Hz.
### 187. The platform emits a soft, harmonic chime from the crystal bell every 5 seconds.
### 188. The crystal chalice gently glows with a soft blue light, 0.2 Hz.
### 189. The crystal candle flickers gently, 0.4 Hz, with a warm glow.
### 190. The crystal flower gently pulses with a soft green light, 0.3 Hz.
### 191. The crystal shell emits a soft, glowing light, 0.1 Hz.
### 192. The crystal statue gently sways and glows, 0.1 Hz.
### 193. The crystal book gently glows with a soft blue light, 0.2 Hz.
### 194. The crystal vases gently glow with a soft green light, 0.1 Hz.
### 195. The crystal bowls gently glow with a soft blue light, 0.1 Hz.

### J. Implementation & Engine Hooks (features 196–200)
### 196. The total tri-budget is 4000 tris.
### 197. The mesh builder strategy in `ios/Mesh.swift` uses `makeTetheredSkyGarden(device:)`.
### 198. The mesh is constructed using `mbSphere`, `mbCylinder`, and `mbRing` helpers.
### 199. The draw-call decomposition uses a single mesh with multiple sub-meshes for each major component.
### 200. The `world.team` switch in `src/main.zig` requires a new case for team 71, and dispatch in `ios/GameViewController.swift` includes a new `tethered_sky_garden` case.
---

