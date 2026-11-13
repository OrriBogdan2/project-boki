class_name WardenOpen
extends RefCounted
## The open channel's body (docs/art/wardens/CLIPS.md "Opening a box"): while a Hero holds a chest or a deathbox open
## (Hunter.holding() "chest" or "loot") the clips' pose gets one shared layer on the rig contract bones: turn to the
## box, step in, sink on bent knees with the soles kept, lean the back, and lay both hands on the lid (two-bone IK).
## It reaches in, holds with a small rummage, and goes straight back to idle or run when the hold ends.
## The plan is the Hero's own: drop and lean are searched against his shoulder height and arm reach, so Kael (2.05 m)
## folds deeper than Neve (1.56 m) and both reach the same lid. A move, dash, cast or hit drops the layer the frame it
## comes; the hold reaches in again once the cause is gone. Gameplay never reads it.

const KINDS := ["chest", "loot"]
const LID := "open_lid"          # box root meta: the lid's top centre in the box's own space (lid_top caches it)
const NEAR := 2.4                # m: the farthest box a holding Hunter can be opening (interact ranges are 1.5-1.6)
const REACH_S := 0.25            # s: down and in
const RETURN_S := 0.1            # s: back to the clips once the hold ends on its own
const CAST_S := 0.3              # s after a cast that the pose stays off
const HIT_S := 0.3               # s after a hit
const STILL := 0.25              # m/s: as WardenClips.STILL; faster is a move
const STEP_MAX := 0.45           # m: the most he shuffles in toward the box
const DROP_MAX := 0.42           # of the leg's length: the deepest sink on the knees
const LEAN_MAX := 0.95           # rad: the most the back bends over
const ARM_K := 0.93              # of the arm's length: the farthest a hand is sent (a locked elbow reads stiff)
const ARM_MIN := 0.45            # of the arm's length: the nearest (closer folds the arms into the chest)
const SPREAD := 0.17             # m: each hand off the lid's centre, across
const IN := 0.1                  # m: the hands lie this far in from the lid's centre toward him
const ABOVE := 0.04              # m: and this far over its top (the palm's thickness under the wrist)
const SHIN_K := 0.245 / 0.2      # the shin's length over the thigh's (RIG_STANDARD proportions: no foot bone)
const RUMMAGE := 0.025           # m: the hands' stir on the lid while he holds
const RUMMAGE_HZ := 2.2
const KNEES := 0.5               # 0..1: how much of the dip goes on the knees rather than the back

var clips: WardenClips
var skel: Skeleton3D
var root: Node3D
var w := 0.0                     # how much of the layer is on (the check reads it)
var t := 0.0                     # s into this reach
var plan := {}                   # {step, drop, lean} for this reach, in skeleton units
var b := {}                      # contract bone name -> index
var arm := 0.0                   # skeleton units: shoulder to wrist
var thigh := 0.0
var shin := 0.0
var layered: Array = []          # bone indices the layer moves
var lid_w := Vector3.INF         # the lid last held (world): the way back still faces it

static func make(c: WardenClips) -> WardenOpen:
	var o := WardenOpen.new()
	var sk := c.skel
	o.clips = c
	o.root = c.root
	o.skel = sk
	for nm in ["root", "hips", "thigh.L", "thigh.R", "shin.L", "shin.R", "upper_arm.L", "upper_arm.R",
			"forearm.L", "forearm.R", "hand.L", "hand.R"]:
		o.b[nm] = WardenSkeleton.find(sk, nm)
		if int(o.b[nm]) < 0:
			return null
		if not nm.begins_with("hand"):
			o.layered.append(o.b[nm])
	var rest := func(nm: String) -> Vector3: return sk.get_bone_global_rest(int(o.b[nm])).origin
	var elbow: Vector3 = rest.call("forearm.R")
	o.arm = elbow.distance_to(rest.call("upper_arm.R")) + elbow.distance_to(rest.call("hand.R"))
	o.thigh = rest.call("thigh.R").distance_to(rest.call("shin.R"))
	o.shin = o.thigh * SHIN_K
	return o

