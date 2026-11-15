#!/usr/bin/env python3
"""The private sound pack: library sounds the built game plays instead of the generated ones in audio/.
The pack (PACK/audio/*.wav) lives outside this repo (Sonniss licence v2.0); content/rules/sfx_pack.json only
points at library files. Run with python3 -I.
  sfx_pack.py build MANIFEST LIB PACK GAME   cut the manifest's picks into PACK/audio (needs numpy, ffmpeg);
                                             the cue plus its takes (re-pitched copies, as many as GAME has)
  sfx_pack.py apply PACK GAME                copy PACK/audio/*.wav over GAME/audio (tools/build_web.sh, before the export)
  sfx_pack.py restore PACK GAME              git checkout those files again, so the tree stays clean
  sfx_pack.py check MANIFEST GAME [PACK]     every pick names a game cue that exists (and, with PACK, has its file there)"""

import glob
import json
import os
import shutil
import subprocess
import sys

TAKE_PITCH = [1.0, 0.94, 1.07, 0.89, 1.12]  # base cue, then take 1..4: playback-speed ratio of the picked clip


def build(manifest, lib, pack, game):
    import numpy as np

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sfxclip as C

    os.makedirs(pack + "/audio", exist_ok=True)
    for p in json.load(open(manifest))["picks"]:
        x = C.decode(os.path.join(lib, p["src"]))
        if p["mode"] == "loop":
            y = C.loop_cut(x, p["start"], p["trim_max"])
        else:
            y = C.cut(x, p["start"], p["end"], p["trim_max"])
        takes = len(glob.glob("%s/audio/%s_[0-9]*.wav" % (game, p["cue"])))
        for i in range(1 + (0 if p["mode"] == "loop" else min(takes, 4))):
            r = TAKE_PITCH[i]
            z = np.interp(np.arange(0, len(y) - 1, r), np.arange(len(y)), y)
            name = p["cue"] + ("_%d" % i if i else "")
            C.write_audio(C.level(z, p["rms_db"]), "%s/audio/%s.wav" % (pack, name))
        print("built", p["cue"], "+", takes, "takes")


def pack_files(pack):
    return sorted(os.path.basename(f) for f in glob.glob(pack + "/audio/*.wav"))


def apply(pack, game):
    for f in pack_files(pack):
        shutil.copyfile("%s/audio/%s" % (pack, f), "%s/audio/%s" % (game, f))
    print("applied", len(pack_files(pack)), "pack files")


def restore(pack, game):
    files = ["audio/" + f for f in pack_files(pack)]
    subprocess.run(["git", "-C", game, "checkout", "--"] + files, check=True)


def check(manifest, game, pack=None):
    bad = []
    for p in json.load(open(manifest))["picks"]:
        if not os.path.exists("%s/audio/%s.wav" % (game, p["cue"])):
            bad.append("no game sound audio/%s.wav" % p["cue"])
        if pack and not os.path.exists("%s/audio/%s.wav" % (pack, p["cue"])):
            bad.append("pack lacks %s.wav" % p["cue"])
    print("sfx pack manifest:", "; ".join(bad) if bad else "ok")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    {"build": build, "apply": apply, "restore": restore, "check": check}[cmd](*args)
