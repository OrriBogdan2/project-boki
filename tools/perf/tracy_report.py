#!/usr/bin/env python3
"""Top zones by mean and p95 from a tracy-csvexport -u file (docs/PERF.md).

  tools/perf/tracy_report.py <zones.csv> [--top 15] [--warm 3] [--by mean|p95]

The first --warm seconds after the first zone are dropped (shader and cache warm-up), as the bench does.
Times are in ms per zone instance; a zone nested in another counts in both.
"""
import argparse
import csv
import math
import sys
from collections import defaultdict


def percentile(sorted_vals, pct):
    """Nearest-rank percentile of an ascending list."""
    return sorted_vals[max(0, math.ceil(pct / 100.0 * len(sorted_vals)) - 1)]


def load(path, warm_s):
    """zone name -> list of durations in ms, after the warm-up."""
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        return {}
    start_ns = min(int(r["ns_since_start"]) for r in rows) + int(warm_s * 1e9)
    zones = defaultdict(list)
    for r in rows:
        if int(r["ns_since_start"]) >= start_ns:
            zones[r["name"]].append(int(r["exec_time_ns"]) / 1e6)
    return zones


def report(zones, top, by):
    stats = []
    for name, ms in zones.items():
        ms.sort()
        stats.append((name, len(ms), sum(ms) / len(ms), percentile(ms, 95), ms[-1], sum(ms)))
    key = 2 if by == "mean" else 3
    stats.sort(key=lambda s: -s[key])
    lines = ["| zone | calls | mean ms | p95 ms | max ms | total ms |", "|---|---|---|---|---|---|"]
    for name, n, mean, p95, mx, tot in stats[:top]:
        lines.append(f"| {name} | {n} | {mean:.3f} | {p95:.3f} | {mx:.3f} | {tot:.0f} |")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv_file")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--warm", type=float, default=3.0, help="seconds dropped after the first zone")
    ap.add_argument("--by", choices=("mean", "p95"), default="mean")
    args = ap.parse_args()
    zones = load(args.csv_file, args.warm)
    if not zones:
        sys.exit("no zones in " + args.csv_file)
    print(report(zones, args.top, args.by))


if __name__ == "__main__":
    main()
