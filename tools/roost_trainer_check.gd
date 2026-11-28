extends RefCounted
## --roost-trainer-check: the Boki Roost's fight trainer (RoostTrainer). At the sign, interact starts it; the
## Summon key's burst drops a wild practice Boki and asks for an order; a Chase order moves it to knock-out; a
## dazed wild Boki moves it to the scan step; if it wakes the drill goes back; the real Capture.complete on it
## finishes the drill (no capsule or stat kept: the Grounds are a training match); falling off stops it.
## Prints ROOSTTRAIN PASS/FAIL.

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
	tr.start()
	m.step(DT)
	ok("started at step 1, line shown", tr.step == RoostTrainer.Step.SUMMON and tr.line.text.begins_with("1/4"))
	p.kin.summon.left = 5.0
	m.step(DT)
	var on_order := tr.step == RoostTrainer.Step.ORDER and tr.line.text.begins_with("2/4")
	ok("summoned: order step, a wild Boki on the roost", on_order and tr.wild != null and tr.wild.is_wild())
	p.kin.cmd = "chase"
	m.step(DT)
	ok("an order given: knock-out step", tr.step == RoostTrainer.Step.KNOCK and tr.line.text.begins_with("3/4"))
	tr.wild.hp = 1.0
	tr.wild._daze()
	m.step(DT)
	ok("dazed: scan step", tr.step == RoostTrainer.Step.SCAN and tr.line.text.begins_with("4/4"), tr.line.text)
	tr.wild.state = "wild"
	m.step(DT)
	ok("it woke: back to the knock-out step", tr.step == RoostTrainer.Step.KNOCK)
	tr.wild._daze()
	m.step(DT)
	var w := tr.wild
	var n0 := p.caught.size()
	Capture.complete(m, p, w)
	ok("the real scan finishes it, keeps no capsule", tr.step == RoostTrainer.Step.DONE and p.caught.size() == n0)
	ok("the practice Boki is gone", tr.wild == null and not w in m.kins)
	var b0 := Rect2(tr.line.get_global_rect())
	var half := m.get_viewport().get_visible_rect().size.y * 0.5
	ok("step line under the pedestal prompt, top half", b0.position.y >= Grounds.PROMPT_Y and b0.end.y < half, str(b0))
	tr.step = RoostTrainer.Step.KNOCK
	p.teleport(Vector3(p.pos.x, Grounds.FALL_Y - 5.0, p.pos.z))
	tr.tick(DT)
	ok("falling stops it and clears the wild Boki", tr.step == RoostTrainer.Step.IDLE and tr.wild == null)
	arena.teardown()
	m.queue_free()
	await main.get_tree().process_frame
	print("ROOSTTRAIN DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)
