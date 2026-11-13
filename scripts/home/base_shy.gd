class_name BaseShy
extends RefCounted
## A Boki adopted from the Shelter is shy for its first farm day (GARDEN.md section 4, base_mode). It arrives at the
## zone's stone (the pad, HubWaystone), the residents come to look (BaseLife._arrived, ComeLook: the first to
## reach it keeps "was there the day <name> arrived"), and it keeps to the island's edge: no tag, no toys, nobody
## picks it as a mate. rec["shy_s"] counts down only while it is on the farm; absent means settled (an old save,
## or a Boki that was not adopted), so no save migration. Tuning: base_life.json "shy".

static func rules() -> Dictionary:
	return Content.rules("base_life")["shy"]

## The Shelter calls this when you adopt: the new Boki starts its shy day.
static func start(rec: Dictionary) -> void:
	if FarmUnlocks.base_mode():
		rec["shy_s"] = float(rules()["secs"])

static func shy(rec: Dictionary) -> bool:
	return float(rec.get("shy_s", 0.0)) > 0.0

## A new Boki appeared on the farm: a shy one steps out of the stone and looks around.
static func arrive(h, k: Dictionary) -> void:
	if not shy(k["rec"]) or h.hway == null:
		return
	var taken: Array = h.kins.map(func(o): return o["pos"])
	taken.append(h.ppos)
	var at: Vector3 = h.world.free_spot_near(h.hway.pad["pos"] + Vector3(0, 0, 1.5), taken, 1.3)
	k["pos"] = at
	(k["node"] as Node3D).position = at
	k["goal"] = Vector3.INF
	h._emote(k, "?")

## Counts the shy day down; when it is over the Boki cheers up and goes to join in.
static func tick(h, k: Dictionary, dt: float) -> void:
	var rec: Dictionary = k["rec"]
	if not shy(rec):
		return
	rec["shy_s"] = float(rec["shy_s"]) - dt
	if float(rec["shy_s"]) <= 0.0:
		rec.erase("shy_s")
		h._emote(k, "♪")
		k["t"] = 0.0

## A shy Boki's walk: the farthest from the island's middle of a few open spots. False when it is not shy.
static func keep_to_edge(h, k: Dictionary) -> bool:
	if not shy(k["rec"]):
		return false
	var isle := maxi(h.world.island_of(k["pos"].x, k["pos"].z), 0)
	var mid: Vector2 = h.world.islands[isle]["c"]
	var far := -1.0
	for i in int(rules()["edge_picks"]):
		var p: Vector3 = h.world.random_ground(isle)
		var d := Vector2(p.x, p.z).distance_to(mid)
		if d > far:
			far = d
			k["goal"] = p
	return true
