extends "res://tools/clip_shots.gd"
## --warden-states-shots --shots-dir=<dir> [--wardens=a,b] [--size=220]: every Hunter in each of the 15 ANIM_COVERAGE
## states (the ones warden_states_check drives), one frame each at the match look: <dir>/<art>/<state>.png. Needs a
## renderer; a montage of them is the contact sheet.

const StatesCheck := preload("res://tools/warden_states_check.gd")
const SHOT_FRAME := 24     # the frame of a state's run that is shown (a hit and a landing show an earlier one)
const EARLY_FRAME := 6
const SETTLE_FRAMES := 20  # frames a new model gets to load before it is driven
const SHOT_YAW := 150.0    # deg: the three-quarter view
const SHOT_DIST := 5.6     # m
const SHOT_AT_Y := 0.8     # m: the height the camera looks at

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = Arch.ORDER.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
		if a.begins_with("--wardens="):
			ids = Array(a.substr(10).split(",", false))
		if a.begins_with("--size="):
			frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 34.0
	cam.position = Vector3(0, SHOT_AT_Y + 0.7, SHOT_DIST)
	cam.look_at(Vector3(0, SHOT_AT_Y, 0))
	for id in ids:
		await _hunter(String(id), out)
	print("WARDEN_STATES_SHOTS_DONE ", ids.size())
	tree.quit()

func _hunter(id: String, out: String) -> void:
	var art := WardenGlb.art(id)
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	model.rotation.y = deg_to_rad(SHOT_YAW)
	var ring := model.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	for i in SETTLE_FRAMES:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync") as WardenGlb.Sync
	sync.set_process(false)
	var an := HunterAnim.new(model)
	var chk := StatesCheck.new()
	DirAccess.make_dir_recursive_absolute(out.path_join(art))
	for st in StatesCheck.STATES:
		var base := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true}
		chk.play(an, sync, base, 40)
		var seq: Array = chk.frames(an, sync, art, st, base)
		var at := EARLY_FRAME if st in ["hit", "land"] else SHOT_FRAME
		for i in at + 1:
			chk.play(an, sync, seq[i], 1)
		await _grab(out.path_join(art).path_join(st + ".png"))
		chk.play(an, sync, base, 30)
	model.queue_free()
