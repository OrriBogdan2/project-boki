class_name TenderKit
extends ArchKit
## Moosh Moosh, the Tender (medium support). docs/heroes/tender.md. Looks are pooled in CareLook;
## the moves are KMovesCare "mm_" entries.
## Passive Bearer: run into a downed teammate to carry them. LMB Lantern Crook embers Kindle foes.
## RMB Burrseed sticks, then roots. Shift Relay Step. E Hearthlight heals; press again to toss it.
## X Hearth Call (level 6): a 5 s healing tether to a teammate; a downed one is pulled home and stood up.
## R is the Boki Merge.

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
var last_dash_pass := false    # the last Relay Step went through a teammate (tests)
var look: CareLook             # pooled visuals (made on first use)
var shot_seen := 0             # the hunter's shot counter at the last ember we dressed
var seed_aim := false          # RMB held: the dotted lane and the coiled pose are up (a hold: dropped on merge)
var aft_t := 0.0               # next dash after-image
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
		lk().burst("flare", t.pos, {"col": Color("b98aff"), "rim": res_col(), "r": 1.3, "dur": 0.35})
		m.sfx("tend_kindled", t.pos, -4.0, 1.0)
		play_soft("mm_kindled")

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
	_tick_burrs(dt)
	_tick_hearth(dt)
	_tick_carry(dt)
	_tick_call(dt)
	_tick_look(dt)
	if h.ctrl == "bot":
		_bot_idle(dt)

## Every ember the crook throws: the comet look, the swirl round the casting hand, the flick move.
func _tick_look(dt: float) -> void:
	if h.shot_n != shot_seen:
		shot_seen = h.shot_n
		var s := lk().last_shot()
		if not s.is_empty() and String((s["x"] as Dictionary).get("src", "")) != "abil":
			var emp: bool = float(s["life0"]) * (s["vel"] as Vector2).length() > float(h.wpn["range"]) * 1.2
			lk().skin(s, "ember")
			var d2 := h.aim_dir()
			lk().burst(
					"swirl", h.pos + Vector3(d2.x * 0.5, 1.05, d2.y * 0.5),
					{"r": 0.55 if not emp else 0.8, "dur": 0.12, "dir": d2})
			stats["embers"] += 1
			stats["swirls"] += 1
			if emp:
				stats["emp"] += 1
				play("mm_shot_emp")
				m.sfx("tend_ember_emp", h.pos, -3.0, 1.0)
			elif not seed_aim:
				play("mm_shot")
	# Kindle reads on the foe: an ember-violet glow at the feet that grows per stack
	for key in kind:
		var e: Dictionary = kind[key]
		var n := kindle_on(e["t"])
		if n > 0:
			var t: Ent = e["t"]
			lk().keep(
					"kin%d" % key, "kindle", t.pos,
					{
						"r": 0.55 + 0.12 * n, "col": Color("b98aff").lerp(Color("ffb347"), float(n) / 5.0),
						"a": 0.35 + 0.13 * n, "fill": 0.6, "pattern": 0.0})
	# the dash's after-images in her lantern colour
	if h.roll_t > 0.0 and h.move_kind == "dash":
		aft_t -= dt
		if aft_t <= 0.0:
			aft_t = 0.035
			lk().burst(
					"aft", h.position,
					{"col": Color("ffd27a"), "yaw": h.face, "r": float(h.cdat.get("scale", 1.0)), "dur": 0.25})
	lk().tick(dt)
	if ult_look != null:
		ult_look.tick(dt)

## A Boki merge sets a carried teammate down (unbroken: no stun), ends the Burrseed aim (no throw),
## and keeps the key from picking anyone up meanwhile.
func _drop_holds() -> void:
	if not hearth_call.is_empty():
		_call_end(false)
	if seed_aim or rmb_down:
		seed_aim = false
		rmb_down = false
		if anim_id == "mm_seed_aim": anim_id = ""
	if not carrying().is_empty():
		drop_all(false)
	carry_t = 0.0
	setdown_was = false
	lock_t = maxf(lock_t, 0.3)

