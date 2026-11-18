class_name ResultsStage
extends SubViewportContainer
## The squad behind the results card: the Hunters of the squad on a little island, each holding a pose from
## its own GLB (content/rules/results_pose.json) with its Boki beside it, front lit, the camera drifting
## slowly. A squad that did not get out stands as dimmed Wisps instead. Built when the results screen opens
## and freed with it; a Hunter's model is built a frame at a time (PreviewBuild) so the card never stalls.

const POSES_PATH := "res://content/rules/results_pose.json"
const SPACING := 1.3         # m between neighbouring Hunters
const KIN_BESIDE := Vector3(0.8, 0.0, 0.45)      # m from its Hunter, outward
const TURN_IN := 0.3         # rad each outer Hunter turns toward the middle
const DRIFT_HZ := 0.12      # camera sway speed (cycles/s)
const DRIFT_M := 0.5         # camera sway width (m)
const WISP_HOVER := 1.0      # m a Wisp floats above the island
const WISP_DIM_GLOW := 0.15  # a dimmed Wisp's core glow (the default look is 0.45)
const WISP_DIM_HALO := 0.1   # ... and halo alpha (0.5)
const WISP_TINT := Color("5f70b0")   # a dimmed Wisp is a cool, dim blue, whatever its team
const LEFT_THIRD := 0.28     # the squad sits this far (of the window width) left of centre, beside the card

static var _poses := {}

var members: Array = []      # [{arch, name, you, kin: {} species/rec of its Boki or empty}]
var extracted := true
var built := 0               # Hunter models (or Wisps) standing on the island
var _w3: Node3D
var _cam: Camera3D
var _t := 0.0
var _todo: Array = []        # member indices still to build
var _bodies: Array = []      # [member index, Node3D]
var _kins: Array = []
var _anims: Array = []       # HunterAnim of a Hunter whose model has no clips

## The squad as the results carry it: the Hunters of the player's team, each with its Boki if it still has one.
static func roster(hunters: Array, me: Hunter) -> Array:
	var out: Array = []
	for h: Hunter in hunters:
		if h.team != me.team:
			continue
		var rec := {}
		if h.kin != null and is_instance_valid(h.kin) and not (h.kin as Kin).dead:
			rec = (h.kin as Kin).rec.duplicate(true)
		out.append({"arch": h.arch, "name": h.pname, "you": h == me, "kin": rec})
	return out

static func poses() -> Dictionary:
	if _poses.is_empty():
		_poses = JSON.parse_string(FileAccess.get_file_as_string(POSES_PATH))
	return _poses

static func make(squad: Array, won: bool) -> ResultsStage:
	var st := ResultsStage.new()
	st.members = squad
	st.extracted = won
	return st

func _ready() -> void:
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_w3 = Node3D.new()
	vp.add_child(_w3)
	var env := WorldEnvironment.new()
	env.environment = Look.environment({})
	_w3.add_child(env)
	if not extracted:
		Look.night(env.environment, 1.0)
	# the key shines from the camera's side, so every face is lit
	var key := Color("fff1d8") if extracted else Color("b9c4ff")
	Look.lights(_w3, key, 1.05 if extracted else 0.7, Vector3(-28, -12, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var span := SPACING * maxi(members.size(), 1)
	_w3.add_child(Models.float_island(rng, 1.8 + span * 0.5, 5.0, Color("6aa64a"), Color("9a7a5a"), Color("3a2f48")))
	_cam = Camera3D.new()
	_cam.fov = 40
	_w3.add_child(_cam)
	for i in members.size():
		_todo.append(i)

## Where member i stands: the first of a trio takes the middle, a step forward.
func _spot(i: int) -> Vector3:
	var n := members.size()
	var slot: int = [1, 0, 2][i] if n == 3 else i
	var mid := slot == 1 and n == 3
	return Vector3((slot - (n - 1) * 0.5) * SPACING, 0.0, 0.4 if mid else 0.0)

func _process(dt: float) -> void:
	_t += dt
	if not _todo.is_empty():
		_build_next()
	for a: HunterAnim in _anims:
		a.update(dt, {"grounded": true, "vel": Vector3.ZERO, "crouch": 0.0, "downed": false})
	for k: Node3D in _kins:
		(k.get_node("Body") as Node3D).position.y = absf(sin(_t * 5.0 + k.position.x)) * 0.12
	for pair: Array in _bodies:
		if not extracted:
			var w: Node3D = pair[1]
			w.position.y = WISP_HOVER + sin(_t * 1.6 + pair[0]) * 0.12
	_drift()

func _drift() -> void:
	var span := SPACING * maxi(members.size(), 1)
	var dist := 5.0 + span * 0.75
	var shift := LEFT_THIRD * 2.0 * dist * tan(deg_to_rad(_cam.fov * 0.5)) * size.x / maxf(size.y, 1.0)
	_cam.position = Vector3(shift + sin(_t * TAU * DRIFT_HZ) * DRIFT_M, 2.2, dist)
	_cam.look_at(Vector3(shift + sin(_t * TAU * DRIFT_HZ) * DRIFT_M * 0.5, 0.9, 0.0))

func _build_next() -> void:
	var i: int = _todo[0]
	var m: Dictionary = members[i]
	var arch := String(m["arch"])
	if extracted and not PreviewBuild.turn(arch):
		return
	_todo.pop_front()
	var at := _spot(i)
	var node := _wisp(m) if not extracted else _hunter(m, i)
	node.position = at + Vector3(0, WISP_HOVER if not extracted else 0.0, 0)
	_w3.add_child(node)
	_bodies.append([i, node])
	if extracted:
		_pose(node, arch)
		_add_kin(m, at)
	built += 1

func _hunter(m: Dictionary, i: int) -> Node3D:
	var arch := String(m["arch"])
	var look: Dictionary = Unmasked.mask_look() if bool(m["you"]) else PlayerLook.random()
	var node := Models.hunter(Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", look, arch)
	var ring := node.get_node_or_null("TeamRing") as Node3D
	if ring:
		ring.visible = false
	var out := signf(_spot(i).x)
	node.rotation.y = PI - out * TURN_IN
	return node

func _wisp(m: Dictionary) -> Node3D:
	var look: Dictionary = WispLook.get_look(WispLook.equipped() if bool(m["you"]) else "").duplicate(true)
	look["core"]["glow"] = WISP_DIM_GLOW
	look["halo"]["alpha"] = WISP_DIM_HALO
	return WispLook.build(look, WISP_TINT)

## Holds the Hunter's pose; a model without clips (the procedural fallback) stands in its idle.
func _pose(node: Node3D, arch: String) -> void:
	var sync := node.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync != null and sync.clips != null:
		sync.clips.force = (poses().get(arch, {"clip": "idle", "t": 0.0}) as Dictionary).duplicate()
	else:
		_anims.append(HunterAnim.new(node))

func _add_kin(m: Dictionary, at: Vector3) -> void:
	var rec: Dictionary = m["kin"]
	if rec.is_empty():
		return
	var out := 1.0 if at.x >= 0.0 else -1.0
	var k := Models.kin(String(rec["species"]), rec)
	k.position = at + Vector3(KIN_BESIDE.x * out, 0.0, KIN_BESIDE.z)
	k.rotation.y = PI - out * TURN_IN
	k.set_meta("happy", true)
	_w3.add_child(k)
	_kins.append(k)
