extends RefCounted
## --summon-station-check: the Training Area's Boki summon pad (SummonStation). Off the pad there is no card;
## on it the card shows the round-vs-critter rule and the live Summon key cap. Interact brings the three
## practice Bokis in turn as wisps, each with the window and cooldown its species has in the data
## (boki_summon.json role x size, three different windows). For each: the Summon key bursts it out for exactly
## that window, it shrinks back into a wisp, the cooldown runs for exactly its length (a press during it is
## refused, the card counts it down), then it can be summoned again.
## Prints SUMMONPAD PASS/FAIL.

const DT := 1.0 / 60.0
const SLACK := 2.0 * DT  # s: one fixed step either side

var main: Node
var fails := 0
var n := 0
var m: Match
var arena: Arena


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("SUMMONPAD %-52s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	arena = m.arena
	var hunter: Hunter = m.player
	arena.cd_off = true
	_card()
	var windows: Array = []
	for sp in SummonStation.rules()["species"]:
		windows.append(_species(String(sp)))
	var distinct := windows.size() == 3 and windows.count(windows[0]) == 1 and windows.count(windows[1]) == 1
	ok("three species, three different windows", distinct, str(windows))
	var first := String(SummonStation.rules()["species"][0])
	ok("the fourth interact comes round to the first species", _cycle_to(first))
	hunter.teleport(arena.home)
	m.step(DT)
	ok("off the pad the card hides", not arena.grounds.summon_pad.card.visible)
	arena.teardown()
	m.queue_free()
	await main.get_tree().process_frame
	print("SUMMONPAD DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func _card() -> void:
	var hunter: Hunter = m.player
	var pad: SummonStation = arena.grounds.summon_pad
	m.step(DT)
	ok("away from the pad: no card", not pad.card.visible and not pad.on_pad())
	hunter.teleport(pad.pad)
	hunter.vel = Vector3.ZERO
	m.step(DT)
	var text := pad.card.text
	ok("on the pad: the card shows", pad.card.visible and pad.on_pad())
	ok("the card names the round-vs-critter rule", text.contains("Round = Hunter, critter = Boki"))
	var bring := "%s  ·  bring a practice Boki" % Settings.key_cap("interact")
	ok("the card names the interact key to bring a Boki", text.contains(bring))


## Interact on the pad until the pad's Boki is this species (at most one lap).
func _cycle_to(sp: String) -> bool:
	for i in SummonStation.rules()["species"].size():
		var k: Kin = m.player.kin
		if k and not k.dead and String(k.species) == sp:
			return true
		arena.grounds.summon_pad.cycle()
	return String(m.player.kin.species) == sp


## One practice Boki's whole round; returns its window.
func _species(sp: String) -> float:
	var hunter: Hunter = m.player
	if hunter.kin == null or String(hunter.kin.species) != sp:
		arena.grounds.summon_pad.cycle()
	var k: Kin = hunter.kin
	var s := k.summon
	var row: Dictionary = Content.rules("boki_summon")["table"][String(k.ks.ai["role"])]
	var cell: Array = row[k.ks.size]
	var want_win := float(cell[0])
	var want_cd := float(cell[1])
	var tag := sp
	ok(
		tag + ": the pad's Boki is that species, a wisp, ready",
		String(k.species) == sp and k.wisp and s.cd == 0.0 and not s.out()
	)
	ok(
		tag + ": window and cooldown are the species' data",
		is_equal_approx(s.dur, want_win) and is_equal_approx(s.cd_base, want_cd),
		"%s/%s want %s/%s" % [s.dur, s.cd_base, want_win, want_cd]
	)
	m.step(DT)
	var listed := "out %d s, rests %d s" % [int(want_win), int(want_cd)]
	ok(tag + ": the card lists its window and cooldown", arena.grounds.summon_pad.card.text.contains(listed))
	ok(
		tag + ": the Summon key bursts it out",
		KinSummon.press(hunter) and not k.wisp and is_equal_approx(s.left, want_win)
	)
	m.step(DT)
	var left := "left  ·  %s sends it back" % Settings.key_cap("summon")
	ok(tag + ": the card shows the key and the time left", arena.grounds.summon_pad.card.text.contains(left))
	var t := 0.0
	while s.left > 0.0 and t < want_win + 5.0:
		m.step(DT)
		t += DT
	ok(tag + ": it stays out for its window", absf(t - want_win) <= SLACK, "%.2f s, want %.2f" % [t, want_win])
	t = 0.0
	while s.out() and t < 3.0:
		m.step(DT)
		t += DT
	ok(
		tag + ": it shrinks back into a wisp, cooldown running its full length",
		k.wisp and is_equal_approx(s.cd_full, want_cd) and s.cd > want_cd - SLACK - 1e-3,
		"cd %.2f" % s.cd
	)
	ok(tag + ": a press while it rests is refused", not KinSummon.press(hunter) and k.wisp)
	hunter.teleport(arena.grounds.summon_pad.pad)  # (a long wait can drift you off the pad)
	m.step(DT)
	var card := arena.grounds.summon_pad.card.text  # (it was written a step ago: the second may have just turned over)
	var rest := "resting: %d s"
	ok(
		tag + ": the card counts the rest",
		card.contains(rest % ceili(s.cd)) or card.contains(rest % (ceili(s.cd) + 1)),
		card.get_slice("\n", 4)
	)
	t = 0.0
	while s.cd > 0.0 and t < want_cd + 5.0:
		m.step(DT)
		t += DT
	ok(
		tag + ": the cooldown ends after its length",
		absf(t - want_cd) <= 2.0 * SLACK,
		"%.2f s, want %.2f" % [t, want_cd]
	)
	ok(tag + ": it can be summoned again", KinSummon.press(hunter))
	KinSummon.press(hunter)  # (sent back early: the next species starts from a fresh pad Boki)
	return want_win
