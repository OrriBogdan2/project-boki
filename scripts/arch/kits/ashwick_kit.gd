class_name AshwickKit
extends ArchKit
## Cinder (id ashwick, heavy). Gameplay follows the "everything builds toward a burn" brief and the
## reference sheet (docs/heroes/ashwick.md); names, art, sounds and text are ours.
##
## - Passive, Flashover: every hit builds Char on a foe (31 = Ablaze: 3s of burning for a share of their
##   health). Stoking a foe that already burns Flashes it over (fiercer). One flame pip over a foe
##   Ablaze, three and a glow over one that Flashed over. Char falls off after 5s. A knock heals, and resets the cloak.
##   A burning foe takes more from the stream and the cinder (ignite_bonus), and the stream chips its health.
## - LMB, Torch Lance: hold for a stream of fire from her hand (a cyan pilot flame first); the stream keeps its own
##   velocity so a sweep bends it, narrow at the palm and billowing at the end.
## - RMB, Cinder Shot: hold to aim down a lane, release: a cinder that always flies its full 14m;
##   it slows the foe and sets it Ablaze; on a burning foe it upgrades and spreads. Rank 3: a second charge.
## - Shift, Soot Ram: two charges of a short head-first dash toward the cursor that STOPS on the
##   first foe with a fiery impact and shoves it; rank 3: more damage, a speed boost and a shield on a hit.
## - E, Furnace Cloak: on the press, a blast round Cinder (a ring at its exact radius): scorch, Char,
##   Anti-Heal, drag foes in (walls block), and a swirling shield for what it hit.
## - X, Flue Flight (level 6): a steerable flight that lays a burning, slowing lava carpet (AshwickJet). No lance
##   in it.

const FLAME_CYAN := Color("6fe8ff")    # the pilot flame: a cool spark in her palm against warm fire
const BOLT_COL := Color("ff4a6a")      # Cinder Shot's red-pink body
const BOLT_CORE := Color("ffe070")
const SKULL_COL := Color("ff6a2a")
const PIP_COL := Color("ff9a3a")
const PILOT_CORE := Color("c8f8ff")
const SHIELD_COL := Color("ff5a1a")    # the cloak's fire shield: a deep orange that holds on yellow grass
const RAM_FRONT := 0.3                 # share of the ram spent at its burst speed, then it slows
const RAM_FRONT_K := 1.4               # the burst speed against the average (front-loaded, hero-ref)
const RAM_BACK_K := 0.85
const DRAG_T := 0.45                   # s the cloak pulls a foe in for (at pull_speed, stopping gap m away)
const TONGUE_EVERY := 2                # flame ticks between two tongues licking off the stream
const LICK_EVERY := 3                  # flame ticks between two scorches where the stream's end licks the ground
const CLOAK_POSE_T := 0.25            # s the Furnace Cloak flare holds her hand up off the aim (as_cloak)
const CRACKS_PEAK := 4.0               # her magma cracks' emission while the fire runs (rest: the toon's 2.2)
const CRACKS_FADE := 0.5               # s back to rest when it stops
const CLOAK_RING_T := 0.18            # s the ring at the cloak's exact radius shows on the press
const SKULL_TILT := 0.6                # rad the skull's front edge lifts toward the camera
const NOZZLE := Vector3(1.3, 0.9, 0.15)  # where the rules start the fire, from the feet: fwd, up, right (m)
const NOZZLE_REACH := 2.6                # m: a palm further off than this isn't posed yet: use NOZZLE
# m the fire leaves ahead of the wrist, off the palm (a model without a palm point)
const PALM_AHEAD := 0.12

