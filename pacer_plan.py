#!/usr/bin/env python3
"""pacer_plan: reset-aware 48h schedule for usage-pacer (owner 11-12: "plan around their usage times more").

Built on pacer_rank (ranking, fresh pace cap, 5h guard). Each pacer tick:
  plan = build_plan(accts, now)              # accts: pacer_rank.Acct + 5h window times (PlanAcct)
  merge_actual(plan, old_plan, running, now) # keep the measured jobs per hour next to the planned ones
  write_plan(plan, "/home/boki/cj/usage-plan.json")
  for line in alerts(plan, state_path): coordinator alert (stall-watch / coord-tick)
  html = render_html(plan)                   # /usage admin fragment: 48h bar per account, resets in EST

Model (knobs below): one running job burns JOB_RATE weekly %-points per hour; one 5h window holds WINDOW weekly
%-points before the 5h limit (100% 5h). The plan keeps each 5h window <= WIN_TARGET (85%) and each account's week
<= its pacer_rank ceiling (97% within 24h of reset). Order each step: pacer_rank.pick_order (soon first, then
expiring headroom/hour). Near-reset accounts front-load (fill windows as fast as MAX_PER_ACCT allows); other
accounts pace to land at the ceiling right at reset; fresh accounts fill the fleet slots left over, under the
fresh pace cap. A window that is full or on a hold gets 0 jobs until it resets; the first hour after its reset
gets jobs again ("starts land right after the 5h reset").
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
from dataclasses import dataclass, replace
from datetime import datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pacer_rank as pr  # noqa: E402

# The plan paces mid accounts to land at the ceiling right at reset, so they no longer need the lower hard stop.
pr.MID_CEIL = pr.SOON_CEIL

HORIZON_H = 48
DT = 0.25            # internal step (h); output is per hour
JOB_RATE = 0.7       # weekly %-points per job-hour (outlook2 11-12: ~17% in ~4h with ~6 jobs)
WINDOW = 17.0        # weekly %-points one 5h window holds at 100% 5h (outlook2 11-12)
WIN_TARGET = 85.0    # use each 5h window to this %
FLEET = 12           # max concurrent pacer jobs, all accounts
MAX_PER_ACCT = 6     # max concurrent jobs on one account
ALERT_HOURS = (12.0, 4.0)
ALERT_UNUSED = 10.0
EST = "America/New_York"


@dataclass
class PlanAcct(pr.Acct):
    label: str = ""
    win_start_h: float | None = None   # hours from now the current 5h window started (<= 0); None = no window open
    win_reset_h: float | None = None   # hours from now the current 5h window resets


def _iso(t: datetime) -> str:
    return t.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%MZ")


def _est(t: datetime | None) -> str:
    if t is None:
        return "?"
    try:
        from zoneinfo import ZoneInfo
        return t.astimezone(ZoneInfo(EST)).strftime("%a %m-%d %I:%M %p ET")
    except Exception:  # no tzdata: fixed EST
        return (t - timedelta(hours=5)).strftime("%a %m-%d %I:%M %p EST")


def _win_room(a: PlanAcct, used_win: float) -> float:
    """Weekly %-points still allowed in the open 5h window (to WIN_TARGET)."""
    return max(0.0, WINDOW * WIN_TARGET / 100.0 - used_win)


def build_plan(accts: list[PlanAcct], now: datetime, horizon: int = HORIZON_H, fleet: int = FLEET,
               demand_jobs: float | None = None) -> dict:
    """Plan jobs per account per hour for `horizon` hours. demand_jobs: jobs the queue can supply per step
    (None = as many as the fleet allows). Returns the usage-plan.json dict."""
    st = [replace(a) for a in accts]
    used_win = {a.name: (WINDOW * a.fiveh / 100.0 if a.win_reset_h and a.win_reset_h > 0 else 0.0) for a in st}
    win_end = {a.name: (a.win_reset_h if a.win_reset_h and a.win_reset_h > 0 else None) for a in st}
    for a in st:
        if a.hold_h > 0:   # hold = window full until the hold ends
            win_end[a.name] = max(win_end[a.name] or 0.0, a.hold_h)
            used_win[a.name] = WINDOW
    hourly = {a.name: [0.0] * horizon for a in st}
    wk_end = {a.name: [0.0] * horizon for a in st}
    fiveh_end = {a.name: [0.0] * horizon for a in st}
    resets = {a.name: [] for a in st}   # (hour, weekly % at reset)
    steps = int(horizon / DT)
    for k in range(steps):
        t = k * DT
        for a in st:  # window / week bookkeeping
            if win_end[a.name] is not None and t >= win_end[a.name] - 1e-9:
                win_end[a.name], used_win[a.name], a.hold_h = None, 0.0, 0.0
            a.fiveh = 100.0 * used_win[a.name] / WINDOW
            if a.hours_to_reset is not None and a.hours_to_reset <= 1e-9:
                if not a.excluded:
                    resets[a.name].append((t, a.weekly))
                a.weekly, a.hours_to_reset = 0.0, pr.WEEK_H
        left = float(fleet if demand_jobs is None else min(fleet, demand_jobs))
        for a in pr.pick_order(st):
            if left <= 0:
                break
            cap = pr.ceiling(a, st)[0]
            b = pr.band(a)
            if b == "fresh":   # plan keeps fresh accounts under the pace line x1.5 even when the rank cap lifts
                cap = min(cap, pr.SOON_CEIL, (pr.even_pace(a) or 0.0) * pr.FRESH_MULT)
            room_wk = max(0.0, cap - a.weekly)
            room_win = _win_room(a, used_win[a.name])
            if b in ("soon", "fresh"):
                want = MAX_PER_ACCT    # soon: front-load (lose it soon); fresh: fill the gaps up to its pace cap
            else:                      # mid: spread what is left to land at the ceiling right at reset
                want = room_wk / max(DT, a.hours_to_reset or pr.WEEK_H) / JOB_RATE
            jobs = min(want, MAX_PER_ACCT, left, room_wk / (JOB_RATE * DT), room_win / (JOB_RATE * DT))
            jobs = math.floor(jobs + 1e-6) if jobs >= 1 else (jobs if jobs > 0.05 else 0.0)
            if jobs <= 0:
                continue
            burn = jobs * JOB_RATE * DT
            a.weekly += burn
            used_win[a.name] += burn
            if win_end[a.name] is None:
                win_end[a.name] = t + 5.0
            hourly[a.name][int(t)] += jobs * DT
            left -= jobs
        for a in st:
            if a.hours_to_reset is not None:
                a.hours_to_reset -= DT
            i = int(t)
            wk_end[a.name][i] = a.weekly
            fiveh_end[a.name][i] = 100.0 * used_win[a.name] / WINDOW
    out = []
    for a0, a in zip(accts, st):
        rh = a0.hours_to_reset
        reset_at = None if rh is None else now + timedelta(hours=rh)
        wr = a0.win_reset_h if a0.win_reset_h and a0.win_reset_h > 0 else (a0.hold_h or None)
        r = resets[a.name]
        proj = r[0][1] if r else (None if rh is None else a.weekly + 0.0)
        out.append({
            "name": a0.name, "label": a0.label or a0.name.split("@")[0], "excluded": a0.excluded,
            "band": pr.band(a0), "weekly": a0.weekly, "fiveh": a0.fiveh,
            "weekly_reset": None if reset_at is None else _iso(reset_at), "hours_to_reset": rh,
            "fiveh_start": None if a0.win_start_h is None else _iso(now + timedelta(hours=a0.win_start_h)),
            "fiveh_reset": None if not wr else _iso(now + timedelta(hours=wr)),
            "plan_jobs": [round(x, 1) for x in hourly[a.name]],
            "plan_weekly": [round(x, 1) for x in wk_end[a.name]],
            "plan_fiveh": [round(x, 0) for x in fiveh_end[a.name]],
            "weekly_at_reset": None if proj is None else round(proj, 1),
            "reset_in_horizon": bool(r),
            "waste_at_reset": None if not r else round(100.0 - r[0][1], 1),
            "actual_jobs": [None] * horizon,
        })
    return {"generated": _iso(now), "horizon_h": horizon, "start_hour": _iso(now.replace(minute=0, second=0, microsecond=0)),
            "knobs": {"JOB_RATE": JOB_RATE, "WINDOW": WINDOW, "WIN_TARGET": WIN_TARGET, "FLEET": fleet,
                      "MAX_PER_ACCT": MAX_PER_ACCT, "SOON_CEIL": pr.SOON_CEIL, "FIVEH_STOP": pr.FIVEH_STOP},
            "accounts": out}


def merge_actual(plan: dict, old: dict | None, running: dict[str, int], now: datetime) -> dict:
    """Carry measured jobs per hour from the previous plan file, add this tick's running count (per hour max)."""
    start = datetime.fromisoformat(plan["start_hour"].replace("Z", "+00:00"))
    prev = {}
    if old:
        os_ = datetime.fromisoformat(old["start_hour"].replace("Z", "+00:00"))
        for a in old.get("accounts", []):
            for i, v in enumerate(a.get("actual_jobs", [])):
                if v is not None:
                    prev[(a["name"], os_ + timedelta(hours=i))] = v
    for a in plan["accounts"]:
        acts = a["actual_jobs"]
        for i in range(len(acts)):
            acts[i] = prev.get((a["name"], start + timedelta(hours=i)))
        if a["name"] in running:
            acts[0] = max(acts[0] or 0, running[a["name"]])
        # keep the last 48h measured too, for the planned-vs-actual bar
        a["actual_past"] = [[_iso(k[1]), v] for k, v in sorted(prev.items(), key=lambda kv: kv[0][1])
                            if k[0] == a["name"] and k[1] < start and k[1] >= start - timedelta(hours=48)]
        if a["name"] in running and old is None:
            a["actual_past"] = []
    return plan


