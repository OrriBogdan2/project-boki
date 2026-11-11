class_name BokiWade
extends RefCounted
## Boki wading (briefs/design/GARDEN.md section 4, content/rules/wade.json): a Boki in pond or stream water
## sinks into it, walks slower, splashes going in, leaves ripples round it and a V wake while it moves (BokiWake)
## and shakes off coming out. With base_mode on, Water, Ice and Crystal Boki paddle (a free roaming one lingers in
## the water playing the splash clip, and gains joy), Fire Boki hurry out to the nearest dry ground, and everyone
## else wades through.
## k["wade"] = {in, stay, out, shake_t}. home.gd calls speed() for the walk and step() after each move.
## Missing clips (anim lane): "wade" (a slow knee-high walk loop) and "shake" (a shake-off); until then the walk
## simply slows and the shake is a quick wobble of the Body node.

const SINK := {1: 0.12, 2: 0.3}   # m a Boki sits below the ground in shallow and deep water
const OUT_RINGS := 8              # directions tried round a Fire Boki when it looks for dry ground
const WOBBLE := 0.3               # rad of side-to-side shake at its fullest

var h
var marks: BokiWake        # the ripples and wakes of every Boki in the water (made when the first steps in)

func _init(home) -> void:
	h = home

static func rules() -> Dictionary:
	return Content.rules("wade")

## "paddle", "fire" or "wade": how this Boki takes to water (its lean or species theme).
func kind(rec: Dictionary) -> String:
	var key: String = HomeToys.lean_of(rec)
	if (rules()["paddle"] as Array).has(key):
		return "paddle"
	return "fire" if (rules()["fire"] as Array).has(key) else "wade"

## Walk-speed multiplier at `pos`: 1 on dry ground, slower in water, faster for a Fire Boki leaving it.
func speed(k: Dictionary, pos: Vector3) -> float:
	var dep: int = h.water.depth(pos.x, pos.z)
	if dep == 0 or not FarmUnlocks.base_mode():
		return 1.0
	var R := rules()
	if kind(k["rec"]) == "fire":
		return float(R["out_speed"])
	return float(R["wade_speed"] if dep == 1 else R["deep_speed"])

## One Boki in (or leaving) the water this frame: the sink, its marks, the splash, the shake, and what its kind does.
func step(k: Dictionary, pos: Vector3, n: Node3D, d: float) -> void:
	var w: Dictionary = k.get("wade", {"in": false, "stay": 0.0, "out": false, "shake_t": 0.0})
	k["wade"] = w
	var dep: int = h.water.depth(pos.x, pos.z)
	if dep > 0:
		n.position.y -= float(SINK[dep]) - sin(float(k["hop"]) * 0.7) * 0.03
		if not w["in"]:
			_enter(k, w, pos)
		_mark(k, pos, n)
		_play(k, w, pos, d)
	elif w["in"]:
		_leave(k, w, pos)
	_shake(w, n, d)

func _enter(k: Dictionary, w: Dictionary, pos: Vector3) -> void:
	w["in"] = true
	Sfx.play("splash", pos, -18.0, 0.1, 1.4)
	if not FarmUnlocks.base_mode():
		return
	var R := rules()
	var how := kind(k["rec"])
	if how == "fire":
		_step_out(k, w, pos)
	elif how == "paddle" and _free(k) and randf() < float(R["linger_chance"]):
		var secs := randf_range(float((R["linger_secs"] as Array)[0]), float((R["linger_secs"] as Array)[1]))
		w["stay"] = secs
		k["t"] = maxf(float(k.get("t", 0.0)), secs)
		h._emote(k, "♪", true)

func _leave(k: Dictionary, w: Dictionary, pos: Vector3) -> void:
	w["in"] = false
	w["stay"] = 0.0
	w["out"] = false
	if (k["node"] as Node3D).has_meta("kact_wade"):
		(k["node"] as Node3D).remove_meta("kact_wade")
		(k["node"] as Node3D).set_meta("kact", "")
	if FarmUnlocks.base_mode():
		w["shake_t"] = float(rules()["shake_secs"])
		Sfx.play("drip", pos, -10.0)
		h.fx.burst(pos + Vector3(0, 0.5, 0), Color("cfeaff"), 8, 1.8, 0.4)

## Its ripple ring, and a V wake while it moves, sized by its body. Nothing on Very Low.
func _mark(k: Dictionary, pos: Vector3, n: Node3D) -> void:
	if marks == null:
		if Settings.quality() == "very_low":
			return
		marks = BokiWake.new(float(rules()["ripple_secs"]))
		h.add_child(marks)
		if h.hb:
			marks.clip_to(h.hb.L()["water"])
	marks.mark(String(k["rec"]["uid"]), pos, k["vel"], n.scale.x)

## A lingering paddler stays put playing, gaining joy, until its time is up or something else claims it.
func _play(k: Dictionary, w: Dictionary, pos: Vector3, d: float) -> void:
	if float(w["stay"]) <= 0.0:
		return
	var n := k["node"] as Node3D
	if not _free(k):
		w["stay"] = 0.0
	else:
		w["stay"] = float(w["stay"]) - d
		k["goal"] = pos
		Care.change(k["rec"], "joy", float(rules()["joy_per_sec"]) * d)
		n.set_meta("kact", "splash")
		n.set_meta("kact_wade", true)
		k["joy_t"] = 0.3
	if float(w["stay"]) <= 0.0 and n.has_meta("kact_wade"):
		n.remove_meta("kact_wade")
		n.set_meta("kact", "")

## A short wobble of the body, shaking the water off.
func _shake(w: Dictionary, n: Node3D, d: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	if body == null:
		return
	if float(w["shake_t"]) > 0.0:
		w["shake_t"] = float(w["shake_t"]) - d
		body.rotation.z = sin(float(w["shake_t"]) * 50.0) * WOBBLE * clampf(float(w["shake_t"]) * 3.0, 0.0, 1.0)
	elif body.rotation.z != 0.0:
		body.rotation.z = 0.0

## A Fire Boki sets off for the nearest dry ground it can stand on.
func _step_out(k: Dictionary, w: Dictionary, pos: Vector3) -> void:
	var reach := float(rules()["out_reach"])
	var r := 1.0
	while r <= reach:
		for i in OUT_RINGS:
			var a := TAU * float(i) / float(OUT_RINGS)
			var spot := pos + Vector3(cos(a), 0, sin(a)) * r
			if h.water.depth(spot.x, spot.z) == 0 and h.world.occupy(spot.x, spot.z, 0.3, 0.0, true) == 0.0 \
					and not h.world.is_void(spot.x, spot.z):
				w["out"] = true
				k["goal"] = spot
				k["t"] = maxf(float(k.get("t", 0.0)), 3.0)
				return
		r += 1.0

## Free to stay and play: nothing else (a job, a toy, a meal, a call, a nap, a pet) has the Boki.
func _free(k: Dictionary) -> bool:
	for key in ["job", "fetch", "chase", "going_in", "bath", "eat", "play", "called_t"]:
		if k.has(key):
			return false
	if k.get("busy", false) or float(k.get("nap_t", 0.0)) > 0.0 or float(k.get("hold_t", 0.0)) > 0.0:
		return false
	return h.life == null or (h.life.machine(k) as Fsm).is_in(BaseLife.S.ROAM)
