class_name GardenXp
extends RefCounted
## Garden XP (GARDEN_MODERN 2.5): until now only expeditions gave XP, so a Boki raised at home stayed level 1 and
## could never be Grown for the Nesting Nook. A garden minigame pays everyone that played, a win more, the first
## win of the day in a game most; the first care of a kind in a day pays a little. Every grant is one journal
## line, so the cause shows on the Boki card. Numbers: content/rules/garden_xp.json. Only with base_mode on.

static func rules() -> Dictionary:
	return Content.rules("garden_xp")

## Gives `n` XP with the reason as one journal line ("won the Dash: +45 XP"); returns n (0 outside the base).
static func grant(rec: Dictionary, n: int, why: String) -> int:
	if n <= 0 or rec.is_empty() or Save.kin(String(rec.get("uid", ""))).is_empty() or not FarmUnlocks.base_mode():
		return 0
	var gained := Game.add_xp(rec, n, {})
	CareJournal.note(rec, "%s: +%d XP" % [why, n])
	if gained > 0:
		CareJournal.note(rec, "reached level %d" % int(rec["level"]))
	return n

## One finished garden game: the backed Boki `mine` against `foe`. Returns the XP `mine` got.
static func played(game_name: String, mine: Dictionary, foe: Dictionary, won: bool, first_win: bool) -> int:
	var R := rules()
	var nm := "the " + game_name.trim_prefix("The ")
	var winner_xp := int(R["first_win"] if first_win else R["win"])
	if won:
		grant(foe, int(R["play"]), "lost " + nm)
		return grant(mine, winner_xp, "won " + nm)
	grant(foe, int(R["win"]), "won " + nm)
	return grant(mine, int(R["play"]), "lost " + nm)

## The first care of this kind today (Care.care_day says so): a few XP, for care_kinds kinds a day.
static func care(rec: Dictionary, kind: String) -> void:
	var now := Time.get_unix_time_from_system()
	var day_s := float(Content.rules("care")["care_day_s"])
	var days: Dictionary = rec.get("care_day", {})
	var today := days.values().filter(func(at): return now - float(at) < day_s).size()
	if today <= int(rules()["care_kinds"]):
		grant(rec, int(rules()["care_first"]), "first care today (%s)" % kind)
