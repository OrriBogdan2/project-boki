## Regions' own loot and the match's hot drop zone. Each region of an authored map may lean its
## chests and drops toward some gear ("loot": slot weights that multiply the biome's, rarity steps
## that add). Every match also picks one region, from the shared match seed (so every player sees
## the same one, and it changes match to match), as the hot zone: loot there rolls a step better.
## It's ringed on the drop map and the minimap, and bot squads weigh it when they pick where to land.
## Owned by BiomeRun, which folds it into its loot answers.
class_name HotZone
extends RefCounted

## Extra rarity steps for everything found in the hot zone (chests, drops, bosses).
const RARITY := 1
## Chance (0..1) a bot squad leader with no human ping heads for the hot zone, if no other squad is.
const BOT_PICK := 0.35
## How near (m) another squad must be to the hot zone's landing for a bot leader to look elsewhere.
const CROWD_R := 25.0
const COL := Color("ff8a3a")

var w: World = null
var region_of := PackedInt32Array()   # island index -> region index (-1: none)
var hot := -1                         # the hot region's index in w.regions (-1: none)
var zone: Array = []                  # the hot region's islands: {c: Vector3 centre, r: radius in m}

func _init(world: World, seed_val: int) -> void:
	w = world
	region_of.resize(w.islands.size())
	region_of.fill(-1)
	var picks: Array = []
	for ri in w.regions.size():
		var heart := false
		for ii in w.islands.size():
			if String(w.islands[ii].get("id", "")) in w.regions[ri].get("islands", []):
				region_of[ii] = ri
				heart = heart or String(w.islands[ii].get("role", "")) == "heart"
		if not heart:
			picks.append(ri)     # (the Crown already pays best: a hot Crown would pull every squad in)
	if not picks.is_empty():
		hot = picks[posmod(hash([seed_val, "hot_zone"]), picks.size())]
	for ii in region_of.size():
		if hot >= 0 and region_of[ii] == hot:
			var I: Dictionary = w.islands[ii]
			zone.append({"c": Vector3(I["c"].x + 0.5, 0, I["c"].y + 0.5), "r": float(I.get("r", 8))})

func region_at(p: Vector3) -> int:
	var ii := w.island_of(p.x, p.z)
	return region_of[ii] if ii >= 0 else -1

## The region's slot weights at p, multiplied into the biome's (`lean`).
func slot_lean(p: Vector3, lean: Dictionary) -> Dictionary:
	var ri := region_at(p)
	var own: Dictionary = w.regions[ri].get("loot", {}).get("slots", {}) if ri >= 0 else {}
	if own.is_empty():
		return lean
	var out := lean.duplicate()
	for sn in own:
		out[sn] = float(out.get(sn, 1.0)) * float(own[sn])
	return out

## Extra rarity steps at p from its region's own loot and the hot zone.
func rarity_bonus(p: Vector3) -> int:
	var ri := region_at(p)
	if ri < 0:
		return 0
	return int(w.regions[ri].get("loot", {}).get("rarity_bonus", 0)) + (RARITY if ri == hot else 0)

## Where a bot squad heading for the hot zone lands: near the middle of its main island.
func landing() -> Vector3:
	return w.free_spot_near(zone[0]["c"], [], 1.0, 0.5, 12.0) if not zone.is_empty() else Vector3.INF

## The hot zone on the drop map / full map (FullMap.draw).
func full_map(fm, kk: float) -> void:
	for k in zone.size():
		var pv: Vector2 = fm.to_screen(zone[k]["c"])
		fm.hud.c.draw_arc(pv, float(zone[k]["r"]) * kk, 0.0, TAU, 48, Color(COL, 0.85), 3.0)
		if k == 0:
			var top := pv - Vector2(0, float(zone[k]["r"]) * kk + 8.0)
			fm.hud._ctext(top, "HOT ZONE  ·  better loot", 13, COL, fm.hud.big)

## The hot zone on the minimap: a ring round each of its islands in view.
func minimap(hud, to_map: Callable, on_map: Callable) -> void:
	for I in zone:
		var pv: Vector2 = to_map.call(I["c"])
		if on_map.call(pv, 0.0):
			var edge: Vector2 = to_map.call(I["c"] + Vector3(float(I["r"]), 0, 0))
			hud.c.draw_arc(pv, (edge - pv).length(), 0.0, TAU, 32, Color(COL, 0.7), 1.5)