var chars := {}                 # foe id -> {e, n, t}
var ignites := {}               # foe id -> {e, lvl, until}
var hose := AshwickHose.new()   # the Torch Lance stream
var flame_acc := 0.0
var spool := 0.0                # how long the hose has been held
var after_t := 0.0              # the slow after letting go
var boost_until := -9.0         # the Soot Ram's rank-3 speed boost runs until then
var relight_t := 0.0            # the lance can't relight until this runs out (0.35s after a release)
var was_held := false
var hose_paused := false        # the lance held through a dash: the stream is out, it roars again as the dash ends
var ember_t := 0.0
var bash := {}                  # hold: the Soot Ram under way {t, dir, hit}
var aiming := false             # hold: Cinder Shot held (the lane shows)
var fx: LDFx
var nozzle_at: Node3D           # the Gun's Muzzle, kept on her casting palm by the model (Sync.apply_blade)
var lmb_key_was := false         # the LMB key last step: only a press in the flight ticks, not a hold carried in
var lmb_denied := 0              # (tests) presses refused during Flue Flight
var jet: AshwickJet             # X, Flue Flight (its flight is a hold: jet.flight)
var ignitions := 0              # (tests)
var upgrades := 0
var spreads := 0
var resets := 0
var cloaks := 0
var blasts := 0
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
	jet = AshwickJet.new(self)

func _best_char() -> float:
	var b := 0.0
	for k in chars:
		b = maxf(b, float(chars[k]["n"]))
	return b

func _fwd() -> Vector3:
	var d2 := h.aim_dir()
	return Vector3(d2.x, 0.0, d2.y)

## Where the stream starts for the rules: a fixed offset from her feet in the aim pose (ahead of her braced palm),
## so the stream's reach never depends on the camera's lean of the model.
func nozzle() -> Vector3:
	var f := _fwd()
	return h.pos + f * NOZZLE.x + f.cross(Vector3.UP) * NOZZLE.z + Vector3(0, NOZZLE.y, 0)

## Her casting palm, for what's drawn: the Gun's Muzzle when the model puts it on the palm (weapon_muzzle),
## else a palm's width ahead of her right wrist. No posed hand yet: nozzle().
func tip() -> Vector3:
	if nozzle_at == null or not is_instance_valid(nozzle_at):
		var skinned: bool = h.model != null and WardenGlb.anchor(h.model, "weapon_muzzle") != null
		nozzle_at = h.model.get_node_or_null("Rig/Torso/Aim/Gun/Muzzle") if skinned else null
	var at := Vector3.INF
	if nozzle_at != null and nozzle_at.is_inside_tree():
		at = nozzle_at.global_position
	elif h.anim != null and h.anim.hand_r != null and h.anim.hand_r.is_inside_tree():
		at = h.anim.hand_r.global_position + _fwd() * PALM_AHEAD
	return at if at.distance_to(h.pos) < NOZZLE_REACH else nozzle()

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
		f.burn_t = maxf(f.burn_t, float(rd()["ignite_t"]))
		f.burn_dps = dps
		f.burn_by = h
	if lvl == 2 and was < 2:
		_flashover_fx(f)
		_stoke_pose()
	elif was == 0:
		m.fx.word(f.pos + Vector3(0, 2.3, 0), "ABLAZE", res_col(), false)
		vfx("ablaze", f.pos)
		m.sfx("as_ignite", f.pos, -3.0, 1.0)

## The Flashover payoff: the word, a column of fire on the foe (content/vfx "flashover"), the blaze and the HUD
## flash; the shared payoff's rings stay out of Cinder's fire.
func _flashover_fx(f: Ent) -> void:
	var col := Color("ffe0a0")
	m.fx.word(f.pos + Vector3(0, 2.7, 0), "FLASHOVER", col, true)
	vfx("flashover", f.pos)
	m.sfx("lw_blaze", f.pos, 0.0, 1.0)
	m.sfx("crit", f.pos, -7.0, 0.85)
	if h.is_local() and m.hud:
		m.hud.flash(col, 0.12)
	RecastCue.payoff(self, f)
	CombatBus.ability_used.emit(h, id + "_payoff", "secondary")

## The Flashover fist pump; mid-roar the hand stays on the foe and only the off arm and the body move.
func _stoke_pose() -> void:
	play("lw_stoke_lance" if was_held else "lw_stoke")

