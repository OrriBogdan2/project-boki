#!/usr/bin/env python3
"""Synthetic checks for suite_speed.py: a fake godot and two tiny git trees. Run: python3 test_suite_speed.py"""

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import suite_speed as ss  # noqa: E402

FAKE = """#!/bin/sh
# fake godot: --headless --path TREE -- FLAG ; behaviour from $FAKE_MODE and $FAKE_RED (space list of flags)
for a; do last=$a; done
case "$FAKE_MODE" in
  broken) echo "ERROR: no display"; exit 1;;
  mismatch) echo "X DONE, failures: 0"; exit 1;;
  hang) case " $FAKE_CRASH " in *" $last "*) echo "SCRIPT ERROR: slow"; exit 124;; esac;;
  crash) case " $FAKE_CRASH " in *" $last "*) echo "SCRIPT ERROR: boom"; exit 1;; esac;;
esac
case "$*" in *"/merge "*) case " $FAKE_RED_MERGE " in *" $last "*) echo "X DONE, failures: 1"; exit 1;; esac;; esac
case " $FAKE_RED " in *" $last "*) echo "X DONE, failures: 2"; exit 1;; esac
echo "X DONE, failures: 0"; exit 0
"""

REG = """class_name CheckRegistry
const CHECKS := {
%s
}
static func run(main, args):
\treturn false
"""


def sh(cwd, *cmd):
    subprocess.run(cmd, cwd=cwd, check=True, capture_output=True)


def make_tree(root, n=12):
    root.mkdir(parents=True)
    (root / "tools").mkdir()
    (root / "scripts").mkdir()
    (root / "art/kael").mkdir(parents=True)
    ents = []
    for i in range(n):
        ents.append(f'\t"--c{i}-check": ["res://tools/c{i}_check.gd", "c{i}", null],')
        dep = "Hero" if i == 0 else "Util"
        (root / f"tools/c{i}_check.gd").write_text(f"extends RefCounted\nfunc run(m):\n\t{dep}.go()\n")
    (root / "tools/check_registry.gd").write_text(REG % "\n".join(ents))
    (root / "scripts/main.gd").write_text('extends Node\nfunc _ready():\n\tif "--inline-check" in args:\n\t\tpass\n')
    (root / "scripts/hero.gd").write_text('class_name Hero\nfunc go():\n\tload("res://art/" + "kael/kael.glb")\n')
    (root / "scripts/util.gd").write_text("class_name Util\nfunc go():\n\tpass\n")
    (root / "scripts/skin.gd").write_text('class_name Skin\nconst DIR := "res://art/kael/"\n')
    (root / "tools/c0_check.gd").write_text("extends RefCounted\nfunc run(m):\n\tHero.go()\n\tSkin.new()\n")
    (root / "art/kael/kael.glb").write_bytes(b"glb")
    (root / "project.godot").write_text("[application]\n")
    sh(root, "git", "init", "-q")
    sh(root, "git", "add", "-A")
    sh(root, "git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base")


def gate(tmp, name, env, *extra):
    out = tmp / name
    os.environ.update(env)
    rc = ss.main(
        ["gate", "--main", str(tmp / "main"), "--merge", str(tmp / "merge"), "--out", str(out), "--jobs", "4",
         "--godot", str(tmp / "godot"), "--cache-dir", str(tmp / "cache"), "--history", str(tmp / "hist.tsv"),
         "--alert-file", str(tmp / "ALERT"), "--canary=--c1-check,--c2-check,--c3-check,--c4-check", *extra]
    )
    runs = sum(1 for _ in out.rglob("*.secs"))
    return rc, (out / "summary.txt").read_text(), runs


