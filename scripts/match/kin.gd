class_name Kin
extends Ent
## A kin in a match. It rides on its hunter's shoulder, gets thrown into fights, fights on its own,
## and has a mind: its traits, trust and memories decide whether it obeys, what it calls out, and how brave it is.
##
## Three separate pieces talk through CombatBus signals and plain calls:
##   this body (movement, states, visuals), KinTactics (who to chase, when to use an ability by
##   itself) and a KinRunner holding its two grammar abilities (k1 = the active on E, k2 = the auto
##   active it casts itself) from content/kin_v2. KinExec runs them from their parts; KinMerge runs
##   its bond ultimate. How it's carried (shoulder, perch or mount) comes from its KinSpec.

var species := "cindle"
var sp: Dictionary = {}
var rec: Dictionary = {}          # the saved record (player kin) or a generated one (bots, wild)
var owner_h: Hunter = null
var unseen := false             # a rival's kin out of the local player's sight
var state := "shoulder"           # shoulder | flying | active | returning | flying_home | fainted | reviving | wild | dazed | bench | fused
var settle := 1.0                 # 0..1 while settling onto the shoulder
var traits := {}
var trust := 50.0
var mood := 0.0
var dmg := 8.0
var speed := 6.5
var atk_cd := 0.0
var lunge_t := 0.0
var target: Ent = null
var chase_stall := 0.0          # seconds spent chasing a target without getting any closer (a ledge, a wall in the way)
var ignore_until := {}          # Ent -> m.time: targets it gave up on, left alone for a few seconds
var fly: Dictionary = {}          # thrown, leaping or rushing
var pend_skill := Vector3.INF     # ability to cast when it lands
var pend_slot := ""
var faint_t := 0.0
var hesitate_t := 0.0
var hesitate_to := Vector3.INF
var revive_wait := 0.0
var bark_cd := 0.0
var callout_seen := {}
var think_t := 0.0
var hop_ph := 0.0
var home := Vector3.ZERO          # wild kin wander around here
var wander_to := Vector3.INF
var dazed_t := 0.0
var catch_prog := 0.0
var angry_at: Ent = null
var power := 1.0                  # treat bonus
var events := []                  # things that happened this match, written to memory afterwards
var lines := {}                   # personalised barks, if the AI wrote any
var st_hits := 0                  # what it did this match, which shapes how it evolves
var st_kos := 0
var st_throws := 0
var st_skills := 0
var cd_mult := 1.0
var runner: KinRunner = null      # its two abilities (k1 = E, k2 = auto)
var ks: KinSpec = null            # its species in the grammar (content/kin_v2)
var grow := 0.0                   # level growth, capped by the expedition tier (KinRules.level_growth)
var melee_n := 0                  # its own melee hits, for "on_hit" triggers
var low_fired := {}               # on_low_hp triggers already fired this dip
var brain: KinTactics = null        # how it fights on its own
var throw_cd := 0.0               # a moment after a recall before it can be thrown again
var shield := 0.0
var shield_t := 0.0
var haste_t := 0.0
var giant: Dictionary = {}        # a mount merged giant under its rider: {scale, t0}
var lost_from := ""               # a kin left behind by a hunter who went down (name), for tracking
var lost_uid := ""
var lost_owner: Ent = null         # the hunter it was lost from (they get it back if revived first)
var ring: MeshInstance3D = null   # the team-coloured ring under it
var shell_fx: Node3D = null       # the glow around its hunter while fused
var comp: KinCompanion = null     # the teammate side: callouts, caring, where it walks (owned kin only)
# walking at your heel: while it's "on your shoulder" (carried, thrown from there) and you're on the
# ground, it hops down and trots beside you instead, and hops back up when you jump, dash or glide.
# Only where it's drawn changes; everything else still treats it as carried.
var heel_k := 0.0                 # 0 riding, 1 down at your heel
var heel_pos := Vector3.INF
var heel_prev := Vector3.INF
var heel_face := 0.0
var heel_moving := false
var heel_t := 0.0                 # how long you've been steady on your feet
var heel_spot_c := Vector3.INF
var heel_spot_t := 0.0
static var XRAY: Shader = preload("res://shaders/kin_aura_xray.gdshader")

func init_kin(match_node: Node, id: String, species_id: String, record: Dictionary, owner_hunter: Hunter) -> void:
	setup(match_node, id)
	kind = "kin"
	species = species_id if Data.KIN.has(species_id) else "cindle"
	sp = Data.KIN[species]
	rec = record
	owner_h = owner_hunter
	team = owner_hunter.team if owner_hunter else -1
	traits = rec.get("traits", sp["traits"]).duplicate()
	trust = float(rec.get("trust", 50.0))
	ks = KinLib.kin(species)
	# stats come from its points (after evolution's budget-neutral shifts); levels add a little,
	# capped by the expedition tier
	var pts := KinLib.points(ks, rec) if ks else {}
	grow = KinRules.level_growth(int(rec.get("level", 1)), int(match_node.get("tier")) if match_node.get("tier") != null else 0)
	max_hp = (KinLib.stat_value("kin_hp", pts) if ks else float(sp["hp"])) * (1.0 + grow)
	hp = max_hp
	dmg = (KinLib.stat_value("kin_damage", pts) if ks else float(sp["dmg"])) * (1.0 + grow)
	speed = KinLib.stat_value("kin_speed", pts) if ks else float(sp["speed"])
	var em := Mutations.mods(rec)        # rare mutations (Giant, Crystal...) keep their small perks
	max_hp *= em["hp"]; hp = max_hp
	dmg *= em["dmg"]
	speed *= em["speed"]
	cd_mult = em["cd"]
	if owner_h:
		# how well it's been raised: trained stats, how it's feeling, how close you are
		var cm := Care.match_mods(rec)
		max_hp *= float(cm["hp"]); hp = max_hp
		dmg *= float(cm["dmg"])
		speed *= float(cm["speed"])
		cd_mult *= float(cm["cd"])
		power *= float(cm["skill"])
		mood = float(cm["mood"])
		# IVS (inborn stats, Care.iv_mult): at most +10% health / +10% damage / +5% speed at 31,
		# on top of the kin's final stats (budget points + level growth + mutations + care).
		# The only match-side use besides the bond meter (Bond.add).
		max_hp *= Care.iv_mult(rec, "hp"); hp = max_hp
		dmg *= Care.iv_mult(rec, "atk")
		speed *= Care.iv_mult(rec, "spd")
	# its own size (Unique): a tiny capped trade-off (bigger: a little more health, a little slower)
	# and a hitbox to match; both off in a normalized match (Unique.normalized)
	var norm := Unique.normalized(match_node)
	var um := Unique.match_mods(rec, norm)
	max_hp *= float(um["hp"]); hp = max_hp
	speed *= float(um["speed"])
	r = 0.36 * (1.0 + minf(rec.get("forms", []).size() * 0.08, 0.4)) * (1.3 if ks and ks.size == "large" else 1.0) * Unique.hit_scale(rec, norm)
	state = "shoulder" if owner_h else "wild"
	settle = 1.0
	runner = KinRunner.new()
	if ks:
		runner.set_slot("k1", KinLib.ability(ks.active))
		if ks.auto != "": runner.set_slot("k2", KinLib.ability(ks.auto))
	runner.rate = 1.0 / maxf(0.3, cd_mult)
	brain = KinTactics.new(self)
	if owner_h:
		comp = KinCompanion.new(self)
	set_model(Models.kin(species, rec))
	ring = MeshInstance3D.new()
	ring.mesh = Models.flat_quad(1.0)
	var tc: Color = Data.TEAM_COLORS[team % Data.TEAM_COLORS.size()] if team >= 0 else Color("e8f4ff")
	ring.material_override = Models.ring_mat(Color(tc, 0.85), 0.16)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	add_child(ring)

