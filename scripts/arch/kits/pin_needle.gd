class_name PinNeedle
extends Node3D
## Lisette's Heavy Shot in her hands: an oversized silver needle nocked on the bow while she holds RMB, drawn
## back as it charges, glowing orchid with the charge, its orchid thread trailing from the eye. World space along
## the aim, at bow height, so it reads the same on any body and any pose. Everyone sees it (it's her wind-up).
## The materials are the toon and glow shaders every Hunter already draws, so it adds no shader compile.

const LENGTH := 2.6            # m, tip to eye (a loosed arrow is about 0.8)
const RADIUS := 0.09           # m at the eye end, so it holds at the match camera
const HEIGHT := 1.12           # m above her feet, x her scale
const NOCK_AT := 0.5           # m ahead of her where the bow holds it
const DRAW_BACK := Vector2(0.35, 0.95)  # m the eye sits behind the bow: as nocked, fully drawn
const NOCK_T := 0.12           # s to slide on
const SHELL := 1.9             # x the shaft: the glow around it
const SILVER := Color("e4ebf2")
const THREAD_N := 9            # thread segments
const THREAD_SEG := 0.26       # m each
const THREAD_R := 0.07         # m half width (holds at the match camera)
const THREAD_DROOP := 1.2      # m/s it sags behind the eye
const GLOW_A := Vector2(0.1, 0.85)  # the shell's alpha at no charge and full
const HOT_K := 0.7             # how far the steel itself reddens at full charge

var shell: MeshInstance3D
var shell_mat: ShaderMaterial
var steel: ShaderMaterial
var links: Array = []          # the thread's segments
var points: Array = []         # the thread's joints, world space, [0] at the eye
var eye := Vector3.ZERO        # where the eye is now (world)
var tip := Vector3.ZERO        # where the point is now (world)
var charge := 0.0              # the charge shown, 0..1 (checks read it)
var _in := 0.0                 # s since it was nocked

func _init() -> void:
	top_level = true
	visible = false
	name = "PinNeedle"
	steel = Models.toon(SILVER, true, 0.25)
	_flat(_lie(KitMeshes.inst(self, _taper(0.01, RADIUS, LENGTH), steel), LENGTH))
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS * 0.8
	ring.outer_radius = RADIUS * 1.7
	var eye_node := KitMeshes.inst(self, ring, steel)
	eye_node.rotation = Vector3(0, 0, PI * 0.5)
	eye_node.scale = Vector3(1.0, 1.0, 1.7)
	_flat(eye_node)
	shell_mat = Models.glow_mat(Color(PinFx.THREAD, GLOW_A.x))
	shell = _lie(KitMeshes.inst(self, _taper(0.02, RADIUS * SHELL, LENGTH * 1.03), shell_mat), LENGTH * 1.03)
	_flat(shell)
	var thread := Models.toon(PinFx.THREAD, false, 0.7)
	for i in THREAD_N:
		var link := MeshInstance3D.new()
		link.mesh = Models.box(THREAD_R * 2.0, THREAD_R * 2.0, 1.0)
		link.material_override = thread
		_flat(link).top_level = true
		add_child(link)
		links.append(link)
		points.append(Vector3.ZERO)

func _taper(top: float, foot: float, len_: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = foot
	c.height = len_
	c.radial_segments = 8
	c.rings = 1
	return c

## A cylinder stands centred on its +Y: lay it along -Z with its foot (the eye end) at the origin.
func _lie(mi: MeshInstance3D, len_: float) -> MeshInstance3D:
	mi.rotation = Vector3(-PI * 0.5, 0, 0)
	mi.position = Vector3(0, 0, -len_ * 0.5)
	return mi

## KitMeshes.inst hands back a pool piece (top level, hidden): this one rides the needle.
func _flat(mi: MeshInstance3D) -> MeshInstance3D:
	mi.top_level = false
	mi.visible = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Every step while it's held: at `at` (her feet), along `dir`, charged `k` 0..1; `sc` is her scale.
func hold(at: Vector3, dir: Vector2, k: float, sc: float, dt: float) -> void:
	var nocking := not visible
	visible = true
	_in = 0.0 if nocking else _in + dt
	charge = k
	var d := Vector3(dir.x, 0, dir.y).normalized()
	var slide := clampf(_in / NOCK_T, 0.0, 1.0)
	var back := lerpf(DRAW_BACK.x, DRAW_BACK.y, k) * slide
	eye = at + Vector3(0, HEIGHT * sc, 0) + d * (NOCK_AT - back)
	tip = eye + d * LENGTH * sc
	global_position = eye
	look_at(tip, Vector3.UP, false)
	scale = Vector3.ONE * sc
	var pulse := 0.1 * sin(Time.get_ticks_msec() * 0.018) if k >= 0.99 else 0.0
	shell_mat.set_shader_parameter("color", Color(PinFx.THREAD, lerpf(GLOW_A.x, GLOW_A.y, k) + pulse))
	steel.set_shader_parameter("albedo", SILVER.lerp(PinFx.THREAD, HOT_K * k))
	steel.set_shader_parameter("glow", lerpf(0.25, 0.4, k) + pulse)
	_thread(d, dt, nocking)

## The thread hangs from the eye and lags behind it.
func _thread(d: Vector3, dt: float, snap: bool) -> void:
	points[0] = eye
	for i in range(1, points.size()):
		var prev: Vector3 = points[i - 1]
		var p: Vector3 = prev - d * THREAD_SEG if snap else points[i]
		p += Vector3(0, -THREAD_DROOP * dt, 0)
		p.y = maxf(p.y, global_position.y - 0.45)
		var off := p - prev
		points[i] = prev + off.normalized() * THREAD_SEG
	for i in links.size():
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1] if i + 1 < points.size() else a - d * THREAD_SEG
		var link: MeshInstance3D = links[i]
		link.global_position = (a + b) * 0.5
		link.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT)
		link.scale = Vector3(1.0, 1.0, a.distance_to(b))

## Not held: nothing shows.
func put_away() -> void:
	visible = false
	charge = 0.0
