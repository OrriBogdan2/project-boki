class_name MageKit
extends ArchKit
## Sparkle (archetype id "mage", light): the storm-kite runner. docs/heroes/mage.md has the per-slot
## table, the assumptions and the research notes (briefs/hero-ref/vireo.md, owner playtest notes).
##
## Loop: finger bolts (1 Static each, every 0.8s, out to full range), Storm Rod and Skycall (2) load
## Static onto a foe; at 4 a sky bolt lands on them and they are Live. Wirerun (hold: the lane and its
## end ring grow with the charge, you can't steer and you keep your height, any drift carries) through
## a Live foe is a Blowout: the run hits double, Static spent, Wirerun back at once (the only reset).
## The Storm Rod knocks the first foe back (a stun against a wall or another foe) and leaves a charge
## orb, a pickup that gives Wirerun back; Skycall drags a crowd the way you flick and grounds it.

const PINK := Color("ff3fb4")        # the lightning's hot core: it burns hot pink (DECISIONS), on the teal
const COPPER := Color("e08a46")
const VIOLET := Color("3a1c8c")
const DEEP_GOLD := Color("e0900a")   # the aim kit whitens its accent: this lands as a rich gold
const TEAL := Color("1fc6dc")        # the lightning's body: a saturated teal that reads on bright grass
const MARK_LIFT := 0.5               # m the Static marker sits above the HP bar
const ECHO_GAP := 0.045              # s between her after-images on the Wirerun and the air dash

var sparks := {}               # foe id -> {e, n, t}
var wire := {}                 # Wirerun held: {t, y, air, end}
var run_t := 0.0               # Wirerun streaking (s left): the model is a lightning silhouette
var motes: Array = []          # charge orbs: {pos, t, node, owner, fly}
var mote_pool: Array = []      # orb nodes, reused
var strikes: Array = []        # Skycall: {at, t, dir, phase ("flick" | "count"), dir0}
var rod: Node3D = null         # the Storm Rod held in the hand while RMB is down
var rod_full := false
var blowouts := 0              # tests and the demo
var reset_dash_boost := false  # a reset armed the next Wirerun: further, charged quicker
var reset_boost_t := 0.0       # s left on it
var slams := 0
var orb_bursts := 0
var lmb_n := 0                 # finger bolts fired (right, left, right...)
var last_shot := 0
var last_dash_kind := ""
var last_strike := {}          # tests: the last Skycall's {at, dir}
var last_push := 0.0           # tests: how hard the last rod knocked
var echo_t := 0.0
var ult: MageUlt               # Kitefall, her ultimate on X
var sky: MageSky               # Skycall (E) and the orbs it flings
var gum                        # the bubble she blows and pops (mage_gum.gd)

func _setup() -> void:
	ult = MageUlt.new(self)
	sky = MageSky.new(self)
	gum = load("res://scripts/arch/kits/mage_gum.gd").new(self)
	# her round is fired after this kit's tick, so its stock orb would draw one frame as a white ball at
	# her hand before _tick_lmb skins it: hide it just before that frame is drawn
	RenderingServer.frame_pre_draw.connect(_hide_fresh_round)

## Hides the stock orb of the round she just fired (the kit's jagged bolt is the round's look).
func _hide_fresh_round() -> void:
	if h == null or not is_instance_valid(h) or h.shot_n == last_shot:
		return
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		if shots[i]["by"] == h and not (shots[i]["x"] as Dictionary).has("src"):
			var orb := shots[i].get("node") as Node3D
			if orb != null and is_instance_valid(orb):
				orb.visible = false
			return

## A rival went down: she pops her gum at them.
func on_knock(_t: Hunter, mine: bool) -> void:
	if mine:
		gum.blow()

func fx() -> VVFx:
	return VVFx.of(m)

func cast_ult() -> bool:
	return HeroUlt.press(self, ult.cast)

func has_ult() -> bool:
	return true

func ult_running() -> bool:
	return ult.busy()

func ult_recast() -> bool:
	return ult.recast()

## Kitefall holds her from the crouch to the strike: no other key works until she lands (in the crouch Shift and
## a jump still do).
func busy() -> bool:
	return super.busy() or ult.busy()

func fire_ok() -> bool:
	return not ult.busy()

func full_ready() -> bool:
	for k in sparks:
		if int(sparks[k]["n"]) >= int(res_def()["max"]):
			return true
	return false

func _best() -> int:
	var best := 0
	for k in sparks: best = maxi(best, int(sparks[k]["n"]))
	return best

func res_text() -> String:
	return "%d/%d" % [_best(), int(res_def()["max"])]

func res_frac() -> float:
	return float(_best()) / float(res_def()["max"])

func ready_label() -> String:
	return "LIVE FOE: WIRERUN THROUGH" if full_ready() else ""

func live(f: Ent) -> bool:
	var s = sparks.get(f.get_instance_id())
	return s != null and int(s["n"]) >= int(res_def()["max"])

func spark_n(f: Ent) -> int:
	var s = sparks.get(f.get_instance_id())
	return int(s["n"]) if s != null else 0

func _top(f: Ent) -> float:
	return 2.25 * (float((f as Hunter).cdat.get("scale", 1.0)) if f is Hunter else 0.85)

