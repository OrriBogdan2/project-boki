class_name TenderKit
extends ArchKit
## Pip, the Tender (a small support on medium stats). docs/heroes/tender.md. Her moments are starlight from her
## lantern (content/vfx/tender.json, HeroVfx); the bodies (the comet, the burr, the Hearthlight disc, the tether)
## are pooled in CareLook and UltLook; the moves are KMovesCare "mm_" entries.
## Passive Carrier: run into a downed teammate to carry them. LMB Ember Cast: embers pushed from
## alternating hands Kindle foes.
## RMB Burrseed sticks, then roots. Shift Relay Step. E Hearthlight heals; press again to toss it.
## X Hearth Call (level 6): a 5 s healing tether to a teammate; a downed one is pulled home and stood up.
## R is the Boki Merge.

const THRUST_T := 0.08         # s into mm_shot_r / _l when the arm is straight out (the hand flashes then)
const PUFF_N := 4              # dust grains in the tiny puff at a ground hop's take-off and landing
const BLOOM_DB := -8.0         # dB: the Hearthlight's closing chime sits well under the fight

var kind := {}                 # target instance id -> {t: Ent, n: int, left: float}
var burrs: Array = []          # seeds stuck to foes: {t: Ent, left, total: float, id: int}
var burr_n := 0
# the light: {pos, mode: self|flying|latched|ground, to, who, left, tick, boost, node, revived}
var hearth := {}
var emp_until := 0.0           # the ember in flight left an idle gun (long range, double refund)
var lock_t := 0.0              # can't pick anyone up (after dropping them)
var pick_blocked := 0.0
var carry_t := 0.0
var safe_t := 0.0
var setdown_was := false        # the set-down key (crouch, never F: F is the Boki system's) was down last tick
const SETDOWN := "crouch"      # the one place to change the set-down key (a Hunter.inp key)
var look: CareLook             # pooled visuals (made on first use)
var shot_seen := 0             # the hunter's shot counter at the last ember we dressed
var seed_aim := false          # the Burrseed wind-up is running (item 118; a merge start drops it)
var seed_wind := 0.0           # s of it left
var glide := {}                # the air dash's long glide: {t, top (m/s)} (a dash: dropped on merge)
var stats := {"embers": 0, "emp": 0, "swirls": 0, "flares": 0, "calls": 0, "rescues": 0, "broken": 0}   # tests
var hearth_call := {}          # Hearth Call running: {who: Hunter, left, tick, fx} (a channel: dropped on merge)
var ult_look: UltLook          # the tether (pooled, made on first use)

func _setup() -> void:
	res = 0.0

func lk() -> CareLook:
	if look == null:
		look = CareLook.new(m, h)
	return look

## A move that waits for the one playing to finish (passive procs never cut an ability's move).
func play_soft(move: String) -> void:
	if anim_id == "" or m.time - anim_at >= KMovesCare.length(anim_id):
		play(move)

# ------------------------------------------------------------------ Kindle
func kindle_on(t: Ent) -> int:
	if t == null or not is_instance_valid(t):
		return 0
	var e: Dictionary = kind.get(t.get_instance_id(), {})
	return int(e.get("n", 0)) if float(e.get("left", 0.0)) > 0.0 else 0

func add_kindle(t: Ent, n := 1) -> void:
	if t == null or not is_instance_valid(t) or t.dead or t.team == h.team:
		return
	var key := t.get_instance_id()
	var e: Dictionary = kind.get(key, {"t": t, "n": 0, "left": 0.0})
	var had := int(e["n"]) if float(e["left"]) > 0.0 else 0
	e["n"] = mini(int(res_def().get("max", 5)), had + n)
	e["left"] = float(res_def().get("dur", 4.0))
	e["t"] = t
	kind[key] = e
	if int(e["n"]) >= int(res_def().get("max", 5)) and had < int(res_def().get("max", 5)):
		m.fx.word(t.pos + Vector3(0, 2.5, 0), "KINDLED", res_col(), true)
		vfx("kindled", t.pos)
		m.sfx("tend_kindled", t.pos, -4.0, 1.0)
		play_soft("mm_kindled")
		ComboMark.payoff(m, h, t)        # the Kindle payoff: full stacks, every shot now hits harder

## The Kindle on `t`, for the ComboMark tag: a pip per stack; the ring is the Kindle left.
func combo_read(t: Ent) -> Dictionary:
	var n := kindle_on(t)
	if n == 0:
		return {}
	return {"icon": "burst", "n": n, "max": int(res_def().get("max", 5)),
			"left": float(kind[t.get_instance_id()]["left"]), "total": float(res_def().get("dur", 4.0))}

func best_kindle() -> int:
	var b := 0
	for k in kind:
		b = maxi(b, kindle_on((kind[k] as Dictionary)["t"]))
	return b

func res_frac() -> float: return float(best_kindle()) / float(res_def().get("max", 5))
func res_text() -> String: return "%d/%d" % [best_kindle(), int(res_def().get("max", 5))]
func full_ready() -> bool: return false

