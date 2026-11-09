class_name MobModels
## Sculpted, hand-painted bodies for the common monsters, in the same style as the hunters and kin:
## smooth rounded forms, painted part gradients and creases, a rim light, glowing eyes, built so
## Mob.render can animate them (the named pivots below). All original designs:
##   skitter   a thornback beetle: split glossy wing-case, bone spines, a horn, mandibles, six legs
##   spitter   a spitpod: a carnivorous seed pod on a root-footed stalk, a glowing toothed maw, leaves
##   brute     a stonehide brute: a hunched knuckle-walker, rock plates on its back, tusks, huge fists
##   warden    the brute grown half again as big, with a gold crown, gold pauldrons and a heart gem
##   bomber    a puffbomb: a spiny puffer with stubby fins, a pursed mouth and a lit fuse
##   sentinel  a rune-carved standing stone holding a slowly turning crystal ringed by shards
##   glimmer   a gold treasure kin: round and long-eared, studded with gems, sparkles round it
## root > "Body" (squashed and leaned by Mob), front is -z, ground is y = 0. Pivots: skitter
## Leg<i><side> and JawL/JawR; spitter Bulb, Leaf<i>; brute/warden Torso (Head, ArmL, ArmR), LegL,
## LegR; bomber Puff (FinL, FinR, Spark); sentinel Crystal (Shards); glimmer EarL/EarR.
## Materials are tagged (meta "mob_part": body / dark / belly) so BiomeRun repaints them per region.
## dress() adds a little of the island's biome to a monster's back (moss, flowers, ice, embers...).

static func build(kind: String) -> Node3D:
	var md: Dictionary = Data.MOBS[kind]
	var col: Color = md["color"]
	var root := Node3D.new()
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var M := {
		"body": _mat(col, 4, "body"),
		"dark": _mat(_dark(col), 2, "dark"),
		"belly": _mat(_belly(col), 4, "belly"),
		"eye": Models.toon(Color("ffe25a"), false, 1.3),
		"bone": _mat(Color("efe4c8"), 0),
		"mouth": _mat(Color("2a1420"), 0),
	}
	(M["eye"] as ShaderMaterial).set_shader_parameter("rim_amount", 0.0)
	var back := Vector3.ZERO
	var back_r := 0.3
	var back_node: Node3D = body
	match kind:
		"skitter":
			back = _skitter(body, M); back_r = 0.26
		"spitter":
			back = _spitter(body, M); back_r = 0.2
			back_node = body.get_node("Bulb")
		"brute", "warden":
			back = _brute(body, M, kind == "warden"); back_r = 0.42
			back_node = body.get_node("Torso")
		"bomber":
			back = _bomber(body, M); back_r = 0.22
			back_node = body.get_node("Puff")
		"sentinel":
			back = _sentinel(body, M); back_r = 0.38
		"glimmer":
			back = _glimmer(body, M); back_r = 0.0
	if kind == "warden":
		root.scale = Vector3.ONE * 1.5
	root.set_meta("back", back)
	root.set_meta("back_r", back_r)
	root.set_meta("back_node", NodePath(String(body.name) + ("" if back_node == body else "/" + String(back_node.name))))
	var mats: Array = []
	for k in M:
		mats.append(M[k])
	root.set_meta("mats", mats)
	root.set_meta("sculpted", true)
	var pulse: Array = []
	for k in ["throat", "spark", "rune"]:
		if M.has(k):
			(M[k] as ShaderMaterial).set_meta("glow0", float((M[k] as ShaderMaterial).get_shader_parameter("glow")))
			pulse.append(M[k])
	if not pulse.is_empty():
		root.set_meta("pulse", pulse)
	_finish(root)
	return root

## Merges each pivot's plain parts into a mesh per material (a handful of draw calls a monster),
## then gives what's left its painted part gradient.
static func _finish(root: Node3D) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n is MeshInstance3D):
			Models.merge_static(n)
		for ch in n.get_children():
			stack.append(ch)
	Models.bake_part_y(root)

static var _meshes := {}
## Monster-weight meshes: smooth enough for the match camera and close-ups, a fraction of the
## triangles of the character meshes (dozens of monsters can be on screen).
static func _sph(r: float) -> SphereMesh:
	var sg := int(clampf(10.0 + r * 36.0, 10.0, 24.0))
	sg += sg % 2
	var key := "s%.4f|%d" % [r, sg]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = r; s.height = r * 2.0; s.radial_segments = sg; s.rings = maxi(6, sg / 2)
		_meshes[key] = s
	return _meshes[key]

static func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var key := "c%.4f|%.4f|%.4f" % [top, bottom, h]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top; c.bottom_radius = bottom; c.height = h; c.radial_segments = 9; c.rings = 1
		c.cap_top = top > 0.0; c.cap_bottom = false
		_meshes[key] = c
	return _meshes[key]

