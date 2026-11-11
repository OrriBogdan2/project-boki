class_name Fsm
extends RefCounted
## The explicit state machine pattern (docs/decisions/0022-one-movement-model.md): one state var, a transition table
## (from -> the states it may go to), a guard per target state or per edge, enter/exit hooks, and a timed log of
## the last transitions and refusals, each with the caller's reason, for the F7 readout (FsmReadout) and the
## checks. A change the table or a guard does not allow is refused and counted, never applied: illegal combos
## can't happen because no code path sets the state except go(). A machine built with a label is listed in
## Fsm.live so the readout and --fsm-check find every machine.

const HISTORY := 32                  # transitions (and refusals) kept per machine for the readout and the checks

static var live := {}                # label -> WeakRef of the machine built with it (the local player's machines)

var names: PackedStringArray         # state id -> its name
var table: Dictionary                # from -> Array of the states it may go to (--fsm-check audits it)
var state := 0
var since := 0.0                     # s in the current state (tick() adds)
var clock := 0.0                     # s the machine has run (tick() adds); stamps the log lines
var refused := 0                     # transitions the table or a guard turned down
var history: PackedStringArray = []  # "   time From>To why", newest last
var refusals: PackedStringArray = [] # the same for refused changes, ending in what refused them
var _guards := {}                    # to -> Callable(from: int) -> bool
var _edge_guards := {}               # Vector2i(from, to) -> Callable() -> bool
var _enter := {}                     # to -> Callable(from: int)
var _exit := {}                      # from -> Callable(to: int)

func _init(state_names: PackedStringArray, from_to: Dictionary, start := 0, label := "") -> void:
	names = state_names
	table = from_to
	state = start
	if label != "":
		live[label] = weakref(self)

## Guards every edge into `to`.
func guard(to: int, f: Callable) -> void:
	_guards[to] = f

## Guards the one edge `from` -> `to` (the same target can have a different rule from each source).
func guard_from(from: int, to: int, f: Callable) -> void:
	_edge_guards[Vector2i(from, to)] = f

func on_enter(to: int, f: Callable) -> void:
	_enter[to] = f

func on_exit(from: int, f: Callable) -> void:
	_exit[from] = f

## True when the table and the guards allow going to `to` from the current state.
func can(to: int) -> bool:
	return to == state or _blocker(to) == ""

## Goes to `to` if allowed (exit hook of the old state, then the enter hook of the new) and logs it with `why`,
## a short word from the call site ("press", "landed", "hit"); false when refused, which logs too.
func go(to: int, why := "") -> bool:
	if to == state:
		return true
	var blocker := _blocker(to)
	if blocker != "":
		refused += 1
		_log(refusals, state, to, "%s (%s)" % [why, blocker])
		return false
	var from := state
	if _exit.has(from):
		(_exit[from] as Callable).call(to)
	state = to
	since = 0.0
	_log(history, from, to, why)
	if _enter.has(to):
		(_enter[to] as Callable).call(from)
	return true

func tick(dt: float) -> void:
	since += dt
	clock += dt

func is_in(s: int) -> bool:
	return state == s

func state_name() -> String:
	return names[state]

## "" when `to` is allowed from the current state, else what refuses it: the table, the target's guard or the edge's.
func _blocker(to: int) -> String:
	if not (table.get(state, []) as Array).has(to):
		return "table"
	if _guards.has(to) and not bool((_guards[to] as Callable).call(state)):
		return "guard"
	var edge := Vector2i(state, to)
	if _edge_guards.has(edge) and not bool((_edge_guards[edge] as Callable).call()):
		return "edge guard"
	return ""

func _log(lines: PackedStringArray, from: int, to: int, why: String) -> void:
	lines.append("%7.2f %s>%s %s" % [clock, names[from], names[to], why])
	if lines.size() > HISTORY:
		lines.remove_at(0)
