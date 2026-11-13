extends "res://tools/idle_shots.gd"
## --recoil-shots --shots-dir=<dir> [--wardens=gunslinger,thief,dredge] [--size=320]: the shot kick on the keyed
## Heroes (warden_anim "recoil"), as before/after strips. Per Hero, in <dir>/<id>/: before_<view>/ and after_<view>/,
## frames f000 (aiming, before the shot) to f005 (0.15 s on), the same clip held still; "before" runs with the
## recoil data removed. Views side and front (3/4). Needs a renderer.

const AIMED := {"gunslinger": "gunslinger_lmb", "thief": "thf_lmb_r", "dredge": "dr_shot"}     # the clip held up
const AT := [-1.0, 0.0, 0.03, 0.06, 0.09, 0.15]     # s from the shot (-1: before it)

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	var ids: Array = AIMED.keys()
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
	for id in ids:
		await _film(String(id), out.path_join(String(id)))
	print("RECOIL_SHOTS_DONE ", ids.size())
	tree.quit()

func _film(id: String, dir: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	model.set_meta("anim_seed", 1)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var tall := _height(model)
	cam.position = Vector3(0, tall * 0.52, tall * 2.15)
	cam.look_at(Vector3(0, tall * 0.5, 0))
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var recoil: Dictionary = clips.d["recoil"]
	var clip := String(clips.d["kmoves"][AIMED[id]]["clip"])
	var s := {"vel": Vector3.ZERO, "face": 0.0, "grounded": true, "fired": 99.0}
	model.set_meta(WardenClips.STATE, s)
	for pass_name in ["before", "after"]:
		clips.d["recoil"] = {"deg": 0.0, "settle": 0.1} if pass_name == "before" else recoil
		for view in VIEWS:
			model.rotation.y = deg_to_rad(float(VIEWS[view]))
			var sub := dir.path_join("%s_%s" % [pass_name, view])
			DirAccess.make_dir_recursive_absolute(sub)
			clips.force = {"clip": clip, "t": 0.1}
			s["fired"] = 99.0
			for k in 12:
				sync.call("_process", DT)
			var at := 0.0
			for i in AT.size():
				if AT[i] >= 0.0:
					if i == 1:
						s["fired"] = 0.0
					while at < AT[i] - 0.001:
						at += DT
						s["fired"] = at
						sync.call("_process", DT)
					if i == 1:
						sync.call("_process", DT)
				await _grab(sub.path_join("f%03d.png" % i))
	clips.d["recoil"] = recoil
	clips.force = {}
	model.queue_free()
	await tree.process_frame
