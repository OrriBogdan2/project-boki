#!/usr/bin/env python3
"""Where a Boki's approved 3D model is: the Bokidex one. Owner 11-17: "you are not using the ones we already have"
(nine starters were in the game from fresh Meshy runs while the Bokidex showed a better model of each).

The game model of a species is built from, in order:
  1. the Bokidex master, ~/meshy/boki3d/<dex name>/model.glb (the full Meshy model the Bokidex's web copy is made from);
  2. the Bokidex web copy, ~/coord/boki-tools/rating-room/dex/glb/<dex name>.glb (<=25k tris, Draco: Blender reads it);
  3. a fresh Meshy run, only when neither exists (docs/art/kin/MESHY_BOKI_RECIPE.md).
<dex name> is the species' name in content/kin_v2/<id>.json, lower case (cindle is Vespyx: vespyx), or the id itself
where the Bokidex still files the Boki under it (cairnback).

  python3 tools/boki/dex_source.py <id> ...      prints "<id> <master|web|none> <path>" a line
"""
import json
import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MASTERS = os.path.expanduser("~/meshy/boki3d")
WEB = os.path.expanduser("~/coord/boki-tools/rating-room/dex/glb")


def dex_name(species):
    path = os.path.join(REPO, "content", "kin_v2", species + ".json")
    return json.load(open(path))["name"].lower() if os.path.exists(path) else species


def find(species):
    """(kind, path) of the species' Bokidex model: "master", "web", or ("none", "")."""
    for name in (dex_name(species), species):
        for kind, path in (("master", os.path.join(MASTERS, name, "model.glb")), ("web", os.path.join(WEB, name + ".glb"))):
            if os.path.exists(path):
                return kind, path
    return "none", ""


if __name__ == "__main__":
    for species in sys.argv[1:]:
        print(species, *find(species))
