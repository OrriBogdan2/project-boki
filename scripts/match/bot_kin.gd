class_name BotKin
extends RefCounted
## How bots use the Boki commands (docs/decisions/0001, 0002), with the same rules as the player: Sic it at
## the target (guard a stationary monster), cast C from where the Boki stands, Return it when either is
## hurt, Call it back when it is far, merge (R) when a fight is worth it, and run into
## a downed Boki to pick it up.

const C_REACH := 7.0          # m: a C cast without a stated range
const THROW_CHANCE := 0.3     # chance per look to throw at something that isn't a hunter or a brute
const MERGE_NEAR := 7.0       # m: a rival this close is worth the merge
const LOW_HP := 0.3           # share of health: a bot or Boki below this goes back on the bot (Return)
const SUMMON_RANGE := 12.0    # m: a rival or brute this close is a fight the bot takes (Summon)
const SUMMON_MATE_R := 15.0   # m: a downed teammate this close calls the Boki out
const SUMMON_HP := 0.45       # share of health: below this the bot is losing, not fighting (no Summon)
const SUMMON_DELAY := 0.3     # s: a quick bot waits this long after the moment starts (easy: up to 5x)
const SUMMON_BASE := 0.5      # chance a bot with no ability skill presses it when the wait is up (skill 1: always)
const SUMMON_RETRY := 3.0     # s: before a bot that skipped the moment looks again
const SIC_REACH := 9.0       # m: how far a Sic can reach (Kin throw range)

## Called while the bot has a target: Return when it is low, Sic at the target, cast C, Call back.
static func fight(m: Match, h: Hunter, tgt: Ent, d: float, abil: float) -> void:
	var k: Kin = h.kin
	var a := h.ai
	if k == null or k.dead or k.resting():
		return          # (a drained Boki rests on you: nothing to throw or order)
	if float(a["throw_cd"]) > 0.0:
		return
	if randf() > abil:
		a["throw_cd"] = randf_range(1.5, 3.5)       # easier bots hold their Boki back more
		return
	var low: bool = h.hp < h.max_hp * LOW_HP or k.hp < k.max_hp * LOW_HP
	if k.state == "shoulder":
		if k.cmd == "return" and not low and d < 8.0 and (tgt is Hunter or (tgt is Mob and tgt.mkind == "brute") or randf() < THROW_CHANCE):
			# a stationary monster is worth guarding; a rival who moves is worth chasing
			if tgt is Mob:
				k.cmd = "guard"
			k.throw_to(Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z))
			a["throw_cd"] = randf_range(4, 8)
	elif k.state == "active":
		if low and KinCommand.can_recall(h) and k.cmd != "return":
			KinCommand.order(h, "return")             # hurt: back on you, safe, its carried bonuses on
			a["throw_cd"] = 3.0
		elif k.runner.is_ready("k1") and k.flat_dist(tgt) < C_REACH and randf() < 0.5:
			h.inp["aim"] = Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z)
			h.inp["kin_ab"] = true
			a["throw_cd"] = randf_range(1, 3)
		elif k.flat_dist(h) > 11.0 and KinCommand.can_recall(h):
			KinCommand.call_back(h)
			a["throw_cd"] = 2.0
		elif k.throw_cd <= 0.0 and k.flat_dist(tgt) > 3.0 and k.flat_dist(tgt) < SIC_REACH and (tgt is Hunter or randf() < THROW_CHANCE):
			k.throw_to(Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z))       # Sic
			a["throw_cd"] = randf_range(3, 6)

## The Summon key (the Boki rides as a wisp, KinSummon): press it on entering a fight the bot will take (a
## rival or a brute in range, health above SUMMON_HP) or when a teammate is downed close by. Never while
## fleeing or hexed, never on cooldown, never while the Boki is already out. Easy bots wait longer and skip
## the moment more often (abil is the bot's ability skill). Tutorial bots wait for a beat to set "summon_ok".
static func summon(m: Match, h: Hunter, tgt: Ent, abil: float, dt: float) -> void:
	var k: Kin = h.kin
	var a := h.ai
	var muted: bool = m.opts.get("tutorial", false) and not a.get("summon_ok", false)
	if k == null or k.summon == null or not k.wisp or k.summon.cd > 0.0 or muted:
		a["sum_wait"] = -1.0
		return
	if not _summon_moment(m, h, tgt):
		a["sum_wait"] = -1.0
		return
	if float(a.get("sum_wait", -1.0)) < 0.0:
		a["sum_wait"] = SUMMON_DELAY * (1.0 + (1.0 - abil) * 4.0) * randf_range(0.8, 1.3)
	a["sum_wait"] = float(a["sum_wait"]) - dt
	if float(a["sum_wait"]) > 0.0:
		return
	if randf() < SUMMON_BASE + (1.0 - SUMMON_BASE) * abil:
		KinSummon.press(h)
	a["sum_wait"] = SUMMON_RETRY

## A fight worth the Boki, and the bot is not running from it.
static func _summon_moment(m: Match, h: Hunter, tgt: Ent) -> bool:
	if h.downed or h.hp < h.max_hp * SUMMON_HP or Hex.active(h) or String(h.ai.get("goal_kind", "")) == "flee":
		return false
	if tgt and not tgt.dead and tgt.hittable() and h.flat_dist(tgt) < SUMMON_RANGE:
		if (tgt is Hunter and not tgt.downed) or (tgt is Mob and tgt.mkind == "brute"):
			return true
	return m.hunters.any(func(x: Hunter) -> bool: return x != h and x.team == h.team and x.downed and not x.out \
			and h.flat_dist(x) < SUMMON_MATE_R)

## The Merge, once the bond is full and a fight is worth it. With the Boki out it leaps back and merges.
static func merge(h: Hunter, tgt: Ent, d: float) -> void:
	var plan := KinMerge.plan(h)
	if plan in ["", "far", "rescue"] or tgt == null:
		return
	var worth: bool = (d < MERGE_NEAR and tgt is Hunter) or (d < 5.0 and tgt is Mob and (tgt as Mob).max_hp > 150.0) or (h.hp < h.max_hp * 0.4 and d < 9.0)
	if worth:
		h.inp["aim"] = Vector3(tgt.pos.x, tgt.pos.y, tgt.pos.z)
		h.inp["ult"] = true

## Out of a fight and the Boki is down where it fell: walk into it (unless it fell into the abyss).
static func rescue_goal(h: Hunter) -> Vector3:
	var k: Kin = h.kin
	if k == null or k.state != "downed" or k.down_void or h.downed:
		return Vector3.INF
	return k.pos if h.flat_dist(k) < 40.0 else Vector3.INF

## Out of a fight: a Boki that wandered off is called back, and a returned Boki comes out again once both are healthy.
static func upkeep(h: Hunter) -> void:
	var k: Kin = h.kin
	if k == null or k.dead or k.resting():
		return
	if k.state == "active" and k.flat_dist(h) > 6.0 and KinCommand.can_recall(h):
		k.recall()
	elif k.state == "shoulder" and k.cmd == "return" and h.hp > h.max_hp * 0.6 and k.hp > k.max_hp * 0.6 and float(h.ai.get("throw_cd", 0.0)) <= 0.0:
		KinCommand.order(h, "follow")