func t(k: String) -> float:
	return float(traits.get(k, 0.5))

func is_wild() -> bool:
	return owner_h == null

func hittable() -> bool:
	return not dead and state in ["active", "flying", "returning", "reviving", "wild"] and not (state == "flying" and fly.get("leap", false))

func mass() -> float:
	var g := float(giant.get("scale", 1.0)) if not giant.is_empty() else 1.0
	return (ks.mass if ks else 0.8) * g * g

## How it's carried: "shoulder", "perch" or "mount" (KinSpec carry.style).
func carry_style() -> String:
	return ks.carry_style if ks else "shoulder"

## Riding with its hunter, settled in (its carry passives are on).
func carried() -> bool:
	return not dead and state == "shoulder" and settle >= 1.0

## Ability strength: treats and care, plus its level growth (capped by tier).
func ability_power() -> float:
	return power * (1.0 + grow)

## Is this slot unlocked this run? (Its abilities are locked until a skill point opens the kin slot.)
func slot_open(_slot: String) -> bool:
	# with an archetype the E slot is the archetype's; the kin's own ability (C) has only its cooldown
	return owner_h == null or owner_h.ak != null or int(owner_h.slot_lv.get("kin", 0)) > 0

## Can its abilities and ultimate be used right now?
func ready_to_fight() -> bool:
	return not dead and state not in ["fainted", "reviving", "bench", "wild", "dazed", "away"]

# ------------------------------------------------------------------ mind
func courage() -> float:
	return t("bravery") * 1.2 + trust / 100.0 * 1.2 + mood * 0.3

func danger_at(p: Vector3) -> float:
	var d := (1.0 - hp / max_hp) * 2.0
	for f in m.foes_of(team):
		var dist: float = Vector2(f.pos.x - p.x, f.pos.z - p.z).length()
		if dist < 4.5:
			var w := 0.6
			if f is Hunter: w = 1.4
			elif f.kind == "mob" and f.mkind == "brute": w = 2.0
			d += w * (1.0 - dist / 4.5)
	return d

## The owner asks it to jump into a fight. Returns "go", "hesitate" or "refuse".
func consider_throw(p: Vector3) -> String:
	if trust >= 90.0:
		return "go"          # soulbound: it goes wherever you send it
	var danger := danger_at(p)
	var c := courage()
	if danger > c + 1.1:
		return "refuse"
	if danger > c + 0.45:
		return "hesitate"
	return "go"

func note(kindk: String, text: String, trust_d := 0.0) -> void:
	# a kin that still misses the hunter it was taken from warms up to you far more slowly
	if trust_d > 0.0 and int(rec.get("pining", 0)) > 0:
		trust_d *= 0.35
	events.append({"kind": kindk, "text": text, "trust": trust_d})
	trust = clampf(trust + trust_d, 0.0, 100.0)

func bark(cat: String, extra := "") -> void:
	if bark_cd > 0.0 and cat not in ["refuse", "hesitate", "revive", "callout"]:
		return
	bark_cd = 3.0
	var txt := KinVoice.line(self, cat, extra)
	if txt != "":
		m.kin_bark(self, txt, cat)

# ------------------------------------------------------------------ owner commands
func throw_to(p: Vector3, slot := "") -> void:
	if state != "shoulder" or dead:
		return
	if hesitate_t > 0.0 or throw_cd > 0.0:
		return
	if settle < 0.35:
		return
	var verdict := consider_throw(p) if owner_h.is_local() or randf() < 0.3 else "go"
	if verdict == "refuse":
		bark("refuse")
		m.sfx("kin_unsure", owner_h.pos, -2.0, Unique.voice(rec))
		note("refused", "refused to jump into a fight that looked too dangerous", -1.0)
		return
	if slot != "":
		pend_skill = p
		pend_slot = slot
	if verdict == "hesitate":
		hesitate_t = 0.45
		hesitate_to = p
		bark("hesitate")
		m.sfx("kin_unsure", owner_h.pos, -4.0, Unique.voice(rec))
		return
	_launch(p)

func _launch(p: Vector3) -> void:
	st_throws += 1
	var dive := carry_style() == "perch"
	# a perched kin is thrown as a dive: up off your pack, then straight down onto the spot
	var start := owner_h.pos + Vector3(0, 3.4 if dive else 1.5, 0)
	if heel_k >= 0.5 and heel_pos != Vector3.INF and not dive:
		start = heel_pos + Vector3(0, 0.4, 0)     # it jumps from where it's standing at your heel
	var dist := Vector2(p.x - start.x, p.z - start.z).length()
	var maxd := 11.0 if dive else 9.0
	var d2 := Vector2(p.x - start.x, p.z - start.z)
	if dist > maxd:
		d2 = d2.normalized() * maxd
	var tgt := Vector3(start.x + d2.x, 0.0, start.z + d2.y)
	var g: float = m.world.ground_at(tgt.x, tgt.z)
	tgt.y = g if g > World.VOID + 1.0 else owner_h.pos.y
	var dur := clampf(d2.length() / (24.0 if dive else 16.0), 0.18, 0.55)
	teleport(start)
	fly = {"from": start, "to": tgt, "t": 0.0, "dur": dur, "hit": {}, "dive": dive}
	state = "flying"
	settle = 0.0
	m.sfx("throw", owner_h.pos, 0.0)
	CombatBus.kin_thrown.emit(self, owner_h)
	if danger_at(tgt) > 1.2 and hp < max_hp * 0.4:
		note("reckless", "was thrown into danger while hurt", -2.0)
	if randf() < 0.35:
		bark("throw")

## Calls it back. It leaps straight to your shoulder, and can't be thrown again for a moment.
func recall() -> void:
	if state in ["active", "flying", "returning"] and not fly.get("leap", false) and not fly.get("rush", false):
		if state == "active" and t("temper") > 0.72 and target and target.hp < target.max_hp * 0.3 and randf() < 0.6:
			bark("ignore")
			hesitate_t = 0.6
			hesitate_to = Vector3.INF
			return
		var to := Vector2(owner_h.pos.x - pos.x, owner_h.pos.z - pos.z)
		fly = {"from": pos, "to": owner_h.pos + Vector3(0, 1.5, 0), "t": 0.0, "dur": clampf(to.length() / 22.0, 0.15, 0.45), "hit": {}, "leap": true, "home": true}
		state = "flying_home"
		throw_cd = float(Content.rules("kin_ai").get("recall_cooldown", 1.0))
		m.sfx("recall", pos, -6.0)
		CombatBus.kin_recalled.emit(self, owner_h)
		fire_trigger("on_recall", {"at": owner_h.pos})

## Old name for a kin ability command, kept for older callers.
func command_skill(p: Vector3, slot := "k1") -> void:
	use_ability(slot, p)

