#!/usr/bin/env python3
"""Headless garden balance sim (briefs/design/GARDEN_MODERN_BALANCE.md). No Godot.

Plays content/rules/garden_sim.json `days` garden days for each player there, `seeds` times,
and prints per player: days to the first evolution, days to fill the stat budget, shaping items
per family, path meter flips, and XP a day against an expedition-only player with the same time.

  python3 tools/garden_sim.py                    print the report
  python3 tools/garden_sim.py --write            put the report into the balance brief
  python3 tools/garden_sim.py --garden-sim-check assert the invariants and that the brief is current
"""
import json
import os
import random
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RULES = os.path.join(ROOT, "content", "rules")
BRIEF = os.path.join(ROOT, "briefs", "design", "GARDEN_MODERN_BALANCE.md")
BEGIN, END = "<!-- garden_sim:begin -->", "<!-- garden_sim:end -->"
STATS = ("power", "guard", "speed", "focus")
FAMILIES = ("stat", "path", "lean", "looks", "personality", "respec")


def load(name):
    path = os.path.join(RULES, name)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        return json.load(f)


def live_rules(sim):
    """Live rules where the branch has them, else the READY-branch copies in sim.fallback."""
    fb = sim["fallback"]
    care = load("care.json") or {}
    budget = care.get("stat_budget", fb["stat_budget"])
    prizes = load("garden_prizes.json")
    if prizes:
        cup = [r["min_ratio"] for r in prizes["cup"]["rounds"]]
        games = {}
        for gid, g in prizes["games"].items():
            table = {}
            for e in g["table"]:
                key = e["id"] if e["kind"] == "item" else "snack"
                table[key] = table.get(key, 0) + e["w"]
            games[gid] = {"first": g["first"], "cup_prize": g["cup_prize"], "table": table}
    else:
        cup, games = fb["cup"], fb["games"]
    items_file = load("garden_items.json")
    if items_file:
        items = {}
        for it in items_file["items"]:
            eff = it["effect"]
            items[it["id"]] = [it["family"], eff.get("stat", eff.get("aff", eff["kind"])), eff.get("n", 0)]
    else:
        items = fb["items"]
    paths = load("evo_paths.json")
    line = dict(paths["lines"][sim["line"]], pips=paths["pips"]) if paths else fb["line"]
    toys = load("toys.json") or {}
    joy = {"gain": toys.get("joy_gain", 10.0), "below": toys.get("joy_below", 85.0)}
    gems_win = (load("base_race.json") or {}).get("gems_win", sim["gems_win"])
    return {"budget": budget, "cup": cup, "games": games, "items": items, "line": line, "joy": joy,
            "gems_win": gems_win}


