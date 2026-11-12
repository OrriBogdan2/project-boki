#!/usr/bin/env python3
"""Export size budget (docs/SIZE_BUDGET.md): the packed build per platform may not grow past its baseline.

Usage: python3 tools/size_budget.py [--check | --update]
Runs `godot --headless --export-pack` for every preset in export_presets.cfg (a dry run: it needs no
export templates and writes only a temporary .pck), reads the pack's file table, and compares each
platform's pack size and its asset categories with tests/size_budget.json.
  --check   (default) exit 1 when any platform's pack is more than TOLERANCE_PCT over its baseline
  --update  rewrite the baseline: bump it in the same PR as the growth you mean to ship
Env: GODOT = the binary (default `godot`).
"""
import collections, json, os, re, struct, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "tests", "size_budget.json")
TOLERANCE_PCT = 5      # % a platform's pack may grow over its baseline before the check fails
MB = 1 << 20
# what each packed file kind counts as (imported textures and models are .ctex / .scn in the pack)
KINDS = {"ctex": "textures", "scn": "models", "mesh": "models", "res": "models", "sample": "audio",
         "oggvorbisstr": "audio", "mp3str": "audio", "gdc": "scripts", "gd": "scripts", "json": "data",
         "fontdata": "fonts", "gdshader": "shaders", "tscn": "scenes", "translation": "translations"}

def presets():
    with open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8") as f:
        return re.findall(r'^name="([^"]+)"', f.read(), re.M)

def pack_files(path):
    """(packed path, size) for every file in a Godot 4 .pck (format 3: directory offset at byte 32)."""
    out = []
    with open(path, "rb") as f:
        f.seek(32)
        f.seek(struct.unpack("<Q", f.read(8))[0])
        for _ in range(struct.unpack("<I", f.read(4))[0]):
            n = struct.unpack("<I", f.read(4))[0]
            name = f.read(n).rstrip(b"\0").decode()
            size = struct.unpack("<QQ", f.read(16))[1]
            f.read(20)      # md5 and flags
            out.append((name, size))
    return out

def measure():
    godot = os.environ.get("GODOT", "godot")
    with tempfile.TemporaryDirectory() as tmp:
        env = dict(os.environ, XDG_DATA_HOME=os.path.join(tmp, "xdg"))
        subprocess.run([godot, "--headless", "--import"], cwd=ROOT, env=env, capture_output=True, timeout=1800)
        out = {}
        for name in presets():
            pck = os.path.join(tmp, "pack.pck")
            r = subprocess.run([godot, "--headless", "--export-pack", name, pck], cwd=ROOT, env=env,
                               capture_output=True, text=True, timeout=1800)
            if r.returncode != 0 or not os.path.exists(pck):
                sys.exit("export dry run failed for %s (rc %d):\n%s" % (name, r.returncode, r.stdout[-600:]))
            cats = collections.Counter()
            files = pack_files(pck)
            for p, size in files:
                cats[KINDS.get(p.rsplit(".", 1)[-1], "other")] += size
            out[name] = {"total": os.path.getsize(pck), "categories": dict(cats.most_common()),
                         "biggest": sorted(files, key=lambda x: -x[1])[:3]}
            os.remove(pck)
    return out

def show(now, base):
    for name, m in now.items():
        was = base.get(name, {}).get("total")
        print("%-13s %7.1f MB%s" % (name, m["total"] / MB, "" if not was else "  (baseline %.1f MB, %+.1f%%)" % (was / MB, 100.0 * (m["total"] - was) / was)))
        print("   " + ", ".join("%s %.1f" % (k, v / MB) for k, v in list(m["categories"].items())[:6]) + " MB")
    print("biggest file (%s): %s %.1f MB" % (next(iter(now)), now[next(iter(now))]["biggest"][0][0], now[next(iter(now))]["biggest"][0][1] / MB))

def main():
    update = "--update" in sys.argv
    base = json.load(open(BASELINE))["platforms"] if os.path.exists(BASELINE) else {}
    now = measure()
    show(now, base)
    if update:
        keep = {k: {"total": v["total"], "categories": v["categories"]} for k, v in now.items()}
        with open(BASELINE, "w") as f:
            json.dump({"tolerance_pct": TOLERANCE_PCT, "platforms": keep}, f, indent=1)
            f.write("\n")
        print("baseline written: %s" % BASELINE)
        return 0
    bad = 0
    for name, m in now.items():
        if name not in base:
            print("FAIL %s has no baseline: run tools/size_budget.py --update" % name)
            bad += 1
        elif m["total"] > base[name]["total"] * (1 + TOLERANCE_PCT / 100.0):
            grew = {k: v - base[name]["categories"].get(k, 0) for k, v in m["categories"].items()}
            print("FAIL %s: %.1f MB is over the baseline %.1f MB by more than %d%%. Grew most: %s. If the growth is meant, "
                  "run tools/size_budget.py --update and commit tests/size_budget.json in the same PR."
                  % (name, m["total"] / MB, base[name]["total"] / MB, TOLERANCE_PCT,
                     ", ".join("%s %+.1f MB" % (k, v / MB) for k, v in sorted(grew.items(), key=lambda x: -x[1])[:3])))
            bad += 1
    print("SIZE BUDGET DONE, failures: %d" % bad)
    return 1 if bad else 0

if __name__ == "__main__":
    sys.exit(main())
