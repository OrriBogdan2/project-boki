extends RefCounted
## --look-at-check: the head's look-at layer (WardenLookAt) on every Hunter's own model (12 and up). The head bone is
## read before the layer and after the whole frame (Probe), so its turn is measured on the skeleton and not taken
## from the layer's word. A 60 degree cursor swing with the body turning at
## HunterMove.turn_rate: the head leads, inside the clamp, never past the aim, and is back at rest when the body
## arrives. A 170 degree swing stays inside the clamp. An aim held off the body is followed in yaw and pitch. A dash,
## a stun, an emote, no aim (a knock, a remote Hunter) and a full-body kit clip switch it off.
## Never touches the save.

const DT := 1.0 / 60.0
const SWING := deg_to_rad(60.0)        # rad: the cursor swing of the task
const WIDE := deg_to_rad(170.0)        # rad: a swing wider than the clamp
const LEAD_MIN := deg_to_rad(8.0)      # rad: the least the head leads the body by on the 60 degree swing
const WIDE_MIN := deg_to_rad(45.0)     # rad: and on the wide one
const BONE_TOL := deg_to_rad(2.0)      # rad: the head bone's measured turn against the layer's figure
const SETTLE := 30                     # frames standing before and after a swing
const OFF_FRAMES := 4                  # frames: WardenLookAt.OFF_S at 60 Hz, rounded up
const CLIP_MIN := 0.4                  # s: a kit clip long enough to take the whole body over

var bad := 0
var holder: Node3D
var sync: WardenGlb.Sync       # the Hunter's model
var probe: Probe
var face := 0.0                # rad: the body's facing, both twins
var bone_err := 0.0            # rad: the worst the measured bone was off the layer's figure, this Hunter

