class_name HunterFoley
extends RefCounted
## Each Hunter's own foley under its steps and dashes (docs/AUDIO.md): a quiet layer of what it wears or carries
## (a chain, skates, wings, coins), one row per Hunter in content/rules/hunter_foley.json. A step's foley follows
## the Hunter's speed and carries as far as the step (StepReach); at most `voice_cap` start per `voice_window_ms`
## across everyone, so a crowd of 30 stays readable.

static var _started_ms: Array[int] = []      # when the latest foley sounds started (the voice cap's window)


static func rules() -> Dictionary:
	return Content.rules("hunter_foley")


## The row for archetype `arch` (empty if it has none).
static func row(arch: String) -> Dictionary:
	return (rules()["rows"] as Dictionary).get(arch, {})


## A footstep's foley: quieter at a standstill (walk_db), full at the Hunter's base run speed.
static func step(h: Hunter) -> void:
	var speed_k := clampf(Vector2(h.vel.x, h.vel.z).length() / maxf(h.base_speed, 0.1), 0.0, 1.0)
	var db := _level(h, "step_db", float(rules()["walk_db"]) * (1.0 - speed_k))
	if _cue(h, "foley") != "" and _room():
		StepReach.play(h, _cue(h, "foley"), db, db)


## A dash's foley: the Hunter's gear whipping along.
static func dash(h: Hunter) -> void:
	var cue := _cue(h, "foley_dash")
	if cue != "" and h.m != null and _room():
		h.m.sfx(cue, h.pos, _level(h, "dash_db", 0.0))


static func _cue(h: Hunter, kind: String) -> String:
	if row(h.arch).is_empty():
		return ""
	return HeroSfx.of(h, kind, "")


static func _level(h: Hunter, row_key: String, trim_db: float) -> float:
	return float(rules()["base_db"]) + float(row(h.arch).get(row_key, 0.0)) + trim_db


## Whether another foley sound may start now (the voice cap); counts it when it may.
static func _room() -> bool:
	var now := Time.get_ticks_msec()
	while not _started_ms.is_empty() and now - _started_ms[0] > int(rules()["voice_window_ms"]):
		_started_ms.pop_front()
	if _started_ms.size() >= int(rules()["voice_cap"]):
		return false
	_started_ms.append(now)
	return true
