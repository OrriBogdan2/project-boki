extends RefCounted
## --summon-pad-check: the Training Grounds' Boki summon pad (SummonPad). Off the pad only its name shows; on it
## the card shows the round-vs-critter rule and the live Summon key cap. Interact brings the three practice
## Boki in turn as wisps, each with the window and cooldown its species has in the data (boki_summon.json role
## x size, three different windows). The pad stands within the shortest chase of a dummy (kin_ai.json
## chase_base). For each, a timed round with the Boki held where it burst out (the start strip's edge is near,
## docs/DEBT.md): the Summon key bursts it out for exactly its window, it shrinks back into a wisp, the cooldown
## runs for exactly its length (a press during it is refused, the card counts it down), then it can be summoned
## again; and the key again sends it back early (its full rest).
## With --shots-dir=<dir> (GPU, a renderer) it also saves the card: ready, then the Boki out.
## Prints SUMMONPAD PASS/FAIL.

const DT := 1.0 / 60.0
const SLACK := 2.0 * DT      # s: one fixed step either side
const OPTS := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"training": true, "practice": true}

var main: Node
var fails := 0
var n := 0
var m: Match
var A: Arena

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("SUMMONPAD %-58s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true, KitDrill.SAVE_KEY: true}
	Save.d = d
	m = Match.new()
	main.add_child(m)
	await m.start(OPTS.duplicate())
	m.set_process(false)
	for mb in m.mobs:      # (the island's monsters roam: one killing the Boki ends its window early, by design)
		mb.queue_free()
	m.mobs.clear()
	A = m.arena
	ok("the Training Grounds have the pad", A != null and A.pad != null)
	if A == null or A.pad == null:
		_done()
		return
	_card()
	var windows: Array = []
	for sp in SummonPad.rules()["species"]:
		windows.append(_species(String(sp)))
	var distinct := windows.size() == 3 and windows.count(windows[0]) == 1 and windows.count(windows[1]) == 1
	ok("three species, three different windows", distinct, str(windows))
	var first := String(SummonPad.rules()["species"][0])
	ok("the fourth interact comes round to the first species", _cycle_to(first))
	m.player.teleport(A.home)
	m.step(DT)
	ok("off the pad the card goes, its name stays", A.pad.card.text == SummonPad.SIGN)
	var dir := ""
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--shots-dir="):
			dir = String(arg).substr(12)
	if dir != "":
		await _shots(dir)
	_done()

func _done() -> void:
	if A:
		A.teardown()
	m.queue_free()
	await main.get_tree().process_frame
	print("SUMMONPAD DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _card() -> void:
	var P: Hunter = m.player
	var S: SummonPad = A.pad
	m.step(DT)
	ok("away from the pad: only its name, no card", S.card.text == SummonPad.SIGN and not S.on_pad())
	var near := 1e9
	for dm in A.dummies:
		near = minf(near, S.pad.distance_to(dm["at"]))
	var chase := float(Content.rules("kin_ai")["chase_base"])
	ok("the pad stands within the shortest chase of a dummy", near < chase, "%.1f m, chase %.1f m" % [near, chase])
	P.teleport(S.pad)
	P.vel = Vector3.ZERO
	m.step(DT)
	var text := S.card.text
	ok("on the pad: the card shows", text != SummonPad.SIGN and S.on_pad())
	ok("the card names the round-vs-critter rule", text.contains("Round = Hunter, critter = Boki"))
	if P.kin == null or not (SummonPad.rules()["species"] as Array).has(String(P.kin.species)):
		var bring := "%s  ·  bring a practice Boki" % Settings.key_cap("interact")
		ok("the card names the interact key to bring a Boki", text.contains(bring))
	_press_interact()
	var k: Kin = P.kin
	var first := String(SummonPad.rules()["species"][0])
	var brought := k != null and String(k.species) == first and k.wisp
	ok("the interact key on the pad brings a practice Boki as a wisp", brought)

## The interact key, pressed and let go, through the viewport (as a player's key reaches ArenaKeys).
func _press_interact() -> void:
	var bound: Array = InputMap.action_get_events("interact").filter(func(e): return e is InputEventKey)
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = (bound[0] as InputEventKey).keycode
		ev.physical_keycode = (bound[0] as InputEventKey).physical_keycode
		ev.pressed = down
		main.get_viewport().push_input(ev)

## Interact on the pad until the pad's Boki is this species (at most one lap).
func _cycle_to(sp: String) -> bool:
	for i in SummonPad.rules()["species"].size():
		var k: Kin = m.player.kin
		if k and not k.dead and String(k.species) == sp:
			return true
		A.pad.cycle()
	return String(m.player.kin.species) == sp

## One practice Boki's whole round; returns its window.
func _species(sp: String) -> float:
	var P: Hunter = m.player
	P.teleport(A.pad.pad)
	if P.kin == null or String(P.kin.species) != sp:
		A.pad.cycle()
	var k: Kin = P.kin
	var s := k.summon
	var row: Dictionary = Content.rules("boki_summon")["table"][String(k.ks.ai["role"])]
	var cell: Array = row[k.ks.size]
	var want_win := float(cell[0])
	var want_cd := float(cell[1])
	ok(sp + ": the pad's Boki is that species, a wisp, ready",
		String(k.species) == sp and k.wisp and s.cd == 0.0 and not s.out())
	ok(sp + ": window and cooldown are the species' data",
		is_equal_approx(s.dur, want_win) and is_equal_approx(s.cd_base, want_cd),
		"%s/%s want %s/%s" % [s.dur, s.cd_base, want_win, want_cd])
	m.step(DT)
	var listed := "out %d s, rests %d s" % [int(want_win), int(want_cd)]
	ok(sp + ": the card lists its window and cooldown", A.pad.card.text.contains(listed))
	var ready := "ready: press %s" % Settings.key_cap("summon")
	ok(sp + ": the card says the Summon key while it is ready", A.pad.card.text.contains(ready))
	_timed(sp, k, want_win, want_cd)
	_sent_back(sp, k)
	return want_win

## Out (the timed round's last press), the Summon key again sends it back early: back in its wisp, resting its
## full cooldown.
func _sent_back(sp: String, k: Kin) -> void:
	var s := k.summon
	ok(sp + ": the Summon key again sends it back early", KinSummon.press(m.player) and s.left == 0.0 and s.out())
	var t := 0.0
	while s.out() and t < 3.0:
		m.step(DT)
		t += DT
	var full := is_equal_approx(s.cd, s.cd_base)
	ok(sp + ": back in its wisp, resting its full cooldown", k.wisp and full, "cd %.2f" % s.cd)

## The timed round: out for exactly its window, then resting exactly its cooldown, a press refused meanwhile
## and the card counting the rest down. Out, it is held where it burst: a fall or a kill would end the window
## early by design (--summon-death-check), and only the timers are under test here.
func _timed(sp: String, k: Kin, want_win: float, want_cd: float) -> void:
	var P: Hunter = m.player
	var s := k.summon
	ok(sp + ": the Summon key bursts it out", KinSummon.press(P) and not k.wisp and is_equal_approx(s.left, want_win))
	m.step(DT)
	var left := "left  ·  %s sends it back" % Settings.key_cap("summon")
	ok(sp + ": the card shows the key and the time left", A.pad.card.text.contains(left))
	var t := DT
	var spot := k.pos
	while s.left > 0.0 and t < want_win + 5.0:
		k.teleport(spot)
		m.step(DT)
		t += DT
	ok(sp + ": it stays out for its window", absf(t - want_win) <= SLACK, "%.2f s, want %.2f" % [t, want_win])
	t = 0.0
	while s.out() and t < 3.0:
		m.step(DT)
		t += DT
	ok(sp + ": it shrinks back into a wisp, cooldown running its full length",
		k.wisp and is_equal_approx(s.cd_full, want_cd) and s.cd > want_cd - SLACK - 1e-3, "cd %.2f" % s.cd)
	ok(sp + ": a press while it rests is refused", not KinSummon.press(P) and k.wisp)
	P.teleport(A.pad.pad)      # (a long wait can drift you off the pad)
	m.step(DT)
	var card := A.pad.card.text      # (it was written a step ago: the second may have just turned over)
	var rest := "resting: %d s"
	ok(sp + ": the card counts the rest",
		card.contains(rest % ceili(s.cd)) or card.contains(rest % (ceili(s.cd) + 1)), card.get_slice("\n", 4))
	t = 0.0
	while s.cd > 0.0 and t < want_cd + 5.0:
		m.step(DT)
		t += DT
	var timed := absf(t - want_cd) <= 2.0 * SLACK
	ok(sp + ": the cooldown ends after its length", timed, "%.2f s, want %.2f" % [t, want_cd])
	ok(sp + ": it can be summoned again", KinSummon.press(P))

## GPU frames of the card under the live match: ready on the pad, then the Boki out at the dummies.
func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	P.teleport(A.pad.pad)
	m.set_process(true)
	await _frames(60)
	_take(dir, "summon_pad_card")
	KinSummon.press(P)
	await _frames(90)
	_take(dir, "summon_pad_out")
	m.set_process(false)

func _frames(count: int) -> void:
	for i in count:
		await main.get_tree().process_frame

func _take(dir: String, file: String) -> void:
	main.get_viewport().get_texture().get_image().save_jpg(dir.path_join(file + ".jpg"), 0.9)
	print("SUMMONPAD shot %s" % dir.path_join(file + ".jpg"))
