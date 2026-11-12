extends "res://tools/cast_predict_check.gd"
## --summon-press-check: the Summon key (KinSummon) goes off the frame you press it, like your own abilities.
## It reuses --cast-predict-check's two games: a listen server and a client over the relay at a 100 ms round
## trip with 2% loss. The client plays a Hunter with a Cindle riding as a wisp (boki_wisps on). It presses Summon
## through the real input path (Input actions, Match._process), first offline and then online, and records the
## first tick the burst shows: the wisp is gone and a burst is spawned. Tick 0 is the step run in the frame of
## the press.
## The cases: standing still, mid-dash, in a cast (Neve's Rime holds the cast pose), in a recast window
## (Meeko's Hearthlight, E again throws it) and in hit-stop. Hit-stop is offline only, since online the sim never
## stops: the press waits out the freeze and must go within the shared buffer (DashFlow.BUFFER_S), not be dropped.
## Online is never later than offline. Then the Summon key and G (offline): pressed in the same frame, both
## act; Summon pressed during a G hold bursts the Boki and the hold still opens the order wheel; Summon with the
## wheel open acts and the wheel stays open; the two default keys don't clash.
## Lines: SUMMONPRESS <case> ...; SUMMONPRESS rtt ...; SUMMONPRESS DONE, failures: N.

const HERO := "thief"         # Sparkle, for the cases that need no particular move
## The moves need no cursor (headless it points nowhere useful): Neve's Rime seals her in the cast pose where
## she stands; Meeko's Hearthlight starts on herself and E again throws it (the recast window).
const CASE_HERO := {"cast": "rimewright", "recast": "tender"}
const BOKI := "cindle"
const CASES := ["still", "dash", "recast", "hitstop", "cast"]   # the cast last: the Rime outlasts SETTLE
const ENTER_MAX := 30         # ticks a case may take to reach its state before the press

func _init() -> void:
	flag = "--summon-press-check"
	tag = "SUMMONPRESS"

func _guest() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dn-port="): dn.port = int(a.substr(10))
	Settings.set_v("boki_wisps", true, false)
	await dn._build({})
	_give_boki(dn.m)
	var offline := {}
	for c in CASES:
		offline[c] = await _trial_summon(c)
	var rows: Array = await _g_rows()
	dn.m.queue_free()
	if not await dn._connect():
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while start_d.is_empty() and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	await dn._build(start_d)
	_give_boki(dn.m)
	var rtt := await _rtt()
	for c in CASES:
		var off: Array = offline[c]
		var on: Array = [-1, true] if c == "hitstop" else await _trial_summon(c)
		rows.append(_row(c, off, on))
	var fails := rows.filter(func(r: String): return r.ends_with("FAIL")).size()
	Net.lobby_emit("cp_r", {"c": "result", "rows": rows, "bad": fails, "rtt": rtt})
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 30000:
		await dn._run(DT)
	main.get_tree().quit(0)

## The other Hunter stands idle, no other Boki run about, and the player gets a Cindle riding as a wisp.
func _give_boki(m: Match) -> void:
	_still(m)
	var P := m.player
	var k := Kin.new()
	k.init_kin(m, P.nid + "k", BOKI, Save.new_kin(BOKI), P)
	m.add_child(k)
	m.kins.append(k)
	m.ents_by_id[k.nid] = k
	P.kin = k

## One case's line. Hit-stop: offline within the shared buffer. Every other case: tick 0 offline, online no later.
func _row(c: String, off: Array, on: Array) -> String:
	var ok_: bool = bool(off[1]) and bool(on[1])
	if c == "hitstop":
		ok_ = ok_ and off[0] >= 0 and off[0] * DT <= DashFlow.BUFFER_S + 0.001
	else:
		ok_ = ok_ and off[0] == 0 and _not_later(on[0], off[0])
	return "%s %-8s burst tick off %2s (%3.0f ms) on %2s  in state off %s on %s  %s" % [tag, c, _t(off[0]),
		maxf(0, off[0]) * DT * 1000.0, _t(on[0]), _yes(off[1]), _yes(on[1]), "ok" if ok_ else "FAIL"]

static func _yes(b: bool) -> String:
	return "yes" if b else "NO"

