extends "res://tools/archer_bulwark_combo_check.gd"
## --cc-measure-check: every crowd control effect of the 13 kits, measured (docs/KIT_PARITY.d/1122-cc-reread.md).
## Each row casts the kit's own ability on an idle dummy (a wall behind it when the effect needs one) and reads the
## peak the dummy's stun, root, slow (time and strength) and Grounded / Daze reach, then compares it with the
## number the table gives. One `CCM` line a row: the numbers are the table.

## A row: [arch, label, expected {stun, root, slow, slow_k, gnd, rat: seconds or strength}, cast method].
const WALLS := preload("res://tools/wall_stun_check.gd")  # its probes: each kit's own wall hit, a cliff behind
const WALL_NAMES := {
	"archer": ["Lace", "Heartpiercer into a wall", 1.2],
	"bulwark": ["Albert", "knock into a wall (Crush)", 1.0],
	"gunslinger": ["Vex", "Burr cone into a wall", 0.9],
	"dolm": ["Tenzo", "Quake Punch into a wall", 0.9],
	"mage": ["Sparkle", "Storm Rod into a wall", 0.8],
	"knock": ["any", "plain knock into a wall", 0.9],
}
var rows: Array = []
var peaks := {}


func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("cc_measure_check", self)
	await _walls()
	var kits: Array[Callable] = [
		_vex, _kael, _lace, _cinder, _meeko, _tenzo, _grimble, _neve, _motley, _albert, _sparkle, _sable, _gil
	]
	for kit in kits:
		await kit.call()
	print("CCM DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## Reads the dummy's CC every frame for `secs` and keeps the highest of each; `each` runs first every frame.
func _watch(m: Match, tg: Hunter, secs: float, each := Callable(), caster: Hunter = null) -> Dictionary:
	var pk := {"stun": 0.0, "root": 0.0, "slow": 0.0, "slow_k": 0.0, "gnd": 0.0, "rat": 0.0, "self_gnd": 0.0}
	var t := 0.0
	while t < secs:
		if each.is_valid():
			each.call()
		m.step(DT)
		Oomph.render_hit(tg, DT)  # the stagger clock (Hunter.render runs it, and a headless run draws nothing)
		t += DT
		pk["stun"] = maxf(pk["stun"], tg.stun_t)
		pk["root"] = maxf(pk["root"], tg.root_t)
		var stagger := is_equal_approx(tg.slow_k, Oomph.STAGGER_SLOW) and tg.slow_t <= Oomph.STAGGER_T + 0.02
		if not stagger and tg.slow_t > 0.0:  # (the hit stagger's own short slow is no rider)
			pk["slow"] = maxf(pk["slow"], tg.slow_t)
			pk["slow_k"] = maxf(pk["slow_k"], tg.slow_k)
		if caster != null:
			pk["self_gnd"] = maxf(pk["self_gnd"], KitStatus.grounded_left(caster))
		pk["gnd"] = maxf(pk["gnd"], KitStatus.grounded_left(tg))
		pk["rat"] = maxf(pk["rat"], KitStatus.rattled_left(tg))
	return pk


## Compares a measured peak with what the table says (tolerance: a frame and a half).
func _row(who: String, what: String, pk: Dictionary, want: Dictionary, landed := true) -> void:
	var line := ""
	var good := landed
	for key: String in pk:
		var got: float = pk[key]
		if got > 0.0:
			line += " %s %.2f" % [key, got]
		if want.has(key):
			var w = want[key]
			if w is Array:
				good = good and got >= float(w[0]) - 0.05 and got <= float(w[1]) + 0.05
			else:
				good = good and absf(got - float(w)) <= (0.05 if key != "slow_k" else 0.005)
		elif got > 0.02:
			good = false
	print("CCM %-9s %-44s%s" % [who, what, line])
	ok("cc %s: %s" % [who, what], good, "want %s" % str(want))


## A fresh strip, the dummy `d` m ahead, aim on it; returns [m, pl, tg, kt, home, lv].
func _kit(arch: String, d := 2.2, second := false) -> Array:
	var r := setup(arch, d, "", second)
	var pl: Hunter = r[1]
	var kt = pl.ak
	for s in ["sec", "dash", "util"]:
		if pl.slot_lv.has(s):
			pl.slot_lv[s] = maxi(1, int(pl.slot_lv[s]))
	return [r[0], pl, r[2], kt, r[4], r[5], r[3]]


func _reset(m: Match, pl: Hunter, tg: Hunter, home: Vector3, d: float) -> void:
	pl.teleport(home)
	pl.vel = Vector3.ZERO
	fresh(tg)
	KitStatus.clear_rattled(tg)
	tg.teleport(home + Vector3(d, 0, 0))
	for k in pl.ak.cd:
		pl.ak.cd[k] = 0.0
	pl.fire_cd = 0.0
	pl.dashes = pl.max_dashes()
	step(m, 0.3)
	fresh(tg)
	KitStatus.clear_rattled(tg)
	tg.teleport(home + Vector3(d, 0, 0))
	aim_at(pl, tg.pos)


## Each kit's wall hit into a cliff (the kit's own number), and a plain knock (the body slam every kit shares).
func _walls() -> void:
	var w = WALLS.new()
	w.main = main
	for src: String in ["archer", "bulwark", "gunslinger", "dolm", "mage", "knock"]:
		var r: Array = w.setup(src if src != "knock" else "thief", 3.0, "", true)
		var tg: Hunter = r[2]
		var spot := tg.pos
		tg.teleport(spot)
		var undo: Callable = w._build(r[0], tg, r[3], "cliff", spot, r[5])
		var rec: Dictionary = w._knock(src, r[0], r[1], tg)
		undo.call()
		var got := {"stun": rec["stun"]}
		var want := {"stun": WALL_NAMES[src][2]}
		if src == "gunslinger":  # the Daze it was left with, plus the frames the probe ran on
			got["rat"] = KitStatus.rattled_left(tg) + float(WALLS.FRAMES) * DT
			want["rat"] = 2.0
		_row(String(WALL_NAMES[src][0]), String(WALL_NAMES[src][1]), got, want)
		await done(r[0])


# ------------------------------------------------------------------ one kit a function
func _vex() -> void:
	var r := _kit("gunslinger")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 4.0)
	tap(m, pl)  # Burr Charge
	_row("Vex", "Burr Charge cone", _watch(m, tg, 2.5), {"rat": 1.4})
	_reset(m, pl, tg, home, 4.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Vex", "Cinderfall zone", _watch(m, tg, 3.0), {"slow": 0.6, "slow_k": 0.3})
	await done(m)


func _kael() -> void:
	var r := _kit("juggernaut")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	var kt: JuggernautKit = pl.ak
	var drop := func(dx: float) -> Dictionary:
		_reset(m, pl, tg, home, 6.0)
		kt.ch_rmb = 1.0
		pl.teleport(tg.pos + Vector3(dx, 3.0, 0))
		pl.grounded = false
		aim_at(pl, tg.pos + Vector3(6.0, 0, 0))
		m.step(DT)
		pl.ak.press_rmb()
		return _watch(m, tg, 2.0)
	_row("Kael", "Meteor Drop, core", drop.call(-1.0), {"stun": 0.8})
	_row("Kael", "Meteor Drop, ring edge", drop.call(-2.6), {"stun": 0.45})
	var hook := func() -> void:
		_reset(m, pl, tg, home, 6.0)
		kt.haul = {}
		kt.ch_rmb = 1.0
		pl.ak.use_e()
		step(m, 0.3)
	hook.call()
	hold(m, pl, 0.95)
	_row("Kael", "Chain Lunge (E, hold RMB)", _watch(m, tg, 1.0), {}, kt.chain_lunges == 1 and dmg(tg) > 0.0)
	step(m, 1.0)
	hook.call()
	pl.inp["sec_hold"] = true
	pl.ak.press_rmb()
	step(m, 0.5, func(): pl.inp["sec_hold"] = true)
	pl.ak.use_e()
	_row(
		"Kael",
		"Haul Slam (E, hold RMB, E)",
		_watch(m, tg, 1.5, func(): pl.inp["sec_hold"] = true),
		{},
		kt.haul_slams == 1 and dmg(tg) > 0.0
	)
	pl.inp["sec_hold"] = false
	_reset(m, pl, tg, home, 3.0)
	pl.inp["fire"] = true  # Searing Wave: LMB held, then let go
	step(m, 1.2, func(): pl.inp["fire"] = true)
	pl.inp["fire"] = false
	_row("Kael", "Fireblast wave", _watch(m, tg, 1.5), {}, kt.waves >= 1 and dmg(tg) > 0.0)
	await done(m)


func _lace() -> void:
	var r := _kit("archer")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 4.0)
	pl.ak.use_e()
	_row("Lace", "Rain of Arrows", _watch(m, tg, 3.0), {"slow": 0.8, "slow_k": 0.35})
	await done(m)