func on_knock(t: Hunter, mine: bool) -> void:
	if not mine or not is_instance_valid(t):
		return
	h.heal(h.max_hp * float(rd()["heal_knock"]))
	vfx("knock")
	_stoke_pose()
	if h.dashes < h.max_dashes():
		h.dashes = minf(h.max_dashes(), floorf(h.dashes) + 1.0)     # a knock gives back one ram charge, never more
		st["knock_charges"] = int(st.get("knock_charges", 0)) + 1
	if float(cd["e"]) > 0.0:
		cd["e"] = 0.0
		resets += 1
		m.fx.word(h.pos + Vector3(0, 2.8, 0), "CLOAK READY", col_of(e_def()), true)
		m.sfx("ab_ready", h.pos, -2.0, 0.8)           # (no ring on a reset: the word and the sound)
		if h.is_local(): h._ab_feedback("k1", "ready")

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
	if not bash.is_empty(): _tick_bash(dt)
	jet.tick(dt)
	KMovesPair.air_moves(self, "lw_jump", "lw_land")
	if h.shield_t > 0.0 and h.shield > 0.5 and st.get("shield_on", false):
		if tells_visible():
			# the Furnace Cloak's shield: a swirling ring of fire hugging Cinder while it holds (about 0.8 bh)
			fx.place(
				"swirl%d" % h.get_instance_id(), "swirl", h.pos + Vector3(0, 0.55, 0), SHIELD_COL, Color("ffc040"),
				1.8, m.time * 2.0, 1.0
			)
			fx.place(
				"swirl2%d" % h.get_instance_id(), "swirl", h.pos + Vector3(0, 1.25, 0), Color("c8301a"),
				Color("ff9a3a"), 1.45, -m.time * 2.6, 0.85
			)
	else:
		st["shield_on"] = false
	tell = ""
	if _best_char() >= 22.0:
		tell = "full"
	elif _best_char() >= 12.0:
		tell = "half"
	net_pulse(dt, not ignites.is_empty(), 1.3)

## The pilot flame in her palm, embers over a heavily charred foe, and the burn stage over each burning
## foe: one flame pip for Ablaze, three and a glow for Flashover (sheet gap 4b).
func _tick_tells(dt: float) -> void:
	var vis := tells_visible()
	var flamer_up: bool = anim_id == "as_cloak" and m.time - anim_at < CLOAK_POSE_T      # swung up on its strap
	if jet.running():
		fx.unplace("pilot%d" % h.get_instance_id())      # the lance is out, its pilot flame too
	elif vis and h.wid == "flamethrower" and not h.downed and not KinMerge.active(h) and not flamer_up:
		var fl := 0.85 + 0.15 * sin(m.time * 37.0)
		var big := 1.0 + (1.2 if was_held and spool < float(lmbd()["spool"]) else 0.0)
		fx.place("pilot%d" % h.get_instance_id(), "pilot", tip(), FLAME_CYAN, PILOT_CORE, 0.4 * fl * big)
	ember_t -= dt
	if ember_t <= 0.0:
		ember_t = 0.35
		for key in chars:
			var e: Dictionary = chars[key]
			if float(e["n"]) >= 15.0 and vis:
				vfx("char_drift", (e["e"] as Ent).pos)
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
			var rise := 0.06 if n == 3 and i == 1 else 0.0       # the middle of three pips sits a little higher
			var off := Vector3((i - (n - 1) * 0.5) * 0.6, rise, 0)
			fx.place(
				"pip%d_%d" % [key, i], "pip", top + off, PIP_COL if lvl < 2 else Color("ff5a2a"), Color("fff0a0"),
				0.4 if lvl < 2 else 0.44
			)
		if lvl >= 2:
			fx.place(
				"pipg%d" % key, "glow", top + Vector3(0, -0.05, 0), Color("ff4a1a"), Color("ff9a3a"),
				0.75 + 0.08 * sin(m.time * 9.0)
			)

## Shown burn stage over a foe: 0, 1 (Ablaze, one pip) or 3 (Flashover, three pips) (tests).
func pips_on(f: Ent) -> int:
	var key := f.get_instance_id()
	var n := 0
	for i in 3:
		if fx.shown("pip%d_%d" % [key, i]): n += 1
	return n

