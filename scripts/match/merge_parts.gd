class_name MergeParts
extends RefCounted
## The silhouette parts of a merged form (MergeLook builds them under the hunter's torso).
##   - the forms with a kit have their own sets: Heavy Star (rock_plates, star_crown, gravity_ring), Stormwing
##     (storm_wings, storm_halo, spark_trail), Prism Shell (crystal_shell, prism_crest, prism_glints)
##   - the stat-style fallback keeps the small parts a Boki type picks (horns, fangs, crest, spikes, plates, wings, halo, antennae, tail)
## build() returns a record of what moves; animate() moves it each frame (idle motion, no per-frame allocation).
## Parts sit on the torso, which is scaled with the model, so sizes here are for a 1.0 hunter.

static func _toon(col: Color, glow: Color, k := 0.35, g := 0.55) -> ShaderMaterial:
	return Models.toon(col.lerp(glow, k), true, g)

static func _cone(parent: Node3D, mat: Material, pos: Vector3, h_: float, r_: float, rot: Vector3, seg := 8) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r_
	cm.height = h_
	cm.radial_segments = seg
	return Models.part(parent, cm, mat, pos + Basis.from_euler(rot) * Vector3(0, h_ * 0.5, 0), Vector3.ONE, rot)

static func _rec() -> Dictionary:
	return {"wings": [], "halo": null, "tail": [], "spin": [], "orbit": [], "glints": [], "bob": [], "trail": null}

static func build(parent: Node3D, form: Dictionary, base: Vector3) -> Dictionary:
	var rec := _rec()
	var col: Color = form["color"]
	var glow: Color = form["glow"]
	var acc: Color = form.get("accent", glow)
	for p in form["parts"]:
		match String(p):
			"rock_plates": _rock_plates(parent, rec, col, glow, acc, base)
			"star_crown": _star_crown(parent, rec, col, glow, acc, base)
			"gravity_ring": _gravity_ring(parent, rec, col, glow, base)
			"storm_wings": _storm_wings(parent, rec, col, glow, acc, base)
			"storm_halo": _storm_halo(parent, rec, glow, acc, base)
			"spark_trail": _spark_trail(parent, rec, glow, base)
			"crystal_shell": _crystal_shell(parent, rec, col, glow, base)
			"prism_crest": _prism_crest(parent, rec, col, glow, base)
			"prism_glints": _prism_glints(parent, rec, base)
			_: _small(parent, rec, String(p), col, glow, base)
	return rec

# ------------------------------------------------------------------ Heavy Star
static func _rock_plates(parent: Node3D, _rec_: Dictionary, col: Color, glow: Color, acc: Color, base: Vector3) -> void:
	var rock := Models.toon(col.lerp(glow, 0.38), true, 0.25)
	var seam := Models.glow_mat(Color(acc, 0.9))
	for s in [-1.0, 1.0]:
		var pl := Models.part(parent, Models.box(0.4, 0.24, 0.46), rock, base + Vector3(0.4 * s, 0.94, 0.0), Vector3.ONE, Vector3(0, 0, 0.45 * s), "Pauldron")
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		Models.part(parent, Models.box(0.3, 0.035, 0.36), seam, base + Vector3(0.4 * s, 1.04, 0.0), Vector3.ONE, Vector3(0, 0, 0.45 * s))
		Models.part(parent, Models.box(0.2, 0.2, 0.22), rock, base + Vector3(0.52 * s, 0.56, 0.0), Vector3.ONE, Vector3(0.2, 0, 0.2 * s))
	for i in 3:
		var w := 0.58 - 0.07 * float(i)
		Models.part(parent, Models.box(w, 0.15, 0.14), rock, base + Vector3(0, 0.38 + 0.22 * float(i), 0.3), Vector3.ONE, Vector3(-0.15, 0, 0))
		Models.part(parent, Models.box(w * 0.8, 0.025, 0.04), seam, base + Vector3(0, 0.47 + 0.22 * float(i), 0.37))
	Models.part(parent, Models.box(0.52, 0.42, 0.1), rock, base + Vector3(0, 0.66, -0.26), Vector3.ONE, Vector3(0.1, 0, 0))
	Models.part(parent, Models.sphere(0.07), Models.glow_mat(Color(glow, 0.95)), base + Vector3(0, 0.72, -0.33))      # the core in the chest

