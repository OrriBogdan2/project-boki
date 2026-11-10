extends RefCounted
## --loot-open-sfx-check: the sound of opening a chest or a deathbox (LootOpenSfx, content/sfx/loot.json).
##   1. a chest hold starts its creak loop, the loop lasts while the hold does and a cancel stops it
##      the very step the hold lets go
##   2. completing it ends the loop and plays exactly one sting for the rarest thing it dropped
##      (Common and Fine: none; Rare, Epic, Legendary: their own), over several chests
##   3. a deathbox hold starts the latch loop; the sting follows its rarest item; an empty or
##      common-only box has none, and a box stings once
##   4. voice limit: no more than MAX_LOOPS opening loops at once, none from out of hearing

var main: Node
var fails := 0
var n := 0
const DT := 1.0 / 60.0
const STING_NAMES := ["loot_rare", "loot_epic", "loot_legend"]

func ok(cond: bool, what: String) -> void:
	n += 1
	print("LOOTSFX %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func stings() -> Array:
	return STING_NAMES.filter(func(s): return not (Sfx.recent.get(s, []) as Array).is_empty())

func times(sting: String) -> int:
	return (Sfx.recent.get(sting, []) as Array).size()

func clear_stings() -> void:
	Sfx.last_played.clear()
	Sfx.recent.clear()

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 3, "squad": 1, "tier": 0, "seed": 7, "no_drop": true})
	m.set_process(false)
	_chests(m)
	_boxes(m)
	_limits(m)
	m.queue_free()
	print("LOOTSFX DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		Sfx.listener = m.player.pos
		t += DT

func _chests(m: Match) -> void:
	var P: Hunter = m.player
	var list: Array = m.chests.filter(func(x): return not x.get("ride", false) and not x["open"])
	P.chest_keys = 99
	var c: Dictionary = list[0]
	P.teleport(c["pos"] + Vector3(0.8, 0, 0))
	P.vel = Vector3.ZERO
	Sfx.listener = P.pos
	P.inp["interact"] = true
	_step(m, 0.3)
	var key := String(c.get("lo_key", ""))
	ok(key != "" and Sfx.loop_on(key), "holding at a chest starts its loop")
	ok(float(c["prog"]) > 0.0 and not c["open"], "...while the channel is still running (prog %.2f)" % float(c["prog"]))
	_step(m, 0.2)
	ok(Sfx.loop_on(key), "...and it lasts as long as the hold")
	P.inp["interact"] = false
	m.step(DT)
	ok(not Sfx.loop_on(key), "letting go stops the loop within one step")
	ok(stings().is_empty() and not c["open"], "a cancelled open makes no sting")
	var seen := {}
	var all_good := true
	for ch in list.slice(0, 12):
		P.teleport(ch["pos"] + Vector3(0.8, 0, 0))
		P.vel = Vector3.ZERO
		clear_stings()
		var before := m.wpicks.map(func(w): return w["id"])
		P.inp["interact"] = true
		for i in 120:
			m.step(DT)
			Sfx.listener = P.pos
			if ch["open"]: break
		P.inp["interact"] = false
		if not ch["open"]:
			continue
		var rar := LootOpenSfx.picks_rar(m.wpicks.filter(func(w): return not before.has(w["id"])), 0)
		var want := String(LootOpenSfx.STINGS.get(mini(rar, 4), ""))
		var got := stings()
		seen[rar] = true
		var one: bool = got.size() == (1 if want != "" else 0) and (want == "" or (got[0] == want and times(want) == 1))
		var quiet := not Sfx.loop_on(String(ch.get("lo_key", "x")))
		_step(m, 0.1)
		var still := stings().size() == got.size()
		all_good = all_good and one and quiet and still
	ok(all_good, "each chest: loop over, one sting for its rarest drop, none for Common/Fine (seen %s)" % [seen.keys()])

func _box(m: Match, dead: Hunter, gear: Array) -> Dictionary:
	var b := Life.drop_box(m, dead, "check")
	b["gems"] = 0
	b["seeds"] = {}
	b["caught"] = []
	b["belt"] = []
	b["pack"] = []
	b["gear"] = gear
	b["empty"] = false
	return b

func _loot(m: Match, looter: Hunter, b: Dictionary, secs: float) -> void:
	looter.teleport(b["pos"] + Vector3(0.5, 0, 0))
	looter.vel = Vector3.ZERO
	looter.inp["interact"] = true
	var t := 0.0
	while t < secs:
		m.time += DT
		m._update_interact(DT)
		m.loot_sfx.sweep()
		t += DT
	looter.inp["interact"] = false

func _boxes(m: Match) -> void:
	var looter: Hunter = m.hunters[1]
	var gid := String(Gear.ALL.keys()[0])
	for rar in [0, 1, 2, 3, 4]:
		var dead: Hunter = m.hunters[2]
		var b := _box(m, dead, [{"id": gid, "rar": rar}])
		Sfx.listener = b["pos"]
		clear_stings()
		looter.teleport(b["pos"] + Vector3(0.5, 0, 0))
		looter.inp["interact"] = true
		m.time += DT
		m._update_interact(DT)
		m.loot_sfx.sweep()
		var key := String(b.get("lo_key", ""))
		var started := key != "" and Sfx.loop_on(key)
		looter.inp["interact"] = false
		m.time += DT
		m._update_interact(DT)
		m.loot_sfx.sweep()
		var stopped := not Sfx.loop_on(key)
		var cancelled := stings().is_empty()
		b["lo_done"] = null
		b.erase("lo_done")
		_loot(m, looter, b, Life.R["loot_time"] + 0.3)
		var want := String(LootOpenSfx.STINGS.get(rar, ""))
		var got := stings()
		ok(started and stopped and cancelled, "deathbox rarity %d: latch loop holds, lets go" % rar)
		ok(got.size() == (1 if want != "" else 0) and (want == "" or got[0] == want),
				"deathbox rarity %d: %s (got %s)" % [rar, "sting " + want if want != "" else "no sting", got])
		_loot(m, looter, b, 0.2)
		ok(stings().size() == got.size() and (want == "" or times(want) == 1), "...and one sting per box")
		m.boxes.erase(b)
	var e := _box(m, m.hunters[2], [])
	e["empty"] = true
	Sfx.listener = e["pos"]
	clear_stings()
	_loot(m, looter, e, 1.5)
	ok(stings().is_empty() and not e.has("lo_key") and m.loot_sfx.active.is_empty(), "an empty box: no loop, no sting")
	m.boxes.erase(e)

func _limits(m: Match) -> void:
	var sfx := LootOpenSfx.new()
	var far := {"pos": Sfx.listener + Vector3(Sfx.hear_range + 20.0, 0, 0)}
	sfx.hold("chest", far)
	ok(sfx.active.is_empty() and not Sfx.loop_on(String(far["lo_key"])), "a looter out of hearing makes no loop")
	var ts: Array = []
	for i in LootOpenSfx.MAX_LOOPS + 2:
		var t := {"pos": Sfx.listener + Vector3(2.0 + i, 0, 0)}
		ts.append(t)
		sfx.hold("box", t)
	var cap := LootOpenSfx.MAX_LOOPS
	ok(sfx.active.size() == cap, "at most %d opening loops at once (%d)" % [cap, sfx.active.size()])
	sfx.sweep()
	sfx.sweep()
	ok(sfx.active.is_empty(), "the sweep ends every loop nobody holds")
