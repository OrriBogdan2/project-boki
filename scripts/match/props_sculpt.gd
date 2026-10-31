class_name PropSculpt
## Sculpted, hand-painted loot props (all original): chests in three rarities and the breakables
## (crates, powder kegs, clay pots). Rounded planks with dark seams, iron or gold bands with rivets,
## and on the rarer chests a trim that glows and light leaking from under the lid. Painted like the
## characters (part gradients, creases, rim light) and merged to a few draw calls each.
## Same named nodes as the primitive versions: chest > Body > Lid (hinged, opens on rotation.x),
## Beacon; keg > Fuse. meta "mats" = [wood, metal, ...] (the deathbox repaints the first two).

const WOOD := [Color("8a5a35"), Color("3f6fb0"), Color("6a3fa8")]
const TRIM := [Color("5a5258"), Color("dfe8f2"), Color("f2c84a")]
const SEAM := [Color(0, 0, 0, 0), Color("8fd8ff"), Color("ffb84a")]

static func _mat(c: Color, surf := 2, gloss := 0.0, glow := 0.0) -> ShaderMaterial:
	var m := Models.toon(c, true, glow)
	Models.painted(m, surf, 0.3, 0.3, 0.26)
	m.set_shader_parameter("rim_amount", 0.45)
	if gloss > 0.0:
		m.set_shader_parameter("gloss", gloss)
	return m

static var _boxes := {}
## A box with softly chamfered edges: one bevel step, so it costs ~70 triangles instead of the
## character meshes' ~1000 (props come in dozens).
static func bx(x: float, y: float, z: float) -> Mesh:
	var mn := minf(x, minf(y, z))
	var r := minf(mn * 0.2, 0.035)
	if r < 0.003:
		var b := BoxMesh.new(); b.size = Vector3(x, y, z)
		return b
	var key := "%.4f|%.4f|%.4f" % [x, y, z]
	if not _boxes.has(key):
		_boxes[key] = Models.rounded_box(Vector3(x, y, z), r, 1)
	return _boxes[key]

static func _finish(root: Node3D) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n is MeshInstance3D):
			Models.merge_static(n)
		for ch in n.get_children():
			stack.append(ch)
	Models.bake_part_y(root)

