class_name BreakFx
extends Node3D
## The look of things breaking, all from pools made once (no node is made per hit): each material's own
## cel debris (wood splinters, clay sherds, metal glints: the shared Hero VFX particle look), a white flash
## over a struck prop, the ground ring and the swelling glow of a lit powder keg, and the scorch left by a blast.

const DEBRIS_POOL := 8           # emitters: breaks whose debris can fly at once
const DEBRIS_CAP := 18           # bits one break throws at most (DEBRIS_POOL x this is the whole budget)
const DEBRIS_MIN := 4            # bits even the lowest quality preset keeps, so a break still reads
const DEBRIS_SPREAD := 0.45      # 0 straight up .. 1 every way
const DEBRIS_GRAVITY := 16.0     # m/s^2
const DEBRIS_DRAG := 0.6         # /s
const RING_POOL := 4
const SCORCH_POOL := 6
const SCORCH_FADE := 14.0        # seconds a scorch mark takes to fade out
const FLASH_ALPHA := 0.7         # how white a struck prop goes

var _debris: Array[GPUParticles3D] = []
var _looks := {}                 # material name -> its debris rules
var _next_debris := 0
var flying: Array = []           # debris in the air: {node, t, n}
var flying_n := 0                # bits in the air now (checks read it)
var _rings: Array[MeshInstance3D] = []
var _globes: Array[MeshInstance3D] = []
var _scorch: Array[MeshInstance3D] = []
var _next_scorch := 0
var _flash_mat: StandardMaterial3D

func _init(debris_rules: Dictionary) -> void:
	name = "BreakFx"
	_build_flash()
	_looks = debris_rules
	for i in DEBRIS_POOL:
		_debris.append(_make_debris())
	for i in RING_POOL:
		_rings.append(_make_ring())
		_globes.append(_make_globe())
	for i in SCORCH_POOL:
		_scorch.append(_make_scorch())

## Bits of `mat_name` burst out of `at`; `power` scales how many and how fast (a blast throws more). The
## quality preset thins them; returns how many flew.
func shatter(at: Vector3, mat_name: String, chunks: int, power := 1.0) -> int:
	var look: Dictionary = _looks[mat_name]
	var p := _debris[_next_debris]
	_next_debris = (_next_debris + 1) % DEBRIS_POOL
	_land(p)
	var n := clampi(int(round(chunks * power * float(Settings.q("fx")))), DEBRIS_MIN, DEBRIS_CAP)
	var pm := p.process_material as ShaderMaterial
	pm.set_shader_parameter("speed", float(look["speed"]) * power)
	pm.set_shader_parameter("size", float(look["size"]))
	var mt := (p.draw_pass_1 as QuadMesh).material as ShaderMaterial
	mt.set_shader_parameter("look", HeroVfx.LOOKS[look["look"]])
	var cols: Array = look["colors"]
	for i in 3:
		mt.set_shader_parameter(["col", "col2", "col3"][i], Color(String(cols[i])))
	p.lifetime = float(look["life"])
	p.amount_ratio = float(n) / DEBRIS_CAP
	p.global_position = at
	p.visible = true
	p.restart()
	flying.append({"node": p, "t": 0.0, "n": n})
	flying_n += n
	return n

## Ages the debris in the air; an emitter whose bits are all down is hidden for reuse.
func tick(dt: float) -> void:
	for i in range(flying.size() - 1, -1, -1):
		var e: Dictionary = flying[i]
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) >= (e["node"] as GPUParticles3D).lifetime:
			_land(e["node"])

func _land(p: GPUParticles3D) -> void:
	p.visible = false
	for e in flying:
		if e["node"] == p:
			flying_n -= int(e["n"])
			flying.erase(e)
			return

## A white flash over every mesh of a prop (a struck keg), on or off.
func flash_prop(prop: Node3D, on: bool) -> void:
	for mi in prop.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _flash_mat if on else null

## Takes a ground ring and a glow for a keg at `at`; returns them for fuse_step and release.
func arm(at: Vector3, radius: float, col: Color) -> Array:
	var ring := _free_of(_rings)
	var globe := _free_of(_globes)
	ring.mesh = Models.flat_quad(radius * 2.0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.9))
	ring.global_position = at + Vector3(0, 0.07, 0)
	ring.visible = true
	globe.global_position = at + Vector3(0, 0.45, 0)
	globe.visible = true
	(globe.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.0))
	return [ring, globe]

## The fuse at `progress` 0..1: the ring fills toward the edge and the glow swells and brightens.
func fuse_step(parts: Array, progress: float, col: Color) -> void:
	var ring: MeshInstance3D = parts[0]
	var globe: MeshInstance3D = parts[1]
	(ring.material_override as ShaderMaterial).set_shader_parameter("progress", progress)
	globe.scale = Vector3.ONE * lerpf(0.7, 2.4, progress)
	(globe.material_override as ShaderMaterial).set_shader_parameter("color", Color(col, 0.35 + 0.65 * progress))

## Gives a ring and glow back to the pool.
func release(parts: Array) -> void:
	for mi in parts:
		(mi as MeshInstance3D).visible = false

## A dark scorch on the ground under a blast, `radius` wide, fading over SCORCH_FADE seconds.
func scorch(at: Vector3, radius: float) -> void:
	var mi := _scorch[_next_scorch]
	_next_scorch = (_next_scorch + 1) % SCORCH_POOL
	var mat := mi.material_override as StandardMaterial3D
	if mi.has_meta("fade"):
		(mi.get_meta("fade") as Tween).kill()
	mat.albedo_color = Color(1, 1, 1, 1)
	mi.scale = Vector3.ONE * radius
	mi.rotation.y = randf() * TAU
	mi.global_position = at + Vector3(0, 0.05, 0)
	mi.visible = true
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, SCORCH_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.hide)
	mi.set_meta("fade", tw)

func _free_of(pool: Array[MeshInstance3D]) -> MeshInstance3D:
	for mi in pool:
		if not mi.visible:
			return mi
	return pool[0]

func _build_flash() -> void:
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.albedo_color = Color(1, 0.96, 0.85, FLASH_ALPHA)

func _make_debris() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = DEBRIS_CAP
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.visible = false
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ShaderMaterial.new()
	pm.shader = HeroVfx.MOTES
	pm.set_shader_parameter("spread", DEBRIS_SPREAD)
	pm.set_shader_parameter("gravity", DEBRIS_GRAVITY)
	pm.set_shader_parameter("drag", DEBRIS_DRAG)
	pm.set_shader_parameter("curl", 0.0)
	p.process_material = pm
	var quad := QuadMesh.new()
	var mt := ShaderMaterial.new()
	mt.shader = HeroVfx.MOTE
	quad.material = mt
	p.draw_pass_1 = quad
	add_child(p)
	return p

func _make_ring() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/telegraph.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _make_globe() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.sphere(0.5, 10)
	mi.material_override = Models.glow_mat(Color.WHITE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _make_scorch() -> MeshInstance3D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var g := Gradient.new()
	var soot := Color(0.05, 0.03, 0.03)
	g.colors = PackedColorArray([Color(soot, 0.85), Color(soot, 0.55), Color(soot, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	tex.gradient = g
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = Models.flat_quad(2.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi
