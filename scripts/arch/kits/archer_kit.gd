class_name ArcherKit
extends ArchKit
## Pin (id archer, light; docs/heroes/archer.md, hero sheet pin.md). Spirit Walk (Shift), Focus, Snare
## (tap: a rooting snare / Tripwire; hold: a charged Heavy Shot that pierces, knocks back and stuns into
## a wall; Plunge in the air), Hail Wall (E, a curved arc of rain at the cursor distance), and on X
## Starpiercer (level 6, PinUlt: three empowered piercing beams). R is the Merge.
## The bow (PinDraw): hold to draw through two stages with a V reticle that closes at each; tap and
## Empowered shots land at the cursor, Supercharged ones fly past it to max range; let go right as a stage
## comes up (a gold fletch burst) and the next draw is faster; hold too long and the arrow is overdrawn (half).
##
## The loop: snares root (Pin) and feed Focus -> full Focus arms the Deadeye (a lens glint and
## a thin aim line everyone sees, crosshairs over every pinned foe) -> the next shot is drawn at once,
## and into a rooted or stunned foe it's a Deadeye: a gold payoff hit with T4 hitstop and its own sound.

var rain := {}                 # the live Hail Wall: {a, b, t, tick, patter, tele}
var draw: PinDraw             # the bow's stages, reticle, perfect release and overdraw
var spirit: PinSpirit          # Shift: Spirit Walk
var fx: PinFx                  # Pin's pooled effects
var ult: PinUlt                # X: Starpiercer
var perfects: int:
	get: return draw.perfects if draw else 0
var trips: Array = []          # our live Tripwires (verbs trap dictionaries)
var pin_aim := false           # the Heavy Shot is being held (its gold V and growing bar show)
var high_t := 0.0              # re-checks high ground now and then
var on_high := false
var loosed := 0.0              # a Focus shot is in the air until this time (its hit can be a Deadeye)
var pin_until := {}            # foe instance id -> [ent, time]: rooted or stunned (plus a short grace)
var armed_at := -9.0           # the last "DEADEYE READY" pop (rate-limited)
var was_full := false
var glint: Node3D = null       # the lens glint at the bow and the thin aim line (full Focus)
var reticles := {}             # foe instance id -> node: crosshairs over pinned foes while Deadeye is armed
var deadeyes := 0              # Deadeyes landed (tests, demo)
var knock_healed := 0.0        # health the knock passive gave back (tests)
var sense_t := 0.0
var pins := 0                  # wall pins landed (tests)
var cremations := 0            # Heavy Shots that knocked a foe burning in the Hail Wall (tests)

func _setup() -> void:
	fx = PinFx.new(h)
	h.add_child(fx)
	self_nodes.append(fx)
	draw = PinDraw.new(self)
	ult = PinUlt.new(self)
	h.add_child(ult)
	self_nodes.append(ult)
	spirit = PinSpirit.new(self)

func full_ready() -> bool:
	return res >= res_max() - 0.01

func res_text() -> String:
	return "READY" if full_ready() else "%d" % int(res)

func ready_label() -> String:
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
	if t == null or t.team == h.team:
		return
	if String(o.get("src", "")) == "shot" and not o.has("ab"):
		_arrow_hit(t)
	if loosed <= 0.0:
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
	var opts := {"src": "abil", "ab": "utility", "tags": ["utility", "deadeye"], "payoff": true, "crit": true, "kb": dir * 5.0}
	t.hurt(float(rd.get("deadeye", 18.0)) * power("sec"), h, opts)
	deadeyes += 1
	play("pin_deadeye")
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
	sense_t -= dt
	if sense_t <= 0.0:
		sense_t = 0.3
		_sense_injured()
	_tick_glint(dt)
	_tick_reticles()
	net_pulse(dt, full)
	trips = trips.filter(func(t): return m.verbs.traps.has(t))
	if pin_aim and rmb_down:
		_heavy_tele()
	if not rain.is_empty():
		_tick_rain(dt)
	draw.tick()
	ult.tick(dt)
	spirit.tick(dt)
	spirit.tick_orbs(dt)
	_tag_shots()
	fx.tick_shots()

## Her bow hand carries its own tell (PinFx's fletch glint), so the shared charge orb stays off.
func charge_orb() -> bool:
	return false

