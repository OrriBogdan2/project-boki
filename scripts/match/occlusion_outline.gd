class_name OcclusionOutline
extends RefCounted
## Keeps Hunters and their Bokis readable behind a cliff, a tree or an arch from the top-down camera: a thin
## side-colour line (shaders/occlusion_outline.gdshader, SideColor: you, your squad, red for rivals) that
## shows only where cover hides them. As in the source: you and your squad always; a rival only while your
## side can see them (not `unseen`), so it is no wallhack. A material overlay on each model's meshes: no
## extra nodes, one extra pass over a few meshes. Off on Low (Settings.QUALITY "occ").

static var _mats := {}    # side colour -> its overlay material
static var _shader: Shader = preload("res://shaders/occlusion_outline.gdshader")

## Every frame from the match: puts the overlay on a model that should wear it and takes it off one that
## should not. Cheap when nothing changed: one meta read per Hunter and Boki, no allocation.
static func for_match(m) -> void:
	var p: Hunter = m.player
	if p == null:
		return
	var on: bool = Settings.q("occ")
	for h in m.hunters:
		_sync(h, h.model, on and (h.team == p.team or not h.unseen), SideColor.of(m, h))
	for k in m.kins:
		var o: Hunter = k.owner_h
		if o != null:
			_sync(k, k.model, on and (o.team == p.team or not k.unseen), SideColor.of(m, k))

static func _sync(e: Node, model: Node3D, on: bool, tint: Color) -> void:
	var tag := (model.get_instance_id() ^ tint.to_rgba32()) if model and on else 0
	if int(e.get_meta("occ", 0)) == tag:
		return
	e.set_meta("occ", tag)
	if model == null:
		return
	var mat := _material(tint) if on else null
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		# not the blob shadow, rings or aura shells: they cast no shadow
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			mi.material_overlay = mat

static func _material(tint: Color) -> ShaderMaterial:
	if not _mats.has(tint):
		var sm := ShaderMaterial.new()
		sm.shader = _shader
		sm.set_shader_parameter("color", tint)
		_mats[tint] = sm
	return _mats[tint]
