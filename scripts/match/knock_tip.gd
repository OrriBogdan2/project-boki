class_name KnockTip
extends RefCounted
## A new player's first knock, explained (content/rules/knock_tip.json): the first time they go down in each
## of their first two real Extractions, one two-line card: what hurt them most, and one tip for it.
## The save's tutorial "knock_tip" counts the cards shown; at the rule's `showings` it stops for good.
## Match owns one as `ktip` (null when this match gets none) and calls note() per hit and on_knock().

const SAVE_KEY := "knock_tip"

var m: Match
var shown := false            # this match has had its card
var _taken := {}              # source -> damage the player took lately
var _last_t := -1000.0        # match time of the last hit on the player

static func rules() -> Dictionary:
	return Content.rules("knock_tip")

## The card for a match inside the first-match guide (a save's first two Extractions) while the save has
## showings left, else null.
static func for_match(mt: Match, guide: FirstMatchGuide) -> KnockTip:
	if guide == null or _count() >= int(rules()["showings"]):
		return null
	var k := KnockTip.new()
	k.m = mt
	return k

static func _count() -> int:
	return int((Save.d["tutorial"] as Dictionary).get(SAVE_KEY, 0))

## Which rules "sources" row a hit on the player counts under.
func source_of(by: Ent, o: Dictionary) -> String:
	var attacker: Ent = by
	if by is Kin and (by as Kin).owner_h:
		attacker = (by as Kin).owner_h
	if by is Blight or String(o.get("src", "")) == "wall":
		return "blight"
	if attacker is Hunter:
		return "far" if attacker.flat_dist(m.player) > float(rules()["far_m"]) else "rival"
	if by is Mob or by is Boss or by is Kin or by is Shrubling:
		return "monster"
	return "other"

## A hit on the player: tallied by source; a long quiet since the last hit starts the count over.
func note(by: Ent, d: float, o: Dictionary) -> void:
	if m.time - _last_t > float(rules()["gap"]):
		_taken.clear()
	_last_t = m.time
	var key := source_of(by, o)
	_taken[key] = float(_taken.get(key, 0.0)) + d

## The most damage taken lately: a "sources" key.
func top() -> String:
	var best := "other"
	var most := -1.0
	for key: String in _taken:
		if float(_taken[key]) > most:
			most = float(_taken[key])
			best = key
	return best

## The two-line card text for a source.
static func card(key: String) -> String:
	var row: Array = rules()["sources"][key]
	var tip: String = row[1]
	for act in ["dash", "throw", "glide"]:
		tip = tip.replace("{%s}" % act, Settings.key_cap(act))
	return "That was mostly %s.\n%s" % [row[0], tip]

## The player went down: the card, once per match and twice per save, unless tips are off.
func on_knock() -> void:
	if shown or m.hud == null or not Settings.get_v("tips") or Record.clean():
		return
	shown = true
	(Save.d["tutorial"] as Dictionary)[SAVE_KEY] = _count() + 1
	m.hud.tip(card(top()))
