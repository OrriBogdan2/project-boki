class_name JuggernautKit
extends ArchKit
## Juggernaut (heavy), kits2: a greatsword bruiser built on a Brall-style baseline (SUPERVIVE;
## mechanics only, the names, numbers, art and sounds are ours). docs/ARCHETYPES.md "Kit loops".
##
## - Passive, Rage: damage you deal heats it; it grants bonus damage, dash haste and ability haste.
##   At 100 you're Enraged (the red shell, the hunter swells): the next Smash is a Rage Smash (the
##   payoff: T4, pay_rage). A knock heals you and refills Rampage.
## - LMB (Greatsword): quick slashes; hold to charge a Searing Wave that rolls through a line.
## - RMB, Smash (adaptive): tap a heavy slam (more to the wounded), hold a charged lunge, in the air a
##   downward slam that slows and stuns the centre.
## - Dash, Rampage: a 2-charge dash attack; its tip hits hardest.
## - E, Warchain: chain a foe (blighted, leashed) or a wall; press again to haul yourself to it.
## - R, Doomfall: invulnerable as you rise, then a crushing strike that heals you; a knock resets it.

var enraged_t := 0.0
var lost := 0.0                # health lost toward the next Rage step
var aura: Node3D = null        # the Enraged look: a red shell, a glow, the hunter grown bigger
var heat: Node3D = null        # the heat glowing through the pauldrons as Rage builds
var grow := 0.0                # 0..1 how far into the Enraged form the model is
var lmb_t := -1.0              # how long the attack key has been held with the greatsword (-1: not)
var lmb_was := false
var lmb_buf := 0.0
var combo_i := 0
var slash_at := -9.0
var bot_wave_t := 0.0
var lunge := {}                # the running Lunge: {end, dir, dmg, stun, emp, hit}
var chain := {}                # the Warchain: {target, pos, node, yank}
var doom := {}                 # Doomfall's wind-up: {from, land, tele}
var doom_hit := {}             # foe id -> when Doomfall hit them (a knock within 2s resets it)
var rage_smashes := 0          # (tests, demo)
var waves := 0
var tips := 0
var dooms := 0
var doom_resets := 0
var reels := 0

func full_ready() -> bool:
	return enraged_t > 0.0

func res_frac() -> float:
	return 1.0 if enraged_t > 0.0 else clampf(res / res_max(), 0.0, 1.0)

func res_text() -> String:
	return "ENRAGED" if enraged_t > 0.0 else "%d" % int(res)

func ready_label() -> String:
	return "RAGE SMASH READY" if enraged_t > 0.0 else ""

## How hot it is, 0..1 (Enraged counts as all the way).
func heat_k() -> float:
	return res_frac()

func gain_rage(v: float) -> void:
	if enraged_t > 0.0:
		return
	add_res(v)
	touch_res()
	if res >= res_max():
		enraged_t = float(res_def().get("enraged_t", 5.0))
		res = res_max()
		_enrage_fx()

## Becoming Enraged: a roar, a red shockwave, and the hunter visibly swells into a red, steaming form
## (everyone sees it: that's the "back off or bait it out" read).
func _enrage_fx() -> void:
	var rc := res_col()
	m.sfx("knock", h.pos, 0.0, 0.6)          # the roar, audible within 25m
	m.sfx("charge", h.pos, -3.0, 0.45)
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "ENRAGED", rc, true)
	m.fx.ring(h.pos, 2.8, rc, 0.45)
	m.fx.ring(h.pos, 1.4, Color(1, 0.9, 0.8, 0.9), 0.25)
	m.fx.burst(h.pos + Vector3(0, 1.2, 0), rc, 30, 6.0, 0.6, -2.0, 1.4)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local():
		if m.hud: m.hud.flash(rc, 0.15)
		h._ab_feedback("sec", "ready")
	net_ring(h.pos, 2.8, rc)
	_make_aura()

func _make_aura() -> void:
	if aura and is_instance_valid(aura):
		return
	aura = Node3D.new()
	var rc := res_col()
	var sh := MeshInstance3D.new()
	sh.mesh = Models.sphere(0.95, 16)
	sh.material_override = Models.glow_mat(Color(rc, 0.16))
	sh.scale = Vector3(1.0, 1.35, 1.0)
	sh.position.y = 1.05
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.name = "Shell"
	aura.add_child(sh)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.cyl(1.05, 1.05, 0.04, 24)
	ring.material_override = Models.glow_mat(Color(rc, 0.45))
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(ring)
	var lt := OmniLight3D.new()
	lt.light_color = rc
	lt.light_energy = 1.6
	lt.omni_range = 3.5
	lt.position.y = 1.2
	aura.add_child(lt)
	h.add_child(aura)

