extends RefCounted
## --evolve-moment-check: the evolve moment at home (EvolveMoment): about 2.2 s: the old form curls up in
## the type colour, a silhouette morph to the new form, which does its pose, the glow fades, the camera eases in,
## soft sparkles, Boki nearby
## turn to watch, no burst or ring, and a Boki off screen gets no moment. Works headless.
## --evolve-moment-shots --shots-dir=<dir>: one sheet per type (needs a renderer, xvfb with opengl3).

const SHOT_TYPES := ["titan", "lunar", "prism"]    # three type colours: sand, pale blue, pink
const SHOT_TIMES := [0.0, 0.5, 0.8, 1.0, 1.4, 2.2]
const CROP := 300          # px square around the Boki in a sheet cell
const STEP := 0.05         # s per hand-driven step

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("EVOLVEMOMENT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node, mode: String = "check") -> void:
	Save.no_write = true
	var stage := _stage(main, mode == "shots")
	if mode == "shots":
		await _shots(main, stage)
	else:
		_check(main, stage)
	main.get_tree().quit(bad)

## A bare stage: ground, light, camera, an Fx.
func _stage(main: Node, rendered: bool) -> Dictionary:
	var host := Node3D.new()
	var vp: SubViewport = null
	if rendered:
		vp = SubViewport.new()
		vp.size = Vector2i(CROP * 2, CROP * 2)
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		main.add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Look.environment({"top": Color("2a4a8a"), "mid": Color("6a8ad0"),
			"horizon": Color("ffd2a8"), "stars": 0.0})
		vp.add_child(env)
		vp.add_child(host)
	else:
		main.add_child(host)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 1.7, 2.6)
	cam.look_at_from_position(cam.position, Vector3(0, 0.5, 0), Vector3.UP)
	cam.current = true
	var sun := DirectionalLight3D.new()
	host.add_child(sun)
	sun.rotation_degrees = Vector3(-50, 30, 0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("6c9a4c")
	ground.material_override = gm
	host.add_child(ground)
	var fx := Fx.new()
	host.add_child(fx)
	return {"host": host, "cam": cam, "fx": fx, "vp": vp}

func _species_of(type: String) -> String:
	for spk in Data.KIN:
		if DexView.type_of(spk) == type:
			return spk
	return "zapple"

func _make(stage: Dictionary, spk: String, watcher: bool) -> EvolveMoment:
	var m := EvolveMoment.new()
	m.host = stage["host"]
	m.fx = stage["fx"]
	# a real first evolution: the hatchling (small, evo_scale) grows its first form at level 4
	var rec := Save.new_kin(spk, "A")
	m.old = Models.kin(spk, rec)
	var grown := rec.duplicate(true)
	grown["level"] = 4
	Evo.on_level(grown)
	m.fresh = Models.kin(spk, grown)
	m.col = DexView.type_col(DexView.type_of(spk))
	m.host.add_child(m.old)
	if watcher:
		var w := Models.kin("zapple", Save.new_kin("zapple", "W"))
		w.position = Vector3(2.5, 0, 0)
		w.rotation.y = -PI * 0.5     # facing away from the middle
		m.host.add_child(w)
		m.watchers = [{"node": w}]
	m.start()
	return m

func _check(_main: Node, stage: Dictionary) -> void:
	var fx: Fx = stage["fx"]
	var m := _make(stage, _species_of("titan"), true)
	var w: Node3D = m.watchers[0]["node"]
	var facing_before := absf(angle_difference(w.rotation.y, atan2(w.position.x, w.position.z)))
	var radial := fx.radial
	var peak := 0.0
	var wash_peak := 0.0
	var wash_mid := 0.0
	var swap_t := -1.0
	var t := 0.0
	var curled_y := 1.0
	var posed := false
	var cam_in := 0.0
	var rig := CamRig.new()
	var cam_zoom := 1.0
	while t < EvolveMoment.LENGTH:
		t += STEP
		m.step(minf(t, EvolveMoment.LENGTH))
		if not m.swapped:
			curled_y = m.old.scale.y / m.base.y
		posed = posed or (m.fresh.get_meta("kact", "") == "hop" and m.fresh.get_meta("face", "") == "happy")
		cam_in = maxf(cam_in, m.look)
		if absf(t - EvolveMoment.SWAP_AT) < STEP * 0.5:
			m.frame(rig, Vector3.ZERO, 1.0)
			cam_zoom = rig.zoom_to
		var cur: Node3D = m.fresh if m.swapped else m.old
		peak = maxf(peak, cur.scale.x / maxf(m.base.x, m.grown.x))
		wash_peak = maxf(wash_peak, m.wash.albedo_color.a)
		if m.swapped and swap_t < 0.0:
			swap_t = t
		if absf(t - EvolveMoment.SWAP_AT) < STEP * 0.5:
			wash_mid = m.wash.albedo_color.a
	var len_s := EvolveMoment.LENGTH
	var swap_at := EvolveMoment.SWAP_AT
	ok(len_s >= 1.8 and len_s <= 2.6, "the moment is about 2 s (%.2f)" % len_s)
	ok(peak >= 1.1 and peak <= 1.2, "the silhouette swells to %.2fx" % peak)
	var curl_clip := String(m.old.get_meta("kstate", ""))
	var curl_msg := "the old form curls up (squash %.2f, kstate %s)" % [curled_y, curl_clip]
	ok(curled_y < 0.9 and curl_clip == "sleep", curl_msg)
	ok(posed and cam_in > 0.9 and cam_zoom < 1.0 and m.look < 0.01, "the new form poses, the camera eases in and back")
	ok(wash_peak >= 0.8 and wash_mid >= 0.8, "the type colour washes over it to %.2f" % wash_peak)
	ok(absf(swap_t - swap_at) <= STEP + 0.01, "the morph to the new form starts (%.2f s)" % swap_t)
	ok(m.fresh.visible and not m.old.visible, "the new form is shown and the old one hidden")
	var settled := absf(m.fresh.scale.x - m.grown.x) < 0.01
	var played: bool = m.sparkled == EvolveMoment.SPARKLE_AT.size()
	ok(m.wash.albedo_color.a < 0.01 and played and settled, "the glow is gone, sparkles played, size settled")
	ok(fx.radial == radial, "no burst or ring (radial stays %d)" % radial)
	var facing_after := absf(angle_difference(w.rotation.y, atan2(w.position.x, w.position.z)))
	var turned := "(%.2f -> %.2f)" % [facing_before, facing_after]
	ok(facing_before > 1.0 and facing_after < 0.15, "a Boki nearby turns to watch " + turned)
	var ratio := m.grown.x / m.base.x
	var want := float(m.fresh.get_meta("evo_scale", 1.0)) / float(m.old.get_meta("evo_scale", 1.0))
	var grew := ratio > 1.1 and absf(ratio - want) < 0.01
	ok(grew, "the hatchling ends at its grown size, home's own scale (%.2fx), no snap" % ratio)
	m.finish()
	rig.free()
	var gone: bool = m.light.is_queued_for_deletion() and m.old.is_queued_for_deletion()
	var no_pose := not m.fresh.has_meta("kact") and not m.fresh.has_meta("face")
	ok(not _washed(m.fresh) and gone and no_pose, "the wash, light and pose come off, the old model goes")
	var cam: Camera3D = stage["cam"]
	var seen := EvolveMoment.on_screen(cam, Vector3.ZERO)
	var far := EvolveMoment.on_screen(cam, Vector3(60, 0, 0))
	var behind := EvolveMoment.on_screen(cam, Vector3(0, 0, 40))
	ok(seen and not far and not behind, "in view gets the moment, off screen and behind the camera do not")
	var plain := Node3D.new()
	var bodied := Node3D.new()
	bodied.add_child(MeshInstance3D.new())
	(bodied.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	var modelled := EvolveMoment.has_model(m.fresh) and EvolveMoment.has_model(bodied)
	ok(modelled and not EvolveMoment.has_model(plain), "a form with no model never plays the moment")
	plain.free()
	bodied.free()
	var kins := [{"node": w}, {"node": m.fresh, "indoors": true}, {"node": m.old, "busy": true}]
	var near := EvolveMoment.watchers_of(kins, {}, Vector3.ZERO)
	var self_only := EvolveMoment.watchers_of(kins, kins[0], Vector3.ZERO)
	ok(near.size() == 1 and self_only.is_empty(), "only idle outdoor Boki close by watch, never the one changing")
	var src := FileAccess.get_file_as_string("res://scripts/home/home.gd")
	var body := src.substr(src.find("func _play_evolutions"), 2600)
	body = body.substr(0, body.find("# ---- buildings"))
	ok(not "fx.burst" in body and not "fx.ring" in body, "home's evolve path calls no burst or ring")
	print("EVOLVEMOMENT DONE, failures: %d" % bad)

func _washed(n: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).material_overlay != null:
		return true
	for c in n.get_children():
		if _washed(c): return true
	return false

## One sheet per type: the moment at SHOT_TIMES, side by side.
func _shots(main: Node, stage: Dictionary) -> void:
	var dir := "user://"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if main.fade:
		main.fade.reveal(0.05)
	for type in SHOT_TYPES:
		var spk := _species_of(type)
		var m := _make(stage, spk, true)
		var sheet := Image.create(CROP * SHOT_TIMES.size(), CROP, false, Image.FORMAT_RGBA8)
		var t := 0.0
		for i in SHOT_TIMES.size():
			while t < SHOT_TIMES[i]:
				t = minf(t + STEP, SHOT_TIMES[i])
				m.step(t)
				await main.get_tree().create_timer(STEP).timeout
			m.step(t)
			for f in 3:
				await RenderingServer.frame_post_draw
			var img: Image = (stage["vp"] as SubViewport).get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var c: Vector2 = (stage["cam"] as Camera3D).unproject_position(Vector3(0, 0.5, 0))
			sheet.blit_rect(img, Rect2i(int(c.x) - CROP / 2, int(c.y) - CROP / 2, CROP, CROP), Vector2i(CROP * i, 0))
		sheet.save_png("%s/evolve_%s_%s.png" % [dir, type, spk])
		print("SHOT evolve %s %s" % [type, spk])
		m.finish()
		m.fresh.queue_free()
		for k in m.watchers:
			(k["node"] as Node3D).queue_free()
		await main.get_tree().process_frame
