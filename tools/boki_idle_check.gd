extends RefCounted
## --boki-idle-check: every rigged Boki's idle breathes and loops without a pop, and its fidget (BokiIdle) starts and
## ends on the idle's pose, comes every 4-9 s while it stands idle and never while it acts. Prints PASS/FAIL lines.

const Shots := preload("res://tools/boki_rig_shots.gd")
const Rig := preload("res://tools/boki_rig_check.gd")
const SEAM := 0.002            # rad / m: the loop's last key against its first
const MOVES := 0.03            # rad: the least an idle's breath or a fidget must swing
const SIM_S := 60.0
const ACTS := ["pet", "eat", "chop", "mine", "carry", "tend"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("BOKIIDLE %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	var rows := {}
	for id in Rig.SPECIES_LIST:
		var spec: Dictionary = (BokiIdle.config()["species"] as Dictionary).get(id, {})
		ok(not spec.is_empty(), "%s has an idle entry" % id)
		var sig := JSON.stringify(spec.get("fidget", {}).get("rows", []))
		ok(not rows.has(sig), "%s has a fidget of its own" % id)
		rows[sig] = id
		await _species(main, id)
	print("BOKIIDLE DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _species(main: Node, id: String) -> void:
	var k := Shots.rigged_kin(id)
	main.add_child(k)
	await main.get_tree().process_frame
	var rig := k.get_node("Body/Flex/BokiRig") as BokiRig
	var idle := rig.player.get_animation("idle")
	var fid := rig.player.get_animation(BokiIdle.FIDGET)
	ok(fid != null, "%s has its fidget" % id)
	if fid == null:
		k.queue_free()
		return
	var loops := idle.loop_mode == Animation.LOOP_LINEAR and fid.loop_mode == Animation.LOOP_NONE
	ok(loops, "%s: idle loops, the fidget plays once" % id)
	ok(is_equal_approx(fposmod(fid.length + 0.001, idle.length), 0.001), "%s: fidget a whole number of idle loops" % id)
	var seam := _seam(idle)
	ok(seam <= SEAM, "%s idle loop seam %.4f" % [id, seam])
	var swing := _swing(idle, idle)
	ok(swing >= MOVES, "%s idle breathes (%.3f rad)" % [id, swing])
	var win: Dictionary = BokiIdle.config()["species"][id]["fidget"]
	var stop := float(win["at"]) + float(win["dur"])
	ok(stop <= fid.length - 0.05, "%s fidget ends at %.1f s of its %.2f s clip" % [id, stop, fid.length])
	var ends := _ends(idle, fid)
	ok(ends <= SEAM, "%s fidget starts and ends on the idle's pose (%.4f)" % [id, ends])
	var move := _swing(fid, idle)
	ok(move >= MOVES and move <= 1.0, "%s fidget moves %.2f rad" % [id, move])
	_schedule(rig, id)
	_acting(rig, k, id)
	k.queue_free()

## Largest gap between the loop's end and its start, over every track (rad for turns, m for the rest).
func _seam(a: Animation) -> float:
	var worst := 0.0
	for t in a.get_track_count():
		worst = maxf(worst, _apart(a, t, a, t, 0.0, a.length))
	return worst

## How far the fidget is from the idle at its first and last frame.
func _ends(idle: Animation, fid: Animation) -> float:
	var worst := 0.0
	for t in fid.get_track_count():
		var i := idle.find_track(fid.track_get_path(t), fid.track_get_type(t))
		if i >= 0:
			worst = maxf(worst, maxf(_apart(fid, t, idle, i, 0.0, 0.0), _apart(fid, t, idle, i, fid.length, 0.0)))
	return worst

## The most `a` strays from `base` (same track paths), or from its own first frame when base is itself.
func _swing(a: Animation, base: Animation) -> float:
	var worst := 0.0
	for t in a.get_track_count():
		var i := base.find_track(a.track_get_path(t), a.track_get_type(t))
		for s in 60:
			var at := a.length * s / 59.0
			if a == base:
				worst = maxf(worst, _apart(a, t, a, t, at, 0.0))
			elif i >= 0:
				worst = maxf(worst, _apart(a, t, base, i, at, fposmod(at, base.length)))
	return worst

func _apart(a: Animation, ta: int, b: Animation, tb: int, at_a: float, at_b: float) -> float:
	match a.track_get_type(ta):
		Animation.TYPE_ROTATION_3D:
			return a.rotation_track_interpolate(ta, at_a).angle_to(b.rotation_track_interpolate(tb, at_b))
		Animation.TYPE_POSITION_3D:
			return a.position_track_interpolate(ta, at_a).distance_to(b.position_track_interpolate(tb, at_b))
		Animation.TYPE_SCALE_3D:
			return a.scale_track_interpolate(ta, at_a).distance_to(b.scale_track_interpolate(tb, at_b))
	return 0.0

## Standing still for a minute: a fidget every 4-9 s, none while it acts.
func _schedule(rig: BokiRig, id: String) -> void:
	var dt := 1.0 / 30.0
	var starts: Array = []
	var was := false
	var t := 0.0
	while t < SIM_S:
		rig._pick_clip(dt)
		rig.player.advance(dt)
		var fidgeting := rig.clip == BokiIdle.FIDGET
		if fidgeting and not was:
			starts.append(t)
		was = fidgeting
		t += dt
	var gaps_ok := starts.size() >= int(SIM_S / 9.0) - 1
	for i in range(1, starts.size()):
		var gap := float(starts[i]) - float(starts[i - 1])
		gaps_ok = gaps_ok and gap >= 4.0 - dt and gap <= 9.0 + dt
	ok(gaps_ok, "%s fidgets every 4-9 s (%d in %d s)" % [id, starts.size(), int(SIM_S)])

func _acting(rig: BokiRig, k: Node3D, id: String) -> void:
	var dt := 1.0 / 30.0
	var fidgets := 0
	var t := 0.0
	while t < SIM_S:
		var turn := int(t / 6.0)
		var doing := turn % 2 == 1                 # six s still, six s busy
		k.set_meta("kact", ACTS[turn % ACTS.size()] if doing else "")
		rig._pick_clip(dt)
		rig.player.advance(dt)
		if doing and rig.clip == BokiIdle.FIDGET:
			fidgets += 1
		t += dt
	k.set_meta("kact", "")
	ok(fidgets == 0, "%s never fidgets while it acts" % id)