## Her dash after-image: green fletch streaks instead of the shared ghost.
func dash_afterimage() -> bool:
	fx.afterimage(h.position, h.face, float(h.cdat.get("scale", 1.0)))
	return true

## X: Starpiercer, the next shots empowered.
func cast_ult() -> bool:
	return ult.cast()

func ult_running() -> bool:
	return ult.active()

## While Starpiercer is up the bow is the ult's: nock, then a beam (PinUlt.lmb).
func lmb_override(held: bool, dt: float) -> bool:
	return ult.lmb(held, dt)

## Hunter.trigger scales the bow's draw by this (the quick draw after a perfect release).
func draw_rate() -> float:
	return draw.rate()

## Hunter._loose asks once per arrow: where it goes and its damage factor (PinDraw.bonus).
func draw_bonus(t: float) -> float:
	return draw.bonus(t)

## Our shots the match just spawned get Pin's own look (PinFx): the bow's arrows by the kind PinDraw
## loosed, the Heavy Shot's gold arrow, the snare.
func _tag_shots() -> void:
	for s in m.shots:
		if s["by"] != h or (s["x"] as Dictionary).has("pin"):
			continue
		var x: Dictionary = s["x"]
		if x.get("cos", false):
			continue
		var kind := "arrow"
		if String(x.get("src", "")) == "abil":
			kind = "heavy" if float(s["r"]) >= 0.2 else "snare"
		elif draw.pending != "":
			kind = draw.pending
		fx.skin(s, kind)
	draw.pending = ""

## Passive, Hawk Sense: rivals under half health are seen through cover and fog within 22m.
func _sense_injured() -> void:
	var rd := res_def()
	for f in m.foes_of(h.team):
		var hurt_enough: bool = f.hp < f.max_hp * float(rd.get("sense_hp", 0.5))
		if f is Hunter and not f.dead and hurt_enough and h.flat_dist(f) < float(rd.get("sense_r", 22.0)):
			f.reveal_t = maxf(f.reveal_t, 0.4)

## Passive: a knock heals us (the dash comes back for every takedown, see DashReset).
func on_knock(t: Hunter, mine: bool) -> void:
	if not mine or not is_instance_valid(t): return
	var rd := res_def()
	var hp0 := h.hp
	h.heal(float(rd.get("knock_heal", 18.0)))
	knock_healed += h.hp - hp0
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("9fe0a8"), 14, 2.5, 0.5, -2.0)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "RUN DOWN", res_col(), true)
	play("pin_rundown")
	m.fx.ring(h.pos, 1.6, res_col(), 0.3)
	net_ring(h.pos, 1.6, res_col())

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
		if spirit.active(): spirit.end("hit")

## One of the bow's arrows hit: the spent-arrow pool skips it; a Supercharged one bursts in a teal X-star.
func _arrow_hit(t: Ent) -> void:
	fx.note_hit(t.pos)
	var kind := ""
	for sid in fx.live:
		var e: Dictionary = fx.live[sid]
		if (e["pos"] as Vector3).distance_to(t.pos) < 2.8: kind = String(e["kind"])
	if kind == "":
		kind = draw.last_kind          # a fast arrow can be gone from the pool on the step it lands
	var at := t.pos + Vector3(0, 1.0, 0)
	if kind == "super":
		fx.star(at, 1.6, PinFx.TEAL, 0.22, 0.8, PI * 0.25, 2.0)
		fx.fletch_burst(at, 1.2, Color("a8ffe0"), 0.05, 0.15, 0.0, 5.0)
		m.fx.burst(at, PinFx.TEAL, 18, 7.0, 0.35, 2.0, 1.2)
		m.sfx("pin_super_hit", t.pos, -2.0)
		Feel.shake(m, "t2", h, t.pos, t)
	elif kind in ["arrow", "tap"]:
		fx.star(at, 0.8, PinFx.GREEN, 0.1)

