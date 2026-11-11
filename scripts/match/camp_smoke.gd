class_name CampSmoke
extends Node3D
## From the air, every live camp sends up a thin smoke column to steer at: one unshaded billboard quad
## per camp (1, 2 or 3 strands by size, orange in the hot zone), no particles, no lights. Built when the
## local player's drop starts, shown within SEE_R m, freed LINGER s after they land. A camp the squad
## sees as cleared (SpawnPlan.camp_state_for) sends no smoke.

const SEE_R := 160.0      # m: the farthest a column shows
const LINGER := 5.0       # s after landing before the columns are freed
const MAX_QUADS := 28     # camps get a column up to this many (the 2x map has 28)
const HEIGHT := 70.0      # m: how tall a column stands
const WIDTH := 3.0        # m of quad per strand
const HOT_COL := Color("ff8a3a")
const SMOKE_COL := Color("c9cdd6")

static var _tex := {}     # strands -> ImageTexture

var m: Match
var quads: Array = []     # {node: MeshInstance3D, cand: Dictionary}
var _landed_t := -1.0     # s since the player landed (-1: still up, or not dropping yet)
var _look_t := 0.0

func _init(match_node: Match) -> void:
	m = match_node

func _ready() -> void:
	for strands in [1, 2, 3]:
		_texture(strands)       # drawn now, under the loading screen, not as the drop starts

func _process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	var p := m.player
	if p == null or m.spawn_plan == null:
		return
	if p.dropping:
		_landed_t = 0.0
		if quads.is_empty():
			_build()
	elif _landed_t >= 0.0:
		_landed_t += dt
		if _landed_t >= LINGER:
			_free()
			_landed_t = -1.0
			return
	_look_t -= dt
	if _look_t <= 0.0:
		_look_t = 0.2
		for q in quads:
			var at: Vector3 = q["cand"]["pos"]
			q["node"].visible = Vector2(at.x - p.pos.x, at.z - p.pos.z).length() <= SEE_R \
				and m.spawn_plan.camp_state_for(q["cand"], p.team) == "active"

func _build() -> void:
	var hot: int = m.biomes.hot.hot if m.biomes else -1
	for c in m.spawn_plan.of("camp").slice(0, MAX_QUADS):
		var strands := mini(int(String(c["shape"]).substr(4)), 3)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = _texture(strands)
		mat.albedo_color = HOT_COL if c["region"] == hot else SMOKE_COL
		var quad := QuadMesh.new()
		quad.size = Vector2(WIDTH * strands, HEIGHT)
		quad.material = mat
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		add_child(node)
		node.global_position = (c["pos"] as Vector3) + Vector3(0, HEIGHT * 0.5, 0)
		quads.append({"node": node, "cand": c})
	_look_t = 0.0

func _free() -> void:
	for q in quads:
		q["node"].queue_free()
	quads.clear()

## A column of `strands` wavy lines that fade out toward the top.
static func _texture(strands: int) -> ImageTexture:
	if _tex.has(strands):
		return _tex[strands]
	var w := 32 * strands
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var up := float(y) / float(h)        # 0 at the top, 1 at the ground
		for s in strands:
			var cx := (s + 0.5) * 32.0 + sin(up * 9.0 + s * 2.0) * 3.0
			for x in w:
				var a := clampf(1.0 - absf(x - cx) / 3.0, 0.0, 1.0) * up * 0.85
				if a > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, maxf(img.get_pixel(x, y).a, a)))
	_tex[strands] = ImageTexture.create_from_image(img)
	return _tex[strands]
