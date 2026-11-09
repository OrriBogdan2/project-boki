extends RefCounted
## --clip-live-claire-check: Neve's clips through the real match code, as --clip-live-check does for Kael: a Match,
## the kit's own keys and the render path. She wears her clips with one weapon drawn; the darts, the skate (start,
## stride, stop) and a skating beam play their clips, and her aim stays on the cursor while she fires on the skate
## (item 109); the spear's hold and push play theirs; a knock-out plays the death clip on screen.
## Never touches the save.

const DT := 1.0 / 60.0

var A
var bad := 0
var ids := {}

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

func _run(m: Match, P: Hunter, n: int, seen: Dictionary) -> void:
	for f in n:
		_frame(m, [P])
		var c := _clips(P)
		if c.cur != "":
			seen[c.cur] = true
		if c.up_w > 0.3:
			seen[String(c._node("anim_u").animation)] = true
		ids[String((P.ak as RimewrightKit).anim_id)] = true

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
	var r: Array = A.setup("rimewright", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var seen := {}
	_run(m, P, 10, seen)
	ok(_clips(P) != null, "Neve wears her clips in a match")
	ok(_shown(P) == 0, "one weapon drawn (%d procedural pieces)" % _shown(P))
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	_run(m, P, 90, seen)
	P.inp["fire"] = false
	ok(seen.has("dart_r") and seen.has("dart_l"), "the darts play their clips (%s)" % str(seen.keys()))
	_run(m, P, 30, seen)
	# the skate, then firing on it: the body stays on the cursor while she runs across it
	P.inp["move"] = Vector2(1, 0)
	P.dashes = 1.0
	P.inp["dash"] = true
	P.inp["dash_down"] = true
	_run(m, P, 30, seen)
	ok(seen.has("skate_go") or seen.has("skate"), "the skate plays its clips (%s)" % str(seen.keys()))
	P.inp["fire"] = true
	_run(m, P, 24, seen)
	var ad := P.aim_dir()
	var off := absf(wrapf(P.face - atan2(-ad.x, -ad.y), -PI, PI))
	ok(off < 0.3, "aim stays on the cursor on the skate (%.2f rad off)" % off)
	ok(seen.has("beam"), "a skating beam plays its clip")
	P.inp["fire"] = false
	P.inp["dash"] = false
	P.inp["move"] = Vector2.ZERO
	_run(m, P, 60, seen)
	ok(seen.has("skate_stop"), "letting go plays the stop")
	_run(m, P, 90, seen)
	# RMB: held, then pushed
	A.aim_at(P, T.pos)
	P.inp["sec"] = true
	P.inp["sec_hold"] = true
	_run(m, P, 30, seen)
	ok(seen.has("spear_aim"), "the spear's hold plays its clip")
	P.inp["sec"] = false
	P.inp["sec_hold"] = false
	_run(m, P, 45, seen)
	ok(seen.has("spear"), "the release plays the push")
	# the Rimelock statue (item 65): nothing on her moves while it holds, not even the braid's idle ripple
	var c0 := _clips(P)
	c0.force = {"clip": "rime_hold", "t": 0.2}
	_run(m, P, 30, seen)
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var sync: WardenGlb.Sync = P.model.get_node("Warden/Sync")
	var tail := sk.find_bone("spring_scarftail_braid_4")
	var hand0 := sk.get_bone_global_pose(sk.find_bone("hand.R")).origin
	var tail0 := sk.get_bone_global_pose(tail).origin
	_run(m, P, 45, seen)
	var hand_d := sk.get_bone_global_pose(sk.find_bone("hand.R")).origin.distance_to(hand0)
	var tail_d := sk.get_bone_global_pose(tail).origin.distance_to(tail0)
	ok(sync.springs.still and hand_d < 0.002 and tail_d < 0.01,
			"the statue holds still (hand %.4f m, tail %.4f m, ripple off %s)" % [hand_d, tail_d, sync.springs.still])
	c0.force = {}
	# a knock-out
	P.lives = 1
	_run(m, P, 30, seen)
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, [P])
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out plays the death clip on screen (clip %s, visible %s)"
			% [dead_seen, was_visible])
	print("LIVE kit moves seen: ", ids.keys(), " clips: ")
	print("CLIP_LIVE_CLAIRE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
