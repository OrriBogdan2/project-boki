#!/usr/bin/env python3
"""Builds docs/TTK.md from a --ttk-check log and tools/ttk_source.json.
Usage: godot --headless --path . -- --ttk-check > log; python3 tools/ttk_table.py log > docs/TTK.md"""
import json, os, re, sys
R = os.path.join(os.path.dirname(__file__), "..")
SRC = json.load(open(os.path.join(R, "tools/ttk_source.json")))
ORDER, H = SRC["order"], SRC["hunters"]
CLS = {"light": 124, "medium": 145, "heavy": 193}  # scripts/core/data.gd
DR, OFF = SRC["armour_dr"], 0.15
HP_O = {a: CLS[json.load(open(os.path.join(R, f"content/archetypes/{a}.json")))["weight"]] for a in ORDER}
AVG_O = sum(HP_O.values()) / 12
AVG_S = SRC["avg_hp_l1"]
ROW = {}
for line in open(sys.argv[1]):
    m = re.match(r"TTK (\w+) (\w+) (\w+) ([\d.]+) ([\d.]+|inf) (\d+)", line)
    if m: ROW[(m[1], m[2])] = (m[3], float(m[4]), float(m[5]), int(m[6]))

def eff(hp): return hp / (1 - DR)
def src_dps(a):
    h = H[a]
    if h.get("dps"): return h["dps"]
    d = src_dmg(a)
    return d / h["every"] if d and h["every"] else None
def src_dmg(a):
    h = H[a]
    if not h["dmg"]: return None
    return h["dmg"] * (AVG_S / SRC["avg_hp_l15"] if h["at15"] else 1)
def src_t(a, d):
    s = src_dps(a)
    return eff(H[d]["hp"]) / s if s else None
def off(o, s): return s is not None and abs(o - s) / s > OFF

def cell(a, d):
    mode, dist, t, hits = ROW[(a, d)]
    s = src_t(a, d)
    mark = "~" if dist < 8 else ""
    txt = f"{mark}{t:.1f}" + (f" / {s:.1f}" if s else "")
    return f"**{txt}**" if off(t, s) else txt

def hits_cell(a, d):
    sd = src_dmg(a)
    if not sd: return None
    ours = ROW[(a, d)][3]
    s = eff(H[d]["hp"]) / sd
    txt = f"{ours} / {s:.1f}"
    return f"**{txt}**" if off(ours, s) else txt

def table(fn, skip_empty=False):
    out = ["| Attacker \\ defender | " + " | ".join(H[d]["name"] for d in ORDER) + " |", "|---|" + "---|" * 12]
    for a in ORDER:
        cells = [fn(a, d) for d in ORDER]
        if skip_empty and cells[0] is None: continue
        out.append(f"| {H[a]['name']} ({ROW[(a, a)][0]}) | " + " | ".join(cells) + " |")
    return "\n".join(out)

def causes(a):
    """Per attacker: the factors that split ours/source (ours share of average HP over source share)."""
    rows = [d for d in ORDER if src_t(a, d)]
    if not rows: return None
    ratio = sum(ROW[(a, d)][2] / src_t(a, d) for d in rows) / len(rows)
    dps_o = sum(eff(HP_O[d]) / ROW[(a, d)][2] for d in ORDER) / 12
    dps_k = (dps_o / AVG_O) / (src_dps(a) / AVG_S)
    out = [f"ours/source seconds x{ratio:.2f}", f"DPS share x{dps_k:.2f}"]
    sd = src_dmg(a)
    if sd:
        dmg_o = sum(eff(HP_O[d]) / ROW[(a, d)][3] for d in ORDER) / 12
        out.append(f"damage per hit x{(dmg_o / AVG_O) / (sd / AVG_S):.2f}")
        if H[a]["every"]:
            cad_o = sum(ROW[(a, d)][3] / ROW[(a, d)][2] for d in ORDER) / 12
            out.append(f"cadence x{cad_o * H[a]['every']:.2f} ({cad_o:.1f}/s vs {1 / H[a]['every']:.1f}/s)")
    return ", ".join(out)

def main():
    p = print
    p("# Time to down: every Hunter's LMB into every other Hunter\n")
    p("Parity first (briefs/DECISIONS.md 2026-11-07): the owner asked for TTK in the combat area. `--ttk-check` puts a Training Area dummy at 8 m with the defender's base health and armour (124/145/193 hp, armour durability 2.2x, 20% off every hit while it lasts) and holds the attacker's LMB on it with perfect aim (aim dead on the dummy, shooter and dummy pinned, no dodging, no dash, no ability). It tries every LMB mode the weapon has (hold, taps, hold-to-charge) and keeps the fastest that reaches. An LMB that cannot reach 8 m (melee, short guns) is measured at 80% of its range and the cell carries a `~`. Cells are seconds to down; the check fails if a cell never downs the dummy in 20 s. Regenerate: `godot --headless --path . -- --ttk-check > log; python3 tools/ttk_table.py log > docs/TTK.md`.\n")
    p("**Source figure.** Effective HP = Base HP / 0.8 (the source's Common armour is also 20% and its 2,500 durability outlasts any single life, so armour only ever scales HP; docs/SUPERVIVE_DATA.md section 3). Source seconds = that / the Hunter's LMB DPS from `tools/ttk_source.json` (kit text damage and cadence). Seconds are scale-free: our HP and damage are both about 1/8 of the source's, so the two columns compare directly. Cells show `ours / source`; a cell with no source figure shows ours only. **Bold** = ours off the source by more than 15%.\n")
    p("## Seconds to down (ours / source)\n")
    p(table(cell))
    p("\nRows are the attacker (best LMB mode in brackets), columns the defender. `~` = measured near (80% of weapon range).\n")
    p("## Hits to down (ours / source), where the source gives a damage per hit\n")
    p("Cadence-free: defender effective HP over damage per hit (level-15 numbers scaled by the average HP ratio, as docs/specs/DAMAGE_RATIOS.md does). Ours is the count of hits that landed (CombatBus.hit_landed).\n")
    p(table(hits_cell, True))
    p("\n## What the source gives, and what is off\n")
    p("| Attacker | Source DPS (basis) | Why ours differs |\n|---|---|---|")
    for a in ORDER:
        s = src_dps(a)
        basis = H[a]["note"] + (f"; cadence {H[a]['every']} s [{H[a]['every_tag']}]" if H[a]["every"] else "")
        c = causes(a)
        p(f"| {H[a]['name']} / {H[a]['src']} | {'%.0f' % s if s else 'none'} ({basis}) | {c if c else 'no seconds figure'} | {H[a].get('why', 'no source cadence or damage number, so nothing to flag')} |")
    p("\nDefender HP shares (ours over source, from docs/KIT_PARITY.md Health): " + ", ".join(f"{H[d]['name']} x{(HP_O[d] / AVG_O) / (H[d]['hp'] / AVG_S):.2f}" for d in ORDER) + ". Armour is not a cause anywhere: both games take 20% off while it lasts and neither runs out in one life.")

main()
