class_name KinHabit
extends RefCounted
## A farm Boki's body language while it stands about (home.gd calls step() every frame for each one). Now and then
## it does its own little habit: a spin, a sniff at the ground, a happy hop, sitting down, looking around or a
## wiggle, rare and staggered so it reads as character, not a dance routine. react() plays a pose on cue, even
## while the Boki is held looking at something: ComeLook's curious sniff, shy hide and proud puff. A pose only
## moves the "Body" node and puts it back when it ends, so feeding and training poses keep theirs.

const HABITS := ["spin", "sniff", "hop", "sit", "look", "wiggle"]
const POSE_S := 1.2              # s one habit or reaction lasts
const FIRST_S := [4.0, 12.0]     # s before a Boki's first habit
const GAP_S := [7.0, 16.0]       # s between habits, times its personality's rest
const CUT_S := 3.0               # s at least until the next habit after one was cut short

## Plays `pose` now: one of HABITS, "hide" (ducks and turns away) or "puff" (swells up, chest out).
static func react(k: Dictionary, pose: String) -> void:
	k["q_as"] = pose
	k["q_on"] = POSE_S

## Per frame: counts down to the next habit, plays the pose that is on, and puts the body back when it ends or is
## cut short. `moving`: the Boki is walking.
static func step(k: Dictionary, n: Node3D, moving: bool, d: float) -> void:
	var body := n.get_node_or_null("Body") as Node3D
	if body == null:
		return
	k["qt"] = float(k.get("qt", randf_range(FIRST_S[0], FIRST_S[1]))) - d
	var q := float(k.get("q_on", 0.0))
	if _cut_short(k, moving):
		if q > 0.0:
			_rest(k, body)
		k["qt"] = maxf(float(k["qt"]), CUT_S)
		return
	if q <= 0.0 and float(k["qt"]) <= 0.0:
		k["qt"] = randf_range(GAP_S[0], GAP_S[1]) * float(k.get("pers", {}).get("rest", 1.0))
		q = POSE_S
	if q <= 0.0:
		return
	q -= d
	k["q_on"] = q
	var pose := String(k.get("q_as", k.get("pers", {}).get("quirk", "look")))
	_pose(body, pose, 1.0 - clampf(q / POSE_S, 0.0, 1.0))      # 0 -> 1 over the pose
	if q <= 0.0:
		_rest(k, body)

## Walking, napping, bathing or fetching stops a pose; being held stops only a habit (a cued reaction plays on).
static func _cut_short(k: Dictionary, moving: bool) -> bool:
	if float(k.get("nap_t", 0.0)) > 0.0 or k.has("bath") or k.has("fetch"):
		return true
	if k.has("q_as"):
		return false
	return moving or float(k.get("hold_t", 0.0)) > 0.0

## `pose` at `t` (0 -> 1 over it): turns in rad, dips and lifts in m, squash and swell as shares of its size.
static func _pose(body: Node3D, pose: String, t: float) -> void:
	var e := sin(t * PI)      # in and out
	match pose:
		"spin":
			body.rotation.y = t * TAU
		"sniff":
			body.rotation.x = e * 0.35
			body.position.y = -e * 0.04
		"hop":
			body.position.y = absf(sin(t * TAU * 1.5)) * 0.22
		"sit":
			body.scale = Vector3(1.0 + e * 0.12, 1.0 - e * 0.16, 1.0 + e * 0.12)
		"look":
			body.rotation.y = sin(t * TAU) * 0.7
		"wiggle":
			body.rotation.z = sin(t * TAU * 3.0) * 0.18 * e
		"hide":
			body.rotation.y = e * 2.4
			body.scale = Vector3(1.0 + e * 0.1, 1.0 - e * 0.3, 1.0 + e * 0.1)
		"puff":
			body.rotation.x = -e * 0.15
			body.scale = Vector3.ONE * (1.0 + e * 0.22)

## The pose is over: the body stands as it was and the next habit is its own again.
static func _rest(k: Dictionary, body: Node3D) -> void:
	k["q_on"] = 0.0
	k.erase("q_as")
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
