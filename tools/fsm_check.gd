extends "res://tools/glide_hold_check.gd"
## --fsm-check (briefs/STATE_MACHINES.md): every state machine's table has the pattern's shape (enum-sized names,
## a row per state, targets that exist, no self-edges, every state reachable), then the glider's edges (M2a) are
## driven with a player's keys through a Hunter's machine (HunterLoco) and the log must read as the rules say,
## with no refused transition: a second Space in the air opens it (Airborne>Gliding press), Space held from the
## jump never does, letting go feathers (Gliding>Airborne let go), Shift folds it (Gliding>Dashing) and it stays
## shut while Space is still held, the press mid air Shift cancels into the glide (Dashing>Gliding press), and a
## pad opens it by itself at the apex (Airborne>Gliding auto). Prints "FSM ok|FAIL ..." and "FSM DONE, failures: N".

## Every machine in the game: label, a fresh instance and its enum's size. Each migration adds its machine here.
static func machines() -> Array:
	return [["loco", Loco.machine(), Loco.S.size()]]

func ok(cond: bool, what: String) -> void:
	print("FSM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The table's shape: enum-sized names, a row per state, targets that exist, no self-edges, all reachable.
func _table_shape(label: String, f: Fsm, enum_size: int) -> void:
	var n := f.names.size()
	ok(n == enum_size, "%s: %d names for an enum of %d" % [label, n, enum_size])
	ok(f.table.size() == n and range(n).all(func(s: int) -> bool: return f.table.has(s)),
		"%s: every state has a row" % label)
	var stray := 0
	var self_edges := 0
	for s in f.table:
		for t in f.table[s]:
			if int(t) < 0 or int(t) >= n:
				stray += 1
			elif int(t) == int(s):
				self_edges += 1
	ok(stray == 0 and self_edges == 0,
		"%s: every target is a state, no self-edges (%d stray, %d self)" % [label, stray, self_edges])
	var seen := {f.state: true}
	var open := [f.state]
	while not open.is_empty():
		for t in f.table.get(open.pop_back(), []):
			if not seen.has(t):
				seen[t] = true
				open.append(t)
	var unreached := range(n).filter(func(s: int) -> bool: return not seen.has(s))
	ok(unreached.is_empty(), "%s: every state reachable from %s (%d not)" % [label, f.state_name(), unreached.size()])

## Runs `script` (Callable(i) -> void, the keys each step) for SECS from `lift` m up with a player's keys, as
## glide_hold_check's scenarios, the machine's log cleared first; returns the log joined.
func _drive(script: Callable, lift := 0.3) -> String:
	_reset(w.random_ground() + Vector3(0, 0.3, 0), Vector3.ZERO)
	for i in 60: m.step(Match.DT)        # 1s on the ground: the last scenario's move ends
	if lift > 0.3:
		_reset(h.pos + Vector3(0, lift, 0), Vector3.ZERO)
		h.coyote = 0.0
		for i in 2: m.step(Match.DT)      # the locomotion state leaves GROUNDED
	h.inp["glide_press_only"] = true
	h.inp["aim"] = h.pos + Vector3(8, 0.9, 0)
	h.inp["move"] = Vector2.ZERO
	h.loco.history.clear()
	h.loco.refused = 0
	for i in int(SECS / Match.DT):
		for k in ["jump", "glide", "glide_btn", "dash"]:
			h.inp[k] = false
		script.call(i)
		m.step(Match.DT)
	return " ".join(h.loco.history)

## A row: the log holds `edges` (each once) and none of `never`, and nothing was refused.
func _row(log: String, what: String, edges: Array, never := []) -> void:
	var good := h.loco.refused == 0
	for e in edges:
		good = good and log.count(e) == 1
	for e in never:
		good = good and not log.contains(e)
	ok(good, "%s: %s (refused %d)" % [what, log.strip_edges(), h.loco.refused])

func _glider_rows() -> void:
	var held := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
	_row(_drive(held), "jump and hold Space: never Gliding", ["Grounded>Airborne"], ["Gliding"])
	var double := func(i: int) -> void:
		h.inp["glide"] = i == 0 or i >= 12
		h.inp["jump"] = i == 0 or i == 12
	_row(_drive(double), "jump, a second Space press opens the glider", ["Airborne>Gliding press"])
	# high in the air the first Space press is a glide press
	var let_go := func(i: int) -> void:
		h.inp["glide"] = i < 100
		h.inp["jump"] = i == 0
	var log := _drive(let_go, HIGH)
	_row(log, "let go: Gliding>Airborne, feathering", ["Airborne>Gliding press", "Gliding>Airborne let go"])
	ok(h.moves.feathering() and not h.gliding,
		"feathering %.2fs after the let-go, under FEATHER_KEEP" % h.moves.let_go_t)
	var shift := func(i: int) -> void:
		held.call(i)
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = i == 40
	_row(_drive(shift, HIGH), "Shift while gliding folds it; Space still held never reopens it",
		["Airborne>Gliding press", "Gliding>Dashing"], ["Dashing>Gliding", "Airborne>Gliding held"])
	var into := func(i: int) -> void:
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = i == 0
		h.inp["glide"] = i >= 4
		h.inp["jump"] = i == 4
	_row(_drive(into, 30.0), "a Space press mid air Shift cancels the dash into the glide",
		["Dashing>Gliding press"])
	var pad := func(i: int) -> void:
		if i == 0:
			PadFlight.launch_up(h)
	_row(_drive(pad), "a pad: the glider opens by itself at the apex, no press", ["Airborne>Gliding auto"], ["press"])

func run(main: Node) -> void:
	Save.no_write = true
	for mach in machines():
		_table_shape(mach[0], mach[1], mach[2])
	var arch := ""
	for a in Arch.ORDER:
		if not SWALLOWS.has(a):
			arch = a
			break
	_start(main, arch)
	_glider_rows()
	m.queue_free()
	print("FSM DONE, failures: ", bad)
	main.get_tree().quit()