func outgoing(t: Ent, dmg: float, o: Dictionary) -> float:
	if String(o.get("src", "")) == "shot":
		return dmg + float(res_def().get("per_stack", 1.0)) * float(kindle_on(t))
	return dmg

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var src := String(o.get("src", ""))
	if src == "shot":
		var had := kindle_on(t)
		if had > 0:
			var emp: bool = m.time < emp_until
			wind_back_hearth(float(res_def().get("emp_refund" if emp else "refund", 0.2)))
		add_kindle(t, 1)
	elif src == "abil" and String(o.get("ab", "")) == "utility" and o.get("kindle", false):
		add_kindle(t, 1)

func wind_back_hearth(s: float) -> void:
	cd["e"] = maxf(0.0, float(cd["e"]) - s)

# ------------------------------------------------------------------ tick
func _tick(dt: float) -> void:
	lock_t = maxf(0.0, lock_t - dt)
	# Kindle fades
	for key in kind.keys():
		var e: Dictionary = kind[key]
		e["left"] = float(e["left"]) - dt
		if float(e["left"]) <= 0.0 or not is_instance_valid(e["t"]) or (e["t"] as Ent).dead:
			kind.erase(key)
	# an idle gun: the next ember flies further (and winds Hearthlight back twice as much)
	if h.idle_fire >= 1.0 and not h.downed:
		h.shot_range_k = 1.4
		emp_until = m.time + 0.9
	_tick_seed(dt)
	_tick_burrs(dt)
	_tick_hearth(dt)
	_tick_carry(dt)
	_tick_call(dt)
	_call_preview()
	_tick_look(dt)
	if h.ctrl == "bot":
		_bot_idle(dt)

## Every ember she casts: the comet look leaving the casting hand (right, then left) with its starlit trail,
## the punch-push move, and at the thrust a little flare of starlight at that hand.
func _tick_look(dt: float) -> void:
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		var s := lk().last_shot()
		if not s.is_empty() and String((s["x"] as Dictionary).get("src", "")) != "abil":
			_dress_ember(s)
	# Kindle reads on the foe: an ember-violet glow at the feet that grows per stack
	for key in kind:
		var e: Dictionary = kind[key]
		var n := kindle_on(e["t"])
		if n > 0:
			var t: Ent = e["t"]
			lk().keep(
					"kin%d" % key, "kindle", t.pos,
					{
						"r": 0.55 + 0.12 * n, "col": Color("9a6aff").lerp(Color("ffb347"), float(n) / 5.0),
						"a": 0.35 + 0.13 * n, "fill": 0.8, "pattern": 0.0})
	_tick_dash_look(dt)
	lk().tick(dt)
	if ult_look != null:
		ult_look.tick(dt)

func _dress_ember(s: Dictionary) -> void:
	var emp: bool = float(s["life0"]) * (s["vel"] as Vector2).length() > float(h.wpn["range"]) * 1.2
	var right := h.shot_n % 2 == 1
	var d2 := h.aim_dir()
	# the ember leaves from the casting hand's side at hand height (the hit band is the same)
	var side := Vector2(-d2.y, d2.x) * (0.18 if right else -0.18)
	var from := Vector3(h.pos.x + d2.x * 0.5 + side.x, h.pos.y + 0.72, h.pos.z + d2.y * 0.5 + side.y)
	s["pos"] = from
	s["start"] = from
	lk().skin(s, "ember")
	HeroVfx.of(m).trail(h, "cast_trail", s["node"])
	stats["embers"] += 1
	stats["swirls"] += 1
	if emp:
		stats["emp"] += 1
		play("mm_shot_emp")
		m.sfx("tend_ember_emp", h.pos, -3.0, 1.0)
	elif not seed_aim:
		play("mm_shot_r" if right else "mm_shot_l")
	var big := 1.4 if emp else 1.0
	m.later(THRUST_T, func():
		if not is_instance_valid(h) or look == null:
			return
		vfx("cast", CareUtil.hand_at(h, right), d2, {"k": big - 1.0}))

## Her dashes leave a faint trail of stars (not the shared after-image), and the air dash glides.
func _tick_dash_look(dt: float) -> void:
	_tick_glide(dt)
	if h.roll_t > 0.0 and h.move_kind == "dash":
		HeroVfx.of(m).hold(h, "dash_trail")

## Her own dash look (motes, puffs and the moves): no shared after-image pill, burst or ring.
func own_dash_trail() -> bool: return true

## The kit's moves are the whole dash pose (mm_skip, mm_float): no shared roll under them.
func dodge_anim() -> String: return "kit"

## A Boki merge sets a carried teammate down (unbroken: no stun), ends the Burrseed aim (no throw),
## and keeps the key from picking anyone up meanwhile.
func _drop_holds() -> void:
	glide = {}
	if not hearth_call.is_empty():
		_call_end(false)
	if seed_aim or rmb_down:
		rmb_down = false
		_seed_cancel()
	if not carrying().is_empty():
		drop_all(false)
	carry_t = 0.0
	setdown_was = false
	lock_t = maxf(lock_t, 0.3)

# ------------------------------------------------------------------ Bearer (carry)
func carrying() -> Array:
	return CareUtil.carried_of(m, h)

