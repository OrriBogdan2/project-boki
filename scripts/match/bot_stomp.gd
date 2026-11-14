class_name BotStomp
extends RefCounted
## How a bot plays the stomp (docs/BOT_KIT_USE.md "Stomps", DECISIONS 2026-11-11 "stomping"). A stomp
## pins the stomper for Stomp.TIME and a stun or knock on it saves the wisp, so:
##   safe()    a bot stomps a downed rival only with no standing enemy Hunter within punish_r() of it
##   rescue()  a bot whose teammate is being stomped spends its ready breaker on the stomper first
## rescue_r is in content/rules/bot_stomp.json. The breakers come from the kit data
## (content/archetypes/<id>.json, breakers()), never a per-Hunter list.

const RULES_PATH := "res://content/rules/bot_stomp.json"
const AIM_HOLD := 1.0         # s after the press the bot keeps aiming at the stomper (wind-up and flight)
static var _rules := {}

const CC_KEYS := ["stun", "knockup", "root", "grounded"]      # Stomp.breaks: Capture.controlled
const SLOT_KEY := {"rmb": "sec", "e": "sig"}      # kit slot -> bot input key (X waits on the bond meter: not used)
const TAP_HOLD := 0.3         # s: a slot whose press must be held longer than this is not a quick tap
const SLOW_WIND := 0.5        # s: a slot that winds up (windup) or spins (spin_t) this long lands too late
static var _breakers := {}
static var _punish_r := -1.0

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## The threat range: the longest reach of any hard CC in any kit's RMB or E, held or tapped (Lace's
## Heavy Shot pin, Meeko's Burrseed: 14 m). A rival on its feet this close can break a stomp.
static func punish_r() -> float:
	if _punish_r < 0.0:
		_punish_r = 0.0
		for a in Arch.ids():
			for slot in SLOT_KEY:
				var d: Dictionary = Arch.def(a).get(slot, {})
				for b in [d] + d.values().filter(func(v): return v is Dictionary):
					for c in CC_KEYS:
						if _num(b.get(c, 0.0)) > 0.0:
							_punish_r = maxf(_punish_r, _reach(b, d) + _num(b.get("radius", 0.0)))
	return _punish_r

## No enemy Hunter on its feet near the downed rival o: stomping it can't be punished.
static func safe(m: Match, h: Hunter, o: Hunter) -> bool:
	var r := punish_r()
	for e in m.hunters:
		if e != o and e.team != h.team and not e.downed and not e.out and e.flat_dist(o) < r:
			return false
	return true

## A teammate being stomped and our breaker ready: walk into its reach and press it on the stomper,
## then keep aiming at it for AIM_HOLD while the move winds up and flies. True while it has taken
## over the bot's step (Bot.think does nothing else then).
static func rescue(m: Match, h: Hunter) -> bool:
	var b: Dictionary = breaker(h.arch)
	if b.is_empty() or h.ak == null:
		return false
	var ready := _ready(h, b)
	var pressed := not ready and m.time - float(h.ai.get("break_at", -9.0)) < AIM_HOLD      # it went off
	if not pressed and not ready:
		return false
	var s := _stomper_on_mate(m, h)
	if s == null or h.flat_dist(s) > float(rules()["rescue_r"]):
		return false
	h.inp["aim"] = s.pos + Vector3(0, 0.9, 0)
	h.inp["aim_y"] = s.pos.y
	var d := h.flat_dist(s)
	h.inp["move"] = h.dir_to(s) if d > float(b["reach"]) and not pressed else Vector2.ZERO
	if not pressed and d <= float(b["reach"]) and m.world.los(h.pos, s.pos, h.pos.y + 0.95):
		h.inp[String(b["key"])] = true
		h.ai["break_at"] = m.time
	return true

static func _stomper_on_mate(m: Match, h: Hunter) -> Hunter:
	for o in m.hunters:
		if o != h and o.team == h.team and o.downed and not o.out and o.has_meta("stomped_by"):
			var s := o.get_meta("stomped_by") as Hunter
			if is_instance_valid(s) and not s.stomp.is_empty():
				return s
	return null

## The breaker's slot is unlocked and off cooldown (the kit's own cooldown timers).
static func _ready(h: Hunter, b: Dictionary) -> bool:
	if b["slot"] == "rmb":
		return int(h.slot_lv["sec"]) > 0 and h.ak.rmb_ready()
	return int(h.slot_lv["kin"]) > 0 and float(h.ak.cd["e"]) <= 0.0

## This Hunter's stomp breaker from its kit data, {} for none: the first of RMB, E (shortest cooldown
## wins) whose quick tap (hold up to TAP_HOLD, no SLOW_WIND wind-up) puts a hard CC (CC_KEYS) on a
## foe, at the slot's top level or one block down
## (deeper blocks are picks, like Gil's vials). Its reach, in metres from the stomper, is that block's
## range/reach plus half its radius, or of its core when only the core stuns (a radius alone: half
## of it). {key, slot, reach, cooldown, cc}.
static func breaker(arch: String) -> Dictionary:
	if not _breakers.has(arch):
		var best := {}
		var kit := Arch.def(arch)
		for slot in SLOT_KEY:
			var d: Dictionary = kit.get(slot, {})
			if d.is_empty() or float(d.get("hold", 0.0)) > TAP_HOLD \
					or maxf(_num(d.get("windup", 0.0)), _num(d.get("spin_t", 0.0))) >= SLOW_WIND:
				continue
			var b := _cc_block(d, false)
			for k in d:
				if b.is_empty() and d[k] is Dictionary and not k in ["variants", "sockets", "boost"]:
					b = _cc_block(d[k])
			if b.is_empty():
				continue
			var reach := _reach(b, d) + 0.5 * _num(b.get("core", b.get("radius", 0.0)))
			var cd := float(d.get("cooldown", 99.0))
			if reach > 0.0 and (best.is_empty() or cd < float(best["cooldown"])):
				best = {"key": SLOT_KEY[slot], "slot": slot, "reach": reach, "cooldown": cd, "cc": b["_cc"]}
		_breakers[arch] = best
	return _breakers[arch]

## The block itself if a tap lands its CC_KEYS entry (above zero), with "_cc" naming it; else {}. Not
## a tap: a charged hold (max_hold), a mode on its own cooldown, one tied to another variant ("on").
static func _cc_block(b: Dictionary, sub := true) -> Dictionary:
	if b.has("max_hold") or (sub and b.has("cooldown")) or String(b.get("on", "tap")) != "tap":
		return {}
	for c in CC_KEYS:
		if _num(b.get(c, 0.0)) > 0.0:
			var out := b.duplicate()
			out["_cc"] = c
			return out
	return {}

## The range or reach of block b, else of its slot d (0 for none).
static func _reach(b: Dictionary, d: Dictionary) -> float:
	return _num(b.get("range", b.get("reach", d.get("range", d.get("reach", 0.0)))))

## A kit number, or the low end of a [min, max] pair.
static func _num(v) -> float:
	return float(v[0]) if v is Array else float(v)
