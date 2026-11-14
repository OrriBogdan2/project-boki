extends RefCounted
## --hob-spot-shots=<dir>: Hob and the market stall from the game camera (run with a real renderer, e.g. xvfb-run
## with --rendering-driver opengl3), for before/after sheets of his clear ring (HobSpot). Writes 1_prompt.png
## (standing 1.6 m in front of the stall, toward Hob: whose prompt shows) and 2_build.png (build mode, a crop
## patch held on open ground 2-3.4 m from him, _beside). Prints "HOBSPOTSHOT <name> <what>". Uses only
## what main had before HobSpot, so the same file shoots the old build too. Never touches the real save.

var main: Node
var dir := ""
var home = null


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hob-spot-shots="):
			dir = String(a).substr(17)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	d["tutorial"]["home"] = true
	d["gems"] = 300
	home = await main._hb_home()
	for i in 1200:
		if home.hob != null and is_instance_valid(home.hob.node) and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	FarmTutorial.skip()
	await main.get_tree().create_timer(4.0).timeout      # (the arrival clouds clear, even on a loaded box)
	var hp: Vector3 = home.hob.pos
	home.hob.node.position = hp
	var sc := HomeLayout.deco_center(HomeLayout.fixtures(Save.d, "stall")[0])
	var to_hob := Vector3(hp.x - sc.x, 0, hp.z - sc.z).normalized()
	for kk in home.kins:
		kk["pos"] = Vector3(-500, 0, -500)
	_look((hp + sc) * 0.5, sc + to_hob * 1.6, 1.1)
	await main.get_tree().create_timer(0.8).timeout
	await _shot("1_prompt", "at the stall, toward Hob: prompt '%s' (Hob %.1f m from the stall centre)"
			% [String(home.interact.get("kind", "")), Vector2(hp.x - sc.x, hp.z - sc.z).length()])
	home.hb.toggle()
	home.hb.take("crop_patch")
	var at := _beside(hp, to_hob)
	_look(hp, hp - to_hob * 3.0 + Vector3(0, 0, 2.0), 1.1)
	await main.get_tree().create_timer(0.6).timeout
	home.hb.debug_m = Vector2(at.x, at.z)
	home.hb.tick(0.0)
	await _shot("2_build", "a crop patch beside Hob: ok=%s '%s'" % [home.hb.ghost_ok, home.hb.why])
	main.get_tree().quit(0)


## The nearest point 2-3.4 m from Hob (the side away from the stall first) where the only thing against a crop
## patch could be Hob's ring: open, buildable ground, so the shot shows green before and "Too close to Hob" after.
func _beside(hp: Vector3, away: Vector3) -> Vector3:
	for r in [2.0, 2.5, 3.0, 3.4]:
		for a in 16:
			var k := ((a + 1) >> 1) * (1 if a % 2 == 1 else -1)      # (0, 1, -1, 2, -2...)
			var at: Vector3 = hp + away.rotated(Vector3.UP, TAU * k / 16.0) * r
			home.hb.debug_m = Vector2(at.x, at.z)
			home.hb.tick(0.0)
			if home.hb.why in ["", "Too close to Hob"]:
				return at
	return hp + away * 2.6


func _look(target: Vector3, stand: Vector3, zoom: float) -> void:
	home.ppos = stand
	home.player.position = stand
	home.cam.zoom_to = zoom
	home.cam.zoom = zoom
	home.cam.snap(target)


func _shot(shot_name: String, what: String) -> void:
	for i in 3:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
		for i in 600:      # (the arrival ink may still be sweeping out on a loaded box)
			if main.fade.rect.color.a <= 0.01:
				break
			await main.get_tree().process_frame
	await main.get_tree().create_timer(0.3).timeout
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("HOBSPOTSHOT %s %s" % [shot_name, what])