func can_pick() -> bool:
	return lock_t <= 0.0 and h.stun_t <= 0.0 and h.root_t <= 0.0 and not busy() and not Hex.active(h)

func _tick_carry(dt: float) -> void:
	var pd: Dictionary = d["passive"]
	var cs := carrying()
	if not cs.is_empty():
		carry_t += dt
		if h.stun_t > 0.0 or h.root_t > 0.0 or Hex.active(h):
			drop_all(true)
			return
		var down := bool(h.inp.get(SETDOWN, false))
		if down and not setdown_was:
			drop_all(false)
		setdown_was = down
		return
	carry_t = 0.0
	setdown_was = bool(h.inp.get(SETDOWN, false))
	if not can_pick():
		return
	for o in CareUtil.mates(m, h, h.pos, float(pd.get("pick_r", 1.1)) + h.r):
		if not o.downed or CareUtil.is_carried(o) or bool(o.get_meta("stomped", false)):
			continue
		if absf(o.pos.y - h.pos.y) > 1.5:
			continue
		if h.ctrl == "bot" and not _foes_near(5.0):
			continue          # a bot only carries when someone is closing in; otherwise it revives on the spot
		if carrying().size() >= int(pd.get("max", 2)):
			break
		pick_up(o)

## Taking damage drops whoever you carry, with the lock.
func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	if dmg > 0.0 and not carrying().is_empty():
		drop_all(true)

func _foes_near(r: float) -> bool:
	for f in m.foes_of(h.team):
		if f is Hunter and h.flat_dist(f) < r:
			return true
	return false

func pick_up(o: Hunter) -> void:
	CareUtil.set_carry(m, o, h.nid)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CARRY", res_col(), false)
	m.sfx("tend_pickup", h.pos, -2.0, 1.0)
	play("mm_pickup")
	if rank("dash") >= 3:
		h.ex_cd = 0.0
	if h.is_local() and m.hud:
		m.hud.toast_small("Carrying %s  ·  %s sets down" % [o.pname, Settings.key_cap(SETDOWN)], res_col())

func drop_all(broken: bool) -> void:
	for o in carrying():
		CareUtil.set_carry(m, o, "")
		m.displace.teleport(o, Vector3(h.pos.x, h.pos.y, h.pos.z) + Vector3(0.9, 0, 0))
		o.vel = Vector3.ZERO
	lock_t = maxf(lock_t, 1.5)          # set down: not picked straight back up
	if broken:
		lock_t = float(d["passive"].get("lock", 4.0))
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "DROPPED", Color("ff8a6a"), false)
		m.sfx("knock", h.pos, -4.0, 1.2)

# ------------------------------------------------------------------ dash: Relay Step
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	# the glide is Elluna's Lunar Air Dash: airborne only. On the ground with the hop spent, Shift is refused
	use_ex = use_ex and not h.grounded
	if not spend_dash(use_ex):
		return true
	var air: Dictionary = dd.get("air", {})
	var dist := float(air["dist"]) if use_ex else float(dd["dist"])
	var tt := float(air["time"]) if use_ex else float(dd["time"])
	travel(dist, tt, {"invuln": float(dd.get("invuln", 0.12)), "dir": dash_dir()})
	# the ground hop goes through the global dash feel (its data is set so the result is the source's 2 bh in
	# 0.2 s); the glide is the source's own measured curve (dash.air), so the feel doesn't touch it
	if use_ex:
		_start_glide(dist, tt)
	play("mm_float" if use_ex else "mm_skip")
	m.sfx("tend_hop", h.pos, -3.0, 1.05 if use_ex else 1.2)
	vfx("hop", null, dash_dir())        # a few stars off her heels
	if h.grounded and not use_ex:
		# a tiny puff of dust where she lands
		m.later(h.roll_t, func():
			if is_instance_valid(h) and h.grounded: m.fx.dust(h.pos, PUFF_N))
	return true

## The air dash is her long glide (dash.air): a quick ramp to a flat burst, then a float out at a share of
## that speed while barely sinking, then down. The peak speed is set so the whole glide covers `dist`.
func _start_glide(dist: float, tt: float) -> void:
	var air: Dictionary = dash_def().get("air", {})
	var ramp := float(air.get("ramp", 0.1))
	var burst := float(air.get("burst", 0.4))
	var out_k := float(air.get("out_k", 0.45))
	var span := ramp * 0.5 + burst + maxf(0.0, tt - ramp - burst) * (1.0 + out_k) * 0.5
	glide = {"t": 0.0, "top": dist / maxf(0.05, span), "time": tt}
	h.roll_t = tt
	h.roll_speed = float(glide["top"]) * 0.5
	h.vel.y = maxf(h.vel.y, 0.0)

