class_name KinTactics
extends RefCounted
## How a kin fights on its own (its tactics; the chat side of its mind is KinBrain in home). Separate from the kin's body (kin.gd) and from its abilities
## (KinRunner, run by KinExec): the body asks the brain what to chase, where to stand and when to use an
## ability, and the brain reads the kin's personality to answer.
##
## Three combat traits, 0..1, mixed from the species' "ai" block and this kin's own traits:
##   aggression  chases further and uses attacking abilities more often
##   loyalty     sticks close, goes after whoever hurts you, saves you when you're in trouble
##   caution     backs off to your side when it's hurt
## The numbers that turn traits into distances live in content/rules/kin_ai.json.

var k: Kin
var aggression := 0.5
var loyalty := 0.5
var caution := 0.5
var style := ""
var think_t := 0.0
var rules: Dictionary = {}

func _init(kin: Kin) -> void:
	k = kin
	rules = Content.rules("kin_ai")
	refresh()

## Recomputed when the kin's traits change (they drift as it grows).
func refresh() -> void:
	var base: Dictionary = Data.KIN[k.species].get("ai", {})
	aggression = clampf(float(base.get("aggression", 0.5)) * 0.5 + (k.t("temper") * 0.5 + k.t("bravery") * 0.5) * 0.5, 0.0, 1.0)
	loyalty = clampf(float(base.get("loyalty", 0.5)) * 0.5 + k.t("loyalty") * 0.5, 0.0, 1.0)
	caution = clampf(float(base.get("caution", 0.5)) * 0.5 + (1.0 - k.t("bravery")) * 0.5, 0.0, 1.0)
	style = String(base.get("style", ""))

func _r(key: String, dflt: float) -> float:
	return float(rules.get(key, dflt))

## How far from itself it will go after a foe.
func chase_range() -> float:
	return _r("chase_base", 4.0) + aggression * _r("chase_per_aggression", 8.0)

## How far from you it will wander before coming back.
func leash() -> float:
	return maxf(5.0, _r("leash_base", 9.0) + aggression * _r("leash_per_aggression", 8.0) + loyalty * _r("leash_per_loyalty", -4.0))

## Below this share of its health it runs back to you.
func retreat_frac() -> float:
	return caution * _r("retreat_hp_per_caution", 0.6)

## Where it hangs around you when nothing's going on: loyal kin stay right by your side.
func idle_radius() -> float:
	return 1.4 + (1.0 - loyalty) * 2.6

func pick_target() -> Ent:
	var reach := chase_range()
	var own := k.owner_h
	var best: Ent = null
	var bs := -1e9
	var focus: Ent = KinFollow.owner_focus(k) if own else null       # what you are fighting
	var attacker: Ent = own.last_hit_by if own else null
	if attacker is Kin and (attacker as Kin).owner_h:
		attacker = attacker
	for f in k.m.foes_of(k.team):
		if f is Hunter and (f.downed or f.cloak_t > 0.0):
			continue
		if not f.hittable() or Shrubling.hidden(f):
			continue      # (a disguised Shrubling is not given away by its Boki)
		if float(k.ignore_until.get(f, -1.0)) > k.m.time:
			continue      # it gave up on this one a moment ago (couldn't reach it)
		var d := k.flat_dist(f)
		if d > reach:
			continue
		if not k.walkable_to(f.pos):
			continue
		var s := -d
		if f == attacker: s += 2.0 + loyalty * _r("guard_owner_per_loyalty", 4.0)
		if f == k.target: s += 1.5
		if f == focus: s += 3.0
		if f is Hunter: s += aggression * 1.5
		if own:
			s -= own.flat_dist(f) * loyalty * 0.25
		if f.stun_t > 0.0 or f.root_t > 0.0: s += 1.0     # finish what was set up
		if s > bs:
			bs = s; best = f
	return best

