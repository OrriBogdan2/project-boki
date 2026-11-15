class_name FxGround
extends Node
## The match's tile heights for the Compatibility renderer's soft effect edges (shaders/soft_fade.gdshaderinc):
## shared as the fx_ground globals while the World holding it is in the tree, switched off when it leaves.

var tex: Texture2D
var map_tiles: Vector2     # the map in tiles (1 m each)

func _init(height_tex: Texture2D, map_size: Vector2) -> void:
	tex = height_tex
	map_tiles = map_size

func _enter_tree() -> void:
	RenderingServer.global_shader_parameter_set("fx_ground", tex)
	RenderingServer.global_shader_parameter_set("fx_ground_size", Vector3(map_tiles.x, map_tiles.y, 1.0))

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("fx_ground_size", Vector3.ZERO)
