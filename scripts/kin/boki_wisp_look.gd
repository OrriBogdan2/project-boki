class_name BokiWispLook
extends RefCounted
## A Boki wisp's look (DECISIONS 2026-11-09): the Boki's soul as a little critter outline of light in its own
## colours (its shiny colours when it shimmers), with one or two silhouette features from its model data
## (ears, horns, fins, a tail tip), a quick bouncy idle and a sparkle trail. Round = Hunter (WispLook),
## critter = Boki. Only the look: build() makes the node and pose() bounces it; who carries it and when is
## the wisp prototype's job. Every wisp is one mesh on one shared material plus TRAIL_AMOUNT sparkles.

const SHADER := preload("res://shaders/boki_wisp.gdshader")
const DOT_SHADER := preload("res://shaders/fx_dot.gdshader")      # the soft round dots Fx bursts use
const DRAW_PRIORITY := -1     # drawn before the aim telegraphs (priority 2), so they lie over the wisp
const BODY_RADIUS := 0.15     # m; the head-and-body blob, about a third of a Boki's height
const EYE_COL := Color("1c1a26")
const TRAIL_AMOUNT := 24      # sparkles alive per wisp: ten wisps stay under 300
const TRAIL_LIFE := 0.6       # s a sparkle lives
const TRAIL_LIGHTEN := 0.35   # sparkles are the glow colour lifted, so dark glows still twinkle
const HOP_HZ := 2.2           # hops per second: quick, never the slow bob of a Hunter Wisp
const HOP_HEIGHT := 0.1       # m at the top of a hop
const SQUASH := 0.25          # fraction of its height it flattens by as it lands
const DART := 0.05            # m; the little side-to-side dart between hops
const DART_HZ := 0.55         # darts per second
const DART_LEAN := 3.0        # rad of lean per metre of dart

## A part is [shape, size, at, tilt, colour slot]: shape "ball" (an ellipsoid with radii `size`), "cone" (base
## radius size.x, height size.y, pointing up before the tilt) or "box"; `at` is its middle; tilt is Euler
## radians. Front is -z, the body's middle is the origin. Parts right of the middle line get a left twin.
const BASE := [
	["ball", Vector3(0.15, 0.135, 0.15), Vector3.ZERO, Vector3.ZERO, "body"],
	["ball", Vector3(0.1, 0.085, 0.05), Vector3(0, -0.035, -0.11), Vector3.ZERO, "belly"],
	["ball", Vector3(0.022, 0.03, 0.012), Vector3(0.05, 0.03, -0.14), Vector3.ZERO, "eye"],
]

## Ear-row features, by the grammar's `look.ears` names plus the hand-built bodies' own ("none" still gets
## small round ears: every critter has some, and they keep it from reading as a round Hunter Wisp).
const EARS := {
	"none": [["ball", Vector3(0.045, 0.045, 0.03), Vector3(0.08, 0.12, 0.01), Vector3.ZERO, "body"]],
	"point": [["cone", Vector3(0.05, 0.13, 0), Vector3(0.075, 0.17, 0), Vector3(0, 0, -0.3), "body"]],
	"long": [["ball", Vector3(0.035, 0.12, 0.02), Vector3(0.05, 0.24, 0.02), Vector3(0, 0, -0.2), "body"]],
	"tuft": [["cone", Vector3(0.04, 0.09, 0), Vector3(0.09, 0.15, -0.01), Vector3(0, 0, -0.7), "body"]],
	"horn": [["cone", Vector3(0.03, 0.12, 0), Vector3(0.08, 0.16, -0.02), Vector3(-0.3, 0, -0.45), "belly"]],
	"beetle": [["cone", Vector3(0.035, 0.16, 0), Vector3(0, 0.1, -0.15), Vector3(-0.9, 0, 0), "belly"]],
	"fin": [["ball", Vector3(0.025, 0.09, 0.11), Vector3(0, 0.16, 0.02), Vector3.ZERO, "glow"]],
	"frills": [
		["cone", Vector3(0.018, 0.1, 0), Vector3(0.13, 0.08, 0), Vector3(0, 0, -1.2), "glow"],
		["cone", Vector3(0.018, 0.1, 0), Vector3(0.14, 0.03, 0), Vector3(0, 0, -1.6), "glow"],
		["cone", Vector3(0.018, 0.1, 0), Vector3(0.13, -0.02, 0), Vector3(0, 0, -2.0), "glow"],
	],
	"cap": [["ball", Vector3(0.14, 0.06, 0.14), Vector3(0, 0.15, 0), Vector3.ZERO, "glow"]],
	"leaf": [["ball", Vector3(0.035, 0.09, 0.015), Vector3(0.08, 0.17, 0), Vector3(0, 0, -0.5), "glow"]],
	"flame": [
		["cone", Vector3(0.05, 0.15, 0), Vector3(0, 0.2, 0), Vector3.ZERO, "glow"],
		["cone", Vector3(0.035, 0.1, 0), Vector3(0.07, 0.16, 0), Vector3(0, 0, -0.4), "glow"],
	],
	"bolt": [
		["box", Vector3(0.03, 0.12, 0.03), Vector3(0.07, 0.17, 0), Vector3(0, 0, -0.45), "glow"],
		["box", Vector3(0.025, 0.08, 0.025), Vector3(0.12, 0.25, 0), Vector3(0, 0, 0.4), "glow"],
	],
	"antenna": [
		["cone", Vector3(0.01, 0.14, 0), Vector3(0.04, 0.2, -0.04), Vector3(0, 0, -0.35), "body"],
		["ball", Vector3(0.025, 0.025, 0.025), Vector3(0.065, 0.27, -0.04), Vector3.ZERO, "glow"],
	],
	"wisp": [
		["ball", Vector3(0.03, 0.03, 0.03), Vector3(0, 0.19, 0), Vector3.ZERO, "glow"],
		["ball", Vector3(0.025, 0.025, 0.025), Vector3(0.09, 0.17, 0), Vector3.ZERO, "glow"],
	],
}

