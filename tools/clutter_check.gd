extends RefCounted
## --clutter-check: builds the first authored map at every quality preset and counts the scatter batches
## (one draw each) and instances per class. Clutter (short grass, flowers, pebbles, undergrowth, tall
## grass) is thinned to Clutter.KEEP of Ultra's; trees, boulders and pillars are the same on every
## preset (map shapes and cover). Prints one PERF line per preset for before/after numbers.

const PRESETS := ["ultra", "high", "medium", "low", "very_low"]
const SLACK := 0.05      # share: the random thinning lands within this of its target

var main: Node
var fails := 0

func ok(cond: bool, what: String) -> void:
	print("CLUTTER %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	var keep_q = Settings.v.get("quality", "auto")
	var counts := {}
	for p in PRESETS:
		if not Settings.QUALITY.has(p):
			continue
		Settings.v["quality"] = p
		counts[p] = await _count()
		var c: Dictionary = counts[p]
		var row := [p, c["batches"], c["small"], c["bush"], c["big"]]
		print("PERF clutter %s: batches %d, small %d, bush %d, big %d" % row)
	Settings.v["quality"] = keep_q
	var full: Dictionary = counts["ultra"]
	for p in counts:
		var c: Dictionary = counts[p]
		ok(c["big"] == full["big"], "%s keeps every tree, boulder and pillar (%d)" % [p, c["big"]])
		for cls in ["small", "bush"]:
			var want := float(Clutter.KEEP[p][cls])
			var got := float(c[cls]) / maxf(float(full[cls]), 1.0)
			ok(absf(got - want) <= SLACK, "%s keeps %.2f of the %s clutter (target %.2f)" % [p, got, cls, want])
	ok(counts["medium"]["small"] <= full["small"] * 0.5, "medium has at most half of the small clutter")
	print("CLUTTER DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

## Builds the map at the current preset and tallies its scatter batches.
func _count() -> Dictionary:
	var T: Dictionary = Data.TIERS[0]
	var w := World.new()
	w.biome = T["biome"].duplicate()
	w.clouds = T["clouds"]
	main.add_child(w)
	w.generate_authored(World.load_layout(World.layout_for_tier(0)), 9)
	await w.build_meshes()
	var c := {"batches": 0, "small": 0, "bush": 0, "big": 0}
	var stack: Array = [w]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		var mmi := n as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or not n.get_parent().name == "Deco":
			continue
		c["batches"] += 1
		var cls := _class_of(String(n.name))
		c[cls] += mmi.multimesh.instance_count
	w.free()
	return c

## The scatter class of a batch from its name ("<label>_<cx>_<cz>").
func _class_of(batch: String) -> String:
	if batch.begins_with("Bushes"):
		return "bush"
	for big in ["tree", "rock", "pillar"]:
		if batch.begins_with(big):
			return "big"
	return "small"