func _drop_aura() -> void:
	if aura and is_instance_valid(aura):
		aura.queue_free()
	aura = null

## Spending the Rage: the shell bursts outward and the hunter shrinks back.
func _spend_fx() -> void:
	var rc := res_col()
	m.fx.ring(h.pos, 3.4, rc, 0.4)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), rc, 26, 7.0, 0.5, 4.0, 1.3)
	_drop_aura()

func _tick_look(dt: float) -> void:
	var want := 1.0 if enraged_t > 0.0 else 0.0
	grow = move_toward(grow, want, dt * (6.0 if want > grow else 3.0))
	if h.model:
		h.model.scale = Vector3.ONE * (1.0 + 0.16 * grow)
	if aura and is_instance_valid(aura):
		var sh := aura.get_node_or_null("Shell") as MeshInstance3D
		if sh: sh.scale = Vector3(1.0, 1.35, 1.0) * (1.0 + 0.06 * sin(m.time * 10.0))
		if randf() < dt * 14.0:
			for sx in [-0.45, 0.45]:
				m.fx.burst(h.pos + Vector3(sx, 1.75, 0), res_col(), 2, 1.6, 0.5, -3.0, 0.9)
	if enraged_t <= 0.0 and aura:
		_drop_aura()
	# the heat: a red glow at the shoulders that grows with Rage (everyone sees how hot it is)
	if heat == null or not is_instance_valid(heat):
		heat = own_node()
		var lt := OmniLight3D.new()
		lt.light_color = res_col()
		lt.omni_range = 2.4
		heat.add_child(lt)
	var hk := heat_k()
	heat.visible = hk > 0.15 and tells_visible() and enraged_t <= 0.0
	if heat.visible:
		heat.global_position = h.position + Vector3(0, 1.85 * float(h.cdat.get("scale", 1.0)), 0)
		(heat.get_child(0) as OmniLight3D).light_energy = 0.4 + 1.6 * hk * (1.0 + 0.15 * sin(m.time * 7.0))
		if hk >= 0.5 and randf() < dt * 6.0 * hk:
			for sx in [-0.42, 0.42]:
				m.fx.burst(h.pos + Vector3(sx, 1.7, 0), res_col(), 1, 1.0, 0.45, -3.0, 0.7)

func _tick(dt: float) -> void:
	_tick_look(dt)
	var rd := res_def()
	if enraged_t > 0.0:
		enraged_t -= dt
		if enraged_t <= 0.0:
			enraged_t = 0.0; res = 0.0
	elif res_wait <= 0.0:
		add_res(-float(rd.get("decay", 9.0)) * dt)
	# Rage's haste: cooldowns and dash charges come back faster the hotter you are
	var hk := heat_k()
	if hk > 0.0:
		for k in ["rmb", "e"]:
			cd[k] = maxf(0.0, float(cd[k]) - dt * float(rd.get("ab_haste", 0.35)) * hk)
		if h.dashes < h.max_dashes():
			h.dashes = minf(h.max_dashes(), h.dashes + dt / h.dash_regen() * float(rd.get("dash_haste", 0.5)) * hk)
	if lmb_buf > 0.0: lmb_buf -= dt
	if not lunge.is_empty(): _tick_lunge()
	if not chain.is_empty(): _tick_chain(dt)
	if not doom.is_empty(): _tick_doom()
	net_pulse(dt, enraged_t > 0.0, 1.4)

func on_deal(t: Ent, dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var rd := res_def()
	var k := 0.4 if String(o.get("src", "")) == "burn" else 1.0
	gain_rage(maxf(float(rd.get("min_hit", 2.0)) * k, dmg * float(rd.get("per_dmg", 0.55)) * k))

func on_take(_by: Ent, dmg: float, _o: Dictionary) -> void:
	lost += dmg
	var step := h.max_hp * 0.1
	while lost >= step and step > 0.0:
		lost -= step
		gain_rage(float(res_def().get("per_10pct", 5.0)))

func outgoing(_t: Ent, dmg: float, _o: Dictionary) -> float:
	var rd := res_def()
	return dmg * (1.0 + float(rd.get("dmg_k", 0.12)) * heat_k() + (float(rd.get("enraged_dmg", 0.2)) if enraged_t > 0.0 else 0.0))

func move_k() -> float:
	return 0.55 if lmb_t > float(lmb_def().get("tap", 0.22)) else 1.0

## A knock (ours or one we helped): a heal, Rampage refilled, and Doomfall back if it hit them.
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	h.heal(h.max_hp * float(rd.get("heal_knock", 0.15)) * (1.0 if mine else 0.5))
	h.dashes = h.max_dashes()
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 16, 2.5, 0.5, -2.0)
	var key := t.get_instance_id() if is_instance_valid(t) else -1
	if doom_hit.has(key) and m.time - float(doom_hit[key]) <= float(r_def().get("reset_t", 2.0)):
		doom_hit.erase(key)
		cd["r"] = 0.0
		doom_resets += 1
		m.fx.word(h.pos + Vector3(0, 2.8, 0), "DOOMFALL RESET", col_of(r_def()), true)
		m.fx.ring(h.pos, 2.0, col_of(r_def()), 0.35)
		m.sfx("ab_ready", h.pos, -2.0, 0.8)
		if h.is_local(): h._ab_feedback("r", "ready")
		net_ring(h.pos, 2.0, col_of(r_def()))