## A tapered limb along Y (r0 at the top), rounded at both ends, a little fuller a third of the way down.
static func _limb(r0: float, r1: float, h: float, bulge := 0.08) -> ArrayMesh:
	var key := "l%.4f|%.4f|%.4f|%.3f" % [r0, r1, h, bulge]
	if _meshes.has(key):
		return _meshes[key]
	var hh := h * 0.5
	var pts := PackedVector2Array()
	for k in 4:
		var a := -PI * 0.5 + PI * 0.5 * float(k) / 3.0
		pts.append(Vector2(cos(a) * r1, -hh + r1 + sin(a) * r1))
	pts.append(Vector2(lerpf(r1, r0, 0.62) * (1.0 + bulge), lerpf(-hh + r1, hh - r0, 0.6)))
	for k in 4:
		var a := PI * 0.5 * float(k) / 3.0
		pts.append(Vector2(cos(a) * r0, hh - r0 + sin(a) * r0))
	var prof := pts
	prof[0] = Vector2(0, -hh); prof[prof.size() - 1] = Vector2(0, hh)
	var am := Models.lathe(prof, int(clampf(maxf(r0, r1) * 70.0, 8.0, 12.0)))
	_meshes[key] = am
	return am

## Dark accents go deep and the belly pale, whatever the region's colour, so a monster keeps a
## strong value range (and reads against ground of its own hue).
static func _dark(c: Color) -> Color:
	return c.darkened(0.58).lerp(Color("231c2c"), 0.35)

static func _belly(c: Color) -> Color:
	return c.lightened(0.3).lerp(Color("f2e6cc"), 0.55)

static func _mat(c: Color, surf := 0, tag := "") -> ShaderMaterial:
	var m := Models.toon(c)
	Models.painted(m, surf, 0.3, 0.32, 0.28)
	m.set_shader_parameter("rim_amount", 0.5)
	m.set_shader_parameter("sss", 0.16)
	m.set_shader_parameter("sheen", 0.08)
	if tag != "":
		m.set_meta("mob_part", tag)
	return m

static func _glow(c: Color, g := 1.2) -> ShaderMaterial:
	var m := Models.toon(c, false, g)
	m.set_shader_parameter("rim_amount", 0.0)
	return m

## A tapered limb from a (thick end, radius r0) to b (radius r1).
static func bone(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, bulge := 0.08) -> MeshInstance3D:
	var d := a - b
	var mi := Models.part(parent, _limb(r0, r1, d.length() + r0 + r1, bulge), mat, (a + b) * 0.5)
	var dn := d.normalized()
	if absf(dn.dot(Vector3.UP)) > 0.999:
		mi.basis = Basis.IDENTITY if dn.y > 0 else Basis(Vector3.RIGHT, PI)
	else:
		mi.basis = Basis(Quaternion(Vector3.UP, dn))
	return mi

## A horn, claw or spine: a cone from base along dir, curling a little toward `curl`.
static func horn(parent: Node3D, base: Vector3, dir: Vector3, r: float, h: float, mat: Material, curl := Vector3.ZERO) -> void:
	var d := dir.normalized()
	var k := 2 if curl == Vector3.ZERO else 3
	var p := base
	var rr := r
	for i in k:
		var seg_h := h / k
		var dd := (d + curl * (float(i) / k)).normalized()
		var mi := Models.part(parent, _cone(rr * 0.55 if i < k - 1 else 0.0, rr, seg_h * 1.15), mat, p + dd * seg_h * 0.5)
		mi.basis = Basis(Quaternion(Vector3.UP, dd)) if absf(dd.dot(Vector3.UP)) < 0.999 else Basis.IDENTITY
		p += dd * seg_h
		rr *= 0.55

## Angry glowing eyes under a heavy brow, set into a head (an ellipsoid at c with radii rad).
static func eyes(parent: Node3D, c: Vector3, rad: Vector3, spread: float, up: float, size: float, M: Dictionary, brow: Material) -> void:
	for sx in [-1.0, 1.0]:
		var d := Vector3(sx * spread, up, -1.0).normalized()
		var p := c + Vector3(d.x * rad.x, d.y * rad.y, d.z * rad.z) * 0.97
		# a dark socket, the glowing eye, a brow slanting down to the middle
		Models.part(parent, _sph(size * 1.35), M["mouth"], p + Vector3(0, 0, size * 0.25), Vector3(1.25, 0.9, 0.6))
		Models.part(parent, _sph(size), M["eye"], p, Vector3(1.2, 0.7, 0.7), Vector3(0, 0, -0.35 * sx))
		Models.part(parent, _sph(size * 1.3), brow, p + Vector3(0.0, size * 0.95, -size * 0.1), Vector3(1.5, 0.5, 0.8), Vector3(0.2, 0, 0.42 * sx))

