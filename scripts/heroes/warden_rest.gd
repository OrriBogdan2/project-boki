class_name WardenRest
extends RefCounted
## Each Warden's rig rest in the neutral look (what its .glb is built on, WardenGlb.neutral_rest), baked into
## PATH. Measuring one builds a whole throwaway procedural Warden (0.15 to 0.7 s cold, per Warden in the match),
## so a match reads the bake instead. --warden-rest-check measures every Warden and fails when the bake is
## stale; --warden-rest-bake rewrites it. What the native path reads off each art's contract .glb (its anchor empties
## and skeleton frame, WardenNative.measure_contract: loading it was 30-120 ms per art on the main thread) is baked
## beside it in ANCHORS_PATH.

const PATH := "res://content/rules/warden_rest.json"
const TOLERANCE := 1e-4      # m (and basis units): a baked rest this close to the measured one is current

const ANCHORS_PATH := "res://content/rules/warden_anchors.json"

static var _baked = null     # Warden id -> {bone: Transform3D}, read from PATH once
static var _anchors = null   # art -> {sk_m, anchors} (WardenNative.measure_contract's form), read once

## The baked rest of a Warden, or {} when it has none (then it is measured).
static func baked(arch: String) -> Dictionary:
	if _baked == null:
		_baked = {}
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if typeof(parsed) == TYPE_DICTIONARY:
			for a in parsed:
				_baked[a] = _decode(parsed[a])
	return (_baked as Dictionary).get(arch, {})

## The baked contract reads: art -> {"sk_m": Transform3D, "anchors": [[name, [[bone, Transform3D]...], Transform3D]...]}
## ({} when none are baked).
static func contracts() -> Dictionary:
	if _anchors == null:
		_anchors = {}
		var src := FileAccess.get_file_as_string(ANCHORS_PATH) if FileAccess.file_exists(ANCHORS_PATH) else ""
		var parsed = JSON.parse_string(src) if src != "" else null
		if typeof(parsed) == TYPE_DICTIONARY:
			for art_name in parsed:
				var c: Dictionary = parsed[art_name]
				var list: Array = []
				for a: Array in c["anchors"]:
					list.append([a[0], (a[1] as Array).map(func(l: Array): return [l[0], _xf(l[1])]), _xf(a[2])])
				_anchors[art_name] = {"sk_m": _xf(c["sk_m"]), "anchors": list}
	return _anchors

## Measures every Warden with a .glb and writes PATH, and every native art's contract anchors to ANCHORS_PATH.
static func bake() -> void:
	var out := {}
	for a in Arch.ORDER:
		if WardenGlb.has_model(a):
			out[a] = _encode(WardenGlb.measure_rest(a))
	_write(PATH, out, false)
	_baked = null
	var anc := {}
	for art_name in WardenNative.arts():
		var c := WardenNative.measure_contract(art_name)
		if c.is_empty():
			continue
		var list: Array = []
		for a: Array in c["anchors"]:
			list.append([a[0], (a[1] as Array).map(func(l: Array): return [l[0], _nums(l[1])]), _nums(a[2])])
		anc[art_name] = {"sk_m": _nums(c["sk_m"]), "anchors": list}
	_write(ANCHORS_PATH, anc, true)
	_anchors = null

static func _write(path: String, data: Dictionary, full: bool) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path(path), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", true, full) + "\n")
	f.close()

## Whether two contract reads have the same frame and the same anchors on the same bones, each within TOLERANCE.
static func same_contract(c: Dictionary, e: Dictionary) -> bool:
	if c.is_empty() or e.is_empty() or not _near(c["sk_m"], e["sk_m"]):
		return c.is_empty() and e.is_empty()
	var a: Array = c["anchors"]
	var b: Array = e["anchors"]
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Array = a[i]
		var y: Array = b[i]
		if x[0] != y[0] or (x[1] as Array).size() != (y[1] as Array).size() or not _near(x[2], y[2]):
			return false
		for j in (x[1] as Array).size():
			if x[1][j][0] != y[1][j][0] or not _near(x[1][j][1], y[1][j][1]):
				return false
	return true

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
		out[k] = _nums(rest[k])
	return out

static func _nums(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]

static func _xf(v: Array) -> Transform3D:
	return Transform3D(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), Vector3(v[6], v[7], v[8]),
			Vector3(v[9], v[10], v[11]))

static func _decode(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = _xf(d[k])
	return out