static func _star_crown(parent: Node3D, rec: Dictionary, col: Color, glow: Color, acc: Color, base: Vector3) -> void:
	var gold := Models.toon(acc.darkened(0.25), true, 0.5)
	for i in 5:
		var a := TAU * float(i) / 5.0
		_cone(parent, gold, base + Vector3(cos(a) * 0.17, 1.2, sin(a) * 0.17), 0.34, 0.06, Vector3(sin(a) * 0.5, 0.0, -cos(a) * 0.5), 6)
	var star := Models.part(parent, Models.sphere(0.1), Models.glow_mat(Color(acc, 1.0)), base + Vector3(0, 1.58, 0))
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rec["bob"].append({"node": star, "y0": star.position.y, "amp": 0.03, "rate": 3.0, "ph": 0.0})

static func _gravity_ring(parent: Node3D, rec: Dictionary, col: Color, glow: Color, base: Vector3) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.66
	tm.outer_radius = 0.72
	var ring := Models.part(parent, tm, Models.glow_mat(Color(glow, 0.85)), base + Vector3(0, 0.5, 0), Vector3.ONE, Vector3(0.25, 0, 0.1))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rec["spin"].append({"node": ring, "rate": 1.4})
	var rock := Models.toon(col, true, 0.1)
	for i in 3:
		var mote := Models.part(parent, Models.sphere(0.09), rock, base + Vector3(0.8, 0.5, 0))
		rec["orbit"].append({"node": mote, "r": 0.82, "y": 0.5, "w": 1.9, "ph": TAU * float(i) / 3.0, "bob": 0.12})

# ------------------------------------------------------------------ Stormwing
static func _storm_wings(parent: Node3D, rec: Dictionary, col: Color, glow: Color, acc: Color, base: Vector3) -> void:
	var feather := Models.toon(col.lerp(Color.WHITE, 0.15), true, 0.45)
	var edge := Models.glow_mat(Color(acc, 0.95))
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = base + Vector3(0.14 * s, 1.0, 0.2)
		parent.add_child(w)
		for i in 5:
			var len_ := 1.25 - 0.15 * float(i)
			var f := Models.part(w, Models.box(len_, 0.035, 0.15), feather, Vector3(0.5 * s * len_ + 0.08 * s, 0.12 * float(i) - 0.1, 0.05 * float(i)), Vector3.ONE, Vector3(0, 0.18 * s * float(i), (0.4 - 0.09 * float(i)) * s))
			f.name = "Feather"
			Models.part(w, Models.box(len_ * 0.96, 0.02, 0.025), edge, Vector3(0.5 * s * len_ + 0.08 * s, 0.12 * float(i) - 0.08, 0.05 * float(i) - 0.08), Vector3.ONE, Vector3(0, 0.18 * s * float(i), (0.4 - 0.09 * float(i)) * s))
		w.set_meta("side", s)
		rec["wings"].append(w)

static func _storm_halo(parent: Node3D, rec: Dictionary, glow: Color, acc: Color, base: Vector3) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.34
	var halo := Models.part(parent, tm, Models.glow_mat(Color(acc, 0.95)), base + Vector3(0, 1.55, 0))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rec["halo"] = halo
	for i in 3:
		var spark := Models.part(parent, Models.sphere(0.045), Models.glow_mat(Color(Color.WHITE, 0.95)), base + Vector3(0.3, 1.55, 0))
		rec["orbit"].append({"node": spark, "r": 0.31, "y": 1.55, "w": 6.0, "ph": TAU * float(i) / 3.0, "bob": 0.0})

