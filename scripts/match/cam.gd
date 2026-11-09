class_name CamRig
extends Camera3D
## Supervive-style camera: high, far and narrow, leaning toward the cursor so you see where you aim.

const HEIGHT := 27.0
const BACK := 17.5
const LEAD_X := 4.2
const LEAD_Z := 5.4
## The numbers (Settings "Camera" presets, "Camera follow" cursor lean, the edge kept) are in content/rules/camera.json.
## The Supervive preset is measured from the source's footage: docs/MOVEMENT_FEEL.md, "Camera calibration" and
## "Camera framing vs the source".
static var RULES: Dictionary = _load_rules()
## Settings "Camera" presets: pitch in degrees, distance, vertical field of view, rise (the view aims that far above you).
static var STYLES: Dictionary = RULES["styles"]

var focus := Vector3.ZERO
var target: Node3D = null
var shake_amp := 0.0          # a shake in progress (see Shake: only big hits on you)
var shake_left := 0.0
var shake_total := 0.0        # seconds of shake run so far (the shake check reads it)
var zoom := 1.0
var zoom_to := 1.0
var user_zoom := 1.0           # the mouse wheel in the practice areas (Practice); multiplies the match's own zoom
var lead := 1.0
var pull := 0.0               # (movefeel) a quick pull-back (a dash into a glide), a dash into a glide
var top := 0.0                # 0 = the usual angle, 1 = looking straight down (the opening drop)
var top_to := 0.0
var pitch := deg_to_rad(57.0)  # how steeply the camera looks down
var dist := 32.2              # how far back it sits
var rise := 0.0               # (camcal) the view aims this far above the focus (the style's "rise")
var yaw := 0.0                # turned around the focus (0 = looking north); only the skyship ride turns it
var yaw_to := 0.0
var chase := 0.0              # 0 = the usual angle, 1 = low behind-the-ship view
var chase_to := 0.0
## Cursor panning: [deadzone, maxzone, pan distance, camera speed, quadratic easing]. Supervive (the default)
## leans toward the cursor in proportion to how far it is from YOU, past a deadzone, eased, and capped so you
## never leave the screen (lean_to). Locked stays centred on you.
static var FOLLOW: Dictionary = RULES["follow"]
var follow_mode := "supervive"
var pan := Vector3.ZERO
var base := Vector3.ZERO      # the followed point, before the cursor pan
## (movefeel) Follow: tight across (FOLLOW_XZ, ~0.07s) so the hunter stays centred [footage] and
## stops dead with you; softer up and down so falls and glides don't jolt the view. While gliding
## Match sets lead_vel (your flat velocity) and the view leans a little ahead of you.
const FOLLOW_XZ := 15.0       # 1/s (was 8: ~0.65m behind you at a run, drifting on after a stop)
const FOLLOW_Y := 3.5
const GLIDE_LEAD := 0.2       # seconds of glide velocity to lean ahead...
const GLIDE_LEAD_MAX := 1.8   # ...capped (m)
const GLIDE_LEAD_EASE := 3.0  # 1/s, so the lean eases in and out instead of popping
var lead_vel := Vector3.ZERO
var lead_off := Vector3.ZERO

## An aimed cast's wider view (item 68): cast_view() asks for it every step of the cast. It eases in and out over
## about 0.2 s, no shake. Only the casting player's camera ever hears about it.
const CAST_EASE := 16.0       # 1/s
const CAST_HOLD := 0.04       # s a request lasts, so the view lets go as soon as the kit stops asking
const CAST_STEP := 1.0 / 60.0 # s a frame can take off that at most
static var EDGE: float = RULES["lean_edge_m"]      # m the cursor lean and a cast keep between you and the screen's edge
var cast_k := 0.0             # 0 = the usual view, 1 = fully pushed out
var cast_zoom := 0.0          # how much wider at cast_k 1 (0.25: 25%)
var cast_left := 0.0
var cast_pan := Vector3.ZERO  # the framing at cast_k 1, taking over from the cursor pan