func ok(cond: bool, what: String) -> void:
	print("LOOK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var ids := Arch.ids()
	ok(ids.size() >= 12, "every Hunter of the roster, 12 or more (%d)" % ids.size())
	var casts := 0
	for id in ids:
		casts += _hunter(String(id))
	ok(casts > 0, "a full-body kit clip was played on %d Hunters" % casts)
	print("LOOK_AT_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The layer with the head bone's pose kept from just before it turned it.
class Probe extends WardenLookAt:
	var before := Basis.IDENTITY

	func step(dt: float, clips: WardenClips) -> void:
		if bone >= 0:
			before = skel.get_bone_global_pose(bone).basis.orthonormalized()
		super.step(dt, clips)

## The Hunter's model, stepped by hand, its look-at layer swapped for a Probe on the same bone.
func _model(id: String) -> bool:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	sync = m.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync == null or sync.head_look == null or sync.head_look.bone < 0:
		return false
	sync.set_process(false)
	probe = Probe.new()
	probe.root = sync.head_look.root
	probe.skel = sync.head_look.skel
	probe.bone = sync.head_look.bone
	sync.head_look = probe
	return true

## All of one Hunter's checks; returns 1 when it had a full-body kit clip to play.
func _hunter(id: String) -> int:
	if not _model(id):
		ok(false, "%s: a model with a head bone" % id)
		return 0
	face = 0.0
	bone_err = 0.0
	_stand(0.0, SETTLE)
	ok(_shown() == Vector2.ZERO, "%s: aiming where he faces, the head is at rest" % id)
	_swing_checks(id, SWING, LEAD_MIN, "60")
	_swing_checks(id, -SWING, LEAD_MIN, "-60")
	_swing_checks(id, WIDE, WIDE_MIN, "170")
	_hold_checks(id)
	_dash_check(id)
	var cast := _off_checks(id)
	var worst := rad_to_deg(bone_err)
	ok(bone_err <= BONE_TOL, "%s: the head bone turns by the layer's figure (worst %.2f deg off)" % [id, worst])
	sync.root.queue_free()
	return cast

## One frame on this state; `look` is the aim (ZERO: none).
func _frame(look: Vector3, extra := {}) -> void:
	var s := {"face": face, "grounded": true, "fired": 99.0, "vel": Vector3.ZERO}
	s.merge(extra)
	s[WardenLookAt.LOOK] = look
	sync.root.rotation.y = face
	sync.root.set_meta(WardenClips.STATE, s)
	sync._process(DT)
	var got := _bone()
	bone_err = maxf(bone_err, absf(wrapf(got.x - _shown().x, -PI, PI)))
	bone_err = maxf(bone_err, absf(got.y - _shown().y))

func _aim(yaw: float, slope := 0.0) -> Vector3:
	return Vector3(-sin(yaw), slope, -cos(yaw))

func _shown() -> Vector2:
	return probe.shown

## The head bone's turn over the frame's look-at, in the model's frame (rad: x about its up, + his left; y up).
func _bone() -> Vector2:
	var after := sync.skel.get_bone_global_pose(probe.bone).basis.orthonormalized()
	var to_model := WardenGlb.model_xf(sync.root, sync.skel).basis.orthonormalized()
	var fwd := (to_model * after * probe.before.inverse() * to_model.inverse()) * Vector3.FORWARD
	return Vector2(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))

func _bone_yaw() -> float:
	return _bone().x

## Frames with the body still and the aim `off` rad from it.
func _stand(off: float, frames: int, extra := {}, slope := 0.0) -> void:
	for f in frames:
		_frame(_aim(face + off, slope), extra)

## The cursor jumps `by` rad; the body turns to it as Hunter does. Returns the head's peak turn (rad, signed like
## `by`) and the furthest it looked past the aim (rad).
func _swing(by: float) -> Vector2:
	var aim_yaw := face + by
	var peak := 0.0
	var past := 0.0
	for f in SETTLE:
		face = rotate_toward(face, aim_yaw, HunterMove.turn_rate * DT)
		_frame(_aim(aim_yaw))
		var left := wrapf(aim_yaw - face, -PI, PI) * signf(by)
		var head := _shown().x * signf(by)
		peak = maxf(peak, head)
		past = maxf(past, head - left)
	return Vector2(peak, past)

func _swing_checks(id: String, by: float, lead: float, label: String) -> void:
	var r := _swing(by)
	var deg := rad_to_deg(r.x)
	ok(r.x >= lead, "%s: a %s degree swing, the head leads the body (peak %.1f deg)" % [id, label, deg])
	ok(r.x <= WardenLookAt.YAW_MAX + 0.0001, "%s: %s swing inside the clamp (peak %.1f deg)" % [id, label, deg])
	ok(r.y <= 0.0001, "%s: %s swing, never past the aim (%.2f deg)" % [id, label, rad_to_deg(r.y)])
	ok(_shown() == Vector2.ZERO, "%s: %s swing, at rest once the body has turned" % [id, label])

## An aim held off the body (a locked facing): followed to it in yaw, and to the clamp in yaw and pitch.
func _hold_checks(id: String) -> void:
	_stand(SWING, SETTLE)
	ok(absf(_shown().x - SWING) < 0.01, "%s: holds an aim 60 degrees off (%.1f deg)" % [id, rad_to_deg(_shown().x)])
	ok(absf(_bone_yaw() - SWING) <= BONE_TOL, "%s: the bone is there (%.1f deg)" % [id, rad_to_deg(_bone_yaw())])
	_stand(-WIDE, SETTLE)
	ok(absf(_shown().x + WardenLookAt.YAW_MAX) < 0.01, "%s: clamped in yaw (%.1f deg)" % [id, rad_to_deg(_shown().x)])
	_stand(0.0, SETTLE, {}, 1.0)
	var up := _shown().y
	ok(absf(up - WardenLookAt.PITCH_MAX) < 0.01, "%s: looks up, clamped (%.1f deg)" % [id, rad_to_deg(up)])
	ok(absf(_bone().y - up) <= BONE_TOL, "%s: the bone is pitched there (%.1f deg)" % [id, rad_to_deg(_bone().y)])
	_stand(0.0, SETTLE, {}, -0.2)
	ok(absf(_shown().y + atan(0.2)) < 0.01, "%s: looks down a slope (%.1f deg)" % [id, rad_to_deg(_shown().y)])
	_stand(0.0, SETTLE)

## A dash begun with the head turned: eased off inside OFF_S, then zero until the dash ends.
func _dash_check(id: String) -> void:
	_stand(SWING, SETTLE)
	var before := absf(_shown().x)
	var dash := {"rolling": true, "dash_dir": Vector2(-sin(face), -cos(face)), "dash_kind": "roll"}
	var frames := ceili(Hunter.DASH_TIME / DT)
	var eased := true
	var zero := true
	for f in frames:
		_frame(_aim(face + SWING), dash)
		if f < OFF_FRAMES:
			eased = eased and absf(_shown().x) < before
			before = absf(_shown().x)
		else:
			zero = zero and _shown() == Vector2.ZERO and absf(_bone_yaw()) < 0.001
	ok(eased, "%s: a dash eases the head back" % id)
	ok(zero, "%s: zero through the dash from %d frames in (of %d)" % [id, OFF_FRAMES, frames])
	_stand(0.0, SETTLE)

## A stun, an emote, no aim (a knock, a remote Hunter) and a full-body kit clip, each from a turned head.
## Returns 1 when the Hero had such a clip.
func _off_checks(id: String) -> int:
	for off in [["a stun", {"stun": true}, true], ["an emote", {"emote": "wave", "emote_t": 0.0}, true],
			["no aim (a knock, a remote Hunter)", {}, false]]:
		_stand(SWING, SETTLE)
		for f in OFF_FRAMES + 1:
			_frame(_aim(face + SWING) if bool(off[2]) else Vector3.ZERO, off[1])
		ok(_shown() == Vector2.ZERO and absf(_bone_yaw()) < 0.001, "%s: off for %s" % [id, off[0]])
	var move := _full_body_move()
	if move == "":
		return 0
	_stand(SWING, SETTLE)
	for f in ceili(CLIP_MIN / DT):
		_frame(_aim(face + SWING), {"kmove": move, "kmove_t": f * DT})
	ok(_shown() == Vector2.ZERO, "%s: off under the full-body clip of %s" % [id, move])
	return 1

## A kit move of this Hero keyed as a full-body clip at least CLIP_MIN long ("" none).
func _full_body_move() -> String:
	if sync.clips == null:
		return ""
	var moves: Dictionary = sync.clips.d.get("kmoves", {})
	for id in moves:
		var mv: Dictionary = moves[id]
		if mv.has("upper") or mv.has("hold_from") or mv.has("lead") or mv.has("fade"):
			continue
		if sync.clips.lib.get_animation(String(mv["clip"])).length >= CLIP_MIN:
			return String(id)
	return ""