# ------------------------------------------------------------------ LMB: Greatsword (slashes / Searing Wave)
func lmb_def() -> Dictionary:
	return d.get("lmb", {})

func _wk() -> float:
	return float(Data.RARITY[clampi(h.wrar, 0, Data.RARITY.size() - 1)]["dmg"]) * m.dmg_mult(h)

func wave_k() -> float:
	var ld := lmb_def()
	return clampf((lmb_t - float(ld["tap"])) / maxf(0.05, float(ld["full"]) - float(ld["tap"])), 0.0, 1.0)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "greatsword":
		return false
	var ld := lmb_def()
	var pressed := held and not lmb_was
	lmb_was = held
	if not h.can_fire():
		if lmb_t >= 0.0:
			lmb_t = -1.0; h.mel_hold = 0.0
		return true
	if h.ctrl != "local":
		# a bot: slashes up close, sometimes a Searing Wave from mid range
		if lmb_t >= 0.0:
			lmb_t += dt
			h.mel_hold = wave_k() if lmb_t > float(ld["tap"]) else 0.0
			if lmb_t >= bot_wave_t: _wave()
			return true
		if held and h.fire_cd <= 0.0:
			var tg := _bot_target()
			if tg and h.flat_dist(tg) > 4.0 and h.flat_dist(tg) < 9.5 and randf() < 0.4:
				lmb_t = 0.0
				bot_wave_t = randf_range(float(ld["tap"]) + 0.3, float(ld["full"]) + 0.1)
			else:
				_slash()
		return true
	if held:
		if lmb_t < 0.0:
			if h.fire_cd > 0.0:
				if pressed: lmb_buf = 0.25
				return true
			lmb_t = 0.0
		lmb_t += dt
		if lmb_t > float(ld["tap"]): h.mel_hold = wave_k()
		if lmb_t >= float(ld["full"]) + 0.5: _wave()      # held well past full: it goes by itself
	elif lmb_t >= 0.0:
		if lmb_t < float(ld["tap"]): _slash()
		else: _wave()
	elif lmb_buf > 0.0 and h.fire_cd <= 0.0:
		lmb_buf = 0.0
		_slash()
	return true

func _bot_target() -> Ent:
	var best: Ent = null; var bd := 12.0
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < bd: bd = h.flat_dist(f); best = f
	return best

## A quick slash, a 3-hit combo (the third hits harder), strongest on the tip.
func _slash() -> void:
	var ld := lmb_def()
	lmb_t = -1.0
	h.mel_hold = 0.0
	if m.time - slash_at > float(ld["combo_reset"]): combo_i = 0
	var cb: Array = ld["combo"]
	var i := combo_i % cb.size()
	combo_i += 1
	slash_at = m.time
	var last := i == cb.size() - 1
	h.fire_cd = float(ld["rate"]) * (1.4 if last else 1.0)
	h._strike(float(cb[i]) * _wk() / m.dmg_mult(h), float(ld["reach"]), float(ld["arc"]), float(ld["kb"]) * (1.6 if last else 1.0), {"heavy": last})
	if last:
		m.fx.dust(h.pos + Vector3(h.aim_dir().x, 0, h.aim_dir().y) * 1.6, 6)

