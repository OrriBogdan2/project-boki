class_name WardenBreak
extends RefCounted
## A Hunter who has stood still a while breaks the idle once: one short beat of their own, then back to the idle
## (content/rules/idle_breaks.json, from the personality lines in docs/art/IDLE_AUDIT.md). Bone rotations laid over the
## clips or the rig, after they posed the body. Only for a hunter whose state says "idle_break" (the player's, in a
## match, the Training Area or at home). Any key, button or move, a hit, a shot or an ability cancels it at once.

const RULES := "idle_breaks"
const WAIT := 6.0            # s of calm standing before a break
const GAP := 6.0             # s of calm added after a break before the next one
const COMBAT_FREE := 6.0     # s since the last shot, ability or hit
const STILL := 0.25          # m/s: below this he is standing
const FADE_OUT_RATE := 14.0  # 1/s: a cancelled break unwinds in about 0.07 s
## State keys that, when set, mean the hunter is busy with something (not standing idle).
const BUSY_FLAGS := ["gliding", "rolling", "downed", "stun", "reviving", "dead", "act", "statue"]
const BUSY_TIMERS := ["mantle", "stomp", "reload", "drink", "base"]      # -1 while off

var root: Node3D
var skel: Skeleton3D
var dur := 0.0
var tracks: Array = []       # {bone, rot (Vector3, rad about model x/y/z), from, to, in, out, beats}, parents first
var calm_t := 0.0            # s standing calm; below 0 is the gap after a break
var play_t := -1.0           # s into the break, -1 when none
var fade := 0.0              # how much of the break is laid on the body
var shown_u := 0.0           # the break's progress last frame (its pose while it fades out)

## The break for a Hunter (archetype id), or null when its data has none.
static func make(model: Node3D, sk: Skeleton3D, arch: String) -> WardenBreak:
	var cfg: Dictionary = Content.rules(RULES).get(arch, {})
	if cfg.is_empty():
		return null
	var b := WardenBreak.new()
	b.root = model
	b.skel = sk
	b.dur = float(cfg["dur"])
	for tr in cfg["tracks"]:
		var bone := WardenSkeleton.find(sk, String(tr["bone"]))
		if bone >= 0:
			b.tracks.append(b._track(bone, tr))
	b.tracks.sort_custom(func(x, y): return b._depth(int(x["bone"])) < b._depth(int(y["bone"])))
	return b

func _track(bone: int, tr: Dictionary) -> Dictionary:
	var rot: Array = tr["rot"]
	return {"bone": bone, "rot": Vector3(rot[0], rot[1], rot[2]), "from": float(tr.get("from", 0.0)),
			"to": float(tr.get("to", 1.0)), "in": float(tr.get("in", 0.3)), "out": float(tr.get("out", 0.3)),
			"beats": float(tr.get("beats", 0.0))}

func _depth(bone: int) -> int:
	var n := 0
	while skel.get_bone_parent(bone) >= 0:
		bone = skel.get_bone_parent(bone)
		n += 1
	return n

func playing() -> bool:
	return play_t >= 0.0

## A key, button or click: whatever the break was doing stops.
func press() -> void:
	calm_t = 0.0
	play_t = -1.0

## One frame, after the clips posed the bones. `s` is the HunterAnim state.
func step(dt: float, s: Dictionary) -> void:
	if not bool(s.get("idle_break", false)):
		press()
	elif _standing(s):
		calm_t += dt
	else:
		press()
	var calm := calm_t >= 0.0 and _combat_free(s)
	if not calm:
		play_t = -1.0
	elif play_t < 0.0 and calm_t >= WAIT:
		play_t = 0.0
	if play_t >= 0.0:
		play_t += dt
		shown_u = play_t / dur
		if play_t >= dur:
			play_t = -1.0
			calm_t = -GAP
	fade = move_toward(fade, 1.0 if play_t >= 0.0 else 0.0, FADE_OUT_RATE * dt)
	if fade > 0.0:
		_lay()

func _standing(s: Dictionary) -> bool:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	if Vector2(vel.x, vel.z).length() >= STILL or not bool(s.get("grounded", true)):
		return false
	if float(s.get("crouch", 0.0)) > 0.05 or String(s.get("emote", "")) != "" or String(s.get("kmove", "")) != "":
		return false
	if String(s.get("tool", "")) != "":
		return false
	for k in BUSY_FLAGS:
		if bool(s.get(k, false)):
			return false
	for k in BUSY_TIMERS:
		if float(s.get(k, -1.0)) >= 0.0:
			return false
	return true

func _combat_free(s: Dictionary) -> bool:
	for k in ["fired", "cast", "hit_t"]:
		if float(s.get(k, 99.0)) < COMBAT_FREE:
			return false
	return true

## How far a track is turned at progress `u` (0..1 of the break): eased in and out, pulsed `beats` times when set.
static func amount(tr: Dictionary, u: float) -> float:
	var span := maxf(float(tr["to"]) - float(tr["from"]), 0.01)
	var w := (u - float(tr["from"])) / span
	if w <= 0.0 or w >= 1.0:
		return 0.0
	var a := smoothstep(0.0, float(tr["in"]), w) * (1.0 - smoothstep(1.0 - float(tr["out"]), 1.0, w))
	if float(tr["beats"]) > 0.0:
		a *= 0.5 - 0.5 * cos(w * float(tr["beats"]) * TAU)
	return a

## Turns each bone about its own head, the angles taken in the model's frame.
func _lay() -> void:
	var into_skel := skel.global_basis.orthonormalized().inverse() * root.global_basis.orthonormalized()
	for tr in tracks:
		var amt := amount(tr, shown_u) * fade
		if amt == 0.0:
			continue
		var bone := int(tr["bone"])
		var pose := skel.get_bone_global_pose(bone)
		var turn := into_skel * Basis.from_euler((tr["rot"] as Vector3) * amt) * into_skel.inverse()
		pose.basis = turn * pose.basis
		skel.set_bone_global_pose(bone, pose)
