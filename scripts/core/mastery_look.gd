class_name MasteryLook
extends RefCounted
## The mask takes hold: the more you play a Relic, the more its Hunter shows on your own character at home.
## content/rules/class_unlock.json "looks" lists the features (a Hunter, the mastery level that gives it, a shape
## and a colour). Once earned, a feature is kept in look["features"] {id: true (shown) | false (faded)}; the
## creator flips it and an earned feature is never switched back on by itself.

const EYE_X := 0.075         # m: each eye's distance from the face's centre line (head space, torso child)
const EYE_Y := 0.89          # m: eye height above the torso's origin
const EYE_SIZE := 0.032      # m: radius of an eye's glow
const FACE_Z := -0.232       # m: the head's front surface (the face looks down -z); pieces are deep enough to sit in it
const SCAR_FROM := Vector2(0.06, 0.97)       # m: the scar's top end (x, y), over the right brow
const SCAR_TO := Vector2(-0.02, 0.8)         # m: and its bottom end, across the cheek
const SCAR_WIDTH := 0.012    # m
const DEPTH := 0.03          # m: how deep a piece is, so it sits in the head instead of floating off it
const GLOW_ENERGY := 2.5     # x: how far past plain white the glow's emission goes

static func features() -> Array:
	return ClassUnlock.rules().get("looks", [])

static func earned(f: Dictionary) -> bool:
	return ClassUnlock.mastery_level(String(f["hunter"])) >= int(f["level"])

## Features that are earned and not faded, in content order.
static func shown(lk: Dictionary) -> Array:
	var on: Dictionary = lk.get("features", {})
	return features().filter(func(f): return bool(on.get(String(f["id"]), false)))

## Records every feature this save has earned and not seen yet as shown. Returns whether the look changed.
static func refresh(lk: Dictionary) -> bool:
	if not lk.get("features") is Dictionary:
		return false
	var on: Dictionary = lk["features"]
	var changed := false
	for f in features():
		if earned(f) and not on.has(String(f["id"])):
			on[String(f["id"])] = true
			changed = true
	return changed

## Keeps or fades an earned feature (false if it isn't earned yet).
static func toggle(lk: Dictionary, id: String) -> bool:
	var on: Dictionary = lk["features"]
	if not on.has(id):
		return false
	on[id] = not bool(on[id])
	return true

## Draws the shown features on the face (torso space). Each is a node named "Mastery_<id>".
static func draw(torso: Node3D, lk: Dictionary) -> void:
	for f in shown(lk):
		var col := Color(String(f["col"]))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = GLOW_ENERGY
		var mark := Node3D.new()
		mark.name = "Mastery_%s" % f["id"]
		torso.add_child(mark)
		match String(f["shape"]):
			"eyes":
				for sx in [-1.0, 1.0]:
					var at := Vector3(EYE_X * sx, EYE_Y, FACE_Z)
					_piece(mark, SphereMesh.new(), mat, at, Vector3(EYE_SIZE * 2.0, EYE_SIZE * 1.2, DEPTH))
			"scar":
				var d := SCAR_TO - SCAR_FROM
				var mid := (SCAR_FROM + SCAR_TO) * 0.5
				var dims := Vector3(SCAR_WIDTH, d.length(), DEPTH)
				_piece(mark, BoxMesh.new(), mat, Vector3(mid.x, mid.y, FACE_Z), dims, atan2(d.x, -d.y))

static func _piece(parent: Node3D, shape: Mesh, mat: Material, at: Vector3, dims: Vector3, roll := 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = shape
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = dims
	mi.rotation.z = roll
	parent.add_child(mi)