## The Searing Wave: a held, charged wave of fire that rolls through everyone in a line (full: it
## burns and slows).
func _wave() -> void:
	var ld := lmb_def()
	var k := wave_k()
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(ld["wave_rate"])
	waves += 1
	var full := k >= 0.99
	var rng := lerpf(float(ld["wave_range"][0]), float(ld["wave_range"][1]), k)
	var size := lerpf(float(ld["wave_size"][0]), float(ld["wave_size"][1]), k)
	var effs: Array = [{"type": "damage", "amount": lerpf(float(ld["wave_dmg"][0]), float(ld["wave_dmg"][1]), k)}, {"type": "push", "strength": lerpf(3.0, 6.0, k), "from": "caster"}]
	if full:
		effs.append({"type": "damage", "amount": float(ld["wave_burn"]) * 2.0, "over": 2.0})
		effs.append({"type": "slow", "duration": 1.0, "strength": float(ld["wave_slow"])})
	var stg := StageSpec.parse({"delivery": {"type": "projectile", "speed": float(ld["wave_speed"]), "range": rng, "size": size}, "effects": effs, "modifiers": [{"type": "pierce", "count": 6}]}, "", GrammarReport.new())
	var c := KinExec.make_cx(m, h, h.kin, h, aim(), _wk(), "primary", "searing_wave")
	c["silent"] = true
	KinExec.run_stage(stg, c)
	# the fire rolling along its line: a glowing crescent of flame everyone sees travel
	var dv := h.aim_dir()
	var from := h.pos
	var wn := own_node()
	var crest := MeshInstance3D.new()
	crest.mesh = Models.box(size * 2.6, 0.75 + 0.5 * k, 0.5)
	crest.material_override = Models.glow_mat(Color(Color("ff7a3a").lerp(res_col(), 0.5 if full else 0.0), 0.85))
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wn.add_child(crest)
	var core := MeshInstance3D.new()
	core.mesh = Models.box(size * 1.6, 0.4 + 0.3 * k, 0.25)
	core.material_override = Models.glow_mat(Color(1.0, 0.92, 0.7, 0.95))
	core.position.z = -0.15
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wn.add_child(core)
	wn.rotation.y = atan2(dv.x, dv.y)
	var a0 := from + Vector3(dv.x * 0.8, 0.45, dv.y * 0.8)
	var a1 := from + Vector3(dv.x * rng, 0.45, dv.y * rng)
	wn.global_position = a0
	var tw := wn.create_tween()
	tw.tween_property(wn, "global_position", a1, (rng - 0.8) / float(ld["wave_speed"]))
	tw.parallel().tween_property(wn, "scale", Vector3(1.25, 1.0, 1.0), (rng - 0.8) / float(ld["wave_speed"]))
	tw.tween_callback(func(): if is_instance_valid(wn): wn.queue_free())
	var steps := int(rng / 1.2)
	for s in steps:
		var p := from + Vector3(dv.x, 0, dv.y) * (1.0 + 1.2 * s)
		m.later(1.2 * s / float(ld["wave_speed"]), func():
			m.fx.burst(p + Vector3(0, 0.5, 0), res_col() if full else Color("ffb070"), 6 + int(6 * k), 2.5 + 2.0 * k, 0.4, -4.0, 0.9 + 0.6 * k, Vector3.UP, 50.0))
	m.fx.slash(h.pos + Vector3(0, 0.6, 0), atan2(dv.y, dv.x), deg_to_rad(70.0), 2.6, Color("ffb070"), true)
	m.sfx("cleave", h.pos, -1.0, 0.7)
	m.sfx("ab_blast", h.pos, -5.0 if not full else -2.0, 1.2 - 0.3 * k)
	h.swing_t = 0.18; h.swing_n += 1
	Oomph.on_fire(h, true)
	Feel.shake(m, "t3" if full else "t2", h, h.pos)
	net_bolt(h.pos + Vector3(0, 0.6, 0), h.pos + Vector3(dv.x * rng, 0.6, dv.y * rng), Color("ff8a4a"))

# ------------------------------------------------------------------ dash: Rampage
func on_dash(use_ex: bool) -> bool:
	if not lunge.is_empty() or not doom.is_empty():
		return true
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)), {"invuln": 0.08, "trail": "dust"}, true)
		return true
	if not spend_dash(false):
		return true
	var dd := dash_def()
	var t := float(dd["time"])
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	travel(float(dd["dist"]), t, {"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "shove_dmg": float(dd["hit_dmg"]) * pk, "trail": "dust"})
	st["last_dash"] = "rampage"
	m.later(t * 0.85, func(): if is_instance_valid(h) and not h.downed: _tip())
	m.sfx("ab_whirr", h.pos, -4.0, 0.7)
	return true

## The tip of the Rampage: the sweet spot, a short arc at the end of the dash.
func _tip() -> void:
	var dd := dash_def()
	var dv := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	var at := h.pos + Vector3(dv.x, 0, dv.y) * 0.9
	var hit := false
	for f in foes_in(at, float(dd["tip_r"])):
		hit = true
		f.hurt(float(dd["tip_dmg"]) * power("dash"), h, {"src": "abil", "ab": "dodge", "tags": ["dodge", "tip"], "kb": dv * float(dd["tip_kb"]), "wallstun": float(dd["tip_stun"]) + (0.4 if rank("dash") >= 3 else 0.0), "melee": true, "crit": true})
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "TIP", res_col(), false)
	m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dv.y, dv.x), deg_to_rad(100.0), 2.2, col_of(dd), true)
	if hit:
		tips += 1
		m.sfx("cleave", at, -2.0, 0.9)
		Feel.shake(m, "t3", h, at)
		if h.is_local(): Oomph.punch_dir(m, dv, 0.2)
		net_ring(at, 1.4, col_of(dd))

