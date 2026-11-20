class_name CcTips
extends RefCounted
## The first-time crowd-control tips (stunned, rooted, grounded): one plain line the first time each happens to
## the player, from content/rules/tutorial.json "tips". Called each frame from Match._tips; Match._tip keeps each once.

const SELF_HOLD_S := 0.12   # s of root a hunter's own statue or stomp keeps refreshing: not a foe's root

static func tick(m) -> void:
	var p: Hunter = m.player
	var seen: Dictionary = Save.d["tutorial"]
	var tips: Dictionary = Content.rules("tutorial")["tips"]
	if p.stun_t > 0.0 and not seen.has("cc_stun"): m._tip("cc_stun", tips["stun"])
	elif p.root_t > SELF_HOLD_S and not seen.has("cc_root"): m._tip("cc_root", tips["root"])
	elif KitStatus.grounded(p) and not seen.has("cc_grounded"): m._tip("cc_grounded", tips["grounded"])
