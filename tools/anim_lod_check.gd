extends RefCounted
## --anim-lod-check: a Hero's rig on screen and near animates every frame; far away it updates every
## hero_anim_far_every frames and off screen every hero_anim_off_every, catching up on the time it skipped
## (AnimLod, tuning.json "perf"); on Ultra every rig animates every frame.

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
	var far := cam.global_position - cam.global_basis.z * (float(perf["hero_anim_near_m"]) + 20.0)
	ok(AnimLod.every(m.player.pos, vp) == 1, "your Hero, on screen and near: every frame")
	ok(AnimLod.every(far, vp) == int(perf["hero_anim_far_every"]), "far on screen: every %d" % perf["hero_anim_far_every"])
	ok(AnimLod.every(behind, vp) == int(perf["hero_anim_off_every"]), "off screen: every %d" % perf["hero_anim_off_every"])
	var sync := m.player.model.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	ok(sync != null, "the arena Hero has a rig")
	if sync:
		m.set_process(false)          # (the camera holds still where it is put)
		cam.global_position = m.player.model.global_position - cam.global_basis.z * 30.0
		var skipped := 0
		for i in 8:
			await main.get_tree().process_frame
			if sync._skip_dt > 0.0: skipped += 1
		ok(skipped >= 4, "off screen the rig skips frames and keeps the time (%d of 8)" % skipped)
		m.set_process(true)
	var was := String(Settings.get_v("quality"))
	Settings.v["quality"] = "ultra"
	ok(AnimLod.every(behind, vp) == 1, "Ultra: every rig every frame")
	Settings.v["quality"] = was
	print("ANIMLOD DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
