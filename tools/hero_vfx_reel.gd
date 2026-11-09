extends "res://tools/combo51_shots.gd"
## --hero-vfx-reel --shots-dir=<dir> [--reel-hero=<arch>] [--reel-only=<part>]: a Hero's whole ability set played
## through in a live Arena match at the match camera, for the approval gate. One PNG sheet per ability (a grid
## of crops round the action, <dir>/<hero>_<part>.png) and REEL_MARK lines with the frame each part starts on.
## A Hero with a script of its own (tools/vfx_reel/<arch>.gd, extending this one: parts() and `_part_<name>` funcs)
## plays its scripted parts; Kael and Lisette's are below; any other plays the generic set (LMB, RMB, Shift, E, R).
## Run it under the movie writer so the looks run on the fixed step and the real mix is recorded:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path . --fixed-fps 60 \
##       --write-movie <dir>/reel.avi -- --hero-vfx-reel --shots-dir=<dir>
## --reel-frames also saves every drawn frame as <dir>/frames/NNNNN.jpg (FRAME_W wide), for a clip made off the
## box (jobq's GPU worker returns the out dir, not a movie): ffmpeg -framerate 60 -i <dir>/frames/%05d.jpg ...

const HERO_PARTS := {"juggernaut": ["lmb", "wave", "slam", "lunge", "drop", "dash", "e", "spin", "r", "rage", "voice"],
	"archer": ["string", "lmb", "miss", "super", "heavy", "dash", "e", "r", "voice"],
	"dredge": ["lmb", "hook", "e"]}
const GENERIC := ["lmb", "rmb", "dash", "e", "r"]
const GAP := 0.7               # s of quiet between parts
const SHEET_CROP := Vector2i(440, 300)    # px of each sheet frame
const WIDE_CROP := Vector2i(640, 300)     # ... for a bow's long shots
const FRAME_W := 960                      # px wide, each --reel-frames frame

var only := ""
var frame_dir := ""            # --reel-frames: where each drawn frame goes
var crop_px := SHEET_CROP
var crop_zoom := 1.0
var frames := 0