## A Boki merge ends the hose, a bash mid-flight and the Cinder Shot lane, with nothing fired.
func _drop_holds() -> void:
	hose.clear()
	if fx: fx.flame_off("hose%d" % h.get_instance_id())
	spool = 0.0
	was_held = false
	after_t = 0.0
	flame_acc = 0.0
	h.mel_hold = 0.0
	bash = {}
	aiming = false
	jet.drop()

func move_k() -> float:
	var boost := 1.0 + float(dash_def().get("rank3_boost", 0.0)) if m.time < boost_until else 1.0
	return (0.6 if after_t > 0.0 else 1.0) * boost

## Rank 3 Cinder Shot holds a second charge.
func rmb_charges() -> int:
	return int(rmb_def().get("rank3_charges", 2)) if rank("sec") >= 3 else 1

## Damage factor a burning foe takes from the stream and the cinder: 1.0 when it isn't burning.
func ignite_k(f: Ent) -> float:
	var lvl := burning(f)
	return 1.0 if lvl == 0 else float(d["ignite_bonus"]["dmg_k"][lvl - 1])

## Share of the foe's health the stream takes a second while it burns.
func ignite_pct(f: Ent) -> float:
	var lvl := burning(f)
	return 0.0 if lvl == 0 else float(d["ignite_bonus"]["tick_pct"][lvl - 1])

# ------------------------------------------------------------------ LMB: Torch Lance
func lmb_override(held: bool, dt: float) -> bool:
	var pressed := held and not lmb_key_was
	lmb_key_was = held
	if jet.running():
		_lance_off(pressed)
		return true
	if h.wid != "flamethrower":
		return false
	# a merge ends the roar: holding the key on must not relight it
	var merging := KinMerge.transforming(h) or KinMerge.active(h)
	if held and was_held and not merging and flow.pauses_hold("lmb"):
		_pause_hose()
		return true
	if not held or not h.can_fire() or merging or (relight_t > 0.0 and not was_held):
		if was_held:
			play("as_lance_end")           # (a key let go in a dash too: the pose never outlasts the key)
		if was_held and not hose_paused:
			vfx("lance_end")
			m.sfx("ashwick_tank_hiss", h.pos, -4.0, 1.0)      # the fire gutters out as she lets go
		if was_held:
			after_t = float(lmbd().get("slow_after", 0.35))
			relight_t = float(lmbd().get("relight", 0.35))      # a short gap before the lance can roar again
			h.mel_hold = 0.0
			hose.snuff()
		was_held = false
		hose_paused = false
		spool = 0.0
		flame_acc = 0.0
		return true
	var ld := lmbd()
	if hose_paused:
		hose_paused = false
		play("as_lance")        # out of the dash, hand already on the aim: back at once
	if not was_held:
		play("as_lance")
		m.sfx("lw_pilot", h.pos, -3.0, 1.0)
		vfx("lance_pilot")              # the pilot flares cyan before the roar
	was_held = true
	h.idle_fire = 0.0
	spool += dt
	h.mel_hold = minf(spool, float(ld["spool"]))
	if spool < float(ld["spool"]):
		return true                # the pilot's flicker: no fire yet
	HeroVfx.of(m).hold(h, "lance")
	hose.emit(nozzle(), h.aim_dir(), h.vel, h.pos.y, float(ld["speed"]), float(ld["range"]), dt, tip() - nozzle())
	flame_acc += dt
	var tick := float(ld["tick"])
	while flame_acc >= tick:
		flame_acc -= tick
		PipStars.pulse(h, CRACKS_PEAK, CRACKS_FADE)
		_flame_tick(tick)
	return true

## Flue Flight: LMB does nothing for the whole flight, whatever is in her hand. The key is ignored,
## not buffered, and a press answers with the soft "can't" tick. A stream running at lift-off goes out with no
## relight gap, so a held key lights the lance the step the flight ends (its usual pilot, then the roar).
func _lance_off(pressed: bool) -> void:
	if pressed:
		lmb_denied += 1
		h._ab_feedback("base", "deny")
	if was_held:
		hose.snuff()
	was_held = false
	hose_paused = false
	spool = 0.0
	flame_acc = 0.0
	relight_t = 0.0
	h.mel_hold = 0.0

