#!/usr/bin/env python3
"""Text lint: no retired hunter display name in player-facing text (DECISIONS 2026-11-07/08).

Final names: Vex, Albert, Sparkle, Kael, Lace, Cinder, Grimble, Meeko, Neve, Tenzo, Motley, Sable, Gil.
Ids, files and folders keep the old names, so only player text is read: string values in content/**/*.json
(not the doc/id/source keys) and string literals in scripts/**/*.gd and scenes (comments are skipped).
Also (owner rule 11-27) fails on he/him/his near a female hunter or she/her near a male one (same sentence).
Usage: python3 tools/old_names_lint.py      exit 1 and list file:line when a retired name is shown to players.
"""

import json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RETIRED = (
    "Pin Hem Zedran Ryzz Vireo Bjorn Breaker Mossy Claire Nivi Tarek Kibo Pip Lumi Ravel Ravyl Lisette Ostra Dancer"
).split()
NAME = re.compile(r"\b(%s)\b" % "|".join(RETIRED))
# Not the retired hunters: the verb "Pin a note/it/a Boki", and the starter Boki's own nickname "Pip".
ALLOW = re.compile(r"\bPin (a|an|it|the|to)\b|\"Pip\"|\bPip\b(?=\")")
SKIP_KEYS = {"doc", "id", "src", "source", "sources", "note", "notes", "comment", "_comment", "file", "path"}
# Boki name fragments (evolution "root", voice "syllables": Pip-eworth), never shown as a hunter name.
SKIP_KEYS |= {"root", "syllables"}
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


FEMALE = "Cinder Lace Neve Meeko Sable Vex Sparkle Malgrave".split()
MALE = "Kael Albert Grimble Motley Tenzo Gil".split()
HUNTER = re.compile(r"\b(%s)\b" % "|".join(FEMALE + MALE))
HE = re.compile(r"\b(he|him|his|himself|He|Him|His)\b")
SHE = re.compile(r"\b(she|her|hers|herself|She|Her|Hers)\b")
PRON_COUNT = {}


def pronoun_hits(text):
    """Owner rule 11-27: a sentence naming only female hunters must not say he/him/his, only male ones not she/her.
    Returns [(hunter, snippet)]; a sentence naming both sexes, or using both he and she, is skipped (pronoun could point either way)."""
    out = []
    for sent in re.split(r"(?<=[.!?;])\s+|\n|\|", text):
        names = set(HUNTER.findall(sent))
        f = names & set(FEMALE)
        m = names & set(MALE)
        if HE.search(sent) and SHE.search(sent):
            continue
        if f and not m and HE.search(sent):
            out += [(n, sent) for n in f]
        elif m and not f and SHE.search(sent):
            out += [(n, sent) for n in m]
    return out


def note_pron(where, text, found):
    for n, sent in pronoun_hits(text):
        PRON_COUNT[n] = PRON_COUNT.get(n, 0) + 1
        found.append(f"{where}: PRONOUN {n}: {sent.strip()[:90]}")


def json_pron(o, path, found):
    if isinstance(o, dict):
        for k, v in o.items():
            if k not in SKIP_KEYS:
                json_pron(v, path, found)
    elif isinstance(o, list):
        for v in o:
            json_pron(v, path, found)
    elif isinstance(o, str):
        note_pron(path, o, found)


def main():
    found = []
    for p in tracked(("docs/heroes/",), (".md",)) + ["docs/KIT_PARITY.md"]:
        try:
            for n, line in enumerate(open(os.path.join(ROOT, p), encoding="utf-8"), 1):
                note_pron(f"{p}:{n}", line, found)
        except OSError:
            pass
    for p in tracked(("content/",), (".json",)):
        try:
            json_pron(json.load(open(os.path.join(ROOT, p), encoding="utf-8")), p, found)
        except (ValueError, OSError):
            pass
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
                note_pron(f"{p}:{n}", s, found)
    for f in found:
        print("OLDNAME", f)
    if PRON_COUNT:
        print("PRONOUN per hunter:", ", ".join(f"{k} {v}" for k, v in sorted(PRON_COUNT.items())))
    print("OLDNAMES FAIL (%d)" % len(found) if found else "OLDNAMES ok")
    sys.exit(1 if found else 0)


if __name__ == "__main__":
    main()