def main():
    ok = True

    def expect(cond, what):
        nonlocal ok
        print(("ok   " if cond else "FAIL ") + what)
        ok &= bool(cond)

    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        (tmp / "godot").write_text(FAKE)
        (tmp / "godot").chmod(0o755)
        make_tree(tmp / "main")
        make_tree(tmp / "merge")
        base = {"FAKE_MODE": "", "FAKE_RED": "", "FAKE_CRASH": "", "FAKE_RED_MERGE": ""}

        rc, summ, runs = gate(tmp, "broken", {**base, "FAKE_MODE": "broken"})
        expect(rc == 3 and "ENV-BROKEN: canary 4/4" in summ, "broken env stops at the canary with ENV-BROKEN")
        expect(runs == 8, f"broken env ran only the canary pairs (8 runs, got {runs})")
        expect((tmp / "ALERT").exists() and "ENV-BROKEN" in (tmp / "ALERT").read_text(), "alert file written")
        expect(not (tmp / "cache").exists(), "an ENV-BROKEN gate caches nothing")
        (tmp / "ALERT").unlink()

        rc, summ, _ = gate(tmp, "mism", {**base, "FAKE_MODE": "mismatch"})
        expect(rc == 3 and "disagrees" in summ, "rc 1 with 'failures: 0' is ENV-BROKEN")

        rc, summ, runs = gate(tmp, "mass", {**base, "FAKE_MODE": "broken"}, "--no-canary", "--massred-min", "4")
        expect(rc == 3 and "mass red" in summ and runs < 26, f"mass-red guard stops a run ({runs} of 26 runs)")

        red = {**base, "FAKE_MODE": "crash", "FAKE_RED": "--c5-check --c6-check", "FAKE_CRASH": "--c7-check"}
        rc, summ, runs = gate(tmp, "first", red)
        expect(rc == 0 and runs == 26 and "red on both 3" in summ, "first gate: full run, 3 reds on both, no NEW-RED")
        cached = sorted(p.name for p in (tmp / "cache").rglob("*.json"))
        expect("c5-check.json" in cached and "c7-check.json" not in cached, "judged red cached, crash red not")

        red2 = {**red, "FAKE_RED": "--c5-check --c6-check --c8-check"}
        rc, summ, runs = gate(tmp, "second", red2)
        expect("8 main results from cache" in summ, "second gate reads main from the cache")
        expect(runs == 8 + 9 + 1, f"second gate runs canary pairs + other merge flags + the uncached crash ({runs})")
        expect(rc == 1 and "NEW-RED 1: --c8-check" in summ, "a cached green still makes a merge red NEW-RED")
        expect("--c5-check" in summ.split("red on both")[1].split("\n")[0], "a cached red still counts as red")

        lz = {**red, "FAKE_RED_MERGE": "--c9-check"}
        rc, summ, runs = gate(tmp, "lazy", lz, "--no-cache", "--main-lazy")
        main_runs = sum(1 for _ in (tmp / "lazy/main").glob("*.secs"))
        expect(rc == 1 and "NEW-RED 1: --c9-check" in summ, "lazy: a merge red against a main green is NEW-RED")
        expect("red on both 3" in summ, "lazy: reds on both trees still found")
        expect(main_runs == 4 + 4, f"lazy: main runs = 4 canaries + 4 merge reds ({main_runs})")
        rc, summ, runs = gate(tmp, "lazyb", {**base, "FAKE_MODE": "broken"}, "--no-canary", "--massred-min", "4",
                              "--main-lazy", "--no-cache")
        expect(rc == 3 and "mass red" in summ, "lazy: mass-red guard still stops a broken env")
        ok_env = {**base, "FAKE_RED": " ".join(f"--c{i}-check" for i in range(5, 12))}
        rc, summ, runs = gate(tmp, "lazyok", ok_env, "--no-canary", "--massred-min", "4", "--main-lazy", "--no-cache")
        expect(rc == 0 and "ENV-BROKEN" not in summ, "lazy: 7/13 red on both (a sane red-heavy tree) is no ENV-BROKEN")

        hang = {**base, "FAKE_MODE": "hang", "FAKE_CRASH": "--c10-check"}
        args = ("--no-canary", "--cache-dir", str(tmp / "tcache"))
        gate(tmp, "to1", hang, *args)
        tc = tmp / "tcache"
        expect(not list(tc.rglob("c10-check.json")), "a first main timeout is not cached")
        rc, summ, _ = gate(tmp, "to2", hang, *args)
        expect(list(tc.rglob("c10-check.json")), "a second timeout in a row is cached")
        rc, summ, runs = gate(tmp, "to3", hang, *args)
        expect("main timeouts from cache (timed out in 2+ gates) 1: --c10-check" in summ and "red on both 1" in summ
               and runs == 13, f"third gate: cached timeout counts as red, main not re-run ({runs} runs)")

        hist = tmp / "h.tsv"
        hist.write_text("--c1-check\t5\n--c2-check\t50\n--c2-check\t60\n--c3-check\t20\n")
        order = ss.order_flags(["--c1-check", "--c2-check", "--c3-check", "--new-check"], ss.load_history(hist))
        expect(order[:2] == ["--c2-check", "--new-check"] and order[-1] == "--c1-check", f"longest-first {order}")
        expect(ss.simulate(["a", "b", "c"], {"a": 1, "b": 1, "c": 2}, 2) == 3, "simulate: list scheduling")

        m = tmp / "merge"
        sh(m, "git", "checkout", "-qb", "x")
        reg = (m / "tools/check_registry.gd").read_text().replace('"c3", null]', '"c3", "shots"]')
        (m / "tools/check_registry.gd").write_text(reg)
        (m / "docs").mkdir()
        (m / "docs/a.md").write_text("x")
        sh(m, "git", "commit", "-qam", "reg")
        expect(ss.select(m, "HEAD~1")[0] == ["--c3-check"], "a changed registry entry selects only its flag")
        (m / "art/kael/kael.glb").write_bytes(b"glb2")
        sh(m, "git", "commit", "-qam", "art")
        expect(ss.select(m, "HEAD~1")[0] == ["--c0-check"], "an asset loaded by a built path selects via its dir")
        (m / "scripts/util.gd").write_text("class_name Util\nfunc go():\n\tprint(1)\n")
        sh(m, "git", "commit", "-qam", "util")
        expect(len(ss.select(m, "HEAD~1")[0]) == 11, "a shared class selects every check that uses it")
        (m / "project.godot").write_text("[application]\nx=1\n")
        sh(m, "git", "commit", "-qam", "proj")
        expect(ss.select(m, "HEAD~1")[0] is None, "project.godot selects ALL")
        (m / "docs/b.md").write_text("y")
        sh(m, "git", "add", "-A")
        sh(m, "git", "commit", "-qm", "doc")
        expect(ss.select(m, "HEAD~1")[0] == [], "docs-only selects nothing")
        print(json.dumps({"ok": ok}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
