class_name PinBjornWeapons
extends RefCounted
## The signature weapon models of Hem (the longbow) and Breaker (his ice-cased oar and prow shield), built
## into the hunter's "Gun" node (Models.hunter calls build). Our own shapes: Hem's bow is a layered recurve
## in black lacquer with bone nocks, a dark steel inlay down both limbs and a leather grip, a red-fletched
## arrow nocked on the string (concept sheet docs/art/concepts/archer.png); Breaker's maul is a ship's oar
## whose blade is frozen into a block of ice bound in iron,
## under a "Hammer" pivot the kit spins while he charges a swing, and his shield is the frozen prow of his
## old ship (concept sheet docs/art/concepts/bulwark.png).

const PROW_TOP := 0.4          # gun-space m: the prow's top edge above the shield's origin
const PROW_FOOT := -0.56       # and its pointed foot below
const PROW_DEPTH := 0.13       # how far the keel stands out in front of the edges
const SHIELD_AT := Vector3(-0.1, 0.24, -0.06)     # the prow's grip in the left hand's space (m)
const SHIELD_TURN := Vector3(0.0, 0.25, 0.0)      # its face turned a little out from the body
const SHIELD_K := 1.35                            # the heavy weapon scale the gun gets, for a prow in the hand

static func build(gun: Node3D, weapon: String, m_dark: Material, m_acc: Material) -> void:
	match weapon:
		"longbow": _longbow(gun, m_dark, m_acc)
		"tower_shield": _hammer_and_shield(gun, m_dark, m_acc)

static func _longbow(gun: Node3D, m_dark: Material, m_acc: Material) -> void:
	var wood := Models.shiny(Color("2c2830"), 0.55)       # black lacquer
	var horn := Models.toon(Color("cfc0a2"))               # bone nocks
	var rune := Models.shiny(Color("636a76"), 0.7)         # a dark steel inlay down both limbs
	var lpts := [Vector3(0, -0.5, 0.06), Vector3(0, -0.4, -0.04), Vector3(0, -0.24, -0.08),
		Vector3(0, -0.08, -0.06), Vector3(0, 0.0, -0.06),
		Vector3(0, 0.08, -0.06), Vector3(0, 0.24, -0.08), Vector3(0, 0.4, -0.04), Vector3(0, 0.5, 0.06)]
	var wid := [Vector2(0.01, 0.016), Vector2(0.016, 0.024), Vector2(0.02, 0.03),
		Vector2(0.026, 0.034), Vector2(0.03, 0.036),
		Vector2(0.026, 0.034), Vector2(0.02, 0.03), Vector2(0.016, 0.024), Vector2(0.01, 0.016)]
	Models.part(gun, HeroKit.loft("pin_bow", lpts, wid, 8, Vector3.FORWARD, 1.0), wood, Vector3(0, 0.0, -0.12))
	# the rune line along the belly of both limbs
	var rpts := [Vector3(0, -0.4, -0.065), Vector3(0, -0.24, -0.1), Vector3(0, -0.1, -0.085)]
	Models.part(
		gun,
		HeroKit.loft(
			"pin_rune_lo",
			rpts,
			[Vector2(0.005, 0.005), Vector2(0.006, 0.006), Vector2(0.005, 0.005)],
			6,
			Vector3.FORWARD,
			1.0
		),
		rune,
		Vector3(0, 0, -0.12)
	)
	var rpts2 := [Vector3(0, 0.1, -0.085), Vector3(0, 0.24, -0.1), Vector3(0, 0.4, -0.065)]
	Models.part(
		gun,
		HeroKit.loft(
			"pin_rune_hi",
			rpts2,
			[Vector2(0.005, 0.005), Vector2(0.006, 0.006), Vector2(0.005, 0.005)],
			6,
			Vector3.FORWARD,
			1.0
		),
		rune,
		Vector3(0, 0, -0.12)
	)
	# horn tips curling forward, the string, the grip wrap
	for sy in [-1.0, 1.0]:
		Models.part(
			gun,
			Models.box(0.022, 0.09, 0.035),
			horn,
			Vector3(0, sy * 0.53, -0.08),
			Vector3.ONE,
			Vector3(sy * 0.5, 0, 0)
		)
		Models.part(gun, Models.sphere(0.02, 8), m_acc, Vector3(0, sy * 0.5, -0.06))
	Models.part(gun, Models.box(0.005, 1.0, 0.005), Models.toon(Color("f6f1e4"), false), Vector3(0, 0.0, -0.06))
	Models.part(gun, Models.cyl(0.036, 0.036, 0.14, 10), m_dark, Vector3(0, 0, -0.18))
	for k in 3:
		Models.part(gun, Models.cyl(0.039, 0.039, 0.012, 10), m_acc, Vector3(0, -0.05 + k * 0.05, -0.18))
	# the nocked arrow: a pale shaft, red fletching, a steel head; it is the bow's "Mag".
	var arrow := Node3D.new()
	arrow.name = "Mag"
	gun.add_child(arrow)
	Models.part(arrow, Models.box(0.01, 0.01, 0.62), Models.toon(Color("d8c9a8"), false), Vector3(0.022, 0.0, -0.34))
	for sx in [-1.0, 1.0]:
		Models.part(
			arrow,
			Models.box(0.004, 0.035, 0.09),
			Models.toon(Color("b0233a"), false),
			Vector3(0.022 + sx * 0.012, 0.0, -0.08),
			Vector3.ONE,
			Vector3(0, sx * 0.4, 0)
		)
	Models.part(
		arrow,
		Models.prism_tip(),
		Models.shiny(Color("a8aeb8"), 0.7),
		Vector3(0.022, 0.0, -0.67),
		Vector3(0.035, 0.07, 0.012),
		Vector3(-PI * 0.5, 0, 0)
	)
	Models.merge_static(arrow)

