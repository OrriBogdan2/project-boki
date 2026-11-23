class_name CareDemo
extends RefCounted
## Screenshot and frame-strip tooling for the support pair (Arena). Hooked from ArenaDemo with one line.
##   --arena-demo=care_<tender|rimewright>_<what>   (what: a SPEC key below)
##   --arena-shot=<dir>/<anything>.png               (only its folder is used)
##   --care-close                                    a low close-up (default: the gameplay camera)
## Saves <dir>/<arch>_<key>_<game|close>.png for each key moment of the demo (the frame at that moment,
## not after the move) and <dir>/<arch>_<what>_strip_<game|close>.png: crops round the hero at the
## strip times (anticipation, release, follow-through, recovery), side by side.

## Per demo: strip times (s, at least 0.06 apart), key moments {name: s}, and the close-up camera yaw.
const SPEC := {
	"tender_lmb": {"strip": [0.34, 0.38, 0.42, 0.52, 0.66, 0.82], "keys": {"lmb": 0.42, "lmb_fly": 0.39}},
	# three embers, the cursor 4, 8 and 14 m out to the open side: each flies on past it to its full range
	"tender_reach": {"strip": [0.7, 1.4, 2.1], "keys": {"reach4": 0.7, "reach8": 1.4, "reach14": 2.1}},
	"tender_emp": {"strip": [1.3, 1.36, 1.42, 1.5, 1.6, 1.8], "keys": {"emp": 1.42, "emp_fly": 1.56}},
	"tender_rmb":
	{"strip": [0.6, 0.84, 0.9, 0.98, 1.4, 1.86], "keys": {"rmb_aim": 0.7, "rmb_disc": 1.4, "rmb_root": 1.86}},
	"tender_e": {"strip": [0.36, 0.4, 0.48, 0.6, 1.06, 1.14], "keys": {"e": 0.5, "e_thrown": 1.3}},
	"tender_dash": {"strip": [0.31, 0.35, 0.41, 0.47, 0.53], "keys": {"dash": 0.41}},
	"tender_air":
	{"strip": [0.33, 0.5, 0.8, 1.1, 1.3], "keys": {"air_start": 0.28, "air": 0.46, "air_float": 0.8, "air_land": 1.3}},
	"tender_airsteer":
	{"strip": [0.33, 0.6, 0.85, 1.1, 1.3], "keys": {"steer_start": 0.3, "steer_mid": 0.85, "steer_end": 1.3}},
	"tender_carry": {"strip": [0.3, 0.45, 0.6, 1.0, 1.5, 2.0], "keys": {"carry": 1.5}},
	"tender_payoff": {"strip": [2.6, 2.75, 2.82, 2.9, 3.0, 3.2], "keys": {"payoff": 2.82}},
	"tender_walk": {"strip": [0.6, 0.68, 0.76, 0.84, 0.92, 1.0], "keys": {"walk": 0.8}},
	"tender_pose": {"strip": [0.5, 0.56, 0.62, 0.68], "keys": {"pose": 0.6}, "yaw": 3.3},
	"tender_ultaim": {"strip": [0.28, 0.34, 0.4, 0.46, 0.6], "keys": {"ultaim": 0.45}},
	"tender_ultkey": {"strip": [0.5, 0.56, 0.62, 0.7, 0.9, 1.5], "keys": {"ultkey": 1.5}},
	"tender_ult": {"strip": [1.5, 5.4, 5.56, 5.62, 5.72, 5.9], "keys": {"ult_end": 5.62}},
	"rimewright_lmb": {"strip": [0.42, 0.45, 0.5, 0.56, 0.62, 0.7], "keys": {"lmb": 0.45, "lmb_fly": 0.8}},
	"rimewright_heavy": {"strip": [0.98, 1.02, 1.06, 1.1, 1.2], "keys": {"heavy": 1.06}},
	"rimewright_shatter":
	{"strip": [1.0, 1.6, 2.02, 2.12, 2.24, 2.4], "keys": {"stacks": 1.6, "shell": 1.98, "shatter": 2.2}},
	"rimewright_payoff": {"strip": [0.5, 0.7, 0.9, 1.1, 1.3, 1.5], "keys": {"payoff": 1.3}},
	"rimewright_rmb":
	{
		"strip": [0.7, 0.84, 0.92, 1.05, 1.32],
		"side": 560,
		"keys": {"rmb_aim": 0.7, "rmb_fly": 1.12, "rmb_land": 1.32, "rmb_boom": 3.12}
	},
	"rimewright_dash": {"strip": [0.32, 0.45, 0.62, 0.8, 1.06], "keys": {"dash": 0.7, "dash_stop": 1.06}},
	"rimewright_skatefire": {"strip": [0.5, 0.58, 0.64, 0.7, 0.8, 0.9], "keys": {"skatefire": 0.66}},
	"rimewright_air": {"strip": [0.3, 0.5, 0.7, 0.9, 1.1], "keys": {"air": 0.5, "air_land": 0.9}},
	"rimewright_airgap": {"strip": [0.3, 0.55, 0.75, 0.95, 1.2], "side": 560, "keys": {"airgap": 0.75}},
	"rimewright_e": {"strip": [0.34, 0.42, 0.5, 0.55, 0.62, 0.9], "keys": {"e": 0.56, "e_slide": 1.3, "e_full": 2.6}},
	"rimewright_walk": {"strip": [0.6, 0.68, 0.76, 0.84, 0.92, 1.0], "keys": {"walk": 0.8}},
	"rimewright_pose": {"strip": [0.5, 0.56, 0.62, 0.68], "keys": {"pose": 0.6}, "yaw": 3.3},
	"rimewright_ultaim": {"strip": [0.32, 0.36, 0.42, 0.5, 1.5], "keys": {"ultaim": 0.36}},
	"rimewright_ultkey": {"strip": [0.33, 0.37, 0.42, 0.5, 2.0, 3.0], "keys": {"ultkey": 2.0}},
	"rimewright_ultskate": {"strip": [1.1, 1.22, 1.3, 1.4, 1.55], "keys": {"ultskate": 1.3}},
	"rimewright_skateult":
	{
		"strip": [0.7, 0.8, 0.9, 1.05, 1.3, 2.2],
		"keys": {"skating": 0.6, "skateult": 0.88, "carried": 1.3, "encased": 2.0}
	},
	"rimewright_ult": {"strip": [3.6, 3.81, 3.85, 3.91, 4.0, 4.25], "keys": {"ult_crash": 3.85}},
}


