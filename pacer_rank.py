#!/usr/bin/env python3
"""pacer_rank: use-it-or-lose-it account choice for usage-pacer (owner 11-12: "optimize around resets").

Drop-in policy module, written on rpc4 where usage-pacer itself is not reachable. It is meant to be imported
by /home/boki/coord/boki-tools/usage-pacer(.py): the pacer builds one Acct per account from cswap's numbers
(weekly %, 5h %, weekly reset time) and calls pick_order() / may_start() / summary_lines().

Rules (task 11-12):
 1. Rank by expiring headroom: headroom% / hours-to-reset. Accounts within SOON_H (24h) of reset with
    headroom rank first and may run to SOON_CEIL (97%).
 2. Fresh accounts (> FRESH_H = 72h to reset): weekly % <= even-pace line x FRESH_MULT (1.5) while any other
    account still has expiring headroom. The even-pace line comes from the reset time (cswap), never from
    history, so there is no "need 6h of history" bypass.
 3. 5h guard: no new start on an account whose 5h window is >= FIVEH_STOP (85%), or while it is on a hold.
 4. summary_lines(): per account %, hours to reset, projected waste at reset.
 5. CLI: `pacer_rank.py --dry-run snapshot.json` prints the ranking and what it would start now,
    plus projected waste before/after (simulation, see simulate()).

Coordinator accounts (corybogdan) are marked excluded and never picked.
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field, replace
from datetime import datetime, timezone

WEEK_H = 168.0
SOON_H = 24.0       # "within 24h of reset"
SOON_CEIL = 97.0    # may run hard to this
MID_CEIL = 90.0     # ceiling for accounts that are neither soon nor fresh (map to the pacer's own ceiling)
FRESH_H = 72.0      # "> 72h to reset" = fresh
FRESH_MULT = 1.5    # fresh cap: even-pace line x 1.5
FIVEH_STOP = 85.0   # 5h window guard
MIN_H = 0.5         # floor for hours-to-reset in the score (avoid div by ~0)


@dataclass
class Acct:
    name: str
    weekly: float                 # weekly used %
    hours_to_reset: float | None  # from cswap's weekly reset time; None = unknown
    fiveh: float = 0.0            # 5h window used %
    hold_h: float = 0.0           # hours until a 5h hold ends (0 = no hold)
    excluded: bool = False        # coordinator / never for pacer jobs
    note: str = ""


def even_pace(a: Acct) -> float | None:
    """Weekly % an account would be at if it spent evenly across its week (from reset time only)."""
    if a.hours_to_reset is None:
        return None
    elapsed = max(0.0, WEEK_H - a.hours_to_reset)
    return 100.0 * elapsed / WEEK_H


def band(a: Acct) -> str:
    h = a.hours_to_reset
    if h is None:
        return "unknown"
    if h <= SOON_H:
        return "soon"
    if h > FRESH_H:
        return "fresh"
    return "mid"


def has_expiring_headroom(a: Acct) -> bool:
    """Non-fresh account that can take work now and before its reset (what fresh accounts must yield to).
    One on a 5h hold or at the 5h guard cannot take work now, so it does not hold a fresh account back."""
    if a.excluded or band(a) in ("fresh", "unknown") or a.hold_h > 0 or a.fiveh >= FIVEH_STOP:
        return False
    return a.weekly < base_ceiling(a)


def base_ceiling(a: Acct) -> float:
    b = band(a)
    if b == "soon":
        return SOON_CEIL
    if b == "mid":
        return MID_CEIL
    return SOON_CEIL if b == "fresh" else MID_CEIL


def ceiling(a: Acct, others: list[Acct]) -> tuple[float, str]:
    """Weekly % this account may run to now, and why."""
    b = band(a)
    if b == "fresh" and any(has_expiring_headroom(o) for o in others if o.name != a.name):
        cap = min(base_ceiling(a), (even_pace(a) or 0.0) * FRESH_MULT)
        return cap, f"fresh pace cap {even_pace(a):.1f}x{FRESH_MULT}"
    return base_ceiling(a), b


def headroom(a: Acct, others: list[Acct]) -> float:
    return max(0.0, ceiling(a, others)[0] - a.weekly)


def score(a: Acct, others: list[Acct]) -> float:
    """Expiring headroom: % per hour that is lost if not spent before the reset."""
    if a.hours_to_reset is None:
        return 0.0
    return headroom(a, others) / max(MIN_H, a.hours_to_reset)


def may_start(a: Acct, others: list[Acct]) -> tuple[bool, str]:
    if a.excluded:
        return False, "excluded (coordinator)"
    if a.hold_h > 0:
        return False, f"5h hold {a.hold_h:.1f}h"
    if a.fiveh >= FIVEH_STOP:
        return False, f"5h {a.fiveh:.0f}% >= {FIVEH_STOP:.0f}%"
    cap, why = ceiling(a, others)
    if a.weekly >= cap:
        return False, f"weekly {a.weekly:.0f}% >= cap {cap:.1f}% ({why})"
    return True, f"ok, cap {cap:.1f}% ({why})"


def pick_order(accts: list[Acct]) -> list[Acct]:
    """Accounts allowed to start now, best first: soon-with-headroom, then by expiring headroom score."""
    ok = [a for a in accts if may_start(a, accts)[0]]
    return sorted(ok, key=lambda a: (band(a) != "soon", -score(a, accts), a.weekly))


def allot(order: list[Acct], accts: list[Acct], slots: int) -> dict[str, int]:
    """Spread `slots` starts: each goes to the highest score, and every start an account gets halves its score
    (so a soon account with lots of headroom takes most slots, but not blindly all of them past the others)."""
    eff = {a.name: (score(a, accts) + (1e3 if band(a) == "soon" else 0.0)) for a in order}
    got: dict[str, int] = {}
    for _ in range(slots if order else 0):
        n = max(eff, key=eff.get)
        got[n] = got.get(n, 0) + 1
        eff[n] /= 2.0
    return got


def projected_at_reset(a: Acct, rate: float | None = None) -> float | None:
    """Weekly % at reset if the account keeps its average rate since reset (or `rate` %/h)."""
    if a.hours_to_reset is None:
        return None
    elapsed = WEEK_H - a.hours_to_reset
    if rate is None:
        rate = a.weekly / elapsed if elapsed > 0 else 0.0
    return min(100.0, a.weekly + rate * a.hours_to_reset)


def summary_lines(accts: list[Acct]) -> list[str]:
    """Daily usage-report block: per account %, hours to reset, projected waste at reset (trend)."""
    out = ["usage-pacer daily: account  weekly  5h  to-reset  proj@reset  waste"]
    for a in accts:
        p = projected_at_reset(a)
        h = "?" if a.hours_to_reset is None else f"{a.hours_to_reset:.1f}h"
        pr = "?" if p is None else f"{p:.0f}%"
        w = "?" if p is None else f"{100 - p:.0f}%"
        if a.hours_to_reset is not None and WEEK_H - a.hours_to_reset < SOON_H:
            pr += " (early trend)"
        tag = " (coord)" if a.excluded else ""
        out.append(f"  {a.name}{tag}  {a.weekly:.0f}%  {a.fiveh:.0f}%  {h}  {pr}  {w}")
    return out


def simulate(accts: list[Acct], demand: float, window: float, horizon: float, dt: float = 0.25,
             policy: str = "new") -> dict[str, list[float]]:
    """Waste (100 - weekly % at reset) per account for each reset reached within `horizon` hours.

    policy "new": fleet demand (%/h of one account's week) goes to accounts in pick_order(), up to each one's
    ceiling and its 5h window (`window` weekly %-points per rolling 5h; fiveh % = window use, guard at 85%).
    policy "old": every account keeps its own average rate since reset (the pacer as it ran on 11-12,
    fresh account uncapped); this is the trend line, i.e. "if nothing changes".
    Excluded accounts take no load. A reset account restarts at 0% with 168h to go.
    """
    st = [replace(a) for a in accts]
    rates = {}
    for a in st:
        el = WEEK_H - (a.hours_to_reset or WEEK_H)
        rates[a.name] = (a.weekly / el) if el > 0 else 0.0
    waste: dict[str, list[float]] = {a.name: [] for a in st}
    waste["_unserved"] = []
    hist: dict[str, list[tuple[float, float]]] = {a.name: [] for a in st}  # (t, take) inside the 5h window
    t = 0.0
    while t < horizon:
        if policy == "new":
            left = demand * dt
            for a in pick_order(st):
                used = sum(v for _, v in hist[a.name])
                take = min(left, max(0.0, window - used), max(0.0, ceiling(a, st)[0] - a.weekly))
                a.weekly += take
                hist[a.name].append((t, take))
                left -= take
                if left <= 1e-9:
                    break
            waste["_unserved"].append(max(0.0, left))
        else:
            for a in st:
                if not a.excluded and a.hold_h <= 0:
                    a.weekly = min(100.0, a.weekly + rates[a.name] * dt)
        for a in st:
            a.hold_h = max(0.0, a.hold_h - dt)
            hist[a.name] = [(t0, v) for t0, v in hist[a.name] if t0 > t + dt - 5.0]
            if a.hold_h <= 0:
                a.fiveh = 100.0 * sum(v for _, v in hist[a.name]) / window
            if a.hours_to_reset is None:
                continue
            a.hours_to_reset -= dt
            if a.hours_to_reset <= 0:
                if not a.excluded:
                    waste[a.name].append(100.0 - a.weekly)
                a.weekly, a.hours_to_reset, a.fiveh = 0.0, WEEK_H, 0.0
        t += dt
    return waste


def load_snapshot(path: str) -> list[Acct]:
    """JSON: {"now": iso?, "accounts": [{name, weekly, reset_at (iso) | hours_to_reset, fiveh, hold_until?, excluded?}]}"""
    d = json.load(open(path))
    now = datetime.fromisoformat(d["now"]) if d.get("now") else datetime.now(timezone.utc)

    def hours(v):
        return None if v is None else (datetime.fromisoformat(v) - now).total_seconds() / 3600.0

    out = []
    for r in d["accounts"]:
        h = r.get("hours_to_reset")
        if h is None and r.get("reset_at"):
            h = hours(r["reset_at"])
        out.append(Acct(r["name"], float(r["weekly"]), h, float(r.get("fiveh", 0.0)),
                        max(0.0, hours(r.get("hold_until")) or 0.0), bool(r.get("excluded", False)),
                        r.get("note", "")))
    return out


def selftest() -> None:
    soon = Acct("soon", 77, 0.5)
    mid = Acct("mid", 71, 36)
    fresh = Acct("fresh", 17, 164)
    coord = Acct("coord", 0, 100, excluded=True)
    fl = [soon, mid, fresh, coord]
    assert [a.name for a in pick_order(fl)] == ["soon", "mid"], pick_order(fl)       # 1: soon first; 2: fresh capped
    assert ceiling(soon, fl)[0] == SOON_CEIL
    assert abs(ceiling(fresh, fl)[0] - 100 * 4 / 168 * 1.5) < 1e-6                     # 2: cap from reset time
    assert may_start(fresh, [fresh, coord])[0]                                        # 2: no one else expiring
    mid5 = replace(mid, fiveh=85)
    assert not may_start(mid5, fl)[0]                                                 # 3: 5h guard
    assert may_start(fresh, [soon, mid5, fresh])[0] is False                          # soon still has headroom
    assert may_start(fresh, [replace(soon, weekly=97), mid5, fresh])[0]               # 5h-blocked does not hold back
    assert not may_start(coord, fl)[0]
    print("pacer_rank selftest ok")


def main(argv=None) -> int:
    if argv is None and sys.argv[1:] == ["--selftest"]:
        selftest()
        return 0
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("snapshot")
    ap.add_argument("--dry-run", action="store_true", help="print only (this module never starts anything)")
    ap.add_argument("--demand", type=float, default=3.0, help="fleet demand, %%/h of one account-week")
    ap.add_argument("--window", type=float, default=17.0, help="weekly %%-points one 5h window holds (outlook2 11-12: ~17)")
    ap.add_argument("--horizon", type=float, default=96.0)
    ap.add_argument("--slots", type=int, default=6, help="starts wanted now")
    a = ap.parse_args(argv)
    accts = load_snapshot(a.snapshot)

    print("ranking (expiring headroom = headroom% / hours-to-reset):")
    for x in sorted(accts, key=lambda x: -score(x, accts)):
        ok, why = may_start(x, accts)
        h = "?" if x.hours_to_reset is None else f"{x.hours_to_reset:5.1f}h"
        print(f"  {x.name:28s} {band(x):7s} wk {x.weekly:3.0f}% 5h {x.fiveh:3.0f}% reset {h} "
              f"head {headroom(x, accts):5.1f}% score {score(x, accts):6.2f}  {'START' if ok else 'skip '} {why}")
    order = pick_order(accts)
    picks = allot(order, accts, a.slots)
    print(f"would start now ({a.slots} slots): " + (", ".join(f"{n} x{k}" for n, k in picks.items()) or "nothing"))
    print()
    for line in summary_lines(accts):
        print(line)
    print()
    old = simulate(accts, a.demand, a.window, a.horizon, policy="old")
    new = simulate(accts, a.demand, a.window, a.horizon, policy="new")
    print(f"projected waste at reset, next {a.horizon:.0f}h (demand {a.demand}%/h, 5h window {a.window}%):")
    for x in accts:
        if x.excluded:
            continue
        f = lambda v: "/".join(f"{w:.0f}%" for w in v) or "no reset"
        print(f"  {x.name:28s} before {f(old[x.name]):10s} after {f(new[x.name])}")
    tot = lambda w: sum(sum(v) for k, v in w.items() if k != "_unserved")
    print(f"  total wasted %-points    before {tot(old):.0f}  after {tot(new):.0f}"
          f"  (after: demand not served {sum(new['_unserved']):.0f} %-points)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