## The oar maul under its "Hammer" pivot (at the grip), then the prow shield on the off side.
static func _hammer_and_shield(gun: Node3D, m_dark: Material, m_acc: Material) -> void:
	var pv := Node3D.new()
	pv.name = "Hammer"
	pv.set_meta("hammer_pivot", true)       # (found by meta: a re-equip renames it while the old one is freed)
	gun.add_child(pv)
	hammer(pv, 1.0, m_dark)
	# the wrist strap at the grip stands in for a magazine (a melee weapon has none to drop)
	Models.part(
		gun,
		Models.cyl(0.036, 0.036, 0.03, 10),
		m_dark,
		Vector3(0, 0, 0.12),
		Vector3.ONE,
		Vector3(PI / 2, 0, 0),
		"Mag"
	)
	# the prow rides the free left hand (the sword hold keeps it free; the kit's moves bring it up
	# to brace), so it stays at his side through the oar's swings; a rebuild replaces the old one
	var hand := gun.get_node_or_null("../../ArmLPivot/Elbow/Hand") as Node3D
	var holder: Node3D = hand if hand else gun
	var old := holder.get_node_or_null("Shield")
	if old:
		holder.remove_child(old)
		old.queue_free()
	var sh := Node3D.new()
	sh.name = "Shield"
	sh.position = SHIELD_AT if hand else Vector3(-0.28, -0.05, -0.3)
	sh.rotation = SHIELD_TURN if hand else Vector3.ZERO
	sh.scale = Vector3.ONE * (SHIELD_K if hand else 1.0)
	holder.add_child(sh)
	_prow(sh, m_acc)
	Models.merge_static(sh)

