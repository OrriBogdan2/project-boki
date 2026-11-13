extends SceneTree
## Bakes the cleaned Uthana clips: godot --headless --path <project> -s uthana_bake.gd -- --recipes=<json> --out=<dir>
## The recipe file (tools/anim/uthana_recipes.json): {rigs: {rig: {model, arm_fix?: {ours, calib, chain}}},
## clips: {name: {rig, raw, warp, yaw, in_place, floor, ik, carry, arm_fix}}} (the steps: uthana_clean.gd).
## Each clip goes to <dir>/<name>.res.

func _init() -> void:
	var rpath := ""
	var out := "res://out/clean"
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--recipes="): rpath = s.trim_prefix("--recipes=")
		if s.begins_with("--out="): out = s.trim_prefix("--out=")
	var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rpath))
	DirAccess.make_dir_recursive_absolute(out)
	var rigs := {}
	for name: String in r["rigs"]:
		var spec: Dictionary = r["rigs"][name]
		var m: Node3D = load(String(spec["model"])).instantiate()
		var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		var fix := {}
		if spec.has("arm_fix"):
			var af: Dictionary = spec["arm_fix"]
			var calib := UthanaClean.load_motion(String(af["calib"]))
			fix = UthanaClean.arm_fix(sk, ap, String(af["ours"]), calib, af["chain"])
			for b: int in fix:
				var deg := rad_to_deg((fix[b] as Quaternion).get_angle())
				print("ARMFIX %s %s %.1f deg" % [name, sk.get_bone_name(b), deg])
		rigs[name] = {"m": m, "sk": sk, "ap": ap, "fix": fix}
	for name: String in r["clips"]:
		var c: Dictionary = r["clips"][name]
		var rig: Dictionary = rigs[String(c["rig"])]
		var fix: Dictionary = rig["fix"] if c.get("arm_fix", true) else {}
		var a := UthanaClean.clean(rig["sk"], rig["ap"], UthanaClean.load_motion(String(c["raw"])), c, fix)
		var err := ResourceSaver.save(a, "%s/%s.res" % [out, name])
		print("BAKED %s len=%.2f err=%d" % [name, a.length, err])
	for k: String in rigs: (rigs[k]["m"] as Node).free()
	quit()
