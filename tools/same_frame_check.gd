extends "res://tools/dash_flow_check.gd"
## --same-frame-check: fast fingers land two presses in one physics step. As in the source, the dash goes first and
## the other press then does what its 'dash then X' row in content/dash_flow says (DashFlow: it goes mid-dash, waits
## for the dash's end, or ends the dash), never before the dash and never lost. Every hero, on the ground and in
## the air, gets Shift with LMB, RMB, E and R on one step, and Space with Shift, whose reference is Space pressed
## the step after Shift (a dash with a wind-up, like the Wirerun's charge, may hold the jump off either way).
## Prints the hero x pair matrix. --same-frame-check=<id>,<id> runs only those heroes. Never touches the save.

const PAIRS := ["lmb", "rmb", "e", "x", "jump"]
const NAMES := {"lmb": "Shift+LMB", "rmb": "Shift+RMB", "e": "Shift+E", "x": "Shift+R", "jump": "Space+Shift"}
const CUT_STEPS := 2            # steps: a dash this much shorter than the dash alone was ended by the press
const RISE_TOL := 0.3           # m: two jumps within this of each other's height are the same jump

var matrix := {}                # hero -> pair -> "ground/air" results

func ok(cond: bool, what: String) -> void:
	print("SAMEFRAME %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(_on_used)
	for hero in _same_frame_heroes():
		var m := _match(main, hero)
		for pair in PAIRS:
			var cells := []
			for in_air in [false, true]:
				cells.append(_pair(m, hero, pair, in_air))
			matrix.get_or_add(hero, {})[pair] = "/".join(cells)
		m.queue_free()
		await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(_on_used)
	_print_matrix()
	print("SAMEFRAME DONE, failures: %d, skipped: %d" % [bad, skipped])
	main.get_tree().quit()

func _same_frame_heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--same-frame-check=") and arg.length() > 19:
			return arg.get_slice("=", 1).split(",")
	return Arch.ORDER

## One pair on one step, checked against its row (or, for Space, against the jump a step into the dash).
## Returns the matrix cell.
func _pair(m: Match, hero: String, pair: String, in_air: bool) -> String:
	var where := "air" if in_air else "ground"
	var full := _dash_alone(m, in_air)
	if full < 0:
		skipped += 1
		print("SAMEFRAME skip %s %s %s: no dash DashFlow sees here" % [hero, where, NAMES[pair]])
		return "n/a"
	if pair == "jump":
		var got := _jump_trial(m, in_air, false)
		var want := _jump_trial(m, in_air, true)
		var same: bool = absf(got["rise"] - want["rise"]) < RISE_TOL and absi(got["dash"] - want["dash"]) <= 1
		ok(same, "%s %s %s: %s (dash then jump: %s)" % [hero, where, NAMES[pair], _jump_str(got), _jump_str(want)])
		return _jump_str(got)
	if not _goes_idle(m, pair, in_air):
		skipped += 1
		print("SAMEFRAME skip %s %s %s: it doesn't go off without a dash here either" % [hero, where, NAMES[pair]])
		return "skip"
	var row := String(DashFlow.row_of(hero, pair, in_air)["mode"])
	var got := _press_trial(m, pair, in_air, full)
	ok(got == row, "%s %s %s: %s (dash then %s row: %s)" % [hero, where, NAMES[pair], got, pair, row])
	return got

## Control: how many steps the dash alone runs (-1: none DashFlow sees).
func _dash_alone(m: Match, in_air: bool) -> int:
	_ready_up(m)
	if in_air:
		_lift()
	_shift()
	var n := 0
	for i in DASH_WAIT + 60:
		m.step(Match.DT)
		if hunter.ak.in_dash():
			n += 1
		elif n > 0:
			break
	return n if n > 0 else -1

## Shift and the slot on one step: "fire" (went off mid-dash), "buffer" (went off once the dash ran out),
## "cancel" (went off as the dash stopped short), "first" (went off before the dash), "no dash" or "lost".
func _press_trial(m: Match, slot: String, in_air: bool, full: int) -> String:
	_ready_up(m)
	if in_air:
		_lift()
	var dash_was := hunter.dash_at
	var before := _snap()
	_shift()
	_press(slot)
	if _went_off(before, slot):
		return "first"            # R goes off on the key, before the step that starts the dash
	var dash_n := 0
	var dash_from := -1
	for i in WATCH:
		m.step(Match.DT)
		hunter.inp["fire"] = false
		var dashing := hunter.ak.in_dash()
		if dashing:
			dash_n += 1
			dash_from = i if dash_from < 0 else dash_from
		if not _went_off(before, slot):
			continue
		var started := dash_from >= 0 or hunter.dash_at > dash_was
		if not started:
			return "no dash"
		if dash_from < 0 or i < dash_from:
			# the dash never showed after a step, or the press beat it: ended on the press, or went first
			return "cancel" if dash_from < 0 and hunter.dash_at > dash_was else "first"
		if dashing:
			return "fire"
		return "cancel" if dash_n < full - CUT_STEPS else "buffer"
	return "lost"

## Space with Shift on one step (`after`: Space the step after Shift): how high the hunter rose and how
## many steps the dash ran.
func _jump_trial(m: Match, in_air: bool, after: bool) -> Dictionary:
	_ready_up(m)
	if in_air:
		_lift()
	var y0 := hunter.pos.y
	_shift()
	hunter.inp["jump"] = not after
	var top := y0
	var dash_n := 0
	for i in DASH_WAIT + 60:
		m.step(Match.DT)
		hunter.inp["jump"] = after and i == 0
		dash_n += 1 if hunter.ak.in_dash() else 0
		top = maxf(top, hunter.pos.y)
	return {"rise": top - y0, "dash": dash_n}

func _jump_str(r: Dictionary) -> String:
	return "%s %d" % ["jump" if float(r["rise"]) > RISE_TOL else "flat", int(r["dash"])]

func _shift() -> void:
	hunter.inp["move"] = Vector2(0, -1)
	hunter.inp["dash"] = true

## R as the keyboard sends it (Match reads the key outside the step); the rest as the dash-flow check presses them.
func _press(slot: String) -> void:
	if slot == "x":
		HunterKeys.press(hunter)
	else:
		super._press(slot)

func _print_matrix() -> void:
	var head := "hero        "
	for pair in PAIRS:
		head += " | %-17s" % NAMES[pair]
	print("SAMEFRAME matrix (ground/air; jump: rise and dash steps)")
	print("SAMEFRAME " + head)
	for hero in matrix:
		var line := "%-12s" % hero
		for pair in PAIRS:
			line += " | %-17s" % String(matrix[hero].get(pair, ""))
		print("SAMEFRAME " + line)
