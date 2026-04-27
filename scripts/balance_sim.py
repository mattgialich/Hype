#!/usr/bin/env python3
"""Combat balance simulator for Hype/Mach5Game.

Mirrors the Zig combat math in player.zig + enemy_ai.zig and runs simulated
fights to verify time-to-kill, mana economy, spell-level XP rate, and player
progression. Prints a punch list of any combat that's wildly off (instakill,
unkillable, mana-starved).

Run:   python3 scripts/balance_sim.py
"""
from dataclasses import dataclass, field
from typing import Callable

# ── Constants pulled from src/game/player.zig (KEEP IN SYNC) ────────────────
PLAYER_SPEED                  = 10.0
BASE_HP_MAX                   = 200.0
BASE_MANA_MAX                 = 100.0
BASE_MANA_REGEN               = 5.0
BASE_LIGHTNING_DMG            = 30.0
BASE_FIREBALL_DMG             = 22.0
BASE_FIREBALL_RADIUS          = 4.0

BASE_MANA_COSTS = [30.0, 15.0, 35.0, 10.0]   # fireball, lightning, ice_nova, dash
BASE_COOLDOWNS  = [1.2,  0.0,  5.0,  2.0]

SPELL_MAX_LEVEL               = 10
SPELL_LEVEL_DMG_PCT           = 0.20
SPELL_LEVEL_MANA_REDUCE_PCT   = 0.03
SPELL_LEVEL_CD_REDUCE_PCT     = 0.02
SPELL_LEVEL_AOE_PCT           = 0.05
SPELL_XP_THRESHOLDS           = [200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800]

PLAYER_XP_THRESHOLD_FN = lambda level: level * 100   # matches on_kill in player.zig

FIREBALL = 0
LIGHTNING = 1

# ── Enemy table mirrors enemy_config.zig ────────────────────────────────────
@dataclass
class Enemy:
    mesh_id: int
    name: str
    level: int
    hp_max: float
    damage: float
    xp_reward: int
    melee_r: float
    telegraph_t: float
    recover_t: float
    chase_speed: float

ENEMIES = {
    "gargoyle":          Enemy(3,  "Gargoyle",        1,  80, 12, 25, 1.8, 0.40, 0.55, 5.5),
    "wisp":              Enemy(25, "Forest Wisp",     1,  35,  8, 15, 1.5, 0.20, 0.30, 8.5),
    "tree_ent":          Enemy(26, "Tree Ent",        5, 280, 28, 80, 3.2, 0.85, 1.10, 2.6),
    "skeleton_knight":   Enemy(27, "Skeleton Knight", 3, 140, 18, 45, 2.2, 0.55, 0.55, 4.2),
}

# ── Skill-tree bonus model: tracks what a "typical" tree investment looks like
# at a given player level. The forest game gives 1 crystal per level beyond the
# free centre node. Each crystal allocates ONE node averaging the values below.
def typical_bonuses(player_level: int) -> dict:
    """Empirically-tuned: each level adds ~+5% damage, +5% HP, +3% mana, on average."""
    L = max(0, player_level - 1)  # crystals available
    return {
        "damage_pct":       0.05 * L,
        "spell_damage_pct": 0.05 * L,
        "hp_pct":           0.05 * L,
        "hp_flat":          0.0,
        "mana_pct":         0.03 * L,
        "mana_regen_pct":   0.04 * L,
        "damage_flat":      0.0,
        "crit_chance_pct":  min(0.30, 0.01 * L),  # caps at 30%
        "crit_damage_pct":  0.05 * L,
        "armour_pct":       0.0,
        "dmg_reduce_pct":   min(0.40, 0.02 * L),
        "cooldown_pct":     0.02 * L,
        "cast_speed_pct":   0.0,
        "move_speed_pct":   0.02 * L,
        "xp_gain_pct":      0.0,
    }