# ------------------------------------------------------------------ dash: Spirit Walk
func on_dash(use_ex: bool) -> bool:
	var ex := use_ex and not h.gliding
	if not spend_dash(ex):
		return true
	if ex:
		# the long dash (in the air, or out of charges): Pin's own flick and tumble, a green streak behind
		# 19 m/s, the base dash speed
		travel(float(h.cdat.get("ex_dist", 4.2)), 0.22, {"invuln": 0.1, "trail": "roll"}, true)
		play("pin_flick")
		st["last_dash"] = "flick"
		for i in 4:
			m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 0.8, 0), PinFx.GREEN, 4, 1.5, 0.3, 0.0, 0.9))
		return true
	CombatBus.ability_used.emit(h, "spirit_walk", "dodge")
	spirit.start(use_ex)
	return true

## While walking as a spirit she moves a little quicker.
## While walking as a spirit she moves quicker, quicker still inside something (wiki: +50 move speed in
## terrain); a draw right after a perfect release slows her less (wiki: perfect shots ease the self-slow).
func move_k() -> float:
	var k := 1.0
	if spirit and spirit.active():
		k = float(dash_def().get("inside_k", 1.35)) if spirit.inside else float(dash_def().get("walk_k", 1.15))
	if draw and draw.quick and h.draw_t >= 0.0:
		k *= float(h.wpn.get("perfect_slow", 0.85)) / maxf(0.05, float(h.wpn.get("draw_slow", 0.7)))
	return k

# ------------------------------------------------------------------ RMB: Snare
func rmb_hold_tick(t: float) -> void:
	if t > 0.15 and not pin_aim and not rmb_ctx.get("air", false):
		# the Heavy Shot's draw: the gold V and a gold bar growing from the bow (its own creak)
		play("arc_heavy_wind")
		pin_aim = true
		m.sfx("pin_heavy_draw", h.pos, -6.0 if h.is_local() else -10.0)
		_heavy_tele()

const HEAVY_GOLD := Color("ffc24a")

## The Heavy Shot held: the V tinted gold closing with the charge, a thick gold bar out of the bow that
## grows to 2 body heights, the cursor ring filling (AimKit; own player).
func _heavy_tele() -> void:
	var hk := heavy_k()
	AimKit.vee(h, "rmb_v", {"k": hk, "col": HEAVY_GOLD, "col2": Color("fff0b0"), "glint": hk * 0.5})
	AimKit.lane(h, "rmb_bar", {"len": 2.0 * AimKit.BH, "len0": 0.3, "k": hk, "width": 0.3, "fill": hk,
		"col": HEAVY_GOLD, "col2": Color("fff0b0")})
	AimKit.charge(h, hk, {"col": HEAVY_GOLD, "col2": Color("fff0b0")})
	fx.bow_glint_at(draw.bow_at(), 1.0 if hk >= 0.99 else 0.0, HEAVY_GOLD)

## The Heavy Shot charges from the hold threshold to full.
func rmb_charge_full() -> float:
	return float(rmb_def()["pin"]["full"])

func heavy_k() -> float:
	var pd: Dictionary = rmb_def()["pin"]
	var hold_t := float(rmb_def()["hold"])
	return clampf((rmb_t - hold_t) / maxf(0.05, float(pd["full"]) - hold_t), 0.0, 1.0)

## The Heavy Shot can be held up to 3 s after it's full before it looses by itself (wiki patch 20.11.24).
func rmb_auto_t() -> float:
	return float(rmb_def()["pin"].get("max_hold", 3.0))

## A Boki merge ends every hold and channel of this kit with no shot: the bow draw (Hunter.draw_t, cleared by
## MergeKit.drop_class_holds; its reticle here), the Heavy Shot's hold and its gold telegraph, and Spirit Walk
## (Hunter.spirit_t; ending inside something still puts her back where she entered).
func _drop_holds() -> void:
	rmb_down = false
	h.draw_t = -1.0
	_drop_tele()
	draw.drop()
	spirit.end("merge")
	if ult: ult.drop()
	if anim_id in ["arc_draw", "arc_over", "arc_heavy_wind", "pin_roll", "pin_walk", "pin_ult_nock"]:
		anim_id = ""

func _drop_tele() -> void:
	pin_aim = false
	fx.bow_glint_at(Vector3.ZERO, 0.0, HEAVY_GOLD)
	AimKit.hide(h, "rmb_v"); AimKit.hide(h, "rmb_bar")