## The stream's look: the MultiMesh of puffs (LDFx.flame).
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
	var w0 := float(ld["w0"])
	var w1 := float(ld["w1"])
	for f in m.foes_of(h.team):
		if not f.hittable():
			continue
		var pf := hose.touching(f, w0, w1)
		if pf.is_empty() or not sees_from(pf["p"], f, 0.0):
			continue
		var dmg: float = float(ld["dps"]) * tick * ignite_k(f) + f.max_hp * ignite_pct(f) * tick
		f.hurt(dmg, h, {"src": "flame", "ab": "primary", "tags": ["flame"], "melee": false})
		add_char(f, float(ld["char_tick"]))
		if flame_ticks % 2 == 0 and tells_visible():
			vfx("lance_hit", f.pos)
	if tells_visible():
		_stream_looks()

## Tongues of flame licking off the stream as it bends, and a scorch where its far end licks the ground.
func _stream_looks() -> void:
	var live := hose.puffs.filter(func(pf): return not pf.get("dead", false))
	if live.size() < 4:
		return
	if flame_ticks % TONGUE_EVERY == 0:
		var mid: Dictionary = live[live.size() / 2]
		var v: Vector3 = mid["v"]
		vfx("lance_tongue", ground(mid["p"]), Vector2(v.x, v.z).normalized())
	if flame_ticks % LICK_EVERY == 0:
		vfx("lance_lick", ground(live[0]["p"]))

# ------------------------------------------------------------------ RMB: Cinder Shot
## Held: a thin white lane of the shot's full, fixed length (the cursor distance doesn't matter), her casting hand
## drawn back.
func rmb_hold_tick(_t: float) -> void:
	if KinMerge.active(h) or not rmb_ready():
		return
	if not aiming:
		aiming = true
		if not jet.running(): play("as_aim")       # (flying, the flight pose stays)
	HeroVfx.of(m).hold(h, "shot_aim")
	var rdf := rmb_def()
	var ln := AimMode.dist(h, float(rdf["range"]), AimMode.MAX)
	AimKit.lane(
		h, "rmb", {"len": ln, "width": float(rdf["size"]) * 2.0, "col": Color("fff4e6"), "col2": BOLT_COL,
				"alpha": 0.9, "tip": true}
	)

func fire_rmb(c: Dictionary) -> void:
	c["variant"] = "tap"
	last_variant = "tap"
	var was_aiming := aiming
	aiming = false
	AimKit.hide(h, "rmb")
	if not spend_rmb():
		if was_aiming: play("")
		return
	var rdf := rmb_def()
	if not jet.running(): play("as_shot")
	var amt := float(rdf["dmg"])
	var rng := AimMode.dist(h, float(rdf["range"]), AimMode.MAX)      # always its full length in the aim direction
	var shot := {"type": "projectile", "speed": float(rdf["speed"]), "range": rng, "size": float(rdf["size"])}
	var stg := stage("rmb", {"delivery": shot,
		"effects": [
			{"type": "damage", "amount": amt},
			{"type": "slow", "duration": float(rdf["slow_for"]), "strength": float(rdf["slow"])},
		]})
	var n0: int = m.shots.size()
	run_own(stg, cx("rmb", "cinder_shot", aim(), {"on_foe": func(f: Ent, _c: Dictionary): _cinder_hit(f)}))
	if m.shots.size() > n0:
		fx.ride(m.shots[-1], "cinder", BOLT_COL, BOLT_CORE, 1.6, 0.5, _bolt_end)
		HeroVfx.of(m).trail(h, "shot_trail", m.shots[-1]["node"])
	vfx("shot")
	m.sfx("lw_bolt", h.pos, -2.0, 1.0)

## A cinder that ran its full length without a hit fizzles there in a small blue-white ring (sheet 0133).
func _bolt_end(at: Vector3, expired: bool) -> void:
	bolt_ends.append([at, expired])
	if bolt_ends.size() > 8: bolt_ends.pop_front()
	if not expired:
		return
	fizzles += 1
	vfx("shot_fizzle", at)
	m.sfx("lw_bolt_hit", at, -10.0, 1.5)

