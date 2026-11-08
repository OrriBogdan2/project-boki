class_name MaskRelic
extends Node3D
## A Relic as a thing in the world (lore: briefs/LORE_MASKS.md): a cracked porcelain face, mended with gold,
## that carries a fallen Hunter's soul, glowing in its Hunter's colour and trailing motes as it drifts. It
## bobs where it hovers and turns to face whoever it is drifting toward. Used by the Relic moments
## (MaskMoment: the first Relic after naming your Boki; HobOffer: the second, from Hob on the farm). MaskBeat
## puts it on.
# "mask" in code = "Relic" in game, owner 2026-11-07

const BOB_HZ := 0.35           # bobs a second
const BOB_M := 0.06            # m up and down
const PLATE_R := 0.25          # m: the plate's curve, a hair over a head (HeroKit.head is 0.235)
const FLOAT_SCALE := 1.3       # x while it floats free, so it reads from across the island

var id := ""
var hover_at := Vector3.ZERO   # where it rests and bobs (drift_to moves it)
var face_to := Vector3.ZERO    # the point it turns to face
var bobbing := true
var plate: Node3D
var light: OmniLight3D
var motes: CPUParticles3D
var _t := 0.0

static func make(hunter_id: String) -> MaskRelic:
	var r := MaskRelic.new()
	r.id = hunter_id
	return r

func _ready() -> void:
	var col := Arch.color(id)
	plate = Node3D.new()
	add_child(plate)
	var porcelain := Models.shiny(Color("f4efe6"), 0.7)
	porcelain.set_shader_parameter("glow", 0.25)      # it gives off a little light of its own
	Models.part(plate, plate_mesh(), porcelain, Vector3.ZERO)
	var aura := Models.part(plate, plate_mesh(), Models.toon(col.lightened(0.1), false, 1.6), Vector3(0, 0, 0.03),
			Vector3(1.14, 1.1, 1.0))      # a rim of the Hunter's colour round the face
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dark := Models.toon(Color("1a1424"), false)
	for sx in [-1.0, 1.0]:
		Models.part(plate, Models.sphere(0.045, 12), dark, _on_plate(0.36 * sx, 0.14, 0.004), Vector3(1.6, 0.6, 0.4))
	var gold := Models.shiny(Color("dcaa48"), 0.8)
	for k in 3:
		var a := _on_plate(-0.1 + 0.12 * k, 0.45 - 0.28 * k, 0.003)
		var b := _on_plate(-0.02 + 0.12 * k, 0.2 - 0.28 * k, 0.003)
		Models.part(plate, Models.box(0.008, 0.008, a.distance_to(b)), gold, (a + b) * 0.5, Vector3.ONE,
				Basis.looking_at((b - a).normalized(), Vector3.FORWARD).get_euler())
	_accent(col)
	var halo := MeshInstance3D.new()
	halo.mesh = Models.sphere(0.42, 16)
	halo.material_override = Models.glow_mat(Color(col.lightened(0.2), 0.22))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	light = OmniLight3D.new()
	light.light_color = col.lerp(Color.WHITE, 0.25)
	light.light_energy = 2.4
	light.omni_range = 5.0
	add_child(light)
	motes = _trail(col)
	add_child(motes)
	hover_at = position
	scale = Vector3.ONE * FLOAT_SCALE

## The Hunter's own relic on the plate: Vex's brass eye, else a band of the Hunter's colour across the brow.
func _accent(col: Color) -> void:
	if id == "gunslinger":
		var brass := Models.shiny(Color("c79a4a"), 0.85)
		var eye := _on_plate(0.36, 0.14, 0.012)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.034
		ring.outer_radius = 0.05
		Models.part(plate, ring, brass, eye, Vector3.ONE, Vector3(PI / 2, 0, 0))
		var lens := Models.toon(col.lightened(0.2), false, 1.6)
		Models.part(plate, Models.sphere(0.03, 12), lens, eye, Vector3(1, 1, 0.5))
		return
	for k in 7:
		var at := _on_plate(-0.6 + 0.2 * k, 0.45 - 0.05 * absf(k - 3), 0.006)
		Models.part(plate, Models.sphere(0.04, 8), Models.toon(col, false, 1.4), at, Vector3(1.8, 0.7, 0.4))

## A point on the plate: x and y across it in -1..1 (y up), `lift` m off the surface.
func _on_plate(x: float, y: float, lift: float) -> Vector3:
	var th := x * 0.8
	var ph := y * 0.85 - 0.1
	return Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph)) * (PLATE_R + lift) + Vector3(0, 0, PLATE_R)

## The porcelain plate: a curved face, broad at the brow, narrowing to the chin, centred on the origin.
static func plate_mesh() -> ArrayMesh:
	var fn := func(u: float, v: float) -> Vector3:
		var ph := lerpf(0.75, -0.95, v)
		var narrow := (1.0 - 0.38 * smoothstep(-0.2, -0.95, ph)) * (1.0 - 0.32 * smoothstep(0.3, 0.75, ph))
		var th := lerpf(-0.8, 0.8, u) * narrow
		return Vector3(sin(th) * cos(ph), sin(ph), -cos(th) * cos(ph)) * PLATE_R + Vector3(0, 0, PLATE_R)
	return HeroKit.shell("mask_plate", fn, 20, 18, 0.016)

func _trail(col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.3
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(col.lightened(0.5), 1.0))
	fade.set_color(1, Color(col, 0.0))
	p.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.018
	dot.height = 0.036
	dot.radial_segments = 6
	dot.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dot.material = mat
	p.mesh = dot
	return p

func _process(dt: float) -> void:
	_t += dt
	if bobbing:
		position = position.lerp(hover_at + Vector3(0, sin(_t * TAU * BOB_HZ) * BOB_M, 0), 1.0 - exp(-4.0 * dt))
	var to := face_to - global_position
	if to.length() > 0.05:
		var want := Quaternion(Basis.looking_at(to.normalized(), Vector3.UP))
		quaternion = quaternion.slerp(want, 1.0 - exp(-5.0 * dt))
	light.light_energy = 2.2 + 0.4 * sin(_t * 3.1)

## Drifts to `at` along a gentle arc over `secs`, then rests there.
func drift_to(at: Vector3, secs: float, rise := 0.8) -> Tween:
	bobbing = false
	var from := position
	var tw := create_tween()
	tw.tween_method(func(k: float):
		position = from.lerp(at, k) + Vector3(0, sin(k * PI) * rise, 0), 0.0, 1.0, secs)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		hover_at = at
		bobbing = true)
	return tw
