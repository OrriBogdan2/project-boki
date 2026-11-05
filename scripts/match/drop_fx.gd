class_name DropFx
extends Node3D
## How the opening drop looks and sounds (docs/decisions/0012): each squad's comet (a burning orb with
## a long glowing trail), a contrail behind every solo diver (everyone sees both), a cloud layer you
## punch through, and for the local player speed lines and wind that rise with the dive, and the
## camera pulled back over the islands. Purely visual: the drop itself is SkyFall and DropComet.

const CLOUD_Y := 82.0          # m: the cloud layer's height, between the skyship and the islands
const CLOUD_HOLE := 16.0       # m: the clear hole round you in it, so the clouds never hide you
const TRAIL_STEP := 0.05       # s between trail points
const COMET_TRAIL := 70        # points: ~3.5 s of comet trail
const DIVER_TRAIL := 30        # points: ~1.5 s of contrail
const TRAIL_FADE := 3          # points a trail loses each step once it has ended (a comet's goes in ~1 s)
const COMET_R := 1.7           # m: the orb's radius (the squad rides inside)
const FREEFALL_CHASE := 0.55   # how far the camera drops behind you high up (CamRig.chase: ~45 degrees down)
const SPEED_LINES := """
shader_type canvas_item;
// k: the speed lines 0..1 (the dive), flash: the white of punching through the clouds 0..1
uniform float k = 0.0;
uniform float flash = 0.0;
float hash(float n) {
	return fract(sin(n * 91.7) * 43758.55);
}
void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 d = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float r = length(d);
	float spoke = floor((atan(d.y, d.x) + 3.1416) * 30.0);
	float on = step(0.7, hash(spoke));
	float run = fract(r * 2.2 + TIME * (2.0 + 3.0 * hash(spoke + 7.0)) + hash(spoke + 3.0));
	float streak = on * smoothstep(0.0, 0.25, run) * (1.0 - smoothstep(0.35, 0.6, run));
	float edge = smoothstep(0.22, 0.7, r);
	float a = streak * edge * k * 0.5 + flash * (0.55 + 0.45 * r);
	COLOR = vec4(1.0, 1.0, 1.0, clamp(a, 0.0, 1.0));
}
"""
const ORB := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform vec4 core : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.78, 0.35, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.97, 0.85, 1.0);
varying float front;
void vertex() {
	front = clamp(-VERTEX.z / 1.7, 0.0, 1.0);
}
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float flick = 0.8 + 0.2 * sin(TIME * 23.0 + UV.y * 40.0 + UV.x * 17.0);
	float lead = pow(front, 3.0);
	ALBEDO = mix(mix(core.rgb, rim.rgb, f), hot.rgb, lead * 0.8) * flick;
	ALPHA = clamp(0.1 + 0.85 * f + 0.4 * lead, 0.0, 0.95);
}
"""
const RIBBON := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = COLOR.rgb * (0.6 + 0.8 * across);
	// faded out close to the camera, so a trail running back past the view never washes it out
	ALPHA = COLOR.a * smoothstep(0.0, 0.7, across) * smoothstep(12.0, 30.0, length(VERTEX));
}
"""

var m: Match
var _trails := {}              # key -> {pts: PackedVector3Array, t: float, mesh: ImmediateMesh, node: MeshInstance3D}
var _orbs := {}                # team -> MeshInstance3D
var _clouds: MeshInstance3D
var _cloud_mat: ShaderMaterial
var _overlay: CanvasLayer
var _lines_mat: ShaderMaterial
var _wind: AudioStreamPlayer
var _flash := 0.0
var _was_above := true
var _orb_mat: ShaderMaterial
var _ribbon_mat: ShaderMaterial
var _lines_rect: ColorRect

func _init(match_node: Match) -> void:
	m = match_node
	name = "DropFx"
	_orb_mat = _mat(ORB)
	_ribbon_mat = _mat(RIBBON)
	_build_clouds()
	_build_overlay()

## The camera in the freefall: behind you along your heading (so forward is up) and looking ahead
## and down over the islands, so high up the whole Hollow Crown spreads out in front of you; it
## settles into the usual view as you near the ground. Recording mode pulls further back.
static func frame_freefall(match_node: Match, p: Hunter) -> void:
	var cam := match_node.cam
	var steer: Hunter = p.comet_lead if p.comet_lead else p
	if steer.fall_dir.length() > 0.01:
		cam.yaw_to = atan2(-steer.fall_dir.x, -steer.fall_dir.y)
	var hk := clampf(SkyFall.height_over(match_node.world, p.pos) / SkyFall.SKY_Y, 0.0, 1.0)
	var far := smoothstep(0.12, 0.5, hk)
	cam.top_to = 0.0
	cam.chase_to = FREEFALL_CHASE * far * (1.2 if Record.clean() else 1.0)
	cam.zoom_to = lerpf(1.1, 1.55, far) * lerpf(1.0, 1.9 if Record.clean() else 1.0, far)

