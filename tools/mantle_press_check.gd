extends RefCounted
## --mantle-press-check: a press made while a hunter rises up a ledge (Hunter._ledge_rise) does what its row in
## content/rules/mantle_press.json says, for every hero and for LMB, RMB, E, R, dash and jump, pressed early in the
## rise: "fire" goes off mid-climb, "buffer" goes off at the top and never in the rise. Either way the press is
## never lost and the hunter still tops the ledge (no press cancels the climb). A row the source doesn't show
## ("seen": false) must buffer. Reuses --dash-flow-check's training patch and its "did it go off" probes; a slot
## that doesn't go off in the air without a mantle either is skipped and named. --mantle-press-check=<id>,<id> runs
## only those heroes. Never touches the save. Prints "MPRESS ok|FAIL ..." and "MPRESS DONE, failures: N".

const INPUTS := ["lmb", "rmb", "e", "x", "dash", "jump"]
const START_BELOW := 1.35       # m under the top, in the air against the face (as --mantle-check's fling)
const PRESS_ON := 2             # the step of the rise the press is made on (early: most of the rise to go)
const WATCH := 90               # steps after the press that we watch for it to go off and for the top
const LEDGE_UP := 2             # terraces: a 1.6 m ledge, a jump's mantle
const AIM_ON := 2.0             # m past the face the aim sits, on top of the ledge (where you'd aim climbing it)

var bad := 0
var skipped := 0
var flow = preload("res://tools/dash_flow_check.gd").new()

func ok(cond: bool, what: String) -> void:
	print("MPRESS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for input in INPUTS:
		var mode := DashFlow.mantle_mode(input)
		ok(mode in ["fire", "buffer"], "the %s row is fire or buffer (%s)" % [input, mode])
	CombatBus.ability_used.connect(flow._on_used)
	for hero in _heroes():
		var m: Match = flow._match(main, hero)
		var ledge := _ledge(m)
		for input in INPUTS:
			_input(m, hero, input, ledge)
		m.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(flow._on_used)
	print("MPRESS DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

## Every hero, or the ones named in --mantle-press-check=<id>,<id>.
func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mantle-press-check=") and arg.length() > 21:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## Raises a 1.6 m ledge just east of home on the flat training patch; returns where the face is and its top.
func _ledge(m: Match) -> Dictionary:
	var w: World = m.world
	var home: Vector3 = flow.get_meta("home")
	var cx := int(floor(home.x))
	var cz := int(floor(home.z))
	var lv := int(w.level[w.idx(cx, cz)])
	for dz in range(-3, 4):
		for dx in range(3, 7):
			w.level[w.idx(cx + dx, cz + dz)] = lv + LEDGE_UP
	return {"x": cx + 3.0, "z": cz + 0.5, "top": (lv + LEDGE_UP) * World.LEVEL}

func _input(m: Match, hero: String, input: String, ledge: Dictionary) -> void:
	var row := DashFlow.mantle_row(input)
	var want := DashFlow.mantle_mode(input)
	if not bool(row.get("seen", false)):
		ok(want == "buffer", "%s: the source doesn't show it, so it buffers (row: %s)" % [input, want])
	if input in DashFlow.SLOTS and not flow._goes_idle(m, input, true):
		skipped += 1
		print("MPRESS skip %s %s: it doesn't go off in the air without a mantle either" % [hero, input])
		return
	var got := _trial(m, input, ledge)
	ok(got[0] == want and got[1], "%s mantle -> %s: %s, %s (row: %s)" % [hero, input, got[0],
			"topped the ledge" if got[1] else "never reached the top", want])

## One press in one rise: ["fire" (went off in the rise), "buffer" (went off once it was over) or "lost", whether
## the hunter got to the top].
func _trial(m: Match, input: String, ledge: Dictionary) -> Array:
	var h: Hunter = flow.hunter
	flow._ready_up(m)
	var top: float = ledge["top"]
	h.teleport(Vector3(float(ledge["x"]) - h.r - 0.05, top - START_BELOW, float(ledge["z"])))
	h.vel = Vector3.ZERO
	h.grounded = false
	h.inp["aim"] = Vector3(float(ledge["x"]) + AIM_ON, top + 0.9, float(ledge["z"]))     # (an aimed dash goes up there)
	var rising := 0
	var before := {}
	var got := "lost"
	var topped := false
	for i in WATCH + PRESS_ON + 20:
		h.inp["move"] = Vector2(1, 0)
		var in_rise := h.mantling()
		rising += 1 if in_rise else 0
		var press_now := before.is_empty() and rising == PRESS_ON
		if press_now:
			before = _snap(h)
			_press(h, input)
		m.step(Match.DT)
		h.inp["fire"] = false        # LMB is a tap: one step down
		topped = topped or h.pos.y >= top - 0.02
		if not before.is_empty() and got == "lost" and _went_off(h, before, input, in_rise, top):
			got = "fire" if in_rise else "buffer"
		if got != "lost" and topped:
			break
	return [got, topped]

func _press(h: Hunter, input: String) -> void:
	if input in DashFlow.MANTLE_MOVES:
		h.inp[input] = true
	else:
		flow._press(input)

func _snap(h: Hunter) -> Dictionary:
	var s: Dictionary = flow._snap()
	s["dash_at"] = h.ak.dash_press_at
	return s

## Did the press go off this step? A dash reached the kit; a jump flung (the rise ended under the top) or, buffered,
## took off from the ground; the slots by --dash-flow-check's probe.
func _went_off(h: Hunter, before: Dictionary, input: String, in_rise: bool, top: float) -> bool:
	match input:
		"dash":
			return h.ak.dash_press_at > float(before["dash_at"])
		"jump":
			if in_rise:
				return not h.mantling() and h.pos.y < top
			return not h.mantling() and h.vel.y >= Hunter.JUMP_V - 0.01
	return flow._went_off(before, input)
