class_name WardenStride
extends RefCounted
## A Hero's run start and stop on top of the locomotion loops (content/rules/warden_stride.json), driven by the speed
## and the brake state, never by a timer. A start leans forward and settles as the shown speed catches the real one. A
## let-go from a walk or run shifts the weight back while the body slides (HunterMove.slide); one foot stays planted
## where it was and the other lifts and lands on its idle spot, then the planted one steps in, then the clips' idle.
## A dash, a cast, a hit, the air or a knock (speed over a run that nothing keyed) wears none of it, in that frame.
## Runs after WardenClips posed the bones.

const RULES := "res://content/rules/warden_stride.json"
const BRAKE_DROP := 0.25     # m/s under the peak speed: a let-go has started
const BRAKE_REGAIN := 0.4    # m/s over the slowest speed of the slide: the keys are down again
const CARRY := 1.15          # of the run speed: faster than this, nothing keyed it (a knock, a kit step)
const LEAN_RAMP := 0.3       # s a start takes to build the run speed on screen
const EASE := 12.0           # 1/s: the weight shift and the lean ease in and out
const RELEASE := 12.0        # 1/s: the foot pins let go of the legs
const REACH_AT := 0.85       # of the slide: the swinging foot is over its spot, and comes down in place from there
const FLIGHT_FROM := 0.12   # of a foot's way: it lifts before it travels (the sole is off the floor by then)
const FLIGHT_TO := 0.88     # and has landed before the last of it
const FREEZE_AT := 0.96      # of the slide: its spot stops following the body (the drawn body lags its speed a little)
const CROUCH_MAX := 0.3      # a sneak or slide dip is not a stop

static var _rules = null
# (loaded when first used, not named as a type: a type reference would compile HunterMove ahead of Hunter and
# GlideSpike's static init would then read HunterMove's rules before they exist)
static var _move: GDScript = null

var root: Node3D
var skel: Skeleton3D
var cfg: Dictionary
var hips := -1
var head := -1
var legs: Array = []         # [thigh bone, shin bone] per side
var idle_feet: Array = [Vector3.ZERO, Vector3.ZERO]   # model frame, off the last standing pose
var idle_known := false
var shown := 0.0             # m/s: the speed the start's lean has caught up with
var peak := 0.0              # m/s: the fastest of this run
var low := 0.0               # m/s: the slowest of this slide
var last_spd := 0.0
var carried := false
var phase := 0               # 0: none, 1: the slide, 2: the planted foot steps in, 3: letting go
var u := 0.0                 # 0..1 along the slide
var step_p := 0.0            # 0..1 of the second step
var from_pos := Vector3.ZERO     # world: where the let-go began
var lead := -1.0 / 60.0      # s: the drawn body is this much of its speed ahead of the physics (learned off each stop)
var aimed: Array = [Vector3.ZERO, 0.0]   # the last end spot guessed before the foot's spot froze, and the speed then
var dir := Vector3.ZERO      # world, flat: where the slide goes
var slide_m := 0.0
var feet0: Array = [Vector3.ZERO, Vector3.ZERO]       # world feet when the let-go began
var feet_to: Array = [Vector3.ZERO, Vector3.ZERO]     # world idle spots at the end of the slide
var swing := 0               # which foot swings in the slide; the other stays planted
var pin_w := 0.0
var stop_w := 0.0            # 0..1: the weight shifted back
var lean_w := 0.0            # 0..1 of the start lean

static func make(model: Node3D, sk: Skeleton3D, art_name: String) -> WardenStride:
	if _move == null:
		_move = load("res://scripts/match/hunter_move.gd")
	if _rules == null:
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	var st := WardenStride.new()
	st.root = model
	st.skel = sk
	st.cfg = _rules.get(art_name, _rules["default"])
	st.hips = WardenSkeleton.find(sk, "hips")
	st.head = WardenSkeleton.find(sk, "head")
	for sd in ["L", "R"]:
		st.legs.append([WardenSkeleton.find(sk, "thigh." + sd), WardenSkeleton.find(sk, "shin." + sd)])
	return st