class Boki:
    def __init__(self, budget):
        self.b = budget
        self.level, self.xp, self.garden_level, self.garden_xp = 1, 0, 1, 0
        self.stats = {s: 0 for s in STATS}
        self.acc = {s: 0.0 for s in STATS}
        self.toy_use = {s: 0 for s in STATS}
        self.tokens, self.ribbons = [], []

    def cap(self, stat):
        own = min(self.b["cap_max"], self.b["cap_base"] + self.b["cap_per_level"] * self.level)
        room = self.b["total_cap"] - sum(self.stats.values())
        return min(own - self.stats[stat], room)

    def share(self, stat):
        for top, k in self.b["bands"]:
            if self.stats[stat] < top:
                return k
        return 0.0

    def toy(self, stat):
        """A toy play: one point times the band share, carried over as a fraction."""
        self.toy_use[stat] += 1
        self.acc[stat] += self.share(stat)
        if self.acc[stat] >= 1.0 and self.cap(stat) > 0:
            self.acc[stat] -= 1.0
            self.stats[stat] += 1

    def bite(self, stat, n):
        """An eaten bite: n times the band share, rounded up (brief 2.2: +3, +2, +1)."""
        gain = -(-n * self.share(stat) // 1)
        self.stats[stat] += int(max(0, min(gain, self.cap(stat))))

    def add_xp(self, n, curve, garden=True):
        self.xp += n
        while self.xp >= need(curve, self.level):
            self.xp -= need(curve, self.level)
            self.level += 1
        if garden:
            self.garden_xp += n
            while self.garden_xp >= need(curve, self.garden_level):
                self.garden_xp -= need(curve, self.garden_level)
                self.garden_level += 1


def need(curve, level):
    """XP from level to level + 1: per_level x level, flat from flat_from on (null: never)."""
    flat = curve["flat_from"]
    return curve["per_level"] * (min(level, flat) if flat else level)


def win_p(sim, ratio):
    return max(0.1, min(0.9, 0.5 + sim["skill"] + sim["slope"] * (1.0 - ratio)))


def meter(boki, line):
    """Pips per end (GARDEN_MODERN 3.2; lean and trait pips are not modelled), then the winner."""
    ends, pips = line["ends"], line["pips"]
    score = [0, 0]
    a, b = boki.stats[ends[0]["stat"]], boki.stats[ends[1]["stat"]]
    lead = 0 if a > b else 1 if b > a else -1
    if lead >= 0:
        score[lead] += pips["stat_lead"]
    top_toy = max(STATS, key=lambda s: boki.toy_use[s])
    for i, end in enumerate(ends):
        score[i] += min(pips["tokens_max"], boki.tokens.count(end["path"]))
        score[i] += min(pips["ribbons_max"], sum(1 for r in boki.ribbons if r in end["sports"]))
        if boki.toy_use[top_toy] and top_toy == end["stat"]:
            score[i] += pips["care_toy"]
    if score[0] != score[1]:
        return 0 if score[0] > score[1] else 1
    return lead


def play_day(sim, rules, p, boki, st, rng):
    xpr, xpl = sim["garden_xp"], sim["xp_curve"]
    line = rules["line"]
    target = line["ends"][1]
    left = float(p["minutes"])
    got = st["items"]

    def gain(item):
        got[item] = got.get(item, 0) + 1
        kind = rules["items"].get(item)
        if kind is None:
            return
        fam, what, n = kind
        if fam == "stat" and what == "xp":
            boki.add_xp(n, xpl)
        elif fam == "stat":
            if p["plan"] and what == line["ends"][0]["stat"]:
                return
            boki.bite(what, n)
        elif fam == "path" and what in (e["path"] for e in line["ends"]):
            if len(boki.tokens) < line["pips"]["tokens_max"] and (not p["plan"] or what == target["path"]):
                boki.tokens.append(what)

    # overnight: away gifts and away training, then the expeditions of the day
    for _ in range(sim["away_gifts"]):
        gain(roll(rng, sim["away_items"]))
    for _ in range(sim["away_points"]):
        boki.toy(rng.choice(sim["toys"]))
    ex = sim["expedition"]
    for _ in range(p["runs"]):
        won = rng.random() < ex["win_p"]
        boki.add_xp(ex["xp_base"] + (ex["xp_win"] if won else 0) + int(ex["xp_knock"] * ex["knocks"]), xpl, garden=False)
        st["run_xp"] += ex["xp_base"] + (ex["xp_win"] if won else 0) + int(ex["xp_knock"] * ex["knocks"])
        earn(st, ex["gems"])
        locked = [z for z in sim["zones"] if z not in st["open"]]
        if locked and rng.random() < ex["wayseed_p"]:
            st["open"].append(locked[0])
    earn(st, sim["home_gems_day"])
    if st["day"] % sim["trader_days"] == 0:
        locked = [z for z in sim["zones"] if z not in st["open"]]
        if locked and st["gems"] >= sim["wayseed_price"]:
            st["gems"] -= sim["wayseed_price"]
            st["open"].append(locked[0])
        else:
            gain(rng.choice(sim["trader_items"]))
    if st["day"] % 7 == 0:
        st["crowned"] = set()

    t = sim["time"]
    ripen = 1 + int(p["minutes"] / sim["patch_min"])
    for z in st["open"]:
        for _ in range(ripen):
            if rng.random() < sim["golden_p"]:
                gain(rng.choice(sim["zones"][z]["golden"]))
    left -= t["arrive"]
    if left >= t["care"]:
        left -= t["care"]
        boki.add_xp(xpr["care_first"] * xpr["care_kinds"], xpl)
        st["garden_xp"] += xpr["care_first"] * xpr["care_kinds"]
    games = [sim["zones"][z]["game"] for z in st["open"]]
    first_won = set()

    def match(gid, ratio):
        stat = sum(boki.stats[s] for s in sim["game_stats"][gid])
        won = rng.random() < win_p(sim, ratio)
        xp = xpr["win"] if won else xpr["play"]
        if won and gid not in first_won:
            xp = xpr["first_win"]
            first_won.add(gid)
            gain(rules["games"][gid]["first"])
        if won:
            gain(roll_w(rng, rules["games"][gid]["table"]))
            earn(st, rules["gems_win"])
        boki.add_xp(xp, xpl)
        st["garden_xp"] += xp
        return won, stat

    granted = 0
    while left >= t["game"]:
        todo = [g for g in games if g not in first_won and st["tries"].get(g, 0) < 2]
        if todo:
            st["tries"][todo[0]] = st["tries"].get(todo[0], 0) + 1
            left -= t["game"]
            match(todo[0], 1.0 + rng.uniform(-sim["rival_spread"], sim["rival_spread"]))
            continue
        if granted < sim["wishes"] and left >= t["wish"]:
            left -= t["wish"]
            granted += 1
            boki.add_xp(xpr["wish"], xpl)
            st["garden_xp"] += xpr["wish"]
            gain(roll(rng, sim["wish_items"]))
            if granted == sim["wishes"]:
                gain("sunsap")
            continue
        cups = [g for g in games if g not in st["crowned"]]
        if cups and left >= t["cup_round"] * len(rules["cup"]):
            gid = cups[0]
            for i, ratio in enumerate(rules["cup"]):
                left -= t["cup_round"]
                won, _ = match(gid, ratio)
                if not won:
                    break
                if i == len(rules["cup"]) - 1:
                    st["crowned"].add(gid)
                    boki.ribbons.append(gid)
                    gain("cup_ribbon")
                    gain(rules["games"][gid]["cup_prize"])
            continue
        left -= t["game"]
        match(rng.choice(games), 1.0 + rng.uniform(-sim["rival_spread"], sim["rival_spread"]))
    for _ in range(int(p["minutes"] * sim["toy_per_min"])):
        boki.toy(rng.choice(sim["toys"]))
    st["tries"] = {}


def earn(st, gems):
    st["gems"] += gems
    st["earned"] += gems


def visit_joy(sim, rules, p):
    """Mean joy over one visit: it starts at the away floor, the first cares and toy plays raise it
    (a toy is only picked below joy_below), the clock lowers it. joy_model holds the sim guesses."""
    m, j = sim["joy_model"], rules["joy"]
    start = m["away"]
    joy = start + m["care"] * sim["garden_xp"]["care_kinds"]
    for _ in range(int(p["minutes"] * sim["toy_per_min"])):
        if joy < j["below"]:
            joy += j["gain"]
    end = min(100.0, joy - m["decay_per_min"] * p["minutes"])
    return (start + end) / 2


def roll(rng, odds):
    r = rng.random()
    for item, p in odds.items():
        if r < p:
            return item
        r -= p
    return "snack"


def roll_w(rng, table):
    return rng.choices(list(table), weights=list(table.values()))[0]


def run_player(sim, rules, p, seed):
    rng = random.Random(seed)
    boki = Boki(rules["budget"])
    st = {"items": {}, "open": [next(iter(sim["zones"]))], "gems": 0, "crowned": set(), "tries": {},
          "garden_xp": 0, "run_xp": 0, "day": 0, "earned": 0}
    out = {"level_day": {}, "garden_first": None, "full": None, "flips": 0, "winner": None}
    last = None
    for day in range(1, sim["days"] + 1):
        st["day"] = day
        play_day(sim, rules, p, boki, st, rng)
        for lv in sim["report_levels"]:
            if boki.level >= lv and lv not in out["level_day"]:
                out["level_day"][lv] = day
        if out["garden_first"] is None and boki.garden_level >= sim["first_evo_level"]:
            out["garden_first"] = day
        if out["full"] is None and sum(boki.stats.values()) >= rules["budget"]["total_cap"]:
            out["full"] = day
        w = meter(boki, rules["line"])
        if w >= 0 and last is not None and w != last:
            out["flips"] += 1
        if w >= 0:
            last = w
    fam = {f: 0 for f in FAMILIES}
    extra = sim["families_extra"]
    for item, n in st["items"].items():
        f = rules["items"][item][0] if item in rules["items"] else extra.get(item)
        if f:
            fam[f] += n
    out.update(fam=fam, level=boki.level, stats=dict(boki.stats), zones=len(st["open"]), winner=last,
               garden_xp=st["garden_xp"] / sim["days"], run_xp=st["run_xp"] / sim["days"],
               gems=st["earned"] / sim["days"])
    return out


def median_day(vals, days):
    """Median day, with a run that never got there counted as days + 1 (shown as '>days')."""
    m = statistics.median(v if v is not None else days + 1 for v in vals)
    return f">{days}" if m > days else f"{m:g}"


def simulate(sim):
    rules = live_rules(sim)
    ex = sim["expedition"]
    run_avg = ex["xp_base"] + ex["xp_win"] * ex["win_p"] + ex["xp_knock"] * ex["knocks"]
    to_100 = sum(need(sim["xp_curve"], lv) for lv in range(1, 100))
    report = {}
    for pid, p in sim["players"].items():
        runs = [run_player(sim, rules, p, 1000 * i + 7) for i in range(sim["seeds"])]
        days = sim["days"]
        mins = p["minutes"] + p["runs"] * ex["run_min"]
        report[pid] = {
            "name": p["name"],
            "levels": {lv: median_day([r["level_day"].get(lv) for r in runs], days) for lv in sim["report_levels"]},
            "garden_first": median_day([r["garden_first"] for r in runs], days),
            "full": median_day([r["full"] for r in runs], days),
            "fam": {f: statistics.mean(r["fam"][f] for r in runs) for f in FAMILIES},
            "flips": statistics.mean(r["flips"] for r in runs),
            "target": statistics.mean(1 if r["winner"] == 1 else 0 for r in runs),
            "level": statistics.median(r["level"] for r in runs),
            "total": statistics.median(sum(r["stats"].values()) for r in runs),
            "zones": statistics.mean(r["zones"] for r in runs),
            "garden_xp": statistics.mean(r["garden_xp"] for r in runs),
            "run_xp": statistics.mean(r["run_xp"] for r in runs),
            "exp_only": run_avg / ex["run_min"] * mins,
            "lv100": to_100 / (statistics.mean(r["garden_xp"] + r["run_xp"] for r in runs)),
            "gems": statistics.mean(r["gems"] for r in runs),
            "joy": visit_joy(sim, rules, p),
            "raw": runs,
        }
    return report


def day_of(text, days):
    """A median-day string back to a number; '>30' counts as 31."""
    return days + 1 if text.startswith(">") else float(text)


def band_flags(sim, report):
    """Every number outside its band (garden_sim.json bands) as 'player: what value (band)'."""
    bands, days, out = sim["bands"], sim["days"], []
    for pid, r in report.items():
        got = {"form_lv4_day": day_of(r["levels"][4], days), "evolution_day": day_of(r["garden_first"], days),
               "stat_total": r["total"], "gems_day": r["gems"], "joy": r["joy"]}
        if r["full"] != f">{days}":
            got["budget_full_day"] = float(r["full"])
        for key, val in got.items():
            lo, hi = bands[key]
            if not lo <= val <= hi:
                out.append(f"{pid}: {key} {val:.1f} outside {lo} to {hi}")
    return out


def render(sim, report):
    lv = sim["report_levels"]
    lines = [f"Generated by `python3 tools/garden_sim.py --write` from content/rules/garden_sim.json "
             f"({sim['days']} days, {sim['seeds']} seeds; days are medians, the rest means).", "",
             "| Player | " + " | ".join(f"Lv {x} (day)" for x in lv)
             + f" | Lv {sim['first_evo_level']}, garden XP only | Budget 240 full | Stat total d{sim['days']} "
             f"| Level d{sim['days']} | Gems/day | Joy | Zones open | Garden XP/day | Run XP/day "
             "| Expedition-only XP/day, same minutes | Days to Lv 100 at this rate |",
             "|---" * (len(lv) + 12) + "|"]
    for r in report.values():
        lines.append(f"| {r['name']} | " + " | ".join(r["levels"][x] for x in lv)
                     + f" | {r['garden_first']} | {r['full']} | {r['total']:g} | {r['level']:g} | {r['gems']:.0f} | {r['joy']:.0f} | {r['zones']:.1f} "
                     f"| {r['garden_xp']:.0f} | {r['run_xp']:.0f} | {r['exp_only']:.0f} | {r['lv100']:.0f} |")
    lines += ["", "| Player | " + " | ".join(FAMILIES) + " | Meter flips | Ends on Ringrove |",
              "|---" * (len(FAMILIES) + 3) + "|"]
    for r in report.values():
        lines.append(f"| {r['name']} | " + " | ".join(f"{r['fam'][f]:.1f}" for f in FAMILIES)
                     + f" | {r['flips']:.1f} | {r['target']:.0%} |")
    lines += ["", "Flags: " + ("; ".join(band_flags(sim, report)) or "none")]
    return "\n".join(lines)


def body(sim):
    return render(sim, simulate(sim))


def check(sim):
    fails = []
    rules = live_rules(sim)
    report = simulate(sim)
    cap = rules["budget"]
    for pid, r in report.items():
        for run in r["raw"]:
            if sum(run["stats"].values()) > cap["total_cap"] or max(run["stats"].values()) > cap["cap_max"]:
                fails.append(f"{pid}: stats over the budget {run['stats']}")
                break
        if sim["players"][pid]["runs"] == 0 and r["run_xp"] != 0:
            fails.append(f"{pid}: home-only player got run XP")
        if r["garden_xp"] <= 0:
            fails.append(f"{pid}: no garden XP")
    keen, casual = report.get("keen30"), report.get("casual5")
    if keen and casual and keen["garden_xp"] <= casual["garden_xp"]:
        fails.append("30-minute player earns no more garden XP than the 5-minute one")
    fails += band_flags(sim, report)
    if render(sim, report) != render(sim, simulate(sim)):
        fails.append("sim is not deterministic")
    with open(BRIEF) as f:
        doc = f.read()
    if BEGIN not in doc or doc.split(BEGIN)[1].split(END)[0].strip() != body(sim).strip():
        fails.append("briefs/design/GARDEN_MODERN_BALANCE.md is stale: run tools/garden_sim.py --write")
    for f in fails:
        print("FAIL", f)
    print(f"garden-sim-check: {len(fails)} failures")
    return 1 if fails else 0


def load_sim():
    """garden_sim.json plus the live garden XP and level curve (garden_xp.json), so the sim fits what is built."""
    sim, live = load("garden_sim.json"), load("garden_xp.json")
    sim["xp_curve"] = live["curve"]
    sim["garden_xp"] = dict(sim["garden_xp_unbuilt"], play=live["play"], win=live["win"],
                            first_win=live["first_win"], care_first=live["care"])
    return sim


def main():
    sim = load_sim()
    if "--garden-sim-check" in sys.argv:
        sys.exit(check(sim))
    text = body(sim)
    if "--write" in sys.argv:
        with open(BRIEF) as f:
            doc = f.read()
        head, rest = doc.split(BEGIN)
        with open(BRIEF, "w") as f:
            f.write(head + BEGIN + "\n" + text + "\n" + END + rest.split(END)[1])
    print(text)


if __name__ == "__main__":
    main()
