class_name TipPick
extends RefCounted
## Picks the tip for the loading screen and the downed screen from content/rules/tips.json: the most
## relevant tip you haven't seen yet (what the last expedition's counts say you missed), else a random
## unseen one. Seen tips are kept in Save.d["tutorial"]["tips_seen"]; once all are seen the list restarts.

static var _rules: Dictionary = {}
## Triggers raised by the last finished expedition (note_run); the loading screen reads them.
static var last: Array = []
static var _down_key := ""
static var _down_tip := ""

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/tips.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## The triggers a run's counts raise, most pressing first. stats and used are the local Hunter's
## (stats, used), why is how it ended ("abyss"), time is seconds played. The habit triggers
## (never summoned, never used E, rarely glided) wait for min_time_s so a short run doesn't blame you.
static func triggers(stats: Dictionary, used: Dictionary, why: String, time: float) -> Array:
	var out: Array = []
	if why == "abyss":
		out.append("abyss")
	if int(stats.get("blight_downs", 0)) + int(stats.get("blight_out", 0)) > 0:
		out.append("blight")
	if int(stats.get("wisp_stolen", 0)) > 0:
		out.append("wisp_stolen")
	if time >= float(rules()["min_time_s"]):
		if int(stats.get("summons", 0)) == 0:
			out.append("no_summon")
		if int(used.get("k1", 0)) == 0:
			out.append("no_e")
		if float(stats.get("glide_t", 0.0)) < float(rules()["few_glide_s"]):
			out.append("few_glide")
	return out

## Remembers what a finished expedition (Game.apply_result's r) says you missed. The tutorial run
## says nothing: it already teaches all of it.
static func note_run(r: Dictionary) -> void:
	if r.get("tutorial", false):
		return
	last = triggers(r.get("stats", {}), r.get("used", {}), String(r.get("why", "")), float(r.get("time", 0.0)))

## The tip for the loading screen. blight: false drops the tips that talk about the Blight.
static func for_loading(blight: bool) -> String:
	return pick(last, blight)

## The tip under "You're down", chosen once per knock (the HUD asks every frame).
static func for_downed(p: Hunter, time: float, blight: bool) -> String:
	var key := "%d:%d" % [p.get_instance_id(), p.downs]
	if key != _down_key:
		_down_key = key
		_down_tip = pick(triggers(p.stats, p.used, "", time), blight)
	return _down_tip

## The most relevant unseen tip for these triggers, else a random unseen one; marks it seen.
static func pick(trig: Array, blight := true) -> String:
	var seen: Array = Save.d["tutorial"].get("tips_seen", [])
	var pool: Array = (rules()["tips"] as Array).filter(
		func(t): return blight or not String(t["text"]).contains("Blight"))
	var fresh := pool.filter(func(t): return not seen.has(t["id"]))
	if fresh.is_empty():
		seen = []
		fresh = pool
	var chosen: Dictionary = fresh[randi() % fresh.size()]
	for tr in trig:
		var hit := fresh.filter(func(t): return t.get("when", "") == tr)
		if not hit.is_empty():
			chosen = hit[0]
			break
	seen.append(chosen["id"])
	Save.d["tutorial"]["tips_seen"] = seen
	return render(String(chosen["text"]))

## A tip's text with each {action} turned into that action's key.
static func render(s: String) -> String:
	var keys := {}
	for m in RegEx.create_from_string("\\{(\\w+)\\}").search_all(s):
		keys[m.get_string(1)] = Settings.key_cap(m.get_string(1))
	return s.format(keys)
