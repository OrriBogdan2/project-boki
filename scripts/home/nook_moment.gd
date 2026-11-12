class_name NookMoment
extends RefCounted
## The beat when two Boki are paired at the Nesting Nook (briefs/design/GARDEN.md section 6), about 4 s,
## in the world: both walk to the nest, face each other, nuzzle (their happy hop), circle the nest once,
## settle side by side (their nap), and the egg fades in between them with a soft glow. An unstable mix
## (UnstableMix.unstable) gets a wobble on the egg. The camera eases in the way the evolve moment's does.
## Any key skips to the end. It is only a show: the egg and the save are made before it starts and it
## writes nothing. Boki that are far, busy or away get no beat (play returns null): the egg just appears.

const WALK_SPEED := 4.4      # m/s: how fast they go to the nest
const WALK_MIN := 0.7        # s: the shortest walk
const WALK_MAX := 1.5        # s: the longest walk; a Boki farther than WALK_SPEED * WALK_MAX starts that far out
const FACE_TIME := 0.25      # s: turning to face each other
const NUZZLE_TIME := 0.6     # s: the happy hop, leaning in
const CIRCLE_TIME := 0.85    # s: once round the nest
const SETTLE_TIME := 0.8     # s: curled up side by side; the egg appears at its start
const EGG_FADE := 0.5        # s: the egg's glow fades and it grows to size
const WOBBLE_AT := 0.4       # s after the egg appears: an unstable mix's wobble starts
const SIDE := 0.8            # m: each parent's distance from the nest's middle
const LEAN := 0.12           # m: how far they lean in to nuzzle
const WOBBLE := 0.2          # rad: the unstable egg's widest tilt
const WOBBLE_RATE := 30.0    # rad/s: how fast it rocks
const EGG_FROM := 0.4        # the egg starts at this fraction of its size
const GLOW := 0.85           # peak alpha of the glow over the egg
const LIGHT_ENERGY := 1.4    # the egg's light at its peak

var host: Node3D
var fx: Fx
var pair: Array = []         # the two kin dicts ("node", "pos", "vel", "goal")
var starts: Array = []       # where each began, pulled in to at most WALK_SPEED * WALK_MAX away
var nest: Node3D
var shell: Node3D            # the egg in the nest
var col: Color
var unstable := false
var running := true
var look := 0.0              # 0 to 1: how far the camera has eased in
var walk := WALK_MIN         # s: the walk's length
var length := 0.0            # s: the whole beat
var wash := StandardMaterial3D.new()
var light := OmniLight3D.new()
var sparkled := false
var tween: Tween
var cam: CamRig
var zoom := 1.0

## Plays the beat for the kin `uids` at `nest_` (its egg already in the nest), or returns null when a
## Boki of the pair is not close and idle outdoors.
static func play(host_: Node3D, fx_: Fx, kins: Array, uids: Array, nest_: Node3D, col_: Color,
		unstable_: bool) -> NookMoment:
	var idle := EvolveMoment.watchers_of(kins, {}, nest_.position)
	var m := NookMoment.new()
	for u in uids:
		for k: Dictionary in idle:
			if k["rec"]["uid"] == u:
				m.pair.append(k)
	if m.pair.size() != 2 or not nest_.has_node("Shell"):
		return null
	m.host = host_
	m.fx = fx_
	m.nest = nest_
	m.col = col_
	m.unstable = unstable_
	m.start()
	m.tween = host_.create_tween()
	m.tween.tween_method(m.step, 0.0, m.length, m.length)
	m.tween.tween_callback(m.finish)
	return m

## Any key ends it now, in the place the whole beat ends.
func skip() -> void:
	if running:
		tween.kill()
		finish()

## The camera's focus for this frame: `focus` leaned toward the nest, the zoom eased closer (as the evolve moment does).
func frame(cam_: CamRig, focus: Vector3, home_zoom: float) -> Vector3:
	cam = cam_
	zoom = home_zoom
	cam.zoom_to = lerpf(home_zoom, home_zoom * EvolveMoment.CAM_ZOOM, look)
	return focus.lerp(nest.position, EvolveMoment.CAM_LEAN * look)

