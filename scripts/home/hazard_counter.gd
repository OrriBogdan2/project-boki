class_name HazardCounter
extends RefCounted
## Which map hazards a Boki walks safely, as one plain line with the hazards' icons ("Walks the lava
## safely") on the home cards: the Boki card, its Field Book page and the expedition portal's carry pick.
## Read from content/rules/terrain_hazards.json (each kind's counter themes and kin); nothing is copied.

## The hazard kinds `spk` counters: its theme or its species is on the kind's counter list.
static func kinds_of(spk: String) -> Array:
	var theme := String(Data.KIN.get(spk, {}).get("theme", ""))
	var out := []
	var kinds: Dictionary = TerrainHazards.rules()["kinds"]
	for kind in kinds:
		var C: Dictionary = kinds[kind].get("counter", {})
		if theme in C.get("themes", []) or spk in C.get("kin", []):
			out.append(kind)
	return out

## "Walks the lava safely" ("Walks the lava and the ice safely"); empty when it counters nothing.
static func line(spk: String) -> String:
	var nouns := PackedStringArray()
	for kind in kinds_of(spk):
		nouns.append(String(TerrainHazards.kind_def(kind).get("noun", kind)))
	return "" if nouns.is_empty() else "Walks %s safely" % " and ".join(nouns)

## The hazards' icons and the line in one row; adds nothing for a Boki that counters nothing.
static func add_row(parent: Control, spk: String, px := 15.0, font := 12) -> void:
	var kinds := kinds_of(spk)
	if kinds.is_empty():
		return
	var r := UI.hbox(5)
	for kind in kinds:
		var def := TerrainHazards.kind_def(kind)
		r.add_child(UI.IconDot.new(String(def.get("icon", "")), Color(String(def["look"]["edge"])), px))
	var l := UI.label(line(spk), font, UI.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	r.add_child(l)
	r.tooltip_text = "Hazard ground on the map: your Boki keeps you safe in it."
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(r)
