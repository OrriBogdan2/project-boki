class_name PipStars
extends RefCounted
## Pip's gold constellations (the emission layer of art/wardens/pip): they rest faint and brighten while she heals. The
## kit calls pulse() on each heal tick; the glow falls back by itself, nothing runs between pulses.

const PEAK := 3.2        # the layer's emission at the top of a pulse
const FADE := 0.8        # s back to rest
const TWEEN := "pip_stars_tween"
const REST := "pip_stars_rest"

static func pulse(h: Hunter) -> void:
	var model := h.model as Node3D
	if model == null or not model.is_inside_tree():
		return
	var mats: Array = (model.get_meta("mats", []) as Array).filter(func(x):
		return x is ShaderMaterial and (x as ShaderMaterial).get_shader_parameter("use_emit") == true)
	if mats.is_empty():
		return
	if not model.has_meta(REST):
		model.set_meta(REST, float((mats[0] as ShaderMaterial).get_shader_parameter("emit")))
	var old = model.get_meta(TWEEN) if model.has_meta(TWEEN) else null     # (a null default still logs an error)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := model.create_tween()
	tw.tween_method(_apply.bind(mats), PEAK, float(model.get_meta(REST)), FADE)
	model.set_meta(TWEEN, tw)

static func _apply(v: float, mats: Array) -> void:
	for x in mats:
		(x as ShaderMaterial).set_shader_parameter("emit", v)
