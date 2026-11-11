#!/usr/bin/env python3
"""Brings the early-zone Meshy Boki into the game; safe to re-run as more models finish.

For every species of the zone batches whose raw model exists (/home/boki/meshy/boki3d/<name>/model.glb):
  1. game-ready it with Blender (tools/blender/meshy_gameready.py) into art/kin/<id>/<name>_m3d.glb + _atlas.webp
  2. write its kin data (content/kin_v2, content/kin) when the species is new to the game (existing ids keep theirs)
  3. write content/kin_models.json (model rows) and content/zone_pools.json (zone -> kin ids).
A species the game already has under another id (same display name, e.g. vespyx = cindle) reuses that id.
Usage: tools/boki/zone_sync.py [--jobs N] [--redo name,name] [--no-blender]
"""
import json, glob, os, subprocess, sys, hashlib, colorsys, argparse, re
from concurrent.futures import ThreadPoolExecutor

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = "/home/boki/meshy/boki3d"
DEX = "/home/boki/coord/boki-tools/rating-room/dex/dex.json"
BLENDER = os.path.expanduser("~/tools/blender-4.5.15-linux-x64/blender")
REDO = {"ermink", "lunink", "blossmink", "prismink", "eclipsowl", "zipling"}   # flagged in REDO.txt: swap the model when redone

ZONES = {
    "0": "vespyx vespox glaivyx prismander glassolotl chandelotl mycroll sporcupine ringrove ermink flarmink rippmink "
         "blossmink voltmink rimink umbrink lunink prismink wyrmink gravadillo gravitank mothlet lunowl eclipsowl echolop "
         "howlop moatpole rampartoad zipling zippelith".split(),
    "1": "seamwyrm anchorbill anchorhorn bellowlet furnacowary wickapi snuffapi chandelapi coolatee frigatee glaciatee "
         "gongibbon gongrowl kayak prowyak dreadnoyak glintmole geodemole druzemole gloamshell gloamspire glomwort "
         "glomworth effigeetle effigoon mortarfly crofthorn crofthollow skidlet skateron".split(),
}
THEME_OF_TYPE = {"Poison": "venom", "Spore": "spore", "Crystal": "prism", "Psychic": "gravity", "Bug": "swarm",
                 "Sound": "echo", "Rock": "stone", "Steel": "titan", "Flying": "tempest", "Fairy": "lunar",
                 "Dark": "shadow", "Ice": "frost", "Fire": "ember", "Grass": "bloom", "Water": "prism",
                 "Electric": "storm", "Dragon": "tempest", "Normal": "bloom"}
# a theme with no kin of the wanted size borrows from these
THEME_FALLBACK = {"stone": ["titan"], "shadow": ["lunar", "tempest"], "frost": ["prism", "titan"], "ember": ["venom", "tempest"],
                  "bloom": ["prism", "spore"], "storm": ["echo", "tempest"], "titan": ["stone", "gravity"]}
SIZE_NUDGE = {"small": 0, "medium": 1, "large": 2}


def jload(p):
    return json.load(open(p))


def jsave(p, d):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(d, f, indent="\t", ensure_ascii=False)
        f.write("\n")


def original_ids():
    out = subprocess.run(["git", "-C", REPO, "ls-tree", "--name-only", "origin/main", "content/kin_v2/"],
                         capture_output=True, text=True).stdout.split()
    return [os.path.basename(x)[:-5] for x in out if x.endswith(".json")]


def size_class(entry, existing_size):
    if existing_size:
        return existing_size
    m = re.match(r"(\d+) to (\d+)", entry.get("size") or "")
    if m:
        mid = (int(m.group(1)) + int(m.group(2))) / 2
        return "small" if mid < 42 else ("medium" if mid < 58 else "large")
    return {1: "small", 2: "medium"}.get(entry.get("stage", 1), "medium")


def h(s, n):
    return int(hashlib.md5(s.encode()).hexdigest(), 16) % n


def hexrgb(c):
    return tuple(int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))


