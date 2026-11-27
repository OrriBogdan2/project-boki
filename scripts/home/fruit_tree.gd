class_name FruitTree
extends RefCounted
## Fruit trees (content/rules/fruit_trees.json). A tree you put down is a sapling, grows over grow_secs of real time
## (it keeps growing while you are away) and then swells one fruit every fruit_secs; the fruit drops to the grass and
## waits there (at most max_fallen). Walking up to the tree picks the fallen fruit for the pantry, and a hungry Boki
## walks to it and eats one (BaseFeed, "fruit"). The fruit is one of the island's snacks (SnackPatch.zone_snacks),
## rotating each drop. The deco entry holds "pt" (put down; "t" is the building tier, which HomeLayout.ensure clamps),
## "ft" (when the swelling fruit began), "fall" (the fallen fruit ids) and "n" (drops so far). SnackPatch.tick runs
## tick() and SnackPatch.sig / HomeBuild.make_deco call sig() / model(), so the farm redraws the tree as it grows.

const ID := "fruit_tree"
const FALL_R := 0.7  # m: fallen fruit lie in a ring this far from the trunk

static var _seen := {}  # deco uid -> the signature the tree was last drawn with


static func rules() -> Dictionary:
	return Content.rules("fruit_trees")


## Every placed fruit tree's deco entry.
static func trees(d: Dictionary) -> Array:
	return HomeLayout.of(d).get("deco", []).filter(func(e): return String(e.get("id", "")) == ID)


## 0 sapling, 1 young, 2 grown (it fruits).
static func stage(e: Dictionary, now: float) -> int:
	var share := (now - float(e.get("pt", now))) / float(rules()["grow_secs"])
	var at: Array = rules()["stage_at"]
	var s := 0
	for i in at.size():
		if share >= float(at[i]):
			s = i
	return s


## The food the swelling fruit will be: the island's snacks in turn, a different one for each tree.
static func fruit(d: Dictionary, e: Dictionary) -> String:
	var list := SnackPatch.zone_snacks(d)
	return String(list[(int(e.get("u", 0)) + int(e.get("n", 0))) % list.size()])


static func fallen(e: Dictionary) -> Array:
	return e.get("fall", [])


## How far the swelling fruit has come (0..1); a full tree has its fruit ready to drop.
static func swell(e: Dictionary, now: float) -> float:
	if stage(e, now) < 2:
		return 0.0
	if fallen(e).size() >= int(rules()["max_fallen"]):
		return 1.0
	return clampf((now - float(e.get("ft", now))) / float(rules()["fruit_secs"]), 0.0, 1.0)


## Drops every fruit that finished swelling by now. True when one fell.
static func settle(d: Dictionary, e: Dictionary, now: float) -> bool:
	if stage(e, now) < 2:
		return false
	e["ft"] = maxf(float(e.get("ft", 0.0)), float(e["pt"]) + float(rules()["grow_secs"]))
	var fall := fallen(e)
	var dropped := false
	while fall.size() < int(rules()["max_fallen"]) and now - float(e["ft"]) >= float(rules()["fruit_secs"]):
		fall.append(fruit(d, e))
		e["n"] = int(e.get("n", 0)) + 1
		e["ft"] = float(e["ft"]) + float(rules()["fruit_secs"])
		dropped = true
	if fall.size() >= int(rules()["max_fallen"]):
		e["ft"] = now  # a full tree waits: the next fruit starts when one is taken
	e["fall"] = fall
	return dropped


## Takes all the fallen fruit to the pantry. Returns the food ids.
static func pick(d: Dictionary, e: Dictionary) -> Array:
	var got := fallen(e).duplicate()
	for f in got:
		SnackPatch.shelve(d, String(f))
	e["fall"] = []
	return got


## The nearest tree with fruit on the grass (not one `hates`): {"at", "tree": uid}, or {} when there is none.
static func nearest_fallen(d: Dictionary, from: Vector3, hates: String) -> Dictionary:
	var best := {}
	var best_d := INF
	for e in trees(d):
		if fallen(e).any(func(f): return String(f) != hates):
			var at := HomeLayout.deco_center(e)
			var dist := Vector2(at.x - from.x, at.z - from.z).length()
			if dist < best_d:
				best_d = dist
				best = {"at": at, "tree": int(e["u"])}
	return best


## A Boki eats one fruit from tree `uid`: its food id and it leaves the grass, or "" when it is gone.
static func take_one(d: Dictionary, uid: int, hates: String) -> String:
	for e in trees(d):
		if int(e["u"]) == uid:
			var fall := fallen(e)
			for i in fall.size():
				if String(fall[i]) != hates:
					return String(fall.pop_at(i))
	return ""


## Part of the deco signature: the model changes when the tree grows, its fruit swells a quarter or one drops.
static func sig(e: Dictionary) -> String:
	if String(e["id"]) != ID:
		return ""
	var now := Time.get_unix_time_from_system()
	return "f%d%d%d" % [stage(e, now), fallen(e).size(), int(swell(e, now) * 4.0)]


## A little trunk and canopy for the stage, the swelling fruit on a branch and the fallen fruit on the grass.
static func model(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	var now := Time.get_unix_time_from_system()
	var grown := stage(e, now)
	var sc := float(rules()["stage_scale"][grown])
	var bark := Models.toon(Color("6b4a35"))
	var leaf := Models.toon(Color("5f9a45") if grown == 2 else Color("78b04e"))
	Models.part(n, Models.cyl(0.1, 0.17, 1.5 * sc), bark, Vector3(0, 0.75 * sc, 0))
	for c in [[0.0, 1.9, 0.0, 0.9], [0.45, 1.6, 0.2, 0.62], [-0.4, 1.65, -0.25, 0.66]]:
		Models.part(n, Models.sphere(float(c[3]) * sc), leaf, Vector3(c[0], c[1], c[2]) * sc)
	if grown == 2:
		var col := Care.food_col(fruit(Save.d, e))
		var r := lerpf(0.05, 0.2, swell(e, now))
		Models.part(n, Models.sphere(r, 8), Models.toon(col), Vector3(0.62, 1.55, 0.7) * sc)
	var fall := fallen(e)
	for i in fall.size():
		var a := PI * 0.5 + (i - (fall.size() - 1) * 0.5) * 0.7  # in front of the trunk, towards the camera
		var at := Vector3(cos(a) * FALL_R, 0.14, sin(a) * FALL_R)
		Models.part(n, Models.sphere(0.16, 8), Models.toon(Care.food_col(String(fall[i]))), at)
	return n


## Runs every 0.2 s from SnackPatch.tick: starts new trees' clocks, drops fruit, redraws a tree that changed and picks
## the fruit when your feet are by it.
static func tick(h, now: float) -> void:
	var redraw := false
	for e in trees(Save.d):
		if not e.has("pt"):
			e["pt"] = now  # growing starts when it is put down
		settle(Save.d, e, now)
		var c := HomeLayout.deco_center(e)
		if not fallen(e).is_empty() and Vector2(h.ppos.x - c.x, h.ppos.z - c.z).length() <= float(rules()["reach"]):
			var got := pick(Save.d, e)
			h._toast("Picked: " + ", ".join(got.map(func(f): return Care.food_name(f))))
			h.fx.burst(c + Vector3(0, 0.5, 0), Color("ffe08a"), 8, 1.5, 0.4)
		var s := sig(e)
		if _seen.get(int(e["u"]), "") != s:
			_seen[int(e["u"])] = s
			redraw = true
	if redraw:
		h.hb.apply(false)
