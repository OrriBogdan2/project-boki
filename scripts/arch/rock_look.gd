class_name RockLook
extends RefCounted
## What Tarek's raised rocks look like (Stone Row, Basalt Spine; owner item 67): a craggy crown of tapered
## columns in warm earth tones, each tallest column broken off at HeroZones.ROCK_TOP (you stand there), pale
## sunlit tops that read from the match camera, warm light on the edges, thin molten cracks in the ground at
## the foot that cool off, and a soft shadow on the ground. They heave up with dust and a short rumble and,
## broken or timed out, crack and crumble into the ground. No other wall in the game looks like it.
## The rules (collision, climbing, Net) stay in HeroZones and StoneStand.

const TOP := HeroZones.ROCK_TOP
const CRACK_T := 0.6                 # s: a fresh rock's ground cracks cool off
const CRUMBLE_T := 0.34              # s: a broken rock slumps into the ground
const STONE := Color("4f3323")       # umber in the cracks and shadows
const STONE_HI := Color("b5804c")    # warm sandstone on the faces
const CAP := Color("e6c08a")         # the broken tops, in the sun
const RIM := 1.1
const RUMBLE_GAP := 0.09             # s: a ridge of rocks rumbles as one, not nine times over
# [x, z, base radius, height under the top, lean]
const COLS := [
	[-0.3, 0.05, 0.42, 0.0, -0.06], [0.14, -0.14, 0.38, 0.28, 0.07], [0.42, 0.16, 0.3, -0.12, 0.1],
	[-0.08, 0.27, 0.3, 0.8, -0.1], [0.58, -0.2, 0.22, 1.15, 0.16], [-0.58, -0.16, 0.24, 1.3, -0.16]
]

static var _rumble_at := -9.0

static func make() -> Node3D:
	var n := Node3D.new()
	_shadow(n)
	for c in COLS:
		_column(n, Vector3(float(c[0]), 0, float(c[1])), float(c[2]), TOP - float(c[3]), float(c[4]))
	_cracks(n)
	return n

## The soft ground shadow: from the match camera it plants the rock on the ground.
static func _shadow(n: Node3D) -> void:
	var s := Models.part(
		n, Models.cyl(1.0, 1.0, 0.01, 18), KitLooks.shade_mat(Color(0.05, 0.03, 0.02, 0.42)), Vector3(0.1, 0.03, 0.05),
		Vector3(1.15, 1.0, 0.8)
	)
	s.name = "Shadow"
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## One column: six-sided, tapering hard to a broken tip, leaning by `lean` (rad) away from the middle, with a
## pale tilted cap (the part the top-down camera sees).
static func _column(n: Node3D, at: Vector3, r: float, hgt: float, lean: float) -> void:
	var tip := r * (0.42 + KitLooks.vis_rng.randf() * 0.18)
	var col := Node3D.new()
	col.name = "Col"
	col.position = at
	col.rotation = Vector3(lean * 0.6, KitLooks.vis_rng.randf() * TAU, lean)
	n.add_child(col)
	Models.part(col, Models.cyl(tip, r, hgt, 6), _stone(), Vector3(0, hgt * 0.5, 0))
	Models.part(
		col, Models.cyl(tip * 0.75, tip * 1.1, 0.16, 5), Models.toon(CAP, false, 0.0), Vector3(0, hgt + 0.06, 0),
		Vector3.ONE, Vector3(0.35, 0.0, -0.25)
	)

static func _stone() -> ShaderMaterial:
	var mt := KitLooks.rock_mat(0.3, KitLooks.vis_rng.randf() * 10.0)
	mt.set_shader_parameter("stone", STONE)
	mt.set_shader_parameter("stone_hi", STONE_HI)
	mt.set_shader_parameter("rim", RIM)
	return mt

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
			tw.tween_property(col, "position", col.position + out * 0.8 - Vector3(0, TOP, 0), CRUMBLE_T).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(col, "rotation:z", col.rotation.z + signf(out.x + 0.01) * -0.5, CRUMBLE_T)
	tw.chain().tween_callback(n.queue_free)
