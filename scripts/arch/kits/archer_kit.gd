class_name ArcherKit
extends ArchKit
## Archer (light): Grapple Arrow, Focus, Snare (tap: a rooting snare / Tripwire; hold: a charged
## Heavy Shot that pierces, knocks back and stuns into a wall; Plunge in the air), Arrow Rain (E),
## Great Arrows (R). docs/ARCHETYPES.md §6.2 and "Kit loops" (kits4; Myth-style hunter archer ideas).
## The bow draws in stages you hear and see; let go right at full draw (the perfect window) for +25%.
##
## The loop (kits4): snares root (Pin) and feed Focus -> full Focus arms the Deadeye (a lens glint and
## a thin aim line everyone sees, crosshairs over every pinned foe) -> the next shot is drawn at once,
## and into a rooted or stunned foe it's a Deadeye: a gold payoff hit with T4 hitstop and its own sound.

var rain := {}                 # the live Arrow Rain: {a, b, t, tick, patter, tele}
var great := {}                # Great Arrows left: {left, t, n}
var draw_was := -1.0           # last frame's bow draw (stage ticks)
var perfects := 0              # perfect draws (tests)
var trips: Array = []          # our live Tripwires (verbs trap dictionaries)
var pin_tele: Node3D = null    # the Pinning Shot's lane while held
var high_t := 0.0              # re-checks high ground now and then
var on_high := false
var loosed := 0.0              # a Focus shot is in the air until this time (its hit can be a Deadeye)
var pin_until := {}            # foe instance id -> [ent, time]: rooted or stunned (plus a short grace)
var armed_at := -9.0           # the last "DEADEYE READY" pop (rate-limited)
var was_full := false
var glint: Node3D = null       # the lens glint at the bow and the thin aim line (full Focus)
var reticles := {}             # foe instance id -> node: crosshairs over pinned foes while Deadeye is armed
var deadeyes := 0              # Deadeyes landed (tests, demo)

func full_ready() -> bool:
	return res >= res_max() - 0.01

func res_text() -> String:
	return "READY" if full_ready() else "%d" % int(res)

func ready_label() -> String:
	if not great.is_empty(): return "GREAT ARROWS  ·  %d" % int(great["left"])
	return "DEADEYE READY" if full_ready() else ""

## Focus from play (a snare that roots, a Pin): the out-of-combat clock doesn't apply to Focus.
func add_focus(v: float) -> void:
	add_res(v)

## A full Focus makes the next shot fully drawn or aimed at once, with +20% range (Hunter.fire reads it).
## The shot stays "loosed" for a moment: if it hits a pinned foe it's a Deadeye.
func take_focus_shot() -> bool:
	if res < res_max() - 0.01:
		return false
	res = 0.0
	was_full = false
	loosed = m.time + float(res_def().get("window", 1.2))
	var d := h.aim_dir()
	m.fx.flash(h.pos + Vector3(d.x * 0.6, 1.0, d.y * 0.6), res_col(), 0.8, 0.08)
	m.fx.ring(h.pos + Vector3(d.x * 0.6, 1.0, d.y * 0.6), 0.6, res_col(), 0.15)
	m.sfx("rail", h.pos, -9.0 if h.is_local() else -12.0, 1.7)       # the string's snap
	return true

## A rooted or stunned foe (anyone's root counts), or one that was a moment ago.
func pinned(t: Ent) -> bool:
	if t == null or not is_instance_valid(t) or t.dead:
		return false
	if t.root_t > 0.0 or t.stun_t > 0.0:
		return true
	var e: Array = pin_until.get(t.get_instance_id(), [])
	return not e.is_empty() and float(e[1]) > m.time

func on_deal(t: Ent, _dmg: float, o: Dictionary) -> void:
	if loosed <= 0.0 or t == null or t.team == h.team:
		return
	if String(o.get("src", "")) != "shot" or o.has("ab"):
		return
	loosed = 0.0
	if pinned(t):
		var tgt := t
		m.later(0.02, func(): if is_instance_valid(h) and is_instance_valid(tgt) and not tgt.dead: _deadeye(tgt))

