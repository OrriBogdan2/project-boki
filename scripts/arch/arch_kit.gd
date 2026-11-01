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
var cd := {"rmb": 0.0, "e": 0.0, "r": 0.0}
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

static func make(hunter: Hunter, arch_id: String) -> ArchKit:
	var k: ArchKit
	match arch_id:
		"thief": k = ThiefKit.new()
		"archer": k = ArcherKit.new()
		"mage": k = MageKit.new()
		"gunslinger": k = GunslingerKit.new()
		"juggernaut": k = JuggernautKit.new()
		"bulwark": k = BulwarkKit.new()
		_: return null
	k.h = hunter
	k.m = hunter.m
	k.id = arch_id
	k.d = Arch.def(arch_id)
	k.ch_rmb = float(k.rmb_def().get("charges", 1))
	k._setup()
	return k

# ------------------------------------------------------------------ data
func rmb_def() -> Dictionary: return d.get("rmb", {})
func e_def() -> Dictionary: return d.get("e", {})
func r_def() -> Dictionary: return d.get("r", {})
func dash_def() -> Dictionary: return d.get("dash", {})
func res_def() -> Dictionary: return d.get("resource", {})
func res_max() -> float: return float(res_def().get("max", 100.0))
func res_col() -> Color: return Color(String(res_def().get("col", "#ffffff")))
func col_of(sd: Dictionary) -> Color: return Color(String(sd.get("col", "#ffffff")))

func rank(slot: String) -> int:
	return h.ability_level(slot)

## +15% damage per rank (Effects.level_k) on top of the hunter's own damage multiplier.
func power(slot: String) -> float:
	return m.dmg_mult(h) * Effects.level_k({"level": rank(slot)})

func cd_k(slot: String) -> float:
	return h.rank_cd_k(slot)

func rmb_charges() -> int: return int(rmb_def().get("charges", 1))

## R rank 2: +30% duration and +15% to its cast effects.
func r_dur_k() -> float: return 1.3 if rank("ult") >= 2 else 1.0
func r_k() -> float: return 1.15 if rank("ult") >= 2 else 1.0

# ------------------------------------------------------------------ overridable kit
func _setup() -> void: pass
func _tick(_dt: float) -> void: pass
func fire_rmb(_c: Dictionary) -> void: pass        # c: {hold, air, e, r, full, t, variant}
func rmb_press_extra() -> bool: return false        # a recast that takes the press (Shadow Step); true = handled
func rmb_hold_tick(_t: float) -> void: pass          # while RMB is held (shields, charge previews)
func rmb_auto_t() -> float: return 9.0               # a hold this long fires by itself
func full_ready() -> bool: return false              # the resource-full RMB variant is ready
func cast_e() -> bool: return false
func e_recast() -> bool: return false                # E pressed while it's up (Sigil detonation)
func cast_r() -> bool: return false
func r_recast() -> bool: return false                # R pressed while it runs (Last Round release)
func on_dash(_ex: bool) -> bool: return false        # true = the archetype handled the dash
func on_deal(_t: Ent, _dmg: float, _o: Dictionary) -> void: pass
func on_take(_by: Ent, _dmg: float, _o: Dictionary) -> void: pass
func on_block(_dmg: float, _by) -> void: pass
func outgoing(_t: Ent, dmg: float, _o: Dictionary) -> float: return dmg
func incoming(_by: Ent, dmg: float, o: Dictionary) -> Array: return [dmg, o]
func move_k() -> float: return 1.0
func fire_ok() -> bool: return true
func res_text() -> String: return "%d" % int(round(res))
func res_frac() -> float: return clampf(res / maxf(1.0, res_max()), 0.0, 1.0)
func bot_use(_tgt: Ent, _dist: float, _los: bool) -> void: pass
func describe_rmb_variant(c: Dictionary) -> String:
	for v in ["full", "r", "e", "air", "hold"]:
		if c.get(v, false): return {"full": "full", "r": "during_r", "e": "during_e", "air": "air", "hold": "hold"}[v]
	return "tap"

