class_name ShotFalloff
extends RefCounted
## A weapon's shot loses damage with the distance it flew (fall-off) and/or starts weak up close (ramp-up).
## The curve classes are in content/rules/shot_falloff.json, in the reference's metres; a weapon names one in
## its primary ("falloff", "ramp"). `add` puts them on a shot's extras ("farf", "near"); Match._shot_apply
## multiplies the damage by `mult`.

const PATH := "res://content/rules/shot_falloff.json"
static var _d: Dictionary = {}


static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _d


static func add(extra: Dictionary, wpn: Dictionary) -> void:
	if wpn.has("falloff"):
		var c: Dictionary = data()["falloff"][wpn["falloff"]]
		extra["farf"] = [float(c["start"]), float(c["floor"]), float(c["end"])]
	if wpn.has("ramp"):
		var r: Dictionary = data()["ramp"][wpn["ramp"]]
		extra["near"] = [float(r["from"]), float(r["start"]), float(r["end"])]


## The damage share of a shot with extras `x` that flew `trav` metres (1.0 when it has no curve).
static func mult(x: Dictionary, trav: float) -> float:
	var k := 1.0
	if x.has("near"):
		var n: Array = x["near"]
		k *= lerpf(float(n[0]), 1.0, clampf((trav - float(n[1])) / maxf(0.1, float(n[2]) - float(n[1])), 0.0, 1.0))
	if x.has("farf"):
		var f: Array = x["farf"]
		k *= lerpf(1.0, float(f[1]), clampf((trav - float(f[0])) / maxf(0.1, float(f[2]) - float(f[0])), 0.0, 1.0))
	return k