# ------------------------------------------------------------------ Static
func add_spark(f: Ent, n := 1) -> void:
	if f == null or not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	if f is Hunter and (f as Hunter).downed:
		return
	var key := f.get_instance_id()
	var rd := res_def()
	var s: Dictionary = sparks.get(key, {"e": f, "n": 0, "t": 0.0})
	var was := int(s["n"])
	s["n"] = mini(int(rd["max"]), was + n)
	s["t"] = float(rd["dur"])
	sparks[key] = s
	if int(s["n"]) >= int(rd["max"]) and was < int(rd["max"]):
		# the 4th stack: a bolt drops out of the sky onto them
		var top := f.position + Vector3(0, 9.0, 0)
		fx().arc(top, f.position + Vector3(0, 0.2, 0), TEAL, PINK, 0.9, 0.28)
		fx().arc(top + Vector3(0.4, 0, -0.3), f.position + Vector3(0, 1.0, 0), TEAL, PINK, 0.5, 0.2)
		m.fx.flash(f.position + Vector3(0, 1.1, 0), PINK, 1.1, 0.1)
		m.sfx("vv_static_full", f.pos, -2.0)
		# the word goes above the marker so the two never print over each other
		m.fx.word(f.pos + Vector3(0, _top(f) + MARK_LIFT, 0) + fx().screen_up() * 1.6, "LIVE", PINK, false)
		if anim_id == "" or m.time - anim_at > 0.3: play("mage_live")
		net_bolt(top, f.position, TEAL)
	elif int(s["n"]) > was:
		m.sfx("mage_zap", f.pos, -6.0, 0.9 + 0.08 * float(s["n"]))     # the zap climbs with each stack

func clear_sparks(f: Ent) -> void:
	var key := f.get_instance_id()
	if sparks.has(key):
		sparks.erase(key)
		fx().unmark("vs%d" % key)

func _tick_sparks(dt: float) -> void:
	var mx := int(res_def()["max"])
	for key in sparks.keys():
		var s: Dictionary = sparks[key]
		var fv = s["e"]     # untyped first: a freed foe can't be assigned to a typed var
		var f: Ent = fv if is_instance_valid(fv) else null
		if not ult.busy():                 # (Kitefall can't refresh it: it waits for the strike that spreads it)
			s["t"] = float(s["t"]) - dt
		if not is_instance_valid(f) or f.dead or float(s["t"]) <= 0.0 or (f is Hunter and (f as Hunter).downed):
			sparks.erase(key)
			fx().unmark("vs%d" % key)
			continue
		var n := int(s["n"])
		fx().marker("vs%d" % key, f, n, mx, TEAL, PINK, _top(f) + MARK_LIFT)
		if n >= mx and int(m.time * 7.0) != int((m.time - dt) * 7.0):
			# Live: arcs crawl down the body from the marker to the ground
			var foot := ground(f.pos) + Vector3(fx().rng.randf_range(-0.5, 0.5), 0.05, fx().rng.randf_range(-0.5, 0.5))
			fx().arc(f.position + Vector3(0, _top(f) - 0.3, 0), foot, TEAL, PINK, 0.35, 0.12)

func _tick(dt: float) -> void:
	_tick_sparks(dt)
	gum.tick(dt)
	if reset_dash_boost:
		reset_boost_t -= dt
		reset_dash_boost = reset_boost_t > 0.0
	ult.tick(dt)
	_tick_echo(dt)
	_tick_trail()
	_tick_motes(dt)
	sky.tick(dt)
	_tick_lmb()
	if not wire.is_empty():
		_tick_wire(dt)
	if run_t > 0.0:
		_tick_run(dt)
	if rmb_down:
		_tick_rod()
	elif rod != null and rod.visible:
		rod.visible = false
	net_pulse(dt, full_ready())

func own_dash_trail() -> bool:
	return true

## Moves whose hand leaves a teal swoosh: [hand, from s, to s].
const TRAILS := {"mage_lmb_l": ["l", 0.0, 0.12], "mage_lmb_r": ["r", 0.0, 0.12], "mage_e": ["l", 0.0, 0.34],
	"mage_e_snap": ["l", 0.0, 0.12], "mage_live": ["l", 0.0, 0.12], "mage_rmb": ["r", 0.0, 0.2]}

func _tick_trail() -> void:
	var tr: Array = TRAILS.get(anim_id, [])
	var t := float(m.time) - anim_at
	if tr.is_empty() or h.anim == null or t < float(tr[1]) or t > float(tr[2]):
		return
	var hand: Node3D = h.anim.hand_l if String(tr[0]) == "l" else h.anim.hand_r
	if hand != null:
		fx().trail("vt%d" % h.get_instance_id(), hand.global_position, TEAL, PINK, 0.24)

## Her own after-images on the air dash and the Wirerun streak: her silhouette in teal (pink on the streak).
func _tick_echo(dt: float) -> void:
	if h.roll_t <= 0.0 and run_t <= 0.0:
		echo_t = 0.0
		return
	echo_t -= dt
	if echo_t > 0.0:
		return
	echo_t = ECHO_GAP
	fx().echo(h, PINK.lerp(TEAL, 0.35) if run_t > 0.0 else TEAL, 0.3)

func teardown() -> void:
	super.teardown()
	if RenderingServer.frame_pre_draw.is_connected(_hide_fresh_round):
		RenderingServer.frame_pre_draw.disconnect(_hide_fresh_round)
	for k in sparks.keys():
		fx().unmark("vs%d" % k)
	sparks.clear()
	for mt in motes.duplicate():
		_free_mote(mt, false)
	motes.clear()
	strikes.clear()
	ult.drop()
	_end_wire(false)
	if run_t > 0.0 and h.model: h.model.visible = true
	run_t = 0.0

# ------------------------------------------------------------------ passive: weapon hits, knocks
func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team or String(o.get("src", "")) == "burn":
		return
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		add_spark(t)

# ------------------------------------------------------------------ LMB: the finger gun
## A new finger bolt left the hand: alternate hands (the bolt starts at that hand), a twist, a crackle
## at the fingertip and sparks at the feet; the round becomes a jagged bolt with a spark impact.
func _tick_lmb() -> void:
	var idle := wire.is_empty() and not rmb_down and run_t <= 0.0 and not ult.busy()
	if h.is_local() and idle and not h.downed:
		# the aim line runs through the cursor out to full range, an arrow tick at its end (always up)
		AimKit.line(h, "lmb", {"len": float(h.wpn.get("range", 13.0)), "col": Color(1, 1, 1, 0.55), "alpha": 0.8})
	if h.shot_n == last_shot:
		return
	last_shot = h.shot_n
	var sd: Dictionary = {}
	var shots: Array = m.get("shots")
	for i in range(shots.size() - 1, -1, -1):
		if shots[i]["by"] == h and not (shots[i]["x"] as Dictionary).has("src"):
			sd = shots[i]
			break
	if sd.is_empty():
		return
	lmb_n += 1
	# (ShotOrigin has seated the round at the fingertip of the hand that fires: right, then left)
	var left := h.shot_n % 2 == 1
	var d := h.aim_dir()
	play("mage_lmb_l" if left else "mage_lmb_r")
	# a teal thrust from the shoulder to the fingertip, then (at the release key, 0.06 s) the fingertip
	# crackles; pink sparks pop at her feet, a jagged bolt rides the round
	var shoulder := h.position + Vector3(0, 1.25, 0) + Vector3(-d.y, 0, d.x) * (-0.2 if left else 0.2)
	fx().smear(shoulder, shoulder + Vector3(d.x, 0, d.y) * 0.9, TEAL, PINK, 0.3, 0.12)
	m.later(0.06, _fingertip.bind(left))
	m.fx.spark(h.pos + Vector3(0, 0.1, 0), Vector3.UP, PINK, 4, 3.0, 80.0, 0.2, 6.0, 0.7)
	fx().ride(sd, "bolt", TEAL, PINK, 1.25, 0.6, _bolt_end.bind(h.pos))

## The finger-gun release: arcs flung out of the pointing fingertip and a star on it.
func _fingertip(left: bool) -> void:
	if not is_instance_valid(h) or h.anim == null:
		return
	var hand: Node3D = h.anim.hand_l if left else h.anim.hand_r
	if hand == null:
		return
	var d := h.aim_dir()
	var tip := hand.global_position + Vector3(d.x, 0, d.y) * 0.15
	if h.model:
		var at := WardenGlb.anchor(h.model, "anchor_finger_L" if left else "weapon_muzzle")
		if at != null:
			tip = at.global_position
	fx().crackle(tip, TEAL, PINK, 0.6, 4, 0.08)
	fx().star(tip, TEAL, PINK, 0.75, 0.08)

## Where a finger bolt ended: a fan of splinters sprays back toward the caster and a crackle.
func _bolt_end(at: Vector3, vel: Vector2, from: Vector3) -> void:
	var back := Vector2(from.x - at.x, from.z - at.z).normalized() if vel.length() > 0.1 else Vector2(0, 1)
	for i in 4:
		var a := (float(i) - 1.5) * 0.45 + fx().rng.randf_range(-0.15, 0.15)
		var bd := back.rotated(a)
		var ln := fx().rng.randf_range(0.5, 1.0)
		var tip := at + Vector3(bd.x * ln, fx().rng.randf_range(0.0, 0.4), bd.y * ln)
		fx().arc(at, tip, TEAL, PINK, 0.26, 0.12)
	fx().star(at, TEAL, PINK, 0.6, 0.12)

# ------------------------------------------------------------------ dash: Wirerun
func dash_charge() -> float:
	return clampf(float(wire["t"]) / wire_hold(), 0.0, 1.0) if not wire.is_empty() else -1.0

## The Wirerun comes back (a Blowout, a charge orb): the next one runs further and charges quicker, so resets chain.
func grant_reset() -> void:
	h.dashes = h.max_dashes()
	reset_dash_boost = true
	reset_boost_t = float(dash_def()["reset_window"])

## Seconds to a full charge: the running one's, or the next one's.
func wire_hold() -> float:
	var dd := dash_def()
	var boosted := bool(wire.get("boost", false)) if not wire.is_empty() else reset_dash_boost
	return float(dd["hold"]) * (float(dd["reset_charge"]) if boosted else 1.0)

func wire_reach() -> float:
	var dd := dash_def()
	var boosted := bool(wire.get("boost", false)) if not wire.is_empty() else reset_dash_boost
	return float(dd["reset_mult"]) if boosted else 1.0

