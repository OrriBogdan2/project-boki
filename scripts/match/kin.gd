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
var state := "shoulder"           # shoulder | flying | active | returning | flying_home | downed | reviving | wild | dazed | bench | fused | away
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
## Where you threw it: it holds that spot (guarding it) until there's a reason to come back
## (you recall it, you go out of leash range, you glide off, it gets hurt). INF when not holding.
var hold_at := Vector3.INF
var cmd := "follow"               # its standing order (KinFollow): follow | guard | chase | return. State "shoulder" is "return" or a short traversal carry
var chase_target: Ent = null      # chase: what it sticks to
var rest_t := 0.0                 # s left resting after the owner's merge release (land_pumped): no C, orders, Sic
var disengaged := false           # an explicit Follow / Call back in a fight: it stays at your side until you attack, it or you are hit up close, or you Sic/Chase (KinFollow.disengage)
var path: Array = []              # its A* path (KinPath), recomputed on path_t
var path_goal := Vector2i.ZERO
var path_t := 0.0
var path_searches := 0          # A* searches it has run (a check counts them)
var stuck_t := 0.0                # seconds without progress (KinFollow.watch_stuck)
var steady_t := 0.0               # carried by traversal: seconds you have been steady on the ground
var gap_at := -9.0                # when need_carry last searched for a way across, and what it found
var gap_v := false
var rng := RandomNumberGenerator.new()    # its own seeded stream (init_kin): decisions never shift other systems' rolls
var marked := {}                  # foe nid -> m.time until which your hits on it fill the bond meter faster (Bond.on_hit)
var ignore_until := {}          # Ent -> m.time: targets it gave up on, left alone for a few seconds
var fly: Dictionary = {}          # thrown, leaping or rushing
var pend_skill := Vector3.INF     # ability to cast when it lands
var pend_slot := ""
var down_t := 0.0                 # downed: seconds until it comes round on its own (KinDowned)
var down_total := 0.0
var rescue_t := 0.0               # downed: rescue progress in seconds (KinDowned: run into it and carry it; a drop loses it)
var rescue_on := false            # downed: its owner is carrying it in their arms right now
var regen_quiet := 0.0             # seconds since it last lost health (KinRegen)
var regen_hp := 0.0               # its health at the end of the last step (KinRegen)
var regen_fx := 0.0               # countdown to the next healing mote (KinRegen)
var mending := false              # KinRegen is healing it right now (the HUD pulses its bar)
var rescue_block := 0.0           # downed: seconds before a rescue can start again (after a drop)
var down_void := false            # downed: it fell into the abyss, only the timer brings it back
var last_safe := Vector3.INF      # the last solid ground it stood on, where a fall marks it
var beacon: MeshInstance3D = null # the downed marker pillar (KinDowned.render)
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
var catch_prog := 0.0             # (net) 5.0 once a client has asked the host to take it (Match._catch)
var scan_by: Hunter = null        # who is scanning it right now: its daze timer waits (Capture)
var scan_at := -9.0               # when that was last confirmed (a scan whose hunter vanished lets go after a few seconds)
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
var comp: KinCompanion = null     # the teammate side: callouts, caring, where it walks (owned kin only)
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
	state = "active" if owner_h else "wild"       # a Boki walks beside you from the start (KinFollow); the shoulder is the Return order
	settle = 1.0
	rng.seed = hash(m.seed_val) * 31 + absi(id.hash())
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

## On you by order (Return), settled in: its carry passives are on. A Boki out beside you, or carried only
## over a glide or a drop, gives nothing (docs/decisions/0002).
func carried() -> bool:
	return not dead and state == "shoulder" and settle >= 1.0 and cmd == "return"

## Walking at your side under the Follow order, close enough to count as "with you" (the death-box rules).
func with_owner() -> bool:
	return state == "active" and cmd == "follow" and owner_h != null and flat_dist(owner_h) < 6.0

