extends "res://tools/hero_vfx_reel.gd"
## --parity-reel --shots-dir=<dir> --reel-hero=<arch> [--reel-only=<part>]: one Hunter's whole move set in the
## Training Grounds against a dummy, at the match camera, for the parity reel (docs/parity_reel/): LMB tap and
## hold, RMB, E, R (each with a second press for the recast), a ground and an air dash, a glide and a mantle. A
## row of key caps along the bottom lights up with the keys being pressed. Frames go to <dir>/frames/NNNNN.jpg at
## FRAME_FPS (run it under jobq --needs gpu, which returns the out dir); cut a clip off the box:
##   ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg -c:v libx264 -crf 30 -pix_fmt yuv420p reel.mp4
## REEL_MARK lines give the frame each part starts on. Never writes the save.

const SEQUENCE := ["lmb_tap", "lmb_hold", "rmb", "e", "r", "dash_ground", "dash_air", "glide", "mantle"]
const FRAME_FPS := 30                   # saved frames per second (every 2nd step of the 60 Hz match)
const KEYS := ["W", "A", "S", "D", "LMB", "RMB", "E", "R", "Shift", "Space"]
const FAR := 12.0                       # m to the dummy for the moves that travel
const KEY_LIT_S := 0.18                 # s a key cap stays lit after its press, so a one-step tap is seen
const KEY_ON := Color(1.0, 0.82, 0.3)
const KEY_OFF := Color(0.1, 0.1, 0.14, 0.7)

var lit := {}                           # key cap -> s left lit
var caps := {}                          # key cap -> its Label
var title: Label
var steps := 0
var r_down := false                     # R was pressed this step (it goes through HunterKeys, not inp)

func parts() -> Array:
	return SEQUENCE

func run(main_node: Node) -> void:
	main = main_node
	who = "juggernaut"
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--reel-hero="):
			who = arg.substr(12)
		if arg.begins_with("--reel-only="):
			only = arg.substr(12)
	hero_name = who
	await _setup()
	_build_keys()
	frame_dir = dir.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frame_dir)
	P.lvl = 6
	for slot in P.slot_lv:
		P.slot_lv[slot] = 3
	for part: String in SEQUENCE:
		if only == "" or part == only:
			print("REEL_MARK %d %s" % [frames, part])
			await Callable(self, "_p_" + part).call()
	print("REEL_DONE %d frames in %s" % [frames, frame_dir])
	main.get_tree().quit(0)

# ------------------------------------------------------------------ key caps
func _build_keys() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_top = -64.0
	row.offset_bottom = -16.0
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.add_theme_constant_override("separation", 6)
	layer.add_child(row)
	for k: String in KEYS:
		caps[k] = _label(k, 22, row)
	title = _label("", 28, layer)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 14.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH

func _label(words: String, px: int, parent: Node) -> Label:
	var l := Label.new()
	l.text = words
	l.add_theme_font_size_override("font_size", px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = KEY_OFF
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	l.add_theme_stylebox_override("normal", sb)
	parent.add_child(l)
	return l

## The caps lit by this step's inputs, held for KEY_LIT_S.
func _keys_update() -> void:
	var mv: Vector2 = P.inp["move"]
	var on := {"W": mv.y < -0.3, "S": mv.y > 0.3, "A": mv.x < -0.3, "D": mv.x > 0.3,
		"LMB": P.inp["fire"], "RMB": P.inp["sec"] or P.inp["sec_hold"], "E": P.inp["sig"], "R": r_down,
		"Shift": P.inp["dash"], "Space": P.inp["jump"]}
	r_down = false
	for k: String in KEYS:
		lit[k] = KEY_LIT_S if on[k] else maxf(0.0, float(lit.get(k, 0.0)) - DT)
		var sb: StyleBoxFlat = caps[k].get_theme_stylebox("normal")
		sb.bg_color = KEY_ON if lit[k] > 0.0 else KEY_OFF
		caps[k].add_theme_color_override("font_color", Color.BLACK if lit[k] > 0.0 else Color.WHITE)

func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	var keyed := func(t: float) -> void:
		if each.is_valid():
			each.call(t)
		if not caps.is_empty():
			_keys_update()
	await super._go(secs, keyed, marks, lead)

func _save_frame() -> void:
	steps += 1
	if steps % (60 / FRAME_FPS) == 0:
		super._save_frame()

# ------------------------------------------------------------------ the parts
## True while `t` is in the `secs` window that starts at `from` (a press is a short window).
func _in(t: float, from: float, secs := 0.1) -> bool:
	return t >= from and t < from + secs

func _seg(text: String, secs: float, each: Callable, td := 7.0) -> void:
	title.text = text
	await _reset(td)
	await _go(secs, func(t: float) -> void:
		_aim(T.pos)
		each.call(t))
	await _go(0.3)

func _p_lmb_tap() -> void:
	await _seg("LMB tap x3", 2.8, func(t: float) -> void:
		P.inp["fire"] = _in(t, 0.2) or _in(t, 1.0) or _in(t, 1.8))

func _p_lmb_hold() -> void:
	await _seg("LMB hold", 3.4, func(t: float) -> void:
		P.inp["fire"] = _in(t, 0.2, 2.4))

func _p_rmb() -> void:
	await _seg("RMB, then again", 4.0, func(t: float) -> void:
		P.inp["sec"] = _in(t, 0.2) or _in(t, 2.0)
		P.inp["sec_hold"] = _in(t, 0.2, 0.7) or _in(t, 2.0, 0.7))

func _p_e() -> void:
	await _seg("E, then the recast", 4.0, func(t: float) -> void:
		P.inp["sig"] = _in(t, 0.2) or _in(t, 1.8))

func _p_r() -> void:
	P.ak.cd["x"] = 0.0
	await _seg("R, then the recast", 6.0, func(t: float) -> void:
		if _at(t, 0.2) or _at(t, 2.6):
			r_down = true
			HunterKeys.ult_pressed(P))

func _p_dash_ground() -> void:
	var dash := func(t: float) -> void:
		P.inp["move"] = Vector2(1, 0) if t < 2.2 else Vector2.ZERO
		P.inp["dash"] = _in(t, 0.3) or _in(t, 1.3)
	await _seg("Dash on the ground, twice", 3.0, dash, FAR)

func _p_dash_air() -> void:
	var dash := func(t: float) -> void:
		P.inp["move"] = Vector2(1, 0) if t < 2.2 else Vector2.ZERO
		P.inp["jump"] = _in(t, 0.2)
		P.inp["dash"] = _in(t, 0.55)
	await _seg("Jump, then dash in the air", 3.0, dash, FAR)

func _p_glide() -> void:
	var glide := func(t: float) -> void:
		P.inp["move"] = Vector2.from_angle(t * 1.5) if t > 0.3 else Vector2.ZERO
		P.inp["jump"] = _in(t, 0.2, 3.4)
	await _seg("Jump and hold Space: glide", 4.2, glide, FAR)

## The Training Grounds has no terrace to run into, so the mantle is an island rim: dropped just below it, moving
## in, the Hunter catches the lip and comes over (as --cliff-mantle-check's "abyss" case).
func _p_mantle() -> void:
	var chk = load("res://tools/cliff_mantle_check.gd").new()
	chk.m = m
	chk.w = m.world
	chk.h = P
	var rims: Array = chk._rims()
	if rims.is_empty():
		print("REEL_MANTLE no rim")
		return
	var f: Dictionary = rims[rims.size() / 2]
	var dv := Vector2(f["d"])
	var a: Vector2i = f["a"]
	var face := Vector2(a.x + 0.5, a.y + 0.5) + dv * 0.5
	var top := float(f["la"] + f["rise"]) * World.LEVEL
	title.text = "Mantle the island rim"
	chk._setup(f, "abyss", face, dv, top)
	var ahead := Vector3(face.x + dv.x * 4.0, top + 0.9, face.y + dv.y * 4.0)
	var climb := func(_t: float) -> void:
		P.inp["move"] = dv
		P.inp["aim"] = ahead
	await _go(2.4, climb)
