class_name StealReel
extends RefCounted
## What a prize monster does at the steal window's line (content/rules/steal_window.json "prize" and "reel",
## docs/CAMPS.md; the look is StealTell): at or under `at` of its health it cries out once, and the first drop
## under the line reels it for `reel` seconds (no attacks, normal damage), the fighting squad's planned burst.
## Nothing is synced beyond what a monster's snapshot carries (health, stagger timer): each machine sounds the
## cry off the health it sees, and the machine that owns the monster starts the reel.

const CRY_VOL := 0.0  # dB
const CRY_PITCH := 0.7

static var _rules := {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/steal_window.json"))
	return _rules


static func is_prize(mb: Mob) -> bool:
	return mb.mkind in rules()["prize"]


## True while `mb` is a prize monster at or under the window's health.
static func open(mb: Mob) -> bool:
	return not mb.dead and mb.hp <= mb.max_hp * StealTell.at() and is_prize(mb)


static func reel_time() -> float:
	return float(rules()["reel"])


## Every frame, on every machine: the cry the first time the window opens here. Both flags rearm once the
## monster is back above the line (a lair boss that reset).
static func tick(mb: Mob) -> void:
	if open(mb):
		if not mb.win_cried:
			mb.win_cried = true
			if "v_" + mb.mkind in Sfx.VOICES:  # a lair boss has no voice file
				mb.m.sfx("v_" + mb.mkind, mb.pos, CRY_VOL, CRY_PITCH)
	elif not mb.dead:
		mb.win_cried = false
		if mb.hp > mb.max_hp * StealTell.at():
			mb.win_reeled = false


## After a hit on the machine that owns `mb`: the first drop into the window reels it.
static func on_hurt(mb: Mob) -> void:
	if mb.win_reeled or mb.remote or not open(mb):
		return
	mb.win_reeled = true
	mb.reel()