# ------------------------------------------------------------------ Bearer (carry)
func carrying() -> Array:
	return CareUtil.carried_of(m, h)

func move_k() -> float:
	return 1.0 - (float(d["passive"].get("slow", 0.3)) if not carrying().is_empty() else 0.0)

func can_pick() -> bool:
	return lock_t <= 0.0 and h.stun_t <= 0.0 and h.root_t <= 0.0 and not busy() and not Hex.active(h)

func _tick_carry(dt: float) -> void:
	var pd: Dictionary = d["passive"]
	var cs := carrying()
	if not cs.is_empty():
		carry_t += dt
		if h.stun_t > 0.0 or h.root_t > 0.0 or Hex.active(h) or h.shield <= 0.01:
			drop_all(true)
			return
		h.shield_t = maxf(h.shield_t, 2.0)      # the Bearer shield stays up while you carry
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

func _foes_near(r: float) -> bool:
	for f in m.foes_of(h.team):
		if f is Hunter and h.flat_dist(f) < r:
			return true
	return false

func pick_up(o: Hunter) -> void:
	var pd: Dictionary = d["passive"]
	CareUtil.set_carry(m, o, h.nid)
	h.shield = float(pd.get("shield", 40.0)) + float(pd.get("shield_lv", 6.0)) * float(maxi(0, h.lvl - 1))
	h.shield_t = 999.0
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CARRY", res_col(), false)
	m.fx.ring(h.pos, 1.4, res_col(), 0.3)
	m.sfx("tend_pickup", h.pos, -2.0, 1.0)
	play("mm_pickup")
	if rank("dash") >= 3:
		h.ex_cd = 0.0
	if h.is_local() and m.hud:
		m.hud.toast_small("Carrying %s. Press %s to set them down" % [o.pname, Settings.key_cap(SETDOWN)], res_col())

func drop_all(broken: bool) -> void:
	for o in carrying():
		CareUtil.set_carry(m, o, "")
		o.teleport(Vector3(h.pos.x, h.pos.y, h.pos.z) + Vector3(0.9, 0, 0))
		o.vel = Vector3.ZERO
	h.shield = 0.0
	h.shield_t = 0.0
	lock_t = maxf(lock_t, 1.5)          # set down: not picked straight back up
	if broken:
		var pd: Dictionary = d["passive"]
		h.stun_t = maxf(h.stun_t, float(pd.get("drop_stun", 0.6)))
		lock_t = float(pd.get("lock", 4.0))
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "DROPPED", Color("ff8a6a"), false)
		m.sfx("knock", h.pos, -4.0, 1.2)

# ------------------------------------------------------------------ dash: Relay Step
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not spend_dash(use_ex):
		return true
	var dist := float(h.cdat.get("ex_dist", 5.0)) if use_ex else float(dd.get("dist", 4.2))
	var tt := float(h.cdat.get("ex_time", 0.2)) if use_ex else float(dd.get("time", 0.16))
	var from := h.pos
	travel(dist, tt, {"invuln": float(dd.get("invuln", 0.12))}, use_ex)
	play("mm_dash_air" if use_ex else "mm_dash")
	m.sfx("tend_hop", h.pos, -3.0, 0.9 if use_ex else 1.0)
	aft_t = 0.0
	var rd := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	var to := from + Vector3(rd.x, 0, rd.y).normalized() * dist
	last_dash_pass = false
	var ar := float(dd.get("ally_r", 1.1))
	for o in CareUtil.mates(m, h, Vector3.INF, 1e9, false):
		var c := Geometry2D.get_closest_point_to_segment(
				Vector2(o.pos.x, o.pos.z), Vector2(from.x, from.z), Vector2(to.x, to.z))
		if Vector2(o.pos.x, o.pos.z).distance_to(c) < ar + o.r and absf(o.pos.y - from.y) < 2.0:
			last_dash_pass = true
			if use_ex:
				h.ex_cd *= 1.0 - float(dd.get("refund", 0.5))
			else:
				h.dashes = minf(h.max_dashes(), h.dashes + float(dd.get("refund", 0.5)))
			wind_back_hearth(float(dd.get("e_refund", 1.0)))
			m.fx.ring(o.pos, 1.3, col_of(dd), 0.3)
			m.fx.word(o.pos + Vector3(0, 2.2, 0), "RELAY", col_of(dd), false)
			m.sfx("tend_relay", o.pos, -4.0, 1.0)
			lk().burst("plus", o.pos + Vector3(0, 1.2, 0), {"r": 0.5, "dur": 0.3})
			if not use_ex: play("mm_relay")
			break
	return true