# ------------------------------------------------------------------ chests
static func chest(tier := 0) -> Node3D:
	tier = clampi(tier, 0, 2)
	var root := Node3D.new()
	var mw := _mat(WOOD[tier], 2)
	var mwd := _mat(Color(WOOD[tier]).darkened(0.42), 2)
	var mg := _mat(TRIM[tier], 3, 0.55 if tier > 0 else 0.25, 0.12 * tier)
	var mgd := _mat(Color(TRIM[tier]).darkened(0.35), 3, 0.3)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var W := 0.8; var H := 0.42; var D := 0.55
	# the box: a dark inner core and three rounded planks a side, a little uneven, so the seams read
	Models.part(body, bx(W - 0.04, H - 0.02, D - 0.04), mwd, Vector3(0, H * 0.5, 0))
	for k in 3:
		var ph := H / 3.0
		var y := ph * (k + 0.5)
		var jz: float = [0.0, 0.008, -0.004][k]
		Models.part(body, bx(W - 0.02, ph - 0.022, D + jz), mw, Vector3(0, y, 0))
	# iron straps round the box, corner brackets and a base rail
	for x in [-0.25, 0.25]:
		Models.part(body, bx(0.075, H + 0.01, D + 0.035), mg, Vector3(x, H * 0.5, 0))
		for z in [-1.0, 1.0]:
			for y in [0.1, 0.32]:
				Models.part(body, Models.sphere(0.018, 6), mgd, Vector3(x, y, z * (D * 0.5 + 0.02)))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Models.part(body, bx(0.09, H + 0.02, 0.09), mg, Vector3(x * (W * 0.5 - 0.025), H * 0.5, z * (D * 0.5 - 0.025)))
	Models.part(body, bx(W + 0.05, 0.05, D + 0.05), mgd, Vector3(0, 0.025, 0))
	# the lid hinges at the back (+z here; Body turns round so the lock faces the camera)
	var lid := Node3D.new(); lid.name = "Lid"; lid.position = Vector3(0, H, D * 0.5); body.add_child(lid)
	lid.set_meta("hinged", true)
	var lc := Vector3(0, 0.0, -D * 0.5)
	# a rounded lid of planks: a half barrel lying on its side
	Models.part(lid, Models.cyl(D * 0.5, D * 0.5, W - 0.02, 20), mw, lc, Vector3(1.0, 1.0, 0.62), Vector3(0, 0, PI / 2))
	for k in 4:
		# plank seams across the curve
		var a := PI * (0.2 + 0.2 * k)
		Models.part(lid, bx(W - 0.01, 0.012, 0.012), mwd, lc + Vector3(0, sin(a) * D * 0.5 * 0.62, cos(a) * D * 0.5), Vector3.ONE, Vector3(-(a - PI / 2) , 0, 0))
	for x in [-0.25, 0.25]:
		Models.part(lid, Models.cyl(D * 0.5 + 0.018, D * 0.5 + 0.018, 0.075, 20), mg, lc + Vector3(x, 0, 0), Vector3(1.0, 1.0, 0.64), Vector3(0, 0, PI / 2))
	for x in [-1.0, 1.0]:
		Models.part(lid, Models.cyl(D * 0.5 + 0.012, D * 0.5 + 0.012, 0.04, 20), mg, lc + Vector3(x * (W * 0.5 - 0.01), 0, 0), Vector3(1.0, 1.0, 0.64), Vector3(0, 0, PI / 2))
	# the lock: a plate with a keyhole, and a hasp coming down from the lid
	Models.part(lid, bx(0.15, 0.13, 0.04), mg, lc + Vector3(0, 0.0, -D * 0.5 - 0.005))
	Models.part(body, bx(0.17, 0.17, 0.045), mg, Vector3(0, H - 0.08, -D * 0.5 - 0.012))
	Models.part(body, Models.sphere(0.028, 8), _mat(Color("1e1a22"), 0), Vector3(0, H - 0.075, -D * 0.5 - 0.036), Vector3(1.0, 1.0, 0.5))
	Models.part(body, bx(0.016, 0.05, 0.02), _mat(Color("1e1a22"), 0), Vector3(0, H - 0.11, -D * 0.5 - 0.034))
	var mats: Array = [mw, mg, mwd, mgd]
	if tier >= 1:
		# light leaking out round the lid, and a gem on the lock (rarer chests)
		var seam := Models.glow_mat(Color(SEAM[tier], 0.95))
		Models.part(body, bx(W - 0.06, 0.03, D - 0.06), seam, Vector3(0, H + 0.0, 0))
		var gem := Models.toon(Color(SEAM[tier]).lightened(0.2), false, 1.1)
		gem.set_shader_parameter("gloss", 0.8)
		Models.part(lid, Models.crystal(0.05, 0.1, 6), gem, lc + Vector3(0, 0.0, -D * 0.5 - 0.04), Vector3(1, 1, 0.7), Vector3(PI / 2, 0, 0))
		mats.append(gem)
		if tier == 2:
			# gold filigree knobs on the lid and gem studs on the corners
			for x in [-1.0, 1.0]:
				Models.part(lid, Models.sphere(0.045, 8), mg, lc + Vector3(x * 0.25, D * 0.5 * 0.62 + 0.02, 0))
				for z in [-1.0, 1.0]:
					Models.part(body, Models.crystal(0.03, 0.06, 5), gem, Vector3(x * (W * 0.5 - 0.025), H - 0.04, z * (D * 0.5 + 0.02)), Vector3.ONE, Vector3(PI / 2 * z, 0, 0))
	body.scale = Vector3.ONE * (1.0 + tier * 0.18)
	body.rotation.y = PI   # lock facing the camera
	if tier >= 1:
		# a light pillar you can see from other islands
		var cc: Array = Models.CHEST_COLS[tier]
		var beam := Models.part(root, Models.cyl(0.16, 0.3, 9.0, 10), Models.glow_mat(Color(cc[1] if tier == 1 else Color("c9a0ff"), 0.22)), Vector3(0, 4.5, 0), Vector3.ONE, Vector3.ZERO, "Beacon")
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_finish(root)
	root.set_meta("mats", mats)
	return root

