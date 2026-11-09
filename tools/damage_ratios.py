#!/usr/bin/env python3
"""Damage ratios vs the source (docs/specs/DAMAGE_RATIOS.md). Usage: tools/damage_ratios.py [--md]
Reads content/ JSON for our side; the source numbers are from supervive_kits.md (hand-copied below)."""
import json, sys, os
R = os.path.join(os.path.dirname(__file__), "..")
def J(p): return json.load(open(os.path.join(R, p)))
CLS = {"light": 124, "medium": 145, "heavy": 193}  # scripts/core/data.gd
OUR_HP = None
SRC = {"Oath": (1475, 88.5), "Kingpin": (1445, 86.7), "Shiv": (1290, 77.4), "Joule": (1290, 77.4), "Tetra": (1290, 77.4),
       "Void": (1150, 66.0), "Felix": (1290, 77.4), "Brall": (1290, 77.4), "Myth": (1100, 66.0), "Elluna": (1290, 77.4),
       "Ghost": (1225, 73.5), "Celeste": (1290, 77.4)}
HERO = [("gunslinger", "Vex", "Ghost"), ("bulwark", "Mossy", "Oath"), ("mage", "Sparkle", "Joule"), ("juggernaut", "Kael", "Brall"),
        ("archer", "Lace", "Myth"), ("ashwick", "Cinder", "Felix"), ("dredge", "Grimble", "Kingpin"), ("tender", "Meeko", "Elluna"),
        ("rimewright", "Neve", "Celeste"), ("dolm", "Tenzo", "Tetra"), ("ostra", "Motley", "Void"), ("thief", "Sable", "Shiv")]
def our_hp():
    return sum(CLS[J(f"content/archetypes/{a}.json")["weight"]] for a, _, _ in HERO) / 12