# ------------------------------------------------------------------ RMB: Burrseed
## Held: a faint dotted lane out to the seed's full range (it flies past the cursor) and the coiled
## pose; let go (or tap) to throw. Not a charge: no charge ring.
func rmb_charge_full() -> float: return 0.0

func rmb_hold_tick(_t: float) -> void:
	if not rmb_ready() or busy():
		return
	var sd: Dictionary = rmb_def()["seed"]
	AimKit.dotted(h, "rmb", {"len": float(sd["range"]), "width": float(sd["hit_r"]) * 2.0, "col": Color("e8f6c8")})
	if not seed_aim:
		seed_aim = true
		play("mm_seed_aim")
		m.sfx("tend_seed_aim", h.pos, -6.0, 1.0)

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	seed_aim = false
	AimKit.hide(h, "rmb")
	if not spend_rmb():
		if anim_id == "mm_seed_aim": anim_id = ""
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
	lk().skin(lk().last_shot(), "burr")
	# the cast flare round her (about 1.5 bh across)
	lk().burst("flare", h.pos, {"col": Color("dff0ff"), "rim": Color(1, 1, 1), "r": 1.4, "dur": 0.25})
	m.fx.flash(start, Color("f0ffe0"), 0.9, 0.08)
	m.sfx("tend_seed", h.pos, -2.0, 1.0)
	Feel.shake(m, "cast", h, h.pos)

func _stick(e: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	burr_n += 1
	burrs.append({"t": e, "left": float(sd["delay"]), "total": float(sd["delay"]), "id": burr_n})
	# the area shows at once: a disc the size of the burst under them, and a light column falling
	lk().burst("column", e.pos, {"col": Color("b98aff"), "r": 1.0, "dur": float(sd["delay"]) + 0.1, "ent": e})
	m.sfx("tend_stick", e.pos, -3.0, 1.0)
	net_ring(e.pos, float(sd["burst_r"]), col_of(rmb_def()))

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
					"r": float(sd["burst_r"]), "col": Color("8a5cff"), "rim": Color("d6b8ff"), "fill": 0.9,
					"sweep": k, "pattern": 3.0, "spin": m.time * 0.8, "a": 0.9})
		AimKit.circle(h, key, {"at": t.pos, "r": float(sd["burst_r"]), "fill": k, "all": true, "col": Color("b98aff")})
		if float(b["left"]) <= 0.0:
			burrs.erase(b)
			lk().drop(key)
			AimKit.hide(h, key)
			_burst(t)

