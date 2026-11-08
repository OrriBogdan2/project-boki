extends RefCounted
## --mob-budget-check: monsters and drops per graphics preset (MobBudget). High keeps today's counts,
## each step down keeps no more, a camp always keeps its lead monster and the gems a kill leaves stay the
## same total in fewer drops; gem nodes are reused; the lowest preset spawns fewer monsters than High.

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("MOBBUDGET %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var camp := ["brute", "skitter", "bomber", "spitter"]
	var prev_k := 2.0
	var prev_drops := 99
	var presets: Array = Settings.QUALITY_ORDER.duplicate()
	presets.reverse()
	for q in presets:
		Settings.v["quality"] = q
		var kept := MobBudget.trim(camp)
		var camp_ok: bool = MobBudget.spawn_k() <= prev_k and kept[0] == "brute" and kept.size() >= 1
		ok(camp_ok, "%s: share %.2f, camp keeps %d, lead first" % [q, MobBudget.spawn_k(), kept.size()])
		var drops_ok: bool = MobBudget.gem_drops(9) <= prev_drops and MobBudget.gem_drops(1) == 1
		ok(drops_ok, "%s: a 9-gem kill leaves %d drops" % [q, MobBudget.gem_drops(9)])
		prev_k = MobBudget.spawn_k()
		prev_drops = MobBudget.gem_drops(9)
	Settings.v["quality"] = "high"
	ok(MobBudget.trim(camp).size() == camp.size() and MobBudget.count(6) == 6, "high keeps every monster")
	Settings.v["quality"] = "medium"
	ok(MobBudget.trim(["skitter", "bomber", "spitter"]).size() == 3, "medium keeps a three-monster camp full")
	var scale_ok: bool = MobBudget.gem_scale(3) == 1.0 and MobBudget.gem_scale(30) <= MobBudget.GEM_SCALE_MAX
	ok(scale_ok, "a bigger drop is drawn bigger, within the cap")
	await _pool()
	await _match_counts()
	print("MOBBUDGET DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _pool() -> void:
	var host := Node3D.new()
	main.add_child(host)
	var pool := NodePool.new()
	var a := pool.take(Models.gem)
	host.add_child(a)
	pool.give(a)
	ok(not a.visible, "a given-back node is hidden")
	var b := pool.take(Models.gem)
	ok(b == a and b.visible and b.get_parent() == host, "the next take reuses it, in place")
	var spares := MobSpares.new()
	host.add_child(spares)
	var first := spares.take("skitter")
	ok(first != null and spares.ready("skitter") == 0, "the first monster of a kind is built on the spot")
	for i in MobSpares.EVERY * 3: await main.get_tree().process_frame
	var n := spares.ready("skitter")
	ok(n > 0 and n <= MobSpares.TARGET, "spares of a met kind are built in the background (%d ready)" % n)
	var model := spares.take("skitter")
	var handed: bool = model.get_parent() == null and spares.ready("skitter") == n - 1
	ok(handed, "a spare is handed out unparented, ready for the monster")
	model.free()
	var own: bool = not MobSpares.plain("colossus") and not MobSpares.plain("shrubling") and MobSpares.plain("skitter")
	ok(own, "bosses and shrublings keep their own builders")
	host.queue_free()

## A built expedition's monsters at the lowest preset against High (the same seed).
func _match_counts() -> void:
	var n := {}
	for q in ["high", Settings.QUALITY_ORDER[0]]:
		Settings.v["quality"] = q
		var o := Match.demo_opts()
		o.merge({"teams": 2, "squad": 1, "total": 2, "no_drop": true, "god": true, "seed": 4101}, true)
		o.erase("demo_match")
		o.erase("fresh_t")
		Game.goto("match", o)
		var m: Match = null
		while m == null:
			await main.get_tree().process_frame
			var cur := main.current as Match
			if cur != null and cur.is_processing() and cur.hud != null:
				m = cur
		n[q] = m.mobs.size()
		m.drop("gem", m.player.pos, 3)
		var first: Node3D = m.pickups[-1]["node"]
		m._release_pickup(m.pickups[-1])
		m.drop("gem", m.player.pos, 3)
		ok(m.pickups[-1]["node"] == first, "%s: a dropped gem reuses the node a collected one left" % q)
	var low: String = Settings.QUALITY_ORDER[0]
	ok(n[low] < n["high"], "%s spawns fewer monsters than high (%d vs %d)" % [low, n[low], n["high"]])
