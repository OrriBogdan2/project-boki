class_name HeroGearPair
extends RefCounted
## The gear of Dredge and Cinder (id ashwick) (HeroGear.dress hands these two over; same contract, see hero_gear.gd).
##
## Dredge, the harbour hauler: a round brass diving-bell helm with a single dark porthole, a heavy
## ochre slicker, a big rope drum on the left shoulder (the team colour), a cross harness, a steel
## anchor on the back and rubber gauntlets. From the match camera: a brass ball, one huge wound drum.
## Cinder, the flue sweep: a tall sooty stovepipe hat with a brass band and team-colour cloth, cyan
## goggles, a long sooty tailcoat, a leather bellows pack with a brass pipe over the shoulder and a
## lantern at the hip. From the match camera: a tall black chimney of a hat and a pleated pack.

const HC := Vector3(0, 0.86, 0)

## Each hero's body against the class: Cinder small and round (0.76 of a heavy, a little broad), Dredge
## as tall as a heavy but 1.3x as broad across the chest and shoulders (hero-ref body sections).
## Neither sets a nameplate height (no plate_offset in their archetype JSON): both sheets measure the
## shared height (the plate floats clear of Cinder's hat and touches Dredge's helm, as in the source).
const BODY := {
	"ashwick": {"size": 0.76, "bulk": 1.05}, "dredge": {"size": 1.0, "bulk": 1.3}
}
const PLAIN_BODY := {"size": 1.0, "bulk": 1.0}

## The body size and breadth multipliers for an archetype (1.0 for heroes outside this pair).
static func body(arch: String) -> Dictionary:
	return BODY.get(arch, PLAIN_BODY)

static func dress(arch: String, c: Dictionary) -> void:
	if arch == "dredge": _dredge(c)
	else: _ashwick(c)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

static func _glow(col: Color, amt := 1.6) -> ShaderMaterial:
	var g := Models.toon(col, false, amt)
	g.set_shader_parameter("rim_amount", 0.0)
	return g

