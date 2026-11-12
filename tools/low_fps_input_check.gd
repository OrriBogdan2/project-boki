extends "res://tools/dash_flow_check.gd"
## --low-fps-input-check: input survives low frame rates (docs/DECISIONS 2026-11-08: 30+ fps on low-end PCs).
## Part 1, taps: for every Hunter, with the render rate capped at 30 fps and then 20 fps (Engine.max_fps), and in a
## third round a 100 ms frame stall before the tap (OS.delay_msec: the next frame's delta is 0.1 s), each slot (LMB,
## RMB, E, the ult, Q, Shift, Space) is pressed and released between two reads of the keys, inside one render frame,
## and must still go off every time: no tap is lost at a low frame rate.
## Part 2, dashes: a dash at 30 fps, and at 60 fps with 100 ms stalls, runs the distance and time of the 60 fps dash
## within --move-feel-check's DASH_TOL. The frames are injected (Match._gather_input once per frame, then the fixed
## steps the frame's time buys, as Match._process does), so the numbers don't depend on the machine. The dash
## rounds run for DASH_HEROES (one dash path, DashPace, measured by the shared roll; the taps cover every kit).
## --low-fps-input-check=<id>,<id> picks the heroes. Never touches the save.

const MFC := preload("res://tools/move_feel_check.gd")
const DASH_HEROES := ["gunslinger", "mage", "juggernaut"]
const ACTION_OF := {"lmb": "fire", "rmb": "secondary", "e": "signature", "x": "hunter_ult", "q": "gear1",
		"dash": "dash", "jump": "jump"}
const TAPS := 3                 # taps per key and round
const CAP_FRAMES := 15          # frames timed to see a cap holds
const STALL_S := 0.1            # s: one frame's time lost (a disk read, a shader compile)
const STALL_EVERY := 5          # frames between stalls in the dash rounds
const SETTLE := 5               # frames a tap gets to show
const RISE := 0.05              # m: a jump has left the ground by this
const DASH_FRAMES := 150
const TAP_ROUNDS := [["30 fps cap", 30, false], ["20 fps cap", 20, false], ["30 fps + 100 ms stall", 30, true]]
const ROUNDS := [["30 fps", 1.0 / 30.0, false], ["60 fps + 100 ms stalls", 1.0 / 60.0, true]]