var style_id := ""
## Multiplies the distance on top of zoom: the home keeps its own wider framing with any style (see
## Home._apply_cam_settings); 1 everywhere in a match.
var dist_mul := 1.0

static func _load_rules() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/camera.json"))
	assert(parsed is Dictionary, "content/rules/camera.json did not parse")
	return parsed

## Picks one of STYLES (Settings "Camera").
func use_style(id: String) -> void:
	var st: Dictionary = STYLES.get(id, STYLES["supervive"])
	style_id = id if STYLES.has(id) else "supervive"
	pitch = deg_to_rad(float(st["pitch"]))
	dist = float(st["dist"])
	fov = float(st["fov"])
	rise = float(st.get("rise", 0.0))

## The Settings camera (style and follow), wherever there's a CamRig: a match, the farm, the
## Training Grounds. Cheap enough to call every frame.
func apply_settings() -> void:
	follow_mode = String(Settings.get_v("cam_follow"))
	var sty := String(Settings.get_v("cam_style"))
	if sty != style_id:
		use_style(sty)

## Metres of ground across a 16:9 screen at the focus, for a style at zoom 1.
static func style_across(id: String) -> float:
	var st: Dictionary = STYLES.get(id, STYLES["supervive"])
	var hfov := 2.0 * atan(tan(deg_to_rad(float(st["fov"])) * 0.5) * 16.0 / 9.0)
	return 2.0 * float(st["dist"]) * tan(hfov * 0.5)

func _ready() -> void:
	fov = 28.0
	near = 1.0
	far = 120.0
	current = true

func snap(p: Vector3) -> void:
	focus = p
	base = p
	pan = Vector3.ZERO
	lead_off = Vector3.ZERO
	_apply(Vector3.ZERO)

## A brief pull-back that eases in fast and settles over ~0.6s (speed bursts).
func pull_back(a: float) -> void:
	pull = maxf(pull, a)

## No-op: camera punches are gone (item 50). Kept only so the reserved merge files, which still call it, compile.
func punch(_a: float) -> void:
	pass

## Asked each step of an aimed cast: push out by `zoom_k` and frame the line of `reach` metres along `dir`.
func cast_view(dir: Vector2, zoom_k: float, reach: float) -> void:
	cast_left = CAST_HOLD
	cast_zoom = zoom_k
	var pan_by := 0.0 if follow_mode == "locked" else minf(reach * 0.5, _cast_room(dir, zoom_k))
	cast_pan = Vector3(dir.x, 0.0, dir.y) * pan_by

## Metres the view can lean along `dir` at that zoom with the hunter still EDGE inside the screen. Up and down the
## screen it is perspective's ground between the centre and the edge: less toward the camera than away from it.
func _cast_room(dir: Vector2, zoom_k: float) -> float:
	var view := get_viewport().get_visible_rect().size
	var d := dist * dist_mul * zoom * (1.0 + zoom_k)
	var half := deg_to_rad(fov) * 0.5
	var turned := dir.rotated(yaw)
	# a lean away from the camera (turned.y < 0) puts you below the centre, toward the near edge
	var down := d * sin(half) / sin(pitch + (half if turned.y < 0.0 else -half))
	var room := Vector2(d * tan(half) * view.x / maxf(1.0, view.y), down) - Vector2.ONE * EDGE
	return minf(room.x / maxf(0.001, absf(turned.x)), room.y / maxf(0.001, absf(turned.y)))

func _tick_cast(delta: float) -> void:
	cast_left = maxf(0.0, cast_left - minf(delta, CAST_STEP))      # (a slow frame mustn't outlast the kit's request)
	cast_k = lerpf(cast_k, 1.0 if cast_left > 0.0 else 0.0, 1.0 - exp(-CAST_EASE * delta))
	if cast_k < 0.001:
		cast_k = 0.0

## The zoom an aimed cast adds right now.
func cast_wide() -> float:
	return 1.0 + cast_zoom * cast_k