func _cinder() -> void:
	var r := _kit("ashwick")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 5.0)
	tap(m, pl)  # Cinder Shot
	_row("Cinder", "Cinder Shot", _watch(m, tg, 3.0), {"slow": 1.5, "slow_k": 0.3})
	_reset(m, pl, tg, home, 5.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Cinder", "Flue Flight carpet", _watch(m, tg, 4.0), {"slow": 0.5, "slow_k": 0.3})
	await done(m)


func _meeko() -> void:
	var r := _kit("tender")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 4.0)
	tap(m, pl)
	_row("Meeko", "Burrseed", _watch(m, tg, 5.0), {"root": 1.1})
	_reset(m, pl, tg, home, 4.0)
	pl.slot_lv["sec"] = 3
	tap(m, pl)
	_row("Meeko", "Burrseed, rank 3", _watch(m, tg, 5.0), {"root": 1.4})
	await done(m)


func _tenzo() -> void:
	var r := _kit("dolm")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 2.2)
	tap(m, pl)
	_row("Tenzo", "Volcano slam centre, tap", _watch(m, tg, 2.0), {"stun": 0.5})
	_reset(m, pl, tg, home, 2.2)
	hold(m, pl, 0.7)  # the charge is full at 0.45 s
	_row("Tenzo", "Volcano slam centre, full charge", _watch(m, tg, 2.0), {"stun": 1.2})
	_reset(m, pl, tg, home, 3.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Tenzo", "Basalt Spine", _watch(m, tg, 3.0), {"slow": 1.0, "slow_k": 0.35})
	_reset(m, pl, tg, home, 3.0)
	pl.do_dash()
	_row("Tenzo", "Rock Hop", _watch(m, tg, 3.0), {"slow": 1.5, "slow_k": 0.3})
	await done(m)


func _grimble() -> void:
	var r := _kit("dredge")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 3.0)
	pl.ak.use_e()
	_row("Grimble", "Anchor Drop", _watch(m, tg, 2.5), {"stun": 1.1})
	_reset(m, pl, tg, home, 3.0)
	pl.slot_lv["kin"] = 3
	pl.ak.use_e()
	_row("Grimble", "Anchor Drop, rank 3", _watch(m, tg, 2.5), {"stun": 1.5})
	pl.slot_lv["kin"] = 1
	_reset(m, pl, tg, home, 8.0)
	tap(m, pl)
	_row("Grimble", "Hook reel", _watch(m, tg, 3.0, Callable(), pl), {"stun": 0.2, "self_gnd": [0.5, 3.0]})
	await done(m)


