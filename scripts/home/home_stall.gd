class_name HomeStall
extends RefCounted
## Every save has a market stall (docs/decisions/0013-market.md). A farm-start island with none placed
## or stored gets one set down near the portal when it loads (a new island, or an older save):
## searching outward from the landing, every rotation, for a spot build mode would accept. If
## nothing fits it waits in storage, with a one-time hint.

const SEARCH_R := 14        # tiles out from the landing

## Places the stall if the island has none. True if the layout changed.
static func ensure(home) -> bool:
	var d: Dictionary = home._d()
	var lay := HomeLayout.of(d)
	if not HomeLayout.fs(d) or HomeLayout.count_of("market_stall", d) > 0:
		return false
	var spot := _spot(home.hb)
	if spot.is_empty():
		lay["inv"]["market_stall"] = 1
		HomeBuild.pending_toast = "Your market stall is in storage: set it down in build mode (Buildings)"
		return true
	var e := {"u": HomeLayout._next_uid(lay), "id": "market_stall", "x": int(spot["x"]), "z": int(spot["z"]),
		"r": int(spot["r"]), "t": 1}
	(lay["deco"] as Array).append(e)
	home.hb._apply_blockers()
	home.hb._reach_cache.clear()
	home._fixture_spots()
	HomeBuild.pending_toast = "Your market stall is set up by the portal: the Market on the hub bar opens it too"
	return true

## The nearest spot to the landing where the stall fits: {x, z, r}, or {} when none does.
static func _spot(hb: HomeBuild) -> Dictionary:
	var from := Vector2i(int(floor(HomeLayout.LANDING.x)), int(floor(HomeLayout.LANDING.z)))
	for rad in range(2, SEARCH_R + 1):
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dz)) != rad: continue
				for r in 4:
					var sz := HomeLayout.size_of("market_stall", r)
					var x := from.x + dx
					var z := from.y + dz
					var cells := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
					if hb.fits({"kind": "deco", "id": "market_stall", "r": r, "from": -1}, cells):
						return {"x": x, "z": z, "r": r}
	return {}
