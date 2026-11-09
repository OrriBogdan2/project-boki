extends RefCounted
## --lean-parts-check: the lean's part at a form (scripts/core/lean.gd grow_part, base_mode on). Every one of
## the 18 types, leaned past part_min, grows its own part at the next form and the rigged model shows that
## bone; a weak lean, Normal and base_mode off grow none; a second form makes the part bigger; the Boki
## card's line says what it grew or will grow. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		print("LEAN-PARTS FAIL %s" % what)
		bad += 1

func _leaned(type: String, strength: float) -> Dictionary:
	var rec := Save.new_kin("puddlet", "Prisma")
	rec["lean"] = {type: Evo.LEAN_FULL * strength}
	rec["level"] = 4
	return rec

## Bone names of the parts the rigged model shows.
func _shown(rec: Dictionary) -> Array:
	var k := Models.kin("puddlet", rec)
	var skel := (k.get_node("Body/Flex/BokiRig") as BokiRig).skeleton()
	var dna := skel.find_children("*", "BokiDna", false, false)[0] as BokiDna
	var out := dna.shown.map(func(p: Array) -> String: return skel.get_bone_name(int(p[0])))
	k.free()
	return out

func _each_type() -> void:
	var types: Dictionary = Lean.rules()["types"]
	var seen := {}
	for t in types:
		var part := String(types[t].get("part", ""))
		var rec := _leaned(t, 1.0)
		var ev := Evo.on_level(rec)
		if part == "":
			ok(not ev.has("lean_part") and rec["muts"].is_empty(), "%s has no part and grows none" % t)
			continue
		seen[part] = true
		ok(ev.get("lean_part", "") == part and rec["muts"].size() == 1 and rec["muts"][0]["aff"] == t, "%s grows %s at a form" % [t, part])
		ok(_shown(rec) == ["part_" + part], "%s: the model shows part_%s (%s)" % [t, part, _shown(rec)])
		ok(Lean.card_line(rec).begins_with(String(types[t]["name"])) and Lean.card_line(rec).contains("grew"), "%s card line says it grew (%s)" % [t, Lean.card_line(rec)])
	ok(seen.size() >= 12, "the 17 typed leans use at least 12 different parts (%d)" % seen.size())

func _rules() -> void:
	var weak := _leaned("fire", 0.2)
	ok(Evo.on_level(weak).get("lean_part", "") == "" and weak["muts"].is_empty(), "a Fire lean under part_min grows no part")
	ok(Lean.card_line(weak).begins_with("More Fire meals"), "weak lean card line says what more meals grow (%s)" % Lean.card_line(weak))
	var strong := _leaned("fire", 0.5)
	ok(Lean.card_line(strong).begins_with("Next form: Fire meals grow horns"), "strong lean card line names the next part (%s)" % Lean.card_line(strong))
	Evo.on_level(strong)
	strong["level"] = 8
	ok(Evo.on_level(strong).get("lean_part", "") == "horns" and strong["muts"][0]["lv"] == 2, "a second form makes the horns bigger")
	ok(Evo.describe({"kind": "form", "aff": "fierce", "from": "a", "to": "b", "lean_part": "horns"}, strong).contains("grew horns"), "the form's line names the part")
	var steady := _leaned("fire", 1.0)
	steady["level"] = 2
	Evo.on_level(steady)
	ok(not steady["muts"].any(func(m): return m["aff"] == "fire"), "a non-form level grows no lean part")
	FarmUnlocks.rules()["base_mode"] = false
	var off := _leaned("fire", 1.0)
	ok(Evo.on_level(off).get("lean_part", "") == "" and off["muts"].is_empty() and Lean.card_line(off) == "", "base_mode off: no part, no card line")

func run(main: Node) -> void:
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	_each_type()
	_rules()
	FarmUnlocks.rules()["base_mode"] = false
	print("LEAN-PARTS DONE, failures: %d" % bad)
	main.get_tree().quit()