func rumble(amp: float, secs: float) -> void:
	shake_amp = maxf(shake_amp, amp)
	shake_left = maxf(shake_left, minf(secs, Shake.MAX_SECS))

## The Supervive cursor lean for a cursor `rel` metres from you on the ground: a share of the distance past the
## deadzone, capped, and never more than the screen has room for along that way (you stay EDGE inside it).
func lean_to(rel: Vector3) -> Vector3:
	var fm: Array = FOLLOW["supervive"]
	var l := rel.length()
	if l <= float(fm[0]):
		return Vector3.ZERO
	var dir := rel / l
	var amt := minf((l - float(fm[0])) * float(fm[1]), float(fm[2]) * maxf(1.0, zoom)) * lead
	return dir * maxf(0.0, minf(amt, _cast_room(Vector2(dir.x, dir.z), 0.0)))

func follow(p: Vector3, delta: float, mouse_lead := true) -> void:
	# recording mode (Record): softer follow, a slower lean, no zoom pops, much less shake
	var rr: Array = Record.cam_rates()
	var lean_k := float(rr[2])
	var want_pan := Vector3.ZERO
	var fm: Array = FOLLOW.get(follow_mode, FOLLOW["supervive"])
	if follow_mode == "supervive" and mouse_lead:
		# where the cursor points on the ground at your height, relative to you
		var cur := mouse_on_plane(p.y)
		want_pan = lean_to(Vector3(cur.x - p.x, 0, cur.z - p.z))
		pan = pan.lerp(want_pan, 1.0 - exp(-float(fm[3]) * lean_k * delta))
	elif mouse_lead and float(fm[2]) > 0.0:
		var vp := get_viewport()
		var sz := vp.get_visible_rect().size
		var half := sz * 0.5
		var rel := (vp.get_mouse_position() - half) / half       # -1..1 on each axis
		var l := rel.length()
		if l > float(fm[0]) and float(fm[1]) > float(fm[0]):
			var f := clampf((l - float(fm[0])) / (float(fm[1]) - float(fm[0])), 0.0, 1.0)
			if fm[4]: f *= f
			want_pan = Vector3(rel.x / l, 0, rel.y / l).rotated(Vector3.UP, yaw) * f * float(fm[2]) * lead
	if follow_mode == "supervive" and mouse_lead:
		pass        # (eased above)
	elif not mouse_lead or float(fm[3]) <= 0.0:
		pan = want_pan if mouse_lead else pan.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	else:
		pan = pan.lerp(want_pan, 1.0 - exp(-float(fm[3]) * lean_k * delta))
	if follow_mode == "dynamic" and mouse_lead and not Record.clean():
		pan = want_pan
	# the focus sits a little below you (so the ground reads), but never more than 4m below, so even
	# far up in the sky you stay on screen
	var want := Vector3(p.x, maxf(p.y * 0.6, p.y - 4.0), p.z)
	if p.y < 0.0:
		want.y = p.y      # below island level: the view goes down with you, so you stay centred and the same size [reference footage]
	# across follows briskly; up and down follows softer, so falls and glides don't jolt the view
	# normal play: movefeel's tight follow; recording mode: its own slower, smoother rates
	var kxz := 1.0 - exp(-(float(rr[0]) if Record.clean() else FOLLOW_XZ) * delta)
	var ky := 1.0 - exp(-(float(rr[1]) if Record.clean() else FOLLOW_Y) * delta)
	base = Vector3(lerpf(base.x, want.x, kxz), lerpf(base.y, want.y, ky), lerpf(base.z, want.z, kxz))
	lead_off = lead_off.lerp((lead_vel * GLIDE_LEAD).limit_length(GLIDE_LEAD_MAX), 1.0 - exp(-GLIDE_LEAD_EASE * delta))
	_tick_cast(delta)
	focus = base + pan.lerp(cast_pan, cast_k) + lead_off
	zoom = lerpf(zoom, zoom_to, 1.0 - exp(-float(rr[3]) * delta))
	top = move_toward(top, top_to, delta * (0.9 if top_to < top else 2.0))
	chase = move_toward(chase, chase_to, delta * 0.7)
	yaw = lerp_angle(yaw, yaw_to, minf(1.0, delta * 1.6))
	var shake := Vector3.ZERO
	if shake_left > 0.0:
		var s := shake_amp * float(rr[4])
		shake = Vector3(Sfx.rng.randf_range(-s, s), Sfx.rng.randf_range(-s, s) * 0.5, Sfx.rng.randf_range(-s, s))
		shake_total += minf(delta, shake_left)
		shake_left = maxf(0.0, shake_left - delta)
		if shake_left <= 0.0:
			shake_amp = 0.0
	_apply(shake)
	Sfx.listener = focus