static func close() -> bool:
	return "--care-close" in OS.get_cmdline_user_args()


static func tick(a: Arena, dt: float, w: String) -> void:
	var parts := w.split("_")
	if parts.size() < 3:
		return
	var arch := String(parts[1])
	var what := String(parts[2])
	var spec: Dictionary = SPEC.get(arch + "_" + what, {})
	if spec.is_empty():
		push_error("care demo: no SPEC for %s_%s" % [arch, what])
		a.m.get_tree().quit()
		return
	var m := a.m
	var p: Hunter = m.player
	var t := float(a.get_meta("care_t", 0.0)) + dt
	a.set_meta("care_t", t)
	var d: Hunter = a.dummies[0]["h"]
	_camera(m, spec)
	if m.hud:
		m.hud.guide_hidden = true
	if t < 0.1:
		Engine.time_scale = ArenaDemoPair.DEMO_TIME_SCALE  # each slow render frame steps only a sliver
		# off every hover spot (no tooltip in the frames) and no Boki at her shoulder in the close-ups
		m.get_viewport().warp_mouse(Vector2(8, 8))
		for l in m.find_children("*", "Label3D", true, false):
			if String((l as Label3D).text).contains("KIT CARD"):
				(l as Label3D).visible = false
	p.hp = p.max_hp
	# far below full, so a payoff this step can't fill it: no BOND READY word or toast over the frames
	p.ult = -100.0
	for k in m.kins + m.mobs:
		if is_instance_valid(k):
			(k as Node3D).visible = false
	if arch == "tender" and what in ["dash", "air"]:
		p.kin = null  # her own dash only: a Boki's dash rider (its ring or decoy) is the Boki's look
	var al: Hunter = a.get_meta("care_ally") if a.has_meta("care_ally") else null
	if al == null:
		al = _setup(a, arch, what)
	if t < 0.25:
		_place_ally(a, p, al, what)
	p.inp["aim"] = d.pos + Vector3(0, 0.9, 0)
	p.inp["aim_y"] = d.pos.y
	_script(a, p, d, al, arch, what, t, dt)
	_capture(a, spec, arch, what, t, dt)


