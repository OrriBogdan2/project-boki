extends RefCounted
## --turn-step-check: every Hunter turning on the spot re-plants its feet (scripts/heroes/warden_turn.gd). Standing
## in the idle clip, per Hunter: a 180 degree flip of the aim takes two steps with alternating feet; the feet are 90
## degrees or more behind the body right after the flip and come round within 0.6 s; a 60 degree flip then leaves
## them planted (no step); the hips keep the body's own yaw all the while (the aim, and so a cast, is never turned
## or delayed); walking away unwinds the feet. Never touches the save.

const DT := 1.0 / 60.0
const SETTLE_T := 0.6          # s a 180 degree flip may take to get the feet round
const LEFTOVER := 0.45         # rad the feet may still trail after SETTLE_T

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("TURNSTEP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	for id in Arch.ORDER:
		_hunter(String(id))
	print("TURN_STEP_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hunter(id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync") as WardenGlb.Sync
	var clips: WardenClips = sync.clips
	ok(clips != null and clips.turn != null, "%s: the turn step is wired" % id)
	if clips == null or clips.turn == null:
		m.free()
		return
	var turn := clips.turn
	var sk := WardenGlb.skeleton(m.get_node("Warden"))
	var thigh := WardenSkeleton.find(sk, "thigh.L")
	var hips := WardenSkeleton.find(sk, "hips")
	var face := 0.0
	_run(m, sync, face, 0.5)
	var hips_was := angle_difference(_yaw(sk, hips), face)
	# 180 degrees: two steps, feet far behind straight after the flip, round again soon
	face += PI
	var seen := 0.0
	var order: Array = []
	var yaw_off := 0.0
	var hips_off := 0.0
	var t := 0.0
	while t < SETTLE_T + 0.4:
		var before := turn.step_t
		_feed(m, sync, face)
		if turn.step_t >= 0.0 and (before < 0.0 or turn.step_t < before):
			order.append(turn.side)
		seen = maxf(seen, absf(turn.trail))
		t += DT
		if t < DT * 1.5:
			yaw_off = angle_difference(_yaw(sk, thigh), face)
			hips_off = absf(angle_difference(angle_difference(_yaw(sk, hips), face), hips_was))
		if t >= SETTLE_T and absf(turn.trail) > LEFTOVER:
			break
	ok(seen > 2.8, "%s: 180 deg flip leaves the feet behind (%.2f rad)" % [id, seen])
	ok(order.size() == 2 and order[0] != order[1], "%s: two steps, feet alternate %s" % [id, str(order)])
	ok(absf(turn.trail) <= LEFTOVER and turn.step_t < 0.0,
			"%s: feet round after %.1f s (trail %.2f rad)" % [id, SETTLE_T, turn.trail])
	ok(hips_off < 0.05,
			"%s: hips keep the body's yaw (%.3f rad off a frame), the feet turn (%.2f)" % [id, hips_off, yaw_off])
	# 60 degrees: planted
	face += deg_to_rad(60.0)
	var steps := _run(m, sync, face, 0.6, turn)
	ok(steps == 0 and absf(turn.trail) > 0.9,
			"%s: 60 deg flip, feet stay planted (trail %.2f rad, %d steps)" % [id, turn.trail, steps])
	# walking off unwinds anything left
	_feed(m, sync, face, Vector3(0, 0, -4))
	for i in 60:
		_feed(m, sync, face, Vector3(0, 0, -4))
	ok(absf(turn.trail) < 0.05, "%s: walking unwinds the feet (%.3f rad)" % [id, turn.trail])
	m.free()

## A bone's heading in the world (bone z is the model's back).
func _yaw(sk: Skeleton3D, bone: int) -> float:
	var z := (sk.global_transform.basis * sk.get_bone_global_pose(bone).basis).z
	return atan2(z.x, z.z)

## Hold `face` for `secs`; the steps taken (a step starting).
func _run(m: Node3D, sync: WardenGlb.Sync, face: float, secs: float, turn: WardenTurn = null) -> int:
	var n := 0
	for i in int(secs / DT):
		var before := turn.step_t if turn else 0.0
		_feed(m, sync, face)
		if turn and turn.step_t >= 0.0 and (before < 0.0 or turn.step_t < before):
			n += 1
	return n

func _feed(m: Node3D, sync: WardenGlb.Sync, face: float, vel := Vector3.ZERO) -> void:
	m.rotation.y = face
	m.set_meta(WardenClips.STATE, {"vel": vel, "face": face, "grounded": true, "fired": 99.0})
	sync.call("_process", DT)
