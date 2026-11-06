extends RefCounted
## --unmasked-check: the Empty (scripts/match/unmasked.gd). Old detailed looks (every race and face, odd
## data) and face-marks looks (eyes, brows, blush) become the closest valid Empty and never crash; a save's look
## migrates (an old skin colour becomes the shroud colour); the creator says Male / Female, has no skin colour
## and an Aura row with a tooltip; the model builds for every body and shroud style with a void head (the void
## shader, all the way round), no skin showing, an aura of big bright specks, no hair; its soles stay on the
## ground at every height and build, idle and walking; height visibly changes the body's height, build its
## mass, and a woman's silhouette and stance differ from a man's; it animates with HunterAnim and shows kept
## mask marks; a match and the Hunter screens use the Hunter's look, never yours.

const FOOT_TOLERANCE := 0.02     # m: how far the lowest foot point may sit above or below the ground

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
	await _feet(main)
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
	var want := [0, 2, 2, Unmasked.HOLLOW_FROM_EYES[4], Unmasked.GHOST_FROM_BROWS[4]]
	var got := [u["gender"], u["build"], u["height"], u["hollow"], u["ghost"]]
	ok(got == want and not u.has("eyes") and not u.has("brows") and not u.has("blush"),
		"an old Stoneborn sturdy fierce look keeps sex and build, reads tall, its face a hollow (%s)" % str(got))
	var marks_look := {"unmasked": true, "gender": 1, "eyes": 2, "brows": 1, "blush": 2, "outfit": 3, "colour": 4}
	var m2 := Unmasked.clean(marks_look)
	ok(m2["hollow"] == Unmasked.HOLLOW_FROM_EYES[2] and m2["ghost"] == Unmasked.GHOST_FROM_BROWS[1]
		and m2["glow"] == 3 and m2["shroud"] == 0 and not m2.has("eyes") and _in_lists(m2),
		"a face-marks look (eyes, brows, blush) migrates to a hollow, ghost and glow, keeping the rest")
	var sexes: Array = Unmasked.ROWS[0][2]
	ok(String(Unmasked.ROWS[0][1]) == "Sex" and sexes == ["Female", "Male"] and not str(Unmasked.ROWS).contains("emin")
		and not str(Unmasked.ROWS).contains("ascul"), "the creator says Male / Female (%s)" % str(sexes))
	ok(String(u["glider"]) == "kite" and not u.has("race") and not u.has("hair"), "the glider stays; race and hair go")
	ok(Unmasked.clean(u) == u, "cleaning an Unmasked changes nothing")
	_shroud_migration()
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
		for o in Unmasked.SHROUDS.size():
			var lk := {"unmasked": true, "gender": g, "shroud": o, "hollow": o % 4, "ghost": o % 4, "glow": o,
				"colour": o * 2}
			var m := _build(Unmasked.clean(lk))
			if m.get_node_or_null("Rig/Torso") != null and m.get_node_or_null("Rig/Legs") != null:
				bodies += 1
			m.free()
	ok(bodies == 2 * Unmasked.SHROUDS.size(),
		"both sexes x %d shroud styles build on the hunter rig" % Unmasked.SHROUDS.size())
	var base := _build(Unmasked.default_look())
	var rig_ok := String(base.get_meta("race")) == "human" and String(base.get_meta("arch")) == "unmasked"
	ok(rig_ok, "it is the human rig with no hunter's gear (arch %s)" % base.get_meta("arch"))
	var tall := _build({"unmasked": true, "height": 2})
	var short := _build({"unmasked": true, "height": 0})
	var tops := [_top(short), _top(base), _top(tall)]
	ok(tops[2] > tops[1] * 1.07 and tops[1] > tops[0] * 1.07,
		"height changes how tall the model stands, by about a tenth a step (%.2f / %.2f / %.2f m)" % tops)
	ok(tall.get_node("TeamRing").scale.x < short.get_node("TeamRing").scale.x * 1.01,
		"the ring under your feet (your real footprint) stays the size it was")
	var hollow := base.find_child("Hollow", true, false) as MeshInstance3D
	var void_mat: ShaderMaterial = hollow.material_override if hollow else null
	var head := base.find_child("Head", true, false) as MeshInstance3D
	ok(void_mat != null and void_mat.shader == Unmasked.VOID_SHADER and hollow.get_parent().name == "Head"
		and hollow.get_aabb().size.z > 0.3 and head.mesh.get_surface_count() == 0 and hollow.scale.x > 1.0,
		"the whole head is a void: a shell over all of the head mesh, not just the front of the face")
	ok(base.find_child("Heart", true, false) == null, "the chest is under the shroud: no heart pasted on it")
	_shroud()
	_aura()
	var styled := _build({"unmasked": true, "hollow": 2, "ghost": 3, "glow": 2})
	var sm: ShaderMaterial = (styled.find_child("Hollow", true, false) as MeshInstance3D).material_override
	ok(int(sm.get_shader_parameter("shape")) == 2 and int(sm.get_shader_parameter("ghost")) == 3
		and (sm.get_shader_parameter("glow") as Color).is_equal_approx(Unmasked.GLOWS[2]),
		"the hollow's shape, ghost features and glow follow the look")
	var woman := _build({"unmasked": true, "gender": 0})
	var man := _build({"unmasked": true, "gender": 1})
	var w_sh := (woman.get_node("Rig/Torso/ArmLPivot") as Node3D).position.x
	var m_sh := (man.get_node("Rig/Torso/ArmLPivot") as Node3D).position.x
	var flare := _width(woman.get_node("Rig/Torso/ShroudBones")) > _width(man.get_node("Rig/Torso/ShroudBones"))
	ok(absf(w_sh) < absf(m_sh) * 0.9 and flare,
		"a woman has narrower shoulders and a shroud that flares wider at the hem")
	ok(String(woman.get_meta("stance")) == "empty_f" and String(man.get_meta("stance")) == "empty_m"
		and WardenStance.new("empty_f").has_stance() and WardenStance.new("empty_m").has_stance(),
		"and her own stance (weight on one hip); his is square")
	var slight := _build({"unmasked": true, "build": 0})
	var sturdy := _build({"unmasked": true, "build": 2})
	ok(_width(sturdy) > _width(base) * 1.08 and _width(base) > _width(slight) * 1.06,
		"build changes the body's mass (%.2f / %.2f / %.2f m wide)" % [_width(slight), _width(base), _width(sturdy)])
	for n in [styled, woman, man, slight, sturdy]:
		n.free()
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

