class_name ArchKit
extends RefCounted
## One hunter's archetype kit at run time (docs/ARCHETYPES.md): the dash shape, the passive and
## its resource, the RMB router (tap / hold / airborne / during E / during R / resource full),
## E, R (level 6, rank 2 at 9) and the Bonded R (bond full: the kin merges 0.2s after the ult's
## cast). Each archetype is a subclass (scripts/arch/kits/); this base holds the timers, the input
## router, the kin's infusion of the sockets, telegraphs and the shared helpers.
##
## Slots keep their run-level names: "sec" RMB, "dash", "kin" E (alias "e"), "ult" R.

var h: Hunter
var m: Node
var id := ""
var d: Dictionary = {}
var res := 0.0                 # the passive's resource (Marks live on targets instead)
var res_wait := 0.0            # seconds left before it decays out of a fight
var full_was := false
var cd := {"rmb": 0.0, "e": 0.0, "r": 0.0, "x": 0.0}
var ch_rmb := 1.0              # RMB charges
var rmb_down := false          # RMB held since its press
var rmb_t := 0.0
var rmb_ctx := {}              # what the press saw (airborne, in E...)
var e_t := 0.0                 # E's window left (0 = not up)
var r_t := 0.0                 # R's window left
var bonded := false            # the R running now was bonded
var dash_t := -1.0             # how long Shift has been held for a hold dash (-1: not holding)
var bot_hold := {"rmb": 0.0, "dash": 0.0}
var last_variant := ""         # the RMB variant that last fired (HUD, tests)
var last_e := ""
var st := {}                   # the subclass's own state
var fx_t := 0.0
var tell := ""                 # "" | "half" | "full": the resource tell enemies read
var bonded_glow := false
var fuse := {}                 # the R's fuse (wind-up) running: {t, T, bond, guard}
var cd_off := false            # practice toggle (Arena): cooldowns don't run down, they're skipped
var flow: DashFlow             # what ability presses do during this hero's dash
var dash_press_at := -9.0      # when Shift last went to on_dash (AirLimits: the dash's moves never hold the glider)

static func make(hunter: Hunter, arch_id: String) -> ArchKit:
	var k: ArchKit
	match arch_id:
		"thief": k = ThiefKit.new()
		"archer": k = ArcherKit.new()
		"mage": k = MageKit.new()
		"gunslinger": k = GunslingerKit.new()
		"juggernaut": k = JuggernautKit.new()
		"bulwark": k = BulwarkKit.new()
		"dredge": k = DredgeKit.new()
		"ashwick": k = AshwickKit.new()
		"tender": k = TenderKit.new()
		"rimewright": k = RimewrightKit.new()
		"dolm": k = DolmKit.new()
		"ostra": k = OstraKit.new()
		_: return null
	k.h = hunter
	k.m = hunter.m
	k.id = arch_id
	k.d = Arch.def(arch_id)
	k.ch_rmb = float(k.rmb_def().get("charges", 1))
	k.flow = DashFlow.new(k)
	k._setup()
	return k

const OWN_LOOK_SKIP := ["boom", "ping", "whoosh", "throw"]     # KinExec's delivery sounds (see run_own)

# ------------------------------------------------------------------ data
func rmb_def() -> Dictionary: return d.get("rmb", {})
func e_def() -> Dictionary: return d.get("e", {})
func r_def() -> Dictionary: return d.get("r", {})
func x_def() -> Dictionary: return d.get("x", {})          # the hero ultimate on X (HeroUlt)
func dash_def() -> Dictionary: return d.get("dash", {})
func lmb_def() -> Dictionary: return d.get("lmb", {})       # the kit's own attack-key data (kits that run the weapon's attack themselves)
func res_def() -> Dictionary: return d.get("resource", {})
func res_max() -> float: return float(res_def().get("max", 100.0))
## false when the passive has no meter (Hawk Sense)
func has_meter() -> bool: return String(res_def().get("kind", "")) != "none"
func res_col() -> Color: return Color(String(res_def().get("col", "#ffffff")))
func col_of(sd: Dictionary) -> Color: return Color(String(sd.get("col", "#ffffff")))

func rank(slot: String) -> int:
	return h.ability_level(slot)

## +15% damage per rank (Effects.level_k) on top of the hunter's own damage multiplier and the
## ability power their level gives (LevelGrowth.ap).
func power(slot: String) -> float:
	return m.dmg_mult(h) * Effects.level_k({"level": rank(slot)}) * LevelGrowth.ap(h)

func cd_k(slot: String) -> float:
	return h.rank_cd_k(slot)

func rmb_charges() -> int: return int(rmb_def().get("charges", 1))

## R rank 2: +30% duration and +15% to its cast effects.
func r_dur_k() -> float: return 1.3 if rank("ult") >= 2 else 1.0
func r_k() -> float: return 1.15 if rank("ult") >= 2 else 1.0

# ------------------------------------------------------------------ overridable kit
func _setup() -> void: pass
func _tick(_dt: float) -> void: pass
## A Boki merge ends every hold, charge and channel this kit started before R, with no release effect (and keeps them
## ended while merged: the form's own kit owns the buttons). Each kit with such state overrides this.
func _drop_holds() -> void: pass
## Merge start (and every step while merged): the kit's own holds, then every AimKit telegraph and cursor
## state this hunter shows. Call this, not _drop_holds, so the shared telegraphs always go with the holds.
func drop_holds() -> void:
	_drop_holds()
	AimKit.clear(h)
func fire_rmb(_c: Dictionary) -> void: pass        # c: {hold, air, e, r, full, t, variant}
func rmb_press_extra() -> bool: return false        # a recast that takes the press (Shadow Step); true = handled
func rmb_hold_tick(_t: float) -> void: pass          # while RMB is held (shields, charge previews)
func rmb_auto_t() -> float: return 9.0               # a hold this long fires by itself
func full_ready() -> bool: return false              # the resource-full RMB variant is ready
func cast_e() -> bool: return false
func e_recast() -> bool: return false                # E pressed while it's up (Sigil detonation)
func cast_r() -> bool: return false
func r_recast() -> bool: return false                # R pressed while it runs (Last Round release)
## X pressed while the hero ultimate runs (HeroUlt.press; true = handled, e.g. an early landing).
func ult_recast() -> bool: return false
## Is the hero ultimate under way (HeroUlt.press turns a press into ult_recast then)?
func ult_running() -> bool: return false
func gate_inputs() -> void: pass                    # a kit drops the presses it locks out
func locks_glide() -> bool: return false            # a move AirLimits can't see from the shared state (a dive)
func on_dash(_ex: bool) -> bool: return false        # true = the archetype handled the dash
## Does this kit have the class long dash (Shift in the air)? The HUD shows its segment only then.
func has_long_dash() -> bool: return true
func on_deal(_t: Ent, _dmg: float, _o: Dictionary) -> void: pass
func on_take(_by: Ent, _dmg: float, _o: Dictionary) -> void: pass
func on_block(_dmg: float, _by) -> void: pass
func outgoing(_t: Ent, dmg: float, _o: Dictionary) -> float: return dmg
func incoming(_by: Ent, dmg: float, o: Dictionary) -> Array: return [dmg, o]
func move_k() -> float: return 1.0
func hovering() -> bool: return false         # a CastHold holds him aloft: the walk steers as on the ground
func dive_speed() -> float: return 0.0          # m/s: a kit's plunge that outruns the fall cap (0: none)
func draw_rate() -> float: return 1.0               # a bow's draw speed (Hem's quick draw after a perfect release)
func fire_ok() -> bool: return true
## The attack key, if this kit runs the weapon's attack itself (true = handled; Hunter.trigger stops).
func lmb_override(_held: bool, _dt: float) -> bool: return false
## The kit's own pace times the R fuse's plant (you stand and gather while it winds up).
func pace() -> float: return move_k() * (0.35 if not fuse.is_empty() else 1.0)
func can_shoot() -> bool: return fire_ok() and fuse.is_empty()
func res_text() -> String: return "%d" % int(round(res))
func res_frac() -> float: return clampf(res / maxf(1.0, res_max()), 0.0, 1.0)
func bot_use(_tgt: Ent, _dist: float, _los: bool) -> void: pass
## The nearest foe a bot can hit within 12 m (the bot paths of the kits that run their own attack key).
func _bot_target() -> Ent:
	var best: Ent = null; var bd := 12.0
	for f in m.foes_of(h.team):
		if f.hittable() and h.flat_dist(f) < bd: bd = h.flat_dist(f); best = f
	return best
