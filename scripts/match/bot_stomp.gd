class_name BotStomp
extends RefCounted
## How a bot plays the stomp (docs/BOT_KIT_USE.md "Stomps", DECISIONS 2026-11-11 "stomping"). A stomp
## pins the stomper for Stomp.TIME and a stun or knock on it saves the wisp, so:
##   safe()    a bot stomps a downed rival only with no standing enemy Hunter within punish_r of it
##   rescue()  a bot whose teammate is being stomped spends its ready breaker on the stomper first
## The numbers and each Hunter's breaker are in content/rules/bot_stomp.json.

const RULES_PATH := "res://content/rules/bot_stomp.json"
const AIM_HOLD := 1.0         # s after the press the bot keeps aiming at the stomper (wind-up and flight)
static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

## No enemy Hunter on its feet near the downed rival o: stomping it can't be punished.
static func safe(m: Match, h: Hunter, o: Hunter) -> bool:
	var r := float(rules()["punish_r"])
	for e in m.hunters:
		if e != o and e.team != h.team and not e.downed and not e.out and e.flat_dist(o) < r:
			return false
	return true

## A teammate being stomped and our breaker ready: walk into its reach and press it on the stomper,
## then keep aiming at it for AIM_HOLD while the move winds up and flies. True while it has taken
## over the bot's step (Bot.think does nothing else then).
static func rescue(m: Match, h: Hunter) -> bool:
	var b: Dictionary = (rules()["breakers"] as Dictionary).get(h.arch, {})
	if b.is_empty() or h.ak == null:
		return false
	var ready := _ready(h, String(b["key"]))
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

## The slot behind an input key is unlocked and off cooldown ("sec" RMB, "sig" E).
static func _ready(h: Hunter, key: String) -> bool:
	if key == "sec":
		return int(h.slot_lv["sec"]) > 0 and h.ak.rmb_ready()
	return int(h.slot_lv["kin"]) > 0 and float(h.ak.cd["e"]) <= 0.0
