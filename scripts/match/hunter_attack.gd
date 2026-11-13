class_name HunterAttack
extends RefCounted
## A hunter's own weapon (Hunter.atk): what the attack key does each frame (Hunter.sim), guns (sway,
## bloom, a sniper's wind-up, a minigun's spin, bursts), bows (draw and loose), melee combos, lunges and
## charged attacks, and reloads. The weapon state the animation, HUD, Net and kits read (shot_n, wbloom,
## warm_t, spin, mel_hold, swing_t, combo_i...) stays on Hunter; this keeps only its own timers.

const SWAY := [0.0, 0.6, -0.4, 1.0, -0.8, 0.3, -1.0, 0.5]   # fixed sway pattern, x spread per shot

var h: Hunter
var fire_was := false
var swing_buf := 0.0           # a tap that came in mid-swing, played as soon as the swing ends
var lunge_n := 0               # lunges in a row; each one in a short window goes 25% less far
var lunge_at := -9.0
var burst_left := 0            # rounds of the current burst still to fire
var burst_t := 0.0             # s until the next round of the burst

func _init(hunter: Hunter) -> void:
	h = hunter

func can_fire() -> bool:
	if Hex.active(h) or Capture.active(h):
		return false
	if h.ak and not h.ak.can_shoot():
		return false
	var busy: bool = h.drink_t > 0.0 or h.reload_t > 0.0 or h.downed or h.stun_t > 0.0
	if h.ak and h.roll_t > 0.0 and h.ak.fires_in_dash() and not busy:
		return true          # shooting from a held slide
	var glide_shut: bool = h.gliding and not (h.ak and h.ak.fires_in_glide())
	return not (busy or h.roll_t > 0.0 or h.out or h.grap.size() > 0 or glide_shut or h.charge.size() > 0)

## Called every frame with the attack key's state; decides what that means for this weapon.
func trigger(dt: float) -> void:
	var held: bool = h.inp["fire"]
	if h.ak and h.ak.lmb_override(held, dt):
		return          # the archetype runs this weapon's attack itself (the Bulwark's mace: throw / smash)
	if h.wpn.get("melee", false):
		swing_buf = maxf(0.0, swing_buf - dt)
		if swing_buf > 0.0 and h.fire_cd <= 0.0 and can_fire():
			swing_buf = 0.0
			fire()
		if h.ctrl != "local" or not h.wpn.has("charge_time"):
			if held: fire()
			return
		# tap for the combo, hold to charge
		var ct := float(h.wpn["charge_time"])
		var pressed := held and not fire_was
		fire_was = held
		if held:
			if not can_fire() or h.fire_cd > 0.0:
				if pressed: swing_buf = 0.3     # tapped mid-swing: it plays when this one ends
				return
			h.mel_hold += dt
			if h.mel_hold >= ct + 0.35:
				# held well past full: it goes off by itself, and keeps charging the next one
				_charged_attack()
		else:
			if h.mel_hold >= ct and can_fire():
				_charged_attack()
			elif h.mel_hold > 0.0:
				if h.fire_cd > 0.0: swing_buf = 0.3
				else: fire()
			h.mel_hold = 0.0
		return
	if h.wpn.has("draw"):
		_trigger_bow(held, dt)
		return
	if h.wpn.has("spin_up"):
		if held and can_fire() and h.ammo > 0:
			h.spin = minf(1.0, h.spin + dt / float(h.wpn["spin_up"]))
			if h.spin >= 1.0:
				h.spun_t += dt
				fire()
		else:
			h.spin = maxf(0.0, h.spin - dt / 0.5)
			h.spun_t = 0.0
			if held and h.ammo <= 0: start_reload()
		return
	if held:
		fire()

## A bow: hold to draw, let go to loose. Only the button coming up looses a player's arrow: a cooldown
## never looses it, and a stun or glide cancels the draw with no shot (a dash too, unless its DashFlow hold
## row keeps it). A bot lets go by itself.
func _trigger_bow(held: bool, dt: float) -> void:
	if h.draw_t >= 0.0 and not can_fire() and h.ak and h.ak.flow.pauses_hold("lmb"):
		if held:
			h.draw_t += dt * h.ak.draw_rate()      # a dash whose row keeps the draw: it charges on through it,
		return          # and a release in it looses when it ends
	var can_draw: bool = can_fire() and h.ammo > 0
	if h.draw_t >= 0.0 and not held:
		_loose()
		return
	if h.draw_t >= 0.0 and not can_draw:
		h.draw_t = -1.0
		return
	if held and can_draw and (h.draw_t >= 0.0 or h.fire_cd <= 0.0):
		_draw_step(dt)
	elif held and h.ammo <= 0:
		start_reload()

