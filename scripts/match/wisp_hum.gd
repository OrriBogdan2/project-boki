class_name WispHum
extends RefCounted
## The Hunter Wisp's hum (DECISIONS 2026-11-09 outline rule): a downed Hunter's Wisp is slow, heavy and low,
## so it hums (tools/gen_wisp_sfx.py), never a chirp like a Boki wisp. Presentation only, called by
## HunterWisp: each frame the Wisp is up it holds a keyed Sfx loop at its place (Sfx.loop_hold, so the loop
## also stops by itself if the hunter stops ticking), and when the Wisp is finished it falls away.
## Heard to reach_m; a teammate's Wisp is a little louder than a rival's; the pitch rises while the revive
## channel fills; at most max_voices hum at once (the nearest to the listener). Numbers:
## content/rules/wisp_hum.json. No state of its own: every frame it reads the Wisp as it is (downed, seen,
## where it is, revive progress), so a stomp lock (the stomp drains the revive, the pitch falls back) or a
## teammate's carry (the Wisp rides the carrier, so does the hum) needs no code here. A Hunter Wisp is
## never stolen (DECISIONS 2026-11-09), so there is no steal case.

const RULES_PATH := "res://content/rules/wisp_hum.json"
const HUM := "wisp_hum"
const HUM_END := "wisp_hum_end"
const END_DB := -6.0       # dB: the fall-away, under the pop that goes with it

static var _rules := {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	return _rules

static func key(h: Hunter) -> String:
	return "wisphum%d" % h.get_instance_id()

## Keeps this Wisp's hum going for a frame, if it is seen, in earshot and among the nearest few.
static func hold(h: Hunter) -> void:
	var R := rules()
	if not h.visible or _dist(h) > float(R["reach_m"]) or _rank(h) >= int(R["max_voices"]):
		return
	Sfx.loop_hold(key(h), HUM, h.position, _level(h), 1.0 + float(R["rise"]) * clampf(h.revive, 0.0, 1.0))

## The Wisp is finished (revived or bled out): the hum stops and sinks away where it was.
static func end(h: Hunter) -> void:
	if not Sfx.loop_on(key(h)):
		return
	Sfx.loop_stop(key(h))
	h.m.sfx(HUM_END, h.position, END_DB)

## Your own Wisp, a teammate's (a little louder: it is the one you can save) or a rival's.
static func _level(h: Hunter) -> float:
	var R := rules()
	if h.is_local():
		return float(R["own_db"])
	var mate: bool = h.m.player != null and h.team == h.m.player.team
	return float(R["mate_db"] if mate else R["foe_db"])

static func _dist(h: Hunter) -> float:
	return Vector2(h.position.x - Sfx.listener.x, h.position.z - Sfx.listener.z).length()

## How many other seen Wisps are nearer to the listener (a tie goes to the older hunter): the cap.
static func _rank(h: Hunter) -> int:
	var d := _dist(h)
	var n := 0
	for o in h.m.hunters:
		if o != h and o.downed and not o.out and o.visible:
			var od := _dist(o)
			if od < d or (od == d and o.get_instance_id() < h.get_instance_id()):
				n += 1
	return n
