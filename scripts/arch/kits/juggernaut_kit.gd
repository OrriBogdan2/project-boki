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
## - Dash, Rampage (Flame Step): 2 charges (3 at rank 2) of a dash attack the way you face, the tip hits double.
## - E, Warchain (Feysteel Chain): a chain to a foe (blighted) or a wall; recast to pull yourself in.
## - X, Gilded Riposte (JuggernautUlt, level 6): a 0.65s gold guard that blocks everything, then a lunging
##   upward cleave that heals 80% of its damage; a knock with it makes it ready again. The Boki Merge has its own key.
## Matched to the footage in briefs/hero-ref/juggernaut.md; docs/heroes/juggernaut.md.

const SLASH_OUT := Color("ff3df0")     # the Slam's magenta strike lane
const LUNGE_RED := Color("ff4a3a")     # the Lunge lane while charging
const LUNGE_FULL := Color("ff3df0")    # ... at full
const EXEC_RED := Color("ff2a2a")      # the wounded-enough-to-finish outline
const WAVE_RED := Color("ff3a2a")      # the Searing Wave's flame crescent
const WAVE_EDGE := Color("ff9a3a")     # ... its orange inner edge
const WAVE_FULL := Color("ffc23a")     # ... gold-hot at full charge
const BUFFER := 0.12                   # s: a press this close before a heavy move ends goes off when it does

var enraged_t := 0.0
var aura: Node3D = null        # the Enraged look: a red shell, a glow, the hunter grown bigger
var grow := 0.0                # 0..1 how far into the Enraged form the model is
var lmb_t := -1.0              # how long the attack key has been held with the greatsword (-1: not)
var lmb_was := false
var lmb_buf := 0.0
var bot_wave_t := 0.0
var slash_n := 0
var slash_at := -9.0
var slam_w := {}               # the Finishing Slam winding up: {t, dir (at the press), pinned (to dir: E went)}
var lunge := {}                # the running Lunge: {end, dir, k, hit}
var warchain: JuggernautChain  # E (its state machine)
var meteor: JuggernautDrop     # the airborne Smash
var rmb_queued_at := -9.0      # a Smash pressed while a heavy move ran (BUFFER)
var dash_held := false         # Shift pressed during a move whose into_dash row holds it to the move's end
var slam_hit := {}             # foe id -> when the Finishing Slam hit them (a knock within 2s resets X)
var riposte: JuggernautUlt     # X, the ultimate
var sweet_spots := 0           # (tests, demo)
var waves := 0
var tips := 0
var slam_resets := 0           # Riposte resets from a Slam sweet spot then a knock
var spins := 0
var chain_lunges := 0
var haul_slams := 0
var haul := {}                 # a Haul Slam armed for the end of the pull: {k}
var lunge_full := false        # the Lunge charge reached full (its flash played)
var perfect_flashed := -1      # the last perfect window whose cue played (-1: none this hold)
var perfects := 0              # (tests) Lunges let go in a perfect window
var knock_healed := 0.0        # (tests) health the knock heals gave back
var rampage_wind := 0.0        # the Rampage's crouch still to go before the drive
var rampage_dir := Vector2.ZERO  # the way the Rampage will drive once its crouch ends

func _setup() -> void:
	riposte = JuggernautUlt.new(self)
	warchain = JuggernautChain.new(self)
	meteor = JuggernautDrop.new(self)
	cd["air"] = 0.0             # the Meteor Drop's own cooldown slot

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

## Two Rampage charges, a third at rank 2.
func extra_dashes() -> float:
	return 1.0 if rank("dash") >= 2 else 0.0

## The Rampage's dodge at the last rank: a shot dodged through it feeds Rage.
func on_perfect_dodge() -> void:
	if rank("dash") >= 3:
		add_res(float(dash_def().get("dodge_rage", 15.0)))
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "RAGE", res_col(), false)

## Warchain cooldown per rank: 12.5% off at rank 2, 37.5% in all at rank 3 (the data's -2s three times).
func cd_k(slot: String) -> float:
	if slot != "kin":
		return super.cd_k(slot)
	return 1.0 - float(e_def().get("rank_cut", 0.125)) * float([0, 1, 3][clampi(rank("kin") - 1, 0, 2)])

func _enrage_fx() -> void:
	var rc := res_col()
	if lunge.is_empty() and slam_w.is_empty() and not rmb_down: play("jug_roar")
	vfx("enrage")
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "ENRAGED", rc, true)
	if h.is_local():
		if m.hud: m.hud.flash(rc, 0.15)
	_make_aura()

func _make_aura() -> void:
	if aura and is_instance_valid(aura):
		return
	aura = Node3D.new()
	# the Enraged look is on the body (the "enraged" hold, _tick_look), no shell or ground disc and no light
	# (from above those read as a pale disc that hid his feet)
	h.add_child(aura)

func _drop_aura() -> void:
	if aura and is_instance_valid(aura):
		aura.queue_free()
	aura = null

## Spending the Rage: the shell bursts outward and the hunter shrinks back.
func _spend_fx() -> void:
	var rc := res_col()
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), rc, 26, 7.0, 0.5, 4.0, 1.3)
	_drop_aura()

