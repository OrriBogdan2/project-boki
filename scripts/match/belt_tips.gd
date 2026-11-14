class_name BeltTips
extends RefCounted
## One-time belt item tips for the local player, shown through Match._tip (once per save, key
## "belt_<item>" in Save.d.tutorial). The first ground pickup of an item names it, its slot's key and
## the first sentence of its desc. The tonic and armor kit, which a hunter starts with, wait for the
## moment they matter: low health and an armor break. A chest key says nothing here (it is a key).

const LOW_HP := 0.4  # of max health: under it the tonic tip is due
const ON_NEED := ["tonic", "armor_kit"]  # taught when they are needed, not when picked up

var _new: Array[String] = []  # items the player picked up from the ground whose tip has not come yet
var _armor_was := 0.0  # the player's armor at the last call
var _armor_broke := false  # the armor broke and the armor kit tip has not come yet


## A ground pickup by the local player (UtilityBelt.pickup).
func picked(id: String) -> void:
	if id not in ON_NEED and not UtilityBelt.is_key(id) and id not in _new:
		_new.append(id)


## The next tip that is due, as [save key, line], or [] (one per call: Match._tips asks every frame).
func next(h: Hunter) -> Array:
	_armor_broke = _armor_broke or (_armor_was > 0.0 and h.armor <= 0.0)
	_armor_was = h.armor
	while not _new.is_empty():
		var tip := _tip(h, _new.pop_front())
		if tip:
			return tip
	if _armor_broke:
		_armor_broke = false
		return _tip(h, "armor_kit")
	if h.hp < h.max_hp * LOW_HP:
		return _tip(h, "tonic")
	return []


## [save key, line] for an item on the belt, or [] if it is not on it or the save has seen its tip.
func _tip(h: Hunter, id: String) -> Array:
	var key := "belt_" + id
	var slot := UtilityBelt.slot_of(h, id)
	if slot < 0 or Save.d["tutorial"].get(key, false):
		return []
	var effect := String(UtilityBelt.def(id).get("desc", "")).get_slice(". ", 0).trim_suffix(".")
	var cap := Settings.key_cap(UtilityBelt.KEYS[slot])
	return [key, "%s on %s: %s" % [UtilityBelt.name_of(id), cap, effect]]
