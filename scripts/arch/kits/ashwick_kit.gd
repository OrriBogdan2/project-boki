class_name AshwickKit
extends ArchKit
## Linwick (id ashwick, heavy). Gameplay follows the "everything builds toward a burn" brief and the
## reference sheet (docs/heroes/ashwick.md); names, art, sounds and text are ours.
##
## - Passive, Flashover: every hit builds Char on a foe (31 = Ablaze: 3s of burning for a share of their
##   health). Stoking a foe that already burns Flashes it over (fiercer). One flame pip over a foe
##   Ablaze, three and a glow over one that Flashed over. Char falls off after 5s. A knock heals, and resets the cloak.
## - LMB, Torch Lance: hold for a hose of fire (a cyan pilot flame first); the stream keeps its own
##   velocity so a sweep bends it, narrow at the nozzle and billowing at the end. +25% on a burning foe.
## - RMB, Cinder Shot: hold to aim down a lane, release: a cinder that lands at the cursor (max 14m);
##   it sets the foe Ablaze; on a burning foe it upgrades and spreads.
## - Shift, Soot Ram: two charges of a short head-first dash toward the cursor that STOPS on the
##   first foe with a fiery impact; rank 3 stokes and lays a 4s lava carpet (the folded Jetpack).
## - E, Furnace Cloak: a 0.2s edge ring, then the blast: scorch, Char, Anti-Heal, drag foes in (walls block),
##   and a swirling shield for what it hit.

const FLAME_CYAN := Color("6fe8ff")    # the pilot flame: a cool nozzle against warm fire
const BOLT_COL := Color("ff4a6a")      # Cinder Shot's red-pink body
const BOLT_CORE := Color("ffe070")
const SKULL_COL := Color("ff6a2a")
const PIP_COL := Color("ff9a3a")
const NOZZLE := Vector3(1.3, 0.9, 0.15)  # the nozzle's tip from the feet in the aim pose: forward, up, right (m)

var chars := {}                 # foe id -> {e, n, t}
var ignites := {}               # foe id -> {e, lvl, until}
var drags: Array = []           # foes being dragged in by the shield blast: {e, left}
var trail: Array = []           # fire-trail points: {p, until}
var hose := AshwickHose.new()   # the Torch Lance stream
var flame_acc := 0.0
var spool := 0.0                # how long the hose has been held
var after_t := 0.0              # the slow after letting go
var relight_t := 0.0            # the lance can't relight until this runs out (0.35s after a release)
var was_held := false
var trail_acc := 0.0
var ember_t := 0.0
var cloak_t := 0.0              # hold: the Furnace Cloak's 0.2s ring before the blast
var bash := {}                  # hold: the Soot Ram under way {t, dir, start, hit}
var aiming := false             # hold: Cinder Shot held (the lane shows)
var fx: LDFx
var ignitions := 0              # (tests)
var upgrades := 0
var spreads := 0
var resets := 0
var cloaks := 0
var blasts := 0
var refunds := 0
var trail_hits := 0
var pulled := 0
var flame_ticks := 0
var bash_hits := 0
var fizzles := 0
var bolt_ends: Array = []       # (tests) where each Cinder Shot ended: [at, expired]

func rd() -> Dictionary: return res_def()
func lmbd() -> Dictionary: return d.get("lmb", {})
func res_text() -> String: return "%d" % int(_best_char())
func res_frac() -> float: return clampf(_best_char() / res_max(), 0.0, 1.0)
func ready_label() -> String: return "FLASHOVER" if not ignites.is_empty() else ""

func _setup() -> void:
	fx = LDFx.of(m)
	LDSfx.ensure()

func _best_char() -> float:
	var b := 0.0
	for k in chars:
		b = maxf(b, float(chars[k]["n"]))
	return b

func _fwd() -> Vector3:
	var d2 := h.aim_dir()
	return Vector3(d2.x, 0.0, d2.y)

## The nozzle: held low at the right hip, pointed forward (sheet: LMB animation).
func nozzle() -> Vector3:
	var f := _fwd()
	return h.pos + f * NOZZLE.x + f.cross(Vector3.UP) * NOZZLE.z + Vector3(0, NOZZLE.y, 0)

# ------------------------------------------------------------------ Char and Flashover
func char_of(f: Ent) -> float:
	var e: Dictionary = chars.get(f.get_instance_id(), {})
	return float(e.get("n", 0.0))

