extends RefCounted
## --carry-two-check: carry two Boki in (DECISIONS 2026-11-11, docs/decisions/0091). Prints CARRY2 PASS/FAIL lines.
##   1. the lead and the second both come in; the second waits in the satchel; bots bring two
##   2. both carry passives are on; the same stat from both does not stack (the stronger counts)
##   3. the swap key (rebindable, default C) trades lead and second, then waits out its cooldown (kin_ai.json)
##   4. downed: a downed lead stays where it fell, the second comes out; it goes back in the satchel when it
##      comes round; no swap while you are downed, except the second coming out by itself
##   5. online: the snapshot carries both Boki, "bench" and the lead flag; another game follows the swap

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("CARRY2 %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "weapon": "rifle",
		"cls": "medium", "demo_kin": "cindle"})
	m.set_process(false)
	_step(0.5)
	var P := m.player
	_two_in(P)
	_passives(P)
	_swap_key(P)
	_downed(P)
	_online(P)
	print("CARRY2 %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _step(secs: float) -> void:
	var t := 0.0
	while t < secs:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT)
		t += Match.DT

func _two_in(P: Hunter) -> void:
	ok(P.kin != null and P.kin2 != null and P.kin != P.kin2, "the lead and the second both come in")
	ok(P.kin2 != null and (P.kin2 as Kin).state == "bench", "the second waits in the satchel")
	var bots: Array = m.hunters.filter(func(h): return h.ctrl == "bot")
	var two := bots.all(func(h): return h.kin != null and h.kin2 != null)
	ok(not bots.is_empty() and two, "every bot brings two Boki (%d bots)" % bots.size())

## Lead: move_speed 0.06. Second: move_speed 0.10 and dodge_regen 0.2.
func _passives(P: Hunter) -> void:
	var a: Kin = P.kin
	var b: Kin = P.kin2
	a.ks.carry_passives = [{"stat": "move_speed", "amount": 0.06}]
	b.ks.carry_passives = [{"stat": "move_speed", "amount": 0.10}, {"stat": "dodge_regen", "amount": 0.2}]
	a.state = "shoulder"
	a.settle = 1.0
	a.cmd = "return"
	P._refresh_kin_stats()
	ok(P.kin_carry_on() and KinSlots.second_on(P), "the lead riding with you, the second in the satchel: both on")
	var dr := P.owner_stat("dodge_regen")
	ok(is_equal_approx(dr, 0.2), "the second's own stat counts (dodge_regen %.2f)" % dr)
	var ms := P.owner_stat("move_speed")
	ok(is_equal_approx(ms, 0.10), "a stat from both: the stronger counts, no stack (move_speed %.2f, not 0.16)" % ms)
	a.cmd = "follow"
	a.state = "active"
	P._refresh_kin_stats()
	ms = P.owner_stat("move_speed")
	ok(not P.kin_carry_on() and is_equal_approx(ms, 0.10), "the lead out fighting: the second's passives stay on")
	b.hp = 0.0
	P._refresh_kin_stats()
	ok(not KinSlots.second_on(P) and is_zero_approx(P.owner_stat("dodge_regen")), "a fainted second gives nothing")
	b.hp = b.max_hp

## Pressing the swap key: the match's queued press, on the fixed step (as the key's poll queues it).
func _press(P: Hunter) -> void:
	m.pending_input["swap"] = true
	_step(Match.DT)

func _swap_key(P: Hunter) -> void:
	var evs := InputMap.action_get_events("swap_kin")
	ok(not evs.is_empty() and evs[0] is InputEventKey and (evs[0] as InputEventKey).physical_keycode == KEY_C,
		"swap_kin is bound by default (C)")
	ok(Settings.ACTIONS.any(func(r): return r[0] == "swap_kin") and Settings.key_cap("swap_kin") == "C",
		"it is in the rebindable list and its text comes from Settings.key_cap")
	var a: Kin = P.kin
	var b: Kin = P.kin2
	var cd := float(Content.rules("kin_ai")["swap_cooldown"])
	P.swap_cd = 0.0
	_press(P)
	ok(P.kin == b and P.kin2 == a and a.state == "bench" and b.state != "bench", "the swap key trades lead and second")
	ok(cd > 0.0 and cd <= 5.0 and absf(P.swap_cd - cd) <= Match.DT + 0.01,
		"the swap starts its short cooldown (%.1fs, content/rules/kin_ai.json)" % cd)
	_press(P)
	ok(P.kin == b, "a second press inside the cooldown does nothing")
	_step(cd)
	_press(P)
	ok(P.kin == a and P.kin2 == b, "after the cooldown the swap works again")