## The prow: oak strakes curving back from a keel that faces out (-Z), widest a little above the
## middle and coming to a point at the foot; the stem post runs up the keel and curls over the top;
## two iron bands with rivets; rime along the top edge with icicles hanging off it and off the foot;
## a crack down one side glowing a faint cold green. The team colour is the stem's iron cap.
static func _prow(sh: Node3D, m_acc: Material) -> void:
	var oak := Models.toon(Color("74513a"))
	oak.set_shader_parameter("rim_amount", 0.7)
	Models.painted(oak, 2, 0.24, 0.22, 0.22)
	var stem_m := Models.toon(Color("5e3f2c"))
	Models.painted(stem_m, 2, 0.24, 0.22, 0.22)
	var iron := Models.shiny(Color("66717d"), 0.55)
	Models.painted(iron, 3, 0.14, 0.12, 0.14)
	var rime := WardenKit.rime()
	var crack := Models.toon(Color("8dffc9"), false, 0.9)
	var hull := func(u: float, v: float) -> Vector3: return _hull_pt(u, v, 0.0)
	var strakes := func(u: float, v: float) -> float:
		var y := lerpf(PROW_TOP, PROW_FOOT, v) + 0.05 * pow(1.0 - absf(2.0 * u - 1.0), 2.0)
		var seam := fposmod(y * 9.0, 1.0)
		return lerpf(0.7, 1.0, smoothstep(0.0, 0.12, seam)) * lerpf(0.82, 1.0, smoothstep(0.0, 0.2, minf(u, 1.0 - u)))
	Models.part(sh, HeroKit.shell("prow_hull", hull, 22, 36, 0.045, strakes, false, 1.0), oak)
	# the stem post up the keel, curling over the top
	var stem := [
		Vector3(0, PROW_FOOT - 0.02, -PROW_DEPTH + 0.01),
		Vector3(0, -0.2, -PROW_DEPTH - 0.012),
		Vector3(0, 0.2, -PROW_DEPTH - 0.012),
		Vector3(0, PROW_TOP + 0.08, -PROW_DEPTH),
		Vector3(0, PROW_TOP + 0.19, -PROW_DEPTH + 0.03),
		Vector3(0, PROW_TOP + 0.23, -PROW_DEPTH + 0.1),
		Vector3(0, PROW_TOP + 0.19, -PROW_DEPTH + 0.15),
		Vector3(0, PROW_TOP + 0.13, -PROW_DEPTH + 0.12),
	]
	var sw := [
		Vector2(0.03, 0.03), Vector2(0.04, 0.034), Vector2(0.04, 0.034), Vector2(0.037, 0.032),
		Vector2(0.034, 0.03), Vector2(0.03, 0.028), Vector2(0.027, 0.025), Vector2(0.022, 0.02),
	]
	Models.part(sh, HeroKit.loft("prow_stem", stem, sw, 10, Vector3.RIGHT, 0.9, 3), stem_m)
	Models.part(
		sh,
		HeroKit.cuff(0.044, 0.046, 0.05),
		m_acc,
		Vector3(0, PROW_TOP + 0.06, -PROW_DEPTH),
		Vector3.ONE,
		Vector3(0.05, 0, 0)
	)
	# iron bands across the face, riveted
	for y in [0.14, -0.2]:
		var band := []
		for k in 13:
			band.append(_hull_pt(k / 12.0, _v_at(y), 0.012))
		Models.part(
			sh,
			HeroKit.loft("prow_band%.2f" % y, band, [Vector2(0.03, 0.01), Vector2(0.03, 0.01)], 6, Vector3.UP, 1.0, 2),
			iron
		)
		for k in [1, 4, 8, 11]:
			Models.part(sh, Models.sphere(0.013, 6), iron, _hull_pt(k / 12.0, _v_at(y), 0.022))
	# rime along the top edge, icicles under it and off the foot
	var rim := []
	for k in 13:
		rim.append(_hull_pt(k / 12.0, 0.0, 0.006) + Vector3(0, 0.012, 0))
	Models.part(
		sh,
		HeroKit.loft("prow_rime", rim, [Vector2(0.03, 0.035), Vector2(0.034, 0.04)], 8, Vector3.FORWARD, 1.0, 2),
		rime
	)
	for k in 9:
		var p := _hull_pt((k + 0.5) / 9.0, 0.0, 0.03)
		Models._spike(sh, rime, p, Vector3(0, -1.0, -0.15), 0.016, 0.05 + 0.05 * absf(sin(k * 2.1)))
	for k in 3:
		Models._spike(
			sh,
			rime,
			Vector3((k - 1) * 0.03, PROW_FOOT + 0.04, -PROW_DEPTH + 0.03),
			Vector3((k - 1) * 0.3, -1.0, 0),
			0.016,
			0.1 - absf(k - 1) * 0.03
		)
	# the crack: a jagged line down the left strakes
	var zig := []
	for k in 6:
		zig.append(_hull_pt(0.3 + 0.06 * (k % 2), _v_at(0.1 - k * 0.07), 0.004))
	Models.part(
		sh,
		HeroKit.loft(
			"prow_crack",
			zig,
			[Vector2(0.008, 0.004), Vector2(0.012, 0.004), Vector2(0.005, 0.003)],
			5,
			Vector3.FORWARD,
			1.0,
			1
		),
		crack
	)

