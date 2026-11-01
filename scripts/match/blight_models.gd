class_name BlightModels
## Bodies for the Blight (docs/TONE_AND_THREATS.md): half creature, half petrified wreck. Stone and
## bone shells, ember light leaking through cracks, no faces, too many legs. Each has one shape you
## can read from the top-down camera at a glance. All original designs:
##   bl_skitter  a cinder tick: a low six-sided stone shell split by glowing seams, carried on eight
##               long bone legs that splay out round it (from above: a spiky star the size of a dog)
##   bl_warden   a lantern-bearer: a tall hooded stone cowl on six stilt legs, a ribcage of bone under
##               it and an ember lamp where a face should be (from above: a long teardrop ringed by
##               stilts, its light fanning out in front)
## root > "Body" (squashed and leaned by Mob), front is -z, ground is y = 0. Pivots: Leg<i><side>
## (skitter, i 0..3, side -1/1), Leg<i> (warden, i 0..5), Hood and Lamp (warden). Glowing materials
## are in meta "pulse" (they flare as an attack winds up) and meta "ember" (Blight.render breathes them).

const EMBER := Color("ff6a2a")
const EMBER_HOT := Color("ffb060")

static func build(kind: String) -> Node3D:
	var md: Dictionary = Data.MOBS[kind]
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var M := {
		"stone": MobModels._mat(md["color"], 2, "body"),
		"dark": MobModels._mat(Color(md["color"]).darkened(0.45), 2, "dark"),
		"bone": MobModels._mat(Color("cbbfa2"), 0, "belly"),
		"ember": _ember(EMBER, 2.4),
		"hot": _ember(EMBER_HOT, 3.0),
	}
	match kind:
		"bl_skitter": _skitter(body, M)
		"bl_warden": _warden(body, M)
	var mats: Array = []
	for k in M:
		mats.append(M[k])
	root.set_meta("mats", mats)
	root.set_meta("sculpted", true)
	for k in ["ember", "hot"]:
		(M[k] as ShaderMaterial).set_meta("glow0", float((M[k] as ShaderMaterial).get_shader_parameter("glow")))
	root.set_meta("pulse", [M["ember"], M["hot"]])
	root.set_meta("ember", [M["ember"], M["hot"]])
	MobModels._finish(root)        # a mesh per material per pivot: a few draw calls a body
	return root

static func _ember(c: Color, g: float) -> ShaderMaterial:
	var m := Models.toon(c, false, g)
	m.set_shader_parameter("rim_amount", 0.0)
	return m

## A jagged glowing seam across a surface: short boxes end to end, turning at random-looking (fixed)
## angles, laid just above y.
static func _seam(parent: Node3D, mat: Material, from: Vector2, dirs: Array, y: float, w := 0.035, tilt := 0.0) -> void:
	var p := from
	for d in dirs:
		var v: Vector2 = d
		var ln := v.length()
		var mid := p + v * 0.5
		Models.part(parent, Models.box(w, 0.025, ln), mat, Vector3(mid.x, y + tilt * mid.y, mid.y), Vector3.ONE, Vector3(0, atan2(v.x, v.y), 0))
		p += v

static func _skitter(body: Node3D, M: Dictionary) -> void:
	# the shell: a flat six-sided stone dome, a darker underside, a ridge of bone plates
	var shell := Models.part(body, Models.cyl(0.36, 0.44, 0.16, 6), M["stone"], Vector3(0, 0.42, 0.02), Vector3(1.0, 1.0, 1.22))
	shell.rotation.y = PI / 6.0
	Models.part(body, Models.cyl(0.26, 0.36, 0.1, 6), M["stone"], Vector3(0, 0.53, 0.02), Vector3(1.0, 1.0, 1.2), Vector3(0, PI / 6.0, 0))
	Models.part(body, Models.cyl(0.4, 0.3, 0.12, 6), M["dark"], Vector3(0, 0.3, 0.02), Vector3(1.0, 1.0, 1.2), Vector3(0, PI / 6.0, 0))
	for i in 3:
		Models.part(body, Models.cyl(0.0, 0.07, 0.14, 4), M["bone"], Vector3(0, 0.6, -0.14 + i * 0.16), Vector3(1.0, 1.0, 1.6), Vector3(-0.35, 0, 0))
	# the cracks: ember light through the stone, and a hot slit at the front where a face would be
	_seam(body, M["ember"], Vector2(-0.24, -0.3), [Vector2(0.12, 0.14), Vector2(-0.04, 0.16), Vector2(0.1, 0.12), Vector2(0.02, 0.18)], 0.59)
	_seam(body, M["ember"], Vector2(0.26, -0.22), [Vector2(-0.1, 0.16), Vector2(0.06, 0.14), Vector2(-0.08, 0.2)], 0.59)
	_seam(body, M["ember"], Vector2(-0.3, 0.22), [Vector2(0.18, 0.06), Vector2(0.14, -0.05)], 0.55)
	Models.part(body, Models.box(0.2, 0.04, 0.05), M["hot"], Vector3(0, 0.42, -0.5))
	Models.part(body, Models.sphere(0.07, 8), M["hot"], Vector3(0, 0.36, -0.44), Vector3(1.6, 0.6, 0.8))
	# eight bone legs, splayed all round: up to a knee, then down to a needle point
	for i in 4:
		for sx in [-1, 1]:
			var lg := Node3D.new(); lg.name = "Leg%d%d" % [i, sx]
			var zz := -0.27 + i * 0.18
			lg.position = Vector3(0.3 * sx, 0.36, zz)
			lg.rotation.y = (-0.55 + i * 0.37) * float(sx) * -1.0
			body.add_child(lg)
			var up := 0.34 + (0.06 if i in [0, 3] else 0.0)
			Models.part(lg, Models.cyl(0.03, 0.045, up, 5), M["bone"], Vector3(up * 0.5 * sx, 0.12, 0), Vector3.ONE, Vector3(0, 0, -1.1 * sx))
			var kx := up * 0.95 * float(sx)
			Models.part(lg, Models.sphere(0.05, 6), M["dark"], Vector3(kx, 0.25, 0))
			Models.part(lg, Models.cyl(0.0, 0.032, 0.5, 5), M["bone"], Vector3(kx + 0.16 * sx, 0.02, 0), Vector3.ONE, Vector3(0, 0, -0.4 * sx))

