extends RefCounted
## --farm-autosort-clip [--clip-dir=autosort_clip]: film the farm auto-sort (docs/FARM_AUTOSORT.md) on the made-up
## work farm (HomeWork.demo_save, never the real save). 2 s with nobody placed, then Work.autosort() sends each kin
## to the station that fits its top knack, then the owner moves one kin by hand and auto-sort leaves it there.
## Like tools/abyss_danger_clip.gd it re-runs itself as a child Godot under the movie writer (GPU worker), so the
## movie lands in <tree>/<clip-dir>/farm_autosort.avi. Prints FACLIP lines.

const Preflight := preload("res://tools/clip_preflight.gd")
const FPS := 30
const BEFORE_S := 2.5  # s with nobody placed
const SORTED_S := 7.0  # s watching the sorted crew walk over and work
const AFTER_S := 5.0  # s after the owner's own move

var main: Node
var label: Label


func run(main_node: Node) -> void:
	main = main_node
	if "--fa-child" not in OS.get_cmdline_user_args():
		_record()
		return
	Save.no_write = true
	Save.d = HomeWork.demo_save()
	var l: Dictionary = Save.d["layout"]
	for s in [["seed_garden", 49, 33], ["kiln", 49, 37]]:  # all four sortable stations on show
		l["uid"] = int(l["uid"]) + 1
		(l["deco"] as Array).append({"u": l["uid"], "id": s[0], "x": s[1], "z": s[2], "r": 0})
	for r in Save.d["roster"]:
		r["work_manual"] = true  # held back for the "before" part
		print("FACLIP kin %s top=%s" % [r["name"], Work.list(r)[0]])
	var h = await main._hb_home()
	h.day_t = 0.45
	h.ppos = Vector3(55.5, 0, 33.0)
	h.player.position = h.ppos
	h.player.visible = false
	h.cam.zoom_to = 0.92
	h.cam.zoom = 0.92
	h.cam.snap(h.ppos)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if not Preflight.enforce(main, 0, "farm_autosort"):
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	label = Label.new()
	label.position = Vector2(32, 32)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	layer.add_child(label)
	main.add_child(layer)
	label.text = "Before: %d kin, nobody at a station" % Save.d["roster"].size()
	await _wait(BEFORE_S)
	for r in Save.d["roster"]:
		r.erase("work_manual")
	var placed := Work.autosort()
	var lines := ["Auto-sort (best knack -> free station):"]
	for p in placed:
		lines.append("  %s -> %s" % [p[0], HomeLayout.CATALOG.get(p[1], {}).get("name", p[1])])
	var rest: Array = []
	for r in Save.d["roster"]:
		if Work.assigned(r) < 0:
			rest.append(String(r["name"]))
	lines.append("  no fitting station: %s (job board)" % ", ".join(rest))
	label.text = "\n".join(lines)
	print("FACLIP placed=%s" % [placed])
	await _wait(SORTED_S)
	# the owner moves the first sorted kin to the other station: a manual pick, auto-sort keeps off it
	if not placed.is_empty():
		var rec := _rec(String(placed[0][0]))
		var other := _other_station(Work.assigned(rec))
		if other.size() > 0:
			Work.assign(rec, int(other["e"]["u"]))
			var again := Work.autosort()
			lines.append("Owner moves %s -> %s (stays: re-sort placed %d)" % [placed[0][0], _name(other), again.size()])
			label.text = "\n".join(lines)
			print("FACLIP owner_move=%s at=%d resort=%d" % [placed[0][0], Work.assigned(rec), again.size()])
	await _wait(AFTER_S)
	print("FACLIP DONE")
	main.get_tree().quit()


func _rec(nm: String) -> Dictionary:
	for r in Save.d["roster"]:
		if String(r["name"]) == nm:
			return r
	return {}


func _name(st: Dictionary) -> String:
	return String(HomeLayout.CATALOG.get(String(st["id"]), {}).get("name", st["id"]))


func _other_station(u: int) -> Dictionary:
	for st in HomeLayout.stations(Save.d):
		if int(st["e"]["u"]) != u and Work.ASSIGN.has(String(st["id"])):
			return st
	return {}


func _wait(secs: float) -> void:
	for _i in roundi(secs * FPS):
		await main.get_tree().process_frame


func _record() -> void:
	var dir := "autosort_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--clip-dir="):
			dir = String(a).substr(11)
	var root := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(root.path_join(dir))
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution", "1280x720"]
	var avi := root.path_join(dir).path_join("farm_autosort.avi")
	args.append_array(["--fixed-fps", str(FPS), "--write-movie", avi, "--"])
	args.append_array(OS.get_cmdline_user_args())
	args.append("--fa-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("FACLIP") or line.begins_with("CLIP_PREFLIGHT") or line.contains("SCRIPT ERROR"):
			print(line)
	print("FACLIP child rc=%d" % rc)
	main.get_tree().quit(rc)