func _tick_glide(dt: float) -> void:
	if glide.is_empty():
		return
	var air: Dictionary = dash_def().get("air", {})
	glide["t"] = float(glide["t"]) + dt
	var t := float(glide["t"])
	if h.roll_t <= 0.0 or h.move_kind != "dash" or h.downed or h.stun_t > 0.0:
		glide = {}
		return
	var ramp := float(air.get("ramp", 0.1))
	var burst := float(air.get("burst", 0.4))
	var top := float(glide["top"])
	# air control (owner): the move keys bend the glide's heading at a capped rate (dash.air.steer rad/s)
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	if mv.length() > 0.1:
		var steer := float(air.get("steer", 3.0)) * dt
		h.roll_dir = h.roll_dir.rotated(clampf(h.roll_dir.angle_to(mv.normalized()), -steer, steer))
	var k := clampf((t - ramp - burst) / maxf(0.05, float(glide["time"]) - ramp - burst), 0.0, 1.0)
	h.roll_speed = top * lerpf(0.5, 1.0, clampf(t / ramp, 0.0, 1.0)) * lerpf(1.0, float(air.get("out_k", 0.45)), k)
	# held up while it floats; the last 0.15 s lets her come down
	if float(glide["time"]) - t > 0.15:
		h.vel.y = maxf(h.vel.y, -float(air.get("float_fall", 1.2)))

# ------------------------------------------------------------------ RMB: Burrseed
## Owner item 118: a press starts a fixed wind-up (`windup`) that nothing extends: she slows
## (`wind_move`), a short dotted lane follows the aim and a ring glows round her. The seed then
## goes by itself, along the aim of that moment: you flick it onto the target. Not a hold, not a
## charge; letting go does nothing. A stun, a Hex or going down loses the throw, not the charge.
func rmb_charge_full() -> float: return 0.0

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if seed_aim:
		return
	if not rmb_ready():
		h._ab_feedback("sec", "deny")
		return
	seed_aim = true
	seed_wind = float(rmb_def()["windup"])
	play("mm_seed_aim")
	m.sfx("tend_seed_aim", h.pos, -6.0, 1.0)
	lk().burst("flare", h.pos,
			{"col": Color("9a6aff"), "rim": Color("ffd27a"), "r": 1.4, "dur": seed_wind, "pattern": 3.0})
	_seed_lane()

func _seed_lane() -> void:
	var sd := rmb_def()
	var width := float(sd["seed"]["hit_r"]) * 2.0
	AimKit.dotted(h, "rmb", {"len": float(sd["wind_lane"]), "width": width, "col": Color("e8f6c8")})

## Her share of run speed during the wind-up.
func move_k() -> float:
	return float(rmb_def()["wind_move"]) if seed_aim else 1.0

func _tick_seed(dt: float) -> void:
	if not seed_aim:
		return
	if busy():
		_seed_cancel()
		return
	seed_wind -= dt
	if seed_wind > 0.0:
		_seed_lane()
		HeroVfx.of(m).hold(h, "seed_aim")      # lilac stars gather at the lantern while she winds up
		return
	_seed_cancel()
	_throw_seed()

func _seed_cancel() -> void:
	seed_aim = false
	seed_wind = 0.0
	AimKit.hide(h, "rmb")
	if anim_id == "mm_seed_aim": anim_id = ""

func _throw_seed() -> void:
	if not spend_rmb():
		return
	play("mm_seed")
	var sd: Dictionary = rmb_def()["seed"]
	var dir := h.aim_dir()
	var start := Vector3(h.pos.x + dir.x * 0.6, h.pos.y + 0.95, h.pos.z + dir.y * 0.6)
	var life := AimMode.dist(h, float(sd["range"]), AimMode.MAX) / float(sd["speed"])
	var on_hit := func(_s: Dictionary, _at: Vector3, e: Ent, _why: String):
		if e != null and e.team != h.team and not e.dead:
			_stick(e)
	var extra := {"src": "abil", "ab": "utility", "tracer": 0.0, "kb": 0.0, "kx": on_hit}
	m.spawn_shot(
			h, start, dir * float(sd["speed"]), float(sd["dmg"]) * power("sec"), life, float(sd["hit_r"]) * 0.5,
			col_of(rmb_def()), extra)
	var s := lk().last_shot()
	lk().skin(s, "burr")
	if not s.is_empty():
		HeroVfx.of(m).trail(h, "seed_trail", s["node"])
	vfx("seed_cast", null, dir)          # the cast flare from her lantern
	m.sfx("tend_seed", h.pos, -2.0, 1.0)

## The Burrseed's burst radius: rank 3 doubles it (the source's detonation-radius upgrade).
func burst_radius() -> float:
	var seed_def: Dictionary = rmb_def()["seed"]
	var r3_k := float(seed_def.get("r3_k", 2.0))
	return float(seed_def["burst_r"]) * (r3_k if rank("sec") >= 3 else 1.0)

