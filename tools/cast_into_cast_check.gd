extends RefCounted
## --cast-into-cast-check: for every hero with into_cast rows in content/dash_flow (the "Cast into cast" tables in
## docs/heroes/dash_interactions.md), a second ability pressed during the first one's wind-up and its recovery does
## what the row says: "fire" (goes within ACT_S), "queue" (held, goes after the row's wait, +-WAIT_TOL), "cancel"
## (goes at once and the first move never comes) or "drop" (never goes). The two press times per first move are its
## row's "at" (s after its press). An LMB hold is held HOLD_S, then let go. --cast-into-cast-check=<id>,<id> runs
## only those heroes. Reuses --dash-flow-check's arena, ready-up and "went off" probes. Never touches the save.

const PHASES := ["windup", "recovery"]
const ACT_S := 0.1              # s: a press that goes this soon went at once
const WAIT_TOL := 0.05          # s: a queued press goes within this of its row's wait
const WATCH_S := 2.5            # s: a press that hasn't gone by then was dropped
const HOLD_S := 0.75            # s an LMB hold is held down
const AIM := Vector3(0, 0.9, -6)        # where the hunter aims, from its feet
const FOE_AT := Vector3(0, 0, -40)      # the other hunter, out of every reach (a foe in reach fights back)

var flow_check = preload("res://tools/dash_flow_check.gd").new()
var bad := 0
var first_cut := false      # the last trial's first move never went off (pressed second, it ended it)
var trials := 0

func ok(cond: bool, what: String) -> void:
	print("CASTCAST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	CombatBus.ability_used.connect(flow_check._on_used)
	for hero in _heroes():
		var firsts: Dictionary = DashFlow.file_of(hero).get("into_cast", {})
		for first in firsts:
			for second in firsts[first]:
				# Tender's Hearth Call needs a teammate within reach (nobody: nothing happens), and a lone trial has none
				if hero == "tender" and (first == "x" or second == "x"):
					continue
				if second != "at":
					await _row(main, hero, first, second, firsts[first])
	CombatBus.ability_used.disconnect(flow_check._on_used)
	print("CASTCAST DONE, trials: %d, failures: %d" % [trials, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _heroes() -> Array:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cast-into-cast-check=") and arg.length() > 23:
			return arg.get_slice("=", 1).split(",")
	var out := []
	for hero in Arch.ORDER:
		if DashFlow.file_of(hero).has("into_cast"):
			out.append(hero)
	return out

func _row(main: Node, hero: String, first: String, second: String, moves: Dictionary) -> void:
	var row: Dictionary = moves[second]
	ok(String(row.get("source", "")) != "", "%s %s during %s has a source" % [hero, second, first])
	var base := maxf(0.0, await _wait(main, hero, "", second, 0.0))
	for i in PHASES.size():
		var phase: String = PHASES[i]
		trials += 1
		var got := _verdict(await _wait(main, hero, first, second, float(moves["at"][i])), base)
		var want := String(row[phase])
		var what := "%s %s in %s's %s: %s (row: %s" % [hero, second, first, phase, got, want]
		if want == "queue":
			var wait := float(row[phase + "_wait"])
			var near := absf(float(got.get_slice(" ", 1)) - wait) <= WAIT_TOL
			ok(got.begins_with("queue") and near, "%s %.2fs)" % [what, wait])
		else:
			ok(got == want, what + ")")

## A trial's wait (see _wait) as "fire", "queue <s it waited>", "cancel" (it went at once and the first move never
## came), "drop", or "no first" (neither went off). It is counted past the second's own time to go off when pressed
## alone (`base`: a hold goes off at its tap threshold).
func _verdict(wait: float, base: float) -> String:
	if wait < 0.0:
		return "no first" if first_cut else "drop"
	wait -= base
	if wait <= ACT_S + 0.001:
		return "cancel" if first_cut else "fire"
	return "queue %.2f" % wait

## Seconds from the press of `second` until it went off (-1: never), `at` s into `first` ("": pressed alone). A
## fresh arena per trial: no trial leaves a charge, a buff or a roused foe to the next.
func _wait(main: Node, hero: String, first: String, second: String, at: float) -> float:
	var m: Match = flow_check._match(main, hero)
	var wait := _timed(m, first, second, at)
	m.queue_free()
	await main.get_tree().process_frame
	return wait

func _timed(m: Match, first: String, second: String, at: float) -> float:
	var h: Hunter = flow_check.hunter
	flow_check._ready_up(m)
	for other in m.hunters:
		if other != h:
			other.teleport(h.pos + FOE_AT)
	var hold_steps := int(round(HOLD_S / Match.DT)) if first == "lmb_hold" else 1
	var step := 0
	var before: Dictionary = flow_check._snap()
	var first_went := first == ""
	if first != "":
		_press(first)
		while step < int(round(at / Match.DT)):
			_step(m, step + 1 < hold_steps)
			step += 1
			first_went = first_went or flow_check._went_off(before, _key(first))
	var first_before := before
	before = flow_check._snap()
	_press(second)
	var second_hold := int(round(HOLD_S / Match.DT)) if second == "lmb_hold" else 1
	var wait := -1.0
	for i in int(WATCH_S / Match.DT):
		_step(m, (first != "" and step + 1 < hold_steps) or i + 1 < second_hold)
		step += 1
		first_went = first_went or flow_check._went_off(first_before, _key(first))
		if wait < 0.0 and flow_check._went_off(before, _key(second)):
			wait = float(i + 1) * Match.DT
		if wait >= 0.0 and first_went:
			break
	first_cut = not first_went
	return wait

func _step(m: Match, fire_down: bool) -> void:
	m.step(Match.DT)
	var h: Hunter = flow_check.hunter
	h.inp["fire"] = fire_down
	h.inp["aim"] = flow_check.get_meta("home") + AIM

func _press(slot: String) -> void:
	flow_check._press(_key(slot))

func _key(slot: String) -> String:
	return "lmb" if slot == "lmb_hold" else slot
