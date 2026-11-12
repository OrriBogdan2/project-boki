extends "res://tools/archetype_check.gd"
## --owner-kit-rules-check: the owner's kit rules in briefs/DECISIONS.md (ext/agent-briefs) that no single kit
## check guards, each driven through the hunter's scripted input (Hunter.inp, X through HunterKeys) in the
## archetype check's flat strip. Every row names the DECISIONS line it guards (line numbers as of Nov 11).
## Prints "OKRCHECK <row> PASS|FAIL" and "OKRCHECK DONE, failures: N".

const LOCK_S := [0.85, 1.25]      # s: Motley's Nightwell cast lock, "about 1 s"
const GLIDE_S := 2.0              # s Space is held from the jump

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("OKRCHECK %-78s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## Steps `secs` with `each` (Callable(i) -> void) setting the keys each frame, after the one-frame keys clear.
## Mobs are cleared each step, as in step(): a spawn beside the hunter would stop a dash or eat a shot.
func drive(m: Match, P: Hunter, secs: float, each: Callable) -> void:
	for i in int(secs / DT):
		for k in ["fire", "sec", "dash", "jump", "sig", "util1", "gear1", "kin_ab"]:
			P.inp[k] = false
		each.call(i)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)

## DECISIONS:83 "during her ult (Flue Flight) only E works. No LMB, no RMB (Cinder Shot), no other weapon or
## utility; E (Furnace Cloak) stays usable."
func _cinder() -> void:
	var r := setup("ashwick", 16.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: AshwickKit = P.ak
	var at: Vector3 = r[4] + Vector3(16, 0, 0)
	UtilityBelt.set_slot(P, 0, "tonic", 3)
	P.gear[0] = {"id": "blink", "rar": 1}
	P.gear_cd = [0.0, 0.0]
	K.cd["x"] = 0.0
	K.cd["e"] = 0.0
	aim_at(P, at)
	HunterKeys.ult_pressed(P)
	drive(m, P, 0.3, func(_i): aim_at(P, at))
	var J := K.jet
	var puffs := K.hose.emitted
	var charges := K.ch_rmb
	var dashes := P.dashes
	var shots := m.shots.size()
	for key in ["fire", "sec", "dash", "util1", "gear1", "kin_ab"]:
		drive(m, P, 0.15, func(i):
			aim_at(P, at)
			P.inp[key] = key == "fire" or i == 0
			P.inp["sec_hold"] = key == "sec")
	P.inp["sec_hold"] = false
	ok("Cinder Flue Flight (DECISIONS:83): LMB, RMB, Shift, utility, glove and C are refused",
		J.running() and K.hose.emitted == puffs and K.ch_rmb == charges and m.shots.size() == shots
		and P.dashes == dashes and P.ex_cd == 0.0 and int(P.belt[0]["n"]) == 3 and float(P.gear_cd[0]) == 0.0,
		"flying %s puffs +%d rmb %.1f->%.1f shots +%d dashes %.1f->%.1f tonic %s glove cd %.1f" % [J.running(),
		K.hose.emitted - puffs, charges, K.ch_rmb, m.shots.size() - shots, dashes, P.dashes, P.belt[0]["n"],
		float(P.gear_cd[0])])
	var cloaks := K.cloaks
	drive(m, P, 0.1, func(i): P.inp["sig"] = i == 0)
	ok("Cinder Flue Flight (DECISIONS:83): E (Furnace Cloak) still works, the flight goes on",
		K.cloaks == cloaks + 1 and J.running(), "cloaks +%d" % (K.cloaks - cloaks))
	await done(m)

## DECISIONS:78 "Ostra ult: about a 1 s cast lock (like the source), then he moves freely while Nightwell runs."
func _motley() -> void:
	var r := setup("ostra", 7.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: OstraKit = P.ak
	var home: Vector3 = r[4]
	K.cd["x"] = 0.0
	aim_at(P, home + Vector3(6, 0, 0))
	HunterKeys.ult_pressed(P)
	var freed := -1.0
	var t := 0.0
	while t < 2.0 and freed < 0.0:
		drive(m, P, DT, func(_i): P.inp["move"] = Vector2(-1, 0))
		t += DT
		if Vector2(P.pos.x - home.x, P.pos.z - home.z).length() > 0.1:
			freed = t
	var from := P.pos
	drive(m, P, 0.5, func(_i): P.inp["move"] = Vector2(-1, 0))
	var speed := Vector2(P.pos.x - from.x, P.pos.z - from.z).length() / 0.5
	P.inp["move"] = Vector2.ZERO
	ok("Motley Nightwell (DECISIONS:78): about 1 s of cast lock, then he walks out",
		freed >= LOCK_S[0] and freed <= LOCK_S[1], "first step at %.2fs" % freed)
	ok("Motley Nightwell (DECISIONS:78): free at >= 90% run speed while the well runs",
		speed >= 0.9 * P.base_speed and K.well.running(), "%.2f of %.2f m/s" % [speed, P.base_speed])
	await done(m)

## Starts `P` gliding high over the strip with a player's keys (a fresh Space press in the air).
func _glide_up(m: Match, P: Hunter, home: Vector3) -> void:
	P.teleport(home + Vector3(0, 12.0, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	m.step(DT)
	m.step(DT)
	P.coyote = 0.0           # the ground's grace would make the press a jump (and Space held from a jump never glides)
	P.inp["glide_press_only"] = true
	drive(m, P, 0.3, func(i):
		P.inp["glide"] = true
		P.inp["jump"] = i == 0)

## DECISIONS:74 "Tarek can use RMB/slam out of a glide, as the source does. The glider never blocks it."
func _tenzo() -> void:
	var r := setup("dolm", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: DolmKit = P.ak
	_glide_up(m, P, r[4])
	var was := P.gliding
	var slams := K.slams
	drive(m, P, DT, func(_i): P.inp["sec"] = true)
	var folded := not P.gliding and K.dive
	var t := 0.0
	while not P.grounded and t < 4.0:
		drive(m, P, DT, func(_i): pass)       # Space stays held: the glider must not take the slam back
		t += DT
	drive(m, P, 0.3, func(_i): pass)
	P.inp["glide"] = false
	ok("Tenzo (DECISIONS:74): RMB out of a glide folds it and slams on landing",
		was and folded and K.slams == slams + 1, "gliding %s folded %s slams +%d" % [was, folded, K.slams - slams])
	await done(m)

## DECISIONS:70 "Kael: RMB held indefinitely, with a perfect release". Returns how far the Lunge carried him.
func _kael_lunge(m: Match, P: Hunter, home: Vector3, perfect: bool) -> float:
	var K: JuggernautKit = P.ak
	P.teleport(home)
	K.cd["rmb"] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	P.inp["sec_hold"] = true
	drive(m, P, 1.2, func(i): P.inp["sec"] = i == 0)
	while (K.perfect_window(K.rmb_t) >= 0) != perfect:
		drive(m, P, DT, func(_i): pass)
	var from := P.pos
	P.inp["sec_hold"] = false
	drive(m, P, 0.8, func(_i): pass)
	return Vector2(P.pos.x - from.x, P.pos.z - from.z).length()

func _kael() -> void:
	var r := setup("juggernaut", 30.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: JuggernautKit = P.ak
	var home: Vector3 = r[4]
	P.inp["sec_hold"] = true
	drive(m, P, 12.0, func(i): P.inp["sec"] = i == 0)
	ok("Kael (DECISIONS:70): RMB held 12 s is still charging (no auto-release)",
		K.rmb_down and K.anim_id == "jug_lunge_wind", "held %.1fs anim %s" % [K.rmb_t, K.anim_id])
	P.inp["sec_hold"] = false
	drive(m, P, 1.0, func(_i): pass)
	var perfects := K.perfects
	var hit := _kael_lunge(m, P, home, true)
	var got := K.perfects - perfects
	var plain := _kael_lunge(m, P, home, false)
	ok("Kael (DECISIONS:70): a release in the window is a perfect Lunge (further), one outside is not",
		got == 1 and K.perfects == perfects + 1 and hit > plain * 1.1,
		"perfects +%d, %.2fm vs %.2fm" % [K.perfects - perfects, hit, plain])
	await done(m)

## DECISIONS:317 "Neve: darts semi-home while skating too" (and :77, they "home in toward the end of their flight").
func _neve() -> void:
	var r := setup("rimewright", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: RimewrightKit = P.ak
	var home: Vector3 = r[4]
	var cursor := home + Vector3(8, 0, 0)
	T.teleport(home + Vector3(8, 0, 2.5))      # off the aim line, inside the cursor's reach (wpn.cursor_r)
	var seen := {"dart": {}, "v0": Vector2.ZERO, "skating": false}      # (a lambda can't assign the caller's locals)
	drive(m, P, 0.6, func(i):
		P.inp["move"] = Vector2(0, -1)
		P.inp["dash"] = i == 0
		P.inp["dash_down"] = true
		P.inp["fire"] = i > 2
		aim_at(P, cursor)
		if seen["dart"].is_empty() and not K.darts.is_empty():
			seen["dart"] = K.darts[0]["s"]
			seen["v0"] = seen["dart"]["vel"]
			seen["skating"] = K.in_dash()
		)
	var dart: Dictionary = seen["dart"]
	var v0: Vector2 = seen["v0"]
	var skating: bool = seen["skating"]
	for k in ["move", "dash_down", "fire"]:
		P.inp[k] = Vector2.ZERO if k == "move" else false
	var out_ok := not dart.is_empty() and absf(rad_to_deg(v0.angle_to(Vector2(1, 0)))) < 25.0
	var turn := 0.0 if dart.is_empty() else rad_to_deg(v0.angle_to(dart["vel"]))
	ok("Neve (DECISIONS:317): a skating beam flies out on the aim, then curves in onto the foe",
		skating and K.stats["beams"] > 0 and out_ok and turn > 5.0,
		"skating %s beams %d out %.0f deg, turned %.1f deg toward the foe" % [skating, K.stats["beams"],
		rad_to_deg(v0.angle_to(Vector2(1, 0))), turn])
	await done(m)

## DECISIONS:80 Vex's "RMB is a side toss", as owner item 112 set it (docs/heroes/gunslinger.md RMB rows): a tap
## from the cannon's launcher, no hold, no lane. The row guards the tap on the press with nothing held.
func _vex() -> void:
	var r := setup("gunslinger", 12.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var K: GunslingerKit = P.ak
	var charges := K.ch_rmb
	var seen := {"lane": false, "held": false}
	P.inp["sec_hold"] = true
	drive(m, P, DT, func(_i): P.inp["sec"] = true)
	var on_press := K.burrs.size() == 1 and K.ch_rmb == charges - 1.0
	drive(m, P, 1.0, func(_i):
		seen["lane"] = seen["lane"] or AimKit.shown(P, "rmb")
		seen["held"] = seen["held"] or K.rmb_down)
	var lane: bool = seen["lane"]
	var held: bool = seen["held"]
	P.inp["sec_hold"] = false
	ok("Vex (DECISIONS:80): RMB goes on the press, holding it shows no lane and holds nothing",
		on_press and not lane and not held, "on press %s lane %s held %s" % [on_press, lane, held])
	await done(m)

## DECISIONS:82 "Abyssal Hand ... goes through walls and cliffs (placed walls still stop it)".
func _grimble(placed: bool) -> void:
	var r := setup("dredge", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: DredgeKit = P.ak
	var home: Vector3 = r[4]
	var W = m.world
	if placed:
		m.verbs.add_wall(T, home + Vector3(4, 0, 0), Vector2(-1, 0), {"length": 8.0, "hp": 999.0, "time": 30.0,
			"block": "all"}, 1.0)
	else:
		for dz in range(-6, 7):
			W.level[W.idx(int(floor(home.x)) + 4, int(floor(home.z)) + dz)] = int(r[5]) + 4
	var grapples := K.grapples
	drive(m, P, DT, func(_i): P.inp["sec"] = true)
	var t := 0.0
	while K.flying and t < 1.5:
		drive(m, P, DT, func(_i): pass)
		t += DT
	drive(m, P, 0.1, func(_i): pass)
	if placed:
		ok("Grimble (DECISIONS:82): a placed wall stops the Abyssal Hand", K.grapples == grapples and K.pull.is_empty(),
			"grapples +%d" % (K.grapples - grapples))
	else:
		ok("Grimble (DECISIONS:82): the Abyssal Hand passes a cliff face and hooks the foe behind it",
			K.grapples == grapples + 1, "grapples +%d" % (K.grapples - grapples))
	await done(m)

## DECISIONS:370-371 "holding Space NEVER opens the glider ... Holding Space from the jump ... must never glide".
## A fresh press in the air still opens it (the control).
func _glide(arch: String) -> void:
	var r := setup(arch, 20.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	P.inp["glide_press_only"] = true
	var t := {"held": 0.0, "fresh": 0.0}      # s the glider was open in each scenario
	drive(m, P, GLIDE_S, func(i):
		P.inp["glide"] = true
		P.inp["jump"] = i == 0
		t["held"] += DT if P.gliding else 0.0)
	P.inp["glide"] = false
	drive(m, P, 1.0, func(_i): pass)
	drive(m, P, GLIDE_S, func(i):
		P.inp["glide"] = i == 0 or i >= 12
		P.inp["jump"] = i == 0 or i == 12
		t["fresh"] += DT if P.gliding else 0.0)
	P.inp["glide"] = false
	ok("%s (DECISIONS:370): Space held from the jump never glides; a second press does" % arch,
		t["held"] == 0.0 and t["fresh"] > 0.3, "held %.2fs, second press %.2fs" % [t["held"], t["fresh"]])
	await done(m)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	await _cinder()
	await _motley()
	await _tenzo()
	await _kael()
	await _neve()
	await _vex()
	await _grimble(false)
	await _grimble(true)
	for arch in Arch.ORDER:
		await _glide(arch)
	print("OKRCHECK DONE, failures: ", fails)
	main.get_tree().quit(1 if fails > 0 else 0)
