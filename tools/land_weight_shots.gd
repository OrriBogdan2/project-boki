extends "res://tools/clip_shots.gd"
## --land-weight-shots --shots-dir=<dir> [--size=480]: one Hunter per weight class (thief light, ostra medium,
## juggernaut heavy: the footage's two) taking the plain jump and the 3 m terrace drop through HunterAnim as in a
## match (its squash over the .glb land clip, WardenClips.land_play), from CAM_PITCH (lower than the match camera's 66
## deg, so the squash's height reads) at CAM_DIST, every 1/30 s into <dir>/<way>/<class>/f000.png... plus
## key.json (the landing frame).
## tools/land_weight_video.sh tiles them into <way>.mp4. Needs a renderer (jobq --needs gpu).

const DT := 1.0 / 30.0
const PICKS := {"light": "thief", "medium": "ostra", "heavy": "juggernaut"}
const CAM_DIST := 5.0  # m: the match camera is 23 m out; in this close the squash reads
const CAM_PITCH := 25.0  # deg down to the Hunter
const RUN_UP := 0.4  # s of standing before the jump
const TAIL := 0.9  # s on the ground after the landing


func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	frame_px = 480
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
	cam.position = Vector3(0, 1.2 + CAM_DIST * sin(deg_to_rad(CAM_PITCH)), CAM_DIST * cos(deg_to_rad(CAM_PITCH)))
	cam.look_at(Vector3(0, 1.2, 0))
	for way: String in ["jump", "drop"]:
		for cls: String in PICKS:
			await _hunter(String(PICKS[cls]), out.path_join(way).path_join(cls), way)
	print("LAND_WEIGHT_SHOTS_DONE")
	tree.quit()


func _hunter(id: String, dir: String, way: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var JumpLand := preload("res://tools/jump_land_shots.gd")
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var anim := HunterAnim.new(model, 1)
	var air: float = JumpLand.air_time(way)
	var i := 0
	var t := -RUN_UP
	while t < air + TAIL:
		var s: Dictionary = JumpLand.arc(t, false, way)
		model.position.y = float(s["y"])
		anim.update(DT, s)
		sync.call("_process", DT)
		await _grab(dir.path_join("f%03d.png" % i))
		i += 1
		t += DT
	var f := FileAccess.open(dir.path_join("key.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"land": int(round((RUN_UP + air) / DT)), "fps": 30}))
	f.close()
	print("LW %s %s %s frames=%d land=%d" % [Arch.weight(id), id, way, i, int(round((RUN_UP + air) / DT))])
	model.queue_free()
	await tree.process_frame
