class_name ModelsHair
## Race hair, head styles and race parts. Moved out of Models; callers still use the Models facade.


## A cone of radius r and length h growing from `at` along `dir` (spikes, fur tufts, horns).
static func _spike(n: Node3D, m: Material, at: Vector3, dir: Vector3, r: float, h: float, flat := 1.0) -> MeshInstance3D:
	var d := dir.normalized()
	var mi := ModelsBase.part(n, ModelsBase.cyl(0.0, r, h), m, at + d * h * 0.5)
	var b := Basis(Quaternion(Vector3.UP, d)) if absf(d.dot(Vector3.UP)) < 0.9999 else (Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI))
	mi.basis = b * Basis.from_scale(Vector3(flat, 1.0, 1.0))
	return mi

## A soft blade (a feather, a leaf, a petal, a fin): an elongated, flattened ellipsoid from `at`
## along `dir`, `w` wide; `face` turns its flat side.
static func _blade(n: Node3D, m: Material, at: Vector3, dir: Vector3, ln: float, w: float, face := 0.0, thick := 0.24) -> MeshInstance3D:
	var d := dir.normalized()
	var mi := ModelsBase.part(n, _blade_mesh(), m, at + d * ln * 0.5)
	var b := Basis(Quaternion(Vector3.UP, d)) if absf(d.dot(Vector3.UP)) < 0.9999 else (Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI))
	mi.basis = b * Basis(Vector3.UP, face) * Basis.from_scale(Vector3(w, ln, w * thick))
	return mi

static var _blade_m: SphereMesh
## The unit ellipsoid every blade is stretched from (small on screen, so a modest segment count).
static func _blade_mesh() -> SphereMesh:
	if _blade_m == null:
		_blade_m = SphereMesh.new()
		_blade_m.radius = 0.5; _blade_m.height = 1.0; _blade_m.radial_segments = 24; _blade_m.rings = 14
	return _blade_m

## A point on the head (centre 0, 0.86, 0, radius about 0.235) in the direction (x, y, z).
static func _on_head(x: float, y: float, z: float, out := 0.0) -> Vector3:
	return Vector3(0, 0.86, 0) + Vector3(x, y, z).normalized() * (0.23 + out)

## Each race's own head styles (see HAIR_STYLES): fur for the Vulpin (parted round their ears),
## crystals, stone and moss for the Stoneborn, leaves and flowers for Sprigs, crests, frills, horns
## and spines for Scalefolk, feathers for Owlets. All in the hair colour.
static func _race_hair(n: Node3D, rid: String, style: int, m_hair: Material, hair_c: Color, skin_c: Color, covered: bool) -> void:
	var light := ModelsBase.toon(hair_c.lightened(0.3)); (light as ShaderMaterial).set_shader_parameter("rim_amount", 0.75)
	var dark := ModelsBase.toon(hair_c.darkened(0.25))
	match rid:
		"vulpin":
			var tip := ModelsBase.toon(hair_c.lightened(0.55))
			if not covered:
				ModelsBase.part(n, ModelsBase.sphere(0.248), m_hair, Vector3(0, 0.905, 0.03), Vector3(1.04, 0.8 if style == 5 else 0.85, 1.02))
			match style:
				0:   # fluffy tuft: a curl of fur between the ears, cheek fluff
					for i in 3:
						var a := (i - 1) * 0.4
						_spike(n, m_hair, _on_head(sin(a) * 0.35, 0.9, -0.5), Vector3(sin(a) * 0.4, 0.6, -0.9), 0.065 - absf(i - 1) * 0.012, 0.2)
					for sx in [-1.0, 1.0]:
						_spike(n, m_hair, _on_head(0.9 * sx, -0.35, -0.2), Vector3(sx, -0.45, -0.1), 0.055, 0.15)
				1:   # mane: a ruff of fur round the back of the head and the neck
					for k in 9:
						var a := (k - 4) * 0.36
						var d := Vector3(sin(a), -0.35, cos(a))
						_spike(n, m_hair if k % 2 == 0 else light, Vector3(0, 0.8, 0.03) + Vector3(sin(a), 0, cos(a)) * 0.16, d, 0.085, 0.2)
					for i in 3:
						_spike(n, m_hair, _on_head((i - 1) * 0.3, 0.9, -0.45), Vector3((i - 1) * 0.3, 0.3, -1.0), 0.05, 0.13)
				2:   # long fur down the back, tips lighter
					ModelsBase.part(n, ModelsBase.capsule(0.17, 0.5), m_hair, Vector3(0, 0.71, 0.11), Vector3(1.3, 1.0, 0.65))
					for i in 3:
						_spike(n, tip, Vector3((i - 1) * 0.11, 0.5, 0.15), Vector3((i - 1) * 0.2, -1.0, 0.15), 0.07, 0.16)
				3:   # brush tail: a fat fox brush of a ponytail with a white tip
					for p in [[Vector3(0, 0.99, 0.2), 0.08], [Vector3(0, 0.92, 0.29), 0.1], [Vector3(0, 0.8, 0.34), 0.112], [Vector3(0, 0.68, 0.34), 0.095]]:
						ModelsBase.part(n, ModelsBase.sphere(float(p[1])), m_hair, p[0])
					ModelsBase.part(n, ModelsBase.sphere(0.075), tip, Vector3(0, 0.58, 0.31))
				4:   # spiky fur swept back over the crown
					for i in 6:
						var a := (i - 2.5) * 0.32
						_spike(n, m_hair, _on_head(sin(a) * 0.6, 0.75, 0.2 + absf(a) * 0.1), Vector3(sin(a) * 0.6, 0.5, 1.0), 0.06, 0.22)
				5:   # sleek: close fur with a flick at the back and cheek tufts
					_spike(n, m_hair, _on_head(0, 0.2, 1.0), Vector3(0, -0.6, 1.0), 0.07, 0.2)
					for sx in [-1.0, 1.0]:
						_spike(n, tip, _on_head(0.92 * sx, -0.3, -0.25), Vector3(sx, -0.3, 0), 0.05, 0.13)
				6:   # fringe: soft locks over the forehead
					for k in 4:
						ModelsBase.part(n, ModelsBase.sphere(0.075), m_hair, Vector3(-0.12 + k * 0.08, 0.99 - absf(k - 1.5) * 0.015, -0.17), Vector3(0.9, 1.0, 0.7), Vector3(0.4, 0, -0.3 + k * 0.2))
					for sx in [-1.0, 1.0]:
						_spike(n, m_hair, _on_head(0.85 * sx, -0.1, -0.35), Vector3(0.3 * sx, -1.0, -0.1), 0.055, 0.18)
		"stoneborn":
			var gem := ModelsBase.toon(hair_c.lightened(0.15), false, 0.75); (gem as ShaderMaterial).set_shader_parameter("gloss", 0.8)
			var rock := ModelsBase.toon(skin_c.darkened(0.28).lerp(hair_c, 0.25))
			match style:
				0:   # crystal crown
					for c in [[Vector3(0, 1.14, 0.03), Vector3(-0.2, 0, 0), 0.38], [Vector3(0.12, 1.07, 0.06), Vector3(-0.35, 0, -0.55), 0.28], [Vector3(-0.13, 1.06, 0.05), Vector3(-0.3, 0, 0.6), 0.26], [Vector3(0.0, 1.0, 0.18), Vector3(-0.9, 0, 0), 0.22]]:
						ModelsBase.part(n, ModelsBase.crystal(0.085, float(c[2]), 6), gem, c[0], Vector3.ONE, c[1])
				1:   # crystal ridge: a row of shards front to back
					for i in 5:
						var h := 0.34 - absf(i - 1.5) * 0.06
						ModelsBase.part(n, ModelsBase.crystal(0.06, h, 5), gem, _on_head(0, 1.0 - absf(i - 1.5) * 0.1, -0.45 + i * 0.3) + Vector3(0, h * 0.35, 0), Vector3.ONE, Vector3(-0.35 + i * 0.22, 0, 0))
				2:   # stone ridge: rounded plates with glowing seams
					for i in 4:
						var at := _on_head(0, 1.0, -0.5 + i * 0.4, 0.01)
						var pl := ModelsBase.part(n, ModelsBase.box(0.16 - absf(i - 1.5) * 0.02, 0.09, 0.12), rock, at, Vector3.ONE, Vector3(-0.5 + i * 0.35, 0, 0))
						pl.position += Vector3(0, 0.02, 0)
						if i < 3: ModelsBase.part(n, ModelsBase.box(0.12, 0.03, 0.02), gem, _on_head(0, 1.0, -0.3 + i * 0.4, 0.03), Vector3.ONE, Vector3(-0.3 + i * 0.35, 0, 0))
				3:   # moss cap with a little crystal sprouting from it
					if not covered:
						ModelsBase.part(n, ModelsBase.sphere(0.25), m_hair, Vector3(0, 0.93, 0.03), Vector3(1.03, 0.68, 1.03))
					var rng := RandomNumberGenerator.new(); rng.seed = 77
					for k in 9:
						var a := TAU * k / 9.0
						ModelsBase.part(n, ModelsBase.sphere(0.05), light if k % 2 == 0 else m_hair, _on_head(cos(a) * 0.8, 0.75 + rng.randf() * 0.3, sin(a) * 0.8, 0.0), Vector3(1.0, 0.6, 1.0))
					ModelsBase.part(n, ModelsBase.crystal(0.04, 0.16, 5), gem, Vector3(0.06, 1.13, 0.0), Vector3.ONE, Vector3(0, 0, -0.3))
				4:   # geode: a cluster of crystals bursting out of the back of the head
					for c in [[Vector3(0.0, 0.25, 1.0), 0.3, 0.075], [Vector3(0.45, 0.5, 0.8), 0.22, 0.06], [Vector3(-0.45, 0.45, 0.85), 0.24, 0.06], [Vector3(0.15, 0.85, 0.5), 0.2, 0.055], [Vector3(-0.2, 0.9, 0.35), 0.16, 0.05], [Vector3(0.0, -0.1, 1.0), 0.18, 0.05]]:
						var d: Vector3 = (c[0] as Vector3).normalized()
						var mi := ModelsBase.part(n, ModelsBase.crystal(float(c[2]), float(c[1]), 6), gem, _on_head(d.x, d.y, d.z, -0.02) + d * float(c[1]) * 0.4)
						mi.basis = Basis(Quaternion(Vector3.UP, d))
		"sprig":
			var gold := ModelsBase.toon(Color("ffd84a"), true, 0.3)
			if not covered and style != 5:
				ModelsBase.part(n, ModelsBase.sphere(0.25), m_hair, Vector3(0, 0.9, 0.03), Vector3(1.03, 0.82, 1.0))
			match style:
				0:   # leaf crown
					for k in 7:
						var a := TAU * k / 7.0 + 0.2
						var d := Vector3(cos(a) * 0.55, 1.0, sin(a) * 0.55)
						_blade(n, m_hair if k % 2 == 0 else light, Vector3(cos(a) * 0.14, 1.03, sin(a) * 0.13 + 0.02), d, 0.24, 0.11, a)
				1:   # flower bud on top
					var c := Vector3(0, 1.13, 0.02)
					for k in 5:
						var a := TAU * k / 5.0
						_blade(n, light, c, Vector3(cos(a) * 0.8, 0.9, sin(a) * 0.8), 0.17, 0.12, a + PI * 0.5, 0.3)
					ModelsBase.part(n, ModelsBase.sphere(0.05), gold, c + Vector3(0, 0.03, 0))
					ModelsBase.part(n, ModelsBase.cyl(0.015, 0.02, 0.06, 8), dark, Vector3(0, 1.08, 0.02))
				2:   # vine locks, each ending in a leaf
					for k in 5:
						var a := PI * 0.5 + (k - 2) * 0.55
						var p := Vector3(cos(a) * 0.2, 0.86, sin(a) * 0.17 + 0.03)
						for j in 4:
							ModelsBase.part(n, ModelsBase.sphere(0.04 - j * 0.004), dark if j % 2 == 0 else m_hair, p + Vector3(cos(a) * j * 0.02, -j * 0.08, sin(a) * j * 0.02))
						_blade(n, light, p + Vector3(cos(a) * 0.08, -0.3, sin(a) * 0.08), Vector3(cos(a) * 0.3, -1.0, sin(a) * 0.3), 0.12, 0.07, a)
				3:   # a sprout: a stem and two leaves
					ModelsBase.part(n, ModelsBase.cyl(0.012, 0.016, 0.16, 8), dark, Vector3(0, 1.15, 0.0), Vector3.ONE, Vector3(0, 0, 0.1))
					for sx in [-1.0, 1.0]:
						_blade(n, light if sx > 0.0 else m_hair, Vector3(-0.008, 1.22, 0.0), Vector3(sx, 0.55, 0), 0.2, 0.1, PI * 0.5, 0.3)
				4:   # petal bob: petals hanging round the head like a bob cut
					for k in 9:
						var a := PI * 0.5 + (k - 4) * 0.42
						var d := Vector3(cos(a), 0, sin(a))
						_blade(n, m_hair if k % 2 == 0 else light, Vector3(0, 0.97, 0.02) + d * 0.2, d * 0.35 + Vector3(0, -1.0, 0), 0.24, 0.13, a + PI * 0.5, 0.3)
				5:   # a toadstool cap with spots
					ModelsBase.part(n, ModelsBase.sphere(0.3), m_hair, Vector3(0, 1.02, 0.02), Vector3(1.15, 0.55, 1.15))
					ModelsBase.part(n, ModelsBase.cyl(0.26, 0.3, 0.03), ModelsBase.toon(Color("f3e6c8")), Vector3(0, 0.96, 0.02))
					var spot := ModelsBase.toon(Color("fbf6ee"))
					for k in 6:
						var a := TAU * k / 6.0
						ModelsBase.part(n, ModelsBase.sphere(0.04), spot, Vector3(cos(a) * 0.2, 1.12, sin(a) * 0.2 + 0.02), Vector3(1.0, 0.45, 1.0))
					ModelsBase.part(n, ModelsBase.sphere(0.045), spot, Vector3(0, 1.185, 0.02), Vector3(1.0, 0.4, 1.0))
		"scalefolk":
			match style:
				0, 4:   # crest of fins front to back (twin: two of them, splayed), and frills
					for side in ([0.0] if style == 0 else [-1.0, 1.0]):
						for i in 5:
							var z := -0.1 + i * 0.075
							var h := 0.2 - absf(i - 1.5) * 0.025
							_blade(n, m_hair if i % 2 == 0 else light, Vector3(0.07 * side, 1.05 - i * 0.02, z), Vector3(0.3 * side, 1.0, 0.55 + i * 0.2), h + 0.04, 0.09, PI * 0.5, 0.3)
					for sx in [-1.0, 1.0]:
						_blade(n, dark, _on_head(0.9 * sx, 0.1, 0.25), Vector3(sx, 0.35, 0.4), 0.18, 0.1, 0.0, 0.25)
				1:   # frills: a fan of webbed spines round the back of the head
					for sx in [-1.0, 1.0]:
						for i in 4:
							var a := 0.15 + i * 0.32
							_blade(n, m_hair if i % 2 == 0 else light, _on_head(0.9 * sx, 0.1, 0.3), Vector3(sx * cos(a), sin(a) * 0.9 + 0.1, 0.5), 0.22 - i * 0.02, 0.12, 0.0, 0.2)
					_blade(n, dark, _on_head(0, 0.5, 0.9), Vector3(0, 0.4, 1.0), 0.2, 0.14, PI * 0.5, 0.2)
				2:   # horns swept back, and two small brow nubs
					for sx in [-1.0, 1.0]:
						var p := _on_head(0.45 * sx, 0.75, 0.15, -0.02)
						var d := Vector3(0.35 * sx, 0.6, 0.75)
						var r := 0.05
						for j in 4:
							var dd := d.normalized()
							if j == 3:
								_spike(n, light, p, dd, r, 0.13)
							else:
								KinModels.seg(n, p, p + dd * 0.11, r, r * 0.8, m_hair, 14)
								ModelsBase.part(n, ModelsBase.sphere(r * 0.8), m_hair, p + dd * 0.11)
							p += dd * 0.11
							r *= 0.8
							d = d.rotated(Vector3.RIGHT, 0.4)
						_spike(n, dark, _on_head(0.35 * sx, 0.55, -0.75), Vector3(0.2 * sx, 1.0, -0.2), 0.025, 0.06)
				3:   # spines: rows of little spikes over the crown and down the neck
					for row in 3:
						var x := (row - 1) * 0.35
						for i in 5:
							var at := _on_head(x, 1.0 - i * 0.35, -0.3 + i * 0.4, -0.01)
							_spike(n, m_hair if (row + i) % 2 == 0 else light, at, (at - Vector3(0, 0.86, 0)).normalized() + Vector3(0, 0, 0.5), 0.035 - absf(row - 1) * 0.008, 0.11 - absf(row - 1) * 0.03)
		"owlet":
			match style:
				0:   # ear tufts: a pair of feathers each side
					for sx in [-1.0, 1.0]:
						_blade(n, m_hair, Vector3(0.15 * sx, 1.04, 0.0), Vector3(0.6 * sx, 1.0, 0.1), 0.3, 0.1, 0.0, 0.25)
						_blade(n, light, Vector3(0.12 * sx, 1.04, 0.04), Vector3(0.35 * sx, 1.0, 0.2), 0.22, 0.08, 0.0, 0.25)
				1:   # feather crest fanning up from the brow
					for i in 5:
						var a := (i - 2) * 0.3
						_blade(n, m_hair if i % 2 == 0 else light, _on_head(sin(a) * 0.3, 0.9, -0.3), Vector3(sin(a) * 0.5, 1.0, 0.45), 0.28 - absf(i - 2) * 0.04, 0.085, PI * 0.5 + a, 0.25)
				2:   # plume: two tall curling feathers
					_blade(n, m_hair, Vector3(0, 1.06, 0.02), Vector3(0.05, 1.0, 0.35), 0.4, 0.1, PI * 0.5, 0.22)
					_blade(n, light, Vector3(0.02, 1.06, 0.0), Vector3(0.3, 1.0, 0.1), 0.3, 0.08, PI * 0.5, 0.22)
				3:   # fluffy crown: soft feathers all over the top
					if not covered:
						ModelsBase.part(n, ModelsBase.sphere(0.248), m_hair, Vector3(0, 0.91, 0.03), Vector3(1.03, 0.84, 1.02))
					for k in 10:
						var a := TAU * k / 10.0
						var at := _on_head(cos(a) * 0.55, 0.85, sin(a) * 0.55)
						_blade(n, light if k % 2 == 0 else m_hair, at, (at - Vector3(0, 0.86, 0)) + Vector3(0, 0.12, 0), 0.13, 0.08, a, 0.35)
				4:   # swept back: feathers laid back along the head
					if not covered:
						ModelsBase.part(n, ModelsBase.sphere(0.246), m_hair, Vector3(0, 0.9, 0.04), Vector3(1.02, 0.82, 1.02))
					for i in 5:
						var x := (i - 2) * 0.07
						_blade(n, light if i % 2 == 0 else m_hair, _on_head(x * 2.5, 0.85, -0.2), Vector3(x, 0.25, 1.0), 0.32, 0.075, PI * 0.5, 0.25)
				5:   # long plumes hanging down the back
					if not covered:
						ModelsBase.part(n, ModelsBase.sphere(0.246), m_hair, Vector3(0, 0.9, 0.04), Vector3(1.02, 0.82, 1.02))
					for i in 4:
						var x := (i - 1.5) * 0.08
						_blade(n, m_hair if i % 2 == 0 else light, _on_head(x * 2.0, 0.4, 0.9), Vector3(x, -1.0, 0.35), 0.44 - absf(i - 1.5) * 0.06, 0.08, PI * 0.5, 0.25)

