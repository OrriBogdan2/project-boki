"""A Hunter's current v95 master into the game, its own mesh, UVs and paint (no rebake): one command per Hunter.
The master is ~/meshy/v95/CURRENT_OVERRIDES.txt's last line for the Hunter, else its current.json. The Warden's swap spec
(art/wardens/src/*_v95.json whose `game` is the Hunter's .glb: joints, regions, anchors, `drop_mats`) runs in v95_swap.py's
`keep_uv` mode on the Warden's current .glb (its rig, clips and kept props), then the .glb replaces it and Godot re-imports.
Run: python3 tools/art1/v95_to_game.py <Name> [--tris N] [--tex PX] [--work DIR] [--no-import]
A later Meshy pass promoted into v95 (v95-promote) reaches the game with the same command."""

import argparse
import json
import os
import shutil
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V95 = os.path.expanduser("~/meshy/v95")
BLENDER = os.path.expanduser(os.environ.get("BLENDER", "~/tools/blender-4.5.15-linux-x64/blender"))
ART = {
    "Albert": "breaker",
    "Cinder": "cinder",
    "Gil": "gil",
    "Grimble": "dredge",
    "Kael": "kael",
    "Meeko": "pip",
    "Motley": "ostra",
    "Sable": "sable",
    "Sparkle": "ryzz",
    "Vex": "vex",
    "claire": "claire",
    "lace": "hem",
    "tarek": "tarek",
}
TRIS = 60000  # the body's triangles in game (RIG_CONTRACT "Budget": the v95 masters' own-paint models)
TEX = 4096  # the largest side of each of the master's images in game (px)


def local(path, name):
    """A master path from current.json (hetzner's offload volume) or the overrides (relative to <Name>/), as found here."""
    rel = path.split("/v95/", 1)[1] if "/v95/" in path else os.path.join(name, path)
    for p in (path, os.path.join(V95, rel)):
        if os.path.isabs(p) and os.path.exists(p):
            return p
    sys.exit("v95_to_game: master not on this host: " + path)


def master(name):
    over = None
    for line in open(os.path.join(V95, "CURRENT_OVERRIDES.txt")):
        words = line.split("#", 1)[0].split()
        if len(words) >= 2 and words[0] == name:
            over = words[1]
    if over:
        return local(over if os.path.isabs(over) else os.path.join(V95, name, over), name)
    return local(json.load(open(os.path.join(V95, name, "current.json")))["glb"], name)


def spec_for(art):
    game = "art/wardens/%s/%s.glb" % (art, art)
    src = os.path.join(REPO, "art/wardens/src")
    for f in sorted(os.listdir(src)):
        if f.endswith("_v95.json"):
            spec = json.load(open(os.path.join(src, f)))
            if spec.get("game") == game:
                return spec
    sys.exit("v95_to_game: no swap spec for " + game)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", choices=sorted(ART))
    ap.add_argument("--tris", type=int)
    ap.add_argument("--tex", type=int, default=TEX)
    ap.add_argument("--work")
    ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args()
    art = ART[a.name]
    spec = spec_for(art)
    spec.update(spec.pop("own", {}))  # (the spec's keep_uv-only keys: `drop_mats`, the master's props the game glb has)
    tris = a.tris or spec.get("own_tris", TRIS)
    k = tris / float(spec["tris"])
    spec.update(master=master(a.name), keep_uv=True, tris=tris, tex=a.tex, max_tris=int(tris * 1.1))
    if spec.get("head_tris"):
        spec["head_tris"] = int(spec["head_tris"] * k)
    # (the current .glb already has a fixed-offset move applied: a {bone: [dx, dy, dz]} would move it twice)
    spec["move_bones"] = {b: v for b, v in spec.get("move_bones", {}).items() if isinstance(v, dict)}
    work = os.path.abspath(os.path.expanduser(a.work or "~/meshy/v95/_ingame/%s" % a.name))
    os.makedirs(work, exist_ok=True)
    shutil.copy(os.path.join(REPO, spec["game"]), os.path.join(work, "game.glb"))
    out = os.path.join(work, art + ".glb")
    for f in ("bake.blend", "fit.blend", "swap.blend", out):
        if os.path.exists(os.path.join(work, f)):
            os.remove(os.path.join(work, f))
    path = os.path.join(work, "spec.json")
    json.dump(spec, open(path, "w"), indent=1)
    print("v95_to_game:", a.name, "->", spec["game"], "master", spec["master"], flush=True)
    subprocess.run(
        [
            BLENDER,
            "-b",
            "--factory-startup",
            "--python",
            os.path.join(REPO, "tools/art1/v95_swap.py"),
            "--",
            path,
            work,
            out,
        ],
        check=True,
    )
    shutil.copy(out, os.path.join(REPO, spec["game"]))
    if not a.no_import:
        subprocess.run(["godot", "--headless", "--path", REPO, "--import"], check=True)


main()