## Uses ability k1 (E) or k2 (the auto active) at a spot. Out on the field the kin casts it itself.
## Carried (shoulder, perch, mount) or merged it never leaves you: it lends you the ability and you
## perform it. A from:owner ability always works on its hunter, wherever the kin is.
## Locked slots (run levels) never cast, by the player, a bot or the kin's own AI.
func use_ability(slot: String, p: Vector3, auto := false) -> bool:
	if runner == null or not runner.is_ready(slot) or not ready_to_fight() or not slot_open(slot):
		return false
	var def := runner.def_of(slot)
	if def.bond_cost > 0.0 and owner_h and owner_h.ult < def.bond_cost:
		return false
	var merged := state == "fused"
	var carried_now := state == "shoulder" or merged
	var pw := ability_power()
	if def.from == "owner":
		if owner_h == null:
			return false
		_cast(slot, p, auto, owner_h, pw)
		return true
	if carried_now:
		if auto or owner_h == null:
			return false        # a riding kin never acts on its own
		_cast(slot, p, auto, owner_h, pw * (1.0 if merged else 0.85))
		return true
	if state in ["returning", "flying_home"]:
		state = "active"
		fly = {}
	if state == "flying":
		pend_skill = p
		pend_slot = slot
		return false
	if def.cast_range > 0.0:
		var dd := Vector2(p.x - pos.x, p.z - pos.z)
		if dd.length() > def.cast_range:
			dd = dd.normalized() * def.cast_range
			p = Vector3(pos.x + dd.x, p.y, pos.z + dd.y)
	_cast(slot, p, auto, self, pw)
	return true

## The ability as this kin casts it now: evolution, the merged patch while merged, the slot's rank.
func effective(slot: String) -> AbilitySpec:
	var rank := owner_h.ability_level("kin") if owner_h else 1
	return KinLib.effective(runner.def_of(slot), slot, ks, rec, rank, KinMerge.patch(owner_h, slot) if owner_h else {})

func _cast(slot: String, p: Vector3, auto: bool, caster: Ent, pw: float, chain: Array = []) -> void:
	var def := runner.def_of(slot)
	var rank := owner_h.ability_level("kin") if owner_h else 1
	pend_skill = Vector3.INF
	pend_slot = ""
	runner.spend(slot, rank)
	if def.bond_cost > 0.0 and owner_h:
		owner_h.ult = maxf(0.0, owner_h.ult - def.bond_cost)
	var dd := Vector2(p.x - pos.x, p.z - pos.z)
	if dd.length() > 0.1 and caster == self:
		face = atan2(-dd.x, -dd.y)
	var cx := KinExec.make_cx(m, caster, self, owner_h, p, pw * Effects.level_k({"level": rank}), slot, def.id, chain)
	KinExec.cast(effective(slot), cx)
	CombatBus.ability_used.emit(caster, def.id, slot)
	if model:
		model.set_meta("pulse", Time.get_ticks_msec())
	st_skills += 1
	# each kin has its own cue: a warm whoomp (venom), a puff (spore), a stone rumble (gravity),
	# a glassy chime (prism), a swirl of wind (lunar), a low crackle of storm (echo)
	var cue := "k_%s" % String(sp.get("type", ""))
	m.sfx(cue if Sfx.has(cue) else "skill", pos, -2.0 if not auto else -7.0)
	m.on_kin_ability(self, def, auto)

## An event trigger (KinParts.TRIGGERS): on_throw, on_hit, on_recall, on_bond_full, on_low_hp.
## Fires the kin's matching ability if it's unlocked and ready. An ability is never set off by its
## own hits: ev.chain lists the abilities that caused the event, and a match there is refused.
## Returns true if something fired.
func fire_trigger(type: String, ev := {}) -> bool:
	if runner == null or owner_h == null or not ready_to_fight():
		return false
	for slot in ["k2", "k1"]:
		var def := runner.def_of(slot)
		if def == null or def.trigger == null or def.trigger.type != type:
			continue
		if (ev.get("chain", []) as Array).has(def.id):
			continue          # no ability triggers itself
		if not slot_open(slot) or not runner.is_ready(slot):
			continue
		match type:
			"on_hit":
				if melee_n % maxi(1, int(def.trigger.params.get("every", 3))) != 0:
					continue
		var at: Vector3 = ev.get("at", target.pos if target and is_instance_valid(target) else pos)
		if def.from == "kin" and state == "shoulder":
			continue          # a riding kin never acts on its own
		var caster: Ent = owner_h if def.from == "owner" else self
		_cast(slot, at, true, caster, ability_power(), ev.get("chain", []))
		return true
	return false

# ------------------------------------------------------------------ ability motion
## A charge along a line (a grammar dash): hits everything it passes through once.
func start_rush(d: Vector2, e: Dictionary, ctx: Dictionary) -> void:
	var dist := float(e.get("distance", 6.0))
	var to := pos
	var k := dist
	while k > 0.5:
		var q := pos + Vector3(d.x, 0, d.y) * k
		if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
			to = Vector3(q.x, m.world.ground_at(q.x, q.z), q.z); break
		k -= 0.5
	fly = {"from": pos, "to": to, "t": 0.0, "dur": maxf(0.08, pos.distance_to(to) / float(e.get("speed", 22.0))), "hit": {}, "rush": true, "e": e, "ctx": ctx}
	state = "flying"

## A jump onto a spot (a grammar leap): untouchable in the air, then its landing.
func start_leap(to: Vector3, e: Dictionary, ctx: Dictionary) -> void:
	var dd := Vector2(to.x - pos.x, to.z - pos.z)
	if dd.length() > 12.0:
		dd = dd.normalized() * 12.0
		to = Vector3(pos.x + dd.x, 0, pos.z + dd.y)
	var g: float = m.world.ground_at(to.x, to.z)
	to.y = g if g > World.VOID + 1.0 else pos.y
	fly = {"from": pos, "to": to, "t": 0.0, "dur": float(e.get("time", 0.45)), "hit": {}, "leap": true, "height": float(e.get("height", 1.6)),
		"land": e.get("on_land", []), "kx_land": e.get("kx_land", null), "ctx": ctx}
	state = "flying"

# ------------------------------------------------------------------ the merge (bond ultimate)
## KinMerge starts it: a mount grows giant under you; any other kin fuses onto you as armor.
func merge_in(giant_form: bool) -> void:
	fly = {}
	target = null
	pend_skill = Vector3.INF
	if giant_form:
		state = "shoulder"
		settle = 1.0
		giant = {"scale": 1.8, "t0": m.time}
		m.shake(0.6, owner_h.pos)
		m.sfx("boom", owner_h.pos, 0.0, 0.6)
	else:
		state = "fused"
		teleport(owner_h.pos + Vector3(0, 1.0, 0))
		if shell_fx == null and owner_h.model:
			shell_fx = Models.kin_shell(sp.get("glow", sp["color"]))
			owner_h.add_child(shell_fx)
	m.fx.flash(owner_h.pos + Vector3(0, 1.0, 0), sp.get("glow", sp["color"]), 1.8, 0.12)

