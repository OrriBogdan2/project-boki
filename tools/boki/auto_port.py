#!/usr/bin/env python3
"""Puts finished Meshy models in the game on the rig each species has (or the glomwort one), with no hand-read landmarks:
boki_prep (the model into ~/meshy/boki/<id>/run1), boki_scan's "auto" fit (proxy bounds to scan bounds), the FRAME row
through that fit, the registrations in boki_rig_check.gd, then the build into art/kin/<id>/.

  python3 tools/boki/auto_port.py <id>=<model.glb> ...      (a species once only: its FRAME row moves through the fit)
"""
import os
import re
import subprocess
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLENDER = os.path.expanduser("~/tools/blender-4.5.15-linux-x64/blender")
TOOLS = os.path.join(REPO, "tools", "boki")
RIG = os.path.join(REPO, "scripts", "match", "boki_rig.gd")
CHECK = os.path.join(REPO, "tools", "boki_rig_check.gd")
SHEETS = os.environ.get("SHEETS", os.path.expanduser("~/cj/20261116-203744-a2/w"))


def blender(*args):
    out = subprocess.run([BLENDER, "-b", "--factory-startup", "--python", *args], capture_output=True, text=True).stdout
    return out


def proxy_of(species):
    spec = re.search(r'"%s": \("(\w+)"' % species, open(os.path.join(TOOLS, "build_boki.py")).read())
    return spec.group(1) if spec else "glomwort"  # the borrowed rig (build_boki.SPECS builds those rows)


def row_of(text, species):
    return re.search(r'\t"%s": \{.*?\}\},\n' % species, text, re.S)


def first_row(species):
    """The species' FRAME row as its primitive rig first had it in full (its own coordinates, before a scan's fit moved it)."""
    log = subprocess.run(["git", "log", "--reverse", "--format=%h", "--", "scripts/match/boki_rig.gd"], cwd=REPO,
                         capture_output=True, text=True).stdout.split()
    for commit in log:
        text = subprocess.run(["git", "show", commit + ":scripts/match/boki_rig.gd"], cwd=REPO, capture_output=True,
                              text=True).stdout
        row = row_of(text, species)
        if row is not None and '"marks"' in row.group(0):
            return row.group(0)


def frame(species):
    """The FRAME row: the proxy's own first row (never one an older scan's fit already moved), then through this fit."""
    text = open(RIG).read()
    proxy = proxy_of(species)
    start = first_row(species if proxy != "glomwort" or species == "glomwort" else "glomwort")
    start = start.replace('"%s"' % (species if proxy != "glomwort" or species == "glomwort" else "glomwort"), '"%s"' % species, 1)
    if row_of(text, species) is None:
        text = text.replace("const FRAME := {\n", "const FRAME := {\n" + start, 1)
    else:
        text = text.replace(row_of(text, species).group(0), start, 1)
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


def main(pairs):
    for pair in pairs:
        species, glb = pair.split("=")
        try:
            print(species, re.search(r"EXT.*", blender(os.path.join(TOOLS, "boki_prep.py"), "--", species, glb)).group(0), flush=True)
            frame(species)
            blender(os.path.join(TOOLS, "build_boki.py"), "--", "--species=" + species)
            print(species, "built", os.path.getsize(os.path.join(REPO, "art/kin", species, species + ".glb")) // 1024, "KB", flush=True)
            check_lists(species)
        except Exception as e:  # one species failing leaves the rest to go on
            print(species, "FAILED", repr(e)[:150], flush=True)


main(sys.argv[1:])
