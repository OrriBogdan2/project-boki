class_name JuggernautKit
extends ArchKit
## Juggernaut (heavy), kits2: a port of SUPERVIVE's Brall, ability by ability (supervive.wiki.gg),
## scaled to our health and TTK; only the names, art, sounds and on-screen text are ours.
##
## - Passive, Rage (Blazing Spirit): damage you deal fills it; full, you're Enraged (the red shell, the
##   hunter swells): bonus damage, dash haste and ability haste. A knock heals you a share of the
##   knocked hunter's health (a monster kill, of the monster's).
## - LMB (Greatsword): quick slashes that hit twice as hard at the tip; hold for a Searing Wave (it
##   fills Rage fast).
## - RMB, Smash (Adaptive Strike): tap a wound-up Finishing Slam behind a magenta strike lane (more to
##   the wounded, who are outlined red while it's ready; a foe knocked within 2s of its sweet spot makes
##   the Gilded Riposte ready again: the payoff, T4, pay_rage), hold a charged Lunge (a crouched
##   wind-up, a lane that grows and turns magenta at full, a rising whine; you can jump while charging;
##   release flings you forward, a miss doubles the cooldown), in the air a Meteor Drop onto a disc at
##   the cursor (slows; the centre stunned), during the Warchain's pull a Cinder Spin.
## - Dash, Rampage (Flame Step): 3 charges of a dash attack the way you face, the tip hits double.
## - E, Warchain (Feysteel Chain): a chain to a foe (blighted) or a wall; recast to pull yourself in.
## - X, Gilded Riposte (JuggernautUlt, level 6): a 0.65s gold guard that blocks everything, then a lunging
##   upward cleave that heals 80% of its damage; a knock with it makes it ready again. R is the Boki Merge.
## Matched to the footage in briefs/hero-ref/juggernaut.md; docs/heroes/juggernaut.md.

const SLASH_OUT := Color("ff3df0")     # the slash crescent's magenta edge
const SLASH_IN := Color("ffe9a0")      # ... and its flame-yellow fill
const LUNGE_RED := Color("ff4a3a")     # the Lunge lane while charging
const LUNGE_FULL := Color("ff3df0")    # ... at full
const DROP_PURPLE := Color("b06aff")   # the Meteor Drop's landing disc
const EXEC_RED := Color("ff2a2a")      # the wounded-enough-to-finish outline
# the Warchain pull bends this far sideways (tan of the angle) with A/D held across it
const REEL_STEER := 0.5

var enraged_t := 0.0
var aura: Node3D = null        # the Enraged look: a red shell, a glow, the hunter grown bigger
var heat: Node3D = null        # the heat glowing through the pauldrons as Rage builds
var grow := 0.0                # 0..1 how far into the Enraged form the model is
var lmb_t := -1.0              # how long the attack key has been held with the greatsword (-1: not)
var lmb_was := false
var lmb_buf := 0.0
var bot_wave_t := 0.0
var slash_n := 0
var slash_at := -9.0
var slam_w := {}               # the Finishing Slam winding up: {t, warn}
var lunge := {}                # the running Lunge: {end, dir, k, hit}
var chain := {}                # the Warchain: {target, pos, node}
var chain_flying := false
var reel_t := 0.0              # the Warchain's pull is carrying you (a Smash now is a Cinder Spin)
var sweet_hit := {}            # foe id -> when the Slam's sweet spot hit them (a knock within 2s resets X)
var riposte: JuggernautUlt     # X, the ultimate
var sweet_spots := 0           # (tests, demo)
var waves := 0
var tips := 0
var slam_resets := 0           # Riposte resets from a Slam sweet spot then a knock
var reels := 0
var spins := 0
var chain_lunges := 0
var haul_slams := 0
var haul := {}                 # a Haul Slam armed for the end of the pull: {k}
var drop := {}                 # a Meteor Drop diving onto its disc: {land, t}
var lunge_full := false        # the Lunge charge reached full (its flash played)
var drops := 0                 # (tests)
var last_drop := Vector3.ZERO
var knock_healed := 0.0        # (tests) health the knock heals gave back

func _setup() -> void:
	riposte = JuggernautUlt.new(self)

func full_ready() -> bool:
	return false               # no resource-full Smash: Enraged buffs everything instead

func res_frac() -> float:
	return 1.0 if enraged_t > 0.0 else clampf(res / res_max(), 0.0, 1.0)

func res_text() -> String:
	return "ENRAGED" if enraged_t > 0.0 else "%d" % int(res)

func ready_label() -> String:
	if not slam_w.is_empty(): return "SMASH  ·  aim it"
	return "ENRAGED" if enraged_t > 0.0 else ""

## How hot it is, 0..1 (Enraged counts as all the way).
func heat_k() -> float:
	return res_frac()

func enraged_k() -> float:
	return 1.0 if enraged_t > 0.0 else 0.0

func gain_rage(v: float) -> void:
	if enraged_t > 0.0:
		return
	add_res(v)
	touch_res()
	if res >= res_max():
		enraged_t = float(res_def().get("enraged_t", 6.0))
		res = res_max()
		_enrage_fx()

## Three Rampage charges from rank 1 (the source's Quick Dash has 3).
func extra_dashes() -> float:
	return 1.0