func _burst(t: Ent) -> void:
	var sd: Dictionary = rmb_def()["seed"]
	var at := t.pos
	var rr := float(sd["burst_r"])
	var col := col_of(rmb_def())
	# the flare: the disc snaps out bigger and brighter, then a root beam holds on each foe
	lk().burst(
			"flare", at,
			{"col": Color("a070ff"), "rim": Color("f0e0ff"), "r": rr * 1.5, "dur": 0.45, "pattern": 3.0})
	m.fx.burst(at + Vector3(0, 0.5, 0), Color("c9a0ff"), 26, 5.0, 0.6, 3.0, 1.2)
	m.fx.burst(at + Vector3(0, 0.2, 0), col, 14, 3.5, 0.5, 6.0, 1.0)
	m.sfx("tend_root", at, 0.0, 1.0)
	Feel.shake(m, "t3", h, at)
	var root := float(sd["root"]) + (0.3 if rank("sec") >= 3 else 0.0)
	for f in foes_in(at, rr):
		f.hurt(
				float(sd["burst_dmg"]) * power("sec"), h,
				{
					"src": "abil", "ab": "utility", "root": root, "dr": true, "kindle": true,
					"tags": ["utility", "burrseed"]})
		lk().burst("beam_root", f.pos, {"col": Color("b98aff"), "r": 1.0, "dur": root, "ent": f})
		lk().burst(
				"flare", f.pos,
				{"col": Color("8a5cff"), "rim": Color("d6b8ff"), "r": 1.0, "dur": root, "pattern": 3.0})
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
	# the lantern plus over her hand and green light rising round her
	lk().burst("plus", h.pos + Vector3(0, 1.9, 0), {"r": 0.9, "dur": 0.4})
	lk().burst("rays", h.pos, {"col": Color("9cf07a"), "r": 1.0, "dur": 0.45})
	m.sfx("tend_hearth", h.pos, -2.0, 1.0)
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
	hearth["boost"] = float(ed.get("boost_t", 1.0)) * (2.0 if rank("kin") >= 3 else 1.0)
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
	# a stun on the bearer puts the light out
	var on_me: bool = String(hearth["mode"]) == "self" or (
			String(hearth["mode"]) == "latched" and hearth.get("who") == h)
	if on_me and h.stun_t > 0.0:
		_hearth_end(false, "OUT")
		return
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
			lk().burst("flare", to, {"col": Color("bff0ff"), "rim": Color(1, 1, 1), "r": hearth_r(), "dur": 0.3})
			m.sfx("tend_land", to, -3.0, 1.0)
	var c := hearth_center()
	hearth["pos"] = c if String(hearth["mode"]) != "flying" else hearth["pos"]
	var tossed := bool(hearth.get("tossed", false))
	# on her: a soft pink-white rim, a faint inside; thrown: a bright filled disc with a white rim
	var gk := float(hearth["left"]) / maxf(0.01, float(ed["time"]))
	var look_p := {"r": hearth_r(), "col": Color("ffd8c8"), "rim": Color("ffe6f0"), "fill": 0.45, "pattern": 1.0,
		"a": 0.85 * (0.6 + 0.4 * gk), "spin": m.time * 0.5, "lamp": not tossed}
	if tossed:
		look_p.merge({"col": Color("bfefff"), "rim": Color(1, 1, 1), "fill": 1.6, "a": 1.2 * (0.6 + 0.4 * gk)}, true)
	lk().keep("hearth", "hearth", c, look_p)
	hearth["left"] = float(hearth["left"]) - dt
	e_t = float(hearth["left"])
	hearth["tick"] = float(hearth["tick"]) + dt
	var every := float(ed["every"])
	if float(hearth["tick"]) >= every:
		hearth["tick"] = float(hearth["tick"]) - every
		var per := float(ed["over"]) / (float(ed["time"]) / every)
		_pulse(c, per)
		m.fx.burst(c + Vector3(0, 0.3, 0), Color("ffe6b0"), 6, 1.2, 0.6, -2.0, 0.7, Vector3.UP, 30.0)
	hearth["boost"] = maxf(0.0, float(hearth["boost"]) - dt)
	if float(hearth["left"]) <= 0.0:
		_hearth_end(true, "FLARE")

func heal_k() -> float:
	return 1.0 + 0.15 * float(maxi(0, rank("kin") - 1))

func _pulse(c: Vector3, per: float) -> void:
	var ed := e_def()
	var boost := 1.5 if float(hearth.get("boost", 0.0)) > 0.0 else 1.0
	for o in m.hunters:
		if o.team != h.team or o.out or o.extracted:
			continue
		if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > hearth_r() + o.r:
			continue
		var amt := per * heal_k() * boost * (float(ed.get("self_k", 0.33)) if o == h else 1.0)
		CareUtil.heal(m, o, amt, float(ed.get("wisp_k", 5.0)))

func _hearth_end(flare: bool, word: String) -> void:
	var ed := e_def()
	var c := hearth_center()
	var rr := hearth_r()
	if flare:
		var amt := float(ed["burst"]) * heal_k()
		var col := col_of(ed)
		CareUtil.payoff(m, h, c, "HEARTH", col, "tend_flare")
		lk().burst(
				"flare", c,
				{"col": Color("fff0c0"), "rim": Color(1, 1, 1), "r": rr * 1.15, "dur": 0.4, "pattern": 1.0})
		lk().burst("rays", c, {"col": Color("ffe6a0"), "r": rr * 0.6, "dur": 0.4})
		play_soft("mm_flare")
		for o in m.hunters:
			if o.team != h.team or o.out or o.extracted:
				continue
			if Vector2(o.pos.x - c.x, o.pos.z - c.z).length() > rr + o.r:
				continue
			if o.downed:
				CareUtil.heal(m, o, amt, float(ed.get("wisp_k", 5.0)))
			else:
				CareUtil.heal(m, o, amt * (float(ed.get("self_k", 0.33)) if o == h else 1.0))
	else:
		m.fx.word(c + Vector3(0, 2.0, 0), word, Color("ff8a6a"), false)
		m.sfx("knock", c, -6.0, 1.4)
	lk().drop("hearth")
	hearth = {}
	e_t = 0.0

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


func ult_aims() -> bool:
	return true


func ult_running() -> bool:
	return not hearth_call.is_empty()


## X again while it runs does nothing (the source has no early end); the press is swallowed.
func ult_recast() -> bool:
	return true


## Held X: the gold reach ring round her and a line onto the teammate under the cursor (or a dim line
## to the cursor when nobody is there).
func ult_aim_tick() -> void:
	var xd := x_def()
	var gold := Color("ffd27a")
	AimKit.circle(h, "x", {"self": true, "r": float(xd["range"]), "col": gold, "dashed": true})
	var who := call_target()
	if who != null and who != h:
		AimKit.line(h, "x_line", {"from": h.pos, "to": who.pos, "col": Color("ffd27a"), "hot": 0.4})
		AimKit.circle(h, "x_pick", {"at": who.pos, "r": 0.8, "col": Color("9cf07a"), "ticks": true})
	else:
		AimKit.line(h, "x_line", {"col": Color("a2a8bb"), "alpha": 0.5})
		AimKit.hide(h, "x_pick")
	if anim_id != "mm_call_aim":
		play("mm_call_aim")


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


func cast_ult() -> bool:
	AimKit.hide(h, "x_line")
	AimKit.hide(h, "x_pick")
	var who := call_target()
	if who == null:
		if h.is_local() and m.hud:
			m.hud.toast_small("No teammate there", Color("a2a8bb"))
		if anim_id == "mm_call_aim":
			anim_id = ""
		return false
	hearth_call = {"who": who, "left": float(x_def()["time"]), "tick": 0.0, "fx": 0.0}
	stats["calls"] += 1
	play("mm_call")
	m.sfx("tend_call", h.pos, -1.0, 1.0)
	lk().burst("plus", who.pos + Vector3(0, 1.3, 0), {"r": 1.1, "dur": 0.45})
	var cast_flare := {"col": Color("9cf07a"), "rim": Color("ffd27a"), "r": 1.4, "dur": 0.35, "pattern": 1.0}
	lk().burst("flare", who.pos, cast_flare)
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "HEARTH CALL", col_of(x_def()), true)
	net_ring(h.pos, float(x_def()["range"]), Color("ffd27a"))
	net_bolt(h.pos + Vector3(0, 1.6, 0), who.pos + Vector3(0, 1.1, 0), Color("ffe6f0"))
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