func _stick(e: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	burr_n += 1
	burrs.append({"t": e, "left": float(sd["delay"]), "total": float(sd["delay"]), "id": burr_n})
	# the area shows at once: a disc the size of the burst under them, and a light column falling
	lk().burst("column", e.pos, {"col": Color("8a5cff"), "r": 1.0, "dur": float(sd["delay"]) + 0.1, "ent": e})
	m.sfx("tend_stick", e.pos, -3.0, 1.0)
	vfx("seed_stick", e.pos)

func _tick_burrs(dt: float) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	for b in burrs.duplicate():
		var tv = b["t"]     # untyped first: a freed foe can't be assigned to a typed var
		var t: Ent = tv if is_instance_valid(tv) else null
		var key := "burr%d" % int(b["id"])
		if t == null or t.dead:
			burrs.erase(b)
			continue
		b["left"] = float(b["left"]) - dt
		var k := 1.0 - float(b["left"]) / maxf(0.01, float(b["total"]))
		# the area rides on the foe (Assumption: it sticks to them), filling toward the root
		lk().keep(
				key, "disc", t.pos,
				{
					"r": burst_radius(), "col": Color("7a4aff"), "rim": Color("c9a0ff"), "fill": 1.2,
					"sweep": k, "pattern": 3.0, "spin": m.time * 0.8, "a": 0.9})
		AimKit.circle(h, key, {"at": t.pos, "r": burst_radius(), "fill": k, "all": true, "col": Color("b98aff")})
		if float(b["left"]) <= 0.0:
			burrs.erase(b)
			lk().drop(key)
			AimKit.hide(h, key)
			_burst(t)

func _burst(t: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	var at := t.pos
	var rr := burst_radius()
	var col := col_of(rmb_def())
	# the flare: a swirl of starlight snaps out over the area, then a root beam holds on each foe
	vfx("seed_burst", at, null, {"r": rr})
	m.sfx("tend_root", at, 0.0, 1.0)
	var root := float(sd["root"]) + (0.3 if rank("sec") >= 3 else 0.0)
	for f in foes_in(at, rr):
		f.hurt(
				float(sd["burst_dmg"]) * power("sec"), h,
				{
					"src": "abil", "ab": "utility", "root": root, "dr": true, "kindle": true,
					"tags": ["utility", "burrseed"]})
		lk().burst("beam_root", f.pos, {"col": Color("9a6aff"), "r": 1.0, "dur": root, "ent": f})
	m.fx.word(at + Vector3(0, 2.2, 0), "ROOTED", col, false)
	stats["flares"] += 1
	play_soft("mm_tug")

# ------------------------------------------------------------------ E: Hearthlight
func cast_e() -> bool:
	var ed := e_def()
	hearth = {
			"pos": h.pos, "mode": "self", "who": null, "left": float(ed["time"]), "tick": 0.0, "boost": 0.0,
			"revived": false, "tossed": false}
	e_t = float(ed["time"])
	play("mm_hearth")
	# the lantern plus over her hand and starlight flaring from the lantern, rising round her
	lk().burst("plus", h.pos + Vector3(0, 1.9, 0), {"r": 0.9, "dur": 0.4})
	vfx("hearth")
	m.sfx("tend_hearth", h.pos, -2.0, 1.0)
	m.sfx("tender_lantern_chime", h.pos, -4.0, 1.0)      # her lantern's star rings as she lifts it
	return true

func e_recastable() -> bool:
	return not hearth.is_empty() and not bool(hearth.get("tossed", false))

## E again: the light is thrown to the cursor (clamped to its reach) almost at once.
func e_recast() -> bool:
	if hearth.is_empty() or hearth.get("tossed", false):
		return true
	var ed := e_def()
	var to := AimMode.point(h, float(ed["reach"]), AimMode.CURSOR, 0.0)
	# carrying someone: a toss aimed at yourself lands on them
	var cs := carrying()
	if not cs.is_empty() and Vector2(to.x - h.pos.x, to.z - h.pos.z).length() < 2.0:
		_latch(cs[0])
	else:
		hearth["mode"] = "flying"
		hearth["to"] = to
		hearth["pos"] = h.pos
	hearth["tossed"] = true
	hearth["boost"] = float(ed.get("boost_t", 1.0))
	play("mm_toss")
	m.sfx("tend_toss", h.pos, -2.0, 1.2)
	h._ab_feedback("k1", "cast")
	return true

func _latch(o: Hunter) -> void:
	hearth["mode"] = "latched"
	hearth["who"] = o
	lk().burst("plus", o.pos + Vector3(0, 1.6, 0), {"r": 0.6, "dur": 0.3})
	m.sfx("tend_land", o.pos, -4.0, 1.2)

func hearth_center() -> Vector3:
	match String(hearth.get("mode", "self")):
		"self": return h.pos
		"latched":
			var w = hearth.get("who")
			return (w as Hunter).pos if is_instance_valid(w) else hearth["pos"]
	return hearth["pos"]

## The ring's radius: on her (or a carried friend) the smaller ring, thrown the wider disc.
func hearth_r() -> float:
	var ed := e_def()
	return float(ed.get("thrown_radius", ed["radius"])) if bool(hearth.get("tossed", false)) else float(ed["radius"])

func _tick_hearth(dt: float) -> void:
	if hearth.is_empty():
		return
	var ed := e_def()
	if String(hearth["mode"]) == "flying":
		var p: Vector3 = hearth["pos"]
		var to: Vector3 = hearth["to"]
		var step := float(ed.get("toss_speed", 45.0)) * dt
		var dv := to - p
		p += dv.normalized() * minf(step, dv.length())
		hearth["pos"] = p
		for o in CareUtil.mates(m, h, p, float(ed.get("latch_r", 1.0)), true):
			_latch(o)
			break
		if String(hearth["mode"]) == "flying" and dv.length() <= step:
			hearth["mode"] = "ground"
			vfx("hearth_land", to, null, {"r": hearth_r()})
			m.sfx("tend_land", to, -3.0, 1.0)
	var c := hearth_center()
	hearth["pos"] = c if String(hearth["mode"]) != "flying" else hearth["pos"]
	var tossed := bool(hearth.get("tossed", false))
	# on her: a soft warm ring with a faint inside; thrown: a filled disc, warm amber in the middle shading
	# to teal, a bright rim, its lantern floating over the middle
	var gk := float(hearth["left"]) / maxf(0.01, float(ed["time"]))
	var look_p := {"r": hearth_r(), "col": Color("ffd27a"), "rim": Color("ffb347"), "fill": 0.45, "pattern": 5.0,
		"a": 0.85 * (0.6 + 0.4 * gk), "spin": m.time * 0.5, "lamp": tossed}
	if tossed:
		look_p.merge({"col": Color("ffd27a"), "rim": Color("3fd8d0"), "fill": 1.8, "a": 1.1 * (0.6 + 0.4 * gk)}, true)
	lk().keep("hearth", "hearth", c, look_p)
	hearth["left"] = float(hearth["left"]) - dt
	e_t = float(hearth["left"])
	hearth["tick"] = float(hearth["tick"]) + dt
	var every := float(ed["every"])
	if float(hearth["tick"]) >= every:
		hearth["tick"] = float(hearth["tick"]) - every
		var per := float(ed["over"]) / (float(ed["time"]) / every)
		_pulse(c, per)
		vfx("hearth_motes", c, null, {"r": hearth_r()})
	hearth["boost"] = maxf(0.0, float(hearth["boost"]) - dt)
	if float(hearth["left"]) <= 0.0:
		_hearth_end(true, "FLARE")

## The extra healing for the second after a throw; rank 3 doubles it (the source's level-4 upgrade).
func throw_boost() -> float:
	return float(e_def().get("boost", 0.5)) * (2.0 if rank("kin") >= 3 else 1.0)

func heal_k() -> float:
	return 1.0 + 0.15 * float(maxi(0, rank("kin") - 1))

func _pulse(c: Vector3, per: float) -> void:
	var ed := e_def()
	var boost := 1.0 + throw_boost() if float(hearth.get("boost", 0.0)) > 0.0 else 1.0
	PipStars.pulse(h)
	for o in m.hunters:
		if o.team != h.team or o.out or o.extracted:
			continue
		if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > hearth_r() + o.r:
			continue
		var amt := per * heal_k() * boost * (float(ed.get("self_k", 0.33)) if o == h else 1.0)
		_mend(o, amt, float(ed.get("wisp_k", 5.0)))

## A heal from her light: CareUtil.heal, and twinkling stars rising off whoever it mends (content/vfx
## "heal_stars").
func _mend(o: Hunter, amt: float, wisp_k := 5.0) -> void:
	CareUtil.heal(m, o, amt, wisp_k)
	vfx("heal_stars", o.pos)

func _hearth_end(flare: bool, word: String) -> void:
	var ed := e_def()
	var c := hearth_center()
	var rr := hearth_r()
	if flare:
		var amt := float(ed["burst"]) * heal_k()
		_bloom(c, rr)
		play_soft("mm_flare")
		PipStars.pulse(h)
		for o in m.hunters:
			if o.team != h.team or o.out or o.extracted:
				continue
			if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > rr + o.r:
				continue
			if o.downed:
				_mend(o, amt, float(ed.get("wisp_k", 5.0)))
			else:
				_mend(o, amt * (float(ed.get("self_k", 0.33)) if o == h else 1.0))
	else:
		m.fx.word(c + Vector3(0, 2.0, 0), word, Color("ff8a6a"), false)
		m.sfx("knock", c, -6.0, 1.4)
	lk().drop("hearth")
	hearth = {}
	e_t = 0.0

## The light's last heal reads as a heal, not a blast: a slow swirl of starlight to its own edge (no wider), stars
## rising off it with the lantern plus over the middle, a soft chime; no ring, burst or shake.
func _bloom(c: Vector3, rr: float) -> void:
	var ed := e_def()
	m.fx.word(c + Vector3(0, 2.4, 0), "HEARTH", col_of(ed), false)
	lk().burst("plus", c + Vector3(0, 1.6, 0), {"r": 0.8, "dur": 0.5})
	vfx("bloom", c, null, {"r": rr})
	m.sfx("tend_flare", c, BLOOM_DB, 1.0)

func _e_end() -> void:
	if not hearth.is_empty():
		_hearth_end(true, "FLARE")

func in_e() -> bool: return not hearth.is_empty()

func teardown() -> void:
	super.teardown()
	hearth = {}
	hearth_call = {}
	burrs.clear()
	if look != null:
		look.teardown()
		look = null
	if ult_look != null:
		ult_look.teardown()
		ult_look = null

# ------------------------------------------------------------------ X: Hearth Call
func ulk() -> UltLook:
	if ult_look == null:
		ult_look = UltLook.new(m, h)
	return ult_look


func ult_running() -> bool:
	return not hearth_call.is_empty()


## X again while it runs does nothing (the source has no early end); the press is swallowed.
func ult_recast() -> bool:
	return true


## The aim telegraph (local only): while Hearth Call is ready and the cursor rests on a teammate in
## reach, the gold reach ring round her, a line onto them and a pick ring under them. X casts on it.
func _call_preview() -> void:
	if not hearth_call.is_empty() or not h.is_local() or not _x_ready():
		return
	var who := call_target()
	if who == null or who == h:
		return
	var xd := x_def()
	AimKit.circle(h, "x", {"self": true, "r": float(xd["range"]), "col": Color("ffd27a"), "dashed": true, "alpha": 1.2})
	AimKit.line(h, "x_line", {"from": h.pos, "to": who.pos, "col": Color("ffb347"), "lw": 0.1, "alpha": 1.8})
	AimKit.circle(h, "x_pick", {"at": who.pos, "r": 0.8, "col": Color("9cf07a"), "ticks": true, "alpha": 1.6})
	# a faint tether already strung from her raised hand onto them: this is who X will reach
	ulk().keep("tether_aim", "tether", h.pos + Vector3(0, 1.3, 0), {"b": who.pos + Vector3(0, 1.0, 0), "a": 0.45})


## X is open (level) and off cooldown, and she is free to cast.
func _x_ready() -> bool:
	return HeroUlt.ready(self) and not busy()


## The teammate under the cursor within reach (standing or downed); with no teammate in the match at
## all, herself (so the key is never dead in solo play).
func call_target() -> Hunter:
	var xd := x_def()
	var aim_p: Vector3 = h.inp.get("aim", h.pos)
	var best: Hunter = null
	var best_d := float(xd["pick_r"])
	var any_mate := false
	for o in CareUtil.mates(m, h):
		any_mate = true
		if h.flat_dist(o) > float(xd["range"]):
			continue
		var dc := Vector2(o.pos.x - aim_p.x, o.pos.z - aim_p.z).length()
		if dc < best_d:
			best_d = dc
			best = o
	if best == null and not any_mate and bool(xd.get("self_when_solo", true)):
		return h
	return best


func cast_ult() -> bool: return HeroUlt.press(self, _start_call)
func has_ult() -> bool: return true


func _start_call() -> bool:
	AimKit.hide(h, "x_line")
	AimKit.hide(h, "x_pick")
	if ult_look != null:
		ult_look.drop("tether_aim")
	var who := call_target()
	if who == null:
		if h.is_local() and m.hud:
			m.hud.toast_small("No teammate there", Color("a2a8bb"))
		return false
	hearth_call = {"who": who, "left": float(x_def()["time"]), "tick": 0.0, "fx": 0.0}
	stats["calls"] += 1
	play("mm_call")
	m.sfx("tend_call", h.pos, -1.0, 1.0)
	lk().burst("plus", who.pos + Vector3(0, 1.3, 0), {"r": 1.1, "dur": 0.45})
	vfx("call")
	vfx("call_land", who.pos)
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "HEARTH CALL", col_of(x_def()), true)
	net_bolt(h.pos + Vector3(0, 1.3, 0), who.pos + Vector3(0, 1.1, 0), Color("ffd27a"))
	return true


func _tick_call(dt: float) -> void:
	if hearth_call.is_empty():
		return
	var xd := x_def()
	var who: Hunter = hearth_call["who"] if is_instance_valid(hearth_call["who"]) else null
	if who == null or who.out or who.extracted:
		_call_end(false)
		return
	if h.downed or h.out or h.stun_t > 0.0 or h.flat_dist(who) > float(xd["range"]) + who.r:
		_call_end(false)
		return
	hearth_call["left"] = float(hearth_call["left"]) - dt
	hearth_call["tick"] = float(hearth_call["tick"]) + dt
	var every := float(xd["every"])
	if float(hearth_call["tick"]) >= every:
		hearth_call["tick"] = float(hearth_call["tick"]) - every
		_call_heal(who, float(xd["heal_ps"]) * every)
	_call_look(who, dt)
	if anim_id == "" or (anim_id != "mm_call_hold" and m.time - anim_at >= KMovesCare.length(anim_id)):
		play("mm_call_hold")
	if float(hearth_call["left"]) <= 0.0:
		_call_end(true)


## A tick of the tether's heal on the teammate (or herself in solo, at self_k). A downed teammate is healed
## too, as the source's channel heals an ally or a Wisp: it tops up what keeps them from bleeding out.
func _call_heal(who: Hunter, amount: float) -> void:
	var amt := amount * LevelGrowth.ap(h)
	PipStars.pulse(h)
	if who == h:
		_mend(h, amt * float(e_def().get("self_k", 0.33)))
	else:
		_mend(who, amt, float(e_def().get("wisp_k", 5.0)))


func _call_look(who: Hunter, dt: float) -> void:
	var xd := x_def()
	var gold := Color("ffd27a")
	AimKit.circle(h, "x", {"self": true, "r": float(xd["range"]), "col": gold, "all": true, "dashed": true})
	AimKit.circle(h, "x_me", {"self": true, "r": 0.7, "col": Color("ffc46a"), "all": true})
	if who != h:
		AimKit.circle(h, "x_pick", {"at": who.pos, "r": 0.7, "col": Color("9cf07a"), "all": true})
		var hand := CareUtil.hand_at(h, false)
		ulk().keep("tether", "tether", hand, {"b": who.pos + Vector3(0, 1.1, 0)})
	hearth_call["fx"] = float(hearth_call["fx"]) - dt
	if float(hearth_call["fx"]) <= 0.0:
		hearth_call["fx"] = 0.22
		var up := who.pos + Vector3(randf_range(-0.4, 0.4), 0.6 + randf() * 0.8, randf_range(-0.4, 0.4))
		lk().burst("plus", up, {"r": 0.28, "dur": 0.5})
		m.sfx("tend_call_hum", h.pos, -12.0, 1.0)


## The end: on time, a downed teammate is pulled to her side and stood up (a rescue), and the bond pays;
## broken early, nothing pays.
func _call_end(done: bool) -> void:
	var who: Hunter = hearth_call["who"] if is_instance_valid(hearth_call.get("who")) else null
	hearth_call = {}
	for id_ in ["x", "x_me", "x_pick", "x_line"]:
		AimKit.hide(h, id_)
	if ult_look != null:
		ult_look.drop("tether")
	if not done or who == null:
		stats["broken"] += 1
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "BROKEN", Color("ff8a6a"), false)
		m.sfx("knock", h.pos, -8.0, 1.5)
		if anim_id == "mm_call_hold":
			anim_id = ""
		return
	var rescue := who != h and who.downed
	if rescue:
		_call_home(who)
	# a support ult lands on a teammate: a completed tether counts as a hit, a rescue as the top event
	KinBond.from_ult(h, "kill" if rescue else "hit", HeroUlt.cast_id(self))
	var at := who.pos if not rescue else h.pos
	# a rescue has its own revive banner, and the bond word lands on her now: no third word there
	if not rescue:
		m.fx.word(at + Vector3(0, 2.7, 0), "MENDED", Color("9cf07a"), true)
	m.sfx("tend_arrive", at, 0.0, 1.0)
	m.sfx("tender_cheer", h.pos, -3.0, 1.0)              # she cheers when her light mends someone
	vfx("mended", at)
	play("mm_call_end")


## Pulls a downed teammate to her side and stands them up (Displace and the "rev" event: an online
## teammate is moved and stood up on their own game).
func _call_home(who: Hunter) -> void:
	stats["rescues"] += 1
	var side := Vector2(cos(h.face), -sin(h.face)) * float(x_def().get("land_r", 0.9))
	var to := Vector3(h.pos.x + side.x, h.pos.y, h.pos.z + side.y)
	lk().burst("plus", who.pos + Vector3(0, 1.2, 0), {"r": 0.8, "dur": 0.3})
	m.displace.teleport(who, to)
	who.vel = Vector3.ZERO
	CareUtil.revive(m, who, h)


# ------------------------------------------------------------------ bots
func _bot_idle(dt: float) -> void:
	# squadmate hurt nearby: light the lantern; carrying under fire: run away from the nearest rival
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and hearth.is_empty() and not busy():
		var need := 0.0
		for o in CareUtil.mates(m, h, h.pos, float(e_def()["radius"]) - 0.6, true):
			need += (o.max_hp - o.hp) if not o.downed else 40.0
		if h.hp < h.max_hp * 0.6:
			need += (h.max_hp - h.hp) * 0.33
		if need > 30.0:
			h.inp["sig"] = true
	var cs := carrying()
	if cs.is_empty():
		safe_t = 0.0
		return
	var worst: Ent = null
	var wd := 1e9
	for f in m.foes_of(h.team):
		if f is Hunter and h.flat_dist(f) < wd:
			wd = h.flat_dist(f)
			worst = f
	if carry_t > 4.0:
		drop_all(false)
		lock_t = 8.0          # a bot carries for a few seconds at most, then revives them
	elif worst != null and wd < 9.0:
		safe_t = 0.0
		var away := -h.dir_to(worst)
		h.inp["move"] = away
		h.inp["fire"] = false
	else:
		safe_t += dt
		if safe_t > 0.3:
			drop_all(false)
			lock_t = 6.0          # now revive them on the spot

func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	_bot_call()
	if tgt == null or not carrying().is_empty():
		return
	# a seed on the nearest rival from mid range
	if (int(h.slot_lv["sec"]) > 0
			and rmb_ready()
			and los
			and dist < 10.0
			and dist > 2.5
			and tgt is Hunter
			and randf() < 0.7):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
	# a hop through a teammate when one is close and we're being pressed
	if dist < 3.5 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true


## A bot calls a downed or badly hurt teammate home when it can.
func _bot_call() -> void:
	if not hearth_call.is_empty() or not _x_ready():
		return
	for o in CareUtil.mates(m, h, h.pos, float(x_def()["range"]) - 1.0):
		if o.downed or o.hp < o.max_hp * 0.35:
			h.inp["aim"] = o.pos + Vector3(0, 0.9, 0)
			HunterKeys.ult_pressed(h)
			return