## One frame, after the clips posed the bones. `clips` says whether the legs are the loop's to move.
func step(dt: float, s: Dictionary, clips: WardenClips) -> void:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var spd := Vector2(vel.x, vel.z).length()
	var lc: Dictionary = clips.d["loco"]
	var run := float(lc.get("run_speed", 4.6))
	var walk := float(lc.get("walk_speed", 2.2))
	if not _owns_body(s, clips):
		_reset(spd)
		return
	if spd > run * CARRY:
		carried = true
	elif spd >= run * 0.9 and spd <= run * 1.02 and absf(spd - last_spd) < 0.02:
		carried = false
	if phase == 0 and spd < WardenClips.STILL:
		peak = spd
		_record_idle(clips)
	peak = maxf(peak, spd) if phase == 0 else peak
	if phase == 0 and not carried and idle_known and peak >= walk * 0.85 and spd < peak - BRAKE_DROP:
		_begin(vel, spd)
	if phase in [1, 2]:
		low = minf(low, spd)
		if spd > low + BRAKE_REGAIN:
			phase = 3
	last_spd = spd
	if phase == 0:
		_lean(dt, spd, run, walk, vel)
	else:
		_stop(dt, spd)
	_pose()

## Nothing but the loops moves him: no action, no air, no dash, no crouch, nothing keyed.
func _owns_body(s: Dictionary, clips: WardenClips) -> bool:
	return clips.act_w < 0.05 and clips.up_w < 0.05 and clips.proc_w < 0.05 and clips.air_w < 0.05 \
			and not bool(s.get("rolling", false)) and String(s.get("kmove", "")) == "" \
			and float(s.get("crouch", 0.0)) < CROUCH_MAX and not bool(s.get("dead", false))

## Everything off in this frame (a dash a frame after a stop shows nothing of it).
func _reset(spd: float) -> void:
	phase = 0
	pin_w = 0.0
	stop_w = 0.0
	lean_w = 0.0
	shown = spd
	peak = spd
	last_spd = spd

func _record_idle(clips: WardenClips) -> void:
	if clips.loco_pos.length() > 0.05 or clips.stance_w > 0.05:
		return
	var inv := root.global_transform.affine_inverse()
	var f := _feet()
	idle_feet = [inv * f[0], inv * f[1]]
	idle_known = true

func _begin(vel: Vector3, spd: float) -> void:
	phase = 1
	u = 0.0
	step_p = 0.0
	low = spd
	from_pos = root.global_position
	dir = Vector3(vel.x, 0.0, vel.z).normalized()
	slide_m = maxf(_move.slide(spd), 0.01)
	feet0 = _feet()
	# (the trailing foot swings through; the leading one plants)
	swing = 0 if _ahead(feet0[0]) < _ahead(feet0[1]) else 1
	_aim(spd)

## The idle spots at the end of what is left of the slide (HunterMove.slide of the speed now).
func _aim(spd: float) -> void:
	var end := root.global_transform
	end.origin += dir * (_move.slide(spd) + lead * spd)
	if u < FREEZE_AT:
		aimed = [end.origin, spd]
	var kept: Vector3 = feet_to[swing]
	feet_to = [end * idle_feet[0], end * idle_feet[1]]
	if u >= FREEZE_AT:
		feet_to[swing] = kept        # (down: it stays where it landed)

func _ahead(p: Vector3) -> float:
	return (p - from_pos).dot(dir)

## The start: leans along the way he goes, less as the shown speed catches up.
func _lean(dt: float, spd: float, run: float, walk: float, vel: Vector3) -> void:
	shown = move_toward(shown, spd, run / LEAN_RAMP * dt) if spd > shown else spd
	var want := 0.0 if carried or spd < WardenClips.STILL else (1.0 - shown / spd) * clampf(spd / walk, 0.0, 1.0)
	lean_w = move_toward(lean_w, want, EASE * dt) if want < lean_w else want
	stop_w = move_toward(stop_w, 0.0, EASE * dt)
	pin_w = move_toward(pin_w, 0.0, RELEASE * dt)
	if lean_w > 0.001:
		_tilt(Vector3(vel.x, 0.0, vel.z), deg_to_rad(float(cfg["lean_deg"])) * lean_w)

