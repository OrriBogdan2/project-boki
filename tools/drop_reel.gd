extends "res://tools/drop_shots.gd"
## --drop-reel --shots-dir=<dir> [--reel-only=solo|squad|comet] [--reel-stills]: the opening drop played live for
## owner review. Run it under the movie writer, so the looks run on the fixed step and the real mix is recorded:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 --path . \
##       --fixed-fps 30 --write-movie <dir>/reel.avi -- --drop-reel --shots-dir=<dir>
## REEL_MARK lines give the frame of each take's beats (start, jump, ping, snap, land), to cut the load away with.
## --reel-stills instead saves a PNG every STILL_S of the take to <dir>/<take>_<n>.png.
##   solo    a lone diver: float, turn, dive, a middle-mouse ping, the snap, the landing
##   squad   a squad of three that breaks out of the comet: three contrails and name tags side by side
##   comet   a squad riding its comet down to the burst

const STILL_S := 1.5
var marks := PackedStringArray()
var stills := false
var only := ""
var take := ""
var still_n := 0
var still_t := 0.0

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--reel-only="):
			only = arg.substr(12)
		if arg == "--reel-stills":
			stills = true
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.v["tips"] = false
	for t in ["solo", "squad", "comet"]:
		if only == "" or only == t:
			take = t
			await Callable(self, "_%s_take" % t).call()
	FileAccess.open(dir.path_join("marks.txt"), FileAccess.WRITE).store_string("\n".join(marks) + "\n")
	print("REEL_DONE")
	main.get_tree().quit(0)

func _mark(what: String) -> void:
	var s := "%d %s %s t=%.2f y=%.1f" % [Engine.get_frames_drawn(), take, what, m.time, P.pos.y]
	marks.append(s)
	print("REEL_MARK ", s)

## Waits, frame by frame, saving stills on the way when asked.
func _wait(cond: Callable, secs := 60.0) -> void:
	var t0 := m.time
	var guard := 0
	while not cond.call() and m.time - t0 < secs and guard < secs * 400.0:
		guard += 1
		await main.get_tree().process_frame
		if stills and m.time - still_t >= STILL_S:
			still_t = m.time
			still_n += 1
			main.get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%02d.png" % [take, still_n]))

func _h() -> float:
	return SkyFall.height_over(m.world, P.pos)

func _aboard() -> void:
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	still_t = m.time
	await _wait(func(): return Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() < 70.0, 40.0)
	_mark("jump")
	m.ship_jump(P)

func _down() -> void:
	await _wait(func(): return not P.dropping, 40.0)
	_mark("snap")
	await _wait(func(): return P.grounded, 25.0)
	_mark("land")
	var t := m.time
	await _wait(func(): return m.time - t > 2.0, 3.0)

func _solo_take() -> void:
	await _start({"teams": 3, "squad": 1, "tier": 0, "seed": 4103, "no_plan": true, "raid": "clear"})
	_mark("start")
	var t := m.time
	await _wait(func(): return m.time - t > 2.0, 3.0)
	await _aboard()
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.74)
	_press("left", true)
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.66)
	_press("left", false)
	_press("up", true)
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.42)
	_press("up", false)
	_mark("ping")
	var sz := main.get_viewport().get_visible_rect().size
	DropPing.place(m, Vector2(sz.x * 0.62, sz.y * 0.6))
	await _down()

func _squad_take() -> void:
	await _start({"teams": 3, "squad": 3, "tier": 0, "seed": 4101, "no_plan": true, "raid": "clear"})
	_mark("start")
	await _aboard()
	for f in m.skydrop.comet.riders(P.team):
		f.ai["break_y"] = -1.0
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.86)
	_mark("break")
	var n := 0
	for f in m.skydrop.comet.riders(P.team).duplicate():
		m.skydrop.separate(f)
		n += 1
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.5)
	await _down()

func _comet_take() -> void:
	await _start({"teams": 3, "squad": 3, "tier": 0, "seed": 4107, "no_plan": true, "raid": "clear"})
	_mark("start")
	await _aboard()
	for f in m.skydrop.comet.riders(P.team):
		f.ai["break_y"] = -1.0
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.8)
	_press("right", true)
	await _wait(func(): return _h() < SkyFall.SKY_Y * 0.7)
	_press("right", false)
	await _down()
