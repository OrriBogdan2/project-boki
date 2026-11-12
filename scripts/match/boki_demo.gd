class_name BokiDemo
extends RefCounted
## Screenshot tooling: --boki-demo=<what>[:species] sets up a training match (the Archetype demo's two
## dummies ahead, a Boki on your shoulder) and, on the match clock, plays one part of the Boki system.
## Take the shots with --match --boki-demo=... --shot=path.png --shot-times=a,b (match seconds; the scene is set up at 1.0):
##   throw   G tap to the dummy at 1.5s (in the air ~1.7s, landed and staggered ~2.2s)
##   recall  the Boki out beside the far dummy, G tap at 2.0s (mid-leap ~2.15s)
##   downed  the Boki goes down at 1.5s (marker ~2.2s), you run into it at 2.6s (scoop bar ~2.8s)
##   merge   R at 1.5s with a full bond meter (the activation ~1.6s, the form ~3.5s); merge:<species>

static func frame(m: Match) -> void:
	var spec := String(m.opts.get("boki_demo", "")).split(":")
	var what := spec[0]
	var P: Hunter = m.player
	if P == null or P.out or m.time < 1.0:
		return
	if not m.has_meta("bdemo"):
		m.set_meta("bdemo", true)
		print("BOKIDEMO setup at t=%.2f" % m.time)
		ArchDemo._setup(m, P, "rmb")
		P.ult = 0.4
		var k0: Kin = P.kin
		k0.trust = 70.0
		for t in ["bravery", "loyalty"]:
			k0.traits[t] = 0.9
		return
	var k: Kin = P.kin
	var foes: Array = m.get_meta("demo_foes", [])
	if foes.is_empty() or k == null:
		return
	var T: Hunter = foes[0]
	for f in foes:
		f.hp = f.max_hp
	P.hp = P.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0); P.inp["aim_y"] = T.pos.y
	P.inp["fire"] = false
	var t := m.time
	var step := String(m.get_meta("bdemo_step", ""))
	if step != String(m.get_meta("bdemo_seen", "")):
		m.set_meta("bdemo_seen", step)
		print("BOKIDEMO step %s at t=%.2f" % [step, m.time])
	match what:
		"throw":
			if t >= 1.5 and step == "":
				m.set_meta("bdemo_step", "tap")
				KinCommand.tap(P)
		"recall":
			if t >= 1.2 and step == "":
				m.set_meta("bdemo_step", "out")
				k.pos = (foes[1] as Hunter).pos + Vector3(-1.0, 0, -1.8); k.state = "active"; k.fly = {}; k.hold_at = Vector3.INF; k.settle = 1.0
			if t >= 2.0 and step == "out":
				m.set_meta("bdemo_step", "tap")
				k.pos = (foes[1] as Hunter).pos + Vector3(-0.5, 0, -1.2)
				KinCommand.tap(P)
		"downed":
			if t >= 1.5 and step == "":
				m.set_meta("bdemo_step", "down")
				k.pos = P.pos + (T.pos - P.pos).normalized() * 3.5 + Vector3(0, 0, 1.5); k.state = "active"; k.fly = {}
				k.go_down()
			if t >= 2.6 and step == "down":
				m.set_meta("bdemo_step", "run")
				P.teleport(k.pos + Vector3(0.4, 0, 0))
		"merge":
			if t >= 1.5 and step == "":
				m.set_meta("bdemo_step", "merge")
				k.state = "shoulder"; k.fly = {}; k.settle = 1.0; k.cmd = "return"     # on you: the instant merge (Follow would leap it back first)
				P.ult = 1.0
				KinMerge.press(P)
			if step == "merge":
				P.ult = 0.0
