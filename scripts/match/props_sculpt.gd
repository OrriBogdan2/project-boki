class_name PropSculpt
## Sculpted, hand-painted loot props (all original): chests in three rarities and the breakables
## (crates, powder kegs, clay pots). Rounded planks with dark seams, iron or gold bands with rivets,
## and on the rarer chests a trim that glows and light leaking from under the lid. Painted like the
## characters (part gradients, creases, rim light) and merged to a few draw calls each.
## Same named nodes as the primitive versions: chest > Body > Lid (hinged, opens on rotation.x),
## Beacon; keg > Fuse. meta "mats" = [wood, metal, ...] (the deathbox repaints the first two).

const WOOD := [Color("9a6236"), Color("3f6fb0"), Color("6a3fa8")]
const TRIM := [Color("d8a84a"), Color("dfe8f2"), Color("f2c84a")]
const SEAM := [Color("ffd890"), Color("8fd8ff"), Color("ffb84a")]
## Loot reads as loot: every chest wears gold-ish trim and stands in a pool of its rarity colour
## (common gold, rare blue, epic purple) with a light pillar; breakables never glow.
const RARITY_COL := [Color("ffd36a"), Color("6ab8ff"), Color("c08aff")]

static func _mat(c: Color, surf := 2, gloss := 0.0, glow := 0.0) -> ShaderMaterial:
	var m := Models.toon(c, true, glow)
	Models.painted(m, surf, 0.3, 0.3, 0.26)
	m.set_shader_parameter("rim_amount", 0.45)
	if gloss > 0.0:
		m.set_shader_parameter("gloss", gloss)
	return m