## Deadeye: the Focus shot found a pinned foe. A second, gold hit (a payoff: T4 hitstop, a crit), the
## arrow's line drawn in gold, its own sound, the T4 shake and a camera punch along the shot.
func _deadeye(t: Ent) -> void:
	var rd := res_def()
	var dir := h.dir_to(t)
	var gold := Color("ffe27a")
	t.hurt(float(rd.get("deadeye", 18.0)) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "deadeye"], "payoff": true, "crit": true, "kb": dir * 5.0})
	deadeyes += 1
	m.fx.bolt(h.pos + Vector3(0, 1.2, 0), t.pos + Vector3(0, 1.0, 0), gold)
	m.fx.bolt(h.pos + Vector3(0, 1.25, 0), t.pos + Vector3(0, 1.05, 0), Color(1, 1, 1, 0.8))
	m.fx.burst(t.pos + Vector3(0, 1.0, 0), res_col(), 18, 9.0, 0.4, 0.0, 1.0, Vector3(dir.x, 0.2, dir.y), 25.0)
	payoff_fx(t.pos, "DEADEYE", gold, "pay_deadeye", dir, t)
	net_bolt(h.pos + Vector3(0, 1.2, 0), t.pos + Vector3(0, 1.0, 0), gold)
	CombatBus.ability_used.emit(h, "deadeye", "secondary")

func _tick(dt: float) -> void:
	var rd := res_def()
	high_t -= dt
	if high_t <= 0.0:
		high_t = 0.5
		on_high = _high_ground()
	var still: bool = h.grounded and Vector2(h.vel.x, h.vel.z).length() < 0.6 and h.roll_t <= 0.0
	var k := float(rd.get("high_k", 1.5)) if on_high else 1.0
	if still:
		add_res(res_max() / float(rd.get("still_t", 1.4)) * k * dt)
	elif h.crouch:
		add_res(res_max() / float(rd.get("sneak_t", 2.8)) * k * dt)
	elif h.grounded and Vector2(h.vel.x, h.vel.z).length() > 2.5:
		add_res(-float(rd.get("run_drain", 60.0)) * dt)
	if loosed > 0.0 and m.time > loosed:
		loosed = 0.0
	# pinned foes: rooted or stunned now, and for a short grace after (the Deadeye can still land)
	var grace := float(rd.get("pin_grace", 0.8))
	for f in m.foes_of(h.team):
		if (f.root_t > 0.0 or f.stun_t > 0.0) and h.flat_dist(f) < 24.0:
			pin_until[f.get_instance_id()] = [f, m.time + grace]
	for key in pin_until.keys():
		if float(pin_until[key][1]) <= m.time or not is_instance_valid(pin_until[key][0]): pin_until.erase(key)
	var full := full_ready()
	if full and not was_full and m.time - armed_at > 2.5:
		armed_at = m.time
		armed_fx("", "")       # (the glint, the aim line and the crosshair label say it; no word every refill)
	was_full = full
	_tick_glint(dt)
	_tick_reticles()
	net_pulse(dt, full)
	trips = trips.filter(func(t): return m.verbs.traps.has(t))
	if pin_tele and is_instance_valid(pin_tele) and rmb_down:
		m.fx.aim_telegraph(pin_tele, h.pos, h.aim_dir())
		m.fx.telegraph_progress(pin_tele, heavy_k())
	if not rain.is_empty():
		_tick_rain(dt)
	if not great.is_empty():
		great["t"] = float(great["t"]) - dt
		if float(great["t"]) <= 0.0 or int(great["left"]) <= 0:
			great = {}
	_tick_draw_stages()

## The bow's stages, heard and seen: a creak at stage 1 (0.4s), and at full draw (0.9s) a bright
## ping and flash that opens the perfect window (let go within it for +25%).
func _tick_draw_stages() -> void:
	var t := h.draw_t
	if t >= 0.0 and t < 5.0 and h.wpn.has("draw"):
		var d := h.aim_dir()
		var at := h.pos + Vector3(d.x * 0.6, 1.1, d.y * 0.6)
		if draw_was < 0.4 and t >= 0.4:
			m.sfx("click", h.pos, -6.0, 1.3)
			m.fx.flash(at, res_col(), 0.45, 0.05)
		var pw := perfect_window()
		if draw_was < pw.x and t >= pw.x:
			m.sfx("ab_ready", h.pos, -3.0 if h.is_local() else -7.0, 1.5)
			m.fx.flash(at, Color.WHITE, 0.9, pw.y - pw.x)
			m.fx.ring(h.pos, 1.3, res_col(), pw.y - pw.x)
			net_ring(h.pos, 1.3, res_col())
	draw_was = t

