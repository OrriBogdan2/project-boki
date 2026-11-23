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
const DAY_T := 0.45  # farm clock: mid-morning all film long
const DEADLINE_S := 120.0  # s of film at most
const ZOOM := 1.2  # camera zoom, as --base-demo
const WATCH_S := 9.0  # s of watching the runners
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
		for need in Care.NEEDS:
			rec["needs"][need] = 90.0  # rested and fed: awake for the film
		d["roster"].append(rec)
	d["roster"][0]["starter"] = true
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"home": true, "hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.new_fs(d, ISLAND_SEED)
	HomeLayout.ensure(d)
	var h = await main._hb_home()
	h.day_t = DAY_T
	var mid: Vector3 = h.world.free_spot_near(h.world.random_ground(0), [], 0.8)
	for i in h.kins.size():
		var k: Dictionary = h.kins[i]
		k["pos"] = h.world.free_spot_near(mid + Vector3(float(i) * 2.0 - 2.0, 0, 0), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["rec"]["bonds"] = {}
	var far := _far_spot(h, mid)
	_stand(h, far)
	h.cam.zoom_to = ZOOM
	h.cam.zoom = ZOOM
	h.cam.snap(h.ppos)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	_caption(h)
	main.get_tree().create_timer(DEADLINE_S).timeout.connect(main.get_tree().quit.bind(1))  # never hang a worker
	for pass_n in 2:
		_stage(h, mid)  # the staging: they are free and where you left them, each time you head back
		await _wait(AWAY_S + 2.0, h)
		await _walk(h, h.world.free_spot_near(mid + Vector3(-3.0, 0, 0), [], 0.8))
		print("FGCLIP pass %d back: %s" % [pass_n, _states(h, " | ")])
		await _wait(WATCH_S, h)
		print("FGCLIP pass %d after: %s" % [pass_n, _states(h, " | ")])
		await _walk(h, far)
	print("FGCLIP DONE %s" % _states(h, " | "))
	main.get_tree().quit()


## A spot on the Boki's island at least FAR_M from them.
func _far_spot(h, mid: Vector3) -> Vector3:
	var here: int = h.world.island_of(mid.x, mid.z)
	for dist: float in [FAR_M, FAR_M - 3.0, FAR_M - 4.5]:  # 16, 13, 11.5 m: past the 10 m of notice.far_m
		for i in 24:
			var at: Vector3 = mid + Vector3(cos(i * 0.7), 0, sin(i * 0.7)) * dist
			if not h.world.is_void(at.x, at.z) and h.world.island_of(at.x, at.z) == here:
				return h.world.free_spot_near(at, [], 0.8)
	return mid + Vector3(FAR_M, 0, 0)


func _stage(h, mid: Vector3) -> void:
	for i in h.kins.size():
		var k: Dictionary = h.kins[i]
		for key in ["play", "eat", "nap_t", "life_at", "life_it", "notice_away", "life_greet", "led"]:
			k.erase(key)
		h.life.machine(k).go(BaseLife.S.ROAM, "film")
		k["pos"] = h.world.free_spot_near(mid + Vector3(float(i) * 2.0 - 2.0, 0, 0), [], 0.8)
		(k["node"] as Node3D).position = k["pos"]
		k["goal"] = k["pos"]
		k["t"] = 4.0


func _walk(h, goal: Vector3) -> void:
	while Vector2(goal.x - h.ppos.x, goal.z - h.ppos.z).length() > 0.3:
		_stand(h, h.ppos + (goal - h.ppos).normalized() * minf(WALK / FPS, (goal - h.ppos).length()))
		await _wait(1.0 / FPS, h)


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
		var m: Fsm = h.life.machine(k)
		out.append("%s (%s): %s" % [k["rec"]["name"], Care.bond(k["rec"])[1], m.state_name()])
	return sep.join(out)


func _wait(secs: float, h) -> void:
	for _i in maxi(1, roundi(secs * FPS)):
		await main.get_tree().process_frame
		h.day_t = DAY_T
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
