class_name WardenLookAt
extends RefCounted
## The head looks where the Hunter aims before the body has turned there: one turn laid over the rig contract's
## head bone (its pivot is the neck) after the clips or the rig posed it, the same for every Hero, so the keyed
## poses stay underneath. The body turns at HunterMove.turn_rate; the head covers what is left of the way to the
## aim, inside a clamp, and gives it back as the body arrives, so it never looks past the aim. Eased off through a
## dash, a knock, a stun, an emote, a full-body move, a glide and a knock-out, and for a remote Hunter (the aim is
## not on the wire). docs/art/wardens/LOOK_AT.md.

const LOOK := "look"                 # anim state key: Vector3 (x, z: the unit aim; y: its slope up), ZERO: none
const YAW_MAX := deg_to_rad(70.0)    # rad [est]: a neck's comfortable turn; the source data and footage give none
const PITCH_MAX := deg_to_rad(25.0)  # rad [est]: up or down, small enough that the face stays readable from above
const RATE := 40.0                   # 1/s [est]: the head covers about half the way to the aim each 60 Hz frame
const OFF_S := 0.06                  # s: eased off, inside the first third of a dash (Hunter.DASH_TIME)
const ON_S := 0.15                   # s: eased back on after it
const CHEST_M := 0.95                # m: the aim point rides this high over the ground under it (Match aim plane)
const NEAR_M := 1.5                  # m: an aim point nearer than this pitches the head as if it were this far
const OFF_FLAGS := ["rolling", "dead", "stun", "gliding", "diving", "ledge", "statue", "reviving"]
const OFF_PHASES := ["mantle", "stomp", "base"]      # (anim state phases: -1 while not on)

var root: Node3D
var skel: Skeleton3D
var bone := -1
var weight := 0.0            # 0..1: how much of the turn is on
var turn := Vector2.ZERO     # rad: x the yaw off the body's facing (+ his left), y the pitch (+ up)
var shown := Vector2.ZERO    # rad: what the head bone got this frame

## What a Hunter's head looks along this frame (the LOOK anim state), ZERO when it should not look.
static func aim_of(h: Hunter) -> Vector3:
	if h.remote or h.knock_t > 0.0:
		return Vector3.ZERO
	var dir := h.aim_dir()
	var at: Vector3 = h.inp["aim"]
	var flat := Vector2(at.x - h.pos.x, at.z - h.pos.z).length()
	return Vector3(dir.x, (at.y - h.pos.y - CHEST_M) / maxf(flat, NEAR_M), dir.y)

## The layer for a model's skeleton (the bone is missing: it does nothing).
static func make(model: Node3D, sk: Skeleton3D) -> WardenLookAt:
	var l := WardenLookAt.new()
	l.root = model
	l.skel = sk
	l.bone = WardenSkeleton.find(sk, "head")
	return l

## One frame, after the clips or the rig posed the bones and before the braids swing off the head.
func step(dt: float, clips: WardenClips) -> void:
	shown = Vector2.ZERO
	if bone < 0:
		return
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	var aim: Vector3 = s.get(LOOK, Vector3.ZERO)
	if aim != Vector3.ZERO and not _busy(s, clips):
		weight = move_toward(weight, 1.0, dt / ON_S)
		_follow(aim, float(s.get("face", 0.0)), dt)
	else:
		weight = move_toward(weight, 0.0, dt / OFF_S)
		if weight <= 0.0:
			turn = Vector2.ZERO
	# (a full-body clip owns the head for as much as it owns the body: a cast, a flinch, a landing)
	var k := weight * (1.0 - clips.act_w) if clips else weight
	shown = turn * k
	if shown.is_zero_approx():
		shown = Vector2.ZERO
		return
	# (the turn is the model's: about its up, then its right; the skeleton may sit turned inside the model)
	var to_skel := WardenGlb.model_xf(root, skel).basis.orthonormalized().inverse()
	var in_model := Basis(Vector3.UP, shown.x) * Basis(Vector3.RIGHT, shown.y)
	var pose := skel.get_bone_global_pose(bone)
	pose.basis = to_skel * in_model * to_skel.inverse() * pose.basis
	skel.set_bone_global_pose(bone, pose)

## The turn eases toward what is left between the body's facing and the aim, clamped.
func _follow(aim: Vector3, face: float, dt: float) -> void:
	var off := wrapf(atan2(-aim.x, -aim.z) - face, -PI, PI)
	var want := Vector2(clampf(off, -YAW_MAX, YAW_MAX), clampf(atan(aim.y), -PITCH_MAX, PITCH_MAX))
	turn = turn.lerp(want, 1.0 - exp(-RATE * dt))
	# (the body catching up takes the turn back as fast as it turns: the head never looks past the aim; an aim
	# that jumped to his other side is eased across instead)
	if turn.x * want.x >= 0.0 or is_zero_approx(want.x):
		turn.x = clampf(turn.x, minf(want.x, 0.0), maxf(want.x, 0.0))

## The body is doing something that owns the head.
func _busy(s: Dictionary, clips: WardenClips) -> bool:
	for flag in OFF_FLAGS:
		if bool(s.get(flag, false)):
			return true
	for phase in OFF_PHASES:
		if float(s.get(phase, -1.0)) >= 0.0:
			return true
	if String(s.get("emote", "")) != "":
		return true
	return _rig_move(s, clips)

## A kit move the procedural rig plays (the Hero has no clip for it): full-body for as long as its keys run.
func _rig_move(s: Dictionary, clips: WardenClips) -> bool:
	var id := String(s.get("kmove", ""))
	if id == "" or (clips and (clips.d.get("kmoves", {}) as Dictionary).has(id)):
		return false
	var move := HunterAnim.km_def(id)
	if move.is_empty():
		return false
	var keys: Array = move["keys"]
	return bool(move.get("hold", false)) or float(s.get("kmove_t", 99.0)) < float(keys[-1][0])