func wire_len(t: float) -> float:
	var dd := dash_def()
	var L := lerpf(float(dd["dist"][0]), float(dd["dist"][1]), clampf(t / wire_hold(), 0.0, 1.0))
	return L * wire_reach()

func run_time(L: float) -> float:
	var dd := dash_def()
	# a constant speed (so a longer run takes longer), slowed by the global dash feel like every dash
	return maxf(0.1, L / float(dd["speed"])) * float(dash_feel()["time"])

func on_dash(use_ex: bool) -> bool:
	if ult.airborne():
		return true         # Kitefall's flight is its own move (content/dash_flow/mage.json); its crouch combines
	if use_ex and (h.dashes < 1.0 or wire.size() > 0 or run_t > 0.0):
		# no charge left: the long air dash / extra dash, her base dash's own look (a tumble, a teal streak)
		if not wire.is_empty() or run_t > 0.0 or not spend_dash(true):
			return true
		var a := h.position + Vector3(0, 0.9, 0)
		var ex_dist := float(h.cdat.get("ex_dist", 5.0))
		travel(ex_dist, float(h.cdat.get("ex_time", 0.2)), {"invuln": 0.1, "phase": 1.0})
		play("mage_dash_ex")
		fx().arc(a, a + Vector3(h.roll_dir.x, 0, h.roll_dir.y) * ex_dist, TEAL, PINK, 0.45, 0.3)
		last_dash_kind = "ex"
		return true
	if not wire.is_empty() or run_t > 0.0:
		return true
	if KitStatus.grounded(h) or h.root_t > 0.0:
		h._ab_feedback("dash", "deny")
		return true
	if not spend_dash(false):          # the cooldown starts on the press
		return true
	wire = {"t": 0.0, "y": h.pos.y, "air": not h.grounded, "boost": reset_dash_boost}
	reset_dash_boost = false
	play("mage_dash")
	# a bolt slams down onto her: the charging tell
	fx().arc(h.position + Vector3(0, 8.0, 0), h.position + Vector3(0, 0.3, 0), col_of(dash_def()), PINK, 0.8, 0.22)
	m.sfx("vv_surge_charge", h.pos, -3.0)
	return true

## A Boki merge ends the Wirerun's charge (refunded: nothing ran), the Storm Rod's hold, a Skycall
## still waiting for its flick and a Kitefall in the air (she drops where she took off), with nothing released.
func _drop_holds() -> void:
	_end_wire(true)
	ult.drop()
	rmb_down = false
	rmb_t = 0.0
	if rod != null: rod.visible = false
	for s in strikes.duplicate():
		if String(s["phase"]) == "flick": strikes.erase(s)

func _end_wire(refund: bool) -> void:
	if wire.is_empty(): return
	if refund: h.dashes = minf(h.max_dashes(), h.dashes + 1.0)
	wire = {}
	AimKit.hide(h, "dash")
	AimKit.hide(h, "dash_end")

## A random offset `across` m to each side and `low` to `high` m up (cosmetic: the effects' own dice).
func _jitter(across: float, low: float, high: float) -> Vector3:
	var r := fx().rng
	return Vector3(r.randf_range(-across, across), r.randf_range(low, high), r.randf_range(-across, across))

## The drift you carry: your ground speed right now (it bleeds off while you hold).
func _drift() -> Vector2:
	return Vector2(h.vel.x, h.vel.z) * float(dash_def().get("drift_k", 1.0))

func _tick_wire(dt: float) -> void:
	var dd := dash_def()
	wire["t"] = float(wire["t"]) + dt
	var t := float(wire["t"])
	if h.downed or h.stun_t > 0.0 or h.root_t > 0.0 or KitStatus.grounded(h):
		_end_wire(false)                # the charge was spent on the press: cut, it's gone
		return
	# no control of your own while you hold it: the keys do nothing, momentum drifts you, height holds
	h.inp["move"] = Vector2.ZERO
	h.inp["jump"] = false
	h.knock_t = maxf(h.knock_t, dt * 1.5)
	if bool(wire["air"]):
		h.vel.y = 0.0
		h.pos.y = float(wire["y"])
	var d := h.aim_dir()
	var L := wire_len(t)
	var k := clampf(t / wire_hold(), 0.0, 1.0)
	var dr := _drift()
	var end := h.pos + Vector3(d.x * L, 0, d.y * L) + Vector3(dr.x, 0, dr.y) * run_time(L)
	wire["end"] = end
	wire["len"] = L
	var full_len := float(dd["dist"][1]) * wire_reach()
	var lane := {"len": full_len, "width": 0.35, "rails": true, "chevrons": 5, "fill": L / full_len, "col": col_of(dd)}
	AimKit.lane(h, "dash", lane)
	var ring := {"at": end, "r": float(dd["end_r"]), "ticks": true, "star": true, "col": col_of(dd), "col2": PINK}
	ring["all"] = true
	ring["hot"] = k * 0.6
	AimKit.circle(h, "dash_end", ring)
	AimKit.charge(h, k, {"col": col_of(dd), "col2": PINK})
	if fx().rng.randf() < 0.35:
		fx().arc(h.position + _jitter(0.4, 0.2, 1.4), h.position + _jitter(0.5, 0.2, 1.6), TEAL, PINK, 0.18, 0.08)
	var auto_t := float(dd.get("auto", float(dd["hold"]) + 0.3)) * wire_hold() / float(dd["hold"])
	if not held("dash") or t >= auto_t:
		_end_wire(false)
		_run(L, d, dr)

