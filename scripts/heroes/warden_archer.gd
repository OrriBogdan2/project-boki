class_name WardenArcher
extends RefCounted
## Pin, the original Dark Archer (concept sheet docs/art/concepts/archer.png on ext/concepts): long and
## narrow, thin verticals and sharp points. A peaked night-dark hood lined in red over a red face wrap,
## so only her eyes show; an oiled-leather tunic with a strap across it, a red sash, and a skirt cut
## into knife points; a cloak off the left shoulder, ragged at the hem and red inside; tall dark boots
## with steel knee plates; red wraps at the wrists. Red sits only on the hood rim, the wrap, the sash
## and the fletching. Her black recurve is her weapon (PinBjornWeapons). No body or head markings.
## HeroGear.dress hands her over; c is HeroGear's context.

const CLOAK := Color("3e3846")        # night cloak (a shade up from the sheet: the hero shader darkens it)
const RED := Color("b0233a")          # heart red
const LEATHER := Color("6e5452")      # oiled leather
const STEEL := Color("a4a2a6")        # dark steel (lifted: the hero shader cools and darkens metal)
const LEGGINGS := Color("221e26")
const BOOTS := Color("2a262e")
const HOOD_OFF := 0.045       # how far the hood stands off the head (m)
const HOOD_SIDE := 0.95       # the face opening, as angles from straight ahead (rad): at the cheeks,
const HOOD_TOP := 0.66        # over the brow,
const HOOD_BOT := 1.6         # and under the chin

static func dress(c: Dictionary) -> void:
	WardenKit.recolour(c, "body", LEATHER)
	WardenKit.recolour(c, "pants", LEGGINGS)
	WardenKit.recolour(c, "leather", BOOTS)
	WardenKit.recolour(c, "gold", STEEL)
	var m := {
		"cloak": WardenKit.cloth(c, CLOAK),
		"red": WardenKit.cloth(c, RED),
		"leather": WardenKit.cloth(c, LEATHER, 2),
		"steel": WardenKit.metal(c, STEEL, 0.6),
		"dark": WardenKit.cloth(c, BOOTS, 2),
		"fletch": WardenKit.cloth(c, RED),
		"wood": Models.toon(Color("6e5a48")),
	}
	_tunic(c, m)
	_cloak(c, m)
	_arms(c, m)
	_legs(c, m)
	_quiver(c, m)
	if not bool(c["bare"]):
		_hood(c, m)

