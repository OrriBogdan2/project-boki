extends RefCounted
## --farm-greet-clip [--clip-dir=greet_clip]: film BaseGreet (docs/BASE_LIFE.md, "You come back") on a made-up garden
## (never the real save): three Boki of bond rank Wary, Close and Soulbound roam; you stand off, then walk back to
## them; the Wary one looks, the other two run to you and follow you a few steps, then all go back to roaming. The
## away time is shortened and the roll made certain so a 30 s film shows each reaction. Like tools/farm_autosort_clip.gd
## it re-runs itself as a child Godot under the movie writer (GPU worker): <tree>/<clip-dir>/farm_greet.avi.
## Prints FGCLIP lines.

const FPS := 30
const ISLAND_SEED := 11  # the farm-start island of --base-life-check
const AWAY_S := 3.0  # s: the filmed away time (base_life.json notice.away_s is 25)
const FAR_M := 16.0  # m: where you stand off
const WALK := 3.2  # m/s you walk
const WATCH_S := 10.0  # s of watching the runners
const LEAVE_M := 7.0  # m you walk away with them following
const SPECS := [["cindle", "Ash", 0.0], ["burrlet", "Moss", 60.0], ["zapple", "Pip", 95.0]]  # species, name, trust

var main: Node
var label: Label


func run(main_node: Node) -> void:
	main = main_node
	if "--fg-child" not in OS.get_cmdline_user_args():
		_record()
		return
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	var n: Dictionary = BaseGreet.rules()
	n["away_s"] = AWAY_S
	n["chance"] = 1.0
	seed(ISLAND_SEED)
	var d := Save.fresh()
	for i in SPECS.size():
		var rec := Save.new_kin(SPECS[i][0], SPECS[i][1], 700 + i)
		rec["uid"] = "fg%d" % i
		rec["trust"] = SPECS[i][2]
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.new_fs(d, ISLAND_SEED)
	HomeLayout.ensure(d)
	var h = await main._hb_home()
	h.day_t = 0.45
	var mid: Vector3 = h.world.free_spot_near(h.world.random_ground(0), [], 0.8)
	for i in h.kins.size():
		var k: Dictionary = h.kins[i]
		k["pos"] = h.world.free_spot_near(mid + Vector3(float(i) * 2.0 - 2.0, 0, 0), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["rec"]["bonds"] = {}
	_stand(h, h.world.free_spot_near(mid + Vector3(-FAR_M, 0, 0), [], 0.8))
	h.cam.zoom_to = 0.8
	h.cam.zoom = 0.8
	h.cam.snap(h.ppos)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	_caption(h)
	await _wait(AWAY_S + 1.5, h)
	var goal: Vector3 = h.world.free_spot_near(mid + Vector3(-3.0, 0, 0), [], 0.8)
	while Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > 0.3:
		_stand(h, h.ppos + (goal - h.ppos).normalized() * minf(WALK / FPS, (goal - h.ppos).length()))
		await _wait(1.0 / FPS, h)
	print("FGCLIP back: %s" % _states(h, " | "))
	await _wait(WATCH_S, h)
	print("FGCLIP after the run: %s" % _states(h, " | "))
	var off: Vector3 = h.ppos + Vector3(-LEAVE_M, 0, 0)
	for _i in roundi(LEAVE_M / WALK * FPS):
		_stand(h, h.ppos + (off - h.ppos).normalized() * (WALK / FPS))
		await _wait(1.0 / FPS, h)
	await _wait(8.0, h)
	print("FGCLIP DONE %s" % _states(h, " | "))
	main.get_tree().quit()


func _stand(h, at: Vector3) -> void:
	h.ppos = at
	h.player.position = at + Vector3(0, h.py, 0)
	h.cam.snap(at)


func _caption(h) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	label = Label.new()
	label.position = Vector2(32, 32)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	layer.add_child(label)
	main.add_child(layer)
	label.text = _states(h)


func _states(h, sep := "\n") -> String:
	var out: PackedStringArray = []
	for k in h.kins:
		var m: Fsm = k["life"]
		out.append("%s (%s): %s" % [k["rec"]["name"], Care.bond(k["rec"])[1], m.state_name()])
	return sep.join(out)


func _wait(secs: float, h) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		label.text = _states(h)


func _record() -> void:
	var dir := "greet_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--clip-dir="):
			dir = String(a).substr(11)
	var root := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(root.path_join(dir))
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution", "1280x720"]
	var avi := root.path_join(dir).path_join("farm_greet.avi")
	args.append_array(["--fixed-fps", str(FPS), "--write-movie", avi, "--"])
	args.append_array(OS.get_cmdline_user_args())
	args.append("--fg-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("FGCLIP") or line.contains("SCRIPT ERROR"):
			print(line)
	print("FGCLIP child rc=%d" % rc)
	main.get_tree().quit(rc)
