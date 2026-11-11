extends RefCounted
## --zone-pool-check: the early zones (tiers 0 and 1) spawn only kin that have a 3D model. Fails when a kin in
## content/zone_pools.json has no Meshy model or rig, is not a species, or sits in two zones. Never touches the save.

const EARLY_TIERS := [0, 1]      # The Meadow, Dusk Isles (Data.TIERS)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("ZONEPOOL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var seen := {}
	for tier in EARLY_TIERS:
		var pool: Array = Data.wild_pool(tier)
		ok(not pool.is_empty(), "tier %d has a wild pool (%d kin)" % [tier, pool.size()])
		for id in pool:
			ok(Data.KIN.has(id), "tier %d: %s is a species" % [tier, id])
			ok(MeshyKin.has(id) or BokiRig.has(id), "tier %d: %s has a 3D model" % [tier, id])
			ok(not seen.has(id), "tier %d: %s is in one zone only" % [tier, id])
			seen[id] = tier
	for id in Data.wild_pool(2):
		ok(not seen.has(id), "tier 2 pool keeps out early-zone kin: %s" % id)
	print("ZONEPOOL DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