static func _spark_trail(parent: Node3D, rec: Dictionary, glow: Color, base: Vector3) -> void:
	var tr := CPUParticles3D.new()
	tr.amount = 18
	tr.lifetime = 0.5
	tr.local_coords = false
	tr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	tr.emission_sphere_radius = 0.35
	tr.direction = Vector3.UP
	tr.spread = 90.0
	tr.gravity = Vector3.ZERO
	tr.initial_velocity_min = 0.2
	tr.initial_velocity_max = 0.9
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 0.18)
	tr.mesh = bm
	tr.material_override = Models.glow_mat(Color(1, 0.95, 0.5))
	tr.position = base + Vector3(0, 0.7, 0.3)
	tr.emitting = false
	parent.add_child(tr)
	rec["trail"] = tr

# ------------------------------------------------------------------ Prism Shell
static func _crystal_shell(parent: Node3D, rec: Dictionary, col: Color, glow: Color, base: Vector3) -> void:
	var cry := Models.toon(Color("a9e8f2").lerp(glow, 0.25), true, 0.7)
	var cry2 := Models.toon(Color("e0b8ff").lerp(glow, 0.2), true, 0.7)
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.3
		var h_ := 0.5 + 0.18 * float(i % 3)
		var c := CylinderMesh.new()
		c.top_radius = 0.02
		c.bottom_radius = 0.11
		c.height = h_
		c.radial_segments = 4
		var pos := base + Vector3(cos(a) * 0.52, 0.5 + 0.05 * float(i % 2), sin(a) * 0.52)
		var shard := Models.part(parent, c, cry if i % 2 == 0 else cry2, pos + Vector3(0, h_ * 0.4, 0), Vector3.ONE, Vector3(sin(a) * 0.38, a, -cos(a) * 0.38) * 1.0)
		shard.name = "Facet"
		rec["bob"].append({"node": shard, "y0": shard.position.y, "amp": 0.02, "rate": 2.0 + 0.3 * float(i), "ph": float(i)})
	for s in [-1.0, 1.0]:
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.0
		c2.bottom_radius = 0.16
		c2.height = 0.6
		c2.radial_segments = 4
		Models.part(parent, c2, cry, base + Vector3(0.42 * s, 1.0, 0.0), Vector3.ONE, Vector3(0, 0.4, 0.7 * s))

static func _prism_crest(parent: Node3D, rec: Dictionary, col: Color, glow: Color, base: Vector3) -> void:
	var cry := Models.toon(Color("d8f6ff").lerp(glow, 0.2), true, 0.8)
	for i in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.07
		c.height = 0.5 - 0.1 * float(i)
		c.radial_segments = 4
		Models.part(parent, c, cry, base + Vector3((float(i) - 1.0) * 0.1, 1.38 + 0.02 * float(i), -0.05 + 0.04 * float(i)), Vector3.ONE, Vector3(-0.3 + 0.25 * float(i), 0.5 * float(i), (float(i) - 1.0) * 0.25))

static func _prism_glints(parent: Node3D, rec: Dictionary, base: Vector3) -> void:
	for i in 5:
		var mat := Models.glow_mat(Color.from_hsv(float(i) / 5.0, 0.5, 1.0, 0.95))
		var g := Models.part(parent, Models.sphere(0.05), mat, base + Vector3(0.7, 0.8, 0))
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rec["glints"].append({"mat": mat, "hue": float(i) / 5.0})
		rec["orbit"].append({"node": g, "r": 0.78 + 0.08 * float(i % 2), "y": 0.45 + 0.17 * float(i), "w": 1.3 + 0.2 * float(i % 3), "ph": TAU * float(i) / 5.0, "bob": 0.05})

