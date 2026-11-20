class_name ModelsScenery
## Part of the Models split (docs/CODE_HEALTH.md): scenery.


# ---------------------------------------------------------------- scenery islands
## A free-standing floating island for scenery (the title screen, distant backdrops): a grassy top
## with a wavy outline, a grass lip, cliffs with rock strata that taper into a jagged spike below.
## Drawn with the island terrain shader so it matches the playable islands.
static func float_island(
	rng: RandomNumberGenerator,
	radius: float,
	depth: float,
	top_c := Color("6aa64a"),
	side_c := Color("8b6d52"),
	deep_c := Color("3a3140")
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 44
	var ph := rng.randf() * 10.0
	var rim: Array = []
	for i in n:
		var a := TAU * i / n
		var wob := 1.0 + 0.13 * sin(a * 3.0 + ph) + 0.07 * sin(a * 7.0 + ph * 2.0) + rng.randf_range(-0.03, 0.03)
		rim.append(Vector2(cos(a), sin(a)) * radius * wob)
	var top_y := 0.0
	# top: a gentle dome, fanned from the middle
	var cen := Vector3(0, top_y + radius * 0.04, 0)
	for i in n:
		var a2: Vector2 = rim[i]
		var b2: Vector2 = rim[(i + 1) % n]
		var a := Vector3(a2.x, top_y, a2.y)
		var b := Vector3(b2.x, top_y, b2.y)
		var ca := top_c.darkened(0.06 + 0.05 * sin(TAU * i / n * 3.0 + ph))
		var cb := top_c.darkened(0.06 + 0.05 * sin(TAU * (i + 1) / n * 3.0 + ph))
		st.set_normal(Vector3.UP)
		st.set_color(top_c.lightened(0.05))
		st.add_vertex(cen)
		st.set_color(ca)
		st.add_vertex(a)
		st.set_color(cb)
		st.add_vertex(b)
	# cliffs: rings shrinking toward a point, with a jagged edge
	var rings := 7
	var prev: Array = []
	for i in n:
		prev.append(Vector3(rim[i].x, top_y, rim[i].y))
	for k in range(1, rings + 1):
		var t := float(k) / rings
		var ring: Array = []
		var shrink := pow(1.0 - t, 1.5) if k < rings else 0.0
		var y := top_y - (0.22 if k == 1 else depth * pow(t, 0.85))
		for i in n:
			var aa := TAU * i / n
			var jag := 0.92 + 0.1 * sin(aa * 5.0 + k * 1.3 + ph) + 0.06 * sin(aa * 11.0 - k * 0.7)
			var r2: Vector2 = rim[i] * (0.97 if k == 1 else shrink * jag)
			ring.append(Vector3(r2.x, y + (sin(aa * 4.0 + k + ph) * depth * 0.05 if k > 1 else 0.0), r2.y))
		var c0: Color = top_c.darkened(0.1) if k == 1 else side_c.lerp(deep_c, float(k - 1) / rings)
		var c1: Color = top_c.darkened(0.1) if k == 1 else side_c.lerp(deep_c, float(k) / rings)
		for i in n:
			var a: Vector3 = prev[i]
			var b: Vector3 = prev[(i + 1) % n]
			var c: Vector3 = ring[(i + 1) % n]
			var d: Vector3 = ring[i]
			var nrm := (d - a).cross(b - a).normalized()
			if nrm.dot(Vector3(a.x, 0, a.z)) < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			st.set_color(c0)
			st.add_vertex(a)
			st.set_color(c0)
			st.add_vertex(b)
			st.set_color(c1)
			st.add_vertex(c)
			st.set_color(c0)
			st.add_vertex(a)
			st.set_color(c1)
			st.add_vertex(c)
			st.set_color(c1)
			st.add_vertex(d)
		prev = ring
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = World.terrain_material()
	mi.set_meta("rim", rim)
	return mi


## A curtain of water pouring off an island edge, with mist where it fades out.
static func waterfall(width: float, height: float) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, height)
	mi.mesh = qm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/waterfall.gdshader")
	mi.material_override = m
	mi.position = Vector3(0, -height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 2.0
	p.preprocess = 2.0
	ParticleCount.tune(p)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.4, 0.3, 0.3)
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -0.2, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.mesh = ModelsBase.sphere(0.25, 6)
	p.material_override = ModelsBase.glow_mat(Color(0.9, 0.95, 1.0, 0.25))
	p.position = Vector3(0, -height * 0.8, 0)
	root.add_child(p)
	return root


## The skyship that carries everyone over the islands at the start of an expedition (SkyshipModel).
static func skyship() -> Node3D:
	return SkyshipModel.build()