func burning(f: Ent) -> int:
	var e: Dictionary = ignites.get(f.get_instance_id(), {})
	return int(e.get("lvl", 0)) if not e.is_empty() and float(e["until"]) > m.time else 0

## Adds Char; at the top the foe goes Ablaze (or the burn upgrades). True if that stoked the burn.
func add_char(f: Ent, amt: float) -> bool:
	if f == null or not is_instance_valid(f) or f.dead or f.team == h.team:
		return false
	var key := f.get_instance_id()
	var e: Dictionary = chars.get(key, {"e": f, "n": 0.0, "t": 0.0})
	e["n"] = float(e["n"]) + amt
	e["t"] = m.time
	chars[key] = e
	if float(e["n"]) >= float(rd()["ignite_at"]):
		e["n"] = 0.0          # extra Char past the top is discarded
		stoke(f)
		return true
	return false

## Apply or upgrade the burn on a foe (Ablaze, then Flashover).
func stoke(f: Ent) -> int:
	var cur := burning(f)
	var lvl := mini(2, cur + 1)
	if cur == 0: ignitions += 1
	elif lvl > cur: upgrades += 1
	_ignite(f, lvl, cur)
	return lvl

func _ignite(f: Ent, lvl: int, was: int) -> void:
	var key := f.get_instance_id()
	ignites[key] = {"e": f, "lvl": lvl, "until": m.time + float(rd()["ignite_t"])}
	var dps := float(rd()["dps%d" % lvl]) * f.max_hp * power("sec")
	if f.remote:
		f.hurt(0.01, h, {"src": "flame", "burn": dps, "burn_for": float(rd()["ignite_t"])})
	else:
		f.burn_t = maxf(f.burn_t, float(rd()["ignite_t"])); f.burn_dps = dps; f.burn_by = h
	var col := res_col()
	if lvl == 2 and was < 2:
		payoff_fx(f.pos, "FLASHOVER", Color("ffe0a0"), "lw_blaze", h.aim_dir(), f)
		fx.sunburst(f.pos + Vector3(0, 1.0, 0), 1.6, Color("ff7a2a"), Color("fff0b0"), 0.35, true)
		if not was_held: play("lw_stoke")
	elif was == 0:
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "ABLAZE", col, false)
		m.fx.burst(f.pos + Vector3(0, 1.0, 0), col, 22, 4.0, 0.5, -3.0, 1.3)
		m.sfx("as_ignite", f.pos, -3.0, 1.0)
		net_ring(f.pos, 1.2, col)

func _refund(slot: String) -> void:
	if rank("sec" if slot == "rmb" else "kin") < 3:
		return
	var sd: Dictionary = rmb_def() if slot == "rmb" else e_def()
	cd[slot] = float(cd[slot]) * (1.0 - float(sd.get("refund", 0.25)))
	refunds += 1

func on_knock(t: Hunter, mine: bool) -> void:
	if not mine or not is_instance_valid(t):
		return
	h.heal(h.max_hp * float(rd()["heal_knock"]))
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 14, 2.5, 0.5, -2.0)
	if not was_held: play("lw_stoke")
	if h.dashes < h.max_dashes():
		h.dashes = minf(h.max_dashes(), floorf(h.dashes) + 1.0)     # a knock gives back one ram charge, never more
		st["knock_charges"] = int(st.get("knock_charges", 0)) + 1
	if float(cd["e"]) > 0.0:
		cd["e"] = 0.0
		resets += 1
		m.fx.word(h.pos + Vector3(0, 2.8, 0), "CLOAK READY", col_of(e_def()), true)
		fx.wave(h.pos, 2.0, col_of(e_def()), 0.35)
		m.sfx("ab_ready", h.pos, -2.0, 0.8)
		if h.is_local(): h._ab_feedback("k1", "ready")
		net_ring(h.pos, 2.0, col_of(e_def()))

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	fx.track()
	if after_t > 0.0: after_t -= dt
	if relight_t > 0.0: relight_t -= dt
	for key in chars.keys():
		var e: Dictionary = chars[key]
		if not is_instance_valid(e["e"]) or (e["e"] as Ent).dead or m.time - float(e["t"]) > float(rd()["expire"]):
			chars.erase(key)
	for key in ignites.keys():
		var e: Dictionary = ignites[key]
		if not is_instance_valid(e["e"]) or (e["e"] as Ent).dead or float(e["until"]) <= m.time:
			ignites.erase(key)
	_tick_tells(dt)
	if not hose.puffs.is_empty():
		hose.step(m.world, dt)
		_hose_look()
	if cloak_t > 0.0:
		cloak_t -= dt
		if h.stun_t > 0.0 or h.downed:
			cloak_t = 0.0
		elif cloak_t <= 0.0:
			cloak_t = 0.0
			_cloak_blast()
	if not bash.is_empty(): _tick_bash(dt)
	if not drags.is_empty(): _tick_drags(dt)
	if not trail.is_empty(): _tick_trail(dt)
	if h.shield_t > 0.0 and h.shield > 0.5 and st.get("shield_on", false):
		if tells_visible():
			# the Furnace Cloak's shield: a swirling ring of fire hugging Linwick while it holds (about 0.8 bh)
			fx.place("swirl%d" % h.get_instance_id(), "swirl", h.pos + Vector3(0, 0.55, 0), Color("ffb040"), Color("fff0b0"), 1.8, m.time * 2.0, 1.0)
			fx.place("swirl2%d" % h.get_instance_id(), "swirl", h.pos + Vector3(0, 1.25, 0), Color("ff7a2a"), Color("ffd890"), 1.45, -m.time * 2.6, 0.7)
	else:
		st["shield_on"] = false
	tell = "full" if _best_char() >= 22.0 else ("half" if _best_char() >= 12.0 else "")
	net_pulse(dt, not ignites.is_empty(), 1.3)