# ------------------------------------------------------------------ skitter
static func _skitter(body: Node3D, M: Dictionary) -> Vector3:
	var shell: Material = M["body"]
	(shell as ShaderMaterial).set_shader_parameter("gloss", 0.45)
	var dark: Material = M["dark"]
	# abdomen and underside
	Models.part(body, _sph(0.36), dark, Vector3(0, 0.36, 0.12), Vector3(1.05, 0.7, 1.3))
	# the split wing-case: two glossy domes meeting at a ridge, flaring at the back
	for sx in [-1.0, 1.0]:
		Models.part(body, _sph(0.34), shell, Vector3(0.15 * sx, 0.47, 0.14), Vector3(0.62, 0.62, 1.22), Vector3(0.06, 0.08 * sx, -0.14 * sx))
		# a pale band along each case's rim
		Models.part(body, _sph(0.3), M["belly"], Vector3(0.24 * sx, 0.36, 0.16), Vector3(0.42, 0.32, 1.18), Vector3(0, 0, -0.5 * sx))
	Models.part(body, _sph(0.06), dark, Vector3(0, 0.66, 0.12), Vector3(0.6, 0.8, 5.0))
	# thorax and head
	Models.part(body, _sph(0.22), dark, Vector3(0, 0.42, -0.26), Vector3(1.15, 0.85, 0.9))
	var hc := Vector3(0, 0.4, -0.44)
	Models.part(body, _sph(0.17), shell, hc, Vector3(1.05, 0.85, 0.95))
	eyes(body, hc, Vector3(0.17, 0.15, 0.16), 0.55, 0.3, 0.04, M, dark)
	# a curved horn and bone spines down the back
	horn(body, hc + Vector3(0, 0.1, -0.08), Vector3(0, 0.8, -0.6), 0.07, 0.34, M["bone"], Vector3(0, 0.3, 0.6))
	for i in 3:
		horn(body, Vector3(0, 0.66 - i * 0.03, -0.06 + i * 0.2), Vector3(0, 1, 0.45), 0.05 - i * 0.008, 0.2 - i * 0.03, M["bone"])
	for sx in [-1.0, 1.0]:
		var jaw := Node3D.new(); jaw.name = "Jaw" + ("L" if sx < 0 else "R"); jaw.position = Vector3(0.08 * sx, 0.32, -0.56); body.add_child(jaw)
		horn(jaw, Vector3.ZERO, Vector3(0.25 * sx, -0.1, -1.0), 0.04, 0.2, M["bone"], Vector3(-0.9 * sx, 0, 0))
		for i in 3:
			var lg := Node3D.new(); lg.name = "Leg%d%d" % [i, int(sx)]
			lg.position = Vector3(0.22 * sx, 0.33, -0.2 + i * 0.2); body.add_child(lg)
			var knee := Vector3(0.3 * sx, 0.16, (i - 1) * 0.08)
			var foot := Vector3(0.48 * sx, -0.33, (i - 1) * 0.16)
			bone(lg, Vector3.ZERO, knee, 0.055, 0.045, dark, 0.1)
			bone(lg, knee, foot, 0.045, 0.018, dark, 0.15)
			Models.part(lg, _sph(0.05), shell, knee, Vector3(1.0, 0.9, 1.0))
	return Vector3(0, 0.66, 0.2)

