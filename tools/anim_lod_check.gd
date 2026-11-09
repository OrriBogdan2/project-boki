extends RefCounted
## --anim-lod-check: a Hero's rig on screen and near animates every frame; far away it updates every
## anim_far_every frames and off screen (its notifier) every anim_off_every, catching up on the time it skipped,
## and casts no shadow (AnimLod, tuning.json "perf"); on Ultra every rig animates every frame. A Boki rig runs
## on the same gate; a calm Boki far from you sims at 10 Hz and one with a foe every step (KinPace).

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("ANIMLOD %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Game.goto("match", Match.arena_opts())
	while not (main.current is Match and (main.current as Match).is_processing()):
		await main.get_tree().process_frame
	var m: Match = main.current
	for i in 10:
		await main.get_tree().process_frame
	var vp := main.get_viewport()
	var cam := vp.get_camera_3d()
	var perf: Dictionary = Content.rules("tuning")["perf"]
	var behind := cam.global_position + cam.global_basis.z * 10.0
	var far := cam.global_position - cam.global_basis.z * (minf(AnimLod.far_m(), 200.0) + 20.0)
	ok(AnimLod.every(m.player.pos, vp) == 1, "your Hero, on screen and near: every frame")
	var far_n := int(perf["anim_far_every"])
	var off_n := int(perf["anim_off_every"])
	ok(AnimLod.every(far, vp) == far_n, "far on screen: every %d" % far_n)
	ok(AnimLod.every(behind, vp) == off_n, "off screen: every %d" % off_n)
	var sync := m.player.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	ok(sync != null, "the arena Hero has a rig")
	if sync:
		m.set_process(false)          # (the camera holds still where it is put)
		var cam_at := cam.global_position
		cam.global_position = m.player.model.global_position - cam.global_basis.z * 30.0
		var skipped := 0
		for i in 8:
			await main.get_tree().process_frame
			if sync.lod.skipped > 0.0: skipped += 1
		ok(skipped >= 4, "off screen the rig skips frames and keeps the time (%d of 8)" % skipped)
		var lit := sync.lod.casters.filter(func(c): return is_instance_valid(c[0]) and c[0].cast_shadow != 0)
		ok(sync.lod.casters.size() > 0 and lit.is_empty(),
			"off screen it casts no shadow (%d casters, %d still on)" % [sync.lod.casters.size(), lit.size()])
		cam.global_position = cam_at
		for i in 4:
			await main.get_tree().process_frame
		m.set_process(true)
		var own := sync.lod.casters.filter(func(c): return not is_instance_valid(c[0]) or c[0].cast_shadow == c[1])
		ok(sync.lod.near and own.size() == sync.lod.casters.size(), "back on screen and near: its own shadows again")
	var k: Kin = await _a_boki(m)
	_boki_rig(k)
	_pace(m, k)
	var was := String(Settings.get_v("quality"))
	Settings.v["quality"] = "ultra"
	ok(AnimLod.every(behind, vp) == 1, "Ultra: every rig every frame")
	Settings.v["quality"] = was
	print("ANIMLOD DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## A Boki of your own beside you (the arena has none): its rig runs on the same gate, its clips advanced by hand.
func _a_boki(m: Match) -> Kin:
	var k := Kin.new()
	var rec := m.bot_kin_record()
	rec["species"] = "cindle"          # (a rigged species)
	k.init_kin(m, "lodk", "cindle", rec, m.player)
	m.add_child(k)
	k.teleport(m.player.pos + Vector3(1.0, 0.0, 0.7))
	m.kins.append(k)
	for i in 6:
		await main.get_tree().process_frame
	return k

func _boki_rig(k: Kin) -> void:
	var rigs := k.find_children("BokiRig", "", true, false)
	var rig: BokiRig = rigs[0] if rigs.size() > 0 else null
	ok(rig != null and rig.lod != null, "a Boki rig runs on an AnimLod gate (rig %s, state %s, shown %s)"
		% [rig != null, k.state, k.is_visible_in_tree()])
	if rig:
		ok(rig.player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL,
			"its clips advance only on its own frames")

## KinPace: a calm Boki far from you (a stand-in viewpoint far off) skips most steps and keeps the time; one
## with a foe runs every step.
func _pace(m: Match, k: Kin) -> void:
	var me := m.player
	var you := Hunter.new()
	you.pos = me.pos + Vector3(Bot.FAR_M + 30.0, 0.0, 0.0)
	m.player = you
	k.state = "active"
	k.target = null
	me.hurt_at = -99.0
	me.ai.erase("tgt")
	var ran := 0
	var got := 0.0
	for i in KinPace.FAR_EVERY * 4:
		m.time += Match.DT
		var dt := KinPace.step(k, Match.DT)
		if dt > 0.0: ran += 1
		got += dt
	ok(ran <= 5, "far and calm: %d sims in %d steps" % [ran, KinPace.FAR_EVERY * 4])
	ok(got + k.pace_dt > Match.DT * (KinPace.FAR_EVERY * 4 - 0.5), "and none of the time is lost")
	k.target = me
	ran = 0
	for i in 12:
		m.time += Match.DT
		if KinPace.step(k, Match.DT) > 0.0: ran += 1
	ok(ran == 12, "with a foe: every step (%d of 12)" % ran)
	k.target = null
	m.player = me
	you.free()