## The pilot flame at the nozzle, embers over a heavily charred foe, and the burn stage over each burning
## foe: one flame pip for Ablaze, three and a glow for Flashover (sheet gap 4b).
func _tick_tells(dt: float) -> void:
	var vis := tells_visible()
	if vis and h.wid == "flamethrower" and not h.downed and not KinMerge.active(h):
		var fl := 0.85 + 0.15 * sin(m.time * 37.0)
		var big := 1.0 + (1.2 if was_held and spool < float(lmbd()["spool"]) else 0.0)
		fx.place("pilot%d" % h.get_instance_id(), "pilot", nozzle(), FLAME_CYAN, Color("e8fbff"), 0.2 * fl * big)
	ember_t -= dt
	if ember_t <= 0.0:
		ember_t = 0.35
		for key in chars:
			var e: Dictionary = chars[key]
			if float(e["n"]) >= 15.0 and vis:
				m.fx.burst((e["e"] as Ent).pos + Vector3(0, 1.7, 0), Color("ff9a3a"), 2, 1.0, 0.6, -2.0, 0.8)
	if not vis:
		return
	for key in ignites:
		var e: Dictionary = ignites[key]
		var f := e["e"] as Ent
		if not is_instance_valid(f):
			continue
		var lvl := int(e["lvl"])
		var top := f.pos + Vector3(0, 3.7, 0)
		var n := 1 if lvl < 2 else 3
		for i in n:
			var off := Vector3((i - (n - 1) * 0.5) * 0.6, (0.06 if i == 1 else 0.0) if n == 3 else 0.0, 0)
			fx.place("pip%d_%d" % [key, i], "pip", top + off, PIP_COL if lvl < 2 else Color("ff5a2a"), Color("fff0a0"), 0.4 if lvl < 2 else 0.44)
		if lvl >= 2:
			fx.place("pipg%d" % key, "glow", top + Vector3(0, -0.05, 0), Color("ff4a1a"), Color("ff9a3a"), 0.75 + 0.08 * sin(m.time * 9.0))

## Shown burn stage over a foe: 0, 1 (Ablaze, one pip) or 3 (Flashover, three pips) (tests).
func pips_on(f: Ent) -> int:
	var key := f.get_instance_id()
	var n := 0
	for i in 3:
		if fx.shown("pip%d_%d" % [key, i]): n += 1
	return n

## A Boki merge ends the hose, a Furnace Cloak about to go off, a bash mid-flight and the Cinder Shot lane,
## with nothing fired.
func _drop_holds() -> void:
	hose.clear()
	if fx: fx.flame_off("hose%d" % h.get_instance_id())
	spool = 0.0
	was_held = false
	after_t = 0.0
	flame_acc = 0.0
	h.mel_hold = 0.0
	cloak_t = 0.0
	bash = {}
	aiming = false

func move_k() -> float:
	if was_held and h.wid == "flamethrower": return 0.8
	return 0.6 if after_t > 0.0 else 1.0