func _stop(dt: float, spd: float) -> void:
	lean_w = 0.0
	shown = spd
	var want := 1.0
	if phase == 1:
		u = clampf(1.0 - _move.slide(spd) / slide_m, 0.0, 1.0)
		_aim(spd)
		if u >= 1.0 or spd < WardenClips.STILL:
			phase = 2
			# (halted: how far off the guess was says how far ahead of the physics the body is drawn)
			if float(aimed[1]) > 0.3:
				lead += 0.5 * (root.global_position - (aimed[0] as Vector3)).dot(dir) / float(aimed[1])
	if phase == 2:
		step_p = minf(step_p + dt / float(cfg["step_s"]), 1.0)
		want = 1.0 - step_p
		if step_p >= 1.0:
			phase = 3
	if phase == 3:
		want = 0.0
		pin_w = move_toward(pin_w, 0.0, RELEASE * dt)
		if pin_w <= 0.0 and stop_w <= 0.01:
			phase = 0
			peak = spd
	else:
		pin_w = 1.0
	stop_w = move_toward(stop_w, want, EASE * dt)
	_tilt(dir, -deg_to_rad(float(cfg["settle_deg"])) * stop_w)

## Leans the hips along a world direction by `ang` radians (+ forward), the head keeping half of it level.
func _tilt(world_dir: Vector3, ang: float) -> void:
	var d := root.global_basis.inverse().orthonormalized() * world_dir
	d.y = 0.0
	if d.length_squared() < 0.0001 or hips < 0:
		return
	d = d.normalized()
	var axis := Vector3(d.z, 0.0, -d.x)
	skel.set_bone_pose_rotation(hips, Quaternion(axis, ang) * skel.get_bone_pose_rotation(hips))
	if head >= 0:
		skel.set_bone_pose_rotation(head, Quaternion(axis, -ang * 0.5) * skel.get_bone_pose_rotation(head))

## Pins the feet of the slide and the step on top of the loops' legs: the swinging foot flies to its idle spot while
## the other stays where it was; once the body halts the planted foot steps in.
func _pose() -> void:
	if pin_w <= 0.001 or phase == 0:
		return
	var arc := float(cfg["arc_m"])
	for i in 2:
		var at: Vector3 = feet_to[i]
		var from: Vector3 = feet0[i]
		var reach := 1.0       # how far this foot is along its way to `at`, and how far through its arc
		var arc_p := 0.5
		if i == swing:
			reach = clampf(u / REACH_AT, 0.0, 1.0) if phase == 1 else 1.0
			arc_p = u if phase == 1 else 1.0
		else:
			from.y = at.y
			reach = 0.0 if phase == 1 else step_p
			arc_p = reach if phase != 1 else 0.0
		var goal := from.lerp(at, smoothstep(FLIGHT_FROM, FLIGHT_TO, reach)) + Vector3.UP * (arc * sin(PI * arc_p))
		_plant(i, goal, pin_w)

func _feet() -> Array:
	var out := []
	for lg in legs:
		var ends := _leg_ends(lg)
		out.append(skel.global_transform * ends[2])
	return out

## [hip, knee, foot] in skeleton space (the shin's Y runs along the limb; its length is the thigh's).
func _leg_ends(lg: Array) -> Array:
	var th := skel.get_bone_global_pose(int(lg[0]))
	var kn := skel.get_bone_global_pose(int(lg[1]))
	return [th.origin, kn.origin, kn.origin + kn.basis.y.normalized() * kn.origin.distance_to(th.origin)]

## Two-bone leg to a world point, the knee bending the way it already does; w blends from the loop's foot.
func _plant(i: int, world_goal: Vector3, w: float) -> void:
	var lg: Array = legs[i]
	var ends := _leg_ends(lg)
	var hip: Vector3 = ends[0]
	var knee: Vector3 = ends[1]
	var l1 := hip.distance_to(knee)
	var goal: Vector3 = (ends[2] as Vector3).lerp(skel.global_transform.affine_inverse() * world_goal, w)
	var to := goal - hip
	var dist := clampf(to.length(), 0.05, l1 * 2.0 - 0.001)
	var axis := to.normalized()
	var a := dist * 0.5
	var bend := (knee - hip) - axis * (knee - hip).dot(axis)
	bend = bend.normalized() if bend.length_squared() > 0.000001 else axis.cross(Vector3.RIGHT).normalized()
	var new_knee := hip + axis * a + bend * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var foot := hip + axis * dist
	var th := skel.get_bone_global_pose(int(lg[0]))
	var kn := skel.get_bone_global_pose(int(lg[1]))
	th.basis = Basis(Quaternion(th.basis.y.normalized(), (new_knee - hip).normalized())) * th.basis
	kn.basis = Basis(Quaternion(kn.basis.y.normalized(), (foot - new_knee).normalized())) * kn.basis
	kn.origin = new_knee
	skel.set_bone_global_pose(int(lg[0]), th)
	skel.set_bone_global_pose(int(lg[1]), kn)
