extends RefCounted
## --toon-consistency-check [--report=<tsv path>]: every 3D model the game draws (each Boki that wears a BokiRig
## .glb, each Hunter in Arch.ORDER; built the way the match, farm and lobby build them) must be cel-shaded the same
## way and sit in the approved range (every drawn model fits in). Per model it reads the finished
## materials and the painted atlas, and fails when
##  - a surface is on a shader that is not in content/rules/toon_consistency.json "shaders" (the shared toon/hero
##    material, plus the named special surfaces: glow, eye, flame, void, card, marks),
##  - the body surface has no ink outline,
##  - the hero look (ramp, shade, shadow floor) differs from the shared one,
##  - the atlas's mean luminance, baked-shadow share (texels under SHADE_REL of the atlas's own median) or
##    saturation is outside the range of the approved set.
## The ranges come from the approved set; a new model that does not fit fails here rather than shipping. Do not
## widen them to go green: fix the model's albedo (docs/art/kin/ de-shade pass) or its material. A model whose fix
## belongs to another job (a Hunter's .glb or look) sits in the rules' "waived" list with the exact fix; the check
## fails when a waived model no longer has a problem, so the entry is removed with the fix.

const RULES := "res://content/rules/toon_consistency.json"
const SAMPLE_PX := 256  # an atlas is reduced to this before its luminance is read
const SHADE_REL := 0.6  # a texel darker than this share of the atlas's median luminance counts as baked shade

var main: Node
var bad := 0
var rules: Dictionary
var rows: Array = []


