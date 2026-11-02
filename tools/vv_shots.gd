extends RefCounted
## --vv-shots --shots-dir=<dir> [--vv-hero=mage|gunslinger] [--vv-tag=v2|before]: screenshots of Vireo's and
## Venator's abilities in a live Arena match (run under xvfb with a renderer): for each ability the
## telegraph or reticle while aiming, the key animation frame and the impact, plus a 4-6 frame
## animation strip per move (anticipation, release, follow-through, recovery) cropped round the hero.
## Writes <dir>/MANIFEST_<hero>_<tag>.txt lines "<name>/<tag>|<file>|<caption>" (strips under /anim).
## Uses only long-standing match and kit calls, so the same file also shoots "before" frames on main.

var main: Node
var m: Match
var P: Hunter
var T: Hunter
var dir := ""
var tag := "v2"
var who := "mage"
var name_ := "vireo"
var home := Vector3.ZERO
var lines: Array = []
var strips := {}               # strip file -> Array of Image
var t := 0.0
const DT := 1.0 / 60.0

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--vv-hero="): who = String(a).substr(10)
		if String(a).begins_with("--vv-tag="): tag = String(a).substr(9)
	name_ = "vireo" if who == "mage" else "venator"
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	if who == "mage": await _vireo()
	else: await _venator()
	var f := FileAccess.open(dir.path_join("MANIFEST_%s_%s.txt" % [name_, tag]), FileAccess.WRITE)
	for l in lines: f.store_line(l)
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
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	home = _spot(P.pos)
	T = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(7.0, 0, 0), {"arch": "none"})
	for x in m.hunters:
		if x != P and x != T: x.teleport(home + Vector3(-30, 0, 30))
	await _reset(7.0)

## A flat stretch of island away from the start (as tools/aimkit_shots.gd).
func _spot(start: Vector3) -> Vector3:
	var W = m.world
	for z in range(6, W.h - 6, 3):
		for x in range(6, W.w - 18, 3):
			if Vector2(x - start.x, z - start.z).length() < 24.0:
				continue
			var lv: int = int(W.level[W.idx(x, z)])
			var good := true
			for dz in range(-4, 5):
				for dx in range(-3, 15):
					var i: int = W.idx(x + dx, z + dz)
					if W.kind[i] != World.T_GROUND or int(W.level[i]) != lv or W.stairs.has(i) or W.walls.has(i) or W.props.has(i) or W.bridge.has(i):
						good = false; break
				if not good: break
			if good:
				return Vector3(x + 0.5, lv * World.LEVEL, z + 0.5)
	return start

func _reset(td: float, tz := 0.0) -> void:
	P.teleport(home); P.vel = Vector3.ZERO
	T.teleport(home + Vector3(td, 0, tz)); T.vel = Vector3.ZERO
	T.hp = T.max_hp; T.stun_t = 0.0; T.inv_t = 0.0
	for k in ["fire", "sec_hold", "dash_down"]: P.inp[k] = false
	P.inp["move"] = Vector2.ZERO
	P.ak.cd["rmb"] = 0.0; P.ak.cd["e"] = 0.0; P.ak.ch_rmb = float(P.ak.rmb_charges()); P.dashes = P.max_dashes()
	_aim(T.pos)
	await _go(0.4)
	T.inv_t = 0.0

