extends RefCounted
## --gil-swim-spin-shots --shots-dir=<dir>: Gil's Ground Swim and Riptide in a real Match, one PNG a frame (needs a
## renderer). swim_*: a swim started east with the keys turned north at 0.1 s (the steer, the waist-deep crawl, the
## wake along the curve, the surfacing), close up and at the gameplay camera. spin_early_* / spin_late_*: four
## frames in a row 0.25 s and 1.75 s into the spin, so the turn per frame shows the wind-up.

const DT := 1.0 / 60.0
const SWIM_AT := [0.05, 0.12, 0.2, 0.28, 0.36, 0.46, 0.6, 0.85]  # s after the dash press
const CLOSE := 0.38  # the close-up camera's distance, a share of the gameplay one

var main: Node
var out := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var a_v = load("res://tools/archetype_check.gd").new()
	a_v.main = main
	var r: Array = a_v.setup("gil", 14.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	(r[2] as Hunter).ctrl = "idle"
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_clear_view(m, p)
	var home := p.pos
	for view in ["close", "game"]:
		m.cam.dist_mul = CLOSE if view == "close" else 1.0
		p.teleport(home)
		await _swim(m, p, view)
	m.cam.dist_mul = CLOSE
	p.teleport(home)
	await _spin(m, p)
	print("GIL_SWIM_SPIN_SHOTS_DONE")
	main.get_tree().quit(0)


func _swim(m: Match, p: Hunter, view: String) -> void:
	_aim(p, Vector3(8.0, 0, 0))
	for f in 30:
		await _step(m, p)
	p.ak.cd["dash"] = 0.0
	p.dashes = p.max_dashes()
	p.inp["move"] = Vector2(1, 0)
	p.ak.on_dash(false)
	var t := 0.0
	var shot := 0
	for want in SWIM_AT:
		while t < float(want):
			if t >= 0.1:
				p.inp["move"] = Vector2(0, -1)  # north, up the screen
			await _step(m, p)
			t += DT
		await _save("swim_%s_%02d" % [view, shot])
		shot += 1
	p.inp["move"] = Vector2.ZERO
	for f in 60:
		await _step(m, p)


func _spin(m: Match, p: Hunter) -> void:
	_aim(p, Vector3(8.0, 0, 0))
	for f in 30:
		await _step(m, p)
	p.ak.cd["e"] = 0.0
	p.ak.use_e()
	var t := 0.0
	for tag in ["early", "late"]:
		var start := 0.25 if tag == "early" else 1.75
		while t < start:
			await _step(m, p)
			t += DT
		for i in 4:
			await _step(m, p)
			t += DT
			await _save("spin_%s_%d" % [tag, i])


func _aim(p: Hunter, rel: Vector3) -> void:
	p.inp["aim"] = p.pos + rel + Vector3(0, 0.9, 0)
	p.inp["aim_y"] = p.pos.y


func _save(file: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(out.path_join(file + ".png"))


## Trees and rocks would hide the ground: everything standing above it goes for the shot, but the hunters.
func _clear_view(m: Match, p: Hunter) -> void:
	for g in m.find_children("*", "GeometryInstance3D", true, false):
		var n := g as GeometryInstance3D
		if p.is_ancestor_of(n):
			continue
		if n.global_transform.origin.y > p.pos.y + 0.4 or n is MultiMeshInstance3D:
			n.visible = false


func _step(m: Match, p: Hunter) -> void:
	m.step(DT)
	p.render(DT, 1.0)
	m.cam.snap(p.pos)
	await main.get_tree().process_frame