func _tick_look(dt: float) -> void:
	var want := 1.0 if enraged_t > 0.0 else 0.0
	grow = move_toward(grow, want, dt * (6.0 if want > grow else 3.0))
	if h.model:
		# grow from the model's own size (class, body and the shared visual scale), never replace it
		if not h.model.has_meta("base_scale"):
			h.model.set_meta("base_scale", h.model.scale)
		h.model.scale = (h.model.get_meta("base_scale") as Vector3) * (1.0 + 0.16 * grow)
	if enraged_t <= 0.0 and aura:
		_drop_aura()
	# everyone sees how hot he is: embers off the shoulders that thicken with Rage, then the whole body burning
	if not tells_visible():
		return
	var hk := heat_k()
	if enraged_t > 0.0:
		HeroVfx.of(m).hold(h, "enraged")
	elif hk > 0.15:
		HeroVfx.of(m).hold(h, "heat", hk)

func _tick(dt: float) -> void:
	_tick_look(dt)
	_tick_trail()
	if rampage_wind > 0.0: _tick_crouch(dt)
	var rd := res_def()
	if enraged_t > 0.0:
		enraged_t -= dt
		if enraged_t <= 0.0:
			enraged_t = 0.0
			res = 0.0
			_drop_aura()
		# Enraged: cooldowns and dash charges come back faster
		for k in ["rmb", "e", "air"]:
			cd[k] = maxf(0.0, float(cd[k]) - dt * float(rd.get("ab_haste", 0.2)))
		if h.dashes < h.max_dashes():
			h.dashes = minf(h.max_dashes(), h.dashes + dt / h.dash_regen() * float(rd.get("dash_haste", 0.12)))
	elif res_wait <= 0.0:
		add_res(-float(rd.get("decay", 9.0)) * dt)
	if lmb_buf > 0.0: lmb_buf -= dt
	if not slam_w.is_empty(): _tick_slam(dt)
	if not lunge.is_empty(): _tick_lunge()
	warchain.tick(dt)
	riposte.tick(dt)
	meteor.tick(dt)
	_flush_buffer()
	_end_held_poses()
	_tick_tells()
	if st.has("bot_haul_at") and m.time >= float(st["bot_haul_at"]):
		st.erase("bot_haul_at")
		if rmb_down and warchain.hooked(): warchain.press()     # a bot pulling in with the Smash charged
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
	if meteor.running(): return meteor.move_k()
	if not slam_w.is_empty(): return 0.6
	if lunge_charging(): return float(rmb_def()["lunge"]["hold_move"])
	return 0.55 if lmb_t > float(lmb_def().get("tap", 0.22)) else 1.0

## The Lunge's hold, on the ground and out of the pull: the source's Heavy Attack hold walks at about 0.8 of a run.
func lunge_charging() -> bool:
	var past_tap := rmb_down and rmb_t > float(rmb_def()["hold"])
	return past_tap and not rmb_ctx.get("air", false) and not rmb_ctx.get("e", false)

## A knock (ours, or one we helped with): ours heals a share of the knocked hunter's health; either
## way, if the Finishing Slam hit them in the last 2s the Gilded Riposte is ready again (the data: "knocking an
## enemy resets Volcanic Rebuke", any hit, not only the sweet spot).
func on_knock(t: Hunter, mine: bool) -> void:
	var rd := res_def()
	if mine and is_instance_valid(t):
		var hp0 := h.hp
		h.heal(t.max_hp * float(rd.get("heal_knock", 0.2)))
		knock_healed += h.hp - hp0
		fx().pillar(h.pos, Color("5ae07a"), 3.6, 0.7, 0.75)
		fx().star(t.pos + Vector3(0, 1.3, 0), Color("ff2a2a"), 3.2, 0.55, Color(1, 0.85, 0.8))
		m.fx.word(h.pos + Vector3(0, 2.7, 0), "+%d" % int(round(h.hp - hp0)), Color("7fe08a"), true)
		m.sfx("juggernaut_heal", h.pos, -4.0, 1.0)
		if h.is_local() and m.hud: m.hud.flash(Color(1, 0.1, 0.05), 0.12)      # the red tint of a kill
	var key := t.get_instance_id() if is_instance_valid(t) else -1
	if slam_hit.has(key) and m.time - float(slam_hit[key]) <= float(rmb_def()["slam"].get("reset_t", 2.0)):
		slam_hit.erase(key)
		_reset_riposte()

## The Slam then a knock: the Gilded Riposte (X) is ready again (once it is unlocked).
func _reset_riposte() -> void:
	if float(cd["x"]) <= 0.0 or h.lvl < int(Hunter.ULT_AT[0]):
		return
	cd["x"] = 0.0
	slam_resets += 1
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "RIPOSTE READY", col_of(x_def()), true)      # no ring on a reset
	m.sfx("ab_ready", h.pos, -2.0, 0.8)
	if h.is_local(): h._ab_feedback("x", "ready")

# ------------------------------------------------------------------ X: Gilded Riposte (JuggernautUlt)
## X (main's HunterKeys gate: level 6; HeroUlt.press: its own cooldown in cd["x"], the cast id).
func cast_ult() -> bool:
	return HeroUlt.press(self, _start_riposte)

func has_ult() -> bool:
	return true

func _start_riposte() -> bool:
	rampage_wind = 0.0                 # X in the Rampage's crouch (its dash row: cancel): no drive after the guard
	riposte.start()
	return true

func ult_running() -> bool:
	return riposte.running()