## The top of a model's meshes, in metres (its height as built).
func _top(m: Node3D) -> float:
	return _bounds(m).end.y

func _width(m: Node3D) -> float:
	return _bounds(m).size.x

## The model's mesh bounds in its parent's space (the root's scale applied), the head and limbs included.
func _bounds(m: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as MeshInstance3D
		if not gi.visible or gi.name == "TeamRing" or gi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = gi
		var shown := true
		while n != m.get_parent() and n != null:
			xf = (n as Node3D).transform * xf
			shown = shown and (n as Node3D).visible
			n = n.get_parent()
		if not shown:
			continue
		var b := xf * gi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

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
	Save.d["look"] = {"unmasked": true, "height": 2, "build": 2, "colour": 9, "marks": []}
	var hero := Models.hunter("medium", Data.TEAM_COLORS[0], "smg", "", Unmasked.mask_look(), "gunslinger")
	var before_scale := hero.scale
	var mat := (hero.get_meta("mats") as Array)[0] as ShaderMaterial
	var tint_before: Color = mat.get_shader_parameter("albedo")
	Unmasked.blend(hero)
	var tint_after: Color = mat.get_shader_parameter("albedo")
	ok(hero.scale.y > before_scale.y and hero.scale.y < before_scale.y * 1.09 and hero.scale.x > before_scale.x,
		"the Mask keeps about 90%% Hunter: height and build show a tenth (%.3f x)" % (hero.scale.y / before_scale.y))
	var want := tint_before.lerp(Unmasked.colour(Save.d["look"]), Unmasked.SHOW)
	ok(tint_after.is_equal_approx(want), "and your shroud colour tints the Hunter a tenth")
	hero.free()

## The lowest point of the model's feet (the boots under each Knee), in world metres; the ground is y = 0.
func _sole_y(m: Node3D) -> float:
	var low := 1e9
	for knee in m.find_children("Knee", "Node3D", true, false):
		for mi in knee.find_children("*", "MeshInstance3D", false, false):
			var gi := mi as MeshInstance3D
			var xf := gi.global_transform
			for sidx in gi.mesh.get_surface_count():
				for v in gi.mesh.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					low = minf(low, (xf * v).y)
	return low

## Item 81: at every height, build and sex the soles rest on the ground, standing and across a walk cycle.
func _feet(main: Node) -> void:
	var worst := 0.0
	var cases := 0
	var tree := main.get_tree()
	for g in 2:
		for h in Unmasked.HEIGHTS.size():
			for b in Unmasked.BUILDS.size():
				var m := _build({"unmasked": true, "gender": g, "height": h, "build": b})
				main.add_child(m)
				var anim := HunterAnim.new(m)
				var lows := []
				for i in 240:
					var walking := i >= 60
					anim.update(1.0 / 60.0, {"fired": 99.0, "face": 0.0,
						"vel": Vector3(0, 0, -3.5) if walking else Vector3.ZERO})
					if i == 59 or (walking and i % 4 == 0):
						lows.append(_sole_y(m))
				for y in lows:
					worst = maxf(worst, absf(y))
				cases += 1
				m.free()
				await tree.process_frame
	ok(worst <= FOOT_TOLERANCE, ("feet stay on the ground at min/mid/max height, every build and both sexes, idle and "
		+ "walking (%d bodies, worst %.1f cm)") % [cases, worst * 100.0])

## Items 79b and 80: an older Empty (a skin colour, an outfit, motes) loads as one with a shroud and an aura.
func _shroud_migration() -> void:
	var before := {"unmasked": true, "colour": 4, "outfit": 4, "motes": 2, "gender": 0}
	var u := Unmasked.clean(before)
	ok(int(u["colour"]) == 4 and int(u["shroud"]) == 4 % Unmasked.OLD_SHROUDS and int(u["aura"]) == 2
		and not u.has("outfit") and not u.has("motes") and _in_lists(u),
		"an Empty saved with a skin colour, outfit and motes becomes a shroud colour, style and aura (%s)" % str(u))
	var worn := {"look": before.duplicate()}
	Unmasked.migrate(worn)
	var once: Dictionary = worn["look"].duplicate(true)
	Unmasked.migrate(worn)
	ok(worn["look"] == once and not (worn["look"] as Dictionary).has("motes"),
		"and migrating the save twice changes nothing")
	var deep := Unmasked.clean({"race": 0, "skin": 700, "outfit": 7, "gender": 1})
	ok(_in_lists(deep) and int(deep["colour"]) < Unmasked.COLOURS.size(),
		"an old detailed look's skin colour lands on a shroud colour")
	var labels := []
	for row in Unmasked.ROWS:
		labels.append(String(row[1]).to_lower())
	var old_label := func(l: String) -> bool: return l.contains("skin") or l == "motes"
	ok(not labels.any(old_label) and "shroud colour" in labels and "aura" in labels,
		"the creator has no skin colour: a shroud colour in its place, and Aura where Motes was (%s)" % str(labels))

## Item 79b: no skin shows, the body is under a shroud in the chosen colour, the styles differ, the silhouette
## still follows sex, height and build.
func _shroud() -> void:
	var cloak := _build({"unmasked": true, "shroud": 0, "colour": 5})
	var wine := _coat(cloak)
	var other := _build({"unmasked": true, "shroud": 0, "colour": 3})
	ok(not wine.is_equal_approx(_coat(other)) and absf(wine.h - Unmasked.COLOURS[5].h) < 0.05,
		"the shroud colour sets the cloth's colour")
	var hand := cloak.find_child("Hand", true, false)
	var hand_dark := false
	for mi in hand.find_children("*", "MeshInstance3D", false, false):
		var c: Variant = ((mi as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("albedo")
		hand_dark = hand_dark or (c is Color and (c as Color).v < 0.12)
	ok(hand_dark, "the hands are void-dark: no skin colour on them")
	var wrapped := _build({"unmasked": true, "shroud": 1})
	var tatters := _build({"unmasked": true, "shroud": 2})
	var shapes := [_shape_of(cloak), _shape_of(wrapped), _shape_of(tatters)]
	ok(shapes[0] != shapes[1] and shapes[1] != shapes[2] and shapes[0] != shapes[2],
		"the three shroud styles are different shapes (%s)" % str(shapes))
	var hem := _bounds(cloak.get_node("Rig/Torso/ShroudBones"))
	ok(hem.size.y > 0.3, "a drape hangs from the hips to the ankles over the legs (%.2f m long)" % hem.size.y)
	for n in [cloak, other, wrapped, tatters]:
		n.free()

## The cloth's colour: the albedo of the shroud's own material (the cloth on its bones).
func _coat(m: Node3D) -> Color:
	for mi in m.get_node("Rig/Torso/ShroudBones").find_children("*", "MeshInstance3D", false, false):
		var c: Variant = ((mi as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("albedo")
		if c is Color:
			return c
	return Color.BLACK

## Item 80: Aura is None / Faint / Strong, with big bright specks round the head, shoulders and shroud.
func _aura() -> void:
	var strong := _build({"unmasked": true, "aura": 2})
	var faint := _build({"unmasked": true, "aura": 1})
	var none := _build({"unmasked": true, "aura": 0})
	var p := strong.find_child("Aura", true, false) as CPUParticles3D
	var f := faint.find_child("Aura", true, false) as CPUParticles3D
	ok(p != null and f != null and none.find_child("Aura", true, false) == null
		and p.amount == Unmasked.AURA_COUNT[2] and f.amount == Unmasked.AURA_COUNT[1] and p.amount > f.amount,
		"the aura has none / faint / strong (%d / %d specks)" % [Unmasked.AURA_COUNT[1], Unmasked.AURA_COUNT[2]])
	var dot := p.mesh as SphereMesh if p else null
	ok(dot != null and dot.radius >= 0.02 and p.emission_sphere_radius >= 0.4 and p.orbit_velocity_max > 0.0,
		"the specks are big (%.0f mm) and swirl wide round head and shoulders" % (dot.radius * 1000.0 if dot else 0.0))
	var row: Array = Unmasked.ROWS[Unmasked.ROWS.size() - 1]
	ok(String(row[1]) == "Aura" and row.size() > 3 and String(row[3]) == "Glowing specks that drift around you",
		"the Aura row has its tooltip")
	for n in [strong, faint, none]:
		n.free()

## A model's vertex count and bounds, which tell one shroud style from another.
func _shape_of(m: Node3D) -> String:
	var b := _bounds(m)
	return "%d:%.3f:%.3f" % [_verts(m), b.size.x, b.size.z]