# ── Player model ────────────────────────────────────────────────────────────
@dataclass
class Player:
    level: int = 1
    xp: int = 0
    spell_level: list[int] = field(default_factory=lambda: [1, 1, 1, 1])
    spell_xp:    list[int] = field(default_factory=lambda: [0, 0, 0, 0])
    bonuses: dict = field(default_factory=lambda: typical_bonuses(1))
    hp: float = BASE_HP_MAX
    mana: float = BASE_MANA_MAX
    cd: list[float] = field(default_factory=lambda: [0.0, 0.0, 0.0, 0.0])

    @property
    def hp_max(self):
        return (BASE_HP_MAX + self.bonuses["hp_flat"]) * (1.0 + self.bonuses["hp_pct"])
    @property
    def mana_max(self):
        return BASE_MANA_MAX * (1.0 + self.bonuses["mana_pct"])
    @property
    def mana_regen(self):
        return BASE_MANA_REGEN * (1.0 + self.bonuses["mana_regen_pct"])

    def spell_dmg_mult(self, idx):
        return 1.0 + (self.spell_level[idx] - 1) * SPELL_LEVEL_DMG_PCT
    def spell_mana_cost(self, idx):
        return BASE_MANA_COSTS[idx] * max(0.5, 1.0 - (self.spell_level[idx] - 1) * SPELL_LEVEL_MANA_REDUCE_PCT)
    def spell_cooldown(self, idx):
        cd_base = BASE_COOLDOWNS[idx] * max(0.5, 1.0 - (self.spell_level[idx] - 1) * SPELL_LEVEL_CD_REDUCE_PCT)
        return cd_base * max(0.1, 1.0 - self.bonuses["cooldown_pct"] - self.bonuses["cast_speed_pct"])
    def spell_aoe(self, idx):
        return BASE_FIREBALL_RADIUS * (1.0 + (self.spell_level[idx] - 1) * SPELL_LEVEL_AOE_PCT)

    def add_spell_xp(self, idx, dmg):
        if self.spell_level[idx] >= SPELL_MAX_LEVEL: return
        self.spell_xp[idx] += int(dmg)
        while self.spell_level[idx] < SPELL_MAX_LEVEL:
            need = SPELL_XP_THRESHOLDS[self.spell_level[idx] - 1]
            if self.spell_xp[idx] < need: break
            self.spell_xp[idx] -= need
            self.spell_level[idx] += 1

    def gain_xp(self, n):
        self.xp += int(n * (1.0 + self.bonuses["xp_gain_pct"]))
        while self.xp >= PLAYER_XP_THRESHOLD_FN(self.level):
            self.xp -= PLAYER_XP_THRESHOLD_FN(self.level)
            self.level += 1
            self.bonuses = typical_bonuses(self.level)

    def cast_lightning(self, enemy_hp: float) -> tuple[float, float]:
        """Returns (mana_spent, damage_dealt). Lightning auto-targets — always hits."""
        idx = LIGHTNING
        cost = self.spell_mana_cost(idx)
        if self.mana < cost or self.cd[idx] > 0:
            return (0.0, 0.0)
        self.mana -= cost
        self.cd[idx] = self.spell_cooldown(idx)
        spell_mult = self.spell_dmg_mult(idx)
        dmg = (BASE_LIGHTNING_DMG * spell_mult + self.bonuses["damage_flat"]) * \
              (1.0 + self.bonuses["damage_pct"] + self.bonuses["spell_damage_pct"])
        # Crit roll — use expected value rather than rolling for stable sims
        avg_crit_mult = 1.0 + self.bonuses["crit_chance_pct"] * (0.5 + self.bonuses["crit_damage_pct"])
        dmg *= avg_crit_mult
        actual = min(dmg, enemy_hp)
        self.add_spell_xp(idx, actual)
        return (cost, actual)

    def cast_fireball(self, enemies_in_radius: list[float]) -> tuple[float, list[float]]:
        """Returns (mana_spent, [dmg_per_enemy]). Fireball is AoE — radius depends on spell level."""
        idx = FIREBALL
        cost = self.spell_mana_cost(idx)
        if self.mana < cost or self.cd[idx] > 0 or not enemies_in_radius:
            return (0.0, [])
        self.mana -= cost
        self.cd[idx] = self.spell_cooldown(idx)
        spell_mult = self.spell_dmg_mult(idx)
        base_dmg = (BASE_FIREBALL_DMG * spell_mult + self.bonuses["damage_flat"]) * \
                   (1.0 + self.bonuses["damage_pct"] + self.bonuses["spell_damage_pct"])
        avg_crit_mult = 1.0 + self.bonuses["crit_chance_pct"] * (0.5 + self.bonuses["crit_damage_pct"])
        per_enemy = base_dmg * avg_crit_mult
        hits = [min(per_enemy, hp) for hp in enemies_in_radius]
        self.add_spell_xp(idx, sum(hits))
        return (cost, hits)

