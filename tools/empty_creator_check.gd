extends RefCounted
## --empty-creator-check: the Empty's body frame and void body (scripts/match/empty_frame.gd, empty_void.gd,
## content/rules/empty_creator.json). The five sliders clean to 0..1 at the saved step and survive a save round trip;
## an old Short / Average / Tall look becomes the nearest slider values (twice over changes nothing); the sexes'
## shoulder and hip ranges do not overlap; each slider changes the built body; every skin-side part is the void with
## an ink line and no hunter's gear is left on the joints; no cloak shows the bare body and still takes an
## accessory; the creator's Body tab has a slider per frame key and dragging one reshapes the model.

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("EMPTY_CREATOR %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	_frame_data()
	_ranges()
	_body_shape()
	_void_body()
	_no_cloak()
	await _creator()
	print("EMPTY_CREATOR_CHECK %s" % ("FAILED %d" % bad if bad > 0 else "PASSED"))
	main.get_tree().quit(1 if bad > 0 else 0)


func _frame_data() -> void:
	var rough := EmptyFrame.clean({"height": 7, "build": -3, "shoulders": "x", "hips": 0.123456, "extra": 1})
	ok(
		rough == {"height": 1.0, "build": 0.0, "shoulders": 0.5, "hips": 0.123, "head": 0.5},
		"sliders clean to 0..1 at the saved step, a bad or missing one neutral (%s)" % str(rough)
	)
	var old := {"unmasked": true, "gender": 0, "height": 2, "build": 0}
	var u := Unmasked.clean(old)
	ok(
		(
			u["frame"]["height"] == EmptyFrame.OLD_STEPS[2]
			and u["frame"]["build"] == EmptyFrame.OLD_STEPS[0]
			and not u.has("height")
			and not u.has("build")
		),
		"an old Tall, Slight look becomes slider values"
	)
	ok(
		Unmasked.clean(u) == u and Unmasked.clean(JSON.parse_string(JSON.stringify(u))) == u,
		"cleaning twice, or through JSON, changes nothing"
	)
	Save.d["look"] = old.duplicate()
	Unmasked.migrate(Save.d)
	var once: Dictionary = Save.d["look"].duplicate(true)
	Unmasked.migrate(Save.d)
	ok(
		Save.d["look"] == once and Unmasked.default_look()["frame"].size() == EmptyFrame.KEYS.size(),
		"a save migrates to the frame, and a second run changes nothing"
	)
	var rnd := Unmasked.random_look()
	ok(Unmasked.clean(rnd) == rnd, "a random look is already clean (sliders at the saved step)")


func _ranges() -> void:
	var fr: Dictionary = EmptyFrame.rules()["frame"]
	ok(
		(
			float(fr["shoulders"]["f"][1]) < float(fr["shoulders"]["m"][0])
			and float(fr["hips"]["f"][0]) > float(fr["hips"]["m"][1])
		),
		"every woman is narrower in the shoulders and wider in the hips than every man"
	)
	ok(
		(
			EmptyFrame.factor({"gender": 0, "frame": {"height": 1.0}}, "height")
			< EmptyFrame.factor({"gender": 1, "frame": {"height": 1.0}}, "height")
		),
		"her tallest is shorter than his"
	)
	ok(
		EmptyFrame.factor({"gender": 0}, "height") < EmptyFrame.factor({"gender": 1}, "height"),
		"at neutral she is shorter than he is"
	)


## Hand and leg spread and the head's size, from the built rig (the sliders at 0 and 1).
func _spread(lk: Dictionary) -> Array:
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", lk)
	main.add_child(m)
	var hands := m.find_children("Hand", "Node3D", true, false)
	var legs := m.find_children("Leg?", "Node3D", true, false)
	var arms_w := absf(hands[0].global_position.x - hands[1].global_position.x)
	var legs_w := absf(legs[0].global_position.x - legs[1].global_position.x)
	var hollow := m.find_child("Hollow", true, false) as MeshInstance3D  # (the void shell is the head)
	var head_w := hollow.get_aabb().size.x * hollow.global_transform.basis.x.length()
	var out := [arms_w / m.scale.x, legs_w / m.scale.x, head_w]
	m.free()
	return out


func _body_shape() -> void:
	for sex in 2:
		var lo := _spread({"unmasked": true, "gender": sex, "frame": {"shoulders": 0.0, "hips": 0.0, "head": 0.0}})
		var hi := _spread({"unmasked": true, "gender": sex, "frame": {"shoulders": 1.0, "hips": 1.0, "head": 1.0}})
		var tag: String = Unmasked.SEXES[sex]
		ok(hi[0] > lo[0] * 1.05, "%s: shoulders widen the arms' stance (%.2f to %.2f m)" % [tag, lo[0], hi[0]])
		ok(hi[1] > lo[1] * 1.05, "%s: hips widen the legs' stance (%.2f to %.2f m)" % [tag, lo[1], hi[1]])
		ok(hi[2] > lo[2] * 1.03, "%s: head size sizes the head (%.3f to %.3f m)" % [tag, lo[2], hi[2]])


func _void_body() -> void:
	var m := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", {"unmasked": true, "shroud": Shrouds.NONE})
	var parts := 0
	var other := 0
	for node in ["Rig/Torso", "Rig/Legs/LegL", "Rig/Legs/LegL/Knee"]:
		for ch in m.get_node(node).get_children():
			var mi := ch as MeshInstance3D
			if mi == null or mi.mesh == null or mi.name == "Hollow" or mi.get_parent().name == "Head":
				continue
			var mat := mi.material_override as ShaderMaterial
			if mat != null and mat.shader == EmptyVoid.VOID_BODY and mat.next_pass != null:
				parts += 1
			else:
				other += 1
	ok(
		parts >= 3 and other == 0,
		"torso, hips and legs are all void with an ink line (%d parts, %d others)" % [parts, other]
	)
	var hand_parts := m.find_child("Hand", true, false).get_children()
	ok(
		hand_parts.all(func(c: Node) -> bool: return (c as MeshInstance3D).material_override is ShaderMaterial),
		"the hands are the void and the glove cuff is gone"
	)
	ok(m.get_node("Rig/Legs/LegL/Knee").get_child_count() <= 1, "no knee pad or boot cuff on the knee")
	m.free()


func _no_cloak() -> void:
	var bare := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", {"unmasked": true, "shroud": Shrouds.NONE})
	ok(bare.get_node_or_null("Rig/Torso/ShroudBones") == null, "no cloak: nothing drapes the body")
	var kept := Unmasked.clean({"unmasked": true, "shroud": Shrouds.NONE})
	ok(
		kept["shroud"] == Shrouds.NONE and Unmasked.clean({"unmasked": true, "shroud": -9})["shroud"] == Shrouds.NONE,
		"no cloak is a saved choice, and below it clamps to it"
	)
	var scarf := Models.hunter(
		"medium", Data.TEAM_COLORS[0], "", "", {"unmasked": true, "shroud": Shrouds.NONE, "accessory": 2}
	)
	ok(scarf.get_node_or_null("Rig/Torso/ShroudBones") != null, "an accessory still goes on a body with no cloak")
	var cloaked := Models.hunter("medium", Data.TEAM_COLORS[0], "", "", Unmasked.default_look())
	ok(cloaked.get_node_or_null("Rig/Torso/ShroudBones") != null, "a new look still wears the hooded cloak")
	for n in [bare, scarf, cloaked]:
		n.free()


func _creator() -> void:
	Save.d["tutorial"]["intro"] = true
	Save.d["look"] = Unmasked.default_look()
	var hx: Node = load("res://scripts/ui/hatch.gd").new()
	hx.edit_only = true
	main.add_child(hx)
	for i in 3:
		await main.get_tree().process_frame
	var locker: LookLocker = hx.locker
	var sliders: Array = hx.root_ui.find_children("Frame_*", "HSlider", true, false)
	ok(locker != null and sliders.size() == EmptyFrame.KEYS.size(), "the Body tab has a slider per frame key")
	var shoulders := hx.root_ui.find_child("Frame_shoulders", true, false) as HSlider
	var before := locker.model
	shoulders.value = 1.0
	for i in 30:
		await main.get_tree().process_frame
	ok(
		float(locker.look["frame"]["shoulders"]) == 1.0 and locker.model != before,
		"dragging a slider changes the look and rebuilds the model"
	)
	locker.pick("shroud", Shrouds.NONE)
	ok(
		locker.look["shroud"] == Shrouds.NONE and locker.model.get_node_or_null("Rig/Torso/ShroudBones") == null,
		"picking None for the shroud shows the bare body"
	)
	hx.free()
