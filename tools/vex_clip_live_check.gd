extends RefCounted
## --vex-clip-live-check: Vex's clips through the real match code (see --clip-live-check for Kael): her clips
## are on and no procedural gun shows; the slide's legs turn to the dash while the cannon arm stays on the aim
## (aims_in_dash); a tapped RMB swings the launcher forward; LMB plays; a knock-out plays the death clip.
## Never touches the save.

const DT := 1.0 / 60.0
const AIM_OFF := 0.3           # rad: how far the cannon may sit off the aim mid slide

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Array) -> void:
	m.step(DT)
	for x in h:
		(x as Hunter).render(DT, 1.0)
		if x.model and x.model.has_node("Warden/Sync"):
			var sync: Node = x.model.get_node("Warden/Sync")
			sync.set_process(false)
			if x.visible or x.out:
				sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

func _yaw_of(h: Hunter, sk: Skeleton3D, bone: String, along: Vector3) -> float:
	var d := sk.global_transform.basis * (sk.get_bone_global_pose(sk.find_bone(bone)).basis * along)
	return atan2(-d.x, -d.z)

func _shown(h: Hunter) -> int:
	var n := 0
	var gun := h.model.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible and (mi as MeshInstance3D).mesh != null:
			n += 1
	return n

## The world yaw a pair of bones faces: the line from the left one's head to the right one's is his right.
func _line_yaw(sk: Skeleton3D, left: String, right: String) -> float:
	var d := sk.global_transform.basis * (sk.get_bone_global_pose(sk.find_bone(right)).origin
			- sk.get_bone_global_pose(sk.find_bone(left)).origin)
	return atan2(-d.z, d.x)

## A frame of running `move` (the stick) while aiming +X, or `swing` rad round from it.
func _run_frame(m: Match, P: Hunter, T: Hunter, home: Vector3, move: Vector2, swing := 0.0) -> void:
	T.teleport(home + Vector3(30.0, 0, 0))
	A.aim_at(P, P.pos + Vector3(8.0, 0, 0).rotated(Vector3.UP, swing))
	P.inp["move"] = move
	_frame(m, [P])

func _run_rel(P: Hunter) -> float:
	return wrapf(atan2(-P.vel.x, -P.vel.z) - P.face, -PI, PI)

