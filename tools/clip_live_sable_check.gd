extends RefCounted
## --clip-live-sable-check: Sable's clips through the real match code, as --clip-live-check does for Kael: a Match, the
## kit's own keys and the render path. She wears her clips with no procedural weapon drawn; her shots, the Vault's
## routine of flips, the Encore and its dance play their clips, the dance loops, the wing flare reaches the model,
## and a knock-out plays the death clip on screen.
## Never touches the save.

const DT := 1.0 / 60.0

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

func _run(m: Match, P: Hunter, n: int, seen: Dictionary) -> void:
	for f in n:
		_frame(m, [P])
		var c := _clips(P)
		if c.cur != "":
			seen[c.cur] = true
		if c.up_w > 0.3:
			seen[c.cur_u] = true

## rad the wing's chain is bent between its first and last links: a twisted wing folds over itself.
func _wing_bend(h: Hunter) -> float:
	var sk := WardenGlb.skeleton(h.model.get_node("Warden"))
	var q: Array = []
	for i in 4:
		q.append(sk.get_bone_global_pose(sk.find_bone("spring_wingR_%d" % i)).origin)
	return ((q[1] - q[0]) as Vector3).angle_to((q[3] - q[2]) as Vector3)

func _shown(h: Hunter) -> int:
	var n := 0
	var gun := h.model.get_node("Rig/Torso/Aim/Gun") as Node3D
	for mi in gun.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible and (mi as MeshInstance3D).mesh != null:
			n += 1
	var off := h.model.find_child("Offhand", true, false)
	if off:
		for mi in off.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).visible and (mi as MeshInstance3D).mesh != null:
				n += 1
	return n

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("thief", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var seen := {}
	_run(m, P, 10, seen)
	ok(_clips(P) != null, "Sable wears her clips in a match")
	ok(_shown(P) == 0, "only the skinned pistols drawn (%d procedural pieces)" % _shown(P))
	P.equip(P.wid)
	_run(m, P, 4, seen)
	ok(_shown(P) == 0, "the same after an equip (%d procedural pieces)" % _shown(P))
	A.aim_at(P, T.pos)
	P.inp["fire"] = true
	_run(m, P, 90, seen)
	P.inp["fire"] = false
	ok(seen.has("lmb_r") and seen.has("lmb_l"), "both pistols' shots play their clips (%s)" % str(seen.keys()))
	_run(m, P, 30, seen)
	# the Vault: three in a row is the routine (a cartwheel, a somersault, a corkscrew)
	var flips := {}
	var kit: ThiefKit = P.ak
	var bend := 0.0
	for i in 3:
		if i > 0:
			kit.chain.on_reset()          # (the empowered bolt landed: the routine moves on)
		P.inp["move"] = Vector2(1, 0)
		P.dashes = 1.0
		P.inp["dash"] = true
		P.inp["dash_down"] = true
		_run(m, P, 2, seen)
		P.inp["dash"] = false
		P.inp["dash_down"] = false
		var s2 := {}
		for f in 24:
			_run(m, P, 1, s2)
			if float(P.model.get_meta(WardenGlb.WING_FOLD, 0.0)) < -0.3:
				bend = maxf(bend, _wing_bend(P))
		for k in s2:
			if String(k).begins_with("vault"):
				flips[k] = true
	P.inp["move"] = Vector2.ZERO
	print("LIVE flips: ", flips.keys())
	ok(flips.size() >= 2, "the Vault's routine plays its flips (%s)" % str(flips.keys()))
	ok(bend < 1.0, "the wings stay untwisted through the flips (worst bend %.2f rad)" % bend)
	_run(m, P, 40, seen)
	# Encore: the dance holds over her and loops
	var K: ThiefKit = P.ak
	var started: bool = K._start_encore()
	ok(started, "Encore starts")
	var s3 := {}
	var flared := false
	for f in 110:
		_run(m, P, 1, s3)
		flared = flared or float(P.model.get_meta(WardenGlb.WING_FOLD, 0.0)) < -0.3
	ok(s3.has("encore") and s3.has("encore_dance"), "Encore plays the opening and the dance (%s)" % str(s3.keys()))
	ok(flared, "the dance flares the wings")
	_run(m, P, 60, seen)
	P.lives = 1
	_run(m, P, 10, seen)
	m.eliminate(P, T, "finished")
	var dead_seen := false
	var was_visible := false
	for f in 60:
		_frame(m, [P])
		dead_seen = dead_seen or _clips(P).cur == "death"
		was_visible = was_visible or P.visible
	ok(dead_seen and was_visible, "a knock-out plays the death clip on screen (clip %s, visible %s)"
			% [dead_seen, was_visible])
	print("CLIP_LIVE_SABLE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
