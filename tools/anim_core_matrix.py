#!/usr/bin/env python3
"""Hunter x MUST-clip matrix (own / stock / proc / missing) from content/rules/anim_core_set.json,
warden_native.json, warden_anim/*.json and the clip names inside the .glb files.
Usage: python3 -I tools/anim_core_matrix.py [--json] [--md OUT.md]"""
import glob, json, os, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STOCK = {"Idle", "walk", "run", "Jump_Run", "Attack", "Crouch_Walk_with_Torch", "Armature|clip0|baselayer"}


def anims(path):
    if not os.path.exists(path):
        return []
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    return [a.get("name") for a in json.loads(b[20:20 + n]).get("animations", [])]


def load(p):
    return json.load(open(os.path.join(ROOT, p)))


def native_cells(art, nat, core, cov):
    w = f"art/wardens/{art}"
    clips = nat.get("clips", {})
    mesh = f"{w}/{art}_meshy.glb"
    own_files = [f"{w}/{os.path.basename(x)}" for x in nat.get("clip_files", [])] + glob.glob(f"{ROOT}/{w}/*clips.glb")
    own_names = {n for f in own_files for n in anims(f if os.path.isabs(f) else os.path.join(ROOT, f))}
    cell = {}
    for s, key in (("idle", "idle"), ("walk", "walk"), ("run", "run"), ("jump", "jump"), ("crouch", "crouch")):
        c = clips.get(key, "")
        cell[s] = ("stock" if c in STOCK else "own", mesh + ":" + c)
    for s, key, fb in (("glide", "glide", "stock"), ("dash", "dash", "stock"), ("hit", "hit", "proc"), ("knock", "downed", "stock")):
        cell[s] = ("own", mesh + ":" + clips[key]) if key in clips else (fb, "Meshy Jump_Run / loop clip" if fb == "stock" else "WardenFlinch (proc)")
    km = nat.get("kmoves", {})
    sm = core["hunters"][art].get("slot_moves", {})
    for s in ("lmb", "rmb", "e", "r", "dash_move", "kit_extra"):
        moves = sm.get(s, [])
        if s in clips:
            cell[s] = ("own", mesh + ":" + clips[s]); continue
        have = [m for m in moves if m in km and km[m].get("clip") in own_names]
        if not moves:
            cell[s] = ("stock", "Meshy Attack")
        elif len(have) == len(moves):
            cell[s] = ("own", f"{len(have)}/{len(moves)} " + ",".join(sorted({os.path.basename(f) for f in own_files})))
        elif have:
            cell[s] = ("part", f"{len(have)}/{len(moves)} own; no clip: " + " ".join(m for m in moves if m not in have))
        else:
            cell[s] = ("stock", "Meshy Attack")
    return cell


def contract_cells(art):
    names = set(anims(os.path.join(ROOT, f"art/wardens/{art}/{art}.glb")))
    src = f"art/wardens/{art}/{art}.glb"
    need = {"idle": ["idle"], "walk": ["idle"], "run": ["idle"], "jump": ["jump"], "crouch": ["crouch_idle"], "glide": ["glide"],
            "dash": ["dash_short"], "hit": ["hit_f"], "knock": ["death", "downed"]}
    cell = {s: ("own" if any(n in names for n in v) else "missing", src) for s, v in need.items()}
    for s in ("lmb", "rmb", "e", "r", "dash_move", "kit_extra"):
        cell[s] = ("own", src + " (kmoves, " + str(len(load(f'content/rules/warden_anim/{art}.json').get('kmoves', {}))) + " clips-mapped moves)")
    return cell


def build():
    core, nat = load("content/rules/anim_core_set.json"), load("content/rules/warden_native.json")
    must = [s for s in core["slots"] if s["priority"] == "MUST"]
    rows = {}
    for art in [a for a in core["hunters"] if not a.startswith("_")]:
        n = nat.get(art, {})
        cells = native_cells(art, n, core, None) if n.get("meshy_native") else contract_cells(art)
        gap = [s["id"] for s in must if cells[s["id"]][0] in ("stock", "missing", "part") and not (cells[s["id"]][0] == "stock" and s["stock_ok"]) and not (cells[s["id"]][0] == "proc" and s["stock_ok"])]
        rows[art] = {"cells": cells, "must_gaps": gap}
    return core, must, rows


if __name__ == "__main__":
    core, must, rows = build()
    ids = [s["id"] for s in must]
    sym = {"own": "OWN", "stock": "stock", "proc": "proc", "missing": "MISSING", "part": "part"}
    lines = ["| hunter | " + " | ".join(ids) + " | MUST gaps |", "|" + "---|" * (len(ids) + 2)]
    for art, r in sorted(rows.items(), key=lambda kv: -len(kv[1]["must_gaps"])):
        lines.append(f"| {core['hunters'][art]['name']} ({art}) | " + " | ".join(sym[r["cells"][i][0]] for i in ids) + f" | {len(r['must_gaps'])} |")
    text = "\n".join(lines)
    if "--json" in sys.argv:
        print(json.dumps(rows, indent=1))
    else:
        print(text)
    if "--md" in sys.argv:
        open(sys.argv[sys.argv.index("--md") + 1], "w").write(text + "\n")