func _enrage_fx() -> void:
	var rc := res_col()
	if lunge.is_empty() and slam_w.is_empty() and not rmb_down: play("jug_roar")
	m.sfx("knock", h.pos, 0.0, 0.6)          # the roar, audible within 25m
	m.sfx("charge", h.pos, -3.0, 0.45)
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "ENRAGED", rc, true)
	m.fx.ring(h.pos, 2.8, rc, 0.45)
	m.fx.ring(h.pos, 1.4, Color(1, 0.9, 0.8, 0.9), 0.25)
	m.fx.burst(h.pos + Vector3(0, 1.2, 0), rc, 30, 6.0, 0.6, -2.0, 1.4)
	Feel.shake(m, "t3", h, h.pos)
	if h.is_local():
		if m.hud: m.hud.flash(rc, 0.15)
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
			enraged_t = 0.0
			res = 0.0
			_drop_aura()
		# Enraged: cooldowns and dash charges come back faster
		for k in ["rmb", "e"]:
			cd[k] = maxf(0.0, float(cd[k]) - dt * float(rd.get("ab_haste", 0.2)))
		if h.dashes < h.max_dashes():
			h.dashes = minf(h.max_dashes(), h.dashes + dt / h.dash_regen() * float(rd.get("dash_haste", 0.12)))
	elif res_wait <= 0.0:
		add_res(-float(rd.get("decay", 9.0)) * dt)
	if lmb_buf > 0.0: lmb_buf -= dt
	reel_t = maxf(0.0, reel_t - dt)
	_steer_reel()
	if not slam_w.is_empty(): _tick_slam(dt)
	if not lunge.is_empty(): _tick_lunge()
	if not chain.is_empty(): _tick_chain(dt)
	riposte.tick(dt)
	if not drop.is_empty(): _tick_drop(dt)
	# a held pose ends with its hold (a charge dropped without a release must not freeze the body)
	if (anim_id == "jug_wave_wind" and lmb_t < 0.0) or (anim_id == "jug_lunge_wind" and not rmb_down):
		anim_id = ""
	if chain_flying: _tick_chain_flight()
	_tick_tells()
	if st.has("bot_haul_at") and m.time >= float(st["bot_haul_at"]):
		st.erase("bot_haul_at")
		if rmb_down and not chain.is_empty(): e_recast()     # a bot pulling in with the Smash charged
	net_pulse(dt, enraged_t > 0.0, 1.4)

func on_deal(t: Ent, dmg: float, o: Dictionary) -> void:
	if t == null or t.team == h.team:
		return
	var rd := res_def()
	var src := String(o.get("src", ""))
	var k := 0.4 if src == "burn" else 1.0
	if String(o.get("ab", "")) == "primary" and src != "shot":
		k = float(lmb_def().get("wave_rage", 3.0))       # the Searing Wave fills Rage fast
	gain_rage(maxf(float(rd.get("min_hit", 2.0)) * k, dmg * float(rd.get("per_dmg", 0.7)) * k))
	# killing a monster heals you a share of its health
	if t is Mob and t.hp <= 0.0 and not t.has_meta("jug_fed"):
		t.set_meta("jug_fed", true)
		h.heal(t.max_hp * float(rd.get("heal_creep", 0.2)))

func outgoing(_t: Ent, dmg: float, _o: Dictionary) -> float:
	return dmg * (1.0 + float(res_def().get("enraged_dmg", 0.15)) * enraged_k())

func move_k() -> float:
	if riposte.running(): return riposte.move_k()
	if not slam_w.is_empty(): return 0.6
	return 0.55 if lmb_t > float(lmb_def().get("tap", 0.22)) else 1.0

## A knock (ours, or one we helped with): ours heals a share of the knocked hunter's health; either
## way, if the Slam's sweet spot hit them in the last 2s the Gilded Riposte is ready again.
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	if mine and is_instance_valid(t):
		var hp0 := h.hp
		h.heal(t.max_hp * float(rd.get("heal_knock", 0.2)))
		knock_healed += h.hp - hp0
		fx().pillar(h.pos, Color("5ae07a"), 3.6, 0.7, 0.75)
		fx().star(t.pos + Vector3(0, 1.3, 0), Color("ff2a2a"), 3.2, 0.55, Color(1, 0.85, 0.8))
		m.fx.word(h.pos + Vector3(0, 2.7, 0), "+%d" % int(round(h.hp - hp0)), Color("7fe08a"), true)
		m.sfx("dj_heal", h.pos, -4.0, 0.8)
		if h.is_local() and m.hud: m.hud.flash(Color(1, 0.1, 0.05), 0.12)      # the red tint of a kill
	var key := t.get_instance_id() if is_instance_valid(t) else -1
	if sweet_hit.has(key) and m.time - float(sweet_hit[key]) <= float(rmb_def()["slam"].get("reset_t", 2.0)):
		sweet_hit.erase(key)
		_reset_riposte()

## The Slam's sweet spot then a knock: the Gilded Riposte (X) is ready again (once it is unlocked).
func _reset_riposte() -> void:
	if float(cd["r"]) <= 0.0 or not r_unlocked():
		return
	cd["r"] = 0.0
	slam_resets += 1
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "RIPOSTE READY", col_of(r_def()), true)
	m.fx.ring(h.pos, 2.0, col_of(r_def()), 0.35)
	m.sfx("ab_ready", h.pos, -2.0, 0.8)
	if h.is_local(): h._ab_feedback("x", "ready")
	net_ring(h.pos, 2.0, col_of(r_def()))

# ------------------------------------------------------------------ X: Gilded Riposte (JuggernautUlt)
func cast_ult() -> bool:
	if not ult_ready():
		return false
	riposte.start()
	ult_spent()
	return true

func ult_running() -> float:
	return riposte.left_k()

## Planted in the guard and the cleave: no other button does anything.
func busy() -> bool:
	return super.busy() or (riposte != null and riposte.move_k() <= 0.0)

## The guard takes every hit (no damage, no crowd control) and counts it.
func incoming(by: Ent, dmg: float, o: Dictionary) -> Array:
	if riposte.block(by, o):
		return [0.0, o]
	return [dmg, o]

# ------------------------------------------------------------------ LMB: Greatsword (slashes / Searing Wave)
func _wk() -> float:
	return h.wup_dmg * m.dmg_mult(h)

## A Boki merge starting (ArchKit's single cleanup hook) drops everything held or wound up: the Searing
## Wave charge, the Finishing Slam's wind-up, an armed Haul Slam and a running Gilded Riposte (guard or
## cleave). Nothing fires and nothing is left over.
func _drop_holds() -> void:
	riposte.drop()
	lmb_t = -1.0
	lmb_buf = 0.0
	h.mel_hold = 0.0
	slam_w = {}
	haul = {}
	drop = {}
	lunge_full = false

func fx() -> DJFx:
	return DJFx.of(m)

func wave_k() -> float:
	var ld := lmb_def()
	return clampf((lmb_t - float(ld["tap"])) / maxf(0.05, float(ld["full"]) - float(ld["tap"])), 0.0, 1.0)

