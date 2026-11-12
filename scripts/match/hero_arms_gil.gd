class_name HeroArmsGil
extends RefCounted
## Gil's signature weapon (Swordfish: a slim silver-blue fish held by the tail like a rapier, its long needle
## bill the blade), built on the gun node (HeroArms asks first). The bill runs along -Z, the hand holds the
## tail near the origin.

const X_AXIS := Vector3(PI / 2, 0, 0)


static func build(gun: Node3D, weapon: String, m_dark: Material, m_acc: Material) -> bool:
	if weapon != "swordfish":
		return false
	var scales := Models.shiny(Color("7fa8d8"), 0.7)
	var belly := Models.shiny(Color("dfe9f4"), 0.5)
	var bill := Models.toon(Color("e9eef4"), true, 0.15)
	var fin := Models.toon(Color("3a6fb4"), true, 0.0)
	# the tail fork in the fist, the body swelling forward, then the long needle bill
	var body_pts := [Vector3(0, 0, 0.06), Vector3(0, 0.01, -0.1), Vector3(0, 0.02, -0.26), Vector3(0, 0.015, -0.4)]
	var body_r := [Vector2(0.022, 0.03), Vector2(0.04, 0.06), Vector2(0.05, 0.075), Vector2(0.03, 0.045)]
	Models.part(gun, HeroKit.loft("gil_fish", body_pts, body_r, 10, Vector3.UP, 1.0), scales)
	var belly_pts := [Vector3(0, -0.02, -0.08), Vector3(0, -0.03, -0.24), Vector3(0, -0.02, -0.38)]
	var belly_r := [Vector2(0.03, 0.03), Vector2(0.038, 0.04), Vector2(0.022, 0.024)]
	Models.part(gun, HeroKit.loft("gil_belly", belly_pts, belly_r, 8, Vector3.UP, 1.0), belly)
	var bill_pts := [Vector3(0, 0.015, -0.38), Vector3(0, 0.015, -0.7), Vector3(0, 0.015, -1.02)]
	var bill_r := [Vector2(0.016, 0.016), Vector2(0.01, 0.01), Vector2(0.002, 0.002)]
	Models.part(gun, HeroKit.loft("gil_bill", bill_pts, bill_r, 8, Vector3.UP, 1.0), bill)
	# the tail fork behind the fist, the dorsal sail on top, a small eye
	for s in [-1.0, 1.0]:
		var tilt := Vector3(0.5 * s, 0, 0)
		Models.part(gun, Models.box(0.012, 0.09, 0.05), fin, Vector3(0, 0.05 * s, 0.11), Vector3.ONE, tilt)
	Models.part(gun, Models.box(0.01, 0.08, 0.2), fin, Vector3(0, 0.09, -0.22))
	Models.part(gun, Models.sphere(0.012, 8), m_dark, Vector3(0.03, 0.03, -0.35))
	Models.part(gun, Models.sphere(0.012, 8), m_dark, Vector3(-0.03, 0.03, -0.35))
	Models.part(gun, Models.cyl(0.024, 0.024, 0.03, 10), m_acc, Vector3(0, 0, 0.02), Vector3.ONE, X_AXIS)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.015, -1.0)
	gun.add_child(muzzle)
	return true