## Breakables' paint: flat, dusty and matte (low rim light, no gloss), so they sit back next to loot.
static func _matte(c: Color, surf := 2) -> ShaderMaterial:
	var m := Models.toon(c, true, 0.0)
	Models.painted(m, surf, 0.36, 0.4, 0.3)
	m.set_shader_parameter("rim_amount", 0.12)
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
## A treasure chest: wide and chunky with a tall domed lid, thick gold-toned bands, big corner
## brackets and a jewelled lock plate, light leaking from under the lid, and (in "Beacon", hidden
## once it's opened) a light pillar and a glowing ring on the ground in its rarity colour.
static func chest(tier := 0) -> Node3D:
	tier = clampi(tier, 0, 2)
	var root := Node3D.new()
	var mw := _mat(WOOD[tier], 2)
	var mwd := _mat(Color(WOOD[tier]).darkened(0.45), 2)
	var mg := _mat(TRIM[tier], 3, 0.6, 0.06 + 0.1 * tier)
	var mgd := _mat(Color(TRIM[tier]).darkened(0.3), 3, 0.4)
	mg.set_shader_parameter("rim_amount", 0.8)
	var body := Node3D.new(); body.name = "Body"; root.add_child(body)
	var W := 1.0; var H := 0.46; var D := 0.68
	# the box: a dark inner core and three rounded planks a side, a little uneven, so the seams read
	Models.part(body, bx(W - 0.04, H - 0.02, D - 0.04), mwd, Vector3(0, H * 0.5, 0))
	for k in 3:
		var ph := (H - 0.06) / 3.0
		var y := 0.06 + ph * (k + 0.5)
		var jz: float = [0.0, 0.01, -0.006][k]
		Models.part(body, bx(W - 0.03, ph - 0.024, D + jz), mw, Vector3(0, y, 0))
	# a thick plinth rail, a rim band round the top, two straps and chunky corner brackets
	Models.part(body, bx(W + 0.08, 0.09, D + 0.08), mgd, Vector3(0, 0.045, 0))
	Models.part(body, bx(W + 0.05, 0.065, D + 0.05), mg, Vector3(0, H - 0.03, 0))
	for x in [-0.3, 0.3]:
		Models.part(body, bx(0.1, H + 0.01, D + 0.045), mg, Vector3(x, H * 0.5, 0))
		for z in [-1.0, 1.0]:
			for y in [0.16, 0.32]:
				Models.part(body, Models.sphere(0.022, 6), mgd, Vector3(x, y, z * (D * 0.5 + 0.03)))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Models.part(body, bx(0.14, H + 0.04, 0.14), mg, Vector3(x * (W * 0.5 - 0.03), H * 0.5 + 0.01, z * (D * 0.5 - 0.03)))
			Models.part(body, Models.sphere(0.03, 6), mgd, Vector3(x * (W * 0.5 + 0.04), H * 0.62, z * (D * 0.5 - 0.03)))
	# the lid hinges at the back (+z here; Body turns round so the lock faces the camera)
	var lid := Node3D.new(); lid.name = "Lid"; lid.position = Vector3(0, H, D * 0.5); body.add_child(lid)
	lid.set_meta("hinged", true)
	var lc := Vector3(0, 0.0, -D * 0.5)
	var dome := 0.86     # a tall rounded lid: half a barrel, squashed a little less than a plank lid
	Models.part(lid, Models.cyl(D * 0.5, D * 0.5, W - 0.03, 22), mw, lc, Vector3(1.0, 1.0, dome), Vector3(0, 0, PI / 2))
	for k in 4:
		# plank seams across the curve
		var a := PI * (0.2 + 0.2 * k)
		Models.part(lid, bx(W - 0.02, 0.014, 0.014), mwd, lc + Vector3(0, sin(a) * D * 0.5 * dome, cos(a) * D * 0.5), Vector3.ONE, Vector3(-(a - PI / 2), 0, 0))
	for x in [-0.3, 0.3]:
		Models.part(lid, Models.cyl(D * 0.5 + 0.022, D * 0.5 + 0.022, 0.1, 22), mg, lc + Vector3(x, 0, 0), Vector3(1.0, 1.0, dome + 0.02), Vector3(0, 0, PI / 2))
	for x in [-1.0, 1.0]:
		Models.part(lid, Models.cyl(D * 0.5 + 0.018, D * 0.5 + 0.018, 0.06, 22), mg, lc + Vector3(x * (W * 0.5 - 0.02), 0, 0), Vector3(1.0, 1.0, dome + 0.02), Vector3(0, 0, PI / 2))
	# a front lip on the lid and the lock: a big plate with a jewel and a hasp coming down
	Models.part(lid, bx(W + 0.02, 0.05, 0.05), mg, lc + Vector3(0, 0.02, -D * 0.5 - 0.005))
	Models.part(lid, bx(0.2, 0.16, 0.05), mg, lc + Vector3(0, 0.0, -D * 0.5 - 0.02))
	Models.part(body, bx(0.26, 0.24, 0.05), mg, Vector3(0, H - 0.13, -D * 0.5 - 0.016))
	Models.part(body, bx(0.18, 0.16, 0.03), mgd, Vector3(0, H - 0.13, -D * 0.5 - 0.04))
	var gem := Models.toon(Color(SEAM[tier]).lightened(0.15) if tier > 0 else Color("e8503a"), false, 0.8 + 0.3 * tier)
	gem.set_shader_parameter("gloss", 0.85)
	Models.part(body, Models.crystal(0.06, 0.12, 6), gem, Vector3(0, H - 0.12, -D * 0.5 - 0.06), Vector3(1, 1, 0.6), Vector3(PI / 2, 0, 0))
	var mats: Array = [mw, mg, mwd, mgd, gem]
	# light leaking out round the lid (a warm crack on a common chest, brighter on rare ones)
	var seam := Models.glow_mat(Color(SEAM[tier], 0.55 + 0.2 * tier))
	Models.part(body, bx(W - 0.08, 0.035, D - 0.08), seam, Vector3(0, H + 0.004, 0))
	if tier >= 1:
		# gem studs on the corners and finials on the lid
		for x in [-1.0, 1.0]:
			Models.part(lid, Models.sphere(0.055, 8), mg, lc + Vector3(x * 0.3, D * 0.5 * dome + 0.03, 0))
			for z in [-1.0, 1.0]:
				Models.part(body, Models.crystal(0.035, 0.07, 5), gem, Vector3(x * (W * 0.5 - 0.03), H + 0.03, z * (D * 0.5 - 0.03)))
		if tier == 2:
			# a crest on the lid: a gold ridge with a big jewel
			Models.part(lid, bx(0.08, 0.06, D * 0.8), mg, lc + Vector3(0, D * 0.5 * dome + 0.01, 0))
			Models.part(lid, Models.crystal(0.08, 0.18, 6), gem, lc + Vector3(0, D * 0.5 * dome + 0.08, -0.05))
	body.scale = Vector3.ONE * (1.0 + tier * 0.1)
	body.rotation.y = PI   # lock facing the camera
	# the rarity marks: a light pillar you can see from other islands and a glowing pool round it
	var rc: Color = RARITY_COL[tier]
	var bcn := Node3D.new(); bcn.name = "Beacon"; root.add_child(bcn)
	var bh: float = [3.2, 9.0, 11.0][tier]
	var beam := Models.part(bcn, Models.cyl(0.14 + 0.03 * tier, 0.3 + 0.05 * tier, bh, 10), Models.glow_mat(Color(rc, [0.13, 0.22, 0.28][tier])), Vector3(0, bh * 0.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := MeshInstance3D.new(); ring.name = "Ring"; ring.mesh = Models.flat_quad(2.0 + 0.3 * tier)
	var rm := Models.ring_mat(Color(rc, 0.9), 0.1)
	rm.set_shader_parameter("fill", 0.16 + 0.05 * tier)
	ring.material_override = rm; ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bcn.add_child(ring)
	_finish(root)
	root.set_meta("mats", mats)
	return root

# ------------------------------------------------------------------ breakables
## A crack across a face: a zigzag of thin dark slivers from `at` along the face's tangent t.
static func _crack(root: Node3D, m: Material, at: Vector3, n: Vector3, t: Vector3, ln: float, rr: RandomNumberGenerator) -> void:
	var p := at
	var dir := t.normalized()
	var up := n.cross(dir).normalized()
	var seg := 3
	for k in seg:
		var d2 := (dir + up * rr.randf_range(-0.9, 0.9)).normalized()
		var l := ln / seg
		var mid := p + d2 * l * 0.5
		var b := Models.part(root, bx(l + 0.01, 0.014, 0.01), m, mid + n * 0.004)
		b.basis = Basis(d2, n.cross(d2).normalized(), n).orthonormalized()
		p += d2 * l

## Things you smash: smaller, dusty and matte, with cracks and splinters, never glowing (the powder
## keg keeps its hazard band and a tiny ember on the fuse, as a warning, not as loot).
static func breakable(kind_s: String) -> Node3D:
	var root := Node3D.new()
	var mats: Array = []
	var rr := RandomNumberGenerator.new(); rr.seed = hash(kind_s) + 11
	match kind_s:
		"crate":
			var wood := _matte(Color("a8916f"), 2); var dark := _matte(Color("66563f"), 2); var iron := _matte(Color("56535a"), 3)
			var crk := Models.toon(Color("2a221c"), false)
			mats = [wood, dark, iron]
			var s := 0.58
			Models.part(root, bx(s - 0.06, s - 0.06, s - 0.06), dark, Vector3(0, s * 0.5, 0))
			# side panels of three planks each, then a frame of edge boards
			for f in 4:
				var a := PI * 0.5 * f
				var n := Vector3(sin(a), 0, cos(a)); var t := Vector3(cos(a), 0, -sin(a))
				for k in 3:
					if f == 0 and k == 2:
						continue    # one plank knocked out: the dark inside and splinters show
					var y := 0.08 + (s - 0.16) * (k + 0.5) / 3.0
					var pl := Models.part(root, bx(s - 0.14, (s - 0.16) / 3.0 - 0.02, 0.04), wood, n * (s * 0.5 - 0.035) + Vector3(0, y, 0))
					pl.rotation.y = a
				# a diagonal brace
				var br := Models.part(root, bx(s * 1.05, 0.06, 0.04), dark, n * (s * 0.5 - 0.005) + Vector3(0, s * 0.5, 0))
				br.rotation = Vector3(0, a, 0.78 * (1.0 if f % 2 == 0 else -1.0))
				if f != 0:
					_crack(root, crk, n * (s * 0.5 + 0.012) + Vector3(0, s * rr.randf_range(0.3, 0.5), 0) - t * 0.12, n, t, 0.24, rr)
			# splinters where the plank broke off
			var fn := Vector3(0, 0, 1)
			for k in 4:
				var x := -0.17 + k * 0.11
				var sp := Models.part(root, bx(0.035, rr.randf_range(0.06, 0.11), 0.03), wood, fn * (s * 0.5 - 0.03) + Vector3(x, s - 0.16 + rr.randf_range(0.0, 0.03), 0))
				sp.rotation.z = rr.randf_range(-0.5, 0.5)
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					Models.part(root, bx(0.075, s, 0.075), dark, Vector3(x * (s * 0.5 - 0.04), s * 0.5, z * (s * 0.5 - 0.04)))
					Models.part(root, bx(0.09, 0.09, 0.09), iron, Vector3(x * (s * 0.5 - 0.035), 0.045, z * (s * 0.5 - 0.035)))
			for y in [0.04, s - 0.04]:
				for f in 4:
					var a := PI * 0.5 * f
					var e := Models.part(root, bx(s - 0.08, 0.07, 0.07), dark, Vector3(sin(a), 0, cos(a)) * (s * 0.5 - 0.04) + Vector3(0, y, 0))
					e.rotation.y = a
			# the lid's planks, one split
			for k in 3:
				var lp := Models.part(root, bx(s - 0.12 - (0.12 if k == 0 else 0.0), 0.04, (s - 0.12) / 3.0 - 0.025), wood, Vector3(-0.06 if k == 0 else 0.0, s - 0.03, (k - 1) * (s - 0.12) / 3.0))
				lp.rotation.y = rr.randf_range(-0.04, 0.04)
			_crack(root, crk, Vector3(-0.15, s + 0.0, 0.05), Vector3.UP, Vector3(1, 0, 0.3), 0.26, rr)
		"pot":
			var clay := _matte(Color("a8826a"), 4); var band := _matte(Color("c9b294"), 4); var dk := _matte(Color("4e3a30"), 0)
			var crk := Models.toon(Color("3a2a22"), false)
			mats = [clay, band, dk]
			var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.14, 0.0), Vector2(0.21, 0.05), Vector2(0.27, 0.19), Vector2(0.26, 0.33),
				Vector2(0.19, 0.45), Vector2(0.11, 0.52), Vector2(0.1, 0.57), Vector2(0.14, 0.61), Vector2(0.135, 0.64), Vector2(0.085, 0.62), Vector2(0.07, 0.57)])
			Models.part(root, Models.lathe(Models.smooth_curve(prof, 3), 20, "pot_body2"), clay, Vector3.ZERO)
			Models.part(root, Models.cyl(0.272, 0.272, 0.045, 18), band, Vector3(0, 0.26, 0))
			Models.part(root, Models.sphere(0.075, 8), dk, Vector3(0, 0.6, 0), Vector3(1.0, 0.25, 1.0))
			# a chipped lip, and cracks running down the belly
			Models.part(root, bx(0.07, 0.05, 0.05), dk, Vector3(0.11, 0.625, -0.06), Vector3.ONE, Vector3(0, 0.6, 0.3))
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				var n := Vector3(cos(a), 0, sin(a))
				_crack(root, crk, n * 0.272 + Vector3(0, 0.42, 0), n, Vector3(0, -1, 0) + n.cross(Vector3.UP) * 0.3, 0.2, rr)
		"barrel", "cask":
			var cask := kind_s == "cask"
			var red := _matte(Color("8a7058") if cask else Color("a8473c"), 2)
			var dkred := _matte(Color("4e3a2a") if cask else Color("622a24"), 2)
			var iron := _matte(Color("44404a"), 3); var hz := _matte(Color("d8b44a"), 1)
			mats = [red, iron, dkred, hz]
			var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.23, 0), Vector2(0.27, 0.11), Vector2(0.285, 0.34), Vector2(0.27, 0.57), Vector2(0.23, 0.68), Vector2(0.18, 0.68), Vector2(0, 0.66)])
			Models.part(root, Models.lathe(Models.smooth_curve(prof, 3), 20, "keg_body2"), red, Vector3.ZERO)
			# stave seams
			for i in 9:
				var a := TAU * i / 9.0
				var sv := Models.part(root, bx(0.012, 0.54, 0.012), dkred, Vector3(cos(a) * 0.279, 0.34, sin(a) * 0.279))
				sv.rotation.y = -a
			for y in [0.12, 0.56]:
				Models.part(root, Models.cyl(0.284, 0.284, 0.055, 18), iron, Vector3(0, y, 0))
			if cask:
				Models.part(root, Models.cyl(0.21, 0.21, 0.03, 16), dkred, Vector3(0, 0.685, 0))
				_finish(root)
				root.set_meta("mats", mats)
				return root
			# a hazard band, a skull-ish warning patch and a fuse stub with a small ember on top
			Models.part(root, Models.cyl(0.29, 0.29, 0.07, 18), hz, Vector3(0, 0.34, 0))
			for i in 6:
				var a := TAU * i / 6.0
				var st := Models.part(root, bx(0.04, 0.075, 0.012), dkred, Vector3(cos(a) * 0.293, 0.34, sin(a) * 0.293))
				st.rotation = Vector3(0, -a + PI / 2, 0.6)
			Models.part(root, Models.cyl(0.05, 0.06, 0.06, 10), iron, Vector3(0.09, 0.7, 0))
			var fuse_m := Models.toon(Color("ffb04a"), false, 0.5)
			Models.part(root, Models.sphere(0.055, 8), fuse_m, Vector3(0.09, 0.76, 0), Vector3.ONE, Vector3.ZERO, "Fuse")
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
	b.position = Vector3(-0.05, 0.72, 0.0)
	root.add_child(b)
	var c := breakable("cask")
	c.position = Vector3(0.42, 0, -0.32); c.rotation.y = r.randf() * TAU
	root.add_child(c)
	var sack := _matte(Color("b4a284"), 1)
	var tie := _matte(Color("5e4836"), 2)
	var sk := Node3D.new(); sk.position = Vector3(-0.45, 0, -0.4); root.add_child(sk)
	Models.part(sk, Models.sphere(0.24, 12), sack, Vector3(0, 0.2, 0), Vector3(1.0, 0.9, 0.9))
	Models.part(sk, Models.sphere(0.13, 10), sack, Vector3(0, 0.42, 0), Vector3(0.8, 0.7, 0.8))
	Models.part(sk, Models.cyl(0.06, 0.07, 0.04, 10), tie, Vector3(0, 0.37, 0))
	_finish(sk)
	return root
