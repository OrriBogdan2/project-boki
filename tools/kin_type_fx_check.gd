extends RefCounted
## --kin-type-fx-check: every Boki type has its own cast accent (KinTypeFx): all 18 types covered, no two
## share a colour or a shape, each stays inside the particle budget, and a real cast plays it.
## Never touches the save.

const MIN_COLOUR_GAP := 0.12     # RGB distance between two types' accent colours
const MAX_DOTS := 10             # full-quality dots per cast
const MAX_STREAKS := 8
const MAX_RINGS := 3

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("KINTYPEFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Dots / streaks / rings and their motion, with the colour left out: two types with the same one look alike.
func _shape(look: Dictionary) -> String:
	var parts := []
	for key in ["dots", "streaks", "rings"]:
		parts.append(str(look.get(key, "")))
	return "|".join(parts)

func run(main: Node) -> void:
	Save.no_write = true
	var types: Array = KinParts.THEMES.filter(func(t): return t != "none")
	ok(types.size() == 18, "18 Boki types (%d)" % types.size())
	ok(KinTypeFx.LOOKS.size() == types.size(), "one accent per type (%d)" % KinTypeFx.LOOKS.size())
	var shapes := {}
	var names: Array = KinTypeFx.LOOKS.keys()
	for t: String in types:
		var look: Dictionary = KinTypeFx.LOOKS.get(t, {})
		ok(not look.is_empty(), "%s has an accent" % t)
		if look.is_empty(): continue
		var dots := int((look.get("dots", {}) as Dictionary).get("n", 0))
		var streaks := int((look.get("streaks", {}) as Dictionary).get("n", 0))
		var rings := (look.get("rings", []) as Array).size()
		var fits := dots <= MAX_DOTS and streaks <= MAX_STREAKS and rings <= MAX_RINGS
		ok(fits, "%s inside the budget (%d dots, %d streaks, %d rings)" % [t, dots, streaks, rings])
		ok(dots + streaks + rings > 0, "%s plays something" % t)
		ok(not shapes.has(_shape(look)), "%s has its own shape" % t)
		shapes[_shape(look)] = t
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a := Color(String(KinTypeFx.LOOKS[names[i]]["col"]))
			var b := Color(String(KinTypeFx.LOOKS[names[j]]["col"]))
			var gap := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			ok(gap >= MIN_COLOUR_GAP, "%s and %s colours differ (%.2f)" % [names[i], names[j], gap])
	var fx := Fx.new()
	main.add_child(fx)
	var si0 := fx.si
	KinTypeFx.play(fx, "electric", Vector3.ZERO, Vector2.RIGHT)
	ok(fx.si == si0 + 1, "electric plays a streak pool entry")
	var rings0 := fx.rings.size()
	KinTypeFx.play(fx, "psychic", Vector3.ZERO, Vector2.RIGHT)
	ok(fx.rings.size() == rings0 + 2, "psychic plays two ripples")
	var bi0 := fx.bi
	KinTypeFx.play(fx, "none", Vector3.ZERO, Vector2.RIGHT)
	ok(fx.bi == bi0 and fx.si == si0 + 1, "an unknown type plays nothing")
	rings0 = fx.rings.size()
	for ty: String in KinTypeFx.LOOKS:
		KinTypeFx.fusion(fx, ty, Vector3.ZERO, Color.WHITE, 3.0)
	ok(fx.rings.size() == rings0, "a Fusion moment of any type draws no ground ring")
	ok(fx.si > si0 + 1, "a Fusion moment plays streaks, even for the ring-only Sound type")
	fx.queue_free()
	await _cast_test(main)
	print("KINTYPEFX DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _cast_test(main: Node) -> void:
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	var k: Kin = m.player.kin
	ok(k != null, "the player has a Boki")
	if k == null: return
	var type := String(k.sp.get("type", ""))
	ok(KinTypeFx.LOOKS.has(type), "its type '%s' has an accent" % type)
	var before := m.fx.bi + m.fx.si + m.fx.rings.size()
	k._cast("k1", k.pos + Vector3(3, 0, 0), true, k, 1.0)
	ok(m.fx.bi + m.fx.si + m.fx.rings.size() > before, "casting an ability plays the accent")
