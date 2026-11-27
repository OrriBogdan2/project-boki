extends RefCounted
## --neve-lmb-shots --shots-dir=<dir>: Neve (rimewright) holding LMB for HOLD s at a dummy STRAFE m/s sideways DIST m
## ahead, in a real Match, then letting go. body_##.png: a side close-up of her every BODY_EVERY frames (the cast
## motion); top_##.png: the match from above every TOP_EVERY frames (the darts' arcs); paths.csv: every dart's position
## each frame (sid,t,x,z) and the dummy's (sid -1). Needs a renderer.

const DT := 1.0 / 60.0
const DIST := 9.0  # m to the dummy
const STRAFE := 4.0  # m/s: the dummy's sideways run, reversing every FLIP s
const FLIP := 0.6
const HOLD := 1.0  # s LMB is held
const SECS := 1.8  # s recorded
const BODY_EVERY := 4  # frames between body shots (1/15 s)
const TOP_EVERY := 6  # frames between top shots (0.1 s)


func run(main: Node) -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	Save.no_write = true
	var ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("rimewright", DIST)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var k: RimewrightKit = p.ak
	HeroVfx.of(m)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(640, 640)
	var tree := main.get_tree()
	for g in m.find_children("*", "GeometryInstance3D", true, false):  # (trees and rocks off the strip's view)
		var n := g as GeometryInstance3D
		if n.global_transform.origin.y > p.pos.y + 0.4 or n is MultiMeshInstance3D:
			if not p.is_ancestor_of(n) and not t.is_ancestor_of(n):
				n.visible = false
	var side := Camera3D.new()
	side.fov = 34.0
	m.add_child(side)
	var top := Camera3D.new()
	top.fov = 50.0
	m.add_child(top)
	var mid := p.pos + Vector3(DIST * 0.5, 0, 0)
	top.look_at_from_position(mid + Vector3(0, 12.0, 0.01), mid)
	var poser := p.model.get_node("Warden/Native")
	poser.set_process(false)  # (her clips step with the sim, DT a frame, whatever the window's frame time)
	for f in 30:
		ac.aim_at(p, t.pos)
		await _step(m, p, poser, tree)
	var csv := FileAccess.open(out.path_join("paths.csv"), FileAccess.WRITE)
	csv.store_line("sid,t,x,z")
	var way := 1.0
	for f in int(SECS / DT):
		var now := f * DT
		way = 1.0 if fmod(now, FLIP * 2.0) < FLIP else -1.0
		t.teleport(t.pos + Vector3(0, 0, way * STRAFE * DT))
		ac.aim_at(p, t.pos)
		p.inp["fire"] = now < HOLD
		if f % BODY_EVERY == 0:
			var at := p.model.global_position
			side.look_at_from_position(at + Vector3(-1.2, 1.3, 3.4), at + Vector3(0.3, 1.0, 0))
			side.make_current()
		elif f % TOP_EVERY == 3:
			top.make_current()
		await _step(m, p, poser, tree)
		if f % BODY_EVERY == 0:
			await _grab(main, out.path_join("body_%02d.png" % (f / BODY_EVERY)))
		elif f % TOP_EVERY == 3:
			await _grab(main, out.path_join("top_%02d.png" % ((f - 3) / TOP_EVERY)))
		csv.store_line("-1,%.4f,%.3f,%.3f" % [now, t.pos.x, t.pos.z])
		for d in k.darts:
			var s: Dictionary = d["s"]
			csv.store_line("%d,%.4f,%.3f,%.3f" % [int(s.get("sid", 0)), now, s["pos"].x, s["pos"].z])
	csv.close()
	print("NEVE_LMB_SHOTS_DONE darts %d" % k.stats["darts"])
	tree.quit(0)


## The frame just stepped, as drawn (the camera was made current before the step).
func _grab(main: Node, path: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(path)


func _step(m: Match, p: Hunter, poser: Node, tree: SceneTree) -> void:
	m.step(DT)
	p.render(DT, 1.0)
	poser.call("_process", DT)
	await tree.process_frame
