extends RefCounted
## --nook-moment-check: the pairing beat at the Nesting Nook (NookMoment): both Boki walk to the nest, face
## each other, nuzzle, circle once, settle side by side, the egg fades in between them with a glow, an unstable
## mix wobbles the egg, any key skips, the beat ends with the egg in the nest and writes nothing to the save.
## Works headless.
## --nook-moment-shots --shots-dir=<dir>: a day sheet and a night sheet (needs a renderer, xvfb with opengl3).

const SHOT_TIMES := [0.0, 0.9, 1.7, 2.4, 3.0, 3.4, 3.8]    # s into the beat (the walk is 1.5 s at most)
const CROP := 300          # px square around the nest in a sheet cell
const STEP := 0.05         # s per hand-driven step
const NEST := Vector3(0, 0, 0)
const DAY_SKY := {"top": Color("4a82d0"), "mid": Color("8ab8e8"), "horizon": Color("e8f0f8"), "stars": 0.0}
const NIGHT_SKY := {"top": Color("0a1030"), "mid": Color("1a2450"), "horizon": Color("2a3868"), "stars": 1.0}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("NOOKMOMENT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode: String = "check") -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var stage: Dictionary = load("res://tools/evolve_moment_check.gd").new()._stage(main, mode == "shots")
	(stage["cam"] as Camera3D).look_at_from_position(Vector3(0, 2.3, 3.8), Vector3(0, 0.45, 0), Vector3.UP)
	if mode == "shots":
		await _shots(main, stage)
	else:
		_check(stage)
	main.get_tree().quit(bad)

## Two kin dicts the way home keeps them, standing at `a_at` and `b_at`, and a nest with its egg.
func _scene(stage: Dictionary, a_at: Vector3, b_at: Vector3) -> Dictionary:
	var host: Node3D = stage["host"]
	var kins: Array = []
	for at: Vector3 in [a_at, b_at]:
		var rec := Save.new_kin("cindle" if kins.is_empty() else "puddlet", "K%d" % kins.size())
		var node := Models.kin(rec["species"], rec)
		node.position = at
		host.add_child(node)
		kins.append({"rec": rec, "node": node, "pos": at, "vel": Vector3.ZERO, "goal": at})
	var nest := Models.nest_egg(Color("ff9a6a"), Color("fff6c0"))
	host.add_child(nest)
	return {"kins": kins, "nest": nest, "uids": [kins[0]["rec"]["uid"], kins[1]["rec"]["uid"]]}

func _play(stage: Dictionary, s: Dictionary, unstable: bool) -> NookMoment:
	var host: Node3D = stage["host"]
	var m := NookMoment.play(host, stage["fx"], s["kins"], s["uids"], s["nest"], Color("ff9a6a"), unstable)
	if m != null:
		m.tween.kill()      # checks step it by hand
	return m

## Runs the whole beat by hand; returns what it saw.
func _run(m: NookMoment) -> Dictionary:
	var seen := {"moved": 0.0, "nuzzled": false, "faced": 9.0, "turned": 0.0, "slept": false, "egg_t": -1.0,
		"glow": 0.0, "wobble": 0.0, "zoom": 1.0, "look": 0.0, "busy": true, "egg_before": true}
	var rig := CamRig.new()
	var a: Node3D = m.pair[0]["node"]
	var b: Node3D = m.pair[1]["node"]
	var last := a.position
	var walk_end := m.walk
	var t := 0.0
	while t < m.length:
		t = minf(t + STEP, m.length)
		m.step(t)
		m.frame(rig, Vector3.ZERO, 1.0)
		seen["busy"] = seen["busy"] and m.pair[0]["busy"] and m.pair[1]["busy"]
		if t < walk_end:
			seen["moved"] += last.distance_to(a.position)
			last = a.position
		if t < walk_end and m.shell.visible:
			seen["egg_before"] = false
		if t >= walk_end + NookMoment.FACE_TIME + 0.1 and t <= walk_end + NookMoment.FACE_TIME + 0.2:
			var to_b := b.position - a.position
			seen["faced"] = minf(seen["faced"], absf(angle_difference(a.rotation.y, atan2(-to_b.x, -to_b.z))))
		seen["nuzzled"] = seen["nuzzled"] or (a.get_meta("happy") and b.get_meta("happy"))
		seen["slept"] = seen["slept"] or (a.get_meta("kstate") == "sleep" and b.get_meta("kstate") == "sleep")
		if m.shell.visible and seen["egg_t"] < 0.0:
			seen["egg_t"] = t
		seen["glow"] = maxf(seen["glow"], m.wash.albedo_color.a)
		seen["wobble"] = maxf(seen["wobble"], absf(m.shell.rotation.z))
		seen["zoom"] = minf(seen["zoom"], rig.zoom_to)
		seen["look"] = maxf(seen["look"], m.look)
	rig.free()
	return seen

func _check(stage: Dictionary) -> void:
	var save_before := JSON.stringify(Save.d)
	var s := _scene(stage, Vector3(-4, 0, 3), Vector3(3, 0, 4))
	var m := _play(stage, s, false)
	ok(m != null, "two idle Boki near the nest get the beat")
	var a: Node3D = m.pair[0]["node"]
	var b: Node3D = m.pair[1]["node"]
	ok(m.length >= 3.0 and m.length <= 4.2, "it is 3 to 4 s (%.2f)" % m.length)
	ok(not m.shell.visible and m.pair[0]["busy"], "the egg is not there yet and the parents are held")
	var seen := _run(m)
	ok(seen["busy"] and seen["egg_before"], "they stay held and no egg shows during the walk")
	ok(seen["moved"] > 3.0, "they walk to the nest (%.1f m)" % seen["moved"])
	ok(seen["faced"] < 0.1, "they face each other (off by %.2f rad)" % seen["faced"])
	ok(seen["nuzzled"] and seen["slept"], "they nuzzle (happy hop) and settle (nap clip)")
	var side := a.position.distance_to(b.position)
	ok(absf(side - NookMoment.SIDE * 2.0) < 0.05, "they end side by side with the egg between (%.2f m apart)" % side)
	var settle_at := m.length - NookMoment.SETTLE_TIME
	var appeared: float = seen["egg_t"]
	var on_time := absf(appeared - settle_at - STEP * 0.5) < STEP * 0.5 + 0.01
	ok(on_time, "the egg appears as they settle (%.2f s)" % appeared)
	ok(seen["glow"] > 0.6 and seen["wobble"] < 0.001, "it fades in with a glow and a steady mix does not wobble")
	ok(seen["look"] > 0.9 and seen["zoom"] < 1.0, "the camera eases in (zoom %.2f)" % seen["zoom"])
	m.finish()
	var egg_in := m.shell.visible and m.shell.scale.is_equal_approx(Vector3.ONE) and m.shell.rotation.is_zero_approx()
	var clean := not a.has_meta("kstate") and not a.has_meta("happy") and not b.has_meta("face")
	var freed: bool = not m.pair[0]["busy"] and not m.pair[1]["busy"]
	ok(egg_in and clean and freed, "it ends with the egg in the nest and the Boki free")
	ok(not m.running and m.light.is_queued_for_deletion(), "the light goes")
	ok(JSON.stringify(Save.d) == save_before, "the save is the same as without the beat")
	var near := _scene(stage, Vector3(-1, 0, 2), Vector3(1, 0, 2))
	var m2 := _play(stage, near, true)
	ok(_run(m2)["wobble"] > 0.15, "an unstable mix wobbles the egg")
	ok(m2.shell.rotation.is_zero_approx() and m2.shell.visible, "and the egg is still at the end")
	m2.finish()
	var m3 := _play(stage, _scene(stage, Vector3(-8.2, 0, 2), Vector3(3, 0, 4)), false)
	var reach := NookMoment.WALK_SPEED * NookMoment.WALK_MAX + NookMoment.SIDE
	ok(m3 != null and m3.starts[0].distance_to(NEST) <= reach + 0.01, "a Boki far off starts a short walk away")
	ok(m3.length <= 4.2, "so the beat is never longer than 4 s")
	var sk := _scene(stage, Vector3(-2, 0, 2), Vector3(2, 0, 2))
	var m4 := _play(stage, sk, true)
	m4.step(1.0)
	m4.skip()
	var skipped := not m4.running and m4.shell.visible and m4.shell.scale.is_equal_approx(Vector3.ONE)
	skipped = skipped and not m4.pair[0]["busy"]
	var a4: Node3D = m4.pair[0]["node"]
	var m5 := _play(stage, _scene(stage, Vector3(-2, 0, 2), Vector3(2, 0, 2)), true)
	_run(m5)
	m5.finish()
	var full_end: Vector3 = (m5.pair[0]["node"] as Node3D).position
	var same_end := a4.position.distance_to(full_end) < 0.01
	ok(skipped and same_end and JSON.stringify(Save.d) == save_before, "any key skips to the same end, save unchanged")
	var busy := _scene(stage, Vector3(-2, 0, 2), Vector3(2, 0, 2))
	busy["kins"][1]["indoors"] = 5.0
	var far := _scene(stage, Vector3(-2, 0, 2), Vector3(40, 0, 2))
	var none := _play(stage, busy, false) == null and _play(stage, far, false) == null
	ok(none, "a Boki indoors or far away gets no beat (the egg just appears)")
	var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	var body := src.substr(src.find("func _make_egg"), 1400)
	var after_save := body.find("Save.save_game()") < body.find("NookMoment.play")
	ok("NookMoment.play" in body and after_save, "home plays it after the egg and the save are made")
	print("NOOKMOMENT DONE, failures: %d" % bad)

## A day sheet and a night sheet: the beat at SHOT_TIMES, side by side.
func _shots(main: Node, stage: Dictionary) -> void:
	var dir := "user://"
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shots-dir="):
			dir = String(arg).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade:
		main.fade.reveal(0.05)
	var vp: SubViewport = stage["vp"]
	var env: WorldEnvironment = null
	for c in vp.get_children():
		if c is WorldEnvironment:
			env = c
	var lights := (stage["host"] as Node3D).get_children().filter(func(n: Node) -> bool: return n is DirectionalLight3D)
	var sun: DirectionalLight3D = lights[0]
	for time in ["day", "night"]:
		if time == "day":
			env.environment = Look.environment(DAY_SKY)
			sun.light_energy = 1.1
			sun.light_color = Color("fff2dc")
		else:
			env.environment = Look.environment(NIGHT_SKY)
			sun.light_energy = 0.25
			sun.light_color = Color("8aa0ff")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color("fff0d8") if time == "day" else Color("3a4a90")
		env.environment.ambient_light_energy = 0.7 if time == "day" else 0.5
		var s := _scene(stage, Vector3(-4, 0, 3), Vector3(3.5, 0, 3.5))
		var m := _play(stage, s, true)
		var sheet := Image.create(CROP * SHOT_TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
		var t := 0.0
		for i in SHOT_TIMES.size():
			while t < minf(SHOT_TIMES[i], m.length):
				t = minf(t + STEP, SHOT_TIMES[i])
				m.step(t)
				await main.get_tree().create_timer(STEP).timeout
			m.step(minf(SHOT_TIMES[i], m.length))
			for f in 3:
				await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var c: Vector2 = (stage["cam"] as Camera3D).unproject_position(Vector3(0, 0.4, 0))
			sheet.blit_rect(img, Rect2i(int(c.x) - CROP / 2, int(c.y) - CROP / 2, CROP, CROP), Vector2i(CROP * i, 0))
		sheet.save_png("%s/nook_moment_%s.png" % [dir, time])
		print("SHOT nook moment %s" % time)
		m.finish()
		for k in s["kins"]:
			(k["node"] as Node3D).queue_free()
		(s["nest"] as Node3D).queue_free()
		await main.get_tree().process_frame