## Tail-tip features, by the grammar's `look.tail` names plus the hand-built bodies' own.
const TAILS := {
	"none": [],
	"stub": [["ball", Vector3(0.04, 0.04, 0.04), Vector3(0, 0, 0.16), Vector3.ZERO, "body"]],
	"curl": [
		["ball", Vector3(0.04, 0.04, 0.04), Vector3(0, 0.02, 0.17), Vector3.ZERO, "body"],
		["ball", Vector3(0.035, 0.035, 0.035), Vector3(0, 0.1, 0.21), Vector3.ZERO, "body"],
		["cone", Vector3(0.03, 0.08, 0), Vector3(0, 0.17, 0.17), Vector3(-2.2, 0, 0), "glow"],
	],
	"wisp": [
		["ball", Vector3(0.05, 0.05, 0.05), Vector3(0, 0.02, 0.18), Vector3.ZERO, "body"],
		["ball", Vector3(0.04, 0.04, 0.04), Vector3(0, 0.07, 0.26), Vector3.ZERO, "body"],
		["ball", Vector3(0.03, 0.03, 0.035), Vector3(0, 0.13, 0.31), Vector3.ZERO, "glow"],
	],
	"fish": [["box", Vector3(0.015, 0.12, 0.1), Vector3(0, 0.02, 0.2), Vector3(0.3, 0, 0), "belly"]],
	"zig": [
		["box", Vector3(0.025, 0.08, 0.025), Vector3(0, 0.03, 0.18), Vector3(-0.6, 0, 0.6), "glow"],
		["box", Vector3(0.025, 0.08, 0.025), Vector3(0, 0.09, 0.22), Vector3(-0.6, 0, -0.6), "glow"],
		["box", Vector3(0.025, 0.08, 0.025), Vector3(0, 0.15, 0.25), Vector3(-0.6, 0, 0.6), "glow"],
	],
	"flame": [["cone", Vector3(0.045, 0.14, 0), Vector3(0, 0.08, 0.2), Vector3(0.9, 0, 0), "glow"]],
	"sprout": [
		["cone", Vector3(0.008, 0.1, 0), Vector3(0, 0.06, 0.18), Vector3(0.6, 0, 0), "body"],
		["ball", Vector3(0.05, 0.015, 0.035), Vector3(0, 0.11, 0.22), Vector3.ZERO, "glow"],
	],
}

## The hand-built bodies (KinModels) carry their ears and tails in code, not in `look`: [ears, tail] for each.
const BODY_FEATURES := {
	"vespyx": ["point", "curl"],
	"prismander": ["frills", "fish"],
	"mycroll": ["cap", "stub"],
	"echolop": ["long", "stub"],
	"gravadillo": ["beetle", "stub"],
	"lunowl": ["tuft", "none"],
	"cairnback": ["horn", "stub"],
	"zephyrak": ["fin", "fish"],
	"hivara": ["antenna", "none"],
}

static var _body_mat: ShaderMaterial
static var _dot_mat: ShaderMaterial
static var _unit_arrays := {}

## The wisp of a species: a node with "Body" (the critter mesh) and "Trail" (its sparkles). rec is the
## Boki's save record ({} for a plain one); "shimmer" gives the shiny colours.
static func build(species: String, rec := {}) -> Node3D:
	var cols := {
		"body": Shiny.col(species, rec, "color"),
		"belly": Shiny.col(species, rec, "belly"),
		"glow": Shiny.col(species, rec, "glow"),
		"eye": EYE_COL,
	}
	var feats := features(species)
	var parts: Array = BASE + EARS.get(feats[0], EARS["none"]) + TAILS.get(feats[1], [])
	var root := Node3D.new()
	root.name = "BokiWisp"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh(_mirrored(parts), cols)
	body.material_override = material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.set_instance_shader_parameter("rim_col", cols["glow"])
	root.add_child(body)
	root.add_child(_trail((cols["glow"] as Color).lightened(TRAIL_LIGHTEN)))
	root.set_meta("phase", randf())
	return root