func _draw_step(dt: float) -> void:
	var top := float((h.wpn["draw"][-1] as Array)[0])
	if h.draw_t < 0.0:
		h.draw_t = 0.0
		h.m.sfx("charge", h.pos, -12.0 if h.is_local() else -16.0, 1.6)
	h.draw_t += dt * (h.ak.draw_rate() if h.ak else 1.0)
	if h.ctrl == "bot" and h.draw_t >= top + 0.05:
		_loose()

## Looses a drawn arrow: the draw stage reached sets damage, range and speed.
func _loose() -> void:
	var t := h.draw_t
	h.draw_t = -1.0
	if not can_fire() or h.ammo <= 0 or t < float(h.wpn.get("draw_min", 0.0)):
		return          # (let go inside draw_min it is a mashed click: no arrow, the next press draws afresh)
	var stages: Array = h.wpn.get("draw", [])
	var dmg := float(h.wpn.get("draw_early", 15.0))
	var rng := float(h.wpn["range"])
	var spd := float(h.wpn["speed"])
	for stg in stages:
		if t >= float(stg[0]):
			dmg = float(stg[1])
			rng = float(stg[2])
			spd = float(stg[3])
	if h.ak and h.ak.has_method("draw_bonus"):
		# the kit's stage rules (Hem: the perfect window, overdraw, where it lands)
		dmg *= float(h.ak.draw_bonus(t))
	var keep := h.wpn
	h.wpn = h.wpn.duplicate()
	h.wpn["dmg"] = dmg * h.wup_dmg
	h.wpn["range"] = rng
	h.wpn["speed"] = spd
	_release()
	h.wpn = keep
	if t >= float((stages[-1] as Array)[0]) if not stages.is_empty() else false:
		h.m.fx.flash(h.pos + Vector3(h.aim_dir().x * 0.7, 1.0, h.aim_dir().y * 0.7), keep["color"], 0.5, 0.06)

func charge_k() -> float:
	if not h.wpn.get("melee", false) or not h.wpn.has("charge_time") or h.mel_hold <= 0.12:
		return 0.0
	return clampf(h.mel_hold / float(h.wpn["charge_time"]), 0.0, 1.0)

func fire_slow() -> float:
	if h.draw_t >= 0.0:
		return float(h.wpn.get("draw_slow", 0.7))
	var firing: bool = h.fire_cd > 0.0 or h.warm_t > 0.0 or (h.spin > 0.0 and h.inp["fire"]) or charge_k() > 0.0
	if not firing:
		return 1.0
	return float(h.wpn.get("fire_slow", 1.0 if h.wpn.get("melee", false) else 0.8))

func fire() -> void:
	if not can_fire() or h.fire_cd > 0.0 or h.warm_t > 0.0:
		return
	if h.wpn.get("melee", false):
		_swing()
		return
	if h.ammo <= 0:
		start_reload()
		return
	if h.cloak_t > 0.0:
		h.cloak_t = 0.0
		h.m.sfx("cloak", h.pos, -8.0)
	h.idle_fire = 0.0
	h.reveal_t = maxf(h.reveal_t, 1.2)
	if float(h.wpn.get("warmup", 0.0)) > 0.0:
		# the sniper winds up with its laser showing, then fires
		h.warm_t = float(h.wpn["warmup"])
		h.fire_cd = 0.0
		h.m.sfx("charge", h.pos, -6.0 if h.is_local() else -12.0, 1.3)
		return
	_release()

## The round actually leaving the gun (straight away, or once a wind-up ends).
func _release() -> void:
	var rate: float = h.wpn["rate"] * (1.0 - minf(0.5, h.owner_stat("fire_rate") + h.buff("fire_rate")))
	h.fire_cd = rate
	h.idle_fire = 0.0
	h.ammo -= 1
	h.recoil = 1.0
	h.muzzle_t = 0.05
	burst_left = int(h.wpn.get("burst", 1)) - 1
	burst_t = float(h.wpn.get("burst_gap", 0.07))
	emit_shot()
	Oomph.on_fire(h)
	if h.ammo <= 0 and burst_left <= 0:
		start_reload()

