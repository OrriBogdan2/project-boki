class_name EvolveMoment
extends RefCounted
## The moment a Boki at home changes form (DECISIONS 2026-11-09, the garden). About 2.2 s, in the world:
## the old form glows in its type colour and curls up (its own sleep clip, a squash), a quick silhouette
## morph blends it into the new form (scale and blend, no explosion), the new form settles to size doing
## a one-shot "new body" pose from its own clips (hop, happy face), a few soft sparkles drift up. The
## camera eases in toward it and Boki nearby turn to watch. No burst, ring or flash (explosions are for
## things that truly explode). Off screen there is no moment: the caller just swaps the model and shows
## the panel. A form with no model never plays it (has_model): the caller keeps what it had.

const LENGTH := 2.2          # s, the whole moment
const SWAP_AT := 0.8         # s: the curled, glowing old form is full and the morph to the new form starts
const MORPH_END := 1.2       # s: the old form is gone and the new form is at its swollen peak
const CURL := Vector3(1.08, 0.82, 1.08)   # the old form's squash at SWAP_AT, times normal
const MORPH_DIP := 0.85      # the two forms meet at this fraction of size, then the new one swells
const SWELL := 1.14          # peak size of the new silhouette at MORPH_END, times normal
const WASH_PEAK := 0.9       # peak alpha of the type-colour wash over the Boki
const SPARKLE_AT := [1.2, 1.5]   # s: when the two small sparkle drifts start
const CAM_LEAN := 0.5        # how far the camera focus moves from the player toward the Boki, 0 to 1
const CAM_ZOOM := 0.75       # the camera's zoom while it watches, times home's (smaller is closer)
const WATCH_RANGE := 9.0     # m: Boki this close turn to watch
const WATCH_TURN := 8.0      # per second: how fast a watcher turns to face it
const OFFSCREEN_PAD := 60.0  # px: a Boki this close to the screen edge still counts as on screen

var host: Node3D
var fx: Fx
var old: Node3D
var fresh: Node3D
var col: Color
var watchers: Array = []     # kin dicts ("node") that turn to watch; the caller frees them with `done`
var wash := StandardMaterial3D.new()
var light := OmniLight3D.new()
var base := Vector3.ONE      # the old form's scale
var grown := Vector3.ONE     # the new form's scale (a hatchling grows to full size: evo_scale)
var peak := Vector3.ONE      # the swollen silhouette at MORPH_END
var swapped := false
var look := 0.0              # 0 to 1: how far the camera has eased in
var sparkled := 0
var last_t := 0.0

## Is a Boki at `p` on the camera's screen?
static func on_screen(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var r := cam.get_viewport().get_visible_rect().grow(OFFSCREEN_PAD)
	return r.has_point(cam.unproject_position(p))

## True when `n` has a body to show (a mesh somewhere under it): never evolve into a form without one.
static func has_model(n: Node) -> bool:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return true
	for c in n.get_children():
		if has_model(c):
			return true
	return false

## The camera's focus for this frame: `focus` leaned toward the Boki, and the zoom eased closer.
func frame(cam: CamRig, focus: Vector3, home_zoom: float) -> Vector3:
	cam.zoom_to = lerpf(home_zoom, home_zoom * CAM_ZOOM, look)
	return focus.lerp(fresh.position, CAM_LEAN * look)

## The Boki of `kins` (not `except`) close enough to watch and free to turn: idle, outdoors.
static func watchers_of(kins: Array, except: Dictionary, at: Vector3) -> Array:
	return kins.filter(func(o: Dictionary) -> bool:
		return o != except and not o.get("busy", false) and (o["node"] as Node3D).visible \
			and not (o.has("indoors") or o.has("leap") or o.has("job") or o.has("fetch") or o.has("bath")) \
			and (o["node"] as Node3D).position.distance_to(at) < WATCH_RANGE)

## Plays the moment: `fresh` (the new model, already built) replaces `old` at `old`'s place under `host`.
## `done` runs when it ends; the watchers are freed again by the caller then.
static func play(host_: Node3D, fx_: Fx, old_: Node3D, fresh_: Node3D, col_: Color, watchers_: Array,
		done: Callable) -> EvolveMoment:
	var m := EvolveMoment.new()
	m.host = host_
	m.fx = fx_
	m.old = old_
	m.fresh = fresh_
	m.col = col_
	m.watchers = watchers_
	m.start()
	var tw := host_.create_tween()
	tw.tween_method(m.step, 0.0, LENGTH, LENGTH)
	tw.tween_callback(func() -> void:
		m.finish()
		done.call())
	return m

func start() -> void:
	base = old.scale
	grown = base / float(old.get_meta("evo_scale", 1.0)) * float(fresh.get_meta("evo_scale", 1.0))
	peak = (base if base.x > grown.x else grown) * SWELL
	wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.albedo_color = Color(col.lightened(0.25), 0.0)
	fresh.position = old.position
	fresh.rotation = old.rotation
	fresh.visible = false
	host.add_child(fresh)
	old.set_meta("kstate", "sleep")        # the old form curls up: its own sleep clip
	set_wash(old, wash)
	set_wash(fresh, wash)
	light.light_color = col
	light.omni_range = 3.5
	light.light_energy = 0.0
	light.position = old.position + Vector3(0, 0.7, 0)
	host.add_child(light)

## The moment at `t` seconds in (0 to LENGTH); the tween drives it, checks step it by hand.
func step(t: float) -> void:
	var rise := smoothstep(0.0, SWAP_AT, t)
	var morph := smoothstep(SWAP_AT, MORPH_END, t)
	var fall := smoothstep(MORPH_END, LENGTH, t)
	var a := WASH_PEAK * rise * (1.0 - fall)
	wash.albedo_color.a = a
	light.light_energy = 1.6 * a
	look = smoothstep(0.0, SWAP_AT, t) * (1.0 - smoothstep(LENGTH - 0.5, LENGTH, t))
	if t >= SWAP_AT and not swapped:
		swapped = true
		fresh.visible = true
		fresh.set_meta("kact", "hop")       # the new body's pose, from its own clips
		fresh.set_meta("face", "happy")
	if not swapped:
		old.scale = base * Vector3.ONE.lerp(CURL, rise)
	elif t < MORPH_END:
		old.scale = base * CURL * lerpf(1.0, MORPH_DIP, morph)
		fresh.scale = (grown * MORPH_DIP).lerp(peak, morph)
	else:
		old.visible = false
		fresh.scale = peak.lerp(grown, fall)
	for i in SPARKLE_AT.size():
		if sparkled == i and t >= SPARKLE_AT[i]:
			sparkled += 1
			fx.sparkles(fresh.position + Vector3(0, 0.6, 0), col.lightened(0.3))
	var dt := maxf(0.0, t - last_t)
	last_t = t
	for k: Dictionary in watchers:
		if not is_instance_valid(k["node"]):
			continue    # a watcher left home (sold, released) mid-moment
		var n: Node3D = k["node"]
		var to := fresh.position - n.position
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), minf(1.0, dt * WATCH_TURN))

## Takes the wash and the light off and frees the old model.
func finish() -> void:
	step(LENGTH)
	fresh.remove_meta("kact")
	fresh.remove_meta("face")
	set_wash(fresh, null)
	fresh.scale = grown
	light.queue_free()
	old.queue_free()

static func set_wash(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		set_wash(c, mat)