## The close-up looks low from the side; the gameplay camera is the real one (default zoom, pitch, north).
static func _camera(m: Match, spec: Dictionary) -> void:
	if not m.cam:
		return
	m.cam.lead = 0.0  # the mouse sits in a corner (no hover tooltip): don't pan toward it
	if close():
		m.cam.zoom = 0.32
		m.cam.pitch = deg_to_rad(22.0)
		m.cam.yaw = float(spec.get("yaw", 2.5))
	else:
		m.cam.zoom = 1.0
		m.cam.pitch = deg_to_rad(57.0)
		m.cam.yaw = 0.0
	m.cam.zoom_to = m.cam.zoom
	m.cam.yaw_to = m.cam.yaw
	m.set_meta("zoom_hold", m.cam.zoom)


## Screen right and screen forward on the ground (the way the camera looks), from the live camera.
static func _axes(m: Match) -> Array:
	var cam := m.get_viewport().get_camera_3d()
	if cam == null:
		return [Vector3.RIGHT, Vector3.FORWARD]
	var b := cam.global_transform.basis
	return [Vector3(b.x.x, 0, b.x.z).normalized(), Vector3(-b.z.x, 0, -b.z.z).normalized()]


## Moves that travel go to screen right (side-on in the frames); a downed teammate lies off to that side
## for the carry and Hearth Call; otherwise the teammate stands behind her and to the left, never between
## her and the camera.
static func _place_ally(a: Arena, p: Hunter, al: Hunter, what: String) -> void:
	var ax := _axes(a.m)
	var right: Vector3 = -(ax[0] as Vector3)  # travel goes screen left: the open side of the arena spot
	var fwd: Vector3 = ax[1]
	a.set_meta("care_right", Vector2(right.x, right.z))
	a.set_meta("care_fwd", Vector2(fwd.x, fwd.z))
	if what in ["carry", "ultkey", "ult", "ultaim"]:
		al.teleport(p.pos + right * 3.0 + fwd * 0.8)
	elif what == "dash":
		al.teleport(p.pos + right * 2.0 + fwd * 0.6)
	elif close():
		al.teleport(p.pos + fwd * 2.6 - right * 1.6)
	else:
		al.teleport(p.pos - fwd * 1.8 - right * 2.2)  # below and left of her on screen, off the aim


## The hero 7.5 m from the first dummy, and a teammate behind her (away from the close-up camera).
static func _setup(a: Arena, arch: String, what: String) -> Hunter:
	var m := a.m
	var p: Hunter = m.player
	var d: Hunter = a.dummies[0]["h"]
	a.set_arch(arch, "lantern_crook" if arch == "tender" else "hoar_fan")
	a.set_kin("puddlet")
	p.teleport(d.pos + Vector3(-1.0, 0, 6.0))
	a.home = p.pos
	var at := p.pos + Vector3(-2.3, 0, 1.2)
	var al := m.make_hunter("Ally", p.team, "medium", "Ally", "idle", {}, at, {"arch": "none"})
	al.max_hp = 145.0
	al.hp = 60.0
	a.set_meta("care_ally", al)
	if what in ["carry", "ultkey", "ult"] and (what == "carry" or arch == "tender"):
		m.knock(al, null, {})
		al.ctrl = "idle"
		al.down_hp = 80.0
	if what == "shatter":
		d.max_hp = 5000.0
	return al


