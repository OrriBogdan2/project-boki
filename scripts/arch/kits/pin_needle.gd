class_name PinNeedle
extends Node3D
## Lisette's Heavy Shot in her hands: an oversized silver needle nocked on the bow while she holds RMB,
## glowing red with the charge, its red thread trailing from the eye. Its eye rides the model's nock anchor
## (her draw hand, HeroVfx "nock"), so the animation's pull-back is the needle's and the shot leaves the bow
## it lies on; it points along the aim. Everyone sees it (it's her wind-up).
## It spins out of a twist of red thread at her fingertips as it appears (APPEAR_T) and, if the hold is cancelled
## (a stun, a dash, a swap), winds back into thread and fades (UNRAVEL_T): `fade`. A loosed one just goes (`put_away`),
## the shot is the needle. `size` makes the same needle smaller: the LMB arrow in her hand, the fan of Hemline and
## Finishing Touch (PinFan).
## The materials are the toon and glow shaders every Hunter already draws, so it adds no shader compile.

const LENGTH := 2.6            # m, tip to eye (a loosed arrow is about 0.8)
const RADIUS := 0.09           # m at the eye end, so it holds at the match camera
const SHELL := 1.9             # x the shaft: the glow around it
const SILVER := Color("e4ebf2")
const THREAD_N := 9            # thread segments
const THREAD_SEG := 0.26       # m each
const THREAD_R := 0.07         # m half width (holds at the match camera)
const THREAD_DROOP := 1.2      # m/s it sags behind the eye
const GLOW_A := Vector2(0.1, 0.85)  # the shell's alpha at no charge and full
const HOT_K := 0.7             # how far the steel itself turns red at full charge
const APPEAR_T := 0.12         # s the needle spins out of the thread twist
const UNRAVEL_T := 0.15        # s a cancelled needle winds back into thread and fades
const SPIN := 12.0             # rad it turns about its shaft over the appear
const COIL_R := 0.14           # m the thread twist's radius at the eye (x her scale and the needle's size)
const COIL_STEP := 0.05        # m the twist advances along the needle per thread joint
const THREAD_MIN_K := 0.45     # the thread of a small needle shrinks no further than this x the big one's
const LEAVE_T := 0.08          # s a loosed fan needle takes to leave the hand as the shot (`loose`)
const LEAVE_RUN := 0.9         # m it slides along its aim over LEAVE_T (x her scale)

var shell: MeshInstance3D
var shell_mat: ShaderMaterial
var steel: ShaderMaterial
var links: Array = []          # the thread's segments
var points: Array = []         # the thread's joints, world space, [0] at the eye
var eye := Vector3.ZERO        # where the eye is now (world)
var tip := Vector3.ZERO        # where the point is now (world)
var charge := 0.0              # the charge shown, 0..1 (checks read it)
var size := 1.0                # the needle's length as a share of the Heavy Shot's
var lift := 0.0                # rad it points above the aim (the fan tips up)
var grow := 0.0                # 0..1: spun out of the thread (1) or wound back into it (0)
var leaving := false           # being wound back into thread (a cancelled hold)
var flying := 0.0              # s left of leaving the hand as the shot (`loose`), 0 when not
var shown: Array = []          # the thread's joints as drawn: chain blended with the twist
var _dir := Vector3.FORWARD
var _sc := 1.0

func _init(thread_n := THREAD_N, size_k := 1.0) -> void:
	size = size_k
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
	for i in thread_n:
		var link := MeshInstance3D.new()
		link.mesh = Models.box(THREAD_R * 2.0, THREAD_R * 2.0, 1.0)
		link.material_override = thread
		_flat(link).top_level = true
		add_child(link)
		links.append(link)
		points.append(Vector3.ZERO)
	shown.resize(thread_n)

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

## Every step while it's held: the eye at `nock` (the bow's nock point, world), along `dir`, charged `k` 0..1;
## `sc` is her scale. A needle that wasn't showing spins out of the thread twist.
func hold(nock: Vector3, dir: Vector2, k: float, sc: float, dt: float) -> void:
	var nocking := not visible
	visible = true
	if nocking:
		grow = 0.0
	leaving = false
	flying = 0.0
	flying = 0.0
	grow = minf(1.0, grow + dt / APPEAR_T)
	charge = k
	var flat := Vector3(dir.x, 0, dir.y).normalized()
	_dir = flat * cos(lift) + Vector3.UP * sin(lift)
	var pulse := 0.1 * sin(Time.get_ticks_msec() * 0.018) if k >= 0.99 else 0.0
	shell_mat.set_shader_parameter("color", Color(PinFx.THREAD, lerpf(GLOW_A.x, GLOW_A.y, k) + pulse))
	steel.set_shader_parameter("albedo", SILVER.lerp(PinFx.THREAD, HOT_K * k))
	steel.set_shader_parameter("glow", lerpf(0.25, 0.4, k) + pulse)
	_pose(nock, sc, dt, nocking)

