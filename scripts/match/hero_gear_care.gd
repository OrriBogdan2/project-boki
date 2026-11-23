class_name HeroGearCare
## Gear for the support pair, kept out of hero_gear.gd.
##   Pip (tender, small): a courier. A flap cap, a small satchel and bedroll low on the back, a
##   long ember-tipped tail that swings as she scurries, ember light cupped in both palms (she holds
##   nothing), a rope coil, a tin cup and a cream poncho with an ochre hem.
##   Claire (rimewright, light): a rink-keeper. An ear-flap cap with a fur band, a huge fluffy collar,
##   two long teal scarf tails, blade skates, a cluster of ice shards on one shoulder and a quilted
##   short coat. Neither design borrows from any hero in another game.

const HC := Vector3(0, 0.86, 0)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

static func cover(arch: String, bare: bool) -> String:
	return "" if bare else "hat"

static func dress(arch: String, c: Dictionary) -> void:
	if arch == "tender":
		_tender(c)
	else:
		_rime(c)

# ------------------------------------------------------------------------------------------ Pip
static func _tender(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var amber := Color("f0b050")
	var wood := Models.toon(Color("7a5434"))
	var cream := Models.toon(Color("efe2c4"))
	var ochre := Models.toon(Color("c98a2e"), true, 0.4)
	var rope := Models.toon(Color("b79a6a"))
	# the flap cap: a knit dome with a short peak and two ear flaps tied under the chin
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		_p(g, Models.sphere(0.215, 18), m["hero"], HC + Vector3(0, 0.08, 0.01), Vector3(1.0, 0.72, 1.06))
		_p(
				g, HeroGear.brim("tend_peak", 0.17, 0.3, 0.0, 0.05, 0.0, 0.9), m["hero"],
				HC + Vector3(0, 0.13, -0.1), Vector3(0.85, 1.0, 0.55))
		_p(g, HeroKit.band("tend_capband", 0.2, 0.21, 0.05, 0.012), cream, HC + Vector3(0, 0.1, 0.01))
		for sx in [-1.0, 1.0]:
			_p(
					g,
					HeroKit.lock_mesh(
						"tend_flap%d" % int(sx),
						[Vector3(0.19 * sx, 0.9, 0.0), Vector3(0.21 * sx, 0.78, 0.02), Vector3(0.2 * sx, 0.66, 0.0)],
						0.06, 0.4, Vector3.FORWARD, 0.8),
					m["hero"])
		_p(g, Models.sphere(0.04, 8), ochre, HC + Vector3(0, 0.27, 0.0))
	# the cream poncho over the shoulders with an ochre hem
	_p(
			t,
			HeroKit.drape("tend_poncho|%.3f" % cw, 0.2 * cw, 0.37 * cw, 0.26, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.014),
			cream, Vector3(0, 0.63, 0.0))
	_p(
			t,
			HeroKit.drape_hem("tend_poncho|%.3f" % cw, 0.2 * cw, 0.37 * cw, 0.26, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.12),
			ochre, Vector3(0, 0.63, 0.0))
	# a leather strap across the chest with a pair of brass buttons, and a belt of pouches
	var bp := [Vector3(0.2, 0.6, -0.13), Vector3(0.04, 0.4, -0.26), Vector3(-0.14, 0.2, -0.24)]
	_p(
			t,
			HeroKit.loft(
				"tend_strap", bp, [Vector2(0.03, 0.01), Vector2(0.032, 0.011), Vector2(0.03, 0.01)], 6,
				Vector3.FORWARD, 0.9),
			m["leather"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	for sx in [-1.0, 1.0]:
		_p(
				t, Models.box(0.08, 0.1, 0.07), m["leather"], Vector3(0.22 * sx * bw, 0.04, -0.05), Vector3.ONE,
				Vector3(0, 0.45 * sx, 0))
	# a small satchel low on the back with a bedroll strapped over it: nothing stands above her head
	var bz := 0.24 * bw
	_p(t, Models.box(0.28, 0.24, 0.15), wood, Vector3(0, 0.22, bz))
	_p(t, Models.box(0.29, 0.03, 0.16), ochre, Vector3(0, 0.33, bz))
	_p(
			t, Models.cyl(0.085, 0.085, 0.42, 12), m["hero"], Vector3(0, 0.44, bz + 0.02), Vector3.ONE,
			Vector3(0, 0, PI * 0.5))
	for sx in [-0.15, 0.15]:
		_p(t, Models.cyl(0.09, 0.09, 0.03, 12), cream, Vector3(sx, 0.44, bz + 0.02), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	_tail(t, bw, amber)
	# a rope coil and a tin cup on the right hip, forearm bracers
	var rc := TorusMesh.new()
	rc.inner_radius = 0.06
	rc.outer_radius = 0.09
	rc.rings = 18
	rc.ring_segments = 6
	_p(t, rc, rope, Vector3(0.3 * bw, 0.0, 0.0), Vector3.ONE, Vector3(0, 0.0, PI * 0.5))
	_p(t, Models.cyl(0.04, 0.032, 0.06, 8), m["steel"], Vector3(-0.28 * bw, 0.0, 0.08))
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.062, 0.075, 0.1), m["leather"], Vector3(0, -0.14, 0))
	_palms(c)

## Her trailing piece: a long ember-tipped brush tail off the small of the back that swings with each
## quick step (HunterAnim drives the "Tail" pivot). Skipped when the look already has a tail.
static func _tail(t: Node3D, bw: float, amber: Color) -> void:
	if t.get_node_or_null("Tail") != null:
		return
	var tail := Models._pivot(t, "Tail", Vector3(0, 0.12, 0.2 * bw))
	var pts := [
		Vector3(0, 0, 0), Vector3(0, -0.06, 0.18), Vector3(0, -0.02, 0.4), Vector3(0, 0.1, 0.58), Vector3(0, 0.2, 0.66)]
	var wid := [
		Vector2(0.05, 0.05), Vector2(0.1, 0.1), Vector2(0.13, 0.12), Vector2(0.1, 0.1), Vector2(0.03, 0.03)]
	_p(tail, HeroKit.loft("tend_tail", pts, wid, 10, Vector3.UP, 0.8), Models.toon(amber.darkened(0.15), true, 0.4))
	var tip := _p(tail, Models.sphere(0.075, 10), Models.glow_mat(Color("ffd890", 0.9)), Vector3(0, 0.16, 0.63))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A soft ember glow cupped in each palm: her casts come out of her hands.
static func _palms(c: Dictionary) -> void:
	for sd in ["L", "R"]:
		var hand: Node3D = (c["arms"][sd] as Array)[2]
		var glow := _p(hand, Models.sphere(0.05, 8), Models.glow_mat(Color("ffd890", 0.85)), Vector3(0, -0.05, -0.04))
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ------------------------------------------------------------------------------------------ Claire
static func _rime(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]
	var cw: float = c["cw"]
	var fur := Models.toon(Color("f2eee6"), true, 0.3)
	var teal := Models.toon(Color("2f9c92"), true, 0.4)
	var ice := Models.glow_mat(Color("aef6ec", 0.82))
	var steel := Models.shiny(Color("c8d4de"), 0.6)
	# the ear-flap cap: a plum dome, a fur band, flaps hanging past the ears
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		_p(g, Models.sphere(0.215, 18), m["hero"], HC + Vector3(0, 0.07, 0.01), Vector3(1.0, 0.76, 1.08))
		_p(g, HeroKit.band("rime_fur", 0.215, 0.225, 0.085, 0.03), fur, HC + Vector3(0, 0.06, 0.01))
		for sx in [-1.0, 1.0]:
			_p(
					g,
					HeroKit.lock_mesh(
						"rime_flap%d" % int(sx),
						[Vector3(0.2 * sx, 0.92, 0.02), Vector3(0.23 * sx, 0.8, 0.03), Vector3(0.22 * sx, 0.68, 0.02)],
						0.075, 0.5, Vector3.FORWARD, 0.8),
					m["hero"])
			_p(g, Models.sphere(0.05, 8), fur, HC + Vector3(0.22 * sx, -0.18, 0.02))
		_p(g, Models.sphere(0.055, 10), fur, HC + Vector3(0, 0.27, 0.02))
	# the collar: a ring of fur tufts round the neck
	var cr := 0.2 * cw
	for k in 14:
		var a := TAU * k / 14.0
		_p(
				t, Models.sphere(0.075, 8), fur,
				Vector3(cos(a) * cr * 1.15, 0.64 + 0.02 * sin(k * 2.0), sin(a) * cr * 1.25 * bw),
				Vector3(1.0, 0.8, 1.0))
	for k in 10:
		var a2 := TAU * (k + 0.5) / 10.0
		_p(t, Models.sphere(0.06, 8), fur, Vector3(cos(a2) * cr * 0.8, 0.7, sin(a2) * cr * 0.9 * bw))
	# a quilted short coat: a flared hem with a fur edge and a teal sash
	_p(
			t,
			HeroKit.drape("rime_coat|%.3f" % cw, 0.22 * cw, 0.33 * bw, 0.2, 0.0, 1.0, 8.0, 0.04, 0.0, 0.0, 0.016),
			m["body"], Vector3(0, 0.0, 0.0))
	_p(
			t,
			HeroKit.drape_hem("rime_coat|%.3f" % cw, 0.22 * cw, 0.33 * bw, 0.2, 0.0, 1.0, 8.0, 0.04, 0.0, 0.0, 0.07),
			fur, Vector3(0, 0.0, 0.0))
	var rx := 0.225 * maxf(cw, bw) + 0.015
	var rz := 0.214 * bw + 0.012
	_p(
			t, HeroKit.band("rime_sash|%.3f" % rx, rx, rz, 0.06, 0.014), teal, Vector3(0, 0.08, 0), Vector3.ONE,
			Vector3(0, 0, 0.05))
	# two long scarf tails streaming behind
	var scarf := Models._pivot(t, "Scarf", Vector3(0, 0.6, 0.18 * bw))
	for sx in [-1.0, 1.0]:
		var ln := 0.55 if sx < 0.0 else 0.42      # short: on her long frame longer tails read as a spike
		_p(
				scarf,
				HeroKit.lock_mesh(
					"rime_scarf_s%d" % int(sx),
					[
						Vector3(0.06 * sx, 0.0, 0.0), Vector3(0.12 * sx, -0.1, 0.22),
						Vector3(0.18 * sx, -0.32, 0.3 * ln + 0.1), Vector3(0.22 * sx, -0.6, 0.45 * ln + 0.12)],
					0.12, 0.4, Vector3.BACK, 0.8, 0.5),
				teal)
		_p(
				scarf,
				HeroKit.lock_mesh(
					"rime_scarfh_s%d" % int(sx),
					[Vector3(0.18 * sx, -0.32, 0.3 * ln + 0.1), Vector3(0.22 * sx, -0.6, 0.45 * ln + 0.12)], 0.12,
					0.4, Vector3.BACK, 0.9, 0.4),
				fur, Vector3(0, 0.003, 0))
	# ice shards cluster on the left shoulder
	for k in 3:
		_p(
				c["pl"], Models.crystal(0.03 + 0.012 * (k % 2), 0.15 - 0.03 * k, 5), ice,
				Vector3(-0.02 - 0.04 * k, 0.07 + 0.015 * k, 0.03 * (k - 1)), Vector3.ONE,
				Vector3(0.3 * (k - 1), 0, 0.5 + 0.35 * k))
	# blade skates under both boots
	for sx in ["L", "R"]:
		var knee: Node3D = c["knees"][sx]
		_p(knee, Models.box(0.014, 0.045, 0.34), steel, Vector3(0, -0.285, -0.035))
		for zz in [-0.14, 0.07]:
			_p(knee, Models.box(0.012, 0.06, 0.012), steel, Vector3(0, -0.25, zz))
		_p(knee, Models.sphere(0.022, 6), steel, Vector3(0, -0.285, -0.2))
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.066, 0.092, 0.09), fur, Vector3(0, -0.15, 0))

