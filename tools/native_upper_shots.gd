extends "res://tools/clip_shots.gd"
## --native-upper-shots --shots-dir=<dir> [--size=480] [--ids=a,b] [--mode=swing|left|right|back] [--view=match|eye] [--zoom=1.0]: each native Hunter
## running at 4.6 m/s, a frame every 1/30 s to 1.2 s: <dir>/<id>/f###.png. swing: a side view, a swing pressed 0.3 s in.
## left, right (strafe) and back: aim -Z (up the screen at --view=match, the game's angle), moving -X, +X, +Z. --view=
## match (default) or eye (a front three-quarter view at eye level). Needs a renderer.

const DT := 1.0 / 30.0
const PRESS := 0.3  # s into the run the swing starts
const SECS := 1.2
const RUN := 4.6  # m/s
const IDS := ["mage", "juggernaut", "archer", "dredge"]
## mode -> [velocity, the Hunter's yaw]
const MODES := {
	"swing": [Vector3(0, 0, -RUN), 90.0],
	"left": [Vector3(-RUN, 0, 0), 0.0],
	"right": [Vector3(RUN, 0, 0), 0.0],
	"back": [Vector3(0, 0, RUN), 0.0],
}
## view -> [fov, the camera, what it looks at]
const VIEWS := {
	"swing": [30.0, Vector3(5.0, 1.2, 0.0), Vector3(0, 0.9, 0)],
	"match": [6.5, Vector3(0.0, 21.0, 9.4), Vector3(0, 0.8, 0)],
	"eye": [30.0, Vector3(3.0, 1.3, -4.5), Vector3(0, 0.9, 0)],
}
var mode := "swing"
var view := "match"
var zoom := 1.0  # the lens widens by this much (a tall Hunter)


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = IDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a.begins_with("--mode="):
			mode = a.substr(7)
		if a.begins_with("--view="):
			view = a.substr(7)
		if a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		if a.begins_with("--ids="):
			ids = a.substr(6).split(",")
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	var v: Array = VIEWS["swing" if mode == "swing" else view]
	cam.fov = v[0] * zoom
	cam.position = v[1]
	cam.look_at(v[2] + Vector3(0, 0.5 * (zoom - 1.0), 0))
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)))
	print("NATIVE_UPPER_SHOTS_DONE")
	tree.quit()


func _hunter(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	model.rotation.y = deg_to_rad(float(MODES[mode][1]))
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var poser := model.get_node("Warden/Native")
	poser.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	var base := {"grounded": true, "face": model.rotation.y, "cast": 99.0, "vel": MODES[mode][0]}
	for k in 20:
		model.set_meta(WardenClips.STATE, base)
		poser.call("_process", DT)
	for i in int(SECS / DT):
		var s := base.duplicate()
		if mode == "swing" and i * DT >= PRESS:
			s["swing_n"] = 1
			s["combo"] = 0
			s["cast"] = 0.0
		model.set_meta(WardenClips.STATE, s)
		poser.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
	model.queue_free()
	await tree.process_frame
