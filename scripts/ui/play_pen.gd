class_name PlayPen
extends SubViewportContainer
## The title screen's backdrop (scenes/title/play_pen.tscn): a small cosy play pen, live in 3D, with a few of the
## game's own Boki wandering, hopping, chasing and napping in it. It is built from the farm's props and the rigged
## Boki (Models.kin), and the Boki drive their own clips from how they move (BokiRig). The camera drifts slowly.
## Cheap: the view renders at most MAX_FPS times a second, and if the device cannot keep up it freezes on its
## last frame (a still) instead of stuttering under the menu.

const PALS := ["burrlet", "puddlet", "cindle", "pebbit", "zapple", "nettlynx", "lilybara"]
const PAL_SCALE := 1.45          # a bit under the farm's 1.7 x (home.gd FARM_BOKI_SCALE), so the pen stays roomy
const HALF := Vector2(5.2, 3.4)  # m: half the pen's size, x and z
const EDGE := 1.1                # m a Boki stays in from the fence
const SPACING := 1.25           # m: two Boki are pushed apart closer than this
const WALK := Vector2(0.9, 1.3)  # m/s: a stroll
const RUN := 2.5                 # m/s: a game of chase
const NAP := Vector2(7.0, 12.0)  # s a nap lasts
const BOUNCE := 0.2              # m a happy hop rises
const TURN_RATE := 7.0           # 1/s the heading eases at
const ACCEL := 3.0               # m/s^2 a Boki speeds up and slows down at
const TREES := [Vector3(-5.6, 0, -4.2), Vector3(6.0, 0, -4.8), Vector3(-8.0, 0, 0.8), Vector3(8.4, 0, 0.5)]
const MAX_FPS := 60.0
const SLOW_FRAME := 1.0 / 24.0   # s: an average frame slower than this, once warm, turns the view into a still
const WARM_S := 2.0              # s the pen gets to load before the frame time is judged
const JUDGE_S := 2.0             # s of frames the slow check averages
const DRIFT_S := 48.0            # s for one slow sweep of the camera
const DRIFT_YAW := 0.1           # rad the camera swings to each side
const CAM_FRAMING := Vector3(0.0, 3.5, 7.8)    # m: where the camera sits, from the pen's centre
const CAM_LOOK := Vector3(0.0, 0.1, -0.7)
const CAM_SHIFT := -1.1          # m the frustum slides so the pen sits right of the menu column

var still := false              # frozen on its last frame (a slow device, or a check asking)
var _t := 0.0
var _judged := 0.0
var _judge_n := 0
var _since_draw := 0.0
var _cam: Camera3D
var _view: SubViewport
var _pals: Array = []           # {node, state, t, goal, speed, bounce}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 26
	_view = get_node("View") as SubViewport
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	env.environment = Look.environment(
		{
			"top": Color("6fa0dc"), "mid": Color("b8d4ee"), "horizon": Color("ffe6c4"), "stars": 0.0,
			"ambient": Color("ffe9d0"), "ambient_energy": 0.7, "fog": Color("f3e6c8"), "fog_density": 0.004,
			"saturation": 1.1,
		}
	)
	_view.add_child(env)
	Look.lights(_view, Color("ffe2b8"), 1.15, Vector3(-38, 52, 0), 30.0)
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.h_offset = CAM_SHIFT
	_view.add_child(_cam)
	_build_pen()
	_add_pals()
	_aim_camera()


func _process(delta: float) -> void:
	if still:
		return
	delta = minf(delta, 0.1)
	_t += delta
	_judge(delta)
	_aim_camera()
	for p: Dictionary in _pals:
		_step(p, delta)
	_separate()
	# render at most MAX_FPS times a second (a 144 Hz screen draws the pen every second or third frame)
	_since_draw += delta
	if _since_draw >= 1.0 / MAX_FPS - 0.002:
		_since_draw = 0.0
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Freezes the view on its last frame (it keeps showing the final render) and stops the Boki.
func freeze() -> void:
	still = true
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _judge(delta: float) -> void:
	if _t < WARM_S or DisplayServer.get_name() == "headless":
		return
	_judged += delta
	_judge_n += 1
	if _judged < JUDGE_S:
		return
	if _judged / float(_judge_n) > SLOW_FRAME:
		freeze()
	_judged = 0.0
	_judge_n = 0


func _aim_camera() -> void:
	var swing := sin(_t * TAU / DRIFT_S)
	var yaw := swing * DRIFT_YAW
	_cam.position = CAM_FRAMING.rotated(Vector3.UP, yaw) + Vector3(0, sin(_t * TAU / (DRIFT_S * 0.7)) * 0.18, 0)
	_cam.look_at(CAM_LOOK)