func _run(L: float, d: Vector2, drift := Vector2.ZERO) -> void:
	var dd := dash_def()
	var time := run_time(L)
	var a := h.position + Vector3(0, 0.9, 0)
	travel(L, time / float(dash_feel()["time"]), {"invuln": time + 0.05, "phase": 1.0, "dir": d})
	# momentum carries: the streak adds the drift you had
	var v := d * (L / time) + drift
	h.roll_dir = v.normalized()
	h.roll_speed = v.length()
	h.phase_t = maxf(h.phase_t, time + 0.05)
	run_t = time
	last_dash_kind = "wire"
	play("mage_dash_go")
	var dmg := float(dd["dmg"]) * run_rank_k()
	h.dash_pass = {"hit": {}, "w": float(dd["width"]) + 0.6, "kx": func(f: Ent): _wire_hit(f, dmg)}
	var b := a + Vector3(v.x, 0, v.y) * time
	fx().arc(a, b, TEAL, PINK, 1.1, time + 0.25)
	fx().arc(a + Vector3(0, 0.3, 0), b + Vector3(0, 0.2, 0), PINK, PINK.lightened(0.5), 0.5, time + 0.15)
	net_bolt(a, b, col_of(dd))
	m.sfx("vv_surge_go", h.pos, -1.0)
	if h.model: h.model.visible = false
	m.later(time, _arrive)

## The streak itself: the body is hidden behind her own pink-teal after-images (_tick_echo); orbs crossed burst.
func _tick_run(dt: float) -> void:
	run_t -= dt
	if h.model:
		h.model.visible = false
	for mt in motes.duplicate():
		if _mote_reached(mt):
			_burst_mote(mt)
	if run_t <= 0.0 and h.model:
		h.model.visible = true

func _arrive() -> void:
	if not is_instance_valid(h): return
	run_t = 0.0
	if h.model: h.model.visible = true
	m.fx.dust(h.pos, 5)           # a quiet arrival: no ring or burst on a dash, the hits are on the way
	m.sfx("mage_bubble_pop", h.pos, -5.0)     # she snaps back into her body with a pop of her gum
	if ult.phase() != MageUlt.CROUCH:
		play("mage_dash_land")      # (a run out of Kitefall's crouch lands in the crouch: it plays that instead)

func _wire_hit(f: Ent, dmg: float) -> void:
	if not is_instance_valid(f) or f.dead: return
	var was_live := live(f)
	if was_live: dmg *= float(dash_def()["full_mult"])     # through a fully charged foe: double
	f.hurt(dmg * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge"]})
	m.fx.burst(f.pos + Vector3(0, 0.9, 0), TEAL, 10, 3.5, 0.3)
	if was_live and is_instance_valid(f) and not f.dead:
		_blowout(f)

func _blowout(f: Ent) -> void:
	var rd := res_def()
	var dmg := (float(rd["blow_dmg"]) + float(rd["blow_pct"]) * f.max_hp) * power("dash")
	clear_sparks(f)
	blowouts += 1
	f.hurt(dmg, h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "blowout"], "payoff": true, "crit": true})
	grant_reset()                             # the dash comes straight back: the only reset
	h.dash_buf = 0.0
	fx().arc(f.position + Vector3(0, 6.0, 0), f.position + Vector3(0, 0.1, 0), TEAL, PINK, 1.0, 0.3)
	payoff_fx(f.pos, "BLOWOUT", PINK, "", h.dir_to(f), f)
	m.sfx("hero_blowout", f.pos, 0.0)        # its own voice (tools/gen_hero_sfx.py)
	# the refund tell on her: copper coil columns and a starburst (our own look)
	var me := ground(h.pos)
	for i in 3:
		var a := TAU * i / 3.0
		fx().pillar(me + Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), COPPER, PINK, 3.2, 0.22, 1.2, false)
	DashReset.cue(h)

# ------------------------------------------------------------------ RMB: Storm Rod
func rmb_charge_full() -> float:
	return float(rmb_def()["hold"])

func rmb_auto_t() -> float:
	return float(rmb_def().get("auto", float(rmb_def()["hold"]) + 0.2))

func rmb_hold_tick(t: float) -> void:
	if rod == null or not is_instance_valid(rod) or not rod.visible:
		_summon_rod()
	var k := clampf(t / float(rmb_def()["hold"]), 0.0, 1.0)
	if k >= 1.0 and not rod_full:
		rod_full = true
		# full: her whole body flashes white for a beat
		m.fx.flash(h.position + Vector3(0, 1.0, 0), Color.WHITE, 1.6, 0.1)
		m.fx.flash(h.position + Vector3(0, 1.6, 0), PINK, 0.9, 0.08)
		AimKit.flare(h, {"col2": PINK})
		m.sfx("vv_rod_full", h.pos, -3.0)

