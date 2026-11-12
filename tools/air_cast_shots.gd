extends "res://tools/clip_shots.gd"
## --air-cast-shots --shots-dir=<dir> [--size=480]: each Hunter's air cast (MOVES) pressed on the way up a plain
## standing jump, the camera following him up, played through the landing, every 1/30 s, twice: <dir>/<id>/before/
## with the move's "air_legs" taken out of the data (the planted stance in the air) and <dir>/<id>/after/ as the data
## has it, plus key.json (press and landing frames). tools/air_cast_strip.py makes the strips. Needs a renderer.

const DT := 1.0 / 30.0
const PRESS := 0.15          # s after the take-off the move is pressed (on the way up)
const LEAD := 0.1            # s filmed before the take-off
const TAIL := 0.5            # s filmed after the landing
## The move filmed per Hunter: the one a player fires most from a jump that stood planted in the air.
const MOVES := {"gunslinger": "gunslinger_lmb", "juggernaut": "jug_slash_r", "ashwick": "as_shot",
	"tender": "mm_shot_r", "dolm": "breah_punch", "archer": "arc_heavy", "dredge": "dr_throw",
	"rimewright": "tm_dart_r", "bulwark": "bul_throw", "thief": "thf_lmb_r"}

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
		if a.begins_with("--size="): frame_px = int(a.substr(7))
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	main.get_window().size = Vector2i(frame_px, frame_px)
	main.get_viewport().size = Vector2i(frame_px, frame_px)
	_stage(main)
	cam.fov = 30.0
	for id in MOVES:
		await _hunter(String(id), String(MOVES[id]), out.path_join(String(id)))
	print("AIR_CAST_SHOTS_DONE")
	tree.quit()

func _hunter(id: String, km: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	model.rotation.y = deg_to_rad(150.0)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var mv: Dictionary = clips.d["kmoves"][km]
	var length := clips.lib.get_animation(String(mv["clip"])).length
	var air := 2.0 * Hunter.JUMP_V / Hunter.H_GRAV
	for variant: String in ["before", "after"]:
		if variant == "before":
			mv.erase("air_legs")
		else:
			mv["air_legs"] = true
		var sub := dir.path_join(variant)
		DirAccess.make_dir_recursive_absolute(sub)
		model.position.y = 0.0
		for k in 30:
			model.set_meta(WardenClips.STATE, {"grounded": true, "vel": Vector3.ZERO, "face": 0.0})
			sync.call("_process", DT)
		var i := 0
		var t := -LEAD
		while t < air + TAIL:
			var up := t >= 0.0 and t < air
			var s := {"grounded": not up, "face": 0.0,
				"vel": Vector3(0, Hunter.JUMP_V - Hunter.H_GRAV * t if up else 0.0, 0)}
			if t >= PRESS and t - PRESS < length:
				s["kmove"] = km
				s["kmove_t"] = t - PRESS
			model.position.y = maxf(Hunter.JUMP_V * t - 0.5 * Hunter.H_GRAV * t * t, 0.0) if up else 0.0
			cam.position = Vector3(0, 1.1 + model.position.y, 7.0)      # (it follows him up, as the game's does)
			cam.look_at(Vector3(0, 0.85 + model.position.y, 0))
			model.set_meta(WardenClips.STATE, s)
			sync.call("_process", DT)
			await _grab(sub.path_join("f%03d.png" % i))
			i += 1
			t += DT
		var key := {"move": km, "press": int(round((LEAD + PRESS) / DT)), "land": int(ceil((LEAD + air) / DT)),
			"end": int(round((LEAD + PRESS + length) / DT)), "fps": 30}
		var f := FileAccess.open(sub.path_join("key.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(key))
		f.close()
	print("AC %s %s" % [id, km])
	model.queue_free()
	await tree.process_frame
