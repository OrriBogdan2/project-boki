class_name SkyshipModel
## The skyship's look: a wooden sky-galleon hull with a plank deck the squad stands on, a long striped
## envelope held over it by rigging, two engine pods with spinning props (PropL, PropR), tail fins, a
## bow mast with a pennant and lanterns. Built once from Models parts, baked into a few meshes (one
## per material) and copied per ship. The ship's nose points down -Z; the deck top is at DECK_Y.
## The parts that move or follow the ground (props, contrail, shadow) are named children that
## SkyshipFx drives each tick.

const DECK_Y := 0.32           # m above the ship's origin: the plank top the riders stand on
const DECK_W := 4.4            # m across the deck, rail to rail
const DECK_L := 11.0           # m from the bow post to the stern rail
const ENVELOPE_Y := 9.0        # m: the envelope's centre over the deck, high enough to stand under
const ENVELOPE_R := Vector3(4.0, 3.4, 9.6)   # m: the envelope's half extents (a long cigar)
const ENGINE_X := 3.5          # m out from the keel to each engine pod
const ENGINE_Z := 3.8          # m aft of the middle: the pods sit by the stern
const MAST_Z := 1.3            # m: the mast stands behind the squad, out of the intro's view of them
const TRAIL_AMOUNT := 40       # particles in the contrail (perf pass: a few dozen, shared quad)
const SHADOW_SIZE := Vector2(12.0, 26.0)     # m: the soft blob the ship throws on the island under it

static var _template: Node3D = null
static var _shadow_mat: StandardMaterial3D = null
static var _trail_mat: StandardMaterial3D = null

## A new skyship node (a copy of the baked template: the meshes and materials are shared).
static func build() -> Node3D:
	if _template == null:
		_template = _make()
	var n := _template.duplicate() as Node3D
	n.add_child(_trail())
	n.add_child(_shadow())
	return n

static func _make() -> Node3D:
	var root := Node3D.new()
	var wood: ShaderMaterial = Models.toon(Color("7a5236"))
	var dark: ShaderMaterial = Models.toon(Color("4e3424"))
	var plank: ShaderMaterial = Models.toon(Color("a8794e"))
	var cloth: ShaderMaterial = Models.toon(Color("f2e6cf"))
	var stripe: ShaderMaterial = Models.toon(Color("d9604a"))
	var gold: ShaderMaterial = Models.toon(Color("f2c84a"))
	var brass: ShaderMaterial = Models.toon(Color("e0b84a"), true, 0.3)
	var lamp: ShaderMaterial = Models.toon(Color("ffd27a"), false, 1.4)
	_hull(root, wood, dark, plank, brass)
	_envelope(root, cloth, stripe, gold, brass)
	_rigging(root, dark)
	_engines(root, dark, brass, wood)
	_mast(root, dark, stripe, lamp)
	Models.merge_static(root)
	return root

