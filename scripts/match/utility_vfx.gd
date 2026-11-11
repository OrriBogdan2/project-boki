class_name UtilityVfx
extends RefCounted
## What every belt item looks like while it works, readable at the match camera (docs/UTILITY_VFX.md).
## content/vfx/belt/utility.json has one entry per item id under "items": "area" (what marks where it
## works), "does" (what it does to whoever it touches) and "ends" (what shows it stopping), and the
## moments, played by the pooled HeroVfx from the same file's "moves":
##   "<id>"        when it is used          "<id>_hit"   on each body or spot it acts on
##   "<id>_hold"   worn by a body while it lasts (wear)   "<id>_end"   when it stops
## Colours are the item's own (hex) or "side" (you / ally / rival, SideColor). The ground pieces that
## last (fuse, portals, spikes, ward ring...) are UtilityLook's. Local: each game plays them from its own sim.

const FILE := "belt/utility"     # content/vfx/belt/utility.json
const WORN := "util_worn"        # Match meta: the bodies wearing an item's look

## Item `id`'s entry (empty if it has none).
static func entry(id: String) -> Dictionary:
	return (HeroVfx.data(FILE).get("items", {}) as Dictionary).get(id, {})

## Body `h` has just used item `id`: its moment, what it starts wearing, and its ground look.
static func used(h: Hunter, id: String) -> void:
	play(h, id)
	match UtilityUse.use_of(id):
		"drink": wear(h, id, h.drink_t, func(): return h.drink_t > 0.0 and h.drink_id == id)
		"repair": wear(h, id, h.kit_t, func(): return h.kit_t > 0.0)
	if id == "stim":
		wear(h, id, h.haste_t, func(): return h.haste_t > 0.0)
	UtilityLook.cast(h, id)

## A moment of item `id` ("" when used, "hit", "end") about body `h`, at `at` (h's feet by default).
static func play(h: Hunter, id: String, moment := "", at: Variant = null) -> void:
	if not is_instance_valid(h):
		return
	var move := id if moment == "" else "%s_%s" % [id, moment]
	HeroVfx.of(h.m).play(h, move, h.pos if at == null else at, h.aim_dir(), {"set": FILE})

## Body `x` wears item `id`'s "_hold" look for `secs` (or until `keep` turns false), then its "_end"
## plays on it. Wearing it again stretches the time.
static func wear(x: Hunter, id: String, secs: float, keep := Callable()) -> void:
	var m: Node = x.m
	if not m.has_meta(WORN):
		m.set_meta(WORN, [])
	for w: Dictionary in m.get_meta(WORN):
		if w["x"] == x and w["id"] == id:
			w["until"] = maxf(float(w["until"]), m.time + secs)
			w["keep"] = keep
			return
	(m.get_meta(WORN) as Array).append({"x": x, "id": id, "until": m.time + secs, "keep": keep})

## Every step: the worn looks follow their bodies; one that runs out (or its body is out) ends.
static func tick(m: Node) -> void:
	if not m.has_meta(WORN):
		return
	var worn: Array = m.get_meta(WORN)
	var fx := HeroVfx.of(m)
	for i in range(worn.size() - 1, -1, -1):
		var w: Dictionary = worn[i]
		var x: Variant = w["x"]
		var keep: Callable = w["keep"]
		var on: bool = is_instance_valid(x) and not x.out and m.time < float(w["until"])
		if on and (not keep.is_valid() or keep.call()):
			fx.hold(x, String(w["id"]) + "_hold", 0.0, {"set": FILE})
			continue
		worn.remove_at(i)
		if is_instance_valid(x):
			play(x, String(w["id"]), "end")

## Who wears item `id` now (checks and shots).
static func wearers(m: Node, id: String) -> Array:
	var worn: Array = m.get_meta(WORN, [])
	return worn.filter(func(w): return w["id"] == id).map(func(w): return w["x"])
