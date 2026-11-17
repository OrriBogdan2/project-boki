extends RefCounted
## --abyss-danger-clip [--sink=1.4]: a real match, the player stepped off an island and sunk slowly (--sink m/s)
## down to the point of no return and death, so the red tint, vignette and warning build up on screen. Run it
## under the movie writer on a GPU worker (docs/PITCH_REEL.md has the pattern): `godot --rendering-driver vulkan
## --write-movie out.avi --fixed-fps 60 -- --abyss-danger-clip`. A small readout (depth, danger, warning dB)
## sits top-left. Prints ADCLIP lines; quits when the run has ended.
## The movie writer's flags are engine arguments and the jobq workers only pass user arguments, so a plain
## `-- --abyss-danger-clip --clip-dir=abyss_clip` runs this scene again as a child Godot under the writer
## (the child gets --abyss-child) and the movie lands in <tree>/<clip-dir>/abyss_danger.avi.

const FPS := 60
const LEAD_S := 1.5          # s above the lip before the drop
const TAIL_S := 3.0          # s after the point of no return

var main: Node
var m: Match
var label: Label


func run(main_node: Node) -> void:
	main = main_node
	if "--abyss-child" not in OS.get_cmdline_user_args():
		_record()
		return
	var sink := 1.4
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--sink="):
			sink = float(String(a).substr(7))
	Demo.setup("match")
	var o := Match.demo_opts()
	o.merge({"no_drop": true, "seed": 77}, true)
	await main.show_screen("match", o)
	m = main.current
	await m.warm_up()
	var p: Hunter = m.player
	var w: World = m.world
	var spot := _step_off(w)
	var layer := CanvasLayer.new()
	layer.layer = 100
	label = Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 26)
	layer.add_child(label)
	main.add_child(layer)
	var lip: float = w.abyss_floor(spot.x, spot.z, p.last_gy) + World.ABYSS_DEPTH
	p.teleport(Vector3(spot.x, lip + 0.3, spot.z))
	await _wait(LEAD_S)
	var AbyssFx = load("res://scripts/match/abyss_fx.gd")
	var frames := 0
	var maxk := 0.0
	while is_instance_valid(p) and not p.out and frames < FPS * 60:
		p.vel = Vector3(0.0, -sink, 0.0)
		var k: float = AbyssFx.danger(p)
		maxk = maxf(maxk, k)
		var db := AbyssFallSfx.warn_db(k)
		label.text = "depth %4.1f m   danger %.2f   warning %s" % [lip - p.pos.y, k, ("%.0f dB, %.1f/s" % [db, AbyssFallSfx.warn_rate(k)]) if db > -INF else "off"]
		if frames % 30 == 0:
			print("ADCLIP depth=%.1f k=%.2f db=%.1f" % [lip - p.pos.y, k, db])
		frames += 1
		await main.get_tree().process_frame
	print("ADCLIP end out=%s max_k=%.2f frames=%d" % [p.out, maxk, frames])
	await _wait(TAIL_S)
	print("ADCLIP DONE")
	main.get_tree().quit()


func _wait(secs: float) -> void:
	for _i in roundi(secs * FPS):
		await main.get_tree().process_frame


## A point 5 m past an island's rim over open void.
func _step_off(w: World) -> Vector3:
	for _k in 4000:
		var g := w.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var q := Vector2(g.x, g.z)
			var n := 0
			while not w.is_void(q.x, q.y) and n < 12:
				q += d * 0.5
				n += 1
			if n >= 12:
				continue
			var far := q + d * 5.0
			if w.is_void(far.x, far.y) and w.is_void(far.x + d.y * 3.0, far.y + d.x * 3.0):
				return Vector3(far.x, g.y, far.y)
	return Vector3.ZERO


func _record() -> void:
	var dir := "abyss_clip"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--clip-dir="):
			dir = String(a).substr(11)
	var root := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(root.path_join(dir))
	var cfg := root.path_join("override.cfg")
	var f := FileAccess.open(cfg, FileAccess.WRITE)
	f.store_string("[display]\n\nwindow/size/viewport_width=1920\nwindow/size/viewport_height=1080\n\n")
	f.store_string("[editor]\n\nmovie_writer/mjpeg_quality=0.9\n")
	f.close()
	var args := ["--path", root, "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--resolution",
		"1920x1080", "--fixed-fps", str(FPS), "--write-movie", root.path_join(dir).path_join("abyss_danger.avi"), "--"]
	args.append_array(OS.get_cmdline_user_args())
	args.append("--abyss-child")
	var out: Array = []
	var rc := OS.execute(OS.get_executable_path(), args, out, true)
	DirAccess.remove_absolute(cfg)
	for line in (String(out[0]) if out.size() > 0 else "").split("\n"):
		if line.begins_with("ADCLIP") or line.contains("ERROR"):
			print(line)
	print("ADCLIP child rc=%d" % rc)
	main.get_tree().quit(rc)