## Putting it on you by order, settled (the Return order; tools and setups use this).
func stow() -> void:
	cmd = "return"; state = "shoulder"; settle = 1.0; fly = {}; target = null; hold_at = Vector3.INF; chase_target = null
	if owner_h:
		pos = owner_h.pos + Vector3(0, 1.5, 0); prev = pos

## Ability strength: treats and care, plus its level growth (capped by tier).
func ability_power() -> float:
	return power * (1.0 + grow)

## Is this slot unlocked this run? (Its abilities are locked until a skill point opens the kin slot.)
func slot_open(_slot: String) -> bool:
	# with an archetype the E slot is the archetype's; the kin's own ability (C) has only its cooldown
	return owner_h == null or owner_h.ak != null or int(owner_h.slot_lv.get("kin", 0)) > 0

## Can its abilities and ultimate be used right now?
func ready_to_fight() -> bool:
	return not dead and rest_t <= 0.0 and state not in ["downed", "reviving", "bench", "wild", "dazed", "away"]

## Resting after the merge ultimate (docs/decisions/0004)?
func resting() -> bool:
	return rest_t > 0.0 and not dead

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
	if state == "fused" and owner_h != null and KinMerge.in_form(owner_h):
		return          # (inside you: it says nothing)
	if bark_cd > 0.0 and cat not in ["refuse", "hesitate", "revive", "callout"]:
		return
	bark_cd = 3.0
	var txt := KinVoice.line(self, cat, extra)
	if txt != "":
		m.kin_bark(self, txt, cat)

# ------------------------------------------------------------------ owner commands
func throw_to(p: Vector3, slot := "") -> void:
	if dead or hesitate_t > 0.0 or throw_cd > 0.0 or rest_t > 0.0:
		return
	if state == "active":
		if slot == "":
			_order_sic(p)       # out beside you: it leaps at the spot
		return
	if state != "shoulder" or settle < 0.35:
		return
	if slot != "":
		pend_skill = p
		pend_slot = slot
	_order_sic(p, true)

## Sic: after the Boki's own verdict (consider_throw). In a fight it never refuses: a short hesitation and a bark.
func _order_sic(p: Vector3, from_shoulder := false) -> void:
	var verdict := consider_throw(p) if owner_h.is_local() or rng.randf() < 0.3 else "go"
	if verdict == "refuse" and KinFollow.in_combat(self, p):
		verdict = "hesitate"
	if verdict == "refuse":
		bark("refuse")
		m.sfx("kin_unsure", owner_h.pos, -2.0, Unique.voice(rec))
		note("refused", "refused to jump into a fight that looked too dangerous", -1.0)
		pend_slot = ""; pend_skill = Vector3.INF
		return
	if verdict == "hesitate":
		hesitate_t = float(KinFollow.rules()["hesitate_s"])
		hesitate_to = p
		if trust < 60.0 or not owner_h.is_local():
			bark("hesitate")
		m.sfx("kin_unsure", owner_h.pos, -4.0, Unique.voice(rec))
		return
	if from_shoulder:
		_launch(p)
	else:
		KinFollow.sic(self, p)

