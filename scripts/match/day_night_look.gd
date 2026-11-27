class_name DayNightLook
extends RefCounted
## The light of the day/night cycle (DayNight): blends the day, dusk and night looks of
## content/rules/day_night.json over the sun, the fill light, the ambient light, the fog and the sky.
## The dusk look is the evening the game has always had. Night is moonlit blue, never pitch black: the
## ambient stays high enough that hunters, telegraphs and the UI read. Plain Environment and light
## properties only, so it is the same on Forward+ and gl_compatibility.

const STEP := 0.004  # a change of the dark share smaller than this is not redrawn

var m: Match
var looks: Dictionary
var last := -1.0


func _init(match_node: Match, cfg: Dictionary) -> void:
	m = match_node
	looks = cfg["looks"]


## Light the world for a dark share `k`: 0 day, 0.5 dusk, 1 night.
func set_dark(k: float) -> void:
	if absf(k - last) < STEP or m.env == null:
		return
	last = k
	var a: Dictionary = looks["day"] if k < 0.5 else looks["dusk"]
	var b: Dictionary = looks["dusk"] if k < 0.5 else looks["night"]
	var f := (k if k < 0.5 else k - 0.5) * 2.0
	var e := m.env.environment
	var sun := m.get_node_or_null("Sun") as DirectionalLight3D
	var fill := m.get_node_or_null("Fill") as DirectionalLight3D
	if sun:
		sun.rotation_degrees = _v3(a["sun_rot"]).lerp(_v3(b["sun_rot"]), f)
		sun.light_color = _col(a["sun_col"]).lerp(_col(b["sun_col"]), f)
		sun.light_energy = lerpf(float(a["sun_energy"]), float(b["sun_energy"]), f)
	if fill:
		fill.light_color = _col(a["fill_col"]).lerp(_col(b["fill_col"]), f)
		fill.light_energy = lerpf(float(a["fill_energy"]), float(b["fill_energy"]), f)
	e.ambient_light_color = _col(a["amb_col"]).lerp(_col(b["amb_col"]), f)
	e.ambient_light_energy = lerpf(float(a["amb_energy"]), float(b["amb_energy"]), f)
	e.fog_light_color = _col(a["fog_col"]).lerp(_col(b["fog_col"]), f)
	e.fog_density = lerpf(float(a["fog_density"]), float(b["fog_density"]), f)
	_sky(e, a["sky"], b["sky"], f)
	RaidLook.sync_vis(e)


func _sky(e: Environment, a: Dictionary, b: Dictionary, f: float) -> void:
	var sm := e.sky.sky_material as ShaderMaterial if e.sky else null
	if sm == null:
		return
	for id in ["top", "mid", "horizon", "sun_col"]:
		sm.set_shader_parameter(id, _col(a[id]).lerp(_col(b[id]), f))
	sm.set_shader_parameter("sun_dir", _v3(a["sun_dir"]).lerp(_v3(b["sun_dir"]), f))
	sm.set_shader_parameter("stars", lerpf(float(a["stars"]), float(b["stars"]), f))


static func _col(hex: Variant) -> Color:
	return Color(String(hex))


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