# ------------------------------------------------------------------ spitter
static func _spitter(body: Node3D, M: Dictionary) -> Vector3:
	var dark: Material = M["dark"]
	var leaf := _mat(Color("4f8a3e").lerp(Color(M["body"].get_shader_parameter("albedo")), 0.35), 1, "")
	M["leaf"] = leaf
	# roots clawing into the ground
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		bone(body, Vector3(0, 0.3, 0) + d * 0.05, d * 0.36 + Vector3(0, 0.08, 0), 0.08, 0.05, dark)
		bone(body, d * 0.36 + Vector3(0, 0.08, 0), d * 0.55 + Vector3(0, -0.02, 0), 0.05, 0.02, dark)
	# a bent stalk
	bone(body, Vector3(0, 0.12, 0), Vector3(0, 0.45, 0.03), 0.15, 0.12, dark, 0.15)
	bone(body, Vector3(0, 0.45, 0.03), Vector3(0, 0.72, -0.02), 0.12, 0.13, dark, 0.1)
	# leaves at the foot of the pod, on pivots so they can flinch and sway
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var lf := Node3D.new(); lf.name = "Leaf%d" % i; lf.position = Vector3(cos(a) * 0.1, 0.62, sin(a) * 0.1); lf.rotation.y = -a
		body.add_child(lf)
		Models.part(lf, _sph(0.2), leaf, Vector3(0.3, -0.06, 0), Vector3(1.7, 0.18, 0.75), Vector3(0, 0, -0.45))
		Models.part(lf, _sph(0.03), dark, Vector3(0.3, -0.04, 0), Vector3(9.0, 0.6, 0.6), Vector3(0, 0, -0.45))
	var bulb := Node3D.new(); bulb.name = "Bulb"; bulb.position = Vector3(0, 0.95, 0); body.add_child(bulb)
	var pod: Material = M["body"]
	Models.part(bulb, _sph(0.38), pod, Vector3(0, 0.0, 0.04), Vector3(1.0, 1.0, 1.08))
	# ribs down the pod
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		if absf(sin(a)) > 0.95 and sin(a) < 0: continue     # leave the maw's side clear
		Models.part(bulb, _sph(0.1), M["belly"], Vector3(cos(a) * 0.33, 0.0, sin(a) * 0.35 + 0.04), Vector3(0.45, 3.6, 0.45), Vector3(0, -a, 0))
	# a crown of small spikes on top
	for i in 5:
		var a := TAU * i / 5.0
		horn(bulb, Vector3(cos(a) * 0.13, 0.33, sin(a) * 0.13 + 0.04), Vector3(cos(a) * 0.5, 1, sin(a) * 0.5), 0.04, 0.16, M["bone"])
	# the maw: a lipped opening at the front, a glowing acid throat, teeth round the rim
	var throat := _glow(Color("b8ff5a"), 1.1); M["throat"] = throat
	var mc := Vector3(0, -0.02, -0.33)
	Models.part(bulb, _sph(0.2), M["dark"], mc + Vector3(0, 0, 0.02), Vector3(1.15, 1.0, 0.55))
	Models.part(bulb, _sph(0.15), M["mouth"], mc + Vector3(0, 0, -0.02), Vector3(1.05, 0.95, 0.5))
	Models.part(bulb, _sph(0.09), throat, mc + Vector3(0, 0, 0.02), Vector3(1.0, 1.0, 0.5))
	for i in 8:
		var a := TAU * i / 8.0
		var rp := mc + Vector3(cos(a) * 0.17, sin(a) * 0.15, -0.04)
		horn(bulb, rp, -Vector3(cos(a), sin(a), 0.6), 0.025, 0.08, M["bone"])
	# eyes above the maw
	eyes(bulb, Vector3(0, 0.0, 0.04), Vector3(0.38, 0.38, 0.41), 0.32, 0.55, 0.045, M, M["dark"])
	return Vector3(0, 0.32, 0.12)

