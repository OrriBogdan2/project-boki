class_name ZoneVents
extends RefCounted
## Updraft vents on a built zone's island (briefs/design/GARDEN.md 10.7 step 7d): a pad in the ground and a pale
## column of air over it. Data: the zone's "build" vents in content/rules/garden_zones.json, world x and z in
## metres, the first one standing on the Dash's track (base_race.json: the stretch with a "vent" is lifted through
## it). A roaming flier over one rides it up (BokiFly) and now and then drifts to one (goal); the Dash's winged
## runners get a lift stretch there (BaseRace). Purely visual on the ground: nothing blocks or is walked into.
## Two MultiMesh batches (pads and columns), so the vents cost two draws however many there are.

const PAD_R := 0.8             # m, the pad's radius
const PAD_H := 0.06            # m, the pad's thickness
const COLUMN_R := 0.55         # m, the column of air's radius
const COLUMN_H := 3.0          # m, how high the column stands
const PAD_COL := Color("f7e8a6")
const COLUMN_COL := Color(0.96, 0.92, 0.7, 0.16)
const JITTER := 0.6            # m: a flier that drifts to a vent stops within this of its middle


## The zone's vents as ground points (y is 0), in the data's order.
static func spots(id: String) -> Array:
	var out: Array = []
	for v in GardenZones.info(id).get("build", {}).get("vents", []):
		out.append(Vector3(float(v[0]), 0.0, float(v[1])))
	return out


## True when `p` is within the pad's reach of one of the zone you are in.
static func over(p: Vector3) -> bool:
	var r := float(BokiFly.rules()["vent_r"])
	return spots(GardenZones.here).any(func(v: Vector3) -> bool: return Vector2(v.x - p.x, v.z - p.z).length() <= r)


## A roaming flier's next goal: now and then a vent, otherwise `else_goal`.
static func goal(k: Dictionary, else_goal: Vector3) -> Vector3:
	var all := spots(GardenZones.here)
	if all.is_empty() or not BokiFly.flier(String(k["rec"]["species"])) \
			or randf() >= float(BokiFly.rules()["vent_pull"]):
		return else_goal
	return all[randi() % all.size()] + Vector3(randf_range(-JITTER, JITTER), 0.0, randf_range(-JITTER, JITTER))


## Called once the zone's world is built (ZoneDress.place): the pads and columns.
static func dress(h) -> void:
	var pads: Array = []
	var columns: Array = []
	for v in spots(h.zone):
		var at := Vector3(v.x, h.world.ground_at(v.x, v.z), v.z)
		pads.append(Transform3D(Basis(), at + Vector3(0.0, PAD_H * 0.5, 0.0)))
		columns.append(Transform3D(Basis(), at + Vector3(0.0, COLUMN_H * 0.5, 0.0)))
	var pad := CylinderMesh.new()
	pad.top_radius = PAD_R
	pad.bottom_radius = PAD_R
	pad.height = PAD_H
	pad.radial_segments = 16
	pad.rings = 1
	var col := CylinderMesh.new()
	col.top_radius = COLUMN_R * 1.4
	col.bottom_radius = COLUMN_R
	col.height = COLUMN_H
	col.radial_segments = 12
	col.rings = 1
	col.cap_top = false
	col.cap_bottom = false
	ZoneDress.batch(h, pad, _glow(PAD_COL, false), pads, "vent_pads", Color.WHITE)
	ZoneDress.batch(h, col, _glow(COLUMN_COL, true), columns, "vent_columns", Color.WHITE)


static func _glow(c: Color, clear: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = 0.5 if clear else 0.2
	if clear:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
