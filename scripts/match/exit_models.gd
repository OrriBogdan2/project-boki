class_name ExitModels
## The props for an outpost's way out (see Exits): the uplink mast, its lift and the yard palisade.
## Built from simple meshes like everything in Models.

const UPLINK := Color("6ae0ff")    # outpost uplinks: sky cyan

static func _beam(c: Color, h: float, r0: float, r1: float, a := 0.22) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.cyl(r0, r1, h, 12)
	mi.material_override = Models.glow_mat(Color(c, a))
	mi.position.y = h * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## The outpost's uplink: a stone plinth with a brass console, a tall mast topped with a crystal and a
## banner on the mast, and four pylons that make the lift. It shows its state through the object itself
## (OutpostLook): the crystal and the pylon lamps fill with the charge, the banner climbs the mast in the
## holder's team colour. The lift is the column of light that opens when the uplink is complete.
## Named children: Mast/Crystal, Banner/Cloth, Lamp0..3, Charge (a ring that fills, shown only while it
## matters), Zone and Signal (ExitSignal: the yard's edge and the sky beam), Lift (the open way out).
static func uplink() -> Node3D:
	var root := Node3D.new()
	var stone := Models.toon(Color("8a8f9c")); var dark := Models.toon(Color("4a4e5c")); var brass := Models.toon(Color("e0b84a"), true, 0.25)
	if Flora.v2():
		_stone_ring(root, 0.92, 0.38, 8, Color("8e8a84"), 0.0)
		Models.part(root, Models.cyl(0.62, 0.66, 0.1, 16), Models.toon(Color("a49e94")), Vector3(0, 0.4, 0))
	else:
		Models.part(root, Models.cyl(0.8, 0.95, 0.36, 8), stone, Vector3(0, 0.18, 0))
	Models.part(root, Models.box(0.8, 0.7, 0.5), dark, Vector3(0, 0.7, 0.25))
	var screen_mat := Models.toon(OutpostLook.NEUTRAL, false, 0.2)
	var tilt := Vector3(-0.35, 0, 0)
	Models.part(root, Models.box(0.6, 0.36, 0.05), screen_mat, Vector3(0, 0.82, 0.52), Vector3.ONE, tilt, "Screen")
	var mast := Node3D.new(); mast.name = "Mast"; root.add_child(mast)
	Models.part(mast, Models.cyl(0.09, 0.14, 3.2, 8), dark, Vector3(0, 2.0, -0.15))
	for y in [1.4, 2.2, 3.0]:
		Models.part(mast, Models.cyl(0.32, 0.32, 0.06, 10), brass, Vector3(0, y, -0.15))
	var cr := Node3D.new(); cr.name = "Crystal"; cr.position = Vector3(0, 3.9, -0.15); mast.add_child(cr)
	var cm := Models.toon(OutpostLook.NEUTRAL, true, 0.0)
	cm.set_shader_parameter("gloss", 0.7)
	Models.part(cr, Models.crystal(0.26, 0.95, 6), cm, Vector3(0, 0.12, 0))
	Models.part(cr, Models.crystal(0.26, 0.45, 6), cm, Vector3(0, -0.45, 0), Vector3.ONE, Vector3(PI, 0, 0))
	var banner := Node3D.new()
	banner.name = "Banner"
	banner.position = Vector3(0, OutpostLook.BANNER_LOW, -0.15)
	mast.add_child(banner)
	Models.part(banner, Models.box(1.25, 0.08, 0.08), dark, Vector3(0.55, 0, 0))
	var cloth_mat := Models.toon(OutpostLook.NEUTRAL, false, 0.0)
	var cloth_at := Vector3(0.55, -0.7, 0)
	Models.part(banner, Models.box(1.0, 1.3, 0.04), cloth_mat, cloth_at, Vector3.ONE, Vector3.ZERO, "Cloth")
	PropAnim.on(cr, 0.25, 0.04)
	# the lift: four pylons round the plinth, each capped with a lamp that lights as the charge fills
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		Models.part(root, Models.box(0.3, 1.2, 0.3), stone, Vector3(cos(a) * 1.9, 0.6, sin(a) * 1.9))
		if Flora.v2():
			Models.part(root, Models.box(0.42, 0.14, 0.42), Models.toon(Color("a49e94")), Vector3(cos(a) * 1.9, 1.24, sin(a) * 1.9), Vector3.ONE, Vector3(0, -a, 0))
			Models.part(root, Models.box(0.44, 0.16, 0.44), Models.toon(Color("6e6a66")), Vector3(cos(a) * 1.9, 0.08, sin(a) * 1.9), Vector3.ONE, Vector3(0, -a, 0))
		var lamp_at := Vector3(cos(a) * 1.9, 1.38, sin(a) * 1.9)
		var lamp_mat := Models.toon(OutpostLook.NEUTRAL, false, 0.0)
		Models.part(root, Models.box(0.3, 0.1, 0.3), lamp_mat, lamp_at, Vector3.ONE, Vector3(0, -a, 0), "Lamp%d" % i)
	var charge := MeshInstance3D.new(); charge.name = "Charge"
	charge.mesh = Models.flat_quad(Exits.OUTPOST_R * 2.0 - 0.6)
	var chm := Models.ring_mat(Color(UPLINK.lightened(0.3), 0.95), 0.08)
	chm.set_shader_parameter("arc", 0.0)
	charge.material_override = chm
	charge.position.y = 0.08
	charge.visible = false
	root.add_child(charge)
	ExitSignal.attach(root, UPLINK, Exits.OUTPOST_R * 2.0)
	var lift := Node3D.new(); lift.name = "Lift"; lift.visible = false; root.add_child(lift)
	var pad := MeshInstance3D.new(); pad.mesh = Models.flat_quad(3.6)
	var lpm := Models.ring_mat(Color(UPLINK.lightened(0.2), 0.9), 0.1)
	lpm.set_shader_parameter("fill", 0.25)
	pad.material_override = lpm; pad.position.y = 0.09
	lift.add_child(pad)
	lift.add_child(_beam(UPLINK, 9.0, 1.5, 1.7, 0.14))
	Flora.paint_set_piece(root)
	return root

