extends RefCounted
## --ult-glow-check: the ready-ultimate glow (UltGlow). A Hunter below the ult level, or with it on cooldown, has
## none; a ready one eases to the quiet level in their archetype colour; a cast flashes to 1 and fades; a downed one
## doesn't glow; the ready state rides the snapshot flags so another client shows (and flashes) it too.
## Never touches the save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("ULTGLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _glow(h: Hunter) -> float:
	var v = (h.mats[0] as ShaderMaterial).get_shader_parameter("ult_glow")
	return 0.0 if v == null else float(v)

func _frames(h: Hunter, secs: float) -> void:
	for i in int(secs * 60.0):
		UltGlow.tick(h, 1.0 / 60.0)

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true,
		"cls": Arch.weight("ashwick"), "arch": "ashwick", "weapon": Arch.signature("ashwick")})
	m.set_process(false)
	var h: Hunter = m.player
	h.set_arch("ashwick")
	ok(not h.mats.is_empty() and h.mats[0] is ShaderMaterial, "the body has shader materials")
	h.lvl = 5
	_frames(h, 1.0)
	ok(_glow(h) == 0.0 and not h.ult_ready, "below the ult level: no glow")
	h.lvl = 6
	h.ak.cd["x"] = 0.0
	_frames(h, 1.0)
	ok(absf(_glow(h) - UltGlow.READY_LEVEL) < 0.001 and h.ult_ready, "ready: the quiet level, %.2f" % _glow(h))
	var col: Color = (h.mats[0] as ShaderMaterial).get_shader_parameter("ult_color")
	ok(col.is_equal_approx(Arch.color("ashwick")), "in the Hunter's own colour")
	ok(m._flags(h) & UltGlow.READY_BIT != 0, "the snapshot flags carry it")
	h.downed = true
	_frames(h, 1.0)
	ok(_glow(h) == 0.0, "downed: no glow")
	h.downed = false
	_frames(h, 1.0)
	h.ak.cd["x"] = 30.0
	UltGlow.tick(h, 1.0 / 60.0)
	ok(_glow(h) > 0.9, "the cast flashes: %.2f" % _glow(h))
	_frames(h, 0.1)
	ok(_glow(h) > 0.3 and _glow(h) < 1.0, "the flash fades, not cut: %.2f" % _glow(h))
	_frames(h, 1.0)
	ok(_glow(h) == 0.0 and m._flags(h) & UltGlow.READY_BIT == 0, "on cooldown: no glow, no flag")
	# another client: the flag alone drives it
	h.remote = true
	h.ult_ready = true
	_frames(h, 1.0)
	ok(absf(_glow(h) - UltGlow.READY_LEVEL) < 0.001, "a remote Hunter with the flag glows")
	h.ult_ready = false
	UltGlow.tick(h, 1.0 / 60.0)
	ok(_glow(h) > 0.9, "and flashes when the flag drops")
	print("ULTGLOW DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