## The perfect release window of the bow: from full draw for 0.15s.
func perfect_window() -> Vector2:
	var st: Array = h.wpn.get("draw", [])
	var full := float((st[-1] as Array)[0]) if not st.is_empty() else 0.9
	return Vector2(full, full + float(res_def().get("perfect_t", 0.15)))

## Hunter._loose asks: a bow let go inside the perfect window hits 25% harder.
func draw_bonus(t: float) -> float:
	var pw := perfect_window()
	if t >= pw.x and t <= pw.y:
		perfects += 1
		var d := h.aim_dir()
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "PERFECT", Color("ffffff"), false)
		m.fx.flash(h.pos + Vector3(d.x * 0.7, 1.1, d.y * 0.7), res_col().lightened(0.4), 1.1, 0.08)
		m.sfx("rail", h.pos, -6.0, 1.9)
		if h.is_local(): Oomph.punch_dir(m, d, 0.25)
		return 1.0 + float(res_def().get("perfect_k", 0.25))
	return 1.0

func _high_ground() -> bool:
	var gy: float = m.world.ground_at(h.pos.x, h.pos.z)
	var lower := 0
	for i in 8:
		var a := TAU * i / 8.0
		var q := h.pos + Vector3(cos(a), 0, sin(a)) * 3.0
		var g: float = m.world.ground_at(q.x, q.z)
		if g <= World.VOID + 1.0 or g < gy - 0.9: lower += 1
	return lower >= 3

## The Focus tell on the hunter (everyone sees it): a lens glint at the bow that brightens from 50,
## and at 100 a bright star with a light and a thin aim line along the shot.
func _tick_glint(_dt: float) -> void:
	var f := res_frac()
	if glint == null or not is_instance_valid(glint):
		glint = own_node()
		var star := MeshInstance3D.new()
		star.name = "Star"
		star.mesh = Models.sphere(0.16, 10)
		star.material_override = Models.glow_mat(Color(res_col(), 1.0))
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.add_child(star)
		var lt := OmniLight3D.new()
		lt.name = "Light"
		lt.light_color = res_col()
		lt.omni_range = 2.6
		glint.add_child(lt)
		var line := MeshInstance3D.new()
		line.name = "Line"
		line.mesh = Models.box(0.05, 0.03, 1.0)
		line.material_override = Models.glow_mat(Color(Color("ffe27a"), 0.55))
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.add_child(line)
	var show := tells_visible() and f >= 0.5
	glint.visible = show
	if not show:
		return
	var d := h.aim_dir()
	glint.global_position = h.position + Vector3(d.x * 0.55, 1.3 * float(h.cdat.get("scale", 1.0)), d.y * 0.55)
	var full := full_ready()
	var star := glint.get_node("Star") as MeshInstance3D
	var pulse := 0.5 + 0.5 * sin(m.time * 12.0)
	star.scale = Vector3.ONE * ((1.4 + 0.5 * pulse) if full else lerpf(0.4, 0.9, (f - 0.5) * 2.0))
	(glint.get_node("Light") as OmniLight3D).light_energy = (1.8 + pulse) if full else 0.0
	var line := glint.get_node("Line") as MeshInstance3D
	line.visible = full
	if full:
		var reach := 15.0 * (1.0 + float(res_def().get("range_k", 0.2)))
		line.scale = Vector3(1.0, 1.0, reach)
		line.position = Vector3(d.x, 0, d.y) * reach * 0.5 + Vector3(0, -0.2, 0)
		line.rotation = Vector3(0.0, atan2(d.x, d.y), 0.0)