func run(m: Node) -> void:
	main = m
	rules = JSON.parse_string(FileAccess.get_file_as_string(RULES))
	var report := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):
			report = a.substr(9)
	var species := Data.KIN.keys()
	species.sort()
	for sp in species:
		if BokiRig.has(sp):
			rows.append(_audit("boki", sp, Models.kin(sp, {"level": 5})))
	for arch in Arch.ORDER:
		var h := Models.hunter(
			Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch
		)
		rows.append(_audit("hunter", arch, h))
	for r in rows:
		_judge(r)
	for key in rules["waived"]:
		var rec: Array = rows.filter(func(r): return "%s:%s" % [r["kind"], r["id"]] == key)
		if rec.is_empty() or (rec[0]["problems"] as Array).is_empty():
			bad += 1
			print("TOON_CONSISTENCY FAIL %s: waived but fine (or not drawn): remove it from the rules" % key)
	if report != "":
		_write(report)
	print("TOON_CONSISTENCY %d models, %d problems" % [rows.size(), bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## What one built model wears: its surfaces' shaders, the body surface's look, its atlas's luminance and shade.
func _audit(kind: String, id: String, root: Node3D) -> Dictionary:
	var r := {"kind": kind, "id": id, "shaders": {}, "problems": [], "body_ink": false, "tex": [], "look": {}}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		for si in inst.mesh.get_surface_count():
			var mat := inst.get_surface_override_material(si)
			if mat == null:
				mat = inst.material_override if inst.material_override else inst.mesh.surface_get_material(si)
			_note_surface(r, mat)
	root.free()
	return r


func _note_surface(r: Dictionary, mat: Material) -> void:
	var sm := mat as ShaderMaterial
	var sh := sm.shader.resource_path.get_file() if sm and sm.shader else "(%s)" % mat.get_class()
	if mat is BaseMaterial3D and (mat as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		sh = "(fx)"  # a glow sprite or soft effect quad, not a body
	r["shaders"][sh] = int(r["shaders"].get(sh, 0)) + 1
	if sm == null or not sm.get_shader_parameter("use_tex"):
		return
	var tex := sm.get_shader_parameter("albedo_tex") as Texture2D
	if tex == null:
		return
	var stats := _tex_stats(tex)
	var trim = sm.get_shader_parameter("tex_sat")  # the material's own saturation trim (hero_toon tex_sat)
	stats["sat"] = float(stats["sat"]) * (1.0 if trim == null else float(trim))
	r["tex"].append(stats)
	r["body_ink"] = r["body_ink"] or sm.next_pass != null
	for k in rules["look_keys"]:
		var v = sm.get_shader_parameter(k)
		if not r["look"].has(k) and v != null:
			r["look"][k] = v


## Mean luminance and baked-shade share of an atlas's opaque texels, plus its pixel count (the weight).
func _tex_stats(tex: Texture2D) -> Dictionary:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(SAMPLE_PX, SAMPLE_PX, Image.INTERPOLATE_BILINEAR)
	var lums := PackedFloat32Array()
	var sat := 0.0
	for y in SAMPLE_PX:
		for x in SAMPLE_PX:
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				lums.append(c.srgb_to_linear().get_luminance())
				sat += c.s
	if lums.is_empty():
		return {"mean": 0.0, "shade": 0.0, "sat": 0.0, "px": 0}
	var sorted := lums.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2]
	var sum := 0.0
	var dark := 0
	for l in lums:
		sum += l
		dark += int(l < median * SHADE_REL)
	return {"mean": sum / lums.size(), "shade": float(dark) / lums.size(), "sat": sat / lums.size(), "px": lums.size()}


func _judge(r: Dictionary) -> void:
	var allowed: Array = rules["shaders"]
	for sh in r["shaders"]:
		if not allowed.has(sh):
			_flag(r, "off the shared toon material: %s" % sh)
	if not r["body_ink"]:
		_flag(r, "the textured body surface has no ink outline")
	var want: Dictionary = rules["look"][r["kind"]]
	for k in want:
		if r["look"].has(k) and not is_equal_approx(float(r["look"][k]), float(want[k])):
			_flag(r, "%s %s, the shared look has %s" % [k, r["look"][k], want[k]])
	if rng_floor(r).size() == 2 and r["look"].has("shade"):
		var floor_v := float(r["look"]["shade"])
		if floor_v < float(rng_floor(r)[0]) or floor_v > float(rng_floor(r)[1]):
			_flag(r, "shadow floor (shade) %.2f outside %s" % [floor_v, str(rng_floor(r))])
	var px := 0
	var mean := 0.0
	var shade := 0.0
	var sat := 0.0
	for t in r["tex"]:
		px += int(t["px"])
		mean += float(t["mean"]) * int(t["px"])
		shade += float(t["shade"]) * int(t["px"])
		sat += float(t["sat"]) * int(t["px"])
	r["mean"] = mean / maxi(px, 1)
	r["shade"] = shade / maxi(px, 1)
	r["sat"] = sat / maxi(px, 1)
	var rng: Dictionary = rules["range"][r["kind"]]
	if r["mean"] < float(rng["mean"][0]) or r["mean"] > float(rng["mean"][1]):
		_flag(r, "atlas luminance %.3f outside %s" % [r["mean"], str(rng["mean"])])
	if r["shade"] > float(rng["shade"]):
		_flag(r, "baked shade %.3f over %.3f" % [r["shade"], float(rng["shade"])])
	if r["sat"] > float(rng["sat"]):
		_flag(r, "atlas saturation %.3f over %.3f" % [r["sat"], float(rng["sat"])])


func rng_floor(r: Dictionary) -> Array:
	return rules["range"][r["kind"]].get("floor", [])


func _flag(r: Dictionary, why: String) -> void:
	r["problems"].append(why)
	var key := "%s:%s" % [r["kind"], r["id"]]
	if (rules["waived"] as Dictionary).has(key):
		print("TOON_CONSISTENCY WAIVED %s: %s (fix: %s)" % [key, why, rules["waived"][key]])
		return
	bad += 1
	print("TOON_CONSISTENCY FAIL %s: %s" % [key, why])


func _write(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("kind\tid\tshaders\tbody_ink\tlum_mean\tshade\tsat\tlook\tproblems")
	for r in rows:
		var look := []
		for k in r["look"]:
			look.append("%s=%s" % [k, r["look"][k]])
		f.store_line(
			(
				"%s\t%s\t%s\t%s\t%.3f\t%.3f\t%.3f\t%s\t%s"
				% [
					r["kind"],
					r["id"],
					JSON.stringify(r["shaders"]),
					r["body_ink"],
					r.get("mean", 0.0),
					r.get("shade", 0.0),
					r.get("sat", 0.0),
					" ".join(look),
					"; ".join(r["problems"])
				]
			)
		)
	f.close()