func describe_rmb_variant(c: Dictionary) -> String:
	for v in ["full", "r", "e", "air", "hold"]:
		if c.get(v, false): return {"full": "full", "r": "during_r", "e": "during_e", "air": "air", "hold": "hold"}[v]
	return "tap"

# ------------------------------------------------------------------ per step
func tick(dt: float) -> void:
	if KinMerge.transforming(h):
		drop_holds()
	if not h.wpn.get("ammo", true):
		h.ammo = int(h.wpn["mag"])        # a weapon with no ammo (Data.weapon_stats): nothing ever runs dry
	var rate := 1.0 + h.gear_stat("cdr")
	for k in cd.keys():
		cd[k] = maxf(0.0, float(cd[k]) - dt * rate)
		if cd_off and not (k == "r" and not fuse.is_empty()): cd[k] = 0.0
	if cd_off:
		ch_rmb = float(rmb_charges())
	if not fuse.is_empty():
		_tick_fuse(dt)
	var mx := float(rmb_charges())
	if ch_rmb < mx and float(cd["rmb"]) <= 0.0:
		ch_rmb = minf(mx, ch_rmb + 1.0)
		if ch_rmb < mx:
			cd["rmb"] = float(rmb_def().get("cooldown", 6.0)) * cd_k("sec")
	for k in bot_hold.keys():
		bot_hold[k] = maxf(0.0, float(bot_hold[k]) - dt)
	if rmb_down:
		if held("rmb") and not h.downed and h.stun_t <= 0.0:
			rmb_t += dt
			rmb_hold_tick(rmb_t)
			if rmb_t >= rmb_auto_t():
				_release_rmb()
		else:
			_release_rmb()
	if e_t > 0.0:
		e_t -= dt
		if e_t <= 0.0:
			e_t = 0.0
			_e_end()
	if r_t > 0.0:
		r_t -= dt
		if r_t <= 0.0:
			r_t = 0.0
			_r_end()
	res_wait = maxf(0.0, res_wait - dt)
	_tick_knocks()
	_tick(dt)
	_tells(dt)
	_tick_charge(dt)

func held(which: String) -> bool:
	match which:
		"rmb": return bool(h.inp.get("sec_hold", false)) or float(bot_hold["rmb"]) > 0.0
		"dash": return bool(h.inp.get("dash_down", false)) or float(bot_hold["dash"]) > 0.0
	return false

func _e_end() -> void: pass
func _r_end() -> void: pass

## A cast holds the caster still (no walking or jumping); aim_lock() is the facing it keeps (ZERO: free to turn).
func cast_locked() -> bool: return false
func aim_lock() -> Vector2: return Vector2.ZERO
## A move that keeps the glider shut while it runs.
func no_glide() -> bool: return false

func busy() -> bool:
	return h.downed or h.out or h.dropping or h.riding or h.stun_t > 0.0 or Hex.active(h)

# ------------------------------------------------------------------ RMB router
## The RMB press. Priority when several apply (§3.3): resource full > during R > during E >
## airborne or gliding > hold > tap. A tap fires on release under the hold threshold.
func press_rmb() -> void:
	if busy():
		h._ab_feedback("sec", "deny")
		return
	if rmb_press_extra():
		return
	if rmb_down:
		return
	rmb_down = true
	rmb_t = 0.0
	rmb_ctx = {"air": not h.grounded or h.gliding, "e": in_e(), "r": r_t > 0.0, "full": full_ready()}
	if float(rmb_def().get("hold", 0.0)) <= 0.0 or rmb_ctx["air"]:
		_release_rmb()          # no hold variant (or in the air): it goes on the press

func _release_rmb() -> void:
	if not rmb_down:
		return
	rmb_down = false
	var c := rmb_ctx.duplicate()
	c["t"] = rmb_t
	c["hold"] = rmb_t >= float(rmb_def().get("hold", 0.3)) and not c.get("air", false)
	c["variant"] = describe_rmb_variant(c)
	fire_rmb(c)

## The RMB charge. False (with the deny buzz) when none is ready.
func spend_rmb(silent := false) -> bool:
	if ch_rmb < 1.0:
		if not silent: h._ab_feedback("sec", "deny")
		return false
	ch_rmb -= 1.0
	if float(cd["rmb"]) <= 0.0:
		cd["rmb"] = float(rmb_def().get("cooldown", 6.0)) * cd_k("sec")
	h.used["utility"] = int(h.used.get("utility", 0)) + 1
	h._ab_feedback("sec", "cast")
	CombatBus.ability_used.emit(h, id + "_rmb", "secondary")
	return true

func rmb_ready() -> bool:
	return ch_rmb >= 1.0

## Inside this archetype's E right now (its zone, or while it's up).
func in_e() -> bool:
	return e_t > 0.0

# ------------------------------------------------------------------ E and R
func use_e() -> void:
	if busy():
		h._ab_feedback("k1", "deny")
		return
	if e_t > 0.0 and e_recast():
		return
	if float(cd["e"]) > 0.0:
		h._ab_feedback("k1", "deny")
		return
	if cast_e():
		cd["e"] = float(e_def().get("cooldown", 14.0)) * cd_k("kin")
		h.used["k1"] = int(h.used.get("k1", 0)) + 1
		h._ab_feedback("k1", "cast")
		CombatBus.ability_used.emit(h, id + "_e", "kin")
		last_e = String(e_def().get("name", ""))
	else:
		h._ab_feedback("k1", "deny")

## The loading screen's rehearsal of this kit's own effect library (Match.warm_up): its pools filled with one of
## every look at `at`, so the first cast makes nothing mid-fight (--first-cast-check). Kits with a library override it.
func warm_fx(_at: Vector3) -> void:
	pass

## X: the hero's own ultimate. No hero has one yet; a kit that does overrides both. Returns true when it went off.
func cast_ult() -> bool:
	return false

## Does this hero have an ultimate on X (the HUD shows the slot only then)?
func has_ult() -> bool:
	return false

## R: the archetype's ultimate. With the bond meter full the cast is Bonded (§5 option C): the ult's
## own tell, then 0.2s later the kin merges (its on_start), one T5 moment for the caster.
func use_r() -> void:
	if r_def().is_empty():
		return          # heroes without an R (the support pair)
	if busy():
		h._ab_feedback("r", "deny")
		return
	if not fuse.is_empty():
		return
	if r_t > 0.0 and r_recast():
		return
	if float(cd["r"]) > 0.0 or int(h.slot_lv.get("ult", 0)) <= 0:
		h._ab_feedback("r", "deny")
		return
	if not r_can_cast():
		h._ab_feedback("r", "deny")
		if h.is_local() and m.hud: m.hud.toast_small(r_no_target_text(), col_of(r_def()))
		return
	var will_bond := KinMerge.can_cast(h)
	var ft := fuse_time()
	if ft <= 0.0:
		_fire_r(will_bond)
		return
	# the fuse: a readable wind-up (pose, energy gathering, a sting, a ring enemies can see), then the
	# effect fires with a big impact. The cooldown starts now, so the slot reads as spent.
	fuse = {"t": ft, "T": ft, "bond": will_bond, "guard": String(r_def().get("fuse_guard", "none")), "fx": 0.0}
	cd["r"] = r_cooldown()
	h._ab_feedback("r", "cast")
	_fuse_start(will_bond)

## R's cooldown: the data's, 15% shorter at rank 2.
func r_cooldown() -> float:
	return float(r_def().get("cooldown", 100.0)) * (0.85 if rank("ult") >= 2 else 1.0)

## How long R winds up before it goes off (docs/ARCHETYPES.md R fuse; 0 = instant).
func fuse_time() -> float:
	return float(r_def().get("fuse", 0.45))

func fusing() -> bool:
	return not fuse.is_empty()

## Can R start now (Heist needs someone to rob)? Checked before the fuse, so a fuse never fizzles.
func r_can_cast() -> bool: return true
func r_no_target_text() -> String: return "Nothing in range"

func _fuse_start(bond: bool) -> void:
	var rd := r_def()
	var col := col_of(rd)
	var T := float(fuse["T"])
	h.cast_at = m.time; h.cast_slot = "ult"
	m.fx.word(h.pos + Vector3(0, 2.8, 0), String(rd.get("name", "")).to_upper(), col, true)
	tele_circle(h.pos, 2.4, col, T)
	m.fx.ring(h.pos, 0.8, Color(col, 0.9), T)
	m.sfx("charge", h.pos, 0.0 if h.is_local() else -2.0, 0.55)
	m.sfx("skill", h.pos, -3.0, 0.6)
	if bond:
		m.sfx("bond", h.pos, -3.0, 0.9)
	if String(fuse["guard"]) == "unstoppable":
		h.fortify_t = maxf(h.fortify_t, T + 0.05)
		m.fx.word(h.pos + Vector3(0, 2.2, 0), "UNSTOPPABLE", Color("ffe2a0"), false)
	# everyone else's game: a ring and a column of light where it's winding up (the existing fx path)
	if m.net_on and not h.remote:
		m.net_fx(["ring", m._r(h.pos.x), m._r(h.pos.y), m._r(h.pos.z), 2.4, col.to_html(false)])
		m.net_fx(["bolt", m._r(h.pos.x), m._r(h.pos.y), m._r(h.pos.z), m._r(h.pos.x), m._r(h.pos.y + 4.0), m._r(h.pos.z), col.to_html(false)])
	CombatBus.ability_used.emit(h, id + "_r_fuse", "ult_fuse")

func _tick_fuse(dt: float) -> void:
	var rd := r_def()
	var col := col_of(rd)
	fuse["t"] = float(fuse["t"]) - dt
	var unstop := String(fuse["guard"]) == "unstoppable"
	if unstop:
		h.fortify_t = maxf(h.fortify_t, 0.1)
		h.stun_t = 0.0; h.root_t = 0.0
	elif h.stun_t > 0.0 or h.downed or h.out:
		# interrupted: the ult fizzles and comes back after a short wait (that's the counterplay)
		fuse = {}
		cd["r"] = minf(float(cd["r"]), 8.0)
		m.fx.word(h.pos + Vector3(0, 2.4, 0), "INTERRUPTED", Color("ff8a7a"), true)
		m.sfx("warn", h.pos, -4.0, 0.8)
		return
	# energy gathers inward, faster and brighter toward the end
	var k := 1.0 - float(fuse["t"]) / maxf(0.01, float(fuse["T"]))
	fuse["fx"] = float(fuse["fx"]) - dt
	if float(fuse["fx"]) <= 0.0:
		fuse["fx"] = 0.05
		var a := randf() * TAU
		var r := lerpf(2.6, 1.2, k)
		var p := h.pos + Vector3(cos(a) * r, 0.4 + randf() * 1.6, sin(a) * r)
		var inward := (h.pos + Vector3(0, 1.0, 0) - p).normalized()
		m.fx.burst(p, col.lightened(0.3 * k), 3, 4.5 + 3.0 * k, 0.28, 0.0, 0.8 + 0.6 * k, inward, 12.0)
		if bool(fuse["bond"]) and h.kin and (h.kin as Kin).visible:
			# the Boki pours itself into you: kin-coloured streams from it to your chest
			var kc: Color = Data.KIN.get((h.kin as Kin).species, {}).get("color", Color.WHITE)
			var kp: Vector3 = (h.kin as Kin).position + Vector3(0, 0.4, 0)
			m.fx.burst(kp, kc, 3, 6.0, 0.25, 0.0, 1.0, (h.pos + Vector3(0, 1.1, 0) - kp).normalized(), 10.0)
			if randf() < 0.35: m.fx.bolt(kp, h.pos + Vector3(0, 1.1, 0), Color(kc, 0.8))
	if float(fuse["t"]) <= 0.0:
		var bond: bool = fuse["bond"]
		fuse = {}
		_fire_r(bond)

## The ult itself, after the fuse: its effect, then the big impact (and the merge when Bonded).
func _fire_r(will_bond: bool) -> void:
	if busy():
		cd["r"] = minf(float(cd["r"]), 8.0)
		return
	bonded = will_bond and KinMerge.can_cast(h)
	if not cast_r():
		bonded = false
		cd["r"] = minf(float(cd["r"]), 2.0)     # nobody left to hit: almost all of it back
		h._ab_feedback("r", "deny")
		return
	cd["r"] = r_cooldown()
	h.used["r"] = int(h.used.get("r", 0)) + 1
	CombatBus.ability_used.emit(h, id + "_r", "ult")
	_r_impact()
	if bonded:
		_bond_tell()
		if KinMerge.cast(h):
			drop_holds()
			Feel.hitstop(m, h, h, 0.0, {"bonded": true})
			if h.is_local() and m.hud: m.hud.flash(Feel.cat_color("control"), 0.25)
			Sfx.duck(0.3)

## The ult going off: a burst, a ring, a flash and a camera punch (the payoff of the fuse).
func _r_impact() -> void:
	var col := col_of(r_def())
	m.fx.ring(h.pos, 3.6, Color(col, 0.95), 0.4)
	m.fx.ring(h.pos, 1.8, Color(1, 1, 1, 0.9), 0.25)
	m.fx.burst(h.pos + Vector3(0, 1.0, 0), col, 34, 7.0, 0.55, 2.0, 1.4)
	m.fx.flash(h.pos + Vector3(0, 1.0, 0), col.lightened(0.4), 1.4, 0.12)
	m.sfx("boom", h.pos, -2.0, 0.8)
	Shake.incoming_big(m, h.pos, 0.6, h)
	if h.is_local():
		if m.hud: m.hud.flash(col, 0.18)
	if m.net_on and not h.remote:
		m.net_fx(["ring", m._r(h.pos.x), m._r(h.pos.y), m._r(h.pos.z), 3.6, col.to_html(false)])

## The 0.35s transform tell of a Bonded R: a column in the kin's colour visible within 25m.
func _bond_tell() -> void:
	var kc: Color = Data.KIN.get((h.kin as Kin).species, {}).get("color", Color.WHITE) if h.kin else Color.WHITE
	m.fx.ring(h.pos, 2.6, Color(kc, 0.95), 0.35)
	for i in 6:
		m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 0.4 + 0.5 * i, 0), kc, 10, 2.5, 0.35, -2.0, 1.1))
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "BONDED", kc, true)
	m.sfx("bond", h.pos, -2.0, 1.2)

# ------------------------------------------------------------------ dash helpers
## s the long (air) dash takes to come back: the hero's own `dash.air.cd` when its data has one, else the class's.
func long_dash_cd() -> float:
	var air: Dictionary = dash_def().get("air", {})
	return float(air.get("cd", h.cdat.get("ex_cd", Hunter.EX_DASH_CD)))

## Spends a dash charge (or the long air dash). False when neither is there.
func spend_dash(use_ex: bool) -> bool:
	if use_ex:
		if h.ex_cd > 0.0:
			h._ab_feedback("dash", "deny")
			return false
		h.ex_cd = long_dash_cd()
		h.ex_next = true
		h.gliding = false
	else:
		if h.dashes < 1.0:
			h._ab_feedback("dash", "deny")
			return false
		h.dashes -= 1.0
	return true

## The way a plain dash goes: where you're moving (WASD), or the cursor when you stand still or turn on
## Settings > "Dash toward the cursor". Aimed movement (a grapple, a blink to a spot) uses the cursor instead.
func dash_dir() -> Vector2:
	var move: Vector2 = h.inp.get("move", Vector2.ZERO)
	if move.length() < 0.1 or (h.is_local() and Settings.get_v("dash_to_cursor")):
		return h.aim_dir()
	return move.normalized()

static var _dash_feel := {}

## The global dash feel for this hunter (content/rules/dash_feel.json): {dist, time} multipliers.
func dash_feel() -> Dictionary:
	if _dash_feel.is_empty():
		_dash_feel = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/dash_feel.json"))
	return _dash_feel.get(id, _dash_feel["default"])

## A travelling dash of a given length and time (the Effects dash, so perfect dodges and the dash
## buffer all work as before). The hero's own: no Boki changes it (DECISIONS 2026-11-05, --boki-dash-check).
func travel(dist: float, t: float, extra := {}) -> void:
	var feel := dash_feel()
	dist *= float(feel["dist"])
	t *= float(feel["time"])
	var e := {"type": "dash", "speed": dist / maxf(0.02, t), "time": t, "invuln": float(extra.get("invuln", 0.0))}
	for k in extra:
		e[k] = extra[k]
	Effects.run([e], h, {"slot": "dodge", "ability": String(dash_def().get("id", "dash")), "level": rank("dash")})
	Feel.dash_sound(m, id, h.pos, h)
	CombatBus.ability_used.emit(h, String(dash_def().get("id", "dash")), "dodge")

# ------------------------------------------------------------------ infusion and the grammar
## The kin's infusion, or {} with no kin able to fight.
func infusion() -> Dictionary:
	var k: Kin = h.kin
	if k == null or k.dead or k.ks == null:
		return {}
	return Arch.infusion(k.ks)

## The socket budget multiplier: a merged kin lends ×1.3 (MERGED_SCALE), a Bonded R's sockets run
## at bonded budget.
func budget_k(slot: String) -> float:
	if slot == "r" and bonded:
		return float(KinParts.MERGED_SCALE[1])
	return float(KinParts.MERGED_SCALE[1]) if KinMerge.active(h) else 1.0

## A grammar stage for one of this kit's abilities, with the kin's parts in its sockets. stage is
## the plain stage dictionary (docs/KIN_GRAMMAR.md); slot: rmb | e | r. Returns a StageSpec.
func stage(slot: String, sd: Dictionary, sockets_override = null) -> StageSpec:
	var sockets: Dictionary = sockets_override if sockets_override is Dictionary else (d.get(slot, {}) as Dictionary).get("sockets", {})
	var s := sd.duplicate(true)
	var effs: Array = s.get("effects", [])
	var mods: Array = s.get("modifiers", [])
	var dt := String((s["delivery"] as Dictionary)["type"])
	var have: Array = mods.map(func(x): return String(x["type"]))
	var f := Arch.fill(sockets, infusion(), slot, dt, have, budget_k(slot))
	if f["swap"]:
		effs = effs.filter(func(e): return KinParts.category(String(e["type"])) != "control")
	for e in f["effects"]:
		# a stage can't carry the same control twice: the infused one wins over a weaker base
		var t := String(e["type"])
		if t in ["slow", "stun", "root", "pull", "push", "lift"]:
			effs = effs.filter(func(x): return String(x["type"]) != t)
		effs.append(e)
	if dt == "wall":
		effs = effs.filter(func(e): return KinParts.WALL_EFFECTS.has(String(e["type"])))
	while effs.size() > KinParts.MAX_EFFECTS:
		effs.pop_front()
	for md in f["mods"]:
		if mods.size() < KinParts.MAX_MODIFIERS: mods.append(md)
	if float(f["fallback"]) > 0.0:
		for e in effs:
			if String(e["type"]) == "damage" and float(e.get("over", 0.0)) <= 0.0:
				e["amount"] = minf(60.0, float(e["amount"]) * (1.0 + float(f["fallback"])))
				break
	s["effects"] = effs
	if not mods.is_empty(): s["modifiers"] = mods
	_clamp_parts(s)
	var rep := GrammarReport.new()
	rep.file = "%s.%s" % [id, slot]
	var depth := 2 if String((s["delivery"] as Dictionary).get("origin", "")) == "here" else 1
	var out := StageSpec.parse(s, "", rep, depth)
	if not rep.ok():
		# never let a kin's parts break the archetype: fall back to the plain stage
		push_warning("ArchKit: %s" % "; ".join(rep.errors))
		var rep2 := GrammarReport.new()
		var sd2 := sd.duplicate(true)
		_clamp_parts(sd2)
		out = StageSpec.parse(sd2, "", rep2, depth)
	return out

## Every number pulled inside its part's bounds before parsing (a Called Shot's bonus can't push a
## part past the grammar's caps; the parser would reject it).
static func _clamp_parts(sd: Dictionary) -> void:
	var dl: Dictionary = sd.get("delivery", {})
	for k in dl:
		if typeof(dl[k]) in [TYPE_FLOAT, TYPE_INT]: dl[k] = KinRules.clamp_param("delivery", String(dl["type"]), k, float(dl[k]))
	for e in sd.get("effects", []):
		for k in e:
			if typeof(e[k]) in [TYPE_FLOAT, TYPE_INT]: e[k] = KinRules.clamp_param("effect", String(e["type"]), k, float(e[k]))
	for md in sd.get("modifiers", []):
		for k in md:
			if typeof(md[k]) in [TYPE_FLOAT, TYPE_INT]: md[k] = KinRules.clamp_param("modifier", String(md["type"]), k, float(md[k]))
	for ev in sd.get("then", {}):
		for sub in sd["then"][ev]:
			_clamp_parts(sub)

## A cast context with this hunter as caster and owner, the kin as the kin.
func cx(slot: String, ability: String, aim: Vector3, extra := {}) -> Dictionary:
	var c := KinExec.make_cx(m, h, h.kin, h, aim, power({"rmb": "sec", "e": "kin", "r": "ult"}.get(slot, slot)), {"rmb": "utility", "e": "k1", "r": "ult"}.get(slot, slot), ability)
	for k in extra:
		c[k] = extra[k]
	return c

func run(st_: StageSpec, c: Dictionary) -> void:
	KinExec.run_stage(st_, c)

## A stage whose look and sound are the Hero's own (HeroVfx): the rules run, the shared cast language stays out.
func run_own(st_: StageSpec, c: Dictionary) -> void:
	c["silent"] = true
	m.fx.own_look = true
	Sfx.skip = OWN_LOOK_SKIP
	KinExec.run_stage(st_, c)
	Sfx.skip = []
	m.fx.own_look = false

# ------------------------------------------------------------------ helpers
func aim() -> Vector3:
	return h.inp.get("aim", h.pos)

