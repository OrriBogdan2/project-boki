class_name ModelsFace
## Faces and hair caps. Moved out of Models; callers still use the Models facade.


## Eyes, brows and a mouth: small shapes, but they carry a lot of character.
## The face on the head: eyes, brows, nose and mouth for the look's expression and gender, sized and
## placed by its face factors (MantleLook params: eye_size, eye_shape, brow, nose), and its markings.
static func _face(torso: Node3D, lk: Dictionary, m_dark: Material, m_skin: Material, paint: Color) -> void:
	var face := int(lk["face"])
	var detail := int(lk["detail"])
	var skin: Color = lk["skin_col"]
	var hair_c: Color = lk["hair_col"]
	var fem := int(lk["gender"]) == 0
	var shine := ModelsBase.toon(Color.WHITE, false, 1.0)
	var white := ModelsBase.toon(Color("fbf8f2"), false, 0.1)
	var iris := ModelsBase.toon(lk["eye_col"], false)
	iris.set_shader_parameter("gloss", 0.85)
	iris.set_shader_parameter("sss", 0.0)
	var y := 0.868
	# big readable eyes; rounder for her, narrower for him
	var es: float = (1.3 if fem else 1.1) * float(lk["eye_size"])
	var eh := float(lk["eye_shape"])        # taller (rounder) or flatter (narrower) eyes
	var brow_up := float(lk["brow"])        # how high the brows sit over the eyes
	var m_hairf := ModelsBase.toon(hair_c.darkened(0.15), false)
	for sx in [-1.0, 1.0]:
		var ex: float = (0.093 if fem else 0.095) * sx
		var kind := face
		if face == 5:
			kind = 3 if sx > 0.0 else 0        # wink: one eye shut
		var open := kind in [0, 1, 4, 6, 7, 8]
		match kind:
			0, 4, 6, 7:   # bright eyes, fierce, starry, determined: white, iris, pupil and a shine
				ModelsBase.part(torso, ModelsBase.sphere(0.05 * es, 12), white, Vector3(ex, y, -0.2), Vector3(0.85, (1.12 if kind in [0, 6] else 0.88) * eh, 0.45))
				ModelsBase.part(torso, ModelsBase.sphere(0.036 * es, 10), iris, Vector3(ex + 0.004 * sx, y - 0.006, -0.219), Vector3(0.9, 1.12 * eh, 0.4))
				ModelsBase.part(torso, ModelsBase.sphere(0.018 * es, 8), m_dark, Vector3(ex + 0.004 * sx, y - 0.008, -0.229), Vector3(1.0, 1.15, 0.4))
				ModelsBase.part(torso, ModelsBase.sphere(0.014 * es, 6), shine, Vector3(ex + 0.016, y + 0.018, -0.237))
				ModelsBase.part(torso, ModelsBase.sphere(0.007 * es, 6), shine, Vector3(ex - 0.012, y - 0.022, -0.236))
				if kind == 6:
					ModelsBase.part(torso, ModelsBase.sphere(0.02 * es, 6), shine, Vector3(ex - 0.01, y + 0.012, -0.233), Vector3(1.0, 1.0, 0.4))
					ModelsBase.part(torso, ModelsBase.sphere(0.008, 6), shine, Vector3(ex - 0.014, y - 0.022, -0.233))
				if kind == 7:
					ModelsBase.part(torso, ModelsBase.box(0.085 * es, 0.022, 0.02), m_skin, Vector3(ex, y + 0.034 * es, -0.228))   # heavy lid
			1:   # calm: soft dark eyes with a shine
				ModelsBase.part(torso, ModelsBase.sphere(0.034 * es, 10), m_dark, Vector3(ex, y, -0.215), Vector3(0.9, 1.1 * eh, 0.5))
				ModelsBase.part(torso, ModelsBase.sphere(0.01, 6), shine, Vector3(ex + 0.012, y + 0.014, -0.232))
			2:   # sleepy: half-closed lids
				ModelsBase.part(torso, ModelsBase.box(0.065 * es, 0.016, 0.02), m_dark, Vector3(ex, y - 0.006, -0.222), Vector3.ONE, Vector3(0, 0, 0.12 * sx))
			8:   # smug: half-lidded, looking sideways
				ModelsBase.part(torso, ModelsBase.sphere(0.04 * es, 10), white, Vector3(ex, y - 0.01, -0.205), Vector3(0.95, 0.6, 0.45))
				ModelsBase.part(torso, ModelsBase.sphere(0.022, 8), m_dark, Vector3(ex + 0.016, y - 0.014, -0.224), Vector3(1.0, 0.8, 0.4))
				ModelsBase.part(torso, ModelsBase.box(0.08 * es, 0.016, 0.02), m_dark, Vector3(ex, y + 0.008, -0.226))
			3:   # cheerful: eyes that smile
				var t := TorusMesh.new(); t.inner_radius = 0.024 * es; t.outer_radius = 0.036 * es; t.rings = 28; t.ring_segments = 10
				ModelsBase.part(torso, t, m_dark, Vector3(ex, y - 0.01, -0.215), Vector3(1.0, 1.0, 0.5), Vector3(PI / 2, 0, 0))
				ModelsBase.part(torso, ModelsBase.box(0.08, 0.032, 0.03), m_skin, Vector3(ex, y - 0.032, -0.22))
		# brows: thin and arched for her, thick and straight for him; angled in when fierce
		var tilt: float = (-0.4 if kind == 4 else (-0.2 if kind == 7 else 0.15)) * sx
		if fem:
			ModelsBase.part(torso, ModelsBase.box(0.066, 0.016, 0.016), m_hairf, Vector3(ex + 0.006 * sx, y + 0.08 * brow_up, -0.208), Vector3.ONE, Vector3(0, 0, tilt + 0.18 * sx))
		else:
			ModelsBase.part(torso, ModelsBase.box(0.088, 0.03, 0.022), m_hairf, Vector3(ex, y + 0.072 * brow_up, -0.208), Vector3.ONE, Vector3(0, 0, tilt * 0.9))
		# lashes on her open eyes: two flicks at the outer corner
		if fem and open:
			ModelsBase.part(torso, ModelsBase.box(0.036, 0.013, 0.012), m_dark, Vector3(ex + 0.056 * sx, y + 0.036, -0.206), Vector3.ONE, Vector3(0, 0, 0.55 * sx))
			ModelsBase.part(torso, ModelsBase.box(0.026, 0.01, 0.012), m_dark, Vector3(ex + 0.058 * sx, y + 0.014, -0.206), Vector3.ONE, Vector3(0, 0, 0.15 * sx))
			ModelsBase.part(torso, ModelsBase.box(0.075 * es, 0.015, 0.012), m_dark, Vector3(ex, y + 0.05 * es, -0.222), Vector3.ONE, Vector3(0, 0, -0.08 * sx))
	# his jaw: wider and squarer at the bottom of the face, with a hint of a chin
	# (the jaw and chin are sculpted into the head itself: HeroKit.head)
	# a small stylized nose: a soft wedge with a lit bridge
	ModelsBase.part(torso, HeroKit.loft("nose|%s" % fem, [Vector3(0, 0.04, 0.0), Vector3(0, 0.0, -0.012), Vector3(0, -0.02, -0.018)], [Vector2(0.01, 0.008), Vector2(0.016 if fem else 0.02, 0.012), Vector2(0.012 if fem else 0.016, 0.01)], 10, Vector3.FORWARD, 0.95), m_skin, Vector3(0, 0.825, -0.226), Vector3.ONE * float(lk["nose"]))
	# mouth: rosy lips for her, a plain line or grin for him
	var mz := -0.236
	var smile := face in [0, 3, 5, 6]
	var lip_m: Material = ModelsBase.toon(skin.lerp(Color("d0405a"), 0.55), false) if fem else m_dark
	if face == 8:
		ModelsBase.part(torso, ModelsBase.box(0.06, 0.015, 0.012), lip_m, Vector3(0.012, 0.778, mz), Vector3.ONE, Vector3(0, 0, 0.3))    # smirk
	elif smile:
		# a smile: a curved stroke (a run of overlapping dots along the bottom of a circle), upturned
		# at the corners, and an open grin on the cheerful faces
		var sr := 0.036 if fem else 0.034
		var cy := 0.796
		for k in 11:
			var a := lerpf(PI * 1.16, PI * 1.84, k / 10.0)
			ModelsBase.part(torso, ModelsBase.sphere(0.0115 if fem else 0.0105, 6), lip_m, Vector3(cos(a) * sr, cy + sin(a) * sr * 0.75, mz + 0.002 + absf(cos(a)) * 0.01), Vector3(1.0, 0.8, 0.5))
		if face in [3, 6]:
			ModelsBase.part(torso, ModelsBase.sphere(0.022, 8), m_dark, Vector3(0, cy - sr * 0.62, mz + 0.004), Vector3(1.2, 0.55, 0.35))
	elif fem:
		ModelsBase.part(torso, ModelsBase.sphere(0.025, 8), lip_m, Vector3(0, 0.776, mz), Vector3(1.35, 0.6, 0.4))
	else:
		ModelsBase.part(torso, ModelsBase.box(0.058, 0.016, 0.012), m_dark, Vector3(0, 0.776, mz))
	if fem or face == 3:
		var blush := ModelsBase.toon(Color("ff9a9a"), false)
		for sx in [-1.0, 1.0]:
			ModelsBase.part(torso, ModelsBase.sphere(0.03, 8), blush, Vector3(0.14 * sx, 0.815, -0.185), Vector3(1.0, 0.6, 0.4))
	# little extras
	match detail:
		1:   # freckles
			var fm := ModelsBase.toon(skin.darkened(0.35), false)
			for sx in [-1.0, 1.0]:
				for k in 3:
					ModelsBase.part(torso, ModelsBase.sphere(0.007, 5), fm, Vector3(sx * (0.1 + k * 0.022), 0.83 + (k % 2) * 0.012, -0.212 + k * 0.006))
		2:   # a scar over one eye
			ModelsBase.part(torso, ModelsBase.box(0.012, 0.11, 0.012), ModelsBase.toon(skin.lerp(Color("c86a6a"), 0.6), false), Vector3(0.1, 0.87, -0.228), Vector3.ONE, Vector3(0, 0, 0.25))
		3:   # face paint in the team colour
			var pm := ModelsBase.toon(paint, false, 0.2)
			for sx in [-1.0, 1.0]:
				for k in 2:
					ModelsBase.part(torso, ModelsBase.box(0.055, 0.012, 0.012), pm, Vector3(sx * 0.12, 0.812 - k * 0.022, -0.2), Vector3.ONE, Vector3(0, 0.4 * sx, 0))
		4:   # stubble
			ModelsBase.part(torso, ModelsBase.sphere(0.205, 14), ModelsBase.toon(skin.lerp(hair_c, 0.45).darkened(0.12), false), Vector3(0, 0.76, -0.025), Vector3(1.18 if not fem else 1.0, 0.6, 1.03))
		5:   # a full beard
			var bm := ModelsBase.toon(hair_c)
			ModelsBase.part(torso, ModelsBase.sphere(0.21, 14), bm, Vector3(0, 0.75, -0.02), Vector3(1.2, 0.72, 1.05))
			ModelsBase.part(torso, ModelsBase.sphere(0.08, 10), bm, Vector3(0, 0.69, -0.17), Vector3(1.3, 1.1, 0.9))
			ModelsBase.part(torso, ModelsBase.box(0.06, 0.012, 0.012), m_dark, Vector3(0, 0.79, -0.25))
		6:   # moustache
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.capsule(0.018, 0.08), ModelsBase.toon(hair_c), Vector3(0.03 * sx, 0.808, -0.236), Vector3.ONE, Vector3(0, 0, PI / 2 + 0.35 * sx))
		7:   # beauty mark
			ModelsBase.part(torso, ModelsBase.sphere(0.008, 5), m_dark, Vector3(0.055, 0.8, -0.23))