static func _warden(body: Node3D, M: Dictionary) -> void:
	# six stilt legs round a raised body: long thigh up and out, a black knee, a needle shin down
	for i in 6:
		var a := TAU * (float(i) + 0.5) / 6.0
		var lg := Node3D.new(); lg.name = "Leg%d" % i
		lg.position = Vector3(cos(a) * 0.32, 1.45, sin(a) * 0.4)
		lg.rotation.y = -a
		body.add_child(lg)
		Models.part(lg, Models.cyl(0.04, 0.06, 0.8, 5), M["bone"], Vector3(0.36, 0.12, 0), Vector3.ONE, Vector3(0, 0, -1.25))
		Models.part(lg, Models.sphere(0.075, 6), M["dark"], Vector3(0.74, 0.3, 0))
		Models.part(lg, Models.cyl(0.0, 0.045, 1.8, 5), M["bone"], Vector3(0.9, -0.55, 0), Vector3.ONE, Vector3(0, 0, -0.18))
	# the body: a ribcage of bone hanging under a stone carapace
	Models.part(body, Models.sphere(0.5, 14), M["dark"], Vector3(0, 1.4, 0.1), Vector3(1.0, 0.55, 1.35))
	for i in 5:
		var z := -0.3 + i * 0.16
		Models.part(body, Models.cyl(0.03, 0.03, 0.7, 5), M["bone"], Vector3(0, 1.12, z), Vector3(1.0, 1.0, 1.0), Vector3(0, 0, PI / 2.0))
		Models.part(body, Models.sphere(0.05, 6), M["ember"], Vector3(0, 1.1, z + 0.06), Vector3(1.0, 0.6, 0.6))
	Models.part(body, Models.cyl(0.5, 0.56, 0.24, 7), M["stone"], Vector3(0, 1.62, 0.18), Vector3(1.0, 1.0, 1.55), Vector3(0, PI / 7.0, 0))
	# the hood: a tall stone cowl curling forward, faceless, the lamp burning where a face would be
	var hood := Node3D.new(); hood.name = "Hood"; hood.position = Vector3(0, 1.7, -0.3)
	body.add_child(hood)
	Models.part(hood, Models.cyl(0.18, 0.42, 0.62, 7), M["stone"], Vector3(0, 0.3, 0.05), Vector3(1.0, 1.0, 1.1), Vector3(-0.32, 0, 0))
	Models.part(hood, Models.cyl(0.0, 0.2, 0.36, 7), M["stone"], Vector3(0, 0.72, -0.12), Vector3(1.0, 1.0, 1.1), Vector3(-0.75, 0, 0))
	Models.part(hood, Models.sphere(0.3, 10), M["dark"], Vector3(0, 0.22, -0.22), Vector3(0.9, 1.0, 0.5))
	_seam(hood, M["ember"], Vector2(-0.2, 0.2), [Vector2(0.06, -0.12), Vector2(0.08, -0.06)], 0.5)
	_seam(hood, M["ember"], Vector2(0.24, 0.3), [Vector2(-0.04, -0.14), Vector2(-0.08, -0.08)], 0.45)
	var lamp := Node3D.new(); lamp.name = "Lamp"; lamp.position = Vector3(0, 0.22, -0.4)
	hood.add_child(lamp)
	Models.part(lamp, Models.sphere(0.16, 10), M["hot"], Vector3.ZERO, Vector3(1.0, 1.3, 0.7))
	Models.part(lamp, Models.sphere(0.24, 10), M["ember"], Vector3(0, 0, 0.06), Vector3(1.0, 1.25, 0.4))
	# a bone spine down the back, and a tail of plates trailing behind (the teardrop's point)
	for i in 4:
		Models.part(body, Models.cyl(0.0, 0.08, 0.26, 4), M["bone"], Vector3(0, 1.82 - i * 0.05, 0.12 + i * 0.2), Vector3(1.0, 1.0, 1.5), Vector3(0.5, 0, 0))
	for i in 3:
		Models.part(body, Models.cyl(0.24 - i * 0.06, 0.3 - i * 0.07, 0.1, 6), M["stone"], Vector3(0, 1.5 - i * 0.12, 0.85 + i * 0.26), Vector3(1.0, 1.0, 1.3))