# ------------------------------------------------------------------------------------------ dredge
static func _dredge(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var brass := Models.toon(Color("c89a3c"), true)
	brass.set_shader_parameter("gloss", 0.6)
	var slick := Models.toon(Color("d9a93a"))
	var rope := Models.toon(Color("e8dcb8"))
	var glass := _glow(Color("6fd8e8"), 1.2)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		# the diving-bell helm: a brass sphere with a ring of rivets, one round dark porthole in front
		_p(g, Models.sphere(0.3, 24), brass, HC + Vector3(0, 0.02, 0.0), Vector3(1.0, 0.95, 1.0))
		_p(g, HeroKit.band("dr_neck", 0.29, 0.29, 0.07, 0.03), m["steel"], HC + Vector3(0, -0.24, 0))
		for k in 10:
			var a := TAU * k / 10.0
			_p(g, Models.sphere(0.022, 8), m["steel"], HC + Vector3(cos(a) * 0.285, -0.2, sin(a) * 0.285))
		_p(
			g, HeroKit.band("dr_port_rim", 0.115, 0.115, 0.05, 0.022), m["steel"], HC + Vector3(0, 0.02, -0.27),
			Vector3.ONE, Vector3(PI / 2, 0, 0)
		)
		_p(
			g, Models.cyl(0.095, 0.095, 0.03, 18), glass, HC + Vector3(0, 0.02, -0.285), Vector3.ONE,
			Vector3(PI / 2, 0, 0)
		)
		# small side ports and a lamp on the crown
		for sx in [-1.0, 1.0]:
			_p(
				g, Models.cyl(0.04, 0.04, 0.03, 12), glass, HC + Vector3(0.275 * sx, 0.04, -0.05), Vector3.ONE,
				Vector3(0, 0, PI / 2)
			)
		_p(g, Models.cyl(0.05, 0.07, 0.07, 12), m["steel"], HC + Vector3(0, 0.3, 0))
		_p(g, Models.sphere(0.04, 10), _glow(Color("ffe08a")), HC + Vector3(0, 0.35, 0))
	# the cross harness: leather straps over the slicker, a big ring at the breastbone
	for sx in [-1.0, 1.0]:
		_p(
			t, Models.box(0.05, 0.62, 0.02), m["leather"], Vector3(0.1 * sx, 0.36, -0.28 * bw), Vector3.ONE,
			Vector3(0, 0, 0.42 * sx)
		)
	_p(
		t, HeroKit.band("dr_ring", 0.07, 0.07, 0.03, 0.014), m["steel"], Vector3(0, 0.46, -0.3 * bw), Vector3.ONE,
		Vector3(PI / 2, 0, 0)
	)
	# the slicker: a wide ochre skirt that flares at the hem, with a back flap
	var sk: Node3D = c["skirt"]
	var r0 := 0.26 * maxf(bw, cw * 0.9)
	_p(
		sk, HeroKit.drape("dr_slicker|%.3f" % r0, r0, r0 * 1.35, 0.32, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1), slick,
		Vector3(0, -0.02, 0)
	)
	_p(t, HeroKit.mantle("dr_collar|%.3f" % cw, 0.25 * cw, 0.23 * bw, 0.1, 8.0, 0.2), slick, Vector3(0, 0.575, 0.03))
	# the anchor on the back: shank, stock, ring, two curved flukes
	var ab := Vector3(0, 0.34, 0.33 * bw)
	_p(t, Models.box(0.05, 0.5, 0.04), m["steel"], ab)
	_p(t, Models.box(0.3, 0.045, 0.04), m["steel"], ab + Vector3(0, 0.2, 0))
	_p(
		t, HeroKit.band("dr_anchor_ring", 0.045, 0.045, 0.03, 0.012), m["steel"], ab + Vector3(0, 0.29, 0.0),
		Vector3.ONE, Vector3(PI / 2, 0, 0)
	)
	for sx in [-1.0, 1.0]:
		_p(
			t, Models.box(0.18, 0.04, 0.04), m["steel"], ab + Vector3(0.1 * sx, -0.22, 0), Vector3.ONE,
			Vector3(0, 0, -0.55 * sx)
		)
		_p(t, Models.sphere(0.035, 8), m["steel"], ab + Vector3(0.19 * sx, -0.16, 0))
	# the rope drum on the left shoulder: a flanged spool wound with rope, in the team colour
	var pl: Node3D = c["pl"]
	var dpos := Vector3(-0.05, 0.1, 0.0)
	_p(pl, Models.cyl(0.17, 0.17, 0.3, 20), m["acc"], dpos, Vector3.ONE, Vector3(0, 0, PI / 2))
	for k in 6:
		_p(
			pl, HeroKit.band("dr_wind", 0.178, 0.178, 0.03, 0.02), rope, dpos + Vector3(-0.12 + k * 0.048, 0, 0),
			Vector3.ONE, Vector3(0, 0, PI / 2)
		)
	for sx in [-1.0, 1.0]:
		_p(
			pl, Models.cyl(0.21, 0.21, 0.03, 20), m["steel"], dpos + Vector3(0.16 * sx, 0, 0), Vector3.ONE,
			Vector3(0, 0, PI / 2)
		)
	_p(pl, Models.sphere(0.05, 10), brass, dpos + Vector3(0.0, 0.17, 0.0))
	# a coil of loose rope hanging from the drum across the chest
	var pts := [
		Vector3(-0.2, 0.62, -0.1), Vector3(-0.12, 0.5, -0.3 * bw), Vector3(0.0, 0.34, -0.31 * bw),
		Vector3(0.1, 0.2, -0.3 * bw)
	]
	_p(
		t,
		HeroKit.loft(
			"dr_rope", pts, [Vector2(0.025, 0.025), Vector2(0.027, 0.027), Vector2(0.027, 0.027), Vector2(0.02, 0.02)],
			8, Vector3.UP, 1.0
		),
		rope
	)
	# the right shoulder: a plain steel pad
	var pr: Node3D = c["pr"]
	_p(
		pr, HeroKit.box_plate("dr_pad", 0.2, 0.22, 0.1, 0.03, 0.55, 2.6), m["steel"], Vector3(0.05, 0.05, 0),
		Vector3.ONE, Vector3(0, 0, 0.3)
	)
	_undersuit(c)
	# rubber gauntlets: big flared cuffs, a strap
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.07, 0.12, 0.17), m["leather"], Vector3(0, -0.14, 0))
		_p(e2, HeroKit.band("dr_gstrap", 0.1, 0.1, 0.025, 0.01), brass, Vector3(0, -0.17, 0))
	HeroGear._greaves(c, m["steel"], brass)