static func _hull(root: Node3D, wood: Material, dark: Material, plank: Material, brass: Material) -> void:
	var p: SphereMesh = _ball(1.0, 24)
	# the boat body: a long squashed egg, the deck laid over its open top, a keel under it
	Models.part(root, p, wood, Vector3(0, -0.25, 0.3), Vector3(2.4, 1.15, 6.4))
	Models.part(root, Models.box(DECK_W, 0.22, DECK_L), plank, Vector3(0, DECK_Y - 0.11, 0.2))
	Models.part(root, Models.box(0.35, 0.5, 10.0), dark, Vector3(0, -1.25, 0.6))
	# the bow: a beak that rises to a carved post
	Models.part(root, _tube(0.05, 1.5, 3.2, 14), wood, Vector3(0, 0.0, -6.2), Vector3(1.4, 1, 0.55),
			Vector3(-PI / 2, 0, 0))
	Models.part(root, Models.box(0.3, 1.6, 0.3), dark, Vector3(0, 0.9, -6.9), Vector3.ONE, Vector3(-0.5, 0, 0))
	Models.part(root, _ball(0.24, 10), brass, Vector3(0, 1.6, -7.3))
	# rails along both sides and across the stern, on posts
	for sx in [-1.0, 1.0]:
		Models.part(root, Models.box(0.14, 0.14, DECK_L - 0.6), dark, Vector3(sx * (DECK_W / 2.0 - 0.1), 1.25, 0.3))
		Models.part(root, Models.box(0.28, 0.5, DECK_L), wood, Vector3(sx * (DECK_W / 2.0 - 0.02), DECK_Y + 0.15, 0.2))
		for i in 6:
			Models.part(root, Models.box(0.1, 0.9, 0.1), dark,
					Vector3(sx * (DECK_W / 2.0 - 0.1), DECK_Y + 0.45, -4.5 + i * 1.9))
	Models.part(root, Models.box(DECK_W - 0.2, 0.14, 0.14), dark, Vector3(0, 1.25, 5.6))
	# a cabin roof at the stern with the wheel before it
	Models.part(root, Models.box(3.2, 1.3, 2.2), wood, Vector3(0, DECK_Y + 0.65, 4.4))
	Models.part(root, Models.box(3.5, 0.18, 2.5), dark, Vector3(0, DECK_Y + 1.38, 4.4))
	Models.part(root, _tube(0.55, 0.55, 0.08, 16), dark, Vector3(0, DECK_Y + 1.25, 2.9), Vector3.ONE,
			Vector3(PI / 2, 0, 0))
	Models.part(root, _tube(0.08, 0.08, 1.1, 8), dark, Vector3(0, DECK_Y + 0.55, 3.0))
	# a band of brass round the waterline (the sky line)
	Models.part(root, p, brass, Vector3(0, -0.05, 0.3), Vector3(2.45, 0.12, 6.45))

static func _envelope(root: Node3D, cloth: Material, stripe: Material, gold: Material, brass: Material) -> void:
	var c := Vector3(0, ENVELOPE_Y, 0.4)
	Models.part(root, _ball(1.0, 28), cloth, c, ENVELOPE_R)
	# hoops round it and a ribbon nose to tail over the top, so it reads from the ride camera above
	for i in 5:
		var z := -6.0 + i * 3.0
		var k := sqrt(maxf(0.0, 1.0 - pow(z / ENVELOPE_R.z, 2.0)))
		Models.part(root, _tube(1.0, 1.0, 0.45, 24), stripe, c + Vector3(0, 0, z),
				Vector3(ENVELOPE_R.x * k + 0.04, 1.0, ENVELOPE_R.y * k + 0.04), Vector3(PI / 2, 0, 0))
	for rz in [-0.5, 0.0, 0.5]:
		Models.part(root, _ball(1.0, 28), stripe if rz == 0.0 else gold, c,
				Vector3(0.12, ENVELOPE_R.y + 0.04, ENVELOPE_R.z + 0.04), Vector3(0, 0, rz))
	Models.part(root, _ball(0.5, 12), brass, c + Vector3(0, 0, -ENVELOPE_R.z + 0.2), Vector3(1, 1, 0.6))
	# tail fins: one up, one down, one each side
	var tail := c + Vector3(0, 0, ENVELOPE_R.z - 1.6)
	Models.part(root, Models.box(0.18, 3.4, 2.8), stripe, tail + Vector3(0, ENVELOPE_R.y * 0.75, 0.4))
	Models.part(root, Models.box(0.18, 2.4, 2.4), stripe, tail + Vector3(0, -ENVELOPE_R.y * 0.7, 0.4))
	for sx in [-1.0, 1.0]:
		Models.part(root, Models.box(3.0, 0.18, 2.6), stripe, tail + Vector3(sx * ENVELOPE_R.x * 0.75, 0, 0.4))

static func _rigging(root: Node3D, dark: Material) -> void:
	# lines from the rails up to the envelope's belly, leaning in
	var top_y := ENVELOPE_Y - ENVELOPE_R.y * 0.85
	for sx in [-1.0, 1.0]:
		for z in [-4.0, -1.0, 2.0]:
			var a := Vector3(sx * (DECK_W / 2.0 - 0.1), 1.25, z)
			var b := Vector3(sx * ENVELOPE_R.x * 0.55, top_y, z + 0.3)
			_line(root, a, b, 0.045, dark)

