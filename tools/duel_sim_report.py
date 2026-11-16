#!/usr/bin/env python3
"""Tables for docs/BALANCE_1111.md from the rounds --duel-sim wrote (one JSON line per round).

    python3 tools/duel_sim_report.py <rounds.jsonl>

Prints markdown: the 12x12 win-rate matrix, each Hunter's totals (win rate, time to knock), its damage
share by slot, and the outliers (a Hunter outside 40-60%, a matchup past 80/20, a slot over 60%).
"""
import json
import math
import statistics
import sys
from collections import defaultdict

ORDER = ["gunslinger", "juggernaut", "ashwick", "tender", "dolm", "archer",
         "dredge", "rimewright", "mage", "bulwark", "thief", "ostra"]
NAME = {"gunslinger": "Vex", "juggernaut": "Kael", "ashwick": "Cinder", "tender": "Meeko",
        "dolm": "Tenzo", "archer": "Lace", "dredge": "Grimble", "rimewright": "Neve",
        "mage": "Sparkle", "bulwark": "Mossy", "thief": "Sable", "ostra": "Motley"}
SLOTS = ["LMB", "RMB", "Dash", "E", "R", "Passive", "Env", "Other"]
R_TAGS = {"ult", "ultimate", "riposte", "encore", "x"}           # a hit tagged with any of these is R
E_TAGS = {"cloak"}                                               # Cinder's E rides the flame tag
FIRST = {"primary": "LMB", "shot": "LMB", "flame": "LMB", "melee": "LMB", "lmb": "LMB",
         "utility": "RMB", "secondary": "RMB", "rmb": "RMB",
         "k1": "E", "signature": "E", "anchor": "E", "e": "E", "tether": "E",
         "rock": "E",       # Tenzo's rocks: Rockwave (E) raises them, the punch and the dash launch them
         "dodge": "Dash", "dash": "Dash", "form_dash": "Dash",
         "passive": "Passive", "burn": "Passive",     # (burn: Cinder's Ignite ticks, summed per round)
         "fall": "Env", "wall": "Env", "boom": "Env"}       # (boom: a breakable keg or pot set off)
LOW, HIGH = 0.40, 0.60      # a Hunter's overall win rate outside this band is an outlier
LOPSIDED = 0.80             # a matchup won this often by one side is an outlier
HEAVY_SLOT = 0.60           # one slot dealing this share of a Hunter's damage is an outlier


def slot_of(key):
    """The kit slot a hit's tag key belongs to (see tools/duel_sim.gd _on_hit). A generic "abil" hit
    carries the kit's own slot key second (Match.on_damage)."""
    tags = key.split("+")
    if tags[0] == "abil" and len(tags) > 1:
        tags = tags[1:]
    if R_TAGS & set(tags):
        return "R"
    if E_TAGS & set(tags):
        return "E"
    return FIRST.get(tags[0], "Other")


def load(path):
    with open(path) as f:
        return [json.loads(line) for line in f if line.strip()]


def tally(rounds):
    wins = defaultdict(float)       # (hero, foe) -> wins (a draw is half)
    games = defaultdict(int)
    ttk = defaultdict(list)         # hero -> seconds from the first hit to its knock of the foe
    dmg = defaultdict(lambda: defaultdict(float))
    other = defaultdict(float)      # unmapped tag keys, for the report's footnote
    draws = defaultdict(int)
    for r in rounds:
        pair = (r["a"], r["b"])
        first = min((h[3] for h in r["hits"]), default=0.0)
        for side, hero in enumerate(pair):
            foe = pair[1 - side]
            if r["a"] == r["b"] and side == 1:
                continue            # a mirror counts once
            games[(hero, foe)] += 1
            if r["win"] == side:
                wins[(hero, foe)] += 1
                ttk[hero].append(r["t"] - first)
            elif r["win"] < 0:
                wins[(hero, foe)] += 0.5
                draws[hero] += 1
        for side, key, d, _t in r["hits"]:
            hero = pair[side]
            s = slot_of(key)
            dmg[hero][s] += d
            if s == "Other":
                other[key] += d
    return wins, games, ttk, dmg, other, draws


def pct(x):
    return "%d" % round(100 * x)


def report(rounds):
    wins, games, ttk, dmg, other, draws = tally(rounds)
    heroes = [h for h in ORDER if any(k[0] == h for k in games)]
    out = ["## Win rate matrix (row beats column, %%; %d rounds)" % len(rounds), "",
           "| | " + " | ".join(NAME[h] for h in heroes) + " |",
           "|---" * (len(heroes) + 1) + "|"]
    for h in heroes:
        cells = []
        for f in heroes:
            n = games[(h, f)]
            cells.append(pct(wins[(h, f)] / n) if n else "-")
        out.append("| **%s** | %s |" % (NAME[h], " | ".join(cells)))
    out += ["", "## Per Hunter", "",
            "| Hunter | Win % (mirrors out) | Rounds | Draws | TTK median s | TTK p90 s |",
            "|---|---|---|---|---|---|"]
    overall = {}
    for h in heroes:
        w = sum(wins[(h, f)] for f in heroes if f != h)
        n = sum(games[(h, f)] for f in heroes if f != h)
        overall[h] = w / n if n else 0.0
        t = sorted(ttk[h])
        med = statistics.median(t) if t else 0.0
        p90 = t[math.ceil(0.9 * len(t)) - 1] if t else 0.0      # nearest rank
        out.append("| %s | %s | %d | %d | %.1f | %.1f |" % (NAME[h], pct(overall[h]), n, draws[h], med, p90))
    out += ["", "## Damage share by slot (%% of all damage the Hunter dealt to the other Hunter)", "",
            "| Hunter | " + " | ".join(SLOTS) + " |", "|---" * (len(SLOTS) + 1) + "|"]
    heavy = []
    for h in heroes:
        tot = sum(dmg[h].values()) or 1.0
        shares = {s: dmg[h][s] / tot for s in SLOTS}
        out.append("| %s | %s |" % (NAME[h], " | ".join(pct(shares[s]) for s in SLOTS)))
        heavy += ["%s %s %s%%" % (NAME[h], s, pct(v)) for s, v in shares.items() if v >= HEAVY_SLOT]
    out += ["", "## Outliers", ""]
    out += ["- Hunter outside %s-%s%%: %s" % (pct(LOW), pct(HIGH), ", ".join(
        "%s %s%%" % (NAME[h], pct(v)) for h, v in sorted(overall.items(), key=lambda x: -x[1])
        if not LOW <= v <= HIGH) or "none")]
    lop = []
    for i, h in enumerate(heroes):
        for f in heroes[i + 1:]:
            n = games[(h, f)]
            if n and max(wins[(h, f)], wins[(f, h)]) / n >= LOPSIDED:
                win, lose = (h, f) if wins[(h, f)] >= wins[(f, h)] else (f, h)
                lop.append("%s over %s %s%%" % (NAME[win], NAME[lose], pct(wins[(win, lose)] / n)))
    out.append("- Matchups past %s/%s: %d: %s" % (pct(LOPSIDED), pct(1 - LOPSIDED), len(lop), "; ".join(lop) or "none"))
    out.append("- One slot over %s%% of a Hunter's damage: %s" % (pct(HEAVY_SLOT), ", ".join(heavy) or "none"))
    if other:
        top = sorted(other.items(), key=lambda x: -x[1])[:8]
        out.append("- Unmapped hit tags (counted as Other): " + ", ".join("%s %.0f" % kv for kv in top))
    return "\n".join(out)


if __name__ == "__main__":
    print(report(load(sys.argv[1])))
