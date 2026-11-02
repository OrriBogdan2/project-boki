class_name HeroArmsVV
extends RefCounted
## The signature weapons of Vireo (Coilcaster: no gun, a copper wrist coil and a lit fingertip) and
## Venator (Quill Rifle: a long-shrouded auto rifle with a drum), built on the gun node (HeroArms asks
## first). The barrel runs along -Z, the hand holds near the origin.

static func build(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> bool:
	match weapon:
		"coilcaster":
			# a finger gun: nothing held. A copper coil wound round the wrist, three bright windings,
			# a teal spark at the pointed fingertip (the Muzzle sits there)
			var cop := Models.shiny(Color("c8793c"), 0.8)
			var tip := Models.toon(Color("9ff5ff"), false, 1.8)
			for k in 4:
				Models.part(gun, Models.cyl(0.058, 0.058, 0.018, 12), cop, Vector3(0, 0.0, 0.07 + k * 0.03), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.cyl(0.05, 0.05, 0.1, 10), m_dark, Vector3(0, 0, 0.11), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.box(0.012, 0.012, 0.1), Models.toon(Color("7ff0ff"), false, 1.2), Vector3(0.05, 0.0, 0.11))
			Models.part(gun, Models.sphere(0.028, 8), tip, Vector3(0, 0.0, -0.13))
			Models.part(gun, Models.crystal(0.012, 0.07, 4), tip, Vector3(0, 0.0, -0.17), Vector3.ONE, Vector3(-PI / 2, 0, 0))
			return true
		"quill_rifle":
			# Venator's rifle: a squat receiver, a vented barrel shroud running long, a bronze drum
			# under the grip, a top rail with a short scope, an ember strip down the side, a slotted brake
			var bronze := Models.shiny(Color("b9732f"), 0.6)
			var ember := Models.toon(Color("ffb36a"), false, 1.2)
			Models.part(gun, Models.box(0.1, 0.13, 0.36), m_gun, Vector3(0, 0, -0.08))
			Models.part(gun, HeroKit.loft("vn_shroud", [Vector3(0, 0.01, -0.24), Vector3(0, 0.01, -0.5), Vector3(0, 0.0, -0.72)], [Vector2(0.05, 0.055), Vector2(0.046, 0.05), Vector2(0.04, 0.044)], 10, Vector3.UP, 0.9), m_dark)
			for k in 4:
				Models.part(gun, Models.box(0.104, 0.012, 0.03), ember, Vector3(0, 0.03, -0.32 - k * 0.1))
			Models.part(gun, Models.cyl(0.022, 0.022, 0.18, 8), m_dark, Vector3(0, 0.0, -0.8), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.box(0.075, 0.04, 0.07), bronze, Vector3(0, 0.0, -0.9))
			Models.part(gun, Models.box(0.09, 0.012, 0.012), ember, Vector3(0, 0.0, -0.93))
			Models.part(gun, Models.cyl(0.095, 0.095, 0.09, 16), bronze, Vector3(0, -0.12, -0.12), Vector3.ONE, Vector3(0, 0, PI / 2))
			Models.part(gun, Models.cyl(0.05, 0.05, 0.1, 10), ember, Vector3(0, -0.12, -0.12), Vector3.ONE, Vector3(0, 0, PI / 2))
			Models.part(gun, Models.box(0.04, 0.02, 0.3), m_acc, Vector3(0, 0.08, -0.12))
			Models.part(gun, Models.cyl(0.026, 0.03, 0.14, 10), m_dark, Vector3(0, 0.115, -0.1), Vector3.ONE, Vector3(PI / 2, 0, 0))
			Models.part(gun, Models.sphere(0.022, 8), ember, Vector3(0, 0.115, -0.175))
			Models.part(gun, Models.box(0.016, 0.03, 0.32), ember, Vector3(0.056, 0.0, -0.12))
			Models.part(gun, HeroKit.loft("vn_grip", [Vector3(0, 0, 0), Vector3(0, -0.07, 0.025), Vector3(0, -0.14, 0.05)], [Vector2(0.026, 0.04), Vector2(0.028, 0.044), Vector2(0.03, 0.046)], 10, Vector3.FORWARD, 0.85), m_dark, Vector3(0, -0.04, -0.02))
			Models.part(gun, HeroKit.loft("vn_stock", [Vector3(0, 0, 0.1), Vector3(0, -0.02, 0.2), Vector3(0, -0.05, 0.3)], [Vector2(0.035, 0.035), Vector2(0.035, 0.045), Vector2(0.04, 0.06)], 10, Vector3.UP, 0.85), m_dark)
			return true
	return false