# ------------------------------------------------------------------------------------------ weapons
## Ember Cast (nothing held) and the Hoar Fan (a folding fan of ice slats). The gun points down -Z.
static func weapon(gun: Node3D, wid: String, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	if wid == "lantern_crook":
		# Ember Cast: nothing in the hands (an empty Mag keeps the shared gun from adding its magazine)
		var mag := Node3D.new()
		mag.name = "Mag"
		gun.add_child(mag)
		return
	# hoar_fan: nine bone slats on a riveted pivot, each tipped with a long ice crystal, a frosted
	# paper web between them and a teal tassel off the grip
	var bone := Models.toon(Color("e8f2f0"))
	var ice := CareLook.ice_mat(Color("9af0e6"), 0.85, 0.35)
	var web := Models.glow_mat(Color("bff7ef", 0.35))
	_p(gun, Models.cyl(0.022, 0.026, 0.22, 8), m_dark, Vector3(0, -0.03, -0.02), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	for k in 9:
		var a := -1.2 + 2.4 * float(k) / 8.0
		var dir := Vector3(sin(a), cos(a), 0)
		var base := Vector3(0, 0.0, -0.16)
		_p(gun, Models.box(0.03, 0.32, 0.01), bone, base + dir * 0.18, Vector3.ONE, Vector3(0, 0, -a))
		var tip := _p(
				gun, Models.crystal(0.026, 0.16 + 0.04 * float(k % 2), 4), ice, base + dir * 0.4, Vector3.ONE,
				Vector3(0, 0, -a))
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k < 8:
			var a2 := a + 0.15
			_p(
					gun, Models.box(0.075, 0.24, 0.004), web, base + Vector3(sin(a2), cos(a2), 0) * 0.2,
					Vector3.ONE, Vector3(0, 0, -a2)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p(gun, Models.sphere(0.032, 8), m_acc, Vector3(0, 0.0, -0.16))
	_p(gun, Models.cyl(0.012, 0.02, 0.12, 6), Models.toon(Color("2f9c92"), true, 0.4), Vector3(0, -0.1, 0.08))
