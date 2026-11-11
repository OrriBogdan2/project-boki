extends RefCounted
## --clip-live-grimble: Grimble's clips through the real match code, as --clip-live-check does for Kael.
## The hook's throw and reel play their clips and his own right arm reaches out (WardenReach: straight on the line,
## his slime hand at the tip; owner 11-11), then comes home; the dash is the junk ball; shots
## leave the blunderbuss; a hit spills coins; a knock-out plays the death clip. Never touches the save.

const DT := 1.0 / 60.0
const MUZZLE_OFF := 0.08       # m: the Gun's Muzzle off the visible muzzle

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, P: Hunter) -> void:
	m.step(DT)
	P.render(DT, 1.0)
	if P.model and P.model.has_node("Warden/Sync"):
		var sync: Node = P.model.get_node("Warden/Sync")
		sync.set_process(false)
		if P.visible or P.out:
			sync.call("_process", DT)

func _clips(P: Hunter) -> WardenClips:
	return P.model.get_node("Warden/Sync").get("clips") as WardenClips

func _bone_scale(P: Hunter, bone: String) -> float:
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	return sk.get_bone_pose_scale(sk.find_bone(bone)).x

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("dredge", 6.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: DredgeKit = P.ak
	for f in 10:
		_frame(m, P)
	ok(_clips(P) != null, "Grimble wears his clips in a match")
	# the hook, at a foe ahead
	T.teleport(home + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.press_rmb()
	var seen := {}
	var hook_min := 1.0     # the slime hand's scale (bone hook) while the arm is out: his own, never shrunk
	var grip_off := 0.0     # m, his hand off the arm's tip once the reach owns the arm (most)
	var off_line := 0.0     # m, his elbow and wrist off the shoulder-to-tip line then (most)
	var longest := 0.0      # m, shoulder to wrist (most)
	var rig := WardenGlb.skeleton(P.model.get_node("Warden"))
	var reach := _clips(P).reach
	var at := func(bone: String) -> Vector3:
		return rig.global_transform * rig.get_bone_global_pose(rig.find_bone(bone)).origin
	for f in 200:
		_frame(m, P)
		seen[_clips(P).cur] = true
		var tip: Vector3 = P.model.get_meta(WardenReach.TIP, Vector3.INF)
		if not tip.is_finite():
			continue
		hook_min = minf(hook_min, _bone_scale(P, "hook"))
		if reach.w < 1.0:
			continue
		var sh: Vector3 = at.call("upper_arm.R")
		var wrist: Vector3 = at.call("hand.R")
		var line := sh.direction_to(tip)
		for b in ["forearm.R", "hand.R"]:
			var v: Vector3 = at.call(b) - sh
			off_line = maxf(off_line, (v - line * v.dot(line)).length())
		grip_off = maxf(grip_off, wrist.distance_to(tip))
		longest = maxf(longest, sh.distance_to(wrist))
	print("LIVE clips seen: ", seen.keys())
	ok(seen.has("throw") and seen.has("reel"), "the throw and the reel play their clips")
	ok(hook_min > 0.9, "his own slime hand and crescent are what reach out, never shrunk (%.2f)" % hook_min)
	ok(off_line < 0.05, "the reaching arm lies straight on the line to its tip, the clips can't swing it (%.3f m)" % off_line)
	# (the grip, 0.45 m at his size, plus up to a step of the hook's flight)
	ok(grip_off < 0.8, "his hand is at the tip it reaches to (%.2f m)" % grip_off)
	ok(longest > 5.0, "the arm stretches out to the foe 7 m off (%.1f m)" % longest)
	for f in 40:
		_frame(m, P)
	ok(reach.w <= 0.0 and rig.get_bone_pose_scale(rig.find_bone("forearm.R")).y < 1.01,
			"the arm comes home after the reel, back in the clips (w %.2f)" % reach.w)
	# the junk ball
	var most := 0.0
	K.h.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	for f in 30:
		_frame(m, P)
		P.inp["dash"] = false
		most = maxf(most, _bone_scale(P, "ball"))
	P.inp["move"] = Vector2.ZERO
	ok(most > 3.0, "the dash is the junk ball (ball scale %.2f)" % most)
	# the Muzzle on the gun you see
	var sync: Node = P.model.get_node("Warden/Sync")
	var muzzle := sync.get("muzzle") as Node3D
	var tip := WardenGlb.anchor(P.model, WardenGlb.WEAPON_MUZZLE)
	for f in 8:
		_frame(m, P)
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var sees: Vector3 = sk.global_transform * (sk.get_bone_global_pose(int(sync.get("blade_bone"))) * tip.position)
	ok(muzzle.global_position.distance_to(sees) <= MUZZLE_OFF,
			"the Muzzle sits on the blunderbuss (%.3f m)" % muzzle.global_position.distance_to(sees))
	# a hit spills coins
	P.hurt_at = m.time
	_frame(m, P)
	ok(K.coins.burst != null, "a hit spills coins from the hoard")
	# a knock-out
	P.lives = 1
	m.eliminate(P, T, "finished")
	var dead_seen := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or _clips(P).cur == "death"
	ok(dead_seen, "a knock-out plays the death clip")
	print("CLIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