def write_plan(plan: dict, path: str) -> None:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(plan, f, indent=1)
    os.replace(tmp, path)


def alerts(plan: dict, state_path: str | None, now: datetime | None = None) -> list[str]:
    """Coordinator alert lines, each once: weekly reset within 12h / 4h with > 10% unused (now and projected),
    and an account at its 5h limit (once per window). Labels only, never emails."""
    now = now or datetime.fromisoformat(plan["generated"].replace("Z", "+00:00"))
    seen = {}
    if state_path and os.path.exists(state_path):
        try:
            seen = json.load(open(state_path))
        except ValueError:
            seen = {}
    out = []
    for a in plan["accounts"]:
        if a["excluded"]:
            continue
        h, lab = a["hours_to_reset"], a["label"]
        if h is not None and h > 0:
            unused_now = 100.0 - a["weekly"]
            proj = a["weekly_at_reset"] if a["reset_in_horizon"] else None
            unused_proj = 100.0 - proj if proj is not None else unused_now
            for th in ALERT_HOURS:
                key = f"reset:{lab}:{a['weekly_reset']}:{th:g}"
                if h <= th and unused_now > ALERT_UNUSED and key not in seen:
                    out.append(f"ALERT usage-reset {lab} weekly reset in {h:.1f}h ({_est(now + timedelta(hours=h))}) "
                               f"unused {unused_now:.0f}% now, plan lands {100 - unused_proj:.0f}% -> start jobs on {lab}")
                    seen[key] = _iso(now)
        if a["fiveh"] >= 100.0 or (a["band"] != "unknown" and a.get("fiveh_reset") and a["fiveh"] >= 99.5):
            key = f"5h:{lab}:{a.get('fiveh_reset')}"
            if key not in seen:
                out.append(f"ALERT usage-5h-limit {lab} hit its 5h limit; no starts until {a.get('fiveh_reset') or '?'} "
                           f"(cj-limit-watch requeues the killed jobs)")
                seen[key] = _iso(now)
    if state_path:
        cut = _iso(now - timedelta(days=8))
        seen = {k: v for k, v in seen.items() if v >= cut}
        with open(state_path + ".tmp", "w") as f:
            json.dump(seen, f)
        os.replace(state_path + ".tmp", state_path)
    return out