func _launch(p: Vector3) -> void:
	st_throws += 1
	disengaged = false
	var dive := carry_style() == "perch"
	# a perched kin is thrown as a dive: up off your pack, then straight down onto the spot
	var start := owner_h.pos + Vector3(0, 3.4 if dive else 1.5, 0)
	var dist := Vector2(p.x - start.x, p.z - start.z).length()
	var maxd := float(KinCommand.rules()["throw_range_dive" if dive else "throw_range"])
	var d2 := Vector2(p.x - start.x, p.z - start.z)
	if dist > maxd:
		d2 = d2.normalized() * maxd
	var tgt := Vector3(start.x + d2.x, 0.0, start.z + d2.y)
	var g: float = m.world.ground_at(tgt.x, tgt.z)
	tgt.y = g if g > World.VOID + 1.0 else owner_h.pos.y
	var dur := clampf(d2.length() / (24.0 if dive else 16.0), 0.18, 0.55)
	teleport(start)
	fly = {"from": start, "to": tgt, "t": 0.0, "dur": dur, "hit": {}, "dive": dive, "charge": carry_style() == "mount"}
	state = "flying"
	settle = 0.0
	if cmd == "return":
		cmd = "follow"        # sent out from your shoulder: it is out beside you now
	hold_at = tgt if cmd == "guard" else Vector3.INF
	last_safe = owner_h.pos
	m.sfx("throw", owner_h.pos, 0.0)
	KinNet.event(m, "throw", self, tgt)
	CombatBus.kin_thrown.emit(self, owner_h)
	if danger_at(tgt) > 1.2 and hp < max_hp * 0.4:
		note("reckless", "was thrown into danger while hurt", -2.0)
	if randf() < 0.35:
		bark("throw")

## Call back: it leaps to your side (or onto you under the Return order) and hits what is on its path.
## It can't be sent again for a moment.
func recall() -> void:
	if state in ["active", "flying", "returning"] and not fly.get("leap", false) and not fly.get("rush", false):
		if state == "active" and t("temper") > 0.72 and target and target.hp < target.max_hp * 0.3 and rng.randf() < 0.6:
			bark("ignore")
			hesitate_t = 0.6
			hesitate_to = Vector3.INF
			return
		fly = {}
		if cmd == "return":
			KinFollow.leap(self, owner_h.pos + Vector3(0, 1.5, 0), "shoulder", true)
		else:
			KinFollow.leap(self, KinFollow.side_spot(self), "side", true)
		throw_cd = float(Content.rules("kin_ai").get("recall_cooldown", 1.0))
		hold_at = Vector3.INF
		if cmd == "guard" or cmd == "chase":
			cmd = "follow"; chase_target = null
		if cmd == "follow":
			KinFollow.disengage(self)       # Call back in a fight: it stays with you
		m.sfx("recall", pos, -6.0)
		KinNet.event(m, "recall", self)
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
		cmd = "return"         # the giant form is ridden: carried() and mounted() need the Return order
		chase_target = null
		hold_at = Vector3.INF
		settle = 1.0
		giant = {"scale": 1.8, "t0": m.time}
		m.sfx("boom", owner_h.pos, 0.0, 0.6)
	else:
		state = "fused"
		teleport(owner_h.pos + Vector3(0, 1.0, 0))

## R with the Boki out: it leaps back to you (hitting what is in its way) and the merge starts when it
## lands on your shoulder, mid-air. Returns false if it can't (it is busy being something else).
func merge_leap() -> bool:
	if not state in ["active", "flying", "returning", "flying_home"] or owner_h == null:
		return false
	var to := owner_h.pos + Vector3(0, 1.5, 0)
	fly = {"from": pos, "to": to, "t": 0.0, "dur": clampf(flat_dist(owner_h) / 26.0, 0.2, 0.5), "hit": {}, "leap": true, "home": true, "cmd": true, "merge": true}
	state = "flying_home"
	hold_at = Vector3.INF
	target = null
	m.sfx("recall", pos, -4.0)
	KinNet.event(m, "merge_leap", self)
	return true

## KinMerge ends it: back to riding with you, ready to throw again straight away.
func merge_out() -> void:
	if not giant.is_empty():
		giant = {}
		m.fx.burst(pos + Vector3(0, 0.6, 0), sp["color"], 20, 4.0)
	if state == "fused" and owner_h and not owner_h.out:
		_hop_on()
		settle = 1.0
		m.fx.burst(pos, sp["color"], 16, 3.0)

## The merge ended with its ultimate: the Boki lands beside you pumped, following, and rests for `secs`
## (no C, no Sic, no orders until it is over; its carried bonuses still apply).
func land_pumped(secs: float) -> void:
	if dead or owner_h == null:
		return
	giant = {}
	disengaged = false
	if state == "fused":
		merge_pop()
	rest_t = secs
	m.fx.burst(pos + Vector3(0, 1.0, 0), sp["color"], 22, 4.0)
	m.fx.ring(pos, 1.6, Color(sp["color"], 0.9), 0.35)
	m.sfx("kin_happy", pos, -4.0, Unique.voice(rec))
	KinNet.event(m, "rest", self, owner_h.pos, "%.1f" % secs)
	if owner_h.is_local():
		KinCommand.say(owner_h, "%s is pumped: back in %ds" % [rec.get("name", "Your Boki"), int(ceil(secs))], sp["color"])

## A merge with a form ended: the Boki springs out beside you, following (not downed, never a shoulder hop).
func merge_pop() -> void:
	if state != "fused" or owner_h == null or dead:
		return
	teleport(owner_h.pos + Vector3(0, 1.0, 0))
	cmd = "follow"
	hold_at = Vector3.INF
	target = null
	fly = {}
	KinFollow.leap(self, KinFollow.side_spot(self), "side")

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
	state = "shoulder"
	settle = 0.2
	if owner_h:
		pos = owner_h.pos + Vector3(0, 1.5, 0); prev = pos
	if hp <= 0.0:
		go_down()

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
	var was_rest := rest_t > 0.0
	for k in ["atk_cd", "bark_cd", "lunge_t", "throw_cd", "haste_t", "rest_t"]:
		set(k, maxf(0.0, get(k) - dt))
	if was_rest and rest_t <= 0.0 and owner_h:
		m.fx.ring(owner_h.pos, 1.6, Color(sp["color"], 0.8), 0.3)
		m.sfx("kin_happy", owner_h.pos, -8.0, Unique.voice(rec))
		KinCommand.say(owner_h, "%s is rested" % rec.get("name", "Your Boki"), sp["color"])
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			HealSfx.shield_end(self)
			shield = 0.0
	if runner:
		runner.tick(dt)
	if remote:
		if state != "shoulder":
			net_follow(dt)
		elif owner_h:
			pos = owner_h.pos + Vector3(0, 1.5, 0); prev = pos
		if comp:
			comp._decay(dt)
		return
	if hesitate_t > 0.0:
		hesitate_t -= dt
		if hesitate_t <= 0.0:
			var to := hesitate_to
			hesitate_to = Vector3.INF
			if to != Vector3.INF and state == "shoulder":
				_launch(to)
			elif to != Vector3.INF and state == "active":
				KinFollow.sic(self, to)
			elif state == "active":
				recall()
	KinFollow.ride_the_drop(self)      # on the ship or in the drop it rides on your shoulder
	think_t -= dt
	match state:
		"shoulder": _sim_shoulder(dt)
		"flying": _sim_fly(dt)
		"flying_home": _sim_fly_home(dt)
		"active": _sim_active(dt)
		"returning": _sim_return(dt)
		"downed": KinDowned.tick(self, dt)
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
	KinRegen.tick(self, dt)
	if comp:
		comp.tick(dt)

## Where its speech bubble sits.
func bubble_at() -> Vector3:
	if state == "shoulder" and owner_h:
		return owner_h.position + Vector3(0, 2.3, 0)
	return position + Vector3(0, 1.2, 0)

## Where it is for the eye (on you counts as your shoulder), for tests and callers that care.
func seen_pos() -> Vector3:
	if state == "shoulder" and owner_h:
		return owner_h.pos + Vector3(0, 1.5, 0)
	return pos

func _sim_shoulder(dt: float) -> void:
	if owner_h.out or owner_h.extracted:
		return
	pos = owner_h.pos + Vector3(0, 1.5, 0)
	prev = pos
	settle = minf(1.0, settle + dt / 1.0)
	if owner_h.downed:
		_consider_revive(dt)
	elif cmd != "return":
		KinFollow.carry_tick(self, dt)       # carried over a glide or a drop: down again once you are steady

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
				if owner_h and owner_h.is_local():
					m.freeze_frame(0.06)
				target = f
	if k >= 1.0:
		var land: Array = fly.get("land", [])
		var lctx: Dictionary = fly.get("ctx", {})
		var rush_end: Array = fly["e"].get("on_end", []) if rush else []
		var kx_land = fly.get("kx_land", null)
		var kx_end = fly["e"].get("kx_end", null) if rush else null
		var thrown: bool = not rush and not fly.get("leap", false)
		var charged: bool = fly.get("charge", false)
		var hit_set: Dictionary = fly.get("hit", {})
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
		if thrown:
			KinStrike.land(self, hit_set, charged)       # a thrown Boki staggers what it lands on (a charging mount harder)
		if not land.is_empty():
			m.fx.dust(pos, 14)
			var c2 := lctx.duplicate(); c2["at"] = pos
			Effects.run(land, self, c2)
		if not rush_end.is_empty():
			var c3 := lctx.duplicate(); c3["at"] = pos
			Effects.run(rush_end, self, c3)
		if kx_land is Callable:
			m.fx.dust(pos, 14)
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
	var side: bool = fly.get("dest", "shoulder") == "side"
	fly["t"] += dt
	if side:
		fly["to"] = KinFollow.side_spot(self)
	else:
		fly["to"] = owner_h.pos + Vector3(0, 1.5, 0)
	var k := clampf(fly["t"] / fly["dur"], 0.0, 1.0)
	var was := pos
	pos = (fly["from"] as Vector3).lerp(fly["to"], k) + Vector3(0, sin(k * PI) * float(fly.get("height", 1.4)), 0)
	if fly.get("cmd", false):
		KinStrike.sweep(self, was, pos)       # a commanded leap hits everything on its path
		if fly.is_empty():
			return
	if k >= 1.0:
		if side:
			KinFollow.land_side(self)
			return
		var merge_now: bool = fly.get("merge", false)
		_hop_on()
		if merge_now and not KinMerge.cast(owner_h):
			owner_h.m.fx.burst(pos, sp["color"], 8, 2.0)     # (the merge was lost on the way: it just lands)

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
	if disengaged and not KinFollow.in_combat(self, pos):
		disengaged = false          # the fight is over: the next one starts engaged again
	if cmd == "return" and owner_h != null:
		KinFollow.set_cmd(self, "return", null)       # Return was ordered while it was in the air: it lands, then goes onto you
		return
	var guard: Ent = _wisp_threat() if owner_h and owner_h.downed else null
	if guard:
		# someone's come to stomp or execute your hunter: the kin goes for them first
		target = guard
	elif owner_h and owner_h.downed:
		_consider_revive(dt)
		if state != "active":
			return
	# a hurt, cautious Boki stays at your side and sits the fight out
	var hang_back: bool = owner_h != null and hp < max_hp * brain.retreat_frac()
	if hang_back:
		if bark_cd <= 0.0:
			bark("scared")
		target = null
	if chase_target != null and (not is_instance_valid(chase_target) or chase_target.dead or not chase_target.hittable()):
		chase_target = null
		if cmd == "chase":
			cmd = "follow"
	if owner_h and flat_dist(owner_h) > (brain.leash() if cmd == "follow" else KinFollow.leash(self)):
		state = "returning"      # wandered off after a fight: run back (a hop when it cannot walk)
		return
	if guard == null and not hang_back:
		if KinFollow.is_disengaged(self):
			target = null          # told to come back: it does not pick a fight on its own until a reason ends that
		elif cmd == "chase" and chase_target != null:
			target = chase_target
		elif target == null or target.dead or not target.hittable() or (target is Hunter and target.downed) or flat_dist(target) > brain.chase_range() + 3.0 or rng.randf() < dt * 0.5:
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
			wish = KinFollow.steer(self, target.pos, dt, spd, false)
			# chasing something it can't get to (up a ledge, round a wall): give up on it for a while
			# and come back to you, instead of standing there pressing into the wall
			chase_stall = chase_stall + dt if Vector2(vel.x, vel.z).length() < spd * 0.35 and spd > 0.0 else 0.0
			if chase_stall > 0.8:
				chase_stall = 0.0
				ignore_until[target] = m.time + 5.0
				target = null
				wish = Vector2.ZERO
		if target and d < reach and atk_cd <= 0.0 and absf(target.pos.y - pos.y) < 1.5:
			atk_cd = 0.95
			lunge_t = 0.15
			vel.x += to.normalized().x * 5.0; vel.z += to.normalized().y * 5.0
			var tp := target.pos
			target.hurt(dmg * power, self, {"kb": to.normalized() * 2.0, "src": "kin", "tags": ["kin", "melee"]})
			m.sfx("kinhit", pos, -6.0, 1.0)
			melee_n += 1
			fire_trigger("on_hit", {"at": tp})
	elif owner_h:
		# no fight for it: back to your side like a teammate (or its guard spot); it hops onto you if you glide off
		wish = KinFollow.idle(self, dt, spd)
		if state != "active":
			return
		if root_t > 0.0 or stun_t > 0.0:
			wish = Vector2.ZERO
	_ground_move(wish, dt)
	KinFollow.watch_stuck(self, wish, dt)

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
	if grounded and not m.world.is_void(pos.x, pos.z):
		last_safe = pos
	if hv.length() > 0.3:
		face = lerp_angle(face, atan2(-hv.x, -hv.y), minf(1.0, dt * 12.0))

func _sim_return(dt: float) -> void:
	if owner_h == null or owner_h.out:
		return
	var goal: Vector3 = owner_h.pos if cmd == "return" else KinFollow.side_spot(self)
	var to := Vector2(goal.x - pos.x, goal.z - pos.z)
	if to.length() < (1.2 if cmd == "return" else 2.2):
		if cmd == "return":
			_hop_on()
		else:
			state = "active"
		return
	if to.length() > 9.0:
		KinFollow.hop_back(self)        # well off: a visible leap rather than an amble
		return
	var wish := KinFollow.steer(self, goal, dt, speed * 1.25, false)
	_ground_move(wish, dt)
	KinFollow.watch_stuck(self, wish, dt)

func _hop_on() -> void:
	hold_at = Vector3.INF
	state = "shoulder"
	settle = 0.0
	target = null
	fly = {}
	pos = owner_h.pos + Vector3(0, 1.5, 0)

func go_down(fell := false) -> void:
	_end_merge("downed")
	KinDowned.begin(self, fell)
	if owner_h:
		note("fainted", "went down in a fight" if not fell else "fell off the island", -0.5)
	m.on_kin_down(self)

func _on_zero(_by: Ent, _opts: Dictionary) -> void:
	if state in ["dazed", "downed"]:
		hp = maxf(hp, 1.0)
		return
	if is_wild():
		hp = 1.0
		_daze()
		return
	go_down()

func fall_out() -> void:
	if is_wild():
		dead = true
		m.on_fell(self)
		return
	go_down(true)

func _consider_revive(dt: float) -> void:
	if state == "downed" or hp <= 0.0:
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
	if scan_by != null and (not is_instance_valid(scan_by) or m.time - scan_at > Capture.HOLD_OVER):
		scan_by = null
	if scan_by == null:
		dazed_t -= dt         # (it stays dazed while someone is scanning it)
	_ground_move(Vector2.ZERO, dt)
	hp = minf(max_hp * 0.25, hp + dt * 0.5)
	KinLoss.tick_guard(self, dt)
	if dazed_t <= 0.0:
		state = "wild"
		hp = max_hp * 0.45
		catch_prog = 0.0