## The aim point clamped to a reach, on the ground.
func aim_at(reach: float) -> Vector3:
	var a := aim()
	var dv := Vector2(a.x - h.pos.x, a.z - h.pos.z)
	if dv.length() > reach:
		dv = dv.normalized() * reach
	var p := Vector3(h.pos.x + dv.x, h.pos.y, h.pos.z + dv.y)
	var g: float = m.world.ground_at(p.x, p.z)
	if g > World.VOID + 1.0: p.y = g
	return p

func foes_in(at: Vector3, r: float, dy := 2.2) -> Array:
	var out: Array = []
	for f in m.foes_of(h.team):
		if f.hittable() and Vector2(f.pos.x - at.x, f.pos.z - at.z).length() < r + f.r and absf(f.pos.y - at.y) < dy:
			out.append(f)
	return out

func rival_hunters_in(r: float) -> Array:
	var out: Array = []
	for o in m.hunters:
		if o.team != h.team and o.targetable() and h.flat_dist(o) < r and sees(o):
			out.append(o)
	return out

func sees(e: Ent) -> bool:
	return m.world.los(h.pos, e.pos, h.pos.y + 0.95)

## Is `attacker` within the rear 120° of `t` (±60° of straight behind)?
static func behind(t: Ent, attacker: Ent, rear_deg := 120.0) -> bool:
	var fwd := Vector2(-sin(t.face), -cos(t.face))
	var to := Vector2(attacker.pos.x - t.pos.x, attacker.pos.z - t.pos.z)
	if to.length() < 0.05:
		return false
	return fwd.dot(to.normalized()) < -cos(deg_to_rad(rear_deg * 0.5))

func ground(p: Vector3) -> Vector3:
	var g: float = m.world.ground_at(p.x, p.z)
	return Vector3(p.x, g if g > World.VOID + 1.0 else p.y, p.z)

## A filling ground circle everyone sees; enemies get the hostile rim. Returns the node.
func tele_circle(at: Vector3, r: float, col: Color, t: float) -> Node3D:
	var c := col
	var p = m.get("player")
	if p != null and int(p.team) != h.team:
		c = col.lerp(Feel.RIM_ENEMY, 0.45)
	var tele: Node3D = m.fx.telegraph_circle(at, r, Color(c, 0.9))
	var tw := tele.create_tween()
	tw.tween_method(func(k: float): if is_instance_valid(tele): m.fx.telegraph_progress(tele, k), 0.0, 1.0, t)
	tw.tween_callback(func(): if is_instance_valid(tele): m.fx.end_telegraph(tele))
	return tele

## A filling lane (dash arrows, beams, charge lines).
func tele_lane(at: Vector3, dir: Vector2, length: float, width: float, col: Color, t: float) -> Node3D:
	var c := col
	var p = m.get("player")
	if p != null and int(p.team) != h.team:
		c = col.lerp(Feel.RIM_ENEMY, 0.45)
	var tele: Node3D = m.fx.telegraph_rect(at, dir, length, width, Color(c, 0.9))
	if t > 0.0:
		var tw := tele.create_tween()
		tw.tween_method(func(k: float): if is_instance_valid(tele): m.fx.telegraph_progress(tele, k), 0.0, 1.0, t)
		tw.tween_callback(func(): if is_instance_valid(tele): m.fx.end_telegraph(tele))
	return tele

## The out-of-combat clock: building or spending the resource keeps it from decaying.
func touch_res(wait := -1.0) -> void:
	res_wait = maxf(res_wait, float(res_def().get("wait", 3.0)) if wait < 0.0 else wait)

func add_res(v: float) -> void:
	res = clampf(res + v, 0.0, res_max())

## The resource tell (§3.2): a subtle glow at 50%, an aura and a short sting at full that
## enemies within 12-25m can hear. Also the Bonded R tell (kin glow and motes while bond is full).
func _tells(dt: float) -> void:
	var f := res_frac()
	var t := "full" if f >= 0.999 or full_ready() else ("half" if f >= 0.5 else "")
	if t == "full" and tell != "full":
		m.sfx("unlock", h.pos, -6.0 if h.is_local() else -3.0, 1.6)
		m.fx.ring(h.pos, 1.6, res_col(), 0.35)
	tell = t
	bonded_glow = int(h.slot_lv.get("ult", 0)) > 0 and h.ult >= 1.0 and h.kin != null and not (h.kin as Kin).dead
	fx_t -= dt
	if fx_t <= 0.0 and not h.unseen and h.visible and not h.out:
		fx_t = 0.18
		if tell != "":
			var rc := res_col()
			m.fx.burst(h.pos + Vector3(randf_range(-0.3, 0.3), 1.0 + randf() * 0.6, randf_range(-0.3, 0.3)), rc, 2 if tell == "half" else 5, 1.0, 0.45, -1.5, 0.7 if tell == "half" else 1.0)
			if tell == "full" and int(m.time * 5.0) % 3 == 0:
				m.fx.ring(h.pos, 0.9, Color(rc, 0.7), 0.25)
		if bonded_glow and h.kin and (h.kin as Kin).visible:
			var kc: Color = Data.KIN.get((h.kin as Kin).species, {}).get("color", Color.WHITE)
			var kp: Vector3 = (h.kin as Kin).position
			var a: float = m.time * 4.0
			m.fx.burst(kp + Vector3(cos(a) * 0.5, 0.5, sin(a) * 0.5), kc, 2, 0.6, 0.4, -1.0, 0.8)

## What the HUD draws for a slot ("sec", "k1", "r", "dash"), the same keys Hunter.slot_info uses.
func slot_info(slot: String) -> Dictionary:
	var out := {"name": "", "short": "", "icon": "", "col": Color.WHITE, "desc": "", "cd": 0.0, "cd_max": 0.0, "charges": 0, "max_charges": 0, "verb": "", "ready": false, "level": h.ability_level(slot)}
	match slot:
		"sec", "utility":
			var sd := rmb_def()
			var lines: Array = []
			for v in ["tap", "hold", "air", "during_e", "full"]:
				if (sd.get("variants", {}) as Dictionary).has(v):
					lines.append("%s: %s" % [{"tap": "Tap", "hold": "Hold", "air": "In the air", "during_e": "With E", "full": "Resource full"}[v], sd["variants"][v]])
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("short", "")), "icon": String(sd.get("icon", "")), "col": col_of(sd), "desc": "\n".join(lines),
				"cd": float(cd["rmb"]) if ch_rmb < 1.0 else 0.0, "cd_max": float(sd.get("cooldown", 6.0)) * cd_k("sec"), "charges": int(floor(ch_rmb)), "max_charges": rmb_charges(),
				"verb": "rmb", "ready": ch_rmb >= 1.0 and fire_ok_rmb(), "variant": last_variant, "full": full_ready()}, true)
		"k1", "e", "kin":
			var sd := e_def()
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("short", "")), "icon": String(sd.get("icon", "")), "col": col_of(sd), "desc": String(sd.get("desc", "")),
				"cd": float(cd["e"]), "cd_max": float(sd.get("cooldown", 14.0)) * cd_k("kin"), "charges": 1 if float(cd["e"]) <= 0.0 else 0, "max_charges": 1, "verb": "e",
				"ready": float(cd["e"]) <= 0.0 or (e_t > 0.0 and e_recastable()), "up": e_t, "full": e_payoff_ready()}, true)
		"r", "ult":
			var sd := r_def()
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("short", "")), "icon": String(sd.get("icon", "")), "col": col_of(sd), "desc": String(sd.get("desc", "")),
				"cd": float(cd["r"]), "cd_max": r_cooldown(), "charges": 1 if float(cd["r"]) <= 0.0 else 0, "max_charges": 1, "verb": "r",
				"ready": float(cd["r"]) <= 0.0 and int(h.slot_lv.get("ult", 0)) > 0, "bonded": bonded_glow, "up": r_t, "fuse": float(fuse.get("t", 0.0))}, true)
		"x":
			return HeroUlt.slot_info(self)
		"dash", "dodge":
			var sd := dash_def()
			var dmax := h.max_dashes()
			var owed := floorf(maxf(h.dashes, 0.0)) + 1.0 - h.dashes        # charges owed: over 1 after a long slide
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("name", "")).split(" ")[0], "icon": String(sd.get("icon", "dash")), "col": col_of(sd), "desc": String(sd.get("desc", "")),
				"cd": owed * h.dash_regen() if h.dashes < dmax - 0.001 else 0.0, "cd_max": h.dash_regen(), "charges": maxi(0, int(floor(h.dashes))), "max_charges": int(dmax), "verb": "dash", "ready": h.dashes >= 1.0, "full": dash_payoff_ready()}, true)
	return out