## KinMerge ends it: back to riding with you, ready to throw again straight away.
func merge_out() -> void:
	if shell_fx:
		shell_fx.queue_free()
		shell_fx = null
	if not giant.is_empty():
		giant = {}
		m.fx.burst(pos + Vector3(0, 0.6, 0), sp["color"], 20, 4.0)
	if state == "fused" and owner_h and not owner_h.out:
		_hop_on()
		settle = 1.0
		m.fx.burst(pos, sp["color"], 16, 3.0)

func _sim_fused(_dt: float) -> void:
	if owner_h == null or owner_h.out:
		return
	pos = owner_h.pos + Vector3(0, 1.0, 0)
	prev = pos

func _end_merge(why: String) -> void:
	if owner_h and KinMerge.active(owner_h) and owner_h.kin == self:
		KinMerge.end(owner_h, why)

# ------------------------------------------------------------------ the bench (two kin per run)
func bench() -> void:
	_end_merge("bench")
	state = "bench"
	fly = {}
	target = null
	pend_skill = Vector3.INF

func unbench() -> void:
	state = "shoulder" if hp > 0.0 else "fainted"
	settle = 0.2
	if owner_h:
		pos = owner_h.pos + Vector3(0, 1.5, 0); prev = pos

# ------------------------------------------------------------------ simulation
func sim(dt: float) -> void:
	prev = pos
	if dead:
		return
	if state == "away":
		# your hunter is dead and waiting on a revive: the kin keeps out of sight until then
		if owner_h: pos = owner_h.pos; prev = pos
		return
	tick_status(dt)
	for k in ["atk_cd", "bark_cd", "lunge_t", "throw_cd", "haste_t"]:
		set(k, maxf(0.0, get(k) - dt))
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0: shield = 0.0
	if runner:
		runner.tick(dt)
	if remote:
		if state != "shoulder":
			net_follow(dt)
		elif owner_h:
			pos = owner_h.pos + Vector3(0, 1.5, 0); prev = pos
		if comp:
			comp._decay(dt)
		_heel_tick(dt)
		return
	if hesitate_t > 0.0:
		hesitate_t -= dt
		if hesitate_t <= 0.0 and hesitate_to != Vector3.INF and state == "shoulder":
			_launch(hesitate_to)
		elif hesitate_t <= 0.0 and state == "active" and hesitate_to == Vector3.INF:
			recall()
	think_t -= dt
	# a hop-out cast (C with an archetype): once its move is done the kin hops straight back
	if has_meta("hop_back") and m.time >= float(get_meta("hop_back")):
		if state == "active" and owner_h and not owner_h.out:
			remove_meta("hop_back")
			recall()
		elif state not in ["flying", "active"]:
			remove_meta("hop_back")
	match state:
		"shoulder": _sim_shoulder(dt)
		"flying": _sim_fly(dt)
		"flying_home": _sim_fly_home(dt)
		"active": _sim_active(dt)
		"returning": _sim_return(dt)
		"fainted": _sim_fainted(dt)
		"reviving": _sim_revive(dt)
		"wild": _sim_wild(dt)
		"dazed": _sim_dazed(dt)
		"fused": _sim_fused(dt)
		"bench":
			if owner_h:
				pos = owner_h.pos; prev = pos
			if hp < max_hp:
				hp = minf(max_hp, hp + max_hp * 0.02 * dt)   # resting in your satchel
	if owner_h and not owner_h.out and state in ["shoulder", "active"] and brain:
		brain.think_abilities(dt)
	if comp:
		comp.tick(dt)
	_heel_tick(dt)

## Down at your heel or up on your shoulder (only how it's drawn; see heel_k).
func _heel_tick(dt: float) -> void:
	heel_prev = heel_pos
	var o := owner_h
	var want := false
	if state == "shoulder" and o and comp and carry_style() in ["shoulder", "perch"] and giant.is_empty() \
			and not o.out and not o.extracted and not o.dropping and not o.riding and not o.downed:
		var steady: bool = o.grounded and not o.gliding and o.roll_t <= 0.0 and o.pad.is_empty() and o.grap.is_empty()
		heel_t = heel_t + dt if steady else 0.0
		want = heel_t > 0.3 and settle >= 1.0 and hesitate_t <= 0.0
	else:
		heel_t = 0.0
	if want:
		heel_spot_t -= dt
		if heel_spot_t <= 0.0 or heel_spot_c == Vector3.INF:
			heel_spot_t = 0.15
			heel_spot_c = comp.heel_spot()
		if heel_spot_c == Vector3.INF:
			want = false
	heel_moving = false
	if want:
		var tgt := heel_spot_c
		if heel_pos == Vector3.INF or heel_k <= 0.0:
			heel_pos = tgt
		var to := Vector2(tgt.x - heel_pos.x, tgt.z - heel_pos.z)
		var step := (maxf(Vector2(o.vel.x, o.vel.z).length(), speed * 0.6) + 3.0) * dt
		if to.length() > 0.08:
			var mv := to.normalized() * minf(to.length(), step)
			heel_pos += Vector3(mv.x, 0, mv.y)
			heel_moving = to.length() > 0.25
			if heel_moving:
				heel_face = lerp_angle(heel_face, atan2(-to.x, -to.y), minf(1.0, dt * 12.0))
		var g: float = m.world.ground_at(heel_pos.x, heel_pos.z)
		heel_pos.y = g if g > World.VOID + 1.0 and not m.world.is_void(heel_pos.x, heel_pos.z) else tgt.y
		if Vector2(heel_pos.x - o.pos.x, heel_pos.z - o.pos.z).length() > 3.8:
			want = false        # fell behind (a dash, a jump pad): back up onto the shoulder
		elif not heel_moving:
			# standing about: it looks where you look, or at what it's on about
			var lk: Vector3 = comp.look if comp.look != Vector3.INF else (o.inp.get("aim", o.pos) if o.inp else o.pos)
			var ld := Vector2(lk.x - heel_pos.x, lk.z - heel_pos.z)
			if ld.length() > 0.4:
				heel_face = lerp_angle(heel_face, atan2(-ld.x, -ld.y), minf(1.0, dt * 6.0))
	heel_k = move_toward(heel_k, 1.0 if want else 0.0, dt * 4.0)
	if heel_k <= 0.0:
		heel_pos = Vector3.INF
		heel_prev = Vector3.INF

## Where its speech bubble sits.
func bubble_at() -> Vector3:
	if state == "shoulder" and owner_h and heel_k < 0.5:
		return owner_h.position + Vector3(0, 2.3, 0)
	return position + Vector3(0, 1.2, 0)

## Where it is for the eye (down at your heel counts), for tests and callers that care.
func seen_pos() -> Vector3:
	if state == "shoulder" and owner_h:
		var top := owner_h.pos + Vector3(0, 1.5, 0)
		return top.lerp(heel_pos, heel_k) if heel_pos != Vector3.INF else top
	return pos

func _sim_shoulder(dt: float) -> void:
	if owner_h.out or owner_h.extracted:
		return
	pos = owner_h.pos + Vector3(0, 1.5, 0)
	prev = pos
	settle = minf(1.0, settle + dt / 1.0)
	if owner_h.downed:
		_consider_revive(dt)