## Running one way while aiming another (+X): the legs turn to the run, the torso stays on the aim. Within the limit
## the legs turn the way he runs (the sign of his run off the aim); beyond it they turn round and run backwards, so
## the turn flips sign and shrinks. Read off the skeleton too, summed over a stride so the run's own sway cancels:
## the line through the thighs turns, the one through the shoulders stays on the aim.
func _twist(m: Match, P: Hunter, T: Hunter, home: Vector3) -> void:
	var c := _clips(P)
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	for deg in [0.0, 60.0, -60.0, 130.0, -130.0, 180.0]:
		var legs := Vector2.ZERO
		var torso := Vector2.ZERO
		for f in 50:
			_run_frame(m, P, T, home, Vector2(1, 0).rotated(deg_to_rad(deg)))
			if f >= 20:
				legs += Vector2.from_angle(_line_yaw(sk, "thigh.L", "thigh.R") - P.face)
				torso += Vector2.from_angle(_line_yaw(sk, "upper_arm.L", "upper_arm.R") - P.face)
		var rel := _run_rel(P)
		var back: bool = absf(rel) > WardenClips.TWIST_MAX
		var want := rel - signf(rel) * PI if back else rel
		ok(absf(c.head_turn - want) < 0.15 and c.twist_back == back,
				"run %d deg off the aim: legs turn %.2f rad (want %.2f, %s)" % [deg, c.head_turn, want,
				"backwards" if c.twist_back else "forwards"])
		ok(absf(wrapf(legs.angle() - want, -PI, PI)) < 0.3 and absf(torso.angle()) < 0.3,
				"  on the skeleton: the thighs face %.2f rad off the aim, the shoulders %.2f" % [legs.angle(),
				torso.angle()])
	# near 90 deg off the aim: just past the limit the legs turn round, running backwards holds a little inside it (no
	# flicker) and lets go further in; either way he never twists past the limit (100 to 88 to 82 on one side, so the
	# run never swings through the aim on the way)
	P.teleport(home)
	var most := 0.0
	var backs := []
	for deg in [0.0, 88.0, -100.0, -88.0, -82.0]:
		for f in 40:
			_run_frame(m, P, T, home, Vector2(1, 0).rotated(deg_to_rad(deg)))
			most = maxf(most, absf(c.head_turn))
		backs.append(c.twist_back)
	ok(backs == [false, false, true, true, false] and most <= WardenClips.TWIST_MAX + 0.01, ("runs 0, 88, 100, 88, "
			+ "82 deg off the aim: backwards %s, the twist at most %.2f rad (limit %.2f)") % [backs, most,
			WardenClips.TWIST_MAX])
	# the aim swings 70 deg toward his run in a tenth of a second: the legs hold his way, the torso takes the swing
	var run_60 := Vector2(1, 0).rotated(deg_to_rad(60.0))
	for f in 40:
		_run_frame(m, P, T, home, run_60)
	var swing := deg_to_rad(70.0) * signf(_run_rel(P))
	var drift := 0.0
	for f in 15:
		_run_frame(m, P, T, home, run_60, swing * minf(1.0, f / 6.0))
		drift = maxf(drift, absf(wrapf(P.face + c.head_turn - atan2(-P.vel.x, -P.vel.z), -PI, PI)))
	ok(drift < 0.1, "the aim swings 70 deg as he runs: the legs hold his way (off it by %.2f rad at most)" % drift)
	# a move keyed "heading" (Lace's roll) out of a twisted run turns him whole: the torso eases round with the legs
	for f in 40:
		_run_frame(m, P, T, home, run_60)
	var roll := {"heading": true, "turn_max": 3.2}
	var st := {"vel": P.vel, "face": P.face}
	var jump := 0.0
	for f in 20:
		var was := c.torso_turn
		c._turn_to_heading(st, roll, false, DT)
		jump = maxf(jump, absf(c.torso_turn - was))
	ok(absf(c.head_turn) > 0.5 and absf(c.torso_turn - c.head_turn) < 0.1 and jump < 0.3, ("a roll out of the run "
			+ "turns him whole: the torso %.2f rad off the legs, eased (%.2f rad a frame at most)")
			% [c.torso_turn - c.head_turn, jump])
	P.inp["move"] = Vector2.ZERO
	for f in 40:
		_frame(m, [P])
	ok(absf(c.head_turn) < 0.05 and absf(c.torso_turn) < 0.05,
			"the legs and torso unwind when he stops (%.2f, %.2f rad)" % [c.head_turn, c.torso_turn])

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("gunslinger", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	for f in 10:
		_frame(m, [P])
	ok(_clips(P) != null, "Vex wears her clips in a match")
	ok(_shown(P) == 0, "the cannon is the only weapon (%d procedural pieces)" % _shown(P))
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	# the slide: aim +X while she slides -Z: the legs go with the dash, the cannon stays on the aim
	var K: GunslingerKit = P.ak
	T.teleport(home + Vector3(30.0, 0, 0))
	A.aim_at(P, P.pos + Vector3(8.0, 0, 0))
	for f in 30:
		_frame(m, [P])
	P.inp["move"] = Vector2(0, -1)
	P.inp["dash"] = true
	var seen := {}
	var legs_turn := 0.0
	var worst := 0.0
	var frames := 0
	# the forearm bone's Y points along the cannon
	for f in 36:
		A.aim_at(P, P.pos + Vector3(8.0, 0, 0))
		P.inp["move"] = Vector2(0, -1)
		_frame(m, [P])
		var c := _clips(P)
		seen[c.cur] = true
		if c.cur == "dash" and c.act_w >= 0.99 and f > 8 and f < 26 and absf(c.head_turn) > 0.3:
			var aim := atan2(-(1.0), 0.0)
			var cannon := _yaw_of(P, sk, "forearm.R", Vector3.UP)
			worst = maxf(worst, absf(wrapf(cannon - aim, -PI, PI)))
			legs_turn = maxf(legs_turn, absf(c.head_turn))
			frames += 1
	P.inp["move"] = Vector2.ZERO
	ok(seen.has("dash"), "the dash plays her slide")
	ok(frames > 0 and legs_turn > 0.8, "the legs follow the dash (up to %.2f rad off the aim, %d frames)"
			% [legs_turn, frames])
	ok(frames > 0 and worst <= AIM_OFF, "the cannon stays on the aim through the slide (worst %.2f rad)" % worst)
	for f in 60:
		_frame(m, [P])
	_twist(m, P, T, home)
	# RMB tap: the fixed firing point is found and sits ahead of her on the aim, right at the press
	var fire := WardenGlb.anchor(P.model, "launcher_fire")
	ok(fire != null and WardenGlb.anchor(P.model, "launcher_muzzle") != null, "the launcher's two FX points are found")
	if fire:
		var ahead := (fire.global_position - P.model.global_position).dot(P.model.global_transform.basis.z * -1.0)
		print("LIVE launcher_fire %.2f m along her facing at rest" % ahead)
	var lb := sk.find_bone("launcher")
	var rest_q := sk.get_bone_pose_rotation(lb)
	seen.clear()
	P.inp["sec"] = true
	var swung := 0.0
	for f in 30:
		_frame(m, [P])
		seen[_clips(P).cur] = true
		swung = maxf(swung, sk.get_bone_pose_rotation(lb).angle_to(rest_q))
	ok(seen.has("rmb"), "a tapped RMB plays its clip")
	ok(swung > 2.4, "the launcher swings forward for the throw (%.2f rad)" % swung)
	# LMB
	seen.clear()
	for f in 60:
		_frame(m, [P])
	P.inp["fire"] = true
	for f in 40:
		_frame(m, [P])
		seen[_clips(P).cur] = true
	P.inp["fire"] = false
	ok(seen.has("lmb"), "LMB plays its clip")
	seen.clear()
	for f in 60:
		_frame(m, [P])
	print("LIVE clips seen last: ", seen.keys())
	# a knock-out
	P.lives = 1
	for f in 30:
		_frame(m, [P])
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, [P])
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out plays the death clip on screen (clip %s, visible %s)"
			% [dead_seen, was_visible])
	print("VEX_CLIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