## A cancelled hold (no shot left): the needle winds back into its thread and fades, then it's gone. Every step
## while it isn't held; nothing when it isn't showing.
func fade(nock: Vector3, dt: float) -> void:
	if not visible:
		return
	leaving = true
	grow -= dt / UNRAVEL_T
	if grow <= 0.0:
		put_away()
		return
	_pose(nock, _sc, dt, false)

## Loosed from the fan: it leaves the hand as the shot, sliding along its aim and thinning over LEAVE_T, so the
## needle that just fired still shows on the shot's frame (Finishing Touch's first arrow leaves with the press). A
## needle not yet spun out leaves at full size. `nock`, `dir`, `sc` as `hold` (where the hand is now).
func loose(nock: Vector3, dir: Vector2, sc: float) -> void:
	var flat := Vector3(dir.x, 0, dir.y).normalized()
	_dir = flat * cos(lift) + Vector3.UP * sin(lift)
	visible = true
	leaving = false
	grow = 1.0
	flying = LEAVE_T
	_sc = sc
	eye = nock

## Every step while a loosed needle leaves (`loose`); false once it's gone.
func fly(dt: float) -> bool:
	if flying <= 0.0:
		return false
	flying -= dt
	if flying <= 0.0:
		put_away()
		return true
	var k := 1.0 - flying / LEAVE_T
	grow = 1.0 - k
	_pose(eye + _dir * LEAVE_RUN * _sc * dt / LEAVE_T, _sc, dt, false)
	return true

## Place the needle (eye at `nock`, along _dir) at the size `grow` gives it, and its thread.
func _pose(nock: Vector3, sc: float, dt: float, snap: bool) -> void:
	_sc = sc
	eye = nock
	tip = eye + _dir * LENGTH * sc * size
	global_position = eye
	look_at(tip, Vector3.UP, false)
	rotate_object_local(Vector3.BACK, SPIN * (1.0 - grow))
	var girth := sqrt(size)
	scale = Vector3(girth, girth, size) * sc * maxf(grow, 0.001)
	_thread(_dir, dt, snap)

## The thread hangs from the eye and lags behind it. While the needle appears or winds back it twists round the
## eye instead, in the share the needle is still missing; it thins away as the needle fades.
func _thread(d: Vector3, dt: float, snap: bool) -> void:
	var seg := THREAD_SEG * maxf(size, THREAD_MIN_K)
	points[0] = eye
	for i in range(1, points.size()):
		var prev: Vector3 = points[i - 1]
		var p: Vector3 = prev - d * seg if snap else points[i]
		p += Vector3(0, -THREAD_DROOP * dt, 0)
		p.y = maxf(p.y, global_position.y - 0.45)
		var off := p - prev
		points[i] = prev + off.normalized() * seg
	var twist := 1.0 - grow
	var u := d.cross(Vector3.UP).normalized()
	var v := d.cross(u)
	var r := COIL_R * _sc * size
	for i in points.size():
		var a: Vector3 = points[i]
		if twist > 0.0:
			var ang := float(i) * 1.1 + grow * SPIN
			var fall := 1.0 - float(i) / points.size()
			var coil: Vector3 = eye - d * float(i) * COIL_STEP * _sc * size + (u * cos(ang) + v * sin(ang)) * r * fall
			a = a.lerp(coil, twist)
		shown[i] = a
	var thin := smoothstep(0.0, 0.5, grow) if leaving else 1.0
	var w := maxf(thin, 0.001) * maxf(size, THREAD_MIN_K)
	for i in links.size():
		var a: Vector3 = shown[i]
		var b: Vector3 = shown[i + 1] if i + 1 < shown.size() else a - d * seg
		var link: MeshInstance3D = links[i]
		var len_ := a.distance_to(b)
		if len_ < 0.001:
			continue
		link.global_position = (a + b) * 0.5
		link.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT)
		link.scale = Vector3(w, w, len_)

## Loosed (the shot is the needle) or done: nothing shows at once.
func put_away() -> void:
	visible = false
	charge = 0.0
	grow = 0.0
	leaving = false
	flying = 0.0