func _neve() -> void:
	var r := _kit("rimewright")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	var kt: RimewrightKit = pl.ak
	_reset(m, pl, tg, home, 5.0)
	tap(m, pl)
	_row("Neve", "Ice Spear", _watch(m, tg, 3.0), {"slow": 0.8, "slow_k": 0.35})
	_reset(m, pl, tg, home, 3.0)
	pl.ak.use_e()
	_row("Neve", "Rink Wall", _watch(m, tg, 3.0), {"slow": 1.0, "slow_k": 0.3})
	_reset(m, pl, tg, home, 3.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Neve", "Rimelock rink zone", _watch(m, tg, 2.0), {"slow": [0.15, 0.2], "slow_k": 0.35})
	_row("Neve", "Rimelock crash", _watch(m, tg, 8.0), {"stun": 0.75, "slow": [0.15, 0.2], "slow_k": 0.35})
	_reset(m, pl, tg, home, 3.0)
	kt.splinter(tg.pos, 10.0, 2.0)
	_row("Neve", "Shatter splinter", _watch(m, tg, 2.0), {})  # damage only since f6c93c7a59: no slow
	await done(m)


func _motley() -> void:
	var r := _kit("ostra")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 5.0)
	tap(m, pl)
	_row("Motley", "Void Snap", _watch(m, tg, 3.0), {"stun": [0.8, 1.8]})
	_reset(m, pl, tg, home, 5.0)
	pl.inp["fire"] = true
	_row("Motley", "orb", _watch(m, tg, 3.0, func(): pl.inp["fire"] = true), {"slow": 1.5, "slow_k": 0.06})
	pl.inp["fire"] = false
	_reset(m, pl, tg, home, 4.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Motley", "Nightwell", _watch(m, tg, 4.0), {"stun": 3.5})
	await done(m)


func _albert() -> void:
	var r := _kit("bulwark")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_wall_at(m, home, r[5], 3)
	_reset(m, pl, tg, home, 2.2)
	pl.ak.cd["rmb"] = 0.0
	pl.inp["sec_hold"] = true
	pl.ak.press_rmb()
	step(m, 0.3, func(): pl.inp["sec_hold"] = true)
	pl.do_dash()
	pl.inp["sec_hold"] = false
	_row("Albert", "Shield Charge into a wall (Crush)", _watch(m, tg, 1.5), {"stun": 1.0})
	_reset(m, pl, tg, home, 5.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Albert", "Faultline lane", _watch(m, tg, 2.5), {"stun": 0.5, "slow": 1.5, "slow_k": 0.5})
	await done(m)


func _sparkle() -> void:
	var r := _kit("mage")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 4.0)
	pl.ak.use_e()
	_row("Sparkle", "Skycall", _watch(m, tg, 2.5), {"gnd": 1.5})
	await done(m)


func _sable() -> void:
	var r := _kit("thief", 4.0, true)
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	r[6].teleport(home + Vector3(0, 0, 8.0))  # the second dummy waits off to the side
	_reset(m, pl, tg, home, 4.0)
	tap(m, pl)  # Bola
	_row("Sable", "Bola, one foe", _watch(m, tg, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	var tg2: Hunter = r[6]
	var pairs0: int = pl.ak.bola_pairs
	_reset(m, pl, tg, home, 4.0)
	fresh(tg2)
	KitStatus.clear_rattled(tg2)
	tg2.teleport(tg.pos + Vector3(1.2, 0, 0))
	tap(m, pl)
	_row(
		"Sable",
		"Bola, a pair",
		_watch(m, tg, 2.5),
		{"gnd": 1.5, "slow": 1.5, "slow_k": 0.3, "stun": 0.9},
		pl.ak.bola_pairs == pairs0 + 1
	)
	_wall_at(m, home, r[5], 5)
	tg2.teleport(home + Vector3(0, 0, 8.0))
	_reset(m, pl, tg, home, 4.0)
	tap(m, pl)
	_row("Sable", "Bola, one foe against a wall", _watch(m, tg, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	_clear_wall(m, home, r[5], 5)
	_reset(m, pl, tg, home, 4.0)
	pl.ak.use_e()
	_row("Sable", "Shadow Knife", _watch(m, tg, 3.5), {"slow": 2.5, "slow_k": 0.5})
	await done(m)


func _gil() -> void:
	var r := _kit("gil")
	var m: Match = r[0]
	var pl: Hunter = r[1]
	var tg: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, pl, tg, home, 2.2)
	var kt: GilKit = pl.ak
	kt.third_until = m.time + 5.0  # the third thrust's hits slow
	pl.inp["fire"] = true
	var thrust := _watch(m, tg, 1.5, func(): pl.inp["fire"] = true)
	_row("Gil", "third thrust", thrust, {"slow": 0.5, "slow_k": 0.3}, dmg(tg) > 0.0)
	pl.inp["fire"] = false
	_reset(m, pl, tg, home, 4.0)
	pl.ak.use_e()
	_row("Gil", "E", _watch(m, tg, 2.0), {"stun": 1.0})
	_reset(m, pl, tg, home, 4.0)
	pl.ult = 1.0
	pl.ak.cast_ult()
	_row("Gil", "ult", _watch(m, tg, 3.0), {"stun": 1.0, "slow": 3.0, "slow_k": 0.5})
	step(m, 2.0)
	_reset(m, pl, tg, home, 3.0)
	pl.do_dash()
	_row("Gil", "Ground Swim dash", _watch(m, tg, 1.5), {"stun": 0.5})
	await done(m)