# ------------------------------------------------------------------ RMB: Smash (tap / hold Lunge / air)
func rmb_charge_full() -> float:
	return float(rmb_def().get("full_t", 0.9))

func rmb_auto_t() -> float:
	return rmb_charge_full() + 0.4

func lunge_k(t: float) -> float:
	var sd := rmb_def()
	return clampf((t - float(sd["hold"])) / maxf(0.05, float(sd["full_t"]) - float(sd["hold"])), 0.0, 1.0)

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not spend_rmb(): return
	var emp: bool = c.get("full", false) and enraged_t > 0.0
	if emp:
		enraged_t = 0.0; res = 0.0      # the Rage Smash spends the rage
		_spend_fx()
		rage_smashes += 1
	if c.get("air", false):
		_meteor(emp)
	elif c.get("hold", false):
		_lunge(lunge_k(float(c.get("t", 0.0))), emp)
	else:
		_slam(emp)

## A Rage Smash landing: the payoff (word, T4 shake, pay_rage, camera punch).
func _rage_payoff(at: Vector3, victim: Ent) -> void:
	payoff_fx(at, "RAGE SMASH", res_col(), "pay_rage", h.aim_dir(), victim)

## The tap: a heavy overhead slam; the wounded (under 40%) take more (BREAK).
func _slam(emp: bool) -> void:
	var sd := rmb_def()
	var sl: Dictionary = sd["slam"]
	var rg: Dictionary = sd["rage"]
	var dk := 1.0 + (float(rg["dmg_k"]) if emp else 0.0)
	var effs: Array = [{"type": "damage", "amount": float(sl["dmg"]) * dk}, {"type": "push", "strength": minf(16.0, float(sl["push"]) * (float(rg["push_k"]) if emp else 1.0)), "from": "caster"}]
	if emp: effs.append({"type": "stun", "duration": float(rg["stun"])})
	var stg := stage("rmb", {"delivery": {"type": "cone", "radius": float(sl["radius"]), "angle": float(sl["angle"])}, "effects": effs})
	var paid := {}
	run(stg, cx("rmb", "rage_smash" if emp else "heavy_slam", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f): return
		if not f.dead and f.max_hp > 0.0 and f.hp / f.max_hp < float(sl["low"]):
			f.hurt(float(sl["dmg"]) * dk * float(sl["low_k"]) * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "break"], "crit": true, "payoff": emp, "melee": true})
			m.fx.word(f.pos + Vector3(0, 2.4, 0), "BREAK", Color("ffd0a0"), true)
		Feel.hitstop(m, h, f, 30.0, {"melee": true, "payoff": emp, "heavy": true})
		if emp and not paid.has("x"):
			paid["x"] = true
			_rage_payoff(f.pos, f)}))
	var dd := h.aim_dir()
	m.fx.cone(h.pos + Vector3(0, 0.1, 0), dd, float(sl["radius"]), res_col() if emp else col_of(sd))
	m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dd.y, dd.x), deg_to_rad(110.0), float(sl["radius"]), col_of(sd), true)
	m.fx.dust(h.pos + Vector3(dd.x, 0, dd.y) * 1.8, 10)
	Feel.shake(m, "t2", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dd, 0.22 * (1.5 if emp else 1.0))
	m.sfx("cleave", h.pos, -1.0, 0.8)
	m.sfx("ab_slam", h.pos, -4.0, 0.9)
	if emp and paid.is_empty():
		m.fx.word(h.pos + Vector3(0, 2.6, 0), "RAGE SMASH", res_col(), true)
		Feel.shake(m, "t4", h, h.pos)

## The hold: a charged lunge into the first foe in its path.
func _lunge(k: float, emp: bool) -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var dist := lerpf(float(ld["dist"][0]), float(ld["dist"][1]), k) + (1.0 if rank("sec") >= 3 and k >= 0.99 else 0.0)
	var t := dist / float(ld["speed"])
	var dv := h.aim_dir()
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv})
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	lunge = {"end": m.time + t + 0.02, "dir": dv, "k": k, "emp": emp, "hit": false}
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "LUNGE", col_of(rmb_def()), false)
	m.sfx("charge", h.pos, -3.0, 0.7 + 0.4 * k)