func e_recastable() -> bool: return false
## E fires on the key's press (a self-centred blast, e.on_press in data), never through the hold-to-aim preview.
func e_on_press() -> bool: return bool(e_def().get("on_press", false))
var anim_id := ""              # the kit move playing on the hunter (HunterAnim.KMOVES), its start
var anim_at := -9.0

## The kit's full-body move on the wire (Net 0.16.0): the move id and its age in seconds, after the
## state array after KinNet.hunter_extra (26-30), at index NET_MOVE_AT. Empty id: nothing playing (an expired move is not sent).
const NET_MOVE_AT := 31
const NET_MOVE_LIFE := 3.0     # seconds a move is still worth sending (the longest is about 2.5s)

static func net_move(h: Hunter) -> Array:
	var k: ArchKit = h.ak
	if k == null or k.anim_id == "" or h.m.time - k.anim_at > NET_MOVE_LIFE:
		return ["", 0.0]
	return [k.anim_id, snappedf(h.m.time - k.anim_at, 0.05)]

## A remote hunter's move starts when the id changes (or the sender's clock says it restarted), then plays
## on locally like any kit move; old hosts send nothing and the hunter just keeps its weapon poses.
static func apply_net_move(h: Hunter, it: Array) -> void:
	if h.ak == null or it.size() <= NET_MOVE_AT + 1:
		return
	var id := String(it[NET_MOVE_AT])
	if id == "":
		return
	var age := float(it[NET_MOVE_AT + 1])
	var k: ArchKit = h.ak
	if k.anim_id != id or absf((h.m.time - k.anim_at) - age) > 0.3:
		k.anim_id = id
		k.anim_at = h.m.time - age

## Plays one of the kit's full-body moves on the hunter (anticipation, key pose, recovery).
func play(move: String) -> void:
	anim_id = move
	anim_at = m.time

## True when the kit draws its own dash after-images; the hunter then skips the shared team-colour pill.
func own_dash_trail() -> bool: return false

## True when the kit draws its own aim line; the shared pale weapon line then stays hidden.
func own_aim_line() -> bool: return false

## The Vault-style flip that matches a dash direction: forward, back, or a side flip.
func flip_for(dir: Vector2, base: String) -> String:
	var fwd := Vector2(-sin(h.face), -cos(h.face))
	var right := Vector2(cos(h.face), -sin(h.face))
	if dir.length() < 0.1: return base + "_f"
	var f := dir.normalized().dot(fwd); var r := dir.normalized().dot(right)
	if absf(r) > absf(f): return base + ("_r" if r > 0.0 else "_l")
	return base + ("_f" if f >= 0.0 else "_b")

## Whether the shared charge ball glows at the hand (false: the kit shows its own held prop or orb).
func shows_charge_ball() -> bool: return true
## The rig's dodge pose for this kit's dash right now ("" = the class's own: phase, roll or charge).
func dodge_anim() -> String: return ""
## Dash charges the kit adds on top of the class's (the Juggernaut's Rampage at rank 2).
func extra_dashes() -> float: return 0.0

## A shot dodged through this hero's dash (kits that feed on it override).
func on_perfect_dodge() -> void: pass

## The payoff lives on the dash (the Thief's Primed shot into 3 Marks): the dash slot gets the gold dot.
func dash_payoff_ready() -> bool: return false

# ------------------------------------------------------------------ knocks and assists (kits2)
var touched := {}              # rival hunter id -> [hunter, time of our last hit on them]
var knocks_seen := 0           # knocks and assists this kit has seen (tests)

## Every hit this hunter lands (Match.on_damage calls it before on_deal): remembered for 5s, so a
## knock on them inside that window reaches on_knock (mine = the knocking blow was ours, else an assist).
func note_hit(t: Ent) -> void:
	if t is Hunter and t.team != h.team:
		touched[t.get_instance_id()] = [t, m.time]

func _tick_knocks() -> void:
	if touched.is_empty():
		return
	for key in touched.keys():
		var e: Array = touched[key]
		var t = e[0]
		if not is_instance_valid(t):
			touched.erase(key)
			continue
		if (t as Hunter).downed:
			touched.erase(key)
			var by = (t as Hunter).last_hit_by
			if by is Kin and (by as Kin).owner_h: by = (by as Kin).owner_h
			knocks_seen += 1
			on_knock(t, by == h)
		elif m.time - float(e[1]) > 5.0:
			touched.erase(key)

## A rival we hit in the last 5s was knocked (mine: our blow did it; else an assist).
func on_knock(_t: Hunter, _mine: bool) -> void: pass
## The weapon fires in this hero's dash when its LMB row says "fire" (DashFlow); a kit with its own dash overrides.
func fires_in_dash() -> bool: return String(flow.row("lmb")["mode"]) == "fire"
## The body and weapon stay on the cursor through this dash, the legs alone following it (item 109). False: she
## turns along the dash. A kit that fires mid-dash answers true, or the gun points away from its own rounds.
func aims_in_dash() -> bool: return fires_in_dash()
## In this hero's dash right now, as DashFlow sees it (a kit with its own dash state overrides this).
func in_dash() -> bool: return h.roll_t > 0.0 and h.move_kind == "dash"
## s left in that dash (0 when not in one); a kit that overrides in_dash() overrides this too.
func dash_left() -> float: return h.roll_t if in_dash() else 0.0
## The vertical speed a dash in the air holds while it runs (0: it holds the height); a skate sinks gently.
func dash_vy(_dt: float) -> float: return 0.0
## True while the model's facing is frozen (a statue): Hunter keeps `face` as it is, whatever the cursor does.
func face_locked() -> bool: return false
func fire_ok_rmb() -> bool: return true

# ------------------------------------------------------------------ payoffs and state tells (shared)
# The Thief (Cash In) and the Juggernaut (Rage Smash) set the bar: a kit builds a resource, the
# hunter visibly changes when its payoff is armed, and the payoff lands with a named word, T4
# hitstop (the hit carries payoff: true), a T4 shake, its own sound, VFX and a camera punch. The
# helpers below give the Archer, Mage, Gunslinger and Bulwark the same language.

var self_nodes: Array = []     # nodes this kit hangs on the hunter (freed by teardown on an archetype swap)
var spips := {}                # the kit's own pips over the hunter's head (Chambers, Guard steps)
var _pulse_t := 0.0

## The crosshair label while the kit's payoff is armed ("" = none).
func ready_label() -> String: return ""
## The payoff lives on E (the Mage's Flashpoint): the E slot gets the gold dot.
func e_payoff_ready() -> bool: return false