# ------------------------------------------------------------------ brute / warden
static func _brute(body: Node3D, M: Dictionary, warden: bool) -> Vector3:
	var skin: Material = M["body"]
	var dark: Material = M["dark"]
	var rock := _mat(Color("6a625e"), 0, "rock")
	M["rock"] = rock
	# legs: short and thick, on hip pivots
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new(); leg.name = "LegL" if sx < 0 else "LegR"
		leg.position = Vector3(0.3 * sx, 0.72, 0.08); body.add_child(leg)
		bone(leg, Vector3(0, 0.02, 0), Vector3(0.04 * sx, -0.4, -0.02), 0.22, 0.17, skin, 0.15)
		bone(leg, Vector3(0.04 * sx, -0.4, -0.02), Vector3(0.05 * sx, -0.62, -0.02), 0.16, 0.15, dark, 0.05)
		Models.part(leg, _sph(0.18), dark, Vector3(0.05 * sx, -0.64, -0.1), Vector3(1.05, 0.55, 1.35))
		for t in 3:
			horn(leg, Vector3(0.05 * sx + (t - 1) * 0.08, -0.66, -0.31), Vector3(0, -0.3, -1), 0.035, 0.08, M["bone"])
	var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.82, 0); body.add_child(torso)
	# a hunched barrel of a body: belly, chest, the great hump of the shoulders
	Models.part(torso, _sph(0.5), M["belly"], Vector3(0, 0.22, -0.12), Vector3(1.15, 0.95, 0.9))
	Models.part(torso, _sph(0.6), skin, Vector3(0, 0.52, 0.04), Vector3(1.25, 0.95, 0.95))
	Models.part(torso, _sph(0.48), skin, Vector3(0, 0.82, 0.18), Vector3(1.35, 0.8, 1.0))
	for sx in [-1.0, 1.0]:
		# shoulders and pecs
		Models.part(torso, _sph(0.32), skin, Vector3(0.52 * sx, 0.84, -0.02), Vector3(1.0, 0.9, 1.0))
		Models.part(torso, _sph(0.26), M["belly"], Vector3(0.22 * sx, 0.6, -0.36), Vector3(1.1, 0.8, 0.6))
	# rock plates growing out of the back
	# (big enough to read from the match camera: a ridge of slabs down the spine and two flanking)
	var plates := [[Vector3(0, 1.2, 0.2), 0.3], [Vector3(0, 1.08, 0.48), 0.27], [Vector3(0, 0.82, 0.66), 0.22],
		[Vector3(-0.42, 1.04, 0.3), 0.22], [Vector3(0.42, 1.06, 0.28), 0.23]]
	for pl in plates:
		Models.part(torso, Models.crystal(pl[1], pl[1] * 1.7, 5), rock, pl[0], Vector3(1.0, 0.85, 0.7), Vector3(-0.55, float(pl[0].x) * 1.5, -float(pl[0].x) * 0.6))
	var hd := Node3D.new(); hd.name = "Head"; hd.position = Vector3(0, 0.86, -0.42); torso.add_child(hd)
	var hc := Vector3(0, 0.0, -0.05)
	Models.part(hd, _sph(0.24), skin, hc, Vector3(1.1, 0.95, 1.0))
	# a jutting jaw with an underbite and tusks
	Models.part(hd, _sph(0.2), dark, hc + Vector3(0, -0.14, -0.1), Vector3(1.25, 0.6, 1.0))
	for sx in [-1.0, 1.0]:
		horn(hd, hc + Vector3(0.12 * sx, -0.1, -0.24), Vector3(0.15 * sx, 1, -0.25), 0.045, 0.16, M["bone"])
		# stubby horns
		horn(hd, hc + Vector3(0.15 * sx, 0.16, 0.02), Vector3(0.8 * sx, 0.7, 0.1), 0.06, 0.2, M["bone"], Vector3(0, 0.6, 0.3))
	eyes(hd, hc, Vector3(0.26, 0.23, 0.25), 0.42, 0.12, 0.045, M, dark)
	# arms: thick upper arms, huge forearms, rock-knuckled fists hanging near the ground
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new(); arm.name = "ArmL" if sx < 0 else "ArmR"
		arm.position = Vector3(0.66 * sx, 0.82, -0.02); torso.add_child(arm)
		var elbow := Vector3(0.14 * sx, -0.48, 0.04)
		var wrist := Vector3(0.12 * sx, -0.92, -0.12)
		bone(arm, Vector3.ZERO, elbow, 0.2, 0.16, skin, 0.18)
		bone(arm, elbow, wrist, 0.19, 0.17, skin, 0.3)
		Models.part(arm, _sph(0.24), dark, wrist + Vector3(0, -0.12, -0.04), Vector3(1.05, 0.9, 1.1))
		for t in 3:
			Models.part(arm, _sph(0.08), rock, wrist + Vector3((t - 1) * 0.11, -0.12, -0.24), Vector3(1.0, 0.9, 0.8))
		# a rock plate on the forearm
		Models.part(arm, Models.crystal(0.13, 0.22, 5), rock, (elbow + wrist) * 0.5 + Vector3(0.12 * sx, 0, 0.06), Vector3(1, 1, 0.7), Vector3(0, 0, -1.1 * sx))
	if warden:
		var gold := _mat(Color("f2c84a"), 3); gold.set_shader_parameter("gloss", 0.6); M["gold"] = gold
		var gem := _glow(Color("c9a0ff"), 1.0); M["gem"] = gem
		# a gold crown of spikes, gold pauldrons, a violet heart-gem in the chest
		Models.part(hd, Models.cyl(0.2, 0.22, 0.1, 14), gold, hc + Vector3(0, 0.22, 0.02))
		for i in 5:
			var a := TAU * i / 5.0
			horn(hd, hc + Vector3(cos(a) * 0.18, 0.26, sin(a) * 0.18 + 0.02), Vector3(cos(a) * 0.2, 1, sin(a) * 0.2), 0.05, 0.2, gold)
		for sx in [-1.0, 1.0]:
			Models.part(torso, _sph(0.3), gold, Vector3(0.6 * sx, 0.98, 0.0), Vector3(1.1, 0.55, 1.1), Vector3(0, 0, 0.35 * sx))
			horn(torso, Vector3(0.66 * sx, 1.1, 0.02), Vector3(0.5 * sx, 1, 0), 0.07, 0.24, gold)
		Models.part(torso, _sph(0.12), gem, Vector3(0, 0.62, -0.52), Vector3(1.0, 1.2, 0.6))
		Models.part(torso, _sph(0.16), gold, Vector3(0, 0.62, -0.47), Vector3(1.0, 1.2, 0.4))
	return Vector3(0, 1.0, 0.3)

