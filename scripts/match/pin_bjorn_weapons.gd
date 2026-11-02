class_name PinBjornWeapons
extends RefCounted
## The signature weapon models of Pin (the longbow) and Bjorn (his war hammer and aegis shield), built
## into the hunter's "Gun" node (Models.hunter calls build). Our own shapes: Pin's bow is a layered recurve
## with pale horn tips, a leather grip and a green rune line that glows along both limbs, an arrow nocked
## on the string; Bjorn's hammer is a squared head with gold face plates, a back fluke and an ember stripe
## on a banded haft, under a "Hammer" pivot the kit spins while he charges a swing.

static func build(gun: Node3D, weapon: String, m_dark: Material, m_acc: Material) -> void:
	match weapon:
		"longbow": _longbow(gun, m_dark, m_acc)
		"tower_shield": _hammer_and_shield(gun, m_dark, m_acc)

static func _longbow(gun: Node3D, m_dark: Material, m_acc: Material) -> void:
	var wood := Models.toon(Color("6e4a30"))
	var horn := Models.toon(Color("e8dcc0"))
	var rune := Models.glow_mat(Color("8dffa8"))
	var lpts := [Vector3(0, -0.5, 0.06), Vector3(0, -0.4, -0.04), Vector3(0, -0.24, -0.08), Vector3(0, -0.08, -0.06), Vector3(0, 0.0, -0.06),
		Vector3(0, 0.08, -0.06), Vector3(0, 0.24, -0.08), Vector3(0, 0.4, -0.04), Vector3(0, 0.5, 0.06)]
	var wid := [Vector2(0.01, 0.016), Vector2(0.016, 0.024), Vector2(0.02, 0.03), Vector2(0.026, 0.034), Vector2(0.03, 0.036),
		Vector2(0.026, 0.034), Vector2(0.02, 0.03), Vector2(0.016, 0.024), Vector2(0.01, 0.016)]
	Models.part(gun, HeroKit.loft("pin_bow", lpts, wid, 8, Vector3.FORWARD, 1.0), wood, Vector3(0, 0.0, -0.12))
	# the rune line along the belly of both limbs
	var rpts := [Vector3(0, -0.4, -0.065), Vector3(0, -0.24, -0.1), Vector3(0, -0.1, -0.085)]
	Models.part(gun, HeroKit.loft("pin_rune_lo", rpts, [Vector2(0.005, 0.005), Vector2(0.006, 0.006), Vector2(0.005, 0.005)], 6, Vector3.FORWARD, 1.0), rune, Vector3(0, 0, -0.12))
	var rpts2 := [Vector3(0, 0.1, -0.085), Vector3(0, 0.24, -0.1), Vector3(0, 0.4, -0.065)]
	Models.part(gun, HeroKit.loft("pin_rune_hi", rpts2, [Vector2(0.005, 0.005), Vector2(0.006, 0.006), Vector2(0.005, 0.005)], 6, Vector3.FORWARD, 1.0), rune, Vector3(0, 0, -0.12))
	# horn tips curling forward, the string, the grip wrap
	for sy in [-1.0, 1.0]:
		Models.part(gun, Models.box(0.022, 0.09, 0.035), horn, Vector3(0, sy * 0.53, -0.08), Vector3.ONE, Vector3(sy * 0.5, 0, 0))
		Models.part(gun, Models.sphere(0.02, 8), m_acc, Vector3(0, sy * 0.5, -0.06))
	Models.part(gun, Models.box(0.005, 1.0, 0.005), Models.toon(Color("f6f1e4"), false), Vector3(0, 0.0, -0.06))
	Models.part(gun, Models.cyl(0.036, 0.036, 0.14, 10), m_dark, Vector3(0, 0, -0.18))
	for k in 3:
		Models.part(gun, Models.cyl(0.039, 0.039, 0.012, 10), m_acc, Vector3(0, -0.05 + k * 0.05, -0.18))
	# the nocked arrow: a pale shaft, green fletching, a glowing leaf head
	Models.part(gun, Models.box(0.01, 0.01, 0.62), Models.toon(Color("d8c9a8"), false), Vector3(0.022, 0.0, -0.34))
	for sx in [-1.0, 1.0]:
		Models.part(gun, Models.box(0.004, 0.035, 0.09), Models.toon(Color("8fd88a"), false), Vector3(0.022 + sx * 0.012, 0.0, -0.08), Vector3.ONE, Vector3(0, sx * 0.4, 0))
	Models.part(gun, Models.prism_tip(), Models.glow_mat(Color("bfffd0")), Vector3(0.022, 0.0, -0.67), Vector3(0.035, 0.07, 0.012), Vector3(-PI * 0.5, 0, 0))