SRC_AVG1 = sum(v[0] for v in SRC.values()) / 12
SRC_AVG15 = SRC_AVG1 + 14 * sum(v[1] for v in SRC.values()) / 12
def rows():
    A = {a: J(f"content/archetypes/{a}.json") for a, _, _ in HERO}
    W = {w: J(f"content/weapons/{w}.json")["primary"] for w in ["quill_rifle", "greatsword", "tower_shield", "coilcaster", "flamethrower", "shotgun", "lantern_crook", "hoar_fan", "longbow", "rubble_fists", "tether_lantern", "arc_bolts"]}
    g, j, b, m, ar, ash, d, t, r, o, th = (A[k] for k in ["gunslinger", "juggernaut", "bulwark", "mage", "archer", "ashwick", "dredge", "tender", "rimewright", "ostra", "thief"])
    def dps(w): p = W[w]; return p["dmg"] * p.get("pellets", 1) / p["rate"]
    # (hero, slot, label, ours, source, source_is_level15, note). source None = the kit text gives no number.
    R_ = []
    A_ = R_.append
    A_(("Vex", "LMB hit", "quill rifle round", W["quill_rifle"]["dmg"], 51, 0, "source rate unknown"))
    A_(("Vex", "LMB DPS", "quill rifle", dps("quill_rifle"), None, 0, "source rate not in the kit text"))
    A_(("Vex", "RMB", "Burr hit (the cone is the wall case) / Spike Grenade", g["rmb"]["burr"]["hit_dmg"], 165, 0, ""))
    A_(("Vex", "E", "Longneedle / Railgun", g["e"]["dmg"], 202, 0, ""))
    A_(("Vex", "R", "Cinderfall impact+3s burn / Napalm 203+3x59", g["x"]["dmg"] + g["x"]["zone_t"] / g["x"]["tick"] * g["x"]["tick_dmg"], 203 + 3 * 59, 0, ""))
    A_(("Mossy", "LMB hit", "tower shield bash (source: hammer throw 192@15)", W["tower_shield"]["dmg"], 192, 1, "different weapon"))
    A_(("Mossy", "LMB charged", "charged bash / charged swing 522@15", W["tower_shield"]["charged_dmg"], 522, 1, ""))
    A_(("Mossy", "RMB shield slam / Shield Bash", "slam", b["rmb"]["slam"]["dmg"], 198, 1, ""))
    A_(("Mossy", "Dash", "360 Smash whirl / Spin Dash", b["dash"]["whirl_dmg"], 364, 1, ""))
    A_(("Mossy", "R", "Abyssal Breaker strike+blast / fissure 31+396", b["x"]["strike_dmg"] + b["x"]["dmg"], 31 + 396, 1, ""))
    A_(("Sparkle", "LMB", "coilcaster bolt / Jolt", W["coilcaster"]["dmg"], 90, 0, ""))
    A_(("Sparkle", "RMB", "Coil max / Voltaic Spear", m["rmb"]["coil"]["dmg"][1], 133, 0, ""))
    A_(("Sparkle", "Dash", "Wirerun tap / Surge press", m["dash"]["dmg"], 153, 0, ""))
    A_(("Sparkle", "E", "Strike / Lightning Strike", m["e"]["dmg"], 162, 0, ""))
    A_(("Sparkle", "R", "Crash / Thunderstorm", m["x"]["dmg"], 72, 0, ""))
    A_(("Kael", "LMB hit", "greatsword slash / Caldera", W["greatsword"]["dmg"], 43, 0, ""))
    A_(("Kael", "LMB charged", "charged slash / fireblast", W["greatsword"]["charged_dmg"], 107, 0, ""))
    A_(("Kael", "RMB", "Smash / Execution Slam", j["rmb"]["slam"]["dmg"], 130, 0, ""))
    A_(("Kael", "RMB lunge", "lunge max / Fiery Lunge", j["rmb"]["lunge"]["dmg"][1], 84, 0, ""))
    A_(("Kael", "RMB air", "Meteor Drop / Obsidian Slam", j["rmb"]["drop"]["dmg"], 88, 0, ""))
    A_(("Kael", "RMB spin", "spin / Scorching Spin", j["rmb"]["spin"]["dmg"], 99, 0, ""))
    A_(("Kael", "Dash", "Rampage tip / Flame Step", j["dash"]["tip_dmg"], 49, 0, ""))
    A_(("Kael", "E", "Warchain / Feysteel", j["e"]["dmg"], 30, 0, ""))
    A_(("Kael", "R", "Cleave / Volcanic Rebuke", j["x"]["dmg"], 230, 0, ""))
    A_(("Lace", "RMB", "Heavy Shot max (no wall) / Heartpiercer", ar["rmb"]["pin"]["dmg"][1], 35, 0, ""))
    A_(("Lace", "RMB wall", "Heavy Shot into wall / 35+173", ar["rmb"]["pin"]["dmg"][1] * (1 + ar["rmb"]["pin"]["wall_mult"]), 35 + 173, 0, ""))
    A_(("Lace", "E DPS", "Rain / Rain of Arrows 61/s", ar["e"]["dmg"] / ar["e"]["every"], 61, 0, ""))
    A_(("Lace", "R final shot", "Starpiercer 3rd / Fury 422", ar["x"]["final_dmg"], 422, 0, ""))
    A_(("Lace", "R shots 1-2", "Starpiercer / Fury 326", ar["x"]["dmg"], 326, 0, ""))
    A_(("Cinder", "LMB DPS", "flamethrower / 258 per s", dps("flamethrower"), 258, 0, ""))
    A_(("Cinder", "RMB", "Ember bolt / Embry Bolt", ash["rmb"]["dmg"], 106, 0, ""))
    A_(("Cinder", "Dash", "Spark Leap / Pyro Pounce", ash["dash"]["dmg"], 150.4, 0, ""))
    A_(("Cinder", "E", "pull / Heat Shield", ash["e"]["dmg"], 76.8, 0, ""))
    A_(("Cinder", "R DPS", "trail / Flight 239.2 per s", ash["x"]["trail_dps"] * 1.0, 239.2, 0, "see ashwick_jet.gd:236"))
    A_(("Grimble", "LMB DPS", "shotgun (7 pellets)", dps("shotgun"), None, 0, "source gives no number"))
    A_(("Grimble", "E", "slam / Primal Slam", d["e"]["dmg"], 264, 0, ""))
    A_(("Grimble", "R", "Slugwave: 2 waves x 6 orbs, all hit", d["x"]["dmg"] * d["x"]["orbs"] * d["x"]["waves"], None, 0, "'massive', no number"))
    A_(("Meeko", "LMB DPS", "lantern crook", dps("lantern_crook"), None, 0, "no number"))
    A_(("Meeko", "RMB", "seed hit+burst / Darkside 49", t["rmb"]["seed"]["dmg"] + t["rmb"]["seed"]["burst_dmg"], 49, 0, ""))
    A_(("Neve", "RMB", "lance+burst / Cryo Spear 156+190", r["rmb"]["lance"]["dmg"] + r["rmb"]["lance"]["burst_dmg"], 156 + 190, 0, ""))
    A_(("Neve", "R", "Whiteout / Chilling Finale", r["x"]["dmg"], 155, 0, ""))
    A_(("Neve", "LMB DPS", "hoar fan", dps("hoar_fan"), None, 0, "no number"))
    A_(("Tenzo", "all", "kit text gives no damage numbers", None, None, 0, "Tetra: only upgrade deltas"))
    A_(("Motley", "LMB hit", "orb / Gravity Orb 263@15", W["tether_lantern"]["dmg"], 263, 1, "item 117: kept"))
    A_(("Motley", "RMB", "snap / Void Snap 277@15", o["rmb"]["snap"]["dmg"], 277, 1, ""))
    A_(("Motley", "E", "bomb x3.5 / Anomaly 365@15 up to 3.5x", o["e"]["dmg"] * o["e"]["dmg_max_k"], 365 * 3.5, 1, ""))
    A_(("Sable", "LMB hit", "arc bolt / Arcslinger 160@15", W["arc_bolts"]["dmg"], 160, 1, ""))
    A_(("Sable", "RMB", "bola+pair / Chain Bolas 46+94", th["rmb"]["bola"]["dmg"] + th["rmb"]["bola"]["pair_dmg"], 46 + 94, 0, ""))
    A_(("Sable", "R", "barrage 10 shots+rim / Fusillade 69+48", th["x"]["shots"] * th["x"]["dmg"], 69 + 48, 1, "per target"))
    return R_
def main():
    oh = our_hp()
    out = []
    for h, s, lab, ours, src, l15, note in rows():
        sh = None if src is None else src / (SRC_AVG15 if l15 else SRC_AVG1)
        oh_ = None if ours is None else ours / oh
        ratio = None if (sh is None or oh_ is None) else oh_ / sh
        out.append((h, s, lab, ours, src, oh_, sh, ratio, note))
    return oh, out
if __name__ == "__main__":
    oh, out = main()
    print(f"ours avg HP {oh:.1f}; source avg L1 {SRC_AVG1:.1f}, L15 {SRC_AVG15:.1f}")
    for h, s, lab, ours, src, a, b, ra, n in out:
        f = lambda x, p=1: "-" if x is None else f"{x*p:.1f}" if p != 100 else f"{x*100:.1f}%"
        print(f"{h:8}{s:12} ours {f(ours)} ({f(a,100)}) src {f(src)} ({f(b,100)}) x{'-' if ra is None else format(ra,'.2f')}")
