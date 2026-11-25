class_name FarmCam
extends RefCounted
## The farm's close third-person view: behind you, low and near, turning with a right-drag or the right stick, and
## never inside the ground or a wall. Numbers and the one flag ("third_person": false puts the top-down view back
## everywhere) are in content/rules/camera.json "farm". It drives the home's CamRig (CamRig.pitch, lens, rise, yaw
## and dist_mul) each frame; build mode, the training sessions and a tutorial spotlight blend back to the top-down
## view the Settings camera has, and a match never makes one (this class is the farm's own).

const NEAR_THIRD := 0.2  # m: the lens's near plane close up (CamRig keeps 1.0 from above)
const NEAR_TOP := 1.0  # m: CamRig's own near plane
const STEP := 0.25  # m between the samples the wall pull-in checks along the view
const MIN_BACK := 1.0  # m: the closest a wall may push the camera to you, whatever the angle
const TIP_STEP := 0.087  # rad (5 deg) between the steeper angles tried when a wall is close behind
const TIP_OUT := 1.5  # rad/s the extra tip eases off again once the wall is gone (it tips at once)
const OUT_SPEED := 5.0  # m/s the camera backs out again once the wall is gone (it comes in at once)
const EAVES_Y := 2.0  # m: above this height a roof reaches past the tile it stands on
const EAVES_AT := [Vector2(0.8, 0.0), Vector2(-0.8, 0.0), Vector2(0.0, 0.8), Vector2(0.0, -0.8)]  # m: how far past
const PAD_DEAD := 0.2  # right stick: ignored below this
const PAD_SPEED := 2.4  # rad/s at full stick

var k := 0.0  # 0 = the Settings view from above, 1 = third person
var yaw := 0.0  # the orbit round you, radians (0: the camera south of you, looking north)
var pitch := 0.0  # radians down from level (starts at the rules' pitch, a drag moves it)
var back := 0.0  # m the camera sits from the point it aims at (after any wall pull-in)
var play := 0.0  # 0..1: a minigame is on (the view tips up and draws back to show its court)
var tip := 0.0  # rad the camera is raised over its pitch to keep wall_min_m from you (0 in the open)
var _drag := false
var _dist := 0.0  # m the view wants (from the wheel's zoom)


static func rules() -> Dictionary:
	return CamRig.rules["farm"]


static func enabled() -> bool:
	return bool(rules()["third_person"])


## Mostly third person: the farm turns your keys to the view and faces you where you walk (not at the cursor).
func third() -> bool:
	return k > 0.5


## Your keys turned to the view: up is away from the camera.
func keys(mv: Vector2, cam: CamRig) -> Vector2:
	return mv.rotated(-cam.yaw)


## Once a frame, after the Settings camera and the distance multiplier are set: `free` is false while the farm wants
## the top-down view (building, a training session, a tutorial spotlight on something that may be behind you);
## `games` are the farm's minigames (a round on tips the view up and draws it back so the whole court shows; Kite Tow's
## loop is too wide for that, so it blends to the top-down view like building does).
func tick(cam: CamRig, delta: float, free: bool, games: Array) -> void:
	if not enabled():
		return
	var r := rules()
	free = free and not games.any(_wants_top)
	if k <= 0.0 and free:
		pitch = deg_to_rad(float(r["pitch_deg"]))
	k = move_toward(k, 1.0 if free else 0.0, delta / float(r["blend_s"]))
	var e := smoothstep(0.0, 1.0, k)
	play = move_toward(play, 1.0 if games.any(_is_playing) else 0.0, delta / float(r["blend_s"]))
	var p := smoothstep(0.0, 1.0, play)
	if free:
		_orbit_pad(delta, r)
	var style: Dictionary = CamRig.styles[cam.style_id]
	cam.pitch = lerpf(
		deg_to_rad(float(style["pitch"])), lerpf(pitch, maxf(pitch, deg_to_rad(float(r["game_pitch_deg"]))), p), e
	)
	cam.lens = lerpf(float(style["fov"]), float(r["fov"]), e)
	cam.rise = lerpf(float(style.get("rise", 0.0)), float(r["rise"]), e)
	cam.yaw = lerp_angle(0.0, yaw, e)
	cam.yaw_to = cam.yaw
	cam.lean_scale = 1.0 - e
	cam.near = lerpf(NEAR_TOP, NEAR_THIRD, e)
	var t := inverse_lerp(CamWheel.near(), CamWheel.far(), cam.zoom)
	_dist = lerpf(float(r["dist_min"]), float(r["dist_max"]), clampf(t, 0.0, float(r["look_out"])))
	_dist *= lerpf(1.0, float(r["game_dist_mul"]), p)
	cam.dist_mul = lerpf(cam.dist_mul, _dist / (cam.dist * maxf(cam.zoom, 0.01)), e)


static func _is_playing(g: Object) -> bool:
	return g.playing()


## Kite Tow flies your Boki round a 13 m loop while you stand at the stand: only the wide top-down view holds it.
static func _wants_top(g: Object) -> bool:
	return g is BaseKite and (g as BaseKite).playing()


