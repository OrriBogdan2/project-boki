extends "res://tools/hero_pair_check.gd"
## The signature-tech step of the kit drill (SignatureDrill, called by --kit-drill-check): for every Hunter the
## scripted correct input makes the kit emit CombatBus.tech once, and the near-miss input does not. Each run is a
## fresh dummy strip with the real kit; nothing here calls the event itself. Also: every Hunter has a drill, with
## a line, a source tag and live key caps.

const DIST := {"archer": 7.0, "juggernaut": 6.0, "bulwark": 2.4, "thief": 8.0, "mage": 5.0, "gunslinger": 6.0,
		"dolm": 6.0, "ashwick": 3.0, "dredge": 4.0, "ostra": 6.0, "rimewright": 6.0, "tender": 6.0, "gil": 6.0}
var seen := 0
var who: Hunter

func _on_tech(hunter: Node, id: String) -> void:
	if hunter == who and id == hunter.arch:
		seen += 1

func drills(main_node: Node) -> void:
	main = main_node
	_texts()
	CombatBus.tech.connect(_on_tech)
	for id in Arch.ids():
		for right in [false, true]:
			var got := await _run(id, right)
			ok("tech %s: %s" % [id, "the correct input fires it once" if right else "the near miss does not"],
					got == (1 if right else 0), "events %d" % got)
	CombatBus.tech.disconnect(_on_tech)

func _texts() -> void:
	for id in Arch.ids():
		var st := SignatureDrill.step(id)
		var d := SignatureDrill.def(id)
		ok("drill %s: a line with its key caps and a source tag" % id,
				not st.is_empty() and "{" not in String(st["line"]) and "[" in String(st["line"])
				and "[" in String(d.get("src", "")) and String(d.get("tech", "")) != "", String(st.get("line", "")))
	ok("the drill is the last step of the kit drill", KitDrill.steps("archer").back()["how"] == "tech")

## One fresh strip, the Hunter does the input; returns how many techs the kit reported.
func _run(id: String, right: bool) -> int:
	var r := setup(id, float(DIST[id]))
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	who = P
	seen = 0
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	P.reload_t = 0.0
	aim_at(P, T.pos)
	var aim := func(): aim_at(P, T.pos)
	var fire := func():
		P.inp["fire"] = true
		aim_at(P, T.pos)
	match id:
		"archer":
			step(m, 0.63 if right else 0.3, fire)
			P.inp["fire"] = false
		"juggernaut":
			_lunge(m, P, T, right)
		"bulwark":
			var K = P.ak
			var t := 0.0
			while t < 3.0 and (K.lmb_t < 0.3 if not right else not K.launch.in_window(K.lmb_t)):
				step(m, DT, fire)
				t += DT
			P.inp["fire"] = false
		"thief":
			if right:
				P.do_dash()
				step(m, 0.4, aim)
				fresh(T)
			P.inp["fire"] = true
			m.step(DT)
			P.inp["fire"] = false
		"mage":
			(P.ak as MageKit).add_spark(T, 4 if right else 2)
			P.inp["dash_down"] = true
			P.do_dash()
			step(m, 0.5, func():
				P.inp["dash_down"] = true
				aim_at(P, T.pos))
			P.inp["dash_down"] = false
		"gunslinger":
			T.hp = 1.0 if right else T.max_hp
			step(m, 1.2, fire)
			P.inp["fire"] = false
		"dolm":
			_punch(m, P, T, home, right)
		"ashwick":
			step(m, 4.0 if right else 1.3, fire)
			P.inp["fire"] = false
		"dredge":
			var away := atan2(-(T.pos.x - P.pos.x), -(T.pos.z - P.pos.z))
			step(m, 0.6, func():
				P.inp["fire"] = true
				aim_at(P, T.pos)
				T.face = away if right else away + PI)
			P.inp["fire"] = false
		"ostra":
			var K = P.ak
			K.cast_e()
			step(m, 7.2 if right else 2.0)
			K.e_recast()
		"rimewright":
			step(m, 2.4 if right else 0.5, fire)
			P.inp["fire"] = false
		"tender":
			_ember(m, P, T, right)
		"gil":
			_bag(m, P, T, right)
	step(m, 0.5)
	var got := seen
	who = null
	m.queue_free()
	await main.get_tree().process_frame
	return got

## Hold RMB; the right input lets go in the first perfect window, the near miss before the blade is full.
func _lunge(m: Match, P: Hunter, T: Hunter, right: bool) -> void:
	var K: JuggernautKit = P.ak
	K.cd["rmb"] = 0.0
	P.inp["sec_hold"] = true
	P.inp["sec"] = true
	K.press_rmb()
	P.inp["sec"] = false
	var t := 0.0
	var until := K.rmb_charge_full() + 0.02 if right else K.rmb_charge_full() * 0.5
	while t < 5.0 and (K.perfect_window(t) < 0 if right else t < until):
		P.inp["sec_hold"] = true
		aim_at(P, T.pos)
		m.step(DT)
		t += DT
	P.inp["sec_hold"] = false

## Tenzo raises rocks with E, then punches them (the right input) or punches with no rock out.
func _punch(m: Match, P: Hunter, T: Hunter, home: Vector3, right: bool) -> void:
	var K: DolmKit = P.ak
	T.teleport(home + Vector3(0, 0, -20.0))
	if right:
		K.use_e()
		step(m, 0.3)
		var rs := rocks(m)
		var gx := K.rock_mid(rs[1]).x if rs.size() > 1 else home.x + 3.4
		var gz := K.rock_mid(rs[0]).z if not rs.is_empty() else home.z
		P.teleport(Vector3(gx - 0.25, home.y, gz - 1.6))
		P.vel = Vector3.ZERO
		aim_at(P, Vector3(gx - 0.25, home.y, gz + 10.0))
	else:
		aim_at(P, home + Vector3(6.0, 0, 0))
	P.fire_cd = 0.0
	var at: Vector3 = P.inp["aim"]
	step(m, 0.95, func():
		P.inp["fire"] = true
		P.inp["aim"] = at)
	P.inp["fire"] = false

## Meeko: a pause, then one ember (the right input), or a second ember straight after the first.
func _ember(m: Match, P: Hunter, T: Hunter, right: bool) -> void:
	step(m, 1.3)
	var tap := func():
		P.fire_cd = 0.0
		P.ammo = int(P.wpn["mag"])
		P.reload_t = 0.0
		P.inp["fire"] = true
		aim_at(P, T.pos)
		step(m, 0.05)
		P.inp["fire"] = false
	if not right:
		tap.call()
		step(m, 0.45)
		seen = 0
	tap.call()

## Gil: the rigged dummy carries one splash mark; two different potions Beach it, two of the same do not.
func _bag(m: Match, P: Hunter, T: Hunter, right: bool) -> void:
	var K: GilKit = P.ak
	K.marks.clear()
	K.bag.clear()
	for v in (["slime", "fire"] if right else ["fire", "fire"]):
		K.bag.append(v)                    # the last one is thrown first
	K.add_mark(T)
	for i in 2:
		K.ch_rmb = 2.0
		aim_at(P, T.pos)
		tap(m, P)
		step(m, 0.8, func(): aim_at(P, T.pos))
