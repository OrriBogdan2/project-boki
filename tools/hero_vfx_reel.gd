extends "res://tools/combo51_shots.gd"
## --hero-vfx-reel --shots-dir=<dir> [--reel-hero=<arch>] [--reel-only=<part>]: a Hero's whole ability set played
## through in a live Arena match at the match camera, for the approval gate. One PNG sheet per ability (a grid
## of crops round the action, <dir>/<hero>_<part>.png) and REEL_MARK lines with the frame each part starts on.
## A Hero with a script of its own (tools/vfx_reel/<arch>.gd, extending this one: PARTS and `_part_<name>` funcs)
## plays its scripted parts; any other plays the generic set (LMB, RMB, Shift, E, R at a dummy).
## Run it under the movie writer so the looks run on the fixed step and the real mix is recorded:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 60 \
##       --write-movie <dir>/reel.avi -- --hero-vfx-reel --shots-dir=<dir>

const GENERIC := ["lmb", "rmb", "dash", "e", "r"]
const GAP := 0.7               # s of quiet between parts
const SHEET_CROP := Vector2i(440, 300)    # px of each sheet frame

var only := ""
var frames := 0

## The parts this reel plays (a Hero's own script overrides it).
func parts() -> Array:
	return GENERIC

func run(main_node: Node) -> void:
	main = main_node
	who = "juggernaut"
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--reel-hero="):
			who = arg.substr(12)
		if arg.begins_with("--reel-only="):
			only = arg.substr(12)
	var own := "res://tools/vfx_reel/%s.gd" % who
	if get_script().resource_path != own and ResourceLoader.exists(own):
		await load(own).new().run(main_node)
		return
	hero_name = String(who)
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	P.lvl = 6
	for slot in P.slot_lv:
		P.slot_lv[slot] = 3
	for part: String in parts():
		if only != "" and part != only:
			continue
		print("REEL_MARK %d %s" % [Engine.get_frames_drawn(), part])
		P.ak.res = 0.0              # (each part starts cool: a resource from the last one would go off in this one)
		await Callable(self, "_part_%s" % part).call()
	_write_captions()
	print("REEL_DONE %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## (the match's own step is off here, so the ears and the detail share follow from this)
func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	Sfx.listener = P.pos
	await super._go(secs, each, marks, lead)

## Larger crops than the shared strips: an area look must fit, at the match camera's own scale.
func _take(kind: String, _file: String, caption: String, focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var at: Vector3 = focus.call() if focus.is_valid() else (P.position + T.position) * 0.5 + Vector3(0, 0.9, 0)
	var crop := _crop(img, at, SHEET_CROP, 1.0)
	var strip_file := "%s_%s.png" % [hero_name, kind]
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("%s|%s|%s" % [hero_name, strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)

## A strip's marks at match zoom, the crop following `focus` (the hero, if left out).
func _sheet(part: String, caption: String, times: Array, focus := Callable()) -> Array:
	var out: Array = []
	for t in times:
		out.append([t, part, "", caption, focus])
	return out

# ------------------------------------------------------------------ the generic parts
func _part_lmb() -> void:
	await _reset(3.3)
	var shoot := func(t: float):
		P.inp["fire"] = fmod(t, 0.5) < DT * 2.0 and t < 1.9
		_aim(T.pos)
	await _go(2.1, shoot, _sheet("lmb", "LMB at the dummy", [0.05, 0.1, 0.18, 0.3, 0.55, 0.62, 0.7, 1.0, 1.6]), 1.5)
	await _go(GAP)

func _part_rmb() -> void:
	await _reset(4.0)
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(2.4, cast, _sheet("rmb", "RMB at the dummy", [0.15, 0.25, 0.35, 0.5, 0.65, 0.8, 1.0, 1.4, 2.0]), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.3:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.8, dash, _sheet("dash", "Shift", [0.18, 0.25, 0.33, 0.42, 0.5, 0.6, 0.8, 1.1, 1.6]), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(2.4, cast, _sheet("e", "E at the dummy", [0.15, 0.25, 0.35, 0.5, 0.65, 0.8, 1.0, 1.4, 2.0]), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(4.0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(T.pos)
	await _go(2.8, cast, _sheet("r", "R, the ultimate", [0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.4, 1.9, 2.6]), 2.5)
	await _go(GAP)