## Crosshairs over every pinned foe while the Deadeye is armed: "this one is about to take it".
func _tick_reticles() -> void:
	var want := {}
	if full_ready() and tells_visible():
		for key in pin_until:
			var t: Ent = pin_until[key][0]
			if is_instance_valid(t) and not t.dead and h.flat_dist(t) < 18.0:
				want[key] = t
	for key in reticles.keys():
		if not want.has(key) or not is_instance_valid(reticles[key]):
			if is_instance_valid(reticles[key]): (reticles[key] as Node3D).queue_free()
			reticles.erase(key)
	for key in want:
		var t: Ent = want[key]
		if not reticles.has(key):
			var n := Node3D.new()
			n.top_level = true
			var ring := MeshInstance3D.new()
			ring.mesh = Models.flat_quad(1.3)
			ring.material_override = Models.ring_mat(Color(Color("ffe27a"), 0.95), 0.1)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(ring)
			for i in 4:
				var tick := MeshInstance3D.new()
				tick.mesh = Models.box(0.08, 0.04, 0.32)
				tick.material_override = Models.glow_mat(Color(Color("ffe27a"), 1.0))
				var a := TAU * i / 4.0
				tick.position = Vector3(sin(a), 0, cos(a)) * 0.72
				tick.rotation.y = a
				n.add_child(tick)
			m.add_child(n)
			reticles[key] = n
		var rn: Node3D = reticles[key]
		rn.global_position = t.position + Vector3(0, (2.6 if t is Hunter else 1.9), 0)
		rn.rotation.y = m.time * 2.5
		rn.scale = Vector3.ONE * (1.0 + 0.12 * sin(m.time * 10.0))

func teardown() -> void:
	for key in reticles:
		if is_instance_valid(reticles[key]): (reticles[key] as Node3D).queue_free()
	reticles = {}
	super.teardown()

func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	if dmg > 0.5:
		add_res(-float(res_def().get("hit_loss", 40.0)))

# ------------------------------------------------------------------ dash: Grapple Arrow
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	if not spend_dash(use_ex and not h.gliding):
		return true
	var dir := h.aim_dir()
	var bite := _bite(dir, float(dd.get("reach", 9.0)), float(dd.get("max_up", 3.2)))
	var from := h.pos
	if h.gliding:
		h.glide_fuel = minf(1.0, h.glide_fuel + float(dd.get("glide_cool", 0.2)))
	Feel.dash_sound(m, id, h.pos, h)
	CombatBus.ability_used.emit(h, "grapple", "dodge")
	if bite == Vector3.INF:
		# bit nothing: a hop back, away from the cursor
		travel(float(dd.get("hop", 3.2)), 0.14, {"invuln": 0.0, "dir": -dir, "trail": "roll"}, use_ex)
		st["last_grapple"] = "hop"
		if rank("dash") >= 3: h.dashes = minf(h.max_dashes(), h.dashes + 0.4)
		return true
	st["last_grapple"] = "zip"
	var dist := Vector2(bite.x - from.x, bite.z - from.z).length()
	var t := clampf(dist / float(dd.get("zip_speed", 22.0)), 0.18, 0.45)
	m.fx.bolt(from + Vector3(0, 1.2, 0), bite + Vector3(0, 0.3, 0), Color("e8f7c0"))
	var rp := rider_points(from, bite)
	if String(rp.get("as", "")) == "blink":
		# a Lunowl: the rope flashes and you're simply there
		m.later(0.1, func():
			if is_instance_valid(h) and not h.downed:
				h.teleport(bite); h.vel = Vector3.ZERO; h.gliding = false)
	else:
		h.gliding = false
		h.launch_to(bite + Vector3(0, 0.15, 0), t)
		# the landing ring flashes 0.15s before you arrive, for everyone
		m.later(maxf(0.0, t - 0.15), func(): if is_instance_valid(h): m.fx.ring(bite, 1.0, Color("e8f7c0"), 0.2))
		tele_lane(from, Vector2(bite.x - from.x, bite.z - from.z).normalized(), dist, 0.12, Color("e8f7c0"), t)
	if rp.get("repeat") != null:
		st["regrapple_t"] = 1.0       # an echo: a free second grapple within 1s
	return true

## Where the line arrow bites: a wall, rock or ledge up to max_up above you (you climb on top),
## or Vector3.INF for nothing (open ground, the abyss).
func _bite(dir: Vector2, reach: float, max_up: float) -> Vector3:
	var y0 := h.pos.y
	var k := 0.5
	var last_ok := Vector3.INF
	while k <= reach:
		var q := h.pos + Vector3(dir.x, 0, dir.y) * k
		var g: float = m.world.ground_at(q.x, q.z)
		if m.world.is_block(q.x, q.z):
			return last_ok if last_ok != Vector3.INF and k > 1.2 else Vector3.INF
		if g > World.VOID + 1.0 and g > y0 + 0.6:
			if g <= y0 + max_up + (2.0 if not h.grounded else 0.0):
				var top := h.pos + Vector3(dir.x, 0, dir.y) * minf(reach, k + 0.6)
				var gt: float = m.world.ground_at(top.x, top.z)
				if gt < g - 0.3 or m.world.is_block(top.x, top.z): top = q
				return Vector3(top.x, m.world.ground_at(top.x, top.z), top.z)
			return last_ok if last_ok != Vector3.INF and k > 1.2 else Vector3.INF
		if g > World.VOID + 1.0 and absf(g - y0) < 0.6:
			last_ok = Vector3(q.x, g, q.z)
		k += 0.25
	return Vector3.INF