## Frees what this kit hung on the hunter (Hunter.set_arch calls it before swapping kits).
func teardown() -> void:
	var ring: Node3D = chg.get("ring")
	if ring and is_instance_valid(ring): m.fx.end_telegraph(ring)
	chg = {}
	for n in self_nodes:
		if is_instance_valid(n): (n as Node).queue_free()
	self_nodes.clear()
	spips = {}

## Where the hunter's right (or left) hand is in the world (the model's hand bone; shoulder height ahead
## of them when there is no model, as in headless checks).
func hand_pos(right: bool) -> Vector3:
	var hand: Node3D = null
	if h.anim != null:
		hand = h.anim.hand_r if right else h.anim.hand_l
	if hand != null and is_instance_valid(hand) and hand.is_inside_tree():
		return hand.global_position
	var d := h.aim_dir()
	return h.pos + Vector3(d.x * 0.4, 1.3 * float(h.cdat.get("scale", 1.0)), d.y * 0.4)

## A node that follows the hunter in world space (top_level child, so it dies with the hunter).
func own_node() -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	h.add_child(n)
	self_nodes.append(n)
	return n

## One of the Hero's moments (HeroVfx, content/vfx/<arch>.json), by default at the body along the aim.
func vfx(move: String, at: Variant = null, dir: Variant = null, o := {}) -> void:
	var where: Vector3 = h.pos if at == null else at
	var way: Vector2 = h.aim_dir() if dir == null else dir
	HeroVfx.of(m).play(h, move, where, way, o)

## Whether the hunter's own tells should draw (hidden while down, out, or unseen by the viewer).
func tells_visible() -> bool:
	if not is_instance_valid(h) or h.out or h.downed or not h.visible:
		return false
	return not h.unseen or h == m.get("player")

func net_ring(at: Vector3, r: float, col: Color) -> void:
	if m.net_on and not h.remote:
		m.net_fx(["ring", m._r(at.x), m._r(at.y), m._r(at.z), r, col.to_html(false)])

func net_bolt(a: Vector3, b: Vector3, col: Color) -> void:
	if m.net_on and not h.remote:
		m.net_fx(["bolt", m._r(a.x), m._r(a.y), m._r(a.z), m._r(b.x), m._r(b.y), m._r(b.z), col.to_html(false)])

## Other players' games don't run this kit: while the payoff is armed a ring in the resource colour
## pulses under the hunter for them every 1.1s (the existing Net fx ring; the protocol is unchanged).
func net_pulse(dt: float, on: bool, r := 1.1) -> void:
	if not on or not m.net_on or h.remote:
		_pulse_t = 0.0
		return
	_pulse_t -= dt
	if _pulse_t <= 0.0:
		_pulse_t = 1.1
		net_ring(h.pos, r, res_col())

## The payoff becoming armed: a word over the hunter, a ring, the ready ping (the owner's slot pings
## too); everyone online gets the ring.
func armed_fx(word: String, slot := "sec") -> void:
	var rc := res_col()
	if word != "": m.fx.word(h.pos + Vector3(0, 2.5, 0), word, rc, false)
	m.fx.ring(h.pos, 1.5, rc, 0.3)
	m.fx.burst(h.pos + Vector3(0, 1.3, 0), rc, 14, 3.0, 0.4, -2.0, 1.0)
	m.sfx("ab_ready", h.pos, -4.0 if h.is_local() else -7.0, 1.0)
	if h.is_local() and slot != "": h._ab_feedback(slot, "ready")
	net_ring(h.pos, 1.5, rc)

## A payoff landing (Deadeye, Flashpoint, Called Shot, Shield Slam): the named word, a double ring, a
## burst and a flash, the kit's own sound over a crit, the T4 shake, a camera punch toward it and a HUD
## flash for whoever landed it; everyone online gets a ring and a column. The hitstop comes from the
## hit itself (payoff: true is tier 4).
func payoff_fx(at: Vector3, word: String, col: Color, snd: String, dir := Vector2.ZERO, victim: Ent = null) -> void:
	m.fx.word(at + Vector3(0, 2.7, 0), word, col, true)
	m.fx.ring(at, 2.4, col, 0.38)
	m.fx.ring(at, 1.0, Color(1, 1, 1, 0.9), 0.2)
	m.fx.burst(at + Vector3(0, 1.1, 0), col, 36, 7.5, 0.65, 8.0, 1.3)
	m.fx.flash(at + Vector3(0, 1.0, 0), col.lightened(0.4), 1.3, 0.1)
	if snd != "": m.sfx(snd, at, 0.0, 1.0)
	m.sfx("crit", at, -7.0, 0.85)
	if h.is_local():
		if m.hud: m.hud.flash(col, 0.12)
	net_ring(at, 2.4, col)
	net_bolt(at + Vector3(0, 0.2, 0), at + Vector3(0, 3.6, 0), col)
	CombatBus.ability_used.emit(h, id + "_payoff", "secondary")

## The kit's pips floating over the hunter's head (everyone sees them): `n` diamonds on a small ring,
## `lit` of them bright, spinning and swelling while `armed`; `lift` m further up the screen and `grow`
## times as big where the default would sit over the face. Call every tick.
func self_pips(n: int, lit: int, armed: bool, dt: float, lift := 0.0, grow := 1.0) -> void:
	if spips.is_empty():
		var node := own_node()
		var ds: Array = []
		for i in n:
			var d := MeshInstance3D.new()
			d.mesh = Models.box(0.17, 0.17, 0.17)
			d.material_override = solid_mat(res_col())
			d.rotation = Vector3(0.0, 0.0, PI * 0.25)
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(d)
			ds.append(d)
		spips = {"node": node, "d": ds, "lit": 0, "pop": 0.0}
	var node: Node3D = spips["node"]
	if not is_instance_valid(node):
		spips = {}
		return
	node.visible = tells_visible() and (lit > 0 or armed)
	if not node.visible:
		spips["lit"] = lit
		return
	if lit > int(spips["lit"]): spips["pop"] = 1.0
	spips["lit"] = lit
	spips["pop"] = maxf(0.0, float(spips["pop"]) - dt * 4.0)
	var top := 2.35 * float(h.cdat.get("scale", 1.0)) + 0.25
	var cam := m.get_viewport().get_camera_3d() if m.is_inside_tree() else null
	var screen_up := cam.global_basis.y if cam != null else Vector3.UP
	node.global_position = h.position + Vector3(0, top, 0) + screen_up * lift
	var a: float = m.time * (5.0 if armed else 1.4)
	var ds: Array = spips["d"]
	var rad := (0.22 + 0.06 * ds.size()) * grow
	for i in ds.size():
		var d: MeshInstance3D = ds[i]
		var ang := a + TAU * i / float(ds.size())
		d.position = Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var on := i < lit
		var s := grow * ((1.0 + float(spips["pop"]) * 0.6) if on else 0.6)
		if armed: s *= 1.2 + 0.12 * sin(m.time * 10.0 + i)
		d.scale = Vector3.ONE * s
		var c := res_col().lightened(0.2) if armed else res_col()
		(d.material_override as StandardMaterial3D).albedo_color = Color(c, 1.0) if on else Color(0.08, 0.08, 0.1, 0.55)