# ------------------------------------------------------------------ LMB: Torch Lance
func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "flamethrower":
		return false
	if held and h.ammo <= 0 and h.reload_t <= 0.0:
		h.start_reload()          # out of fuel: the tank refills
	if not held or not h.can_fire() or KinMerge.transforming(h) or KinMerge.active(h) or (relight_t > 0.0 and not was_held):       # (a merge ends the roar: holding the key on must not relight it)
		if was_held:
			play("as_lance_end")
			after_t = float(lmbd().get("slow_after", 0.35))
			relight_t = float(lmbd().get("relight", 0.35))      # a short gap before the lance can roar again
			h.mel_hold = 0.0
			hose.snuff()
		was_held = false
		spool = 0.0
		flame_acc = 0.0
		return true
	var ld := lmbd()
	if not was_held:
		play("as_lance")
		m.sfx("lw_pilot", h.pos, -3.0, 1.0)
		fx.orb(nozzle(), FLAME_CYAN, Color.WHITE, 0.55, float(ld["spool"]))      # the pilot flares cyan before the roar
	was_held = true
	h.idle_fire = 0.0              # firing: no auto-reload mid-roar
	spool += dt
	h.mel_hold = minf(spool, float(ld["spool"]))
	if spool < float(ld["spool"]):
		return true                # the pilot's flicker: no fire yet
	if h.ammo > 0:
		hose.emit(nozzle(), h.aim_dir(), h.vel, h.pos.y, float(ld["speed"]), float(ld["range"]), dt)
	flame_acc += dt
	var tick := float(ld["tick"])
	while flame_acc >= tick and h.ammo > 0:
		flame_acc -= tick
		h.ammo -= 1               # a tick of fuel (10 a second)
		_flame_tick(tick)
	return true

## The hose's look: the MultiMesh of puffs (LDFx.flame).
func _hose_look() -> void:
	var id := "hose%d" % h.get_instance_id()
	if not tells_visible():
		fx.flame_off(id)
		return
	var ld := lmbd()
	fx.flame(id, hose.parts(float(ld["w0"]), float(ld["w1"])))

func _flame_tick(tick: float) -> void:
	var ld := lmbd()
	flame_ticks += 1
	if flame_ticks % 4 == 1:
		m.sfx("lw_roar", h.pos, -6.0, 0.95 + randf() * 0.1)
	var w0 := float(ld["w0"]); var w1 := float(ld["w1"])
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var pf := hose.touching(f, w0, w1)
		if pf.is_empty() or not sees_from(pf["p"], f, 0.0):
			continue
		var hot := burning(f) > 0
		var dmg := float(ld["dps"]) * tick * (float(ld["burning_k"]) if hot else 1.0)
		f.hurt(dmg, h, {"src": "flame", "ab": "primary", "tags": ["flame"], "melee": false})
		add_char(f, float(ld["char_burning"] if hot else ld["char_tick"]))
		if flame_ticks % 2 == 0 and tells_visible():
			m.fx.spark(f.pos + Vector3(0, 1.0, 0), Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4)), Color("ffb04a"), 4, 4.0, 70.0, 0.3)

# ------------------------------------------------------------------ RMB: Cinder Shot
## Held: a thin white lane to the cursor (clamped to 14m) with a small end ring, the gun hand cocked.
func rmb_hold_tick(_t: float) -> void:
	if KinMerge.active(h) or not rmb_ready():
		return
	if not aiming:
		aiming = true
		play("as_aim")
	var rdf := rmb_def()
	var ln := AimMode.dist(h, float(rdf["range"]))
	AimKit.lane(h, "rmb", {"len": ln, "width": 0.42, "col": Color("fff4e6"), "col2": BOLT_COL, "alpha": 0.9, "tip": true})
	AimKit.circle(h, "rmb_end", {"at": h.pos + _fwd() * ln, "r": 0.55, "col": Color("bfe0ff")})