## The lid's top centre in world space, from the lid's own meshes (every chest model hangs a "Lid" under "Body").
static func lid_top(box: Node3D) -> Vector3:
	if not box.has_meta(LID):
		var lid := box.find_child("Lid", true, false) as Node3D
		var top := Vector3(0, 0.5, 0)
		if lid:
			var aabb := AABB()
			var first := true
			for mi in lid.find_children("*", "MeshInstance3D", true, false):
				var g := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				aabb = g if first else aabb.merge(g)
				first = false
			if not first:
				var c := aabb.get_center()
				top = box.global_transform.affine_inverse() * Vector3(c.x, aabb.end.y, c.z)
		box.set_meta(LID, top)
	return box.global_transform * (box.get_meta(LID) as Vector3)

## The lid a Hunter at `at` is opening: the nearest closed chest or full deathbox; INF when none is near.
static func lid_near(m: Match, at: Vector3) -> Vector3:
	var best: Node3D = null
	var bd := NEAR
	for e in m.chests + m.boxes:
		var n: Node3D = e.get("node")
		if n == null or not is_instance_valid(n) or bool(e.get("open", false)) or bool(e.get("empty", false)):
			continue
		var dd := Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length()
		if dd < bd:
			bd = dd
			best = n
	return lid_top(best) if best else Vector3.INF

## After the clips (and the rig mix) are on the bones: `on` is how much the clips own the body (1 - proc_w).
func step(dt: float, on: float) -> void:
	var s: Dictionary = root.get_meta(WardenClips.STATE, {})
	var at: Vector3 = s.get("act_at", Vector3.INF)
	if String(s.get("act", "")) not in KINDS or at == Vector3.INF:
		w = maxf(w - dt / RETURN_S, 0.0)
	elif cancelled(s):
		w = 0.0
	else:
		if w <= 0.0:
			t = 0.0
			plan = {}
		t += dt
		w = maxf(w, smoothstep(0.0, REACH_S, t))
	if w <= 0.0:
		plan = {}
		return
	if at != Vector3.INF:
		lid_w = at
	if lid_w != Vector3.INF:
		_pose(skel.global_transform.affine_inverse() * lid_w, w * on)

## A move, a dash, a cast, a hit, or anything else the clips play over the walk (clips.busy: a kit move, a stun, a
## landing): the pose goes this frame.
func cancelled(s: Dictionary) -> bool:
	var v: Vector3 = s.get("vel", Vector3.ZERO)
	return clips.busy or Vector2(v.x, v.z).length() >= STILL or bool(s.get("rolling", false)) \
			or float(s.get("cast", 99.0)) < CAST_S or float(s.get("hit_t", 99.0)) < HIT_S \
			or not bool(s.get("grounded", true))

func _g(nm: String) -> Transform3D:
	return skel.get_bone_global_pose(int(b[nm]))

func _put(nm: String, xf: Transform3D) -> void:
	skel.set_bone_global_pose(int(b[nm]), xf)

## The whole pose at full weight in skeleton space, then each moved bone's local pose eased from the clips' by `k`.
func _pose(lid: Vector3, k: float) -> void:
	var keep: Array = []
	for bi in layered:
		keep.append([skel.get_bone_pose_position(bi), skel.get_bone_pose_rotation(bi)])
	var up := Vector3.UP
	var unit := 1.0 / maxf(skel.global_basis.get_scale().y, 0.001)      # skeleton units per metre
	# turn the root to the box
	var r := _g("root")
	var right := (_g("upper_arm.R").origin - _g("upper_arm.L").origin)
	right.y = 0.0
	var fwd := up.cross(right.normalized())
	var to := lid - r.origin
	to.y = 0.0
	if to.length() > 0.01 and right.length() > 0.001:
		r.basis = Basis(up, fwd.signed_angle_to(to.normalized(), up)) * r.basis
		fwd = to.normalized()
	right = fwd.cross(up)
	var tl := lid + (-fwd * IN - right * SPREAD + up * ABOVE) * unit
	var tr := lid + (-fwd * IN + right * SPREAD + up * ABOVE) * unit
	_put("root", r)
	if plan.is_empty():
		plan = _plan(fwd, right, tl, tr, unit)
	r.origin += fwd * float(plan["step"])
	_put("root", r)
	var soles := [_sole("L"), _sole("R")]
	r.origin -= up * float(plan["drop"])
	_put("root", r)
	for i in 2:
		var sd: String = ["L", "R"][i]
		_ik("thigh." + sd, "shin." + sd, soles[i], _g("shin." + sd).origin + fwd * thigh, thigh, shin, true)
	var hp := _g("hips")
	hp.basis = Basis(right, -float(plan["lean"])) * hp.basis
	_put("hips", hp)
	var stir := Vector3(sin(t * TAU * RUMMAGE_HZ), 0.0, cos(t * TAU * RUMMAGE_HZ * 0.5)) * RUMMAGE * unit
	for i in 2:
		var sd: String = ["L", "R"][i]
		var aim: Vector3 = [tl, tr][i] + (stir if i == 0 else -stir)
		var sh := _g("upper_arm." + sd).origin
		var pole := sh + (right * (1.0 if sd == "R" else -1.0) - fwd * 0.4 - up * 0.3) * arm
		_ik("upper_arm." + sd, "forearm." + sd, aim, pole, -1.0, -1.0, false)
	for i in layered.size():
		var bi: int = layered[i]
		skel.set_bone_pose_position(bi, (keep[i][0] as Vector3).lerp(skel.get_bone_pose_position(bi), k))
		skel.set_bone_pose_rotation(bi, (keep[i][1] as Quaternion).slerp(skel.get_bone_pose_rotation(bi), k))