func lmb_override(held: bool, dt: float) -> bool:
	if h.wid != "greatsword":
		return false
	if KinMerge.active(h) or riposte.move_k() <= 0.0:
		# merged, the form owns the attack key (a charge from before must not go off); guarding, no swings
		lmb_was = false
		return true
	var ld := lmb_def()
	var pressed := held and not lmb_was
	lmb_was = held
	# (a merge ends the charge: letting go of it must not swing a wave mid-transformation)
	if not h.can_fire() or KinMerge.transforming(h):
		if lmb_t >= 0.0:
			lmb_t = -1.0
			h.mel_hold = 0.0
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
		if lmb_t > float(ld["tap"]):
			h.mel_hold = wave_k()
			if anim_id != "jug_wave_wind": play("jug_wave_wind")
		if lmb_t >= float(ld["full"]) + 0.5: _wave()      # held well past full: it goes by itself
	elif lmb_t >= 0.0:
		if lmb_t < float(ld["tap"]): _slash()
		else: _wave()
	elif lmb_buf > 0.0 and h.fire_cd <= 0.0:
		lmb_buf = 0.0
		_slash()
	return true

## A quick slash: a cone, twice as hard on the tip (the sweet spot at the far end of the swing).
func _slash() -> void:
	var ld := lmb_def()
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(ld["rate"])
	# quick slashes, alternating right-to-left and back (no heavier third: each is the same cut)
	if m.time - slash_at > 0.8: slash_n = 0
	slash_at = m.time
	h.combo_i = slash_n % 2 + 1
	play("jug_slash_r" if slash_n % 2 == 0 else "jug_slash_l")
	slash_n += 1
	var keep := h.wpn
	h.wpn = h.wpn.duplicate()
	h.wpn["tip_bonus"] = float(ld["tip"])
	h.wpn["color"] = SLASH_OUT
	h._strike(float(ld["dmg"]) * _wk() / m.dmg_mult(h), float(ld["reach"]), float(ld["arc"]), float(ld["kb"]), {})
	h.wpn = keep
	# the two-tone crescent (magenta edge, flame-yellow fill), sweeping the other way each swing, and a
	# white star on anyone caught at the tip
	var dv := h.aim_dir()
	fx().crescent(h.pos + Vector3(0, 0.85, 0), dv, float(ld["arc"]), float(ld["reach"]) + 0.2, SLASH_OUT, SLASH_IN, 0.2,
			0.0 if slash_n % 2 == 1 else PI)
	for f in foes_in(h.pos, float(ld["reach"]) + 0.4):
		var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		if to.length() >= float(ld["reach"]) * 0.7 and absf(dv.angle_to(to)) <= deg_to_rad(float(ld["arc"]) * 0.5):
			fx().star(f.pos + Vector3(0, 1.1, 0), Color(1, 1, 1), 1.3, 0.2, Color(1, 0.95, 0.8))
	m.sfx("jug_slash", h.pos, -5.0 if h.is_local() else -9.0, randf_range(0.95, 1.08))

## The Searing Wave: a held, charged wave of fire that rolls through everyone in a line (full: it
## burns and slows).
var _shots0 := 0
## The shot this kit just put in the air (a stage projectile), or null.
func _my_last_shot():
	if m.shots.size() > _shots0 and m.shots[-1]["by"] == h:
		return m.shots[-1]
	return null

func _wave() -> void:
	var ld := lmb_def()
	var k := wave_k()
	lmb_t = -1.0
	h.mel_hold = 0.0
	h.fire_cd = float(ld["wave_rate"])
	waves += 1
	play("jug_wave")
	var full := k >= 0.99
	var rng := lerpf(float(ld["wave_range"][0]), float(ld["wave_range"][1]), k)
	var size := lerpf(float(ld["wave_size"][0]), float(ld["wave_size"][1]), k)
	var effs: Array = [{"type": "damage", "amount": lerpf(float(ld["wave_dmg"][0]), float(ld["wave_dmg"][1]), k)},
			{"type": "push", "strength": lerpf(3.0, 6.0, k), "from": "caster"}]
	if full:
		effs.append({"type": "damage", "amount": float(ld["wave_burn"]) * 2.0, "over": 2.0})
		effs.append({"type": "slow", "duration": 1.0, "strength": float(ld["wave_slow"])})
	var stg := StageSpec.parse(
			{"delivery": {"type": "projectile", "speed": float(ld["wave_speed"]), "range": rng, "size": size},
					"effects": effs, "modifiers": [{"type": "pierce", "count": 6}]},
			"", GrammarReport.new())
	var c := KinExec.make_cx(m, h, h.kin, h, aim(), _wk(), "primary", "searing_wave")
	c["silent"] = true
	_shots0 = m.shots.size()
	KinExec.run_stage(stg, c)
	# the fire rolling along its line: a red standing crescent of flame (pooled) riding the wave's shot
	var dv := h.aim_dir()
	var from := h.pos
	var sd = _my_last_shot()
	if sd != null: fx().ride(sd, "crescent_bolt", Color("ff3a2a"), Color("ffb070") if not full else Color("fff0b0"),
			1.6, size * 2.2)
	m.sfx("jug_wave", h.pos, -2.0, 1.0 - 0.15 * k)
	var steps := int(rng / 1.2)
	for s in steps:
		var p := from + Vector3(dv.x, 0, dv.y) * (1.0 + 1.2 * s)
		m.later(1.2 * s / float(ld["wave_speed"]), func():
			m.fx.burst(p + Vector3(0, 0.5, 0), res_col() if full else Color("ffb070"), 6 + int(6 * k), 2.5 + 2.0 * k,
					0.4, -4.0, 0.9 + 0.6 * k, Vector3.UP, 50.0))
	m.fx.slash(h.pos + Vector3(0, 0.6, 0), atan2(dv.y, dv.x), deg_to_rad(70.0), 2.6, Color("ffb070"), true)
	m.sfx("cleave", h.pos, -1.0, 0.7)
	m.sfx("ab_blast", h.pos, -5.0 if not full else -2.0, 1.2 - 0.3 * k)
	h.swing_t = 0.18
	h.swing_n += 1
	Oomph.on_fire(h, true)
	Feel.shake(m, "t3" if full else "t2", h, h.pos)
	net_bolt(h.pos + Vector3(0, 0.6, 0), h.pos + Vector3(dv.x * rng, 0.6, dv.y * rng), Color("ff8a4a"))

# ------------------------------------------------------------------ dash: Rampage
func on_dash(use_ex: bool) -> bool:
	if not lunge.is_empty() or riposte.move_k() <= 0.0:
		return true
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)),
				{"invuln": 0.08, "trail": "dust", "shove": true, "shove_kb": 4.0, "shove_dmg": 0.0}, true)
		play("jug_exdash")         # the shared long dash, his way: a lumbering shoulder-first shove
		m.fx.spark(h.pos + Vector3(0, 0.9, 0), Vector3(-h.aim_dir().x, 0.1, -h.aim_dir().y), Arch.color(id), 12, 7.0,
				30.0, 0.3, 0.0, 1.4)
		m.later(float(h.cdat.get("ex_time", 0.21)),
				func(): if is_instance_valid(h): m.fx.dust(h.pos, 14); m.fx.ring(h.pos, 1.2, Arch.color(id), 0.2))
		return true
	if not spend_dash(false):
		return true
	var dd := dash_def()
	var t := float(dd["time"])
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	travel(float(dd["dist"]), t,
			{"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "shove_dmg": float(dd["hit_dmg"]) * pk,
					"trail": "dust", "dir": h.aim_dir()})
	st["last_dash"] = "rampage"
	play("jug_dash")
	for i in 3:      # orange flame streaks behind him
		m.later(t * 0.3 * i,
				func(): if is_instance_valid(h): m.fx.spark(h.pos + Vector3(0, 0.9, 0),
						Vector3(-h.aim_dir().x, 0.15, -h.aim_dir().y), Color("ff9a3a"), 10, 9.0, 25.0, 0.25, 0.0, 1.4))
	m.sfx("jug_dash", h.pos, -4.0 if h.is_local() else -8.0, 1.0)
	h.glide_cd = maxf(h.glide_cd, t + 0.35)    # the dash's wind-down: no glider straight out of it
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
		f.hurt(float(dd["tip_dmg"]) * power("dash") * (1.25 if rank("dash") >= 3 else 1.0), h,
				{"src": "abil", "ab": "dodge", "tags": ["dodge", "tip"], "kb": dv * float(dd["tip_kb"]),
						"wallstun": float(dd["tip_stun"]), "melee": true, "crit": true})
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "TIP", res_col(), false)
	m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dv.y, dv.x), deg_to_rad(100.0), 2.2, col_of(dd), true)
	if hit:
		tips += 1
		m.sfx("cleave", at, -2.0, 0.9)
		Feel.shake(m, "t3", h, at)
		if h.is_local(): Oomph.punch_dir(m, dv, 0.2)
		net_ring(at, 1.4, col_of(dd))

# ------------------------------------------------------------------ RMB: Smash (Adaptive Strike)
func rmb_charge_full() -> float:
	return float(rmb_def().get("full_t", 0.9))

func rmb_auto_t() -> float:
	return rmb_charge_full() + 0.4

## Holding past the tap: the Lunge's crouched wind-up pose (held while you charge).
func rmb_hold_tick(t: float) -> void:
	var sd := rmb_def()
	if t > float(sd["hold"]) and not rmb_ctx.get("air", false) and not rmb_ctx.get("e", false):
		# the Lunge charging: a lane grows ahead of you with a fill, magenta and flashing at full; the
		# cursor ring fills; a rising whine on the way in, a ping at full
		var k := lunge_k(t)
		var ld: Dictionary = sd["lunge"]
		AimKit.lane(h, "rmb",
				{"len": float(ld["dist"][1]), "len0": float(ld["dist"][0]), "k": k, "fill": k, "width": 1.3,
						"col": LUNGE_RED, "col_full": LUNGE_FULL, "tip": true})
		AimKit.charge(h, k, {"col": LUNGE_RED, "col2": LUNGE_FULL})
		if anim_id != "jug_lunge_wind" and chain.is_empty():
			m.sfx("jug_charge", h.pos, -3.0 if h.is_local() else -7.0, 1.0)
		if k >= 1.0 and not lunge_full:
			lunge_full = true
			var d := h.aim_dir()
			fx().star(h.pos + Vector3(d.x * 0.5, 1.0, d.y * 0.5), LUNGE_FULL, 1.8, 0.22)
			m.sfx("jug_full", h.pos, -2.0 if h.is_local() else -6.0, 1.0)
			if h.is_local() and m.cam: m.cam.add_trauma(0.1)
	if t > float(sd["hold"]) and anim_id != "jug_lunge_wind" and anim_id != "jug_haul_wind" and not rmb_ctx.get("air", false):
		play("jug_haul_wind" if rmb_ctx.get("e", false) else "jug_lunge_wind")
		if not chain.is_empty() or rmb_ctx.get("e", false):
			# charging on the chain: the links glow hot (everyone sees a chain swing is coming)
			m.fx.ring(h.pos, 1.2, Color("ffcf6a"), 0.25)
			net_ring(h.pos, 1.2, Color("ffcf6a"))

func lunge_k(t: float) -> float:
	var sd := rmb_def()
	return clampf((t - float(sd["hold"])) / maxf(0.05, float(sd["full_t"]) - float(sd["hold"])), 0.0, 1.0)

## Every Smash's damage: its rank, and +20% at rank 3.
func smash_k() -> float:
	return 1.2 if rank("sec") >= 3 else 1.0

func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if not slam_w.is_empty() or not lunge.is_empty():
		return
	if not spend_rmb(): return
	if c.get("e", false):
		# pressed while the Warchain pulls you: a tap spins (Cinder Spin), a held one slams on arrival
		if c.get("hold", false): _haul_slam(lunge_k(float(c.get("t", 0.0))))
		else: _spin()
	elif not chain.is_empty() and c.get("hold", false) and not c.get("air", false):
		_chain_lunge(lunge_k(float(c.get("t", 0.0))))      # charged while tethered: along the chain
	elif c.get("air", false):
		_meteor()
	elif c.get("hold", false):
		_lunge(lunge_k(float(c.get("t", 0.0))))
	else:
		# the Finishing Slam winds up first (you keep aiming); everyone sees the warning over you
		slam_w = {"t": float(rmb_def()["windup"])}
		play("jug_slam")                # keyed to the wind-up: the strike lands at 0.6s
		m.sfx("jug_slam_wind", h.pos, -3.0, 1.0)
		net_ring(h.pos, 1.3, SLASH_OUT)

func _tick_slam(dt: float) -> void:
	slam_w["t"] = float(slam_w["t"]) - dt
	if h.stun_t > 0.0 or h.downed or Hex.active(h):
		slam_w = {}          # interrupted
		return
	# the short magenta strike lane ahead of him, filling as the wind-up runs (everyone sees it)
	var sl: Dictionary = rmb_def()["slam"]
	var wk := 1.0 - clampf(float(slam_w["t"]) / float(rmb_def()["windup"]), 0.0, 1.0)
	AimKit.lane(h, "slam",
			{"len": float(sl["radius"]), "width": 1.9, "fill": wk, "col": SLASH_OUT, "all": true, "chevrons": 2})
	if randf() < 0.5: m.fx.burst(h.pos + Vector3(0, 2.3, 0), Color("ff5a3a"), 1, 1.0, 0.25, 0.0, 0.8)
	if float(slam_w["t"]) <= 0.0:
		slam_w = {}
		_slam()

## The Finishing Slam: a heavy cone; the wounded (under 35%) take +50%; a foe in the sweet spot (the far
## tip, dead ahead) is the payoff, and a knock on that foe within 2s makes the Gilded Riposte ready again.
func _slam() -> void:
	var sd := rmb_def()
	var sl: Dictionary = sd["slam"]
	var dd := h.aim_dir()
	var effs: Array = [{"type": "damage", "amount": float(sl["dmg"]) * smash_k()},
			{"type": "push", "strength": float(sl["push"]), "from": "caster"}]
	var stg := stage("rmb",
			{"delivery": {"type": "cone", "radius": float(sl["radius"]), "angle": float(sl["angle"])}, "effects": effs})
	var from := h.pos
	var paid := {}
	run(stg, cx("rmb", "finishing_slam", aim(), {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f): return
		if not f.dead and f.max_hp > 0.0 and f.hp / f.max_hp < float(sl["low"]):
			f.hurt(float(sl["dmg"]) * smash_k() * float(sl["low_k"]) * power("sec"), h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "execute"], "crit": true, "melee": true})
			m.fx.word(f.pos + Vector3(0, 2.4, 0), "EXECUTE", Color("ffd0a0"), true)
		var to := Vector2(f.pos.x - from.x, f.pos.z - from.z)
		var sw: Array = sl["sweet"]
		var sweet := to.length() >= float(sw[0]) and to.length() <= float(sw[1]) + f.r and absf(rad_to_deg(dd.angle_to(to.normalized()))) <= float(sl["sweet_deg"])
		Feel.hitstop(m, h, f, 30.0, {"melee": true, "payoff": sweet, "heavy": true})
		if sweet and not paid.has("x"):
			paid["x"] = true
			sweet_spots += 1
			payoff_fx(f.pos, "SWEET SPOT", res_col(), "pay_rage", dd, f)
		if sweet:
			sweet_hit[f.get_instance_id()] = m.time}))
	AimKit.hide(h, "slam")
	m.fx.cone(h.pos + Vector3(0, 0.1, 0), dd, float(sl["radius"]), col_of(sd))
	fx().crescent(h.pos + Vector3(0, 0.6, 0), dd, 80.0, float(sl["radius"]), SLASH_OUT, SLASH_IN, 0.24, PI * 0.5)
	m.sfx("jug_slam_hit", h.pos, -1.0, 1.0)
	m.fx.dust(h.pos + Vector3(dd.x, 0, dd.y) * 2.4, 12)
	m.fx.ring(h.pos + Vector3(dd.x, 0, dd.y) * 2.6, 0.7, res_col(), 0.2)      # where the sweet spot was
	Feel.shake(m, "t2", h, h.pos)
	if h.is_local(): Oomph.punch_dir(m, dd, 0.24)
	m.sfx("cleave", h.pos, -1.0, 0.75)
	m.sfx("ab_slam", h.pos, -3.0, 0.85)

## The hold: a charged dash attack into the first foe in its path; a miss doubles the cooldown.
func _lunge(k: float) -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var dist := lerpf(float(ld["dist"][0]), float(ld["dist"][1]), k)
	var t := dist / float(ld["speed"])
	var dv := h.aim_dir()
	lunge_full = false
	AimKit.hide(h, "rmb")
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv})
	fx().crescent(h.pos + Vector3(0, 0.9, 0), dv, 50.0, 2.0, LUNGE_RED, Color(1, 0.8, 0.6), 0.25)
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	lunge = {"end": m.time + t + 0.02, "dir": dv, "k": k}
	play("jug_lunge")
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "LUNGE", col_of(rmb_def()), false)
	m.sfx("charge", h.pos, -3.0, 0.7 + 0.4 * k)

func _tick_lunge() -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var dv: Vector2 = lunge["dir"]
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < h.r + f.r + 0.6 and absf(f.pos.y - h.pos.y) < 1.6:
			var k := float(lunge["k"])
			var was_chain: bool = lunge.get("chain", false)
			lunge = {}
			h.roll_t = 0.0
			h.vel = Vector3.ZERO
			if was_chain and f.hittable():
				f.hurt(1.0, h,
						{"src": "abil", "ab": "utility", "tags": ["utility", "chain_lunge"], "stun": 0.35, "dr": true})
				m.fx.word(f.pos + Vector3(0, 2.4, 0), "RUN THROUGH", Color("ffcf6a"), true)
				m.sfx("ab_tether", f.pos, -2.0, 1.3)
			var chained: bool = lunge.get("chain", false)
			var dmg := lerpf(float(ld["dmg"][0]), float(ld["dmg"][1]), k) * smash_k() * (1.25 if chained else 1.0)
			var stg := stage("rmb",
					{"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
							"effects": [{"type": "damage", "amount": dmg},
									{"type": "push", "strength": float(ld["push"]), "from": "caster"}]},
					{"hit": "add", "mod": "add"})
			var c := cx("rmb", "lunge", f.pos, {"at": f.pos})
			KinExec.apply_foe(stg.effects, f, c, f.pos, stg)
			m.fx.slash(h.pos + Vector3(0, 0.9, 0), atan2(dv.y, dv.x), deg_to_rad(60.0), 2.4, col_of(rmb_def()), true)
			# the impact: a huge white burst and a horizontal red slash across them
			fx().star(f.pos + Vector3(0, 1.1, 0), Color(1, 1, 1), 2.6 + 1.4 * k, 0.3, Color(1, 1, 1))
			fx().crescent(f.pos + Vector3(0, 1.0, 0), dv.rotated(PI * 0.5), 120.0, 1.6, LUNGE_RED, Color(1, 0.6, 0.5),
					0.2)
			m.sfx("jug_lunge_hit", f.pos, -1.0, 1.0)
			m.sfx("cleave", f.pos, 0.0, 0.7)
			Feel.shake(m, "t3", h, f.pos, f)
			if h.is_local(): Oomph.punch_dir(m, dv, 0.25)
			return
	if m.time >= float(lunge["end"]) or h.roll_t <= 0.0:
		lunge = {}
		h.glide_cd = maxf(h.glide_cd, 0.35)      # the dash's wind-down: no glider straight out of it
		cd["rmb"] = float(cd["rmb"]) * float(ld["miss_k"])        # struck nothing: the cooldown doubles
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "MISS", Color("c0b0a0"), false)

## Charged while tethered and let go: the Lunge runs along the chain to its end (the foe it holds, or
## the wall), harder and with a short stun on the foe; the chain is spent.
func _chain_lunge(k: float) -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var f = chain.get("target")
	var dest: Vector3 = chain["pos"]
	var dv := Vector2(dest.x - h.pos.x, dest.z - h.pos.z)
	var gap := ((f as Ent).r + h.r) if f != null and is_instance_valid(f) else 0.7
	var dist := clampf(dv.length() - gap + 0.6, 2.0, float(e_def()["range"]) + 1.0)
	var t := dist / (float(ld["speed"]) * 1.25)
	chain_lunges += 1
	m.fx.bolt(h.pos + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), Color("ffcf6a"))
	m.fx.bolt(h.pos + Vector3(0, 0.7, 0), dest + Vector3(0, 0.7, 0), Color(1, 0.95, 0.8, 0.9))
	net_bolt(h.pos + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), Color("ffcf6a"))
	_drop_chain()
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv.normalized()})
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	lunge = {"end": m.time + t + 0.02, "dir": dv.normalized(), "k": k, "chain": true}
	play("jug_chainlunge")
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CHAIN LUNGE", Color("ffcf6a"), true)
	m.sfx("ab_tether", h.pos, -1.0, 0.9)
	m.sfx("charge", h.pos, -2.0, 1.1)

## A Haul Slam: armed for the end of the pull (or now, if the pull is over): you arrive in a crash.
func _haul_slam(k: float) -> void:
	if reel_t > 0.0:
		haul = {"k": k}
		play("jug_haul_wind")
	else:
		_haul_land(k)

func _haul_land(k: float) -> void:
	var hd: Dictionary = rmb_def()["haul"]
	haul = {}
	haul_slams += 1
	var at := h.pos
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(hd["radius"])},
		"effects": [{"type": "damage", "amount": lerpf(float(hd["dmg"][0]), float(hd["dmg"][1]), k) * smash_k()},
				{"type": "push", "strength": float(hd["push"])}]})
	run(stg, cx("rmb", "haul_slam", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if is_instance_valid(f) and not f.dead:
			f.hurt(1.0, h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "haul_slam"],
							"stun": lerpf(float(hd["stun"][0]), float(hd["stun"][1]), k), "dr": true})}))
	play("jug_haulslam")
	m.fx.word(at + Vector3(0, 2.6, 0), "HAUL SLAM", Color("ffcf6a"), true)
	m.fx.ring(at, float(hd["radius"]), Color("ffcf6a"), 0.35)
	m.fx.ring(at, 1.0, Color(1, 1, 1, 0.9), 0.2)
	m.fx.dust(at, 18)
	m.fx.burst(at + Vector3(0, 0.4, 0), Color("ffcf6a"), 24, 6.0, 0.5, 6.0, 1.2)
	m.sfx("ab_slam", at, 0.0, 0.65)
	m.sfx("boom", at, -4.0, 0.9)
	m.sfx("ab_tether", at, -6.0, 0.6)
	Feel.shake(m, "t3", h, at)
	if h.is_local(): Oomph.punch_dir(m, h.aim_dir(), 0.25)
	net_ring(at, float(hd["radius"]), Color("ffcf6a"))

## In the air: a dive onto the disc at the cursor (5m at most from under you); everyone in the burst
## is slowed, the centre takes +50% and is stunned.
func _meteor() -> void:
	var dd: Dictionary = rmb_def()["drop"]
	var land := _drop_point()
	var height := maxf(0.0, h.pos.y - land.y)
	var t := clampf(height / 22.0, 0.1, 0.6)
	h.gliding = false
	h.vel = Vector3((land.x - h.pos.x) / t, -22.0, (land.z - h.pos.z) / t)
	drop = {"land": land, "t": t}
	play("jug_meteor")
	m.sfx("jug_drop", h.pos, -2.0, 1.0)
	AimKit.circle(h, "drop",
			{"at": land, "r": float(dd["radius"]), "col": DROP_PURPLE, "all": true, "ticks": true, "fill": 0.4,
					"dur": t + 0.05})

## Where a Meteor Drop would land now: the cursor, clamped to the reach from under you, on open ground.
func _drop_point() -> Vector3:
	var dd: Dictionary = rmb_def()["drop"]
	var at := AimMode.point(h, float(dd.get("reach", 5.0)), AimMode.CURSOR, 0.0)
	if m.world.is_void(at.x, at.z) or m.world.is_block(at.x, at.z):
		at = Vector3(h.pos.x, at.y, h.pos.z)
	return ground(at)

func _tick_drop(dt: float) -> void:
	drop["t"] = float(drop["t"]) - dt
	if float(drop["t"]) > 0.0 and not h.grounded:
		return
	var land: Vector3 = drop["land"]
	drop = {}
	if h.downed or KinMerge.active(h):
		return
	if h.pos.distance_to(land) > 0.8 and not m.world.is_block(land.x, land.z):
		h.teleport(land)
	h.vel = Vector3.ZERO
	_drop_hit(h.pos)

func _drop_hit(at: Vector3) -> void:
	var dd: Dictionary = rmb_def()["drop"]
	drops += 1
	last_drop = at
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(dd["radius"])},
		"effects": [{"type": "damage", "amount": float(dd["dmg"]) * smash_k()},
				{"type": "slow", "duration": float(dd["slow_t"]), "strength": float(dd["slow"])}]})
	run(stg, cx("rmb", "meteor_drop", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f) or f.dead: return
		if Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < float(dd["core"]) + f.r:
			f.hurt(float(dd["dmg"]) * smash_k() * float(dd["core_k"]) * power("sec"), h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "meteor_core"], "stun": float(dd["stun"]),
							"dr": true})
			m.fx.word(f.pos + Vector3(0, 2.3, 0), "CRUSHED", res_col(), false)}))
	fx().star(at + Vector3(0, 0.6, 0), Color(1, 1, 1), 2.6, 0.3, Color(1, 1, 1))
	fx().crescent(at + Vector3(0, 0.2, 0), h.aim_dir(), 330.0, float(dd["radius"]), DROP_PURPLE, Color("ffd0ff"), 0.3)
	m.fx.spark(at, Vector3.UP, DROP_PURPLE, 16, 10.0, 70.0)
	m.fx.dust(at, 18)
	m.sfx("ab_slam", at, -1.0, 0.75)
	m.sfx("jug_slam_hit", at, -3.0, 0.8)
	Feel.shake(m, "leap", h, at)
	net_ring(at, float(dd["radius"]), DROP_PURPLE)

## Small mechanic (the owner's example): while the Warchain pulls you, movement held across the pull
## bends it to that side, so you arrive beside the anchor rather than on it.
func _steer_reel() -> void:
	if reel_t <= 0.0 or h.roll_t <= 0.0 or not st.has("reel_dir") or not lunge.is_empty():
		return
	var base: Vector2 = st["reel_dir"]
	var mv: Vector2 = h.inp.get("move", Vector2.ZERO)
	var side := Vector2(-base.y, base.x)
	h.roll_dir = (base + side * clampf(mv.dot(side), -1.0, 1.0) * REEL_STEER).normalized()

## The reads that aren't a key press: the wounded outlined red while the Smash is ready (yours only),
## the landing disc under the cursor while you're in the air with it ready, and the ring round the body
## while the Searing Wave charges.
func _tick_tells() -> void:
	if not h.is_local() or busy() or KinMerge.active(h):
		return
	var sl: Dictionary = rmb_def()["slam"]
	if rmb_ready():
		for f in foes_in(h.pos, 9.0):
			if f.max_hp > 0.0 and f.hp / f.max_hp < float(sl["low"]):
				AimKit.circle(h, "exec%d" % f.get_instance_id(),
						{"at": f.pos, "r": f.r + 0.4, "col": EXEC_RED, "hot": 0.5, "lw": 0.1})
		if not h.grounded and drop.is_empty() and not h.gliding:
			AimKit.circle(h, "drop_aim",
					{"at": _drop_point(), "r": float(rmb_def()["drop"]["radius"]), "col": DROP_PURPLE, "alpha": 0.7,
							"ticks": true})
	if lmb_t > float(lmb_def()["tap"]):
		var k := wave_k()
		AimKit.circle(h, "wave", {"self": true, "r": 1.35, "fill": k, "col": Color(1, 1, 1)})
		AimKit.charge(h, k, {"col": Color("ff6a4a")})

## During the Warchain's pull: a fiery spin around you that blights everyone it hits.
func _spin() -> void:
	var sp: Dictionary = rmb_def()["spin"]
	spins += 1
	play("jug_spin")
	var stg := stage("rmb",
			{"delivery": {"type": "burst", "origin": "caster", "radius": float(sp["radius"])},
					"effects": [{"type": "damage", "amount": float(sp["dmg"]) * smash_k()}]})
	run(stg, cx("rmb", "cinder_spin", h.pos, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if is_instance_valid(f) and not f.dead: KitStatus.apply(f, "blt", float(sp["blight"]))}))
	for i in 3:
		m.later(0.06 * i,
				func(): if is_instance_valid(h): m.fx.slash(h.pos + Vector3(0, 0.9, 0), m.time * 11.0, TAU,
						float(sp["radius"]), Color("ff7a3a"), i == 2))
	m.fx.ring(h.pos, float(sp["radius"]), Color("ff7a3a"), 0.3)
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CINDER SPIN", Color("ff7a3a"), false)
	m.sfx("ab_whirr", h.pos, -2.0, 0.9)
	m.sfx("ab_blast", h.pos, -6.0, 1.0)
	net_ring(h.pos, float(sp["radius"]), Color("ff7a3a"))

# ------------------------------------------------------------------ E: Warchain (Feysteel Chain)
## "During E" for the Smash is the pull itself (the Cinder Spin).
func in_e() -> bool:
	return reel_t > 0.0

func e_recastable() -> bool:
	return not chain.is_empty()

## The chain's own press: thrown, then recast to pull; its cooldown starts when you pull or it breaks.
func use_e() -> void:
	if busy():
		h._ab_feedback("k1", "deny")
		return
	if not chain.is_empty():
		e_recast()
		return
	if chain_flying or float(cd["e"]) > 0.0 or h.root_t > 0.0 or KitStatus.grounded(h):
		h._ab_feedback("k1", "deny")
		return
	if cast_e():
		h.used["k1"] = int(h.used.get("k1", 0)) + 1
		h._ab_feedback("k1", "cast")
		CombatBus.ability_used.emit(h, id + "_e", "kin")
		last_e = String(e_def().get("name", ""))

func _start_e_cd() -> void:
	cd["e"] = float(e_def().get("cooldown", 13.0)) * cd_k("kin")

func cast_e() -> bool:
	var ed := e_def()
	chain_flying = true
	play("jug_chain")
	var stg := stage("e", {"delivery": {"type": "projectile", "speed": float(ed["speed"]), "range": float(ed["range"]),
			"size": 0.22, "rope": true},
		"effects": [{"type": "damage", "amount": float(ed["dmg"])}]})
	_shots0 = m.shots.size()
	run(stg, cx("e", "warchain", aim(), {
		"on_foe": func(f: Ent, _c: Dictionary):
			if chain.is_empty() and is_instance_valid(f) and not f.dead: _hook(f, f.pos),
		"on_shot_end": func(at: Vector3, why: String, e: Ent):
			chain_flying = false
			if not chain.is_empty() or e != null: return
			if why == "wall": _hook(null, at)
			else:
				_start_e_cd()      # hooked nothing: the chain breaks, its cooldown starts
				m.fx.word(at + Vector3(0, 1.2, 0), "MISS", Color("c0b0a0"), false)}))
	var sd = _my_last_shot()
	if sd != null: fx().ride(sd, "hook", Color("ff9a3a"), Color("ffcf6a"), 0.6, 0.15)
	m.sfx("jug_chain", h.pos, -3.0, 1.0)
	m.sfx("ab_tether", h.pos, -6.0, 0.7)
	return true

func _hook(f: Ent, at: Vector3) -> void:
	var ed := e_def()
	chain_flying = false
	chain = {"target": f, "pos": at, "node": null, "refund": 0.0}
	fx().star(at + Vector3(0, 1.0 if f else 0.5, 0), Color("ffd84a"), 0.9, 0.18)      # the spark at the anchor
	e_t = float(ed["time"])
	if f:
		KitStatus.apply(f, "blt", float(ed["time"]))
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "CHAINED", col_of(ed), true)
		if rank("kin") >= 3: chain["refund"] = float(ed["refund_foe"])
	else:
		m.fx.word(at + Vector3(0, 1.4, 0), "ANCHORED", col_of(ed), false)
	m.fx.ring(at, 0.9, col_of(ed), 0.25)
	m.sfx("ab_tether", at, -2.0, 1.0)
	net_bolt(h.pos + Vector3(0, 1.0, 0), at + Vector3(0, 1.0, 0), col_of(ed))

func _tick_chain(_dt: float) -> void:
	var f = chain["target"]
	if (f != null and (not is_instance_valid(f) or (f as Ent).dead)) or h.stun_t > 0.0:
		_break_chain()          # its foe is gone, or a stun broke it
		return
	if f != null:
		chain["pos"] = (f as Ent).pos
	# attached: a straight striped chain, orange and dark links, that stays on as you walk
	if tells_visible() or f != null:
		var a := h.pos + Vector3(0, 1.0, 0)
		var b: Vector3 = (chain["pos"] as Vector3) + Vector3(0, 1.0 if f != null else 0.6, 0)
		fx().chain("war%d" % h.get_instance_id(), a, b, 0.0, Color("ff9a3a"), Color("3a2a22"), 0.13)

## In flight: a loose orange zig-zag from the hand to the hook.
func _tick_chain_flight() -> void:
	for s in m.shots:
		if s["by"] == h and (s["x"] as Dictionary).get("rope", false):
			fx().chain("war%d" % h.get_instance_id(), h.pos + Vector3(0, 1.0, 0), s["pos"], 1.0, Color("ff9a3a"),
					Color("ffcf6a"), 0.1)
			return

func _drop_chain() -> void:
	var n: Node3D = chain.get("node")
	if n and is_instance_valid(n):
		self_nodes.erase(n)
		n.queue_free()
	var refund := float(chain.get("refund", 0.0))
	chain = {}
	e_t = 0.0
	_start_e_cd()
	if refund > 0.0: cd["e"] = float(cd["e"]) * (1.0 - refund)

func _break_chain() -> void:
	if chain.is_empty():
		return
	m.fx.word(h.pos + Vector3(0, 2.2, 0), "CHAIN BROKE", Color("c0b0a0"), false)
	_drop_chain()

func _e_end() -> void:
	if not chain.is_empty():
		_drop_chain()

## Press E again: pull yourself along the chain to its end (a Smash on the way is a Cinder Spin).
func e_recast() -> bool:
	if chain.is_empty():
		return false
	var ed := e_def()
	var f = chain["target"]
	var dest: Vector3 = chain["pos"]
	_drop_chain()
	if busy() or h.root_t > 0.0:
		return true
	var dv := Vector2(dest.x - h.pos.x, dest.z - h.pos.z)
	var gap := ((f as Ent).r + h.r + 0.2) if f != null else 0.7
	var dist := dv.length() - gap
	if dist < 0.4:
		return true
	var t := dist / float(ed["reel_speed"])
	reels += 1
	play("jug_reel")
	if rmb_down and rmb_t > 0.12 and not rmb_ctx.get("air", false):
		# charging the Smash when you pull: the charge goes into a Haul Slam where you arrive
		var hk := lunge_k(rmb_t)
		rmb_down = false
		rmb_t = 0.0
		if spend_rmb(true):
			haul = {"k": hk}
			last_variant = "during_e"
			play("jug_haul_wind")
	m.later(t + 0.02, func():
		if is_instance_valid(h) and not haul.is_empty() and not h.downed: _haul_land(float(haul["k"])))
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv.normalized()})
	st["reel_dir"] = dv.normalized()
	reel_t = t + 0.15
	m.fx.bolt(h.pos + Vector3(0, 1.0, 0), dest + Vector3(0, 1.0, 0), col_of(ed))
	m.sfx("ab_whirr", h.pos, -3.0, 0.6)
	last_e = "reel"
	return true

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# the Gilded Riposte up close: the guard eats what they throw, then the cleave answers
	if r_unlocked() and float(cd["r"]) <= 0.0 and los and dist < float(r_def()["len"]):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["hult"] = true
		return
	# pulled along the chain: spin as you arrive
	if reel_t > 0.0 and rmb_ready() and int(h.slot_lv["sec"]) > 0:
		h.inp["sec"] = true
		return
	# chained to them: run a Chain Lunge down it, wind up a Smash and pull into a Haul Slam, or just pull
	if not chain.is_empty() and chain.get("target") != null and dist > 3.5 and not rmb_down:
		var roll := randf()
		if rmb_ready() and int(h.slot_lv["sec"]) > 0 and roll < 0.25:
			h.inp["aim"] = tgt.pos
			h.inp["sec"] = true
			bot_hold["rmb"] = 1.0
			return
		if rmb_ready() and int(h.slot_lv["sec"]) > 0 and roll < 0.45:
			h.inp["aim"] = tgt.pos
			h.inp["sec"] = true
			bot_hold["rmb"] = 1.2
			st["bot_haul_at"] = m.time + 0.45
			return
		if roll < 0.8:
			h.inp["sig"] = true
			return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and chain.is_empty() and not chain_flying and los and (dist > 3.0 or (not rmb_ready() and dist > 1.2)) and dist < float(e_def()["range"]) - 0.5 and randf() < 0.4:
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sig"] = true
		return
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and slam_w.is_empty():
		if not h.grounded and dist < 3.0:
			h.inp["aim"] = tgt.pos
			h.inp["sec"] = true
		elif dist < 3.2:
			h.inp["aim"] = tgt.pos
			h.inp["sec"] = true # the Finishing Slam (best on the wounded)
		elif dist < 7.0 and randf() < 0.45:
			h.inp["aim"] = tgt.pos
			h.inp["sec"] = true
			bot_hold["rmb"] = float(rmb_def()["hold"]) + (float(rmb_def()["full_t"]) - float(rmb_def()["hold"])) * clampf((dist - 3.0) / 4.0, 0.0, 1.0) + 0.05
	# keep the wound-up slam on them while it winds up
	if not slam_w.is_empty():
		h.inp["aim"] = tgt.pos
	# Rampage in: the tip is the sweet spot, so dash from about a dash length out, facing them
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and lunge.is_empty() and dist > 2.5 and dist < 6.0 and randf() < 0.25:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
