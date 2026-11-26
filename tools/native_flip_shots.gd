extends "res://tools/clip_shots.gd"
## --native-flip-shots --shots-dir=<dir> [--size=480]: Sable's Vault flips on her Meshy-native model (WardenNativeFlip)
## in the game's renderer, one still per beat of the 0.48 s dash (press, push-off, quarter, top, three quarters,
## landing crouch, upright, then 0.15 s on into the run): <dir>/<kmove>/f##_<ms>.png. The camera looks across the way
## she dashes, so the turn is drawn side on. The match's own timing is --native-flip-check's. Needs a renderer.

const DT := 1.0 / 60.0
const BEATS := [0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.36, 0.48, 0.63]  # s on the move's clock
## kmove -> [the way she dashes (x, z; she faces -Z), the camera's place]
const FLIPS := {
	"thf_vault_r": [Vector2(1, 0), Vector3(0.0, 1.0, 6.5)],
	"thf_vault_f": [Vector2(0, -1), Vector3(6.5, 1.0, 0.0)],
	"thf_vault_twist": [Vector2(1, 0), Vector3(0.0, 1.0, 6.5)],
}
const DASH_MPS := 9.4  # the Vault's mean speed (4.5 m / 0.48 s)
const RUN_MPS := 5.5


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 34.0
	for km in FLIPS:
		await _flip(String(km), out.path_join(String(km)))
	print("NATIVE_FLIP_SHOTS_DONE")
	tree.quit()


func _flip(km: String, dir: String) -> void:
	var way: Vector2 = FLIPS[km][0]
	cam.position = FLIPS[km][1]
	cam.look_at(Vector3(0, 0.75, 0))
	var model := Models.hunter(
		Arch.weight("thief"), Data.TEAM_COLORS[0], "arc_bolts", "", PlayerLook.neutral(), "thief"
	)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var poser := model.get_node("Warden/Native")
	poser.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	var run_v := Vector3(way.x, 0.0, way.y) * RUN_MPS
	var base := {"grounded": true, "face": 0.0, "cast": 99.0, "vel": run_v}
	for k in 30:
		model.set_meta(WardenClips.STATE, base)
		poser.call("_process", DT)
	var t := 0.0
	var beat := 0
	while beat < BEATS.size():
		var s := base.duplicate()
		var dash := t < 0.48
		s["kmove"] = km
		s["kmove_t"] = t
		s["rolling"] = dash
		s["dash_dir"] = way
		s["vel"] = Vector3(way.x, 0.0, way.y) * (DASH_MPS if dash else RUN_MPS)
		s["swing_n"] = 0
		model.set_meta(WardenClips.STATE, s)
		poser.call("_process", DT)
		if t >= float(BEATS[beat]) - DT * 0.5:
			await _grab(dir.path_join("f%02d_%03dms.png" % [beat, roundi(t * 1000.0)]))
			beat += 1
		t += DT
	model.queue_free()
	await tree.process_frame