func _sim_fly(dt: float) -> void:
	fly["t"] += dt
	var k := clampf(fly["t"] / fly["dur"], 0.0, 1.0)
	var a: Vector3 = fly["from"]; var b: Vector3 = fly["to"]
	var rush: bool = fly.get("rush", false)
	var arc := 0.0 if rush or fly.get("dive", false) else sin(k * PI) * (float(fly.get("height", 1.6)) if fly.get("leap", false) else 0.8)
	pos = a.lerp(b, k) + Vector3(0, arc, 0)
	if rush:
		var e: Dictionary = fly["e"]
		for f in m.foes_of(team):
			if fly.is_empty(): return      # a hit can end the flight (a knock, a recall) mid-loop
			if fly["hit"].has(f.nid):
				continue
			if Vector2(f.pos.x - pos.x, f.pos.z - pos.z).length() < f.r + float(e.get("width", 1.0)) and absf(f.pos.y - pos.y) < 1.8:
				fly["hit"][f.nid] = true
				if e.get("kx_hit") is Callable:
					(e["kx_hit"] as Callable).call(f)       # a grammar dash: its effects and on_hit followups
					continue
				var dirv := Vector2(b.x - a.x, b.z - a.z).normalized()
				var o := {"src": "kin", "ab": String(fly["ctx"].get("slot", "k1")), "tags": [String(fly["ctx"].get("slot", "")), String(fly["ctx"].get("ability", "")), "kin"], "kb": dirv.rotated(PI / 2 * (1.0 if randf() < 0.5 else -1.0)) * float(e.get("kb", 4.0))}
				for st in ["burn", "stun", "slow", "root"]:
					if e.has(st): o[st] = float(e[st])
				f.hurt(float(e.get("dmg", 10.0)) * float(fly["ctx"].get("power", 1.0)), self, o)
		if randf() < 0.6:
			m.fx.burst(pos + Vector3(0, 0.3, 0), Color(String(e.get("color", "#ffffff"))), 3, 1.5, 0.35, -2.0)
	elif not fly.get("leap", false):
		# a thrown kin hits whoever it flies into: damage, a short stun, and an opening for your shots.
		# A perched kin dives: it only strikes as it comes down on the spot, a little wider.
		var dive: bool = fly.get("dive", false)
		for f in m.foes_of(team):
			if fly.is_empty(): return      # a hit can end the flight (a knock, a recall) mid-loop
			if fly["hit"].has(f.nid):
				continue
			if dive and k < 0.55:
				continue
			if Vector2(f.pos.x - pos.x, f.pos.z - pos.z).length() < f.r + (0.9 if dive else 0.5) and absf(f.pos.y + 0.6 - pos.y) < (2.2 if dive else 1.6):
				fly["hit"][f.nid] = true
				var dirv := Vector2(b.x - a.x, b.z - a.z).normalized()
				# the throw itself is core (damage, a short stun, a shove); the kin's throw effects ride on it
				var extra := {"kb": dirv * 4.0, "stun": 0.6, "src": "throw", "ab": "throw", "tags": ["throw", "kin"], "dr": true}
				var cx := KinExec.make_cx(m, self, self, owner_h, f.pos, ability_power(), "throw", "throw")
				KinExec.apply_foe(ks.throw_effects if ks else [], f, cx, pos, null, 16.0 * power, extra)
				fire_trigger("on_throw", {"at": f.pos})
				m.sfx("kinhit", pos, 0.0)
				m.fx.burst(pos, sp["color"], 14, 4.0)
				m.shake(0.25, pos)
				if owner_h and owner_h.is_local():
					m.freeze_frame(0.06)
				target = f
	if k >= 1.0:
		var land: Array = fly.get("land", [])
		var lctx: Dictionary = fly.get("ctx", {})
		var rush_end: Array = fly["e"].get("on_end", []) if rush else []
		var kx_land = fly.get("kx_land", null)
		var kx_end = fly["e"].get("kx_end", null) if rush else null
		fly = {}
		var g := ground()
		if g <= World.VOID + 1.0:
			pos.y = b.y
			grounded = false
		else:
			pos.y = g
			grounded = true
		vel = Vector3.ZERO
		state = "active"
		if not land.is_empty():
			m.fx.dust(pos, 14)
			m.shake(0.35, pos)
			var c2 := lctx.duplicate(); c2["at"] = pos
			Effects.run(land, self, c2)
		if not rush_end.is_empty():
			var c3 := lctx.duplicate(); c3["at"] = pos
			Effects.run(rush_end, self, c3)
		if kx_land is Callable:
			m.fx.dust(pos, 14)
			m.shake(0.35, pos)
			(kx_land as Callable).call(pos)
		if kx_end is Callable:
			(kx_end as Callable).call(pos)
		if pend_skill != Vector3.INF and pend_slot != "":
			var ps := pend_slot
			var pp := pend_skill
			pend_slot = ""
			pend_skill = Vector3.INF
			use_ability(ps, pp)

func _sim_fly_home(dt: float) -> void:
	if owner_h == null or owner_h.out:
		return
	fly["t"] += dt
	fly["to"] = owner_h.pos + Vector3(0, 1.5, 0)
	var k := clampf(fly["t"] / fly["dur"], 0.0, 1.0)
	pos = (fly["from"] as Vector3).lerp(fly["to"], k) + Vector3(0, sin(k * PI) * 1.4, 0)
	if k >= 1.0:
		_hop_on()

func walkable_to(p: Vector3) -> bool:
	var d := Vector2(p.x - pos.x, p.z - pos.z)
	var n := int(d.length() / 0.6) + 1
	for i in range(1, n + 1):
		var q := Vector2(pos.x, pos.z) + d * (float(i) / n)
		if m.world.is_void(q.x, q.y):
			return false
	return absf(p.y - pos.y) < 2.0

