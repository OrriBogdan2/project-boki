#!/usr/bin/env python3
"""Text lint: no retired hunter display name in player-facing text (DECISIONS 2026-11-07/08).

Final names: Vex, Albert, Sparkle, Kael, Lace, Cinder, Grimble, Meeko, Neve, Tenzo, Motley, Sable, Gil.
Ids, files and folders keep the old names, so only player text is read: string values in content/**/*.json
(not the doc/id/source keys) and string literals in scripts/**/*.gd and scenes (comments are skipped).
Usage: python3 tools/old_names_lint.py      exit 1 and list file:line when a retired name is shown to players.
"""

import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RETIRED = (
    "Pin Hem Zedran Ryzz Vireo Bjorn Breaker Mossy Claire Nivi Tarek Kibo Pip Lumi Ravel Ravyl Lisette Ostra Dancer"
).split()
NAME = re.compile(r"\b(%s)\b" % "|".join(RETIRED))
# Not the retired hunters: the verb "Pin a note/it/a Boki", Lace's "Pin Down" shot, and the starter Boki's nickname "Pip".
ALLOW = re.compile(r"\bPin (a|an|it|the|to|Downs?)\b|\"Pip\"|\bPip\b(?=\")")
SKIP_KEYS = {"doc", "id", "src", "source", "sources", "note", "notes", "comment", "_comment", "file", "path"}
STRING = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def tracked(prefixes, suffixes):
    out = subprocess.run(["git", "ls-files", "-z"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return [p for p in out.split("\0") if p.startswith(prefixes) and p.endswith(suffixes)]


def hit(text):
    return NAME.search(ALLOW.sub("", text))


def json_strings(o, path, out):
    if isinstance(o, dict):
        for k, v in o.items():
            if k not in SKIP_KEYS:
                json_strings(v, path, out)
    elif isinstance(o, list):
        for v in o:
            json_strings(v, path, out)
    elif isinstance(o, str) and hit(o):
        out.append(f"{path}: {o[:90]}")


def main():
    found = []
    for p in tracked(("content/",), (".json",)):
        try:
            json_strings(json.load(open(os.path.join(ROOT, p), encoding="utf-8")), p, found)
        except (ValueError, OSError):
            pass
    for p in tracked(("scripts/", "scenes/"), (".gd", ".tscn")):
        for n, line in enumerate(open(os.path.join(ROOT, p), encoding="utf-8", errors="replace"), 1):
            if line.lstrip().startswith("#"):
                continue
            for s in STRING.findall(line):
                if hit(s):
                    found.append(f"{p}:{n}: {s[:90]}")
    for f in found:
        print("OLDNAME", f)
    print("OLDNAMES FAIL (%d)" % len(found) if found else "OLDNAMES ok")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
