class_name KeyGlint
extends Node3D
## The small key hovering over a monster that carries one: it turns and bobs, and a bright star
## winks on it every second or so, so a key carrier can be picked out of a crowd. Hidden while a
## Shrubling is still disguised (the glint would give it away).

var _t := 0.0
var _star: Node3D = null
var _key: Node3D = null

func _init() -> void:
	name = "KeyGlint"
	_key = KeyModels.key(0.7, false)
	add_child(_key)
	var halo := MeshInstance3D.new()
	halo.mesh = Models.flat_quad(0.9)
	halo.material_override = Models.ring_mat(Color(KeyModels.BRASS, 0.8), 0.1)
	halo.position.y = 0.2
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_star = Models.icon_badge("ckey", 0.28, 0.55)
	add_child(_star)

func _process(delta: float) -> void:
	_t += delta
	_key.rotation.y += delta * 2.4
	position.y = _base_h + sin(_t * 2.6) * 0.07
	var wink := maxf(0.0, sin(_t * 4.4 - 1.2))
	_star.scale = Vector3.ONE * (0.8 + wink * 0.5)

var _base_h := 1.9

func set_height(h: float) -> void:
	_base_h = h
	position.y = h