func _downed(P: Hunter) -> void:
	var a: Kin = P.kin
	var b: Kin = P.kin2
	a.ks.carry_passives = [{"stat": "dodge_regen", "amount": 0.3}]
	a.teleport(P.pos + Vector3(8.0, 0, 0))       # (out of reach: no scoop by walking into it)
	a.go_down()
	P.swap_cd = 0.0
	_press(P)
	ok(P.kin == b and b.state != "bench" and P.kin2 == a and a.state == "downed",
		"a downed lead stays where it fell, the second comes out (%s / %s)" % [a.state, b.state])
	P._refresh_kin_stats()
	var dr := P.owner_stat("dodge_regen")
	ok(is_zero_approx(dr), "the downed one's passive is off, the new lead's too until it rides (dodge_regen %.2f)" % dr)
	P.swap_cd = 0.0
	P.swap_kin()
	ok(P.kin == b, "a downed Boki can't be swapped back in")
	_online_check(P, "after a swap off a downed lead")
	KinDowned.come_round(a, false)
	ok(a.state == "bench" and KinSlots.second_on(P) and P.kin == b, "it comes round into the satchel, passive on")
	P.downed = true
	P.down_hp = 1000.0
	P.swap_cd = 0.0
	P.swap_kin()
	ok(P.kin == b, "no swap while you are downed")
	b.teleport(P.pos + Vector3(-8.0, 0, 0))
	b.go_down()
	_step(Match.DT)
	ok(P.kin == a and a.state != "bench" and P.kin2 == b, "downed with the lead down: the second comes out by itself")
	P.downed = false
	KinDowned.come_round(b, false)
	ok(b.state == "bench", "the other one comes round into the satchel too")

func _online(P: Hunter) -> void:
	var bumped := Net.VERSION.naturalnocasecmp_to("0.29.0") >= 0
	ok(bumped, "Net.VERSION is bumped for the new sync shape (%s)" % Net.VERSION)
	ok(Match.KIN_STATES.has("bench"), "the kin snapshot can say bench")
	_online_check(P, "at start")
	P.swap_cd = 0.0
	P.swap_kin()
	_online_check(P, "after a swap")

## Another game's copy of P (its nids prefixed "R"), built and updated from P's own snapshot rows.
func _online_check(P: Hunter, when: String) -> void:
	var rows := m.net_snapshot(true)
	ok(rows.size() == 3, "%s: the snapshot carries the hunter and both Boki (%d rows)" % [when, rows.size()])
	var R: Hunter = null
	for row in rows:
		var it: Array = (row as Array).duplicate()
		it[1] = "R" + String(it[1])
		if String(it[0]) == "k":
			it[10] = "R" + String(it[10])
		var e: Ent = m.ents_by_id.get(String(it[1]), null)
		if e == null:
			e = m._net_make(it)
		m._net_apply(e, it)
		if e is Hunter:
			R = e
	var lead: Kin = P.kin
	var second: Kin = P.kin2
	var follows := R != null and R.kin != null and R.kin2 != null
	ok(follows and R.kin.nid == "R" + lead.nid and R.kin2.nid == "R" + second.nid,
		"%s: the other game follows which one leads" % when)
	if R and R.kin2:
		ok((R.kin2 as Kin).state == second.state and (R.kin as Kin).state == lead.state,
			"%s: and each one's state (%s / %s)" % [when, (R.kin as Kin).state, (R.kin2 as Kin).state])