func _process(delta: float) -> void:
	if m.paused:
		return
	var D := m.skydrop
	for h in m.hunters:
		var falls: bool = h.dropping and h.comet_lead == null and not (D and D.comet.leads(h))
		_trail(h.nid, falls and h.visible, h.render_pos(1.0) + Vector3(0, 0.9, 0), DIVER_TRAIL, delta)
	var teams := _orbs.duplicate()
	if D:
		teams.merge(D.comet.comets)
	for t in teams:
		var l: Hunter = D.comet.comets[t]["lead"] if D and D.comet.comets.has(t) else null
		_orb(t, l)
		var at := l.render_pos(1.0) + Vector3(0, 0.9, 0) if l else Vector3.ZERO
		_trail("comet%d" % t, l != null, at, COMET_TRAIL, delta)
	_draw_trails()
	_local(delta)

## The local player's sky: the cloud layer with its hole round you, the speed lines, the wind.
func _local(delta: float) -> void:
	var p := m.player
	var in_sky := p != null and not p.out and (p.riding or p.dropping or p.drop_glide)
	_clouds.visible = in_sky
	if not in_sky:
		_lines_rect.visible = false
		if _wind and _wind.playing: _wind.stop()
		return
	_cloud_mat.set_shader_parameter("hole_xz", Vector2(p.pos.x, p.pos.z))
	var fall := clampf(-p.vel.y, 0.0, SkyFall.DIVE_FALL)
	var calm := SkyFall.FLOAT_FALL + 1.0       # m/s: no speed lines while floating
	var dive_k := clampf((fall - calm) / (SkyFall.DIVE_FALL - calm), 0.0, 1.0) if p.dropping else 0.0
	var above := p.pos.y > CLOUD_Y
	if _was_above and not above and p.dropping:
		_flash = 1.0
		m.sfx("whoosh", null, -3.0, 0.7)
		m.fx.burst(p.pos + Vector3(0, 1.0, 0), Color(1, 1, 1, 0.8), 30, 9.0, 0.7, 0.0, 4.0)
	_was_above = above
	_flash = maxf(0.0, _flash - delta * 2.2)
	var lines_k := dive_k * (0.0 if Record.cinema() else 1.0)
	_lines_rect.visible = lines_k > 0.01 or _flash > 0.01
	_lines_mat.set_shader_parameter("k", lines_k)
	_lines_mat.set_shader_parameter("flash", _flash * 0.6)
	_wind_at(p.dropping, dive_k, fall)

func _wind_at(on: bool, dive_k: float, fall: float) -> void:
	if not on:
		if _wind and _wind.playing: _wind.stop()
		return
	if _wind == null:
		_wind = AudioStreamPlayer.new()
		_wind.bus = "SFX"
		var st := load("res://audio/br_wind.wav") as AudioStreamWAV
		if st:
			st = st.duplicate() as AudioStreamWAV
			st.loop_mode = AudioStreamWAV.LOOP_PINGPONG
			st.loop_end = int(st.get_length() * st.mix_rate)
			_wind.stream = st
		add_child(_wind)
	if not _wind.playing and _wind.stream:
		_wind.play()
	_wind.volume_db = lerpf(-24.0, -8.0, clampf(fall / SkyFall.DIVE_FALL, 0.0, 1.0))
	_wind.pitch_scale = lerpf(0.55, 0.95, dive_k)

# ------------------------------------------------------------------ the comet and the trails
func _orb(team: int, l: Hunter) -> void:
	var orb: MeshInstance3D = _orbs.get(team)
	if l == null:
		if orb: orb.visible = false
		return
	if orb == null:
		orb = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = COMET_R
		sm.height = COMET_R * 2.0
		orb.mesh = sm
		orb.material_override = _orb_mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb)
		_orbs[team] = orb
	orb.visible = true
	orb.global_position = l.render_pos(1.0) + Vector3(0, 0.9, 0)
	var pulse := 1.0 + 0.05 * sin(m.time * 14.0)
	var v := l.vel.length()
	# stretched a little along its flight, like something burning in
	orb.scale = Vector3(pulse, pulse, pulse * (1.0 + clampf(v / 40.0, 0.0, 0.5)))
	if v > 0.5:
		var ahead := l.vel.normalized()
		orb.look_at(orb.global_position + ahead, Vector3.UP if absf(ahead.y) < 0.98 else Vector3.RIGHT)