## The tunic: a strap from the right shoulder to the left hip with a steel buckle, the red sash with
## its knot on the left hip, and the skirt below it cut into knife points.
static func _tunic(c: Dictionary, m: Dictionary) -> void:
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var strap := [
		Vector3(0.19, 0.6, -0.1),
		Vector3(0.05, 0.42, -0.245),
		Vector3(-0.12, 0.24, -0.235),
		Vector3(-0.21, 0.12, -0.14)
	]
	Models.part(
		t,
		HeroKit.loft(
			"wa_strap",
			strap,
			[Vector2(0.024, 0.008), Vector2(0.026, 0.009), Vector2(0.026, 0.009), Vector2(0.024, 0.008)],
		6, Vector3.FORWARD, 0.9), m["dark"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	Models.part(
		t,
		Models.box(0.05, 0.04, 0.02),
		m["steel"],
		Vector3(0.0, 0.36, -0.245 * bw - 0.01),
		Vector3.ONE,
		Vector3(0, 0, 0.75)
	)
	var rx := 0.222 * maxf(cw, bw) + 0.02
	var rz := 0.214 * bw + 0.018
	Models.part(t, HeroKit.band("wa_sash|%.3f|%.3f" % [rx, rz], rx, rz, 0.075, 0.018), m["red"], Vector3(0, 0.1, 0))
	Models.part(t, Models.box(0.06, 0.06, 0.03), m["steel"], Vector3(0, 0.1, -rz - 0.012))
	for k in 2:
		var tail := [
			Vector3(-rx * 0.8, 0.09, -rz * 0.5),
			Vector3(-rx * 0.95 - 0.02 * k, -0.02, -rz * 0.45),
			Vector3(-rx - 0.03 * k, -0.14 - 0.05 * k, -rz * 0.35)
		]
		Models.part(t, HeroKit.lock_mesh("wa_sashtail%d" % k, tail, 0.05, 0.2, Vector3.LEFT, 0.85, 0.3), m["red"])
	var sk: Node3D = c["skirt"]
	var r0 := 0.22 * maxf(bw, cw)
	for k in 7:
		var a := (k + 0.5) / 7.0 * TAU
		var at := Vector3(cos(a) * r0, -0.01, sin(a) * r0 * 0.92)
		var ln := 0.17 + 0.03 * (k % 2)
		Models.part(
			sk,
			HeroKit.sheet("wa_tunic%d" % (k % 2), 0.19, ln, ln, 0.1, 0.05, 2, 0.06, 0.014),
			m["leather"],
			at,
			Vector3.ONE, Vector3(0.12, -a - PI * 0.5, 0))

## The cloak off the left shoulder: night cloth falling round the back and the left side to the
## calf, red inside, its hem cut into ragged knife points; a steel clasp on the shoulder.
static func _cloak(c: Dictionary, m: Dictionary) -> void:
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var cape := Models._pivot(t, "Cape", Vector3(0, 0.56, 0.24 * bw))
	var at := Vector3(0, 0.02, -0.24 * bw)
	var scl := Vector3(cw, 1.0, bw)
	var tilt := Vector3(0.05, 0, -0.06)
	Models.part(
		cape,
		HeroKit.drape("wa_cloak", 0.31, 0.44, 0.7, 0.2, 0.63, 6.0, 0.1, 0.05, 0.12, 0.018),
		m["cloak"],
		at,
		scl,
		tilt
	)
	Models.part(
		cape,
		HeroKit.drape("wa_lining", 0.295, 0.42, 0.66, 0.21, 0.62, 6.0, 0.1, 0.05, 0.12, 0.012),
		m["red"],
		at,
		scl,
		tilt
	)
	# knife-point tips along the hem
	for k in 9:
		var u := lerpf(0.22, 0.61, k / 8.0)
		var th := u * TAU
		var ln := 0.7 * (1.0 + 0.12 * clampf(sin(th), 0.0, 1.0))
		var r := 0.44 * (1.0 + 0.1 * sin(6.0 * th + 0.6 * sin(th * 3.0)))
		var root := Vector3(cos(th) * r * cw, 0.02 - ln + 0.04, sin(th) * r * 0.92 * bw - 0.24 * bw)
		var drop := 0.08 + 0.06 * absf(sin(k * 1.9))
		var pts := [root + Vector3(0, 0.06, 0), root, root + Vector3(cos(th) * 0.02, -drop, sin(th) * 0.02)]
		Models.part(
			cape,
			HeroKit.lock_mesh("wa_tip%d" % k, pts, 0.07, 0.18, Vector3(cos(th), 0, sin(th)), 0.9, 0.0),
			m["cloak"],
			Vector3.ZERO,
			Vector3.ONE, tilt)
	Models.part(
		c["pl"],
		Models.cyl(0.045, 0.05, 0.03, 14),
		m["steel"],
		Vector3(0.02, 0.07, -0.08),
		Vector3.ONE,
		Vector3(-0.9, 0, 0.3)
	)
	Models.part(
		c["pl"],
		HeroKit.dome_plate("wa_pad", 0.11, 0.5, 0.75, 0.2, 0.016),
		m["cloak"],
		Vector3(-0.02, 0.04, 0),
		Vector3(1.0, 1.0, 1.1),
		Vector3(0, 0, 0.5)
	)

## Red wraps at both wrists over leather bracers.
static func _arms(c: Dictionary, m: Dictionary) -> void:
	for sd in ["L", "R"]:
		var el: Node3D = (c["arms"][sd] as Array)[1]
		Models.part(el, HeroKit.cuff(0.056, 0.066, 0.1), m["leather"], Vector3(0, -0.15, 0))
		for k in 2:
			Models.part(
				el,
				HeroKit.band("wa_wrap", 0.064, 0.064, 0.016, 0.006),
				m["red"],
				Vector3(0, -0.13 - k * 0.04, 0),
				Vector3.ONE,
				Vector3(0.25 * (1 - 2 * k), 0, 0))

## Tall boots to the knee, a pointed steel plate over each knee.
static func _legs(c: Dictionary, m: Dictionary) -> void:
	for sd in ["L", "R"]:
		var kn: Node3D = c["knees"][sd]
		Models.part(kn, HeroKit.cuff(0.07, 0.08, 0.12), m["dark"], Vector3(0, -0.04, 0))
		Models.part(
			kn,
			HeroKit.dome_plate("wa_knee", 0.08, 0.5, 0.7, 0.1, 0.014),
			m["steel"],
			Vector3(0, 0.02, -0.055),
			Vector3(0.85, 1.0, 1.5),
			Vector3(-PI * 0.5 + 0.1, 0, 0))
		Models._spike(kn, m["steel"], Vector3(0, 0.07, -0.06), Vector3(0, 1.0, -0.15), 0.03, 0.06, 0.4)

## The quiver behind the right hip, its arrows fletched red.
static func _quiver(c: Dictionary, m: Dictionary) -> void:
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var qb := Vector3(0.2, 0.06, 0.2 * bw)
	var qr := Vector3(-0.35, 0, -0.3)
	var b := Basis.from_euler(qr)
	var profile := PackedVector2Array([Vector2(0, -0.2), Vector2(0.055, -0.19), Vector2(0.062, 0.0),
		Vector2(0.07, 0.19),
		Vector2(0.075, 0.2), Vector2(0.0, 0.2)])
	Models.part(t, Models.lathe(Models.smooth_curve(profile, 2), 16, "wa_quiver"), m["dark"], qb, Vector3.ONE, qr)
	Models.part(t, Models.cyl(0.078, 0.078, 0.024, 16), m["steel"], qb + b * Vector3(0, 0.19, 0), Vector3.ONE, qr)
	for k in 5:
		var off := Vector3((k % 3) * 0.035 - 0.035, 0.0, (k / 3) * 0.035 - 0.017)
		Models.part(
			t,
			Models.cyl(0.006, 0.006, 0.26, 4),
			m["wood"],
			qb + b * (off + Vector3(0, 0.25, 0)),
			Vector3.ONE,
			qr
		)
		var top := qb + b * (off + Vector3(0, 0.36, 0))
		Models.part(
			t,
			HeroKit.lock_mesh(
				"wa_fletch",
				[Vector3(0, -0.06, 0), Vector3(0, 0.0, 0), Vector3(0, 0.04, 0)],
				0.045,
				0.15,
				Vector3.BACK,
				1.0,
				0.5
			),
			m["fletch"], top, Vector3.ONE, qr + Vector3(0, k * 0.8, 0))

## The peaked hood, a red rim round the face, and the red wrap over nose and mouth.
static func _hood(c: Dictionary, m: Dictionary) -> void:
	var g: Node3D = c["gear"]
	var hk: String = c["hk"]
	var hc := HeroGear.HC
	Models.part(
		g,
		HeroGear.hood_mesh("wa_hood", hk, HOOD_OFF, HOOD_SIDE, HOOD_TOP, HOOD_BOT, 0.07, 0.1),
		m["cloak"],
		hc
	)
	# the peak: a sharp point rising up and back off the crown
	var peak := [
		hc + Vector3(0, 0.17, 0.06),
		hc + Vector3(0, 0.26, 0.13),
		hc + Vector3(0, 0.33, 0.24),
		hc + Vector3(0, 0.35, 0.36)
	]
	Models.part(g, HeroKit.lock_mesh("wa_peak", peak, 0.15, 0.45, Vector3.RIGHT, 0.85, 0.0), m["cloak"])
	# the red lining showing as a band all round the face opening, on the hood's own edge
	var s: Dictionary = HeroKit.HEADS.get(hk, HeroKit.HEADS["human_m"])
	var rim := []
	for k in 17:
		var th := lerpf(-0.45, PI + 0.45, k / 16.0)       # round the opening: the side, over the brow, the other side
		var st := sin(th)
		var op := lerpf(HOOD_SIDE, HOOD_TOP, st) if st >= 0.0 else lerpf(HOOD_SIDE, HOOD_BOT, -st)
		var d := Vector3(sin(op) * cos(th), sin(op) * st, -cos(op))
		rim.append(HeroKit.head_pt(d, s) + d * (HOOD_OFF - 0.008) + hc)
	Models.part(
		g,
		HeroKit.loft(
			"wa_rim|" + hk,
			rim,
			[Vector2(0.03, 0.014), Vector2(0.034, 0.016), Vector2(0.03, 0.014)],
			8,
			Vector3.FORWARD,
			1.0
		),
		m["red"]
	)
	Models.part(g, HeroGear.mask_mesh("wa_wrap", hk), m["red"], hc)
	for k in 2:
		var fold := []
		for j in 7:
			var th := lerpf(-1.0, 1.0, j / 6.0)
			var ph := -0.42 - k * 0.2 - 0.04 * cos(th * 2.0)
			var d := Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph))
			fold.append(HeroKit.head_pt(d, s) + d * 0.017 + hc)
		Models.part(
			g,
			HeroKit.loft(
				"wa_fold%d|%s" % [k, hk],
				fold,
				[Vector2(0.004, 0.002), Vector2(0.005, 0.0025), Vector2(0.004, 0.002)],
				5,
			Vector3.UP, 1.0), Models.toon(RED.darkened(0.4), false))
