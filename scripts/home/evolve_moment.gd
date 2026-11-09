class_name EvolveMoment
extends RefCounted
## The quiet moment when a Boki at home changes form (DECISIONS 2026-11-09, the garden). About 1.5 s,
## in the world: the Boki is washed in its type colour and swells into a glowing silhouette, the new
## form takes its place at the peak and settles back to size as the glow fades, a few soft sparkles
## drift up. No burst, ring or flash (explosions are for things that truly explode). Boki nearby
## turn to watch. Off screen there is no moment: the caller just swaps the model and shows the panel.

const LENGTH := 1.5          # s, the whole moment
const SWAP_AT := 0.6         # s: the glowing silhouette is full and the new form takes its place
const SWELL := 1.14          # peak size of the silhouette, times normal
const WASH_PEAK := 0.9       # peak alpha of the type-colour wash over the Boki
const SPARKLE_AT := [0.7, 1.0]   # s: when the two small sparkle drifts start
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
var base := Vector3.ONE      # the Boki's normal scale
var swapped := false
var sparkled := 0
var last_t := 0.0

## Is a Boki at `p` on the camera's screen?
static func on_screen(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var r := cam.get_viewport().get_visible_rect().grow(OFFSCREEN_PAD)
	return r.has_point(cam.unproject_position(p))

## The Boki of `kins` (not `except`) close enough to watch and free to turn: idle, outdoors.
static func watchers_of(kins: Array, except: Dictionary, at: Vector3) -> Array:
	return kins.filter(func(o: Dictionary) -> bool:
		return o != except and not o.get("busy", false) and (o["node"] as Node3D).visible \
			and not (o.has("indoors") or o.has("leap") or o.has("job") or o.has("fetch") or o.has("bath")) \
			and (o["node"] as Node3D).position.distance_to(at) < WATCH_RANGE)

## Plays the moment: `fresh` (the new model, already built) replaces `old` at `old`'s place under `host`.
## `done` runs when it ends; the watchers are freed again by the caller then.
static func play(host_: Node3D, fx_: Fx, old_: Node3D, fresh_: Node3D, col_: Color, watchers_: Array, done: Callable) -> EvolveMoment:
	var m := EvolveMoment.new()
	m.host = host_; m.fx = fx_; m.old = old_; m.fresh = fresh_; m.col = col_; m.watchers = watchers_
	m.start()
	var tw := host_.create_tween()
	tw.tween_method(m.step, 0.0, LENGTH, LENGTH)
	tw.tween_callback(func() -> void:
		m.finish()
		done.call())
	return m

func start() -> void:
	base = old.scale
	wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wash.albedo_color = Color(col.lightened(0.25), 0.0)
	fresh.position = old.position
	fresh.rotation = old.rotation
	fresh.visible = false
	host.add_child(fresh)
	_set_wash(old, wash)
	_set_wash(fresh, wash)
	light.light_color = col
	light.omni_range = 3.5
	light.light_energy = 0.0
	light.position = old.position + Vector3(0, 0.7, 0)
	host.add_child(light)

## The moment at `t` seconds in (0 to LENGTH); the tween drives it, checks step it by hand.
func step(t: float) -> void:
	var rise := smoothstep(0.0, SWAP_AT, t)
	var fall := smoothstep(SWAP_AT, LENGTH, t)
	var a := WASH_PEAK * rise * (1.0 - fall)
	wash.albedo_color.a = a
	light.light_energy = 1.6 * a
	var s := lerpf(1.0, SWELL, rise) if t < SWAP_AT else lerpf(SWELL, 1.0, fall)
	if t >= SWAP_AT and not swapped:
		swapped = true
		old.visible = false
		fresh.visible = true
	(fresh if swapped else old).scale = base * s
	for i in SPARKLE_AT.size():
		if sparkled == i and t >= SPARKLE_AT[i]:
			sparkled += 1
			fx.sparkles(fresh.position + Vector3(0, 0.6, 0), col.lightened(0.3))
	var dt := maxf(0.0, t - last_t)
	last_t = t
	for k: Dictionary in watchers:
		var n: Node3D = k["node"]
		var to := fresh.position - n.position
		n.rotation.y = lerp_angle(n.rotation.y, atan2(-to.x, -to.z), minf(1.0, dt * WATCH_TURN))

## Takes the wash and the light off and frees the old model.
func finish() -> void:
	step(LENGTH)
	_set_wash(fresh, null)
	fresh.scale = base
	light.queue_free()
	old.queue_free()

func _set_wash(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_overlay = mat
	for c in n.get_children():
		_set_wash(c, mat)