# ------------------------------------------------------------------ bomber
static func _bomber(body: Node3D, M: Dictionary) -> Vector3:
	var puff := Node3D.new(); puff.name = "Puff"; body.add_child(puff)
	var c := Vector3(0, 0.55, 0)
	Models.part(puff, _sph(0.44), M["body"], c, Vector3(1.0, 0.95, 1.0))
	Models.part(puff, _sph(0.36), M["belly"], c + Vector3(0, -0.12, -0.14), Vector3(1.0, 0.8, 0.9))
	# spines all over the upper body, dark at the root
	var n := 14
	for i in n:
		var y := 1.0 - (float(i) + 0.5) / n * 1.25
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		var a := i * 2.39996
		var d := Vector3(cos(a) * rr, y, sin(a) * rr)
		if d.z < -0.55 and d.y < 0.5: continue     # not over the face
		horn(puff, c + d * 0.4, d, 0.06, 0.2, M["dark"])
	# a pursed mouth and angry eyes
	Models.part(puff, _sph(0.07), M["mouth"], c + Vector3(0, -0.08, -0.42), Vector3(1.0, 0.8, 0.5))
	Models.part(puff, _sph(0.09), M["dark"], c + Vector3(0, -0.08, -0.4), Vector3(1.2, 1.0, 0.5))
	eyes(puff, c, Vector3(0.44, 0.42, 0.44), 0.36, 0.22, 0.05, M, M["dark"])
	# stubby fins to waddle-flap with
	for sx in [-1.0, 1.0]:
		var fin := Node3D.new(); fin.name = "FinL" if sx < 0 else "FinR"; fin.position = c + Vector3(0.4 * sx, -0.05, 0.05); puff.add_child(fin)
		Models.part(fin, _sph(0.14), M["dark"], Vector3(0.1 * sx, 0, 0.02), Vector3(1.2, 0.3, 0.9), Vector3(0, 0, 0.4 * sx))
	# the fuse: a stub of cord curling out of the top, and its spark
	bone(puff, c + Vector3(0, 0.38, 0.04), c + Vector3(0.04, 0.55, 0.08), 0.035, 0.03, M["mouth"])
	Models.part(puff, Models.cyl(0.07, 0.09, 0.07, 10), M["bone"], c + Vector3(0, 0.4, 0.04))
	var spark := Node3D.new(); spark.name = "Spark"; spark.position = c + Vector3(0.05, 0.6, 0.09); puff.add_child(spark)
	var sg := _glow(Color("ffd25a"), 1.6); M["spark"] = sg
	Models.part(spark, _sph(0.07), sg, Vector3.ZERO)
	for i in 4:
		var a := TAU * i / 4.0
		Models.part(spark, _sph(0.025), sg, Vector3(cos(a), 0.4, sin(a)) * 0.09, Vector3(1, 2.5, 1), Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7))
	return Vector3(0, 0.95, 0.12)

# ------------------------------------------------------------------ sentinel
static func _sentinel(body: Node3D, M: Dictionary) -> Vector3:
	var stone := _mat(Color("8a8478"), 0, "")
	M["stone"] = stone
	var stone2 := _mat(Color("6e6a66"), 0, "")
	M["stone2"] = stone2
	var rune := _glow(Color(M["body"].get_shader_parameter("albedo")).lightened(0.25), 1.0)
	rune.set_meta("mob_part", "glow")
	M["rune"] = rune
	# a stepped plinth of cut stone, chipped, with a carved pillar
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.56, 0), Vector2(0.6, 0.06), Vector2(0.56, 0.2), Vector2(0.44, 0.24),
		Vector2(0.42, 0.34), Vector2(0.3, 0.38), Vector2(0.27, 0.5), Vector2(0.24, 0.85), Vector2(0.3, 0.9), Vector2(0.36, 0.98),
		Vector2(0.34, 1.04), Vector2(0.2, 1.06), Vector2(0, 1.06)])
	Models.part(body, Models.lathe(Models.smooth_curve(prof, 2), 20, "sentinel_plinth"), stone, Vector3.ZERO, Vector3(1, 1, 1), Vector3(0, PI / 8, 0))
	# carved bands round the pillar, moss on the plinth's step
	for y in [0.52, 0.8]:
		Models.part(body, Models.cyl(0.29, 0.29, 0.05, 16), stone2, Vector3(0, y, 0))
	var moss := _mat(Color("5f8a45"), 1, "")
	M["moss"] = moss
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		Models.part(body, _sph(0.13), moss, Vector3(cos(a) * 0.36, 0.33, sin(a) * 0.36), Vector3(1.3, 0.45, 1.0), Vector3(0, -a, 0))
	# glowing rune slots up the pillar's four faces and a ring of them on the plinth
	for i in 4:
		var a := TAU * i / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		Models.part(body, Models.box(0.06, 0.26, 0.03), rune, d * 0.25 + Vector3(0, 0.66, 0), Vector3.ONE, Vector3(0, -a + PI / 2, 0))
		Models.part(body, Models.box(0.12, 0.03, 0.03), rune, d * 0.4 + Vector3(0, 0.28, 0), Vector3.ONE, Vector3(0, -a + PI / 2, 0))
	# broken stones at its foot
	for i in 3:
		var a := TAU * i / 3.0 + 0.6
		Models.part(body, Models.crystal(0.12, 0.2, 5), stone2, Vector3(cos(a) * 0.62, 0.05, sin(a) * 0.62), Vector3(1, 0.7, 1), Vector3(0.6, a, 0.3))
	# three claws holding the crystal up
	for i in 3:
		var a := TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		horn(body, d * 0.22 + Vector3(0, 1.0, 0), d + Vector3(0, 1.6, 0), 0.07, 0.36, stone2, -d * 0.9)
	var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 1.25, 0); body.add_child(cr)
	var cm := _mat(Color(M["body"].get_shader_parameter("albedo")), 6, "body")
	cm.set_shader_parameter("glow", 0.5); cm.set_shader_parameter("gloss", 0.7)
	M["crystal"] = cm
	Models.part(cr, Models.crystal(0.2, 0.62, 6), cm, Vector3(0, 0.05, 0))
	Models.part(cr, Models.crystal(0.2, 0.3, 6), cm, Vector3(0, -0.18, 0), Vector3.ONE, Vector3(PI, 0, 0))
	Models.part(cr, _sph(0.07), M["eye"], Vector3(0, 0.02, -0.17), Vector3(1.2, 1.2, 0.5))
	var sh := Node3D.new(); sh.name = "Shards"; cr.add_child(sh)
	for i in 4:
		var a := TAU * i / 4.0
		Models.part(sh, Models.crystal(0.06, 0.22, 4), cm, Vector3(cos(a) * 0.42, sin(a * 2.0) * 0.06, sin(a) * 0.42), Vector3.ONE, Vector3(0.3, a, 0.2))
	return Vector3(0, 1.04, 0)

