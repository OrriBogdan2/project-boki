extends RefCounted
## --fall-reel --reel-mode=tutorial|expedition --shots-dir=<dir> [--reel-tag=<text>]: the --fall-parity-check runs
## played on the real match frame (Match._process at a fixed 1/60 s: the live camera, keys through Input), for the
## owner's before/after clips (11-11). Saves every frame as <dir>/frames/NNNNN.jpg; encode off the box:
##   ffmpeg -framerate 60 -i <dir>/frames/%05d.jpg -c:v libx264 -pix_fmt yuv420p <out>.mp4
## Needs a real renderer (jobq submit --needs gpu). Never writes the save.
##   1 a 10 m drop, no keys          2 a 10 m drop running, let go on landing
##   3 two running jumps, let go on the second landing
##   4 down a flight, let go on it (expedition: a flight of the map's; the tutorial map has none: a 3 m drop)

const DT := 1.0 / 60.0
const MODES := {
	"tutorial": {"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "no_drop": true},
	"expedition": {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true},
}
const FRAME_W := 1280          # px wide, each saved frame

var main: Node
var m: Match
var P: Hunter
var dir := "/tmp/fall_reel"
var frames := 0
var caption: Label

func run(main_node: Node) -> void:
	main = main_node
	var mode := "tutorial"
	var tag := ""
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--reel-mode="): mode = arg.substr(12)
		if arg.begins_with("--shots-dir="): dir = arg.substr(12)
		if arg.begins_with("--reel-tag="): tag = arg.substr(11)
	Save.no_write = true
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	m = Match.new()
	main.add_child(m)
	await m.start(MODES[mode].duplicate())
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	m.opts["god"] = true
	P = m.player
	if m.hud: m.hud.guide_hidden = true
	if m.tut: m.tut.intro = false      # (the first-time card would cover the drops)
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(24, 230)
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(caption)
	var at := _flat_spot(m.world)
	var run_v := P.base_speed
	var head := "%s  %s  " % [tag, mode]
	_put(at + Vector3(0, 10, 0), Vector3.ZERO)
	await _go(head + "10 m drop, no keys", 2.4, "", false)
	_put(at + Vector3(-run_v * sqrt(20.0 / Hunter.H_GRAV), 10, 0), Vector3(run_v, 0, 0))
	await _go(head + "10 m drop running, let go on landing", 2.6, "right", true)
	_put(at + Vector3(-4.5, 0, 0), Vector3.ZERO)
	P.grounded = true
	await _jumps(head + "running jumps, let go on the 2nd landing")
	var fl := _flight(m.world)
	if fl.is_empty():
		_put(at + Vector3(0, 3, 0), Vector3.ZERO)
		await _go(head + "3 m drop, no keys", 1.8, "", false)
	else:
		_put(fl["from"], Vector3.ZERO)
		P.grounded = true
		await _down_flight(head + "down a flight, let go on it", fl)
	print("FALL_REEL_DONE %d frames in %s" % [frames, dir])
	main.get_tree().quit(0)

func _put(p: Vector3, v: Vector3) -> void:
	_keys("")
	P.teleport(p)
	P.vel = v
	P.grounded = false
	P.air_peak = p.y
	m.cam.snap(p)

func _keys(k: String) -> void:
	for a in ["left", "right", "up", "down"]:
		if a == k: Input.action_press(a)
		else: Input.action_release(a)

## Plays `secs` of the real match frame holding `key`; let_go: the key comes up on the first landing.
func _go(text: String, secs: float, key: String, let_go: bool) -> void:
	caption.text = text
	_keys(key)
	var was := P.grounded
	for i in int(secs / DT):
		await _frame()
		if let_go and P.grounded and not was:
			_keys("")
		was = P.grounded

func _jumps(text: String) -> void:
	caption.text = text
	_keys("right")
	var landings := 0
	var press_at := 15
	var was := true
	for i in int(3.0 / DT):
		if i == press_at: Input.action_press("jump")
		elif i == press_at + 1: Input.action_release("jump")
		await _frame()
		if P.grounded and not was:
			landings += 1
			if landings == 1: press_at = i + 8
			else: _keys("")
		was = P.grounded

func _down_flight(text: String, fl: Dictionary) -> void:
	caption.text = text
	_keys(fl["key"])
	var mid: Vector3 = fl["mid"]
	for i in int(2.4 / DT):
		await _frame()
		if Vector2(P.pos.x - mid.x, P.pos.z - mid.z).length() < 0.2:
			_keys("")

func _frame() -> void:
	m._process(DT)
	await main.get_tree().process_frame
	var img := main.get_viewport().get_texture().get_image()
	img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
	img.save_jpg(dir.path_join("frames/%05d.jpg" % frames), 0.9)
	frames += 1

## Flat open ground 11 x 5 tiles round a spot (the drop lane), scanning out from the map's middle.
func _flat_spot(w: World) -> Vector3:
	var c := Vector2i(w.w / 2, w.h / 2)
	for ring in range(0, maxi(w.w, w.h) / 2):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) == ring and _open(w, c.x + dx, c.y + dz, Rect2i(-6, -2, 11, 5)):
					return Vector3(c.x + dx + 0.5, w.ground_at(c.x + dx + 0.5, c.y + dz + 0.5), c.y + dz + 0.5)
	return Vector3(c.x + 0.5, 0, c.y + 0.5)

func _open(w: World, x: int, z: int, lane: Rect2i) -> bool:
	if x < 8 or z < 8 or x > w.w - 8 or z > w.h - 8:
		return false
	var y := w.ground_at(x + 0.5, z + 0.5)
	if y <= World.VOID + 1.0:
		return false
	for dx in range(lane.position.x, lane.end.x):
		for dz in range(lane.position.y, lane.end.y):
			var q := Vector2(x + dx + 0.5, z + dz + 0.5)
			if absf(w.ground_at(q.x, q.y) - y) > 0.001 or w.stairs.has(w.idx(int(q.x), int(q.y))):
				return false
			if w.occupy(q.x, q.y, 0.45, y, false) != 0.0:
				return false
	return true

## A flight with open ground two tiles above its top and below its foot: {from, mid, key}.
func _flight(w: World) -> Dictionary:
	var keys := {Vector2i(1, 0): "left", Vector2i(-1, 0): "right", Vector2i(0, 1): "up", Vector2i(0, -1): "down"}
	for i in w.stairs:
		var d: Vector2i = w.stairs[i]
		var t := Vector2i(int(i) % w.w, int(i) / w.w)
		var top := t + d * 2
		var foot := t - d * 2
		var ok := w.inb(top.x, top.y) and w.inb(foot.x, foot.y) and not w.stairs.has(w.idx(top.x, top.y))
		ok = ok and not w.is_void(top.x + 0.5, top.y + 0.5) and not w.is_void(foot.x + 0.5, foot.y + 0.5)
		if ok and w.occupy(top.x + 0.5, top.y + 0.5, 0.45, w.ground_at(top.x + 0.5, top.y + 0.5), false) == 0.0:
			var from := Vector3(top.x + 0.5, w.ground_at(top.x + 0.5, top.y + 0.5), top.y + 0.5)
			return {"from": from, "mid": Vector3(t.x + 0.5, 0, t.y + 0.5), "key": keys[d]}
	return {}
