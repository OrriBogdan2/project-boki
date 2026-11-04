extends RefCounted
## --unmasked-check: the Unmasked (scripts/match/unmasked.gd). Old detailed looks (every race and face, odd
## data) become the closest valid Unmasked and never crash; a save's look migrates; the model builds for every
## body and outfit, has no hair, animates with HunterAnim and shows kept mask marks; a match and the hero
## screens use the Warden's look, never yours.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("UNMASKED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _verts(n: Node) -> int:
	var t := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for sidx in mesh.get_surface_count():
			t += (mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return t

func _build(lk: Dictionary) -> Node3D:
	return Models.hunter("medium", Data.TEAM_COLORS[0], "smg", "", lk)

func _in_lists(u: Dictionary) -> bool:
	for row in Unmasked.ROWS:
		if int(u[row[0]]) < 0 or int(u[row[0]]) >= (row[2] as Array).size():
			return false
	return true

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var tree := main.get_tree()
	_old_looks()
	_model(main)
	await _anim(main)
	_who_shows()
	_blend(main)
	print("UNMASKED CHECK DONE, failures: %d" % bad)
	tree.quit()

func _old_looks() -> void:
	var valid := true
	var cases := 0
	for race in Models.RACES.size():
		for face in Models.LOOK_FACES.size():
			var old := {"race": race, "face": face, "gender": face % 2, "body": race % 3, "skin": face * 2,
				"outfit": face, "hair": 5, "glider": "classic"}
			valid = valid and _in_lists(Unmasked.clean(old))
			cases += 1
	ok(valid, "%d old looks (every race x face) clean to values inside every list" % cases)
	var bad_old := {"race": 99, "face": -4, "gender": "x", "body": 1e9, "outfit": null, "skin": 500, "marks": "no"}
	var junk := Unmasked.clean(bad_old)
	ok(Unmasked.is_look(junk) and junk["marks"] is Array and _in_lists(junk),
		"garbage in an old look still gives a whole Unmasked")
	ok(Unmasked.clean({}) == Unmasked.default_look(), "no look gives the default")
	var old := {"race": 2, "gender": 0, "body": 2, "face": 4, "skin": 5, "outfit": 1, "hair": 3, "glider": "kite"}
	var u := Unmasked.clean(old)
	var want := [0, 2, 2, 4, 4]
	var got := [u["gender"], u["build"], u["height"], u["eyes"], u["brows"]]
	ok(got == want,
		"an old Stoneborn sturdy fierce look keeps gender and build, reads tall, with narrow eyes and furrowed brows")
	ok(String(u["glider"]) == "kite" and not u.has("race") and not u.has("hair"), "the glider stays; race and hair go")
	ok(Unmasked.clean(u) == u, "cleaning an Unmasked changes nothing")
	var data := {"look": old.duplicate()}
	Unmasked.migrate(data)
	var once: Dictionary = data["look"].duplicate(true)
	Unmasked.migrate(data)
	ok(Unmasked.is_look(data["look"]) and data["look"] == once,
		"a save's look migrates, and a second run changes nothing")
	Unmasked.migrate({})
	var json := {"look": JSON.parse_string(JSON.stringify(old))}
	Unmasked.migrate(json)
	ok(Unmasked.is_look(json["look"]), "a look read back from JSON migrates")

func _model(main: Node) -> void:
	var bodies := 0
	for g in 2:
		for o in Unmasked.OUTFITS.size():
			var lk := {"unmasked": true, "gender": g, "outfit": o, "eyes": o, "brows": o, "colour": o * 2}
			var m := _build(Unmasked.clean(lk))
			if m.get_node_or_null("Rig/Torso") != null and m.get_node_or_null("Rig/Legs") != null:
				bodies += 1
			m.free()
	ok(bodies == 10, "all 2 genders x %d outfits build on the hunter rig" % Unmasked.OUTFITS.size())
	var base := _build(Unmasked.default_look())
	var rig_ok := String(base.get_meta("race")) == "human" and String(base.get_meta("arch")) == "unmasked"
	ok(rig_ok, "it is the human rig with no hunter's gear (arch %s)" % base.get_meta("arch"))
	var tall := _build({"unmasked": true, "height": 2})
	var short := _build({"unmasked": true, "height": 0})
	ok(tall.scale.y > base.scale.y and base.scale.y > short.scale.y,
		"height scales the body (%.2f / %.2f / %.2f)" % [short.scale.y, base.scale.y, tall.scale.y])
	var slight := _verts(_build({"unmasked": true, "build": 0}))
	ok(slight > 0 and _verts(_build({"unmasked": true, "build": 2})) > 0, "every build has a body")
	var marked := _build({"unmasked": true, "marks": [{"x": 0.0, "y": 0.9, "col": "#ff4040"}]})
	ok(_verts(marked) > _verts(base), "a kept mask mark is drawn (%d > %d vertices)" % [_verts(marked), _verts(base)])
	var hair := base.get_node_or_null("Rig/Torso/HeadPivot/Hair")
	ok(hair == null or _verts(hair) == 0, "no hair on the Unmasked")
	main.add_child(base)
	for m in [tall, short, marked]:
		m.free()

func _anim(main: Node) -> void:
	var base := main.get_child(main.get_child_count() - 1) as Node3D
	var anim := HunterAnim.new(base)
	for i in 30:
		anim.update(1.0 / 60.0, {"fired": 99.0, "face": 0.0})
		await main.get_tree().process_frame
	ok(is_instance_valid(base), "the hunter animations run on it")
	base.queue_free()

func _who_shows() -> void:
	var fresh := Unmasked.mask_look()
	ok(not Unmasked.is_look(fresh) and fresh == _with_glider(Models.default_look()),
		"a new save's Warden look is the plain default, as on main")
	var old := {"race": 2, "gender": 0, "face": 4, "hair": 1, "skin": 5, "glider": "kite"}
	Save.d["look"] = old.duplicate()
	Unmasked.migrate(Save.d)
	var warden := Unmasked.mask_look()
	var same: bool = int(warden["race"]) == 2 and int(warden["face"]) == 4 and warden["glider"] == "kite"
	ok(not Unmasked.is_look(warden) and same, "a migrated save's Warden keeps its old race, face and glider")
	ok(Unmasked.is_look(Unmasked.worn()) and not Unmasked.is_look(Unmasked.mask_look()),
		"the farm wears you as the Unmasked, a match wears the Warden")

func _with_glider(lk: Dictionary) -> Dictionary:
	lk["glider"] = "classic"
	return lk

func _blend(main: Node) -> void:
	Save.d["look"] = {"unmasked": true, "eyes": 5, "height": 2, "build": 2, "colour": 9, "marks": []}
	ok(int(Unmasked.worn_look()["face"]) == Unmasked.FACE_FOR_EYES[5], "your eyes show behind the mask")
	var hero := Models.hunter("medium", Data.TEAM_COLORS[0], "smg", "", Unmasked.worn_look(), "gunslinger")
	var before_scale := hero.scale
	var mat := (hero.get_meta("mats") as Array)[0] as ShaderMaterial
	var tint_before: Color = mat.get_shader_parameter("albedo")
	Unmasked.blend(hero)
	var tint_after: Color = mat.get_shader_parameter("albedo")
	ok(hero.scale.y > before_scale.y and hero.scale.y < before_scale.y * 1.09 and hero.scale.x > before_scale.x,
		"the mask keeps about 90%% Warden: height and build show a tenth (%.3f x)" % (hero.scale.y / before_scale.y))
	var want := tint_before.lerp(Unmasked.colour(Save.d["look"]), Unmasked.SHOW)
	ok(tint_after.is_equal_approx(want), "and your body colour tints the Warden a tenth")
	hero.free()