## Step, drop and lean for this reach: the cheapest that brings both shoulders within reach of their hands' marks.
## Cheap is KNEES: toward 1 he sinks before he bends, toward 0 he bends before he sinks.
func _plan(fwd: Vector3, right: Vector3, tl: Vector3, tr: Vector3, unit: float) -> Dictionary:
	var hips := _g("hips").origin
	var sl := _g("upper_arm.L").origin - hips
	var sr := _g("upper_arm.R").origin - hips
	var drop_max := DROP_MAX * (thigh + shin)
	var best := {"step": STEP_MAX * unit, "drop": drop_max, "lean": LEAN_MAX}
	var cost := INF
	var miss_best := INF
	for si in 4:
		for di in 8:
			for li in 8:
				var st := STEP_MAX * unit * si / 3.0
				var dr := drop_max * di / 7.0
				var ln := LEAN_MAX * li / 7.0
				var rot := Basis(right, -ln)
				var base := hips + fwd * st - Vector3.UP * dr
				var miss := 0.0
				for p in [[sl, tl], [sr, tr]]:
					var dd: float = (base + rot * (p[0] as Vector3)).distance_to(p[1])
					miss += maxf(dd - ARM_K * arm, 0.0) + maxf(ARM_MIN * arm - dd, 0.0)
				# squared, so a bit of knees and a bit of back beats all of either
				var c := 0.6 * pow(si / 3.0, 2) + (1.0 - KNEES) * pow(di / 7.0, 2) + KNEES * pow(li / 7.0, 2)
				if miss < miss_best - 0.0001 or (miss <= miss_best + 0.0001 and c < cost):
					miss_best = minf(miss, miss_best)
					cost = c
					best = {"step": st, "drop": dr, "lean": ln}
	return best

## Where the sole is: no foot bone, so the shin's own length down its Y (RIG_STANDARD).
func _sole(sd: String) -> Vector3:
	var g := _g("shin." + sd)
	return g.origin + g.basis.y.normalized() * shin

## Two-bone IK in skeleton space: `upper` and `mid` turn so the chain's end (the wrist, or the sole) lands on `aim`,
## bending toward `pole`. Lengths < 0 are read off the bones; `sole` ends the chain at _sole, not a child bone.
func _ik(upper: String, mid: String, aim: Vector3, pole: Vector3, la: float, lb: float, sole: bool) -> void:
	var a := _g(upper).origin
	var m := _g(mid).origin
	var end := _sole(mid.substr(mid.length() - 1)) if sole else _g("hand." + mid.substr(mid.length() - 1)).origin
	if la < 0.0:
		la = a.distance_to(m)
		lb = m.distance_to(end)
	var to := aim - a
	var dist := clampf(to.length(), absf(la - lb) + 0.001, la + lb - 0.001)
	var axis := to.normalized()
	var along := (la * la - lb * lb + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(la * la - along * along, 0.0))
	var bend := (pole - a) - axis * (pole - a).dot(axis)
	if bend.length() < 0.0001:
		return
	var knee := a + axis * along + bend.normalized() * h
	_turn(upper, m - a, knee - a)
	m = _g(mid).origin
	end = _sole(mid.substr(mid.length() - 1)) if sole else _g("hand." + mid.substr(mid.length() - 1)).origin
	_turn(mid, end - m, (a + axis * dist) - m)

func _turn(nm: String, from: Vector3, to: Vector3) -> void:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return
	var g := _g(nm)
	g.basis = Basis(Quaternion(from.normalized(), to.normalized())) * g.basis
	_put(nm, g)
