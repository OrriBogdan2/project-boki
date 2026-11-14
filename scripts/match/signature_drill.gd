class_name SignatureDrill
extends RefCounted
## The last step of the kit drill (KitDrill): each Hunter's one tech that separates good play from basic play
## (content/rules/signature_drills.json: the line with live key caps, the dummy rig, the source tags; the list is
## in docs/TRAINING_DRILLS.md). The step is done by the kit's own CombatBus.tech event, never a timer.

## A dummy carrying this meta is left alone by Arena.tick (no heal, no revive) while the drill uses it.
const META := "drill_rig"
const ACTIONS := ["fire", "secondary", "signature", "hunter_ult", "dash"]

static func def(hunter_id: String) -> Dictionary:
	return Content.rules("signature_drills")["drills"].get(hunter_id, {})

## The step KitDrill appends after the five slots (empty when the Hunter has no tech).
static func step(hunter_id: String) -> Dictionary:
	var d := def(hunter_id)
	if d.is_empty():
		return {}
	var text := String(d["line"])
	for action in ACTIONS:
		text = text.replace("{%s}" % action, "[%s]" % Settings.key_cap(action))
	return {"slot": "tech", "action": "", "key": "TECH", "line": text, "how": "tech",
			"tech": d["tech"], "id": hunter_id}

## Sets the dummy up for the tech (the first dummy); the drill calls it on entering the step and every rearm_s.
static func rig(m: Match, hunter_id: String) -> void:
	if m.arena == null or m.arena.dummies.is_empty():
		return
	var c: Dictionary = Content.rules("signature_drills")
	var dummy: Hunter = m.arena.dummies[0]["h"]
	match String(def(hunter_id).get("rig", "")):
		"low":
			dummy.set_meta(META, true)
			if not dummy.downed:
				dummy.hp = minf(dummy.hp, float(c["low_hp"]))
		"static":
			var kit := m.player.ak as MageKit
			if kit != null and kit.spark_n(dummy) < int(c["static_n"]):
				kit.add_spark(dummy, int(c["static_n"]) - kit.spark_n(dummy))
		"splash":
			var gil := m.player.ak as GilKit
			if gil != null and gil.marks_on(dummy) < 1:
				gil.add_mark(dummy)
		"back":
			var away := dummy.pos - m.player.pos
			dummy.face = atan2(-away.x, -away.z)

## Gives the dummy back to the Arena (it heals and gets up on its next tick).
static func unrig(m: Match) -> void:
	if m.arena != null and not m.arena.dummies.is_empty():
		(m.arena.dummies[0]["h"] as Hunter).remove_meta(META)