func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	var was_aiming := aiming
	aiming = false
	AimKit.hide(h, "rmb")
	AimKit.hide(h, "rmb_end")
	if not spend_rmb():
		if was_aiming: play("")
		return
	var rdf := rmb_def()
	play("as_shot")
	var amt := float(rdf["dmg"]) * (1.6 if rank("sec") >= 3 else 1.0)
	var rng := AimMode.dist(h, float(rdf["range"]))      # lands at the cursor, 14m at most (sheet 0133)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(rdf["speed"]), "range": rng, "size": float(rdf["size"])},
		"effects": [{"type": "damage", "amount": amt}]})
	var n0: int = m.shots.size()
	run(stg, cx("rmb", "cinder_shot", aim(), {"on_foe": func(f: Ent, _c: Dictionary): _cinder_hit(f)}))
	if m.shots.size() > n0:
		fx.ride(m.shots[-1], "cinder", BOLT_COL, BOLT_CORE, 1.6, 0.5, _bolt_end)
	var mz := nozzle() + Vector3(0, 0.2, 0)
	fx.orb(mz, Color("ff6a3a"), BOLT_CORE, 0.8, 0.12)
	m.fx.burst(mz, Color("ffb04a"), 10, 4.0, 0.3, -2.0, 1.2, _fwd(), 30.0)
	m.sfx("lw_bolt", h.pos, -2.0, 1.0)
	if h.is_local(): Oomph.punch_dir(m, -h.aim_dir(), 0.12)

## A cinder that ran out at the cursor fizzles there in a small blue-white ring (sheet 0133).
func _bolt_end(at: Vector3, expired: bool) -> void:
	bolt_ends.append([at, expired])
	if bolt_ends.size() > 8: bolt_ends.pop_front()
	if not expired:
		return
	fizzles += 1
	fx.wave(ground(at), 0.9, Color("bfe0ff"), 0.3, Color("6a5aff"))
	fx.orb(at, Color("8ab0ff"), Color.WHITE, 0.5, 0.15)
	m.sfx("lw_bolt_hit", at, -10.0, 1.5)

func _cinder_hit(f: Ent) -> void:
	if not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	var rdf := rmb_def()
	var cur := burning(f)
	# the impact: a red flash and an ember shower (sheet 0076-0079)
	fx.orb(f.pos + Vector3(0, 1.0, 0), Color("ff3a3a"), BOLT_CORE, 1.4, 0.18)
	fx.embers(f.pos, 0.6)
	m.sfx("lw_bolt_hit", f.pos, -1.0, 1.0)
	Feel.hitstop(m, h, f, float(rdf["dmg"]), {})
	if cur > 0:
		# a burning foe: upgrade, and the burn the foe had spreads to the ones around
		spreads += 1
		var around := foes_in(f.pos, float(rdf["spread_r"]))
		stoke(f)
		for o in around:
			if o != f and is_instance_valid(o) and not o.dead and sees_from(f.pos, o):
				_ignite(o, cur, burning(o))
				m.fx.bolt(f.pos + Vector3(0, 1.0, 0), o.pos + Vector3(0, 1.0, 0), Color("ff7a2a"))
		fx.wave(f.pos, float(rdf["spread_r"]), col_of(rdf), 0.35)
		m.fx.word(f.pos + Vector3(0, 2.5, 0), "SPREAD", col_of(rdf), true)
	else:
		stoke(f)
	_refund("rmb")

func sees_from(p: Vector3, o: Ent, lift := 0.95) -> bool:
	return m.world.los(p, o.pos, p.y + lift)

# ------------------------------------------------------------------ Shift: Soot Ram
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	var dir := h.aim_dir()
	if use_ex and not h.grounded:
		# the class air dash, Linwick's way: a jet from the bellows tucks him into a ball
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)), {"invuln": 0.08, "trail": "", "dir": dir}, true)
		play("lw_hop")
		m.sfx("lw_hop", h.pos, -3.0, 1.0)
		fx.sunburst(h.pos + Vector3(0, 0.5, 0), 0.9, Color("ff8a3a"), Color("ffe0a0"), 0.25, true)
		bash = {"t": float(h.cdat.get("ex_time", 0.21)), "dir": dir, "start": h.pos, "hit": true, "hop": true}
		return true
	if not spend_dash(false):
		return true
	var t := float(dd["time"])
	travel(float(dd["dist"]), t, {"invuln": 0.06, "trail": "", "dir": dir})
	st["last_dash"] = "soot_ram"
	play("as_leap")
	h.glide_cd = maxf(h.glide_cd, t + 0.35)
	m.sfx("lw_bash", h.pos, -2.0, 1.0)
	bash = {"t": t, "dir": dir, "start": h.pos, "hit": false}
	return true

