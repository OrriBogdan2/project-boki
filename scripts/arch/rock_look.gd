class_name RockLook
extends RefCounted
## What Tarek's raised rocks look like (Stone Row, Basalt Spine; owner item 67): a craggy crown of tapered
## columns in warm earth tones, the main one peaking at HeroZones.ROCK_TOP (you stand there), pale sunlit
## upward faces that read from the match camera, warm light on the edges, thin molten cracks in the ground at
## the foot that cool off, and a soft shadow on the ground. They heave up with dust and a short rumble and,
## broken or timed out, crack and crumble into the ground. No other wall in the game looks like it.
## The rules (collision, climbing, Net) stay in HeroZones and StoneStand.

const TOP := HeroZones.ROCK_TOP
const CRACK_T := 0.6                 # s: a fresh rock's ground cracks cool off
const CRUMBLE_T := 0.34              # s: a broken rock slumps into the ground
const STONE := Color("3d2618")       # umber in the cracks and shadows
const STONE_HI := Color("96663c")    # warm sandstone on the faces
const CAP := Color("eccb96")         # the upward faces, in the sun: what the match camera sees most
const RIM := 0.4
const RUMBLE_GAP := 0.09             # s: a ridge of rocks rumbles as one, not nine times over
const SIDES := 6
# a crag's rings going up: [share of its height, share of its base radius]
const TIERS := [[0.0, 1.0], [0.36, 0.84], [0.62, 0.72], [0.84, 0.56], [0.94, 0.4]]
# [x, z, base radius, height under the top, lean]
const COLS := [
	[-0.3, 0.05, 0.44, 0.0, -0.06], [0.14, -0.14, 0.4, 0.28, 0.07], [0.42, 0.16, 0.32, -0.12, 0.1],
	[-0.08, 0.27, 0.32, 0.8, -0.1], [0.58, -0.2, 0.24, 1.15, 0.16], [-0.58, -0.16, 0.26, 1.3, -0.16]
]

static var _rumble_at := -9.0
static var _crags: Dictionary = {}   # column index -> [mesh, material], shared by every rock

static func make() -> Node3D:
	var n := Node3D.new()
	_shadow(n)
	for i in COLS.size():
		var c: Array = COLS[i]
		var col := Node3D.new()
		col.name = "Col"
		col.position = Vector3(float(c[0]), 0, float(c[1]))
		col.rotation = Vector3(float(c[4]) * 0.6, 0.0, float(c[4]))
		n.add_child(col)
		var crag: Array = _crag(i)
		Models.part(col, crag[0], crag[1])
	_cracks(n)
	return n

## Stands the columns straight, so a low rock can be squashed without shearing them.
static func upright(n: Node3D) -> void:
	for c in n.get_children():
		if c.name.begins_with("Col"):
			(c as Node3D).rotation = Vector3.ZERO

## The soft ground shadow: from the match camera it plants the rock on the ground.
static func _shadow(n: Node3D) -> void:
	var s := Models.part(
		n, Models.cyl(1.0, 1.0, 0.01, 18), KitLooks.shade_mat(Color(0.05, 0.03, 0.02, 0.34)), Vector3(0.06, 0.03, 0.03),
		Vector3(0.95, 1.0, 0.68)
	)
	s.name = "Shadow"
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## One crag, built once: rings of jittered points narrowing and wandering upward to a broken peak at its
## full height, flat-shaded, so the outline is jagged from above and from the side.
static func _crag(i: int) -> Array:
	if _crags.has(i):
		return _crags[i]
	var c: Array = COLS[i]
	var r := float(c[2])
	var hgt := TOP - float(c[3])
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + i
	var rings: Array = []
	var off := Vector2.ZERO
	for tier in TIERS:
		var ring: Array = []
		for s in SIDES:
			var a := TAU * (float(s) + rng.randf_range(-0.2, 0.2)) / SIDES
			var rr := r * float(tier[1]) * rng.randf_range(0.82, 1.16)
			var y := hgt * float(tier[0]) * rng.randf_range(0.94, 1.04)
			ring.append(Vector3(off.x + cos(a) * rr, y, off.y + sin(a) * rr))
		rings.append(ring)
		off += Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for j in rings.size() - 1:
		for s in SIDES:
			var a0: Vector3 = rings[j][s]
			var a1: Vector3 = rings[j][(s + 1) % SIDES]
			var b0: Vector3 = rings[j + 1][s]
			var b1: Vector3 = rings[j + 1][(s + 1) % SIDES]
			for v in [a0, a1, b1, a0, b1, b0]:
				st.add_vertex(v)
	var peak := Vector3(off.x, hgt, off.y)
	for s in SIDES:
		for v in [rings[-1][s], rings[-1][(s + 1) % SIDES], peak]:
			st.add_vertex(v)
	st.generate_normals()
	var mt := KitLooks.rock_mat(0.3, float(i) * 1.7)
	mt.set_shader_parameter("stone", STONE)
	mt.set_shader_parameter("stone_hi", STONE_HI)
	mt.set_shader_parameter("rim", RIM)
	mt.set_shader_parameter("cap_col", CAP)
	mt.set_shader_parameter("cap", 1.0)
	_crags[i] = [st.commit(), mt]
	return _crags[i]

