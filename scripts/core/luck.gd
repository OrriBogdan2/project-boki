class_name Luck
extends RefCounted
## Lucky stat gains (content/rules/luck.json, briefs/design/BOKI_PLAYSTYLE_GROWTH.md "Lucky bonus"). Each whole
## point a Boki gains from an expedition (PlayStyle.run_growth) or a stat bite (GardenItems.apply) rolls a lucky
## chance to be worth one more. Luck treats (garden_items.json family luck) raise the chance for a few stat gains:
## any treat a little, the Boki's hidden favourite more, a rare favourite the most. Playing at its favourite toy
## (FavToy) raises it for the next expedition. Luck never makes a gain by itself: callers roll only for points
## already earned, and the extra point stops at the stat's room (the caps still hold).
## State: rec.luck = {add, left} (treat buff), rec.luck_toy (toy buff), rec.luck_n (rolls made, seeds the next).


static func rules() -> Dictionary:
	return Content.rules("luck")


## The treat ids of one kind (rare or common), in data order.
static func treats(rare: bool) -> Array:
	var out: Array = []
	for it in GardenItems.rules()["items"]:
		var e: Dictionary = it["effect"]
		if String(e["kind"]) == "luck" and bool(e["rare"]) == rare:
			out.append(String(it["id"]))
	return out


## The treat this Boki loves most. Hidden until it eats it (known "treat"); fixed by its id.
static func favourite(rec: Dictionary) -> String:
	var r := RandomNumberGenerator.new()
	r.seed = hash(String(rec.get("uid", "x")) + "treat")
	var pool := treats(r.randf() < float(rules()["rare_fav"]))
	return String(pool[r.randi() % pool.size()])


## The tier of treat `id` for this Boki: liked, rare_liked, fav or rare_fav (luck.json tiers).
static func tier(rec: Dictionary, id: String) -> String:
	var rare := bool(GardenItems.item(id)["effect"]["rare"])
	if id == favourite(rec):
		return "rare_fav" if rare else "fav"
	return "rare_liked" if rare else "liked"


## The lucky chance for the next point it gains (run: on an expedition, where the toy buff counts too).
static func chance(rec: Dictionary, run := false) -> float:
	var r := rules()
	var c := float(r["base"]) + float((rec.get("luck", {}) as Dictionary).get("add", 0.0))
	if run and bool(rec.get("luck_toy", false)):
		c += float(r["toy"])
	return minf(c, float(r["cap"]))


## Gains left on the treat buff.
static func left(rec: Dictionary) -> int:
	return int((rec.get("luck", {}) as Dictionary).get("left", 0))


## It eats treat `id`: the buff is set (a weaker treat never lowers a stronger buff still running). Returns
## {text, love, new}: the line the feed shows, whether it was a favourite, and whether this was the first
## time it showed (the favourite is learned by trying, Care.discover "treat").
static func eat(rec: Dictionary, id: String) -> Dictionary:
	var r := rules()
	var t := tier(rec, id)
	var add := float(r["tiers"][t])
	var now: Dictionary = rec.get("luck", {})
	if left(rec) <= 0 or add >= float(now.get("add", 0.0)):
		rec["luck"] = {"add": add, "left": int(r["charges"])}
	else:
		rec["luck"]["left"] = int(r["charges"])
	var love := t.ends_with("fav")
	var out := {"love": love, "new": love and Care.discover(rec, "treat")}
	var nm := String(rec.get("name", "It"))
	var words := "%s adores it!" % nm if love else "%s likes it." % nm
	out["text"] = (
		"%s Lucky chance %d%% for its next %d stat gains" % [words, roundi(chance(rec) * 100.0), int(r["charges"])]
	)
	return out


## The favourite toy was played with: the next expedition's gains get the toy buff.
static func toy_played(rec: Dictionary) -> void:
	rec["luck_toy"] = true


## An expedition has paid its growth: the toy buff is used up.
static func end_run(rec: Dictionary) -> void:
	rec.erase("luck_toy")


## The extra points for `gained` (>0) points it just earned: one roll each at chance(), at most `room` extra.
## Uses one gain of the treat buff. Seeded from the Boki's id and its roll count, so a rerun agrees.
static func bonus(rec: Dictionary, gained: int, room: int, run := false) -> int:
	if gained <= 0:
		return 0
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|luck|%d" % [String(rec.get("uid", "x")), int(rec.get("luck_n", 0))])
	rec["luck_n"] = int(rec.get("luck_n", 0)) + 1
	var c := chance(rec, run)
	var extra := 0
	for i in gained:
		if r.randf() < c:
			extra += 1
	if left(rec) > 0:
		rec["luck"]["left"] = left(rec) - 1
		if left(rec) == 0:
			rec.erase("luck")
	return mini(extra, maxi(room, 0))


## The pop for `extra` lucky points: one point worth +2 instead of +1, or several doubled.
static func words(extra: int) -> String:
	return "Lucky! +2 instead of +1" if extra == 1 else "Lucky! %d points worth double" % extra


## The Boki card's luck line ("" when nothing is running).
static func line(rec: Dictionary) -> String:
	var n := left(rec)
	if n > 0:
		return "Luck up for next %d gains: lucky chance %d%%" % [n, roundi(chance(rec) * 100.0)]
	if bool(rec.get("luck_toy", false)):
		return "Luck up for its next expedition: lucky chance %d%%" % roundi(chance(rec, true) * 100.0)
	return ""
