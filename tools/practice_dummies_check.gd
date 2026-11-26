extends RefCounted
## --practice-dummies-check: in the Test Zone and the Training Grounds a practice dummy loses HP to a real
## basic attack and to abilities (logged), is knocked down at 0, stays down for respawn_s
## (content/rules/practice_dummies.json), then stands on its own mark at full HP; the DPS label keeps its
## totals through it, Reset dummies still works, and god mode never reaches the dummies.
## Prints PDUMMYCHECK PASS/FAIL lines.

const DT := 1.0 / 60.0
var main: Node
var fails := 0


func ok(name: String, cond: bool, info := "") -> void:
	printerr("PDUMMYCHECK %-52s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT


func run(main_node: Node) -> void:
	main = main_node
	var zone := TestZone.opts()
	zone["weapon"] = "rifle"
	var grounds := {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	for case in [["Test Zone", zone], ["Training Grounds", grounds]]:
		await _zone(String(case[0]), case[1])
	print("PDUMMYCHECK DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _zone(label: String, opts: Dictionary) -> void:
	Game.god = (label == "Test Zone")      # (the owner plays the Test Zone with god mode on: it must not touch the dummies)
	var m := Match.new()
	main.add_child(m)
	m.start(opts.duplicate())
	m.set_process(false)
	var P: Hunter = m.player
	var A: Arena = m.arena
	var R := Content.rules("practice_dummies")
	var rs := float(R["respawn_s"])
	ok("%s: three dummies, respawn_s in the rules" % label, A.dummies.size() == 3 and rs > 0.0, "respawn_s %.1f" % rs)
	var dm: Dictionary = A.dummies[0]
	var D: Hunter = dm["h"]
	var at: Vector3 = dm["at"]
	step(m, 0.3)
	# a real basic attack (hold fire at it) and a couple of abilities
	P.teleport(D.pos + Vector3(0, 0, 4.0))
	var hp0 := D.hp
	for i in 90:
		P.inp["aim"] = D.pos + Vector3(0, 0.9, 0)
		P.inp["fire"] = true
		m.step(DT)
	P.inp["fire"] = false
	ok("%s: basic attack takes HP off the dummy" % label, D.hp < hp0 - 5.0, "%.0f -> %.0f" % [hp0, D.hp])
	var hp1 := D.hp
	P.inp["aim"] = D.pos + Vector3(0, 0.9, 0)
	if P.ak:
		P.ak.use_e()
		P.ak.ch_rmb = 1.0
		P.ak.press_rmb()
	step(m, 1.0)
	printerr("PDUMMYCHECK %s: after abilities hp %.0f -> %.0f" % [label, hp1, D.hp])
	ok("%s: HP does not climb back while it is being hit" % label, D.hp <= hp1 + 0.1, "%.0f -> %.0f" % [hp1, D.hp])
	# hit it to 0
	var total0 := float(dm["total"])
	D.hurt(Arena.DUMMY_HP * 2.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("%s: dummy is knocked down at 0 HP" % label, D.downed and D.hp <= 0.0, "hp %.0f downed %s" % [D.hp, D.downed])
	ok("%s: DPS label counted the damage" % label, float(dm["total"]) > total0)
	# pushed off its mark, it is still down and not healed a second later
	D.teleport(at + Vector3(2.5, 0, 0))
	step(m, rs - 1.0)
	ok("%s: still down before respawn_s" % label, D.downed and D.hp <= 0.0, "hp %.0f" % D.hp)
	step(m, 1.3)
	ok("%s: respawned alive at full HP" % label, not D.downed and not D.out and is_equal_approx(D.hp, D.max_hp), "hp %.0f/%.0f" % [D.hp, D.max_hp])
	ok("%s: respawned on its own spot" % label, D.pos.distance_to(at) < 0.5, "%.2f m from its mark" % D.pos.distance_to(at))
	ok("%s: DPS label keeps its total" % label, float(dm["total"]) > total0 and String((dm["label"] as Label3D).text).begins_with("DPS"), (dm["label"] as Label3D).text)
	# and it can be killed again
	D.hurt(Arena.DUMMY_HP * 2.0, P, {"src": "shot"})
	step(m, 0.1)
	ok("%s: it can be knocked down again" % label, D.downed)
	# Reset dummies mid-down
	A.reset()
	ok("%s: Reset dummies stands it up at full HP" % label, not D.downed and D.hp >= Arena.DUMMY_HP - 0.1 and D.pos.distance_to(at) < 0.5)
	step(m, rs + 1.0)
	ok("%s: no respawn left pending after Reset" % label, not D.downed and D.hp >= Arena.DUMMY_HP - 0.1)
	m.queue_free()
	Game.god = false