## Called a few times a second while the kin is out (or riding with you, for abilities that work
## on you). Uses abilities by itself when their cue (KinParts.CUES) fits:
##   k2, the auto active, is the kin's own: it always uses it when it sees the chance
##   k1, the Boki's own ability, when the cue fits; yours casts it only while it is out beside you or fighting
## Locked slots (run levels) are never cast. Event triggers (on_hit, on_throw...) fire elsewhere;
## on_low_hp is watched here.
func think_abilities(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = 0.35 + randf() * 0.25
	if k.runner == null or k.owner_h == null or k.owner_h.out or k.owner_h.downed:
		return
	_low_hp()
	for slot in ["k2", "k1"]:
		if not k.runner.is_ready(slot) or not k.slot_open(slot):
			continue
		var def := k.runner.def_of(slot)
		if def.cue == null:
			continue
		if slot == "k1" and k.owner_h.is_local() and k.state != "active":
			continue     # your Boki casts its own ability once it is out
		if slot == "k2" and (def.trigger == null or def.trigger.type != "auto"):
			continue
		if k.state in ["shoulder", "fused"] and def.from == "kin":
			continue     # kin-cast abilities wait until it's out in the fight
		var aim := cue_aim(def.cue)
		if aim == Vector3.INF:
			continue
		if k.use_ability(slot, aim, true):
			return

## on_low_hp triggers: once each time the owner (or the kin) dips below the line.
func _low_hp() -> void:
	for slot in ["k2", "k1"]:
		var def := k.runner.def_of(slot)
		if def == null or def.trigger == null or def.trigger.type != "on_low_hp":
			continue
		var who: Ent = k.owner_h if String(def.trigger.params.get("who", "owner")) == "owner" else k
		var low := who.hp < who.max_hp * float(def.trigger.params.get("below", 0.35))
		if not low:
			k.low_fired.erase(slot)
		elif not k.low_fired.has(slot) and k.fire_trigger("on_low_hp", {"at": who.pos}):
			k.low_fired[slot] = true

## Where the cue says to aim, or Vector3.INF if the moment isn't right.
func cue_aim(cue: PartSpec) -> Vector3:
	var own := k.owner_h
	var p := cue.params
	var offensive_rate := _r("auto_rate_base", 0.35) + aggression * _r("auto_rate_per_aggression", 0.6)
	match cue.type:
		"foe_in_range":
			if k.target and k.target.hittable() and k.flat_dist(k.target) < float(p["range"]) and randf() < offensive_rate:
				return k.target.pos
		"foes_clumped":
			if k.target and k.flat_dist(k.target) < float(p["range"]):
				var n := 0
				for f in k.m.foes_of(k.team):
					if f.flat_dist(k.target) < float(p["radius"]): n += 1
				if n >= int(p["count"]) and randf() < offensive_rate:
					return k.target.pos
		"owner_hurt":
			if own.hp < own.max_hp * float(p["below"]) and own.regen_wait > 0.0 and randf() < 0.4 + loyalty * 0.6:
				return own.pos
		"owner_under_fire":
			# a rival is shooting you: put something between you and them
			var att = own.last_hit_by
			if att is Kin and (att as Kin).owner_h: att = (att as Kin).owner_h
			if att is Hunter and att.team != own.team and k.m.time - own.hurt_at < 0.8 and own.flat_dist(att) > 3.0 and randf() < 0.45 + loyalty * 0.5:
				var d: Vector2 = own.dir_to(att)
				return own.pos + Vector3(d.x, 0, d.y) * 2.2
		"owner_falling":
			# the kin saves you from the abyss: loyal kin react faster
			if (own.below_lip or (own.over_void() and own.vel.y < -4.0 and not own.grounded)) and randf() < 0.35 + loyalty * 0.65:
				return own.pos
		"owner_fighting":
			if own.idle_fire < 1.5 and k.m.foes_of(k.team).any(func(f): return f.flat_dist(own) < 10.0) and randf() < float(p["chance"]) * (0.5 + aggression):
				return own.inp.get("aim", own.pos)
	return Vector3.INF