func _tick_lunge() -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var rg: Dictionary = rmb_def()["rage"]
	var dv: Vector2 = lunge["dir"]
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < h.r + f.r + 0.6 and absf(f.pos.y - h.pos.y) < 1.6:
			var k := float(lunge["k"])
			var emp: bool = lunge["emp"]
			lunge = {}
			h.roll_t = 0.0
			h.vel = Vector3.ZERO
			var dmg := lerpf(float(ld["dmg"][0]), float(ld["dmg"][1]), k) * (1.0 + (float(rg["dmg_k"]) if emp else 0.0))
			var stun := lerpf(float(ld["stun"][0]), float(ld["stun"][1]), k) + (float(rg["stun"]) * 0.5 if emp else 0.0)
			var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "here", "radius": 0.0}, "effects": [{"type": "damage", "amount": dmg}]}, {"hit": "add", "mod": "add"})
			var c := cx("rmb", "lunge", f.pos, {"at": f.pos})
			KinExec.apply_foe(stg.effects, f, c, f.pos, stg)
			if is_instance_valid(f) and not f.dead:
				f.hurt(1.0 * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "lunge"], "stun": stun, "dr": true, "kb": dv * float(ld["push"]) * (1.5 if emp else 1.0), "melee": true, "payoff": emp})
			m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dv.y, dv.x), deg_to_rad(60.0), 2.4, col_of(rmb_def()), true)
			m.sfx("cleave", f.pos, 0.0, 0.7)
			Feel.shake(m, "t3", h, f.pos, f)
			if h.is_local(): Oomph.punch_dir(m, dv, 0.25)
			if emp: _rage_payoff(f.pos, f)
			return
	if m.time >= float(lunge["end"]) or h.roll_t <= 0.0:
		lunge = {}

## In the air: a downward slam; everyone in it is slowed, the centre stunned.
func _meteor(emp: bool) -> void:
	var dd: Dictionary = rmb_def()["drop"]
	var rg: Dictionary = rmb_def()["rage"]
	h.gliding = false
	h.vel = Vector3(h.vel.x * 0.2, -22.0, h.vel.z * 0.2)
	m.later(0.12, func():
		if not is_instance_valid(h): return
		var at := h.pos
		var dk := 1.0 + (float(rg["dmg_k"]) if emp else 0.0)
		var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["radius"])},
			"effects": [{"type": "damage", "amount": float(dd["dmg"]) * dk}, {"type": "slow", "duration": float(dd["slow_t"]), "strength": float(dd["slow"])}]})
		var paid := {}
		run(stg, cx("rmb", "meteor_drop", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
			if not is_instance_valid(f) or f.dead: return
			if Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < float(dd["core"]) + f.r:
				f.hurt(1.0 * power("sec"), h, {"src": "abil", "ab": "utility", "tags": ["utility", "meteor_core"], "stun": float(dd["stun"]), "dr": true, "payoff": emp})
				m.fx.word(f.pos + Vector3(0, 2.3, 0), "CRUSHED", res_col(), false)
			if emp and not paid.has("x"):
				paid["x"] = true
				_rage_payoff(f.pos, f)}))
		m.fx.ring(at, float(dd["radius"]), col_of(rmb_def()), 0.3)
		m.fx.ring(at, float(dd["core"]), Color(1, 1, 1, 0.9), 0.2)
		m.fx.dust(at, 14)
		m.sfx("ab_slam", at, -1.0, 0.75)
		Feel.shake(m, "leap", h, at))

# ------------------------------------------------------------------ E: Warchain
func in_e() -> bool:
	return not chain.is_empty()

func e_recastable() -> bool:
	return not chain.is_empty()

func cast_e() -> bool:
	var ed := e_def()
	var reach := float(ed["range"]) + (2.0 if rank("kin") >= 3 else 0.0)
	var stg := stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]), "range": reach, "size": 0.22, "rope": true},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}, {"type": "slow", "duration": float(ed["time"]), "strength": float(ed["slow"])}]})
	run(stg, cx("e", "warchain", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if chain.is_empty() and is_instance_valid(f) and not f.dead: _hook(f, f.pos),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			if not chain.is_empty() or e != null: return
			if why == "wall": _hook(null, at)
			else:
				# hooked nothing: most of the cooldown back
				cd["e"] = float(cd["e"]) * (1.0 - float(e_def()["miss_refund"]))
				m.fx.word(at + Vector3(0, 1.2, 0), "MISS", Color("c0b0a0"), false)}))
	m.sfx("ab_throw", h.pos, -3.0, 0.8)
	m.sfx("ab_tether", h.pos, -6.0, 0.7)
	return true

