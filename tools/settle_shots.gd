extends "res://tools/idle_shots.gd"
## --hair-gallery --settle --shots-dir=<dir> [--wardens=a,b] [--size=320]: the spring chains of every v2 Hero
## through the --spring-settle-check scenarios (a dash stop, a jump's landing, a sharp turn), filmed from the
## side on the upper body at 30 fps from 0.3 s before the event to 1.2 s after: <dir>/<id>/<scene>/f000.png...
## (docs/art/secondary_motion/README.md makes the strips and clips). Needs a renderer.

const Settle := preload("res://tools/spring_settle_check.gd")
const BEFORE := 0.3           # s filmed before the event
const AFTER := 1.2            # and after it

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = WardenGlb.ART.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--wardens="): ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	for k in 30:
		await tree.process_frame       # (past the title's fade)
	for id in ids:
		for sc in Settle.SCENES:
			await _scene(String(id), String(sc), out.path_join(String(id)).path_join(String(sc)))
	print("SETTLE_SHOTS_DONE ", ids.size())
	tree.quit()

func _scene(id: String, sc: String, dir: String) -> void:
	var m := Settle.model(id, holder)
	if m == null:
		return
	var ring := m.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	sync.set_process(false)
	var tall := _height(m)
	DirAccess.make_dir_recursive_absolute(dir)
	var ev: float = Settle.SCENES[sc][0]
	var i := 0
	for f in int((ev + AFTER) / Settle.DT):
		var pose := Settle.at(sc, f * Settle.DT)
		m.position = pose[0]
		m.rotation.y = pose[1]
		sync._process(Settle.DT)
		if f * Settle.DT >= ev - BEFORE and f % 2 == 0:
			var at := Vector3(m.position.x, m.position.y + tall * 0.7, m.position.z)     # (the upper body)
			cam.position = at + Vector3(tall * 1.5, tall * 0.05, 0)
			cam.look_at(at)
			await _grab(dir.path_join("f%03d.png" % i))
			i += 1
	m.queue_free()
	await tree.process_frame
