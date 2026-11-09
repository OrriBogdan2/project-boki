class_name TutFunnel
extends RefCounted
## Where testers speed through, stall at, skip or quit the two tutorials ("match" and "farm").
## Per step it keeps [entered, finished, idle, hints, end]:
##   entered / finished   whole seconds on that tutorial's own clock (it runs only while the tutorial does,
##                        so it adds up across launches); finished is -1 until the step ends
##   idle                 seconds in the step with no key or mouse movement (after IDLE_AFTER of quiet)
##   hints                extra help shown: the match's stall reminder, a later hint line on the farm
##   end                  "done", "skip", or "" (entered and never ended: the tester quit there)
## The numbers live in the feedback file (Feedback.funnel) and go out with the rate card's answer. No names,
## ids or dates: nothing beyond what the card already sends. tools/tut_funnel.py turns a folder of them into a table.

const IDLE_AFTER := 5.0     # s without input before time in a step counts as idle
const SAVE_EVERY := 10.0    # s between writes while a step is open, so a quit keeps the latest numbers
const IN := 0
const OUT := 1
const IDLE := 2
const HINTS := 3
const END := 4

static var _f: Dictionary = {}          # track -> step id -> [entered, finished, idle, hints, end]
static var _clock: Dictionary = {}      # track -> s on its clock
static var _cur: Dictionary = {}        # track -> the step in progress
static var _stage: Dictionary = {}      # track -> that step's hint stage
static var _quiet := 0.0                # s since the last input
static var _since_save := 0.0
static var loaded := false

## Forgets everything in memory (checks swap Feedback.path, then call this).
static func reset() -> void:
	_f = {}
	_clock = {}
	_cur = {}
	_stage = {}
	_quiet = 0.0
	_since_save = 0.0
	loaded = false

static func _ensure() -> void:
	if loaded:
		return
	loaded = true
	_f = Feedback.funnel()
	for track in _f:
		var top := 0.0
		for rec in (_f[track] as Dictionary).values():
			top = maxf(top, maxf(float(rec[IN]), float(rec[OUT])))
		_clock[track] = top

static func _rec(track: String, sid: String) -> Array:
	_ensure()
	if not _f.has(track):
		_f[track] = {}
	if not (_f[track] as Dictionary).has(sid):
		_f[track][sid] = [float(_clock.get(track, 0.0)), -1.0, 0.0, 0, ""]
	return _f[track][sid]

static func _input_active() -> bool:
	return Input.is_anything_pressed() or Input.get_last_mouse_velocity() != Vector2.ZERO

## `sid` is now the step the tester is on (a repeat call is a no-op). A new hint stage within the same step
## counts as one more hint.
static func enter(track: String, sid: String, stage := "") -> void:
	if sid == "":
		return
	if _cur.get(track, "") == sid:
		var rec := _rec(track, sid)
		if stage != String(_stage.get(track, "")) and String(_stage.get(track, "")) != "" and String(rec[END]) == "":
			rec[HINTS] += 1
		_stage[track] = stage
		return
	_rec(track, sid)
	_cur[track] = sid
	_stage[track] = stage
	save()

## An extra prompt went up on the current step (the match's stall reminder).
static func hint(track: String) -> void:
	var sid := String(_cur.get(track, ""))
	if sid != "":
		_rec(track, sid)[HINTS] += 1

## The step is finished (it may never have been the current one: the farm can find it already done).
static func leave(track: String, sid: String) -> void:
	var rec := _rec(track, sid)
	if String(rec[END]) == "":      # (the match calls this every frame after extraction: write once)
		rec[OUT] = float(_clock.get(track, 0.0))
		rec[END] = "done"
		save()

## The tester skipped the tutorial: the step they were on ends as "skip".
static func skip(track: String) -> void:
	var sid := String(_cur.get(track, ""))
	if sid != "":
		var rec := _rec(track, sid)
		if String(rec[END]) == "":
			rec[OUT] = float(_clock.get(track, 0.0))
			rec[END] = "skip"
			save()

## Time passes in the current step. `active` is whether the tester is touching keys or the mouse.
static func tick(track: String, dt: float, active := _input_active()) -> void:
	_clock[track] = float(_clock.get(track, 0.0)) + dt
	_quiet = 0.0 if active else _quiet + dt
	var sid := String(_cur.get(track, ""))
	if sid != "" and _quiet >= IDLE_AFTER:
		_rec(track, sid)[IDLE] += dt
	_since_save += dt
	if _since_save >= SAVE_EVERY:
		save()

## The numbers as they go out: whole seconds, only tracks that have a step.
static func payload() -> Dictionary:
	_ensure()
	var out := {}
	for track in _f:
		var steps := {}
		for sid in _f[track]:
			var r: Array = _f[track][sid]
			steps[sid] = [roundi(r[IN]), roundi(r[OUT]), roundi(r[IDLE]), int(r[HINTS]), String(r[END])]
		if not steps.is_empty():
			out[track] = steps
	return out

static func save() -> void:
	_since_save = 0.0
	if loaded:
		Feedback.set_funnel(payload())
