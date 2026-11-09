class_name CastQueue
extends RefCounted
## What an RMB or E press does while another of the hero's abilities owns the body, in its wind-up or recovery
## (ArchKit.move_slot names it). The shared rule is the queue: the press is held and goes the step that move
## ends. A hero's exceptions, where the source or an owner call differs, are rows in content/rules/cast_queue.json:
## "fire" (it goes at once and the move runs on) or "drop" (refused with the deny cue). docs/heroes/cast_queue.md
## is the table. A press of a slot during its own move, or an E that is a recast, is the kit's (recasts and the
## Smash during a Smash buffer there), and so are presses during a dash (DashFlow routes those first).

enum S {
	OPEN,   ## no press waits; a press in a move goes by its row (queue -> HELD)
	HELD,   ## one press waits for `during` to end; it goes then (OPEN "fired"), and a newer press replaces it
}
const NAMES: PackedStringArray = ["OPEN", "HELD"]
const TABLE := {S.OPEN: [S.HELD], S.HELD: [S.OPEN]}
const SLOTS := ["rmb", "e"]
const MODES := ["queue", "fire", "drop"]
const FEEDBACK := {"rmb": "sec", "e": "k1"}       # the deny cue's slot name (Hunter._ab_feedback)

static var _rules := {}

var kit: ArchKit
var fsm: Fsm
var slot := ""              # the held press (HELD)
var during := ""            # the move it waits for

func _init(owner_kit: ArchKit) -> void:
	kit = owner_kit
	fsm = Fsm.new(NAMES, TABLE, S.OPEN)

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/cast_queue.json"))
	return _rules

## The mode for a press of `pressed` during `move`'s wind-up or recovery: the hero's row, else the shared rule.
static func mode_of(hero: String, pressed: String, move: String) -> String:
	var row: Dictionary = rules()["heroes"].get(hero, {}).get(move, {}).get(pressed, {})
	return String(row.get("mode", rules()["default"]))

## Each step, after the kit's tick and before Hunter reads the RMB and E presses: lets a held press go once its
## move is over, then routes this step's presses made in a move.
func route(dt: float) -> void:
	fsm.tick(dt)
	var h := kit.h
	var move := kit.move_slot()
	if fsm.is_in(S.HELD) and move != during:
		h.inp[DashFlow.KEY_OF[slot]] = true
		fsm.go(S.OPEN, "fired %s after %s" % [slot, during])
	if move == "":
		return
	for pressed in SLOTS:
		var key: String = DashFlow.KEY_OF[pressed]
		if not h.inp.get(key, false) or pressed == move or (pressed == "e" and kit.e_recastable()):
			continue
		match mode_of(kit.id, pressed, move):
			"queue":
				h.inp[key] = false
				slot = pressed
				during = move
				fsm.go(S.HELD, "%s in %s" % [pressed, move])
			"drop":
				h.inp[key] = false
				h._ab_feedback(FEEDBACK[pressed], "deny")

## A merge or a new kit: nothing held goes off.
func clear() -> void:
	fsm.go(S.OPEN, "cleared")
