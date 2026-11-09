class_name WardenStance
extends RefCounted
## A Warden's signature stance (content/rules/warden_stance.json): pose offsets on the shared rig's bones, so
## the procedural model and a 3D model that follows the same bones stand alike. Full while standing, held
## at a reduced weight through runs, aiming and abilities so the attitude never drops, and gone in the
## whole-body moves (downed, gliding, ledges, dodges). An idle cycle on top: the breath, the weight shifting
## off the signature leg and back, and a signature fidget every few seconds. HunterAnim reads the outputs.

const RULES := "warden_stance"
const SHIFT_BACK := 0.35       # x the shift period: how long the weight stays on the other leg
const FIDGET_IDLE := 1.0       # s standing still before the signature fidget's clock runs
const ABILITY_T := 0.6         # s after a cast that counts as an ability
const AIM_HOLD := 1.1          # s after a shot that the weapon stays up (HunterAnim's aim)
const RELEASE := 40.0          # 1/s: how fast the carry lets go when they fire (0.1 s: under 2% left)

## The stance's outputs this frame (read by HunterAnim).
var body := Vector3.ZERO       # torso pitch, yaw, roll (added)
var head := Vector3.ZERO       # head pitch, yaw, roll (added)
var hip := Vector3.ZERO        # the rig's offset (m)
var hip_l := Vector2.ZERO      # left leg hip, knee (added)
var hip_r := Vector2.ZERO
var spread := 0.0              # the legs wider apart (rad, each)
var arm_l := Vector3.ZERO      # the free left hand's offset (m)
var breath_k := 1.0            # x the breathing
var carry_w := 0.0             # how far the weapon sits in its signature carry
var fidgets := 0               # signature fidgets played (checks read it)

var _on := false
var _w := 0.0                  # body weight (eased)
var _idle_w := 0.0             # legs, hips, hands and the carry (eased)
var _leg := 1.0                # the signature weight leg (-1 left, 1 right)
var _spine := 0.0
var _tilt := 0.0
var _twist := 0.0
var _hip := Vector3.ZERO       # side shift, lift, back
var _knee := 0.0
var _spread := 0.0
var _free_leg := Vector2.ZERO
var _head := Vector3.ZERO
var _arm_l := Vector3.ZERO
var _carry := Transform3D.IDENTITY
var _has_carry := false
var _carry_free := 0.0
var _carry_free_r := 0.0      # a weapon carried in the left hand alone (Hem's bow at her side)
var _breath_amp := 1.0
var _shift := 9.0
var _shift_t := 0.0
var _fid_every := 6.0
var _fid_dur := 1.0
var _fid_wave := 0.0
var _fid_body := Vector3.ZERO
var _fid_head := Vector3.ZERO
var _fid_hip := Vector3.ZERO
var _fid_gun := Vector3.ZERO
var _fid_wait := 6.0
var _fid_t := -1.0
var _carry_k := 0.0            # the carry's own ease: lets go fast on a shot, settles back slowly
var _blend := {}

func _init(arch: String) -> void:
	var all := Content.rules(RULES)
	_blend = all.get("blend", {})
	var d: Dictionary = all.get(arch, {})
	if d.is_empty():
		return
	_on = true
	var p: Dictionary = d["pose"]
	_leg = -1.0 if String(d.get("leg", "r")) == "l" else 1.0
	_spine = float(p.get("spine", 0.0))
	_tilt = float(p.get("tilt", 0.0))
	_twist = float(p.get("twist", 0.0))
	_hip = Vector3(float(p.get("hip", 0.0)), float(p.get("lift", 0.0)), float(p.get("back", 0.0)))
	_knee = float(p.get("knee", 0.0))
	_spread = float(p.get("spread", 0.0))
	_free_leg = _v2(p.get("free_leg", []))
	_head = _v3(p.get("head", []))
	_arm_l = _v3(p.get("arm_l", []))
	var c: Dictionary = p.get("carry", {})
	_has_carry = not c.is_empty()
	if _has_carry:
		_carry = Transform3D(Basis.from_euler(_v3(c["rot"])), _v3(c["pos"]))
		_carry_free = float(c.get("free_l", 0.0))
		_carry_free_r = float(c.get("free_r", 0.0))
	var idle: Dictionary = d["idle"]
	_breath_amp = float(idle.get("breath_amp", 1.0))
	_shift = float(idle.get("shift", 9.0))
	var f: Dictionary = idle.get("fidget", {})
	_fid_every = float(f.get("every", 6.0))
	_fid_dur = float(f.get("dur", 1.0))
	_fid_wave = float(f.get("wave", 0))
	_fid_body = _v3(f.get("body", []))
	_fid_head = _v3(f.get("head", []))
	_fid_hip = _v3(f.get("hip", []))
	_fid_gun = _v3(f.get("gun", []))
	_fid_wait = _fid_every

## The archetype's gait over its class (HunterAnim.STANCE keys, with its idle breath rate); empty for none.
static func gait(arch: String) -> Dictionary:
	var d: Dictionary = Content.rules(RULES).get(arch, {})
	if d.is_empty():
		return {}
	var out: Dictionary = (d["gait"] as Dictionary).duplicate()
	out["breath"] = float(d["idle"]["breath"])
	return out

## True for a Warden with a stance.
func has_stance() -> bool:
	return _on

## True while the signature fidget plays (the generic fidgets wait for it).
func fidgeting() -> bool:
	return _fid_t >= 0.0