# ── Single-enemy combat sim (lightning kiting) ─────────────────────────────
# Damage-to-player model: continuous expected DPS rather than a discrete
# state machine, so short fights still incur a fair fraction of a strike.
# Per-cycle expected dmg = connect_rate * enemy.damage. Cycle length includes
# the chase-into-melee re-approach (~melee_r/chase_spd seconds).
def enemy_expected_dps(e: Enemy, connect_rate: float) -> float:
    cycle = e.telegraph_t + 0.05 + e.recover_t + (e.melee_r / e.chase_speed)
    return connect_rate * e.damage / cycle

def sim_kite_single(player: Player, enemy_key: str, max_time: float = 60.0,
                    connect_rate: float = 0.30) -> dict:
    e = ENEMIES[enemy_key]
    enemy_hp = e.hp_max
    p = player
    p.hp = p.hp_max
    p.mana = p.mana_max
    p.cd = [0.0] * 4

    t = 0.0
    dt = 1/60.0
    casts = 0
    player_dmg_taken = 0.0
    dps_in = enemy_expected_dps(e, connect_rate)
    dr = max(0.0, 1.0 - p.bonuses["dmg_reduce_pct"] - p.bonuses["armour_pct"])

    while t < max_time:
        for i in range(4):
            p.cd[i] = max(0.0, p.cd[i] - dt)
        p.mana = min(p.mana_max, p.mana + p.mana_regen * dt)

        cost, dmg = p.cast_lightning(enemy_hp)
        if dmg > 0:
            casts += 1
            enemy_hp -= dmg
            if enemy_hp <= 0:
                p.gain_xp(e.xp_reward)
                return {
                    "outcome": "win", "time": t, "casts": casts,
                    "dmg_taken": player_dmg_taken,
                    "dmg_taken_pct": player_dmg_taken / p.hp_max * 100,
                    "ended_mana": p.mana,
                }

        # Continuous expected damage to player
        d_in = dps_in * dt * dr
        p.hp -= d_in
        player_dmg_taken += d_in
        if p.hp <= 0:
            return {"outcome": "die", "time": t, "casts": casts,
                    "dmg_taken": player_dmg_taken,
                    "dmg_taken_pct": player_dmg_taken / p.hp_max * 100,
                    "ended_mana": p.mana}
        t += dt

    return {"outcome": "timeout", "time": t, "casts": casts,
            "dmg_taken": player_dmg_taken,
            "dmg_taken_pct": player_dmg_taken / p.hp_max * 100,
            "ended_mana": p.mana}

# ── Pack fight: 4 enemies in a clump, fireball-friendly ─────────────────────
def sim_pack(player: Player, enemy_key: str, count: int = 4, max_time: float = 30.0) -> dict:
    """Fireball-test: a clump of N enemies. Player blasts the cluster."""
    e = ENEMIES[enemy_key]
    enemy_hps = [e.hp_max] * count
    p = player
    p.hp = p.hp_max
    p.mana = p.mana_max
    p.cd = [0.0] * 4

    t = 0.0
    dt = 1/60.0
    casts = 0
    fb_uses = 0
    lt_uses = 0
    player_dmg_taken = 0.0
    while t < max_time:
        for i in range(4):
            p.cd[i] = max(0.0, p.cd[i] - dt)
        p.mana = min(p.mana_max, p.mana + p.mana_regen * dt)

        # Prefer fireball when 2+ enemies alive and in radius (assume yes for sim)
        alive_hps = [h for h in enemy_hps if h > 0]
        if len(alive_hps) >= 2 and p.mana >= p.spell_mana_cost(FIREBALL) and p.cd[FIREBALL] <= 0:
            cost, hits = p.cast_fireball(alive_hps)
            casts += 1
            fb_uses += 1
            j = 0
            for i in range(len(enemy_hps)):
                if enemy_hps[i] > 0 and j < len(hits):
                    enemy_hps[i] -= hits[j]
                    j += 1
                    if enemy_hps[i] <= 0:
                        p.gain_xp(e.xp_reward)
        else:
            # Fall back to lightning on the first alive enemy
            for i in range(len(enemy_hps)):
                if enemy_hps[i] > 0:
                    cost, dmg = p.cast_lightning(enemy_hps[i])
                    if dmg > 0:
                        casts += 1
                        lt_uses += 1
                        enemy_hps[i] -= dmg
                        if enemy_hps[i] <= 0:
                            p.gain_xp(e.xp_reward)
                    break

        if all(h <= 0 for h in enemy_hps):
            return {
                "outcome": "win", "time": t, "casts": casts,
                "fireballs": fb_uses, "lightnings": lt_uses,
                "ended_mana": p.mana,
            }

        # Each surviving enemy takes a turn-shaped chunk out of the player every
        # cycle. With N enemies and similar cycle times, player damage taken
        # scales roughly linearly with N. Use 35% connect rate (slightly worse
        # in a pack — harder to kite multiple).
        cycle = e.telegraph_t + 0.05 + e.recover_t
        per_cycle_dmg_per_enemy = e.damage * 0.35
        n_alive = sum(1 for h in enemy_hps if h > 0)
        per_sec = (per_cycle_dmg_per_enemy * n_alive) / cycle
        dmg_to_player = per_sec * dt * (1.0 - p.bonuses["dmg_reduce_pct"] - p.bonuses["armour_pct"])
        dmg_to_player = max(0.0, dmg_to_player)
        p.hp -= dmg_to_player
        player_dmg_taken += dmg_to_player
        if p.hp <= 0:
            return {"outcome": "die", "time": t, "casts": casts,
                    "fireballs": fb_uses, "lightnings": lt_uses,
                    "dmg_taken_pct": player_dmg_taken / p.hp_max * 100,
                    "ended_mana": p.mana}
        t += dt

    return {"outcome": "timeout", "time": t, "casts": casts,
            "fireballs": fb_uses, "lightnings": lt_uses,
            "ended_mana": p.mana}

