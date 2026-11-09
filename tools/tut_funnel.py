#!/usr/bin/env python3
"""Prints the tutorial funnel from a folder of tester feedback.

    python3 tools/tut_funnel.py <folder>     # every *.json and *.jsonl in it

Reads the server's feedback.jsonl lines, a tester's feedback.json (its "queue") or a JSON list of records;
each record's "funnel" is {track: {step: [entered s, finished s or -1, idle s, hints, end]}} (see
scripts/core/tut_funnel.gd). Per step of the "match" and "farm" tutorials it prints how many testers
reached it, finished it, skipped there, quit there (the last step they entered, never ended, and no
skip anywhere), the median seconds in the step when done, the median idle seconds and the average hints.
Plain Python 3.
"""
import json
import os
import statistics
import sys

IN, OUT, IDLE, HINTS, END = range(5)
TRACKS = ("match", "farm")


def records(folder: str):
    """Every feedback record that carries a funnel, from the *.json and *.jsonl files in `folder`."""
    for name in sorted(os.listdir(folder)):
        if not name.endswith((".json", ".jsonl")):
            continue
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            text = f.read()
        parsed = []
        for chunk in ([text] if name.endswith(".json") else text.splitlines()):
            try:
                parsed.append(json.loads(chunk))
            except ValueError:
                continue
        for item in parsed:
            for rec in (item if isinstance(item, list) else item.get("queue", [item]) if isinstance(item, dict) else []):
                if isinstance(rec, dict) and isinstance(rec.get("funnel"), dict):
                    yield rec["funnel"]


def quit_step(steps: dict) -> str:
    """The step a tester walked away at: the last one entered and left open, when nothing was skipped."""
    if any(r[END] == "skip" for r in steps.values()):
        return ""
    open_steps = [(r[IN], sid) for sid, r in steps.items() if r[END] == ""]
    return max(open_steps)[1] if open_steps else ""


def table(funnels: list, track: str) -> list:
    """Rows [step, reached, done, skip, quit, median s, median idle, avg hints], in the order testers met them."""
    seen: dict = {}
    for fun in funnels:
        steps = fun.get(track, {})
        quit_at = quit_step(steps)
        for sid, r in steps.items():
            s = seen.setdefault(sid, {"in": [], "dur": [], "idle": [], "hints": [], "done": 0, "skip": 0, "quit": 0})
            s["in"].append(r[IN])
            s["idle"].append(r[IDLE])
            s["hints"].append(r[HINTS])
            if r[END] == "done":
                s["done"] += 1
                s["dur"].append(r[OUT] - r[IN])
            s["skip"] += r[END] == "skip"
            s["quit"] += sid == quit_at
    rows = []
    for sid, s in sorted(seen.items(), key=lambda kv: statistics.median(kv[1]["in"])):
        rows.append([sid, len(s["in"]), s["done"], s["skip"], s["quit"],
                     statistics.median(s["dur"]) if s["dur"] else None,
                     statistics.median(s["idle"]), statistics.mean(s["hints"])])
    return rows


def render(rows: list) -> str:
    head = f"{'step':<12}{'reached':>8}{'done':>6}{'skip':>6}{'quit':>6}{'med s':>8}{'idle s':>8}{'hints':>7}"
    lines = [head, "-" * len(head)]
    for sid, reached, done, skip, quit_n, dur, idle, hints in rows:
        lines.append(f"{sid:<12}{reached:>8}{done:>6}{skip:>6}{quit_n:>6}"
                     f"{'-' if dur is None else format(dur, '.0f'):>8}{idle:>8.0f}{hints:>7.1f}")
    return "\n".join(lines)


def main(argv: list) -> int:
    if len(argv) != 2 or not os.path.isdir(argv[1]):
        print(__doc__.split("\n\n")[0] + "\n\nusage: tut_funnel.py <folder>")
        return 2
    funnels = list(records(argv[1]))
    print(f"{len(funnels)} records with a funnel")
    for track in TRACKS:
        rows = table(funnels, track)
        if rows:
            print(f"\n{track} tutorial\n{render(rows)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
