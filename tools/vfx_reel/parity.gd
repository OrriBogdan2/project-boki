extends "res://tools/hero_vfx_reel.gd"
## --hero-vfx-reel --reel-parity --reel-hero=<arch> --reel-frames: the same short reel for any Hunter, the parity gate's
## "done means played": LMB tap and hold, RMB, E, R, a ground dash and an air dash, a glide and a mantle at the
## match camera against the dummy, the key being pressed on screen the whole time. Frames are every STRIDE-th
## step at FRAME_PX wide (jobq returns the out dir: ffmpeg -framerate 30 -i frames/%05d.jpg ...).

const STRIDE := 2              # 60 Hz steps per saved frame (a 30 fps clip)
const FRAME_PX := 800          # px wide, each saved frame
const DAIS_X := 26             # tile column of the Arena's dais (its south face runs along it)

var key_label: Label

func parts() -> Array:
	return ["lmb_tap", "lmb_hold", "rmb", "e", "r", "dash", "dash_air", "glide", "mantle"]

func _part_func(part: String) -> String:
	return "_part_" + part

func _setup() -> void:
	frame_every = STRIDE
	frame_w = FRAME_PX
	await super._setup()
	var layer := CanvasLayer.new()
	layer.layer = 100
	key_label = Label.new()
	key_label.position = Vector2(24, 24)
	key_label.add_theme_font_size_override("font_size", 40)
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(key_label)
	main.add_child(layer)

func _key(text: String) -> void:
	key_label.text = text

func _part_lmb_tap() -> void:
	await _reset(6.0)
	_key("%s  tap" % Settings.key_cap("fire"))
	var tap := func(t: float):
		P.inp["fire"] = t < DT * 1.5
		_aim(T.pos)
	await _go(2.6, tap, [], 2.0)
	await _go(GAP)

func _part_lmb_hold() -> void:
	await _reset(6.0)
	_key("%s  hold" % Settings.key_cap("fire"))
	var hold := func(t: float):
		P.inp["fire"] = t < 1.8
		_aim(T.pos)
	await _go(3.2, hold, [], 2.0)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(6.0)
	_key(Settings.key_cap("secondary"))
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(3.4, cast, [], 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(6.0)
	_key(Settings.key_cap("signature"))
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(3.4, cast, [], 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(6.0)
	_key(Settings.key_cap("hunter_ult"))
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			HunterKeys.ult_pressed(P)
		_aim(T.pos)
	await _go(4.2, cast, [], 2.5)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(8.0)
	_key("%s  dash on the ground" % Settings.key_cap("dash"))
	var dash := func(t: float):
		P.inp["move"] = Vector2(1, 0) if t < 0.5 else Vector2.ZERO
		if _at(t, 0.15):
			P.do_dash()
		_aim(T.pos)
	await _go(2.6, dash, [], 2.5)
	await _go(GAP)

func _part_dash_air() -> void:
	await _reset(10.0)
	P.teleport(home + Vector3(-6, 0, 0))       # (the far dashes would end off the island)
	_key("%s, then %s  dash in the air" % [Settings.key_cap("jump"), Settings.key_cap("dash")])
	var dash := func(t: float):
		P.inp["move"] = Vector2(1, 0) if t < 1.0 else Vector2.ZERO
		P.inp["jump"] = t < DT
		if _at(t, 0.3):
			P.do_dash()
		_aim(T.pos)
	await _go(2.6, dash, [], 2.5)
	await _go(GAP)

func _part_glide() -> void:
	await _reset(11.0)
	P.teleport(home + Vector3(-9, 0, 0))
	_key("%s, then hold %s  glide" % [Settings.key_cap("jump"), Settings.key_cap("jump")])
	P.pos.y += 5.0
	P.grounded = false
	var glide := func(t: float):
		P.inp["move"] = Vector2(1, 0)
		P.inp["glide"] = t > 0.2
		_aim(T.pos)
	await _go(3.6, glide, [], 3.0)
	P.inp["glide"] = false
	P.inp["move"] = Vector2.ZERO
	await _go(GAP)

## A running jump into the dais's south face (the Arena's one ledge), the lip caught on the way up.
func _part_mantle() -> void:
	var w: World = m.world
	var face_z := 0
	for z in range(w.h - 2, 1, -1):
		if int(w.level[w.idx(DAIS_X, z)]) == 0 and int(w.level[w.idx(DAIS_X, z - 1)]) == 1:
			face_z = z
			break
	var start := Vector3(DAIS_X + 0.5, 0.0, face_z + 5.5)
	_key("%s  run into the ledge, %s  jump" % [Settings.key_cap("up"), Settings.key_cap("jump")])
	await _reset(8.0)
	P.teleport(start)
	_aim(start + Vector3(0, 0, -8))
	var run := func(t: float):
		P.inp["move"] = Vector2(0, -1)
		P.inp["jump"] = P.pos.z < face_z + 1.6 and P.grounded and t > 0.2
		P.inp["aim"] = P.pos + Vector3(0, 0.9, -8)
	await _go(3.0, run, [], 2.5)
	P.inp["move"] = Vector2.ZERO
	await _go(GAP)
