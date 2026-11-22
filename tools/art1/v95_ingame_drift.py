"""Does the game load each Hunter's approved v95 model? (docs/heroes/V95_CONTACT.md "In-game drift")
Per Hunter: the master ~/meshy/v95 names (CURRENT_OVERRIDES.txt's last line for it, else current.json;
against the .glb the game loads (art/wardens/<art>/<art>.glb, WardenGlb.ART): blob hash, triangles, clips.
Run: python3 tools/art1/v95_ingame_drift.py [--ref REF] [--md]
(REF reads the game .glb from a git ref, default the working tree)
Exit 0 = every Hunter matches, 1 = drift or a master missing on this host."""

import argparse
import ast
import json
import os
import struct
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V95 = os.path.expanduser("~/meshy/v95")


def _art():
    """v95_to_game.py's ART (v95 name -> art name); read, not imported (that script parses its arguments on import)."""
    tree = ast.parse(open(os.path.join(os.path.dirname(__file__), "v95_to_game.py")).read())
    for node in tree.body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "ART":
            return ast.literal_eval(node.value)
    sys.exit("v95_ingame_drift: no ART in v95_to_game.py")


ART = _art()


def master_path(name):
    """The approved master's path as written (overrides' last line, else current.json), or None."""
    over = None
    for line in open(os.path.join(V95, "CURRENT_OVERRIDES.txt")):
        words = line.split("#", 1)[0].split()
        if len(words) >= 2 and words[0] == name:
            over = words[1] if os.path.isabs(words[1]) else os.path.join(V95, name, words[1])
    if over:
        return over
    cur = os.path.join(V95, name, "current.json")
    return json.load(open(cur))["glb"] if os.path.exists(cur) else None


def glb_info(data):
    """Triangles (every mesh primitive, mode 4) and animation names of a .glb's bytes."""
    n = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20 : 20 + n])
    acc = gltf.get("accessors", [])
    tris = 0
    for mesh in gltf.get("meshes", []):
        for prim in mesh["primitives"]:
            if prim.get("mode", 4) != 4:
                continue
            if "indices" in prim:
                tris += acc[prim["indices"]]["count"] // 3
            else:
                tris += acc[prim["attributes"]["POSITION"]]["count"] // 3
    clips = sorted(a.get("name", "") for a in gltf.get("animations", []))
    return tris, clips


def blob(data):
    return (
        subprocess.run(["git", "hash-object", "--stdin"], input=data, capture_output=True, cwd=REPO)
        .stdout.decode()
        .strip()
    )


def game_bytes(art, ref):
    path = "art/wardens/%s/%s.glb" % (art, art)
    if ref:
        return path, subprocess.run(["git", "show", "%s:%s" % (ref, path)], capture_output=True, cwd=REPO).stdout
    return path, open(os.path.join(REPO, path), "rb").read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", default="", help="git ref to read the game .glb from")
    ap.add_argument("--md", action="store_true", help="print a Markdown table")
    a = ap.parse_args()
    rows, bad = [], 0
    for name, art in sorted(ART.items(), key=lambda kv: kv[0].lower()):
        path, gdata = game_bytes(art, a.ref)
        gtris, gclips = glb_info(gdata)
        gblob = blob(gdata)
        mpath = master_path(name)
        if not mpath or not os.path.exists(mpath):
            rows.append((name, mpath or "-", path, gblob[:11], "-", gtris, "-", len(gclips), "master missing here"))
            bad += 1
            continue
        mdata = open(mpath, "rb").read()
        mtris, mclips = glb_info(mdata)
        mblob = blob(mdata)
        same = mblob == gblob
        why = (
            "yes"
            if same
            else "no: "
            + ", ".join(w for w, d in (("hash", True), ("tris", mtris != gtris), ("clips", mclips != gclips)) if d)
        )
        bad += not same
        rows.append(
            (
                name,
                mpath.replace(os.path.expanduser("~"), "~"),
                path,
                gblob[:11],
                mblob[:11],
                gtris,
                mtris,
                len(gclips),
                why,
            )
        )
    if a.md:
        cols = ["Hunter", "current.json / override glb", "game glb", "game blob", "master blob", "game tris"]
        print("| " + " | ".join(cols + ["master tris", "clips", "match"]) + " |")
        print("|---|---|---|---|---|---|---|---|---|")
        for r in rows:
            print("| %s | `%s` | `%s` | %s | %s | %s | %s | %s | %s |" % r)
    else:
        for r in rows:
            print("  ".join(str(x) for x in r))
    print("v95_ingame_drift: %d of %d match" % (len(rows) - bad, len(rows)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
