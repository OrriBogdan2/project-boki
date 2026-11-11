class_name BotShop
extends RefCounted
## What a bot does about shops: with gems to spare and a vendor close, walk there and buy a belt
## item it is short of, or a repair when its armor is worn. It keeps a reserve of gems to take home.

const BUY_REACH := 1.8      # m: a bot buys from a little further out than a player uses the stall

## [goal, "shop"] for a bot that wants to shop, or [].
static func goal(m, h: Hunter) -> Array:
	var best := {}
	var bd: float = float(_bot().get("range", 48.0))
	for v in Shops.list(m):
		var d: float = h.flat_dist(v["pos"])
		if d < bd and not _want(h, v).is_empty() and not (m.lairs and m.lairs.walled_off(h, v["pos"])):
			bd = d
			best = v
	return [best["pos"], "shop"] if not best.is_empty() else []

## Buys what the bot wants when it stands at a vendor. Returns true if it bought something.
static func think(m, h: Hunter) -> bool:
	var v := Shops.vendor_near(m, h, BUY_REACH)
	if v.is_empty():
		return false
	var want := _want(h, v)
	if want.is_empty():
		return false
	return Shops.buy(m, h, v, int(want["i"])) == ""

static func _bot() -> Dictionary:
	return ShopStock.rules().get("bot", {})

## {i: row index} of the row this bot would buy here, or {}.
static func _want(h: Hunter, v: Dictionary) -> Dictionary:
	var cfg := _bot()
	var spare: int = h.gems - int(cfg.get("reserve", 25))
	var rows: Array = v["rows"]
	for i in rows.size():
		var row: Dictionary = rows[i]
		if int(row["left"]) <= 0 or ShopStock.can_buy(h, row) != "" or ShopStock.price(h, row) > spare:
			continue
		var id := ShopStock.ref(String(row["id"]))
		match ShopStock.kind_of(String(row["id"])):
			"repair":
				if h.armor < h.max_armor * float(cfg.get("repair_below", 0.5)):
					return {"i": i}
			"util":
				if (cfg.get("wants", []) as Array).has(id) and ShopStock.owned(h, row) < int(cfg.get("belt_below", 2)):
					return {"i": i}
	return {}