# ------------------------------------------------------------------ RMB: Snare
func rmb_hold_tick(t: float) -> void:
	if t > 0.15 and pin_tele == null and not rmb_ctx.get("air", false):
		# the draw shows a glint and the lane to enemies (a hard-CC telegraph)
		pin_tele = tele_lane(h.pos, h.aim_dir(), float(rmb_def()["pin"]["range"]), 0.5, Color("ffe0a0"), 0.0)
		m.fx.flash(h.pos + Vector3(0, 1.2, 0), Color("ffe0a0"), 0.4, 0.1)

## The Heavy Shot charges from the hold threshold to full.
func rmb_charge_full() -> float:
	return float(rmb_def()["pin"]["full"])

func heavy_k() -> float:
	var pd: Dictionary = rmb_def()["pin"]
	return clampf((rmb_t - float(rmb_def()["hold"])) / maxf(0.05, float(pd["full"]) - float(rmb_def()["hold"])), 0.0, 1.0)

func rmb_auto_t() -> float:
	return float(rmb_def()["pin"]["full"]) + 0.5

func _drop_tele() -> void:
	if pin_tele and is_instance_valid(pin_tele):
		m.fx.end_telegraph(pin_tele)
	pin_tele = null

func fire_rmb(c: Dictionary) -> void:
	_drop_tele()
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	if c.get("air", false):
		_plunge()
		return
	var target_aim := aim()
	if c.get("hold", false):
		_pin(target_aim, clampf((float(c["t"]) - float(sd["hold"])) / maxf(0.05, float(sd["pin"]["full"]) - float(sd["hold"])), 0.0, 1.0))
		return
	var sn: Dictionary = sd["snare"]
	# full Focus, or with your Arrow Rain falling: the snare roots for longer
	var root := float(sn["root_full"]) if c.get("full", false) or c.get("e", false) else float(sn["root"])
	# the arrow comes down at the cursor (up to 11m): a miss plants the Tripwire there
	var srange := clampf(Vector2(target_aim.x - h.pos.x, target_aim.z - h.pos.z).length() + 0.5, 2.5, float(sn["range"]))
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(sn["speed"]), "range": srange, "size": 0.16},
		"effects": [{"type": "damage", "amount": float(sn["dmg"])}, {"type": "root", "duration": root}]})
	run(stg, cx("rmb", "snare", target_aim, {"on_foe": func(_f: Ent, _c: Dictionary): add_focus(float(res_def().get("snare_gain", 40.0))),
		"on_shot_end": func(at: Vector3, why: String, e):
		if why != "hit" and e == null:
			_tripwire(at)}))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)

func _tripwire(at: Vector3) -> void:
	var tr := res_def()
	var td: Dictionary = rmb_def()["trip"]
	var g := ground(at - Vector3(h.aim_dir().x, 0, h.aim_dir().y) * 0.3)
	if m.world.is_void(g.x, g.z):
		return
	var maxn := int(td["max"]) + (1 if rank("sec") >= 3 else 0)
	while trips.size() >= maxn:
		var old: Dictionary = trips.pop_front()
		if m.verbs.traps.has(old): m.verbs._drop_trap(old)
	var n0: int = m.verbs.traps.size()
	# the trigger: a 0.15s click, then root, reveal and damage (the trap rule, DASHES §5.3)
	var stg := stage("rmb", {"delivery": {"type": "trap", "origin": "here", "radius": 1.0, "arm": float(td["arm"]), "duration": float(td["time"])},
		"then": {"on_trigger": [{"delivery": {"type": "burst", "origin": "here", "radius": 1.3},
			"effects": [{"type": "damage", "amount": float(td["dmg"])}, {"type": "root", "duration": float(td["root"])}, {"type": "mark", "mode": "reveal", "duration": float(td["reveal"])}],
			"modifiers": [{"type": "delay", "time": 0.15}]}]}}, {"hit": "add"})
	run(stg, cx("rmb", "tripwire", g, {"at": g}))
	for i in range(n0, m.verbs.traps.size()):
		trips.append(m.verbs.traps[i])