func _cinder_hit(f: Ent) -> void:
	if not is_instance_valid(f) or f.dead or f.team == h.team:
		return
	var rdf := rmb_def()
	var cur := burning(f)
	if cur > 0:
		var bonus := float(rdf["dmg"]) * power("sec") * (ignite_k(f) - 1.0)
		f.hurt(bonus, h, {"src": "flame", "ab": "utility", "tags": ["flame"], "melee": false})
	# the impact: a red flash and an ember shower (sheet 0076-0079)
	vfx("shot_hit", f.pos)
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
				vfx("shot_spread", f.pos, null, {"to": o.pos + Vector3(0, 1.0, 0)})
		m.fx.word(f.pos + Vector3(0, 2.5, 0), "SPREAD", col_of(rdf), true)
	else:
		stoke(f)

func sees_from(p: Vector3, o: Ent, lift := 0.95) -> bool:
	return m.world.los(p, o.pos, p.y + lift)

## The lance held through a ram or a poof: the stream goes out (no fire comes from the dash) but the
## hold carries, so it roars again the step the dash ends, with no pilot and no relight gap (that gap is after a
## release).
func _pause_hose() -> void:
	if not hose_paused:
		hose_paused = true
		hose.snuff()
		flame_acc = 0.0

# ------------------------------------------------------------------ Shift: Soot Ram
func on_dash(use_ex: bool) -> bool:
	var dd := dash_def()
	var dir := dash_dir()
	if jet.running():
		# in the flight (AshwickJet passes Shift on) a poof from the bellows feeds it and the flight goes on
		if spend_dash(true):
			jet.poof(dir)
			_poof_cloud(dir)
		return true
	if use_ex and not h.grounded:
		if not spend_dash(true): return true
		_poof(dd, dir)
		return true
	if not spend_dash(false):
		return true
	travel(float(dd["dist"]), float(dd["time"]), {"invuln": 0.06, "trail": "", "dir": dir})
	st["last_dash"] = "soot_ram"
	play("as_leap")
	vfx("ram", null, dir)
	h.glide_cd = maxf(h.glide_cd, h.roll_t + 0.35)
	m.sfx("lw_bash", h.pos, -2.0, 1.0)
	bash = {"t": h.roll_t, "t0": h.roll_t, "speed": h.roll_speed, "dir": dir, "hit": false}
	return true

## The air dash, Cinder's way: a "poof" from the bellows that launches him far and fast (a cloud of smoke and
## flame blown out behind him, no blast), and he keeps a share of the speed after it (the class long dash is
## replaced).
func _poof(dd: Dictionary, dir: Vector2) -> void:
	var feel := dash_feel()
	var air_t := float(dd["air_time"]) * float(feel["time"])
	var air_dist := float(dd["air_dist"]) * float(feel["dist"])
	travel(float(dd["air_dist"]), float(dd["air_time"]), {"invuln": 0.08, "trail": "", "dir": dir})
	h.roll_t = air_t
	h.roll_speed = air_dist / air_t
	play("lw_hop")
	_poof_cloud(dir)
	# held a step past the burst, so the kept speed lands after the class's own small carry
	bash = {"t": air_t + 0.04, "dir": dir, "hit": true, "hop": true, "speed": h.roll_speed}

## While the ram flies: the flame skull wraps his front and ember tails stream behind; the first foe it
## meets stops the dash with the impact (sheet gap 2).
func _tick_bash(dt: float) -> void:
	var dir: Vector2 = bash["dir"]
	if bash.has("t0") and not bash.get("hit", false) and h.roll_t > 0.0:
		var into := float(bash["t0"]) - float(bash["t"])
		h.roll_speed = float(bash["speed"]) * (RAM_FRONT_K if into < RAM_FRONT * float(bash["t0"]) else RAM_BACK_K)
	bash["t"] = float(bash["t"]) - dt
	if tells_visible():
		_ram_looks(dir)
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
		if b.get("hop", false):
			_keep_poof(b)
		elif not b.get("hit", false):
			m.fx.dust(h.pos, 6)

