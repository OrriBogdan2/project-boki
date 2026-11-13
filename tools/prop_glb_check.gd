extends RefCounted
## --prop-glb-check (docs/art/PROPS_3D.md): each 3D prop in art/props loads, has the parts the game animates
## as separate nodes with their pivots where they move, is game-sized next to the primitive it replaces, stays
## in its triangle budget and draws on the toon shader with its own texture. The jump pad builds from its
## model with its plate "Top" in the caller's colour, and --prim-art (Assets.on() off) turns it back into the
## primitive pad. Prints "PGCHECK ok|FAIL ..." lines and "PGCHECK DONE, failures: N".

## id: [parts, metres along x (the footprint: the primitive pad, the updraft's 1.6 m radius, the sculpted
## chest), max triangles, [min, max] height as a share of a hunter's (round the models as made: the vent's rim
## stands 0.55 m, the chest with its domed lid 1.12 m, as in their concepts)]
const PROPS := {
	"jump_pad": [["Base", "Spring", "Top"], 1.5, 7000, [0.15, 0.35]],
	"gust_fan": [["Body", "Blades"], 0.0, 9000, [0.5, 0.9]],
	"updraft_vent": [["Rim", "Grate", "Glow"], 3.2, 7000, [0.25, 0.4]],
	"chest": [["Body", "Lid", "Lock"], 1.16, 9000, [0.5, 0.75]],
}
const TOL := 0.03

var bad := 0


func ok(cond: bool, msg: String) -> void:
	print("PGCHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var hunter := Models.hunter(
		Arch.weight(Arch.ORDER[0]),
		Data.TEAM_COLORS[0],
		Arch.signature(Arch.ORDER[0]),
		"",
		PlayerLook.neutral(),
		Arch.ORDER[0]
	)
	main.add_child(hunter)
	var tall := 0.0
	for mi: MeshInstance3D in hunter.find_children("*", "MeshInstance3D", true, false):
		if mi.is_visible_in_tree():
			tall = maxf(tall, (mi.global_transform * mi.get_aabb()).end.y - hunter.global_position.y)
	hunter.free()
	ok(tall > 1.0, "a hunter stands %.2f m" % tall)
	for id in PROPS:
		var spec: Array = PROPS[id]
		var n := PropGlb.build(id)
		ok(n != null, "%s loads" % id)
		if n == null:
			continue
		main.add_child(n)
		var box := AABB()
		var tris := 0
		var textured := true
		for nm in spec[0]:
			var mi := n.get_node_or_null(NodePath(nm)) as MeshInstance3D
			ok(mi != null, "%s has its part %s" % [id, nm])
			if mi == null:
				continue
			var b := mi.transform * mi.mesh.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
			for s in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
				var m := mi.get_surface_override_material(s) as ShaderMaterial
				textured = (
					textured
					and m != null
					and m.shader == Models.TOON
					and m.get_shader_parameter("use_tex")
					and m.get_shader_parameter("albedo_tex") != null
				)
		ok(textured, "%s draws on the toon shader with its texture" % id)
		ok(tris <= spec[2], "%s is in its budget (%d <= %d tris)" % [id, tris, spec[2]])
		ok(absf(box.position.y) < TOL, "%s stands on its origin (bottom %.2f)" % [id, box.position.y])
		if spec[1] > 0.0:
			ok(absf(box.size.x - spec[1]) < TOL, "%s is %.2f m wide (%.2f)" % [id, spec[1], box.size.x])
		var h: Array = spec[3]
		var share := box.size.y / tall
		ok(
			share > h[0] and share < h[1],
			"%s is %.2f m tall, %d%% of a hunter (%d%% to %d%%)" % [id, box.size.y, share * 100, h[0] * 100, h[1] * 100]
		)
		_pivots(id, n, box)
		n.queue_free()
	_pad()
	print("PGCHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Each moving part's origin sits where it moves from.
func _pivots(id: String, n: Node3D, box: AABB) -> void:
	match id:
		"jump_pad":
			var top := n.get_node("Top") as MeshInstance3D
			ok(
				absf(top.mesh.get_aabb().position.y) < TOL and Vector2(top.position.x, top.position.z).length() < TOL,
				"the pad's plate pivots at its bottom centre (it squashes down)"
			)
			ok(top.position.y > box.size.y * 0.5, "the plate sits on the top half of the pad")
		"gust_fan":
			var bl := n.get_node("Blades") as MeshInstance3D
			var c := bl.mesh.get_aabb().get_center()
			var off := Vector2(c.x, c.y).length()
			ok(off < 0.06, "the blades spin about their hub on local Z (%.3f m off)" % off)
			ok(bl.position.z > 0.0, "the blades face the fan's front (+Z)")
		"chest":
			var lid := n.get_node("Lid") as MeshInstance3D
			var a := lid.mesh.get_aabb()
			ok(absf(a.position.z) < TOL and absf(a.position.y) < TOL, "the lid hinges at its back edge, on the seam")
			ok(lid.position.z < 0.0, "the hinge is at the back (-Z)")
			var lock := n.get_node("Lock") as MeshInstance3D
			var at := lock.transform * lock.mesh.get_aabb().get_center()
			ok(at.z > box.get_center().z, "the padlock hangs on the front")


## The game's jump pad: from its model, the plate tinted, and the primitive under --prim-art.
func _pad() -> void:
	var tint := Color("ff8a7a")
	var pad := Models.jump_pad(tint)
	var top := pad.get_node_or_null("Top") as MeshInstance3D
	ok(top != null and top.mesh is ArrayMesh, "Models.jump_pad builds the 3D pad, its plate Top (match.gd pulses it)")
	if top:
		var m := top.get_surface_override_material(0) as ShaderMaterial
		ok(m.get_shader_parameter("albedo") == tint * PropGlb.GLOW_GAIN, "the plate takes the caller's colour")
		ok(m.next_pass == null and m.get_shader_parameter("glow") > 0.0, "the plate glows, unoutlined")
	var pad2 := Models.jump_pad(tint)
	ok(
		(
			top != null
			and (
				(pad2.get_node("Top") as MeshInstance3D).get_surface_override_material(0)
				== top.get_surface_override_material(0)
			)
		),
		"pads of one colour share their materials"
	)
	pad.free()
	pad2.free()
	Assets._off = 1
	var prim := Models.jump_pad(tint)
	ok(prim.get_node_or_null("Chev0") != null and prim.has_node("Top"), "--prim-art builds the primitive pad")
	prim.free()
	Assets._off = 0