## The Heavy Shot: a held, charged arrow (0.5s -> full at 1.1s) that pierces, knocks back by its
## charge and, driven into a wall within 3m, stuns (PINNED). Full charge is a heavy hit.
func _pin(a: Vector3, k: float) -> void:
	var pd: Dictionary = rmb_def()["pin"]
	var dmg := lerpf(float(pd["dmg"][0]), float(pd["dmg"][1]), k)
	var push := lerpf(float(pd["push"][0]), float(pd["push"][1]), k)
	var stg := stage("rmb", {"delivery": {"type": "projectile", "speed": float(pd["speed"]), "range": float(pd["range"]) * (1.0 + 0.2 * k), "size": lerpf(0.2, 0.34, k)},
		"effects": [{"type": "damage", "amount": dmg}, {"type": "push", "strength": push, "from": "caster"}],
		"modifiers": [{"type": "pierce", "count": int(pd["pierce"])}]})
	var dir := Vector2(a.x - h.pos.x, a.z - h.pos.z).normalized()
	var extra := {"hit_extra": {"heavy": true}} if k >= 0.99 else {}
	extra["on_foe"] = func(f: Ent, _c: Dictionary):
		add_focus(float(res_def().get("snare_gain", 40.0)))
		# driven into terrain within 3m: pinned (a stun), and the shot lines up: full Focus
		if _wall_behind(f, dir, float(pd["wall"])):
			add_focus(res_max())
			m.later(0.12, func():
				if is_instance_valid(f) and not f.dead:
					f.hurt(0.1, h, {"stun": float(pd["stun"]), "src": "abil", "ab": "utility", "tags": ["utility", "pin"], "exploit": true, "dr": true})
					m.fx.word(f.pos + Vector3(0, 2.2, 0), "PINNED", Feel.cat_color("control"), true)
					m.fx.dust(f.pos, 10)
					Feel.shake(m, "t3", h, f.pos, f))
	run(stg, cx("rmb", "heavy_shot", a, extra))
	Feel.cast_sound(m, "projectile", "control", h.pos, h)
	m.sfx("rail", h.pos, lerpf(-6.0, 0.0, k), lerpf(1.4, 0.8, k))
	m.sfx("sniper", h.pos, lerpf(-12.0, -3.0, k), 1.3)
	var d := h.aim_dir()
	m.fx.flash(h.pos + Vector3(d.x * 0.7, 1.1, d.y * 0.7), Color("ffe0a0"), 0.5 + 0.6 * k, 0.07)
	if k >= 0.99: Feel.shake(m, "t2", h, h.pos)
	h.vel.x -= d.x * (1.5 + 3.0 * k); h.vel.z -= d.y * (1.5 + 3.0 * k)

func _wall_behind(f: Ent, dir: Vector2, reach: float) -> bool:
	var g0: float = f.pos.y
	var k := 0.4
	while k <= reach:
		var q := f.pos + Vector3(dir.x, 0, dir.y) * k
		if m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > g0 + 0.8:
			return true
		k += 0.3
	return false

func _plunge() -> void:
	var pd: Dictionary = rmb_def()["plunge"]
	var at := h.pos
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(pd["radius"])},
		"effects": [{"type": "push", "strength": float(pd["push"])}]}, {"hit": "add"})
	run(stg, cx("rmb", "plunge", at))
	h.vel.y = maxf(h.vel.y, float(pd["lift"]))
	h.gliding = false
	h.grounded = false
	h.glide_fuel = minf(1.0, h.glide_fuel + float(pd["cool"]))
	m.fx.bolt(at + Vector3(0, 1.0, 0), ground(at) + Vector3(0, 0.1, 0), Color("e8f7c0"))
	m.sfx("whoosh", at, -3.0, 1.3)

# ------------------------------------------------------------------ E: Arrow Rain
## A wall of falling arrows: lobbed in front of you, it rains along a line across your aim (6m long,
## 2.2m deep) for 3.75s: damage over time, a slow and a blight (healing barely takes) on foes inside.
func in_e() -> bool:
	return not rain.is_empty()

func cast_e() -> bool:
	var ed := e_def()
	var c := aim_at(float(ed["reach"]))
	var d := Vector2(c.x - h.pos.x, c.z - h.pos.z)
	d = d.normalized() if d.length() > 0.2 else h.aim_dir()
	var side := Vector2(-d.y, d.x)
	var half := float(ed["length"]) * 0.5 + (0.5 if rank("kin") >= 3 else 0.0)
	var a := c + Vector3(side.x, 0, side.y) * half
	var b := c - Vector3(side.x, 0, side.y) * half
	var tell := float(ed["tell"])
	# the arrows go up first (enemies see the strip fill), then the rain starts
	var tele := tele_lane(a, -side, half * 2.0, float(ed["width"]), col_of(ed), tell)
	m.spawn_shot(h, h.pos + Vector3(0, 1.2, 0), d * maxf(4.0, h.flat_dist(c) / tell), 0.0, tell, 0.15, col_of(ed), {"lob": 3.0, "cos": true})
	for i in 6:
		m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 1.5, 0), col_of(ed), 3, 7.0, 0.35, -10.0, 0.8, Vector3.UP, 12.0))
	m.sfx("ab_throw", h.pos, -2.0, 1.4)
	net_bolt(a + Vector3(0, 0.2, 0), b + Vector3(0, 0.2, 0), col_of(ed))
	var t := float(ed["time"])
	rain = {"a": a, "b": b, "c": c, "d": d, "t": t + tell, "start": tell, "tick": 0.0, "patter": 0.0, "fx": 0.0, "tele": tele}
	e_t = t + tell
	return true

func _in_rain(f: Ent) -> bool:
	var fp := Vector2(f.pos.x, f.pos.z)
	var a: Vector3 = rain["a"]; var b: Vector3 = rain["b"]
	var cp := Geometry2D.get_closest_point_to_segment(fp, Vector2(a.x, a.z), Vector2(b.x, b.z))
	return fp.distance_to(cp) < float(e_def()["width"]) * 0.5 + f.r and absf(f.pos.y - a.y) < 2.5

func _tick_rain(dt: float) -> void:
	var ed := e_def()
	rain["t"] = float(rain["t"]) - dt
	if float(rain["t"]) <= 0.0:
		rain = {}
		return
	if float(rain["start"]) > 0.0:
		rain["start"] = float(rain["start"]) - dt
		if float(rain["start"]) <= 0.0:
			# the strip stays marked while it rains
			rain["tele2"] = tele_lane(rain["a"], Vector2(rain["b"].x - rain["a"].x, rain["b"].z - rain["a"].z).normalized(), float(ed["length"]) + (1.0 if rank("kin") >= 3 else 0.0), float(ed["width"]), Color(col_of(ed), 0.6), float(rain["t"]))
		return
	var a: Vector3 = rain["a"]; var b: Vector3 = rain["b"]; var d: Vector2 = rain["d"]
	# the rain: arrows falling all along the strip, and a steady patter
	rain["fx"] = float(rain["fx"]) - dt
	if float(rain["fx"]) <= 0.0:
		rain["fx"] = 0.06
		for i in 2:
			var q := a.lerp(b, randf()) + Vector3(d.x, 0, d.y) * randf_range(-1.0, 1.0) * float(ed["width"]) * 0.45
			q = ground(q)
			m.fx.bolt(q + Vector3(randf_range(-0.6, 0.6), 7.0, randf_range(-0.6, 0.6)), q, Color(col_of(ed), 0.9))
			m.fx.burst(q + Vector3(0, 0.1, 0), col_of(ed), 2, 1.5, 0.2, 4.0, 0.7)
	rain["patter"] = float(rain["patter"]) - dt
	if float(rain["patter"]) <= 0.0:
		rain["patter"] = randf_range(0.07, 0.13)
		m.sfx("click", a.lerp(b, randf()), -13.0, randf_range(1.6, 2.4))
	rain["tick"] = float(rain["tick"]) - dt
	if float(rain["tick"]) > 0.0:
		return
	rain["tick"] = float(ed["every"])
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": 0.8, "strength": float(ed["slow"])}]})
	for f in m.foes_of(h.team):
		if f.hittable() and _in_rain(f):
			KinExec.apply_foe(stg.effects, f, cx("e", "arrow_rain", f.pos, {"at": f.pos}), f.pos, stg)
			if "blight_t" in f: f.set("blight_t", maxf(float(f.get("blight_t")), float(ed["blight"])))

