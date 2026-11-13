extends RefCounted
## --item-art-check: the sculpted item models (art/items, ItemArt) are what the game builds. The gem,
## the tonic, the armor and boots drops and the Heart each load their GLB under the toon light with its
## painted texture, at the size of the primitive they replace; gear drops take the drop's colour; a
## missing model gives null so callers keep their primitive.
## Prints "IACHECK ok|FAIL ..." lines and "IACHECK DONE, failures: N".

var bad := 0

func ok(cond: bool, msg: String) -> void:
	print("IACHECK %s %s" % ["ok  " if cond else "FAIL", msg])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	_sized("gem", Models.gem(), 0.45, 0.75)
	_sized("tonic", Models.tonic(), 0.35, 0.65)
	var col := Color("7ac8ff")
	for slot in [2, 3]:
		var d := GearModels.drop(slot, col, 2)
		var spin: Node3D = d.get_node("Spin")
		var piece := _textured(spin)
		ok(piece != null, "gear slot %d drop spins its sculpted piece" % slot)
		if piece:
			var m := _mats(piece)[0] as ShaderMaterial
			ok(m.get_shader_parameter("albedo") == col, "gear slot %d piece takes the drop colour" % slot)
		d.free()
	var h := Node3D.new()
	var heart := ItemArt.add(h, "heart", 0.5)
	ok(heart != null and _textured(h) != null, "the Heart loads its glass heart")
	if heart:
		var b := _aabb(heart)
		ok(b.size.y > 1.6 and b.size.y < 2.2, "the Heart stands about 1.9 m on its plinth (%.2f)" % b.size.y)
	h.free()
	var none := Node3D.new()
	ok(ItemArt.add(none, "no_such_item") == null and none.get_child_count() == 0, "a missing model gives null")
	none.free()
	print("IACHECK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _sized(id: String, n: Node3D, lo: float, hi: float) -> void:
	ok(_textured(n) != null, "%s uses its sculpted model" % id)
	var y := _aabb(n).size.y
	ok(y > lo and y < hi, "%s is the primitive's size (%.2f m)" % [id, y])
	n.free()

## The first mesh under `n` drawn with a textured toon material, or null.
func _textured(n: Node) -> MeshInstance3D:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for m in _mats(mi):
			if m is ShaderMaterial and m.get_shader_parameter("use_tex") and m.get_shader_parameter("albedo_tex"):
				return mi
	return null

func _mats(mi: MeshInstance3D) -> Array:
	var out: Array = []
	for si in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(si):
			out.append(mi.get_surface_override_material(si))
	return out

func _aabb(n: Node) -> AABB:
	var b := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var p: Node = mi
		while p != n and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var a := t * mi.get_aabb()
		b = a if first else b.merge(a)
		first = false
	return b
