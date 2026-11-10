class_name HeroArmsVV
extends RefCounted
## The signature weapons of Sparkle (Coilcaster: no gun, a copper wrist coil and a pointed, lit finger)
## and Vex (Quill Rifle: a long-shrouded auto rifle with a drum), built on the gun node (HeroArms
## asks first). The barrel runs along -Z, the hand holds near the origin.

const X_AXIS := Vector3(PI / 2, 0, 0)
const Z_AXIS := Vector3(0, 0, PI / 2)

static func build(gun: Node3D, weapon: String, m_gun: Material, m_dark: Material, m_acc: Material) -> bool:
	match weapon:
		"coilcaster":
			_coilcaster(gun, m_dark)
			return true
		"quill_rifle":
			_quill_rifle(gun, m_gun, m_dark, m_acc)
			return true
	return false

## A finger gun: nothing held. A copper coil wound round the wrist with three bright windings, the index
## finger pointed straight out of the fist and a pink spark at its tip (the Muzzle sits there).
static func _coilcaster(gun: Node3D, m_dark: Material) -> void:
	var copper := Models.shiny(Color("c8793c"), 0.8)
	var tip := Models.toon(Color("ff5ab4"), false, 1.8)
	for k in 4:
		var winding := Models.cyl(0.058, 0.058, 0.018, 12)
		Models.part(gun, winding, copper, Vector3(0, 0.0, 0.07 + k * 0.03), Vector3.ONE, X_AXIS)
	Models.part(gun, Models.cyl(0.05, 0.05, 0.1, 10), m_dark, Vector3(0, 0, 0.11), Vector3.ONE, X_AXIS)
	Models.part(gun, Models.box(0.012, 0.012, 0.1), Models.toon(Color("ff8fd0"), false, 1.2), Vector3(0.05, 0.0, 0.11))
	Models.part(gun, Models.box(0.026, 0.026, 0.11), m_dark, Vector3(0, 0.01, -0.07))
	Models.part(gun, Models.sphere(0.03, 8), tip, Vector3(0, 0.01, -0.13))
	Models.part(gun, Models.crystal(0.014, 0.08, 4), tip, Vector3(0, 0.01, -0.17), Vector3.ONE, -X_AXIS)

## Vex's rifle: a squat receiver, a vented barrel shroud running long, a bronze drum under the grip,
## a top rail with a short scope, an ember strip down the side, a slotted brake.
static func _quill_rifle(gun: Node3D, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	var bronze := Models.shiny(Color("b9732f"), 0.6)
	var ember := Models.toon(Color("ffb36a"), false, 1.2)
	Models.part(gun, Models.box(0.1, 0.13, 0.36), m_gun, Vector3(0, 0, -0.08))
	var shroud_path := [Vector3(0, 0.01, -0.24), Vector3(0, 0.01, -0.5), Vector3(0, 0.0, -0.72)]
	var shroud_r := [Vector2(0.05, 0.055), Vector2(0.046, 0.05), Vector2(0.04, 0.044)]
	Models.part(gun, HeroKit.loft("vn_shroud", shroud_path, shroud_r, 10, Vector3.UP, 0.9), m_dark)
	for k in 4:
		Models.part(gun, Models.box(0.104, 0.012, 0.03), ember, Vector3(0, 0.03, -0.32 - k * 0.1))
	Models.part(gun, Models.cyl(0.022, 0.022, 0.18, 8), m_dark, Vector3(0, 0.0, -0.8), Vector3.ONE, X_AXIS)
	Models.part(gun, Models.box(0.075, 0.04, 0.07), bronze, Vector3(0, 0.0, -0.9))
	Models.part(gun, Models.box(0.09, 0.012, 0.012), ember, Vector3(0, 0.0, -0.93))
	Models.part(gun, Models.cyl(0.095, 0.095, 0.09, 16), bronze, Vector3(0, -0.12, -0.12), Vector3.ONE, Z_AXIS)
	Models.part(gun, Models.cyl(0.05, 0.05, 0.1, 10), ember, Vector3(0, -0.12, -0.12), Vector3.ONE, Z_AXIS)
	Models.part(gun, Models.box(0.04, 0.02, 0.3), m_acc, Vector3(0, 0.08, -0.12))
	Models.part(gun, Models.cyl(0.026, 0.03, 0.14, 10), m_dark, Vector3(0, 0.115, -0.1), Vector3.ONE, X_AXIS)
	Models.part(gun, Models.sphere(0.022, 8), ember, Vector3(0, 0.115, -0.175))
	Models.part(gun, Models.box(0.016, 0.03, 0.32), ember, Vector3(0.056, 0.0, -0.12))
	var grip_path := [Vector3(0, 0, 0), Vector3(0, -0.07, 0.025), Vector3(0, -0.14, 0.05)]
	var grip_r := [Vector2(0.026, 0.04), Vector2(0.028, 0.044), Vector2(0.03, 0.046)]
	var grip := HeroKit.loft("vn_grip", grip_path, grip_r, 10, Vector3.FORWARD, 0.85)
	Models.part(gun, grip, m_dark, Vector3(0, -0.04, -0.02))
	var stock_path := [Vector3(0, 0, 0.1), Vector3(0, -0.02, 0.2), Vector3(0, -0.05, 0.3)]
	var stock_r := [Vector2(0.035, 0.035), Vector2(0.035, 0.045), Vector2(0.04, 0.06)]
	Models.part(gun, HeroKit.loft("vn_stock", stock_path, stock_r, 10, Vector3.UP, 0.85), m_dark)