func _summon_rod() -> void:
	rod_full = false
	if rod == null or not is_instance_valid(rod):
		rod = _build_rod()
	rod.visible = true
	play("mage_rmb_hold")
	_tick_rod()
	# it arrives in her hand: a flash and a crackle off the tip
	var tip := rod.global_position - rod.global_basis.z * 0.75
	m.fx.flash(_rod_hand(), PINK, 1.0, 0.08)
	fx().crackle(tip, TEAL, PINK, 0.8, 5, 0.16)
	fx().star(tip, TEAL, PINK, 1.0, 0.14)
	m.sfx("vv_rod_summon", h.pos, -3.0)

func shows_charge_ball() -> bool:
	return false                   # the summoned rod is her charge tell

## The Storm Rod: a 1.3 m copper shaft along -Z (the tip) with a dark grip at +0.25 where the hand
## holds it, three teal windings and a teal crystal tip with a pink heart.
func _build_rod() -> Node3D:
	var n := own_node()
	var along := Vector3(PI / 2, 0, 0)
	var teal := solid_mat(TEAL)
	Models.part(n, Models.cyl(0.045, 0.045, 1.3, 10), Models.shiny(COPPER, 0.8), Vector3.ZERO, Vector3.ONE, along)
	var grip := Models.toon(Color("2a2233"))
	Models.part(n, Models.cyl(0.058, 0.058, 0.24, 10), grip, Vector3(0, 0, 0.25), Vector3.ONE, along)
	for i in 3:
		Models.part(n, Models.cyl(0.066, 0.066, 0.04, 10), teal, Vector3(0, 0, -0.1 - 0.17 * i), Vector3.ONE, along)
	Models.part(n, Models.crystal(0.09, 0.42, 4), teal, Vector3(0, 0, -0.68), Vector3.ONE, -along)
	Models.part(n, Models.sphere(0.06, 8), solid_mat(PINK), Vector3(0, 0, -0.72))
	for ch in n.get_children():
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## Her right hand in the world (the rig's), or where it would be by her shoulder.
func _rod_hand() -> Vector3:
	if h.anim != null and h.anim.hand_r != null:
		return h.anim.hand_r.global_position
	var d := h.aim_dir()
	return h.position + Vector3(0, 1.4, 0) + Vector3(d.y, 0, -d.x) * 0.3

## While held: the rod upright in her raised right hand, crackling; the fixed double-rail lane to full range.
func _tick_rod() -> void:
	var cd_ := rmb_def()["coil"] as Dictionary
	var d := h.aim_dir()
	var k := clampf(rmb_t / float(rmb_def()["hold"]), 0.0, 1.0)
	if rod != null and is_instance_valid(rod) and rod.visible:
		var out := Vector3(d.y, 0, -d.x) * 0.45          # leaned out past her right shoulder: reads from above
		var up := (Vector3(d.x * 0.3, 1.0, d.y * 0.3) + out).normalized()
		rod.global_position = _rod_hand() + up * 0.25
		rod.look_at(rod.global_position + up, Vector3(d.x, 0, d.y))
		if fx().rng.randf() < 0.35:
			var tip := rod.global_position + up * 0.75
			fx().arc(tip, tip + _jitter(0.35, -0.6, 0.2), TEAL, PINK, 0.22, 0.08)
	var lane := {"len": float(cd_["range"]), "width": 0.3, "rails": true, "chevrons": 4, "k": k}
	lane["col"] = col_of(rmb_def())
	lane["col_full"] = PINK
	AimKit.lane(h, "rmb", lane)
	AimKit.charge(h, k, {"col": col_of(rmb_def()), "col2": PINK, "flare": false})

func fire_rmb(c: Dictionary) -> void:
	AimKit.hide(h, "rmb")
	if rod != null and is_instance_valid(rod):
		rod.visible = false
	var sd := rmb_def()
	if not spend_rmb():
		return
	var held_t := float(c["t"])
	var min_t := float(sd["min_t"])
	var k := clampf((held_t - min_t) / (float(sd["hold"]) - min_t), 0.0, 1.0)
	last_variant = "hold" if k > 0.5 else "tap"
	play("mage_rmb")
	var wait := maxf(0.0, min_t - held_t)
	if wait > 0.0:
		m.later(wait, func(): if is_instance_valid(h) and not h.downed: _coil(k))
	else:
		_coil(k)

## Rank 3 of the Storm Rod: its throw hits harder (rmb.rank3_mult).
func rod_rank_k() -> float:
	return float(rmb_def()["rank3_mult"]) if rank("sec") >= 3 else 1.0

## Rank 3 of Wirerun: the run's own hit hits harder; the Blowout is the passive's and does not grow (dash.rank3_mult).
func run_rank_k() -> float:
	return float(dash_def()["rank3_mult"]) if rank("dash") >= 3 else 1.0

