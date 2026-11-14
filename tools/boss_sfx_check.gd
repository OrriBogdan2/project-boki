extends RefCounted
## --boss-sfx-check: each lair boss event plays its own boss_<kind>_* cue and no borrowed Boki cast
## name (k_*). Per boss in Data.BOSSES: the wake roar (heard from 60 m, the lair band), the phase
## sting and the enrage (the same sting, lower), and the defeat sting for the squad that cleared it;
## a rival squad's kill keeps the match-wide horn instead. Every attack plays its own wind-up cue when it starts,
## pitched so its last swell lands on the clip's wind-up key (BossAnim.hit_t, normal and enraged), and its own
## strike cue when its blows run (boulders and lob also the landing); a stagger groans; the body's fall is heard
## by everyone. None of them is a borrowed shared cue. Never touches the save.

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

const BORROWED := ["zap", "boom", "whoosh", "throw", "die_small", "v_warden"]      # what the attacks used to play

func _expect(event: String, cue: String, names: Array, strict := false) -> void:
	var borrowed := names.filter(func(n): return String(n).begins_with("k_") or (strict and BORROWED.has(n)))
	ok(names.has(cue) and borrowed.is_empty(), "%s plays %s, no k_ name (played %s)" % [event, cue, names])

## Every attack, normal and enraged in the last phase: the wind-up cue plays on the start and peaks on the wind-up
## key; the strike cue (and the landing, for a thrown one) plays when the blows run.
func _attacks(main: Node, b: Boss, kind: String, foe: Hunter) -> void:
	b.tgt = foe      # (a dash needs someone to aim at)
	for atk in BossAnim.ATTACKS[kind]:
		for rage in [false, true]:
			b._clear_attack()
			b.stagger_t = 0.0
			b.phase = 2 if rage else 0
			b.enraged = rage
			var tag := "%s %s%s" % [kind, atk, " enraged" if rage else ""]
			var t0 := Time.get_ticks_msec()
			b.call("_atk_" + atk)
			for s in b.steps:      # (what starts with the attack: the first dash's tell)
				if float(s["t"]) <= 0.0:
					s["done"] = true
					(s["f"] as Callable).call()
			_expect(tag + " wind-up", "boss_%s_%s_wind" % [kind, atk], _played(t0), true)
			var wind_cue: AudioStream = Sfx.streams["boss_%s_%s_wind" % [kind, atk]]
			var swell_s := wind_cue.get_length() - BossSfx.WIND_TAIL_S
			var hit_s := BossAnim.hit_t(b)
			var k := swell_s / hit_s
			var fits := k >= BossSfx.PITCH_MIN and k <= BossSfx.PITCH_MAX
			ok(fits, "%s: swell %.2f s, wind-up key %.2f s, pitch x%.2f" % [tag, swell_s, hit_s, k])
			await _gap(main)
			t0 = Time.get_ticks_msec()
			for s in b.steps:
				if not s["done"]:
					(s["f"] as Callable).call()
			_expect(tag + " strike", "boss_%s_%s_hit" % [kind, atk], _played(t0), true)
			if atk in ["boulders", "lob"]:
				t0 = Time.get_ticks_msec()
				b._tick_flying(9.0)
				_expect(tag + " lands", "boss_%s_%s_land" % [kind, atk], _played(t0), true)
			await _gap(main)
	b._clear_attack()
	b.phase = 0
	b.enraged = false

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
		b.dmg_mult = 0.0      # (the blows run for their sound, not for P's health)
		await _attacks(main, b, kind, P)
		t0 = Time.get_ticks_msec()
		b.stagger_t = 0.0
		b._stagger(P, {})
		_expect("%s stagger" % kind, "boss_%s_stagger" % kind, _played(t0))
		await _gap(main)
		t0 = Time.get_ticks_msec()
		b.stagger_t = 0.0
		b.invul_t = 0.0
		b.hurt(b.hp + b.max_hp, P, {"src": "shot"})
		var heard := _played(t0)
		_expect("%s falls to your squad" % kind, "boss_%s_defeat" % kind, heard)
		_expect("%s body falls" % kind, "boss_%s_fall" % kind, heard)
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
