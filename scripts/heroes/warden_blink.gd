class_name WardenBlink
extends Node
## A Hero's eyelids blink in a close-up (hero select, the Model Room, the relic put-on). Data: warden_anim/<art>.json
## "blink": the lids' closed pose off their rest, in each bone's own frame: "turn" {bone: axis x angle, radians},
## "move" {bone: metres}. Every EVERY s (random) it looks for the camera: within WardenGlb.FAR_HIDE_D of the head the
## lids close over the clip's pose for SHUT_T s, now and then twice; past it (the match camera) they never do. Asleep
## between blinks: a Timer wakes it, so a far camera costs no per-frame work. Cosmetic: its own RNG, nothing synced.

const EVERY := Vector2(2.0, 6.0)   # s between blinks, at random
const DOWN_T := 0.04               # s the lids take to close
const HOLD_T := 0.04               # s they stay shut
const UP_T := 0.07                 # s they take to open
const SHUT_T := DOWN_T + HOLD_T + UP_T
const GAP_T := 0.12                # s open between the two of a double blink
const TWICE := 0.2                 # share of blinks that come as a double

var skel: Skeleton3D
var head := -1
var lids: Array = []               # [bone index, closed rotation, closed position or null]
var left := 0                      # blinks still to come in this run
var t := 0.0                       # s into the current blink
var timer := Timer.new()
var rng := RandomNumberGenerator.new()

## The blink of this model, added under glb; null when its art has no lids in its data.
static func make(glb: Node3D, sk: Skeleton3D, art_name: String) -> WardenBlink:
	var cfg: Dictionary = WardenClips.data(art_name).get("blink", {})
	if cfg.is_empty():
		return null
	var b := WardenBlink.new()
	b.name = "Blink"
	b.skel = sk
	b.head = WardenSkeleton.find(sk, "head")
	var turn: Dictionary = cfg.get("turn", {})
	var move: Dictionary = cfg.get("move", {})
	for nm in turn.keys() + move.keys():
		var bi := WardenSkeleton.find(sk, String(nm))
		if bi < 0 or b.lids.any(func(l): return int(l[0]) == bi):
			continue
		var rest := sk.get_bone_rest(bi)
		var rq := rest.basis.get_rotation_quaternion()
		var tv := _vec(turn.get(nm, [0, 0, 0]))
		var q := rq * Quaternion(tv.normalized(), tv.length()) if tv.length() > 0.0 else rq
		b.lids.append([bi, q, rest.origin + rq * _vec(move[nm]) if move.has(nm) else null])
	b.process_priority = 11         # after the clips pose the lids (WardenGlb.Sync, 10)
	b.rng.randomize()
	glb.add_child(b)
	return b

static func _vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _ready() -> void:
	set_process(false)
	timer.one_shot = true
	timer.timeout.connect(_due)
	add_child(timer)
	_arm()

func _arm() -> void:
	timer.start(rng.randf_range(EVERY.x, EVERY.y))

## The timer: a blink when the camera is close, else back to sleep.
func _due() -> void:
	if near():
		start(2 if rng.randf() < TWICE else 1)
	else:
		_arm()

## True when the camera is within the far-camera distance of the head (and the model is shown).
func near() -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or head < 0 or not skel.is_visible_in_tree():
		return false
	var at := skel.global_transform * skel.get_bone_global_pose(head).origin
	return cam.global_position.distance_to(at) < WardenGlb.FAR_HIDE_D

func start(times: int) -> void:
	left = times
	t = 0.0
	set_process(true)

## How shut the lids are `at` s into a blink: 0 open, 1 closed.
static func shut(at: float) -> float:
	if at < DOWN_T:
		return at / DOWN_T
	if at < DOWN_T + HOLD_T:
		return 1.0
	return clampf(1.0 - (at - DOWN_T - HOLD_T) / UP_T, 0.0, 1.0)

func _process(dt: float) -> void:
	t += dt
	if left > 1 and t >= SHUT_T + GAP_T:
		left -= 1
		t -= SHUT_T + GAP_T
	if t < SHUT_T:
		pose(shut(t))
	elif left <= 1:
		left = 0
		set_process(false)
		_arm()

## The lids k of the way from the clip's pose to closed.
func pose(k: float) -> void:
	for l in lids:
		var bi := int(l[0])
		skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi).slerp(l[1], k))
		if l[2] != null:
			skel.set_bone_pose_position(bi, skel.get_bone_pose_position(bi).lerp(l[2], k))