func _apply(shake: Vector3) -> void:
	pull = maxf(0.0, pull - get_process_delta_time() * 0.2)
	var z := zoom * (1.0 + pull) * cast_wide()
	far = (120.0 * maxf(1.0, z) + 30.0) * (1.0 + 1.5 * chase)
	var k := top * top * (3.0 - 2.0 * top)
	var c := chase * chase * (3.0 - 2.0 * chase)
	# pitch: the style's angle, tipped toward straight down for a bird's-eye view, or low behind
	# the skyship for the ride
	var p := lerpf(lerpf(pitch, deg_to_rad(88.0), k), deg_to_rad(30.0), c)
	var d := dist * dist_mul * z * (1.0 + 0.15 * k)
	# (Record.orbit_yaw: recording mode's slow orbit round the player, with the HUD hidden)
	var back := Vector3(0, sin(p), cos(p)).rotated(Vector3.UP, yaw + Record.orbit_yaw)
	# (camcal) aim at the body rather than the feet, so you sit a touch low on screen [footage];
	# faded out toward the bird's-eye and ship views
	var aim := focus + Vector3(0, rise * (1.0 - k) * (1.0 - c), 0)
	position = aim + back * d + shake
	look_at(aim + shake, Vector3.UP if p < deg_to_rad(85.0) else Vector3(0, 0, -1).rotated(Vector3.UP, yaw + Record.orbit_yaw))

## Character lean (feelfix): hunters are tipped back (their tops away from the camera, so their
## fronts turn up to face it) by this much, about their feet, so at the calibrated angle you see
## faces and bodies (as in the reference footage) instead of the tops of hats, without changing the
## world's framing. Faded out for the bird's-eye and the
## ship's chase view. The world is drawn at the style's pitch; characters read as if at ~pitch - lean.
const CHAR_LEAN := deg_to_rad(20.0)
func char_lean() -> Basis:
	var k := top * top * (3.0 - 2.0 * top)
	var c := chase * chase * (3.0 - 2.0 * chase)
	var a := CHAR_LEAN * (1.0 - k) * (1.0 - c)
	if a < 0.001:
		return Basis()
	return Basis(Vector3.RIGHT.rotated(Vector3.UP, yaw + Record.orbit_yaw), -a)

## A body's basis: leaned toward the camera (char_lean), then turned to `face`, keeping its scale.
func char_basis(face: float, scl: Vector3) -> Basis:
	return char_lean() * Basis(Vector3.UP, face).scaled_local(scl)

## The mouse's ray into the world: [origin, direction]. A ground-targeted move reads this, not inp["aim"] (that is the
## ray cut at the shooter's own height, or a foe's: right for shots, far off the ground under the cursor).
func mouse_ray() -> Array:
	var mp := get_viewport().get_mouse_position()
	return [project_ray_origin(mp), project_ray_normal(mp)]

## Where the mouse points on the horizontal plane at height y.
func mouse_on_plane(y: float) -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var o := project_ray_origin(mp)
	var d := project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return focus
	var t := (y - o.y) / d.y
	return o + d * t

func on_screen(p: Vector3) -> bool:
	if is_position_behind(p):
		return false
	var s := unproject_position(p)
	var sz := get_viewport().get_visible_rect().size
	return s.x > 20 and s.y > 20 and s.x < sz.x - 20 and s.y < sz.y - 20