## Corner posts with pennants for an outpost on a map without authored walls.
static func palisade(half: float) -> Node3D:
	var root := Node3D.new()
	var wood := Models.toon(Color("6e5038"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Models.part(root, Models.cyl(0.14, 0.18, 1.8, 8), wood, Vector3(sx * half, 0.9, sz * half))
			Models.part(root, Models.box(0.04, 0.4, 0.6), Models.toon(UPLINK), Vector3(sx * half, 1.55, sz * half + 0.32))
	Flora.paint_set_piece(root)
	return root

## A plank deck w wide (x) and d long (z), its top at y = 0.1: planks of slightly uneven width and
## length, a shade apart, nailed down, with dark gaps between them.
static func _deck(root: Node3D, w: float, d: float, base: Color) -> void:
	var rr := RandomNumberGenerator.new(); rr.seed = 9177
	var gap := Models.toon(base.darkened(0.6))
	Models.part(root, PropSculpt.bx(w - 0.1, 0.06, d - 0.05), gap, Vector3(0, 0.03, 0))
	var mats: Array = []
	for k in 3:
		mats.append(Models.toon(base.lightened(-0.06 + k * 0.07)))
	var nail := Models.toon(Color("3a3440"))
	var z := -d * 0.5
	while z < d * 0.5 - 0.15:
		var pw := rr.randf_range(0.36, 0.5)
		var plen := w + rr.randf_range(-0.12, 0.08)
		var off := rr.randf_range(-0.06, 0.06)
		Models.part(root, PropSculpt.bx(plen, 0.09, pw - 0.04), mats[rr.randi_range(0, 2)], Vector3(off, 0.07 + rr.randf_range(-0.008, 0.01), z + pw * 0.5), Vector3.ONE, Vector3(0, rr.randf_range(-0.012, 0.012), 0))
		for sx in [-w * 0.45, w * 0.45]:
			Models.part(root, Models.sphere(0.022, 6), nail, Vector3(sx, 0.12, z + pw * 0.5))
		z += pw

## A ring of chunky wedge-cut stones (a collar, a plinth): n stones around a circle of radius r, h
## tall, each chiselled (rounded box), a little uneven, with dark joints and a lighter top.
static func _stone_ring(root: Node3D, r: float, h: float, n: int, c: Color, inner := 0.55) -> void:
	var rr := RandomNumberGenerator.new(); rr.seed = n * 31 + int(r * 100.0)
	Models.part(root, Models.cyl(r * 0.96, r * 0.98, h * 0.9, 16), Models.toon(c.darkened(0.55)), Vector3(0, h * 0.45, 0))
	var ms: Array = []
	for k in 3:
		ms.append(Models.toon(c.lightened(-0.05 + k * 0.06)))
	var rin := r * inner
	for i in n:
		var a := TAU * (i + 0.5) / n
		var arc := TAU * r / n
		var depth := r - rin if inner > 0.0 else r * 0.5
		var mid := (r + rin) * 0.5 if inner > 0.0 else r * 0.72
		var hh := h + rr.randf_range(-0.03, 0.04)
		Models.part(root, PropSculpt.bx(arc * 0.94, hh, depth), ms[rr.randi_range(0, 2)], Vector3(cos(a) * mid, hh * 0.5, sin(a) * mid), Vector3.ONE, Vector3(rr.randf_range(-0.03, 0.03), PI * 0.5 - a, rr.randf_range(-0.03, 0.03)))
	if inner <= 0.0:
		# a solid plinth: a cap stone over the middle
		Models.part(root, Models.cyl(r * 0.5, r * 0.52, h + 0.02, 16), ms[1], Vector3(0, (h + 0.02) * 0.5, 0))
