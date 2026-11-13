class_name ShotFloor
extends RefCounted
## A readable floor for every LMB projectile at match zoom: a hot white core and a side-coded rim that
## are never smaller than MIN_CORE_PX on screen (default camera, 720p), drawn over particles so a bolt
## never vanishes in the muzzle flash or an impact. Visual only: the hit radius (s["r"]) is untouched.
## The shot keeps its own look (plain sphere or a kit skin) and its Hunter ability colour; this is the
## beacon in its middle.

const MIN_CORE_PX := 6.0      # px across the white core, at REF_H, default camera, at the farthest point in view
const REF_H := 720.0          # px: the screen height the floor is measured at (more pixels read larger)
const STYLE := "supervive"    # the default camera preset (CamRig.STYLES)
const RIM_K := 1.8            # the rim's radius as a share of the core's
const FOE_RIM := Color("ff5a3a", 0.9)      # what can hurt you (the same tint Oomph.shot_look gives a foe's shot)
const FRIEND_RIM := Color("7fe8ff", 0.6)   # your side's shots: cool and softer, so they never hide an incoming one
const TOP := 20               # render priority: over particles and trails
const CAP := 96               # beacons at once (shots past it keep their own look)
const LAYER := 1 << 18        # the beacons' render layer, so a measuring camera can leave them out

var m: Node
var pool: Array[MeshInstance3D] = []

func _init(match_node: Node) -> void:
	m = match_node

## Radius in metres of the core for MIN_CORE_PX at REF_H with the default camera style, at the farthest a
## shot can be in view (anywhere nearer it reads larger).
static func floor_r() -> float:
	return MIN_CORE_PX * 0.5 / px_per_m(far_depth(), REF_H)

## Screen pixels per metre at view depth `depth` (metres) on a screen `h_px` tall, default camera.
static func px_per_m(depth: float, h_px: float) -> float:
	return h_px * 0.5 / (depth * tan(deg_to_rad(float(CamRig.STYLES[STYLE]["fov"])) * 0.5))

## View depth, metres, of the floor under the top edge of the default view: the farthest a shot can be
## on screen (the camera sits "rise" + dist * sin(pitch) above its focus, CamRig._apply).
static func far_depth() -> float:
	var st: Dictionary = CamRig.STYLES[STYLE]
	var half := deg_to_rad(float(st["fov"])) * 0.5
	var pitch := deg_to_rad(float(st["pitch"]))
	var high := float(st.get("rise", 0.0)) + float(st["dist"]) * sin(pitch)
	return high / sin(pitch - half) * cos(half)

## Does this shot get a beacon? Every plain LMB projectile: not a melee strike, a decoy, a mob's or a rope,
## and not an ability (those have their own tells in AbilityFx).
static func wants(s: Dictionary) -> bool:
	var x: Dictionary = s["x"]
	for skip in ["melee", "cos", "mob", "rope"]:
		if x.get(skip, false):
			return false
	return String(x.get("src", "")) != "abil"

## The drawn radius of the shot's beacon core, metres (0 when it has none).
func core_r(s: Dictionary) -> float:
	return floor_r() if wants(s) else 0.0

## Puts one beacon on each live LMB shot, at the shot's rendered position (called from Match.render).
func sync(alpha: float) -> void:
	var used := 0
	var me = m.get("player")
	for s in m.shots:
		if used >= CAP:
			break
		if not wants(s):
			continue
		var b := _beacon(used)
		used += 1
		b.visible = true
		b.global_position = (s["prev"] as Vector3).lerp(s["pos"], alpha)
		var foe: bool = me == null or (s["by"] as Ent).team != me.team
		rim_mat(b).set_shader_parameter("color", FOE_RIM if foe else FRIEND_RIM)
	for i in range(used, pool.size()):
		pool[i].visible = false

## The rim's material (the beacon's one child).
static func rim_mat(b: MeshInstance3D) -> ShaderMaterial:
	return (b.get_child(0) as MeshInstance3D).material_override as ShaderMaterial

func _beacon(i: int) -> MeshInstance3D:
	while pool.size() <= i:
		pool.append(_make())
	return pool[i]

func _make() -> MeshInstance3D:
	var r := floor_r()
	var core := MeshInstance3D.new()
	core.top_level = true
	core.mesh = Models.sphere(r, 8)
	core.material_override = _mat(Color.WHITE)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.layers = LAYER
	var rim := MeshInstance3D.new()
	rim.mesh = Models.sphere(r * RIM_K, 8)
	rim.material_override = _mat(FOE_RIM)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.layers = LAYER
	core.add_child(rim)
	m.add_child(core)
	return core

func _mat(c: Color) -> ShaderMaterial:
	var mat := Models.glow_mat(c)
	mat.render_priority = TOP
	return mat
