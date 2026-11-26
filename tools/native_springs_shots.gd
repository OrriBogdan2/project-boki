extends "res://tools/clip_shots.gd"
## --native-springs-shots --warden=<id> --shots-dir=<dir> [--no-springs] [--size=512]: a Meshy-native Hunter's loose
## parts (WardenSprings on data "springs") in motion: it runs, turns, lunges (the swing clip, still moving) and stops,
## from the game's own angle (<dir>/match/) and from eye level, behind and to the side (<dir>/eye/); a frame every
## 1/FPS s, phases.json names the frame each phase starts at. --no-springs: the live model (the clips' keys only).
## Needs a renderer.

const FPS := 15.0
const DT := 1.0 / FPS
const RUN_MPS := 5.5
const SPEEDS := {"lunge": 3.5, "stop": 0.0}  # phase -> m/s (the others run at RUN_MPS)
## [phase, seconds, the heading's change over them (degrees)]
const PHASES := [["run", 2.0, 0.0], ["turn", 0.7, 135.0], ["run2", 0.6, 0.0], ["lunge", 1.0, 0.0], ["stop", 1.4, 0.0]]
const VIEWS := {"match": [8.0, Vector3(0.0, 21.0, 9.4), 0.8], "eye": [30.0, Vector3(1.5, 1.45, 3.3), 0.95]}


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var id := "thief"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--warden="):
			id = a.substr(9)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a == "--no-springs":
			(WardenNative.entry(WardenGlb.art(id)) as Dictionary).erase("springs")
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	var starts := {}
	for view in VIEWS:
		var model := Models.hunter(
			Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id
		)
		holder.add_child(model)
		var ring := model.get_node_or_null("TeamRing") as Node3D
		if ring:
			ring.visible = view == "match"
		for k in 30:
			await tree.process_frame  # (past the title's fade)
		starts = await _film(model, view, out.path_join(view))
		model.queue_free()
	var f := FileAccess.open(out.path_join("phases.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(starts))
	print("NATIVE_SPRINGS_SHOTS_DONE")
	tree.quit()


## The run, turn, lunge and stop of PHASES for one view: the model travels (the springs need the motion), the camera
## keeps its offset from it.
func _film(model: Node3D, view: String, dir: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(dir)
	var nat := model.get_node("Warden/Native") as WardenNative
	nat.set_process(false)
	var vw: Array = VIEWS[view]
	cam.fov = float(vw[0])
	var heading := 0.0
	var swing_n := 0
	var starts := {}
	var i := 0
	var warm := {"grounded": true, "cast": 99.0, "vel": Vector3(0.0, 0.0, -RUN_MPS)}
	model.set_meta(WardenClips.STATE, warm)
	for k in 30:
		_advance(model, nat, warm, 0.0, DT)
	for ph in PHASES:
		starts[ph[0]] = i
		for k in int(float(ph[1]) * FPS):
			heading += deg_to_rad(float(ph[2])) / (float(ph[1]) * FPS)
			var mps: float = SPEEDS.get(ph[0], RUN_MPS)
			var s := {"grounded": true, "cast": 99.0, "vel": Vector3(0.0, 0.0, -mps), "swing_n": swing_n}
			if ph[0] == "lunge" and k == 0:
				swing_n += 1
				s["swing_n"] = swing_n
			model.rotation.y = heading
			_advance(model, nat, s, mps, DT)
			var at := model.position + Vector3(0.0, float(vw[2]), 0.0)
			var off: Vector3 = vw[1]
			cam.position = model.position + (Basis(Vector3.UP, heading) * off if view == "eye" else off)
			cam.look_at(at)
			await _grab(dir.path_join("f%03d.png" % i))
			i += 1
	return starts


func _advance(model: Node3D, nat: WardenNative, s: Dictionary, mps: float, dt: float) -> void:
	model.set_meta(WardenClips.STATE, s)
	model.position += Basis(Vector3.UP, model.rotation.y) * Vector3(0.0, 0.0, -mps * dt)
	nat._process(dt)