## The hammer under its "Hammer" pivot (at the grip), then the aegis shield on the off side.
static func _hammer_and_shield(gun: Node3D, m_dark: Material, m_acc: Material) -> void:
	var pv := Node3D.new()
	pv.name = "Hammer"
	gun.add_child(pv)
	hammer(pv, 1.0, m_dark)
	var steel := Models.shiny(Color("b8c0d0"), 0.55)
	var gold := Models.shiny(Color("e2b04a"), 0.7)
	var sh := Node3D.new(); sh.name = "Shield"; sh.position = Vector3(-0.28, -0.05, -0.3); gun.add_child(sh)
	Models.part(sh, Models.box(0.44, 0.64, 0.05), m_acc, Vector3.ZERO)
	Models.part(sh, Models.box(0.05, 0.68, 0.065), gold, Vector3(0.21, 0, 0))
	Models.part(sh, Models.box(0.05, 0.68, 0.065), gold, Vector3(-0.21, 0, 0))
	Models.part(sh, Models.box(0.46, 0.05, 0.065), gold, Vector3(0, 0.33, 0))
	# the hammer sigil on its face
	Models.part(sh, Models.box(0.18, 0.06, 0.02), Models.glow_mat(Color("ffd27a")), Vector3(0, 0.12, -0.035))
	Models.part(sh, Models.box(0.04, 0.28, 0.02), Models.glow_mat(Color("ffd27a")), Vector3(0, -0.04, -0.035))
	Models.part(sh, Models.sphere(0.05, 10), steel, Vector3(0, -0.2, -0.04))
	Models.merge_static(sh)

## The war hammer along -Z from the origin (the grip): a banded haft, a squared head with gold face
## plates, a back fluke and an ember stripe. Also the thrown hammer (scale k).
static func hammer(parent: Node3D, k := 1.0, m_dark: Material = null) -> void:
	var haft_m := m_dark if m_dark else Models.toon(Color("4a3428"))
	var steel := Models.shiny(Color("a9b3c6"), 0.5)
	var gold := Models.shiny(Color("e2b04a"), 0.7)
	var ember := Models.glow_mat(Color("ff9a3a"))
	Models.part(parent, Models.cyl(0.026 * k, 0.03 * k, 0.72 * k, 10), haft_m, Vector3(0, 0, -0.26 * k), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for z in [0.0, -0.22, -0.44]:
		Models.part(parent, Models.cyl(0.034 * k, 0.034 * k, 0.03 * k, 10), gold, Vector3(0, 0, (z - 0.02) * k), Vector3.ONE, Vector3(PI / 2, 0, 0))
	Models.part(parent, Models.sphere(0.04 * k, 8), gold, Vector3(0, 0, 0.1 * k))
	var hz := -0.62 * k
	Models.part(parent, Models.box(0.17 * k, 0.36 * k, 0.19 * k), steel, Vector3(0, 0.0, hz))
	for sy in [-1.0, 1.0]:
		Models.part(parent, Models.box(0.19 * k, 0.05 * k, 0.21 * k), gold, Vector3(0, sy * 0.19 * k, hz))
	Models.part(parent, Models.box(0.18 * k, 0.04 * k, 0.012 * k), ember, Vector3(0, 0, hz - 0.1 * k))
	Models.part(parent, Models.box(0.18 * k, 0.04 * k, 0.012 * k), ember, Vector3(0, 0, hz + 0.1 * k))
	Models.part(parent, Models.prism_tip(), steel, Vector3(0, 0, hz - 0.17 * k), Vector3(0.12, 0.14, 0.1) * k, Vector3(-PI * 0.5, 0, 0))