static func _script(
	a: Arena, p: Hunter, d: Hunter, al: Hunter, arch: String, what: String, t: float, dt: float
) -> void:
	var k: ArchKit = p.ak
	var go := 0.3
	var tender_lane := arch == "tender" and what in ["dash", "air", "airsteer", "reach"]
	if t < 0.2 and (what in ["skateult", "skatefire"] or tender_lane):
		_open_lane(a, p, al)
	match what:
		"rmb":
			# held keys are re-sent every step: the match's own input poll would let go of them
			p.inp["sec_hold"] = t >= go and t < 0.8
			if _at(t, dt, go):
				k.ch_rmb = float(k.rmb_charges())
				k.press_rmb()
		"e":
			if _at(t, dt, go):
				k.cd["e"] = 0.0
				if arch == "rimewright":
					# aimed 11m out across the screen, so the frames show the long slide out
					var side: Vector2 = a.get_meta("care_right", Vector2(1, 0))
					p.inp["aim"] = p.pos + Vector3(side.x * 11.0, 0.9, side.y * 11.0)
				k.use_e()
			if arch == "tender" and _at(t, dt, 1.0):
				p.inp["aim"] = p.pos + Vector3(-4.0, 0.9, -2.0)
				k.use_e()
		"dash":
			_dash(a, p, arch, t, dt)
		"air", "airsteer":
			p.inp["move"] = a.get_meta("care_right", Vector2(1, 0))
			if what == "airsteer" and t > 0.55:
				p.inp["move"] = a.get_meta("care_fwd", Vector2(0, -1))  # steer the glide round mid-flight
			if _at(t, dt, 0.2):
				p.vel.y = 6.0
				if arch == "rimewright":
					p.pos.y += 2.0  # a clear drop, so the press lands well before she does
					p.grounded = false
			# Claire's Shift in the air skates at once (item 62)
			p.inp["dash_down"] = arch == "rimewright" and t >= go and t < 1.3
			if _at(t, dt, go):
				p.ex_cd = 0.0
				p.dashes = p.max_dashes()
				k.on_dash(true)
		"airgap":
			_air_gap(a, p, t, dt)
		"lmb", "heavy":
			p.inp["fire"] = t > 0.3 and t < 1.5
		"shatter":
			p.inp["fire"] = t > 0.3 and t < 1.75
		"emp":
			p.inp["fire"] = t > 1.28 and t < 1.32
		"reach":
			_reach(a, p, t)
		"skatefire":
			_dash(a, p, arch, t, dt)
			p.inp["fire"] = t > 0.55 and t < 1.0
		"carry":
			var side: Vector2 = a.get_meta("care_right", Vector2(1, 0))
			p.inp["move"] = Vector2.ZERO
			if t > 0.3 and t < 3.0:
				p.inp["move"] = -side if t > 1.0 else side
		"walk":
			# strafing across the cursor: the legs go the way she moves, the body keeps facing the aim
			p.inp["move"] = (a.get_meta("care_right", Vector2(1, 0)) as Vector2) if t > 0.3 else Vector2.ZERO
		"payoff":
			_payoff(p, d, al, k, arch, t, dt)
		"ultaim", "ultkey", "ult", "ultskate":
			_ult(a, al, arch, what, t, dt)
		"skateult":
			_skate_ult(a, p, t, dt)


## Ember i leaves at 0.3 + 0.7 i s with the cursor REACH_D[i] m out to the open side, marked by a ring there.
const REACH_D := [4.0, 8.0, 14.0]


static func _reach(a: Arena, p: Hunter, t: float) -> void:
	var i := clampi(int((t - 0.3) / 0.7), 0, REACH_D.size() - 1)
	var side: Vector2 = a.get_meta("care_right", Vector2(1, 0))
	var at := p.pos + Vector3(side.x, 0, side.y) * float(REACH_D[i])
	p.inp["aim"] = at + Vector3(0, 0.9, 0)
	AimKit.circle(p, "reach", {"at": at, "r": 0.5, "star": true})
	var go := 0.3 + 0.7 * i
	p.inp["fire"] = t > go and t < go + 0.04
	if p.inp["fire"]:
		p.idle_fire = 0.0  # plain embers: an idle crook's next one is Empowered (further)


