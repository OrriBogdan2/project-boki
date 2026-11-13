#!/usr/bin/env python3
"""Reads the logs of `--pacing-sim` runs and prints the clock as markdown (docs/PACING_1111.md).
Usage: tools/pacing_report.py seed1.log seed2.log ...  (one row per run, then the median)."""
import re
import statistics
import sys

BEATS = [120, 240, 315, 480, 600]          # 2:00 4:00 5:15 8:00 10:00, the pace table's columns
EV = re.compile(r"^PACE ev ([\d.]+) (\w+) ?(.*)$")
SNAP = re.compile(r"^PACE snap (\d+) tide (\d+) levels ([\d.,]*) out (\d+) extracted (\d+)")
TRAIL = re.compile(r"^PACE (heart|seat_lair|seat_uplink)\s+([\d.]+) (\w+)>(\w+) ?(.*)$")


def fmt(t):
    return "-" if t is None else "%d:%02d" % (int(t) // 60, int(t) % 60)


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def parse(path):
    r = {"ev": [], "snap": {}, "trail": {"heart": [], "seat_lair": [], "seat_uplink": []}, "end": None}
    for line in open(path, errors="replace"):
        line = line.rstrip()
        m = EV.match(line)
        if m:
            r["ev"].append((float(m.group(1)), m.group(2), m.group(3)))
        m = SNAP.match(line)
        if m:
            r["snap"][int(m.group(1))] = (int(m.group(2)), [float(x) for x in m.group(3).split(",") if x], int(m.group(4)), int(m.group(5)))
        m = TRAIL.match(line)
        if m:
            r["trail"][m.group(1)].append((float(m.group(2)), m.group(3), m.group(4), m.group(5)))
        if line.startswith("PACE end"):
            r["end"] = line
    return r


def first(r, kind, pred=lambda s: True):
    for t, k, s in r["ev"]:
        if k == kind and pred(s):
            return t
    return None


def nth(r, kind, n):
    ts = [t for t, k, s in r["ev"] if k == kind]
    return ts[n - 1] if len(ts) >= n else None


def squad_level_at(r, beat):
    """The squads' mean levels at the snapshot nearest the beat (snapshots are every 30 s)."""
    keys = sorted(r["snap"])
    if not keys:
        return None
    k = min(keys, key=lambda x: abs(x - beat))
    return k, r["snap"][k][1]


def squad_times(r):
    """Per squad: first landing, first damage dealt (any member)."""
    land, hit = {}, {}
    for t, k, s in r["ev"]:
        m = re.match(r"(\S+) t(\d+)", s)
        if not m:
            continue
        team = int(m.group(2))
        if k == "land":
            land[team] = min(land.get(team, 1e9), t)
        if k == "hit":
            hit[team] = min(hit.get(team, 1e9), t)
    return land, hit


def first_level(r, lvl):
    return first(r, "lvl", lambda s: s.endswith(" L%d" % lvl))


def trail_t(r, which, to, pat=""):
    for t, a, b, why in r["trail"][which]:
        if b == to and pat in why:
            return t
    return None


def lair_t(r, state):
    ts = {}
    for t, k, s in r["ev"]:
        if k == "lair" and s.endswith(" " + state):
            ts.setdefault(s[: -len(state) - 1], t)
    return ts


def row(path):
    r = parse(path)
    land, hit = squad_times(r)
    gaps = [hit[t] - land[t] for t in hit if t in land]
    d = {"run": path.split("/")[-1].replace(".log", "")}
    d["land_first"] = min(land.values()) if land else None
    d["land_last"] = max(land.values()) if land else None
    d["fight_gap_med"] = med(gaps)
    d["fight_gap_max"] = max(gaps) if gaps else None
    d["first_knock"] = first(r, "first_knock") or next((float(m.group(1)) for m in [re.match(r"PACE first_knock (\d+)", l) for l in open(path)] if m), None)
    d["camp1"] = nth(r, "camp_clear", 1)
    d["camp5"] = nth(r, "camp_clear", 5)
    d["camps"] = sum(1 for e in r["ev"] if e[1] == "camp_clear")
    m = re.search(r"camps_cleared (\d+)/(\d+)", r["end"] or "")
    d["camp_total"] = int(m.group(2)) if m else None
    for lv in (2, 3, 4, 5, 6, 8):
        d["L%d" % lv] = first_level(r, lv)
    d["levels"] = {b: squad_level_at(r, b) for b in BEATS}
    d["tide"] = {b: (r["snap"].get(b - b % 30) or (0,))[0] for b in (120, 240, 360, 480, 600)}
    d["lair_open"] = lair_t(r, "open")
    d["lair_awake"] = lair_t(r, "awake")
    d["lair_cleared"] = lair_t(r, "cleared")
    d["heart"] = {(a + ">" + b): t for t, a, b, why in r["trail"]["heart"]}
    d["seat_lair"] = [(t, b) for t, a, b, why in r["trail"]["seat_lair"]]
    d["seat_uplink"] = [(t, b) for t, a, b, why in r["trail"]["seat_uplink"]]
    d["extract"] = [(t, s) for t, k, s in r["ev"] if k == "extract"]
    d["alive"] = [(t, int(s)) for t, k, s in r["ev"] if k == "squads_alive"]
    d["end"] = r["end"]
    return d


def squads_alive_t(d, n):
    for t, a in d["alive"]:
        if a <= n:
            return t
    return None


def main(paths):
    rows = [row(p) for p in paths]
    print("| run | landed (first-last) | first damage after landing (median/worst) | first knock | first camp clear | 5th | camps cleared | L2 | L3 | L4 | L6 |")
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for d in rows:
        print("| %s | %s-%s | %.0f s / %.0f s | %s | %s | %s | %d/%s | %s | %s | %s | %s |" % (
            d["run"], fmt(d["land_first"]), fmt(d["land_last"]), d["fight_gap_med"] or 0, d["fight_gap_max"] or 0,
            fmt(d["first_knock"]), fmt(d["camp1"]), fmt(d["camp5"]), d["camps"], d["camp_total"], fmt(d["L2"]), fmt(d["L3"]), fmt(d["L4"]), fmt(d["L6"])))
    print()
    print("| run | squads' mean level at 2:00 (min/med/max, squads still in) | 4:00 | 5:15 | 8:00 | 10:00 |")
    print("|---|---|---|---|---|---|")
    for d in rows:
        cells = []
        for b in BEATS:
            x = d["levels"][b]
            cells.append("-" if not x or not x[1] else "%.1f / %.1f / %.1f" % (min(x[1]), statistics.median(x[1]), max(x[1])))
        print("| %s | %s |" % (d["run"], " | ".join(cells)))
    print()
    print("| run | tide radius m at 2:00 / 4:00 / 6:00 / 8:00 / 10:00 | lair gate opens | boss awake | boss dies | Heart wakes | spark charged | Heart final | squads left <=5 / <=3 / 1 | ended |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for d in rows:
        h = d["heart"]
        awake = med(d["lair_awake"].values())
        cleared = sorted(d["lair_cleared"].values())
        print("| %s | %s | %s | %s | %s | %s | %s | %s | %s / %s / %s | %s |" % (
            d["run"], " / ".join(str(d["tide"][b]) for b in (120, 240, 360, 480, 600)),
            fmt(min(d["lair_open"].values()) if d["lair_open"] else None), fmt(min(d["lair_awake"].values()) if d["lair_awake"] else None),
            ", ".join(fmt(c) for c in cleared) or "-", fmt(h.get("ASLEEP>CHARGING")), fmt(h.get("CHARGING>READY")), fmt(h.get("READY>FINAL") or h.get("WAITING>FINAL") or h.get("CHARGING>FINAL") or next((t for k, t in h.items() if k.endswith(">FINAL")), None)),
            fmt(squads_alive_t(d, 5)), fmt(squads_alive_t(d, 3)), fmt(squads_alive_t(d, 1)), (d["end"] or "").replace("PACE end ", "")[:70]))
    print()
    for d in rows:
        print("- %s extractions: %s; Sealed Lair seat %s; Uplink seat %s; Heart %s" % (
            d["run"], ", ".join("%s %s" % (fmt(t), s) for t, s in d["extract"]) or "none",
            " ".join("%s %s" % (fmt(t), b) for t, b in d["seat_lair"]) or "-", " ".join("%s %s" % (fmt(t), b) for t, b in d["seat_uplink"]) or "-",
            " ".join("%s %s" % (fmt(t), k) for k, t in sorted(d["heart"].items(), key=lambda kv: kv[1]))))


if __name__ == "__main__":
    main(sys.argv[1:])
