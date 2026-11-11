class_name WardenGlide
extends RefCounted
## The glide set on a Hero's clips (WardenClips; docs/art/anim_audit/GLIDE_SET.md): the open plays once over the hold
## when the glider opens, the hold leans by the steer (a Blend3 of glide_lean_l, glide, glide_lean_r), an overheated
## glider plays the struggle over it, and a glider shut in the air plays the close over the fall. A landing is the
## Hero's land clip, as for any fall. Clip names: content/rules/warden_anim/<art>.json "air" open, close, lean_l,
## lean_r, burn. The hold shows only while the state says "gliding" (the glide input, Hunter._update_glide).

const OPEN_IN := 0.03        # s: the open takes over from the fall pose at once (it starts on the fall)
const OPEN_OUT := 0.06       # s: the open's last stretch hands over to the hold
const CLOSE_OUT := 0.06      # s: the close's last stretch hands over to the fall
const LEAN_RATE := 9.0       # 1/s: the lean follows the keys over ~0.1 s (the glider turns 90 deg in ~0.2 s)
const BURN_RATE := 4.0       # 1/s: the struggle grows over ~0.25 s as the heat runs out
const STEER_MIN := 1.0       # m/s: slower than this the glide has no heading to lean off
const TURN_FULL := 3.0       # rad/s of heading turn that leans all the way (no keys: a remote Hunter, a drift)

var air: Dictionary
var open_len := 0.0
var close_len := 0.0
var open_t := INF            # s since the glider opened (INF: no open playing)
var close_t := INF           # s since it shut in the air
var lean := 0.0              # -1 left .. 1 right, eased: also banks the body (WardenAirTilt)
var burn_w := 0.0
var was_gliding := false
var heading_was := Vector2.ZERO

static func loops(ai: Dictionary) -> Array:
	return [ai["lean_l"], ai["lean_r"], ai["burn"]]

func _init(ai: Dictionary, lib: AnimationLibrary) -> void:
	air = ai
	open_len = lib.get_animation(String(ai["open"])).length
	close_len = lib.get_animation(String(ai["close"])).length

## The hold's subtree: open over (struggle over (the leaning hold)). Returns its output node.
func build_hold(t: AnimationNodeBlendTree, anim: Callable) -> String:
	t.add_node("glide", anim.call(String(air["glide"])))
	t.add_node("lean_l", anim.call(String(air["lean_l"])))
	t.add_node("lean_r", anim.call(String(air["lean_r"])))
	t.add_node("glide_lean", AnimationNodeBlend3.new())
	t.connect_node("glide_lean", 0, "lean_l")
	t.connect_node("glide_lean", 1, "glide")
	t.connect_node("glide_lean", 2, "lean_r")
	t.add_node("burn", anim.call(String(air["burn"])))
	t.add_node("burn_w", AnimationNodeBlend2.new())
	t.connect_node("burn_w", 0, "glide_lean")
	t.connect_node("burn_w", 1, "burn")
	return _over(t, "open", "burn_w", anim)

## The fall side: the close over the fall and rise. Returns its output node.
func build_fall(t: AnimationNodeBlendTree, anim: Callable, fall: String) -> String:
	return _over(t, "close", fall, anim)

## A one-shot clip laid over "under", seeked by its own clock.
func _over(t: AnimationNodeBlendTree, nm: String, under: String, anim: Callable) -> String:
	t.add_node(nm, anim.call(String(air[nm])))
	t.add_node(nm + "_at", AnimationNodeTimeSeek.new())
	t.connect_node(nm + "_at", 0, nm)
	t.add_node(nm + "_w", AnimationNodeBlend2.new())
	t.connect_node(nm + "_w", 0, under)
	t.connect_node(nm + "_w", 1, nm + "_at")
	return nm + "_w"

func step(tree: AnimationTree, s: Dictionary, dt: float) -> void:
	var gliding := bool(s.get("gliding", false))
	var grounded := bool(s.get("grounded", true))
	if gliding and not was_gliding:
		open_t = 0.0
		close_t = INF
	elif was_gliding and not gliding and not grounded and not bool(s.get("diving", false)):
		close_t = 0.0
		open_t = INF
	if grounded:
		close_t = INF                 # (a landing is the land clip's)
	was_gliding = gliding
	open_t += dt
	close_t += dt
	lean = lerpf(lean, steer(s, dt) if gliding else 0.0, 1.0 - exp(-dt * LEAN_RATE))
	burn_w = move_toward(burn_w, 1.0 if gliding and bool(s.get("burn", false)) else 0.0, dt * BURN_RATE)
	tree.set("parameters/glide_lean/blend_amount", lean)
	tree.set("parameters/burn_w/blend_amount", burn_w)
	tree.set("parameters/open_w/blend_amount", open_w())
	tree.set("parameters/close_w/blend_amount", close_w())
	if open_t < open_len:
		tree.set("parameters/open_at/seek_request", open_t)
	if close_t < close_len:
		tree.set("parameters/close_at/seek_request", close_t)

func open_w() -> float:
	if open_t >= open_len:
		return 0.0
	return minf(clampf(open_t / OPEN_IN, 0.0, 1.0), clampf((open_len - open_t) / OPEN_OUT, 0.0, 1.0))

func close_w() -> float:
	return clampf((close_len - close_t) / CLOSE_OUT, 0.0, 1.0) if close_t < close_len else 0.0

## How hard the glider is being steered, -1 left .. 1 right of the heading, as the body sees it (side-on it leans less,
## facing back the other way). The keys ("steer_in", world x/z) say it first; with none, the heading's own turn does.
func steer(s: Dictionary, dt: float) -> float:
	var vel: Vector3 = s.get("vel", Vector3.ZERO)
	var hv := Vector2(vel.x, vel.z)
	var was := heading_was
	heading_was = hv.normalized() if hv.length() > STEER_MIN else Vector2.ZERO
	if heading_was == Vector2.ZERO:
		return 0.0
	var keys: Vector2 = s.get("steer_in", Vector2.ZERO)
	var turn := 0.0
	if keys.length() > 0.1:
		turn = heading_was.cross(keys.normalized())
	elif was != Vector2.ZERO and dt > 0.0:
		turn = was.angle_to(heading_was) / dt / TURN_FULL
	var face := float(s.get("face", 0.0))
	return clampf(turn, -1.0, 1.0) * Vector2(-sin(face), -cos(face)).dot(heading_was)