# ------------------------------------------------------------------ glimmer
static func _glimmer(body: Node3D, M: Dictionary) -> Vector3:
	var gold: ShaderMaterial = M["body"]
	gold.set_shader_parameter("gloss", 0.7)
	gold.set_shader_parameter("glow", 0.25)
	var c := Vector3(0, 0.42, 0)
	Models.part(body, _sph(0.36), gold, c, Vector3(1.0, 0.92, 1.08))
	Models.part(body, _sph(0.28), M["belly"], c + Vector3(0, -0.08, -0.14), Vector3(1.0, 0.85, 0.8))
	# little feet
	for sx in [-1.0, 1.0]:
		Models.part(body, _sph(0.1), M["dark"], Vector3(0.17 * sx, 0.08, -0.08), Vector3(1.0, 0.6, 1.3))
	# long ears on pivots
	for sx in [-1.0, 1.0]:
		var ear := Node3D.new(); ear.name = "EarL" if sx < 0 else "EarR"; ear.position = c + Vector3(0.17 * sx, 0.28, 0.04); ear.rotation.z = -0.35 * sx
		body.add_child(ear)
		Models.part(ear, _sph(0.12), gold, Vector3(0, 0.24, 0), Vector3(0.7, 2.3, 0.45))
		Models.part(ear, _sph(0.09), M["belly"], Vector3(0, 0.24, -0.03), Vector3(0.6, 2.0, 0.3))
	# friendly eyes (it's the treasure, not a threat): big, dark and shiny
	var iris := Models.toon(Color("2b2a33"), false)
	iris.set_shader_parameter("gloss", 0.8)
	M["iris"] = iris
	for sx in [-1.0, 1.0]:
		Models.part(body, _sph(0.065), iris, c + Vector3(0.12 * sx, 0.08, -0.32), Vector3(1.0, 1.25, 0.6))
		Models.part(body, _sph(0.02), M["bone"], c + Vector3(0.12 * sx + 0.02, 0.12, -0.36))
	# gems set in its back, and sparkles that turn with it
	var gem := _glow(Color("8ff0ff"), 0.9); M["gem"] = gem
	var gem2 := _glow(Color("ff8ad8"), 0.9); M["gem2"] = gem2
	for i in 4:
		var a := PI * 0.25 + i * 0.55
		Models.part(body, Models.crystal(0.06, 0.12, 5), gem if i % 2 == 0 else gem2, c + Vector3(cos(a) * 0.28, 0.22, sin(a) * 0.3), Vector3.ONE, Vector3(-0.4, 0, 0))
	var sp := _glow(Color("fff4c0"), 1.4); M["sparkle"] = sp
	for i in 3:
		var a := TAU * i / 3.0
		var pm := PrismMesh.new(); pm.size = Vector3(0.14, 0.2, 0.05)
		Models.part(body, pm, sp, Vector3(cos(a) * 0.58, 0.9, sin(a) * 0.58))
		Models.part(body, pm, sp, Vector3(cos(a) * 0.58, 0.72, sin(a) * 0.58), Vector3.ONE, Vector3(PI, 0, 0))
	return Vector3.ZERO