## Planted in the guard and the cleave: no other button does anything (but E on a held chain, use_e).
func busy() -> bool:
	return super.busy() or (riposte != null and riposte.move_k() <= 0.0)

## Owner 113.2: a held Smash never opens the glider on a jump, nor do the Riposte's guard and cleave. Its last
## beat, the recovery, is open: a glide there ends the rest of it.
func no_glide() -> bool:
	return rmb_down or (riposte != null and riposte.move_k() <= 0.0)

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
	rampage_wind = 0.0
	lmb_t = -1.0
	lmb_buf = 0.0
	h.mel_hold = 0.0
	slam_w = {}
	haul = {}
	meteor.cancel()
	warchain.snap("")
	rmb_queued_at = -9.0
	dash_held = false
	lunge_full = false
	perfect_flashed = -1

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
	# (a merge ends the charge: letting go of it must not swing a wave mid-transformation); a press while a
	# pull, a dash or a Meteor Drop holds the blade is kept for BUFFER and swings when it's free
	if not h.can_fire() or KinMerge.transforming(h) or meteor.running():
		if lmb_t >= 0.0 and _hold_waits():
			return true         # a dash whose hold row keeps the Searing Wave charge: it waits for the dash's end
		if lmb_t >= 0.0:
			lmb_t = -1.0
			h.mel_hold = 0.0
		# (a press in a dash is DashFlow's to hold)
		if pressed and not KinMerge.transforming(h) and not in_dash(): lmb_buf = BUFFER
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
			_wave_preview()
			if anim_id != "jug_wave_wind": play("jug_wave_wind")
	elif lmb_t >= 0.0:
		if lmb_t < float(ld["tap"]): _slash()
		else: _wave()
	elif lmb_buf > 0.0 and h.fire_cd <= 0.0:
		lmb_buf = 0.0
		_slash()
	return true

## The Searing Wave charging: its lane on the ground grows as long and as wide as the wave it would throw now,
## going gold-hot at full, and the cursor ring fills.
func _wave_preview() -> void:
	var ld := lmb_def()
	var k := wave_k()
	var lane := {"len": lerpf(float(ld["wave_range"][0]), float(ld["wave_range"][1]), k),
			"width": lerpf(float(ld["wave_size"][0]), float(ld["wave_size"][1]), k) * 2.0, "k": k, "fill": k,
			"col": WAVE_RED, "col_full": WAVE_FULL}
	AimKit.lane(h, "lmb", lane)
	AimKit.charge(h, k, {"col": WAVE_RED, "col2": WAVE_FULL})
	HeroVfx.of(m).hold(h, "wave_charge", k)

## The Searing Wave charge waits out what stops the blade, rather than ending: a dash its hold row keeps it through.
func _hold_waits() -> bool:
	return flow.pauses_hold("lmb") and not KinMerge.transforming(h) and not meteor.running()

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
	# the swing's arc of flame, sweeping the other way each swing, and a burst on anyone caught at the tip
	var dv := h.aim_dir()
	vfx("slash", h.pos, dv, {"flip": slash_n % 2 == 0, "r": float(ld["reach"]), "arc": float(ld["arc"])})
	for f in foes_in(h.pos, float(ld["reach"]) + 0.4):
		var to := Vector2(f.pos.x - h.pos.x, f.pos.z - h.pos.z)
		if to.length() >= float(ld["reach"]) * 0.7 and absf(dv.angle_to(to)) <= deg_to_rad(float(ld["arc"]) * 0.5):
			vfx("slash_tip", f.pos, dv)

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
	AimKit.hide(h, "lmb")
	h.fire_cd = float(ld["wave_rate"])
	waves += 1
	play("jug_wave")
	var full := k >= 0.99
	var rng := lerpf(float(ld["wave_range"][0]), float(ld["wave_range"][1]), k)
	var wave_size := lerpf(float(ld["wave_size"][0]), float(ld["wave_size"][1]), k)
	var effs: Array = [{"type": "damage", "amount": lerpf(float(ld["wave_dmg"][0]), float(ld["wave_dmg"][1]), k)},
			{"type": "push", "strength": lerpf(3.0, 6.0, k), "from": "caster"}]
	if full:
		effs.append({"type": "damage", "amount": float(ld["wave_burn"]) * 2.0, "over": 2.0})
		effs.append({"type": "slow", "duration": 1.0, "strength": float(ld["wave_slow"])})
	var stg := StageSpec.parse(
			{"delivery": {"type": "projectile", "speed": float(ld["wave_speed"]), "range": rng, "size": wave_size},
					"effects": effs, "modifiers": [{"type": "pierce", "count": 6}]},
			"", GrammarReport.new())
	var c := KinExec.make_cx(m, h, h.kin, h, aim(), _wk(), "primary", "searing_wave")
	_shots0 = m.shots.size()
	run_own(stg, c)
	# the fire rolling along its line: a red standing crescent of flame (pooled) riding the wave's shot
	var dv := h.aim_dir()
	var from := h.pos
	var sd: Variant = _my_last_shot()
	if sd != null:
		sd["col"] = WAVE_RED              # its sparks along the way are red too
		fx().ride(sd, "crescent_bolt", WAVE_RED, WAVE_EDGE if not full else WAVE_FULL, 1.6, wave_size * 3.6)
	vfx("wave_fire", from, dv, {"k": k, "full": full, "len": rng, "w": wave_size * 2.0})
	h.swing_t = 0.18
	h.swing_n += 1
	Oomph.on_fire(h, true)