func _aim(p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

## Steps the match `secs`, rendering every frame; `each` runs before each step; `marks` is
## [[time, kind, file, caption], ...] with kind "full" (the whole view) or a strip file (a crop round the hero).
func _go(secs: float, each := Callable(), marks: Array = [], lead := 3.5) -> void:
	var t0 := 0.0
	var todo := marks.duplicate()
	while t0 < secs:
		if each.is_valid(): each.call(t0)
		m.step(DT); t0 += DT
		P.face = atan2(-(P.inp["aim"].x - P.pos.x), -(P.inp["aim"].z - P.pos.z)) if P.roll_t <= 0.0 else P.face
		m.cam.snap(P.pos + Vector3(lead, 0, 0))
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
		while not todo.is_empty() and t0 >= float(todo[0][0]):
			var mk: Array = todo.pop_front()
			_take(String(mk[1]), String(mk[2]), String(mk[3]))

func _take(kind: String, file: String, caption: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if kind == "full":
		img.save_png(dir.path_join(file))
		lines.append("%s/%s|%s|%s" % [name_, tag, file, caption])
		return
	var cam := main.get_viewport().get_camera_3d()
	var c := cam.unproject_position(P.position + Vector3(0, 0.9, 0))
	var sz := Vector2i(150, 170)
	var rg := Rect2i(Vector2i(int(c.x) - sz.x / 2, int(c.y) - sz.y / 2), sz).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(sz.x * 2, sz.y * 2, Image.INTERPOLATE_BILINEAR)
	if not strips.has(kind):
		strips[kind] = []
		lines.append("%s/%s/anim|%s|%s" % [name_, tag, kind, caption])
	(strips[kind] as Array).append(crop)
	_save_strip(kind)

func _save_strip(file: String) -> void:
	var fr: Array = strips[file]
	var w: int = (fr[0] as Image).get_width(); var hh: int = (fr[0] as Image).get_height()
	var out := Image.create(w * fr.size() + 4 * (fr.size() - 1), hh, false, (fr[0] as Image).get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	for i in fr.size():
		out.blit_rect(fr[i], Rect2i(Vector2i.ZERO, Vector2i(w, hh)), Vector2i(i * (w + 4), 0))
	out.save_png(dir.path_join(file))

func _strip(file: String, caption: String, times: Array) -> Array:
	var out: Array = []
	for tt in times: out.append([tt, file, file, caption])
	return out

func _merge(a: Array, b: Array) -> Array:
	var c := a + b
	c.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	return c

# ------------------------------------------------------------------ Vireo
func _vireo() -> void:
	var K = P.ak
	# LMB: the line to full range with the cursor close, the bolt in flight, the impact; the strip
	await _reset(7.0)
	_aim(home + Vector3(3.0, 0, 0))
	await _go(0.2, Callable(), [[0.15, "full", "lmb_aim.png", "LMB aim: the line runs through a near cursor (3m) on to full range"]])
	await _reset(9.0)
	var hold_fire := func(_t): P.inp["fire"] = true
	var mk := _merge(_strip("anim_lmb.png", "LMB finger bolts: twist, arm flung out, snap, settle; left then right", [0.02, 0.07, 0.13, 0.35, 0.85, 0.9]),
		[[0.1, "full", "lmb_bolt.png", "LMB: a jagged bolt from the fingertip (no gun), crackle at the hand"], [0.32, "full", "lmb_impact.png", "LMB impact: splinters spray back toward her; the Static marker over the head"]])
	await _go(1.0, hold_fire, mk)
	P.inp["fire"] = false
	# Static marker growing; Live sky bolt
	await _reset(6.0)
	if K.has_method("add_spark"):
		K.add_spark(T, 2)
		await _go(0.3, Callable(), [[0.25, "full", "static_2.png", "Static: 2 stacks, the marker's count and sparks on the body"]])
		K.add_spark(T, 2)
		await _go(0.3, Callable(), [[0.05, "full", "static_live.png", "Static: the 4th stack calls a sky bolt, they're Live"]])
	# RMB: the rod held with its fixed lane, the full flash, the throw and impact; strips
	await _reset(6.0)
	K.press_rmb()
	var hold_r := func(_t): P.inp["sec_hold"] = true
	await _go(1.02, hold_r, _merge(_strip("anim_rmb_hold.png", "RMB summon and hold: the rod raised by the shoulder, side-on", [0.03, 0.1, 0.3, 0.7]),
		[[0.5, "full", "rmb_aim.png", "RMB held: the rod in the hand and a fixed double-rail lane to full range"], [1.0, "full", "rmb_full.png", "RMB full: the white body flash"]]))
	P.inp["sec_hold"] = false
	await _go(0.8, Callable(), _merge(_strip("anim_rmb_throw.png", "RMB throw: overarm whip, stretch, follow-through, recover", [0.02, 0.08, 0.16, 0.4, 0.7]),
		[[0.18, "full", "rmb_impact.png", "RMB impact: white-gold blast, shock ring, the target knocked back, an orb left at the impact"], [0.6, "full", "rmb_orb.png", "The charge orb zapping the target with Static"]]))
	# Shift: the held lane and end ring growing, the release silhouette, the arrival
	await _reset(6.0)
	_aim(home + Vector3(3.0, 0, 0))
	P.inp["dash_down"] = true; P.do_dash()
	var hold_d := func(_t): P.inp["dash_down"] = true
	await _go(0.62, hold_d, _merge(_strip("anim_dash.png", "Shift: the charging crouch, then the streak and re-forming on arrival", [0.05, 0.3, 0.6]),
		[[0.25, "full", "dash_aim_mid.png", "Shift held: rails out to max, the ticked end ring partway (short of nothing: the cursor plays no part)"], [0.6, "full", "dash_aim_full.png", "Shift held to full: the end ring at 12.6m, past the 3m cursor"]]))
	P.inp["dash_down"] = false
	await _go(0.8, Callable(), _merge(_strip("anim_dash.png", "", [0.05, 0.42, 0.6]), [[0.08, "full", "dash_run.png", "Shift released: a lightning streak, the body a silhouette"], [0.46, "full", "dash_arrive.png", "Shift arrival: a ring burst with spark needles"]]), 6.0)
	# the payoff: Wirerun through a Live target
	await _reset(5.0)
	if K.has_method("add_spark"): K.add_spark(T, 4)
	_aim(T.pos + Vector3(3, 0, 0))
	P.inp["dash_down"] = true; P.do_dash()
	await _go(0.3, hold_d)
	P.inp["dash_down"] = false
	await _go(0.6, Callable(), [[0.2, "full", "blowout.png", "Payoff: Wirerun through a Live foe, BLOWOUT, the copper refund columns on her"]], 4.0)
	# E: placed at the cursor, the flick, the countdown pillar, the strike and drag
	await _reset(7.0)
	K.use_e()
	var flick := func(tt):
		if tt > 0.05: _aim(home + Vector3(4.0, 0, 0))
	await _go(1.6, flick, _merge(_strip("anim_e.png", "E: a one-arm sweep toward the spot, the hand snapped down", [0.03, 0.08, 0.16, 0.45, 0.8]),
		[[0.2, "full", "e_aim.png", "E: the circle at the cursor, the flick sets the drag arrow and the rim chevron (toward her: a pull)"], [0.7, "full", "e_count.png", "E countdown: dark disc, crackling copper rim, a pillar of light narrowing"],
		[1.15, "full", "e_strike.png", "E strike: lightning, the target dragged toward her, Grounded with shackle rings"]]))

# ------------------------------------------------------------------ Venator
func _venator() -> void:
	var K = P.ak
	# LMB: rounds past the cursor; on a Dazed target big gold numbers
	await _reset(8.0)
	_aim(home + Vector3(3.0, 0, 0))
	var hold_fire := func(_t): P.inp["fire"] = true
	await _go(0.6, hold_fire, _merge(_strip("anim_lmb.png", "LMB: the shoulder takes each kick, head on the sights", [0.02, 0.06, 0.1, 0.14]),
		[[0.3, "full", "lmb_aim.png", "LMB: ember tracers through a near cursor out to full range, the muzzle star"]]))
	P.inp["fire"] = false
	await _reset(7.0)
	KitStatus.apply(T, "rat", 3.0)
	await _go(0.7, hold_fire, [[0.6, "full", "lmb_dazed.png", "LMB on a Dazed target: big gold numbers (+90%)"]])
	P.inp["fire"] = false
	# RMB: the held lane (target marked), the throw, the stick on the ground with the cone, the blast
	await _reset(6.0)
	_aim(home + Vector3(3.0, 0, 0))
	K.press_rmb()
	var hold_r := func(_t): P.inp["sec_hold"] = true
	await _go(0.6, hold_r, _merge(_strip("anim_rmb.png", "RMB: cocked over the shoulder while aiming, the overhand throw, follow-through", [0.05, 0.5]),
		[[0.5, "full", "rmb_aim.png", "RMB held: a fixed lane with an arrow tip past the cursor; the target in it is marked"]]))
	P.inp["sec_hold"] = false
	T.teleport(home + Vector3(8.5, 0, 0))
	await _go(1.6, Callable(), _merge(_strip("anim_rmb.png", "", [0.07, 0.16, 0.4]),
		[[0.25, "full", "rmb_flight.png", "RMB: the spiked charge flies past the person, on to the lane's end"], [0.75, "full", "rmb_cone.png", "RMB stuck on the ground: the cone shows back toward him for 0.9s (everyone sees it)"],
		[1.37, "full", "rmb_blast.png", "RMB blast: the cone front, the target shoved toward him and Dazed (swirl)"]]), 5.0)
	# the wall version
	await _reset(6.0)
	var W = m.world
	for z in range(-3, 4):
		W.kind[W.idx(int(floor(home.x + 9.5)), int(floor(home.z + z)))] = World.T_BLOCK
	_aim(home + Vector3(9.5, 0, 0))
	K.press_rmb(); await _go(0.05)
	await _go(1.6, Callable(), [[0.8, "full", "rmb_wall_cone.png", "RMB on a wall: stuck, the cone back out toward him"], [1.33, "full", "rmb_wall_blast.png", "RMB wall blast"]], 5.0)
	for z in range(-3, 4):
		W.kind[W.idx(int(floor(home.x + 9.5)), int(floor(home.z + z)))] = World.T_GROUND
	# Shift: a slide one way while shooting another
	await _reset(7.0)
	P.inp["move"] = Vector2(0, -1)
	var slide := func(_t): P.inp["dash_down"] = true; P.inp["fire"] = true; P.inp["move"] = Vector2(0, -1)
	P.inp["dash_down"] = true; P.do_dash()
	await _go(0.8, slide, _merge(_strip("anim_dash.png", "Shift: dropped feet-first, leaning back, rifle up and firing; the stand-up", [0.02, 0.1, 0.3, 0.6, 0.78]),
		[[0.22, "full", "dash.png", "Shift: sliding one way while shooting another; the ember afterimage and ring at the start"]]))
	P.inp["dash_down"] = false; P.inp["fire"] = false; P.inp["move"] = Vector2.ZERO
	# E: the narrowing line, the beam, the recoil
	await _reset(9.0)
	K.use_e()
	await _go(1.2, Callable(), _merge(_strip("anim_e.png", "E: braced through the 0.6s cast, the recoil throws the chest back, settle", [0.05, 0.3, 0.58, 0.66, 0.8, 1.05]),
		[[0.1, "full", "e_aim_start.png", "E cast start: a wide bright line full length"], [0.5, "full", "e_aim_end.png", "E cast end: narrowed to a thin core"], [0.68, "full", "e_fire.png", "E fire: the beam, muzzle orb and flare, the smoke ring and recoil"]]))
	# payoff: Longneedle on a Dazed hunter
	await _reset(8.0)
	KitStatus.apply(T, "rat", 3.0)
	K.use_e()
	await _go(1.0, Callable(), [[0.72, "full", "skewer.png", "Payoff: Longneedle through a Dazed hunter, SKEWERED"]])