# ── Run the suite ───────────────────────────────────────────────────────────
def run_suite():
    print("Hype Combat Balance Suite")
    print("=" * 78)

    # 1. Single-enemy progression — lightning vs each enemy at varying player levels
    print("\n[1] Lightning kiting — single enemy by player level")
    print(f"{'Player Lvl':>10} {'Spell Lvl':>10} {'Enemy':>17} {'Outcome':>9} {'Time':>7} {'Casts':>6} {'Dmg taken %':>11}")
    for plvl in [1, 3, 5, 8, 12, 18]:
        for spell_lvl in [1, 3, 5, 8]:
            for ek in ENEMIES:
                p = Player()
                p.level = plvl
                p.bonuses = typical_bonuses(plvl)
                p.spell_level[LIGHTNING] = spell_lvl
                r = sim_kite_single(p, ek)
                if r["outcome"] != "win" or r["dmg_taken_pct"] > 80:
                    flag = "  ⚠"
                elif r["dmg_taken_pct"] < 5 and r["time"] < 3:
                    flag = "  ✓"
                else:
                    flag = ""
                print(f"{plvl:>10} {spell_lvl:>10} {ENEMIES[ek].name:>17} {r['outcome']:>9} "
                      f"{r['time']:>6.1f}s {r['casts']:>6d} {r['dmg_taken_pct']:>10.1f}%{flag}")
            print()

    # 2. Pack fights — fireball-friendly
    print("\n[2] Pack fights (fireball + lightning) — 4 enemies in radius")
    print(f"{'Player Lvl':>10} {'FB Lvl':>7} {'LT Lvl':>7} {'Pack':>17} {'Outcome':>9} {'Time':>7} {'FB':>4} {'LT':>4}")
    for plvl in [1, 3, 5, 8, 12]:
        for fb_lvl, lt_lvl in [(1, 1), (3, 3), (5, 5), (8, 8)]:
            for ek in ["wisp", "gargoyle", "skeleton_knight"]:
                p = Player()
                p.level = plvl
                p.bonuses = typical_bonuses(plvl)
                p.spell_level[FIREBALL]  = fb_lvl
                p.spell_level[LIGHTNING] = lt_lvl
                r = sim_pack(p, ek, count=4)
                print(f"{plvl:>10} {fb_lvl:>7} {lt_lvl:>7} {ENEMIES[ek].name:>17} "
                      f"{r['outcome']:>9} {r['time']:>6.1f}s "
                      f"{r.get('fireballs',0):>4d} {r.get('lightnings',0):>4d}")
            print()

    # 3. Spell-level XP rate — how fast do spells level up?
    print("\n[3] Spell XP progression — how many gargoyle kills to max each spell?")
    p = Player()
    p.level = 1
    p.bonuses = typical_bonuses(1)
    kills_to_max = {1: 0}
    cur_lvl = 1
    total_kills = 0
    while p.spell_level[LIGHTNING] < SPELL_MAX_LEVEL and total_kills < 1000:
        # Player kills a gargoyle: 80 HP, lightning at base 30 dmg → 3 casts
        # Total damage dealt across the kill ≈ 80 (since over-damage is capped).
        e_hp = ENEMIES["gargoyle"].hp_max
        while e_hp > 0:
            cost, dmg = p.cast_lightning(e_hp)
            if dmg <= 0: break
            e_hp -= dmg
            p.mana = p.mana_max  # reset mana between kills (simulating regen between fights)
            p.cd = [0.0] * 4
        total_kills += 1
        p.gain_xp(ENEMIES["gargoyle"].xp_reward)
        if p.spell_level[LIGHTNING] != cur_lvl:
            cur_lvl = p.spell_level[LIGHTNING]
            kills_to_max[cur_lvl] = total_kills
    print(f"  Lightning level progression (gargoyle kills cumulative):")
    for lvl, kills in sorted(kills_to_max.items()):
        # Approximate player level reached at that spell level milestone
        # (cumulative XP from `kills` gargoyles → player level via threshold table)
        cum_xp = kills * ENEMIES["gargoyle"].xp_reward
        approx_plvl = 1
        thresh_sum = 0
        while True:
            need = approx_plvl * 100
            if thresh_sum + need > cum_xp: break
            thresh_sum += need
            approx_plvl += 1
        print(f"    spell L{lvl:>2} reached at {kills:>4d} kills (player ≈ lvl {approx_plvl})")
    print(f"  Total kills to max lightning: {total_kills}")
    print(f"  Final player level: {p.level}")

    # 4. Mana economy — sustained DPS by spell level
    print("\n[4] Sustained DPS (mana-limited steady state) by spell level")
    p = Player()
    p.level = 5
    p.bonuses = typical_bonuses(5)
    print(f"  Lightning DPS (player lvl 5, +regen and bonuses):")
    print(f"  {'Spell Lvl':>9} {'Cost':>6} {'Damage':>8} {'CD':>6} {'Steady DPS':>11}")
    for sl in [1, 3, 5, 8, 10]:
        p.spell_level[LIGHTNING] = sl
        cost = p.spell_mana_cost(LIGHTNING)
        spell_mult = p.spell_dmg_mult(LIGHTNING)
        dmg = (BASE_LIGHTNING_DMG * spell_mult) * (1.0 + p.bonuses["damage_pct"] + p.bonuses["spell_damage_pct"])
        regen = p.mana_regen
        # Steady DPS: limited by mana regen / cost, OR by cooldown
        casts_per_sec_mana = regen / cost
        cd = p.spell_cooldown(LIGHTNING)
        casts_per_sec_cd = (1.0 / cd) if cd > 0 else 1000.0  # lightning has 0 base cd
        casts_per_sec = min(casts_per_sec_mana, casts_per_sec_cd)
        dps = casts_per_sec * dmg
        print(f"  {sl:>9} {cost:>6.1f} {dmg:>8.1f} {cd:>6.2f} {dps:>11.1f}")

    # 5. Player level vs enemy difficulty — sanity check
    print("\n[5] Player level needed to comfortably handle each enemy (lightning only, spell L1)")
    print(f"  {'Enemy':>17} {'TTK lvl 1':>10} {'TTK lvl 5':>10} {'TTK lvl 10':>10} {'Lvl5 dmg taken':>15}")
    for ek in ENEMIES:
        row = []
        dmg_taken_5 = "?"
        for plvl in [1, 5, 10]:
            p = Player(); p.level = plvl
            p.bonuses = typical_bonuses(plvl)
            r = sim_kite_single(p, ek, max_time=120)
            row.append(r["time"])
            if plvl == 5: dmg_taken_5 = r["dmg_taken_pct"]
        ttks = [f"{t:>7.1f}s" for t in row]
        print(f"  {ENEMIES[ek].name:>17} {ttks[0]:>10} {ttks[1]:>10} {ttks[2]:>10} {dmg_taken_5:>14.1f}%")

    print("\n" + "=" * 78)
    print("Done.")

if __name__ == "__main__":
    run_suite()
