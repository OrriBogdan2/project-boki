class_name NpcModel
extends Node3D
## A talking NPC drawn from a rigged Meshy model (art/npcs/<id>/<id>.glb, built by tools/meshy/npc_bake.py; see
## docs/art/npcs/PIPELINE.md): the painted atlas on the hero toon shader with an ink line, a pose that picks a
## clip, a name tag, a "!" mark and a called-out bubble over the head, and a talk-box portrait. Sizes and the
## pose -> clip table: content/rules/npcs.json. Hob (HobModel) and Pell (TutorialPell) are these. Faces -Z.
## Poses: "idle", "talk", "wave", "point" (turns to point_at), "hammer", "walk"; a pose without a clip plays idle.

const PATH := "res://art/npcs/%s/%s.glb"
const TURN_RATE := 6.0         # 1/s: how fast the NPC turns to face someone
const SHOUT_S := 2.6           # s a called-out line stays over the head
const BLEND_S := 0.25          # s a pose change cross-fades
const INK_WIDTH := 0.0011      # the outline per metre of camera distance (as a rigged Boki's)
const INK_FAR_THIN := 0.5

var id := ""
var pose := "idle"
var point_at := Vector3.INF    # world point the "point" pose turns to
var face_to := Vector3.INF     # world point the NPC turns to face (INF: keeps the heading)
var tag: Label3D
var mark: Label3D
var bubble: Label3D
var anim: AnimationPlayer = null
var _spec: Dictionary = {}
var _t := 0.0
var _shout_t := 0.0
var _playing := ""

static func spec(npc_id: String) -> Dictionary:
	return Content.rules("npcs").get(npc_id, {})

static func has(npc_id: String) -> bool:
	return ResourceLoader.exists(PATH % [npc_id, npc_id])

func _init(npc_id: String, shown_name := "") -> void:
	id = npc_id
	name = npc_id.capitalize()
	_spec = spec(npc_id)
	_body()
	_labels(shown_name if shown_name != "" else String(_spec.get("name", name)))

## Calls a line out over the head for a moment ("Hey! Over here!").
func shout(line: String) -> void:
	bubble.text = line
	bubble.visible = true
	_shout_t = SHOUT_S

func height() -> float:
	return float(_spec.get("height", 1.8))

func _ready() -> void:
	_play(true)

func _process(dt: float) -> void:
	_t += dt
	_turn(dt)
	_play()
	mark.position.y = height() + 0.65 + sin(_t * 3.0) * 0.08
	if _shout_t > 0.0:
		_shout_t -= dt
		bubble.visible = _shout_t > 0.0
		tag.modulate.a = 0.0 if bubble.visible else 1.0      # (one line over the head at a time)

func _turn(dt: float) -> void:
	var at := point_at if pose == "point" and point_at.x != INF else face_to
	if at.x == INF:
		return
	var d := at - global_position
	if Vector2(d.x, d.z).length() < 0.1:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-TURN_RATE * dt))

## The pose's clip, cross-faded in when the pose changes (`now`: straight to its first frame, for the portrait).
func _play(now := false) -> void:
	if anim == null:
		return
	var clips: Dictionary = _spec.get("clips", {})
	var clip := String(clips.get(pose, clips.get("idle", "idle")))
	if clip == _playing or not anim.has_animation(clip):
		return
	_playing = clip
	anim.play(clip, 0.0 if now else BLEND_S)
	if now:
		anim.seek(0.0, true)

# ------------------------------------------------------------------ the body
func _body() -> void:
	var path := PATH % [id, id]
	if not ResourceLoader.exists(path):
		push_warning("NpcModel: no model at " + path)
		return
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.rotation.y = PI      # (a Meshy model faces +Z)
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		for si in inst.mesh.get_surface_count():
			inst.set_surface_override_material(si, _toon(inst.mesh.surface_get_material(si)))
	var ab := _rest_aabb(model)
	var s := height() / maxf(0.01, ab.size.y)
	model.scale = Vector3.ONE * s
	model.position.y = -ab.position.y * s
	ShadowPolicy.judge_tree(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for clip in anim.get_animation_list():
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

## The painted atlas on the hero toon shader, lit like a painted Hunter (WardenGlb.PAINTED), with the ink line.
static func _toon(src: Material) -> Material:
	var m := Models.toon(Color.WHITE, false)
	Models.hero_look(m)
	var tex := (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null
	m.set_shader_parameter("use_tex", tex != null)
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("vertex_ao", false)
	for k in WardenGlb.PAINTED:
		m.set_shader_parameter(k, WardenGlb.PAINTED[k])
	var ink := ShaderMaterial.new()
	ink.shader = Models.OUTLINE
	ink.set_shader_parameter("width", INK_WIDTH)
	ink.set_shader_parameter("far_thin", INK_FAR_THIN)
	m.next_pass = ink
	return m

## The model's mesh bounds in its own space, at rest. A skinned mesh draws through its bind pose (a Meshy rig's is
## 100x, under a 0.01 armature), so the mesh bounds are scaled by it.
static func _rest_aabb(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		var ab := inst.get_aabb()
		if inst.skin and inst.skin.get_bind_count() > 0:
			ab = Transform3D(Basis.from_scale(inst.skin.get_bind_pose(0).basis.get_scale()), Vector3.ZERO) * ab
		var tr := Transform3D()
		var n: Node = inst
		while n != model and n is Node3D:
			tr = (n as Node3D).transform * tr
			n = n.get_parent()
		ab = tr * ab
		out = ab if first else out.merge(ab)
		first = false
	return out

func _labels(shown_name: String) -> void:
	var h := height()
	tag = _label(shown_name, 40, Color.WHITE)
	tag.position = Vector3(0.0, h + 0.35, 0.0)
	mark = _label("!", 90, UI.GOLD)
	mark.visible = false
	bubble = _label("", 44, Color("fff4d8"))
	bubble.position = Vector3(0.0, h + 0.95, 0.0)
	bubble.visible = false

func _label(text: String, px: int, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = 0.0085
	l.outline_size = 14
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	return l

# ------------------------------------------------------------------ the portrait
## The NPC's face for the talk box: a TextureRect drawn once from the model (its SubViewport rides as its child).
static func portrait(npc: NpcModel, px: float) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(px * 2.0), int(px * 2.0))
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8a93b8")
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25, 160, 0)
	key.light_energy = 1.2
	vp.add_child(key)
	npc.set_process(false)
	vp.add_child(npc)
	npc.tag.visible = false
	var cam := Camera3D.new()
	cam.fov = 24.0
	vp.add_child(cam)
	var face := Vector3(0.0, float(npc._spec.get("face_y", 1.5)), 0.0)
	cam.transform = Transform3D(Basis(), face + Vector3(-0.35, 0.05, -1.45)).looking_at(face + Vector3(0, -0.04, 0))
	cam.current = true
	var tex := TextureRect.new()
	tex.texture = vp.get_texture()
	tex.custom_minimum_size = Vector2(px, px)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.add_child(vp)
	return tex