## A tick of the tether's heal: on a standing teammate (or herself in solo); while they are down the
## healing goes to her instead (the source's rule for a channel on a downed ally).
func _call_heal(who: Hunter, amount: float) -> void:
	var amt := amount * LevelGrowth.ap(h)
	if who.downed or who == h:
		CareUtil.heal(m, h, amt * (float(e_def().get("self_k", 0.33)) if who == h else 1.0))
	else:
		CareUtil.heal(m, who, amt)


func _call_look(who: Hunter, dt: float) -> void:
	var xd := x_def()
	var gold := Color("ffd27a")
	AimKit.circle(h, "x", {"self": true, "r": float(xd["range"]), "col": gold, "all": true, "dashed": true})
	AimKit.circle(h, "x_me", {"self": true, "r": 0.7, "col": Color("ffc46a"), "all": true})
	if who != h:
		AimKit.circle(h, "x_pick", {"at": who.pos, "r": 0.7, "col": Color("9cf07a"), "all": true})
		var hand := h.pos + Vector3(0, 1.75, 0)
		ulk().keep("tether", "tether", hand, {"b": who.pos + Vector3(0, 1.1, 0)})
	hearth_call["fx"] = float(hearth_call["fx"]) - dt
	if float(hearth_call["fx"]) <= 0.0:
		hearth_call["fx"] = 0.22
		var up := who.pos + Vector3(randf_range(-0.4, 0.4), 0.6 + randf() * 0.8, randf_range(-0.4, 0.4))
		lk().burst("plus", up, {"r": 0.28, "dur": 0.5})
		m.fx.burst(who.pos + Vector3(0, 0.5, 0), Color("9cf07a"), 4, 1.4, 0.7, -3.0, 0.7, Vector3.UP, 25.0)
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
	HeroUlt.bond(h, "kill" if rescue else "hit")
	var at := who.pos if not rescue else h.pos
	# a rescue has its own revive banner, and the bond word lands on her now: no third word there
	CareUtil.payoff(m, h, at, "" if rescue else "MENDED", Color("9cf07a"), "tend_arrive")
	lk().burst("flare", at, {"col": Color("9cf07a"), "rim": Color("ffd27a"), "r": 1.8, "dur": 0.4, "pattern": 1.0})
	lk().burst("rays", at, {"col": Color("b8ff9a"), "r": 0.9, "dur": 0.45})
	play("mm_call_end")


## Pulls a downed teammate to her side and stands them up. An online teammate rides there on the
## existing "carry" event, then the "rev" event stands them up a beat later.
func _call_home(who: Hunter) -> void:
	stats["rescues"] += 1
	var side := Vector2(cos(h.face), -sin(h.face)) * float(x_def().get("land_r", 0.9))
	var to := Vector3(h.pos.x + side.x, h.pos.y, h.pos.z + side.y)
	lk().burst("plus", who.pos + Vector3(0, 1.2, 0), {"r": 0.8, "dur": 0.3})
	if who.remote:
		CareUtil.set_carry(m, who, h.nid)
		m.later(0.15, func():
			CareUtil.revive(m, who, h)
			CareUtil.set_carry(m, who, ""))
		return
	who.teleport(to)
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
	if not hearth_call.is_empty() or not HeroUlt.can_cast(h):
		return
	for o in CareUtil.mates(m, h, h.pos, float(x_def()["range"]) - 1.0):
		if o.downed or o.hp < o.max_hp * 0.35:
			h.inp["aim"] = o.pos + Vector3(0, 0.9, 0)
			HeroUlt.press(h)
			if x_aim:
				HeroUlt.fire(h)
			return