static func _dash(a: Arena, p: Hunter, arch: String, t: float, dt: float) -> void:
	var side: Vector2 = a.get_meta("care_right", Vector2(1, 0))
	var fwd: Vector2 = a.get_meta("care_fwd", Vector2(0, -1))
	if arch == "tender":
		p.dashes = p.max_dashes()
		p.inp["move"] = side if t < 0.5 else Vector2.ZERO
		if _at(t, dt, 0.3):
			p.do_dash()
		return
	p.inp["move"] = side if t < 0.62 else (side + fwd * 1.5).normalized()  # a carve partway
	p.inp["dash_down"] = t >= 0.3 and t < 1.0
	if _at(t, dt, 0.3):
		p.dashes = p.max_dashes()
		p.do_dash()


static func _payoff(p: Hunter, d: Hunter, al: Hunter, k: ArchKit, arch: String, t: float, dt: float) -> void:
	if arch == "rimewright":
		if _at(t, dt, 0.3):
			(k as RimewrightKit).add_chill(d)
			d.hp = 1.0
		p.inp["fire"] = t > 0.5 and t < 1.0
		return
	if _at(t, dt, 0.3):
		al.hp = 20.0
		k.cd["e"] = 0.0
		k.use_e()


## The X ultimates: Pip puts the cursor on the (downed) teammate, presses X and walks while it
## channels; Claire seals in beside the dummy and lets the rink crack open.
static func _ult(a: Arena, ally: Hunter, arch: String, what: String, t: float, dt: float) -> void:
	var p: Hunter = a.m.player
	p.lvl = maxi(p.lvl, 6)
	if t < 0.3:
		p.ak.cd["x"] = 0.0
	if arch == "tender":
		p.inp["aim"] = ally.pos + Vector3(0, 0.9, 0)
		if what != "ultaim" and _at(t, dt, 0.5):
			HunterKeys.ult_pressed(p)  # the aim shot keeps the cursor on the teammate: the preview telegraph
		var walking := what != "ultaim" and t > 0.8 and t < 2.3
		var away: Vector2 = -(a.get_meta("care_right", Vector2(1, 0)) as Vector2)
		p.inp["move"] = away if walking else Vector2.ZERO
		return
	var d: Hunter = a.dummies[0]["h"]
	if t < 0.3:
		p.teleport(d.pos + Vector3(-1.0, 0, 3.5))
	if _at(t, dt, 0.3):
		HunterKeys.ult_pressed(p)
	if what == "ultskate":
		# sealed a beat, then Shift: she skates straight out of the bud at speed
		p.inp["move"] = (a.get_meta("care_right", Vector2(1, 0)) as Vector2) if t > 1.1 else Vector2.ZERO
		p.inp["dash_down"] = t >= 1.2 and t < 1.9
		if _at(t, dt, 1.2):
			p.dashes = p.max_dashes()
			p.inp["dash"] = true


## A long clear lane across the arena below the dummy (no rocks, no teammate in the way) for the dashes.
static func _open_lane(a: Arena, p: Hunter, al: Hunter) -> void:
	var d: Hunter = a.dummies[0]["h"]
	p.teleport(d.pos + Vector3(6.0, 0, 9.4))
	if al != null:
		al.teleport(d.pos + Vector3(-12.0, 0, -6.0))


## Item 62: a jump off the near edge of a 6 m abyss gap and Shift at the top of it: she skates across.
static func _air_gap(a_v: Arena, p: Hunter, t: float, dt: float) -> void:
	var right: Vector2 = a_v.get_meta("care_right", Vector2(1, 0))
	var side := Vector2(-right.y, right.x)
	if t < 0.2:
		_open_lane(a_v, p, a_v.get_meta("care_ally"))
	if _at(t, dt, 0.1):
		var w_v = a_v.m.world
		for a in range(3, 9):
			for b in range(-4, 5):
				var q := Vector2(p.pos.x, p.pos.z) + right * (a + 0.5) + side * b
				if w_v.inb(int(floor(q.x)), int(floor(q.y))):
					w_v.kind[w_v.idx(int(floor(q.x)), int(floor(q.y)))] = World.T_VOID
		w_v.build_meshes()
	p.inp["move"] = right if t > 0.2 else Vector2.ZERO
	if _at(t, dt, 0.25):
		p.vel.y = 6.0
		p.grounded = false
	p.inp["dash_down"] = t >= 0.55 and t < 1.7
	if _at(t, dt, 0.55):
		p.dashes = p.max_dashes()
		p.ak.on_dash(true)


