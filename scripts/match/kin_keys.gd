class_name KinKeys
extends RefCounted
## The quick Boki order keys (Settings > Controls): attack my target (Chase), come back (Return), hold this
## position (Guard). Each is the same order the G wheel gives; the pick waits in h.inp["wheel_pick"] until
## KinCommand.apply_pick runs on the fixed step.

const ORDERS := [["kin_attack", "chase"], ["kin_return", "return"], ["kin_hold", "guard"]]

## Per frame from Match._gather_input for the local player. `blocked`: a menu or map is up.
static func poll(h: Hunter, blocked: bool) -> void:
	if blocked or h.kin == null:
		return
	for o in ORDERS:
		if Input.is_action_just_pressed(o[0]):
			h.inp["wheel_pick"] = o[1]