# ------------------------------------------------------------------ the pen
func _build_pen() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 60)
	ground.mesh = plane
	ground.material_override = Models.toon(Color("7fb35a"), false)
	_view.add_child(ground)
	var props := Node3D.new()
	_view.add_child(props)
	var back := Models.fence(HALF.x * 2.0)     # (the front is open toward the camera)
	back.position = Vector3(0, 0, -HALF.y)
	props.add_child(back)
	for side in [-1.0, 1.0]:
		var edge := Models.fence(HALF.y * 2.0)
		edge.rotation.y = PI * 0.5
		edge.position = Vector3(side * HALF.x, 0, 0)
		props.add_child(edge)
	_tuft_the_grass(props)
	for tree_at: Vector3 in TREES:
		var tree := Models.tree(_rng, Color("7cc060"), "blossom" if tree_at.x > 0.0 else "round")
		tree.position = tree_at
		tree.scale = Vector3.ONE * _rng.randf_range(1.2, 1.5)
		props.add_child(tree)
	var bed := Models.kin_bed(Color("c98a5e"))
	bed.position = Vector3(-2.6, 0, -1.6)
	bed.scale = Vector3.ONE * 1.5
	props.add_child(bed)
	var pond := Models.pond(1.1, 0.7)
	pond.position = Vector3(2.9, 0, -1.7)
	props.add_child(pond)
	var flowers := Models.flower_bed(_rng, 9)
	flowers.position = Vector3(-3.7, 0, 1.9)
	flowers.scale = Vector3.ONE * 1.4
	props.add_child(flowers)
	for rock_at: Vector3 in [Vector3(3.6, 0, 2.0), Vector3(0.6, 0, -2.4)]:
		var rock := Models.rock(_rng, 0.55)
		rock.position = rock_at
		props.add_child(rock)
	Models.merge_tree(props)


## Short grass over the pen and a little way past it.
func _tuft_the_grass(parent: Node3D) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.grass_mesh(false)
	mm.instance_count = 200
	for i in mm.instance_count:
		var at := Vector3(_rng.randf_range(-HALF.x - 3.0, HALF.x + 3.0), 0, 0)
		at.z = _rng.randf_range(-HALF.y - 2.5, HALF.y + 1.5)
		var tilt := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4))
		var tuft := Transform3D(tilt, at)
		mm.set_instance_transform(i, tuft)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var blades := Models.grass_material(0.08)
	blades.set_shader_parameter("tip_tint", Color("b4e07a"))
	inst.material_override = blades
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# ------------------------------------------------------------------ the Boki
func _add_pals() -> void:
	for i in PALS.size():
		var node := Models.kin(PALS[i], {})
		node.scale = Vector3.ONE * PAL_SCALE
		node.position = _spot()
		node.rotation.y = _rng.randf() * TAU
		_view.add_child(node)
		_pals.append(
			{
				"node": node, "state": "idle", "t": _rng.randf_range(0.2, 2.5), "goal": node.position,
				"speed": 0.0, "bounce": 0.0,
			}
		)


func _spot() -> Vector3:
	return Vector3(_rng.randf_range(-HALF.x + EDGE, HALF.x - EDGE), 0, _rng.randf_range(-HALF.y + EDGE, HALF.y - EDGE))


func _step(p: Dictionary, d: float) -> void:
	var node: Node3D = p["node"]
	var want_speed := 0.0
	var state: String = p["state"]
	if state == "walk" or state == "run":
		var to: Vector3 = (p["goal"] as Vector3) - node.position
		to.y = 0.0
		if to.length() < 0.25:
			_idle(p, _rng.randf_range(0.8, 3.0))
		else:
			want_speed = float(p["want"])
			node.rotation.y = lerp_angle(node.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-TURN_RATE * d))
	else:
		p["t"] = float(p["t"]) - d
		if float(p["t"]) <= 0.0:
			_pick(p)
	p["speed"] = move_toward(float(p["speed"]), want_speed, ACCEL * d)
	node.position -= node.basis.z * float(p["speed"]) * d
	node.position.x = clampf(node.position.x, -HALF.x + EDGE, HALF.x - EDGE)
	node.position.z = clampf(node.position.z, -HALF.y + EDGE, HALF.y - EDGE)
	var hopping: bool = state == "hop"
	p["bounce"] = float(p["bounce"]) + d * 9.0 if hopping else 0.0
	(node.get_node("Body") as Node3D).position.y = absf(sin(float(p["bounce"]))) * BOUNCE
	node.set_meta("happy", hopping or state == "run")
	node.set_meta("kstate", "sleep" if state == "nap" else "")


func _idle(p: Dictionary, secs: float) -> void:
	p["state"] = "idle"
	p["t"] = secs


## What a resting Boki does next: mostly wander, sometimes bounce, nap or tear off in a game of chase.
func _pick(p: Dictionary) -> void:
	var roll := _rng.randf()
	if roll < 0.5:
		p["state"] = "walk"
		p["goal"] = _spot()
		p["want"] = _rng.randf_range(WALK.x, WALK.y)
	elif roll < 0.68:
		p["state"] = "hop"
		p["t"] = _rng.randf_range(1.2, 2.4)
	elif roll < 0.84:
		p["state"] = "nap"
		p["t"] = _rng.randf_range(NAP.x, NAP.y)
	else:
		p["state"] = "run"
		p["goal"] = _spot()
		p["want"] = RUN


func _separate() -> void:
	for i in _pals.size():
		for j in range(i + 1, _pals.size()):
			var a: Node3D = _pals[i]["node"]
			var b: Node3D = _pals[j]["node"]
			var gap := b.position - a.position
			gap.y = 0.0
			var dist := gap.length()
			if dist < SPACING and dist > 0.001:
				var push := gap / dist * (SPACING - dist) * 0.5
				a.position -= push
				b.position += push