## While the ram flies: the flame skull wraps his front and ember tails stream behind; the first foe it
## meets stops the dash with the impact (sheet gap 2).
func _tick_bash(dt: float) -> void:
	var dir: Vector2 = bash["dir"]
	bash["t"] = float(bash["t"]) - dt
	if tells_visible():
		var f3 := Vector3(dir.x, 0, dir.y)
		if bash.get("hop", false):
			fx.orb(h.pos + Vector3(0, 0.7, 0) - f3 * 0.4, Color("ff8a3a"), Color("ffe0a0"), 0.5, 0.25)
		elif not bash.get("hit", false):
			fx.place("skull%d" % h.get_instance_id(), "skull", h.pos + Vector3(0, 0.95, 0) + f3 * 0.35, SKULL_COL, Color("ffe08a"), 1.0, atan2(-dir.x, -dir.y))
	if not bash.get("hit", true):
		for f in m.foes_of(h.team):
			if not f.hittable() or absf(f.pos.y - h.pos.y) > 1.8:
				continue
			var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
			if to.length() < h.r + f.r + 0.45 and (to.length() < 0.2 or to.normalized().dot(dir) > 0.2):
				_bash_impact(f)
				break
	if float(bash["t"]) <= 0.0:
		var b := bash
		bash = {}
		if not b.get("hop", false):
			if rank("dash") >= 3:
				_lay_trail(b["start"])
			if not b.get("hit", false):
				m.fx.dust(h.pos, 6)

func _bash_impact(f: Ent) -> void:
	var dd := dash_def()
	bash["hit"] = true
	bash_hits += 1
	h.roll_t = 0.0                  # the dash stops on the foe
	var dir: Vector2 = bash["dir"]
	h.vel.x = -dir.x * float(dd["recoil"]); h.vel.z = -dir.y * float(dd["recoil"])     # and he bounces back a little off them
	f.hurt(float(dd["dmg"]) * power("dash"), h, {"src": "flame", "ab": "dodge", "tags": ["flame"], "melee": true, "kb": dir * float(dd["kb"])})
	add_char(f, float(dd["char"]))
	if rank("dash") >= 3:
		stoke(f)
	var at := (h.pos + f.pos) * 0.5 + Vector3(0, 1.0, 0)
	fx.sunburst(at, 2.2, Color("ff4a2a"), Color("ffe0a0"), 0.3, true)
	fx.orb(at, Color("ff6a2a"), Color.WHITE, 1.8, 0.14)
	m.fx.burst(at, Color("ff5a3a"), 26, 6.0, 0.45, 6.0, 1.3)
	m.sfx("lw_bash_hit", f.pos, 0.0, 1.0)
	Feel.hitstop(m, h, f, 30.0, {"melee": true, "heavy": true})
	Feel.shake(m, "t2", h, f.pos, f)
	if h.is_local(): Oomph.punch_dir(m, dir, 0.25)
	net_ring(f.pos, 1.4, SKULL_COL)

func _lay_trail(start: Vector3) -> void:
	var dd := dash_def()
	var a := Vector2(start.x, start.z); var b := Vector2(h.pos.x, h.pos.z)
	var n := maxi(1, int(ceil(a.distance_to(b) / 0.9)))
	var seg_a := Vector3.INF
	var seg_b := Vector3.INF
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var g: float = m.world.ground_at(p.x, p.y)
		if g <= World.VOID + 1.0:
			if seg_a != Vector3.INF and seg_b != Vector3.INF and seg_a.distance_to(seg_b) > 0.3:
				fx.lava(seg_a, seg_b, float(dd["trail_w"]), float(dd["trail_t"]))
			seg_a = Vector3.INF
			continue           # fire never forms over the abyss
		var q := Vector3(p.x, g, p.y)
		trail.append({"p": q, "until": m.time + float(dd["trail_t"])})
		if seg_a == Vector3.INF: seg_a = q
		seg_b = q
	if seg_a != Vector3.INF and seg_b != Vector3.INF and seg_a.distance_to(seg_b) > 0.3:
		fx.lava(seg_a, seg_b, float(dd["trail_w"]), float(dd["trail_t"]))
		m.sfx("lw_trail", seg_b, -4.0, 1.0)
	while trail.size() > 14: trail.pop_front()