# ------------------------------------------------------------------ dash: Rampage
## Shift during one of his moves does what its into_dash row in content/dash_flow/juggernaut.json says: held to
## the move's end ("buffer"), the move dropped and the dash at once ("cancel"; out of the Warchain's pull the drive
## goes at once, the pull's speed running into it), or the dash at once with the move running on ("fire"). Out of
## the Slam's wind-up that is a Slam Drive: the drive goes at once along the strike's aim, the overhead pose kept,
## and the Slam lands where it arrives. A Lunge or a Meteor Drop's dive is a dash of its own: Shift goes as it ends.
func on_dash(use_ex: bool) -> bool:
	if _dash_waits():
		dash_held = true
		return true
	var slot := _move_slot()
	var from_pull := slot == "e" and _into_mode(slot) == "cancel"
	var from_slam := not slam_w.is_empty() and h.grounded
	if from_pull:
		warchain.dash_out()
	if riposte.running():
		riposte.drop()               # (only its recovery is left by now: Shift moves him out of it)
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		travel(float(h.cdat.get("ex_dist", 4.2)), float(h.cdat.get("ex_time", 0.21)),
				{"invuln": 0.08, "trail": "dust"})
		if not meteor.running(): play("jug_exdash")     # an air dash: a hurled shoulder charge, knees tucked
		return true
	if not spend_dash(false):
		return true
	var dd := dash_def()
	var wind := 0.0 if from_pull or from_slam else float(dd.get("windup", 0.15))
	var dir := h.aim_dir() if from_slam else dash_dir()
	rampage_dir = dir
	st["last_dash"] = "rampage"
	h.glide_cd = maxf(h.glide_cd, wind + float(dd["time"]) + 0.35)    # its wind-down: no glider straight out
	if from_slam:
		_rampage(dir)                # the Slam's own keys run on: the overhead blade rides the drive in
		return true
	play("jug_dash")                 # the crouch with the blade cocked high behind, then the drive
	if from_pull:
		anim_at -= float(dd.get("windup", 0.15))       # (straight into the drive's keys)
		_rampage(dir)
		return true
	vfx("dash_wind", h.pos, dir)
	# the crouch is the dash's start standing still (planted; DashFlow and the dash rules see the dash from here)
	rampage_wind = wind
	h.dash_with({"type": "dash", "speed": 0.0, "time": wind, "dir": dir, "invuln": 0.0})
	return true

## The crouch before the drive: the drive goes when it's done, unless something ended the dash first (a stun,
## a dash row's cancel such as X, a merge).
func _tick_crouch(dt: float) -> void:
	if h.roll_t <= 0.0 or h.downed or h.stun_t > 0.0:
		rampage_wind = 0.0
		return
	rampage_wind -= dt
	if rampage_wind <= 0.0:
		rampage_wind = 0.0
		_rampage(rampage_dir)

## Rampage's drive after the crouch: the dash attack along `dir`, the tip at its end.
func _rampage(dir: Vector2) -> void:
	var dd := dash_def()
	var t := float(dd["time"])
	var pk := power("dash") / maxf(0.01, m.dmg_mult(h))
	rampage_wind = 0.0
	travel(float(dd["dist"]), t,
			{"invuln": 0.06, "shove": true, "shove_kb": float(dd["hit_kb"]), "shove_dmg": float(dd["hit_dmg"]) * pk,
					"trail": "dust", "dir": dir})
	vfx("dash_go", h.pos, dir, {"len": float(dd["dist"]) * float(dash_feel()["dist"])})
	m.later(t * 0.85, func(): if is_instance_valid(h) and not h.downed: _tip())

## His own after-images on a dash: orange flame streaks along the ground behind him, not the shared pill.
func own_dash_trail() -> bool:
	return true

func _tick_trail() -> void:
	if h.roll_t > 0.0 and h.roll_speed >= 1.0 and tells_visible():
		HeroVfx.of(m).hold(h, "dash_drive")

## The tip of the Rampage: the sweet spot, a short arc at the end of the dash.
func _tip() -> void:
	var dd := dash_def()
	var dv := h.roll_dir if h.roll_dir.length() > 0.1 else h.aim_dir()
	var at := h.pos + Vector3(dv.x, 0, dv.y) * 0.9
	var hit := false
	for f in foes_in(at, float(dd["tip_r"])):
		hit = true
		f.hurt(float(dd["tip_dmg"]) * power("dash"), h,
				{"src": "abil", "ab": "dodge", "tags": ["dodge", "tip"], "kb": dv * float(dd["tip_kb"]),
						"melee": true, "crit": true})
		m.fx.word(f.pos + Vector3(0, 2.2, 0), "TIP", res_col(), false)
	vfx("dash_tip", h.pos, dv, {"hit": hit})
	if hit:
		tips += 1

# ------------------------------------------------------------------ RMB: Smash (Adaptive Strike)
func rmb_charge_full() -> float:
	return float(rmb_def().get("full_t", 0.9))

## Held as long as you like: it never lets go by itself (the Lunge waits at full until you let go).
func rmb_auto_t() -> float:
	return INF

