class_name HeroGearCare
## Gear for the support pair, kept out of hero_gear.gd.
##   Moosh Moosh (tender, medium): a courier. A flap cap, a tall wooden pack-frame with a bedroll, and a
##   caged lantern hanging on a hook ABOVE the head (the silhouette from the match camera: a person
##   with a glowing lamp on a pole); a rope coil, a tin cup and a cream poncho with an ochre hem.
##   Tamsin (rimewright, light): a rink-keeper. An ear-flap cap with a fur band, a huge fluffy collar,
##   two long teal scarf tails, blade skates, a cluster of ice shards on one shoulder and a quilted
##   short coat. Neither design borrows from any hero in another game.

const HC := Vector3(0, 0.86, 0)

static func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.part(n, mesh, mat, pos, scl, rot)

static func cover(arch: String, bare: bool) -> String:
	return "" if bare else "hat"

static func dress(arch: String, c: Dictionary) -> void:
	if arch == "tender":
		_tender(c)
	else:
		_rime(c)

# ------------------------------------------------------------------------------------------ Moosh Moosh
static func _tender(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
	var amber := Color("f0b050")
	var wood := Models.toon(Color("7a5434"))
	var cream := Models.toon(Color("efe2c4"))
	var ochre := Models.toon(Color("c98a2e"), true, 0.4)
	var rope := Models.toon(Color("b79a6a"))
	var lamp := Models.glow_mat(Color(amber, 0.95))
	# the flap cap: a knit dome with a short peak and two ear flaps tied under the chin
	if not bool(c["bare"]):
		var g: Node3D = c["gear"]
		_p(g, Models.sphere(0.215, 18), m["hero"], HC + Vector3(0, 0.08, 0.01), Vector3(1.0, 0.72, 1.06))
		_p(g, HeroGear.brim("tend_peak", 0.17, 0.3, 0.0, 0.05, 0.0, 0.9), m["hero"], HC + Vector3(0, 0.13, -0.1), Vector3(0.85, 1.0, 0.55))
		_p(g, HeroKit.band("tend_capband", 0.2, 0.21, 0.05, 0.012), cream, HC + Vector3(0, 0.1, 0.01))
		for sx in [-1.0, 1.0]:
			_p(g, HeroKit.lock_mesh("tend_flap%d" % int(sx), [Vector3(0.19 * sx, 0.9, 0.0), Vector3(0.21 * sx, 0.78, 0.02), Vector3(0.2 * sx, 0.66, 0.0)], 0.06, 0.4, Vector3.FORWARD, 0.8), m["hero"])
		_p(g, Models.sphere(0.04, 8), ochre, HC + Vector3(0, 0.27, 0.0))
	# the cream poncho over the shoulders with an ochre hem
	_p(t, HeroKit.drape("tend_poncho|%.3f" % cw, 0.2 * cw, 0.37 * cw, 0.26, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.014), cream, Vector3(0, 0.63, 0.0))
	_p(t, HeroKit.drape_hem("tend_poncho|%.3f" % cw, 0.2 * cw, 0.37 * cw, 0.26, 0.0, 1.0, 6.0, 0.05, 0.0, 0.1, 0.12), ochre, Vector3(0, 0.63, 0.0))
	# a leather strap across the chest with a pair of brass buttons, and a belt of pouches
	var bp := [Vector3(0.2, 0.6, -0.13), Vector3(0.04, 0.4, -0.26), Vector3(-0.14, 0.2, -0.24)]
	_p(t, HeroKit.loft("tend_strap", bp, [Vector2(0.03, 0.01), Vector2(0.032, 0.011), Vector2(0.03, 0.01)], 6, Vector3.FORWARD, 0.9), m["leather"], Vector3.ZERO, Vector3(cw, 1.0, bw))
	for sx in [-1.0, 1.0]:
		_p(t, Models.box(0.08, 0.1, 0.07), m["leather"], Vector3(0.22 * sx * bw, 0.04, -0.05), Vector3.ONE, Vector3(0, 0.45 * sx, 0))
	# the pack-frame: two poles up the back, rungs, a bedroll, a crate, and the lamp hook above the head
	var bz := 0.27 * bw
	for sx in [-1.0, 1.0]:
		_p(t, Models.cyl(0.02, 0.02, 1.62, 8), wood, Vector3(0.13 * sx, 0.72, bz))
	for ry in [0.1, 0.5, 1.0]:
		_p(t, Models.cyl(0.016, 0.016, 0.3, 8), wood, Vector3(0, ry, bz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	_p(t, Models.cyl(0.095, 0.095, 0.5, 12), m["hero"], Vector3(0, 0.32, bz + 0.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	for sx in [-0.17, 0.17]:
		_p(t, Models.cyl(0.1, 0.1, 0.03, 12), cream, Vector3(sx, 0.32, bz + 0.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	_p(t, Models.box(0.26, 0.18, 0.14), wood, Vector3(0, 0.08, bz + 0.1))
	_p(t, Models.box(0.27, 0.03, 0.15), ochre, Vector3(0, 0.17, bz + 0.1))
	# the hook: a pole up from the frame, over the head, and a caged lantern hanging off its end
	_p(t, Models.cyl(0.014, 0.014, 0.72, 8), wood, Vector3(0, 1.62, bz - 0.12), Vector3.ONE, Vector3(PI * 0.5 - 0.3, 0, 0))
	var lanp := Node3D.new(); lanp.name = "Lantern"; lanp.position = Vector3(0, 1.36, -0.04)
	t.add_child(lanp)
	var core := _p(lanp, Models.sphere(0.075, 14), lamp, Vector3.ZERO)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_p(lanp, Models.sphere(0.13, 12), m["glow_soft"], Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_p(lanp, Models.box(0.012, 0.19, 0.012), m["dark"], Vector3(cos(a) * 0.095, 0, sin(a) * 0.095))
	_p(lanp, Models.cyl(0.0, 0.1, 0.07, 8), m["dark"], Vector3(0, 0.13, 0))
	_p(lanp, Models.cyl(0.08, 0.06, 0.03, 8), m["dark"], Vector3(0, -0.11, 0))
	_p(lanp, Models.cyl(0.006, 0.006, 0.12, 4), m["gold"], Vector3(0, 0.22, 0))
	# a rope coil and a tin cup on the right hip, forearm bracers
	var rc := TorusMesh.new(); rc.inner_radius = 0.06; rc.outer_radius = 0.09; rc.rings = 18; rc.ring_segments = 6
	_p(t, rc, rope, Vector3(0.3 * bw, 0.0, 0.0), Vector3.ONE, Vector3(0, 0.0, PI * 0.5))
	_p(t, Models.cyl(0.04, 0.032, 0.06, 8), m["steel"], Vector3(-0.28 * bw, 0.0, 0.08))
	for sd in ["L", "R"]:
		var e2: Node3D = (c["arms"][sd] as Array)[1]
		_p(e2, HeroKit.cuff(0.062, 0.075, 0.1), m["leather"], Vector3(0, -0.14, 0))

# ------------------------------------------------------------------------------------------ Tamsin
static func _rime(c: Dictionary) -> void:
	var m: Dictionary = c["m"]
	var t: Node3D = c["torso"]
	var bw: float = c["bw"]; var cw: float = c["cw"]
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
			_p(g, HeroKit.lock_mesh("rime_flap%d" % int(sx), [Vector3(0.2 * sx, 0.92, 0.02), Vector3(0.23 * sx, 0.8, 0.03), Vector3(0.22 * sx, 0.68, 0.02)], 0.075, 0.5, Vector3.FORWARD, 0.8), m["hero"])
			_p(g, Models.sphere(0.05, 8), fur, HC + Vector3(0.22 * sx, -0.18, 0.02))
		_p(g, Models.sphere(0.055, 10), fur, HC + Vector3(0, 0.27, 0.02))
	# the collar: a ring of fur tufts round the neck
	var cr := 0.2 * cw
	for k in 14:
		var a := TAU * k / 14.0
		_p(t, Models.sphere(0.075, 8), fur, Vector3(cos(a) * cr * 1.15, 0.64 + 0.02 * sin(k * 2.0), sin(a) * cr * 1.25 * bw), Vector3(1.0, 0.8, 1.0))
	for k in 10:
		var a2 := TAU * (k + 0.5) / 10.0
		_p(t, Models.sphere(0.06, 8), fur, Vector3(cos(a2) * cr * 0.8, 0.7, sin(a2) * cr * 0.9 * bw))
	# a quilted short coat: a flared hem with a fur edge and a teal sash
	_p(t, HeroKit.drape("rime_coat|%.3f" % cw, 0.22 * cw, 0.33 * bw, 0.2, 0.0, 1.0, 8.0, 0.04, 0.0, 0.0, 0.016), m["body"], Vector3(0, 0.0, 0.0))
	_p(t, HeroKit.drape_hem("rime_coat|%.3f" % cw, 0.22 * cw, 0.33 * bw, 0.2, 0.0, 1.0, 8.0, 0.04, 0.0, 0.0, 0.07), fur, Vector3(0, 0.0, 0.0))
	var rx := 0.225 * maxf(cw, bw) + 0.015; var rz := 0.214 * bw + 0.012
	_p(t, HeroKit.band("rime_sash|%.3f" % rx, rx, rz, 0.06, 0.014), teal, Vector3(0, 0.08, 0), Vector3.ONE, Vector3(0, 0, 0.05))
	# two long scarf tails streaming behind
	var scarf := Models._pivot(t, "Scarf", Vector3(0, 0.6, 0.18 * bw))
	for sx in [-1.0, 1.0]:
		var ln := 0.9 if sx < 0.0 else 0.7
		_p(scarf, HeroKit.lock_mesh("rime_scarf%d" % int(sx), [Vector3(0.06 * sx, 0.0, 0.0), Vector3(0.12 * sx, -0.1, 0.22), Vector3(0.2 * sx, -0.18, 0.42 * ln + 0.2), Vector3(0.26 * sx, -0.32, 0.7 * ln + 0.3)], 0.12, 0.4, Vector3.BACK, 0.8, 0.5), teal)
		_p(scarf, HeroKit.lock_mesh("rime_scarfh%d" % int(sx), [Vector3(0.2 * sx, -0.18, 0.42 * ln + 0.2), Vector3(0.26 * sx, -0.32, 0.7 * ln + 0.3)], 0.12, 0.4, Vector3.BACK, 0.9, 0.4), fur, Vector3(0, 0.003, 0))
	# ice shards cluster on the left shoulder
	for k in 3:
		_p(c["pl"], Models.crystal(0.03 + 0.012 * (k % 2), 0.15 - 0.03 * k, 5), ice, Vector3(-0.02 - 0.04 * k, 0.07 + 0.015 * k, 0.03 * (k - 1)), Vector3.ONE, Vector3(0.3 * (k - 1), 0, 0.5 + 0.35 * k))
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
## The Lantern Crook (a shepherd's crook with a little lamp on its hook) and the Hoar Fan (a folding
## fan of ice slats). The gun points down -Z.
static func weapon(gun: Node3D, wid: String, m_gun: Material, m_dark: Material, m_acc: Material) -> void:
	if wid == "lantern_crook":
		var wood := Models.toon(Color("7a5434"))
		_p(gun, Models.cyl(0.022, 0.026, 1.05, 8), wood, Vector3(0, 0, -0.3), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		for k in 5:
			var a := PI * 0.5 + k * 0.5
			_p(gun, Models.cyl(0.02, 0.022, 0.12, 8), wood, Vector3(0, 0.1 - cos(a) * 0.1 + 0.02 * k, -0.84 - sin(a) * 0.1), Vector3.ONE, Vector3(PI * 0.5 + (a - PI * 0.5) * 0.9, 0, 0))
		_p(gun, Models.cyl(0.006, 0.006, 0.1, 4), m_dark, Vector3(0, 0.12, -0.96))
		var lamp := Models.glow_mat(Color("ffc46a", 0.95))
		_p(gun, Models.sphere(0.05, 10), lamp, Vector3(0, 0.02, -0.96)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_p(gun, Models.cyl(0.0, 0.06, 0.04, 8), m_dark, Vector3(0, 0.08, -0.96))
		_p(gun, Models.cyl(0.05, 0.04, 0.02, 8), m_dark, Vector3(0, -0.04, -0.96))
		_p(gun, Models.cyl(0.03, 0.03, 0.04, 8), m_acc, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		return
	# hoar_fan: seven slats spread over a half disc, tipped in glowing ice, on a short grip
	var bone := Models.toon(Color("e8f2f0"))
	var ice := Models.glow_mat(Color("9af0e6", 0.85))
	_p(gun, Models.cyl(0.022, 0.026, 0.22, 8), m_dark, Vector3(0, -0.03, -0.02), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	for k in 9:
		var a := -1.15 + 2.3 * float(k) / 8.0
		var dir := Vector3(sin(a), cos(a), 0)
		var base := Vector3(0, 0.0, -0.16)
		_p(gun, Models.box(0.035, 0.34, 0.012), bone, base + dir * 0.19, Vector3.ONE, Vector3(0, 0, -a))
		_p(gun, Models.box(0.03, 0.08, 0.016), ice, base + dir * 0.36, Vector3.ONE, Vector3(0, 0, -a))
	_p(gun, Models.sphere(0.03, 8), m_acc, Vector3(0, 0.0, -0.16))