func _hook(f: Ent, at: Vector3) -> void:
	var ed := e_def()
	var n := own_node()
	var link := MeshInstance3D.new()
	link.mesh = Models.box(0.09, 0.09, 1.0)
	link.material_override = Models.glow_mat(Color(col_of(ed), 0.95))
	link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(link)
	chain = {"target": f, "pos": at, "node": n, "yank": 0.0}
	e_t = float(ed["time"])
	if f:
		KitStatus.apply(f, "blt", float(ed["time"]))
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "CHAINED", col_of(ed), true)
	else:
		m.fx.word(at + Vector3(0, 1.4, 0), "ANCHORED", col_of(ed), false)
	m.fx.ring(at, 0.9, col_of(ed), 0.25)
	m.sfx("ab_tether", at, -2.0, 1.0)
	net_bolt(h.pos + Vector3(0, 1.0, 0), at + Vector3(0, 1.0, 0), col_of(ed))

func _tick_chain(dt: float) -> void:
	var ed := e_def()
	var f = chain["target"]
	if f != null and (not is_instance_valid(f) or (f as Ent).dead):
		_drop_chain()
		return
	if f != null:
		chain["pos"] = (f as Ent).pos
		# the leash: past 10m they're yanked back toward you
		chain["yank"] = float(chain["yank"]) - dt
		if h.flat_dist(f) > float(ed["leash"]) and float(chain["yank"]) <= 0.0:
			chain["yank"] = 0.35
			(f as Ent).hurt(0.5, h, {"src": "abil", "ab": "k1", "tags": ["k1", "leash"], "kb": -h.dir_to(f) * 9.0})
			m.fx.word((f as Ent).pos + Vector3(0, 2.1, 0), "YANK", col_of(ed), false)
	var n: Node3D = chain["node"]
	if is_instance_valid(n):
		var a := h.pos + Vector3(0, 1.0, 0)
		var b: Vector3 = (chain["pos"] as Vector3) + Vector3(0, 1.0 if f != null else 0.6, 0)
		var len := maxf(0.1, a.distance_to(b))
		n.global_position = (a + b) * 0.5
		n.visible = tells_visible() or f != null
		if len > 0.2: n.look_at(b, Vector3.UP)
		(n.get_child(0) as MeshInstance3D).scale = Vector3(1.0, 1.0, len)

func _drop_chain() -> void:
	var n: Node3D = chain.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	chain = {}
	e_t = 0.0

func _e_end() -> void:
	if not chain.is_empty():
		_drop_chain()

## Press E again: haul yourself along the chain to its end (into a hooked foe: a hit and a stun).
func e_recast() -> bool:
	if chain.is_empty():
		return false
	var ed := e_def()
	var f = chain["target"]
	var dest: Vector3 = chain["pos"]
	_drop_chain()
	if busy():
		return true
	var dv := Vector2(dest.x - h.pos.x, dest.z - h.pos.z)
	var gap := ((f as Ent).r + h.r + 0.2) if f != null else 0.7
	var dist := dv.length() - gap
	if dist < 0.4:
		return true
	var t := dist / float(ed["reel_speed"])
	reels += 1
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv.normalized()})
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	m.fx.bolt(h.pos + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), col_of(ed))
	m.sfx("ab_whirr", h.pos, -3.0, 0.6)
	last_e = "reel"
	if f != null:
		m.later(t, func():
			if not is_instance_valid(h) or not is_instance_valid(f) or (f as Ent).dead: return
			if h.flat_dist(f) < 2.4:
				(f as Ent).hurt(float(ed["reel_dmg"]) * power("kin"), h, {"src": "abil", "ab": "k1", "tags": ["k1", "reel"], "stun": float(ed["reel_stun"]), "dr": true, "melee": true, "kb": dv.normalized() * 4.0})
				m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dv.y, dv.x), deg_to_rad(90.0), 2.0, col_of(ed), true)
				m.sfx("cleave", h.pos, -2.0, 0.85)
				Feel.shake(m, "t3", h, h.pos, f))
	return true

# ------------------------------------------------------------------ R: Doomfall
## The wind-up: you rise with the blade overhead, invulnerable, toward the landing everyone sees.
func _fuse_start(bond: bool) -> void:
	super._fuse_start(bond)
	var rd := r_def()
	var land := aim_at(float(rd["reach"]))
	if m.world.is_void(land.x, land.z) or m.world.is_block(land.x, land.z):
		land = h.pos
	land = ground(land)
	doom = {"from": h.pos, "land": land}
	tele_circle(land, float(rd["radius"]), col_of(rd), fuse_time())
	net_ring(land, float(rd["radius"]), col_of(rd))
	h.vel.y = 7.0
	h.grounded = false
	m.sfx("whoosh", h.pos, -2.0, 0.6)

