extends "res://tools/cast_predict_check.gd"
## --summon-press-check: the Boki key (G, KinCommand) on a wisp bursts it (KinSummon) the frame you press it,
## like your own abilities. It reuses --cast-predict-check's two games: a listen server and a client over the
## relay at a 100 ms round trip with 2% loss. The client plays a Hunter with a Cindle riding as a wisp (boki_wisps
## on). It taps G through the real input path (Input actions, Match._process), first offline and then online, and
## records the first tick the burst shows: the wisp is gone and a burst is spawned. Tick 0 is the step run in the
## frame of the press; letting go of that tap must not send the Boki back.
## The cases: standing still, mid-dash, in a cast (Neve's Rime holds the cast pose), in a recast window
## (Meeko's Hearthlight, E again throws it) and in hit-stop. Hit-stop is offline only, since online the sim never
## stops: the press waits out the freeze and must go within the shared buffer (DashFlow.BUFFER_S), not be dropped.
## Online is never later than offline. Then G alone (offline): there is no separate summon action; a tap bursts
## and the Boki stays out, a tap again sends it back into the wisp, a hold on the wisp bursts and opens the
## order wheel without sending it back, a hold while out only opens the wheel, a wisp on cooldown stays one.
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
		var on: Array = [-1, true, true] if c == "hitstop" else await _trial_summon(c)
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
## Both: the Boki is still out when the watch ends (the tap's release sent nothing back).
func _row(c: String, off: Array, on: Array) -> String:
	var ok_: bool = bool(off[1]) and bool(on[1]) and bool(off[2]) and bool(on[2])
	if c == "hitstop":
		ok_ = ok_ and off[0] >= 0 and off[0] * DT <= DashFlow.BUFFER_S + 0.001
	else:
		ok_ = ok_ and off[0] == 0 and _not_later(on[0], off[0])
	return "%s %-8s burst tick off %2s (%3.0f ms) on %2s  in state off %s on %s  stays out off %s on %s  %s" % [tag, c,
		_t(off[0]), maxf(0, off[0]) * DT * 1000.0, _t(on[0]), _yes(off[1]), _yes(on[1]), _yes(off[2]), _yes(on[2]),
		"ok" if ok_ else "FAIL"]

static func _yes(b: bool) -> String:
	return "yes" if b else "NO"

## One G tap in case `c`: [first tick the burst shows (-1: none), whether the case's state held at the press,
## whether the Boki is still out at the end of the watch].
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
	Input.action_press("throw")
	var first := -1
	for tick in WATCH:
		if tick == 1:
			Input.action_release("throw")
		_no_mobs(m)
		m._process(DT)
		if first < 0 and not k.wisp and m.fx.bi != pool: first = tick
		await main.get_tree().process_frame
	return [first, inside, not k.wisp and k.summon.shrink <= 0.0]

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

## G alone: one Boki key, no summon action. A tap on the wisp bursts it and letting go keeps it out; a tap again
## sends it back; a hold on the wisp bursts and opens the order wheel, letting go picks and keeps it out; a hold
## while out only opens the wheel; a wisp on cooldown stays a wisp.
func _g_rows() -> Array:
	var m: Match = dn.m
	var P := m.player
	var k: Kin = P.kin
	var rows: Array = []
	rows.append(_g_row("one Boki key: no summon action, the ring shows %s" % Settings.key_cap("throw"),
		not InputMap.has_action("summon") and not Settings.ACTIONS.any(func(a): return a[0] == "summon")
		and Settings.key_cap("throw") != "?"))
	await _rested(m, k)
	var queued := await _tap(m)
	var stayed := await _settled_out(m, k)
	rows.append(_g_row("tap on the wisp: the press bursts, letting go keeps it out", queued == "summon" and stayed))
	queued = await _tap(m)
	for i in SETTLE: await _frame(m)
	rows.append(_g_row("tap again: back into the wisp", queued == "throw" and k.wisp and k.summon.cd > 0.0))
	await _rested(m, k)
	var opened := await _hold(m, P)
	Input.action_release("throw")
	var tap_after := await _gather(m, "throw")
	stayed = await _settled_out(m, k)
	rows.append(_g_row("hold on the wisp: it bursts, the wheel opens, letting go keeps it out",
		opened and not tap_after and not KinWheel.is_open(P) and stayed))
	opened = await _hold(m, P)
	Input.action_release("throw")
	tap_after = await _gather(m, "throw")
	stayed = await _settled_out(m, k)
	rows.append(_g_row("hold while out: the wheel opens, it stays out", opened and not tap_after and stayed))
	await _rested(m, k)
	k.summon.cd = 5.0
	await _tap(m)
	for i in 5: await _frame(m)
	rows.append(_g_row("wisp on cooldown: the press leaves it a wisp", k.wisp and k.summon.cd > 0.0))
	k.summon.cd = 0.0
	return rows

## One G tap (down for a frame): the pending key it queued, "summon" on the press, "throw" on the release, or "".
func _tap(m: Match) -> String:
	Input.action_press("throw")
	var on_press := await _gather(m, "summon")
	Input.action_release("throw")
	var on_release := await _gather(m, "throw")
	if on_press:
		return "summon"
	return "throw" if on_release else ""

## G held past g_hold_s (and still down): whether the order wheel is open.
func _hold(m: Match, P: Hunter) -> bool:
	Input.action_press("throw")
	for i in ceili(float(KinCommand.rules().get("g_hold_s", 0.35)) / DT) + 2:
		await _frame(m)
	return KinWheel.is_open(P)

## SETTLE frames on: out as the full Boki and not on its way back.
func _settled_out(m: Match, k: Kin) -> bool:
	for i in SETTLE: await _frame(m)
	return not k.wisp and k.summon.out() and k.summon.shrink <= 0.0

func _g_row(what: String, ok_: bool) -> String:
	return "%s G %s  %s" % [tag, what, "ok" if ok_ else "FAIL"]

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
