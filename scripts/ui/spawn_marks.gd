class_name SpawnMarks
extends RefCounted
## Spawns about to appear (SpawnTable.warning), on the minimap and the full map: a shrinking ember
## ring with the seconds left. The same ring marks the ground where it will happen.

const COL := Color("ff7a3a")
const RING := 9.0          # px: where the ring starts on the map

static func draw(hud, m: Match, to_map: Callable, on_map: Callable) -> void:
	if m.spawn_table == null:
		return
	var tele: float = float(SpawnTable.rules()["burrow"]["tele"])
	for w in m.spawn_table.warning():
		var pv: Vector2 = to_map.call(w["pos"])
		if not on_map.call(pv, RING):
			continue
		var left: float = w["left"]
		hud.c.draw_arc(pv, RING * (0.5 + 0.5 * clampf(left / tele, 0.0, 1.0)), 0.0, TAU, 20, COL, 2.0, true)
		hud._ctext(pv + Vector2(0, -RING - 3.0), str(ceili(left)), 12, COL)
