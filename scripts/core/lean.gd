class_name Lean
## The base's food lean (briefs/design/GARDEN.md section 3, lever 1). With base_mode on (FarmUnlocks, farm_build.json),
## every food has one of the 18 types (content/rules/lean.json) and its meals lean a Boki to that type
## (rec["lean"], one key per type): the body takes the type's tint (Evo.dress), a few flecks of its colour
## show over the head within a meal or two (mark), and the next form grows the type's part (grow_part).
## With it off, Evo.eat keeps the four affinities and nothing here runs.

static func rules() -> Dictionary:
	return Content.rules("lean")

static func on() -> bool:
	return FarmUnlocks.base_mode()

## The type a meal of food f leans a Boki to: "" when it has none (Normal food never leans).
static func key_of(f: String) -> String:
	var t := String(rules()["foods"].get(f, ""))
	return t if (rules()["types"].get(t, {}) as Dictionary).has("tint") else ""

## {name, tint} of a lean key: a type, or (before base_mode) an Evo affinity.
static func face(key: String) -> Dictionary:
	var t: Dictionary = rules()["types"].get(key, {})
	if t.is_empty():
		return Evo.AFF[key]
	return {"name": t["name"], "tint": Color(String(t["tint"]))}

## Flecks of the lean's colour over the head; more as the lean grows (strength 0..1).
static func mark(flex: Node3D, key: String, strength: float) -> void:
	var rig := flex.get_node_or_null("BokiRig") as BokiRig
	var fr: Dictionary = BokiRig.FRAME.get(rig.species, {}) if rig else {}
	var top := float(fr.get("top", 0.72))
	var head_z: float = (fr["head"] as Vector3).z if fr.has("head") else -0.2
	var mat := Models.toon(face(key)["tint"], false, 0.9)
	var n := clampi(ceili(strength * int(rules()["marks"])), 1, int(rules()["marks"]))
	for i in n:
		var a := (float(i) - (n - 1) * 0.5) * 0.8
		var at := Vector3(sin(a) * 0.2, top + 0.05 + 0.02 * cos(a), head_z * 0.5)
		Models.part(flex, Models.sphere(0.035, 6), mat, at, Vector3.ONE, Vector3.ZERO, "LeanMark%d" % i)

## At a form: the part its lean has earned (a first one, or the same part one size bigger). Returns the
## part id, "" when base_mode is off or the lean is too weak.
static func grow_part(rec: Dictionary) -> String:
	var ln := Evo.lean(rec)
	var key := String(ln[0])
	var part := String(rules()["types"].get(key, {}).get("part", ""))
	if not on() or part == "" or float(ln[1]) < float(rules()["part_min"]):
		return ""
	for m in rec["muts"]:
		if m["id"] == part:
			m["lv"] = int(m["lv"]) + 1
			return part
	rec["muts"].append({"id": part, "lv": 1, "aff": key})
	return part