## Claire skates (Shift held from 0.3s) inland along the clear lane, presses X at 0.75s: carried on as the bud
## seals, then rooted.
static func _skate_ult(a: Arena, p: Hunter, t: float, dt: float) -> void:
	p.lvl = maxi(p.lvl, 6)
	if t < 0.3:
		p.ak.cd["x"] = 0.0
	p.inp["move"] = (a.get_meta("care_right", Vector2(1, 0)) as Vector2) if t < 2.5 else Vector2.ZERO
	p.inp["dash_down"] = t >= 0.3 and t < 0.75
	if _at(t, dt, 0.3):
		p.dashes = p.max_dashes()
		p.do_dash()
	if _at(t, dt, 0.75):
		HunterKeys.ult_pressed(p)


## Grabs the strip frames and the key frames at their moments; quits after the last one.
static func _capture(a: Arena, spec: Dictionary, arch: String, what: String, t: float, dt: float) -> void:
	var m := a.m
	var mode := "close" if close() else "game"
	var dir := ArenaDemo.shot_path().get_base_dir()
	var strip: Array = spec["strip"]
	var keys: Dictionary = spec["keys"]
	var last := 0.0
	for i in strip.size():
		last = maxf(last, float(strip[i]))
		if _at(t, dt, float(strip[i])):
			_grab(
				a,
				func(img: Image):
					var fr: Array = a.get_meta("care_frames", [])
					fr.append(_crop(m, img, int(spec.get("side", 0))))
					a.set_meta("care_frames", fr)
			)
	for k in keys:
		last = maxf(last, float(keys[k]))
		if _at(t, dt, float(keys[k])):
			var path := "%s/%s_%s_%s.png" % [dir, arch, k, mode]
			_grab(
				a,
				func(img: Image):
					img.save_png(path)
					print("ARENASHOT ", path)
			)
	if t >= last + 0.15 and not a.has_meta("care_done"):
		a.set_meta("care_done", true)
		m.get_tree().process_frame.connect(
			func():
				_strip(a.get_meta("care_frames", []), "%s/%s_%s_strip_%s.png" % [dir, arch, what, mode])
				m.get_tree().quit(),
			CONNECT_ONE_SHOT
		)


## The rendered frame, once this step has drawn.
static func _grab(a: Arena, use: Callable) -> void:
	var m := a.m
	m.get_tree().process_frame.connect(func(): use.call(m.get_viewport().get_texture().get_image()), CONNECT_ONE_SHOT)


## A square crop round the hero's middle on screen (360 px close up, 240 px at the gameplay zoom, or the
## spec's own `side` for a move that reaches further), scaled to 360 px.
static func _crop(m: Match, img: Image, side_px := 0) -> Image:
	var cam := m.get_viewport().get_camera_3d()
	var p: Hunter = m.player
	var c := Vector2(img.get_width() * 0.5, img.get_height() * 0.56)
	if cam and p:
		c = cam.unproject_position(p.position + Vector3(0, 0.8, 0))
	var side := 360 if close() else 240
	if side_px > 0:
		side = side_px
	var x0 := clampi(int(c.x) - side / 2, 0, img.get_width() - side)
	var y0 := clampi(int(c.y) - side / 2, 0, img.get_height() - side)
	var crop := img.get_region(Rect2i(x0, y0, side, side))
	crop.resize(360, 360)
	return crop


static func _at(t: float, dt: float, when: float) -> bool:
	return t >= when - 0.0001 and t - dt < when - 0.0001


static func _strip(frames: Array, path: String) -> void:
	if frames.is_empty():
		return
	var out := Image.create(360 * frames.size(), 360, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		var img: Image = frames[i]
		img.convert(Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(0, 0, 360, 360), Vector2i(i * 360, 0))
	out.save_png(path)
	print("ARENASHOT ", path)