func tick_weapon(dt: float) -> void:
	if h.warm_t > 0.0:
		h.warm_t -= dt
		if not can_fire() or h.ammo <= 0:
			h.warm_t = 0.0
		elif h.warm_t <= 0.0:
			h.warm_t = 0.0
			_release()
	# per-shot bloom recovers once you've stopped firing for a beat (an aimed-first gun snaps back to its aimed shot)
	if h.wbloom > 0.0 and h.idle_fire > float(h.wpn["rate"]) + 0.2:
		var drop: float = INF if h.wpn.get("aimed_first", false) else float(h.wpn.get("bloom_recover", 20.0)) * dt
		h.wbloom = maxf(0.0, h.wbloom - drop)
	if h.idle_fire > 0.35 or h.reload_t > 0.0:
		h.sus_n = 0
	if not h.strike_at_end.is_empty():
		if h.roll_t > 0.0 and not h.downed and h.stun_t <= 0.0:
			# the lunge curves to follow your aim
			h.roll_dir = h.roll_dir.slerp(h.aim_dir(), minf(1.0, dt * 6.0)).normalized()
		else:
			var st: Dictionary = h.strike_at_end
			h.strike_at_end = {}
			if not h.downed and h.stun_t <= 0.0:
				strike(float(st["dmg"]), float(st["reach"]), float(st["arc"]), float(st["kb"]), st)

## Burst weapons fire the rest of their burst on a short timer (see Hunter.sim).
func tick_burst(dt: float) -> void:
	if burst_left <= 0:
		return
	burst_t -= dt
	if burst_t > 0.0:
		return
	if h.ammo <= 0 or not can_fire():
		burst_left = 0
		return
	burst_left -= 1
	burst_t = float(h.wpn.get("burst_gap", 0.07))
	h.ammo -= 1
	h.recoil = 1.0
	h.muzzle_t = 0.05
	emit_shot()
	Oomph.on_fire(h)
	if h.ammo <= 0 and burst_left <= 0:
		start_reload()

## Melee: a wedge in front of you, a short step into it, and a combo whose last hit lands hardest.
## Swing again within the combo window to keep it going. Hold to charge a heavier attack instead.
func _swing() -> void:
	var cd: Array = h.wpn.get("combo_dmg", [])
	var cn: int = cd.size() if cd.size() > 0 else (h.wpn.get("combo", [1.0]) as Array).size()
	if h.m.time - h.swing_at > float(h.wpn["rate"]) + float(h.wpn.get("combo_reset", 0.6)):
		h.combo_i = 0
	var step := h.combo_i % cn
	var dmg: float = (float(cd[step]) if cd.size() > 0
		else float(h.wpn["dmg"]) * float((h.wpn.get("combo", [1.0]) as Array)[step]))
	var last: bool = step == cn - 1
	h.combo_i += 1
	h.swing_at = h.m.time
	h.fire_cd = float(h.wpn["rate"]) * (1.35 if last else 1.0)
	# a basic swing never moves you: you keep walking control (fire_slow), and gap-closers live on
	# right click (and in a deliberate held charge where a weapon has one)
	var kb := float(h.wpn["kb"]) * (1.5 if last else 1.0)
	strike(dmg, float(h.wpn["range"]), float(h.wpn.get("arc", 100.0)), kb, {"heavy": last})

## A step forward with the swing. Lunges close together get 25% shorter each time.
func lunge(dist: float) -> void:
	if dist <= 0.0 or not h.grounded:
		return
	if h.m.time - lunge_at > 1.2:
		lunge_n = 0
	var k := pow(0.75, lunge_n)
	lunge_n += 1
	lunge_at = h.m.time
	# the speed that covers about dist before the ground brake takes it back (to a walk while you hold a direction)
	var d2 := h.aim_dir()
	var moving := (h.inp["move"] as Vector2).length() > 0.1
	var want := HunterMove.slide_speed(dist * k, h.base_speed if moving else 0.0)
	var hv := HunterMove.push(Vector2(h.vel.x, h.vel.z), d2, want)
	h.vel.x = hv.x
	h.vel.z = hv.y

