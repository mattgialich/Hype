#!/usr/bin/env python3
"""Cross-cutting audit of docs/drifting_isles.md (Zone 3).

Same shape as desert_doc_audit.py but with Isles-allocated ranges.
"""
import re, pathlib, sys, collections

DOC = pathlib.Path("docs/drifting_isles.md")
if not DOC.exists():
    print(f"  ✗ {DOC} not found"); sys.exit(2)
text = DOC.read_text()

# Canonical ranges for the Isles
ISLES_MESH = set(range(67, 142))  # 67..141
ISLES_UBASE_FREE = set(range(45, 50)) | set(range(51, 60)) | set(range(61, 70)) | {0, 8}
FOREST_DESERT_UBASE = {0,1,2,8,10,11,12,13,14,20,21,25,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,50,60,70,80}
ISLES_TEAMS = {1} | set(range(53, 80))
PALETTE = set()  # populated dynamically from §3 if present

errors, warnings = [], []
seen_meshes = set()

# extract palette names from a §3 table if present
m = re.search(r"## §3\.[^\n]*Palette\s*\n(?:[^\n]*\n){1,40}", text)
if m:
    palette_block = m.group(0)
    PALETTE = set(re.findall(r"`([a-z_]+)`", palette_block))

# ── 1. Per-section uBase audit ────────────────────────────────────────────
sections = re.split(r"^## (Enemy \d+ — \w+|Asset \d+ — \w+)$", text, flags=re.M)
for i in range(1, len(sections), 2):
    title = sections[i]; body = sections[i+1]
    m = re.match(r"(Enemy|Asset) (\d+) — (\w+)", title)
    if not m: continue
    kind, mid, name = m.groups()
    mid = int(mid)
    seen_meshes.add(mid)
    if mid not in ISLES_MESH:
        errors.append(f"{kind} {mid} ({name}): mesh_id outside isles range 67..141")

    sec5 = re.search(r"###\s*[45]\.[^\n]*uBase[^\n]*\n((?:.+\n)+?)\s*###\s*[56]\.",
                     body, flags=re.I)
    if sec5:
        uvals = set(int(x) for x in re.findall(r"\|\s*(\d+)\s*\|", sec5.group(1)))
        bad_prior = uvals & (FOREST_DESERT_UBASE - ISLES_UBASE_FREE)
        bad_other = uvals - ISLES_UBASE_FREE - FOREST_DESERT_UBASE
        if bad_prior:
            errors.append(f"{kind} {mid} ({name}): uBase {sorted(bad_prior)} collides with forest/desert")
        elif bad_other:
            warnings.append(f"{kind} {mid} ({name}): uBase {sorted(bad_other)} not in isles allocation")

# ── 2. Mesh-ID coverage (10 enemies + 64 assets + 1 boundary = 75 IDs) ───
expected = set(range(67, 142))
missing = expected - seen_meshes
extra   = seen_meshes - expected
if missing: errors.append(f"missing mesh sections: {sorted(missing)}")
if extra:   errors.append(f"unexpected mesh ids: {sorted(extra)}")

# ── 3. Palette word audit ────────────────────────────────────────────────
if PALETTE:
    candidates = re.findall(r"`?([a-z_]+)`?\s*\(0\.[0-9]+,\s*0\.[0-9]+,\s*0\.[0-9]+\)", text)
    unknown = [c for c in candidates if c not in PALETTE]
    if unknown:
        bad = collections.Counter(unknown).most_common(5)
        warnings.append(f"non-standard palette swatch names mentioned: {bad}")
else:
    warnings.append("could not extract §3 palette swatches — skipping palette audit")

# ── 4. Spawn-count totals (table after §4 mesh-ID assignment) ────────────
table = re.search(r"\|\s*mesh_id\s*\|.*?\n((?:\|[^\n]+\n)+)", text)
if table:
    rows = re.findall(r"\|\s*(\d+)\s*\|\s*([\w_]+)\s*\|[^|]+\|\s*\d+\s*\|\s*(\d+)\s*\|",
                      table.group(1))
    total = sum(int(c) for _,_,c in rows)
    print(f"  Foundation roster total spawn count: {total}  (cap 8192; needs MAX_DRAW bump)")
    if total > 7500:
        errors.append(f"spawn count {total} exceeds 8192 cap minus 700 FX headroom")

# ── 5. lerp() bug grep ───────────────────────────────────────────────────
lerps = re.findall(r"\blerp\s*\(", text)
if lerps: errors.append(f"lerp() found {len(lerps)} time(s) — Metal uses mix()")

# ── 6. Path constants extraction (Isles uses bridges, may not have a single formula) ──
# (lighter check than desert — just ensure §2 mentions 900m radius and 720m path)
if re.search(r"MAP_RADIUS[^\d]+9\d{2}", text) is None:
    warnings.append("§2 may not state MAP_RADIUS=900 cleanly")
if re.search(r"PATH_LEN[^\d]+72\d", text) is None:
    warnings.append("§2 may not state PATH_LEN=720 cleanly")

# ── Summary ──────────────────────────────────────────────────────────────
print()
print(f"  ERRORS:   {len(errors)}")
for e in errors: print(f"    ✗ {e}")
print(f"  WARNINGS: {len(warnings)}")
for w in warnings[:15]: print(f"    ⚠ {w}")
print(f"  Sections audited: {len(seen_meshes)} (expected 75: 10 enemies + 64 assets + 1 boundary*)")
print("  *boundary marker has no per-asset section — only foundation table entry")
sys.exit(1 if errors else 0)
