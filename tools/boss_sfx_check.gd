extends RefCounted
## --boss-sfx-check: each lair boss event plays its own boss_<kind>_* cue and no borrowed Boki cast
## name (k_*). Per boss in Data.BOSSES: the wake roar (heard from 60 m, the lair band), the phase
## sting and the enrage (the same sting, lower), and the defeat sting for the squad that cleared it;
## a rival squad's kill keeps the match-wide horn instead. Never touches the save.

var bad := 0
var m: Match

func ok(cond: bool, what: String) -> void:
	print("BOSSSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## Names Sfx played since `t0` (ms).
func _played(t0: int) -> Array:
	var names := []
	for n in Sfx.last_played:
		if int(Sfx.last_played[n]) >= t0: names.append(n)
	return names

func _gap(main: Node) -> void:
	await main.get_tree().create_timer(0.12).timeout      # (Sfx merges a repeat of one sound inside 30 ms)

func _expect(event: String, cue: String, names: Array) -> void:
	var borrowed := names.filter(func(n): return String(n).begins_with("k_"))
	ok(names.has(cue) and borrowed.is_empty(), "%s plays %s, no k_ name (played %s)" % [event, cue, names])

func run(main: Node) -> void:
	main.set_meta("boss_sfx_check", self)      # (a RefCounted that awaits frames must be kept alive)
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for L in m.lairs.list: m.lairs.activate(L)
	var seen := []
	for L in m.lairs.list:
		var b: Boss = L["boss_mob"]
		var kind := String(L["boss"])
		if seen.has(kind): continue
		seen.append(kind)
		for g in L["guards"]:
			if is_instance_valid(g) and not g.dead:
				g.dead = true
				g.visible = false
		if L["state"] == "sealed": m.lairs.open(L, P, "dial")
		P.teleport(Vector3(L["c"].x, m.world.ground_at(L["c"].x, L["c"].z), L["c"].z))
		Sfx.listener = L["c"] + Vector3(60, 0, 0)      # the lair band: past hear_range, inside the set's reach
		var t0 := Time.get_ticks_msec()
		m.lairs.wake(L, P)
		_expect("%s wakes (heard from 60 m)" % kind, "boss_%s_wake" % kind, _played(t0))
		await _gap(main)
		Sfx.listener = b.pos      # the fight itself: the stings carry the usual 22 m
		t0 = Time.get_ticks_msec()
		b._phase_up(1)
		_expect("%s phase 2" % kind, "boss_%s_phase" % kind, _played(t0))
		await _gap(main)
		t0 = Time.get_ticks_msec()
		m.lairs.on_enrage(b)
		_expect("%s enrage" % kind, "boss_%s_phase" % kind, _played(t0))
		await _gap(main)
		t0 = Time.get_ticks_msec()
		b.stagger_t = 0.0
		b.invul_t = 0.0
		b.hurt(b.hp + b.max_hp, P, {"src": "shot"})
		_expect("%s falls to your squad" % kind, "boss_%s_defeat" % kind, _played(t0))
		await _gap(main)
		t0 = Time.get_ticks_msec()
		BossSfx.defeat(m, b, Q)
		var rival := _played(t0)
		var mine := rival.has("boss_%s_defeat" % kind)
		ok(rival.has("horn") and not mine, "%s falls to a rival: the horn, not your sting" % kind)
		await _gap(main)
	ok(seen.size() == Data.BOSSES.size(), "all %d bosses were in this match (%s)" % [Data.BOSSES.size(), seen])
	print("BOSSSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
