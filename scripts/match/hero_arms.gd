class_name HeroArms
extends RefCounted
## The fixed weapons of Tarek (dolm, Rubble Fists) and Ostra (Tether Lantern), built on the gun node
## (Models.gun_parts asks first). The barrel runs along -Z, the hand holds near the origin.

static func build(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> bool:
	if HeroArmsDJ.build(gun, weapon, m_dark, m_acc): return true      # Sable's Arc Bolts
	if HeroArmsVV.build(gun, weapon, m_gun, m_dark, m_acc): return true      # Sparkle's finger coil, Vex's rifle
	match weapon:
		"rubble_fists":
			_fists(gun, m_dark, m_acc)
			return true
		"tether_lantern":
			_lantern(gun, m_acc)
			return true
	return false

## One great basalt gauntlet, much bigger than the hand: a fist of stacked plates whose cracks glow
## with magma (shaders/molten_rock), four knuckle studs, a thumb slab, a strapped wrist bracer and a
## hot core at the back of the hand. The fist leads her silhouette.
static func _fists(gun: Node3D, m_dark: Material, m_acc: Material) -> void:
	var rock := KitLooks.rock_mat(0.5, 2.0)
	var rock2 := KitLooks.rock_mat(0.35, 5.0)
	var pale := Models.toon(Color("e0bd86"), true, 0.5)
	var seam := Models.toon(Color("ffb36a"), false, 1.6)
	# the fist
	Models.part(gun, Models.box(0.27, 0.25, 0.34), rock, Vector3(0, 0, -0.2))
	# the back plate
	Models.part(gun, Models.box(0.29, 0.13, 0.22), rock2, Vector3(0, 0.1, -0.3), Vector3.ONE, Vector3(0.12, 0, 0))
	# the thumb slab
	Models.part(
		gun, Models.box(0.09, 0.12, 0.16), rock2, Vector3(-0.15, -0.03, -0.24), Vector3.ONE, Vector3(0, 0.2, 0.25)
	)
	for k in 4:
		Models.part(
			gun, Models.box(0.06, 0.06, 0.06), pale, Vector3(-0.1 + 0.066 * k, 0.07, -0.39), Vector3.ONE,
			Vector3(0, 0, 0.785)
		)
	Models.part(gun, Models.box(0.25, 0.016, 0.016), seam, Vector3(0, -0.02, -0.37))
	Models.part(gun, Models.box(0.016, 0.2, 0.016), seam, Vector3(0.12, 0.0, -0.26))
	# the hot core
	Models.part(gun, Models.sphere(0.05, 10), Models.glow_mat(Color(1.0, 0.55, 0.15, 0.9)), Vector3(0, 0.16, -0.22))
	# the bracer
	Models.part(gun, Models.cyl(0.1, 0.12, 0.2, 10), m_dark, Vector3(0, 0, 0.0), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for z in [-0.06, 0.05]:
		Models.part(gun, Models.cyl(0.13, 0.13, 0.03, 10), m_acc, Vector3(0, 0, z), Vector3.ONE, Vector3(PI / 2, 0, 0))

## A long pale crook with a curled hook; from it hangs a brass-caged lantern whose teal flame wraps a
## small void-glass core, and two violet shards hang in the air beside it. Her silhouette's light.
static func _lantern(gun: Node3D, m_acc: Material) -> void:
	var wood := Models.toon(Color("e8e0cc"), true, 0.4)
	var brass := Models.shiny(Color("c9a35a"), 0.6)
	var flame := Models.toon(Color("9bf2e4"), false, 1.8)
	Models.part(gun, Models.cyl(0.024, 0.028, 1.15, 8), wood, Vector3(0, 0, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for k in 3:
		# the hook: three short pieces turning down
		var a := 0.5 + 0.7 * k
		Models.part(
			gun, Models.box(0.03, 0.03, 0.12), wood, Vector3(0, 0.05 + sin(a) * 0.06, -0.88 - cos(a) * 0.06 - 0.04 * k),
			Vector3.ONE, Vector3(-a, 0, 0)
		)
	Models.part(gun, Models.box(0.025, 0.16, 0.025), brass, Vector3(0, -0.04, -0.98))
	Models.part(gun, Models.cyl(0.085, 0.085, 0.03, 12), brass, Vector3(0, -0.14, -0.98))
	Models.part(gun, Models.sphere(0.085, 12), flame, Vector3(0, -0.22, -0.98))
	Models.part(
		gun, Models.sphere(0.04, 10), KitLooks.glass_mat(Color("1a0636"), Color("e070ff")), Vector3(0, -0.22, -0.98)
	)
	Models.part(gun, Models.cyl(0.105, 0.085, 0.03, 12), brass, Vector3(0, -0.31, -0.98))
	Models.part(gun, Models.cyl(0.02, 0.0, 0.06, 6), brass, Vector3(0, -0.35, -0.98))
	for k in 5:
		var a2 := TAU * k / 5.0 + 0.4
		Models.part(
			gun, Models.box(0.012, 0.18, 0.012), brass, Vector3(cos(a2) * 0.092, -0.225, -0.98 + sin(a2) * 0.092)
		)
	for sx in [-1.0, 1.0]:
		Models.part(
			gun, PrismMesh.new(), KitLooks.glass_mat(Color("240838"), Color("c48cff")), Vector3(sx * 0.2, -0.12, -0.92),
			Vector3(0.05, 0.14, 0.05), Vector3(0.2, 0, sx * 0.3)
		)
	Models.part(gun, Models.sphere(0.035, 8), m_acc, Vector3(0, 0, 0.27))
