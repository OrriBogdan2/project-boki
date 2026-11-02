class_name HeroArms
extends RefCounted
## The fixed weapons of Dolm (Rubble Fists) and Ostra (Tether Lantern), built on the gun node
## (Models.gun_parts asks first). The barrel runs along -Z, the hand holds near the origin.

static func build(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> bool:
	if HeroArmsVV.build(gun, weapon, m_gun, m_dark, m_acc): return true      # Vireo's finger coil, Venator's rifle
	match weapon:
		"rubble_fists":
			# one great stone gauntlet: a slab fist ringed with strapped plates and a glowing seam
			var stone := Models.toon(Color("b58650"), true, 0.5)
			var pale := Models.toon(Color("e0bd86"), true, 0.5)
			var seam := Models.toon(Color("ffb36a"), false, 1.2)
			Models.part(gun, Models.box(0.2, 0.2, 0.3), stone, Vector3(0, 0, -0.18))
			Models.part(gun, Models.box(0.24, 0.12, 0.2), pale, Vector3(0, 0.07, -0.3), Vector3.ONE, Vector3(0.1, 0, 0))
			for k in 4:
				Models.part(gun, Models.box(0.05, 0.05, 0.05), m_dark, Vector3(-0.075 + 0.05 * k, 0.12, -0.42), Vector3.ONE, Vector3(0, 0, 0.785))
			Models.part(gun, Models.box(0.2, 0.012, 0.012), seam, Vector3(0, 0.0, -0.33))
			Models.part(gun, Models.cyl(0.085, 0.1, 0.16, 10), m_dark, Vector3(0, 0, 0.0), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.cyl(0.11, 0.11, 0.03, 10), m_acc, Vector3(0, 0, -0.05), Vector3.ONE, Vector3(PI / 2, 0, 0))
			return true
		"tether_lantern":
			# a long pale staff with a hook; the lantern hangs below it, a teal flame in a caged glass
			var wood := Models.toon(Color("e8e0cc"), true, 0.4)
			var brass := Models.shiny(Color("c9a35a"), 0.6)
			var flame := Models.toon(Color("9bf2e4"), false, 1.8)
			Models.part(gun, Models.cyl(0.022, 0.026, 1.1, 8), wood, Vector3(0, 0, -0.3), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.box(0.03, 0.03, 0.16), brass, Vector3(0, 0.07, -0.88))
			Models.part(gun, Models.box(0.03, 0.18, 0.03), brass, Vector3(0, -0.02, -0.96))
			Models.part(gun, Models.cyl(0.075, 0.075, 0.03, 10), brass, Vector3(0, -0.13, -0.96))
			Models.part(gun, Models.sphere(0.075, 12), flame, Vector3(0, -0.2, -0.96))
			Models.part(gun, Models.cyl(0.095, 0.075, 0.03, 10), brass, Vector3(0, -0.29, -0.96))
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				Models.part(gun, Models.box(0.012, 0.17, 0.012), brass, Vector3(cos(a) * 0.082, -0.21, -0.96 + sin(a) * 0.082))
			Models.part(gun, Models.sphere(0.035, 8), m_acc, Vector3(0, 0, 0.26))
			return true
	return false