# ------------------------------------------------------------------ per step
func tick(dt: float) -> void:
	var rate := 1.0 + h.gear_stat("cdr")
	for k in cd.keys():
		cd[k] = maxf(0.0, float(cd[k]) - dt * rate)
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
	_tick(dt)
	_tells(dt)

func held(which: String) -> bool:
	match which:
		"rmb": return bool(h.inp.get("sec_hold", false)) or float(bot_hold["rmb"]) > 0.0
		"dash": return bool(h.inp.get("dash_down", false)) or float(bot_hold["dash"]) > 0.0
	return false

func _e_end() -> void: pass
func _r_end() -> void: pass

func busy() -> bool:
	return h.downed or h.out or h.dropping or h.riding or h.stun_t > 0.0

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

## R: the archetype's ultimate. With the bond meter full the cast is Bonded (§5 option C): the ult's
## own tell, then 0.2s later the kin merges (its on_start), one T5 moment for the caster.
func use_r() -> void:
	if busy():
		h._ab_feedback("r", "deny")
		return
	if r_t > 0.0 and r_recast():
		return
	if float(cd["r"]) > 0.0 or int(h.slot_lv.get("ult", 0)) <= 0:
		h._ab_feedback("r", "deny")
		return
	var will_bond := KinMerge.can_cast(h)
	bonded = will_bond
	if not cast_r():
		bonded = false
		h._ab_feedback("r", "deny")
		return
	cd["r"] = float(r_def().get("cooldown", 70.0))
	h.used["r"] = int(h.used.get("r", 0)) + 1
	h._ab_feedback("r", "cast")
	CombatBus.ability_used.emit(h, id + "_r", "ult")
	Feel.shake(m, "cast", h, h.pos, null, 3)
	if will_bond:
		_bond_tell()
		m.later(0.2, func():
			if is_instance_valid(h) and not h.downed and not h.out and KinMerge.cast(h):
				Feel.hitstop(m, h, h, 0.0, {"bonded": true})
				Feel.shake(m, "bonded", h, h.pos)
				if h.is_local() and m.hud: m.hud.flash(Feel.cat_color("control"), 0.25)
				Sfx.duck(0.3))

## The 0.35s transform tell of a Bonded R: a column in the kin's colour visible within 25m.
func _bond_tell() -> void:
	var kc: Color = Data.KIN.get((h.kin as Kin).species, {}).get("color", Color.WHITE) if h.kin else Color.WHITE
	m.fx.ring(h.pos, 2.6, Color(kc, 0.95), 0.35)
	for i in 6:
		m.later(0.05 * i, func(): if is_instance_valid(h): m.fx.burst(h.pos + Vector3(0, 0.4 + 0.5 * i, 0), kc, 10, 2.5, 0.35, -2.0, 1.1))
	m.fx.word(h.pos + Vector3(0, 2.6, 0), "BONDED", kc, true)
	m.sfx("bond", h.pos, -2.0, 1.2)

# ------------------------------------------------------------------ dash helpers
## Spends a dash charge (or the long air dash). False when neither is there.
func spend_dash(use_ex: bool) -> bool:
	if use_ex:
		if h.ex_cd > 0.0:
			h._ab_feedback("dash", "deny")
			return false
		h.ex_cd = float(h.cdat.get("ex_cd", Hunter.EX_DASH_CD))
		h.ex_next = true
		h.gliding = false
	else:
		if h.dashes < 1.0:
			h._ab_feedback("dash", "deny")
			return false
		h.dashes -= 1.0
	return true

## A travelling dash of a given length and time (the Effects dash, so perfect dodges, riders and
## the dash buffer all work as before).
func travel(dist: float, t: float, extra := {}, use_ex := false) -> void:
	var e := {"type": "dash", "speed": dist / maxf(0.02, t), "time": t, "invuln": float(extra.get("invuln", 0.0))}
	for k in extra:
		e[k] = extra[k]
	Effects.run([e], h, {"slot": "dodge", "ability": String(dash_def().get("id", "dash")), "level": rank("dash")})
	h._dash_rider(use_ex)
	Feel.dash_sound(m, id, h.pos, h)
	Feel.shake(m, "dash", h, h.pos)
	if h.is_local() and m.cam: m.cam.punch(0.03)
	CombatBus.ability_used.emit(h, String(dash_def().get("id", "dash")), "dodge")

