extends RefCounted
## --echo-steps-check: Echo Steps (scripts/home/echo_steps.gd, briefs/design/GARDEN_MODERN.md 4.2 game 2).
## Plays whole dances headless by feeding the Run presses at chosen times on its (audio) clock:
##   1. length: a dance lasts what the rules add up to, about 90 s
##   2. perfect presses: every beat a hit, one unbroken streak, the exact score from the rules
##   3. late presses: inside the window all hit, past it all miss; Focus 100 widens the window
##   4. missing presses and wrong stones: all miss and score nothing
##   5. trust fixes one miss a round at Close, two at Soulbound; Sound keeps a streak through one miss
##   6. the rival copies only in the last round, and its Focus sets how often it misses
##   7. the machine: no move refused, the phases in order, RESULT goes nowhere
##   8. settle: versus winner and loser, a solo's gems
##   9. on the base: no stones with base_mode off; with it on, a dance starts and ends with a card
##  10. the practice: one slow phrase of 4 beats the lead calls, perfect presses hit all 4; on the base
##      the first dance opens with it (key caps on the stones, a rebind shows, the line, the beat bar),
##      it pays nothing and round one follows, never again; a skip goes straight to round one
## Never touches the real save.

const DT := 1.0 / 60.0           # s per step of the fake clock
const LEN_LOW := 80.0            # s, the shortest dance that is still "about 90 s"
const LEN_HIGH := 100.0          # s, the longest
const COPY_DANCES := 40          # seeded versus dances per Focus in the copy test
const COPY_TOL := [0.06, 0.04]   # how far the rival's miss share may stray from rival_miss (Focus 0, 100)
const EDGE := 0.01               # s inside a hit window a late press lands
const PAST := 0.02               # s past a hit window a too-late press lands
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("ECHO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_length()
	_perfect()
	_late()
	_missing()
	_trust_and_sound()
	_rival()
	_machine()
	_settle()
	_practice()
	await _on_base()
	print("ECHO DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String, focus: int, trust: float) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["stats"]["focus"] = focus
	k["needs"]["joy"] = 50.0
	k["needs"]["energy"] = 90.0
	k["trust"] = trust
	return k

## A species that is not of the Sound type (echo_steps rules sound_themes), or one that is.
func _species(sound: bool) -> String:
	var themes: Array = EchoSteps.rules()["sound_themes"]
	for sp in Data.KIN:
		if themes.has(BaseShove.theme({"species": sp})) == sound:
			return sp
	return ""

## Plays a whole dance: in your turns you press offset s after each beat (on the stone it asks for, or
## the next one with wrong), except the beats skip(run, i) leaves out.
func _dance(you: Dictionary, rival: Dictionary, offset: float, skip := Callable(), wrong := false,
		seed_ := 7) -> EchoSteps.Run:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	return _play(EchoSteps.Run.new(you, rival, rng), offset, skip, wrong)

func _play(r: EchoSteps.Run, offset: float, skip := Callable(), wrong := false) -> EchoSteps.Run:
	var t := 0.0
	while not r.over() and t < LEN_HIGH * 2.0:
		var nt := t + DT
		if r.mine():
			for i in r.pattern.size():
				var pt := r.at(r.first + i) + offset
				if pt <= t or pt > nt or (skip.is_valid() and skip.call(r, i)):
					continue
				var s: int = i % 4 if r.pattern[i] < 0 else r.pattern[i]
				r.press(pt, (s + 1) % 4 if wrong else s)
		r.step(nt)
		r.events.clear()
		t = nt
	return r

## Beats you are judged on in a dance, and the score of a dance with every one of them hit.
func _your_beats() -> int:
	var R := EchoSteps.rules()
	var n := 0
	for b in R["rounds"]:
		n += int(b) * int(R["phrases"])
	return n

func _perfect_score(n: int) -> int:
	var R := EchoSteps.rules()
	var total := 0
	for k in n:
		total += int(R["hit_pts"]) + int(R["streak_pts"]) * mini(k, int(R["streak_cap"]))
	return total

func _length() -> void:
	var R := EchoSteps.rules()
	var r := _dance(_kin(_species(false), "Pip", 0, 0.0), {}, 0.0)
	var beats := 0
	for b in R["rounds"]:
		beats += int(R["count_in"]) + int(R["phrases"]) * (2 * int(b) + int(R["gap"])) + int(R["score_beats"])
	var want := (beats - 0.5) * 60.0 / float(R["bpm"])
	ok(is_equal_approx(r.end_t, want), "length: the dance ends at %.1f s (rules add up to %.1f s)" % [r.end_t, want])
	var about := r.end_t >= LEN_LOW and r.end_t <= LEN_HIGH
	ok(about, "length: about 90 s (%.1f s, %d to %d)" % [r.end_t, LEN_LOW, LEN_HIGH])

func _perfect() -> void:
	var n := _your_beats()
	var r := _dance(_kin(_species(false), "Pip", 0, 0.0), {}, 0.0)
	ok(r.hits[0] == n and r.beats[0] == n, "perfect: %d of %d beats hit (%d judged)" % [r.hits[0], n, r.beats[0]])
	ok(r.best[0] == n, "perfect: one unbroken streak of %d" % r.best[0])
	ok(r.score[0] == _perfect_score(n), "perfect: score %d = %d from the rules" % [r.score[0], _perfect_score(n)])
	var early := _dance(_kin(_species(false), "Pip", 0, 0.0), {}, -0.1)
	ok(early.hits[0] == n, "early by 100 ms: still all hits (%d)" % early.hits[0])

func _late() -> void:
	var n := _your_beats()
	var R := EchoSteps.rules()
	var w0 := float(R["window_ms"][0]) / 1000.0
	var w1 := float(R["window_ms"][1]) / 1000.0
	var plain := _kin(_species(false), "Pip", 0, 0.0)
	var sharp := _kin(_species(false), "Pip", 100, 0.0)
	var inside := _dance(plain, {}, w0 - EDGE)
	ok(inside.hits[0] == n, "late by %d ms (inside the window): %d of %d hit" % [ms(w0 - EDGE), inside.hits[0], n])
	var past := _dance(plain, {}, w0 + PAST)
	ok(past.hits[0] == 0 and past.score[0] == 0 and past.beats[0] == n,
			"late by %d ms (past it, Focus 0): %d hits, %d points" % [ms(w0 + PAST), past.hits[0], past.score[0]])
	var wide := _dance(sharp, {}, w0 + PAST)
	ok(wide.hits[0] == n, "the same presses at Focus 100 (window %d ms): %d of %d hit" % [ms(w1), wide.hits[0], n])
	var too_late := _dance(sharp, {}, w1 + PAST)
	ok(too_late.hits[0] == 0, "late past %d ms at Focus 100: %d hits" % [ms(w1), too_late.hits[0]])

func ms(s: float) -> int:
	return roundi(s * 1000.0)

func _missing() -> void:
	var n := _your_beats()
	var none := _dance(_kin(_species(false), "Pip", 50, 0.0), {}, 0.0, func(_r, _i): return true)
	ok(none.hits[0] == 0 and none.score[0] == 0 and none.beats[0] == n,
			"no presses: %d hits, %d points, %d of %d beats judged" % [none.hits[0], none.score[0], none.beats[0], n])
	var wrong := _dance(_kin(_species(false), "Pip", 50, 0.0), {}, 0.0, Callable(), true)
	var lead := int(EchoSteps.rules()["rounds"][-1]) * int(EchoSteps.rules()["phrases"])
	ok(wrong.hits[0] == lead, "wrong stones: only your own lead's %d beats count (%d hits)" % [lead, wrong.hits[0]])

func _trust_and_sound() -> void:
	var rounds := (EchoSteps.rules()["rounds"] as Array).size()
	var skip_all := func(_r, _i): return true
	var close := _dance(_kin(_species(false), "Pip", 0, 55.0), {}, 0.0, skip_all)
	ok(close.fixed == rounds and close.hits[0] == rounds, "Close: it fixes one miss a round (%d fixed)" % close.fixed)
	var soul := _dance(_kin(_species(false), "Pip", 0, 95.0), {}, 0.0, skip_all)
	ok(soul.fixed == 2 * rounds, "Soulbound: two a round (%d fixed)" % soul.fixed)
	var wary := _dance(_kin(_species(false), "Pip", 0, 10.0), {}, 0.0, skip_all)
	ok(wary.fixed == 0, "Wary: none (%d fixed)" % wary.fixed)
	var one_a_round := func(r: EchoSteps.Run, i: int): return r.phrase == 1 and i == 1
	var plain := _dance(_kin(_species(false), "Pip", 0, 0.0), {}, 0.0, one_a_round)
	var sound := _dance(_kin(_species(true), "Hum", 0, 0.0), {}, 0.0, one_a_round)
	ok(sound.hits[0] == plain.hits[0] and sound.best[0] == sound.hits[0] and plain.best[0] < plain.hits[0],
			"Sound type: one miss a round keeps the streak (best %d of %d hits; plain best %d)"
			% [sound.best[0], sound.hits[0], plain.best[0]])
	ok(sound.score[0] > plain.score[0],
			"Sound type: the kept streak scores more (%d > %d)" % [sound.score[0], plain.score[0]])
	var leaned := _kin(_species(false), "Lea", 0, 0.0)
	leaned["lean"] = {"sound": 12.0}
	ok(EchoSteps.streak_saves(leaned) == 1 and EchoSteps.streak_saves(plain.recs[0]) == 0,
			"a Sound lean saves a streak too, a plain Boki does not")

func _rival() -> void:
	var lead := int(EchoSteps.rules()["rounds"][-1]) * int(EchoSteps.rules()["phrases"])
	var misses := [0, 0]
	for f in 2:
		for n in COPY_DANCES:
			var r := _dance(_kin(_species(false), "Pip", 0, 0.0), _kin(_species(false), "Ash", f * 100, 0.0), 0.0,
					Callable(), false, n + 1)
			if n == 0 and f == 0:
				ok(r.beats[1] == lead, "the rival copies only your lead: %d of %d beats" % [r.beats[1], lead])
			misses[f] += r.beats[1] - r.hits[1]
	var total := COPY_DANCES * lead
	var want: Array = EchoSteps.rules()["rival_miss"]
	ok(misses[1] < misses[0], "Focus 100 copies better: %d misses vs %d at Focus 0" % [misses[1], misses[0]])
	var share := [float(misses[0]) / total, float(misses[1]) / total]
	var near := absf(share[0] - float(want[0])) < COPY_TOL[0] and absf(share[1] - float(want[1])) < COPY_TOL[1]
	ok(near, "its misses follow rival_miss (%.2f, %.2f vs %s)" % [share[0], share[1], want])

func _machine() -> void:
	var rng := RandomNumberGenerator.new()
	var r := EchoSteps.Run.new(_kin(_species(false), "Pip", 0, 0.0), {}, rng)
	var order: Array = []
	var t := 0.0
	while not r.over() and t < LEN_HIGH * 2.0:
		t += DT
		r.step(t)
		if order.is_empty() or order[-1] != r.state:
			order.append(r.state)
	var S := EchoSteps.Run.S
	var phrases := int(EchoSteps.rules()["phrases"])
	var rounds := (EchoSteps.rules()["rounds"] as Array).size()
	var want: Array = []
	for i in rounds:
		for p in phrases:
			want.append_array([S.CALL, S.ANSWER])
		want.append(S.SCORE)
	want.append(S.RESULT)
	ok(order == want, "machine: %d phases in order, call, answer, score, result" % want.size())
	ok(r.refused == 0, "machine: no move refused (%d)" % r.refused)
	ok(not r.go(S.CALL) and r.refused == 1, "machine: RESULT goes nowhere, the move is refused and counted")

func _settle() -> void:
	Save.d = Save.fresh()
	var a := _kin(_species(false), "Pip", 50, 50.0)
	var b := _kin(_species(false), "Ash", 50, 50.0)
	var r := EchoSteps.Run.new(a, b, RandomNumberGenerator.new())
	r.score = [300, 100]
	r.beats = [30, 24]
	var gems := int(Save.d["gems"])
	var res := EchoSteps.settle(r)
	ok(res["win"] == a and res["good"], "settle: the better points per beat wins (10.0 vs 4.2)")
	ok(float(a["needs"]["joy"]) > 50.0 and float(a["trust"]) > 50.0 and float(b["needs"]["joy"]) < 50.0,
			"settle: the winner gains joy and trust, the loser sulks")
	ok(String(a["memory"][-1]["text"]).contains("Ash") and String(b["memory"][-1]["text"]).contains("Pip"),
			"settle: both remember it")
	ok(int(Save.d["gems"]) == gems + int(EchoSteps.rules()["gems_win"]), "settle: win gems for your Boki's win")
	var solo := EchoSteps.Run.new(_kin(_species(false), "Bo", 0, 0.0), {}, RandomNumberGenerator.new())
	solo.hits = [10, 0]
	solo.beats = [40, 0]
	gems = int(Save.d["gems"])
	var sres := EchoSteps.settle(solo)
	ok(not sres["good"] and int(Save.d["gems"]) == gems + int(EchoSteps.rules()["gems_ran"]),
			"settle: a poor solo (10 of 40) pays the small gems")

func _practice() -> void:
	var R := EchoSteps.rules()
	var r := EchoSteps.Run.new(_kin(_species(false), "Pip", 0, 0.0), {}, RandomNumberGenerator.new(), true)
	ok(r.practice and r.beat_s > 60.0 / float(R["bpm"]) and r.pattern.size() == 4 and not r.you_lead(),
			"practice: 4 beats at %.0f bpm (the dance %d), the lead calls" % [60.0 / r.beat_s, int(R["bpm"])])
	_play(r, 0.0)
	ok(r.over() and r.hits[0] == 4 and r.beats[0] == 4 and r.refused == 0,
			"practice: perfect presses hit %d of %d, then it is over" % [r.hits[0], r.beats[0]])

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 2:
		var k := _kin(["zapple", "cindle"][i], ["Pip", "Ash"][i], 10, 50.0)
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hecho == null, "off: no stones on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hecho != null, "on: the base has Echo Steps")
	if home.hecho != null:
		var es: EchoSteps = home.hecho
		var at := Vector2(es.middle.position.x, es.middle.position.z)
		ok(is_instance_valid(es.middle) and es.stones.size() == 4 and es.find(at) == {"kind": "echo"},
				"on: four stones offer a dance")
		for k in home.kins:
			k.erase("indoors")
		await _first_dance(es)
		es.use()
		ok(es.run != null and not es.run.practice and es.run.versus and is_instance_valid(es.readout),
				"on: the next dance is a versus straight away (the practice never repeats)")
		var press := InputEventAction.new()
		press.action = "up"
		press.pressed = true
		ok(es.input(press), "on: W is taken by the dance")
		var you: Node3D = es.dancers[EchoSteps.YOU]["node"]
		var now := es.clock
		es._show(["hop", EchoSteps.YOU, 0], now)
		ok(you.get_meta("kact", "") == "stonehop", "on: a hop plays the stone hop")
		es._place(now + float(EchoSteps.rules()["hop_s"]))
		ok(not you.has_meta("kact"), "on: it ends with the hop")
		es._show(["kept", EchoSteps.YOU, 0], now)
		es._show(["hop", EchoSteps.YOU, 1], now + 0.1)
		ok(you.get_meta("kact", "") == "spin", "on: a kept phrase spins, and a hop does not cut it short")
		es._place(now + EchoSteps.spin_s())
		ok(not you.has_meta("kact"), "on: the spin lasts two beats")
		es.run.step(LEN_HIGH * 2.0)
		es.tick(0.1)
		ok(es.run == null and is_instance_valid(es.card), "on: the dance ends with a result card")
		ok(not you.has_meta("kact"), "on: and nobody keeps a dance clip")
		Save.d["tutorial"].erase("echo_practice")
		es.use()
		var skip := InputEventAction.new()
		skip.action = "interact"
		skip.pressed = true
		ok(es.run.practice and es.input(skip), "skip: the interact key is taken in the practice")
		ok(not es.run.practice and es.run.round_i == 0 and es.run.state == EchoSteps.Run.S.CALL
				and not es.caps[0].visible, "skip: straight to round one, the key caps gone")
		var stop := InputEventAction.new()
		stop.action = "menu"
		stop.pressed = true
		es.input(stop)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

## The first dance on a save: the practice with "up" rebound to I, then round one, nothing paid.
func _first_dance(es: EchoSteps) -> void:
	var up := InputMap.action_get_events("up")
	InputMap.action_erase_events("up")
	InputMap.action_add_event("up", _key(KEY_I))
	var gems := int(Save.d["gems"])
	var you: Dictionary = es.h.hrace.entrants()[0]["rec"]
	var energy := float(you["needs"]["energy"])
	var memories: int = you.get("memory", []).size()
	es.use()
	ok(es.run != null and es.run.practice and Save.d["tutorial"].get("echo_practice", false),
			"practice: the first dance opens with it, marked done at once")
	var texts: Array = es.caps.map(func(c: Label3D): return c.text)
	var want: Array = EchoSteps.KEYS.map(func(a: String): return Settings.key_cap(a))
	ok(texts == want and texts[0] == "I" and es.caps.all(func(c: Label3D): return c.visible),
			"practice: each stone shows its key, the rebind too (%s)" % " ".join(texts))
	ok(es.lbl.text == EchoSteps.PRACTICE_LINE and is_instance_valid(es.bar), "practice: the one line and the beat bar")
	var hint: Label = es.readout.get_child(0).get_child(-1)
	ok(hint.text.begins_with("I ") and hint.text.contains(Settings.key_cap("interact") + " to skip"),
			"practice: the key row shows the rebind and the skip (%s)" % hint.text)
	await main.get_tree().process_frame
	var lit := -1
	var t := 0.0
	while not es.run.over() and t < LEN_HIGH:
		t += DT
		es.run.step(t)
		for e in es.run.events:
			if lit < 0 and e[0] == "hop" and e[1] == EchoSteps.RIVAL:
				lit = e[2]
				es._show(e, t)
				es.run.events.clear()
				es.tick(DT)
				var dark: Label3D = es.caps[(lit + 1) % 4]
				ok(es.caps[lit].modulate.a > EchoSteps.KEY_DIM and is_equal_approx(dark.modulate.a, EchoSteps.KEY_DIM),
						"practice: the stone the lead hops on lights its key, the others stay dim")
				break
		es.run.events.clear()
	ok(lit >= 0 and es.run.over(), "practice: the lead hops the stones, then the phrase ends")
	es.tick(DT)
	InputMap.action_erase_events("up")
	for e in up:
		InputMap.action_add_event("up", e)
	ok(es.run != null and not es.run.practice and es.run.round_i == 0, "practice: round one follows it")
	ok(int(Save.d["gems"]) == gems and float(you["needs"]["energy"]) == energy
			and you.get("memory", []).size() == memories, "practice: no gems, energy or memory for it")
	var stop := InputEventAction.new()
	stop.action = "menu"
	stop.pressed = true
	es.input(stop)