## What each race adds: ears, tails, wings, snouts, crests, crystals.
static func _race_parts(torso: Node3D, rid: String, m_skin: Material, m_hair: Material, m_dark: Material, skin_c: Color, hair_c: Color, hero_col: Color) -> void:
	match rid:
		"vulpin":
			var inner := ModelsBase.toon(Color("ffb6bf"))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.16, 0.46, 4), m_hair, Vector3(0.17 * sx, 1.16, 0.01), Vector3(1.0, 1.0, 0.55), Vector3(0, 0.785, -0.4 * sx))
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.095, 0.3, 4), inner, Vector3(0.165 * sx, 1.13, -0.035), Vector3(1.0, 1.0, 0.3), Vector3(0, 0.785, -0.4 * sx))
			ModelsBase.part(torso, ModelsBase.sphere(0.1, 12), ModelsBase.toon(skin_c.lightened(0.35)), Vector3(0, 0.79, -0.19), Vector3(1.15, 0.75, 0.9))   # muzzle
			ModelsBase.part(torso, ModelsBase.sphere(0.035, 8), m_dark, Vector3(0, 0.81, -0.285))   # nose
			# the tail: a big brush that sweeps up behind, with a white tip
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.02, 0.26); torso.add_child(tail)
			var pts := [[Vector3(0, -0.02, 0.08), 0.11], [Vector3(0.07, 0.07, 0.28), 0.19], [Vector3(0.19, 0.21, 0.46), 0.23], [Vector3(0.31, 0.4, 0.55), 0.19]]
			for p in pts:
				ModelsBase.part(tail, ModelsBase.sphere(float(p[1]), 12), m_hair, p[0])
			ModelsBase.part(tail, ModelsBase.sphere(0.15, 10), ModelsBase.toon(Color("fbf6ee")), Vector3(0.39, 0.56, 0.57))
		"stoneborn":
			var rock := ModelsBase.toon(skin_c.darkened(0.28))
			var glow := ModelsBase.toon(hero_col.lightened(0.2), false, 0.9)
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.box(0.16, 0.12, 0.18), rock, Vector3(0.25 * sx, 0.62, 0.03), Vector3.ONE, Vector3(0.1, 0.3 * sx, -0.25 * sx))     # rock plates on the shoulders
				ModelsBase.part(torso, ModelsBase.crystal(0.05, 0.2, 6), glow, Vector3(0.24 * sx, 0.74, 0.1), Vector3.ONE, Vector3(-0.3, 0, -0.45 * sx))   # shoulder crystals
			# glowing cracks across the chest
			ModelsBase.part(torso, ModelsBase.box(0.025, 0.2, 0.02), glow, Vector3(-0.05, 0.36, -0.235), Vector3.ONE, Vector3(0, 0, 0.5))
			ModelsBase.part(torso, ModelsBase.box(0.025, 0.14, 0.02), glow, Vector3(0.05, 0.27, -0.235), Vector3.ONE, Vector3(0, 0, -0.6))
			ModelsBase.part(torso, ModelsBase.box(0.18, 0.08, 0.18), rock, Vector3(0, 0.84, -0.17), Vector3.ONE, Vector3(0.2, 0, 0))   # heavy brow
		"sprig":
			var tipm := ModelsBase.toon(hero_col.lightened(0.3), false, 1.0)
			for sx in [-1.0, 1.0]:
				# antennae with glowing tips, and long pointed ears
				ModelsBase.part(torso, ModelsBase.cyl(0.012, 0.014, 0.3, 6), m_dark, Vector3(0.08 * sx, 1.16, 0.0), Vector3.ONE, Vector3(-0.25, 0, -0.38 * sx))
				ModelsBase.part(torso, ModelsBase.sphere(0.045, 8), tipm, Vector3(0.14 * sx, 1.3, -0.04))
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.055, 0.2, 4), m_skin, Vector3(0.28 * sx, 0.88, 0.0), Vector3(1.0, 1.0, 0.5), Vector3(0, 0, -1.25 * sx))
			# leaf wings on the back, see-through and faintly lit
			var wing_m := StandardMaterial3D.new()
			wing_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			wing_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wing_m.albedo_color = Color(hero_col.lerp(Color("c8ffd8"), 0.5), 0.55)
			wing_m.cull_mode = BaseMaterial3D.CULL_DISABLED
			var wings := Node3D.new(); wings.name = "Wings"; wings.position = Vector3(0, 0.5, 0.3); torso.add_child(wings)
			for sx in [-1.0, 1.0]:
				var wmi := ModelsBase.part(wings, ModelsBase.sphere(0.26, 12), wing_m, Vector3(0.26 * sx, 0.1, 0.1), Vector3(0.8, 1.9, 0.06), Vector3(1.0, 0.35 * sx, 0.95 * sx))
				wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var w2 := ModelsBase.part(wings, ModelsBase.sphere(0.18, 12), wing_m, Vector3(0.2 * sx, -0.16, 0.12), Vector3(0.75, 1.5, 0.06), Vector3(1.0, 0.25 * sx, 2.0 * sx))
				w2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"scalefolk":
			ModelsBase.part(torso, ModelsBase.sphere(0.16, 14), m_skin, Vector3(0, 0.8, -0.19), Vector3(0.9, 0.72, 1.25))   # snout
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.sphere(0.02, 6), m_dark, Vector3(0.05 * sx, 0.84, -0.385))
			# a long tail that tapers down to the ground behind
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.0, 0.24); torso.add_child(tail)
			var segs := [[Vector3(0, -0.04, 0.08), 0.11, 0.3], [Vector3(0, -0.16, 0.3), 0.085, 0.3], [Vector3(0, -0.3, 0.52), 0.06, 0.28], [Vector3(0, -0.38, 0.72), 0.035, 0.22]]
			for sg in segs:
				ModelsBase.part(tail, ModelsBase.capsule(float(sg[1]), float(sg[2]) + float(sg[1]) * 2.0), m_skin, sg[0], Vector3.ONE, Vector3(1.05, 0, 0))
		"owlet":
			ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.05, 0.13, 4), ModelsBase.toon(Color("f2a24a")), Vector3(0, 0.8, -0.26), Vector3(1.0, 1.0, 0.8), Vector3(-PI / 2 + 0.35, 0, 0))   # beak
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.sphere(0.11, 14), m_hair, Vector3(0.27 * sx, 0.3, 0.05), Vector3(0.3, 1.0, 0.15), Vector3(0.1, 0, -0.25 * sx))   # wing feathers at the sides
			var tail := Node3D.new(); tail.name = "Tail"; tail.position = Vector3(0, 0.0, 0.26); torso.add_child(tail)
			for i in 5:
				var a := (i - 2) * 0.32
				ModelsBase.part(tail, ModelsBase.sphere(0.12, 16), m_hair if i % 2 == 0 else ModelsBase.toon(hair_c.lightened(0.25)), Vector3(sin(a) * 0.12, -0.1, 0.14), Vector3(0.4, 1.95, 0.11), Vector3(1.0, 0, a))
