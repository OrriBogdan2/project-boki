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
	var grounds := {
		"training": true,
		"practice": true,
		"teams": 1,
		"squad": 1,
		"tier": 0,
		"length": 1e9,
		"seed": 4242,
		"no_drop": true,
	}
	for case in [["Test Zone", zone], ["Training Grounds", grounds]]:
		await _zone(String(case[0]), case[1])
	print("PDUMMYCHECK DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)


func _zone(label: String, opts: Dictionary) -> void:
	# (the owner plays the Test Zone with god mode on: it must not touch the dummies)
	Game.god = label == "Test Zone"
	var m := Match.new()
	main.add_child(m)
	m.start(opts.duplicate())
	m.set_process(false)
	var p_v: Hunter = m.player
	var a_v: Arena = m.arena
	var pd_rules := Content.rules("practice_dummies")
	var rs := float(pd_rules["respawn_s"])
	var three := a_v.dummies.size() == 3 and rs > 0.0
	ok("%s: three dummies, respawn_s in the rules" % label, three, "respawn_s %.1f" % rs)
	var dm: Dictionary = a_v.dummies[0]
	var d_v: Hunter = dm["h"]
	var at: Vector3 = dm["at"]
	step(m, 0.3)
	# a real basic attack (hold fire at it) and a couple of abilities
	p_v.teleport(d_v.pos + Vector3(0, 0, 4.0))
	var hp0 := d_v.hp
	for i in 90:
		p_v.inp["aim"] = d_v.pos + Vector3(0, 0.9, 0)
		p_v.inp["fire"] = true
		m.step(DT)
	p_v.inp["fire"] = false
	ok("%s: basic attack takes HP off the dummy" % label, d_v.hp < hp0 - 5.0, "%.0f -> %.0f" % [hp0, d_v.hp])
	var hp1 := d_v.hp
	p_v.inp["aim"] = d_v.pos + Vector3(0, 0.9, 0)
	if p_v.ak:
		p_v.ak.use_e()
		p_v.ak.ch_rmb = 1.0
		p_v.ak.press_rmb()
	step(m, 1.0)
	printerr("PDUMMYCHECK %s: after abilities hp %.0f -> %.0f" % [label, hp1, d_v.hp])
	var kept := d_v.hp <= hp1 + 0.1
	ok("%s: HP does not climb back while it is being hit" % label, kept, "%.0f -> %.0f" % [hp1, d_v.hp])
	# hit it to 0
	var total0 := float(dm["total"])
	d_v.hurt(Arena.DUMMY_HP * 2.0, p_v, {"src": "shot"})
	step(m, 0.1)
	ok(
		"%s: dummy is knocked down at 0 HP" % label,
		d_v.downed and d_v.hp <= 0.0,
		"hp %.0f downed %s" % [d_v.hp, d_v.downed]
	)
	ok("%s: DPS label counted the damage" % label, float(dm["total"]) > total0)
	# pushed off its mark, it is still down and not healed a second later
	d_v.teleport(at + Vector3(2.5, 0, 0))
	step(m, rs - 1.0)
	ok("%s: still down before respawn_s" % label, d_v.downed and d_v.hp <= 0.0, "hp %.0f" % d_v.hp)
	step(m, 1.3)
	var full := not d_v.downed and not d_v.out and is_equal_approx(d_v.hp, d_v.max_hp)
	ok("%s: respawned alive at full HP" % label, full, "hp %.0f/%.0f" % [d_v.hp, d_v.max_hp])
	var far := d_v.pos.distance_to(at)
	ok("%s: respawned on its own spot" % label, far < 0.5, "%.2f m from its mark" % far)
	var txt: String = (dm["label"] as Label3D).text
	ok("%s: DPS label keeps its total" % label, float(dm["total"]) > total0 and txt.begins_with("DPS"), txt)
	# and it can be killed again
	d_v.hurt(Arena.DUMMY_HP * 2.0, p_v, {"src": "shot"})
	step(m, 0.1)
	ok("%s: it can be knocked down again" % label, d_v.downed)
	# Reset dummies mid-down
	a_v.reset()
	var back := not d_v.downed and d_v.hp >= Arena.DUMMY_HP - 0.1 and d_v.pos.distance_to(at) < 0.5
	ok("%s: Reset dummies stands it up at full HP" % label, back)
	step(m, rs + 1.0)
	ok("%s: no respawn left pending after Reset" % label, not d_v.downed and d_v.hp >= Arena.DUMMY_HP - 0.1)
	m.queue_free()
	Game.god = false
