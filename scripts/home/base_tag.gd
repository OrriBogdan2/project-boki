class_name BaseTag
extends RefCounted
## Tag (GARDEN.md section 4), the PlayWith state of base life: two Boki whose bond is at the friend line chase
## each other in turns for 10-20 s. Whoever is "it" runs at the other; a touch swaps it, and the new "it" gets a
## moment's grace so the pair doesn't trade it every tick. Each touch builds the pair's bond. A finished game
## trains Speed a little (Care.add_stat) and writes one journal line. A rival of either that wanders close turns
## it into a short squabble: both players huff and sulk, and the game ends. A rival never plays: BaseLife picks
## mates from friends only. Uses existing clips only. Tuning: base_life.json "tag".

const CATCH := 1.1      # m: a tag lands this close (Boki keep about 0.8 m of personal space, so a touch is 1 m or so)

static func rules() -> Dictionary:
	return Content.rules("base_life")["tag"]

## A player leaves the game: its marks go.
static func clear(k: Dictionary) -> void:
	for key in ["life_it", "life_safe", "life_from"]:
		k.erase(key)

## Both Boki go into PlayWith for one game; `k` starts as "it".
static func start(life: BaseLife, k: Dictionary, o: Dictionary) -> void:
	var m := life.machine(k)
	var om := life.machine(o)
	if not m.can(BaseLife.S.PLAY_WITH) or not om.can(BaseLife.S.PLAY_WITH):
		return
	m.go(BaseLife.S.PLAY_WITH, "tag")
	om.go(BaseLife.S.PLAY_WITH, "tagged")
	var secs := randf_range(life.R["play_with"][0], life.R["play_with"][1])
	for pair in [[k, o], [o, k]]:
		pair[0]["life_at"] = pair[1]
		pair[0]["life_for"] = secs
		pair[0]["t"] = secs
	k["life_it"] = true
	life.h._emote(k, "★")

## One tick of a player in PlayWith (BaseLife._tick).
static func tick(life: BaseLife, k: Dictionary, m: Fsm) -> void:
	var o: Dictionary = k["life_at"]
	var om: Fsm = o.get("life", null)
	if om == null or not om.is_in(BaseLife.S.PLAY_WITH) or BaseLife._taken(o):
		m.go(BaseLife.S.ROAM, "tag over")
		return
	if m.since >= float(k["life_for"]):
		_finish(life, k, o)
		return
	var rival := _rival_in(life, k, o)
	if not rival.is_empty():
		_squabble(life, k, o, rival)
		return
	if not k.get("life_it", false):
		_run(life, k, m, o)
		return
	k["goal"] = o["pos"]
	if BaseLife._dist(k, o) < CATCH and m.since >= float(k.get("life_safe", 0.0)):
		BaseLife.add_bond(k["rec"], o["rec"], float(life.R["bond_tag"]))
		life.h._emote(k, "♪")
		k.erase("life_it")
		k["life_from"] = m.since
		o["life_it"] = true
		o["life_safe"] = om.since + float(rules()["grace"])
		o["goal"] = o["pos"]

## The runner flees for flee_s, then stops to catch its breath for stand_s (equal speeds never meet otherwise).
static func _run(life: BaseLife, k: Dictionary, m: Fsm, o: Dictionary) -> void:
	var R := rules()
	var phase := fmod(m.since - float(k.get("life_from", 0.0)), float(R["flee_s"]) + float(R["stand_s"]))
	var away: Vector3 = k["pos"] + Vector3(k["pos"].x - o["pos"].x, 0, k["pos"].z - o["pos"].z).normalized() * 3.0
	if phase < float(R["flee_s"]) and not life.h.world.is_void(away.x, away.z):
		k["goal"] = away
	else:
		k["goal"] = k["pos"]

## Time is up: both gain a little Speed and a journal line, and go back to roaming for a breather.
static func _finish(life: BaseLife, k: Dictionary, o: Dictionary) -> void:
	for pair in [[k, o], [o, k]]:
		var rec: Dictionary = pair[0]["rec"]
		Care.add_stat(rec, "speed", int(rules()["speed"]))
		var words := "played tag with %s" % pair[1]["rec"]["name"]
		var lines: Array = rec.get("journal", [])
		if lines.is_empty() or CareJournal.text(lines.back()) != words:
			CareJournal.note(rec, words)
		life.machine(pair[0]).go(BaseLife.S.ROAM, "tag over")
		pair[0]["t"] = float(rules()["rest"])      # a breather before it picks again, so games don't run on

## A Boki near either player that one of them is a rival of, or {}.
static func _rival_in(life: BaseLife, k: Dictionary, o: Dictionary) -> Dictionary:
	var gap := float(rules()["rival_gap"])
	for r in life.h.kins:
		if r == k or r == o or BaseLife._taken(r):
			continue
		if BaseLife._dist(r, k) > gap and BaseLife._dist(r, o) > gap:
			continue
		if BaseRival.is_rival(k["rec"], r["rec"]) or BaseRival.is_rival(o["rec"], r["rec"]):
			return r
	return {}

## The rival bursts in: everyone huffs, the players sulk (joy dips, they stand about a moment), the game is over.
static func _squabble(life: BaseLife, k: Dictionary, o: Dictionary, rival: Dictionary) -> void:
	for p in [k, o]:
		life._squabble(p, rival)
		Care.change(p["rec"], "joy", -float(rules()["sulk_joy"]))
		life.machine(p).go(BaseLife.S.ROAM, "squabble")
		p["t"] = float(rules()["sulk_s"])
		p["goal"] = p["pos"]