## Holding past the tap: the Lunge's crouched wind-up pose (held while you charge). Hooked, the lane runs
## down the chain instead: letting go is a Chain Lunge along it.
func rmb_hold_tick(t: float) -> void:
	var sd := rmb_def()
	if t <= float(sd["hold"]) or rmb_ctx.get("air", false) or rmb_ctx.get("e", false):
		return
	# the Lunge charging: a lane grows ahead of you with a fill, magenta and flashing at full; the cursor ring
	# fills; a rising whine on the way in, a ping at full
	var k := lunge_k(t)
	var ld: Dictionary = sd["lunge"]
	var feel := float(dash_feel()["dist"])        # the lane shows the fling travel() really makes
	var lane := {"len": float(ld["dist"][1]) * feel, "len0": float(ld["dist"][0]) * feel, "k": k, "fill": k,
			"width": 1.3, "col": LUNGE_RED, "col_full": LUNGE_FULL, "tip": true}
	if warchain.hooked():
		var to := warchain.anchor - h.pos
		lane["dir"] = Vector2(to.x, to.z)
		lane["len"] = Vector2(to.x, to.z).length()
		lane["len0"] = lane["len"]
	AimKit.lane(h, "rmb", lane)
	AimKit.charge(h, k, {"col": LUNGE_RED, "col2": LUNGE_FULL})
	HeroVfx.of(m).hold(h, "lunge_charge", k)
	if anim_id != "jug_lunge_wind":
		play("jug_lunge_wind")
		vfx("lunge_wind")
	if k >= 1.0 and not lunge_full:
		lunge_full = true
		vfx("lunge_full")
	var window := perfect_window(t)
	if window >= 0 and window != perfect_flashed:
		perfect_flashed = window
		_perfect_cue()

## The perfect-release window the held Lunge is in at `t` s of hold (0 at full charge, then one every
## lunge.perfect_every), or -1 between them.
func perfect_window(t: float) -> int:
	var ld: Dictionary = rmb_def()["lunge"]
	var since := t - rmb_charge_full()
	if since < 0.0:
		return -1
	var every := float(ld["perfect_every"])
	return int(since / every) if fmod(since, every) < float(ld["perfect_w"]) else -1

## "Now": the raised blade flashes white-hot at its tip and rings out.
func _perfect_cue() -> void:
	vfx("lunge_perfect")

func lunge_k(t: float) -> float:
	var sd := rmb_def()
	return clampf((t - float(sd["hold"])) / maxf(0.05, float(sd["full_t"]) - float(sd["hold"])), 0.0, 1.0)

## Every Smash's damage: its rank, and +20% more at rank 2 and again at rank 3.
func smash_k() -> float:
	return 1.0 + 0.2 * float(clampi(rank("sec") - 1, 0, 2))

## The Meteor Drop's own cooldown, 2.4s shorter at rank 3.
func air_cooldown() -> float:
	var dd: Dictionary = rmb_def()["drop"]
	return float(dd["cooldown"]) - (float(dd["r3_cut"]) if rank("sec") >= 3 else 0.0)

## Spends the Meteor Drop's slot (the Smash's charge stays ready). False, with the deny buzz, while it rests.
func spend_air() -> bool:
	if float(cd["air"]) > 0.0:
		h._ab_feedback("sec", "deny")
		return false
	cd["air"] = air_cooldown()
	h.used["utility"] = int(h.used.get("utility", 0)) + 1
	h._ab_feedback("sec", "cast")
	CombatBus.ability_used.emit(h, id + "_rmb", "secondary")
	return true

## While airborne the secondary slot shows the Meteor Drop's own cooldown.
func slot_info(slot: String) -> Dictionary:
	var out := super.slot_info(slot)
	if slot in ["sec", "utility"] and not h.grounded:
		out["cd"] = float(cd["air"])
		out["cd_max"] = air_cooldown()
		out["ready"] = float(cd["air"]) <= 0.0
	return out

## The Smash press. A press while a heavy move runs (the Slam's wind-up, a Lunge, a Meteor Drop) is kept for
## BUFFER and goes off when it ends; in the Warchain's pull (and just after) it spins at once.
func press_rmb() -> void:
	if _locked():
		rmb_queued_at = m.time
		return
	super.press_rmb()
	if rmb_down and rmb_ctx.get("e", false):
		_release_rmb()

## A heavy move owns the body: Smash and slash presses wait (BUFFER).
func _locked() -> bool:
	return not slam_w.is_empty() or not lunge.is_empty() or meteor.running()

## Presses kept while a heavy move ran go off once it's done, if they're recent enough.
func _flush_buffer() -> void:
	if not _locked() and rmb_queued_at > -9.0:
		var fresh: bool = m.time - rmb_queued_at <= BUFFER
		rmb_queued_at = -9.0
		if fresh and not rmb_down: press_rmb()
	if dash_held and not _dash_waits():
		dash_held = false
		h.do_dash()

## Which of his moves owns the body now, by slot ("" for none): the Gilded Riposte's guard and cleave, a Smash
## (the Slam's wind-up, a Lunge, a Meteor Drop in the air), the Warchain's pull.
func _move_slot() -> String:
	if riposte.move_k() <= 0.0:
		return "x"
	if not slam_w.is_empty() or not lunge.is_empty() or meteor.airborne():
		return "rmb"
	if warchain.pulling():
		return "e"
	return ""

