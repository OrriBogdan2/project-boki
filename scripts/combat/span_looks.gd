class_name SpanLooks
extends Node3D
## The looks of temporary ground (an ice or rock bridge's slabs, the platform glove's pad), kept as reuse
## lists that Match.warm_up fills at load. A first cast in a match then builds no node or mesh mid-fight
## (--first-cast-check: the frost glove's ~20 slab meshes were 8-10 ms on a 4090). A span or pad is taken
## shown, restyled to its colour, and given back hidden when it ends.

const SPANS_WARM := 2  # spans built at load (a frost glove and a Breah floor up at once)
const SLOTS_WARM := 32  # slab slots each (a 10 m x 1.5 m ice bridge over open abyss lays ~25)
const PADS_WARM := 2

var _spans: Array[Node3D] = []  # free span roots (hidden)
var _pads: Array[Node3D] = []  # free platform pads (hidden)


static func of(match_node: Node) -> SpanLooks:
	var s := match_node.get_node_or_null("SpanLooks") as SpanLooks
	if s == null:
		s = SpanLooks.new()
		s.name = "SpanLooks"
		match_node.add_child(s)
	return s


## Under the loading screen: the spans and pads a fight may need, built now.
func warm() -> void:
	while _spans.size() < SPANS_WARM:
		var root := _new_span()
		_grow(root, SLOTS_WARM)
		_spans.append(root)
	while _pads.size() < PADS_WARM:
		_pads.append(_new_pad())


# ------------------------------------------------------------------ bridges
## A span with one slab per place in `at` (a tile's centre on its top), coloured `col`, shown at the origin.
func span(at: Array[Vector3], col: Color) -> Node3D:
	var root: Node3D = _spans.pop_back() if not _spans.is_empty() else _new_span()
	_grow(root, at.size())
	var mats: Array = root.get_meta("mats")
	(mats[0] as ShaderMaterial).set_shader_parameter("albedo", col)
	(mats[1] as ShaderMaterial).set_shader_parameter("color", Color(col.lightened(0.3), 0.45))
	(mats[2] as ShaderMaterial).set_shader_parameter("color", Color(col.lightened(0.85), 1.0))
	var slots := root.get_children()
	for k in slots.size():
		var slot := slots[k] as Node3D
		slot.visible = k < at.size()
		if slot.visible:
			slot.position = at[k]
			for c in 2:
				(slot.get_child(2 + c) as Node3D).visible = false
	root.position = Vector3.ZERO
	root.visible = true
	root.set_meta("free", false)
	return root


## A crumble-warned span's cracks: two crossed on each slab, turned by its tile index (`tiles`, in slab order).
func crack(root: Node3D, tiles: Array) -> void:
	for k in mini(tiles.size(), root.get_child_count()):
		var slot := root.get_child(k)
		for j in 2:
			var c := slot.get_child(2 + j) as Node3D
			c.rotation.y = float(int(tiles[k]) % 7) * 0.45 + j * 1.7
			c.visible = true


## Whether a span shows its warning cracks (checks read it).
static func cracked(root: Node3D) -> bool:
	return root.get_child_count() > 0 and (root.get_child(0).get_child(2) as Node3D).visible


## A tween on a span or pad that stops the one before (a rise still going when it is reused or falls).
static func tween(n: Node3D) -> Tween:
	var old = n.get_meta("tw") if n.has_meta("tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := n.create_tween()
	n.set_meta("tw", tw)
	return tw


## A span or pad back to its list, hidden (twice is harmless).
func give(n: Node3D) -> void:
	if not is_instance_valid(n) or bool(n.get_meta("free", true)):
		return
	n.set_meta("free", true)
	var old = n.get_meta("tw") if n.has_meta("tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	n.visible = false
	n.position = Vector3.ZERO
	(_pads if n.has_meta("pad") else _spans).append(n)


func _new_span() -> Node3D:
	var root := Node3D.new()
	root.visible = false
	root.set_meta("free", true)
	var mats := [Models.toon(Color.WHITE, true, 0.5), Models.glow_mat(Color.WHITE), Models.glow_mat(Color.WHITE)]
	root.set_meta("mats", mats)
	add_child(root)
	return root


## Slab slots up to `n`: a slab, the glassy cone under it and its two (hidden) warning cracks.
func _grow(root: Node3D, n: int) -> void:
	var mats: Array = root.get_meta("mats")
	while root.get_child_count() < n:
		var slot := Node3D.new()
		Models.part(slot, Models.box(1.0, 0.28, 1.0), mats[0], Vector3(0, -0.14, 0))
		Models.part(slot, Models.cyl(0.45, 0.05, 0.6, 6), mats[1], Vector3(0, -0.55, 0))
		for j in 2:
			var crack_v := Models.box(Verbs.BRIDGE_CRACK_W, 0.02, 1.15)
			Models.part(slot, crack_v, mats[2], Vector3(0, 0.015, 0)).visible = false
		for c in slot.get_children():
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		slot.visible = false
		root.add_child(slot)


# ------------------------------------------------------------------ platform pads
## The platform glove's pad in `col`, shown (place it, it is already in the tree).
func pad(col: Color) -> Node3D:
	var n: Node3D = _pads.pop_back() if not _pads.is_empty() else _new_pad()
	(n.get_node("Rim") as MeshInstance3D).material_override.set_shader_parameter("albedo", col)
	(n.get_node("Glow") as MeshInstance3D).material_override.set_shader_parameter("color", Color(col, 0.35))
	n.visible = true
	n.set_meta("free", false)
	return n


func _new_pad() -> Node3D:
	var n := Models.gear_platform(Color.WHITE)
	n.visible = false
	n.set_meta("free", true)
	n.set_meta("pad", true)
	add_child(n)
	return n
