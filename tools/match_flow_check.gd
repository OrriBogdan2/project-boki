extends RefCounted
## --match-flow-check: the match phase machine (scripts/match/match_flow.gd, docs/decisions/0061).
##   1. the table: every target is a state, every state is reachable from LOADING, no self-edges, names match
##   2. a real expedition: LOADING (no Esc menu) > PLANNING > DROP (on the ship, through the jump) > PLAY, in that
##      order, with the HUD word PLANNING / DROPPING / none, and the Esc menu allowed in each
##   3. Ways Out: PLAY until the Heart's final seat, then CLOSING ("FINAL SEAT"); the last FALLING_S on the clock
##      say ISLANDS FALLING and turn the clock red
##   4. the end: decided once (ENDING, no Esc menu, no phase word), over once (`over` reads it, a second _finish
##      does nothing, step no longer moves the clock), and an illegal step back is refused
##   5. no refusals in the scripted run before that; the real HUD draws every phase without a script error
## Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("MFLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_table()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 6101, "plan_t": 0.5, "heart": true, "god": true})
	var F := m.flow
	var S := MatchFlow.S
	ok(F.fsm.is_in(S.LOADING) and not F.can_pause(), "built but not stepped: LOADING, no Esc menu")
	# ---------------------------------------------------------------- 2. planning, the drop, landing
	m.step(Match.DT)
	ok(F.fsm.is_in(S.PLANNING) and F.word() == "PLANNING" and F.can_pause(), "planning the drop: PLANNING, Esc ok")
	await _frames(main)
	var n := 0
	while F.fsm.is_in(S.PLANNING) and n < 600:
		m.step(Match.DT)
		n += 1
	ok(F.fsm.is_in(S.DROP) and m.player.riding and F.word() == "DROPPING", "the ship sets off: DROP while aboard")
	m.ship_jump(m.player, true)
	m.step(Match.DT)
	ok(F.fsm.is_in(S.DROP) and m.player.dropping, "jumped: still DROP in the air")
	n = 0
	while F.fsm.is_in(S.DROP) and n < 3600:
		m.step(Match.DT)
		n += 1
	ok(F.fsm.is_in(S.PLAY) and not m.player.dropping and F.word() == "" and F.can_pause(),
		"landed: PLAY after %.1f s, no phase word, Esc ok" % (n * Match.DT))
	await _frames(main)
	var order := " ".join(F.fsm.history)
	ok(order.contains("LOADING>PLANNING") and order.contains("PLANNING>DROP") and order.contains("DROP>PLAY"),
		"in order: %s" % order)
	# ---------------------------------------------------------------- 3. Ways Out onto PLAY / CLOSING
	m.time = Heart.r("final_s") - 5.0
	m.step(Match.DT)
	ok(F.fsm.is_in(S.PLAY), "before the final seat: still PLAY")
	m.heart.state = Heart.S.FINAL
	m.step(Match.DT)
	ok(F.fsm.is_in(S.CLOSING) and F.word() == "FINAL SEAT" and not F.falling(), "the final seat is up: CLOSING")
	m.time = m.length - MatchFlow.FALLING_S + 1.0
	m.step(Match.DT)
	ok(F.word() == "ISLANDS FALLING" and F.falling() and F.can_pause(), "the last %d s: ISLANDS FALLING"
		% int(MatchFlow.FALLING_S))
	await _frames(main)
	ok(F.fsm.refused == 0, "no refusals in the scripted run (refused %d)" % F.fsm.refused)
	# ---------------------------------------------------------------- 4. ending and over, once each
	m.opts["sim_keep"] = true      # (no results timer: this check finishes the match itself)
	m.result = {"extracted": true, "why": "check"}
	m._end_soon(0.1)
	ok(F.fsm.is_in(S.ENDING) and F.ending() and not F.can_pause() and F.word() == "", "decided: ENDING, no Esc menu")
	m.result = {"extracted": true}
	ok(not F.end("again") and F.fsm.is_in(S.ENDING), "a second decision is ignored, even with a new result")
	await _frames(main)
	ok(F.finish("check") and m.over and F.fsm.is_in(S.OVER), "over: OVER, and `over` reads it")
	m._finish()
	ok(F.fsm.history.size() > 0 and F.fsm.history[-1].ends_with("ENDING>OVER check"), "a second _finish does nothing")
	var t := m.time
	m.step(Match.DT)
	ok(m.time == t, "over: the clock no longer moves")
	ok(not F.fsm.go(S.PLAY, "check") and F.fsm.refused == 1, "OVER > PLAY is refused and counted")
	print("MFLOW readout: ", F.fsm.state_name(), " ", " | ".join(F.fsm.history.slice(-3)))
	m.queue_free()
	print("MFLOW DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _table() -> void:
	var names := MatchFlow.NAMES
	ok(names.size() == MatchFlow.S.size(), "a name per state")
	var seen := {MatchFlow.S.LOADING: true}
	var todo: Array = [MatchFlow.S.LOADING]
	var sound := true
	while not todo.is_empty():
		var from: int = todo.pop_back()
		for to in MatchFlow.TABLE.get(from, []):
			sound = sound and to != from and to >= 0 and to < names.size()
			if not seen.has(to):
				seen[to] = true
				todo.append(to)
	ok(sound, "every target is a state, no self-edges")
	ok(seen.size() == names.size(), "every state reachable from LOADING (%d of %d)" % [seen.size(), names.size()])

func _frames(main: Node) -> void:
	for i in 3:
		await main.get_tree().process_frame