## One Summon press in case `c`: [first tick the burst shows (-1: none), whether the case's state held at the press].
func _trial_summon(c: String) -> Array:
	var m: Match = dn.m
	dn._kit(String(CASE_HERO.get(c, HERO)))
	var P := m.player
	P.teleport(dn.home + dn.PARK)
	var k: Kin = P.kin
	await _rested(m, k)
	await _enter(m, c)
	var inside := _in(m, c)
	var pool: int = m.fx.bi
	Input.action_press("summon")
	var first := -1
	for tick in WATCH:
		if tick == 1:
			Input.action_release("summon")
		_no_mobs(m)
		m._process(DT)
		if first < 0 and not k.wisp and m.fx.bi != pool: first = tick
		await main.get_tree().process_frame
	return [first, inside]

## Into the case's state through the real keys (the hit-stop: the longest freeze a hit gives, Feel tier 5).
func _enter(m: Match, c: String) -> void:
	var key: String = {"dash": "dash", "recast": "signature", "cast": "hunter_ult"}.get(c, "")
	if c == "hitstop":
		m.freeze_frame(float(Feel.HITSTOP[5][0]))
	if key == "":
		return
	Input.action_press(key)          # a tap: down for one frame
	await _frame(m)
	Input.action_release(key)
	for i in ENTER_MAX:
		if _in(m, c):
			return
		await _frame(m)

func _in(m: Match, c: String) -> bool:
	var ak: ArchKit = m.player.ak
	match c:
		"dash": return ak.in_dash()
		"recast": return ak.e_recastable()
		"cast": return ak.cast_locked()
		"hitstop": return m.hitstop > 0.0
	return true

## The Summon key and G (tap: send or call back; hold: the order wheel) never swallow each other.
func _g_rows() -> Array:
	var m: Match = dn.m
	var P := m.player
	var k: Kin = P.kin
	var rows: Array = []
	var ev: InputEvent = InputMap.action_get_events("summon")[0]
	var caps := [Settings.key_cap("summon"), Settings.key_cap("throw")]
	var clash := Settings.conflicts(ev, "summon").any(func(c: Array): return c[0] == "throw")
	rows.append(_g_row("default keys differ, Summon %s, G %s" % caps, caps[0] != caps[1] and not clash))
	await _rested(m, k)
	# both pressed in one frame, G let go the next (a tap): the Summon press and the tap both come through
	Input.action_press("throw")
	Input.action_press("summon")
	var summon_in := await _gather(m, "summon")
	Input.action_release("summon")
	Input.action_release("throw")
	var tap_in := await _gather(m, "throw")
	rows.append(_g_row("same frame: Summon bursts and the G tap comes through", summon_in and tap_in and not k.wisp))
	await _rested(m, k)
	# Summon early in a G hold: the Boki bursts, and the hold still opens the order wheel on the summoned Boki
	Input.action_press("throw")
	var hold := ceili(float(KinCommand.rules().get("g_hold_s", 0.35)) / DT) + 2
	for i in hold:
		if i == 3: Input.action_press("summon")
		if i == 4: Input.action_release("summon")
		await _frame(m)
	var opened := KinWheel.is_open(P)
	rows.append(_g_row("Summon in a G hold: it bursts and the wheel still opens", not k.wisp and opened))
	# Summon with the wheel open: it goes back early, and the wheel stays open until G comes up (no tap then)
	Input.action_press("summon")
	await _frame(m)
	Input.action_release("summon")
	var stays := KinWheel.is_open(P) and k.summon.shrink > 0.0
	Input.action_release("throw")
	var tap_after := await _gather(m, "throw")
	rows.append(_g_row("Summon with the wheel open: it goes back, the wheel stays", stays and not tap_after
		and not KinWheel.is_open(P)))
	return rows

func _g_row(what: String, ok_: bool) -> String:
	return "%s G+summon %s  %s" % [tag, what, "ok" if ok_ else "FAIL"]

## A ready wisp: any summon ended, the shrink over, the cooldown cleared.
func _rested(m: Match, k: Kin) -> void:
	if k.summon.out():
		k.summon.end()
	for i in SETTLE:
		await _frame(m)
	k.summon.cd = 0.0

## One frame with the input read on its own first: whether it queued `key` for the fixed step.
func _gather(m: Match, key: String) -> bool:
	m._gather_input()
	var queued := bool(m.pending_input.get(key, false))
	await _frame(m)
	return queued
