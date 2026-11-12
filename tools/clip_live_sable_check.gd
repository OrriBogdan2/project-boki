extends RefCounted
## --clip-live-sable-check: Sable's clips through the real match code, as --clip-live-check does for Kael: a Match, the
## kit's own keys and the render path. She wears her clips with no procedural weapon drawn; her shots, the Vault's
## routine of flips, the Encore and its dance play their clips, the dance loops, the wing flare reaches the model,
## her moth wings come up now and then while she stands (raised behind her, clear of her back, then folded again),
## stay folded while she runs and rise on a jump (WardenWings), and a knock-out plays the death clip on screen.
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

## rad the wing's chain is bent between its first and last segments: a twisted wing folds over itself.
func _wing_bend(h: Hunter) -> float:
	var sk := WardenGlb.skeleton(h.model.get_node("Warden"))
	var q: Array = []
	for i in 3:
		q.append(sk.get_bone_global_pose(sk.find_bone("spring_wingR_%d" % i)).origin)
	return ((q[1] - q[0]) as Vector3).angle_to((q[2] - q[1]) as Vector3)

func _fold(h: Hunter) -> float:
	return float(h.model.get_meta(WardenGlb.WING_FOLD, 0.0))

## m: how far the raised right wing's tip stands above its root and behind it (skeleton space, +Z behind).
func _wing_up(h: Hunter) -> Vector2:
	var sk := WardenGlb.skeleton(h.model.get_node("Warden"))
	var r := sk.get_bone_global_pose(sk.find_bone("spring_wingR_0")).origin
	var t := sk.get_bone_global_pose(sk.find_bone("spring_wingR_2")).origin
	return Vector2(t.y - r.y, t.z - r.z)

## WardenWings on its own (the emote has no hook in a check match): an emote opens the wings slowly, a run folds
## them, an idle raise comes within the data's gap and folds again.
func _wings_unit() -> void:
	var cfg: Dictionary = WardenClips.data("sable").get("wings", {})
	ok(not cfg.is_empty(), "sable.json carries the wings block")
	var w := WardenWings.make(cfg, 7)
	var f := 0.0
	for i in 30:
		f = w.fold(DT, 0.0, false, true, 0.0, false)
	ok(f > -0.6, "an emote opens them slowly (%.2f after 0.5 s)" % f)
	for i in 60:
		f = w.fold(DT, 0.0, false, true, 0.0, false)
	ok(f < -0.9, "and fully (%.2f)" % f)
	for i in 30:
		f = w.fold(DT, 0.0, false, true, 4.6, false)
	ok(f > -0.02, "a run folds them even mid-emote (%.2f)" % f)
	var up := 0.0
	var first := -1.0
	var shut_after := false
	for i in int(cfg["idle_gap_s"][1] * 60.0) + 300:
		f = w.fold(DT, 0.0, false, false, 0.0, false)
		if f < -0.9 and first < 0.0:
			first = i * DT
		if f < -0.5:
			up += DT
		shut_after = shut_after or (first >= 0.0 and f > -0.02)
	ok(first >= 0.0 and shut_after, "an idle raise comes, holds and folds again (first at %.1f s, open %.1f s)"
			% [first, up])

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
	# the moth wings: once the dance is over and has let them down, standing about raises them now and then
	K.encore.drop()
	var n := 0
	while _fold(P) < -0.05 and n < 600:
		_run(m, P, 1, seen)
		n += 1
	ok(n < 600, "the dance over, the wings fold down (%.2f after %d frames)" % [_fold(P), n])
	var idle_up := false
	var shut := false
	var lift := Vector2.ZERO
	var ibend := 0.0
	for f in int(WardenClips.data("sable")["wings"]["idle_gap_s"][1] * 60.0) + 240:
		_run(m, P, 1, seen)
		if _fold(P) < -0.9:
			idle_up = true
			lift = _wing_up(P)
			ibend = maxf(ibend, _wing_bend(P))
		shut = shut or (idle_up and _fold(P) > -0.05)
		if shut:
			break
	ok(idle_up and shut, "standing about raises the wings and folds them again (raised %s, folded %s)"
			% [idle_up, shut])
	# (0.15 m back: a body the tool tipped the cards back on raises them more upright, and still behind her)
	ok(lift.x > 0.25 and lift.y > 0.15, "raised, the tips stand up and back behind her (%.2f m up, %.2f m back)"
			% [lift.x, lift.y])
	ok(ibend < 0.5, "the raised wing is flat, not folded over itself (bend %.2f rad)" % ibend)
	P.inp["move"] = Vector2(0, -1)
	var run_open := 0.0
	for f in 150:
		_run(m, P, 1, seen)
		if f > 30 and P.grounded:
			run_open = maxf(run_open, -_fold(P))
	P.inp["move"] = Vector2.ZERO
	ok(run_open < 0.05, "running keeps them folded on the ground (most open %.2f)" % run_open)
	_run(m, P, 30, seen)
	P.inp["jump"] = true
	var air_open := 0.0
	for f in 40:
		_run(m, P, 1, seen)
		P.inp["jump"] = false
		air_open = maxf(air_open, -_fold(P))
	ok(air_open > 0.6, "a jump raises them (most open %.2f)" % air_open)
	_run(m, P, 60, seen)
	_wings_unit()
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
