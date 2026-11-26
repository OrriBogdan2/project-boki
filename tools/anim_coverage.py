#!/usr/bin/env python3
"""Animation coverage matrix: 13 Hunters x the states a player sees, read headless from the data and the .glb clip lists.

    python3 tools/anim_coverage.py            print the matrix and the gap list
    python3 tools/anim_coverage.py --md       the same as a markdown table
    python3 tools/anim_coverage.py --check    exit 1 if a Hunter has a gap that tools/anim_coverage_gaps.json does not list
    python3 tools/anim_coverage.py --update   rewrite the gap list (it may only shrink; a new gap is refused)

Cells: clip = a clip made for that state; shared = the clip of a neighbouring state plays (Jump_Run for the fall,
Attack for a cast); proc = the procedural layer (HunterAnim, the flinch layer); part = a clip for part of the state;
WRONG = a clip of another meaning plays (the jump clip for a glide, the run clip for a dash, idle while knocked down);
MISSING = nothing for the state. Only WRONG and MISSING are gaps. How the game picks (scripts/heroes/warden_native.gd
for the native Hunters, warden_clips.gd for the contract one) is in docs/ANIM_COVERAGE.md.
"""

import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art", "wardens")
GAPS = os.path.join(ROOT, "tools", "anim_coverage_gaps.json")
STATES = ["idle", "idle_combat", "walk", "run", "jump", "fall", "land", "glide", "dash",
          "lmb", "rmb", "e", "r", "hit", "down", "revive"]
BAD = ("WRONG", "MISSING")
# kit move ids by slot for the Hunters whose kit moves have their own clips (data "kmoves")
WEAPON_OUT_IDLE = {"gil", "vex"}  # idle holds the weapon out front (stills 11-26): it needs a casual idle and a combat one
KMOVE_SLOTS = {
    "hem": {"lmb": ["arc_draw", "arc_over", "arc_tap", "arc_loose", "arc_perfect", "arc_over_loose", "arc_super"],
            "rmb": ["arc_heavy_wind", "arc_heavy"], "r": ["pin_ult_loose", "pin_ult_final"], "dash": ["pin_roll", "pin_walk"]},
    "kael": {"lmb": ["jug_slash_r", "jug_slash_l", "jug_wave_wind", "jug_wave"], "rmb": ["jug_slam"],
             "e": ["jug_chain", "jug_reel"], "r": ["jug_guard", "jug_riposte", "jug_ult_recover"], "dash": []},
}


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def glb_clips(path):
    """Clip names of a .glb (its JSON chunk); [] when the file is absent."""
    if not os.path.exists(path):
        return []
    with open(path, "rb") as f:
        head = f.read(20)
        n = struct.unpack("<I", head[12:16])[0]
        return [a.get("name") for a in json.loads(f.read(n)).get("animations", [])]


def native_cells(art, d):
    """Cells of a Hunter drawn on Meshy's skeleton (warden_native.gd): data clips + slots + kmoves, in the file's order."""
    clips = d.get("clips", {})
    have = set(glb_clips(os.path.join(ART, art, art + "_meshy.glb")))
    for f in d.get("clip_files", []) + [os.path.join(ART, art, art + "_clips.glb")]:
        have |= set(glb_clips(f.replace("res://", ROOT + "/")))
    own = lambda key: key in clips and clips[key] in have  # noqa: E731
    km = KMOVE_SLOTS.get(art, {})
    kmoves = set(d.get("kmoves", {}))

    def move(slot, base="shared"):
        if own(slot):
            return "clip"
        got = [k for k in km.get(slot, []) if k in kmoves]
        return "clip" if got and len(got) == len(km[slot]) else "part" if got else base

    out = art in WEAPON_OUT_IDLE and not own("idle_combat")
    return {
        "idle": "WRONG" if out else "clip" if own("idle") else "MISSING",
        "idle_combat": "clip" if own("idle_combat") else "MISSING" if out else "shared",  # (shared: idle holds it low)
        "walk": "clip" if own("walk") else "MISSING", "run": "clip" if own("run") else "MISSING",
        "jump": "clip" if own("jump") else "MISSING",
        "fall": "clip" if own("fall") else "shared",
        "land": "clip" if own("land") else "proc",
        "glide": "clip" if own("glide") else "WRONG",
        "dash": move("dash", "WRONG"),
        "lmb": move("lmb"), "rmb": move("rmb"), "e": move("e"), "r": move("r"),
        "hit": "clip" if own("hit") else "proc",
        "down": "clip" if own("downed") else "WRONG",
        "revive": "clip" if own("revive") else "shared",  # (the crouch pose held, warden_native.gd _loco)
    }


