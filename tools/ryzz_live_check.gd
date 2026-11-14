extends RefCounted
## --ryzz-live-check: Sparkle's clips through the real match code (tools/clip_live_check.gd for her kit): a Match,
## the kit's own presses and the render path. Each ability plays its clip, the rods blaze in Kitefall and at no
## other time, and a knock-out plays the death clip.
## Never touches the save.

const DT := 1.0 / 60.0

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	if h.model and h.model.has_node("Warden/Sync"):
		var sync: Node = h.model.get_node("Warden/Sync")
		sync.set_process(false)
		if h.visible or h.out:
			sync.call("_process", DT)

func _clips(h: Hunter) -> WardenClips:
	return h.model.get_node("Warden/Sync").get("clips") as WardenClips

## How far the rods' glow sleeves are flared right now (1 = hidden inside the rod).
func _flare(h: Hunter) -> float:
	var sk := WardenGlb.skeleton(h.model.get_node("Warden"))
	var bi := sk.find_bone("rodlit.1")
	return sk.get_bone_pose_scale(bi).x if bi >= 0 else 0.0

func _run(m: Match, P: Hunter, frames: int, seen: Dictionary) -> float:
	var top := 0.0
	for f in frames:
		_frame(m, P)
		var c := _clips(P)
		seen[c.cur] = true
		if c.up_w > 0.5:
			seen[c.cur_u] = true
		top = maxf(top, _flare(P))
	return top

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("mage", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var seen := {}
	_run(m, P, 10, seen)
	ok(_clips(P) != null, "Sparkle wears her clips in a match")
	var K: MageKit = P.ak
	T.teleport(home + Vector3(0, 0, -9.0))
	A.aim_at(P, T.pos)
	for shot in 3:
		P.inp["fire"] = true
		_frame(m, P)
		P.inp["fire"] = false
		_run(m, P, 54, seen)
	ok(seen.has("lmb_l") and seen.has("lmb_r"), "the finger bolts play lmb_l and lmb_r")
	# item 139: nothing but the model is drawn (the old wrist coil and forearm rings read as a gun); the bolts leave the
	# fingertip of the hand that fires, left then right
	var strays: Array = []
	for mi in P.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(P.model.get_path_to(mi))
		# (under Rig: the procedural body and the Gun; her blooms and the team ring aren't a weapon)
		if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null and n.begins_with("Rig"):
			strays.append(n)
	print("LIVE drawn outside the model: ", strays)
	ok(strays.is_empty(), "no procedural coil or weapon is drawn on her (%d)" % strays.size())
	var sides := []
	var worst := 0.0
	for shot in 4:
		_run(m, P, 45, seen)
		var was := K.lmb_n
		P.inp["fire"] = true
		_frame(m, P)
		P.inp["fire"] = false
		for wait in 3:              # (the kit skins the round on its next tick)
			if K.lmb_n == was:
				_frame(m, P)
		var fired := K.lmb_n != was
		var left := K.lmb_n % 2 == 1
		sides.append("L" if left else "R")
		var sd: Dictionary = m.get("shots")[-1] if not (m.get("shots") as Array).is_empty() else {}
		var from: Vector3 = sd.get("start", Vector3.ZERO)
		_run(m, P, 5, seen)         # (the release key: the arm is out)
		var tip := WardenGlb.anchor(P.model, "anchor_finger_L" if left else "weapon_muzzle")
		if fired and tip != null:
			var off := Vector2(from.x - tip.global_position.x, from.z - tip.global_position.z).length()
			print("LIVE shot %s: %.3f m from its fingertip" % [sides[-1], off])
			worst = maxf(worst, off)
		else:
			worst = 99.0
	ok(sides == ["L", "R", "L", "R"] or sides == ["R", "L", "R", "L"], "the bolts alternate hands: %s" % str(sides))
	ok(worst < 0.2, "each bolt leaves its firing fingertip (worst %.3f m)" % worst)
	var calm := _flare(P)
	P.grounded = true          # (in the air the rod goes on the press, with no hold)
	P.gliding = false
	K.bot_hold["rmb"] = 0.7    # (held as a bot holds it: no key is down in a check)
	K.press_rmb()
	_run(m, P, 40, seen)
	K._release_rmb()
	_run(m, P, 50, seen)
	ok(seen.has("rmb_hold") and seen.has("rmb"), "Storm Rod plays its hold and its throw")
	K.on_dash(false)
	_run(m, P, 90, seen)
	ok(seen.has("dash") or seen.has("dash_go"), "Wirerun plays its clips")
	K.cast_e()
	_run(m, P, 150, seen)
	ok(seen.has("sky"), "Skycall plays sky")
	ok(calm <= 1.05, "the rods sit dark outside the ult (flare %.2f)" % calm)
	K.cast_ult()
	var blaze := _run(m, P, 90, seen)
	K.ult_recast()
	blaze = maxf(blaze, _run(m, P, 90, seen))
	ok(seen.has("ult") and seen.has("ult_air"), "Kitefall plays its crouch and its hang")
	ok(blaze >= 3.0, "the rods blaze on Kitefall (flare %.2f)" % blaze)
	_run(m, P, 60, seen)
	var blown: bool = K.gum.blow()
	_run(m, P, 80, seen)
	ok(blown and seen.has("gum"), "she blows and pops her gum")
	print("LIVE clips seen: ", seen.keys())
	P.lives = 1
	_run(m, P, 30, seen)
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out stays on screen and plays the death clip")
	print("RYZZ_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
