class_name ShotFalloff
extends RefCounted
## A weapon's shot loses damage with the distance it flew (fall-off) and/or starts weak up close (ramp-up).
## The curve classes are in content/rules/shot_falloff.json; a weapon names one in its primary ("falloff",
## "ramp"). Match._shot_apply reads the two arrays this adds to a shot's extras: "farf" and "near".

const PATH := "res://content/rules/shot_falloff.json"
static var _d: Dictionary = {}

static func data() -> Dictionary:
	if _d.is_empty():
		_d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _d

## `range`: the shot's travel. A weapon shorter than the class end squeezes the class into its range.
static func add(extra: Dictionary, wpn: Dictionary, range: float) -> void:
	if wpn.has("falloff"):
		var c: Dictionary = data()["falloff"][wpn["falloff"]]
		var k := minf(1.0, range / float(c["end"]))
		extra["farf"] = [float(c["start"]) * k, float(c["floor"]), float(c["end"]) * k]
	if wpn.has("ramp"):
		var r: Dictionary = data()["ramp"][wpn["ramp"]]
		var k2 := minf(1.0, range / float(data()["falloff"][wpn.get("falloff", "long")]["end"]))
		extra["near"] = [float(r["from"]), float(r["end"]) * k2, float(r["start"]) * k2]
