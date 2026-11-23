#!/usr/bin/env python3
"""The private sound pack: library sounds the built game plays instead of the generated ones in audio/.
The pack (PACK/audio/*.wav) lives outside this repo (Sonniss licence v2.0); content/rules/sfx_pack.json only
points at library files. Run with python3 -I.
  sfx_pack.py build MANIFEST LIB PACK GAME   cut each slot's pick into PACK/audio (needs numpy, ffmpeg): the cue
                                             plus its takes (re-pitched copies, as many as GAME has)
  sfx_pack.py tester MANIFEST LIB PACK       cut every candidate of the tester slots into PACK/audio/sfxtest/<slot>_<letter>.wav
  sfx_pack.py apply PACK GAME                copy the pack over GAME/audio (tools/build_web.sh, before the export)
  sfx_pack.py restore PACK GAME              put GAME/audio back: git checkout the replaced files, delete audio/sfxtest
  sfx_pack.py check MANIFEST GAME [PACK]     every pick names a game cue that exists (and, with PACK, has its file there)"""

import glob
import json
import os
import shutil
import subprocess
import sys

TAKE_PITCH = [1.0, 0.94, 1.07, 0.89, 1.12]  # base cue, then take 1..4: playback-speed ratio of the picked clip


def cut_pick(C, lib, slot, c):
    """One candidate of a slot, cut and levelled to the live sound's loudness."""
    x = C.decode(os.path.join(lib, c["src"]))
    if slot["mode"] == "loop":
        y = C.loop_cut(x, c["start"], slot["trim_max"])
    else:
        y = C.cut(x, c["start"], c["end"], slot["trim_max"])
    return C.level(y, slot["rms_db"])


def picked(manifest):
    """(slot, candidate) for every slot that has a pick."""
    for s in json.load(open(manifest))["slots"]:
        for c in s["candidates"]:
            if c["letter"] == s["pick"]:
                yield s, c


def build(manifest, lib, pack, game):
    import numpy as np

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sfxclip as C

    os.makedirs(pack + "/audio", exist_ok=True)
    for old in pack_files(pack):  # a pick that was dropped must not linger in the pack
        os.remove("%s/audio/%s" % (pack, old))
    for s, c in picked(manifest):
        y = cut_pick(C, lib, s, c)
        takes = len(glob.glob("%s/audio/%s_[0-9]*.wav" % (game, s["cue"])))
        for i in range(1 + (0 if s["mode"] == "loop" else min(takes, 4))):
            r = TAKE_PITCH[i]
            z = np.interp(np.arange(0, len(y) - 1, r), np.arange(len(y)), y)
            C.write_audio(z, "%s/audio/%s.wav" % (pack, s["cue"] + ("_%d" % i if i else "")))
        print("built", s["cue"], "+", takes, "takes")


def tester(manifest, lib, pack):
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sfxclip as C

    out = pack + "/audio/sfxtest"
    os.makedirs(out, exist_ok=True)
    n = 0
    for s in json.load(open(manifest))["slots"]:
        for c in s["candidates"] if s.get("tester") else []:
            C.write_audio(cut_pick(C, lib, s, c), "%s/%s_%s.wav" % (out, s["slot"], c["letter"]))
            n += 1
    print("tester clips", n)


def pack_files(pack):
    return sorted(os.path.basename(f) for f in glob.glob(pack + "/audio/*.wav"))


def tester_files(pack):
    return sorted(glob.glob(pack + "/audio/sfxtest/*.wav"))


def apply(pack, game):
    for f in pack_files(pack):
        shutil.copyfile("%s/audio/%s" % (pack, f), "%s/audio/%s" % (game, f))
    os.makedirs(game + "/audio/sfxtest", exist_ok=True)
    for f in tester_files(pack):
        shutil.copyfile(f, game + "/audio/sfxtest/" + os.path.basename(f))
    print("applied", len(pack_files(pack)), "pack files,", len(tester_files(pack)), "tester clips")


def restore(pack, game):
    files = ["audio/" + f for f in pack_files(pack)]
    subprocess.run(["git", "-C", game, "checkout", "--"] + files, check=True)
    shutil.rmtree(game + "/audio/sfxtest", ignore_errors=True)


def check(manifest, game, pack=None):
    bad = []
    for s, _ in picked(manifest):
        if not os.path.exists("%s/audio/%s.wav" % (game, s["cue"])):
            bad.append("no game sound audio/%s.wav" % s["cue"])
        if pack and not os.path.exists("%s/audio/%s.wav" % (pack, s["cue"])):
            bad.append("pack lacks %s.wav" % s["cue"])
    print("sfx pack manifest:", "; ".join(bad) if bad else "ok")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    cmd, args = sys.argv[1], sys.argv[2:]
    {"build": build, "tester": tester, "apply": apply, "restore": restore, "check": check}[cmd](*args)
