extends RefCounted
## --idle-break-check: every one of the 12 Hunters breaks its idle once (WardenBreak, content/rules/idle_breaks.json).
## Per Hunter: nothing before 6 s of calm standing, the break starts after it and moves the bones, it runs 2 to 3 s and
## returns to the idle (and does not come again at once); a key press cancels it at once (through the real input path);
## it never starts or keeps going in combat (a hit, a shot or an ability under 6 s ago), while moving, or for a state
## without the "idle_break" flag (town, title). Never touches the save.

const DT := 1.0 / 15.0
const MOVE_MIN := 0.08         # rad: how far the break turns a bone off the same frame without it
const FADE_WITHIN := 0.15      # s a cancelled break takes to unwind
const DUR_MIN := 2.0           # s
const DUR_MAX := 3.0           # s

var bad := 0
var holder: Node3D
var tree: SceneTree

func ok(cond: bool, what: String) -> void:
	print("IDLEBREAK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	tree = main.get_tree()
	holder = Node3D.new()
	main.add_child(holder)
	for id in Arch.ORDER:
		await _hunter(String(id))
	print("IDLE BREAK CHECK DONE, failures: ", bad)
	tree.quit(1 if bad > 0 else 0)

func _state(extra := {}) -> Dictionary:
	var s := {"idle_break": true, "grounded": true, "fired": 99.0, "vel": Vector3.ZERO}
	s.merge(extra, true)
	return s

## Runs the Hunter's frames for `secs` with state `s`; returns true when the break was playing at any frame.
func _run(model: Node3D, sync: Node, s: Dictionary, secs: float) -> bool:
	var seen := false
	model.set_meta(WardenClips.STATE, s)
	for k in int(secs / DT):
		sync.call("_process", DT)
		seen = seen or (sync.get("idle_break") as WardenBreak).playing()
	return seen

func _hunter(id: String) -> void:
	var model := Models.hunter(Arch.weight(id), Data.TEAM_COLORS[0], Arch.signature(id), "", PlayerLook.neutral(), id)
	holder.add_child(model)
	for k in 30:
		await tree.process_frame
	var sync := model.get_node("Warden/Sync")
	sync.set_process(false)
	var brk := sync.get("idle_break") as WardenBreak
	ok(brk != null, "%s has a break" % id)
	if brk == null:
		return
	ok(brk.dur >= DUR_MIN and brk.dur <= DUR_MAX, "%s: the break runs %.1f s (%.0f to %.0f)"
			% [id, brk.dur, DUR_MIN, DUR_MAX])
	var town := _state({"idle_break": false})
	ok(not _run(model, sync, town, 6.5), "%s: no break without the flag (town, title)" % id)
	var moving := _state({"vel": Vector3(3, 0, 0)})
	ok(not _run(model, sync, moving, 6.5), "%s: no break while moving" % id)
	for key in ["hit_t", "fired", "cast"]:
		ok(not _run(model, sync, _state({key: 3.0}), 6.5), "%s: no break in combat (%s 3 s ago)" % [id, key])
	brk.press()
	ok(not _run(model, sync, _state(), WardenBreak.WAIT - 0.3), "%s: no break before 6 s of calm" % id)
	ok(_run(model, sync, _state(), 0.6), "%s: the break starts after 6 s of calm" % id)
	_moves_bones(id, model, sync, brk)
	await _cancel(id, model, sync, brk)
	await _returns(id, model, sync, brk)
	model.queue_free()
	await tree.process_frame

## The progress (0..1) at which the break's tracks turn the bones most.
func _peak(brk: WardenBreak) -> float:
	var best := 0.0
	var peak := 0.5
	for i in 50:
		var u := i / 50.0
		var turned := 0.0
		for tr in brk.tracks:
			turned += (tr["rot"] as Vector3).length() * WardenBreak.amount(tr, u)
		if turned > best:
			best = turned
			peak = u
	return peak

## At its peak, the bones sit off where they stand without it.
func _moves_bones(id: String, model: Node3D, sync: Node, brk: WardenBreak) -> void:
	brk.press()
	_run(model, sync, _state(), WardenBreak.WAIT + brk.dur * _peak(brk))
	var skel: Skeleton3D = brk.skel
	var with := {}
	for tr in brk.tracks:
		with[tr["bone"]] = skel.get_bone_global_pose(int(tr["bone"])).basis.get_rotation_quaternion()
	sync.set("idle_break", null)
	sync.call("_process", DT)
	var worst := 0.0
	for bone in with:
		var plain := skel.get_bone_global_pose(int(bone)).basis.get_rotation_quaternion()
		worst = maxf(worst, (with[bone] as Quaternion).angle_to(plain))
	sync.set("idle_break", brk)
	ok(worst >= MOVE_MIN, "%s: the break turns a bone %.2f rad (>= %.2f)" % [id, worst, MOVE_MIN])

## A key press (the real input path) ends it in the same frame and unwinds it in a few.
func _cancel(id: String, model: Node3D, sync: Node, brk: WardenBreak) -> void:
	brk.press()
	_run(model, sync, _state(), WardenBreak.WAIT + brk.dur * 0.4)
	ok(brk.playing(), "%s: playing before the press" % id)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	model.get_viewport().push_input(key)
	ok(not brk.playing(), "%s: the first press cancels it at once" % id)
	_run(model, sync, _state(), FADE_WITHIN)
	ok(brk.fade == 0.0 and not brk.playing(), "%s: back on the idle %.2f s after the press" % [id, FADE_WITHIN])
	ok(not _run(model, sync, _state(), WardenBreak.WAIT - 0.5), "%s: a press restarts the 6 s wait" % id)

## Left alone it plays once, ends, and waits the gap before it comes again.
func _returns(id: String, model: Node3D, sync: Node, brk: WardenBreak) -> void:
	brk.press()
	_run(model, sync, _state(), WardenBreak.WAIT + brk.dur + 0.5)
	ok(not brk.playing() and brk.fade == 0.0, "%s: the break ended and the idle is back" % id)
	ok(not _run(model, sync, _state(), WardenBreak.GAP - 0.5), "%s: it does not repeat at once" % id)
	brk.press()
	_run(model, sync, _state(), WardenBreak.WAIT + brk.dur * 0.3)
	var hit := _state({"hit_t": 0.0})
	_run(model, sync, hit, DT * 2.0)
	ok(not brk.playing(), "%s: a hit ends it" % id)
