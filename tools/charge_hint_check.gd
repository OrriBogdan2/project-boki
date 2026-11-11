extends RefCounted
## --charge-hint-check: the uplink's "More teammates in the <outpost> fuel it faster!" tip shows once
## (one copy across the prompt, the status line and the tip), is gone by 5 s, and does not come back
## when you step out and in again soon after. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CHARGEHINT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## How many of the lines on screen for the uplink carry the tip.
func _copies(m: Match, P: Hunter) -> int:
	var n := 0
	var st: Dictionary = m.exits.status_for(P)
	for s in [String(m.exits.interact_for(P).get("label", "")), String(st.get("text", "")), String(st.get("hint", ""))]:
		if s.contains("fuel it faster") or s.contains("charge it faster"):
			n += 1
	return n

func _step(m: Match, secs: float, at: Vector3) -> void:
	var t := 0.0
	while t < secs:
		m.player.teleport(at)
		m.player.vel = Vector3.ZERO
		for mb in m.mobs:
			mb.dead = true
			mb.visible = false
		m.step(Match.DT)
		t += Match.DT

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.max_hp = 5000.0
		h.hp = 5000.0
	var P: Hunter = m.player
	var up: Dictionary = m.exits.of_kind("outpost")[0]
	var yard: Vector3 = up["pos"] + Vector3(0.9, 0, 0.9)
	m.time = float(up["open_at"]) + 1.0
	_step(m, 0.2, yard)
	m.exits._start(up, P)
	_step(m, 0.5, yard)
	var st: Dictionary = m.exits.status_for(P)
	ok(_copies(m, P) == 1, "one copy on screen while you charge it alone (got %d)" % _copies(m, P))
	var want := "More teammates in the %s fuel it faster!" % up["name"]
	ok(String(st.get("hint", "")) == want, "the tip names the zone: '%s'" % st.get("hint", ""))
	_step(m, 3.0, yard)
	ok(float(m.exits.status_for(P).get("hint_a", 0.0)) < 1.0 and _copies(m, P) == 1, "at 3.5 s it is fading out")
	_step(m, 1.6, yard)
	ok(_copies(m, P) == 0, "gone by 5 s (%d copies, charge %d%%)" % [_copies(m, P), int(up["prog"] * 100.0)])
	_step(m, 5.0, up["pos"] + Vector3(20, 0, 0))
	_step(m, 1.0, yard)
	ok(_copies(m, P) == 0, "stepping back in a few seconds later does not show it again")
	m.over = true
	m.queue_free()
	await main.get_tree().process_frame
	print("CHARGE HINT CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