# ------------------------------------------------------------------ the small parts of a Boki without a form
static func _small(parent: Node3D, rec: Dictionary, kind: String, col: Color, glow: Color, base: Vector3) -> void:
	var mat := _toon(col, glow)
	match kind:
		"horns":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.13 * s, 1.12, -0.02), 0.5, 0.07, Vector3(0.0, 0.0, -0.45 * s))
		"fangs":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.07 * s, 1.0, -0.15), 0.2, 0.035, Vector3(PI, 0.0, 0.0))
		"crest":
			for i in 5:
				_cone(parent, mat, base + Vector3(0, 1.16 - 0.02 * i, -0.02 + 0.09 * i), 0.42 - 0.05 * i, 0.05, Vector3(0.5 + 0.1 * i, 0.0, 0.0))
		"spikes":
			for i in 4:
				_cone(parent, mat, base + Vector3(0, 0.95 - 0.2 * i, 0.2), 0.34, 0.06, Vector3(1.0, 0.0, 0.0))
		"plates":
			for s in [-1.0, 1.0]:
				var pl := Models.part(parent, BoxMesh.new(), mat, base + Vector3(0.34 * s, 0.85, 0.0), Vector3(0.26, 0.1, 0.3), Vector3(0, 0, 0.35 * s))
				pl.name = "Plate"
		"wings":
			for s in [-1.0, 1.0]:
				var w := Node3D.new()
				w.position = base + Vector3(0.14 * s, 0.7, 0.2)
				parent.add_child(w)
				for i in 3:
					var f := Models.part(w, BoxMesh.new(), mat, Vector3(0.38 * s * (0.55 + 0.4 * i), 0.1 * i, 0.04 * i), Vector3(0.62 - 0.12 * i, 0.03, 0.14), Vector3(0, 0.25 * s * i, 0.5 * s - 0.15 * s * i))
					f.name = "Feather"
				w.set_meta("side", s)
				w.set_meta("calm", true)
				rec["wings"].append(w)
		"halo":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.26
			tm.outer_radius = 0.31
			var halo := Models.part(parent, tm, Models.glow_mat(glow), base + Vector3(0, 1.5, 0))
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rec["halo"] = halo
		"antennae":
			for s in [-1.0, 1.0]:
				_cone(parent, mat, base + Vector3(0.09 * s, 1.14, -0.05), 0.5, 0.025, Vector3(-0.3, 0.0, -0.35 * s))
				Models.part(parent, Models.sphere(0.04), Models.glow_mat(glow), base + Vector3(0.29 * s, 1.62, -0.1))
		"tail":
			for i in 5:
				var seg := Models.part(parent, Models.sphere(0.11 - 0.017 * i), mat, base + Vector3(0, 0.3 + 0.1 * i, 0.3 + 0.08 * i))
				rec["tail"].append(seg)

# ------------------------------------------------------------------ idle motion
static func animate(rec: Dictionary, t: float, dt: float, moving: bool) -> void:
	for w in rec["wings"]:
		if not is_instance_valid(w):
			continue
		var s: float = w.get_meta("side")
		var calm: bool = w.get_meta("calm", false)
		var rate := 7.0 if calm else 15.0
		var amp := 0.22 if calm else 0.38
		w.rotation.z = s * (0.15 + amp * (0.5 + 0.5 * sin(t * rate)))
	var halo = rec["halo"]
	if halo != null and is_instance_valid(halo):
		(halo as Node3D).rotation.y += dt * 2.5
		(halo as Node3D).position.y += sin(t * 4.0) * 0.1 * dt
	var tail: Array = rec["tail"]
	for i in tail.size():
		if is_instance_valid(tail[i]):
			(tail[i] as Node3D).position.x = sin(t * 5.0 - i * 0.6) * 0.09 * float(i)
	for sp in rec["spin"]:
		if is_instance_valid(sp["node"]):
			(sp["node"] as Node3D).rotation.y += dt * float(sp["rate"])
	for o in rec["orbit"]:
		var n: Node3D = o["node"]
		if is_instance_valid(n):
			var a := t * float(o["w"]) + float(o["ph"])
			n.position = Vector3(cos(a) * float(o["r"]), float(o["y"]) + sin(a * 1.7) * float(o["bob"]), sin(a) * float(o["r"])) + Vector3(0, 0, 0)
	for b in rec["bob"]:
		var n2: Node3D = b["node"]
		if is_instance_valid(n2):
			n2.position.y = float(b["y0"]) + sin(t * float(b["rate"]) + float(b["ph"])) * float(b["amp"])
	for g in rec["glints"]:
		(g["mat"] as ShaderMaterial).set_shader_parameter("color", Color.from_hsv(fposmod(float(g["hue"]) + t * 0.35, 1.0), 0.5, 1.0, 0.95))
	var tr = rec["trail"]
	if tr != null and is_instance_valid(tr):
		(tr as CPUParticles3D).emitting = moving