# ------------------------------------------------------------------ R: Great Arrows
## Three empowered arrows: for 6s your next three shots need no draw, fly far, pierce everything,
## knock back and hit hard, the third hardest (a payoff hit; into a wall it stuns).
func cast_r() -> bool:
	var rd := r_def()
	great = {"left": int(rd["shots"]), "t": float(rd["window"]) * r_dur_k(), "n": 0}
	r_t = float(great["t"])
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "GREAT ARROWS", col_of(rd), true)
	for i in 3:
		m.fx.ring(h.pos, 0.8 + 0.4 * i, Color(col_of(rd), 0.9), 0.3 + 0.1 * i)
	m.sfx("ab_ready", h.pos, -2.0, 0.8)
	return true

func lmb_override(held: bool, _dt: float) -> bool:
	if great.is_empty() or int(great["left"]) <= 0:
		return false
	if held and h.can_fire() and h.fire_cd <= 0.0 and h.ammo > 0:
		_great_arrow()
		h.draw_t = -1.0
		return true
	return held

func _great_arrow() -> void:
	var rd := r_def()
	var i := int(great["n"])
	great["n"] = i + 1
	great["left"] = int(great["left"]) - 1
	var last := int(great["left"]) <= 0
	var dmgs: Array = rd["dmg"]; var pushes: Array = rd["push"]
	var dmg := float(dmgs[mini(i, dmgs.size() - 1)]) * r_k()
	var push := float(pushes[mini(i, pushes.size() - 1)])
	var d := h.aim_dir()
	h.fire_cd = float(rd["rate"])
	var stg := stage("r", {"delivery": {"type": "projectile", "speed": float(rd["speed"]), "range": float(rd["range"]), "size": 0.42 if not last else 0.55},
		"effects": [{"type": "damage", "amount": dmg}, {"type": "push", "strength": push, "from": "caster"}],
		"modifiers": [{"type": "pierce", "count": 5}]})
	var extra := {"hit_extra": {"payoff": true} if last else {"heavy": true}, "on_foe": func(f: Ent, _c: Dictionary):
		if last:
			payoff_fx(f.pos, "GREAT ARROW", col_of(rd), "pay_deadeye", d, f)
			if _wall_behind(f, d, 3.0): f.hurt(0.1, h, {"stun": float(rd["wall_stun"]), "src": "abil", "ab": "ult", "tags": ["ult"], "dr": true})
		else:
			m.fx.ring(f.pos, 1.4, col_of(rd), 0.25)}
	run(stg, cx("r", "great_arrow", aim(), extra))
	# the release: a heavy twang and boom, a big flash, the archer rocked back
	m.sfx("sniper", h.pos, -1.0, 0.7 if not last else 0.55)
	m.sfx("ab_rail", h.pos, -6.0, 1.2 if not last else 0.9)
	m.fx.flash(h.pos + Vector3(d.x * 0.8, 1.1, d.y * 0.8), col_of(rd).lightened(0.3), 1.0 + (0.6 if last else 0.0), 0.08)
	m.fx.burst(h.pos + Vector3(d.x * 0.8, 1.1, d.y * 0.8), col_of(rd), 16, 9.0, 0.35, 0.0, 1.2, Vector3(d.x, 0.1, d.y), 25.0)
	Feel.shake(m, "t3" if last else "t2", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, -d, 0.3 if last else 0.18)
	h.vel.x -= d.x * (3.0 if not last else 6.0); h.vel.z -= d.y * (3.0 if not last else 6.0)
	net_bolt(h.pos + Vector3(0, 1.1, 0), h.pos + Vector3(d.x, 0, d.y) * float(rd["range"]) + Vector3(0, 1.1, 0), col_of(rd))
	if last: great = {}

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# Deadeye armed and someone pinned in range: loose it at them
	if full_ready() and los and dist < 15.0 and pinned(tgt):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["fire"] = true
		return
	# Great Arrows: when a rival is in a long, clear line (then the gun loop fires them through)
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and dist < float(r_def()["range"]) * 0.75 and los and tgt is Hunter and randf() < 0.4:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	if not great.is_empty() and los:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["fire"] = true; return
	# Arrow Rain across their path (lead them a little), from mid range
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["reach"]) + 1.0 and dist > 3.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.4; h.inp["sig"] = true; return
	# snare first: a root pins them (and feeds Focus) for the Deadeye
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 13.0 and not pinned(tgt):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 9.0 or randf() < 0.35: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.15
	# grapple away from a brawler, or up onto a ledge
	if dist < 3.0 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true