func _coil(k: float) -> void:
	var cd_ := rmb_def()["coil"] as Dictionary
	var dir := h.aim_dir()
	var dmg := lerpf(float(cd_["dmg"][0]), float(cd_["dmg"][1]), k)
	var rng := float(cd_["range"])                       # a fixed lane: the charge never changes the range
	var push := lerpf(float(cd_["push"][0]), float(cd_["push"][1]), k)
	last_push = push
	dmg *= rod_rank_k()
	var delivery := {"type": "projectile", "speed": float(cd_["speed"]), "range": rng, "size": 0.22}
	var effects := [{"type": "damage", "amount": dmg}, {"type": "push", "strength": push, "from": "caster"}]
	var stg := stage("rmb", {"delivery": delivery, "effects": effects})
	var done := {"hit": false}
	var shots: Array = m.get("shots")
	var n0 := shots.size()
	run(stg, cx("rmb", "coilshot", aim(), {"on_foe": func(f: Ent, _c: Dictionary):
		if not done["hit"]:
			done["hit"] = true
			_coil_hit(f, dir, k)}))
	var a := h.position + Vector3(dir.x * 0.6, 1.5, dir.y * 0.6)
	if shots.size() > n0 and shots[-1]["by"] == h:
		fx().ride(shots[-1], "bolt", TEAL, PINK, 3.2, 0.7, func(at: Vector3, _v: Vector2): _rod_end(at))
	else:
		fx().arc(a, a + Vector3(dir.x, 0, dir.y) * rng, TEAL, PINK, 0.7, 0.2)
	m.fx.flash(a, PINK, 0.9, 0.08)
	m.sfx("vv_rod_throw", h.pos, -1.0, 1.0 + 0.2 * (1.0 - k))

func _rod_end(at: Vector3) -> void:
	fx().star(at, TEAL, PINK, 1.0, 0.16)
	m.fx.burst(at, PINK, 14, 4.0, 0.35, 2.0, 1.4)

func _coil_hit(f: Ent, dir: Vector2, k: float) -> void:
	if not is_instance_valid(f) or f.dead:
		return
	var cd_ := rmb_def()["coil"] as Dictionary
	add_spark(f)
	m.sfx("mage_rod_hit", f.pos, -2.0)
	# the pink blast, a teal crackle and a shock ring round them
	m.fx.flash(f.position + Vector3(0, 1.0, 0), PINK, 1.6, 0.12)
	m.fx.burst(f.position + Vector3(0, 1.0, 0), PINK, 18, 4.5, 0.45, 1.0, 1.8)
	fx().crackle(f.position + Vector3(0, 1.0, 0), TEAL, PINK, 1.0, 5, 0.18)
	fx().ring(ground(f.pos), 2.2, TEAL, PINK, 0.35)
	# thrown into a wall or another foe: stunned (so is the one it hits)
	var reach := 1.6 + 1.4 * k
	var other: Ent = null
	for o in foes_in(f.pos + Vector3(dir.x, 0, dir.y) * (f.r + reach * 0.6), reach * 0.6):
		if o != f:
			other = o
			break
	if other != null or terrain_behind(f, dir, reach):
		slams += 1
		var stn := float(cd_["stun"])
		var slam := {"src": "abil", "ab": "utility", "tags": ["utility", "slam"], "stun": stn, "dr": true}
		f.hurt(0.1, h, slam)
		m.fx.word(f.pos + Vector3(0, 2.2, 0) + fx().screen_up() * 1.0, "SLAMMED", PINK, false)   # over STUNNED
		fx().ring(ground(f.pos), 1.6, PINK, COPPER, 0.25)
		m.sfx("ab_wall", f.pos, -2.0, 1.3)
		if other != null:
			other.hurt(0.1, h, slam.duplicate(true))
			add_spark(other)
	# every foe hit leaves a charge orb at the impact (dummies and monsters too)
	var at := ground(f.pos)
	m.later(float(cd_["mote_t"]), func(): _drop_mote(at))

# ------------------------------------------------------------------ charge orbs
func _drop_mote(at: Vector3) -> void:
	if not is_instance_valid(h) or h.downed:
		return
	var cd_ := rmb_def()["coil"] as Dictionary
	var n: Node3D = null
	for p in mote_pool:
		if is_instance_valid(p) and not (p as Node3D).visible:
			n = p
			break
	if n == null:
		n = _build_mote()
	n.visible = true
	n.global_position = at + Vector3(0, 0.55, 0)
	var mote := {"pos": at, "t": float(cd_["mote_life"]), "node": n, "owner": h}
	mote["arc"] = 0.0
	motes.append(mote)
	fx().ring(at, float(cd_["mote_r"]) + 0.3, PINK, TEAL, 0.3)
	m.sfx("vv_orb", at, -5.0)
	net_ring(at, 1.0, PINK)