## Records a trail point for `key` (while `on`), and lets the trail shrink away once it's off.
func _trail(key: String, on: bool, at: Vector3, max_pts: int, delta: float) -> void:
	var tr: Dictionary = _trails.get(key, {})
	if tr.is_empty():
		if not on:
			return
		var im := ImmediateMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = _ribbon_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		tr = {"pts": PackedVector3Array(), "t": 0.0, "mesh": im, "node": mi, "comet": key.begins_with("comet")}
		_trails[key] = tr
	tr["t"] = float(tr["t"]) + delta
	var pts: PackedVector3Array = tr["pts"]
	if float(tr["t"]) < TRAIL_STEP:
		if on and pts.size() > 0:
			pts[0] = at
			tr["pts"] = pts
		return
	tr["t"] = 0.0
	if on:
		pts.insert(0, at)
	elif pts.size() > 0:
		pts.resize(maxi(0, pts.size() - TRAIL_FADE))
	else:
		(tr["node"] as Node).queue_free()      # (gone: nothing left to draw)
		_trails.erase(key)
		return
	while pts.size() > max_pts:
		pts.remove_at(pts.size() - 1)
	tr["pts"] = pts

func _draw_trails() -> void:
	var eye := m.cam.global_position if m.cam else Vector3.UP * 100.0
	for key in _trails.keys():
		var tr: Dictionary = _trails[key]
		var im: ImmediateMesh = tr["mesh"]
		im.clear_surfaces()
		var pts: PackedVector3Array = tr["pts"]
		if pts.size() < 2:
			continue
		var comet: bool = tr["comet"]
		var width := COMET_R * 1.5 if comet else 0.45
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var a := pts[maxi(0, i - 1)]
			var b := pts[mini(pts.size() - 1, i + 1)]
			var along := (b - a).normalized()
			var side := along.cross((eye - pts[i]).normalized()).normalized() * width * (1.0 - float(i) / pts.size())
			var u := float(i) / (pts.size() - 1)
			var col := _trail_col(comet, u)
			im.surface_set_color(col)
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(pts[i] + side)
			im.surface_set_color(col)
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(pts[i] - side)
		im.surface_end()

## A comet's trail runs white-hot to orange to a smoky ember; a contrail is a pale streak.
static func _trail_col(comet: bool, u: float) -> Color:
	if comet:
		var hot := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.5, 0.15), clampf(u * 2.5, 0.0, 1.0))
		return Color(hot.lerp(Color(0.55, 0.2, 0.25), clampf(u * 1.4 - 0.3, 0.0, 1.0)), (1.0 - u) * 0.9)
	return Color(0.85, 0.93, 1.0, (1.0 - u) * 0.55)

# ------------------------------------------------------------------ building
func _build_clouds() -> void:
	_clouds = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400.0, 1400.0)
	_clouds.mesh = pm
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = load("res://shaders/cloud_layer.gdshader")
	_cloud_mat.set_shader_parameter("lit", Color(1.0, 0.99, 0.97))
	_cloud_mat.set_shader_parameter("shade", Color(0.66, 0.72, 0.86))
	_cloud_mat.set_shader_parameter("rim", Color("ffe2c4"))
	_cloud_mat.set_shader_parameter("haze", Color(0.78, 0.84, 0.95))
	_cloud_mat.set_shader_parameter("scale", 0.022)
	_cloud_mat.set_shader_parameter("cover", 0.58)
	_cloud_mat.set_shader_parameter("alpha", 0.82)
	_cloud_mat.set_shader_parameter("hole_r", CLOUD_HOLE)
	_clouds.material_override = _cloud_mat
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.position = Vector3(m.world.w * 0.5, CLOUD_Y, m.world.h * 0.5)
	_clouds.visible = false
	add_child(_clouds)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 3
	_lines_rect = ColorRect.new()
	_lines_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines_mat = _mat(SPEED_LINES)
	_lines_rect.material = _lines_mat
	_lines_rect.visible = false
	_overlay.add_child(_lines_rect)
	add_child(_overlay)

static func _mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat
