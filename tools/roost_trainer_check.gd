extends RefCounted
## --roost-trainer-check: the Boki Roost's fight trainer (RoostTrainer). At the sign, interact starts it; the
## Summon key's burst moves it to the knock-out step and drops a wild practice Boki; a dazed wild Boki moves it
## to the scan step; if it wakes the drill goes back; a capsule in the carry-out slot finishes it and is handed
## back; falling off the roost stops it. Prints ROOSTTRAIN PASS/FAIL.

const DT := 1.0 / 60.0

var main: Node
var fails := 0
var m: Match
var arena: Arena


func ok(what: String, cond: bool, info := "") -> void:
	printerr("ROOSTTRAIN %-54s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	arena = m.arena
	var tr: RoostTrainer = arena.grounds.roost_trainer
	var p: Hunter = m.player
	m.step(DT)
	ok("idle: no step line", tr.step == -1 and not tr.line.visible)
	p.teleport(tr.sign_at)
	m.step(DT)
	arena.grounds.summon_pad.cycle()
	tr._start()
	m.step(DT)
	ok("started at step 0, line shown", tr.step == 0 and tr.line.visible and tr.line.text.begins_with("1/3"))
	p.kin.summon.left = 5.0
	m.step(DT)
	ok("summoned: knock-out step, a wild Boki on the roost", tr.step == 1 and tr.wild != null and tr.wild.is_wild())
	tr.wild.hp = 1.0
	tr.wild._daze()
	m.step(DT)
	ok("dazed: scan step", tr.step == 2 and tr.line.text.begins_with("3/3"), tr.line.text)
	tr.wild.state = "wild"
	m.step(DT)
	ok("it woke: back to the knock-out step", tr.step == 1)
	p.caught.append(Save.new_kin("kestrike"))
	m.step(DT)
	ok("captured: done, and the slot is handed back", tr.step == 3 and p.caught.is_empty())
	tr.step = 1
	p.teleport(Vector3(p.pos.x, Grounds.FALL_Y - 5.0, p.pos.z))
	tr.tick(DT)
	ok("falling stops it and clears the wild Boki", tr.step == -1 and tr.wild == null)
	arena.teardown()
	m.queue_free()
	await main.get_tree().process_frame
	print("ROOSTTRAIN DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
