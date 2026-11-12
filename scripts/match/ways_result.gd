class_name WaysResult
extends RefCounted
## What the results screen says about the way out (spec task 5, docs/decisions/0051-limited-ways-out.md).
## Result fields: `how` (HOWS) for a squad that left, `place` and `squads` for one that did not. Placement
## pay is content/rules/heart.json "place"; Game.apply_result calls settle(). Nothing here is saved but gems.

const HOWS := {
	"lair": "You rode the updraft out of the Sealed Lair.",
	"heart_early": "You left through the Heart Gate.",
	"uplink": "You rode the Uplink lift out of %s.",
	"heart_final": "You held the Heart ring and left.",
}

static func place_rules() -> Dictionary:
	return Heart.rules()["place"]

## The line under the title: how you left, or where your squad placed.
static func how_line(r: Dictionary) -> String:
	if r.get("extracted", false):
		var how := String(HOWS.get(String(r.get("how", "")), ""))
		return (how % String(r.get("where", "the islands")) if how.contains("%s") else how) + " "
	if int(r.get("place", 0)) > 0:
		return "Your squad placed %s of %d. " % [ordinal(int(r["place"])), int(r["squads"])]
	return ""

## The one plain line when hiding earned nothing.
static func hid_line(r: Dictionary) -> String:
	if r.get("extracted", false) or not r.get("hid", false) or r.get("tutorial", false):
		return ""
	return "No placement pay: your squad never levelled up."

static func ordinal(n: int) -> String:
	var tail := n % 100
	if tail < 11 or tail > 13:
		match n % 10:
			1: return "%dst" % n
			2: return "%dnd" % n
			3: return "%drd" % n
	return "%dth" % n

## Where `team` placed among the squads of `hunters` when the match ended for it: {} when one of its Hunters
## left (a squad that left has a seat, not a place), else {place, squads, hid}; `hid` is a squad no Hunter of
## which reached place "min_level" (it hid; no placement pay). A squad is over when its last
## Hunter went out (met "died_at"); one with a Hunter still in or out the door ranks above any that is over;
## over at the same moment (the islands falling) is a tie. `now` is when the player's match ended.
static func placing(hunters: Array, team: int, now: float) -> Dictionary:
	var ends := {}
	for h in hunters:
		var end := INF
		if h.out and not h.extracted:
			end = float(h.get_meta("died_at", now))
		ends[h.team] = maxf(float(ends.get(h.team, -INF)), INF if h.extracted else end)
	if hunters.any(func(h): return h.team == team and h.extracted):
		return {}
	var mine := minf(float(ends[team]), now)
	var above := 0
	for t in ends:
		if t != team and float(ends[t]) > mine:
			above += 1
	var min_level := int(place_rules()["min_level"])
	var hid := not hunters.any(func(h): return h.team == team and h.lvl >= min_level)
	return {"place": above + 1, "squads": ends.size(), "hid": hid}

## Gems for a squad that did not leave: a few for every squad that went out before it, up to a cap.
static func pay(place: int, squads: int) -> int:
	var pr := place_rules()
	return clampi((squads - place) * int(pr["gems_per_squad_below"]), 0, int(pr["gems_max"]))

## Game.apply_result: placement pay into the save and the summary.
static func settle(r: Dictionary, out: Dictionary) -> void:
	if r.get("extracted", false) or r.get("tutorial", false) or int(r.get("place", 0)) <= 0 or r.get("hid", false):
		return
	out["place_gems"] = pay(int(r["place"]), int(r["squads"]))
	Save.d["gems"] = int(Save.d["gems"]) + int(out["place_gems"])

## The seat reward's home half as one line (the egg and the materials; gems and seeds show with the rest).
static func reward_line(hb: Dictionary) -> String:
	var parts: Array = []
	if not (hb.get("egg", {}) as Dictionary).is_empty():
		parts.append("a Rare Egg")
	for g in hb.get("goods", {}):
		parts.append("%d %s" % [int(hb["goods"][g]), String(g).capitalize()])
	return "Heart reward: %s." % ", ".join(parts) if not parts.is_empty() else ""

## One Boki you left behind, in one line.
static func boki_line(news: Dictionary) -> String:
	var boki := String((news["kin"] as Dictionary)["name"])
	return "%s held by %s" % [boki, news["holder"]] if String(news["fate"]) == "rival" else "%s came home" % boki