func fire_rmb(c: Dictionary) -> void:
	_drop_tele()
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var sd := rmb_def()
	if c.get("air", false):
		play("arc_plunge")
		_plunge()
		return
	var target_aim := aim()
	if c.get("hold", false):
		play("arc_heavy")
		_pin(target_aim, clampf((float(c["t"]) - float(sd["hold"])) / maxf(0.05, float(sd["pin"]["full"]) - float(sd["hold"])), 0.0, 1.0))
		return
	play("arc_snare")
	var sn: Dictionary = sd["snare"]
	# full Focus, or with your Hail Wall falling: the snare roots for longer
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
		# the impact: a red-white burst, a white dust cloud as it's driven back, a white ring round it
		var at := f.pos + Vector3(0, 1.0, 0)
		fx.note_hit(f.pos)
		fx.star(at, 1.5 + 0.7 * k, Color("ff5a4a"), 0.14, 0.0, PI * 0.25, 2.0)
		m.fx.burst(at, Color("ff8a6a"), 14, 6.5, 0.3, 4.0, 1.2)
		m.fx.burst(at, Color("fff0e8"), 8, 4.0, 0.25, 4.0, 0.9)
		m.fx.dust(f.pos, 14)
		m.later(0.12, func(): if is_instance_valid(f): m.fx.ring(f.pos, 1.3, Color.WHITE, 0.3))
		m.sfx("pin_heavy_hit", f.pos, -3.0)
		# knocked while burning in the Hail Wall: Cremated (a burst of the blue fire)
		if not rain.is_empty() and _in_rain(f):
			cremations += 1
			f.hurt(float(e_def().get("cremate", 10.0)) * power("kin"), h, {"src": "abil", "ab": "signature", "tags": ["signature", "cremate"]})
			if "blight_t" in f: f.set("blight_t", maxf(float(f.get("blight_t")), float(e_def()["blight"]) + 1.5))
			m.fx.burst(f.pos + Vector3(0, 1.0, 0), Color("5aa8ff"), 18, 4.0, 0.5, -3.0, 1.2)
			m.fx.word(f.pos + Vector3(0, 2.4, 0), "CREMATED", Color("8ac8ff"), false)
		# driven into terrain within 3m: pinned (a stun), and the shot lines up: full Focus
		if _wall_behind(f, dir, float(pd["wall"])):
			pins += 1
			add_focus(res_max())
			f.hurt(float(pd.get("wall_dmg", 12.0)) * k * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "pin"], "heavy": true})
			m.later(0.12, func():
				if is_instance_valid(f) and not f.dead:
					f.hurt(0.1, h, {"stun": float(pd["stun"]), "src": "abil", "ab": "utility", "tags": ["utility", "pin"], "exploit": true, "dr": true})
					m.fx.word(f.pos + Vector3(0, 2.2, 0), "PINNED", Feel.cat_color("control"), true)
					m.fx.dust(f.pos, 10)
					Feel.shake(m, "t3", h, f.pos, f))
	run(stg, cx("rmb", "heavy_shot", a, extra))
	m.sfx("pin_heavy", h.pos, lerpf(-6.0, 0.0, k), lerpf(1.15, 0.9, k))
	var d := h.aim_dir()
	# a small pink crescent swipe at the feet on the release
	m.fx.slash(h.pos + Vector3(0, 0.15, 0), atan2(d.y, d.x), PI * 0.6, 1.1, Color("ff9ad8"), false)
	fx.fletch_burst(h.pos + Vector3(d.x * 0.7, 1.1, d.y * 0.7), 0.6 + 0.5 * k, HEAVY_GOLD, 0.05, 0.1, 0.0, 5.0)
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

# ------------------------------------------------------------------ E: Hail Wall
## A wall of falling arrows on a curved arc round you (hero sheet: Rain of Arrows): centred on your aim at
## the cursor distance (clamped to rmin..reach), "deg" wide and "width" deep. Lobbed up first ("tell" s,
## everyone sees the arc), then it rains for "time" s: damage over time, a slow and a blight (healing
## barely takes, the blue burn) on foes inside.
func in_e() -> bool:
	return not rain.is_empty()

func _arc_deg() -> float:
	return float(e_def().get("deg", 120.0)) * (1.3 if rank("kin") >= 3 else 1.0)