def contract_cells(art):
    """Cells of the contract-path Hunter (warden_clips.gd): the json names the clip, the .glb must carry it."""
    d = load("content/rules/warden_anim/%s.json" % art)
    have = set(glb_clips(os.path.join(ART, art, art + ".glb")))
    air, st = d.get("air", {}), d.get("states", {})
    km = d.get("kmoves", {})

    def has(name):
        return "clip" if name in have else "MISSING"

    def slot(prefix):
        return "clip" if any(k.startswith(prefix) for k in km) else "shared"

    return {
        "idle": has("idle"), "idle_combat": has(d.get("loco", {}).get("stance", "stance")),
        "walk": has("walk_f"), "run": has("run_f"), "jump": has(air.get("rise", "")),
        "fall": has(air.get("fall", "")), "land": has(d.get("land", {}).get("clip", "")),
        "glide": has(air.get("glide", "")),
        "dash": "clip" if any(v.get("dash") for v in km.values()) else "WRONG",
        "lmb": slot("bul_throw"), "rmb": slot("bul_guard"), "e": "clip" if "e_mend" in have else "shared",
        "r": "clip" if "x_slam" in have else "shared",
        "hit": has(st.get("hit", {}).get("front", "")), "down": has(st.get("dead", "")),
        "revive": has(st.get("reviving", "")),
    }


def matrix():
    native = load("content/rules/warden_native.json")
    rows = {}
    for art in sorted(a for a in os.listdir(os.path.join(ROOT, "content/rules/warden_anim")) if a.endswith(".json")):
        art = art[:-5]
        if art == "emote_gestures":
            continue
        d = native.get(art, {})
        rows[art] = native_cells(art, d) if d.get("meshy_native") else contract_cells(art)
    return rows


def gaps(rows):
    return sorted("%s:%s" % (a, s) for a, cells in rows.items() for s in STATES if cells[s] in BAD)


def table(rows, md):
    sep = " | " if md else "  "
    lines = [sep.join(["%-8s" % "hunter"] + ["%-11s" % s for s in STATES])]
    if md:
        lines = ["| " + " | ".join(["hunter"] + STATES) + " |", "|" + "---|" * (len(STATES) + 1)]
    for a, cells in rows.items():
        row = [cells[s] for s in STATES]
        lines.append(("| " + " | ".join([a] + row) + " |") if md else sep.join(["%-8s" % a] + ["%-11s" % c for c in row]))
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    rows = matrix()
    now = gaps(rows)
    known = load("tools/anim_coverage_gaps.json")["gaps"] if os.path.exists(GAPS) else []
    new = [g for g in now if g not in known]
    if "--check" in args:
        if new:
            print("ANIM COVERAGE FAIL: gaps not in tools/anim_coverage_gaps.json (give the state a clip): " + ", ".join(new))
            sys.exit(1)
        print("ANIM COVERAGE OK: %d gaps (listed %d)" % (len(now), len(known)))
        return
    if "--update" in args:
        if new and known:
            print("refusing: new gaps " + ", ".join(new))
            sys.exit(1)
        with open(GAPS, "w", encoding="utf-8") as f:
            json.dump({"doc": "Gap cells (WRONG or MISSING) of tools/anim_coverage.py; the list may only shrink.", "gaps": now}, f, indent=1)
            f.write("\n")
        print("gap list now %d cells" % len(now))
        return
    print(table(rows, "--md" in args))
    print("\n%d gaps: %s" % (len(now), ", ".join(now)))


if __name__ == "__main__":
    main()