def tohex(rgb):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v * 255)))) for v in rgb)


def shiny_of(colors):
    out = {}
    for k in ("body", "belly", "glow"):
        r, g, b = hexrgb(colors[k])
        hh, s, v = colorsys.rgb_to_hsv(r, g, b)
        out["color" if k == "body" else k] = tohex(colorsys.hsv_to_rgb((hh + (0.42 if k != "belly" else 0.1)) % 1, min(1, s * 0.9 + 0.1), v))
    return out


def pick_template(theme, size, name, originals, kin):
    for th in [theme] + THEME_FALLBACK.get(theme, []):
        c = [i for i in originals if kin[i]["theme"] == th and kin[i]["body"]["size"] == size]
        if c:
            return c[h(name, len(c))]
    c = [i for i in originals if kin[i]["body"]["size"] == size]
    return c[h(name, len(c))]


def make_kin(name, entry, size, model, originals, kin, homes):
    types = entry["types"]
    theme = THEME_OF_TYPE[types[0]]
    t = kin[pick_template(theme, size, name, originals, kin)]
    k = json.loads(json.dumps(t))
    k["id"] = name
    k["name"] = name.capitalize()
    first = re.split(r" whose | with | that |,| who | in | on ", entry.get("entry") or "", 1)[0].strip()
    k["animals"] = [first[:30] or name.capitalize()]
    k["theme"] = theme
    k["flavor"] = (entry.get("entry") or k["flavor"]).strip()
    cols = model.get("colors") or t["colors"]
    k["colors"] = {"body": cols["body"], "belly": cols["belly"], "glow": cols["glow"]}
    for key, dev in (("bravery", 0.1), ("loyalty", 0.1), ("temper", 0.1), ("curiosity", 0.1)):
        k["personality"][key] = round(min(1.0, max(0.0, t["personality"][key] + ((h(name + key, 21) - 10) / 10) * dev)), 2)
    if size == "large" and "mount" in k["carry"]:
        k["carry"]["mount"]["speed"] = min(k["carry"]["mount"]["speed"], 1.0)     # not a new rideable (roster cap 4-6)
    half = max(2, len(name) // 2)
    k["voice"] = {"line": t["voice"]["line"], "syllables": [name[:half].capitalize(), name[half:]]}
    root = name.capitalize()[:4]
    keep = []
    for p in t["evolution"]["paths"]:
        nodes = [n for n in p["nodes"] if n.endswith("_form")]
        if nodes:
            keep.append({"affinity": p["affinity"], "nodes": nodes})
    k["evolution"] = {"root": root, "paths": keep}
    k["egg"] = {"name": f"{name.capitalize()} Egg", "temper": t["egg"]["temper"], "desc": t["egg"]["desc"], "play": t["egg"]["play"]}
    # carry names are per kin
    k["carry"]["name"] = t["carry"]["name"]
    home = json.loads(json.dumps(homes[t["id"]]))
    home["id"] = name
    home["shiny"] = shiny_of(k["colors"])
    cm = {"small": 24, "medium": 38, "large": 60}[size]
    m = re.match(r"(\d+) to (\d+)", entry.get("size") or "")
    if m:
        cm = (int(m.group(1)) + int(m.group(2))) // 2
    home["size"] = {"cm": cm, "kg": round(cm * cm / 2400.0 + 0.5, 1), "_doc": home["size"]["_doc"]}
    home["line"] = {"dex": name, "stage": entry.get("stage"), "stages": entry.get("stages"),
                    "prev": entry.get("prev", []), "next": entry.get("next", []),
                    "_doc": "its evolution line in the dex; the game evolves by affinity form within a species, so the line is data only"}
    return k, home


def blender_job(args):
    src, out_dir, name, size, = args
    r = subprocess.run(["nice", "-n", "10", BLENDER, "-b", "-P", os.path.join(REPO, "tools/blender/meshy_gameready.py"),
                        "--", src, out_dir, name, size], capture_output=True, text=True)
    ok = os.path.exists(os.path.join(out_dir, name + ".glb"))
    tail = [l for l in r.stdout.splitlines() if l.startswith("RESULT")] or r.stdout.splitlines()[-3:] + r.stderr.splitlines()[-3:]
    print(("ok  " if ok else "FAIL"), name, tail[-1][:160] if tail else "")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--redo", default="")
    ap.add_argument("--no-blender", action="store_true")
    ar = ap.parse_args()
    redo = set(filter(None, ar.redo.split(",")))
    dex = {e["id"]: e for e in jload(DEX)["entries"]}
    originals = original_ids()
    kin = {i: jload(f"{REPO}/content/kin_v2/{i}.json") for i in originals}
    homes = {i: jload(f"{REPO}/content/kin/{i}.json") for i in originals}
    by_name = {v["name"].lower(): i for i, v in kin.items()}
    jobs, plan = [], []
    for zone, names in ZONES.items():
        for n in names:
            raw = f"{RAW}/{n}/model.glb"
            if not os.path.exists(raw):
                continue
            gid = by_name.get(n, n)
            size = size_class(dex[n], kin[gid]["body"]["size"] if gid in kin else None)
            out_dir = f"{REPO}/art/kin/{gid}"
            plan.append((zone, n, gid, size, out_dir))
            if (n in redo or not os.path.exists(f"{out_dir}/{n}_m3d.glb")) and not ar.no_blender:
                jobs.append((raw, out_dir, n + "_m3d", size))
    print(f"{len(plan)} models ready, {len(jobs)} to build")
    with ThreadPoolExecutor(ar.jobs) as ex:
        list(ex.map(blender_job, jobs))
    rows, pools, made = {}, {z: [] for z in ZONES}, []
    for zone, n, gid, size, out_dir in plan:
        mj = f"{out_dir}/{n}_m3d.json"
        if not os.path.exists(f"{out_dir}/{n}_m3d.glb") or not os.path.exists(mj):
            print("skip (no game-ready model)", n)
            continue
        m = jload(mj)
        if gid not in kin and not os.path.exists(f"{REPO}/content/kin_v2/{gid}.json"):
            k, home = make_kin(n, dex[n], size, m, originals, kin, homes)
            jsave(f"{REPO}/content/kin_v2/{gid}.json", k)
            jsave(f"{REPO}/content/kin/{gid}.json", home)
            made.append(gid)
        H, hw, fr, bk = m["height"], m["half_w"], m["front"], m["back"]
        rows[gid] = {"dex": n, "glb": f"res://art/kin/{gid}/{n}_m3d.glb", "atlas": f"res://art/kin/{gid}/{n}_m3d_atlas.webp",
                     "tris": m["tris"], "size": size, "redo": n in REDO,
                     "frame": {"head": [0, round(H * 0.8, 3), round(fr * 0.85, 3)], "top": H,
                               "carry": [0, round(H * 0.95, 3), 0.05], "ear_tip": [round(hw * 0.5, 3), H, round(fr * 0.3, 3)],
                               "tail_tip": [0, round(H * 0.5, 3), bk]}}
        pools[zone].append(gid)
    jsave(f"{REPO}/content/kin_models.json", {"_doc": "kin id -> Meshy model row (MeshyKin). tools/boki/zone_sync.py writes it.", "kin": rows})
    jsave(f"{REPO}/content/zone_pools.json", {"_doc": "zone (expedition tier) -> the only kin that spawn wild there; each needs a 3D model "
                                              "(tools/zone_pool_check.gd). Other tiers keep Data.common_kin() minus every kin listed here.",
                                              "zones": pools})
    left = {z: [n for n in ZONES[z] if not os.path.exists(f"{RAW}/{n}/model.glb")] for z in ZONES}
    print("new kin written:", len(made), "| pools:", {z: len(v) for z, v in pools.items()}, "| raw not ready:", {z: len(v) for z, v in left.items()})


if __name__ == "__main__":
    main()
