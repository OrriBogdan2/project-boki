class_name VisitorArrive
extends RefCounted
## What makes a wild visitor (GardenVisitor) read as a stranger: footprints from the island edge to where it
## settles that fade in, a small shimmer in its type colour on it for its first seconds, and one glint on the
## egg it leaves in the Incubator until the egg is hatched. Flat cel colour, no rings (ground rings mean
## gameplay). Tuning: content/rules/garden_visitor.json "arrive".

const SHIMMER_STEP := 0.1      # s: GardenVisitor.step's tick, so one mote burst per mote_s

static var _glint_t := 0.0

static func rules() -> Dictionary:
	return GardenVisitor.rules()["arrive"]

static func type_col(species: String) -> Color:
	return DexView.type_col(GardenVisitor.theme_of(species))

## Footprints from the island edge towards `to` (where the visitor stands), in its type colour: they fade in
## over fade_in_s, hold, then fade out and the node frees itself.
static func trail(h, to: Vector3, species: String) -> void:
	var a: Dictionary = rules()
	var isle: Dictionary = h.world.islands[0]
	var centre := Vector2(isle["c"])
	var dir := Vector2(to.x, to.z) - centre
	dir = dir.normalized() if dir.length() > 0.5 else Vector2.RIGHT
	var step_m := float(a["step_m"])
	var edge_m := (centre + dir * float(isle["r"]) - Vector2(to.x, to.z)).length()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(type_col(species), 0.0)
	var mesh := SphereMesh.new()
	mesh.radius = float(a["print_m"])
	mesh.height = 2.0 * mesh.radius
	mesh.material = mat
	var side := Vector2(-dir.y, dir.x)
	var root := Node3D.new()
	h.add_child(root)
	for i in int(a["prints"]):
		var d := step_m * (i + 1)
		if d > edge_m:
			break
		var p := Vector2(to.x, to.z) + dir * d + side * (0.2 if i % 2 == 0 else -0.2)
		if h.world.is_void(p.x, p.y) or h.world.is_block(p.x, p.y):
			continue
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.scale = Vector3(1.0, 0.1, 1.6)
		m.position = Vector3(p.x, h.world.ground_at(p.x, p.y) + 0.03, p.y)
		m.rotation.y = -dir.angle() + PI / 2.0
		root.add_child(m)
	var tw := root.create_tween()
	tw.tween_property(mat, "albedo_color:a", float(a["alpha"]), float(a["fade_in_s"]))
	tw.tween_interval(float(a["hold_s"]))
	tw.tween_property(mat, "albedo_color:a", 0.0, float(a["fade_out_s"]))
	tw.tween_callback(root.queue_free)

## Called at 10 Hz while the visitor `r` stands as `k`: for its first shimmer_s, a few motes of its type
## colour every mote_s (placed by its age, so the global random stream is left alone).
static func shimmer(h, k: Dictionary, r: Dictionary, age: float) -> void:
	var a: Dictionary = rules()
	if age < 0.0 or age >= float(a["shimmer_s"]) or fmod(age, float(a["mote_s"])) >= SHIMMER_STEP:
		return
	var drift := Vector3(sin(age * 7.0) * 0.3, 0.4 + fmod(age * 1.7, 0.6), cos(age * 5.0) * 0.3)
	var at: Vector3 = (k["node"] as Node3D).position + drift
	h.fx.burst(at, type_col(String(r["species"])), int(a["motes"]), 0.6, 0.7, -0.6, 0.6)

## Every glint_s: one glint on each egg a visitor left that is still in the Incubator (hinc `inc`).
static func glint(inc: HomeIncubator, d: float) -> void:
	_glint_t += d
	if _glint_t < float(rules()["glint_s"]):
		return
	_glint_t = 0.0
	var q := Incubator.shelf()
	for i in mini(inc.shelf_eggs.size(), q.size()):
		if q[i].has("visitor") and is_instance_valid(inc.shelf_eggs[i]):
			_sparkle(inc, inc.shelf_eggs[i], q[i])
	for e in Incubator.eggs():
		var en: Node3D = inc.egg_nodes.get(String(e["id"]), null)
		if e.has("visitor") and is_instance_valid(en):
			_sparkle(inc, en, e)

static func _sparkle(inc: HomeIncubator, egg: Node3D, e: Dictionary) -> void:
	inc.h.fx.flash(egg.global_position + Vector3(0.12, 0.35, 0.1), type_col(String(e["sp"])).lightened(0.5), 0.3, 0.25)