func _into_mode(slot: String) -> String:
	return String(DashFlow.into_row_of(id, slot, flow.dash_move())["mode"])

## Shift is held now (it goes the step this turns false): a move whose into_dash row buffers it (the guard and
## the cleave), or a Lunge or a Meteor Drop's dive, each a dash of its own.
func _dash_waits() -> bool:
	var slot := _move_slot()
	if slot != "" and _into_mode(slot) == "buffer":
		return true
	return not lunge.is_empty() or meteor.phase == "dive"

## In the Rampage as DashFlow sees it (its crouch is the dash standing still); a Lunge, also a travelled dash, is
## not: the RMB rules own it.
func in_dash() -> bool:
	return super.in_dash() and lunge.is_empty()

## A held pose ends with its hold (a charge dropped without a release must not freeze the body).
func _end_held_poses() -> void:
	var over := (anim_id == "jug_wave_wind" and lmb_t < 0.0) or (anim_id == "jug_lunge_wind" and not rmb_down) \
			or (anim_id == "jug_haul_wind" and haul.is_empty()) or (anim_id == "jug_meteor" and not meteor.airborne())
	if over:
		anim_id = ""

## The RMB variants by state: docs/heroes/juggernaut.md "RMB: the interaction table".
func fire_rmb(c: Dictionary) -> void:
	last_variant = String(c["variant"])
	if _locked():
		return
	var spin: bool = c.get("e", false)
	var dropping: bool = c.get("air", false) and not spin
	if dropping:
		if not spend_air(): return
	elif not spend_rmb():
		return
	if spin:
		_spin()                     # in the Warchain's pull, or just arrived
	elif warchain.hooked() and c.get("hold", false) and not c.get("air", false):
		_chain_lunge(lunge_k(float(c.get("t", 0.0))))      # charged while tethered: along the chain
	elif dropping:
		meteor.start()
	elif c.get("hold", false):
		var held_t := float(c.get("t", 0.0))
		_lunge(lunge_k(held_t), perfect_window(held_t) >= 0)
	else:
		# the Finishing Slam winds up first (you keep aiming); everyone sees the warning over you
		slam_w = {"t": float(rmb_def()["windup"]), "dir": h.aim_dir()}
		play("jug_slam")                # keyed to the wind-up: the strike lands at 0.6s
		vfx("slam_tell")

func _tick_slam(dt: float) -> void:
	slam_w["t"] = float(slam_w["t"]) - dt
	if h.stun_t > 0.0 or h.downed or Hex.active(h):
		slam_w = {}          # interrupted
		return
	# the short magenta strike lane ahead of him, filling as the wind-up runs (everyone sees it)
	var sl: Dictionary = rmb_def()["slam"]
	var wk := 1.0 - clampf(float(slam_w["t"]) / float(rmb_def()["windup"]), 0.0, 1.0)
	var pin: Vector2 = slam_w["dir"] if slam_w.get("pinned", false) else Vector2.ZERO
	var lane := {"len": float(sl["radius"]), "width": 1.9, "fill": wk, "col": SLASH_OUT, "all": true, "chevrons": 2}
	if pin != Vector2.ZERO:
		lane["dir"] = pin
	AimKit.lane(h, "slam", lane)
	HeroVfx.of(m).hold(h, "slam_wind", wk)
	if float(slam_w["t"]) <= 0.0:
		slam_w = {}
		_slam(pin)

## The Finishing Slam: a heavy cone; the wounded (under 35%) take +50%; a foe in the sweet spot (the far
## tip, dead ahead) is the payoff, and a knock on that foe within 2s makes the Gilded Riposte ready again.
func _slam(pin := Vector2.ZERO) -> void:
	var sd := rmb_def()
	var sl: Dictionary = sd["slam"]
	var dd := h.aim_dir() if pin == Vector2.ZERO else pin
	var effs: Array = [{"type": "damage", "amount": float(sl["dmg"]) * smash_k()},
			{"type": "push", "strength": float(sl["push"]), "from": "caster"}]
	var stg := stage("rmb",
			{"delivery": {"type": "cone", "radius": float(sl["radius"]), "angle": float(sl["angle"])}, "effects": effs})
	var from := h.pos
	var paid := {}
	var at := aim() if pin == Vector2.ZERO else h.pos + Vector3(pin.x, 0, pin.y) * float(sl["radius"])
	run_own(stg, cx("rmb", "finishing_slam", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if not is_instance_valid(f): return
		if not f.dead and f.max_hp > 0.0 and f.hp / f.max_hp < float(sl["low"]):
			f.hurt(float(sl["dmg"]) * smash_k() * float(sl["low_k"]) * power("sec"), h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "execute"], "crit": true, "melee": true})
			m.fx.word(f.pos + Vector3(0, 2.4, 0), "EXECUTE", Color("ffd0a0"), true)
		var to := Vector2(f.pos.x - from.x, f.pos.z - from.z)
		var sw: Array = sl["sweet"]
		var in_band := to.length() >= float(sw[0]) and to.length() <= float(sw[1]) + f.r
		var sweet := in_band and absf(rad_to_deg(dd.angle_to(to.normalized()))) <= float(sl["sweet_deg"])
		Feel.hitstop(m, h, f, 30.0, {"melee": true, "payoff": sweet, "heavy": true})
		if sweet and not f.dead:
			# the data's "edge hits do more": the far tip lands sweet_k harder
			f.hurt(float(sl["dmg"]) * smash_k() * float(sl["sweet_k"]) * power("sec"), h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "sweet"], "melee": true})
		if sweet and not paid.has("x"):
			paid["x"] = true
			sweet_spots += 1
			payoff_fx(f.pos, "SWEET SPOT", res_col(), "pay_rage", dd, f)
			vfx("slam_sweet", f.pos, dd)
		slam_hit[f.get_instance_id()] = m.time}))
	AimKit.hide(h, "slam")
	vfx("slam_hit", h.pos, dd, {"r": float(sl["radius"])})

