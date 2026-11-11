class_name XpRules
extends RefCounted
## Who earns level XP and how much (content/rules/xp.json, docs/decisions/0048-camps-and-xp.md).
## XP is a kill reward: a monster's kill and a knock pay the killer's squad within share_r of the
## killer, in full to each. Each game pays only the Hunters it owns (levels sync from their owner).
##
## Public API:
##   XpRules.pay_squad(m, by, xp, src)   pays xp to the killer (a Boki's kill is its Hunter's) and squad in range
##   XpRules.pay_knock(m, by, victim), pay_kill(m, by, mb, xp)   the same, by what was killed
##   XpRules.pay_one(h, xp, src)   pays one Hunter; src is camp | mob | boss | knock
##   XpRules.steal_check(m, by, by_team)   a last hit that took a kill another squad did most of
##   XpRules.line(h) -> String, XpRules.log_hunters(m, tag)   the results line and the match log
##   XpRules.knock_xp(victim) -> float   what knocking this Hunter pays
##   XpRules.kill_xp(mb) -> float   what killing this monster pays (0 for a lair boss: Lairs pays it)
##   XpRules.pace_level(t) -> int   the level a squad that plays camps and objectives well has at match second t

const MARKS: Array[float] = [120.0, 240.0, 315.0, 480.0, 600.0]     # s: when each Hunter's level goes to the match log
# camp monsters, other monsters, bosses and the Watcher, knocks
const SOURCES: Array[String] = ["camp", "mob", "boss", "knock"]
const TALLY := "xp_tally"       # Hunter meta: {src: {"n": payments, "xp": total}, "camps", "stole", "robbed"}

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/xp.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## The killer's squadmates (alive or downed) within share_r of the killer, this game's own Hunters only.
static func squad_in_range(m, by) -> Array[Hunter]:
	var out: Array[Hunter] = []
	var h = by.owner_h if by is Kin else by
	if not (h is Hunter):
		return out
	var r := float(rules()["share_r"])
	for o: Hunter in m.hunters:
		if o.team == h.team and not o.remote and not o.out and not o.extracted and o.flat_dist(h.pos) <= r:
			out.append(o)
	return out

## Pays the killer and each squadmate in range, in full, and counts it under src.
static func pay_squad(m, by, xp: float, src: String) -> void:
	if xp <= 0.0:
		return
	for o in squad_in_range(m, by):
		pay_one(o, xp, src)

static func pay_knock(m, by, victim: Hunter) -> void:
	pay_squad(m, by, knock_xp(victim), "knock")

static func pay_kill(m, by, mb: Mob, xp: float) -> void:
	pay_squad(m, by, xp, source_of(mb))

static func pay_one(h: Hunter, xp: float, src: String) -> void:
	var e: Dictionary = tally(h).get_or_add(src, {"n": 0, "xp": 0.0})
	e["n"] += 1
	e["xp"] += xp
	h.gain_xp(xp)

static func tally(h: Hunter) -> Dictionary:
	if not h.has_meta(TALLY):
		h.set_meta(TALLY, {"camps": 0, "stole": 0, "robbed": 0})
	return h.get_meta(TALLY)

static func count(h: Hunter, key: String) -> int:
	return int(tally(h).get(key, {}).get("n", 0))

static func note_camp_clear(m, by) -> void:
	for o in squad_in_range(m, by):
		tally(o)["camps"] += 1

## A steal: the last hit's squad landed a kill that another squad did more of (by_team: team -> damage or XP).
static func steal_check(m, by, by_team: Dictionary) -> void:
	var h = by.owner_h if by is Kin else by
	if not (h is Hunter):
		return
	var top := float(by_team.get(h.team, 0.0))
	var victim := -1
	for t: int in by_team:
		if t >= 0 and t != h.team and float(by_team[t]) > top:
			top = float(by_team[t])
			victim = t
	if victim < 0:
		return
	for o in squad_in_range(m, h):
		tally(o)["stole"] += 1
	for o: Hunter in m.hunters:
		if o.team == victim and not o.remote:
			tally(o)["robbed"] += 1

static func xp_total(h: Hunter) -> float:
	var t := 0.0
	for src in SOURCES:
		t += float(tally(h).get(src, {}).get("xp", 0.0))
	return t

## The results line: "Level 8: 6 camps, 4 knocks, 1 boss".
static func line(h: Hunter) -> String:
	var parts: Array[String] = []
	var counts := [[int(tally(h)["camps"]), "camp", "camps"], [count(h, "knock"), "knock", "knocks"],
		[count(h, "boss"), "boss", "bosses"]]
	for k in counts:
		if k[0] > 0:
			parts.append("%d %s" % [k[0], k[1] if k[0] == 1 else k[2]])
	return "Level %d: %s" % [h.lvl, ", ".join(parts) if not parts.is_empty() else "no XP yet"]

## [name, line] for each Hunter of the team, for the results screen.
static func squad_lines(m, team: int) -> Array:
	return m.hunters.filter(func(h): return h.team == team).map(func(h): return [h.pname, line(h)])

## One match-log line per Hunter: level, XP by source (payments/XP), steals made and suffered.
static func log_hunters(m, tag: String) -> void:
	for h: Hunter in m.hunters:
		var t := tally(h)
		var bits: Array[String] = []
		for src in SOURCES:
			bits.append("%s=%d/%d" % [src, count(h, src), int(float(t.get(src, {}).get("xp", 0.0)))])
		print("XPLOG %s %s team=%d lvl=%d %s camps=%d stole=%d robbed=%d" % [
			tag, h.pname, h.team, h.lvl, " ".join(bits), t["camps"], t["stole"], t["robbed"]])

static func pace_level(t: float) -> int:
	var lv := 0
	for from_s in rules()["pace"]["from_s"]:
		if t >= float(from_s): lv += 1
	return maxi(lv, 1)

static func knock_xp(victim: Hunter) -> float:
	var k: Dictionary = rules()["knock"]
	return float(k["base"]) + float(k["per_level"]) * victim.lvl

## camp, mob (any other monster), or boss (lair bosses and the Watcher).
static func source_of(mb: Mob) -> String:
	if mb is Boss or mb.mkind == "warden":
		return "boss"
	return "camp" if mb.has_meta("camp") else "mob"

static func kill_xp(mb: Mob) -> float:
	if mb is Boss:
		return 0.0
	if mb.has_meta("camp"):
		var kind := "chief" if mb.has_meta("chief") else mb.mkind
		return float(rules()["camp_mob"].get(kind, rules()["stray"]))
	return float(rules()["stray"])
