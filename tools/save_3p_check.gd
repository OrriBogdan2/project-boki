extends RefCounted
## --save-3p-check: saves from 0.24.4-0.24.6 (v12 chain fixture, v13/v14 goldens) load into the close third-person
## garden. Each one runs twice: as it is, and "dense" (a ring of lamp posts and lanterns round the first Boki and
## the landing, from before lamps blocked, plus two built buildings). After the farm builds: every Boki and you
## stand on open ground the walk flood reaches, not under the terrain; every placed building keeps open ground at
## its door; no decoration stands on water or off the island; no saved Boki is dropped. Prints per save how many
## Boki and buildings the load moved. Never touches the real save.

const FIXTURES := {
	"0.24.4 (v12)": "res://tools/fixtures/save_chain/v0.24.4.json",
	"0.24.5 (v13)": "res://tests/fixtures/saves/save_v13_farm.json",
	"0.24.6 (v14)": "res://tests/fixtures/saves/save_v14_farm.json",
}
const BUILT := ["workshop", "cottage"]

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("SAVE3P %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for tag in FIXTURES:
		var text := FileAccess.get_file_as_string(FIXTURES[tag])
		for dense in [false, true]:
			await _one("%s %s" % [tag, "dense" if dense else "as saved"], text, dense)
	print("SAVE3P DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _load(text: String) -> void:
	var p := "user://save_3p_check.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	Save.load_from(p)
	DirAccess.remove_absolute(p)


func _one(tag: String, text: String, dense: bool) -> void:
	_load(text)
	var roster: Array = Save.d["roster"]
	var saved: Array = (JSON.parse_string(text)["roster"] as Array).map(func(r): return String(r["uid"]))
	var layout: Dictionary = HomeLayout.of(Save.d)
	var spots: Array = []
	if dense:
		spots = await _spots()
		_load(text)
		_dense(spots)
	var before := _placed(Save.d)
	var home = await main._hb_home()
	var hb: HomeBuild = home.hb
	var seen: PackedByteArray = hb._reach([], [])
	var lost := 0
	var stuck := 0
	var below := 0
	for uid in saved:
		if not roster.any(func(r): return String(r["uid"]) == uid):
			lost += 1
	for r in GardenZones.out_here():
		var k = _kin_of(home, String(r["uid"]))
		if k == null:
			lost += 1
			continue
		var at: Vector3 = k["pos"]
		if not hb._hit(seen, at):
			stuck += 1
		if (k["node"] as Node3D).position.y < home.world.ground_at(at.x, at.z) - 0.05:
			below += 1
	ok(
		lost == 0 and stuck == 0 and below == 0,
		"%s: %d Boki out, %d shut in, %d under the ground, %d dropped" % [tag, home.kins.size(), stuck, below, lost]
	)
	ok(
		hb._hit(seen, home.ppos) and home.ppos.y >= home.world.ground_at(home.ppos.x, home.ppos.z) - 0.05,
		"%s: you stand on open ground (%s)" % [tag, str(home.ppos)]
	)
	var bad_b := _buildings_bad(home, hb, seen)
	ok(bad_b.is_empty(), "%s: buildings and decorations sit on ground with an open door %s" % [tag, str(bad_b)])
	var after := _placed(Save.d)
	var moved := 0
	for key in before:
		if after.get(key, null) != before[key]:
			moved += 1
			print("SAVE3P moved %s: %s -> %s" % [key, before[key], after.get(key, null)])
	print(
		(
			"SAVE3P report %s: %d Boki, buildings/decorations moved %d of %d, layout fs=%s sk=%s"
			% [tag, roster.size(), moved, before.size(), str(layout.get("fs")), str(layout.get("sk"))]
		)
	)
	home.queue_free()
	await main.get_tree().process_frame


func _kin_of(home, uid: String):
	for k in home.kins:
		if String(k["rec"]["uid"]) == uid:
			return k
	return null


## "kind:id@x,z" -> where the save puts it, for buildings and decorations.
func _placed(d: Dictionary) -> Dictionary:
	var out := {}
	var L := HomeLayout.of(d)
	for b in L.get("b", {}) as Dictionary:
		out["b:%s" % b] = "%s,%s,%s" % [L["b"][b]["x"], L["b"][b]["z"], L["b"][b].get("r", 0)]
	for e in L.get("deco", []):
		out["d:%s" % e["u"]] = "%s@%s,%s" % [e["id"], e["x"], e["z"]]
	return out


## Pass 1 of a dense save: the landing, where the first Boki stands, and two free 5x5 lots for the buildings.
func _spots() -> Array:
	var home = await main._hb_home()
	var hb: HomeBuild = home.hb
	var out: Array = [home.kins[0]["pos"], HomeLayout.LANDING]
	var from: Vector3 = HomeLayout.LANDING
	var lots: Array = []
	for z in range(4, home.world.h - 9):
		for x in range(4, home.world.w - 9):
			var d := Vector2(x - from.x, z - from.z).length()
			if d > 10.0 and _lot_free(hb, x, z):
				lots.append([d, x, z])
	lots.sort()
	out.append(Vector2i(lots[0][1], lots[0][2]))
	for l in lots:
		if absf(l[1] - lots[0][1]) + absf(l[2] - lots[0][2]) > 10.0:
			out.append(Vector2i(l[1], l[2]))
			break
	home.queue_free()
	await main.get_tree().process_frame
	return out


func _lot_free(hb: HomeBuild, x: int, z: int) -> bool:
	for dz in range(-1, 6):
		for dx in range(-1, 6):
			if hb.cell_reason(Vector2i(x + dx, z + dz)) != "":
				return false
	return true


## The old farm's lamps did not block: a ring of them round the first Boki and one on the landing; two buildings.
func _dense(spots: Array) -> void:
	var L := HomeLayout.of(Save.d)
	Save.d["layout"] = L  # a classic (v12) save has none yet
	var at: Vector3 = spots[0]
	var cx := int(floor(at.x))
	var cz := int(floor(at.z))
	var u := 1000
	var ring := [
		Vector2i(-1, -1),
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(-1, 1),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(0, 0)
	]
	for i in ring.size():
		L["deco"].append(
			{
				"u": u + i,
				"id": "lamp_post" if i % 2 == 0 else "lantern",
				"x": cx + ring[i].x,
				"z": cz + ring[i].y,
				"r": 0
			}
		)
	var land: Vector3 = spots[1]
	L["deco"].append({"u": u + 20, "id": "lantern", "x": int(floor(land.x)), "z": int(floor(land.z)), "r": 0})
	Save.d["buildings"] = BUILT.duplicate()
	for i in BUILT.size():
		if int(L.get("fs", 0)) < 1:
			break
		var lot: Vector2i = spots[2 + i]
		L["b"][BUILT[i]] = {"x": lot.x, "z": lot.y, "r": 0}


## Buildings and decorations that stand off the island, in water, or with no open ground at the door.
func _buildings_bad(home, hb: HomeBuild, seen: PackedByteArray) -> Array:
	var w: World = home.world
	var out: Array = []
	var d: Dictionary = Save.d
	for b in d.get("buildings", []):
		if not Data.BUILDINGS.has(b):
			continue
		var p := HomeLayout.place_of(b, d)
		var door := HomeLayout.door_at(b, p["x"], p["z"], p["r"])
		for c in HomeLayout.cells_of(HomeLayout.rect_of(b, d)):
			if not w.inb(c.x, c.y) or w.kind[w.idx(c.x, c.y)] == World.T_VOID:
				out.append("%s off island" % b)
				break
		if not hb._hit(seen, door, 2):
			out.append("%s door shut" % b)
	for e in HomeLayout.of(d).get("deco", []):
		for c in HomeLayout.deco_cells(e):
			if not w.inb(c.x, c.y) or w.kind[w.idx(c.x, c.y)] == World.T_VOID:
				out.append("%s#%s off island" % [e["id"], e["u"]])
				break
	return out
