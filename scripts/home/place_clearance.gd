class_name PlaceClearance
extends RefCounted
## Walkable clearance on the farm: nothing you place may shut a Boki (or you) into a pocket. The flood
## starts at the house door (a zone: its return pad); HomeBuild.keeps_paths asks who a piece would trap
## and the ghost names them. A Boki that loads into a pocket (an old save) is set on open ground.

## Where the walkable flood starts: a zone's return pad, else the house door.
static func start(h) -> Vector3:
	if h.zone != "" and h.hway != null and h.hway.node != null:
		return h.hway.node.position
	return h._house_door()

## Everyone who has to be able to walk out: you, and each Boki that is out on the farm. [{name, at}]
static func walkers(h) -> Array:
	var out: Array = [{"name": "you", "at": h.ppos}]
	for k in h.kins:
		if not KinIndoors.inside.has(String(k["rec"]["uid"])):
			out.append({"name": String(k["rec"]["name"]), "at": k["pos"]})
	return out

## The first walker that was reachable before (`base`) and is not after, or "".
static func trapped(hb: HomeBuild, base: PackedByteArray, after: PackedByteArray) -> String:
	for who in walkers(hb.h):
		if hb._hit(base, who["at"]) and not hb._hit(after, who["at"]):
			return who["name"]
	return ""

## "This would shut Mossbun in" when keeps_paths just refused for a walker, else the general reason.
static func why(trapped_name: String) -> String:
	if trapped_name == "":
		return "That would cut off a door or a path"
	return "This would shut %s in" % trapped_name

## Sets every Boki and the player that sits in a pocket onto the nearest tile that can be walked to.
## Returns how many were moved.
static func free_trapped(h) -> int:
	var hb: HomeBuild = h.hb
	var w: World = h.world
	var seen := hb._reach([], [])
	var moved := 0
	for who in walkers(h):
		var at: Vector3 = who["at"]
		if hb._hit(seen, at) or not w.inb(int(floor(at.x)), int(floor(at.z))):
			continue
		var best := Vector3.INF
		var best_d := INF
		for i in seen.size():
			if seen[i] != 1 or w.kind[i] != World.T_GROUND:
				continue
			var tile := Vector3(i % w.w + 0.5, 0, i / w.w + 0.5)
			var d := Vector2(tile.x - at.x, tile.z - at.z).length_squared()
			if d < best_d:
				best = tile
				best_d = d
		if best == Vector3.INF:
			continue
		_move(h, who, best)
		moved += 1
	return moved

static func _move(h, who: Dictionary, to: Vector3) -> void:
	if who["name"] == "you":
		h.ppos = to
		return
	for k in h.kins:
		if String(k["rec"]["name"]) == who["name"] and k["pos"] == who["at"]:
			k["pos"] = to
			(k["node"] as Node3D).position = to
			k["goal"] = Vector3.INF
			k.erase("path")
