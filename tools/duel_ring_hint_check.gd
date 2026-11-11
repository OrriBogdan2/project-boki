extends RefCounted
## --duel-ring-hint-check: the duel ring hint shows on the first walk into the ring area only. Far from
## the pad: nothing. Inside the area: the hint line (pad key + the choices) and a beam over the pad, and
## the save remembers it. Standing on the pad ends the beam. A new match on the same save: no hint.

# the Training Grounds the farm Esc menu opens (Home._start_training): the one with the duel pad
const GROUNDS := {"training": true, "practice": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242}

var main: Node
var bad := 0

func ok(cond: bool, what: String, extra := "") -> void:
	print("DUELHINT %s %s %s" % ["ok  " if cond else "FAIL", what, extra])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d["tutorial"].erase(DuelRingHint.SAVE_KEY)
	var m := await _match()
	ok(m.duel_pad != Vector3.INF and m.duel_hint != null, "first match: a pad and a live hint")
	if m.duel_hint == null:
		main.get_tree().quit(1)
		return
	var pad := m.duel_pad
	var line := DuelRingHint.line()
	var named := line.contains(Settings.key_cap("interact")) and line.contains("Fight a bot")
	named = named and not line.contains("Arena")
	ok(named, "the line names the key and a choice", line)
	m.player.pos = pad + Vector3(DuelRingHint.NEAR_M + 6.0, 0, 0)
	m._update_training(0.1)
	var seen := func() -> bool: return Save.d["tutorial"].get(DuelRingHint.SAVE_KEY, false)
	ok(not seen.call() and m.duel_hint.beam == null, "far from the pad: nothing shown")
	m.player.pos = pad + Vector3(DuelRingHint.NEAR_M - 2.0, 0, 0)
	m._update_training(0.1)
	var beam: MeshInstance3D = m.duel_hint.beam
	ok(beam != null and seen.call(), "walking into the area: beam up, save flagged")
	var over := beam != null and absf(beam.position.x - pad.x) < 0.01 and beam.position.y > pad.y + 20.0
	ok(over, "the beam stands over the pad")
	m.player.pos = pad
	m._update_training(0.1)
	ok(m.duel_hint == null and beam.is_queued_for_deletion(), "on the pad: the beam ends")
	m.queue_free()
	await main.get_tree().process_frame
	var again := await _match()
	ok(again.duel_hint == null, "same save, new match: no hint")
	again.queue_free()
	print("DUELHINT %s" % ("PASS" if bad == 0 else "FAIL"))
	main.get_tree().quit(1 if bad > 0 else 0)

func _match() -> Match:
	var m := Match.new()
	main.add_child(m)
	await m.start(GROUNDS)
	m.set_process(false)
	return m
