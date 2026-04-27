#!/usr/bin/env python3
"""Cross-cutting audit of docs/desert_zone.md.

Verifies that every mention of a mesh_id, uBase, team, and palette swatch in any
per-enemy or per-asset section stays within the canonical sets defined in the
foundation tables. Also tallies actual numbers vs claims.
"""
import re, pathlib, sys, collections

DOC = pathlib.Path("docs/desert_zone.md")
text = DOC.read_text()

# Canonical sets
DESERT_MESH = set(range(29, 67))
DESERT_UBASE = {0, 8} | set(range(30, 45))
FOREST_UBASE = {0,1,2,8,10,11,12,13,14,20,21,25,50,60,70,80}
DESERT_TEAMS = {1} | set(range(40, 53))
PALETTE = {"sand_light","sand_dark","dune_shadow","sky_horizon","sky_zenith",
           "rock_warm","rock_cool","dry_vegetation","accent_gold",
           "accent_turquoise","bone_pale","ember_orange"}

errors, warnings = [], []

# ── 1. uBase audit per asset/enemy section ────────────────────────────────
sections = re.split(r"^## (Enemy \d+ — \w+|Asset \d+ — \w+)$", text, flags=re.M)
# split returns [pre, title, body, title, body, ...]
seen_meshes = set()
for i in range(1, len(sections), 2):
    title = sections[i]; body = sections[i+1]
    m = re.match(r"(Enemy|Asset) (\d+) — (\w+)", title)
    if not m: continue
    kind, mid, name = m.groups()
    mid = int(mid)
    seen_meshes.add(mid)
    if mid not in DESERT_MESH:
        errors.append(f"{kind} {mid} ({name}): mesh_id outside desert range 29..66")

    # Find uBase table after "uBase marker assignments"
    sec5 = re.search(r"###\s*[45]\.[^\n]*uBase[^\n]*\n((?:.+\n)+?)\s*###\s*[56]\.",
                     body, flags=re.I)
    if sec5:
        uvals = set(int(x) for x in re.findall(r"\|\s*(\d+)\s*\|", sec5.group(1)))
        bad_forest = uvals & (FOREST_UBASE - DESERT_UBASE)
        bad_other  = uvals - DESERT_UBASE
        if bad_forest:
            errors.append(f"{kind} {mid} ({name}): uBase {sorted(bad_forest)} collides with forest")
        elif bad_other:
            warnings.append(f"{kind} {mid} ({name}): uBase {sorted(bad_other)} not in desert allocation")

# ── 2. Mesh-ID coverage ───────────────────────────────────────────────────
expected = set(range(29, 67))
missing = expected - seen_meshes
extra   = seen_meshes - expected
if missing: errors.append(f"missing mesh sections: {sorted(missing)}")
if extra:   errors.append(f"unexpected mesh ids: {sorted(extra)}")

# ── 3. Palette word audit ────────────────────────────────────────────────
# Find any "palette swatch"-like word that isn't in the official set.
# This is a heuristic — scan for `(0.xx, 0.xx, 0.xx)` and the word right before.
candidates = re.findall(r"`?([a-z_]+)`?\s*\(0\.[0-9]+,\s*0\.[0-9]+,\s*0\.[0-9]+\)", text)
unknown = [c for c in candidates if c not in PALETTE]
if unknown:
    bad = collections.Counter(unknown).most_common(5)
    warnings.append(f"non-standard palette swatch names mentioned: {bad}")

# ── 4. Spawn-count totals ────────────────────────────────────────────────
table = re.search(r"\|\s*mesh_id\s*\|.*?\n((?:\|[^\n]+\n)+)", text)
if table:
    rows = re.findall(r"\|\s*(\d+)\s*\|\s*([\w_]+)\s*\|[^|]+\|\s*\d+\s*\|\s*(\d+)\s*\|",
                      table.group(1))
    total = sum(int(c) for _,_,c in rows)
    print(f"  Foundation roster total spawn count: {total}  (cap 4096; budgeted 2476)")
    if total > 2700:
        errors.append(f"spawn count {total} exceeds budget 2476 (+10% slack = 2724)")

# ── 5. lerp() bug grep ───────────────────────────────────────────────────
lerps = re.findall(r"\blerp\s*\(", text)
if lerps: errors.append(f"lerp() found {len(lerps)} time(s) — Metal uses mix()")

# ── 6. Path constants extraction ─────────────────────────────────────────
m_a = re.search(r"\|\s*A\s*\|.*?\*\*([\d.]+)\*\*", text)
m_w1 = re.search(r"\|\s*ω₁\s*\|.*?\*\*([\d.]+)\*\*", text)
m_b = re.search(r"\|\s*B\s*\|.*?\*\*([\d.]+)\*\*", text)
m_w2 = re.search(r"\|\s*ω₂\s*\|.*?\*\*([\d.]+)\*\*", text)
print(f"  Desert path coefficients from doc: A={m_a.group(1) if m_a else '?'}, "
      f"ω₁={m_w1.group(1) if m_w1 else '?'}, "
      f"B={m_b.group(1) if m_b else '?'}, "
      f"ω₂={m_w2.group(1) if m_w2 else '?'}")

# ── Summary ──────────────────────────────────────────────────────────────
print()
print(f"  ERRORS:   {len(errors)}")
for e in errors: print(f"    ✗ {e}")
print(f"  WARNINGS: {len(warnings)}")
for w in warnings[:10]: print(f"    ⚠ {w}")
print(f"  Sections audited: {len(seen_meshes)} (expected 38: 5 enemies + 32 assets + 1 boundary obelisk*)")
print("  *boundary obelisk has no per-asset section — only foundation table entry")
sys.exit(1 if errors else 0)