## A flat, unlit, solid colour (pips and plates that must read as their colour, not glow white).
static func solid_mat(c: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_color = c
	mt.no_depth_test = false
	return mt

# ------------------------------------------------------------------ holds and charges (shared)
# Every hold in a kit (a charged RMB, a bow draw, a melee charge, a held dash) gets the same feel:
# a rising wind-up sound in the archetype's own voice (pitch and volume climb, the ticks quicken), a
# glow building at the hand and a filling ring at the hunter (enemies get the hostile rim), a clear
# "full" tick (a ping, a flash, a ring), a Net fx ring when it starts and when it's full (so remote
# players read it), and a release punch scaled by how far it got.

## [sound, pitch at 0, pitch at full] of each archetype's wind-up.
const CHARGE_VOICE := {
	"thief": ["swipe", 1.3, 2.3], "archer": ["click", 0.8, 2.0], "mage": ["zap", 0.7, 1.9],
	"gunslinger": ["reload", 0.8, 1.8], "juggernaut": ["thump", 0.55, 1.3], "bulwark": ["shield", 0.55, 1.2], "dolm": ["thump", 0.5, 1.2], "ostra": ["hover", 0.8, 1.9],
}
var chg := {}                  # the hold being charged: {src, k, full, tick, ring, glow}
var charge_last := 0.0         # how far the last hold got when it was let go (tests)
var charge_fulls := 0          # full ticks played (tests)

## How long the RMB must be held to be fully charged (0 = this RMB's hold isn't a charge, e.g. a shield).
func rmb_charge_full() -> float:
	return float(rmb_def().get("hold", 0.0))

## A held dash's charge 0..1 (-1: none). The Juggernaut's Rampage wind-up.
func dash_charge() -> float:
	return -1.0

## The hold being charged right now: [source, k 0..1] or ["", -1].
func charge_now() -> Array:
	var rf := rmb_charge_full()
	if rmb_down and rf > 0.0 and not rmb_ctx.get("air", false) and rmb_t > 0.06:
		return ["rmb", clampf(rmb_t / rf, 0.0, 1.0)]
	if h.draw_t >= 0.0 and h.draw_t < 5.0:
		return ["draw", clampf(h.draw_t / 0.9, 0.0, 1.0)]
	var ck := h.charge_k()
	if ck > 0.0:
		return ["melee", ck]
	var dk := dash_charge()
	if dk >= 0.0:
		return ["dash", dk]
	return ["", -1.0]

func charge_k() -> float:
	return float(chg.get("k", -1.0)) if not chg.is_empty() else -1.0

## The colour of the shared charge tell (the ring at the feet, the ticks, the full flash); kits with their
## own palette override it.
func charge_color() -> Color:
	return Arch.color(id)

## Called on each after-image tick of a dash: a kit with its own after-image draws it and returns true;
## false leaves the shared one.
func dash_afterimage() -> bool:
	return false

## Whether the shared charge tell shows its glowing orb at the hand; kits that draw their own hand tell
## turn it off.
func charge_orb() -> bool:
	return true

func _charge_ball(col: Color) -> Node3D:
	var g := own_node()
	var ball := MeshInstance3D.new()
	ball.mesh = Models.sphere(0.2, 10)
	ball.material_override = Models.glow_mat(Color(col.lightened(0.2), 1.0))
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(ball)
	return g

func _tick_charge(dt: float) -> void:
	var cn := charge_now()
	var src := String(cn[0]); var k := float(cn[1])
	if src == "" or not is_instance_valid(h) or h.downed or h.out:
		if not chg.is_empty():
			_charge_release()
		return
	var col := charge_color()
	if chg.is_empty() or String(chg["src"]) != src:
		if not chg.is_empty(): _charge_release()
		chg = {"src": src, "k": k, "full": false, "tick": 0.0}
		var rc := col
		var p = m.get("player")
		if p != null and int(p.team) != h.team: rc = col.lerp(Feel.RIM_ENEMY, 0.45)
		var ring: Node3D = m.fx.telegraph_circle(h.pos, 1.15 * float(h.cdat.get("scale", 1.0)), Color(rc, 0.9))
		chg["ring"] = ring
		if charge_orb():
			chg["glow"] = _charge_ball(col)
		net_ring(h.pos, 0.8, rc)            # remote players: "they're winding something up"
	chg["k"] = k
	var ring2: Node3D = chg.get("ring")
	if ring2 and is_instance_valid(ring2):
		ring2.global_position = h.pos + Vector3(0, 0.07, 0)
		m.fx.telegraph_progress(ring2, k)
	var g2: Node3D = chg.get("glow")
	if g2 and is_instance_valid(g2):
		var d := h.aim_dir()
		g2.visible = tells_visible() and shows_charge_ball()
		g2.global_position = h.position + Vector3(d.x * 0.6, 1.05 * float(h.cdat.get("scale", 1.0)), d.y * 0.6)
		var full_pulse := (0.3 * sin(m.time * 30.0)) if bool(chg["full"]) else 0.0
		g2.scale = Vector3.ONE * (0.25 + 1.35 * k + full_pulse)
	# the wind-up voice: ticks that climb in pitch and volume and come faster as it fills
	chg["tick"] = float(chg["tick"]) - dt
	if float(chg["tick"]) <= 0.0 and not bool(chg["full"]):
		chg["tick"] = lerpf(0.13, 0.05, k)
		var v: Array = CHARGE_VOICE.get(id, ["click", 0.8, 1.8])
		var mine := h.is_local()
		m.sfx(String(v[0]), h.pos, lerpf(-16.0, -6.0, k) - (0.0 if mine else 4.0), lerpf(float(v[1]), float(v[2]), k))
		if randf() < 0.5: m.fx.burst(h.position + Vector3(randf_range(-0.6, 0.6), 0.4 + randf(), randf_range(-0.6, 0.6)), col, 2, 2.0 + 3.0 * k, 0.25, 0.0, 0.7, (h.pos + Vector3(0, 1.0, 0) - h.position).normalized(), 30.0)
	if k >= 0.999 and not bool(chg["full"]):
		chg["full"] = true
		charge_fulls += 1
		_charge_full_tick(col)

## Fully charged: a bright ping, a flash at the hand, a ring; everyone online gets the ring.
func _charge_full_tick(col: Color) -> void:
	var v: Array = CHARGE_VOICE.get(id, ["click", 0.8, 1.8])
	m.sfx("ab_ready", h.pos, -3.0 if h.is_local() else -7.0, float(v[2]) * 0.6)
	m.sfx(String(v[0]), h.pos, -4.0, float(v[2]) * 1.15)
	var d := h.aim_dir()
	m.fx.flash(h.pos + Vector3(d.x * 0.6, 1.05, d.y * 0.6), col.lightened(0.4), 0.9, 0.08)
	m.fx.ring(h.pos, 1.5, Color(col, 0.95), 0.22)
	net_ring(h.pos, 1.5, col)

## Let go: the ring and glow go, and the release punches in proportion to the charge.
func _charge_release() -> void:
	var k := float(chg.get("k", 0.0))
	charge_last = k
	var ring: Node3D = chg.get("ring")
	if ring and is_instance_valid(ring): m.fx.end_telegraph(ring)
	var g: Node3D = chg.get("glow")
	if g and is_instance_valid(g):
		self_nodes.erase(g)
		g.queue_free()
	var full := bool(chg.get("full", false))
	chg = {}
	if not is_instance_valid(h) or h.downed:
		return
	if k > 0.5:
		m.fx.burst(h.pos + Vector3(h.aim_dir().x * 0.7, 1.0, h.aim_dir().y * 0.7), charge_color(), int(6 + 14 * k), 3.0 + 5.0 * k, 0.3, 0.0, 1.0, Vector3(h.aim_dir().x, 0.1, h.aim_dir().y), 35.0)

## Terrain (a wall, a rock, a ledge face) within `reach` behind `t` along `dir`.
func terrain_behind(t: Ent, dir: Vector2, reach: float) -> bool:
	var k := 0.3
	while k <= reach:
		var q := t.pos + Vector3(dir.x, 0, dir.y) * (t.r + k)
		if m.world.is_block(q.x, q.z) or m.world.ground_at(q.x, q.z) > t.pos.y + 0.8:
			return true
		k += 0.3
	return false

