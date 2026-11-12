class_name DexFound
extends RefCounted
## Where a Boki is found and how rare it is, for the Field Book (DexView). Both come from the spawn data
## an expedition really uses: wild Boki live on the islands a map's layout gives a "wild" list; a boss-egg
## Boki only hatches from the Rare Egg of its boss's lair. A Boki you haven't met shows "?" for both.

const TIERS := ["Common", "Rare", "Very rare"]
const MODE := "Expedition"

## 0 Common (wild, on any run), 2 Very rare (only from a boss's Rare Egg). Tier 1 (Rare) is the
## middle rung: no species sits there until the spawn data gives one a thinner share than the rest.
static func tier(spk: String) -> int:
	return 2 if Data.is_rare(spk) else 0

static func tier_name(spk: String) -> String:
	return String(TIERS[tier(spk)])

## "Expedition, The Hollow Crown: Thornwood, Larkhollow" (wild), or the boss's lair for a Rare Egg Boki.
static func found_in(spk: String) -> String:
	var map: Dictionary = World.load_layout(World.layout_for_tier(0))
	var places: Array = []
	if Data.is_rare(spk):
		for lair in map.get("lairs", []):
			if String(lair.get("boss", "")) == String(Data.KIN[spk].get("boss", "")):
				places.append(String(lair.get("name", "")))
	else:
		var region_of := {}
		for r in map.get("regions", []):
			for isl in r.get("islands", []): region_of[String(isl)] = String(r.get("name", ""))
		for isl in map.get("islands", []):
			var rn := String(region_of.get(String(isl.get("id", "")), String(isl.get("name", ""))))
			if not (isl.get("wild", []) as Array).is_empty() and not places.has(rn): places.append(rn)
	var out := "%s, %s" % [MODE, String(map.get("name", "the Skylands"))]
	return out if places.is_empty() else "%s: %s" % [out, ", ".join(places)]

## Three small diamonds, filled up to its tier; "?" when the Boki hasn't been met.
class Pip extends Control:
	const D := 5.0          # a diamond's half-width, px
	var filled := -1        # diamonds lit (tier + 1); -1: unmet
	func _init(spk: String, met: bool) -> void:
		filled = DexFound.tier(spk) + 1 if met else -1
		custom_minimum_size = Vector2(D * 6.0 + 4.0, D * 2.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tooltip_text = DexFound.tier_name(spk) if met else "Rarity unknown"
		if met: return
		var q := UI.label("?", UI.T_SMALL, UI.FAINT, UI.semi)
		q.set_anchors_preset(Control.PRESET_FULL_RECT)       # level with the number, in the badge's corner
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.grow_vertical = Control.GROW_DIRECTION_BOTH          # taller than the pip: spill evenly up and down
		add_child(q)
	func _draw() -> void:
		if filled < 0: return
		for i in DexFound.TIERS.size():
			var c := Vector2(D + i * (D * 2.0 + 2.0), size.y * 0.5)
			var pts := PackedVector2Array([c + Vector2(0, -D), c + Vector2(D, 0), c + Vector2(0, D), c - Vector2(D, 0)])
			draw_colored_polygon(pts, UI.INK if i < filled else Color(1, 1, 1, 0.14))
