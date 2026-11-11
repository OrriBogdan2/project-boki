class_name KinKeys
extends RefCounted
## Quick keys for the Boki commands, beside G (docs/decisions/0002): one bindable action for each order on
## G's wheel (Chase, Guard, Return, Follow) and one for G's tap (send out or call back). All start unbound,
## so a new player sees only G. A press takes the wheel's own path: an order waits in h.inp["kin_keys"] and
## KinCommand.order runs it on the fixed step, a summon is the same queued tap as G (Match.pending_input["throw"]).
## The orders are a queue, so two keys in one frame, or a key beside a G wheel pick, never drop each other.

const SUMMON := "kin_summon"
## Action -> the wheel segment id it gives (KinWheel.SEGMENTS).
const ORDERS := {"kin_chase": "chase", "kin_guard": "guard", "kin_return": "return", "kin_follow": "follow"}
## The action ids, in Controls order (their names are in Settings.ACTIONS).
static func ids() -> Array:
	return [SUMMON] + ORDERS.keys()

## The local player's keys, each frame. Queues the orders pressed; true when the summon key went down.
static func poll(h: Hunter, paused: bool) -> bool:
	if paused:
		return false
	for action in ORDERS:
		if Input.is_action_just_pressed(action):
			var q: Array = h.inp.get("kin_keys", [])
			q.append(ORDERS[action])
			h.inp["kin_keys"] = q
	return Input.is_action_just_pressed(SUMMON)

## The queued orders, on the fixed step (with KinCommand.apply_pick).
static func apply(h: Hunter) -> void:
	var q: Array = h.inp.get("kin_keys", [])
	if q.is_empty():
		return
	h.inp.erase("kin_keys")
	for id in q:
		KinCommand.order(h, id)

## The "Your kit" card rows for the quick keys that are bound: [key caps, name, text, colour].
static func card_lines(col: Color) -> Array:
	var out: Array = []
	for id in ids():
		if Settings.slots(id) == ["", ""]:
			continue
		var what := "Send out or call back" if id == SUMMON else String(KinFollow.NAMES[ORDERS[id]])
		out.append([Settings.key_caps(id), what, "", col])
	return out