def render_html(plan: dict) -> str:
    """Self-contained HTML fragment for the /usage admin page."""
    start = datetime.fromisoformat(plan["start_hour"].replace("Z", "+00:00"))
    peak = max([MAX_PER_ACCT] + [max([x or 0 for x in a["plan_jobs"] + a["actual_jobs"]] or [0]) for a in plan["accounts"]])
    rows = []
    for a in plan["accounts"]:
        if a["excluded"]:
            continue
        cells = []
        for i, p in enumerate(a["plan_jobs"]):
            act = a["actual_jobs"][i]
            hp = int(30 * p / peak)
            ha = 0 if act is None else int(30 * act / peak)
            t = start + timedelta(hours=i)
            mark = ""
            if a["fiveh_reset"] and a["fiveh_reset"][:13] == _iso(t)[:13]:
                mark = " r5"
            if a["weekly_reset"] and a["weekly_reset"][:13] == _iso(t)[:13]:
                mark = " rw"
            cells.append(f'<span class="h{mark}" title="{_est(t)}: plan {p:g}, actual {"-" if act is None else act}, '
                         f'wk {a["plan_weekly"][i]:.0f}%, 5h {a["plan_fiveh"][i]:.0f}%">'
                         f'<i class="p" style="height:{hp}px"></i><i class="a" style="height:{ha}px"></i></span>')
        wr = a["weekly_reset"] and datetime.fromisoformat(a["weekly_reset"].replace("Z", "+00:00"))
        fr = a["fiveh_reset"] and datetime.fromisoformat(a["fiveh_reset"].replace("Z", "+00:00"))
        land = "?" if a["weekly_at_reset"] is None else f'{a["weekly_at_reset"]:.0f}%'
        land += "" if a["reset_in_horizon"] else " at +48h"
        rows.append(f'<tr><td><b>{a["label"]}</b><br>{a["band"]} wk {a["weekly"]:.0f}% 5h {a["fiveh"]:.0f}%</td>'
                    f'<td class="bar">{"".join(cells)}</td>'
                    f'<td>5h reset: {_est(fr) if fr else "no window open"}<br>weekly reset: {_est(wr) if wr else "?"}'
                    f'<br>lands {land}</td></tr>')
    css = (".uplan .bar{white-space:nowrap}.uplan .h{display:inline-block;width:7px;height:30px;position:relative;"
           "margin-right:1px;background:#eee}.uplan .h i{position:absolute;bottom:0;width:7px;left:0}"
           ".uplan .p{background:#9bc}.uplan .a{background:#246;width:3px!important;left:2px!important}"
           ".uplan .r5{border-left:2px solid #c80}.uplan .rw{border-left:2px solid #c00}")
    return (f'<div class="uplan"><style>{css}</style><h3>Usage plan, next {plan["horizon_h"]}h '
            f'(from {_est(start)}; light = planned jobs, dark = actual; orange = 5h reset, red = weekly reset)</h3>'
            f'<table>{"".join(rows)}</table></div>')


