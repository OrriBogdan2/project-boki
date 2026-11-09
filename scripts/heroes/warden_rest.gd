class_name WardenRest
extends RefCounted
## Each Warden's rig rest in the neutral look (what its .glb is built on, WardenGlb.neutral_rest), baked into
## PATH. Measuring one builds a whole throwaway procedural Warden (0.15 to 0.7 s cold, per Warden in the match),
## so a match reads the bake instead. --warden-rest-check measures every Warden and fails when the bake is
## stale; --warden-rest-bake rewrites it.

const PATH := "res://content/rules/warden_rest.json"
const TOLERANCE := 1e-4      # m (and basis units): a baked rest this close to the measured one is current

static var _baked = null     # Warden id -> {bone: Transform3D}, read from PATH once

## The baked rest of a Warden, or {} when it has none (then it is measured).
static func baked(arch: String) -> Dictionary:
	if _baked == null:
		_baked = {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if typeof(parsed) == TYPE_DICTIONARY:
			for a in parsed:
				_baked[a] = _decode(parsed[a])
	return (_baked as Dictionary).get(arch, {})

## Measures every Warden with a .glb and writes PATH.
static func bake() -> void:
	var out := {}
	for a in Arch.ORDER:
		if WardenGlb.has_model(a):
			out[a] = _encode(WardenGlb.measure_rest(a))
	var f := FileAccess.open(ProjectSettings.globalize_path(PATH), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t", true) + "\n")
	f.close()
	_baked = null

## Whether two rests have the same bones, each within TOLERANCE.
static func same(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k) or not _near(a[k], b[k]):
			return false
	return true

static func _near(x: Transform3D, y: Transform3D) -> bool:
	for i in 4:
		var d: Vector3 = (x.origin - y.origin) if i == 3 else (x.basis[i] - y.basis[i])
		if d.length() > TOLERANCE:
			return false
	return true

## {bone: [basis x, y, z columns, origin]} as 12 numbers per bone.
static func _encode(rest: Dictionary) -> Dictionary:
	var out := {}
	for k in rest:
		var t: Transform3D = rest[k]
		out[k] = [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
				t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
	return out

static func _decode(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v: Array = d[k]
		out[k] = Transform3D(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]),
				Vector3(v[9], v[10], v[11]))
	return out
