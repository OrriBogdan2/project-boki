#!/usr/bin/env python3
"""pacer_backtest: what was lost at weekly resets and to 5h-limit kills, vs what pacer_plan would have done.

  pacer_backtest.py /home/boki/usage/snapshots.jsonl [--log /home/boki/cj/pacer.log] [--days 3]

snapshots.jsonl is read loosely (the real format was not reachable from rpc4 when this was written): one JSON row
per snapshot, a time under ts/time/at/generated, accounts as a list or a {key: row} dict; per account an
email/name/label and either the OAuth usage shape (usage.five_hour/seven_day .utilization/.resets_at) or flat
weekly/fiveh/reset_at/fiveh_reset fields. Rows it cannot read are counted and skipped, never guessed.
pacer.log: lines that name an account and say limit + (kill|died|dead|requeue) count as 5h-limit kills.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pacer_plan as pp  # noqa: E402

TS_KEYS = ("ts", "time", "at", "generated", "t")


def _t(v):
    if v is None or v == "":
        return None
    if isinstance(v, (int, float)):
        return datetime.fromtimestamp(v / (1000 if v > 1e11 else 1), timezone.utc)
    v = str(v).replace("Z", "+00:00")
    try:
        d = datetime.fromisoformat(v)
    except ValueError:
        return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def _pct(v):
    if v is None:
        return None
    return float(v)   # percent (0-100), as cswap and the OAuth usage API report it


def parse_row(r: dict):
    ts = next((_t(r[k]) for k in TS_KEYS if k in r and _t(r[k])), None)
    accs = r.get("accounts", r.get("rows", []))
    if isinstance(accs, dict):
        accs = [dict(v, name=v.get("email", k)) if isinstance(v, dict) else {} for k, v in accs.items()]
    out = []
    for a in accs:
        name = a.get("email") or a.get("name") or a.get("label")
        u = a.get("usage") or {}
        wk = (u.get("seven_day") or {}).get("utilization", a.get("weekly"))
        wr = (u.get("seven_day") or {}).get("resets_at", a.get("reset_at"))
        fh = (u.get("five_hour") or {}).get("utilization", a.get("fiveh"))
        fr = (u.get("five_hour") or {}).get("resets_at", a.get("fiveh_reset"))
        if name and wk is not None:
            out.append((name, a.get("label") or name.split("@")[0], _pct(wk), _t(wr), _pct(fh) or 0.0, _t(fr)))
    return ts, out


def load_series(path: str, since: datetime | None):
    ser, bad = {}, 0
    for line in open(path, errors="replace"):
        try:
            ts, rows = parse_row(json.loads(line))
        except (ValueError, TypeError, AttributeError):
            bad += 1
            continue
        if ts is None or not rows:
            bad += 1
            continue
        if since and ts < since:
            continue
        for name, lab, wk, wr, fh, fr in rows:
            ser.setdefault(name, {"label": lab, "pts": []})["pts"].append((ts, wk, wr, fh, fr))
    for v in ser.values():
        v["pts"].sort(key=lambda p: p[0])
    return ser, bad


def measured(ser: dict, log_path: str | None, since: datetime | None):
    """Per account: weekly resets seen with % lost, 5h windows that reached 100%, kills in pacer.log."""
    res = {}
    for name, v in ser.items():
        pts, lost, hit = v["pts"], [], set()
        for p0, p1 in zip(pts, pts[1:]):
            new_week = (p0[2] and p1[2] and p1[2] - p0[2] > timedelta(days=3)) or (p1[1] + 20 < p0[1])
            if new_week:
                lost.append((p0[2] or p1[0], round(100.0 - p0[1], 1)))
        for p in pts:
            if p[3] >= 100.0:
                hit.add(p[4] or p[0].replace(minute=0, second=0))
        res[name] = {"label": v["label"], "resets": lost, "fiveh_limit_windows": len(hit), "kills": 0,
                     "first": pts[0] if pts else None}
    if log_path and os.path.exists(log_path):
        rx = re.compile(r"limit", re.I)
        kx = re.compile(r"kill|died|dead|requeue", re.I)
        for line in open(log_path, errors="replace"):
            if not (rx.search(line) and kx.search(line)):
                continue
            ts = _t((re.search(r"\d{4}-\d\d-\d\dT[\d:]+Z?", line) or [None])[0]) if re.search(r"\d{4}-\d\d-\d\dT", line) else None
            if since and ts and ts < since:
                continue
            for name, r in res.items():
                if name in line or r["label"] in line:
                    r["kills"] += 1
    return res


def counterfactual(ser: dict, start: datetime, hours: int, excluded=("corybogdan",)):
    """Run pacer_plan from the first snapshot at `start` for `hours`: weekly % lost at each reset, 5h-limit hits."""
    accts = []
    for name, v in ser.items():
        p = next((p for p in v["pts"] if p[0] >= start), None)
        if p is None:
            continue
        ts, wk, wr, fh, fr = p
        accts.append(pp.PlanAcct(name, wk, None if wr is None else (wr - ts).total_seconds() / 3600, fh,
                                 (fr - ts).total_seconds() / 3600 if fh >= 100 and fr else 0.0,
                                 any(e in name for e in excluded), label=v["label"],
                                 win_reset_h=None if fr is None else (fr - ts).total_seconds() / 3600))
    plan = pp.build_plan(accts, start, horizon=hours)
    out = {}
    for a in plan["accounts"]:
        hits = sum(1 for f, j in zip(a["plan_fiveh"], a["plan_jobs"]) if j > 0 and f >= 100)
        out[a["name"]] = {"waste": a["waste_at_reset"], "fiveh_hits": hits, "jobs": round(sum(a["plan_jobs"]))}
    return out


def report(snap: str, log: str | None, days: float, now: datetime | None = None) -> list[str]:
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(days=days)
    ser, bad = load_series(snap, since)
    if not ser:
        return [f"backtest: no readable snapshots since {pp._iso(since)} ({bad} rows skipped)"]
    m = measured(ser, log, since)
    start = min(v["pts"][0][0] for v in ser.values())
    cf = counterfactual(ser, start, int((now - start).total_seconds() // 3600) or 1)
    out = [f"backtest {pp._iso(start)} .. {pp._iso(now)} ({len(ser)} accounts, {bad} rows skipped)",
           "  account          lost at resets (measured)   5h-limit windows / kills   plan: lost at resets   plan: 5h hits"]
    tl = tp = 0.0
    for name, r in m.items():
        if "corybogdan" in name:
            continue
        lost = sum(x[1] for x in r["resets"])
        c = cf.get(name, {})
        pw = c.get("waste")
        tl += lost
        tp += pw or 0.0
        out.append(f"  {r['label']:16s} {'/'.join(f'{x[1]:.0f}%' for x in r['resets']) or 'no reset':27s} "
                   f"{r['fiveh_limit_windows']} / {r['kills']:<20d} {('-' if pw is None else f'{pw:.0f}%'):22s} {c.get('fiveh_hits', 0)}")
    out.append(f"  total lost at resets: measured {tl:.0f} %-points, plan {tp:.0f} %-points "
               f"(plan assumes the queue had work for the fleet; it never plans a 5h window past 85%)")
    return out


def selftest() -> None:
    """Synthetic 3 days: A resets at 60% (lost 40), B hits its 5h limit twice."""
    import tempfile
    t0 = datetime(2026, 11, 9, 4, tzinfo=timezone.utc)
    d = tempfile.mkdtemp()
    sp, lp = os.path.join(d, "s.jsonl"), os.path.join(d, "p.log")
    with open(sp, "w") as f:
        for h in range(0, 72, 1):
            t = t0 + timedelta(hours=h)
            a_wk = 40 + h * 0.5 if h < 40 else (h - 40) * 0.5
            a_rs = t0 + timedelta(hours=40) if h < 40 else t0 + timedelta(hours=208)
            b_fh = 100 if h in (10, 11, 30) else 50
            b_fr = t0 + timedelta(hours=12 if h < 20 else 33)
            f.write(json.dumps({"ts": pp._iso(t), "accounts": [
                {"email": "a@x", "label": "A", "usage": {"seven_day": {"utilization": a_wk, "resets_at": pp._iso(a_rs)},
                                                         "five_hour": {"utilization": 10, "resets_at": None}}},
                {"email": "b@x", "label": "B", "weekly": 30 + h * 0.2, "reset_at": pp._iso(t0 + timedelta(hours=150)),
                 "fiveh": b_fh, "fiveh_reset": pp._iso(b_fr)}]}) + "\n")
        f.write("not json\n")
    open(lp, "w").write("2026-11-09T14:10Z job 123 on B died: 5h limit, requeued\n")
    ser, bad = load_series(sp, None)
    m = measured(ser, lp, None)
    assert bad == 1 and m["a@x"]["resets"][0][1] == 40.5, m["a@x"]
    assert m["b@x"]["fiveh_limit_windows"] == 2 and m["b@x"]["kills"] == 1, m["b@x"]
    r = report(sp, lp, 3, t0 + timedelta(hours=72))
    assert any(x.strip().startswith("A ") for x in r), r
    print("pacer_backtest selftest ok")
    for x in r:
        print("  synthetic|", x)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("snapshots", nargs="?")
    ap.add_argument("--log")
    ap.add_argument("--days", type=float, default=3.0)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)
    if a.selftest:
        selftest()
        return 0
    for line in report(a.snapshots, a.log, a.days):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