func _charged_attack() -> void:
	h.mel_hold = 0.0
	h.combo_i = 0
	h.swing_at = h.m.time
	h.fire_cd = float(h.wpn["rate"]) * 1.8
	var w: Dictionary = h.wpn
	var lunging: bool = w.has("charged_lunge")
	var st := {"dmg": float(w.get("charged_dmg", float(w["dmg"]) * 2.5)),
		"reach": float(w.get("charged_reach", float(w["range"]) * (0.85 if lunging else 1.0))),
		"arc": float(w.get("charged_arc", float(w.get("arc", 100.0)) * (0.5 if lunging else 1.0))),
		"kb": float(w.get("charged_kb", float(w["kb"]) * 2.0)),
		"stun": float(w.get("charged_stun", 0.0)), "heavy": true, "charged": true}
	if lunging:
		# a lunging stab: you travel, and the hit lands where the lunge ends (charged lunges don't decay)
		var t := 0.2
		h.roll_dir = h.aim_dir()
		h.roll_t = t
		h.roll_speed = float(h.wpn["charged_lunge"]) / t
		h.dash_is_ex = false
		h.shove = {}
		h.strike_at_end = st
		h.m.fx.dash_trail(h)
		h.m.sfx("dash", h.pos, -4.0, 0.7)
	else:
		strike(float(st["dmg"]), float(st["reach"]), float(st["arc"]), float(st["kb"]), st)

func strike(dmg: float, reach: float, arc_deg: float, kb: float, o := {}) -> void:
	h.idle_fire = 0.0
	h.reveal_t = maxf(h.reveal_t, 1.2)
	if h.cloak_t > 0.0:
		h.cloak_t = 0.0
	h.swing_t = 0.18
	h.swing_n += 1
	var dir := h.aim_dir()
	var heavy: bool = o.get("heavy", false)
	var arc := deg_to_rad(arc_deg)
	var a0 := atan2(dir.y, dir.x)
	var y := h.pos.y + 0.95 * float(h.cdat["scale"])
	var extra := {"kb": kb, "swing": "%s_%d" % [h.nid, h.swing_n], "melee": true,
		"kbi": float(h.wpn.get("kb_influence", 0.3))}
	if h.wpn.has("tip_bonus"):
		extra["tip"] = [reach * 0.7, float(h.wpn["tip_bonus"])]
	if float(o.get("stun", 0.0)) > 0.0: extra["stun"] = float(o["stun"])
	if h.crit_t > 0.0: extra["crit"] = true
	h._kin_riders(extra)
	Loot.rider(h, extra, dmg * h.m.dmg_mult(h))
	# the swing is a fan of very short, invisible strikes, so walls and terraces block it like shots
	var rays := 9 if arc_deg > 130.0 else 7
	for i in rays:
		var aa := a0 - arc * 0.5 + arc * float(i) / float(rays - 1)
		var st := Vector3(h.pos.x + cos(aa) * 0.25, y, h.pos.z + sin(aa) * 0.25)
		h.m.spawn_shot(h, st, Vector2(cos(aa), sin(aa)) * 40.0, dmg * h.m.dmg_mult(h),
			maxf(0.02, (reach - 0.25) / 40.0), 0.22, h.wpn["color"], extra)
	h.m.fx.slash(Vector3(h.pos.x, y - 0.15, h.pos.z), a0, arc, reach, h.wpn["color"], heavy)
	Oomph.on_fire(h, true)
	var vol := 0.0 if o.get("charged", false) else -4.0
	h.m.sfx(h.wpn["sfx"], h.pos, vol, (0.8 if heavy else 1.15) + randf() * 0.1)