## Which leg the weight wants: the signature leg, shifting to the other one now and then.
func weight_side(cur: float) -> float:
	if not _on:
		return cur
	return -_leg if _shift_t > _shift else _leg

## Advances the stance one frame from the animator's state and works out the outputs.
func tick(dt: float, a: HunterAnim, s: Dictionary) -> void:
	if not _on:
		return
	var r1 := minf(a.run_k, 1.0)
	var off := _whole_body(a)
	var busy := not a.km.is_empty() or a.swing_t < a.swing_dur or a.cast_now < ABILITY_T
	var want := (1.0 - off) * lerpf(1.0, float(_blend.get("move", 0.45)), r1)
	want *= lerpf(1.0, float(_blend.get("aim", 0.55)), a.aim_k)
	want *= float(_blend.get("ability", 0.4)) if busy else 1.0
	var want_idle := 0.0 if busy else (1.0 - off) * (1.0 - r1) * (1.0 - a.air_k) * (1.0 - a.crouch_k)
	var k := 1.0 if a.snap else 1.0 - exp(-float(_blend.get("rate", 7.0)) * dt)
	_w = lerpf(_w, want, k)
	_idle_w = lerpf(_idle_w, want_idle, k)
	_shift_t = fmod(_shift_t + dt, _shift * (1.0 + SHIFT_BACK))
	_tick_fidget(dt, a)
	var fe := _fidget_env()
	var side := a.weight
	body = Vector3(-_spine, _twist, -_tilt * side) * _w + _fid_body * fe
	head = _head * _w + _fid_head * fe
	hip = Vector3(_hip.x * side, _hip.y, _hip.z) * _idle_w + _fid_hip * fe
	var free_l := (1.0 + side) * 0.5      # the weight on the right leaves the left one free
	var free_r := 1.0 - free_l
	hip_l = Vector2(_free_leg.x * free_l + _knee * 0.5, -_free_leg.y * free_l - _knee) * _idle_w
	hip_r = Vector2(_free_leg.x * free_r + _knee * 0.5, -_free_leg.y * free_r - _knee) * _idle_w
	spread = _spread * _idle_w
	arm_l = _arm_l * _idle_w
	breath_k = lerpf(1.0, _breath_amp, _w)
	_tick_carry(dt, a, s)

## The signature carry's weight: off at once when they fire, reload, drink or fidget with the weapon.
func _tick_carry(dt: float, a: HunterAnim, s: Dictionary) -> void:
	if not _has_carry:
		return
	var firing := float(s.get("fired", 99.0)) < AIM_HOLD or float(s.get("charge", 0.0)) > 0.0 or a.aim_k > 0.5
	var busy := float(s.get("reload", -1.0)) >= 0.0 or a.fidget in ["weapon", "stretch"] or a.drink_k > 0.0
	var want := 0.0 if firing or busy else 1.0
	var rate := RELEASE if want < _carry_k else float(_blend.get("rate", 7.0))
	_carry_k = want if a.snap else lerpf(_carry_k, want, 1.0 - exp(-rate * dt))
	carry_w = _idle_w * _carry_k * (1.0 - a.carry_k)

## The weapon's place under Aim with the signature carry blended in (the aim pose when firing).
func carry(xf: Transform3D) -> Transform3D:
	if carry_w <= 0.001:
		return xf
	var fe := _fidget_env()
	var to := Transform3D(_carry.basis * Basis.from_euler(_fid_gun * fe), _carry.origin)
	return Transform3D(xf.basis.slerp(to.basis, carry_w), xf.origin.lerp(to.origin, carry_w))

## How far the carry lets the left hand off the weapon.
func carry_free_l() -> float:
	return _carry_free * carry_w

## How far the carry lets the right hand off the weapon (a bow hanging in the left hand).
func carry_free_r() -> float:
	return _carry_free_r * carry_w

## How far a whole-body move (downed, gliding, a ledge, a dodge, a trick...) takes over from the stance.
func _whole_body(a: HunterAnim) -> float:
	var off := maxf(maxf(a.down_k, a.glide_k), maxf(a.dive_k, a.ledge_k))
	off = maxf(off, maxf(maxf(a.revive_k, a.act_k), maxf(a.base_k, a.stomp_k)))
	off = maxf(off, maxf(maxf(a.dash_k, a.emote_k), a.stun_k))
	if a.roll_t >= 0.0 or a.trick != "":
		off = 1.0
	return clampf(off, 0.0, 1.0)

func _tick_fidget(dt: float, a: HunterAnim) -> void:
	if _fid_t >= 0.0:
		_fid_t += dt
		if _fid_t >= _fid_dur or _idle_w < 0.5:
			_fid_t = -1.0
			_fid_wait = _fid_every
		return
	if _idle_w < 0.9 or a.idle_t < FIDGET_IDLE or a.fidget != "":
		return
	_fid_wait -= dt
	if _fid_wait <= 0.0:
		_fid_t = 0.0
		fidgets += 1

## The signature fidget's weight now: up and back down over its length, waving `wave` times if it waves.
func _fidget_env() -> float:
	if _fid_t < 0.0:
		return 0.0
	var p := clampf(_fid_t / maxf(_fid_dur, 0.01), 0.0, 1.0)
	var e := sin(p * PI)
	if _fid_wave > 0.0:
		e *= sin(p * TAU * _fid_wave)
	return e

static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a.size() == 3 else Vector3.ZERO

static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a.size() == 2 else Vector2.ZERO