def text_plan(plan: dict) -> list[str]:
    out = [f"plan from {plan['start_hour']} (jobs per hour, '.' = under 0.5; '|' = 5h reset, '#' = weekly reset):"]
    start = datetime.fromisoformat(plan["start_hour"].replace("Z", "+00:00"))
    for a in plan["accounts"]:
        if a["excluded"]:
            continue
        s = ""
        for i, p in enumerate(a["plan_jobs"]):
            h = _iso(start + timedelta(hours=i))[:13]
            if a["weekly_reset"] and a["weekly_reset"][:13] == h:
                s += "#"
            elif a["fiveh_reset"] and a["fiveh_reset"][:13] == h:
                s += "|"
            s += "." if 0 < p < 0.5 else str(min(9, int(round(p))))
        land = "?" if a["weekly_at_reset"] is None else f"{a['weekly_at_reset']:.0f}%"
        out.append(f"  {a['label']:16s} {s}  lands {land}{'' if a['reset_in_horizon'] else ' at +48h'}")
    return out


def load(path: str) -> tuple[list[PlanAcct], datetime]:
    """Snapshot JSON as pacer_rank.load_snapshot, plus per account: label, fiveh_start, fiveh_reset (iso)."""
    d = json.load(open(path))
    now = datetime.fromisoformat(d["now"]) if d.get("now") else datetime.now(timezone.utc)
    base = pr.load_snapshot(path)
    out = []
    for a, r in zip(base, d["accounts"]):
        hh = lambda k: None if not r.get(k) else (datetime.fromisoformat(r[k]) - now).total_seconds() / 3600.0
        out.append(PlanAcct(**vars(a), label=r.get("label", ""), win_start_h=hh("fiveh_start"), win_reset_h=hh("fiveh_reset")))
    return out, now


