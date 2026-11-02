class_name DropFamily
extends RefCounted
## Which weapon an earned or found drop holds: leaning toward the earner's own archetype family,
## so a Thief isn't left looking at rifles it can't hold. (Moved out of match.gd, which cannot grow.)

## The weapon in a drop someone earned (a chest they opened, a crate they broke, a guard or treasure
## monster they felled): with an archetype, three times in four one from its own family, so a Thief
## isn't left looking at rifles it can't hold; otherwise (and the rest of the time) `fallback`, or any.
## (Boss drops are always the killer's family: Lairs._victory.)
static func earned(by, keys: Array, fallback := "") -> String:
	var h = by
	if h != null and not (h is Hunter) and is_instance_valid(h) and "owner_h" in h:
		h = h.owner_h
	if h is Hunter and is_instance_valid(h) and String((h as Hunter).arch) != "":
		var fam: Array = Arch.weapons(String((h as Hunter).arch))
		if not fam.is_empty() and randf() < 0.75:
			return String(fam[randi() % fam.size()])
	return fallback if fallback != "" else String(keys[randi() % keys.size()])

## The weapons lying in the open and beside caches (rolled the same for everyone online): offline,
## with an archetype, three in five are swapped for one of your own family (picked from `salt`, so
## the map's other rolls don't move), so the weapons on the ground aren't mostly ones you can't hold.
static func ground(wk: String, salt: int, net_on: bool, player, seed_val: int) -> String:
	if net_on or player == null or String(player.arch) == "":
		return wk
	var fam: Array = Arch.weapons(String(player.arch))
	if fam.is_empty() or fam.has(wk):
		return wk
	var hv := absi(hash(salt * 7919 + seed_val))
	return String(fam[(hv / 7) % fam.size()]) if hv % 5 < 3 else wk
