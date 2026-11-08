extends RefCounted
## --vv-shots --shots-dir=<dir> [--vv-hero=mage|gunslinger] [--vv-tag=v2/polish]: screenshots of Sparkle's
## and Vex's abilities in a live Arena match (run under xvfb with a renderer). Each moment is taken at
## the default gameplay zoom and again as a close-up crop round what it shows; every move also gets a
## 4-6 frame strip cropped round the hero (anticipation, release, follow-through, recovery). Files go
## straight into <dir> as <hero>_<name>.png, and <dir>/MANIFEST_<hero>.txt gets one line per file:
## "<hero>/<tag>|<file>|<caption>". Uses only long-standing match and kit calls. With --vv-ult only the
## ultimate's shots are taken (tools/vv_ult_shots.gd); with --vv-only=<part> only that part (for example
## dash or lmb: _<hero>_<part>), to retake one move.

const DT := 1.0 / 60.0
const STRIP_CROP := Vector2i(120, 140)       # px round the hero for a strip frame (scaled 2.5x)
const CLOSE_CROP := Vector2i(320, 220)       # px round the subject for a close-up (scaled 2x)

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var T2: Hunter                 # a second dummy for the wall-cone shot
var dir := ""
var tag := "v2/polish"
var who := "mage"
var hero_name := "vireo"
var home := Vector3.ZERO
var lines: Array = []
var strips := {}               # strip file -> Array of Image
var ult_only := false
var only_part := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--vv-hero="):
			who = arg.substr(10)
		if arg.begins_with("--vv-tag="):
			tag = arg.substr(9)
		if arg == "--vv-ult":
			ult_only = true
		if arg.begins_with("--vv-only="):
			only_part = arg.substr(10)
	hero_name = "vireo" if who == "mage" else "venator"
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	if ult_only:
		await load("res://tools/vv_ult_shots.gd").new(self).run_for(who)
	elif only_part != "":
		await Callable(self, "_%s_%s" % [hero_name, only_part]).call()
	elif who == "mage":
		await _vireo()
	else:
		await _venator()
	var f := FileAccess.open(dir.path_join("MANIFEST_%s.txt" % hero_name), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("VVSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _setup() -> void:
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts(who), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T:
			x.teleport(home + Vector3(-30, 0, 30))
	await _reset(7.0)

## A flat stretch of island away from the start (as tools/aimkit_shots.gd).
func _spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(6, W.h - 6, 3):
		for x in range(6, W.w - 18, 3):
			if Vector2(x - start.x, z - start.z).length() >= 24.0 and _flat(W, x, z):
				return Vector3(x + 0.5, int(W.level[W.idx(x, z)]) * World.LEVEL, z + 0.5)
	return start

func _flat(W, x: int, z: int) -> bool:
	var lv: int = int(W.level[W.idx(x, z)])
	for dz in range(-4, 5):
		for dx in range(-3, 15):
			var i: int = W.idx(x + dx, z + dz)
			var odd: bool = W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i)
			if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or odd:
				return false
	return true

func _reset(td: float, tz := 0.0) -> void:
	P.teleport(home)
	P.vel = Vector3.ZERO
	T.teleport(home + Vector3(td, 0, tz))
	T.vel = Vector3.ZERO
	T.hp = T.max_hp
	T.armor = 0.0                  # an unarmoured target: crits show as the gold numbers
	T.stun_t = 0.0
	T.inv_t = 0.0
	for k in ["fire", "sec_hold", "dash_down"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	var sp = P.ak.get("sparks")
	if sp is Dictionary:
		(sp as Dictionary).clear()
	if T.has_meta("rat_until"):
		T.set_meta("rat_until", 0.0)
	P.ak.cd["rmb"] = 0.0
	P.ak.cd["e"] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())
	P.dashes = P.max_dashes()
	P.ex_cd = 0.0
	_aim(T.pos)
	await _go(0.5)
	T.inv_t = 0.0

func _aim(p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = p.y

var cam_at := Vector3.ZERO           # a fixed camera point (zero: the camera follows the hero)

## Steps the match `secs`, rendering every frame; `each` runs before each step; `marks` is
## [[time, kind, file, caption, focus], ...]: kind "full" (the view plus a close-up round `focus`, a
## Callable giving a world point, the hero if left out) or a strip file (a crop round the hero).
func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	var t0 := 0.0
	var todo := marks.duplicate()
	todo.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	while t0 < secs:
		if each.is_valid():
			each.call(t0)
		m.step(DT)
		t0 += DT
		_park_others()
		if P.roll_t <= 0.0:
			P.face = atan2(-(P.inp["aim"].x - P.pos.x), -(P.inp["aim"].z - P.pos.z))
		m.cam.snap(cam_at if cam_at != Vector3.ZERO else P.pos + Vector3(lead, 0, 0))
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
		while not todo.is_empty() and t0 >= float(todo[0][0]):
			var mk: Array = todo.pop_front()
			var focus: Callable = mk[4] if mk.size() > 4 else Callable()
			_take(String(mk[1]), String(mk[2]), String(mk[3]), focus)

## The Arena's moving dummies walk back toward the player; keep them parked far off so none ends up
## between the camera and the hero (that was the pink blob filling the last strip frames).
func _park_others() -> void:
	for x in m.hunters:
		if x != P and x != T and x != T2 and x.flat_dist(P) < 26.0:
			x.teleport(home + Vector3(-30, 0, 30))
			x.vel = Vector3.ZERO

func _take(kind: String, file: String, caption: String, focus: Callable) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if kind == "full":
		var name_full := "%s_%s.png" % [hero_name, file]
		img.save_png(dir.path_join(name_full))
		lines.append("%s/%s|%s|%s" % [hero_name, tag, name_full, caption])
		var at: Vector3 = focus.call() if focus.is_valid() else P.position + Vector3(0, 0.9, 0)
		var close := _crop(img, at, CLOSE_CROP, 2.0)
		var name_close := "%s_%s_close.png" % [hero_name, file]
		close.save_png(dir.path_join(name_close))
		lines.append("%s/%s|%s|%s (close-up)" % [hero_name, tag, name_close, caption])
		return
	var crop := _crop(img, P.position + Vector3(0, 0.9, 0), STRIP_CROP, 2.5)
	var strip_file := "%s_%s.png" % [hero_name, kind]
	if not strips.has(strip_file):
		strips[strip_file] = []
		lines.append("%s/%s|%s|%s" % [hero_name, tag, strip_file, caption])
	(strips[strip_file] as Array).append(crop)
	_save_strip(strip_file)

## The region `px` round world point `at` on the image, scaled by `zoom`.
func _crop(img: Image, at: Vector3, px: Vector2i, zoom: float) -> Image:
	var cam := main.get_viewport().get_camera_3d()
	var c := cam.unproject_position(at)
	var corner := Vector2i(int(c.x) - px.x / 2, int(c.y) - px.y / 2)
	var rg := Rect2i(corner, px).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(px.x * zoom), int(px.y * zoom), Image.INTERPOLATE_BILINEAR)
	return crop

func _save_strip(file: String) -> void:
	var frames: Array = strips[file]
	var w: int = (frames[0] as Image).get_width()
	var hh: int = (frames[0] as Image).get_height()
	var out := Image.create(w * frames.size() + 4 * (frames.size() - 1), hh, false, (frames[0] as Image).get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in frames.size():
		var fr: Image = frames[i]
		out.blit_rect(fr, Rect2i(Vector2i.ZERO, Vector2i(fr.get_width(), fr.get_height())), Vector2i(i * (w + 4), 0))
	out.save_png(dir.path_join(file))

## Strip marks for `file` at each of `times` (the caption goes on the first).
func _strip(file: String, caption: String, times: Array) -> Array:
	var out: Array = []
	for tt in times:
		out.append([tt, file, file, caption])
	return out

func _on_target() -> Vector3:
	return T.position + Vector3(0, 1.0, 0)

func _above_target() -> Vector3:
	return T.position + Vector3(0, 2.4, 0)

# ------------------------------------------------------------------ Sparkle
func _vireo() -> void:
	await _vireo_run()
	await _vireo_lmb()
	await _vireo_static()
	await _vireo_rmb()
	await _vireo_dash()
	await _vireo_e()

## Her run: upright, both arms held out wide (the body sheet), at her 0.96 scale.
func _vireo_run() -> void:
	await _reset(7.0, 6.0)
	_aim(home + Vector3(12.0, 0, 0))
	var run := func(_t: float): P.inp["move"] = Vector2(1, 0)
	var marks := _strip("anim_run", "Run: upright, both arms held out wide, short quick steps", [0.3, 0.42, 0.54, 0.66])
	marks.append([0.5, "full", "run", "Running at gameplay zoom: arms out wide, 0.96 scale, the wider shoulders"])
	await _go(0.7, run, marks)
	P.inp["move"] = Vector2.ZERO

func _vireo_lmb() -> void:
	await _reset(7.0)
	_aim(home + Vector3(3.0, 0, 0))
	await _go(0.2,
			Callable(),
			[[0.15, "full", "lmb_aim", "LMB aim: the line runs through a near cursor (3m) on to full range"]])
	await _reset(9.0)
	var hold_fire := func(_t: float): P.inp["fire"] = true
	var beats := [0.01, 0.03, 0.06, 0.09, 0.2, 0.35]
	var marks := _strip("anim_lmb_l",
			"LMB left hand: rest, drawn back to the chest, flung out with the finger pointed,"
		+ "the recoil snap up, follow-through, settled", beats)
	var right: Array = []
	for b in beats:
		right.append(0.8 + float(b))
	marks += _strip("anim_lmb_r", "LMB right hand (the finger gun): rest, pulled in, punched out, the wrist "
		+ "flicked up by the recoil, follow-through, settled", right)
	marks.append([0.05,
			"full",
			"lmb_fire",
			"LMB release: the arm out, the fingertip crackling with teal arcs, gold sparks at her feet"])
	marks.append([0.14, "full", "lmb_bolt", "LMB: the jagged teal bolt (about 1.2m) in flight, gold core", _bolt_spot])
	marks.append([0.3,
			"full",
			"lmb_impact",
			"LMB impact: teal splinters spray back toward her; the Static marker above the HP bar",
			_on_target])
	await _go(1.25, hold_fire, marks)
	P.inp["fire"] = false

func _bolt_spot() -> Vector3:
	return P.position + Vector3(4.0, 1.0, 0)

func _vireo_static() -> void:
	var K = P.ak
	await _reset(6.0)
	K.add_spark(T, 1)
	var one := "Static 1: one pip lit, a bold 1 on a dark disc above the HP bar, 2 body sparks"
	await _go(0.3, Callable(), [[0.25, "full", "static_1", one, _on_target]])
	K.add_spark(T, 1)
	await _go(0.3,
			Callable(),
			[[0.25, "full", "static_2", "Static 2: two pips, the count, 4 sparks on the body", _on_target]])
	K.add_spark(T, 2)
	var live := _strip("anim_live",
			"Passive proc: a foe goes Live, her left hand flicked up to the sky as the bolt drops",
			[0.01, 0.07, 0.15, 0.3, 0.5])
	live.append([0.06,
			"full",
			"static_live",
			"Static 4: the sky bolt, LIVE above the marker, all pips gold, 8 sparks and arcs",
			_on_target])
	await _go(0.6, Callable(), live)

func _vireo_rmb() -> void:
	var K = P.ak
	await _reset(6.0)
	K.press_rmb()
	var hold_r := func(_t: float): P.inp["sec_hold"] = true
	var marks := _strip("anim_rmb_hold",
			"RMB summon and hold: the rod arrives in a burst, the arm raises it upright by the shoulder, side-on",
			[0.02, 0.06, 0.14, 0.4, 0.9])
	marks.append([0.05,
			"full",
			"rmb_summon",
			"RMB pressed: the copper Storm Rod arrives in her raised hand with a teal crackle and a ring"])
	marks.append([0.5,
			"full",
			"rmb_aim",
			"RMB held: the rod upright in her hand (no RELOADING), a fixed double-rail lane to full range"])
	marks.append([1.0, "full", "rmb_full", "RMB full: the white body flash, the lane gold"])
	await _go(1.02, hold_r, marks)
	P.inp["sec_hold"] = false
	var throw := _strip("anim_rmb_throw",
			"RMB throw: overarm whip, stretch at the release, follow-through, recover",
			[0.01, 0.06, 0.12, 0.25, 0.5])
	throw.append([0.18,
			"full",
			"rmb_impact",
			"RMB impact: a gold blast, teal crackle and a shock ring, the target knocked back",
			_on_target])
	throw.append([0.75,
			"full",
			"rmb_orb",
			"The charge orb: a gold core in a teal shell with spinning bands, short teal arcs crackling off it",
			_orb_spot])
	await _go(0.8, Callable(), throw)

func _orb_spot() -> Vector3:
	var motes: Array = P.ak.get("motes")
	return (motes[0]["pos"] as Vector3) + Vector3(0, 0.6, 0) if not motes.is_empty() else _on_target()

func _vireo_dash() -> void:
	var K = P.ak
	await _reset(6.0)
	_aim(home + Vector3(3.0, 0, 0))
	P.inp["dash_down"] = true
	P.do_dash()
	var hold_d := func(_t: float): P.inp["dash_down"] = true
	var marks := _strip("anim_dash",
			"Shift: the charging crouch, the streak (her gold-teal after-images), re-forming on arrival",
			[0.05, 0.3, 0.6])
	marks.append([0.25,
			"full",
			"dash_aim_mid",
			"Shift held: rails out to max, the ticked end ring partway (the cursor plays no part)"])
	marks.append([0.6, "full", "dash_aim_full", "Shift held to full: the end ring at 8.5m, past the 3m cursor"])
	await _go(0.62, hold_d, marks)
	P.inp["dash_down"] = false
	var run := _strip("anim_dash", "", [0.06, 0.42, 0.6])
	run.append([0.08,
			"full",
			"dash_run",
			"Shift released: a lightning streak, the body a trail of her own gold-teal after-images"])
	run.append([0.46, "full", "dash_arrive",
			"Shift arrival: she re-forms with a dust puff (no ring or burst: the hits are along the way)"])
	await _go(0.8, Callable(), run, 6.0)
	# the base air dash (her own variant): a tumble with teal after-images in her silhouette
	await _reset(6.0, 6.0)
	P.dashes = 0.0
	P.do_dash()
	var ex := _strip("anim_dash_ex",
			"Air dash (her base dash variant): the tuck, the forward tumble, her teal after-images, the landing",
			[0.02, 0.07, 0.14, 0.22, 0.36, 0.5])
	ex.append([0.15,
			"full",
			"dash_ex",
			"Air dash: her own teal after-images (her silhouette, not a shared pill) and the teal streak"])
	await _go(0.6, Callable(), ex)
	# the payoff: Wirerun through a Live target
	await _reset(5.0)
	K.add_spark(T, 4)
	_aim(T.pos + Vector3(3, 0, 0))
	P.inp["dash_down"] = true
	P.do_dash()
	await _go(0.3, hold_d)
	P.inp["dash_down"] = false
	await _go(0.6,
			Callable(),
			[[0.2, "full", "blowout", "Payoff: Wirerun through a Live foe, BLOWOUT, the copper refund columns on her"]],
			4.0)

func _vireo_e() -> void:
	var K = P.ak
	await _reset(7.0)
	K.use_e()
	var flick := func(tt: float):
		if tt > 0.05:
			_aim(home + Vector3(4.0, 0, 0))
	var marks := _strip("anim_e",
			"E: the arm sweeps toward the spot, flicks up for the drag, stays up, snaps down at the strike",
			[0.02, 0.07, 0.14, 0.3, 0.7, 1.16])
	marks.append([0.2,
			"full",
			"e_aim",
			"E: the dark disc at the cursor; the flick sets the drag arrow and the gold rim chevron (a pull)",
			_on_target])
	marks.append([0.7,
			"full",
			"e_count",
			"E countdown: a dark violet disc, a crackling copper rim, gold veins, the gold pillar narrowing",
			_on_target])
	marks.append([1.15,
			"full",
			"e_strike",
			"E strike: lightning, the target dragged toward her, Grounded with shackle rings",
			_on_target])
	await _go(1.6, flick, marks)

func _vireo_owner1103() -> void:
	var K = P.ak
	await _reset(7.0)
	K.use_e()
	var flick := func(tt: float):
		if tt > 0.05:
			_aim(home + Vector3(4.0, 0, 0))
	var marks := []
	var count_cap := "owner1103 #9: Skycall circle, radius 1.5 m (15-20% smaller), before the strike"
	marks.append([0.7, "full", "owner1103_e_count", count_cap, _on_target])
	var a_cap := "owner1103 #9b: struck, the target starts a slow slide toward her"
	marks.append([1.2, "full", "owner1103_e_slide_a", a_cap, _on_target])
	marks.append([1.75, "full", "owner1103_e_slide_b", "owner1103 #9b: mid-slide, easing out", _on_target])
	var c_cap := "owner1103 #9b: the slide ends about 3.4 m from where it was hit"
	marks.append([2.4, "full", "owner1103_e_slide_c", c_cap, _on_target])
	await _go(2.6, flick, marks)

# ------------------------------------------------------------------ Vex
func _venator() -> void:
	await _venator_lmb()
	await _venator_rmb()
	await _venator_dash()
	await _venator_e()
	await _venator_knock()

func _venator_lmb() -> void:
	await _reset(8.0)
	_aim(home + Vector3(3.0, 0, 0))
	var string := func(tt: float): P.inp["fire"] = tt < 0.6
	var marks := _strip("anim_lmb",
			"LMB: shouldered in the aim crouch, a round's kick (gun up and back at 0.025s), back on the shoulder; "
			+ "after the last round the rifle stays up a beat and he eases out",
			[0.36, 0.385, 0.42, 0.47, 0.8, 1.15])
	marks.append([0.31,
			"full",
			"lmb_aim",
			"LMB: ember tracers through a near cursor out to full range, the bronze muzzle star, the firing brackets"])
	await _go(1.2, string, marks)
	P.inp["fire"] = false
	await _reset(8.0)
	var run_fire := func(_t: float):
		P.inp["fire"] = true
		P.inp["move"] = Vector2(0, 1)
	await _go(0.9, run_fire, _strip("anim_lmb_walk",
			"LMB while walking: the upper body stays on the cursor, the legs keep walking (no crouch at a run)",
			[0.3, 0.42, 0.54, 0.66, 0.78]))
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	await _reset(7.0)
	KitStatus.apply(T, "rat", 3.0)
	var burst := func(tt: float): P.inp["fire"] = tt < 0.45
	await _go(0.75,
			burst,
			[[0.62, "full", "lmb_dazed", "LMB on a Dazed target: the big gold numbers (+90%) in frame", _on_target]])
	P.inp["fire"] = false

## The passive: a knock gives Slipstep back (last: the target stays down after it).
func _venator_knock() -> void:
	await _reset(6.0)
	P.dashes = 0.0
	T.hp = 2.0
	var hold_fire := func(_t: float): P.inp["fire"] = true
	var knock := _strip("anim_knock",
			"Passive proc (Hot Streak): a knock, the rifle spun up onto his shoulder, chin up",
		[0.02, 0.1, 0.2, 0.35, 0.55])
	knock.append([0.12,
			"full",
			"knock",
			"Hot Streak: the knock gives Slipstep back: +KNOCK, the ember column and ring on him"])
	await _go(0.6, hold_fire, knock)
	P.inp["fire"] = false

func _venator_rmb() -> void:
	var K = P.ak
	await _reset(6.0)
	_aim(home + Vector3(3.0, 0, 0))
	T.teleport(home + Vector3(8.5, 0, 0))
	K.press_rmb()
	var throw := _strip("anim_rmb_throw",
			"RMB Coin Blast: the cyborg hand cocked, flicked out along the aim at 0.07, follow-through, home",
			[0.01, 0.04, 0.07, 0.13, 0.25, 0.45])
	throw.append([0.08,
			"full",
			"rmb_release",
			"RMB release: the big coin leaves her open cyborg palm with a lime spark"])
	throw.append([0.2,
			"full",
			"rmb_flight",
			"RMB: the big gold coin with its green-fire rim, flipping in flight",
			_burr_spot])
	throw.append([0.75,
			"full",
			"rmb_cone",
			"RMB stuck on the ground: the cone shows back toward her for its fuse (everyone sees it)",
			_burr_spot])
	throw.append([1.37,
			"full",
			"rmb_blast",
			"RMB blast: the cone front, the target shoved toward her and Dazed (swirl)",
			_on_target])
	await _go(1.6, Callable(), throw, 5.0)
	# the wall version
	await _reset(6.0)
	_wall(World.T_BLOCK)
	_aim(home + Vector3(9.5, 0, 0))
	K.press_rmb()
	await _go(0.05)
	var wall := [[0.8, "full", "rmb_wall_cone", "RMB on a wall: stuck, the cone back out toward him", _burr_spot]]
	wall.append([1.33, "full", "rmb_wall_blast", "RMB wall blast", _burr_spot])
	await _go(1.6, Callable(), wall, 5.0)
	_wall(World.T_GROUND)

func _wall(kind: int) -> void:
	var W = m.world
	for z in range(-3, 4):
		W.kind[W.idx(int(floor(home.x + 9.5)), int(floor(home.z + z)))] = kind

func _burr_spot() -> Vector3:
	var burrs: Array = P.ak.get("burrs")
	return burrs[0]["pos"] if not burrs.is_empty() else _on_target()

func _venator_dash() -> void:
	await _reset(7.0)
	P.inp["move"] = Vector2(0, -1)
	var slide := func(_t: float):
		P.inp["dash_down"] = true
		P.inp["fire"] = true
		P.inp["move"] = Vector2(0, -1)
	P.inp["dash_down"] = true
	P.do_dash()
	var marks := _strip("anim_dash",
			"Shift: feet-first, leaning back but upright enough to aim, both hands on the rifle, firing; stand-up",
			[0.02, 0.1, 0.3, 0.6, 0.78])
	marks.append([0.12,
			"full",
			"dash",
			"Shift: sliding one way, shooting another; his ember after-image, the start ring, a dust scrape"])
	await _go(0.8, slide, marks)
	P.inp["dash_down"] = false
	P.inp["fire"] = false
	P.inp["move"] = Vector2.ZERO
	# a tap: the skid that bleeds off over 0.45s
	await _reset(7.0)
	P.inp["move"] = Vector2(0, -1)
	P.do_dash()
	var tap := _strip("anim_slide_tap", "Shift tap: a 0.45s skid, fast at the start and bleeding off, then up",
		[0.02, 0.1, 0.2, 0.3, 0.45, 0.6])
	await _go(0.65, func(_t: float): P.inp["move"] = Vector2(0, -1), tap)
	P.inp["move"] = Vector2.ZERO
	# the base air dash (his own variant): a barrel roll with ember after-images in his silhouette
	await _reset(6.0, 6.0)
	P.dashes = 0.0
	P.do_dash()
	var ex := _strip("anim_dash_ex",
			"Air dash (his base dash variant): a shoulder-led barrel roll with his ember after-images, the landing",
			[0.02, 0.07, 0.14, 0.22, 0.36, 0.5])
	ex.append([0.15, "full", "dash_ex", "Air dash: his own ember after-images (his silhouette, not a shared pill)"])
	await _go(0.6, Callable(), ex)

## Owner playtest 1103 retakes: the direct hit, the wall cone on two dummies, the slide start without rings.
func _venator_owner1103() -> void:
	var K = P.ak
	await _reset(6.0)
	_aim(home + Vector3(6.0, 0, 0))
	K.press_rmb()
	await _go(0.6, func(_t: float): P.inp["sec_hold"] = true)
	P.inp["sec_hold"] = false
	var direct_cap := "owner1103: Coin Blast direct hit: damage and DAZED, no cone"
	var direct := [[0.22, "full", "owner1103_direct_a", direct_cap, _on_target]]
	direct.append([0.26, "full", "owner1103_direct_b", "owner1103: direct hit, a beat later: DAZED", _on_target])
	await _go(0.7, Callable(), direct, 5.0)
	await _reset(7.0, 1.5)
	T2 = m.make_hunter("T2", 5, "medium", "Target2", "idle", {}, home + Vector3(7.0, 0, -1.5), {"arch": "none"})
	T2.teleport(home + Vector3(7.0, 0, -1.5))
	_wall(World.T_BLOCK)
	_aim(home + Vector3(9.5, 0, 0))
	K.press_rmb()
	await _go(0.05)
	var between := func() -> Vector3: return (T.position + T2.position) * 0.5 + Vector3(0, 1.0, 0)
	var wall := [[1.25, "full", "owner1103_wall_cone_a", "owner1103: wall cone hits two dummies, both DAZED", between]]
	wall.append([1.32, "full", "owner1103_wall_cone_b", "owner1103: wall cone, a beat later: both DAZED", between])
	await _go(1.8, Callable(), wall, 5.0)
	_wall(World.T_GROUND)
	T2.teleport(home + Vector3(-30, 0, 30))
	T2 = null
	await _reset(7.0)
	P.inp["move"] = Vector2(0, -1)
	P.inp["dash_down"] = true
	P.do_dash()
	var start_cap := "owner1103: Slipstep start, no rings or disc: ember after-image, dust, faint skid streaks"
	var start := [[0.03, "full", "owner1103_slide_start", start_cap]]
	start.append([0.15, "full", "owner1103_slide_mid", "owner1103: Slipstep a moment in, no rings"])
	await _go(0.4, func(_t: float): P.inp["move"] = Vector2(0, -1), start)
	P.inp["dash_down"] = false
	P.inp["move"] = Vector2.ZERO

func _venator_e() -> void:
	var K = P.ak
	await _reset(9.0)
	K.use_e()
	var marks := _strip("anim_e",
			"E Palm Lance: the cyborg arm raised, palm out, through the 0.6s cast, the recoil, settle",
			[0.05, 0.3, 0.58, 0.66, 0.8, 1.05])
	marks.append([0.1,
			"full",
			"e_aim_start",
			"E cast start: a wide line full length out of the palm, green fire burning in the open palm"])
	marks.append([0.5, "full", "e_aim_end", "E cast end: narrowed to a thin core, the palm flame swollen"])
	marks.append([0.68,
			"full",
			"e_fire",
			"E fire: the lance leaves the palm, hot core and lime edges, and the recoil"])
	await _go(1.2, Callable(), marks)
	# payoff: Palm Lance on a Dazed hunter
	await _reset(8.0)
	KitStatus.apply(T, "rat", 3.0)
	K.use_e()
	var skewer := "Payoff: Palm Lance through a Dazed hunter at the hit: SKEWERED and the number"
	await _go(0.8, Callable(), [[0.66, "full", "skewer", skewer, _above_target]])