# ------------------------------------------------------------------ breakables
static func breakable(kind_s: String) -> Node3D:
	var root := Node3D.new()
	var mats: Array = []
	match kind_s:
		"crate":
			var wood := _mat(Color("b07e4c"), 2); var dark := _mat(Color("6a4630"), 2); var iron := _mat(Color("4a4650"), 3, 0.3)
			mats = [wood, dark, iron]
			var s := 0.66
			Models.part(root, bx(s - 0.06, s - 0.06, s - 0.06), dark, Vector3(0, s * 0.5, 0))
			# side panels of three planks each, then a frame of edge boards
			for f in 4:
				var a := PI * 0.5 * f
				var n := Vector3(sin(a), 0, cos(a)); var t := Vector3(cos(a), 0, -sin(a))
				for k in 3:
					var y := 0.08 + (s - 0.16) * (k + 0.5) / 3.0
					var pl := Models.part(root, bx(s - 0.14, (s - 0.16) / 3.0 - 0.018, 0.04), wood, n * (s * 0.5 - 0.035) + Vector3(0, y, 0) + t * 0.0)
					pl.rotation.y = a
				# a diagonal brace
				var br := Models.part(root, bx(s * 1.05, 0.07, 0.04), wood, n * (s * 0.5 - 0.005) + Vector3(0, s * 0.5, 0))
				br.rotation = Vector3(0, a, 0.78 * (1.0 if f % 2 == 0 else -1.0))
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					Models.part(root, bx(0.08, s, 0.08), dark, Vector3(x * (s * 0.5 - 0.04), s * 0.5, z * (s * 0.5 - 0.04)))
					Models.part(root, bx(0.1, 0.1, 0.1), iron, Vector3(x * (s * 0.5 - 0.035), s - 0.05, z * (s * 0.5 - 0.035)))
					Models.part(root, bx(0.1, 0.1, 0.1), iron, Vector3(x * (s * 0.5 - 0.035), 0.05, z * (s * 0.5 - 0.035)))
			for y in [0.04, s - 0.04]:
				for f in 4:
					var a := PI * 0.5 * f
					var e := Models.part(root, bx(s - 0.08, 0.08, 0.08), dark, Vector3(sin(a), 0, cos(a)) * (s * 0.5 - 0.04) + Vector3(0, y, 0))
					e.rotation.y = a
			# the lid's planks
			for k in 3:
				Models.part(root, bx(s - 0.12, 0.04, (s - 0.12) / 3.0 - 0.02), wood, Vector3(0, s - 0.03, (k - 1) * (s - 0.12) / 3.0))
		"pot":
			var clay := _mat(Color("c9825a"), 4); var band := _mat(Color("f0c890"), 4); var dk := _mat(Color("6a3a2a"), 0)
			mats = [clay, band, dk]
			var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.16, 0.0), Vector2(0.24, 0.06), Vector2(0.31, 0.22), Vector2(0.3, 0.38),
				Vector2(0.22, 0.52), Vector2(0.13, 0.6), Vector2(0.12, 0.66), Vector2(0.17, 0.71), Vector2(0.16, 0.74), Vector2(0.1, 0.72), Vector2(0.08, 0.66)])
			Models.part(root, Models.lathe(Models.smooth_curve(prof, 3), 22, "pot_body"), clay, Vector3.ZERO)
			Models.part(root, Models.cyl(0.315, 0.315, 0.06, 18), band, Vector3(0, 0.3, 0))
			Models.part(root, Models.sphere(0.09, 8), dk, Vector3(0, 0.69, 0), Vector3(1.0, 0.25, 1.0))
			for i in 6:
				var a := TAU * i / 6.0
				Models.part(root, Models.sphere(0.035, 6), dk, Vector3(cos(a) * 0.305, 0.3, sin(a) * 0.305), Vector3(1, 1, 1))
			for sx in [-1.0, 1.0]:
				# little loop handles
				Models.part(root, Models.cyl(0.04, 0.04, 0.02, 10), clay, Vector3(sx * 0.2, 0.55, 0), Vector3(1.0, 1.0, 1.0), Vector3(0, 0, PI / 2))
		"barrel", "cask":
			var cask := kind_s == "cask"
			var red := _mat(Color("9a6a42") if cask else Color("c8483a"), 2, 0.0, 0.0 if cask else 0.1)
			var dkred := _mat(Color("5a3a26") if cask else Color("7a2a26"), 2)
			var iron := _mat(Color("3a3440"), 3, 0.35); var hz := _mat(Color("f2c84a"), 1)
			mats = [red, iron, dkred, hz]
			var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.26, 0), Vector2(0.3, 0.12), Vector2(0.32, 0.38), Vector2(0.3, 0.64), Vector2(0.26, 0.76), Vector2(0.2, 0.76), Vector2(0, 0.74)])
			Models.part(root, Models.lathe(Models.smooth_curve(prof, 3), 24, "keg_body"), red, Vector3.ZERO)
			# stave seams
			for i in 10:
				var a := TAU * i / 10.0
				var sv := Models.part(root, bx(0.012, 0.6, 0.012), dkred, Vector3(cos(a) * 0.312, 0.38, sin(a) * 0.312))
				sv.rotation.y = -a
			for y in [0.13, 0.63]:
				Models.part(root, Models.cyl(0.318, 0.318, 0.06, 20), iron, Vector3(0, y, 0))
			if cask:
				Models.part(root, Models.cyl(0.24, 0.24, 0.03, 18), dkred, Vector3(0, 0.765, 0))
				_finish(root)
				root.set_meta("mats", mats)
				return root
			# a hazard band and a fuse stub on top
			Models.part(root, Models.cyl(0.325, 0.325, 0.08, 20), hz, Vector3(0, 0.38, 0))
			Models.part(root, Models.cyl(0.06, 0.07, 0.06, 10), iron, Vector3(0.1, 0.78, 0))
			var fuse_m := Models.toon(Color("ffd25a"), false, 0.9)
			Models.part(root, Models.sphere(0.08, 8), fuse_m, Vector3(0.1, 0.86, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
			mats.append(fuse_m)
	_finish(root)
	root.set_meta("mats", mats)
	return root

## A camp's supplies (a blocker tile): crates stacked a little askew, a cask and a sack.
static func camp(r: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var a := breakable("crate")
	a.scale = Vector3.ONE * 1.25; a.rotation.y = r.randf_range(-0.3, 0.3)
	a.position = Vector3(-0.1, 0, 0.05)
	root.add_child(a)
	var b := breakable("crate")
	b.scale = Vector3.ONE * 0.9; b.rotation.y = r.randf_range(0.3, 0.9)
	b.position = Vector3(-0.05, 0.82, 0.0)
	root.add_child(b)
	var c := breakable("cask")
	c.position = Vector3(0.42, 0, -0.32); c.rotation.y = r.randf() * TAU
	root.add_child(c)
	var sack := _mat(Color("c8b08a"), 1)
	var tie := _mat(Color("6a4a30"), 2)
	var sk := Node3D.new(); sk.position = Vector3(-0.45, 0, -0.4); root.add_child(sk)
	Models.part(sk, Models.sphere(0.24, 12), sack, Vector3(0, 0.2, 0), Vector3(1.0, 0.9, 0.9))
	Models.part(sk, Models.sphere(0.13, 10), sack, Vector3(0, 0.42, 0), Vector3(0.8, 0.7, 0.8))
	Models.part(sk, Models.cyl(0.06, 0.07, 0.04, 10), tie, Vector3(0, 0.37, 0))
	_finish(sk)
	return root