## The poof's cloud of smoke and flame blown out behind her along `dir` (no blast), and its sound.
func _poof_cloud(dir: Vector2) -> void:
	m.sfx("lw_hop", h.pos, -3.0, 1.0)
	vfx("poof", null, dir)

## Out of the poof he sails on with a share of its speed (momentum kept), not the class's small carry.
func _keep_poof(b: Dictionary) -> void:
	var keep := (b["dir"] as Vector2) * float(b["speed"]) * float(dash_def()["air_keep"])
	h.vel.x = keep.x
	h.vel.z = keep.y

## The ram's looks: the flame skull round her front (flat, so it reads from above) and flame tails streaming
## behind her (the hop leaves them too).
func _ram_looks(dir: Vector2) -> void:
	var f3 := Vector3(dir.x, 0, dir.y)
	if not bash.get("hop", false) and not bash.get("hit", false):
		var skull := fx.place(
			"skull%d" % h.get_instance_id(), "skull", h.pos + Vector3(0, 0.95, 0) - f3 * 0.5, SKULL_COL,
			Color("ffe08a"), 1.6, atan2(-dir.x, -dir.y)
		)
		skull.rotate_object_local(Vector3.RIGHT, SKULL_TILT)
	HeroVfx.of(m).hold(h, "ram_trail")

func own_dash_trail() -> bool: return true

## His ram and poof moves are the whole dash pose (as_leap, lw_hop): no shared heavy charge under them.
func dodge_anim() -> String: return "kit"

func _bash_impact(f: Ent) -> void:
	var dd := dash_def()
	bash["hit"] = true
	bash_hits += 1
	h.roll_t = 0.0                  # the dash stops on the foe
	var dir: Vector2 = bash["dir"]
	# and he bounces back a little off them
	h.vel.x = -dir.x * float(dd["recoil"])
	h.vel.z = -dir.y * float(dd["recoil"])
	var rank3 := rank("dash") >= 3
	var ram_dmg := float(dd["dmg"]) + (float(dd["rank3_dmg"]) if rank3 else 0.0)
	f.hurt(
		ram_dmg * power("dash"), h,
		{"src": "flame", "ab": "dodge", "tags": ["flame"], "melee": true, "kb": dir * float(dd["kb"])}
	)
	add_char(f, float(dd["char"]))
	if rank3:
		_ram_reward()
	vfx("ram_hit", (h.pos + f.pos) * 0.5, dir)
	m.sfx("lw_bash_hit", f.pos, 0.0, 1.0)
	Feel.hitstop(m, h, f, 30.0, {"melee": true, "heavy": true})

## Rank 3: a clean ram hit speeds Cinder up and wraps him in a short shield.
func _ram_reward() -> void:
	var dd := dash_def()
	boost_until = m.time + float(dd["rank3_boost_t"])
	h.shield = maxf(h.shield, h.max_hp * float(dd["rank3_shield"]))
	h.shield_t = maxf(h.shield_t, float(dd["rank3_shield_t"]))
	m.fx.word(h.pos + Vector3(0, 2.8, 0), "SPEED + SHIELD", col_of(dd), true)

# ------------------------------------------------------------------ E: Furnace Cloak
## The press: the blast goes off at once round Cinder (never at the cursor), with a quick arms-out flare
## and a thin ring at the blast's exact radius that everyone sees.
func cast_e() -> bool:
	var ed := e_def()
	cloaks += 1
	play("as_cloak")
	AimKit.circle(
		h, "e_ring",
		{"self": true, "r": float(ed["radius"]), "all": true, "dur": CLOAK_RING_T, "col": col_of(ed), "hot": 0.3}
	)
	m.sfx("lw_shield", h.pos, -1.0, 1.0)
	vfx("cloak_gather", null, null, {"r": float(ed["radius"])})
	_cloak_blast()
	return true

