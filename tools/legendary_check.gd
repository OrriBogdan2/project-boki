extends RefCounted
## --legendary-check: legendary Boki (Legendary, SpawnPlan, content/rules/legendary.json).
##   1. data: every roster species exists and is rare; each map lists 1-3 eligible legendaries
##   2. over MATCHES seeded matches per map, the any-legendary rate is the chance +- TOL, at most one
##      per match (SpawnPlan.legend is one species), always from the map's list, all of them turn up
##   3. the map's legendary_spawn_chance overrides the default (0 never, 1 always)
##   4. the spot is remote: never a live Rare Boki point, never within min_start_dist of a start

const MATCHES := 2000
const TOL := 0.03
const MAPS := ["hollowcrown", "skyreach"]

var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("LEGENDARY %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	_data()
	for map_id in MAPS:
		_rate(World.load_layout(map_id), map_id)
	_rate({}, "generated map")
	_override()
	_spot()
	print("LEGENDARY DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _data() -> void:
	var roster: Array = Legendary.rules()["roster"]
	ok("roster is rare species", roster.all(func(sp): return Data.is_rare(String(sp))), str(roster))
	for map_id in MAPS:
		var list: Array = World.load_layout(map_id).get("legendaries", [])
		var fits := list.size() >= 1 and list.size() <= 3 and list.all(func(sp): return roster.has(sp))
		ok("%s lists 1-3 legendaries from the roster" % map_id, fits, str(list))

func _rate(layout: Dictionary, label: String) -> void:
	var cfg := Legendary.config(layout)
	var holder := Match.new()
	var plan := SpawnPlan.new(holder)
	plan.legend_cfg = cfg
	var hits := 0
	var seen := {}
	var stray := 0
	for s in MATCHES:
		plan.roll(s)
		if plan.legend != "":
			hits += 1
			seen[plan.legend] = true
			if not (cfg["eligible"] as Array).has(plan.legend):
				stray += 1
	holder.free()
	var rate := float(hits) / MATCHES
	var want := float(cfg["chance"])
	ok("%s: any-legendary rate %.3f is %.2f +- %.2f" % [label, rate, want, TOL], absf(rate - want) <= TOL)
	ok("%s: always one species from the map's list" % label, stray == 0)
	var eligible: Array = cfg["eligible"]
	ok("%s: every eligible legendary turns up" % label, seen.size() == eligible.size(), str(seen.keys()))

func _override() -> void:
	var none := {"chance": 0.0, "eligible": ["hivara"]}
	var sure := Legendary.config({"legendary_spawn_chance": 1.0, "legendaries": ["hivara"]})
	var rolled_none := range(200).any(func(s): return Legendary.roll(s, none) != "")
	var rolled_all := range(200).all(func(s): return Legendary.roll(s, sure) == "hivara")
	ok("map chance 0 never spawns, 1 always spawns", not rolled_none and rolled_all)

func _spot() -> void:
	var cands: Array = []
	for i in 6:
		cands.append({"pos": Vector3(i * 30.0, 0, 0), "active": i < 3})
	var starts := [Vector3(0, 0, 0)]
	var near := float(Legendary.rules()["min_start_dist"])
	var bad := 0
	for s in 200:
		var c := Legendary.pick_spot(cands, starts, s)
		if c["active"] or Vector2(c["pos"].x, c["pos"].z).length() < near:
			bad += 1
	ok("spot is a remote point that is not a live Rare Boki one", bad == 0)
	var far_one := Legendary.pick_spot(cands.slice(0, 2), [Vector3(100, 0, 0)], 1)
	ok("no point far enough: takes the farthest", far_one["pos"].x == 0.0)
