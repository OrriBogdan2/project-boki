extends RefCounted
## --fps-feel-check: the same scripted input stepped at 1/30, 1/60 and 1/144 s must give the same movement, so a
## 30 fps machine plays the game a 144 fps one does. For Vex, Kael, Albert and Sable: run 1 s, jump, a dash tap,
## a dash hold, a 2 s glide and a standard knock. Each measure must agree across the three steps within SPREAD
## and, where docs/SUPERVIVE_FEEL.md has a [game data] number for it, match that within SPREAD too:
##   jump apex  Hunter.JUMP_V^2 / (2 Hunter.H_GRAV)  (gravity 1470 uu/s^2, our jump speed)
##   glide sink HunterMove.glide_pull_vy over the glide's second second, high over the ground (GlideDownwardForce)
## Dash and knock distances have no [game data] (dash curves not decoded): they are held to agreement only.
## Prints "FPSFEEL <hero> <measure> <dt30> <dt60> <dt144> ..." rows and "FPS FEEL CHECK DONE, failures: N".

const HEROES := {"gunslinger": "Vex", "juggernaut": "Kael", "bulwark": "Albert", "thief": "Sable"}
const STEPS := [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]
const SPREAD := 0.03            # largest relative difference allowed (between steps, and to a [game data] number)
const KNOCK := 9.0              # m/s: the standard shove (Effects' push, a dash's shove_kb)
const GLIDE_AT := 20.0          # m over the ground: well above HunterMove.glide_height, where the source pulls down
const SETTLE_S := 1.5           # s with no keys after a dash or knock: long enough to come to rest

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("FPSFEEL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var apex_target := Hunter.JUMP_V * Hunter.JUMP_V / (2.0 * Hunter.H_GRAV)
	for arch: String in HEROES:
		var rows := {}          # measure -> [value per step]
		for dt: float in STEPS:
			var got := _measure(main, arch, dt)
			for key: String in got:
				if not rows.has(key):
					rows[key] = []
				rows[key].append(got[key])
		for key: String in rows:
			var v: Array = rows[key]
			var lo: float = v.min()
			var hi: float = v.max()
			var spread := (hi - lo) / maxf(absf(hi), 0.01)
			var who: String = HEROES[arch]
			print("FPSFEEL %-7s %-10s %7.3f %7.3f %7.3f  spread %4.1f%%" % [who, key, v[0], v[1], v[2], spread * 100.0])
			ok(spread <= SPREAD, "%s %s agrees across 30/60/144 fps (%.1f%%)" % [who, key, spread * 100.0])
			var target: float = {"apex_m": apex_target, "sink_mps": HunterMove.glide_pull_vy}.get(key, 0.0)
			if target > 0.0:
				for x: float in v:
					ok(absf(x / target - 1.0) <= SPREAD, "%s %s %.3f matches [game data] %.3f" % [who, key, x, target])
	print("FPS FEEL CHECK DONE, failures: ", bad)
	main.get_tree().quit()

## One hero's scripted run at one step size: {apex_m, tap_m, hold_m, sink_mps, knock_m}.
func _measure(main: Node, arch: String, dt: float) -> Dictionary:
	var m := _match(main, arch)
	var h: Hunter = m.player
	var home := h.pos
	var out := {}
	# run 1 s, then jump off the run
	h.inp["move"] = Vector2(1, 0)
	_for(m, 1.0, dt)
	var g0 := h.pos.y
	h.inp["jump"] = true
	var apex := 0.0
	for i in roundi(2.0 / dt):
		m.step(dt)
		apex = maxf(apex, h.pos.y - g0)
		if h.grounded and i > 2:
			break
	out["apex_m"] = apex
	out["tap_m"] = _dash(m, h, home, dt, false)
	out["hold_m"] = _dash(m, h, home, dt, true)
	# glide 2 s high over the ground; the sink is the second second's
	_reset(h, home + Vector3(0, GLIDE_AT, 0))
	h.grounded = false
	h.inp["jump"] = true
	h.inp["glide"] = true
	_for(m, 1.0, dt)
	var y1 := h.pos.y
	h.inp["glide"] = true
	_for(m, 1.0, dt)
	out["sink_mps"] = y1 - h.pos.y
	# a standard knock from standing, slid to rest
	_reset(h, home)
	h.impulse(Vector2(KNOCK * h.mass(), 0.0))
	var x0 := h.pos.x
	_for(m, SETTLE_S, dt)
	out["knock_m"] = h.pos.x - x0
	m.queue_free()
	return out

## A dash from standing along +x (Shift held throughout when `hold`), slid to rest: the metres covered.
func _dash(m: Match, h: Hunter, home: Vector3, dt: float, hold: bool) -> float:
	_reset(h, home)
	h.inp["move"] = Vector2(1, 0)
	h.inp["dash"] = true
	h.inp["dash_down"] = true
	var x0 := h.pos.x
	for i in roundi(SETTLE_S / dt):
		m.step(dt)
		h.inp["move"] = Vector2.ZERO
		h.inp["dash_down"] = hold
	return h.pos.x - x0

## Steps `seconds` of sim at `dt`, the glide key held when it was set.
func _for(m: Match, seconds: float, dt: float) -> void:
	var glide := bool(m.player.inp["glide"])
	for i in roundi(seconds / dt):
		m.player.inp["glide"] = glide
		m.step(dt)

## A standing hunter at p with full dashes, no keys.
func _reset(h: Hunter, p: Vector3) -> void:
	for i in 30:
		h.m.step(Match.DT)          # (whatever ran before ends on the same clock every time)
	h.teleport(p)
	h.vel = Vector3.ZERO
	h.grounded = true
	h.roll_t = 0.0
	h.knock_t = 0.0
	h.gliding = false
	h.glide_fuel = 1.0
	h.glide_cd = 0.0
	h.dashes = h.max_dashes()
	h.ex_cd = 0.0
	h.dash_buf = 0.0
	for k in ["jump", "dash", "dash_down", "glide", "glide_btn", "fire", "crouch"]:
		h.inp[k] = false
	h.inp["move"] = Vector2.ZERO

## A fresh match as `arch` on a flat 29 x 29 m patch, the other hunters far away and idle.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"god": true, "cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch)})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var h: Hunter = m.player
	var w: World = m.world
	var cx := int(floor(h.pos.x))
	var cz := int(floor(h.pos.z))
	var home_i: int = w.idx(cx, cz)
	var level: int = int(w.level[home_i]) if w.kind[home_i] != World.T_VOID else 0
	for dz in range(-14, 15):
		for dx in range(-14, 15):
			if not w.inb(cx + dx, cz + dz):
				continue
			var i: int = w.idx(cx + dx, cz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = level
			w.island[i] = w.island[home_i]
			w.walls.erase(i)
			w.props.erase(i)
			w.stairs.erase(i)
	h.teleport(Vector3(cx - 8.5, level * World.LEVEL, cz + 0.5))
	h.set_arch(arch)
	h.unlock_all()
	h.ctrl = "local"
	if h.kin:
		(h.kin as Kin).stow()
	for other in m.hunters:
		if other != h:
			other.ctrl = "idle"
			other.teleport(h.pos + Vector3(40, 0, 40))
	for i in 20:
		m.step(Match.DT)
	return m