func _tick_doom() -> void:
	if fusing():
		h.inv_t = maxf(h.inv_t, 0.08)        # invulnerable while it winds up
		var k := 1.0 - float(fuse["t"]) / maxf(0.01, float(fuse["T"]))
		var from: Vector3 = doom["from"]; var land: Vector3 = doom["land"]
		h.pos.x = lerpf(from.x, land.x, k); h.pos.z = lerpf(from.z, land.z, k)
		var dv := Vector2(land.x - from.x, land.z - from.z)
		if dv.length() > 0.3: h.face = atan2(-dv.x, -dv.y)
		if randf() < 0.5: m.fx.burst(h.pos + Vector3(0, 1.8, 0), col_of(r_def()), 2, 1.5, 0.3, 2.0, 0.9)
	elif not doom.has("struck"):
		doom = {}          # interrupted or done

func cast_r() -> bool:
	var rd := r_def()
	var land: Vector3 = doom.get("land", ground(aim_at(float(rd["reach"]))))
	doom = {}
	h.teleport(land)
	h.vel = Vector3.ZERO
	dooms += 1
	var r := float(rd["radius"])
	var before := {}
	for f in foes_in(land, r):
		before[f.get_instance_id()] = f.hp
	var healed := {"hp": 0.0}
	var heal_k := float(rd["heal"]) + (0.2 if rank("ult") >= 2 else 0.0)
	var stg := stage("r", {"delivery": {"type": "burst", "origin": "caster", "radius": r},
		"effects": [{"type": "damage", "amount": float(rd["dmg"]) * r_k()}, {"type": "push", "strength": float(rd["push"])}]})
	var paid := {}
	run(stg, cx("r", "doomfall", land, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f): return
		var key := f.get_instance_id()
		doom_hit[key] = m.time
		var lostp := maxf(0.0, float(before.get(key, f.hp)) - f.hp) if not f.dead or f.hp <= 0.0 else 0.0
		healed["hp"] = float(healed["hp"]) + lostp * (1.0 if f is Hunter else 0.5)
		Feel.hitstop(m, h, f, 40.0, {"melee": true, "payoff": true, "heavy": true})
		if not paid.has("x"):
			paid["x"] = true
			payoff_fx(f.pos, "DOOMFALL", col_of(rd), "", h.aim_dir(), f)}))
	var amt := float(healed["hp"]) * heal_k
	if amt > 0.5:
		h.heal(amt)
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "+%d" % int(round(amt)), Color("7fe08a"), true)
		m.fx.burst(h.pos + Vector3(0, 1.0, 0), Color("7fe08a"), 18, 3.0, 0.6, -2.0)
	m.fx.ring(land, r, col_of(rd), 0.4)
	m.fx.dust(land, 20)
	m.sfx("ab_slam", land, 0.0, 0.6)
	m.sfx("boom", land, -2.0, 0.7)
	Feel.shake(m, "t4", h, land)
	return true

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	if int(h.slot_lv["ult"]) > 0 and float(cd["r"]) <= 0.0 and los and dist < float(r_def()["reach"]) + 1.5 and (tgt.hp < tgt.max_hp * 0.55 or randf() < 0.25) and randf() < 0.45:
		h.inp["aim"] = tgt.pos; h.inp["ult"] = true; return
	# chained: haul in once they're out of sword reach
	if not chain.is_empty() and chain.get("target") != null and dist > 3.5 and randf() < 0.5:
		h.inp["sig"] = true; return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and chain.is_empty() and los and dist > 4.0 and dist < float(e_def()["range"]) - 0.5 and randf() < 0.35:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0); h.inp["sig"] = true; return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los:
		if not h.grounded and dist < 3.0:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
		elif dist < 3.0:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true      # the slam (BREAK on the wounded)
		elif dist < 7.5 and randf() < 0.5:
			h.inp["aim"] = tgt.pos; h.inp["sec"] = true
			bot_hold["rmb"] = float(rmb_def()["hold"]) + (float(rmb_def()["full_t"]) - float(rmb_def()["hold"])) * clampf((dist - 3.0) / 4.0, 0.0, 1.0) + 0.05
	# Rampage in: the tip is the sweet spot, so dash from about a dash length out
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and lunge.is_empty() and dist > 2.5 and dist < 6.0 and randf() < 0.25:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