## Hair that peeks out under whatever the hero wears on their head: a cap of hair, chunky fringe
## locks over the forehead, then the style.
static func _hair(torso: Node3D, style: int, gender: int, m_hair: Material, covered := false) -> void:
	if style == 13:
		return   # bald
	if covered:
		# under a hood or helmet only what hangs below it shows
		if style not in [5, 9]:
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.06, 0.2, 8), m_hair, Vector3(0.2 * sx, 0.84, -0.06), Vector3(1.0, 1.0, 0.8), Vector3(PI, 0, 0.15 * sx))
		match style:
			1: ModelsBase.part(torso, ModelsBase.capsule(0.17, 0.52), m_hair, Vector3(0, 0.7, 0.1), Vector3(1.35, 1.0, 0.7))
			7: _pigtails(torso, m_hair)
			8: _braid(torso, m_hair)
		return
	if style == 5 or style == 9:
		ModelsBase.part(torso, ModelsBase.sphere(0.242), m_hair, Vector3(0, 0.885, 0.02), Vector3(1.0, 0.82, 1.0))
		if style == 9:
			# mohawk: a crest of spikes front to back
			for i in 6:
				var z := -0.16 + i * 0.07
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.05, 0.2 - absf(i - 2.5) * 0.02, 6), m_hair, Vector3(0, 1.08 - absf(i - 2.0) * 0.012, z), Vector3(0.6, 1.0, 1.2), Vector3(-0.3 + i * 0.12, 0, 0))
		return
	if style == 10:
		# afro: a big round cloud of hair
		ModelsBase.part(torso, ModelsBase.sphere(0.31, 16), m_hair, Vector3(0, 0.98, 0.08), Vector3(1.1, 0.95, 1.0))
		for k in 5:
			var x := -0.13 + k * 0.065
			ModelsBase.part(torso, ModelsBase.sphere(0.07, 10), m_hair, Vector3(x, 1.0 - absf(k - 2) * 0.012, -0.165), Vector3(1.0, 0.9, 0.7))
		return
	ModelsBase.part(torso, ModelsBase.sphere(0.25), m_hair, Vector3(0, 0.91, 0.035), Vector3(1.05, 0.86, 1.02))
	# fringe: soft locks sweeping across the forehead
	for k in 4:
		var x := -0.12 + k * 0.08
		ModelsBase.part(torso, ModelsBase.sphere(0.075, 10), m_hair, Vector3(x, 0.99 - absf(k - 1.5) * 0.015, -0.17), Vector3(0.9, 1.0, 0.7), Vector3(0.4, 0, -0.3 + k * 0.2))
	for sx in [-1.0, 1.0]:
		ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.06, 0.2, 8), m_hair, Vector3(0.2 * sx, 0.84, -0.06), Vector3(1.0, 1.0, 0.8), Vector3(PI, 0, 0.15 * sx))   # sideburn locks
	match style:
		1:   # long
			ModelsBase.part(torso, ModelsBase.capsule(0.17, 0.52), m_hair, Vector3(0, 0.7, 0.1), Vector3(1.35, 1.0, 0.7))
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.07, 0.26, 8), m_hair, Vector3(0.16 * sx, 0.5, 0.14), Vector3.ONE, Vector3(PI, 0, 0.1 * sx))
		2:   # ponytail with a tie
			ModelsBase.part(torso, ModelsBase.sphere(0.05, 8), ModelsBase.toon(Color("e0607e")), Vector3(0, 0.95, 0.24))
			ModelsBase.part(torso, ModelsBase.capsule(0.075, 0.38), m_hair, Vector3(0, 0.82, 0.3), Vector3.ONE, Vector3(0.55, 0, 0))
			ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.07, 0.16, 8), m_hair, Vector3(0, 0.62, 0.38), Vector3.ONE, Vector3(PI - 0.4, 0, 0))
		3:   # bun
			ModelsBase.part(torso, ModelsBase.sphere(0.11), m_hair, Vector3(0, 1.08, 0.16))
			ModelsBase.part(torso, ModelsBase.cyl(0.06, 0.06, 0.03, 10), ModelsBase.toon(Color("f2c84a")), Vector3(0, 1.04, 0.13), Vector3.ONE, Vector3(-0.6, 0, 0))
		4:   # spiky
			for i in 7:
				var a := -1.2 + i * 0.4
				ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.065, 0.22, 8), m_hair, Vector3(sin(a) * 0.14, 1.08, 0.05 + cos(a) * 0.06), Vector3.ONE, Vector3(-0.35, 0, -a * 0.75))
		6:   # bob: straight sides down to the jaw
			for sx in [-1.0, 1.0]:
				ModelsBase.part(torso, ModelsBase.sphere(0.13, 12), m_hair, Vector3(0.17 * sx, 0.82, 0.04), Vector3(0.6, 1.35, 1.2))
			ModelsBase.part(torso, ModelsBase.sphere(0.2, 12), m_hair, Vector3(0, 0.82, 0.12), Vector3(1.2, 1.1, 0.7))
		7:   # pigtails
			_pigtails(torso, m_hair)
		8:   # a long braid down the back
			_braid(torso, m_hair)
		11:  # curly: little curls all over
			for k in 14:
				var a := TAU * k / 14.0
				var yy := 0.95 + (k % 3) * 0.05
				ModelsBase.part(torso, ModelsBase.sphere(0.075, 8), m_hair, Vector3(cos(a) * 0.21, yy, sin(a) * 0.19 + 0.04))
			ModelsBase.part(torso, ModelsBase.sphere(0.09, 8), m_hair, Vector3(0, 1.12, 0.03))
		12:  # swoop: a big side-swept fringe
			ModelsBase.part(torso, ModelsBase.sphere(0.16, 12), m_hair, Vector3(0.06, 1.02, -0.13), Vector3(1.4, 0.7, 0.8), Vector3(0.3, 0, -0.35))
			ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.06, 0.22, 8), m_hair, Vector3(0.2, 0.92, -0.13), Vector3.ONE, Vector3(0.2, 0, -2.2))
		_:   # short: a tuft on the crown
			ModelsBase.part(torso, ModelsBase.cyl(0.0, 0.05, 0.12, 8), m_hair, Vector3(0.03, 1.12, 0.02), Vector3.ONE, Vector3(-0.3, 0, -0.5))

static func _pigtails(torso: Node3D, m_hair: Material) -> void:
	for sx in [-1.0, 1.0]:
		ModelsBase.part(torso, ModelsBase.sphere(0.04, 8), ModelsBase.toon(Color("e0607e")), Vector3(0.22 * sx, 0.93, 0.12))
		ModelsBase.part(torso, ModelsBase.capsule(0.07, 0.34), m_hair, Vector3(0.27 * sx, 0.78, 0.15), Vector3.ONE, Vector3(0.25, 0, 0.3 * sx))

static func _braid(torso: Node3D, m_hair: Material) -> void:
	for k in 5:
		ModelsBase.part(torso, ModelsBase.sphere(0.065 - k * 0.006, 8), m_hair, Vector3(0, 0.86 - k * 0.09, 0.27 + k * 0.01))
	ModelsBase.part(torso, ModelsBase.sphere(0.03, 6), ModelsBase.toon(Color("e0607e")), Vector3(0, 0.44, 0.3))

static func prism_tip() -> PrismMesh:
	var pm := PrismMesh.new(); pm.size = Vector3(1, 1, 1)
	return pm