## The hold: a charged dash attack into the first foe in its path; a miss doubles the cooldown.
## The Lunge let go at charge `k`; `perfect`: in a perfect window, it flings him lunge.perfect_k further.
func _lunge(k: float, perfect: bool) -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var dist := lerpf(float(ld["dist"][0]), float(ld["dist"][1]), k) * (float(ld["perfect_k"]) if perfect else 1.0)
	var t := dist / float(ld["speed"])
	var dv := h.aim_dir()
	lunge_full = false
	perfect_flashed = -1
	AimKit.hide(h, "rmb")
	travel(dist, t, {"invuln": 0.0, "trail": "dust", "dir": dv})
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	lunge = {"end": m.time + t * float(dash_feel()["time"]) + 0.02, "dir": dv, "k": k}
	play("jug_lunge")
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "LUNGE", col_of(rmb_def()), false)
	vfx("lunge_go", h.pos, dv, {"k": k, "len": dist * float(dash_feel()["dist"]), "perfect": perfect})
	if perfect:
		perfects += 1
		AimKit.perfect(h, {"col": LUNGE_FULL})

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
			var dmg := lerpf(float(ld["dmg"][0]), float(ld["dmg"][1]), k) * smash_k() * (1.25 if was_chain else 1.0)
			var stg := stage("rmb",
					{"delivery": {"type": "burst", "origin": "here", "radius": 0.0},
							"effects": [{"type": "damage", "amount": dmg},
									{"type": "push", "strength": float(ld["push"]), "from": "caster"}]},
					{"hit": "add", "mod": "add"})
			var c := cx("rmb", "lunge", f.pos, {"at": f.pos})
			KinExec.apply_foe(stg.effects, f, c, f.pos, stg)
			vfx("lunge_hit", f.pos, dv, {"k": k})
			return
	if m.time >= float(lunge["end"]) or h.roll_t <= 0.0:
		var to_wall: bool = lunge.get("chain", false)
		lunge = {}
		h.glide_cd = maxf(h.glide_cd, 0.35)      # the dash's wind-down: no glider straight out of it
		if to_wall:
			return                  # down the chain to a wall: it went where it was sent
		cd["rmb"] = float(cd["rmb"]) * float(ld["miss_k"])        # struck nothing: the cooldown doubles
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "MISS", Color("c0b0a0"), false)

## Charged while tethered and let go: the Lunge runs along the chain to its end (the foe it holds, or
## the wall), harder and with a short stun on the foe; the chain is spent.
func _chain_lunge(k: float) -> void:
	var ld: Dictionary = rmb_def()["lunge"]
	var f := warchain.target
	var dest := warchain.anchor
	var dv := Vector2(dest.x - h.pos.x, dest.z - h.pos.z)
	var gap := (f.r + h.r) if f != null and is_instance_valid(f) else 0.7
	var dist := clampf(dv.length() - gap + 0.6, 2.0, float(e_def()["range"]) + 1.0)
	var t := dist / (float(ld["speed"]) * 1.25)
	chain_lunges += 1
	vfx("chain_lunge", h.pos, dv.normalized(), {"len": dist})
	warchain.spend()
	# the whole way down the chain (travel() scales by the global dash feel; the chain sets the length)
	var feel := dash_feel()
	travel(dist / float(feel["dist"]), t / float(feel["time"]),
			{"invuln": 0.0, "trail": "dust", "dir": dv.normalized()})
	h.fortify_t = maxf(h.fortify_t, t + 0.05)
	lunge = {"end": m.time + t + 0.02, "dir": dv.normalized(), "k": k, "chain": true}
	play("jug_chainlunge")
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CHAIN LUNGE", Color("ffcf6a"), true)

## The pull starting with the Lunge charging: the charge becomes a Haul Slam for the arrival.
func arm_haul() -> void:
	if not rmb_down or rmb_t <= 0.12 or rmb_ctx.get("air", false):
		return
	var hk := lunge_k(rmb_t)
	rmb_down = false
	rmb_t = 0.0
	lunge_full = false
	perfect_flashed = -1
	AimKit.hide(h, "rmb")
	if spend_rmb(true):
		haul = {"k": hk}
		last_variant = "during_e"
		play("jug_haul_wind")

## The pull arrived: an armed Haul Slam comes down.
func land_haul() -> void:
	if not haul.is_empty() and not h.downed:
		_haul_land(float(haul["k"]))

## The pull ended some other way (Shift, a jump, a stun): the armed Haul Slam is dropped and the Smash given back.
func drop_haul() -> void:
	if haul.is_empty():
		return
	haul = {}
	ch_rmb = minf(float(rmb_charges()), ch_rmb + 1.0)

