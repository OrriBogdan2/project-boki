class_name DropFx
extends Node3D
## How the opening drop looks and sounds (docs/decisions/0012): each squad's comet (a
## burning orb with a long glowing trail), a contrail behind every solo diver (everyone sees both, your
## squad's in its own colours with a name tag), a cloud deck and the clouds you fall past (DropClouds), for
## the local player the rush past the screen and the wind that builds (DropWind), and everyone's glider
## snap and landing ring (DropBlasts). Purely visual: the drop itself is SkyFall, DropComet and DropCam.

static var look: Dictionary = DropData.rules["look"]
static var CLOUD_Y: float = look["cloud_y"]     # m: the cloud deck's height, between the skyship and the islands
static var RUSH_FLOAT: float = look["rush_float"]
static var RUSH_DIVE: float = look["rush_dive"]
static var DIVER_TRAIL: int = int(look["trail_pts"])    # points: ~1.5 s of contrail
const CLOUD_HOLE := 64.0       # m: the clear hole round you in the deck, so it never hides you
const TRAIL_STEP := 0.05       # s between trail points
const COMET_TRAIL := 70        # points: ~3.5 s of comet trail
const TRAIL_FADE := 3          # points a trail loses each step once it has ended (a comet's goes in ~1 s)
const COMET_R := 1.7           # m: the orb's radius (the squad rides inside)
const FAR_REDRAW := 3          # frames: a trail that isn't your squad's is redrawn this rarely
const MUSIC_DUCK_DB := -10.0   # the score under the fall
const MUSIC_HOLD_S := 1.2      # s, renewed while you fall
const SHADOW_K := 0.12         # DropCam.wide above this: no sun shadows
const TAG_K := 0.15            # DropCam.wide above this: name tags over you and your squad
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
// UV.x runs from the head (0) to the tail (1): a torn wisp, not a flat strip
void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float wisp = 0.72 + 0.28 * sin(UV.x * 26.0 - TIME * 11.0 + UV.y * 3.0) * sin(UV.x * 9.0 + TIME * 4.0);
	ALBEDO = COLOR.rgb * (0.6 + 0.8 * across);
	// faded out close to the camera, so a trail running back past the view never washes it out
	ALPHA = COLOR.a * wisp * smoothstep(0.0, 0.7, across) * smoothstep(12.0, 30.0, length(VERTEX));
}
"""

var m: Match
var _trails := {}              # key -> {pts: PackedVector3Array, t: float, mesh: ImmediateMesh, node: MeshInstance3D}
var _orbs := {}                # team -> MeshInstance3D
var _clouds: MeshInstance3D
var _cloud_mat: ShaderMaterial
var _puffs: DropClouds
var _overlay: CanvasLayer
var _rush_mat: ShaderMaterial
var _rush_rect: ColorRect
var wind: DropWind
var blasts: DropBlasts
var _flash := 0.0
var _was_above := true
var _orb_mat: ShaderMaterial
var _ribbon_mat: ShaderMaterial
var _phase := {}               # hunter nid -> 1 falling, 2 under the glider or out of a comet's burst
var _tags := {}                # hunter nid -> Label3D
var _frame := 0
var _duck_t := 0.0
var _shadows_on := true
var _shadow_lights: Array = []
var _fog_base := -1.0          # the look's fog density, held while the wide view clears it
var _wide_on := false
var rush_k := 0.0              # (read by the checks) the rush this frame

func _init(match_node: Match) -> void:
	m = match_node
	name = "DropFx"
	_orb_mat = _mat(ORB)
	_ribbon_mat = _mat(RIBBON)
	_build_clouds()
	_build_overlay()
	_puffs = DropClouds.new(m)
	add_child(_puffs)
	blasts = DropBlasts.new()
	add_child(blasts)
	wind = DropWind.new()
	add_child(wind)

func _process(delta: float) -> void:
	if m.paused:
		return
	var D := m.skydrop
	_frame += 1
	for h in m.hunters:
		_beats(h)
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
	_tag_squad()

## Each hunter's two beats, read off its state so they play for bots and for other players online alike:
## the fall ending (the glider's snap, or a comet's burst), then touching down.
func _beats(h: Hunter) -> void:
	var was := int(_phase.get(h.nid, 0))
	if h.dropping:
		_phase[h.nid] = 1
		return
	if was == 0:
		return
	if was == 1:
		_phase[h.nid] = 2
		snap(h)
	if h.grounded or h.out:
		_phase.erase(h.nid)
		if not h.out:
			land(h)

## The glider catching: a crack of air, the canopy's bang.
func snap(h: Hunter) -> void:
	blasts.snap(h.render_pos(1.0) + Vector3(0, 1.2, 0), _col(h))
	_beat_sfx("drop_snap", h)

## Touchdown: the dust ring, a burst of grit and the thud (no self-shake: item 50).
func land(h: Hunter) -> void:
	blasts.land(h.pos, _col(h))
	m.fx.dust(h.pos, 16)
	_beat_sfx("drop_land", h)

## Yours in your ears, anyone else's out in the world and quieter.
func _beat_sfx(sound: String, h: Hunter) -> void:
	if h.is_local():
		m.sfx(sound)
	else:
		m.sfx(sound, h.pos, -10.0)

## You, your squad's own colours, and everyone else a neutral pale.
func _col(h: Hunter) -> Color:
	if m.player and h.team == m.player.team:
		return Color(1.0, 0.93, 0.6) if h == m.player else m.mate_col(h)
	return Color(0.85, 0.9, 1.0)

## The local player's sky: the cloud deck with its hole round you, the puffs, the rush, the wind.
func _local(delta: float) -> void:
	var p := m.player
	var in_sky := p != null and not p.out and (p.riding or p.dropping or p.drop_glide)
	_clouds.visible = in_sky
	_puffs.visible = in_sky
	_wide_view(DropCam.wide(m, p) if p != null and p.dropping else 0.0)
	if not in_sky:
		_rush_rect.visible = false
		rush_k = 0.0
		wind.tick(0, 0.0, delta)
		return
	_cloud_mat.set_shader_parameter("hole_xz", Vector2(p.pos.x, p.pos.z))
	_cloud_mat.set_shader_parameter("hole_r", CLOUD_HOLE)
	var fall := clampf(-p.vel.y, 0.0, SkyFall.DIVE_FALL)
	var over := (fall - SkyFall.FLOAT_FALL) / (SkyFall.DIVE_FALL - SkyFall.FLOAT_FALL)
	var speed := clampf(over, 0.0, 1.0) if p.dropping else 0.0
	var above := p.pos.y > CLOUD_Y
	if _was_above and not above and p.dropping:
		_flash = 0.5
		m.sfx("drop_cloud", null, 0.0)
	if p.riding:
		above = true
	_was_above = above
	_flash = maxf(0.0, _flash - delta * 2.2)
	rush_k = (lerpf(RUSH_FLOAT, RUSH_DIVE, speed) if p.dropping else 0.0) * clampf(fall / SkyFall.FLOAT_FALL, 0.0, 1.0)
	_rush_rect.visible = rush_k > 0.01 or _flash > 0.01
	if _rush_rect.visible:
		_rush_mat.set_shader_parameter("k", rush_k)
		_rush_mat.set_shader_parameter("flash", _flash * 0.6)
		var sz := get_viewport().get_visible_rect().size
		var ahead := p.render_pos(1.0) + p.vel * 2.0
		if m.cam and not m.cam.is_position_behind(ahead) and sz.x > 0.0:
			var at := (m.cam.unproject_position(ahead) / sz).clamp(Vector2(0.2, 0.2), Vector2(0.8, 0.8))
			_rush_mat.set_shader_parameter("focus", at)
	if p.dropping:
		_duck_t -= delta
		if _duck_t <= 0.0:
			_duck_t = 1.0
			Sfx.duck(MUSIC_HOLD_S, MUSIC_DUCK_DB)      # the score leaves the sky to the wind until the glider
	var glide_stage := 2 if p.drop_glide and not p.grounded else 0
	wind.tick(1 if p.dropping else glide_stage, speed, delta)

## With the camera hundreds of metres out the match's distance fog would drown the island and the sun
## shafts (made for the low view) turn into flat slabs across the screen: both clear for the wide view.
func _wide_view(k: float) -> void:
	var on := k > 0.02
	if on != _wide_on:
		_wide_on = on
		get_tree().set_group("sky_shaft", "visible", not on)
	_shadows(k <= SHADOW_K)
	var e: Environment = m.env.environment if m.env else null
	if e == null:
		return
	if on and _fog_base < 0.0:
		_fog_base = e.fog_density
	if _fog_base >= 0.0:
		e.fog_density = _fog_base * (1.0 - clampf(k * 3.0, 0.0, 0.94))
		if not on:
			e.fog_density = _fog_base
			_fog_base = -1.0

## The whole island in the frustum at once is the wide view's cost, and from up there its sun shadows
## are a few pixels: the sun casts none while the camera is out.
func _shadows(on: bool) -> void:
	if on == _shadows_on:
		return
	_shadows_on = on
	if on:
		for l in _shadow_lights:
			if is_instance_valid(l):
				(l as DirectionalLight3D).shadow_enabled = true
		_shadow_lights.clear()
		return
	for n in m.get_children():
		if n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled:
			_shadow_lights.append(n)
			(n as DirectionalLight3D).shadow_enabled = false

## A name tag over each of your squad still in the sky (it reads when they're specks), and "You".
func _tag_squad() -> void:
	var p := m.player
	var wide := DropCam.wide(m, p) if p and p.dropping else 0.0
	for h in m.hunters:
		var tag: Label3D = _tags.get(h.nid)
		var show_it: bool = p != null and h.team == p.team and h.dropping and h.comet_lead == null and wide > TAG_K
		if not show_it:
			if tag:
				tag.visible = false
			continue
		if tag == null:
			tag = _tag(h)
			_tags[h.nid] = tag
		tag.visible = true
		tag.global_position = h.render_pos(1.0) + Vector3(0, 2.0, 0)

func _tag(h: Hunter) -> Label3D:
	var t := Label3D.new()
	t.text = "You" if h == m.player else h.pname
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.no_depth_test = true
	t.fixed_size = true
	t.pixel_size = 0.0007
	t.font_size = 26
	t.outline_size = 8
	t.modulate = _col(h)
	t.offset = Vector2(0, 26)
	add_child(t)
	return t

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
	var pulse := (1.0 + 0.05 * sin(m.time * 14.0)) * maxf(1.0, m.cam.zoom * 0.42)
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
		tr = {"pts": PackedVector3Array(), "t": 0.0, "mesh": im, "node": mi, "comet": key.begins_with("comet"),
			"col": _diver_col(key), "near": _is_squad(key)}
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
	var far_k := maxf(1.0, m.cam.zoom * 0.42) if m.cam else 1.0
	for key in _trails.keys():
		var tr: Dictionary = _trails[key]
		if not bool(tr["near"]) and (_frame + key.hash()) % FAR_REDRAW != 0:
			continue
		var im: ImmediateMesh = tr["mesh"]
		im.clear_surfaces()
		var pts: PackedVector3Array = tr["pts"]
		if pts.size() < 2:
			continue
		var comet: bool = tr["comet"]
		var diver_w := 0.75 if bool(tr["near"]) else 0.45
		# (it stays a read from the wide view, your squad's most of all: a thin line at 400 m is nothing)
		var from_afar := far_k if bool(tr["near"]) else sqrt(far_k)
		var width := (COMET_R * 1.5 if comet else diver_w) * from_afar
		var base: Color = tr["col"]
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in pts.size():
			var a := pts[maxi(0, i - 1)]
			var b := pts[mini(pts.size() - 1, i + 1)]
			var along := (b - a).normalized()
			var side := along.cross((eye - pts[i]).normalized()).normalized() * width * (1.0 - float(i) / pts.size())
			var u := float(i) / (pts.size() - 1)
			var col := _trail_col(comet, u, base)
			im.surface_set_color(col)
			im.surface_set_uv(Vector2(u, 0.0))
			im.surface_add_vertex(pts[i] + side)
			im.surface_set_color(col)
			im.surface_set_uv(Vector2(u, 1.0))
			im.surface_add_vertex(pts[i] - side)
		im.surface_end()

## A comet's trail runs white-hot to orange to a smoky ember; a contrail is a streak of `base`.
static func _trail_col(comet: bool, u: float, base: Color) -> Color:
	if comet:
		var hot := Color(1.0, 0.95, 0.7).lerp(Color(1.0, 0.5, 0.15), clampf(u * 2.5, 0.0, 1.0))
		return Color(hot.lerp(Color(0.55, 0.2, 0.25), clampf(u * 1.4 - 0.3, 0.0, 1.0)), (1.0 - u) * 0.9)
	return Color(base.lerp(Color.WHITE, 0.3 * (1.0 - u)), (1.0 - u) * base.a)

func _is_squad(key: String) -> bool:
	if key.begins_with("comet"):
		return m.player != null and key == "comet%d" % m.player.team
	var h := m.ents_by_id.get(key) as Hunter
	return h != null and m.player != null and h.team == m.player.team

func _diver_col(key: String) -> Color:
	var h := m.ents_by_id.get(key) as Hunter
	if h == null or not _is_squad(key):
		return Color(0.85, 0.93, 1.0, 0.55)
	var c := _col(h)
	c.a = 0.95
	return c

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
	_cloud_mat.set_shader_parameter("cover", 0.66)
	_cloud_mat.set_shader_parameter("alpha", 0.7)
	_cloud_mat.set_shader_parameter("hole_r", CLOUD_HOLE)
	_clouds.material_override = _cloud_mat
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.position = Vector3(m.world.w * 0.5, CLOUD_Y, m.world.h * 0.5)
	_clouds.visible = false
	add_child(_clouds)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 3
	_rush_rect = ColorRect.new()
	_rush_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rush_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rush_mat = ShaderMaterial.new()
	_rush_mat.shader = load("res://shaders/drop_rush.gdshader")
	_rush_rect.material = _rush_mat
	_rush_rect.visible = false
	_overlay.add_child(_rush_rect)
	add_child(_overlay)

static func _mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat
