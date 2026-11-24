extends "res://tools/archetype_check.gd"
## --owner-kit-rules-check: the owner's kit rules in briefs/DECISIONS.md (ext/agent-briefs) that no single kit
## check guards, each driven through the hunter's scripted input (Hunter.inp, X through HunterKeys) in the
## archetype check's flat strip. Every row names the DECISIONS line it guards (line numbers as of Nov 11).
## Prints "OKRCHECK <row> PASS|FAIL" and "OKRCHECK DONE, failures: N".

const WARDEN_MODEL_CHECK := preload("res://tools/warden_model_check.gd")
const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
const SIZE_COL := 0.3          # m: the head column _sizes measures the over-head height in
const LOCK_S := [0.85, 1.25]      # s: Motley's Nightwell cast lock, "about 1 s"
const GLIDE_S := 2.0              # s Space is held from the jump

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("OKRCHECK %-78s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

## Steps `secs` with `each` (Callable(i) -> void) setting the keys each frame, after the one-frame keys clear.
## Mobs are cleared each step, as in step(): a spawn beside the hunter would stop a dash or eat a shot.
func drive(m: Match, hu: Hunter, secs: float, each: Callable) -> void:
	for i in int(secs / DT):
		for k in ["fire", "sec", "dash", "jump", "sig", "util1", "gear1", "kin_ab"]:
			hu.inp[k] = false
		each.call(i)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)

## DECISIONS:83 "during her ult (Flue Flight) only E works. No LMB, no RMB (Cinder Shot), no other weapon or
## utility; E (Furnace Cloak) stays usable."
func _cinder() -> void:
	var r := setup("ashwick", 16.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var kt: AshwickKit = hu.ak
	var at: Vector3 = r[4] + Vector3(16, 0, 0)
	UtilityBelt.set_slot(hu, 0, "tonic", 3)
	hu.gear[0] = {"id": "blink", "rar": 1}
	hu.gear_cd = [0.0, 0.0]
	kt.cd["x"] = 0.0
	kt.cd["e"] = 0.0
	aim_at(hu, at)
	HunterKeys.ult_pressed(hu)
	drive(m, hu, 0.3, func(_i): aim_at(hu, at))
	var jt := kt.jet
	var puffs := kt.hose.emitted
	var charges := kt.ch_rmb
	var dashes := hu.dashes
	var shots := m.shots.size()
	for key in ["fire", "sec", "dash", "util1", "gear1", "kin_ab"]:
		drive(m, hu, 0.15, func(i):
			aim_at(hu, at)
			hu.inp[key] = key == "fire" or i == 0
			hu.inp["sec_hold"] = key == "sec")
	hu.inp["sec_hold"] = false
	ok("Cinder Flue Flight (DECISIONS:83): LMB, RMB, Shift, utility, glove and C are refused",
		jt.running() and kt.hose.emitted == puffs and kt.ch_rmb == charges and m.shots.size() == shots
		and hu.dashes == dashes and hu.ex_cd == 0.0 and int(hu.belt[0]["n"]) == 3 and float(hu.gear_cd[0]) == 0.0,
		"flying %s puffs +%d rmb %.1f->%.1f shots +%d dashes %.1f->%.1f tonic %s glove cd %.1f" % [jt.running(),
		kt.hose.emitted - puffs, charges, kt.ch_rmb, m.shots.size() - shots, dashes, hu.dashes, hu.belt[0]["n"],
		float(hu.gear_cd[0])])
	var cloaks := kt.cloaks
	drive(m, hu, 0.1, func(i): hu.inp["sig"] = i == 0)
	ok("Cinder Flue Flight (DECISIONS:83): E (Furnace Cloak) still works, the flight goes on",
		kt.cloaks == cloaks + 1 and jt.running(), "cloaks +%d" % (kt.cloaks - cloaks))
	await done(m)

## DECISIONS:78 "Ostra ult: about a 1 s cast lock (like the source), then he moves freely while Nightwell runs."
func _motley() -> void:
	var r := setup("ostra", 7.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var kt: OstraKit = hu.ak
	var home: Vector3 = r[4]
	kt.cd["x"] = 0.0
	aim_at(hu, home + Vector3(6, 0, 0))
	HunterKeys.ult_pressed(hu)
	var freed := -1.0
	var t := 0.0
	while t < 2.0 and freed < 0.0:
		drive(m, hu, DT, func(_i): hu.inp["move"] = Vector2(-1, 0))
		t += DT
		if Vector2(hu.pos.x - home.x, hu.pos.z - home.z).length() > 0.1:
			freed = t
	var from := hu.pos
	drive(m, hu, 0.5, func(_i): hu.inp["move"] = Vector2(-1, 0))
	var speed := Vector2(hu.pos.x - from.x, hu.pos.z - from.z).length() / 0.5
	hu.inp["move"] = Vector2.ZERO
	ok("Motley Nightwell (DECISIONS:78): about 1 s of cast lock, then he walks out",
		freed >= LOCK_S[0] and freed <= LOCK_S[1], "first step at %.2fs" % freed)
	ok("Motley Nightwell (DECISIONS:78): free at >= 90% run speed while the well runs",
		speed >= 0.9 * hu.base_speed and kt.well.running(), "%.2f of %.2f m/s" % [speed, hu.base_speed])
	await done(m)

## Starts `hu` gliding high over the strip with a player's keys (a fresh Space press in the air).
func _glide_up(m: Match, hu: Hunter, home: Vector3) -> void:
	hu.teleport(home + Vector3(0, 12.0, 0))
	hu.vel = Vector3.ZERO
	hu.grounded = false
	m.step(DT)
	m.step(DT)
	hu.coyote = 0.0           # the ground's grace would make the press a jump (and Space held from a jump never glides)
	hu.inp["glide_press_only"] = true
	drive(m, hu, 0.3, func(i):
		hu.inp["glide"] = true
		hu.inp["jump"] = i == 0)

## DECISIONS:74 "Tarek can use RMB/slam out of a glide, as the source does. The glider never blocks it."
func _tenzo() -> void:
	var r := setup("dolm", 8.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var kt: DolmKit = hu.ak
	_glide_up(m, hu, r[4])
	var was := hu.gliding
	var slams := kt.slams
	drive(m, hu, DT, func(_i): hu.inp["sec"] = true)
	var folded := not hu.gliding and kt.dive
	var t := 0.0
	while not hu.grounded and t < 4.0:
		drive(m, hu, DT, func(_i): pass)       # Space stays held: the glider must not take the slam back
		t += DT
	drive(m, hu, 0.3, func(_i): pass)
	hu.inp["glide"] = false
	ok("Tenzo (DECISIONS:74): RMB out of a glide folds it and slams on landing",
		was and folded and kt.slams == slams + 1, "gliding %s folded %s slams +%d" % [was, folded, kt.slams - slams])
	await done(m)

## DECISIONS:70 "Kael: RMB held indefinitely, with a perfect release". Returns how far the Lunge carried him.
func _kael_lunge(m: Match, hu: Hunter, home: Vector3, perfect: bool) -> float:
	var kt: JuggernautKit = hu.ak
	hu.teleport(home)
	kt.cd["rmb"] = 0.0
	kt.ch_rmb = float(kt.rmb_charges())
	hu.inp["sec_hold"] = true
	drive(m, hu, 1.2, func(i): hu.inp["sec"] = i == 0)
	while (kt.perfect_window(kt.rmb_t) >= 0) != perfect:
		drive(m, hu, DT, func(_i): pass)
	var from := hu.pos
	hu.inp["sec_hold"] = false
	drive(m, hu, 0.8, func(_i): pass)
	return Vector2(hu.pos.x - from.x, hu.pos.z - from.z).length()

func _kael() -> void:
	var r := setup("juggernaut", 30.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var kt: JuggernautKit = hu.ak
	var home: Vector3 = r[4]
	hu.inp["sec_hold"] = true
	drive(m, hu, 12.0, func(i): hu.inp["sec"] = i == 0)
	ok("Kael (DECISIONS:70): RMB held 12 s is still charging (no auto-release)",
		kt.rmb_down and kt.anim_id == "jug_lunge_wind", "held %.1fs anim %s" % [kt.rmb_t, kt.anim_id])
	hu.inp["sec_hold"] = false
	drive(m, hu, 1.0, func(_i): pass)
	var perfects := kt.perfects
	var hit := _kael_lunge(m, hu, home, true)
	var got := kt.perfects - perfects
	var plain := _kael_lunge(m, hu, home, false)
	ok("Kael (DECISIONS:70): a release in the window is a perfect Lunge (further), one outside is not",
		got == 1 and kt.perfects == perfects + 1 and hit > plain * 1.1,
		"perfects +%d, %.2fm vs %.2fm" % [kt.perfects - perfects, hit, plain])
	await done(m)

## DECISIONS:317 "Neve: darts semi-home while skating too" (and :77, they "home in toward the end of their flight").
func _neve() -> void:
	var r := setup("rimewright", 8.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var foe_h: Hunter = r[2]
	var kt: RimewrightKit = hu.ak
	var home: Vector3 = r[4]
	var cursor := home + Vector3(8, 0, 0)
	T.teleport(home + Vector3(8, 0, 1.8))      # off the aim line, inside the cursor's reach (wpn.cursor_r)
	var seen := {"dart": {}, "v0": Vector2.ZERO, "skating": false}      # (a lambda can't assign the caller's locals)
	drive(m, hu, 0.6, func(i):
		hu.inp["move"] = Vector2(0, -1)
		hu.inp["dash"] = i == 0
		hu.inp["dash_down"] = true
		hu.inp["fire"] = i > 2
		aim_at(hu, cursor)
		if seen["dart"].is_empty() and not kt.darts.is_empty():
			seen["dart"] = kt.darts[0]["s"]
			seen["v0"] = seen["dart"]["vel"]
			seen["skating"] = kt.in_dash()
		)
	var dart: Dictionary = seen["dart"]
	var v0: Vector2 = seen["v0"]
	var skating: bool = seen["skating"]
	for k in ["move", "dash_down", "fire"]:
		hu.inp[k] = Vector2.ZERO if k == "move" else false
	var out_ok := not dart.is_empty() and absf(rad_to_deg(v0.angle_to(Vector2(1, 0)))) < 25.0
	var turn := 0.0 if dart.is_empty() else rad_to_deg(v0.angle_to(dart["vel"]))
	ok("Neve (DECISIONS:317): a skating beam flies out on the aim, then curves in onto the foe",
		skating and kt.stats["beams"] > 0 and out_ok and turn > 5.0,
		"skating %s beams %d out %.0f deg, turned %.1f deg toward the foe" % [skating, kt.stats["beams"],
		rad_to_deg(v0.angle_to(Vector2(1, 0))), turn])
	await done(m)

## DECISIONS:80 Vex's "RMB is a side toss", as owner item 112 set it (docs/heroes/gunslinger.md RMB rows): a tap
## from the cannon's launcher, no hold, no lane. The row guards the tap on the press with nothing held.
func _vex() -> void:
	var r := setup("gunslinger", 12.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var kt: GunslingerKit = hu.ak
	var charges := kt.ch_rmb
	var seen := {"lane": false, "held": false}
	hu.inp["sec_hold"] = true
	drive(m, hu, DT, func(_i): hu.inp["sec"] = true)
	var on_press := kt.burrs.size() == 1 and kt.ch_rmb == charges - 1.0
	drive(m, hu, 1.0, func(_i):
		seen["lane"] = seen["lane"] or AimKit.shown(hu, "rmb")
		seen["held"] = seen["held"] or kt.rmb_down)
	var lane: bool = seen["lane"]
	var held: bool = seen["held"]
	hu.inp["sec_hold"] = false
	ok("Vex (DECISIONS:80): RMB goes on the press, holding it shows no lane and holds nothing",
		on_press and not lane and not held, "on press %s lane %s held %s" % [on_press, lane, held])
	await done(m)

## DECISIONS:82 "Deep Reach ... goes through walls and cliffs (placed walls still stop it)".
func _grimble(placed: bool) -> void:
	var r := setup("dredge", 8.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var foe_h: Hunter = r[2]
	var kt: DredgeKit = hu.ak
	var home: Vector3 = r[4]
	var wld = m.world
	if placed:
		m.verbs.add_wall(foe_h, home + Vector3(4, 0, 0), Vector2(-1, 0), {"length": 8.0, "hp": 999.0, "time": 30.0,
			"block": "all"}, 1.0)
	else:
		for dz in range(-6, 7):
			wld.level[wld.idx(int(floor(home.x)) + 4, int(floor(home.z)) + dz)] = int(r[5]) + 4
	var grapples := kt.grapples
	drive(m, hu, DT, func(_i): hu.inp["sec"] = true)
	var t := 0.0
	while kt.flying and t < 1.5:
		drive(m, hu, DT, func(_i): pass)
		t += DT
	drive(m, hu, 0.1, func(_i): pass)
	if placed:
		ok("Grimble (DECISIONS:82): a placed wall stops the Deep Reach", kt.grapples == grapples and kt.pull.is_empty(),
			"grapples +%d" % (kt.grapples - grapples))
	else:
		ok("Grimble (DECISIONS:82): the Deep Reach passes a cliff face and hooks the foe behind it",
			kt.grapples == grapples + 1, "grapples +%d" % (kt.grapples - grapples))
	await done(m)

## DECISIONS:370-371 "holding Space NEVER opens the glider ... Holding Space from the jump ... must never glide".
## A fresh press in the air still opens it (the control).
func _glide(arch: String) -> void:
	var r := setup(arch, 20.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	hu.inp["glide_press_only"] = true
	var t := {"held": 0.0, "fresh": 0.0}      # s the glider was open in each scenario
	drive(m, hu, GLIDE_S, func(i):
		hu.inp["glide"] = true
		hu.inp["jump"] = i == 0
		t["held"] += DT if hu.gliding else 0.0)
	hu.inp["glide"] = false
	drive(m, hu, 1.0, func(_i): pass)
	drive(m, hu, GLIDE_S, func(i):
		hu.inp["glide"] = i == 0 or i >= 12
		hu.inp["jump"] = i == 0 or i == 12
		t["fresh"] += DT if hu.gliding else 0.0)
	hu.inp["glide"] = false
	ok("%s (DECISIONS:370): Space held from the jump never glides; a second press does" % arch,
		t["held"] == 0.0 and t["fresh"] > 0.3, "held %.2fs, second press %.2fs" % [t["held"], t["fresh"]])
	await done(m)

## DECISIONS 2026-11-11, the owner's combat/UI call, "Kael LMB has no knockback". Both LMB hits (the quick slash and the
## Searing Wave) must damage the dummy and leave it where it stood with no knock in flight (knock distance 0).
func _fire_at(hu: Hunter, at: Vector3) -> void:
	hu.inp["fire"] = true
	aim_at(hu, at)

## Presses RMB on step 0 only (a tap), aimed at `at`.
func _tap_at(hu: Hunter, i: int, at: Vector3) -> void:
	hu.inp["sec"] = i == 0
	aim_at(hu, at)

func _kael_lmb_noknock() -> void:
	var r := setup("juggernaut", 2.0)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var foe_h: Hunter = r[2]
	var home: Vector3 = r[4]
	var kt: JuggernautKit = hu.ak
	var hp0 := foe_h.hp
	var at := foe_h.pos
	var worst_knock := 0.0
	drive(m, hu, 0.1, func(_i): _fire_at(hu, foe_h.pos))
	for i in int(0.8 / DT):
		hu.inp["fire"] = false
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		worst_knock = maxf(worst_knock, foe_h.knock_t)
	var slide := Vector2(foe_h.pos.x - at.x, foe_h.pos.z - at.z).length()
	ok("Kael LMB (11-11): the quick slash hurts the target and knocks it back 0 m",
		foe_h.hp < hp0 and slide < 0.01 and worst_knock == 0.0, "dmg %.1f, moved %.3fm, knock_t %.2f"
			% [hp0 - foe_h.hp, slide, worst_knock])
	# the Searing Wave: held to full, let go, through a target 5 m out
	hu.teleport(home)
	hu.vel = Vector3.ZERO
	foe_h.teleport(home + Vector3(5.0, 0, 0))
	kt.cd["lmb"] = 0.0
	hu.fire_cd = 0.0
	drive(m, hu, 0.1, func(_i): pass)
	hp0 = foe_h.hp
	at = foe_h.pos
	drive(m, hu, 1.2, func(_i): _fire_at(hu, foe_h.pos))
	worst_knock = 0.0
	for i in int(1.0 / DT):
		hu.inp["fire"] = false
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		worst_knock = maxf(worst_knock, foe_h.knock_t)
	slide = Vector2(foe_h.pos.x - at.x, foe_h.pos.z - at.z).length()
	ok("Kael LMB (11-11): the Searing Wave hurts the target and knocks it back 0 m",
		foe_h.hp < hp0 and slide < 0.01 and worst_knock == 0.0, "dmg %.1f, moved %.3fm, knock_t %.2f"
			% [hp0 - foe_h.hp, slide, worst_knock])
	await done(m)

## Fires Kael's RMB tap (the Finishing Slam) at a dummy on the axis, with a second dummy `lat` m to the side at the
## same range; returns [hurt on axis, hurt at the side].
func _slam_at(lat: float, range_m: float) -> Array:
	var r := setup("juggernaut", range_m, "", true)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var foe_h: Hunter = r[2]
	var foe_h2: Hunter = r[3]
	var home: Vector3 = r[4]
	foe_h2.teleport(home + Vector3(range_m, 0, lat))
	var kt: JuggernautKit = hu.ak
	kt.cd["rmb"] = 0.0
	kt.ch_rmb = float(kt.rmb_charges())
	for i in 5:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
	var h1 := foe_h.hp
	var h2 := foe_h2.hp
	hu.inp["sec_hold"] = false
	drive(m, hu, 1.2, func(i): _tap_at(hu, i, home + Vector3(range_m, 0, 0)))
	var out := [h1 - foe_h.hp, h2 - foe_h2.hp]
	await done(m)
	return out

## DECISIONS 2026-11-11, owner combat/UI: "Kael RMB is a straight-line thrust ... not a cone". The tap's hit shape is
## the lane of the data's rmb.slam.width and rmb.slam.len, not a wedge. A dummy at the lane's rim is hit, one just
## past the rim (inside any cone's spread at that range) is not; the hold's Lunge runs straight ahead into the foe on
## its line and leaves one off to the side alone.
func _kael_rmb_lane() -> void:
	var sl: Dictionary = Arch.def("juggernaut")["rmb"]["slam"]
	var w := float(sl["width"])
	var len_m := float(sl["len"])
	var fr := 0.5          # the dummy's body radius is read from the hunter below; this is only the first guess
	var probe := setup("juggernaut", 3.0)
	fr = (probe[2] as Hunter).r
	await done(probe[0])
	var range_m := minf(3.0, len_m - 0.5)
	var a: Array = await _slam_at(w * 0.5 + fr - 0.15, range_m)
	ok("Kael RMB (11-11): the Slam hits a foe inside the lane's rim (data width %.2f m)" % w,
		a[0] > 0.0 and a[1] > 0.0, "axis %.1f, rim %.1f" % [a[0], a[1]])
	var b: Array = await _slam_at(w * 0.5 + fr + 0.35, range_m)
	ok("Kael RMB (11-11): the Slam misses a foe just past the rim (a lane, not a cone)",
		b[0] > 0.0 and b[1] == 0.0, "axis %.1f, beside %.1f at %.2f m out" % [b[0], b[1], w * 0.5 + fr + 0.35])
	var c: Array = await _slam_at(0.0, len_m + fr + 0.5)
	ok("Kael RMB (11-11): the Slam stops at the data length (%.1f m)" % len_m, c[0] == 0.0, "past the end %.1f" % c[0])
	# the Lunge: a straight thrust along the aim into the first foe, one off to the side untouched
	var r := setup("juggernaut", 5.0, "", true)
	var m: Match = r[0]
	var hu: Hunter = r[1]
	var foe_h: Hunter = r[2]
	var foe_h2: Hunter = r[3]
	var home: Vector3 = r[4]
	foe_h2.teleport(home + Vector3(2.5, 0, 3.0))
	var kt: JuggernautKit = hu.ak
	kt.cd["rmb"] = 0.0
	kt.ch_rmb = float(kt.rmb_charges())
	var h1 := foe_h.hp
	var h2 := foe_h2.hp
	hu.inp["sec_hold"] = true
	drive(m, hu, 0.5, func(i): _tap_at(hu, i, foe_h.pos))
	hu.inp["sec_hold"] = false
	var drift := 0.0
	for i in int(1.0 / DT):
		for k in ["fire", "sec", "dash", "jump"]: hu.inp[k] = false
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		drift = maxf(drift, absf(hu.pos.z - home.z))
	ok("Kael RMB (11-11): the hold's Lunge thrusts straight into the foe on its line, not the one beside it",
		foe_h.hp < h1 and foe_h2.hp == h2 and drift < 0.2, "hit %.1f, side foe %.1f, sideways drift %.2f m"
			% [h1 - foe_h.hp, h2 - foe_h2.hp, drift])
	await done(m)

## DECISIONS 2026-11-11, owner combat/UI: "Albert is the biggest Hunter by only ~10-15%, Kael smaller too": the
## drawn height of every Hunter's current .glb (the model WardenGlb loads, vertices through the bones, as
## --warden-model-check measures). Two heights: `top` the whole silhouette, `col` the highest vertex over the head
## (within SIZE_COL m of the head pivot), which leaves out what stands off to the side (Albert's owner-approved
## masts and sails, 11-12). Albert is the tallest on both; over the next Hunter by 5 to 16% on `col`; Kael below him.
func _sizes() -> void:
	var was_contract := WardenNative.contract_only
	WardenNative.contract_only = true  # (as --warden-model-check: the contract path, which has Warden/Sync)
	var wm = WARDEN_MODEL_CHECK.new()
	var holder := Node3D.new()
	main.add_child(holder)
	wm.holder = holder
	var top := {}
	var col := {}
	for arch in Arch.ORDER:
		if not WardenGlb.uses_model(arch): continue
		var g: Node3D = wm._model(arch, PlayerLook.neutral(), true)
		top[arch] = wm._glb_top(g)
		var hp := g.get_node("Rig/Torso/HeadPivot") as Node3D
		var hi := -INF
		for nd in g.get_node("Warden").find_children("*", "MeshInstance3D", true, false):
			var mi := nd as MeshInstance3D
			if mi.skin == null: continue
			for q in WARDEN_SKIN.points(mi):
				if Vector2(q.x - hp.global_position.x, q.z - hp.global_position.z).length() < SIZE_COL:
					hi = maxf(hi, q.y)
		col[arch] = hi - g.global_position.y
		g.free()
	var rank: Array = col.keys()
	rank.sort_custom(func(a, b): return col[a] > col[b])
	var line := ""
	for a in rank: line += "%s %.2f/%.2f  " % [a, col[a], top[a]]
	var ratio := float(col[rank[0]]) / float(col[rank[1]])
	var all_top := float(top["bulwark"]) / float(top["dredge"])
	var label := "Albert (11-11): tallest Hunter, %.0f%% over the next (%s; whole silhouette %.0f%%)"
	ok(label % [(ratio - 1.0) * 100.0, rank[1], (all_top - 1.0) * 100.0],
		String(rank[0]) == "bulwark" and ratio >= 1.05 and ratio <= 1.16 and top["bulwark"] > top["dredge"],
		"m over-head/whole: " + line)
	var kr := float(col["juggernaut"]) / float(col["bulwark"])
	ok("Kael (11-11): smaller than Albert (%.0f%% of his height) and under his 11-11 1.93 m" % (kr * 100.0),
		kr <= 0.85 and col["juggernaut"] <= 1.93, "Kael %.2f m, Albert %.2f m" % [col["juggernaut"], col["bulwark"]])
	holder.queue_free()
	WardenNative.contract_only = was_contract
	await main.get_tree().process_frame

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	await _cinder()
	await _motley()
	await _tenzo()
	await _kael()
	await _kael_lmb_noknock()
	await _kael_rmb_lane()
	await _sizes()
	await _neve()
	await _vex()
	await _grimble(false)
	await _grimble(true)
	for arch in Arch.ORDER:
		await _glide(arch)
	print("OKRCHECK DONE, failures: ", fails)
	main.get_tree().quit(1 if fails > 0 else 0)