func _tick_trail(dt: float) -> void:
	trail = trail.filter(func(t): return float(t["until"]) > m.time)
	trail_acc += dt
	if trail_acc < 0.3:
		return
	trail_acc = 0.0
	var dd := dash_def()
	var rr := float(dd["trail_w"]) * 0.5
	for t in trail:
		if randf() < 0.5: m.fx.burst((t["p"] as Vector3) + Vector3(0, 0.2, 0), Color("ff8a3a"), 2, 1.5, 0.4, -3.0, 1.2)
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		for t in trail:
			if Vector2(f.pos.x - t["p"].x, f.pos.z - t["p"].z).length() < rr + f.r and absf(f.pos.y - t["p"].y) < 1.6:
				f.hurt(float(dd["trail_dps"]) * 0.3, h, {"src": "flame", "ab": "dodge", "tags": ["flame"], "slow": 0.25, "slow_for": 0.5})
				add_char(f, 4.0)
				trail_hits += 1
				break

# ------------------------------------------------------------------ E: Furnace Cloak
## The press: arms crossed, a thin orange ring at full radius for 0.2s (everyone sees it), then the blast.
func cast_e() -> bool:
	if cloak_t > 0.0:
		return false
	var ed := e_def()
	cloaks += 1
	cloak_t = float(ed["tele"])
	play("as_cloak")
	AimKit.circle(h, "e_ring", {"self": true, "r": float(ed["radius"]), "all": true, "dur": float(ed["tele"]), "col": col_of(ed), "hot": 0.3})
	m.sfx("lw_shield", h.pos, -1.0, 1.0)
	return true

func _cloak_blast() -> void:
	var ed := e_def()
	blasts += 1
	var col := col_of(ed)
	var hit := 0
	var stoked := false
	var k := 1.5 if rank("kin") >= 3 else 1.0
	var r := float(ed["radius"])
	fx.sunburst(h.pos, r * 1.05, Color("ffb040"), Color("fff4c0"), 0.4)
	fx.scorch(h.pos, r * 0.75, 1.6)
	fx.wave(h.pos, r, col, 0.3)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 30, 6.0, 0.5, -2.0, 1.4)
	Feel.shake(m, "t2", h, h.pos)
	for f in foes_in(h.pos, r):
		if not sees(f):
			continue
		hit += 1
		f.hurt(float(ed["dmg"]) * power("kin") * k, h, {"src": "flame", "ab": "k1", "tags": ["flame", "cloak"]})
		if add_char(f, float(ed["char"])): stoked = true
		KitStatus.apply(f, "blt", float(ed["blt_t"]))
		m.fx.burst(f.pos + Vector3(0, 1.4, 0), Color("6a4a5a"), 8, 1.5, 0.6, -1.0, 1.6)      # a smoke puff over the target
		if f.mass() < 6.0 and not f.remote:
			drags.append({"e": f, "left": 0.45})
			pulled += 1
	if hit > 0:
		h.shield = maxf(h.shield, h.max_hp * (float(ed["shield_base"]) + float(ed["shield_each"]) * hit) * k)
		h.shield_t = float(ed["shield_t"])
		st["shield_on"] = true
		m.sfx("shield", h.pos, -5.0, 0.9)
	if stoked: _refund("e")
	net_ring(h.pos, r, col)

func _tick_drags(dt: float) -> void:
	var ed := e_def()
	for dg in drags.duplicate():
		var fe = dg["e"]
		dg["left"] = float(dg["left"]) - dt
		if not is_instance_valid(fe) or (fe as Ent).dead or float(dg["left"]) <= 0.0:
			drags.erase(dg); continue
		var e := fe as Ent
		var to := Vector2(h.pos.x - e.pos.x, h.pos.z - e.pos.z)
		var dist := to.length()
		if dist <= float(ed["gap"]):
			drags.erase(dg); continue
		var step := minf(float(ed["pull_speed"]) * dt, dist - float(ed["gap"]))
		var dir := to / dist
		var nx := e.pos.x + dir.x * step; var nz := e.pos.z + dir.y * step
		var bx: float = m.world.occupy(nx, e.pos.z, e.r, e.pos.y, false)
		var bz: float = m.world.occupy(e.pos.x, nz, e.r, e.pos.y, false)
		if bx == 0.0: e.pos.x = nx
		if bz == 0.0: e.pos.z = nz
		if bx != 0.0 and bz != 0.0: drags.erase(dg)

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var te := tgt as Ent
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist < float(e_def()["radius"]) - 0.5:
		h.inp["aim"] = tgt.pos; h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < float(rmb_def()["range"]) - 1.0 and dist > 3.0 and (burning(te) > 0 or randf() < 0.5):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sec"] = true; return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 2.5 and dist < 5.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
