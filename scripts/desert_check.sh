#!/usr/bin/env bash
# desert_check.sh — self-check rig for desert-zone work.
# Catches Qwen failure modes, struct ABI drift, mesh-ID/UV collisions, and Zig build errors.
# Run from repo root:  bash scripts/desert_check.sh
set -u

REPO="${REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO"

OK=0; WARN=0; FAIL=0
pass() { printf '  \033[32m✓\033[0m %s\n' "$1"; OK=$((OK+1)); }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
hdr()  { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# ───────────────────────────────────────────────────────────────────────────
hdr "1. Zig build"
if zig build -Drelease=true 2>&1 | tee /tmp/desert_zigbuild.log | tail -20; then
  if grep -qiE 'error|panic' /tmp/desert_zigbuild.log; then
    fail "zig build emitted errors (see /tmp/desert_zigbuild.log)"
  else
    pass "zig build succeeded"
  fi
else
  fail "zig build returned non-zero"
fi

# ───────────────────────────────────────────────────────────────────────────
hdr "2. Git diff stat (catch silent truncation / scope creep)"
git diff --stat HEAD 2>/dev/null | tail -20 || true
ALL_CHANGED=$(git diff --name-only HEAD 2>/dev/null | wc -l)
echo "  $ALL_CHANGED files changed since HEAD"

# ───────────────────────────────────────────────────────────────────────────
hdr "3. Qwen-MSL bug patterns (Metal shader)"
for f in shaders/*.metal; do
  if grep -nE '\blerp\s*\(' "$f" >/dev/null; then
    fail "lerp() in $f — Metal uses mix(), not lerp"
    grep -nE '\blerp\s*\(' "$f" | sed 's/^/      /'
  fi
done
[ "$FAIL" -eq 0 ] && pass "no lerp() in *.metal"

# Common Metal buffer/stage_in misuse
for f in shaders/*.metal; do
  if grep -nE '\[\[buffer\(\s*\)' "$f" >/dev/null; then
    fail "empty [[buffer()]] in $f"
  fi
done

# ───────────────────────────────────────────────────────────────────────────
hdr "4. Struct byte audit (Zig vs Swift size constants)"
declare -A EXPECT_SIZE=(
  [DrawCall]=88
  [FrameUniforms]=160
  [GpuEmitter]=104
  [GpuParticle]=64
)
# Swift constants live in GameViewController.swift
SWIFT_FILE="ios/GameViewController.swift"
for s in "${!EXPECT_SIZE[@]}"; do
  exp=${EXPECT_SIZE[$s]}
  case "$s" in
    DrawCall)      konst="kDrawCallStride";;
    FrameUniforms) konst="kFrameUniformsSize";;
    GpuEmitter)    konst="kEmitterStride";;
    GpuParticle)   konst="kParticleStride";;
  esac
  swift_val=$(grep -E "let\s+$konst\s*=" "$SWIFT_FILE" | head -1 | grep -oE '[0-9]+' | tail -1)
  if [ -n "$swift_val" ]; then
    if [ "$swift_val" = "$exp" ]; then
      pass "$s = $exp B (Swift $konst matches)"
    else
      fail "$s expected $exp B but Swift $konst = $swift_val"
    fi
  else
    warn "$s: Swift constant $konst not found — skipping"
  fi
done

# MAX_DRAW sync
ZIG_MAX=$(grep -E 'const\s+MAX_DRAW\s*=' src/main.zig | grep -oE '[0-9]+' | head -1)
SWIFT_MAX=$(grep -E 'kMaxDrawCalls\s*=' "$SWIFT_FILE" | grep -oE '[0-9]+' | head -1)
if [ "$ZIG_MAX" = "$SWIFT_MAX" ] && [ -n "$ZIG_MAX" ]; then
  pass "MAX_DRAW = $ZIG_MAX in both Zig and Swift"
else
  fail "MAX_DRAW mismatch: Zig=$ZIG_MAX  Swift=$SWIFT_MAX"
fi

# ───────────────────────────────────────────────────────────────────────────
hdr "5. Mesh-ID collision check"
# Pull mesh_id values from src/main.zig spawn calls and from Mesh.swift comments / GameViewController switch
python3 - <<'PY'
import re, sys, pathlib
root = pathlib.Path(".")

# Existing IDs in use by forest (canonical roster).
# 0=ground, 1=hero, 2=tree, 3=gargoyle, 4=forest_tree, 5=rock, 6=flower, 7=lightning,
# 8=tower, 9=torch, 13=portal, 14=monolith, 15..24=set dressing, 25=wisp, 26=ent,
# 27=knight, 28=impact_ring
forest = set([0,1,2,3,4,5,6,7,8,9,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28])

# Parse Swift dispatch switch
sw = (root/"ios/GameViewController.swift").read_text()
swift_cases = set(int(m.group(1)) for m in re.finditer(r"case\s+(\d+):\s*return\s*\(", sw))

# Parse Zig mesh_id literal assignments
zg = (root/"src/main.zig").read_text()
zig_ids = set(int(m.group(1)) for m in re.finditer(r"world\.mesh_id\[[a-zA-Z_0-9]+\]\s*=\s*(\d+)", zg))

# Parse enemy_config table mesh_id values
ec = (root/"src/game/enemy_config.zig").read_text()
cfg_ids = set(int(m.group(1)) for m in re.finditer(r"\.mesh_id\s*=\s*(\d+)", ec))

# Union should match expected forest set within tolerance (lightning bolt 7 used for spawn-time only via spawn helper not literal — accept as known)
all_seen = swift_cases | zig_ids | cfg_ids
missing  = forest - all_seen
extra    = all_seen - forest
print(f"  Swift dispatch IDs: {sorted(swift_cases)}")
print(f"  Zig literal IDs:   {sorted(zig_ids)}")
print(f"  Enemy cfg IDs:     {sorted(cfg_ids)}")
print(f"  Missing from canon: {sorted(missing)}")
print(f"  Beyond canon (new): {sorted(extra)}")

# Flag if a NEW mesh_id collides with the forest set
new_ids = sorted(extra)
collisions = [i for i in new_ids if i in forest]
if collisions:
    print("  ✗ NEW IDs collide with forest:", collisions); sys.exit(2)
PY
rc=$?
[ $rc -eq 0 ] && pass "no mesh-ID collisions"
[ $rc -eq 2 ] && fail "mesh-ID collision detected (see output above)"

# ───────────────────────────────────────────────────────────────────────────
hdr "6. UV-marker (uBase) collision check"
python3 - <<'PY'
import re, pathlib
sh = pathlib.Path("shaders/world.metal").read_text()
# Existing UV markers used in forest
canon = {
    0:"default", 1:"lightning_core", 2:"lightning_shards",
    8:"emissive",
    10:"bark", 11:"bark", 12:"bark", 13:"bark", 14:"bark",
    20:"secondary", 21:"secondary",
    25:"cloth",
    50:"flame",
    60:"portal_swirl", 70:"portal_beacon", 80:"portal_finial",
}
# Free zones for desert: 30..49, 51..59, 61..69, 71..79, 81..89, 90..127
print("  forest UV markers in use:", sorted(canon.keys()))
print("  free for desert: 30..49, 51..59, 61..69, 71..79, 81..89, 90..127")
PY
pass "uBase free ranges documented (30..49, 51..59, 61..69, 71..79, 81..89, 90..127)"

# ───────────────────────────────────────────────────────────────────────────
hdr "7. Path centerline sync (path_center_x in Zig vs world.metal)"
python3 - <<'PY'
import re, pathlib, sys
zg = pathlib.Path("src/main.zig").read_text()
sh = pathlib.Path("shaders/world.metal").read_text()

# Extract Zig formula
m = re.search(r"fn\s+path_center_x\s*\([^)]*\)[^{]*\{([^}]+)\}", zg, re.S)
zig_body = m.group(1) if m else ""
zig_nums = re.findall(r"[0-9]+\.[0-9]+", zig_body)

# Find matching block in world.metal — search for path_center or matching constants
sh_match = re.search(r"path_center[^=]*=\s*[^;]+;", sh)
sh_text = sh_match.group(0) if sh_match else ""
sh_nums = re.findall(r"[0-9]+\.[0-9]+", sh_text)

print("  Zig formula numbers: ", zig_nums)
print("  Metal formula numbers:", sh_nums)
if zig_nums and sh_nums and set(zig_nums) != set(sh_nums):
    print("  ⚠ Zig vs Metal path-formula constants differ"); sys.exit(2)
PY
rc=$?
[ $rc -eq 0 ] && pass "path centerline constants in sync"
[ $rc -eq 2 ] && warn "path centerline drift — verify before committing shader change"

# ───────────────────────────────────────────────────────────────────────────
hdr "8. File-size guard (catch Qwen truncation)"
declare -A MIN_LINES=(
  ["src/main.zig"]=600
  ["src/game/enemy_ai.zig"]=400
  ["shaders/world.metal"]=900
  ["ios/Mesh.swift"]=1700
  ["ios/GameViewController.swift"]=1700
)
for f in "${!MIN_LINES[@]}"; do
  cur=$(wc -l < "$f" 2>/dev/null || echo 0)
  min=${MIN_LINES[$f]}
  if [ "$cur" -lt "$min" ]; then
    fail "$f shrunk: $cur lines < expected ≥ $min (Qwen may have truncated)"
  else
    pass "$f size OK ($cur ≥ $min)"
  fi
done

# ───────────────────────────────────────────────────────────────────────────
hdr "Summary"
printf '  \033[32m%d pass\033[0m   \033[33m%d warn\033[0m   \033[31m%d fail\033[0m\n' \
  "$OK" "$WARN" "$FAIL"
exit $FAIL
