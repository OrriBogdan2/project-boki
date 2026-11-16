extends RefCounted
## --duo-tutorial-check: the 2v2 tutorial (DuoTutorial) plays through with the test driver for each
## starter (Lace's bow, Kael's blade, Vex's gun): every beat is reached in order and passes on what the
## driver did (none of them by the stall skip), the guide is on your side and the rivals on the other,
## nobody leaves the walled ring, the rivals hold still in the first beats, and the run ends with the
## end card inside the time limit. A player who does nothing gets the nag line and the beat passes itself.

const STARTERS := ["archer", "juggernaut", "gunslinger"]
const RUN_MAX := 420.0       # s of match time a full run may take
const STILL_BEATS := ["meet", "slide", "attack", "sec"]
const RING_R := 13.4         # m: past the ring wall's inner tiles (content/maps/duo_arena.json, walls at 12.4 and 13.2)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("DUOTUT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	for arch in STARTERS:
		await _play(main, arch)
	await _idle(main)
	print("DUOTUT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _play(main: Node, arch: String) -> void:
	seed(7)
	var o := DuoTutorial.opts(arch)
	o["demo_kin"] = "cindle"
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	var tu: DuoTutorial = m.duo
	ok(tu != null and tu.foes.size() == 2, arch + ": the tutorial is up with two rivals")
	var p := m.player
	ok(tu.guide.team == p.team and tu.foes.all(func(f): return f.team != p.team), arch + ": 2v2 sides")
	var reached: Array = []
	var skipped: Array = []
	var still_shots := 0
	var outside := 0
	var t := 0.0
	while t < RUN_MAX and not (tu.finished and tu.end_t > 1.5):
		DuoTutorialDrive.drive(m, tu)
		var gap_was := tu.gap_t
		var quiet := tu.quiet_t
		m.step(Match.DT)
		t += Match.DT
		if tu.id() != "" and not reached.has(tu.id()):
			reached.append(tu.id())
		if gap_was <= 0.0 and tu.gap_t > 0.0 and quiet + Match.DT >= float(tu.cfg["skip_s"]):
			skipped.append(tu.id())
		if tu.id() in STILL_BEATS:
			still_shots += tu.foes.filter(func(f): return f.inp.get("fire", false)).size()
		for h in [p, tu.guide] + tu.foes:
			if Vector2(h.pos.x - DuoTutorial.RING_C.x, h.pos.z - DuoTutorial.RING_C.y).length() > RING_R:
				outside += 1
	var ids: Array = tu.beats.map(func(b): return String(b["id"]))
	print("DUOTUT %s: %.1f s, reached %s, skipped %s, put back in the ring %d times" % [arch, t, str(reached),
		str(skipped), tu.cast.kept])
	ok(tu.finished, "%s: the run ends (%.0f s, beat %d %s)" % [arch, t, tu.beat, tu.id()])
	ok(reached == ids, arch + ": every beat in order")
	ok(skipped.is_empty(), "%s: no beat passed by the stall skip %s" % [arch, str(skipped)])
	ok(still_shots == 0, "%s: the rivals hold fire in the first beats (%d)" % [arch, still_shots])
	ok(outside == 0, "%s: nobody left the ring (%d steps outside)" % [arch, outside])
	ok(p.caught.size() == 1, arch + ": the wild Boki was caught")
	m.queue_free()
	await main.get_tree().process_frame

## Nobody at the keys: the guide nags after nag_s, and the first beat passes itself after skip_s.
func _idle(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(DuoTutorial.opts("gunslinger"))
	m.set_process(false)
	var tu: DuoTutorial = m.duo
	var nag := tu.fill(String(tu.cur()["nag"]))
	var nagged := false
	var t := 0.0
	while t < float(tu.cfg["skip_s"]) + DuoTutorial.GAP_T + 1.0:
		m.player.inp["move"] = Vector2.ZERO
		m.step(Match.DT)
		t += Match.DT
		nagged = nagged or tu.line == nag
	ok(nagged, "idle: the guide nags ('%s')" % nag)
	ok(tu.beat == 1, "idle: the first beat passed itself (beat %d)" % tu.beat)
	m.queue_free()
	await main.get_tree().process_frame
