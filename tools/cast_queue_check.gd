extends RefCounted
## --cast-queue-check: for every hero, every RMB or E press made in another ability's wind-up or recovery does
## what its row in content/rules/cast_queue.json says (CastQueue): "queue" (held while the move runs, goes within
## a step of its end), "fire" (goes while the move runs) or "drop" (never goes). Each trial starts the move, presses
## the other slot mid-move and watches; a queued trial also asserts the queue machine's log ("fired") and that it
## refused nothing. A hero with a "note" has no move that holds the body (no trials). --cast-queue-check=<id>,<id>
## runs only those heroes. Never touches the save. Reuses --dash-flow-check's arena, ready-up and "went off" probes.

const START_WAIT := 90          # steps: the move shows up within this (a chain hooks, then pulls)
const MID := 4                  # steps into the move before the press (mid-cast, not on its first frame)
const WATCH := 600              # steps the move may run after the press (Rimelock, a Broadside)
const AFTER := 2                # steps after the move's end a queued press must have gone by
const HOOK_AT := Vector3(0, 0, -7)     # where the foe stands for an E that hooks (Zedran's chain)
const AWAY_AT := Vector3(0, 0, -40)    # elsewhere: a foe in reach fights back and its stun eats the trial

var flow_check = preload("res://tools/dash_flow_check.gd").new()
var bad := 0
var trials := 0

func ok(cond: bool, what: String) -> void:
	print("CASTQ %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	var rules := CastQueue.rules()
	CombatBus.ability_used.connect(flow_check._on_used)
	for hero in _heroes(rules):
		var moves: Dictionary = rules["heroes"][hero]
		ok(moves.has("note") != _has_moves(moves), "%s has rows or a note, not both" % hero)
		for move in moves:
			for slot in CastQueue.SLOTS:
				if move != "note" and slot != move:
					# a fresh arena per pair: no trial leaves a stun or a roused foe to the next
					var m: Match = flow_check._match(main, hero)
					_pair(m, hero, slot, move)
					m.queue_free()
					await main.get_tree().process_frame
	CombatBus.ability_used.disconnect(flow_check._on_used)
	print("CASTQ DONE, trials: %d, failures: %d" % [trials, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _heroes(rules: Dictionary) -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cast-queue-check=") and arg.length() > 19:
			return arg.get_slice("=", 1).split(",")
	return rules["heroes"].keys()

func _has_moves(moves: Dictionary) -> bool:
	return moves.keys().any(func(k): return k != "note")

## One press of `slot` in `move`, judged against its row.
func _pair(m: Match, hero: String, slot: String, move: String) -> void:
	trials += 1
	var what := "%s %s during %s" % [hero, slot, move]
	var mode := CastQueue.mode_of(hero, slot, move)
	var h: Hunter = flow_check.hunter
	var k := h.ak
	if not _start(m, move):
		ok(false, "%s: the move never started (move_slot '%s')" % [what, k.move_slot()])
		return
	var refused_was := k.queue.fsm.refused
	var before: Dictionary = flow_check._snap()
	flow_check._press(slot)
	var went := -1              # step the press went off
	var ended := -1             # step the move ended
	for i in WATCH:
		m.step(Match.DT)
		if ended < 0 and k.move_slot() != move:
			ended = i
		if went < 0 and flow_check._went_off(before, slot):
			went = i
		if ended >= 0 and (went >= 0 or i > ended + 30):
			break
	var timing := "went at step %d, the move ended at step %d; %s" % [went, ended, k.queue.fsm.history[-1].strip_edges()
			if not k.queue.fsm.history.is_empty() else "no queue log"]
	match mode:
		"fire":
			ok(went >= 0 and (ended < 0 or went < ended), "%s goes at once (%s)" % [what, timing])
		"drop":
			ok(went < 0 and ended >= 0, "%s is refused (%s)" % [what, timing])
		"queue":
			var lines := "\n".join(k.queue.fsm.history)
			ok(ended >= 0 and went >= ended and went <= ended + AFTER and lines.contains("fired %s" % slot),
					"%s is held and goes as the move ends (%s)" % [what, timing])
			ok(k.queue.fsm.refused == refused_was and k.queue.fsm.is_in(CastQueue.S.OPEN),
					"%s: the queue refused nothing and is open again (%s)" % [what, k.queue.fsm.state_name()])

## Ready, the foe placed, then the move pressed (an E that hooks is pressed again to pull) and MID steps into it.
func _start(m: Match, move: String) -> bool:
	var h: Hunter = flow_check.hunter
	flow_check._ready_up(m)
	var foe: Hunter = _foe(m)
	foe.teleport(h.pos + (HOOK_AT if move == "e" else AWAY_AT))
	foe.hp = foe.max_hp
	h.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
	flow_check._press(move)
	var recast := false
	for i in START_WAIT:
		m.step(Match.DT)
		h.inp["aim"] = foe.pos + Vector3(0, 0.9, 0)
		if h.ak.move_slot() == move:
			flow_check._steps(m, MID)
			return h.ak.move_slot() == move
		if move == "e" and not recast and h.ak.e_recastable():
			recast = true
			flow_check._press("e")
	return false

func _foe(m: Match) -> Hunter:
	for other in m.hunters:
		if other != flow_check.hunter:
			return other
	return null