# ------------------------------------------------------------------------------------------ ashwick
static func _ashwick(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var soot := Models.toon(Color("2c2825"))
	var soot2 := Models.toon(Color("3a342f"))
	var brass := Models.toon(Color("c89a3c"), true)
	brass.set_shader_parameter("gloss", 0.6)
	var lens := _glow(Color("7fe8ff"), 1.8)
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		# the stovepipe hat: a tall crown, a narrow brim, a brass band, team-colour cloth tied round it
		_p(g, Models.cyl(0.18, 0.2, 0.46, 20), soot, HC + Vector3(0, 0.46, 0.0))
		_p(g, Models.cyl(0.19, 0.19, 0.02, 20), soot2, HC + Vector3(0, 0.69, 0.0))
		_p(g, HeroGear.brim("ash_brim", 0.17, 0.3, 0.02, 0.0, 0.0), soot, HC + Vector3(0, 0.25, 0.0))
		_p(g, HeroKit.band("ash_hatband", 0.2, 0.2, 0.06, 0.02), brass, HC + Vector3(0, 0.3, 0.0))
		_p(g, HeroKit.band("ash_hatcloth", 0.205, 0.205, 0.07, 0.016), m["acc"], HC + Vector3(0, 0.37, 0.0))
		for sx in [-1.0, 1.0]:
			_p(
				g, Models.box(0.04, 0.2, 0.012), m["acc"], HC + Vector3(0.1 * sx, 0.26, 0.2), Vector3.ONE,
				Vector3(0.2, 0, 0.3 * sx)
			)
		# goggles pushed up on the brow: two cyan lenses in brass rims on a strap
		for sx in [-1.0, 1.0]:
			_p(
				g, HeroKit.band("ash_lens_rim", 0.062, 0.062, 0.03, 0.014), brass, HC + Vector3(0.085 * sx, 0.1, -0.2),
				Vector3.ONE, Vector3(PI / 2 - 0.25, 0, 0)
			)
			_p(
				g, Models.cyl(0.052, 0.052, 0.02, 14), lens, HC + Vector3(0.085 * sx, 0.1, -0.215), Vector3.ONE,
				Vector3(PI / 2 - 0.25, 0, 0)
			)
		_p(g, HeroKit.band("ash_strap", 0.215, 0.205, 0.035, 0.012), m["leather"], HC + Vector3(0, 0.1, 0.0))
	# the sooty tailcoat: a short front, two long back tails
	var sk: Node3D = c["skirt"]
	var r0 := 0.25 * maxf(bw, cw * 0.9)
	_p(
		sk, HeroKit.drape("ash_coat|%.3f" % r0, r0, r0 * 1.2, 0.22, 0.0, 1.0, 5.0, 0.04, 0.0, 0.0), soot,
		Vector3(0, -0.02, 0)
	)
	for sx in [-1.0, 1.0]:
		_p(
			sk, HeroKit.sheet("ash_tail", 0.17, 0.62, 0.68, 0.0, -0.03, 1, 0.08), soot,
			Vector3(0.1 * sx, -0.05, r0 + 0.02)
		)
	_p(t, HeroKit.mantle("ash_lapel|%.3f" % cw, 0.24 * cw, 0.22 * bw, 0.07, 8.0, 0.2), soot2, Vector3(0, 0.575, 0.03))
	# brass buttons down the front
	for k in 3:
		_p(t, Models.sphere(0.022, 8), brass, Vector3(0, 0.52 - k * 0.16, -0.285 * bw))
	# the bellows pack: a pleated leather accordion on the back in a brass frame, with a team-colour strap
	var bp := Vector3(0, 0.34, 0.36 * bw)
	for k in 6:
		var w := 0.34 - absf(k - 2.5) * 0.015
		_p(
			t, Models.box(w, 0.05, 0.18), m["leather"] if k % 2 == 0 else soot2, bp + Vector3(0, -0.2 + k * 0.085, 0.0),
			Vector3.ONE, Vector3(0.0, 0.0, 0.0)
		)
	for sx in [-1.0, 1.0]:
		_p(t, Models.box(0.025, 0.6, 0.2), brass, bp + Vector3(0.18 * sx, 0.05, 0.0))
	_p(t, Models.box(0.38, 0.03, 0.22), brass, bp + Vector3(0, 0.34, 0.0))
	_p(t, Models.box(0.36, 0.03, 0.2), brass, bp + Vector3(0, -0.26, 0.0))
	_p(t, Models.box(0.36, 0.06, 0.21), m["acc"], bp + Vector3(0, 0.05, 0.0))
	# a brass pipe from the pack over the right shoulder and down the arm to the lance
	var pipe := [
		bp + Vector3(0.1, 0.36, 0.0), Vector3(0.2, 0.7, 0.2), Vector3(0.3, 0.72, 0.0), Vector3(0.32, 0.55, -0.2)
	]
	_p(
		t,
		HeroKit.loft(
			"ash_pipe", pipe, [Vector2(0.028, 0.028), Vector2(0.03, 0.03), Vector2(0.03, 0.03), Vector2(0.026, 0.026)],
			8, Vector3.UP, 1.0
		),
		brass
	)
	# a lantern at the left hip: a brass cage round a glowing core
	var lk := Vector3(-0.27 * cw, 0.04, -0.12)
	_p(t, Models.sphere(0.055, 10), _glow(Color("ffc860"), 1.8), lk)
	_p(t, HeroKit.band("ash_lcage", 0.07, 0.07, 0.12, 0.01), brass, lk)
	_p(t, Models.cyl(0.04, 0.07, 0.03, 10), brass, lk + Vector3(0, 0.08, 0))
	# small brass epaulettes, leather gauntlets with brass cuffs
	for sd in ["L", "R"]:
		var pv: Node3D = c["pl"] if sd == "L" else c["pr"]
		var sxx := -1.0 if sd == "L" else 1.0
		_p(
			pv, Models.cyl(0.11, 0.12, 0.04, 14), brass, Vector3(0.04 * sxx, 0.07, 0), Vector3.ONE,
			Vector3(0, 0, -0.25 * sxx)
		)
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.07, 0.11, 0.15), m["leather"], Vector3(0, -0.14, 0))
		_p(e2, HeroKit.band("ash_gcuff", 0.092, 0.092, 0.025, 0.01), brass, Vector3(0, -0.07, 0))
	HeroGear._greaves(c, soot, brass)

