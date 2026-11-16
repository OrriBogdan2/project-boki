extends RefCounted
## --hold-check: a hold keeps its pose while it's refreshed and lets go cleanly when it stops;
## every kind rides the snapshot flags (bits 11 and 15-18) and decodes back to itself.

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var bad := 0
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	for i in 5: await main.get_tree().process_frame
	var h: Hunter = m.player
	for k in Hunter.HOLD_KINDS:
		h.set_hold(String(k))
		var f: int = m._flags(h)
		var back := ((f >> 15) & 15) - 1
		if f & 2048 == 0 or back < 0 or String(Hunter.HOLD_KINDS[back]) != String(k):
			bad += 1; print("HOLDCHECK FAIL flags for %s: %d" % [k, f])
	# (the flags never reach the bits other state uses)
	h.hold_until = 0.0
	if m._flags(h) & (2048 | (15 << 15)) != 0: bad += 1; print("HOLDCHECK FAIL flags set with no hold")
	var t := 0.0
	var peak := 0.0
	while t < 0.8:
		h.set_hold("chest")
		m.step(Match.DT); t += Match.DT
		await main.get_tree().process_frame
		if h.anim: peak = maxf(peak, h.anim.act_k)
	var held_kind: String = h.anim.act_kind if h.anim else ""
	t = 0.0
	while t < 1.0:
		m.step(Match.DT); t += Match.DT
		await main.get_tree().process_frame
	var after: float = h.anim.act_k if h.anim else 0.0
	print("HOLDCHECK chest hold: pose %.2f while held (%s), %.2f a second after letting go, holding '%s'" % [peak, held_kind, after, h.holding()])
	if h.anim and (peak < 0.6 or held_kind != "chest" or after > 0.1): bad += 1; print("HOLDCHECK FAIL pose")
	if h.holding() != "": bad += 1; print("HOLDCHECK FAIL the hold didn't lapse")
	print("HOLDCHECK done, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