def selftest() -> None:
    now = datetime(2026, 11, 12, 4, tzinfo=timezone.utc)
    soon = PlanAcct("s@x", 70, 10, label="soon")   # 27% left, 2 windows x 14.5 = 29 room
    fresh = PlanAcct("f@x", 17, 160, fiveh=100, hold_h=2.5, label="fresh", win_reset_h=2.5)
    mid = PlanAcct("m@x", 70, 40, label="mid")
    p = build_plan([soon, fresh, mid], now)
    A = {a["label"]: a for a in p["accounts"]}
    assert A["soon"]["reset_in_horizon"] and A["soon"]["weekly_at_reset"] <= pr.SOON_CEIL + 0.5
    assert A["soon"]["waste_at_reset"] <= 10, A["soon"]                          # near reset: spends it
    assert sum(A["fresh"]["plan_jobs"][:2]) == 0                                  # hold: nothing before 5h reset
    for a in p["accounts"]:
        m = max([f for f, j in zip(a["plan_fiveh"], a["plan_jobs"]) if j > 0] or [0])
        assert m <= WIN_TARGET + 1, (a["label"], m)                               # planned hours never past 85% 5h
    assert all(sum(a["plan_jobs"][i] for a in p["accounts"]) <= FLEET + 1e-6 for i in range(HORIZON_H))
    assert A["mid"]["weekly_at_reset"] >= 85, A["mid"]                            # lands near ceiling at reset
    st = "/tmp/pacer_plan_selftest_state.json"
    if os.path.exists(st):
        os.remove(st)
    al = alerts(p, st, now)
    assert any("usage-reset soon" in x for x in al) and any("usage-5h-limit fresh" in x for x in al), al
    assert alerts(p, st, now) == []                                               # once only
    assert "uplan" in render_html(p)
    print("pacer_plan selftest ok")


def main(argv=None) -> int:
    global JOB_RATE, WINDOW, FLEET
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("snapshot", nargs="?")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--json", help="write usage-plan.json here (merges actuals from the existing file)")
    ap.add_argument("--html", help="write the /usage admin fragment here")
    ap.add_argument("--alert-state", help="dedupe file for alert lines")
    ap.add_argument("--running", default="", help="name=jobs,... running now (actuals)")
    ap.add_argument("--job-rate", type=float, default=JOB_RATE)
    ap.add_argument("--window", type=float, default=WINDOW)
    ap.add_argument("--fleet", type=int, default=FLEET)
    a = ap.parse_args(argv)
    if a.selftest:
        pr.selftest()
        selftest()
        return 0
    JOB_RATE, WINDOW, FLEET = a.job_rate, a.window, a.fleet
    accts, now = load(a.snapshot)
    plan = build_plan(accts, now, fleet=a.fleet)
    if a.json:
        old = json.load(open(a.json)) if os.path.exists(a.json) else None
        run = dict((k, int(v)) for k, v in (x.split("=") for x in a.running.split(",") if x))
        merge_actual(plan, old, run, now)
        write_plan(plan, a.json)
    if a.html:
        open(a.html, "w").write(render_html(plan))
    for line in text_plan(plan):
        print(line)
    for line in alerts(plan, a.alert_state, now):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