## A charge orb: a pink core in a teal shell wound with two teal bands (it spins), its own light; short
## arcs crackle off it in _tick_motes. Solid colours, so it reads pink and teal, not a white glow.
func _build_mote() -> Node3D:
	var n := own_node()
	var core := Models.part(n, Models.sphere(0.24, 12), solid_mat(PINK))
	core.sorting_offset = 1.0              # drawn after the shell: the pink heart shows through
	Models.part(n, Models.sphere(0.36, 12), solid_mat(Color(TEAL, 0.22)))
	for i in 2:
		var band := TorusMesh.new()
		band.inner_radius = 0.33
		band.outer_radius = 0.39
		Models.part(n, band, solid_mat(TEAL), Vector3.ZERO, Vector3.ONE, Vector3(0.9 * (i * 2 - 1), 0, 0.5))
	for ch in n.get_children():
		(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lt := OmniLight3D.new()
	lt.light_color = PINK
	lt.omni_range = 2.4
	lt.light_energy = 1.2
	n.add_child(lt)
	mote_pool.append(n)
	return n

## Two or three short arcs jump off the orb's shell every ~0.12 s.
func _crackle_mote(mt: Dictionary, dt: float) -> void:
	mt["arc"] = float(mt.get("arc", 0.0)) - dt
	if float(mt["arc"]) > 0.0:
		return
	mt["arc"] = 0.12
	var c: Vector3 = (mt["node"] as Node3D).global_position
	for i in 2 + fx().rng.randi() % 2:
		var out := _jitter(1.0, -0.6, 0.8).normalized()
		fx().arc(c + out * 0.3, c + out * 0.85 + _jitter(0.15, -0.1, 0.1), TEAL, PINK, 0.28, 0.1)

func _tick_motes(dt: float) -> void:
	for mt in motes.duplicate():
		var n: Node3D = mt["node"]
		if mt.has("fly"):
			_fly_mote(mt, dt)
		else:
			mt["t"] = float(mt["t"]) - dt
			if run_t <= 0.0 and not h.downed and _mote_reached(mt):   # walking over a resting orb picks it up
				_grab_mote(mt)
				continue
		if is_instance_valid(n):
			var mp: Vector3 = mt["pos"]
			n.global_position = mp + Vector3(0, 0.55 + 0.12 * sin(m.time * 5.0), 0)
			n.rotation.y += dt * 4.0
			_crackle_mote(mt, dt)
		if float(mt["t"]) <= 0.0:
			_free_mote(mt, true)

## Her body is over the orb (flat distance, the orb's pickup radius plus her own).
func _mote_reached(mt: Dictionary) -> bool:
	var mp: Vector3 = mt["pos"]
	return Vector2(h.pos.x - mp.x, h.pos.z - mp.z).length() < float(rmb_def()["coil"]["mote_r"]) + h.r

## A flung orb glides to where it lands; one pulled to her ends in her hands (see _grab_mote).
func _fly_mote(mt: Dictionary, dt: float) -> void:
	var fly: Dictionary = mt["fly"]
	var dur := float(e_def()["fling_t"])
	fly["t"] = float(fly["t"]) + dt
	var u := clampf(float(fly["t"]) / dur, 0.0, 1.0)
	var to: Vector3 = fly["to"]
	if bool(fly["home"]):
		to = ground(h.pos)
	mt["pos"] = (fly["from"] as Vector3).lerp(to, 1.0 - (1.0 - u) * (1.0 - u))
	if u >= 1.0:
		mt.erase("fly")
		if bool(fly["home"]):
			_grab_mote(mt)

## An orb in her hands (Skycall pulled it in) or under her Wirerun: the dash is back at once, with the
## usual reset cue (the chime and the Shift icon) and a flash on her. It adds Static to nobody.
func _grab_mote(mt: Dictionary) -> void:
	orb_bursts += 1
	var was_spent := h.dashes < h.max_dashes()
	h.dashes = h.max_dashes()
	h.dash_buf = 0.0
	if was_spent:
		grant_reset()
		m.fx.flash(h.position + Vector3(0, 1.0, 0), PINK, 2.4, 0.16)
		m.fx.flash(h.position + Vector3(0, 1.6, 0), TEAL, 0.9, 0.08)
		DashReset.cue(h, "orb")
	_free_mote(mt, false)

## Wirerun through an orb picks it up like a hand does.
func _burst_mote(mt: Dictionary) -> void:
	m.sfx("vv_orb", mt["pos"], -1.0, 1.5)
	_grab_mote(mt)

func _free_mote(mt: Dictionary, fizzle: bool) -> void:
	var n = mt.get("node")
	if n != null and is_instance_valid(n):
		(n as Node3D).visible = false
		if fizzle:
			m.fx.burst((n as Node3D).global_position, PINK, 6, 1.5, 0.3, 0.0, 0.7)
	motes.erase(mt)

# ------------------------------------------------------------------ E: Skycall (mage_sky.gd)
func cast_e() -> bool:
	return sky.cast()

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var aimp := tgt.pos + Vector3(0, 0.9, 0)
	if not wire.is_empty() or rmb_down or ult.busy():
		h.inp["aim"] = aimp
		return
	if HeroUlt.ready(self) and tgt is Hunter and los and dist < float(x_def()["range"]) and randf() < 0.35:
		h.inp["aim"] = aimp
		if HunterKeys.ult_pressed(h):
			return
	if float(cd["e"]) <= 0.0 and int(h.slot_lv["kin"]) > 0 and los and dist < 10.0 and randf() < 0.3:
		h.inp["aim"] = aimp
		h.inp["sig"] = true
		return
	if live(tgt) and h.dashes >= 1.0 and dist < 11.0 and los:
		h.inp["aim"] = aimp
		h.inp["dash"] = true
		bot_hold["dash"] = clampf((dist + 1.5 - 5.0) / 3.5, 0.05, 1.0) * float(dash_def()["hold"]) + 0.05
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 12.5 and randf() < 0.4:
		h.inp["aim"] = aimp
		h.inp["sec"] = true
		bot_hold["rmb"] = (0.6 + randf() * 0.5) if dist > 5.0 else 0.0