## A point on the hull: u across (0 one edge, 0.5 the keel, 1 the other), v down (0 the top edge,
## 1 the foot), `off` out from the face.
static func _hull_pt(u: float, v: float, off: float) -> Vector3:
	var y := lerpf(PROW_TOP, PROW_FOOT, v)
	var w := lerpf(0.27, 0.235, (y - 0.06) / (PROW_TOP - 0.06))      # widest just above the middle
	if y < 0.06:
		w = 0.27 * sqrt(clampf(1.0 - pow((y - 0.06) / (PROW_FOOT - 0.06), 2.0), 0.0, 1.0))
	var a := 2.0 * u - 1.0
	var keel := pow(1.0 - a * a, 0.6)
	var p := Vector3(a * w, y, 0.04 - PROW_DEPTH * keel)
	var n := Vector3(a * 0.6, 0.0, -1.0).normalized()
	return p + n * off

static func _v_at(y: float) -> float:
	return (PROW_TOP - y) / (PROW_TOP - PROW_FOOT)

## The oar maul along -Z from the origin (the grip): a long oar shaft with a knob and leather wraps,
## its blade frozen into a block of ice bound by two iron bands. The ice's middle is near -0.62 (the
## kit's FX find the head there). Also the thrown maul (scale k).
static func hammer(parent: Node3D, k := 1.0, m_dark: Material = null) -> void:
	var wood := Models.toon(Color("8a6a4a"))
	Models.painted(wood, 2, 0.24, 0.2, 0.2)
	var grip_wrap := m_dark if m_dark else Models.toon(Color("4a3428"))
	var iron := Models.shiny(Color("66717d"), 0.55)
	var ice := WardenKit.rime(Color("9fd8ff"), 0.2)
	Models.part(
		parent,
		Models.cyl(0.024 * k, 0.028 * k, 0.86 * k, 10),
		wood,
		Vector3(0, 0, -0.17 * k),
		Vector3.ONE,
		Vector3(PI / 2, 0, 0)
	)
	Models.part(parent, Models.sphere(0.038 * k, 10), wood, Vector3(0, 0, 0.26 * k))
	for z in [0.08, -0.04]:
		Models.part(
			parent,
			Models.cyl(0.032 * k, 0.032 * k, 0.07 * k, 10),
			grip_wrap,
			Vector3(0, 0, z * k),
			Vector3.ONE,
			Vector3(PI / 2, 0, 0)
		)
	Models.part(parent, Models.box(0.15 * k, 0.03 * k, 0.32 * k), wood, Vector3(0, 0, -0.66 * k))
	var hz := -0.64 * k
	Models.part(
		parent,
		Models.crystal(0.18 * k, 0.54 * k, 6),
		ice,
		Vector3(0, 0, hz),
		Vector3(1.0, 1.0, 0.85),
		Vector3(-PI / 2, 0.3, 0)
	)
	Models.part(
		parent,
		Models.crystal(0.07 * k, 0.22 * k, 5),
		ice,
		Vector3(0.1 * k, 0.05 * k, hz - 0.08 * k),
		Vector3.ONE,
		Vector3(-PI / 2 + 0.6, 0, -0.7)
	)
	Models.part(
		parent,
		Models.crystal(0.06 * k, 0.18 * k, 5),
		ice,
		Vector3(-0.09 * k, -0.04 * k, hz + 0.04 * k),
		Vector3.ONE,
		Vector3(-PI / 2 - 0.5, 0, 0.9)
	)
	for z in [hz + 0.13 * k, hz - 0.1 * k]:
		Models.part(
			parent,
			Models.cyl(0.165 * k, 0.165 * k, 0.035 * k, 8),
			iron,
			Vector3(0, 0, z),
			Vector3(1.0, 1.0, 0.8),
			Vector3(PI / 2, 0, 0)
		)