func cast_e() -> bool:
	var ed := e_def()
	var d := h.aim_dir()
	var radius := clampf(AimMode.cursor_dist(h), float(ed.get("rmin", 2.0)), float(ed["reach"]))
	var c := AimMode.ground(m, h.pos + Vector3(d.x, 0, d.y) * radius)
	var tell := float(ed["tell"])
	var center := h.pos
	# the arrows go up first (everyone sees the arc), then the rain starts
	AimKit.arc_wall(h, "e", {"center": center, "dir": d, "radius": radius, "deg": _arc_deg(), "thick": float(ed["width"]), "panels": 7, "all": true, "dur": tell, "col": col_of(ed)})
	for i in 5:
		var u := (float(i) - 2.0) / 2.0 * deg_to_rad(_arc_deg()) * 0.4
		var dv := d.rotated(u)
		m.spawn_shot(h, h.pos + Vector3(0, 1.4, 0), dv * maxf(4.0, radius / tell), 0.0, tell, 0.12, col_of(ed), {"lob": 3.5, "cos": true})
	fx.lob(h.pos + Vector3(0, 1.6, 0), d)
	m.sfx("pin_hail", h.pos, -2.0)
	net_ring(c, 1.6, col_of(ed))
	play("arc_hail")
	var t := float(ed["time"])
	rain = {"center": center, "c": c, "d": d, "radius": radius, "t": t + tell, "start": tell, "tick": 0.0, "patter": 0.0}
	e_t = t + tell
	return true

func _in_rain(f: Ent) -> bool:
	var ed := e_def()
	return AimMode.in_arc(rain["center"], rain["d"], float(rain["radius"]), _arc_deg(), float(ed["width"]), f.pos, f.r) and absf(f.pos.y - (rain["c"] as Vector3).y) < 2.5

func _tick_rain(dt: float) -> void:
	var ed := e_def()
	rain["t"] = float(rain["t"]) - dt
	if float(rain["t"]) <= 0.0:
		rain = {}
		fx.rain_off()
		return
	if float(rain["start"]) > 0.0:
		rain["start"] = float(rain["start"]) - dt
		if float(rain["start"]) <= 0.0:
			fx.rain_on(rain["center"], rain["d"], float(rain["radius"]), _arc_deg(), float(rain["t"]))
			m.sfx("pin_rain", rain["c"], -3.0)
		return
	rain["patter"] = float(rain["patter"]) - dt
	if float(rain["patter"]) <= 0.0:
		rain["patter"] = randf_range(0.08, 0.14)
		m.sfx("pin_patter", rain["c"], -12.0, randf_range(0.85, 1.25))
	var inside: Array = []
	for f in m.foes_of(h.team):
		if f.hittable() and _in_rain(f): inside.append(f)
	fx.burn(inside)
	rain["tick"] = float(rain["tick"]) - dt
	if float(rain["tick"]) > 0.0:
		return
	rain["tick"] = float(ed["every"])
	var stg := stage("e", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": 0.8, "strength": float(ed["slow"])}]})
	for f in inside:
		KinExec.apply_foe(stg.effects, f, cx("e", "hail_wall", f.pos, {"at": f.pos}), f.pos, stg)
		if "blight_t" in f: f.set("blight_t", maxf(float(f.get("blight_t")), float(ed["blight"])))

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# Deadeye armed and someone pinned in range: loose it at them
	if full_ready() and los and dist < 15.0 and pinned(tgt):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["fire"] = true
		return
	# Hail Wall across their path (lead them a little), from mid range
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and dist < float(e_def()["reach"]) + 1.0 and dist > 3.0 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(tgt.vel.x, 0, tgt.vel.z) * 0.4; h.inp["sig"] = true; return
	# snare first: a root pins them (and feeds Focus) for the Deadeye
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and dist < 13.0 and not pinned(tgt):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		if dist > 9.0 or randf() < 0.35: bot_hold["rmb"] = float(rmb_def()["hold"]) + 0.15
	# Spirit Walk away from a brawler
	if dist < 3.0 and h.dashes >= 1.0 and randf() < 0.2:
		h.inp["aim"] = h.pos - Vector3(h.dir_to(tgt).x, 0, h.dir_to(tgt).y) * 4.0
		h.inp["dash"] = true