func emit_shot() -> void:
	var dir := h.aim_dir()
	# no dice rolls: every shot goes where you aim. Fast guns sway in a fixed, learnable pattern,
	# wider as per-shot bloom builds up
	h.shot_n += 1
	var spread: float = float(h.wpn["spread"])
	var rng_add := 0.0
	if h.wpn.has("tighten_from_deg"):
		var tk := clampf(h.spun_t / float(h.wpn.get("tighten_time", 1.5)), 0.0, 1.0)
		spread = deg_to_rad(lerpf(float(h.wpn["tighten_from_deg"]), rad_to_deg(float(h.wpn["spread"])), tk))
		rng_add = float(h.wpn.get("spun_range", 0.0)) * tk
	var pel := int(h.wpn.get("pellets", 1))
	if pel <= 1:
		spread += deg_to_rad(h.wbloom)
	var a: float = atan2(dir.y, dir.x) + spread * 0.45 * float(SWAY[h.shot_n % SWAY.size()])
	var shot_y := h.pos.y + 0.95 * float(h.cdat["scale"])
	var start := Vector3(h.pos.x + cos(a) * 0.6, shot_y, h.pos.z + sin(a) * 0.6)
	var spd: float = h.wpn["speed"]
	if h.has_meta("zero_spread_t") and h.m.time < float(h.get_meta("zero_spread_t")):
		spread = 0.0            # a Thief's SMG right after a Shadow Step
		a = atan2(dir.y, dir.x)
	var rng: float = (float(h.wpn["range"]) + rng_add) * h.shot_range_k
	h.shot_range_k = 1.0
	var life: float = rng / spd
	var dmg: float = float(h.wpn["dmg"]) * h.m.dmg_mult(h)
	if h.wpn.has("nth"):
		h.nth_n += 1
		if h.nth_n % int(h.wpn["nth"][0]) == 0: dmg *= 1.0 + float(h.wpn["nth"][1])
	if h.wpn.has("sustain_loss"):
		dmg *= 1.0 - float(h.wpn["sustain_loss"]) * minf(1.0, float(h.sus_n) / float(h.wpn.get("sustain_rounds", 10)))
	h.sus_n += 1
	var extra := {"kb": h.wpn["kb"], "tracer": float(h.wpn.get("tracer", 1.0))}
	extra.merge(h.wpn.get("shot_x", {}), true)      # a weapon's own shot rules (Tether Lantern: through terrain)
	if h.wpn.has("decel"):
		# slugs slow down and stop at the weapon's range: v^2 = 2 a d
		extra["decel"] = float(h.wpn["decel"])
		spd = sqrt(2.0 * float(h.wpn["decel"]) * rng)
		life = spd / float(h.wpn["decel"]) + 0.05
	if h.wpn.has("close_mult"):
		extra["near"] = [float(h.wpn["close_mult"]), rng * 0.5]
	if h.wpn.has("far_mult"):
		extra["farf"] = [rng * float(h.wpn.get("far_start", 0.6)), float(h.wpn["far_mult"]), rng]
	if AimMode.take(h) == AimMode.CURSOR:
		life = AimMode.dist(h, rng) / spd      # lands at the cursor, clamped to range (scripts/match/aim/aim_mode.gd)
	if h.wpn.get("pierce", false):      # through everyone in line (Sparkle's bolts)
		extra["pierce"] = true
		extra["hitset"] = {}
	if h.wpn.has("boom"):
		extra["boom"] = h.wpn["boom"]
		extra["boom_kb"] = h.wpn["boom_kb"]
	if h.crit_t > 0.0:
		extra["crit"] = true
	Loot.rider(h, extra, dmg)
	h._kin_riders(extra)
	if pel > 1:
		# a shotgun throws the same fixed fan every time, wider with each shot in a row. However
		# few slugs land, the first one on a target still does a good share of the whole volley
		var fan: float = (deg_to_rad(float(h.wpn.get("fan_deg", 23.0)) + h.wbloom) if h.wpn.has("fan_deg")
			else float(h.wpn.get("fan", 0.4)))
		if h.wbloom == 0.0 and h.wpn.get("aimed_first", false):
			fan = 0.0           # the first volley of a burst goes straight down the aim line
		extra["pg"] = "%s_%d" % [h.nid, h.shot_n]
		extra["pn"] = pel
		extra["pf"] = float(h.wpn.get("pellet_floor", 1.0 / pel))
		for i in pel:
			var pa := a - fan * 0.5 + fan * float(i) / float(pel - 1)
			var p0 := Vector3(h.pos.x + cos(pa) * 0.6, shot_y, h.pos.z + sin(pa) * 0.6)
			h.m.spawn_shot(h, p0, Vector2(cos(pa), sin(pa)) * spd, dmg, life, h.wpn["size"], h.wpn["color"], extra)
	else:
		h.m.spawn_shot(h, start, Vector2(cos(a), sin(a)) * spd, dmg, life, h.wpn["size"], h.wpn["color"], extra)
	if h.wpn.has("bloom_deg"):
		h.wbloom = minf(float(h.wpn.get("bloom_max_deg", 6.0)), h.wbloom + float(h.wpn["bloom_deg"]))
	h.m.sfx(h.wpn["sfx"], h.pos, -2.0 if h.is_local() else -6.0)
	Juice.shot(h, start, Vector2(cos(a), sin(a)))

func start_reload() -> void:
	if h.reload_t > 0.0 or h.ammo >= int(h.wpn["mag"]) or h.downed:
		return
	if h.wpn.get("melee", false) or not h.wpn.has("reload"):
		return
	var quick := 0.7 if h.perk_n("quickhands") > 0 else 1.0
	h.reload_t = float(h.wpn["reload"]) * (1.0 - h.owner_stat("reload") - h.gear_stat("reload")) * quick
	h.m.sfx("reload", h.pos, -8.0)
