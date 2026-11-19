#!/usr/bin/env python3
"""Markdown tables for docs/TTK.md "main 11-19": Vex, Kael, Lace, Cinder into each other (16 pairs) at level 1 and 6,
no armour and tier 2. Needs logs from `godot --headless --path . -- --ttk-matrix-check --ttk-matrix-set=gunslinger,juggernaut,archer,ashwick
--ttk-matrix-level=L --ttk-matrix-armor=none|tier2` (TTKV rows) and the base run (TTK rows).
Usage (base.log = the TTK rows of --ttk-matrix-check, Lace's from --ttk-matrix-only=archer): python3 tools/ttk_pairs.py base.log v_1_none.log v_1_tier2.log v_6_none.log v_6_tier2.log"""
import json, os, re, sys
R = os.path.join(os.path.dirname(__file__), "..")
SRC = json.load(open(os.path.join(R, "tools/ttk_matrix_source.json")))
H = SRC["hunters"]
SET = ["gunslinger", "juggernaut", "archer", "ashwick"]
NAME = {"gunslinger": "Vex", "juggernaut": "Kael", "archer": "Lace", "ashwick": "Cinder"}
DR = {"none": 0.0, "common": SRC["armour_dr"], "tier2": 0.30}      # the source's 20 / 25 / 30 / 35% ladder (docs/ARMOUR_PARITY.md)
LV_HP = 0.06      # health a level adds, share of base: ours and the source's (content/rules/level_growth.json, sv/DATA.md section 6)
LO, HI = 0.8, 1.25

def rows(path, tag):
    out = {}
    for line in open(path):
        m = re.match(tag + r" (?:L\d+ armour \w+ )?(\w+) (\w+) (\w+) ([\d.]+) ([\d.]+|inf) (\d+)", line)
        if m and m[1] in SET and m[2] in SET: out[(m[1], m[2])] = (m[3], float(m[5]), float(m[4]))
    return out

def src_t(a, d, lv, arm):
    h = H[a]
    dps = h.get("dps") or (h["dmg"] / h["every"] if h.get("dmg") and h.get("every") else None)
    return H[d]["hp"] * (1 + LV_HP * (lv - 1)) / (1 - DR[arm]) / dps if dps else None

def old_doc():
    out, cols = {}, None
    for line in open(os.path.join(R, "docs/TTK_MATRIX.md")):
        if line.startswith("## Hits to down"): break
        if line.startswith("| Attacker \\ defender") and cols is None:
            cols = [c.strip() for c in line.strip().strip("|").split("|")[1:]]
        elif cols and line.startswith("| ") and "(" in line.split("|")[1]:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            att = [a for a in SET if NAME[a] in cells[0].split()[0]]
            if att:
                for c, v in zip(cols, cells[1:]):
                    d = [x for x in SET if NAME[x] == c]
                    m = re.match(r"\**~?([\d.]+)", v)
                    if d and m: out[(att[0], d[0])] = float(m[1])
        elif cols and not line.startswith("|"): cols = None if out else cols
    return out

def main():
    base = rows(sys.argv[1], "TTK")
    for k, v in rows(sys.argv[1], "TTK").items(): base[k] = v
    cfg = [("L1 none", 1, "none"), ("L1 tier 2", 1, "tier2"), ("L6 none", 6, "none"), ("L6 tier 2", 6, "tier2")]
    run = {c[0]: rows(p, "TTKV") for c, p in zip(cfg, sys.argv[2:])}
    old = old_doc()
    print("| Pair (attacker into defender) | Doc 11-11, L1 Common | Now, L1 Common | Delta | " + " | ".join(c[0] for c in cfg) + " |")
    print("|---|---|---|---|" + "---|" * len(cfg))
    for a in SET:
        for d in SET:
            o, n = old.get((a, d)), base[(a, d)][1]
            cells = [f"{run[c[0]][(a, d)][1]:.1f}" + ("~" if run[c[0]][(a, d)][2] < 8 else "") for c in cfg]
            print(f"| {NAME[a]} into {NAME[d]} | {o if o else 'n/a'} | {n:.1f} | {('%+.1f' % (n - o)) if o else 'n/a'} | " + " | ".join(cells) + " |")
    print("\n| Pair | " + " | ".join(f"{c[0]} ours / source = ratio" for c in cfg) + " |\n|---|" + "---|" * len(cfg))
    for a in SET:
        if a == "archer": continue
        for d in SET:
            cs = []
            for name, lv, arm in cfg:
                t, s = run[name][(a, d)][1], src_t(a, d, lv, arm)
                r = t / s
                cs.append(f"{t:.1f} / {s:.1f} = {r:.2f}" + ("" if LO <= r <= HI else " **out**"))
            print(f"| {NAME[a]} into {NAME[d]} | " + " | ".join(cs) + " |")

main()
