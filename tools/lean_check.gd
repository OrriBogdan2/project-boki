extends RefCounted
## --lean-check: food lean by type (scripts/core/lean.gd, farm_build.json base_mode + lean.json). Every
## food has a type and every type's part is a real one. base_mode is off by default and then Evo.eat is
## the old four-affinity lean. With it on, 3 Fire snacks (Emberberry) to a fresh Prismander (puddlet) raise
## its fire lean, shift its tint, show a mark after one meal, and its next form grows the Fire part (horns).
## Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LEAN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _tint(root: Node3D) -> Color:
	return ((root.get_meta("mats", []) as Array)[0] as ShaderMaterial).get_shader_parameter("albedo")

func _gap(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _marks(root: Node3D) -> int:
	return root.find_children("LeanMark*", "MeshInstance3D", true, false).size()

## Names of the grown parts the rigged model shows.
func _parts(root: Node3D) -> Array:
	var skel := (root.get_node("Body/Flex/BokiRig") as BokiRig).skeleton()
	var dna := skel.find_children("*", "BokiDna", false, false)[0] as BokiDna
	return dna.shown.map(func(p: Array) -> String: return skel.get_bone_name(int(p[0])))

func _data() -> void:
	var types: Dictionary = Lean.rules()["types"]
	ok(types.size() == 18, "18 types (%d)" % types.size())
	var foods: Array = Data.CROPS.keys() + Care.FOODS.keys()
	var typed: Dictionary = Lean.rules()["foods"]
	var untyped := foods.filter(func(f): return not types.has(String(typed.get(f, ""))))
	ok(untyped.is_empty(), "every food has a type (%d foods; untyped: %s)" % [foods.size(), untyped])
	var bad_parts := types.keys().filter(func(t): return not KinParts.EVO_PARTS.has(types[t].get("part", "horns")))
	ok(bad_parts.is_empty(), "every type's part is a grown part (%s)" % str(bad_parts))

func _raise() -> void:
	var rec := Save.new_kin("puddlet", "Prisma")
	var m0 := Models.kin("puddlet", rec)
	var c0 := _tint(m0)
	ok(_marks(m0) == 0 and _parts(m0).is_empty(), "a fresh Prismander has no mark and no part")
	Evo.eat(rec, "emberberry")
	var m1 := Models.kin("puddlet", rec)
	var fire: Color = Lean.face("fire")["tint"]
	ok(float(rec["lean"]["fire"]) > 0.0 and _marks(m1) >= 1 and _gap(_tint(m1), fire) < _gap(c0, fire),
		"one Fire snack: lean %.0f, a mark, and the tint moves toward Fire" % float(rec["lean"]["fire"]))
	for i in 2:
		Evo.eat(rec, "emberberry")
	var m2 := Models.kin("puddlet", rec)
	var ln := Evo.lean(rec)
	ok(String(ln[0]) == "fire" and float(ln[1]) > 0.8, "3 Fire snacks: it leans Fire (%.0f%%)" % (100.0 * float(ln[1])))
	ok(_gap(_tint(m2), fire) < _gap(_tint(m1), fire) and _marks(m2) > _marks(m1),
		"more tint and more marks (%d, then %d)" % [_marks(m1), _marks(m2)])
	ok(_parts(m2).is_empty(), "but no part before a form")
	rec["level"] = int(Evo.rules()["lines"]["puddlet"]["level"])      # its line's form level (evolve.json)
	var ev := Evo.on_level(rec)
	var m3 := Models.kin("puddlet", rec)
	var said := Evo.describe(ev, rec)
	ok(ev.get("lean_part", "") == "horns" and _parts(m3) == ["part_horns"] and said.contains("fire meals grew horns"),
		"its next form grows the Fire part: %s" % said)
	ok(Evo.eat(rec, "kibble") == "" and String(Evo.lean(rec)[0]) == "fire", "plain food leaves the lean alone")
	for i in 4:
		Evo.eat(rec, "tidebloom")
	ok(String(Evo.lean(rec)[0]) == "water", "four Tideblooms later the lean is Water")
	for m in [m0, m1, m2, m3]:
		m.free()

## Every rigged species has what the lean draws on: the head frame (FRAME head and top) for the flecks and, in its
## model, a bone for each type's part (BokiDna.part_bone).
func _anchors() -> void:
	var parts: Array = []
	for t in Lean.rules()["types"].values():
		if t.has("part") and not parts.has(t["part"]):
			parts.append(t["part"])
	var missing: Array = []
	var rigged := 0
	for sp in BokiRig.FRAME:
		if not Evo.has_art(sp):
			continue
		rigged += 1
		var fr: Dictionary = BokiRig.FRAME[sp]
		for key in ["head", "top"]:
			if not fr.has(key):
				missing.append("%s FRAME %s" % [sp, key])
		var model := (load(BokiRig.PATH % [sp, sp]) as PackedScene).instantiate()
		var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for part in parts:
			if skel.find_bone(BokiDna.part_bone(part, skel)) < 0:
				missing.append("%s %s" % [sp, BokiDna.part_bone(part, skel)])
		model.free()
	ok(rigged >= 10 and missing.is_empty(),
		"every rigged species (%d) has the lean's anchors (missing: %s)" % [rigged, missing])

func run(main: Node) -> void:
	Save.no_write = true
	_data()
	_anchors()
	ok(not Lean.on() and Evo.eat(Save.new_kin("puddlet"), "emberberry") == "fierce",
		"base_mode is off by default and meals lean the old way")
	FarmUnlocks.rules()["base_mode"] = true
	_raise()
	FarmUnlocks.rules()["base_mode"] = false
	print("LEAN DONE, failures: %d" % bad)
	main.get_tree().quit()
