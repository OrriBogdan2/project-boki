class_name BotRescue
extends RefCounted
## How bots play downed teammates the way a fair player does (Bot._revive_plan and Bot.think call in):
## no revive inside an enemy area, give up when under fire and low, and a Meeko bot (TenderKit) that
## has shouldered a wisp walks it away from the fight and sets it down once it is calm.

const AOE_MARGIN := 1.0       # m: stay this far outside an enemy area's rim
const FIRE_T := 1.2           # s: a foe hit on us this recently means we are under fire
const GIVE_UP_FRAC := 0.4     # share of armor + health: under fire below this, the bot abandons the revive
const GIVE_UP_T := 5.0        # s: how long it stays off the revive after giving up
const CALM_DIST := 14.0       # m: a carrier with no foe this close sets the wisp down to revive it

## True when `at` is inside an area an enemy squad put down (a Well, a hero or Boki field).
static func in_hostile_aoe(m: Match, h: Hunter, at: Vector3) -> bool:
	for z in m.zones:
		if z["kind"] == "well" and z["team"] != h.team and _flat(at, z["pos"]) < float(z["r"]) + AOE_MARGIN:
			return true
	if m.fields:
		for f in m.fields.list:
			if int(f["team"]) != h.team and _flat(at, f["at"]) < float(f["r"]) + AOE_MARGIN:
				return true
	return false

## The foe whose fire just hit this bot, or null.
static func shooter(m: Match, h: Hunter) -> Hunter:
	if m.time - h.hurt_at > FIRE_T:
		return null
	var by: Ent = h.last_hit_by
	if by is Kin and (by as Kin).owner_h:
		by = (by as Kin).owner_h
	if by is Hunter and by.team != h.team and by.targetable():
		return by
	return null

## Whether this bot should go for the downed squadmate `o` right now.
static func revive_ok(m: Match, h: Hunter, o: Hunter) -> bool:
	if CareUtil.is_carried(o) or float(h.ai.get("rv_off", -1.0)) > m.time:
		return false
	return not in_hostile_aoe(m, h, o.pos)

## Under fire and low: drop the revive for a while. True when the bot just gave up (or already has).
static func gives_up(m: Match, h: Hunter) -> bool:
	if shooter(m, h) != null and h.hp + h.armor < (h.max_hp + h.max_armor) * GIVE_UP_FRAC:
		h.ai["rv_off"] = m.time + GIVE_UP_T
	return float(h.ai.get("rv_off", -1.0)) > m.time

## A Meeko bot carrying wisps: the way to walk (away from the nearest foe), or ZERO. Once no foe is
## within CALM_DIST it holds the set-down key so the wisp can be revived on the spot.
static func carry_move(m: Match, h: Hunter) -> Vector2:
	if not h.ak is TenderKit:
		return Vector2.ZERO
	var carrying := not CareUtil.carried_of(m, h).is_empty()
	var near: Hunter = null
	var nd := CALM_DIST
	if carrying:
		for f in m.foes_of(h.team):
			if f is Hunter and f.targetable() and h.flat_dist(f) < nd:
				near = f
				nd = h.flat_dist(f)
	h.inp[TenderKit.SETDOWN] = carrying and near == null
	return -h.dir_to(near) if near else Vector2.ZERO

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