func ok(cond: bool, what: String) -> void:
	print("LOWFPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	var tree := main.get_tree()
	for hero in _hero_ids():
		var m := _match(main, hero)
		m.set_process(true)
		for r in TAP_ROUNDS:
			await _tap_round(tree, m, hero, r[0], r[1], r[2])
		Engine.max_fps = 0
		m.set_process(false)
		if hero in DASH_HEROES:
			for air in [false, true]:
				await _dash_rounds(tree, m, hero, air)
		m.queue_free()
		await tree.process_frame
	CombatBus.ability_used.disconnect(_on_used)
	print("LOWFPS DONE, failures: %d" % bad)
	main.get_tree().quit()

## Every slot tapped TAPS times with the frame rate capped at `cap` fps (the cap is timed on the first round at it).
func _tap_round(tree: SceneTree, m: Match, hero: String, round_name: String, cap: int, stall: bool) -> void:
	if Engine.max_fps != cap:
		Engine.max_fps = cap
		var t0 := Time.get_ticks_msec()
		for i in CAP_FRAMES:
			await tree.process_frame
		var ms := float(Time.get_ticks_msec() - t0) / CAP_FRAMES
		ok(ms >= 1000.0 / cap * 0.85, "%s: frames capped at %d fps: %.1f ms a frame" % [hero, cap, ms])
	for key in ACTION_OF:
		var lost := 0
		for i in TAPS:
			if not await _tap_trial(tree, m, key, stall):
				lost += 1
		ok(lost == 0, "%s %s tap, %s: %d/%d lost" % [hero, key, round_name, lost, TAPS])

func _hero_ids() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--low-fps-input-check=") and arg.length() > 22:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## An action pressed and let go before the next frame reads it (a real tap on a slow frame).
func _tap(action: String) -> void:
	_event(action, true)
	_event(action, false)

func _event(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	e.strength = 1.0 if down else 0.0
	Input.parse_input_event(e)

## One tap, in the continuation of a frame (before that frame's _process): did it go off within SETTLE frames? "Went
## off" is the dash-flow check's tell for the slot, plus the ones a tap of a hold leaves: the kit took the RMB press
## (rmb_t written; a tap under a draw's hold looses nothing, as at 60 fps), the weapon saw the LMB (Hunter.idle_fire
## reset: Cinder's lance tap is its pilot flicker, no shot), a kit's own dash started (a charge spent, in_dash).
func _tap_trial(tree: SceneTree, m: Match, key: String, stall: bool) -> bool:
	_ready_up(m)
	await tree.process_frame
	if stall:
		OS.delay_msec(int(STALL_S * 1000.0))
		await tree.process_frame
	var before := _snap()
	var y0 := hunter.pos.y
	var dash0 := hunter.dash_at
	var dashes0 := hunter.dashes
	var idle0 := hunter.idle_fire
	hunter.ak.rmb_t = -1.0
	_tap(ACTION_OF[key])
	for i in SETTLE:
		await tree.process_frame
		var went: bool
		match key:
			"dash": went = hunter.dash_at > dash0 or hunter.dashes < dashes0 or hunter.ak.in_dash()
			"jump": went = hunter.pos.y > y0 + RISE
			"rmb": went = hunter.ak.rmb_t >= 0.0 or _went_off(before, key)
			"lmb": went = hunter.idle_fire < idle0 or _went_off(before, key)
			_: went = _went_off(before, key)
		if went:
			return true
	return false

## One hero's dash, on the ground or in the air, at the rounds' frame rates against the 60 fps dash.
func _dash_rounds(tree: SceneTree, m: Match, hero: String, air: bool) -> void:
	var ref: Array = await _dash(tree, m, Match.DT, false, air)
	for r in ROUNDS:
		var got: Array = await _dash(tree, m, r[1], r[2], air)
		var tol: Array = MFC.DASH_TOL
		var hit: bool = ref[0] > 0.0 and absf(got[0] / ref[0] - 1.0) <= tol[0] and absf(got[1] - ref[1]) <= tol[1]
		var what := "%s %s dash %s" % [hero, "air" if air else "ground", r[0]]
		ok(hit, "%s: %.2f m in %.3f s, 60 fps %.2f m in %.3f s" % [what, got[0], got[1], ref[0], ref[1]])

## One dash (Shift held for the first frame, a move key until it starts) with frames of `fdt` seconds, every
## STALL_EVERY-th of them STALL_S when `stall`. Returns [metres, seconds] of the dash's travel, as
## --move-feel-check's felt dash measures it.
func _dash(tree: SceneTree, m: Match, fdt: float, stall: bool, air: bool) -> Array:
	_ready_up(m)
	if air:
		_lift()
	_event("right", true)
	_event("dash", true)
	var acc := 0.0
	var start := Vector3.INF
	var n := 0
	for f in DASH_FRAMES:
		await tree.process_frame
		m._gather_input()
		_event("dash", false)
		acc += DashPace.frame_dt(m, STALL_S if stall and f % STALL_EVERY == STALL_EVERY - 1 else fdt)
		while acc >= Match.DT:
			acc -= Match.DT
			var before := hunter.pos
			var left := minf(hunter.roll_t, Match.DT)
			m.step(Match.DT)
			if hunter.roll_t > 0.0:
				_event("right", false)
				if start == Vector3.INF:
					start = before
				n += 1
			elif start != Vector3.INF:
				var v := Vector2(hunter.vel.x, hunter.vel.z)
				var end := Vector2(hunter.pos.x, hunter.pos.z) - v * (Match.DT - left)
				return [end.distance_to(Vector2(start.x, start.z)), n * Match.DT + left]
	return [0.0, 0.0]