func hurt(d: float, by: Ent, opts := {}) -> float:
	if state in ["dazed", "bench", "fused", "downed"]:
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
	visible = not dead and state != "bench" and state != "away" and not (state == "downed" and down_void) and not (owner_h and (owner_h.out or owner_h.extracted or owner_h.riding) and not KinLoss.guarding(self)) and not KinMerge.inside(self)
	KinDowned.render(self, delta)
	if not model:
		return
	var body: Node3D = model.get_node("Body")
	var shell: Node3D = model.get_node_or_null("Body/Shell")
	hop_ph += delta * (9.0 if Vector2(vel.x, vel.z).length() > 0.5 else 3.0)
	var out_now := state in ["active", "flying", "returning", "reviving", "flying_home", "downed"]
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
		if MergeXform.boki_pose(self):
			return           # (the transformation: it flies in on a spiral)
		# wrapped around its hunter's back as armor
		global_position = owner_h.model.global_position + Vector3(0, 1.05, 0) + Vector3(sin(owner_h.face), 0, cos(owner_h.face)) * 0.32
		model.rotation.y = owner_h.face
		model.scale = Vector3.ONE * 0.85
		body.position.y = sin(m.time * 6.0) * 0.04
		body.rotation.x = 0.0
		return
	model.set_meta("kstate", "perch" if state == "shoulder" else ("attack" if lunge_t > 0.0 else ""))
	# body language (KinPuppet): growl, point, whine, cheer...
	var pose_now: String = comp.pose if comp else ""
	if state == "reviving" and comp and pose_now == "":
		pose_now = "nudge"
	model.set_meta("pose", pose_now)
	model.set_meta("happy", pose_now in ["cheer", "beckon"])
	if state == "shoulder" and owner_h and owner_h.model and carry_style() == "mount" and not owner_h.gliding and (cmd == "return" or not giant.is_empty()):
		_render_mount(delta, body)       # you ride it (the Return order, or merged); carried over a glide it curls up on your back below
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
	model.set_meta("dazed", state in ["downed", "dazed"] or stun_t > 0.0)
	if state in ["downed", "dazed"]:
		body.rotation.z = lerpf(body.rotation.z, 1.4 if state == "downed" else 0.0, delta * 6.0)
		body.rotation.y += delta * (4.0 if state == "dazed" else 0.0)
	else:
		body.rotation.z = lerpf(body.rotation.z, 0.0, delta * 8.0)
		body.rotation.y = lerpf(body.rotation.y, 0.0, delta * 8.0)
		body.rotation.x = -0.4 if lunge_t > 0.0 else 0.0
	if state == "flying" and not fly.get("rush", false):
		body.rotation.x += delta * 14.0
	if state in ["active", "reviving"]:
		_render_attention(delta, body)
	_render_demo()
	Capture.dissolve(self)
	KinDowned.scoop_pose(self)

## A little show-and-tell for the tutorial: a dash, a jump, a hop (KinCompanion.demo).
func _render_demo() -> void:
	if comp == null or comp.demo.size() == 0 or state != "active":
		return
	var dk := clampf(float(comp.demo["t"]) / 0.9, 0.0, 1.0)
	var dd: Vector2 = comp.demo.get("dir", Vector2(0, -1))
	match String(comp.demo["kind"]):
		"dash":
			var sd: Vector2 = Vector2(-dd.y, dd.x) * comp.side
			global_position += Vector3(sd.x, 0, sd.y) * sin(dk * PI) * 2.2
			if dk < 0.1 and m.fx: m.fx.dust(pos, 4)
		"jump":
			global_position += Vector3(dd.x, 0, dd.y) * sin(dk * PI) * 1.2 + Vector3(0, sin(dk * PI) * 1.8, 0)
		"hop":
			global_position += Vector3(0, absf(sin(dk * PI * 2.0)) * 0.45, 0)

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
	if beacon and is_instance_valid(beacon):
		beacon.queue_free()