func start() -> void:
	var farthest := 0.0
	for k: Dictionary in pair:
		k["busy"] = true
		k["goal"] = Vector3.INF
		k["vel"] = Vector3.ZERO
		var from: Vector3 = k["pos"] - nest.position
		from.y = 0.0
		farthest = maxf(farthest, from.length())
		starts.append(nest.position + from.limit_length(WALK_SPEED * WALK_MAX + SIDE))
	walk = clampf((farthest - SIDE) / WALK_SPEED, WALK_MIN, WALK_MAX)
	length = walk + FACE_TIME + NUZZLE_TIME + CIRCLE_TIME + SETTLE_TIME
	shell = nest.get_node("Shell")
	shell.visible = false
	wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.albedo_color = Color(col.lightened(0.4), 0.0)
	EvolveMoment.set_wash(shell, wash)
	light.light_color = col.lightened(0.2)
	light.omni_range = 3.0
	light.light_energy = 0.0
	light.position = nest.position + Vector3(0, 0.6, 0)
	host.add_child(light)

## The beat at `t` seconds in (0 to length); the tween drives it, checks step it by hand.
func step(t: float) -> void:
	if not is_instance_valid(shell):
		return      # the nest was rebuilt under it: nothing left to show
	var t_face := walk
	var t_nuzzle := t_face + FACE_TIME
	var t_circle := t_nuzzle + NUZZLE_TIME
	var t_settle := t_circle + CIRCLE_TIME
	var circled := smoothstep(t_circle, t_settle, t)
	for i in 2:
		var k: Dictionary = pair[i]
		var n: Node3D = k["node"]
		if not is_instance_valid(n):
			continue     # sold or released mid-beat
		var base := PI * (1.0 - i)             # the first stands west of the nest, the second east
		var meet := nest.position + Vector3(cos(base), 0, sin(base)) * SIDE
		var at := meet
		var yaw := atan2(-(nest.position.x - meet.x), -(nest.position.z - meet.z))   # toward the nest (and each other)
		if t < t_face:
			at = starts[i].lerp(meet, smoothstep(0.0, walk, t))
			yaw = atan2(-(meet.x - starts[i].x), -(meet.z - starts[i].z))
		elif t < t_circle:
			var lean := LEAN / SIDE * sin(PI * clampf((t - t_nuzzle) / NUZZLE_TIME, 0.0, 1.0))
			at = nest.position + (meet - nest.position) * (1.0 - lean)
		elif t < t_settle:
			var a := base + TAU * circled
			at = nest.position + Vector3(cos(a), 0, sin(a)) * SIDE
			yaw = atan2(sin(a), -cos(a))       # along the way round
		k["pos"] = at
		n.position = at
		n.rotation.y = lerp_angle(n.rotation.y, yaw, 0.35) if t < t_nuzzle else yaw
		n.set_meta("happy", t >= t_nuzzle and t < t_circle)
		n.set_meta("face", "happy")
		n.set_meta("kstate", "sleep" if t >= t_settle else "")
	_egg(t - t_settle)
	look = smoothstep(0.0, walk, t) * (1.0 - smoothstep(length - 0.5, length, t))

## The egg `s` seconds after the parents settle: the glow fades and it grows, then (unstable) wobbles.
func _egg(s: float) -> void:
	var grown := smoothstep(0.0, EGG_FADE, s)
	shell.visible = s >= 0.0
	shell.scale = Vector3.ONE * lerpf(EGG_FROM, 1.0, grown)
	wash.albedo_color.a = GLOW * (1.0 - grown) * float(s >= 0.0)
	light.light_energy = LIGHT_ENERGY * sin(PI * clampf(s / SETTLE_TIME, 0.0, 1.0))
	if s >= 0.0 and not sparkled:
		sparkled = true
		fx.sparkles(nest.position + Vector3(0, 0.5, 0), col.lightened(0.3))
	var wob := clampf((s - WOBBLE_AT) / (SETTLE_TIME - WOBBLE_AT), 0.0, 1.0)
	var rock := sin(wob * WOBBLE_RATE * (SETTLE_TIME - WOBBLE_AT)) * WOBBLE * (1.0 - wob)
	shell.rotation.z = rock if unstable else 0.0

## Ends it: the show comes off, the Boki are released where they settled, the camera is let go.
func finish() -> void:
	step(length)
	running = false
	for k: Dictionary in pair:
		k["busy"] = false
		k["t"] = 1.5
		if is_instance_valid(k["node"]):
			for key in ["face", "happy", "kstate"]:
				(k["node"] as Node3D).remove_meta(key)
	if is_instance_valid(shell):
		EvolveMoment.set_wash(shell, null)
		shell.rotation = Vector3.ZERO
		shell.scale = Vector3.ONE
		shell.visible = true
	light.queue_free()
	if cam:
		cam.zoom_to = zoom
