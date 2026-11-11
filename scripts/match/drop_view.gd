class_name DropView
extends Node3D
## What the local player sees on the way down (decision 0049, content/rules/drop.json "view", "cloud" and
## "wind"): the view widens and tips further down while you dive and eases back as the canopy opens; one
## drifting cloud sheet hangs under the ship, and crossing it is a moment of haze and a whoosh; wind streaks
## at the screen edges grow with the fall speed (one screen pass, off on the lowest quality preset).
## Match ticks it every frame. It makes itself when you board or drop and frees itself once you are down.

const HAZE_ALPHA := 0.85      # the haze at its thickest
const SHEET_SIZE := 900.0     # m across, centred on you (the shader fades it out well inside that)

var view: Dictionary = DropFeel.rules("view")
var cloud: Dictionary = DropFeel.rules("cloud")
var wind: Dictionary = DropFeel.rules("wind")
var k := 0.0                  # 0 the usual view, 1 the full dive view
var haze_t := 0.0             # s of cloud haze left
var sheet: MeshInstance3D     # the cloud sheet (null once you are through it)
var pass_mat: ShaderMaterial
var pass_rect: ColorRect

static func tick(m: Match, delta: float) -> void:
	var v: DropView = m.get_node_or_null("DropView")
	var p: Hunter = m.player
	if v == null:
		if p == null or not (p.riding or p.dropping):
			return
		v = DropView.new()
		v.name = "DropView"
		m.add_child(v)
		v._build(p.pos.y > float(v.cloud["height"]))
	v._update(m, p, delta)

func _build(with_sheet: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1               # under the HUD
	add_child(layer)
	pass_rect = ColorRect.new()
	pass_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pass_mat = ShaderMaterial.new()
	pass_mat.shader = load("res://shaders/drop_view.gdshader")
	pass_rect.material = pass_mat
	pass_rect.visible = false
	layer.add_child(pass_rect)
	if not with_sheet:
		return
	sheet = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SHEET_SIZE, SHEET_SIZE)
	sheet.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cloud_layer.gdshader")
	mat.set_shader_parameter("lit", Color(0.96, 0.97, 1.0))
	mat.set_shader_parameter("shade", Color(0.6, 0.66, 0.82))
	mat.set_shader_parameter("haze", Color(0.8, 0.85, 0.95))
	mat.set_shader_parameter("scale", cloud["scale"])
	mat.set_shader_parameter("speed", cloud["drift"])
	mat.set_shader_parameter("cover", cloud["cover"])
	mat.set_shader_parameter("alpha", cloud["alpha"])
	sheet.material_override = mat
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)

func _update(m: Match, p: Hunter, delta: float) -> void:
	var airborne := p != null and (p.riding or p.dropping) and not p.out
	var diving := airborne and p.dropping and p.diving and not DropLaunch.locked(p)
	var ease_s: float = view["widen_s"] if diving else view["back_s"]
	k = move_toward(k, float(diving), delta / ease_s)
	var e := k * k * (3.0 - 2.0 * k)
	m.cam.dive_view(float(view["widen_deg"]) * e, float(view["tilt_deg"]) * e)
	haze_t = maxf(0.0, haze_t - delta)
	if sheet != null:
		_update_sheet(m, p, airborne)
	if not airborne and k <= 0.0 and haze_t <= 0.0:
		queue_free()              # down (or out): nothing of the drop's view is left
		return
	var streak := 0.0
	if airborne and p.dropping and Settings.quality() != Settings.QUALITY_ORDER[0]:
		streak = clampf(inverse_lerp(wind["streak_from"], DropFeel.dive_fall, -p.vel.y), 0.0, 1.0)
	var haze := sin(PI * haze_t / float(cloud["haze_s"])) * HAZE_ALPHA
	pass_rect.visible = streak > 0.0 or haze > 0.0
	if pass_rect.visible:
		pass_mat.set_shader_parameter("streak", streak)
		pass_mat.set_shader_parameter("haze", haze)

## The sheet follows you until you fall through it: haze and a whoosh, and it is gone by the haze's peak.
func _update_sheet(m: Match, p: Hunter, airborne: bool) -> void:
	var h: float = cloud["height"]
	var haze_s: float = cloud["haze_s"]
	if airborne and p.pos.y >= h:
		sheet.position = Vector3(p.pos.x, h, p.pos.z)
	elif airborne and sheet.visible and haze_t <= 0.0:
		haze_t = haze_s
		m.sfx("whoosh", null, -3.0, 0.9)
	if not airborne or (haze_t > 0.0 and haze_t <= haze_s * 0.5):
		sheet.queue_free()
		sheet = null
