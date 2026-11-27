extends "res://tools/clip_shots.gd"
## --anim-state-shots --shots-dir=<dir> [--size=320] [--ids=a,b] [--states=idle,jump,...]: each Hunter on
## Meshy's rig held in a game state (the STATE meta, as HunterAnim hands it over) for SECS, one frame at the end:
## <dir>/<id>/<state>.png (--yaw= turns the model). Needs a renderer. States: STATES below.

const DT := 1.0 / 30.0
const SECS := 0.8  # s a state is held before its frame ("jump@0.3" holds that state 0.3 s)
const IDS := [
	"mage",
	"rimewright",
	"thief",
	"dolm",
	"dredge",
	"ashwick",
	"tender",
	"gunslinger",
	"archer",
	"juggernaut",
	"gil",
	"ostra"
]
const STATES := {
	"idle": {},
	"idle_combat": {"fired": 0.5},
	"jump": {"grounded": false, "vel": Vector3(0, 6, -2)},
	"fall": {"grounded": false, "vel": Vector3(0, -7, -2)},
	"glide": {"grounded": false, "gliding": true, "vel": Vector3(0, -2, -7)},
	"dash": {"rolling": true, "vel": Vector3(0, 0, -9)},
	"down_hit": {"fall": 0.25},  # the knocked-down beat (HunterFall k): shoved off the hit
	"down": {"fall": 0.6},  # on the knees
	"down_end": {"fall": 0.95},  # slumped, as the body fades
	"revive": {"reviving": true},
}

var yaw := 90.0  # deg: the model's turn (--yaw=)


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = IDS
	var states: Array = STATES.keys()
	yaw = 90.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
		if a.begins_with("--ids="):
			ids = a.substr(6).split(",")
		if a.begins_with("--yaw="):
			yaw = float(a.substr(6))
		if a.begins_with("--states="):
			states = a.substr(9).split(",")
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	cam.position = Vector3(4.0, 1.4, 4.0)
	cam.look_at(Vector3(0, 0.9, 0))
	for id in ids:
		await _hunter(String(id), out.path_join(String(id)), states)
	print("ANIM_STATE_SHOTS_DONE")
	tree.quit()


func _hunter(id: String, dir: String, states: Array) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	model.rotation.y = deg_to_rad(yaw)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var poser := model.get_node("Warden/Native")
	poser.set_process(false)
	DirAccess.make_dir_recursive_absolute(dir)
	for st in states:
		var s := {"grounded": true, "face": model.rotation.y, "cast": 99.0, "vel": Vector3.ZERO, "fired": 99.0}
		s.merge(STATES[String(st).get_slice("@", 0)], true)
		var secs := float(String(st).get_slice("@", 1)) if "@" in st else SECS
		for i in int(secs / DT):
			model.set_meta(WardenClips.STATE, s)
			poser.call("_process", DT)
		await _grab(dir.path_join("%s.png" % st))
	model.queue_free()
	await tree.process_frame