# ------------------------------------------------------------------ biome dress
## A little of the island on a monster's back: moss and sprouts, flowers, ice, embers, storm
## crystals or glowing toadstools. Merged into a single mesh or two.
static func dress(root: Node3D, style: String) -> void:
	var r := float(root.get_meta("back_r", 0.0))
	if r <= 0.0 or not root.has_meta("back_node"):
		return
	var host := root.get_node_or_null(root.get_meta("back_node")) as Node3D
	if host == null:
		return
	var at: Vector3 = root.get_meta("back", Vector3.ZERO)
	var g := Node3D.new(); g.name = "Dress"; g.position = at; host.add_child(g)
	var rng := RandomNumberGenerator.new(); rng.seed = hash(str(root.get_instance_id()))
	var mats: Array = root.get_meta("mats", [])
	var add := func(c: Color, glow: float) -> ShaderMaterial:
		var m: ShaderMaterial = _glow(c, glow) if glow > 0.0 else _mat(c, 1)
		mats.append(m)
		return m
	match style:
		"meadow", "bloom":
			var moss: ShaderMaterial = add.call(Color("5f9a45") if style == "meadow" else Color("74b05a"), 0.0)
			Models.part(g, _sph(r * 0.7), moss, Vector3(0, 0.0, 0), Vector3(1.3, 0.35, 1.2))
			for i in 4:
				var a := rng.randf() * TAU
				var p := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.2, 0.6)
				horn(g, p, Vector3(rng.randf_range(-0.3, 0.3), 1, rng.randf_range(-0.3, 0.3)), r * 0.09, r * rng.randf_range(0.4, 0.7), moss)
			if style == "bloom":
				var pet: ShaderMaterial = add.call(Color("ff9ac8"), 0.0)
				var mid: ShaderMaterial = add.call(Color("fff3a8"), 0.3)
				for i in 3:
					var p := Vector3(rng.randf_range(-0.5, 0.5), 0.08, rng.randf_range(-0.5, 0.5)) * r
					for k in 5:
						var a := TAU * k / 5.0
						Models.part(g, _sph(r * 0.1), pet, p + Vector3(cos(a), 0, sin(a)) * r * 0.1, Vector3(1.0, 0.4, 1.0))
					Models.part(g, _sph(r * 0.06), mid, p + Vector3(0, r * 0.03, 0))
		"frost":
			var ice: ShaderMaterial = add.call(Color("bfe8ff"), 0.25)
			ice.set_shader_parameter("gloss", 0.7)
			var snow: ShaderMaterial = add.call(Color("f2f6ff"), 0.0)
			Models.part(g, _sph(r * 0.7), snow, Vector3.ZERO, Vector3(1.3, 0.3, 1.2))
			for i in 4:
				var a := TAU * i / 4.0 + rng.randf()
				var p := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.0, 0.5)
				Models.part(g, Models.crystal(r * 0.14, r * rng.randf_range(0.6, 1.0), 5), ice, p + Vector3(0, r * 0.25, 0), Vector3.ONE, Vector3(rng.randf_range(-0.5, 0.5), a, rng.randf_range(-0.5, 0.5)))
		"ember":
			var ash: ShaderMaterial = add.call(Color("3a3030"), 0.0)
			var coal: ShaderMaterial = add.call(Color("ff7a2a"), 1.3)
			for i in 4:
				var a := TAU * i / 4.0 + rng.randf()
				var p := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.1, 0.55)
				Models.part(g, Models.crystal(r * 0.2, r * 0.45, 5), ash, p + Vector3(0, r * 0.1, 0), Vector3.ONE, Vector3(rng.randf_range(-0.4, 0.4), a, 0))
				Models.part(g, _sph(r * 0.09), coal, p + Vector3(0, r * 0.05, 0) + Vector3(cos(a + 1.0), 0, sin(a + 1.0)) * r * 0.15)
		"storm":
			var cry: ShaderMaterial = add.call(Color("8fd8ff"), 0.7)
			for i in 3:
				var a := TAU * i / 3.0 + rng.randf()
				var p := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.0, 0.45)
				Models.part(g, Models.crystal(r * 0.13, r * rng.randf_range(0.7, 1.1), 4), cry, p + Vector3(0, r * 0.3, 0), Vector3.ONE, Vector3(rng.randf_range(-0.6, 0.6), a, rng.randf_range(-0.6, 0.6)))
		"gloom":
			var stem: ShaderMaterial = add.call(Color("d8c8e8"), 0.0)
			var cap: ShaderMaterial = add.call(Color("b48cff"), 0.6)
			for i in 3:
				var a := TAU * i / 3.0 + rng.randf()
				var p := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.1, 0.5)
				var hgt := r * rng.randf_range(0.25, 0.45)
				Models.part(g, Models.cyl(r * 0.04, r * 0.05, hgt, 6), stem, p + Vector3(0, hgt * 0.5, 0))
				Models.part(g, _sph(r * 0.16), cap, p + Vector3(0, hgt, 0), Vector3(1.0, 0.55, 1.0))
	root.set_meta("mats", mats)
	Models.merge_static(g)
	Models.bake_part_y(g)
