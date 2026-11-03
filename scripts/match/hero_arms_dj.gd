class_name HeroArmsDJ
extends RefCounted
## Sable's signature weapon, Arc Bolts, built on the gun node (HeroArms.build asks first). Two ring
## blades, one per hand: a dark steel hoop with four swept spikes, a gold glowing inner edge (where the
## bolt forms) and a wrapped grip bar across the back of the hoop. The left one sits at x < -0.04 so
## HunterAnim's twin hold hands it to the left hand.

static func build(gun: Node3D, weapon: String, m_dark: Material, m_acc: Material) -> bool:
	if weapon != "arc_bolts":
		return false
	var steel := Models.shiny(Color("4c4660"), 0.7)
	var gold := Models.toon(Color("ffc04a"), false, 1.6)
	var violet := Models.toon(Color("c9a0ff"), false, 1.1)
	for k in 2:
		var x := 0.06 if k == 0 else -0.12
		var c := Vector3(x, 0.0, -0.14)
		var hoop := TorusMesh.new()
		hoop.inner_radius = 0.085
		hoop.outer_radius = 0.115
		hoop.rings = 24
		hoop.ring_segments = 8
		Models.part(gun, hoop, steel, c, Vector3.ONE, Vector3(0, 0, PI / 2))
		var edge := TorusMesh.new()
		edge.inner_radius = 0.07
		edge.outer_radius = 0.085
		edge.rings = 24
		edge.ring_segments = 6
		Models.part(gun, edge, gold, c, Vector3.ONE, Vector3(0, 0, PI / 2))
		for s in 4:
			var a := TAU * s / 4.0 + PI / 4.0
			var dir := Vector3(0, sin(a), -cos(a))
			# swept spikes: each leans along the spin so the hoop reads as a thrown blade, not a bangle
			Models.part(gun, Models.box(0.02, 0.03, 0.11), steel, c + dir * 0.15, Vector3.ONE, Vector3(a + 0.5, 0, 0))
			Models.part(gun, Models.box(0.012, 0.012, 0.06), violet, c + dir * 0.19, Vector3.ONE,
					Vector3(a + 0.5, 0, 0))
		Models.part(gun, Models.box(0.035, 0.035, 0.12), m_dark, Vector3(x, 0.0, -0.02))
		Models.part(gun, Models.box(0.04, 0.04, 0.025), m_acc, Vector3(x, 0.0, 0.03))
		Models.part(gun, Models.sphere(0.03, 8), gold, c)
	return true