static func _engines(root: Node3D, dark: Material, brass: Material, wood: Material) -> void:
	for sx in [-1.0, 1.0]:
		var at := Vector3(sx * ENGINE_X, 1.4, ENGINE_Z)
		# the outrigger out from the hull, the pod, its brass cowl
		_line(root, Vector3(sx * 1.9, 0.6, ENGINE_Z), at, 0.14, dark)
		_line(root, at, Vector3(sx * ENVELOPE_R.x * 0.6, ENVELOPE_Y - ENVELOPE_R.y * 0.8, ENGINE_Z - 0.5), 0.05, dark)
		Models.part(root, _tube(0.55, 0.42, 2.4, 16), wood, at, Vector3.ONE, Vector3(PI / 2, 0, 0))
		var cowl := at + Vector3(0, 0, -1.2)
		Models.part(root, _tube(0.6, 0.6, 0.3, 16), brass, cowl, Vector3.ONE, Vector3(PI / 2, 0, 0))
		Models.part(root, _ball(0.4, 12), brass, at + Vector3(0, 0, -1.25), Vector3(1, 1, 0.7))
		var hub := Node3D.new()
		hub.name = "Prop%s" % ("L" if sx < 0 else "R")
		hub.position = at + Vector3(0, 0, 1.35)
		root.add_child(hub)
		Models.part(hub, _tube(0.18, 0.18, 0.4, 10), brass, Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
		for b in 4:
			Models.part(hub, Models.box(0.22, 2.0, 0.06), wood, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, TAU * b / 4.0))
		Models.merge_static(hub)

static func _mast(root: Node3D, dark: Material, stripe: Material, lamp: Material) -> void:
	Models.part(root, _tube(0.11, 0.13, 3.4, 10), dark, Vector3(0, DECK_Y + 1.7, MAST_Z))
	Models.part(root, Models.box(0.05, 0.7, 1.4), stripe, Vector3(0, DECK_Y + 3.0, MAST_Z + 0.6))
	for at in [Vector3(-1.9, 1.6, -4.8), Vector3(1.9, 1.6, -4.8), Vector3(-1.5, 2.0, 5.6), Vector3(1.5, 2.0, 5.6)]:
		Models.part(root, _ball(0.18, 8), lamp, at)
		Models.part(root, Models.box(0.04, 0.5, 0.04), dark, at + Vector3(0, -0.4, 0))

## A thin rod from a to b (a rigging line, an outrigger).
static func _line(root: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var mi: MeshInstance3D = Models.part(root, _tube(r, r, a.distance_to(b), 6), mat, (a + b) / 2.0)
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.basis = Basis(side, up, side.cross(up))

## The contrail: two streams of soft puffs off the props, left behind in the world.
static func _trail() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Trail"
	p.amount = TRAIL_AMOUNT
	p.lifetime = 2.6
	p.local_coords = false
	p.position = Vector3(0, 1.4, ENGINE_Z + 1.8)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(ENGINE_X, 0.2, 0.2)
	p.direction = Vector3(0, 0.1, 1)
	p.spread = 8.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.55))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	if _trail_mat == null:
		_trail_mat = StandardMaterial3D.new()
		_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_mat.vertex_color_use_as_albedo = true
		_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_trail_mat.albedo_texture = _soft_dot()
	q.material = _trail_mat
	p.mesh = q
	return p

## The shadow blob: a flat soft oval kept on the ground under the ship (top_level: placed in world space).
static func _shadow() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Shadow"
	mi.top_level = true
	var pm := PlaneMesh.new()
	pm.size = SHADOW_SIZE
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_color = Color(0.05, 0.06, 0.12, 0.42)
		_shadow_mat.albedo_texture = _soft_dot()
	mi.material_override = _shadow_mat
	mi.visible = false
	return mi

static var _dot: GradientTexture2D = null
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot

## A sphere at exactly `seg` segments round (and half that in rings): the ship's parts are scaled far
## past their radius, so Models.sphere's size-based detail would spend 50-100 sides on each.
static func _ball(r: float, seg: int) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = int(seg / 2.0)
	return sm

## A cylinder (or cone) at exactly `seg` sides, one ring (likewise).
static func _tube(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return cm