func _sim_active(dt: float) -> void:
	if owner_h and (owner_h.out or owner_h.extracted):
		return
	var guard: Ent = _wisp_threat() if owner_h and owner_h.downed else null
	if guard:
		# someone's come to stomp or execute your hunter: the kin goes for them first
		target = guard
	elif owner_h and owner_h.downed:
		_consider_revive(dt)
		if state != "active":
			return
	# cautious kin back off to you when they're hurt
	if owner_h and hp < max_hp * brain.retreat_frac():
		if bark_cd <= 0.0:
			bark("scared")
		state = "returning"
		return
	if owner_h and flat_dist(owner_h) > brain.leash():
		state = "returning"
		return
	if guard == null and (target == null or target.dead or not target.hittable() or (target is Hunter and target.downed) or flat_dist(target) > brain.chase_range() + 3.0 or randf() < dt * 0.5):
		target = brain.pick_target()
	var wish := Vector2.ZERO
	var spd := speed * slow_mult(0.6) * (1.3 if haste_t > 0.0 else 1.0)
	if root_t > 0.0 or stun_t > 0.0:
		spd = 0.0
	if target:
		var to := Vector2(target.pos.x - pos.x, target.pos.z - pos.z)
		var d := to.length()
		var reach: float = sp["range"] + target.r
		if d > reach * 0.8:
			wish = to.normalized() * spd
			# chasing something it can't get to (up a ledge, round a wall): give up on it for a while
			# and come back to you, instead of standing there pressing into the wall
			chase_stall = chase_stall + dt if Vector2(vel.x, vel.z).length() < spd * 0.35 and spd > 0.0 else 0.0
			if chase_stall > 0.8:
				chase_stall = 0.0
				ignore_until[target] = m.time + 5.0
				target = null
				wish = Vector2.ZERO
		if d < reach and atk_cd <= 0.0 and absf(target.pos.y - pos.y) < 1.5:
			atk_cd = 0.95
			lunge_t = 0.15
			vel.x += to.normalized().x * 5.0; vel.z += to.normalized().y * 5.0
			var tp := target.pos
			target.hurt(dmg * power, self, {"kb": to.normalized() * 2.0, "src": "kin", "tags": ["kin", "melee"]})
			m.sfx("kinhit", pos, -6.0, 1.0)
			melee_n += 1
			fire_trigger("on_hit", {"at": tp})
	elif owner_h:
		# no fight for it: back to your side like a teammate, at your heel or between you and
		# whatever's close; it hops onto your shoulder if you glide off
		var to := Vector2(owner_h.pos.x - pos.x, owner_h.pos.z - pos.z)
		if owner_h.gliding and to.length() > 2.5:
			state = "returning"
			return
		var spot: Vector3 = comp.heel_spot() if comp else Vector3.INF
		if spot != Vector3.INF and to.length() < 8.0:
			# keep pace like a teammate: move with you (your velocity) plus a pull toward the heel spot.
			# Chasing the spot at its own run speed alone left it trailing ~3.5m behind a hunter who
			# runs faster than it does (archetype paces, hastes, dash carry)
			var ts := Vector2(spot.x - pos.x, spot.z - pos.z)
			var ov := Vector2(owner_h.vel.x, owner_h.vel.z)
			if ts.length() > 0.5 or ov.length() > 0.3:
				wish = (ov + ts * HEEL_PULL).limit_length(maxf(spd * 1.45, ov.length() * 1.3))
				if root_t > 0.0 or stun_t > 0.0: wish = Vector2.ZERO
		elif to.length() > brain.idle_radius() + 1.0:
			wish = to.normalized() * spd
		if to.length() > 6.0 and not walkable_to(owner_h.pos):
			state = "returning"
		elif to.length() > 8.0:
			state = "returning"      # well off (after a fight): run back hard, or leap, rather than amble
	_ground_move(wish, dt)

const HEEL_PULL := 4.0     # 1/s: how hard an out-of-place kin closes on its heel spot, on top of your pace

func _ground_move(wish: Vector2, dt: float) -> void:
	var hv := Vector2(vel.x, vel.z)
	var k := 12.0 if grounded else 2.0
	# speed above a run (a knock, a lunge) eases off slowly; keeping pace with a fast hunter isn't that
	var run_cap := maxf(speed * 1.3, wish.length() * 1.05)
	if hv.length() > run_cap:
		k = 3.0 if grounded else 0.6
	hv += (wish - hv) * (1.0 - exp(-k * dt))
	# don't walk off edges on purpose
	var ahead := Vector2(pos.x, pos.z) + hv.normalized() * (r + 0.25)
	if grounded and hv.length() <= run_cap and wish.length() > 0.1 and m.world.is_void(ahead.x, ahead.y):
		hv = Vector2.ZERO
	vel.x = hv.x; vel.z = hv.y
	slide(dt)
	body_vertical(dt)
	if hv.length() > 0.3:
		face = lerp_angle(face, atan2(-hv.x, -hv.y), minf(1.0, dt * 12.0))

func _sim_return(dt: float) -> void:
	if owner_h == null or owner_h.out:
		return
	var to := Vector2(owner_h.pos.x - pos.x, owner_h.pos.z - pos.z)
	if to.length() < 1.2:
		_hop_on()
		return
	if not walkable_to(owner_h.pos) or to.length() > 9.0:
		# leap straight back to the shoulder
		fly = {"from": pos, "to": owner_h.pos + Vector3(0, 1.5, 0), "t": 0.0, "dur": clampf(to.length() / 18.0, 0.2, 0.6), "hit": {}, "leap": true, "home": true}
		state = "flying_home"
		return
	_ground_move(to.normalized() * speed * 1.25, dt)

func _hop_on() -> void:
	state = "shoulder"
	settle = 0.0
	target = null
	fly = {}
	pos = owner_h.pos + Vector3(0, 1.5, 0)

func _sim_fainted(dt: float) -> void:
	faint_t -= dt
	if not over_void():
		body_vertical(dt)
	if faint_t <= 0.0 and owner_h and not owner_h.out:
		hp = max_hp * 0.5
		_hop_on()
		m.fx.burst(owner_h.pos + Vector3(0, 1.5, 0), sp["color"], 10, 2.0)

func faint(fell := false) -> void:
	_end_merge("fainted")
	state = "fainted"
	faint_t = 8.0
	hp = 0.0
	target = null
	fly = {}
	m.fx.burst(pos + Vector3(0, 0.4, 0), sp["color"], 16, 3.0)
	if owner_h:
		note("fainted", "fainted in a fight" if not fell else "fell off the island", -0.5)
		if fell:
			pos = owner_h.pos
			prev = pos
	m.on_kin_faint(self)

func _on_zero(_by: Ent, _opts: Dictionary) -> void:
	if state in ["dazed", "fainted"]:
		hp = maxf(hp, 1.0)
		return
	if is_wild():
		hp = 1.0
		_daze()
		return
	faint()

func fall_out() -> void:
	if is_wild():
		dead = true
		m.on_fell(self)
		return
	faint(true)

func _consider_revive(dt: float) -> void:
	if state == "fainted" or hp <= 0.0:
		return
	if revive_wait <= 0.0:
		# loyal kin rush in; a kin that doesn't trust you takes a moment
		revive_wait = 0.1 + (1.0 - t("loyalty")) * 1.2 + (1.0 - trust / 100.0) * 1.8
		bark("revive")
	revive_wait -= dt
	if revive_wait > 0.0:
		return
	if state == "shoulder":
		pos = owner_h.pos + Vector3(0.6, 0, 0.3)
		pos.y = owner_h.pos.y
		grounded = true
	state = "reviving"

## An enemy standing over your downed hunter (to stomp or execute them).
func _wisp_threat() -> Ent:
	if owner_h == null or not owner_h.downed or hp <= 0.0:
		return null
	for f in m.hunters:
		if f.team != owner_h.team and not f.downed and not f.out and f.hittable() and f.flat_dist(owner_h) < 3.0:
			return f
	return null

func _sim_revive(dt: float) -> void:
	var threat := _wisp_threat()
	if threat:
		state = "active"
		target = threat
		bark("owner_down")
		return
	if owner_h == null or not owner_h.downed or owner_h.out:
		state = "active"
		revive_wait = 0.0
		return
	var to := Vector2(owner_h.pos.x - pos.x, owner_h.pos.z - pos.z)
	if to.length() > 1.3:
		if not walkable_to(owner_h.pos):
			pos = owner_h.pos + Vector3(0.6, 0, 0); prev = pos
		_ground_move(to.normalized() * speed * 1.3, dt)
		return
	_ground_move(Vector2.ZERO, dt)
	var speedup := 0.8 + trust / 100.0 * 0.4
	owner_h.revive += dt / Life.R["kin_revive_time"] * speedup
	if owner_h.revive >= 1.0:
		m.revive_hunter(owner_h, self)
		note("revived", "pulled you back up when you were down", 4.0)
		revive_wait = 0.0
		_hop_on()

# ---- wild kin
func _sim_wild(dt: float) -> void:
	var wish := Vector2.ZERO
	if angry_at and (angry_at.dead or flat_dist(angry_at) > 10.0 or (angry_at is Hunter and angry_at.downed)):
		angry_at = null
	if angry_at:
		var to := Vector2(angry_at.pos.x - pos.x, angry_at.pos.z - pos.z)
		if t("bravery") < 0.45:
			wish = -to.normalized() * speed * 0.9  # timid wild kin run away
		else:
			if to.length() > 1.2:
				wish = to.normalized() * speed * 0.85
			elif atk_cd <= 0.0:
				atk_cd = 1.1
				lunge_t = 0.15
				angry_at.hurt(dmg * 0.8, self, {"kb": to.normalized() * 2.0, "src": "kin"})
	else:
		if wander_to == Vector3.INF or flat_dist(wander_to) < 0.5 or randf() < dt * 0.15:
			var a := randf() * TAU
			var q := home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 3.5)
			if not m.world.is_void(q.x, q.z) and not m.world.is_block(q.x, q.z):
				wander_to = q
		if wander_to != Vector3.INF:
			var to := Vector2(wander_to.x - pos.x, wander_to.z - pos.z)
			wish = to.normalized() * speed * 0.35
	_ground_move(wish, dt)

func _daze() -> void:
	burn_t = 0.0
	state = "dazed"
	dazed_t = 9.0 if lost_from == "" else 1e9   # a kin left behind waits where it was lost
	angry_at = null
	m.fx.burst(pos + Vector3(0, 0.8, 0), Color("fff2a0"), 10, 2.0)
	m.on_wild_dazed(self)

func _sim_dazed(dt: float) -> void:
	dazed_t -= dt
	_ground_move(Vector2.ZERO, dt)
	hp = minf(max_hp * 0.25, hp + dt * 0.5)
	if dazed_t <= 0.0:
		state = "wild"
		hp = max_hp * 0.45
		catch_prog = 0.0

func hurt(d: float, by: Ent, opts := {}) -> float:
	if state in ["dazed", "bench", "fused"]:
		return 0.0
	if is_wild() and by and by is Hunter:
		angry_at = by
	elif is_wild() and by and by is Kin and by.owner_h:
		angry_at = by.owner_h
	if shield > 0.0 and d > 0.0:
		var soak := minf(shield, d)
		shield -= soak
		d -= soak
		if d <= 0.0:
			flash_t = 0.08
			return 0.0
	return super.hurt(d, by, opts)

# (callouts, caring and where it walks beside you live in KinCompanion)

# ------------------------------------------------------------------ visuals
func render(delta: float, alpha: float) -> void:
	super.render(delta, alpha)
	visible = not dead and state != "bench" and state != "away" and not (owner_h and (owner_h.out or owner_h.extracted or owner_h.riding))
	if not model:
		return
	var body: Node3D = model.get_node("Body")
	var shell: Node3D = model.get_node_or_null("Body/Shell")
	hop_ph += delta * (9.0 if Vector2(vel.x, vel.z).length() > 0.5 else 3.0)
	var out_now := state in ["active", "flying", "returning", "reviving", "flying_home"]
	if ring:
		ring.visible = visible and (out_now or has_meta("lineup")) and not unseen
		if ring.visible:
			var rs := r * 2.6 + 0.3
			ring.global_position = Vector3(global_position.x, m.world.ground_at(global_position.x, global_position.z) + 0.06, global_position.z)
			ring.scale = Vector3.ONE * rs * (1.0 + 0.06 * sin(m.time * 5.0))
	if shell and not has_meta("xr") and m.player:
		# your squad's kin glow through grass and walls, so you never lose track of them
		set_meta("xr", true)
		if team == m.player.team and owner_h:
			var sm0: ShaderMaterial = (shell as MeshInstance3D).material_override
			sm0.shader = XRAY
	if shell:
		var want := 0.0 if state in ["shoulder", "fused"] else (1.0 if not giant.is_empty() else 0.6)
		if state in ["wild", "dazed"]: want = 0.25 if not has_meta("lineup") else 0.6
		shell.set_meta("a", lerpf(float(shell.get_meta("a", 0.0)), want, minf(1.0, delta * 6.0)))
		var sm: ShaderMaterial = (shell as MeshInstance3D).material_override
		sm.set_shader_parameter("strength", float(shell.get_meta("a", 0.0)))
		shell.visible = float(shell.get_meta("a", 0.0)) > 0.02
	var parts: Node = model.get_node_or_null("Aura")
	if parts:
		(parts as CPUParticles3D).emitting = visible and state not in ["shoulder", "bench", "fused"] and not unseen
	if state == "fused" and owner_h and owner_h.model:
		# wrapped around its hunter's back as armor
		global_position = owner_h.model.global_position + Vector3(0, 1.05, 0) + Vector3(sin(owner_h.face), 0, cos(owner_h.face)) * 0.32
		model.rotation.y = owner_h.face
		model.scale = Vector3.ONE * 0.85
		body.position.y = sin(m.time * 6.0) * 0.04
		body.rotation.x = 0.0
		return
	model.set_meta("kstate", "perch" if state == "shoulder" and heel_k < 0.5 else ("attack" if lunge_t > 0.0 else ""))
	# body language (KinPuppet): growl, point, whine, cheer...
	var pose_now: String = comp.pose if comp else ""
	if state == "reviving" and comp and pose_now == "":
		pose_now = "nudge"
	model.set_meta("pose", pose_now)
	model.set_meta("happy", pose_now in ["cheer", "beckon"])
	if state == "shoulder" and owner_h and owner_h.model and carry_style() == "mount" and not owner_h.gliding:
		_render_mount(delta, body)
		return
	if state == "shoulder" and owner_h and owner_h.model and heel_k > 0.0 and heel_pos != Vector3.INF:
		_render_heel(delta, alpha, body)
		return
	if state == "shoulder" and owner_h and owner_h.model and carry_style() != "shoulder":
		# perched on the pack (or a mount curled up into a ball on your back while you glide)
		var torso: Node3D = owner_h.model.get_node("Rig/Torso")
		var ball := carry_style() == "mount"
		global_position = torso.global_transform * Vector3(0, 0.92 if not ball else 0.55, 0.3 if not ball else 0.36)
		model.rotation.y = owner_h.face
		model.scale = Vector3.ONE * lerpf(0.75, 0.62 if not ball else 0.42, settle) * minf(float(model.get_meta("evo_scale", 1.0)), 1.2)
		body.position.y = absf(sin(hop_ph * 0.5)) * 0.03
		body.rotation = Vector3(0.0, 0.0, sin(m.time * 2.0) * 0.05) if not ball else Vector3(0.9, 0.0, 0.0)
		return
	if state == "shoulder" and owner_h and owner_h.model:
		var sh: Node3D = owner_h.model.get_node("Rig/Torso/Shoulder")
		global_position = sh.global_position
		model.rotation.y = owner_h.face
		model.scale = Vector3.ONE * lerpf(0.75, 0.55, settle) * minf(float(model.get_meta("evo_scale", 1.0)), 1.2)
		body.position.y = absf(sin(hop_ph * 0.5)) * 0.03
		# now and then it peeks out past its hunter's head, or nuzzles in against it
		var nz := fmod(m.time + float(absi(nid.hash()) % 97), 9.0)
		var peek := smoothstep(0.0, 0.3, nz) * (1.0 - smoothstep(1.1, 1.5, nz))
		var nuz := smoothstep(4.5, 4.8, nz) * (1.0 - smoothstep(5.8, 6.2, nz))
		body.rotation.x = 0.0
		body.rotation.y = peek * 0.7
		body.rotation.z = -nuz * 0.35 + sin(m.time * 9.0) * 0.06 * nuz
		if comp and comp.look != Vector3.INF:
			# turned on your shoulder toward what it's on about
			var ld := Vector2(comp.look.x - global_position.x, comp.look.z - global_position.z)
			if ld.length() > 0.4:
				body.rotation.y = clampf(angle_difference(model.rotation.y, atan2(-ld.x, -ld.y)), -1.6, 1.6)
		if comp and comp.pose == "cheer":
			body.position.y += absf(sin(m.time * 11.0)) * 0.12
		return
	var gs := 1.0
	model.scale = Vector3.ONE * 0.95 * float(model.get_meta("evo_scale", 1.0)) * gs
	model.rotation.y = face
	var moving := Vector2(vel.x, vel.z).length() > 0.5
	body.position.y = absf(sin(hop_ph)) * (0.14 if moving else 0.03) + (0.12 if lunge_t > 0.0 else 0.0)
	var sq := squash
	body.scale = Vector3(1.0 + sq * 0.4, 1.0 - sq * 0.45, 1.0 + sq * 0.4)
	model.set_meta("dazed", state in ["fainted", "dazed"] or stun_t > 0.0)
	if state in ["fainted", "dazed"]:
		body.rotation.z = lerpf(body.rotation.z, 1.4 if state == "fainted" else 0.0, delta * 6.0)
		body.rotation.y += delta * (4.0 if state == "dazed" else 0.0)
	else:
		body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 8.0)
		body.rotation.y = lerpf(body.rotation.y, 0.0, delta * 8.0)
		body.rotation.x = -0.4 if lunge_t > 0.0 else 0.0
	if state == "flying" and not fly.get("rush", false):
		body.rotation.x += delta * 14.0
	if state in ["active", "reviving"]:
		_render_attention(delta, body)