func _cloak_blast() -> void:
	var ed := e_def()
	blasts += 1
	var hit := 0
	var shield_k := rank_k("rank_shield", "kin", 1.0)
	var r := float(ed["radius"])
	vfx("cloak", null, null, {"r": r})        # no wider than the blast reaches
	for f in foes_in(h.pos, r):
		if not sees(f):
			continue
		hit += 1
		if hit == 1:
			m.sfx("ashwick_cloak_hit", f.pos, -2.0, 1.0)
		f.hurt(float(ed["dmg"]) * power("kin"), h, {"src": "flame", "ab": "k1", "tags": ["flame", "cloak"]})
		add_char(f, float(ed["char"]))
		KitStatus.apply(f, "blt", float(ed["blt_t"]))
		vfx("cloak_hit", f.pos)        # a smoke puff over the target
		if f.mass() < 6.0:
			# dragged in toward her (Displace: a player online is pulled on their own game)
			var drag := {"mode": "step", "spd": float(ed["pull_speed"]), "gap": float(ed["gap"]), "dur": DRAG_T}
			m.displace.tow(f, h, drag)
			pulled += 1
	if hit > 0:
		h.shield = maxf(h.shield, h.max_hp * (float(ed["shield_base"]) + float(ed["shield_each"]) * hit) * shield_k)
		h.shield_t = float(ed["shield_t"])
		st["shield_on"] = true
		m.sfx("shield", h.pos, -5.0, 0.9)

# ------------------------------------------------------------------ X: Flue Flight
func cast_ult() -> bool: return HeroUlt.press(self, jet.start)
func has_ult() -> bool: return true
func ult_recast() -> bool: return jet.recast()
func ult_running() -> bool: return jet.running()
## RecastCue: X again lands the flight early, where you are (it lands by itself when it runs out).
func recast_window() -> Dictionary:
	if not jet.running():
		return {}
	var t := float(x_def()["time"])
	return RecastCue.window("x", float(jet.flight["t"]), t, h.pos, true, true)

## RecastCue's badge: Char on each foe; gold once it's Ablaze, where the next ignite is the Flashover.
func combo_marks(out: Array) -> void:
	super(out)
	var ttl := float(rd()["expire"])
	for key in chars:
		var c: Dictionary = chars[key]
		if not is_instance_valid(c["e"]) or (c["e"] as Ent).dead:
			continue
		var lvl := burning(c["e"])
		var left: float = ttl - (m.time - float(c["t"]))
		if left > 0.0 or lvl > 0:
			var label := "ABLAZE" if lvl > 0 else "CHAR"
			out.append(RecastCue.mark(c["e"], int(c["n"]), maxf(0.0, left), ttl, label, lvl == 1))
## In the flight (a roll) only E works (item 66: AshwickJet.lock_inputs).
func fires_in_dash() -> bool: return jet.running() or super.fires_in_dash()
func aims_in_dash() -> bool: return not jet.running() and super.aims_in_dash()
func gate_inputs() -> void: jet.lock_inputs()

# ------------------------------------------------------------------ bots
func bot_use(tgt: Ent, dist: float, los: bool) -> void:
	if tgt == null:
		return
	var te := tgt as Ent
	if HeroUlt.ready(self) and los and dist > 3.0 and dist < 9.0:
		h.inp["aim"] = tgt.pos
		HunterKeys.ult_pressed(h)
		return
	if int(h.slot_lv["kin"]) > 0 and float(cd["e"]) <= 0.0 and los and dist < float(e_def()["radius"]) - 0.5:
		h.inp["aim"] = tgt.pos
		h.inp["sig"] = true
		return
	var in_reach := dist < float(rmb_def()["range"]) - 1.0 and dist > 3.0
	if int(h.slot_lv["sec"]) > 0 and rmb_ready() and los and in_reach and (burning(te) > 0 or randf() < 0.5):
		h.inp["aim"] = tgt.pos + Vector3(0, 0.9, 0)
		h.inp["sec"] = true
		return
	if int(h.slot_lv["dash"]) > 0 and h.dashes >= 1.0 and los and dist > 2.5 and dist < 5.0 and randf() < 0.2:
		h.inp["aim"] = tgt.pos
		h.ai["dash_dir"] = h.dir_to(tgt)
		h.inp["move"] = h.dir_to(tgt)
		h.inp["dash"] = true