## Thin glowing cracks in the ground at the rock's foot.
static func _cracks(n: Node3D) -> void:
	var cracks := Node3D.new()
	cracks.name = "Cracks"
	n.add_child(cracks)
	for i in 7:
		var a := TAU * i / 7.0 + KitLooks.vis_rng.randf() * 0.4
		var len_ := 0.35 + KitLooks.vis_rng.randf() * 0.45
		Models.part(
			cracks, Models.box(0.035, 0.012, len_), KitLooks.shade_mat(Color(1.0, 0.45, 0.1, 0.95)),
			Vector3(cos(a), 0.04, sin(a)) * (0.55 + len_ * 0.5), Vector3.ONE, Vector3(0, -a + PI * 0.5, 0)
		)
	for mi in cracks.get_children():
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The ground cracks at a fresh rock's foot cool and fade out.
static func cool(n: Node3D) -> void:
	var cracks := n.get_node_or_null("Cracks") as Node3D
	if cracks == null:
		return
	var tw := n.create_tween().set_parallel()
	for mi in cracks.get_children():
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		tw.tween_property(mat, "albedo_color:a", 0.0, CRACK_T).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func(): cracks.visible = false)

## A rock coming up: a burst of dust and earth at its foot and one short rumble.
static func rise_fx(m: Node, at: Vector3) -> void:
	m.fx.dust(at, 14)
	m.fx.burst(at + Vector3(0, 0.3, 0), STONE_HI, 12, 3.5, 0.45, 8.0, 1.2)
	m.fx.spark(at + Vector3(0, 0.2, 0), Vector3.UP, Color("ff7a2a"), 8, 5.0, 40.0, 0.3, 10.0, 1.0)
	if absf(float(m.time) - _rumble_at) >= RUMBLE_GAP:
		_rumble_at = float(m.time)
		m.sfx("br_rumble", at, -3.0, 1.0)

## A rock broken or timed out (Verbs._break_wall's kx_end): it takes the node over, so the columns can snap,
## lean out and slump into the ground in a spray of chips. A launched rock leaves through HeroZones.remove_rock.
static func crumble(m: Node, w: Dictionary) -> void:
	var n := w.get("node") as Node3D
	if n == null or not is_instance_valid(n):
		return
	w["node"] = null
	var at := n.global_position
	m.sfx("br_crumble", at, -4.0, 1.0)
	m.fx.dust(at, 12)
	KitLooks.of(m).chips(at + Vector3(0, TOP * 0.5, 0), 6, 0.2)
	var shadow := n.get_node_or_null("Shadow") as Node3D
	if shadow != null:
		shadow.visible = false
	var tw := n.create_tween().set_parallel()
	for c in n.get_children():
		if c.name.begins_with("Col"):
			var col := c as Node3D
			var out := Vector3(col.position.x, 0.0, col.position.z)
			var sunk := col.position + out * 0.8 - Vector3(0, TOP, 0)
			tw.tween_property(col, "position", sunk, CRUMBLE_T).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(col, "rotation:z", col.rotation.z + signf(out.x + 0.01) * -0.5, CRUMBLE_T)
	tw.chain().tween_callback(n.queue_free)
