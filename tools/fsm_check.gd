extends RefCounted
## --fsm-check (briefs/STATE_MACHINES.md, M1): builds every state machine from its table and asserts its edges:
## the names match the enum, every state has a row, every target is a state, no self-edges, every state is
## reachable from the start. Then drives one machine through the pattern's rules: the table and a guard refuse
## and log why, guard_from guards one edge and not another, go(to, why) stamps the log with the machine's
## clock, the log is capped, and a labelled machine is listed in Fsm.live for the F7 readout.
## Prints "FSM ok|FAIL ..." and "FSM DONE, failures: N".

var bad := 0

## Every machine in the game: label, a fresh instance and its enum's size. Each migration adds its machine here.
static func machines() -> Array:
	return [["loco", Loco.machine(), Loco.S.size()]]

func ok(cond: bool, what: String) -> void:
	print("FSM %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	for m in machines():
		_edges(m[0], m[1], m[2])
	_pattern()
	print("FSM DONE, failures: ", bad)
	main.get_tree().quit()

## The table's shape: enum-sized names, a row per state, targets that exist, no self-edges, all reachable.
func _edges(label: String, f: Fsm, enum_size: int) -> void:
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
	ok(stray == 0, "%s: every target is a state (%d stray)" % [label, stray])
	ok(self_edges == 0, "%s: no self-edges (%d)" % [label, self_edges])
	var seen := {f.state: true}
	var open := [f.state]
	while not open.is_empty():
		for t in f.table.get(open.pop_back(), []):
			if not seen.has(t):
				seen[t] = true
				open.append(t)
	var unreached := range(n).filter(func(s: int) -> bool: return not seen.has(s))
	unreached = unreached.map(func(s: int) -> String: return f.names[s])
	ok(unreached.is_empty(), "%s: every state reachable from %s %s" % [label, f.state_name(), unreached])

## The pattern itself, on a labelled Loco machine.
func _pattern() -> void:
	var f := Fsm.new(Loco.NAMES, Loco.TABLE, Loco.S.GROUNDED, "check")
	var listed: bool = Fsm.live.has("check") and (Fsm.live["check"] as WeakRef).get_ref() == f
	ok(listed, "a labelled machine is listed in Fsm.live")
	ok(not f.go(Loco.S.GLIDING, "press") and f.refused == 1 and f.is_in(Loco.S.GROUNDED),
		"the table refuses a glide off the ground")
	ok(_last(f.refusals) == "   0.00 Grounded>Gliding press (table)",
		"the refusal logs the reason and what refused it: %s" % _last(f.refusals))
	var fresh := {"press": false}
	f.guard_from(Loco.S.AIRBORNE, Loco.S.GLIDING, func() -> bool: return fresh["press"])
	f.tick(0.5)
	ok(f.go(Loco.S.AIRBORNE, "jump") and _last(f.history) == "   0.50 Grounded>Airborne jump",
		"go(to, why) logs the clock, the edge and the reason: %s" % _last(f.history))
	ok(not f.go(Loco.S.GLIDING, "hold") and _last(f.refusals).ends_with("Airborne>Gliding hold (edge guard)"),
		"guard_from refuses Airborne>Gliding without a fresh press")
	fresh["press"] = true
	ok(f.go(Loco.S.GLIDING, "press"), "guard_from allows it with one")
	fresh["press"] = false
	ok(f.go(Loco.S.DASHING, "dash") and f.go(Loco.S.GLIDING, "dash"),
		"the Airborne edge's guard does not touch Dashing>Gliding")
	f.guard(Loco.S.KNOCKED, func(_from: int) -> bool: return false)
	ok(not f.go(Loco.S.KNOCKED, "hit") and _last(f.refusals).ends_with("Gliding>Knocked hit (guard)"),
		"a target guard refuses from any state")
	ok(f.refused == 3 and f.refusals.size() == 3 and f.history.size() == 4,
		"refused %d, refusals %d, history %d" % [f.refused, f.refusals.size(), f.history.size()])
	fresh["press"] = true
	for i in Fsm.HISTORY:
		f.go(Loco.S.AIRBORNE, "fold")
		f.go(Loco.S.GLIDING, "press")
	ok(f.history.size() == Fsm.HISTORY and f.history[0].ends_with("fold"),
		"the log keeps the last %d lines, oldest first: %s" % [Fsm.HISTORY, f.history[0]])

func _last(lines: PackedStringArray) -> String:
	return lines[lines.size() - 1] if lines.size() > 0 else ""
