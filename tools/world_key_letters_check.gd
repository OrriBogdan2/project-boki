extends RefCounted
## --world-key-letters-check: no key cap or key word on a world object during a match (the owner's rule:
## no keybind letters on the world, e.g. no E on Sable's dagger; a timer shows as a flash or a pulse). It starts
## the Training Grounds (every sign, pedestal label and the summon pad's card) and the practice island (the duel
## ring), walks onto the pads so every label is written, then fails on any Label3D in the match whose text holds
## a live key cap. The interact prompt in the HUD bar is a Control, so it stays. Prints WORLDKEYS PASS/FAIL.

const DT := 1.0 / 60.0

var main: Node
var fails := 0
var n := 0
var _caps: Array[String] = []


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("WORLDKEYS %-58s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	_build_caps()
	ok("the cap list is not empty", _caps.size() > 8, str(_caps.size()))
	var planted := Label3D.new()
	planted.text = "Chest\n%s to open" % Settings.key_cap("interact")
	ok("a planted 'E to open' label is caught", not hits(planted).is_empty())
	planted.text = "Chest\nopens with a key"
	ok("a plain label passes", hits(planted).is_empty())
	planted.free()
	await _grounds()
	await _practice_island()
	print("WORLDKEYS DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## The live key caps (digits left out: a damage number is not a key).
func _build_caps() -> void:
	for action in InputMap.get_actions():
		var cap := Settings.key_cap(String(action))
		if cap != "" and not cap.is_valid_int() and not _caps.has(cap):
			_caps.append(cap)


## The key caps `lbl` prints as a whole word (empty when it is clean).
func hits(lbl: Label3D) -> Array:
	var out := []
	for cap in _caps:
		var at := lbl.text.find(cap)
		while at >= 0:
			var end := at + cap.length()
			var before := lbl.text.substr(at - 1, 1) if at > 0 else ""
			var after := lbl.text.substr(end, 1)
			if not _is_word(before) and not _is_word(after):
				out.append(cap)
				break
			at = lbl.text.find(cap, end)
	return out


func _is_word(c: String) -> bool:
	return c != "" and (c.to_upper() != c.to_lower() or c.is_valid_int())


## Every Label3D under `root`, shown or hidden, that prints a key cap, as "text -> caps".
func offenders(root: Node) -> Array:
	var out := []
	for node in root.find_children("*", "Label3D", true, false):
		var lbl := node as Label3D
		var found := hits(lbl)
		if not found.is_empty():
			out.append("%s -> %s" % [lbl.text.replace("\n", " / "), ", ".join(found)])
	return out


func _grounds() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	var arena: Arena = m.arena
	arena.cd_off = true
	var hunter: Hunter = m.player
	var spots: Array[Vector3] = [arena.grounds.summon_pad.pad]
	for s in arena.grounds.stations:
		spots.append(s["at"])
	for at in spots:  # a label is written (or shown) once someone stands by it
		hunter.teleport(at)
		hunter.vel = Vector3.ZERO
		m.step(DT)
	ok("the grounds have signs to read", m.find_children("*", "Label3D", true, false).size() > 10)
	var bad := offenders(m)
	ok("the grounds' world labels carry no key cap", bad.is_empty(), str(bad))
	arena.teardown()
	m.queue_free()
	await main.get_tree().process_frame


func _practice_island() -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	ok("the practice island has its duel ring label", m.duel_pad != Vector3.INF)
	var bad := offenders(m)
	ok("the practice island's world labels carry no key cap", bad.is_empty(), str(bad))
	m.queue_free()
	await main.get_tree().process_frame
