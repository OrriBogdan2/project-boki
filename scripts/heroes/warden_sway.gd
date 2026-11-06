class_name WardenSway
extends RefCounted
## What a Hero's clips can't key because it depends on how the player moves (warden_anim/<art>.json "sway"): a body on
## a spring (Motley, the jack on his box) lags behind every change of speed, overshoots and wobbles back, in whichever
## direction; and the cards round him tumble, each on its own turn and height, instead of circling in a ring. Runs
## after the clips each frame. A Hero without the block has no WardenSway.

var root: Node3D
var skel: Skeleton3D
var bone := -1
var stiff := 70.0            # 1/s^2: the spring's pull back
var damp := 7.0              # 1/s: its damping
var gain := 0.009            # radians of lean per m/s^2 of the body's acceleration
var limit := 0.45            # radians at most
var tumble_hz := 0.35        # turns a second of a tumbling prop
var swirl_m := 0.13          # m, how far a prop wanders up and down
var clear_m := 0.0           # m: a prop passing in front of the face drops this far, so it never covers it
var clear_orbit := ""        # the orbit that happens on
var lean := Vector2.ZERO     # radians, in the model's frame: x sideways, y along
var rate := Vector2.ZERO
var last_pos := Vector3.INF
var last_vel := Vector3.ZERO
var t := 0.0

## The Hero's sway, or null when its data has none.
static func make(model: Node3D, sk: Skeleton3D, cfg: Dictionary) -> WardenSway:
	if cfg.is_empty():
		return null
	var s := WardenSway.new()
	s.root = model
	s.skel = sk
	s.bone = WardenSkeleton.find(sk, String(cfg.get("bone", "hips")))
	s.stiff = float(cfg.get("stiff", s.stiff))
	s.damp = float(cfg.get("damp", s.damp))
	s.gain = float(cfg.get("gain", s.gain))
	s.limit = float(cfg.get("max", s.limit))
	s.tumble_hz = float(cfg.get("tumble_hz", s.tumble_hz))
	s.swirl_m = float(cfg.get("swirl_m", s.swirl_m))
	s.clear_m = float(cfg.get("clear_m", 0.0))
	s.clear_orbit = String(cfg.get("clear_orbit", ""))
	return s

## One frame, after the clips posed the bones. (lean.y + is back, lean.x + his right.)
func step(dt: float) -> void:
	if dt <= 0.0 or bone < 0 or not root.is_inside_tree():
		return
	var pos := root.global_position
	if last_pos == Vector3.INF or pos.distance_to(last_pos) > 2.0:      # (the first frame, a teleport)
		last_pos = pos
		last_vel = Vector3.ZERO
	var vel := (pos - last_pos) / dt
	var acc := (vel - last_vel) / dt
	last_pos = pos
	last_vel = vel
	var local := root.global_basis.inverse().orthonormalized() * Vector3(acc.x, 0.0, acc.z)
	var push := Vector2(-local.x, -local.z) * gain       # (the body stays behind what the box does)
	# (sub-stepped: the frame's push is a sharp kick, and a spring this stiff blows up on one long step)
	var h := minf(dt, 1.0 / 60.0)
	var left := dt
	while left > 0.0001:
		var k := minf(h, left)
		rate += (push * stiff - lean * stiff - rate * damp) * k
		lean += rate * k
		left -= k
	lean = lean.limit_length(limit)
	if lean.length_squared() < 0.00001:
		return
	var turn := Quaternion(Vector3(lean.y, 0.0, -lean.x).normalized(), lean.length())
	skel.set_bone_pose_rotation(bone, turn * skel.get_bone_pose_rotation(bone))

## 0..1: how far in front of him a prop is (the model faces -Z).
func _in_front(pivot: Node3D, nd: Node3D) -> float:
	var d := nd.global_position - pivot.global_position
	d.y = 0.0
	var fwd := -root.global_basis.z
	fwd.y = 0.0
	if d.length_squared() < 0.0001 or fwd.length_squared() < 0.0001:
		return 0.0
	return smoothstep(0.25, 0.8, d.normalized().dot(fwd.normalized()))

## The props on the orbits (WardenGlb.Orbits) tumble, after the orbit placed them: each its own axis, speed and height.
func tumble(dt: float, pivots: Array) -> void:
	t += dt
	var i := 0
	for pv in pivots:
		for pr in pv[2]:
			var nd: Node3D = pr[0]
			var ph := float(i) * 1.7
			var hz := tumble_hz * (0.7 + 0.13 * (i % 5))
			nd.position.y += sin(t * TAU * 0.17 * (1.0 + 0.11 * i) + ph) * swirl_m
			if String((pv[0] as Node3D).name) == clear_orbit:
				nd.position.y -= clear_m * _in_front(pv[0], nd)
			var a := t * TAU * hz
			nd.rotation = Vector3(sin(a * 0.6 + ph) * 0.5, a + ph, cos(a * 0.45 + ph) * 0.4)
			i += 1