func _haul_land(k: float) -> void:
	var hd: Dictionary = rmb_def()["haul"]
	haul = {}
	haul_slams += 1
	var at := h.pos
	var stg := stage("rmb", {"delivery": {"type": "burst", "origin": "caster", "radius": float(hd["radius"])},
		"effects": [{"type": "damage", "amount": lerpf(float(hd["dmg"][0]), float(hd["dmg"][1]), k) * smash_k()},
				{"type": "push", "strength": float(hd["push"])}]})
	run_own(stg, cx("rmb", "haul_slam", at, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if is_instance_valid(f) and not f.dead:
			f.hurt(1.0, h,
					{"src": "abil", "ab": "utility", "tags": ["utility", "haul_slam"],
							"stun": lerpf(float(hd["stun"][0]), float(hd["stun"][1]), k), "dr": true})}))
	play("jug_haulslam")
	m.fx.word(at + Vector3(0, 2.6, 0), "HAUL SLAM", Color("ffcf6a"), true)
	vfx("haul_hit", at, h.aim_dir(), {"r": float(hd["radius"])})

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
	# the Meteor Drop's own slot (not while a Lunge charges through a jump: that release is the Lunge)
	var air_ready := float(cd["air"]) <= 0.0 and not meteor.running() and not warchain.spin_window()
	if not h.grounded and air_ready and not h.gliding and not rmb_down:
		AimKit.circle(h, "drop_aim", {"at": meteor.point(), "r": float(rmb_def()["drop"]["radius"]),
				"col": JuggernautDrop.PURPLE, "alpha": 0.7, "ticks": true})
	if lmb_t > float(lmb_def()["tap"]):
		var k := wave_k()
		AimKit.circle(h, "wave", {"self": true, "r": 1.35, "fill": k, "col": WAVE_RED})
		AimKit.charge(h, k, {"col": Color("ff6a4a")})

## During the Warchain's pull: a fiery spin around you that blights everyone it hits.
func _spin() -> void:
	var sp: Dictionary = rmb_def()["spin"]
	spins += 1
	play("jug_spin")
	var stg := stage("rmb",
			{"delivery": {"type": "burst", "origin": "caster", "radius": float(sp["radius"])},
					"effects": [{"type": "damage", "amount": float(sp["dmg"]) * smash_k()}]})
	run_own(stg, cx("rmb", "cinder_spin", h.pos, {"no_floor": true, "on_foe": func(f: Ent, _c: Dictionary):
		if is_instance_valid(f) and not f.dead: KitStatus.apply(f, "blt", float(sp["blight"]))}))
	vfx("spin", h.pos, h.aim_dir(), {"r": float(sp["radius"])})
	m.fx.word(h.pos + Vector3(0, 2.4, 0), "CINDER SPIN", Color("ff7a3a"), false)

# ------------------------------------------------------------------ E: Warchain (JuggernautChain)
## "During E" for the Smash is the pull and the moment after it (the Cinder Spin).
func in_e() -> bool:
	return warchain.spin_window()

func e_recastable() -> bool:
	return warchain.hooked()

## E: throw the chain, or pull yourself along it (JuggernautChain.press).
func use_e() -> void:
	if not slam_w.is_empty() and warchain.state == "ready":
		slam_w["pinned"] = true        # the cursor moved on to the throw: the Slam goes where it was started
	if warchain.hooked() and riposte.move_k() <= 0.0 and not super.busy():
		riposte.pull_through()         # owner 113.7: the held chain hauls him in, the ult's strike on the way
		return
	if busy():
		h._ab_feedback("k1", "deny")
		return
	warchain.press()

## The Warchain's cooldown starts when you pull, or when the chain misses or breaks.
func start_e_cd() -> void:
	cd["e"] = float(e_def().get("cooldown", 13.0)) * cd_k("kin")

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	# the Gilded Riposte up close: the guard eats what they throw, then the cleave answers
	if HeroUlt.ready(self) and los and dist < float(x_def()["len"]):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		HunterKeys.ult_pressed(h)
		return
	# pulled along the chain: spin as you arrive
	if warchain.spin_window() and rmb_ready() and int(h.slot_lv["sec"]) > 0:
		h.inp["sec"] = true
		return
	# chained to them: run a Chain Lunge down it, wind up a Smash and pull into a Haul Slam, or just pull
	if warchain.hooked() and warchain.target != null and dist > 3.5 and not rmb_down:
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
	var worth_chain := dist > 3.0 or (not rmb_ready() and dist > 1.2)
	var chain_up := int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and warchain.state == "ready"
	if chain_up and los and worth_chain and dist < float(e_def()["range"]) - 0.5 and randf() < 0.4:
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
			var hold_t := float(rmb_def()["hold"])
			var far_k := clampf((dist - 3.0) / 4.0, 0.0, 1.0)
			bot_hold["rmb"] = hold_t + (float(rmb_def()["full_t"]) - hold_t) * far_k + 0.05
	# keep the wound-up slam on them while it winds up
	if not slam_w.is_empty():
		h.inp["aim"] = tgt.pos
	# Rampage in: the tip is the sweet spot, so dash from about a dash length out, facing them
	var dash_up := int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and lunge.is_empty()
	if dash_up and los and dist > 2.5 and dist < 6.0 and randf() < 0.25:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
