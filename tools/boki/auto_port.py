#!/usr/bin/env python3
"""Puts Bokidex models in the game on the rig each species has (or the glomwort one), with no hand-read landmarks:
boki_prep (the model into ~/meshy/boki/<id>/<run>), boki_scan's "auto" fit (proxy bounds to scan bounds), the FRAME row
through that fit, the registrations in boki_rig_check.gd, then the build into art/kin/<id>/.

The model is the species' Bokidex one (tools/boki/dex_source.py: the master, else the web copy), run "dex": the row in
boki_scan.AUTO must say {"run": "dex"}. <id>=<model.glb> (run "run1") is only for a Boki the Bokidex has no 3D of; any
other model is refused (owner 11-17: the Bokidex models are the approved ones).

  python3 tools/boki/auto_port.py <id> ...      (a species once only: its FRAME row moves through the fit; a species
                                                 that changes model goes back first, build_boki.py --unfit)
"""
import os
import re
import subprocess
import sys

import dex_source

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLENDER = os.path.expanduser("~/tools/blender-4.5.15-linux-x64/blender")
TOOLS = os.path.join(REPO, "tools", "boki")
RIG = os.path.join(REPO, "scripts", "match", "boki_rig.gd")
CHECK = os.path.join(REPO, "tools", "boki_rig_check.gd")
SHEETS = os.path.expanduser("~/cj/20261116-203744-a2/w")


def blender(*args):
    out = subprocess.run([BLENDER, "-b", "--factory-startup", "--python", *args], capture_output=True, text=True).stdout
    return out


def proxy_of(species):
    spec = re.search(r'"%s": \("(\w+)"' % species, open(os.path.join(TOOLS, "build_boki.py")).read())
    return spec.group(1) if spec else "glomwort"  # the borrowed rig (build_boki.SPECS builds those rows)


def row_of(text, species):
    return re.search(r'\t"%s": \{.*?\}\},\n' % species, text, re.S)


def frame(species):
    text = open(RIG).read()
    if row_of(text, species) is None:  # a new id starts on its proxy species' row
        proxy = row_of(text, proxy_of(species)).group(0)
        text = text.replace("const FRAME := {\n", "const FRAME := {\n" + proxy.replace('"%s"' % proxy_of(species), '"%s"' % species, 1), 1)
        open(RIG, "w").write(text)
    out = blender(os.path.join(TOOLS, "build_boki.py"), "--", "--species=" + species, "--no-export", "--fit-sheet=%s/fit_%s.png" % (SHEETS, species))
    moved = out.split("FRAME row through the fit:\n", 1)[1].split("\nBlender", 1)[0].rstrip("\n") + "\n"
    text = open(RIG).read()
    open(RIG, "w").write(text.replace(row_of(text, species).group(0), moved, 1))


def check_lists(species):
    text = open(CHECK).read()
    text = text.replace('"floenatee"]', '"floenatee", "%s"]' % species, 1) if '"%s"' % species not in text.split("const MAX_TRIS")[0] else text
    if '"%s": MESHY_TRIS' % species not in text:
        text = text.replace('"selenfin": MESHY_TRIS}', '"selenfin": MESHY_TRIS, "%s": MESHY_TRIS}' % species, 1)
    open(CHECK, "w").write(text)


def source(species, given):
    """(model, run) to build the species from: its Bokidex model, or `given` where the Bokidex has none."""
    kind, path = dex_source.find(species)
    if kind == "none":
        if not given:
            raise SystemExit("%s: the Bokidex has no 3D of it; pass %s=<model.glb> (a fresh Meshy run)" % (species, species))
        return given, "run1"
    if given and os.path.realpath(given) != os.path.realpath(path):
        raise SystemExit("%s: the Bokidex has a model (%s); the game is built from that one" % (species, path))
    row = re.search(r'\n    "%s": .*?(?=\n    "|\n})' % species, open(os.path.join(TOOLS, "boki_scan.py")).read(), re.S)
    if row is None or '"run": "dex"' not in row.group(0):
        raise SystemExit('%s: give its boki_scan.AUTO row "run": "dex" first' % species)
    return path, "dex"


def main(pairs):
    for pair in pairs:
        species, _, glb = pair.partition("=")
        try:
            glb, run = source(species, glb)
            print(species, re.search(r"EXT.*", blender(os.path.join(TOOLS, "boki_prep.py"), "--", species, glb, run)).group(0), flush=True)
            frame(species)
            blender(os.path.join(TOOLS, "build_boki.py"), "--", "--species=" + species)
            print(species, "built", os.path.getsize(os.path.join(REPO, "art/kin", species, species + ".glb")) // 1024, "KB", flush=True)
            check_lists(species)
        except Exception as e:  # one species failing leaves the rest to go on
            print(species, "FAILED", repr(e)[:150], flush=True)


main(sys.argv[1:])
