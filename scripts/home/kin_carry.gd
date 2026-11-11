class_name KinCarry
extends RefCounted
## Lifting a Boki at home: walk up, press interact to pick it up, carry it about, press interact again
## to set it down on open ground. It answers by its nature: a loyal or easy-going one nuzzles, a curious
## or bold one wiggles, a hot-tempered one it doesn't trust yet sulks. Being held is gentle, so a nuzzle
## or a wiggle nudges its trust up a little, once per COOLDOWN, so lifting it over and over can't farm
## trust. Nothing else in the save changes.
## The one state is `state`; every change goes through _go and the NEXT table.

enum S { FREE, LIFT, CARRIED, SET }
## (a Boki that vanishes mid-carry goes straight back to FREE)
const NEXT := {S.FREE: [S.LIFT], S.LIFT: [S.CARRIED, S.FREE], S.CARRIED: [S.SET, S.FREE], S.SET: [S.FREE]}
const LIFT_T := HunterAnim.CARRY_BEAT   # s: scooping it up
const SET_T := HunterAnim.CARRY_BEAT    # s: putting it down
const HOLD_FWD := 0.55         # m in front of you, where it rides (at the chest)
const HOLD_UP := 0.6           # m above your feet
const SET_FWD := 1.0           # m in front of you, where it is set down first (else the nearest open ground)
const COOLDOWN := 30.0         # s before the same Boki's trust moves again
const TRUST_STEP := 0.6        # trust points (0..100) for a gentle one
const HOT := 0.62              # temper above this sulks; loyalty, bravery or curiosity above it is warm
const FACES := {"nuzzle": "bliss", "wiggle": "happy", "sulk": "sad"}
const GLYPHS := {"nuzzle": "♥", "wiggle": "★", "sulk": "…"}
const WIGGLE_T := 0.9          # s of happy bouncing after a wiggle or a nuzzle
const SULK_T := 1.8            # s it stands apart, looking away, after a sulk

var state := S.FREE
var since := 0.0               # s in this state
var refused := 0               # changes the table turned down (a check wants 0)
var kin: Dictionary = {}       # home's entry for the Boki in hand
var mood := ""
var _clock := 0.0              # s since the home loaded: the cooldown runs on it
var _from := Vector3.ZERO      # where the Boki was when the lift or the set-down began
var _spot := Vector3.ZERO      # where the set-down puts it

## How this Boki takes being picked up: "nuzzle", "wiggle" or "sulk".
static func mood_of(rec: Dictionary) -> String:
	var tr: Dictionary = rec["traits"]
	var loyal := float(tr.get("loyalty", 0.5))
	var trust := float(rec.get("trust", 0.0))
	if float(tr.get("temper", 0.5)) > HOT and loyal <= HOT and trust < 70.0:
		return "sulk"
	if loyal > HOT or trust >= 70.0:
		return "nuzzle"
	return "wiggle"

func holds(k: Dictionary) -> bool:
	return state != S.FREE and k == kin

## The HunterAnim "act" for your body: "" when you aren't holding one.
func pose() -> String:
	return ["", "lift", "carry", "set"][state]

func can_lift(k: Dictionary) -> bool:
	if state != S.FREE or k.get("busy", false):
		return false
	for key in ["indoors", "fetch", "bath", "job", "leap"]:
		if k.has(key):
			return false
	return true

func lift(home: Node, k: Dictionary) -> bool:
	if not can_lift(k):
		return false
	kin = k
	k["busy"] = true
	for stale in ["goal", "chase", "task", "going_in", "nap_go", "called_t"]:
		k.erase(stale)
	k["nap_t"] = 0.0
	_from = k["pos"]
	mood = mood_of(k["rec"])
	if mood != "sulk" and _clock >= float(k.get("carry_ok", 0.0)):
		k["carry_ok"] = _clock + COOLDOWN
		k["rec"]["trust"] = minf(100.0, float(k["rec"].get("trust", 0.0)) + TRUST_STEP)
	var node := k["node"] as Node3D
	node.set_meta("kstate", "carried")
	node.set_meta("face", FACES[mood])
	Sfx.play("kin_happy" if mood != "sulk" else "click", null, -6.0, 0.12, Unique.voice(k["rec"]))
	_go(S.LIFT)
	return true

## Puts it down on open ground in front of you, or beside you when that is blocked.
func set_down(home: Node) -> bool:
	if state != S.CARRIED:
		return false
	var fwd := Vector3(-sin(home.pface), 0.0, -cos(home.pface))
	_spot = home.world.free_spot_near(home.ppos + fwd * SET_FWD, [], 0.0, 0.3)
	if home.world.island_of(_spot.x, _spot.z) != home.world.island_of(home.ppos.x, home.ppos.z):
		_spot = home.world.free_spot_near(home.ppos, [], 0.0, 0.3)
	_from = _hold_point(home)
	kin["pos"] = _spot
	_go(S.SET)
	return true

func step(home: Node, dt: float) -> void:
	_clock += dt
	since += dt
	if state == S.FREE:
		return
	var node := kin["node"] as Node3D
	if not is_instance_valid(node):
		kin = {}
		_go(S.FREE)
		return
	match state:
		S.LIFT:
			var u := smoothstep(0.0, 1.0, since / LIFT_T)
			node.position = _from.lerp(_hold_point(home), u)
			if since >= LIFT_T:
				_go(S.CARRIED)
		S.CARRIED:
			node.position = _hold_point(home)
			node.rotation.y = lerp_angle(node.rotation.y, home.pface, minf(1.0, dt * 10.0))
			kin["pos"] = home.ppos
		S.SET:
			var u := smoothstep(0.0, 1.0, since / SET_T)
			node.position = _from.lerp(_spot, u)
			if since >= SET_T:
				_release(home)

func _hold_point(home: Node) -> Vector3:
	var fwd := Vector3(-sin(home.pface), 0.0, -cos(home.pface))
	return Vector3(home.ppos.x, home.py + HOLD_UP, home.ppos.z) + fwd * HOLD_FWD

## It is on the ground again: it answers, then goes back to its day.
func _release(home: Node) -> void:
	var node := kin["node"] as Node3D
	node.set_meta("kstate", "")
	node.remove_meta("face")
	node.position = kin["pos"]
	kin["busy"] = false
	kin["vel"] = Vector3.ZERO
	kin["goal"] = kin["pos"]
	kin["hold_t"] = SULK_T if mood == "sulk" else WIGGLE_T
	kin["joy_t"] = 0.0 if mood == "sulk" else WIGGLE_T
	home._emote(kin, GLYPHS[mood], true)
	kin = {}
	_go(S.FREE)

func _go(to: S) -> void:
	if not NEXT[state].has(to):
		refused += 1
		return
	state = to
	since = 0.0
