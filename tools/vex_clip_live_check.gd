extends RefCounted
## --vex-clip-live-check: Vex's clips through the real match code (see --clip-live-check for Kael): her clips
## are on and no procedural gun shows; the slide's legs turn to the dash while the cannon arm stays on the aim
## (aims_in_dash); a tapped RMB flicks the coin hand out; E raises the open palm; LMB plays; a knock-out plays
## the death clip.
## Never touches the save.

const DT := 1.0 / 60.0
const AIM_OFF := 0.3           # rad: how far the cannon may sit off the aim mid slide
const FLICK := 0.2             # m: how far past rest the coin hand reaches along her facing
const PALM_UP := 1.2           # m: the raised palm above her feet while Palm Lance charges
const PALM_OUT := 0.25         # m: the palm ahead of her while Palm Lance charges

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
	# RMB tap: Coin Blast is flicked from her cyborg hand: the palm emitter is found and goes out ahead of her
	var palm := WardenGlb.anchor(P.model, "palm_emitter")
	ok(palm != null, "the palm emitter (Coin Blast, Palm Lance) is found")
	# (the hand's BoneAttachment3D follows the skeleton when the tree draws; this check steps by hand)
	var at := func() -> Vector3:
		sk.force_update_all_bone_transforms()
		var ba := palm.get_parent() as BoneAttachment3D
		return sk.global_transform * sk.get_bone_global_pose(ba.bone_idx) * palm.transform.origin - P.pos
	var fwd := func() -> float:
		var a := P.aim_dir()
		return (at.call() as Vector3).dot(Vector3(a.x, 0, a.y)) if palm else 0.0
	var up := func() -> float:
		return (at.call() as Vector3).y if palm else 0.0
	var rest_ahead: float = fwd.call()
	seen.clear()
	P.inp["sec"] = true
	var flick := -9.0
	for f in 30:
		_frame(m, [P])
		seen[_clips(P).cur] = true
		flick = maxf(flick, fwd.call() - rest_ahead)
	P.inp["sec"] = false
	ok(seen.has("rmb"), "a tapped RMB plays its clip")
	ok(flick > FLICK, "the coin hand flicks out ahead of her (%.2f m past rest %.2f m)" % [flick, rest_ahead])
	# E: Palm Lance charges from the raised open palm, out in front at chest height
	for f in 60:
		_frame(m, [P])
	seen.clear()
	K.cd["e"] = 0.0
	K.use_e()
	var high := 0.0
	var out := 0.0
	for f in 30:
		_frame(m, [P])
		seen[_clips(P).cur] = true
		if not K.needle.is_empty():
			high = maxf(high, up.call())
			out = maxf(out, fwd.call())
	ok(seen.has("e"), "Palm Lance plays its clip")
	ok(high > PALM_UP and out > PALM_OUT,
			"the palm is raised and out for the charge (%.2f m up, %.2f m ahead)" % [high, out])
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
