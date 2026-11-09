class_name BotBelt
extends RefCounted
## How a bot uses its utility belt (UtilityBelt): the same keys a player presses (inp util1..3), at
## the moments a player would. Called once a step from Bot.think with the bot's mind `a`.
##   tonic       hurt (under 45% health), with ground under it
##   armor kit   armor mostly gone (under 30%) and nobody close
##   mending kit hurt (under 55%) in a fight
##   smoke       hurt and a rival close: hide and slip away
##   shield cell a rival in range and shooting back
##   swift       hurt and a rival close (to get away), or a long chase
##   seeker      now and then, with no target, to see what is around
## Spring pads are for players (a bot has no use for a launch it did not plan).

const SCAN_GAP := 40.0          # seconds between a bot's seeker flares

static func think(m, h: Hunter, a: Dictionary, inp: Dictionary) -> void:
	if h.drink_t > 0.0 or h.kit_t > 0.0 or h.downed or h.out or h.dropping:
		return
	var grounded: bool = h.grounded or (not h.gliding and not h.over_void())
	var tgt = a.get("tgt", null)
	var near: bool = tgt != null and is_instance_valid(tgt) and tgt is Hunter and h.flat_dist(tgt) < 14.0
	var frac: float = h.hp / h.max_hp
	if grounded and frac < 0.45 and _press(h, inp, "tonic"):
		return
	if grounded and h.armor < h.max_armor * 0.3 and not near and _press(h, inp, "armor_kit"):
		return
	if frac < 0.55 and near and _press(h, inp, "medkit"):
		return
	if frac < 0.4 and near and _press(h, inp, "smoke"):
		return
	if near and tgt != null and h.flat_dist(tgt) < 10.0 and frac < 0.8 and h.shield <= 0.0 \
			and _press(h, inp, "shield_cell"):
		return
	if near and frac < 0.5 and _press(h, inp, "stim"):
		return
	if tgt == null and m.time - float(a.get("scan_t", -SCAN_GAP)) > SCAN_GAP and randf() < 0.02:
		if _press(h, inp, "scanner"):
			a["scan_t"] = m.time

static func _press(h: Hunter, inp: Dictionary, id: String) -> bool:
	var i := UtilityBelt.slot_of(h, id)
	if i < 0 or float(h.belt[i].get("cd", 0.0)) > 0.0 or not UtilityUse.can_use(h, id):
		return false
	inp[UtilityBelt.KEYS[i]] = true
	return true