## [ears, tail] feature names for a species: its hand-built body's, else its `look` data's.
static func features(species: String) -> Array:
	var look: Dictionary = Data.KIN[species].get("look", {})
	var body_id := String(look.get("body", ""))
	if BODY_FEATURES.has(body_id):
		return BODY_FEATURES[body_id]
	return [String(look.get("ears", "none")), String(look.get("tail", "none"))]

## The one material every Boki wisp body is drawn with.
static func material() -> ShaderMaterial:
	if _body_mat == null:
		_body_mat = ShaderMaterial.new()
		_body_mat.shader = SHADER
		_body_mat.render_priority = DRAW_PRIORITY
	return _body_mat

## The idle: quick hops with a squash as it lands and a little dart side to side. t is seconds; call it
## every frame (it only sets transforms).
static func pose(wisp: Node3D, t: float) -> void:
	var body := wisp.get_node("Body") as Node3D
	var phase := float(wisp.get_meta("phase", 0.0))
	var hop := absf(sin(PI * (t * HOP_HZ + phase)))      # 0 as it lands, 1 at the top
	var squash := SQUASH * pow(1.0 - hop, 6.0)           # only right at the ground
	var dart := DART * sin(TAU * (t * DART_HZ + phase))
	body.position = Vector3(dart, HOP_HEIGHT * hop - BODY_RADIUS * squash, 0)
	body.scale = Vector3(1.0 + squash * 0.6, 1.0 - squash, 1.0 + squash * 0.6)
	body.rotation.z = -dart * DART_LEAN
	(wisp.get_node("Trail") as Node3D).position = body.position

## Adds the left twin of every part off the middle line (x > 0), with its tilt turned the other way.
static func _mirrored(parts: Array) -> Array:
	var out := parts.duplicate()
	for part in parts:
		var at: Vector3 = part[2]
		if at.x > 0.0:
			var tilt: Vector3 = part[3]
			out.append([part[0], part[1], Vector3(-at.x, at.y, at.z), Vector3(tilt.x, -tilt.y, -tilt.z), part[4]])
	return out

## All parts baked into one mesh, each in its colour (sRGB vertex colours; the shader makes them linear).
## The wisp blends with no depth, so the faces of a feature that lie inside the body are left out (they
## would paint over the body's far side).
static func _mesh(parts: Array, cols: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body_radii: Vector3 = parts[0][1]
	for part in parts:
		var extent: Vector3 = part[1]
		if part[0] == "cone":
			extent = Vector3(extent.x, extent.y, extent.x)
		var xform := Transform3D(Basis.from_euler(part[3]) * Basis.from_scale(extent), part[2])
		var normal_basis := xform.basis.inverse().transposed()
		var col: Color = cols[part[4]]
		var arrays := _unit(String(part[0]))
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for tri in idx.size() / 3:
			var at: Array[Vector3] = []
			for i in idx.slice(tri * 3, tri * 3 + 3):
				at.append(xform * verts[i])
			if part != parts[0] and at.all(func(v: Vector3): return (v / body_radii).length_squared() < 1.0):
				continue
			for k in 3:
				st.set_color(col)
				st.set_normal((normal_basis * normals[idx[tri * 3 + k]]).normalized())
				st.add_vertex(at[k])
	return st.commit()

## The surface arrays of a unit shape (radius 1 ball, cone of base radius 1 and height 1, or 1 m box).
static func _unit(shape: String) -> Array:
	if not _unit_arrays.has(shape):
		var mesh: PrimitiveMesh
		match shape:
			"ball":
				mesh = SphereMesh.new()
				(mesh as SphereMesh).radius = 1.0
				(mesh as SphereMesh).height = 2.0
				(mesh as SphereMesh).radial_segments = 14
				(mesh as SphereMesh).rings = 7
			"cone":
				mesh = CylinderMesh.new()
				(mesh as CylinderMesh).top_radius = 0.0
				(mesh as CylinderMesh).bottom_radius = 1.0
				(mesh as CylinderMesh).height = 1.0
				(mesh as CylinderMesh).radial_segments = 8
			_:
				mesh = BoxMesh.new()
		_unit_arrays[shape] = mesh.get_mesh_arrays()
	return _unit_arrays[shape]

## Sparkles shed where the wisp has been (world space), twinkling out.
static func _trail(col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	p.amount = TRAIL_AMOUNT
	p.lifetime = TRAIL_LIFE
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = BODY_RADIUS * 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0, -0.25, 0)
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.055
	p.color = col
	p.color_ramp = _twinkle()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	p.mesh = quad
	if _dot_mat == null:
		_dot_mat = ShaderMaterial.new()
		_dot_mat.shader = DOT_SHADER
		_dot_mat.render_priority = DRAW_PRIORITY
	p.material_override = _dot_mat
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## Fades in fast, then out: a twinkle, not a smear.
static func _twinkle() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return g