## The parts this reel plays (a Hero's own script overrides it).
func parts() -> Array:
	return HERO_PARTS.get(who, GENERIC)

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
		if arg == "--reel-frames":
			frame_dir = "frames"
	var own := "res://tools/vfx_reel/%s.gd" % who
	if get_script().resource_path != own and ResourceLoader.exists(own):
		await load(own).new().run(main_node)
		return
	hero_name = String(who)
	if who == "archer":
		crop_px = WIDE_CROP
	DirAccess.make_dir_recursive_absolute(dir)
	if frame_dir != "":
		frame_dir = dir.path_join(frame_dir)
		DirAccess.make_dir_recursive_absolute(frame_dir)
	await _setup()
	HeroVfx.of(m).fixed_dt = DT     # the looks age with the stepped match, not the (slow, saving) frames
	P.lvl = 6
	for slot in P.slot_lv:
		P.slot_lv[slot] = 3
	for part: String in parts():
		if only != "" and part != only:
			continue
		print("REEL_MARK %d %s" % [Engine.get_frames_drawn(), part])
		P.ak.res = 0.0              # (each part starts cool: Rage from the last one would go off in this one)
		P.ak.set("enraged_t", 0.0)
		await Callable(self, "_%s_%s" % [who, part] if HERO_PARTS.has(who) else "_part_" + part).call()
	_write_captions()
	print("REEL_DONE %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

## (the match's own step is off here, so the ears and the detail share follow from this)
func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	Sfx.listener = P.pos
	var step := each
	if frame_dir != "":
		step = func(t: float) -> void:
			_save_frame()
			if each.is_valid():
				each.call(t)
	await super._go(secs, step, marks, lead)

## (--reel-frames) the frame last drawn, scaled down to FRAME_W
func _save_frame() -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.resize(FRAME_W, FRAME_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
	img.save_jpg(frame_dir.path_join("%05d.jpg" % frames), 0.88)
	frames += 1

## Larger crops than the shared strips: an area look must fit, at the match camera's own scale.
func _take(kind: String, _file: String, caption: String, focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	var at: Vector3 = focus.call() if focus.is_valid() else (P.position + T.position) * 0.5 + Vector3(0, 0.9, 0)
	var crop := _crop(img, at, crop_px, crop_zoom)
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

# ------------------------------------------------------------------ Kael
func _juggernaut_lmb() -> void:
	await _reset(3.3)
	var swing := func(t: float):
		P.inp["fire"] = fmod(t, 0.5) < DT * 2.0 and t < 1.9
		_aim(T.pos)
	await _go(2.1, swing, _sheet("lmb",
			"LMB Greatsword: a slash, the arc burning away, tip burst on the dummy; the next slash "
			+ "back the other way",
			[0.04, 0.09, 0.15, 0.22, 0.3, 0.54, 0.6, 0.68, 0.8]), 1.5)
	await _go(GAP)

func _juggernaut_wave() -> void:
	await _reset(8.5)
	var hold := func(t: float):
		P.inp["fire"] = t < 1.15
		_aim(T.pos)
	await _go(2.9, hold, _sheet("wave",
			"LMB hold, Searing Wave: the blade heating (AimKit's lane fills), the release, the wave "
			+ "burning a lane that cools to fissures",
			[0.5, 1.0, 1.2, 1.3, 1.4, 1.6, 1.9, 2.3, 2.8]), 3.0)
	await _go(GAP)

func _juggernaut_slam() -> void:
	await _reset(3.2)
	var K: JuggernautKit = P.ak
	var slam := func(t: float):
		if _at(t, 0.1):
			K.press_rmb()
		_aim(T.pos)
	await _go(2.5, slam, _sheet("slam",
			"RMB tap, Finishing Slam: the wind-up gathers at the blade, the strike opens a burning "
			+ "cone, debris, sweet spot on the dummy, fissures cool",
			[0.3, 0.6, 0.72, 0.76, 0.82, 0.92, 1.1, 1.5, 2.2]), 1.5)
	await _go(GAP)

func _juggernaut_lunge() -> void:
	await _reset(7.0)
	var K: JuggernautKit = P.ak
	var lunge := func(t: float):
		if _at(t, 0.1):
			P.inp["sec_hold"] = true
			K.press_rmb()
		if t >= 1.25:
			P.inp["sec_hold"] = false
		_aim(T.pos)
	await _go(2.8, lunge, _sheet("lunge",
			"RMB hold, Lunge: charging (the lane is AimKit's), full flash at the blade, the fling "
			+ "with its mesh trails, the impact, the scorched line",
			[0.5, 0.9, 1.2, 1.32, 1.4, 1.48, 1.6, 1.9, 2.6]), 3.0)
	await _go(GAP)

func _juggernaut_drop() -> void:
	await _reset(5.0)
	var K: JuggernautKit = P.ak
	var drop := func(t: float):
		P.inp["jump"] = t < DT
		if _at(t, 0.3):
			K.press_rmb()
		_aim(T.pos)
	await _go(3.0, drop, _sheet("drop",
			"RMB in the air, Meteor Drop: the gather over the marker, the comet dive, the ground "
			+ "breaking open, the wall of flame at the stun's edge, debris, cooling fissures",
			[0.34, 0.45, 0.55, 0.64, 0.7, 0.8, 1.0, 1.6, 2.6]), 2.0)
	await _go(GAP)

func _juggernaut_dash() -> void:
	await _reset(6.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.3:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.8, dash, _sheet("dash",
			"Shift, Rampage: the crouch, the drive with its trail, the tip's arc, the scorched "
			+ "line",
			[0.2, 0.33, 0.42, 0.5, 0.58, 0.66, 0.8, 1.1, 1.7]), 2.5)
	await _go(GAP)

func _juggernaut_e() -> void:
	await _reset(10.0)
	var K: JuggernautKit = P.ak
	var chain := func(t: float):
		if _at(t, 0.1):
			K.use_e()
		if _at(t, 1.2):
			K.use_e()
		P.inp["move"] = Vector2(-1, 0) if t > 0.5 and t < 1.2 else Vector2.ZERO
		_aim(T.pos)
	var on_action := func() -> Vector3:
		var at_foe: bool = K.warchain.state == "hooked"
		return (T.position if at_foe else P.position) + Vector3(0, 0.9, 0)
	await _go(2.6, chain, _sheet("e",
			"E, Warchain: the throw from the hand, the hook biting the dummy (sparks, a scorch), the "
			+ "chain straining as he backs off, E again: the haul with sparks off his feet, the arrival",
			[0.13, 0.3, 0.38, 0.5, 0.9, 1.24, 1.32, 1.5, 1.8], on_action), 4.5)
	await _go(GAP)

func _juggernaut_spin() -> void:
	await _reset(9.0)
	var K: JuggernautKit = P.ak
	var spin := func(t: float):
		if _at(t, 0.1):
			K.use_e()
		if _at(t, 0.55):
			K.use_e()
		if _at(t, 0.8):
			K.press_rmb()
		_aim(T.pos)
	await _go(2.0, spin, _sheet("spin",
			"Smash in the Warchain's pull, Cinder Spin: the full arc, the low wall of flame, the "
			+ "burn under him",
			[0.75, 0.82, 0.88, 0.96, 1.05, 1.15, 1.3, 1.5, 1.8]), 4.0)
	await _go(GAP)

func _juggernaut_r() -> void:
	await _reset(3.0)
	var K: JuggernautKit = P.ak
	var ult := func(t: float):
		if _at(t, 0.1):
			K.cd["x"] = 0.0
			K.cast_ult()
		if _at(t, 0.4):
			K.riposte.block(T, {})
		_aim(T.pos)
	await _go(2.7, ult, _sheet("r",
			"X, Gilded Riposte: the gold guard, a blocked hit, the cleave up through the strip, the "
			+ "gold scorch and embers",
			[0.2, 0.42, 0.6, 0.77, 0.84, 0.92, 1.05, 1.5, 2.5]), 1.5)
	await _go(GAP)

func _juggernaut_rage() -> void:
	await _reset(3.3)
	var K: JuggernautKit = P.ak
	var rage := func(t: float):
		if _at(t, 0.1):
			K.gain_rage(K.res_max())
		P.inp["fire"] = t > 0.8 and fmod(t, 0.5) < DT * 2.0
		_aim(T.pos)
	await _go(2.4, rage, _sheet("rage", "Enraged: the flare as Rage fills, the body burning, slashes keeping it fed",
			[0.13, 0.2, 0.3, 0.6, 0.86, 1.0, 1.4, 1.9, 2.3]), 1.5)
	K.enraged_t = 0.0
	await _go(GAP)

## The sounds with no key of their own: footsteps by surface, the hurt grunts and the downed grunt.
func _juggernaut_voice() -> void:
	await _reset(12.0)
	var step_k := 0
	var walk := func(t: float):
		P.inp["move"] = Vector2(0, -1) if t < 2.2 else Vector2.ZERO
		if fmod(t, 0.32) < DT:
			var surface: String = ["grass", "stone", "snow", "wood"][int(t / 0.56) % 4]
			Sfx.play(HeroSfx.of(P, "step_" + surface, "step_" + surface), P.pos, -13.0, 0.08)
			step_k += 1
		if _at(t, 2.5) or _at(t, 2.9) or _at(t, 3.3):
			HeroSfx.voice(m, P, "hurt")
		if _at(t, 3.8):
			HeroSfx.voice(m, P, "down")
		_aim(T.pos)
	await _go(5.0, walk)


func _archer_string() -> void:
	await _reset(8.0)
	var gun: Node3D = P.model.get_node("Rig/Torso/Aim/Gun")
	for c in gun.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			print("GUNMESH ", c.name, " ", (c as MeshInstance3D).get_aabb(), " ", c.scale)
	var idle := func(_t: float):
		_aim(T.pos)
	crop_px = Vector2i(220, 150)
	crop_zoom = 3.0
	var on_her := func() -> Vector3: return P.position + Vector3(0, 0.9, 0)
	await _go(1.0, idle, _sheet("string", "The glowing thread bowstring at rest, then drawn back to the hand",
			[0.3, 0.6, 0.95], on_her), 2.0)
	var pull := func(t: float):
		P.inp["fire"] = t < 0.5
		_aim(T.pos)
	await _go(0.9, pull, _sheet("string", "", [0.2, 0.4, 0.55], on_her), 2.0)
	crop_px = WIDE_CROP
	crop_zoom = 1.0
	await _go(GAP)

func _archer_lmb() -> void:
	await _reset(8.0)
	var shots := func(t: float):
		P.inp["fire"] = t < 0.04 or (t >= 0.8 and t < 1.5)
		_aim(T.pos)
	await _go(2.6, shots, _sheet("lmb",
			"LMB: a tap needle, then the Empowered draw: thread gathering at the nock, the needle with its "
			+ "red thread trailing, the hit on the dummy", [0.06, 0.14, 0.3, 0.9, 1.3, 1.53, 1.58, 1.65, 1.8]), 3.0)
	await _go(GAP)

## Grimble's gun at the dummy: fire held for four volleys (the spread lines kick wide on each and breathe back
## between), let go so they close and fold to the aim line, then one tap fired tight.
func _dredge_lmb() -> void:
	await _reset(5.5)
	var shots := func(t: float):
		P.inp["fire"] = t < 1.75 or (t >= 3.0 and t < 3.05)
		_aim(T.pos)
	await _go(4.0, shots, _sheet("lmb",
			"LMB: four held volleys (the spread lines kick wide, breathe in between), let go (they close and fold), "
			+ "a tight tap", [0.05, 0.3, 0.55, 0.8, 1.3, 1.9, 2.3, 2.8, 3.1]), 3.0)
	await _go(GAP)

## Grimble's RMB at the dummy: the arm stretches out, the hook bites, the reel hauls it in.
func _dredge_hook() -> void:
	await _reset(8.0)
	var K: DredgeKit = P.ak
	var hook := func(t: float):
		if _at(t, 0.1):
			K.press_rmb()
		_aim(T.pos)
	await _go(2.4, hook, _sheet("hook",
			"RMB, the hook: the arm stretches to the dummy, the hook bites, the reel hauls it in, the arm snaps back",
			[0.15, 0.3, 0.45, 0.6, 0.9, 1.2, 1.5, 1.8, 2.2]), 3.0)
	await _go(GAP)

## Grimble's E at the dummy: the giant scrap fist forms raised over the cone through the 0.38 s wind-up, then
## smashes down on the strike frame and crumbles.
func _dredge_e() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		_aim(T.pos)
	await _go(2.0, cast, _sheet("e",
			"E, Anchor Drop: the scrap fist forms over the cone in the wind-up, smashes down on the strike, crumbles",
			[0.15, 0.25, 0.35, 0.45, 0.5, 0.53, 0.6, 0.75, 1.0]), 2.5)
	await _go(GAP)

func _archer_miss() -> void:
	await _reset(8.0)
	var off := home + Vector3(5.5, 0, -2.5)
	var shots := func(t: float):
		P.inp["fire"] = fmod(t, 0.9) < 0.04 and t < 1.9
		_aim(off + Vector3(0, 0, 1.6 * floor(t / 0.9)))
	await _go(4.6, shots, _sheet("miss",
			"Missed needles stay stuck in the ground with their red threads attached, 4 s, swaying, then they run out",
			[0.1, 0.3, 0.6, 1.2, 2.0, 2.8, 3.6, 4.2, 4.5], func() -> Vector3: return off), 3.0)
	await _go(GAP)

func _archer_super() -> void:
	await _reset(11.0)
	var shot := func(t: float):
		P.inp["fire"] = t < 1.55
		_aim(T.pos)
	await _go(2.8, shot, _sheet("super",
			"LMB held to Supercharged: the ready ring, the release (the gold perfect burst stays), the long thread, "
			+ "the silver crack on the dummy", [0.6, 1.1, 1.5, 1.58, 1.64, 1.72, 1.85, 2.2, 2.7]), 3.0)
	await _go(GAP)

func _archer_heavy() -> void:
	await _reset(8.0)
	var K: ArcherKit = P.ak
	var heavy := func(t: float):
		if _at(t, 0.1):
			P.inp["sec_hold"] = true
			K.press_rmb()
		if t >= 1.3:
			P.inp["sec_hold"] = false
		_aim(T.pos)
	await _go(3.0, heavy, _sheet("heavy",
			"RMB Heavy Shot: the bar (AimKit) and thread gathering, the big red needle (HEAVY_SCALE) with "
			+ "its thick thread, the shove, the seam it leaves",
			[0.6, 1.2, 1.33, 1.38, 1.44, 1.52, 1.7, 2.2, 2.9]), 3.0)
	await _go(GAP)

func _archer_dash() -> void:
	await _reset(7.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		P.inp["move"] = Vector2(1, 0) if t >= 0.15 and t < 2.0 else Vector2.ZERO
		_aim(T.pos)
	var on_her := func() -> Vector3: return P.position + Vector3(0, 0.9, 0)
	await _go(3.6, dash, _sheet("dash",
			"Shift, Spirit Walk: the roll unspooling thread, the walk trailing loose threads through a rock, the end",
			[0.2, 0.28, 0.36, 0.5, 0.9, 1.5, 2.2, 3.0, 3.4], on_her), 2.0)
	await _go(GAP)

func _archer_e() -> void:
	await _reset(7.0)
	var K: ArcherKit = P.ak
	var hail := func(t: float):
		if _at(t, 0.1):
			K.cd["e"] = 0.0
			K.cast_e()
		_aim(T.pos)
	await _go(5.4, hail, _sheet("e",
			"E Hail Wall: the volley up, needles raining on the arc, silver sparks where they land, the red "
			+ "thread stitched post to post", [0.2, 0.42, 0.6, 1.0, 2.0, 3.0, 4.0, 4.7, 5.2],
			func() -> Vector3: return T.position + Vector3(0, 0.9, 0)), 3.0)
	await _go(GAP)

func _archer_r() -> void:
	await _reset(9.0)
	var K: ArcherKit = P.ak
	var ult := func(t: float):
		if _at(t, 0.1):
			K.cd["x"] = 0.0
			K.cast_ult()
		P.inp["fire"] = t > 0.6 and t < 0.66 or t > 1.6 and t < 1.66 or t > 2.6 and t < 2.66
		_aim(T.pos)
	await _go(4.6, ult, _sheet("r",
			"X Starpiercer: armed, a nock, the beam stitching a seam across the ground, the hit, the last and "
			+ "deepest beam", [0.15, 0.3, 0.8, 0.95, 1.05, 1.3, 2.95, 3.1, 4.4]), 3.0)
	await _go(GAP)

func _archer_voice() -> void:
	await _reset(12.0)
	var walk := func(t: float):
		P.inp["move"] = Vector2(0, -1) if t < 2.2 else Vector2.ZERO
		if fmod(t, 0.28) < DT:
			var surface: String = ["grass", "stone", "snow", "wood"][int(t / 0.56) % 4]
			Sfx.play(HeroSfx.of(P, "step_" + surface, "step_" + surface), P.pos, -13.0, 0.08)
		if _at(t, 2.5) or _at(t, 2.9) or _at(t, 3.3):
			HeroSfx.voice(m, P, "hurt")
		if _at(t, 3.8):
			HeroSfx.voice(m, P, "down")
		_aim(T.pos)
	await _go(5.0, walk)