## After the camera moved this frame: pulls it in along the view so it stays clear of the ground and walls. With a
## wall close behind it keeps `wall_min_m` from you by tipping the view steeper (up and over) instead of coming in.
func keep_clear(cam: CamRig, home: Node3D, delta: float) -> void:
	if k <= 0.0 or not enabled():
		return
	var aim := cam.focus + Vector3(0.0, cam.rise, 0.0)
	var way := cam.position - aim
	var full := way.length()
	if full < 0.01:
		return
	way /= full
	var r := rules()
	var gap := float(r["wall_gap"])
	var want := float(r["wall_min_m"])
	var up := asin(clampf(way.y, -1.0, 1.0))
	var clear := _clear(home, aim, way, full, gap)
	var target := 0.0
	var steep := up
	while clear < want and steep < deg_to_rad(float(r["wall_pitch_deg"])):
		steep += TIP_STEP
		var c := _clear(home, aim, _tipped(way, steep), full, gap)
		if c > clear:
			clear = c
			target = steep - up
	tip = target if target > tip else move_toward(tip, target, TIP_OUT * delta)
	if tip > 0.0:
		way = _tipped(way, up + tip)
		clear = _clear(home, aim, way, full, gap)
	back = clear if back <= 0.0 or clear < back else move_toward(back, clear, OUT_SPEED * delta)
	back = minf(back, full)
	if back < full or tip > 0.0:
		cam.position = aim + way * back
		cam.look_at(aim, Vector3.UP)


## The view's direction `way` tipped to `steep` radians above the level (same way round).
static func _tipped(way: Vector3, steep: float) -> Vector3:
	var flat := Vector2(way.x, way.z).normalized()
	return Vector3(flat.x * cos(steep), sin(steep), flat.y * cos(steep))


## How far along `way` (unit) from `aim` the view stays clear, at most `full` m.
static func _clear(home: Node3D, aim: Vector3, way: Vector3, full: float, gap: float) -> float:
	var s := MIN_BACK
	while s <= full:
		if _blocked(home, aim + way * s, gap):
			return maxf(s - STEP, MIN_BACK)
		s += STEP
	return full


## A right-button drag turns the view (and tips it, inside the rules' range). True when it took the event.
func input(event: InputEvent) -> bool:
	if not third():
		_drag = false
		return false
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_drag = (event as InputEventMouseButton).pressed
		return true
	if _drag and event is InputEventMouseMotion:
		var r := rules()
		var rel := (event as InputEventMouseMotion).relative * float(r["orbit_per_px"])
		yaw = wrapf(yaw - rel.x, -PI, PI)
		pitch = clampf(pitch + rel.y, deg_to_rad(float(r["pitch_min_deg"])), deg_to_rad(float(r["pitch_max_deg"])))
		return true
	return false


func _orbit_pad(delta: float, r: Dictionary) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() < PAD_DEAD:
		return
	yaw = wrapf(yaw - stick.x * PAD_SPEED * delta, -PI, PI)
	pitch = clampf(
		pitch + stick.y * PAD_SPEED * delta,
		deg_to_rad(float(r["pitch_min_deg"])),
		deg_to_rad(float(r["pitch_max_deg"]))
	)


## Is the point inside the ground or a solid block (with `gap` m to spare)?
static func _blocked(home: Node3D, p: Vector3, gap: float) -> bool:
	var world: World = home.world
	if world.ground_at(p.x, p.z) + gap > p.y or _in_prop(home, p, gap):
		return true
	if _solid(home, p.x, p.z, p.y, gap, 0.0):
		return true
	if p.y < EAVES_Y:
		return false
	for o in EAVES_AT:
		if _solid(home, p.x + o.x, p.z + o.y, p.y, gap, float(rules()["building_m"]) - 0.01):
			return true
	return false


## Is (x, y, z) inside a block's top? `tall_from` > 0: only a block that tall (a building: its roof reaches past
## its tile) counts.
static func _solid(home: Node3D, x: float, z: float, y: float, gap: float, tall_from: float) -> bool:
	var world: World = home.world
	if not world.is_block(x, z):
		return false
	var i := world.idx(int(floor(x)), int(floor(z)))
	var top := _top(home, i)
	return top + gap > y and top - world.level[i] * World.LEVEL >= tall_from


## Is the point inside the portal ring or the glider rack? They stand off the tile grid, so they are boxes:
## rules "props" = {spot: [half width m, height m, half depth m]}.
static func _in_prop(home: Node3D, p: Vector3, gap: float) -> bool:
	var props: Dictionary = rules()["props"]
	for nm in props:
		if not home.spots.has(nm):
			continue
		var at: Vector3 = home.spots[nm]
		var box: Array = props[nm]
		if (
			absf(p.x - at.x) < float(box[0]) + gap
			and absf(p.z - at.z) < float(box[2]) + gap
			and p.y < float(box[1]) + gap
		):
			return true
	return false


## The height of what stands on block tile `i`: a building or a tree is a tall wall, a rock or a low piece (fence,
## bench) its own top. The block's own top is only how high you may climb it, not how tall the model is.
static func _top(home: Node3D, i: int) -> float:
	var world: World = home.world
	var level: float = world.level[i] * World.LEVEL
	var tag := String(home.hb.occ.get(i, ""))
	if tag.begins_with("d:"):
		tag = _deco_id(home, int(tag.substr(2)))
	elif tag.begins_with("b:"):
		return level + float(rules()["building_m"])
	elif world.props.get(i, "tree") == "tree":
		return level + float(rules()["tree_m"])
	if tag == "" or not HomeLayout.CATALOG.get(tag, {}).has("fixture"):
		return world.block_top_of(i)
	return level + float(rules()["building_m"])


static func _deco_id(home: Node3D, uid: int) -> String:
	for e in HomeLayout.of(home._d()).get("deco", []):
		if int(e["u"]) == uid:
			return String(e["id"])
	return ""
