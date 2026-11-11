class_name Fsm
extends RefCounted
## The explicit state machine pattern (docs/decisions/0022-one-movement-model.md): one state var, a transition table
## (from -> the states it may go to), an optional guard per target state, enter/exit hooks, and the last few
## transitions kept for debug readouts. A change the table does not list is refused and counted, never applied:
## illegal combos can't happen because no code path sets the state except go().

const HISTORY := 6                   # transitions kept for the debug readout

var names: PackedStringArray         # state id -> its name
var state := 0
var since := 0.0                     # s in the current state (tick() adds)
var refused := 0                     # transitions the table or a guard turned down
var history: PackedStringArray = []  # "from>to", newest last
var _table: Dictionary               # from -> Array of the states it may go to
var _guards := {}                    # to -> Callable(from: int) -> bool
var _enter := {}                     # to -> Callable(from: int)
var _exit := {}                      # from -> Callable(to: int)

func _init(state_names: PackedStringArray, table: Dictionary, start := 0) -> void:
	names = state_names
	_table = table
	state = start

func guard(to: int, f: Callable) -> void:
	_guards[to] = f

func on_enter(to: int, f: Callable) -> void:
	_enter[to] = f

func on_exit(from: int, f: Callable) -> void:
	_exit[from] = f

## True when the table and the target's guard allow going there from the current state.
func can(to: int) -> bool:
	if to == state:
		return true
	if not (_table.get(state, []) as Array).has(to):
		return false
	return not _guards.has(to) or bool((_guards[to] as Callable).call(state))

## Goes to `to` if allowed (exit hook of the old state, then the enter hook of the new); false when refused.
func go(to: int) -> bool:
	if to == state:
		return true
	if not can(to):
		refused += 1
		return false
	var from := state
	if _exit.has(from):
		(_exit[from] as Callable).call(to)
	state = to
	since = 0.0
	history.append("%s>%s" % [names[from], names[to]])
	if history.size() > HISTORY:
		history.remove_at(0)
	if _enter.has(to):
		(_enter[to] as Callable).call(from)
	return true

func tick(dt: float) -> void:
	since += dt

func is_in(s: int) -> bool:
	return state == s

func state_name() -> String:
	return names[state]