static func _undersuit(c: Dictionary) -> void:
	HeroGear._undersuit(c)

## Cinder carries no weapon: the fire comes from her hands (docs/heroes/ashwick.md), so there is no gun
## to build (no barrel, canister or hose). The weapon id stays "flamethrower" for the kit and its stats.
static func flamer(_gun: Node3D, _m_gun: Material, _m_dark: Material, _m_acc: Material) -> void:
	pass

## Dredge's harbour scattergun: a short, fat iron barrel ending in a flared brass bell, a pump wrapped in
## tarred rope, a riveted receiver, a drum of slugs on top and a stubby hook-shaped stock, with a hot
## glowing seam that flares on each shot.
static func scattergun(gun: Node3D, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	var brass := Models.toon(Color("c89a3c"), true)
	brass.set_shader_parameter("gloss", 0.6)
	var iron := Models.toon(Color("4a4d55"), true)
	var rope := Models.toon(Color("cdb88a"), true)
	var seam := Models.toon(Color("ffb070"), false, 1.4)
	_gp(gun, Models.box(0.15, 0.16, 0.36), m_gun, Vector3(0, 0, -0.1))
	for k in 3:
		_gp(gun, Models.sphere(0.014, 6), brass, Vector3(0.078, 0.05 - k * 0.04, -0.2 + k * 0.08))
	_gp(gun, Models.cyl(0.062, 0.07, 0.4, 14), iron, Vector3(0, 0.03, -0.48), Vector3(PI / 2, 0, 0))
	_gp(
		gun,
		HeroKit.loft(
			"dr_bell", [Vector3(0, 0.03, -0.66), Vector3(0, 0.03, -0.74), Vector3(0, 0.03, -0.8)],
			[Vector2(0.07, 0.07), Vector2(0.1, 0.1), Vector2(0.14, 0.12)], 16, Vector3.UP, 0.9
		),
		brass
	)
	_gp(gun, HeroKit.band("dr_bell_lip", 0.14, 0.12, 0.03, 0.014), brass, Vector3(0, 0.03, -0.8), Vector3(PI / 2, 0, 0))
	for k in 5:
		_gp(
			gun, HeroKit.band("dr_pump_rope", 0.08, 0.075, 0.022, 0.016), rope, Vector3(0, -0.04, -0.3 - k * 0.03),
			Vector3(PI / 2, 0, 0)
		)
	_gp(gun, Models.cyl(0.07, 0.07, 0.1, 14), m_acc, Vector3(0, 0.15, -0.1), Vector3(0, 0, PI / 2))
	_gp(gun, Models.box(0.02, 0.03, 0.26), seam, Vector3(0.08, 0.03, -0.14))
	_gp(gun, Models.cyl(0.024, 0.024, 0.16, 8), m_dark, Vector3(0, -0.12, 0.02))
	_gp(
		gun,
		HeroKit.loft(
			"dr_stock", [Vector3(0, -0.02, 0.08), Vector3(0, -0.06, 0.2), Vector3(0, -0.12, 0.3)],
			[Vector2(0.04, 0.06), Vector2(0.045, 0.07), Vector2(0.05, 0.09)], 10, Vector3.UP, 0.85
		),
		m_dark
	)

static func _gp(gun: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> void:
	Models.part(gun, mesh, mat, pos, scl, rot)
