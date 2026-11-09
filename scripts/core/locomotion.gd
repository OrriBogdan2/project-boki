class_name Loco
extends RefCounted
## ONE movement model for the farm avatar (Home) and every match hunter (Hunter, the Training Area too): ground,
## air and glide steps, the dash ease, and the locomotion state machine both own (docs/decisions/0022). Numbers
## come from content/rules/tuning.json, re-read live while the movement readout is open (MoveReadout).

enum S {GROUNDED, AIRBORNE, GLIDING, DASHING, MANTLING, KNOCKED, STUNNED}
const NAMES: PackedStringArray = ["Grounded", "Airborne", "Gliding", "Dashing", "Mantling", "Knocked", "Stunned"]
## Where each state may go. Gliding is entered only from the air or a dash (never the ground: no hold-to-glide
## off a jump), and entering a dash folds the glider (exit hook): never both at once.
const TABLE := {
	S.GROUNDED: [S.AIRBORNE, S.DASHING, S.MANTLING, S.KNOCKED, S.STUNNED],
	S.AIRBORNE: [S.GROUNDED, S.GLIDING, S.DASHING, S.MANTLING, S.KNOCKED, S.STUNNED],
	S.GLIDING: [S.AIRBORNE, S.GROUNDED, S.DASHING, S.MANTLING, S.KNOCKED, S.STUNNED],
	S.DASHING: [S.GROUNDED, S.AIRBORNE, S.GLIDING, S.MANTLING, S.KNOCKED, S.STUNNED],
	S.MANTLING: [S.GROUNDED, S.AIRBORNE, S.GLIDING, S.KNOCKED, S.STUNNED],
	S.KNOCKED: [S.GROUNDED, S.AIRBORNE, S.STUNNED],
	S.STUNNED: [S.GROUNDED, S.AIRBORNE, S.KNOCKED],
}
const PATH := "res://content/rules/tuning.json"

static var T: Dictionary = {}
static var air_accel := 0.0
static var air_counter := 0.0
static var air_side := 0.0
static var air_drag := 0.0
static var air_idle_drag := 0.0
static var glide_accel := 0.0
static var glide_turn := 0.0
static var glide_turn_fast := 0.0
static var glide_brake := 0.0
static var glide_brake_deg := 0.0
static var glide_drag := 0.0
static var glide_drag_steer := 0.0
static var glide_coast := 0.0
static var glide_catch := 0.0
static var glide_max := 0.0
static var carry_drag := 0.0
static var dash_jump_keep := 0.0
static var _mtime := 0
static var _loaded := load_tuning()

## (Re)reads tuning.json into the static knobs. True when it parsed.
static func load_tuning() -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_warning("tuning.json did not parse: keeping the last good numbers")
		return false
	T = parsed
	_mtime = FileAccess.get_modified_time(PATH)
	var a: Dictionary = T["air"]
	air_accel = a["accel"]
	air_counter = a["counter"]
	air_side = a["side"]
	air_drag = a["drag"]
	air_idle_drag = a["idle_drag"]
	var g: Dictionary = T["glide"]
	glide_accel = g["accel"]
	glide_turn = g["turn"]
	glide_turn_fast = g["turn_fast"]
	glide_brake = g["brake"]
	glide_brake_deg = g["brake_deg"]
	glide_drag = g["drag"]
	glide_drag_steer = g["drag_steer"]
	glide_coast = g["coast"]
	glide_catch = g["catch"]
	glide_max = g["max"]
	carry_drag = T["glide_carry"]["carry_drag"]
	dash_jump_keep = T["dash"]["jump_keep"]
	return true

## Re-reads the file if it changed on disk (the readout calls this every poll_s while open).
static func poll() -> void:
	if FileAccess.get_modified_time(PATH) != _mtime:
		load_tuning()

## A fresh locomotion state machine for one mover.
static func machine() -> Fsm:
	return Fsm.new(NAMES, TABLE, S.GROUNDED)

## The most speed this hunter carries from Shift into a glide before carry_drag bites (m/s).
static func glide_carry(arch: String) -> float:
	var c: Dictionary = T["glide_carry"]
	return float(c.get(arch, c["default"]))

## A dash's speed share at `u` (0..1 through it) for this hunter, and how much longer it runs (speed scale
## and ease from tuning.json dash_ease; flat 1.0 for a hunter not listed). The ease averages 1 over the dash.
static func dash_k(arch: String, u: float) -> float:
	var e: Dictionary = T["dash_ease"].get(arch, {})
	if e.is_empty():
		return 1.0
	return float(e["speed"]) * (1.0 - float(e["ease"]) * cos(TAU * u))

static func dash_time_k(arch: String) -> float:
	return 1.0 / float(T["dash_ease"].get(arch, {}).get("speed", 1.0))

## A dash's velocity with `left` of its `total` s to go: `v` (its direction x its flat speed) through the hunter's
## ease. The farm avatar and a match hunter both dash through this, so a Shift feels the same everywhere.
static func dash_hv(v: Vector2, arch: String, left: float, total: float) -> Vector2:
	return v * dash_k(arch, 1.0 - left / maxf(total, left))

## Momentum-preserving ground acceleration: under the wanted speed, move toward it; over it (a dash, a pad, a
## knock) bleed the extra at `over` while still steering, and steering back against it brakes properly.
static func accel_to(cur: Vector2, wish: Vector2, accel: float, decel: float, over: float, dt: float) -> Vector2:
	var mx := wish.length()
	if mx < 0.001:
		return cur.move_toward(Vector2.ZERO, decel * dt)
	var cs := cur.length()
	if cs <= mx:
		return cur.move_toward(wish, accel * dt)
	var wd := wish / mx
	var against := maxf(0.0, -(cur / cs).dot(wd))
	var ns := maxf(cs - (over + accel * against) * dt, mx)
	var d := (cur / cs).lerp(wd, clampf(accel * dt / cs, 0.0, 1.0))
	if d.length_squared() < 0.0001:
		d = wd
	return d.normalized() * ns

## One air step: strong WASD air control, as SUPERVIVE (DECISIONS 11-08). Never overwrites what you carry: the keys
## (length <= 1) add air_accel toward where they point. The part of your speed against them brakes at
## air_counter x that, the part across them at air_side x (the arc bends). Along them you gain only up to
## `cap` (your run speed); speed above the cap (a dash, a knock, a launch) bleeds under air_drag, never clipped.
static func air_step(hv: Vector2, keys: Vector2, cap: float, dt: float) -> Vector2:
	var s := hv.length()
	if s > cap:
		hv *= (cap + (s - cap) * exp(-air_drag * dt)) / s
		s = hv.length()
	var k := minf(keys.length(), 1.0)
	if k < 0.01:
		return hv * exp(-air_idle_drag * dt)
	var wd := keys / keys.length()
	var along := hv.dot(wd)
	var across := hv - wd * along
	var a := air_accel * k * dt
	if along < 0.0:
		var b := a * air_counter
		along = along + b if along + b < 0.0 else (along + b) / air_counter     # what's left pushes at the normal rate
	else:
		along = minf(along + a, maxf(along, cap * k))
	across = across.move_toward(Vector2.ZERO, a * air_side)
	return (wd * along + across).limit_length(maxf(s, cap))

## One glide step. `wish` = keys x cruise speed `gs`; `carry` = the most this hunter carries from Shift. Speed
## above cruise bleeds back within ~1.5 s (glide_drag; glide_drag_steer while steering), faster above `carry`;
## at or under cruise the glider pulls toward where you steer; a let-go coasts. Turns in wider arcs when fast.
static func glide_step(hv: Vector2, wish: Vector2, gs: float, carry: float, dt: float) -> Vector2:
	var s := hv.length()
	var ws := wish.length()
	if s > gs:
		var ns := gs + (s - gs) * exp(-(glide_drag_steer if ws >= 0.05 else glide_drag) * dt)
		if s > carry:
			ns = minf(ns, carry + (s - carry) * exp(-(carry_drag + glide_drag) * dt))
		hv *= ns / s
		s = ns
	if ws < 0.05:
		return hv if s > gs else hv.move_toward(Vector2.ZERO, glide_coast * dt)
	if s <= gs + 0.05:
		return hv.move_toward(wish, glide_accel * dt)
	var d := hv / s
	var ang := d.angle_to(wish / ws)
	if absf(ang) > deg_to_rad(glide_brake_deg):
		return hv.move_toward(wish, glide_brake * dt)     # pulling back against your heading
	var fast := clampf((s - gs) / maxf(0.1, glide_max - gs), 0.0, 1.0)
	var rate := deg_to_rad(glide_turn) * lerpf(1.0, glide_turn_fast, fast)
	return d.rotated(clampf(ang, -rate * dt, rate * dt)) * s

# ---------------------------------------------------------------- the movement readout's numbers
## The local mover writes these each step (no allocation); MoveReadout shows them.
static var r_hs := 0.0           # horizontal speed, m/s
static var r_vs := 0.0           # vertical speed, m/s
static var r_cap := 0.0          # the speed the current state steers up to (run speed, glide cruise), m/s
static var r_fsm: Fsm

static func report(fsm: Fsm, hv: Vector2, vy: float, cap: float) -> void:
	r_fsm = fsm
	r_hs = hv.length()
	r_vs = vy
	r_cap = cap

## The drag the reported state applies above its cap (1/s).
static func drag_now() -> float:
	if r_fsm == null:
		return 0.0
	match r_fsm.state:
		S.AIRBORNE: return air_drag
		S.GLIDING: return glide_drag
	return 0.0
