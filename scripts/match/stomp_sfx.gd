class_name StompSfx
extends RefCounted
## What a stomp sounds like (docs/AUDIO.md "Stomp sounds"): a commit at the hold, a strike per beat
## weighted by the stomper's weight class and louder each beat, the pinned wisp's own hum straining, a
## crush when the last slam kills it and a bright crack when crowd control breaks it. Numbers in
## content/rules/stomps.json "sound". Stomp calls these from start, the beats and end, which run in
## every game (the stomper's own, the others through the "stomp" event), so everyone in range hears
## them at the spot, the wisp included.

static func _spec(key: String) -> Dictionary:
	return (StompLook.rules()["sound"] as Dictionary)[key]

static func _cue(m: Match, key: String, at: Vector3) -> void:
	var s := _spec(key)
	m.sfx(String(s["sfx"]), at, float(s["db"]))

static func commit(m: Match, h: Hunter) -> void:
	_cue(m, "commit", h.pos)

## Slam i of the stomp (0-based), louder than the one before: light Hunters a higher, lighter strike;
## medium and heavy ones a lower one with the shared body sound under it.
static func strike(m: Match, h: Hunter, i: int) -> void:
	var s := _spec("strike")
	var w: Dictionary = s.get(Arch.weight(h.arch), s["medium"])
	var ramp: Array = s["ramp_db"]
	var louder := float(ramp[clampi(i, 0, ramp.size() - 1)])
	var pitch := float(w["pitch"])
	m.sfx(String(s["sfx"]), h.pos, float(w["db"]) + louder, pitch)
	if w.has("body_db"):
		m.sfx(String(s["body"]), h.pos, float(w["body_db"]) + louder, pitch)

static func crush(m: Match, o: Hunter) -> void:
	_cue(m, "crush", o.pos)

## The stomp on o broke: the saved wisp and its squad hear it as their own cue wherever they are, the
## rest at the stomper's spot.
static func crack(m: Match, h: Hunter, o: Hunter) -> void:
	var saved := is_instance_valid(o) and m.player != null and o.team == m.player.team
	var s := _spec("crack")
	m.sfx(String(s["sfx"]), null if saved else h.pos, float(s["db"]))

## The pinned wisp's hum: Vector2(extra dB, pitch), rising and trembling over the stomp; (0, 1) when
## nobody is stomping it. HunterWisp holds the hum with it.
static func strain(o: Hunter) -> Vector2:
	if not o.has_meta("stomped_by"):
		return Vector2(0.0, 1.0)
	var by = o.get_meta("stomped_by")
	if not is_instance_valid(by) or (by as Hunter).stomp.is_empty():
		return Vector2(0.0, 1.0)
	var s := _spec("strain")
	var t := float((by as Hunter).stomp["t"])
	var rise: Array = s["pitch"]
	var pitch := lerpf(float(rise[0]), float(rise[1]), clampf(t / Stomp.TIME, 0.0, 1.0))
	pitch += float(s["wobble"]) * sin(t * TAU * float(s["wobble_hz"]))
	return Vector2(float(s["db"]), pitch)