## Down at its hunter's heel (or hovering at their flank, for a percher): the hop down from the
## shoulder and back up is the blend between the two spots, with an arc.
func _render_heel(delta: float, alpha: float, body: Node3D) -> void:
	var o := owner_h
	var perch := carry_style() == "perch"
	var top: Vector3
	var top_s: float
	if perch:
		var torso: Node3D = o.model.get_node("Rig/Torso")
		top = torso.global_transform * Vector3(0, 0.92, 0.3)
		top_s = 0.62
	else:
		top = (o.model.get_node("Rig/Torso/Shoulder") as Node3D).global_position
		top_s = 0.55
	var hp := heel_prev.lerp(heel_pos, alpha) if heel_prev != Vector3.INF else heel_pos
	var low := hp + Vector3(0, 1.1 if perch else 0.0, 0)
	# a little show-and-tell for the tutorial: a dash, a jump, a hop
	if comp and comp.demo.size() > 0:
		var dk := clampf(float(comp.demo["t"]) / 0.9, 0.0, 1.0)
		var dd: Vector2 = comp.demo.get("dir", Vector2(0, -1))
		match String(comp.demo["kind"]):
			"dash":
				var sd: Vector2 = Vector2(-dd.y, dd.x) * comp.side
				low += Vector3(sd.x, 0, sd.y) * sin(dk * PI) * 2.2
				if dk < 0.1 and m.fx: m.fx.dust(hp, 4)
			"jump":
				low += Vector3(dd.x, 0, dd.y) * sin(dk * PI) * 1.2 + Vector3(0, sin(dk * PI) * 1.8, 0)
			"hop":
				low += Vector3(0, absf(sin(dk * PI * 2.0)) * 0.45, 0)
	var hk := heel_k
	global_position = top.lerp(low, hk) + Vector3(0, sin(hk * PI) * 0.7, 0)
	model.rotation.y = lerp_angle(o.face, heel_face, hk)
	var evo := float(model.get_meta("evo_scale", 1.0))
	model.scale = Vector3.ONE * lerpf(top_s * minf(evo, 1.2), 0.95 * evo, hk)
	if heel_moving:
		hop_ph += delta * 6.0
	body.position.y = absf(sin(hop_ph)) * (0.12 if heel_moving else 0.0)
	body.rotation.x = 0.0
	body.rotation.z = lerpf(body.rotation.z, 0.0, minf(1.0, delta * 8.0))
	body.rotation.y = 0.0
	_render_attention(delta, body)

## Where its head is: turned toward what it's calling out (or what you're aiming at), bouncing
## when it cheers, pulled back in a flinch.
func _render_attention(delta: float, body: Node3D) -> void:
	if comp == null:
		return
	var lk: Vector3 = comp.look
	if lk == Vector3.INF and owner_h and owner_h.inp and state == "shoulder":
		lk = owner_h.inp.get("aim", Vector3.INF)
	if lk != Vector3.INF:
		var ld := Vector2(lk.x - global_position.x, lk.z - global_position.z)
		if ld.length() > 0.4:
			var want := clampf(angle_difference(model.rotation.y, atan2(-ld.x, -ld.y)), -1.3, 1.3)
			body.rotation.y = lerp_angle(body.rotation.y, want, minf(1.0, delta * 10.0))
	match comp.pose:
		"cheer":
			body.position.y += absf(sin(m.time * 11.0)) * 0.22
		"flinch":
			body.position.y += 0.06
			body.rotation.x = -0.35
		"growl", "guard":
			body.rotation.x = 0.12
		"point", "alert":
			body.rotation.x = -0.15

## How high the rider sits on a mount (the hunter's model is raised this much).
func ride_height() -> float:
	return 0.42 * _mount_scale()

func _mount_scale() -> float:
	if giant.is_empty():
		return 1.0
	var grow_k := clampf((m.time - float(giant.get("t0", m.time))) / 0.35, 0.0, 1.0)
	return lerpf(1.0, float(giant["scale"]), grow_k)

## Ridden: under its hunter, turning with them, trotting when they run. Merged it's giant.
func _render_mount(delta: float, body: Node3D) -> void:
	var h: Hunter = owner_h
	global_position = h.position
	model.rotation.y = h.face
	var gs := _mount_scale()
	model.scale = Vector3.ONE * 1.05 * gs * minf(float(model.get_meta("evo_scale", 1.0)), 1.2)
	var moving := Vector2(h.vel.x, h.vel.z).length() > 0.5 and h.grounded
	hop_ph += delta * (6.0 if moving else 0.0)
	body.position.y = absf(sin(hop_ph)) * (0.06 if moving else 0.0)
	body.rotation = Vector3(-0.08 if moving else 0.0, 0.0, 0.0)
	if ring:
		ring.visible = false

func _exit_tree() -> void:
	if shell_fx and is_instance_valid(shell_fx):
		shell_fx.queue_free()
