extends RefCounted
## --turn-step-check: turning on the spot (TurnStep, WardenTurn) on every Hero with clips. A standing 180° swing of
## the aim steps the feet round and no planted foot slides more than SLIDE (the same swing with the step off is
## printed beside it); a small turn stays an upper-body lead; moving, a cast, a shot or a kit move never steps, and
## moving cancels a step at once. Never touches the save.

const DT := 1.0 / 60.0
const SLIDE := 0.03           # m: the most a planted foot may slide
const SWING := 0.3            # s: the 180° swing of the aim
const SETTLE := 1.4           # s after it for the steps to finish
const LIFTS := 0.02           # m: a stepping foot leaves the ground at least this far

var bad := 0
var holder: Node3D

func ok(cond: bool, what: String) -> void:
	print("TURN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	holder = Node3D.new()
	main.add_child(holder)
	var n := 0
	for id in Arch.ids():
		if WardenClips.data(WardenGlb.art(String(id))).is_empty():
			continue
		n += 1
		_hero(String(id))
	ok(n == 12, "all 12 Heroes have clips (%d)" % n)
	print("TURN_STEP_CHECK_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _hero(id: String) -> void:
	var m := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	m.set_meta("anim_seed", 1)
	holder.add_child(m)
	var sync := m.get_node("Warden/Sync")
	sync.set_process(false)
	var clips: WardenClips = sync.get("clips")
	var an := HunterAnim.new(m)
	var steps := clips.turn
	if steps == null:
		ok(bool(clips.d.get("rig_root", false)), "%s: no step only for a body that rides the rig (no feet)" % id)
		m.free()
		return
	var off := _swing(m, an, sync, steps, {}, false)
	clips.turn = steps
	var on := _swing(m, an, sync, steps, {}, true)
	ok(on["slide"] < SLIDE, "%s: 180° on the spot, planted feet slide %.1f cm (no step: %.1f cm)"
			% [id, on["slide"] * 100.0, off["slide"] * 100.0])
	ok(on["steps"] >= 2 and on["lift"] > LIFTS and absf(an.spot.lag) < TurnStep.STEP_AGAIN,
			"%s: %d steps, the foot lifts %.1f cm, the legs end under the body (lag %.2f rad)"
			% [id, on["steps"], on["lift"] * 100.0, an.spot.lag])
	var small := _swing(m, an, sync, steps, {}, true, PI / 4.0)
	ok(small["steps"] == 0 and absf(an.spot.lag) > 0.6, "%s: a 45° turn keeps the upper-body lead (no step)" % id)
	for busy in [{"vel": Vector3(0, 0, -3.0)}, {"cast": 0.1}, {"fired": 0.05}, {"kmove": "x", "kmove_t": 0.1}]:
		var r := _swing(m, an, sync, steps, busy, true)
		ok(r["steps"] == 0, "%s: no step while %s" % [id, str(busy.keys()[0])])
	# a step under way stops the moment he moves
	_rest(m, an, sync)
	var t := 0.0
	while an.spot.t < 0.0 and t < SWING:
		t += DT
		_play(m, an, sync, {}, PI * t / SWING, DT)
	_play(m, an, sync, {"vel": Vector3(0, 0, -3.0)}, PI, DT)
	ok(an.spot.t < 0.0 and steps.pin_w.max() < 1.0, "%s: moving cancels the step at once" % id)
	m.free()

## One frame (or `dur` s of frames) at facing `face`, the state `extra` laid over a standing one.
func _play(m: Node3D, an: HunterAnim, sync: Node, extra: Dictionary, face: float, dur: float) -> void:
	var s := {"vel": Vector3.ZERO, "face": face, "grounded": true, "fired": 99.0}
	s.merge(extra, true)
	var t := 0.0
	while t < dur - 0.0001:
		m.rotation.y = face
		an.update(DT, s)
		sync.call("_process", DT)
		t += DT

## Back to facing 0 with the legs under him: a few steps of a walk, then standing.
func _rest(m: Node3D, an: HunterAnim, sync: Node) -> void:
	_play(m, an, sync, {"vel": Vector3(0, 0, -3.0)}, 0.0, 0.3)
	_play(m, an, sync, {}, 0.0, 0.6)

## The aim swung by `turn` over SWING s, then held: {slide (m, the worst planted foot), steps, lift (m)}.
func _swing(m: Node3D, an: HunterAnim, sync: Node, steps: WardenTurn, extra: Dictionary, step_on: bool,
		angle := PI) -> Dictionary:
	var clips: WardenClips = sync.get("clips")
	clips.turn = steps
	_rest(m, an, sync)
	if not step_on:
		clips.turn = null
	var serial := an.spot.serial
	var sk := steps.skel
	var anchor: Array = [null, null]
	var floor_y: Array = [0.0, 0.0]
	var slide := 0.0
	var lift := 0.0
	var t := 0.0
	while t < SWING + SETTLE:
		t += DT
		_play(m, an, sync, extra, angle * minf(t / SWING, 1.0), DT)
		for f in 2:
			var at: Vector3 = sk.global_transform * steps.ankle(f)
			if an.spot.t >= 0.0 and an.spot.swing == f and step_on:
				anchor[f] = null
				lift = maxf(lift, at.y - float(floor_y[f]))
			elif anchor[f] == null:
				anchor[f] = at
				floor_y[f] = at.y
			else:
				slide = maxf(slide, Vector2(at.x - anchor[f].x, at.z - anchor[f].z).length())
	clips.turn = steps
	return {"slide": slide, "steps": an.spot.serial - serial, "lift": lift}