## The kin's dodge rider on a dash that doesn't travel (a blink, a zip, a leap): on_start at the
## departure, on_pass on foes within 1m of the line (the streak rule), on_end at the arrival
## (DASHES §3.4). Returns the rider's repeat and as fields for the shape to interpret.
func rider_points(from: Vector3, to: Vector3) -> Dictionary:
	var out := {"repeat": null, "as": ""}
	var k: Kin = h.kin
	if k == null or k.dead or k.ks == null or k.ks.dodge_rider.is_empty():
		return out
	var rd: Dictionary = k.ks.dodge_rider
	var cx := KinExec.make_cx(m, h, k, h, h.inp.get("aim", to), m.dmg_mult(h) * Effects.level_k({"level": rank("dash")}), "dodge", "rider_" + k.species)
	var dir := Vector2(to.x - from.x, to.z - from.z)
	dir = dir.normalized() if dir.length() > 0.05 else h.aim_dir()
	if not (rd.get("on_start", []) as Array).is_empty():
		var c1 := cx.duplicate(); c1["at"] = from; c1["dir"] = dir
		KinExec.run_stages(rd["on_start"], c1)
	if not (rd.get("on_pass", []) as Array).is_empty():
		var a2 := Vector2(from.x, from.z); var b2 := Vector2(to.x, to.z)
		for f in m.foes_of(h.team):
			var fp := Vector2(f.pos.x, f.pos.z)
			if fp.distance_to(Geometry2D.get_closest_point_to_segment(fp, a2, b2)) < 1.0 + f.r and absf(f.pos.y - from.y) < 2.0:
				KinExec.apply_foe(rd["on_pass"], f, cx, from)
		m.fx.bolt(from + Vector3(0, 0.8, 0), to + Vector3(0, 0.8, 0), Hunter._rider_color(k.ks))
	if not (rd.get("on_end", []) as Array).is_empty():
		var c2 := cx.duplicate(); c2["at"] = to; c2["dir"] = dir
		KinExec.run_stages(rd["on_end"], c2)
	for md in rd.get("modifiers", []):
		if (md as PartSpec).type == "repeat": out["repeat"] = md
	out["as"] = String(rd.get("as", "dash"))
	var th := String(Data.KIN.get(k.species, {}).get("type", ""))
	Feel.sound(m, "sweet", th, from, h)
	return out

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
				"ready": float(cd["e"]) <= 0.0 or (e_t > 0.0 and e_recastable()), "up": e_t}, true)
		"r", "ult":
			var sd := r_def()
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("short", "")), "icon": String(sd.get("icon", "")), "col": col_of(sd), "desc": String(sd.get("desc", "")),
				"cd": float(cd["r"]), "cd_max": float(sd.get("cooldown", 70.0)), "charges": 1 if float(cd["r"]) <= 0.0 else 0, "max_charges": 1, "verb": "r",
				"ready": float(cd["r"]) <= 0.0 and int(h.slot_lv.get("ult", 0)) > 0, "bonded": bonded_glow, "up": r_t}, true)
		"dash", "dodge":
			var sd := dash_def()
			var dmax := h.max_dashes()
			out.merge({"name": String(sd.get("name", "")), "short": String(sd.get("name", "")).split(" ")[0], "icon": String(sd.get("icon", "dash")), "col": col_of(sd), "desc": String(sd.get("desc", "")),
				"cd": (1.0 - fposmod(h.dashes, 1.0)) * h.dash_regen() if h.dashes < 1.0 else 0.0, "cd_max": h.dash_regen(), "charges": int(floor(h.dashes)), "max_charges": int(dmax), "verb": "dash", "ready": h.dashes >= 1.0}, true)
	return out

func e_recastable() -> bool: return false
func fires_in_dash() -> bool: return false
func fire_ok_rmb() -> bool: return true
