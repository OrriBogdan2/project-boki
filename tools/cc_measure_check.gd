extends "res://tools/archer_bulwark_combo_check.gd"
## --cc-measure-check: every crowd control effect of the 13 kits, measured (docs/KIT_PARITY.d/1122-cc-reread.md).
## Each row casts the kit's own ability on an idle dummy (a wall behind it when the effect needs one) and reads the
## peak the dummy's stun, root, slow (time and strength) and Grounded / Daze reach, then compares it with the
## number the table gives. One `CCM` line a row: the numbers are the table.

const WALLS := preload("res://tools/wall_stun_check.gd")  # its probes: each kit's own wall hit, a cliff behind
const WALL_NAMES := {
	"archer": ["Lace", "Heartpiercer into a wall", 1.2],
	"bulwark": ["Albert", "knock into a wall (Crush)", 1.0],
	"gunslinger": ["Vex", "Burr cone into a wall", 0.9],
	"dolm": ["Tenzo", "Quake Punch into a wall", 0.9],
	"mage": ["Sparkle", "Storm Rod into a wall", 0.8],
	"knock": ["any", "plain knock into a wall", 0.9],
}
## A row: [arch, label, expected {stun, root, slow, slow_k, gnd, rat: seconds or strength}, cast method].
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
func _watch(m: Match, tgt: Hunter, secs: float, each := Callable(), caster: Hunter = null) -> Dictionary:
	var pk := {"stun": 0.0, "root": 0.0, "slow": 0.0, "slow_k": 0.0, "gnd": 0.0, "rat": 0.0, "self_gnd": 0.0}
	var t := 0.0
	while t < secs:
		if each.is_valid():
			each.call()
		m.step(DT)
		Oomph.render_hit(tgt, DT)  # the stagger clock (Hunter.render runs it, and a headless run draws nothing)
		t += DT
		pk["stun"] = maxf(pk["stun"], tgt.stun_t)
		pk["root"] = maxf(pk["root"], tgt.root_t)
		var stagger := is_equal_approx(tgt.slow_k, Oomph.STAGGER_SLOW) and tgt.slow_t <= Oomph.STAGGER_T + 0.02
		if not stagger and tgt.slow_t > 0.0:  # (the hit stagger's own short slow is no rider)
			pk["slow"] = maxf(pk["slow"], tgt.slow_t)
			pk["slow_k"] = maxf(pk["slow_k"], tgt.slow_k)
		if caster != null:
			pk["self_gnd"] = maxf(pk["self_gnd"], KitStatus.grounded_left(caster))
		pk["gnd"] = maxf(pk["gnd"], KitStatus.grounded_left(tgt))
		pk["rat"] = maxf(pk["rat"], KitStatus.rattled_left(tgt))
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


## A fresh strip, the dummy `d` m ahead, aim on it; returns [m, P, T, K, home, lv].
func _kit(arch: String, d := 2.2, second := false) -> Array:
	var r := setup(arch, d, "", second)
	var ply: Hunter = r[1]
	var kit = ply.ak
	for s in ["sec", "dash", "util"]:
		if ply.slot_lv.has(s):
			ply.slot_lv[s] = maxi(1, int(ply.slot_lv[s]))
	return [r[0], ply, r[2], kit, r[4], r[5], r[3]]


func _reset(m: Match, ply: Hunter, tgt: Hunter, home: Vector3, d: float) -> void:
	ply.teleport(home)
	ply.vel = Vector3.ZERO
	fresh(tgt)
	KitStatus.clear_rattled(tgt)
	tgt.teleport(home + Vector3(d, 0, 0))
	for k in ply.ak.cd:
		ply.ak.cd[k] = 0.0
	ply.fire_cd = 0.0
	ply.dashes = ply.max_dashes()
	step(m, 0.3)
	fresh(tgt)
	KitStatus.clear_rattled(tgt)
	tgt.teleport(home + Vector3(d, 0, 0))
	aim_at(ply, tgt.pos)


## Each kit's wall hit into a cliff (the kit's own number), and a plain knock (the body slam every kit shares).
func _walls() -> void:
	var w = WALLS.new()
	w.main = main
	for src: String in ["archer", "bulwark", "gunslinger", "dolm", "mage", "knock"]:
		var r: Array = w.setup(src if src != "knock" else "thief", 3.0, "", true)
		var tgt: Hunter = r[2]
		var spot := tgt.pos
		tgt.teleport(spot)
		var undo: Callable = w._build(r[0], tgt, r[3], "cliff", spot, r[5])
		var rec: Dictionary = w._knock(src, r[0], r[1], tgt)
		undo.call()
		var got := {"stun": rec["stun"]}
		var want := {"stun": WALL_NAMES[src][2]}
		if src == "gunslinger":  # the Daze it was left with, plus the frames the probe ran on
			got["rat"] = KitStatus.rattled_left(tgt) + float(WALLS.FRAMES) * DT
			want["rat"] = 2.0
		_row(String(WALL_NAMES[src][0]), String(WALL_NAMES[src][1]), got, want)
		await done(r[0])


# ------------------------------------------------------------------ one kit a function
func _vex() -> void:
	var r := _kit("gunslinger")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 4.0)
	tap(m, ply)  # Burr Charge
	_row("Vex", "Burr Charge cone", _watch(m, tgt, 2.5), {"rat": 1.4})
	_reset(m, ply, tgt, home, 4.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Vex", "Cinderfall zone", _watch(m, tgt, 3.0), {"slow": 0.6, "slow_k": 0.3})
	await done(m)


func _kael() -> void:
	var r := _kit("juggernaut")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	var kit: JuggernautKit = ply.ak
	var drop := func(dx: float) -> Dictionary:
		_reset(m, ply, tgt, home, 6.0)
		kit.ch_rmb = 1.0
		ply.teleport(tgt.pos + Vector3(dx, 3.0, 0))
		ply.grounded = false
		aim_at(ply, tgt.pos + Vector3(6.0, 0, 0))
		m.step(DT)
		ply.ak.press_rmb()
		return _watch(m, tgt, 2.0)
	_row("Kael", "Meteor Drop, core", drop.call(-1.0), {"stun": 0.8})
	_row("Kael", "Meteor Drop, ring edge", drop.call(-2.6), {"stun": 0.45})
	var hook := func() -> void:
		_reset(m, ply, tgt, home, 6.0)
		kit.haul = {}
		kit.ch_rmb = 1.0
		ply.ak.use_e()
		step(m, 0.3)
	hook.call()
	hold(m, ply, 0.95)
	_row("Kael", "Chain Lunge (E, hold RMB)", _watch(m, tgt, 1.0), {}, kit.chain_lunges == 1 and dmg(tgt) > 0.0)
	step(m, 1.0)
	hook.call()
	ply.inp["sec_hold"] = true
	ply.ak.press_rmb()
	step(m, 0.5, func(): ply.inp["sec_hold"] = true)
	ply.ak.use_e()
	_row(
		"Kael",
		"Haul Slam (E, hold RMB, E)",
		_watch(m, tgt, 1.5, func(): ply.inp["sec_hold"] = true),
		{},
		kit.haul_slams == 1 and dmg(tgt) > 0.0
	)
	ply.inp["sec_hold"] = false
	_reset(m, ply, tgt, home, 3.0)
	ply.inp["fire"] = true  # Searing Wave: LMB held, then let go
	step(m, 1.2, func(): ply.inp["fire"] = true)
	ply.inp["fire"] = false
	_row("Kael", "Fireblast wave", _watch(m, tgt, 1.5), {}, kit.waves >= 1 and dmg(tgt) > 0.0)
	await done(m)


func _lace() -> void:
	var r := _kit("archer")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 4.0)
	ply.ak.use_e()
	_row("Lace", "Rain of Arrows", _watch(m, tgt, 3.0), {"slow": 0.8, "slow_k": 0.35})
	await done(m)


func _cinder() -> void:
	var r := _kit("ashwick")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 5.0)
	tap(m, ply)  # Cinder Shot
	_row("Cinder", "Cinder Shot", _watch(m, tgt, 3.0), {"slow": 1.5, "slow_k": 0.3})
	_reset(m, ply, tgt, home, 5.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Cinder", "Flue Flight carpet", _watch(m, tgt, 4.0), {"slow": 0.5, "slow_k": 0.3})
	await done(m)


func _meeko() -> void:
	var r := _kit("tender")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 4.0)
	tap(m, ply)
	_row("Meeko", "Burrseed", _watch(m, tgt, 5.0), {"root": 1.1})
	_reset(m, ply, tgt, home, 4.0)
	ply.slot_lv["sec"] = 3
	tap(m, ply)
	_row("Meeko", "Burrseed, rank 3", _watch(m, tgt, 5.0), {"root": 1.4})
	await done(m)


func _tenzo() -> void:
	var r := _kit("dolm")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 2.2)
	tap(m, ply)
	_row("Tenzo", "Volcano slam centre, tap", _watch(m, tgt, 2.0), {"stun": 0.5})
	_reset(m, ply, tgt, home, 2.2)
	hold(m, ply, 0.7)  # the charge is full at 0.45 s
	_row("Tenzo", "Volcano slam centre, full charge", _watch(m, tgt, 2.0), {"stun": 1.2})
	_reset(m, ply, tgt, home, 3.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Tenzo", "Basalt Spine", _watch(m, tgt, 3.0), {"slow": 1.0, "slow_k": 0.35})
	_reset(m, ply, tgt, home, 3.0)
	ply.do_dash()
	_row("Tenzo", "Rock Hop", _watch(m, tgt, 3.0), {"slow": 1.5, "slow_k": 0.3})
	await done(m)


func _grimble() -> void:
	var r := _kit("dredge")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 3.0)
	ply.ak.use_e()
	_row("Grimble", "Anchor Drop", _watch(m, tgt, 2.5), {"stun": 1.1})
	_reset(m, ply, tgt, home, 3.0)
	ply.slot_lv["kin"] = 3
	ply.ak.use_e()
	_row("Grimble", "Anchor Drop, rank 3", _watch(m, tgt, 2.5), {"stun": 1.5})
	ply.slot_lv["kin"] = 1
	_reset(m, ply, tgt, home, 8.0)
	tap(m, ply)
	_row("Grimble", "Hook reel", _watch(m, tgt, 3.0, Callable(), ply), {"stun": 0.2, "self_gnd": [0.5, 3.0]})
	await done(m)


func _neve() -> void:
	var r := _kit("rimewright")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	var kit: RimewrightKit = ply.ak
	_reset(m, ply, tgt, home, 5.0)
	tap(m, ply)
	_row("Neve", "Ice Spear", _watch(m, tgt, 3.0), {"slow": 0.8, "slow_k": 0.35})
	_reset(m, ply, tgt, home, 3.0)
	ply.ak.use_e()
	_row("Neve", "Rink Wall", _watch(m, tgt, 3.0), {"slow": 1.0, "slow_k": 0.3})
	_reset(m, ply, tgt, home, 3.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Neve", "Rimelock rink zone", _watch(m, tgt, 2.0), {"slow": [0.15, 0.2], "slow_k": 0.35})
	_row("Neve", "Rimelock crash", _watch(m, tgt, 8.0), {"stun": 0.75, "slow": [0.15, 0.2], "slow_k": 0.35})
	_reset(m, ply, tgt, home, 3.0)
	kit.splinter(tgt.pos, 10.0, 2.0)
	_row("Neve", "Shatter splinter", _watch(m, tgt, 2.0), {"slow": 1.2, "slow_k": 0.3})
	await done(m)


func _motley() -> void:
	var r := _kit("ostra")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 5.0)
	tap(m, ply)
	_row("Motley", "Void Snap", _watch(m, tgt, 3.0), {"stun": [0.8, 1.8]})
	_reset(m, ply, tgt, home, 5.0)
	ply.inp["fire"] = true
	_row("Motley", "orb", _watch(m, tgt, 3.0, func(): ply.inp["fire"] = true), {"slow": 1.5, "slow_k": 0.06})
	ply.inp["fire"] = false
	_reset(m, ply, tgt, home, 4.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Motley", "Nightwell", _watch(m, tgt, 4.0), {"stun": 3.5})
	await done(m)


func _albert() -> void:
	var r := _kit("bulwark")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_wall_at(m, home, r[5], 3)
	_reset(m, ply, tgt, home, 2.2)
	ply.ak.cd["rmb"] = 0.0
	ply.inp["sec_hold"] = true
	ply.ak.press_rmb()
	step(m, 0.3, func(): ply.inp["sec_hold"] = true)
	ply.do_dash()
	ply.inp["sec_hold"] = false
	_row("Albert", "Shield Charge into a wall (Crush)", _watch(m, tgt, 1.5), {"stun": 1.0})
	_reset(m, ply, tgt, home, 5.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Albert", "Faultline lane", _watch(m, tgt, 2.5), {"stun": 0.5, "slow": 1.5, "slow_k": 0.5})
	await done(m)


func _sparkle() -> void:
	var r := _kit("mage")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 4.0)
	ply.ak.use_e()
	_row("Sparkle", "Skycall", _watch(m, tgt, 2.5), {"gnd": 1.5})
	await done(m)


func _sable() -> void:
	var r := _kit("thief", 4.0, true)
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	r[6].teleport(home + Vector3(0, 0, 8.0))  # the second dummy waits off to the side
	_reset(m, ply, tgt, home, 4.0)
	tap(m, ply)  # Bola
	_row("Sable", "Bola, one foe", _watch(m, tgt, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	var t2_v: Hunter = r[6]
	var pairs0: int = ply.ak.bola_pairs
	_reset(m, ply, tgt, home, 4.0)
	fresh(t2_v)
	KitStatus.clear_rattled(t2_v)
	t2_v.teleport(tgt.pos + Vector3(1.2, 0, 0))
	tap(m, ply)
	_row(
		"Sable",
		"Bola, a pair",
		_watch(m, tgt, 2.5),
		{"gnd": 1.5, "slow": 1.5, "slow_k": 0.3, "stun": 0.9},
		ply.ak.bola_pairs == pairs0 + 1
	)
	_wall_at(m, home, r[5], 5)
	t2_v.teleport(home + Vector3(0, 0, 8.0))
	_reset(m, ply, tgt, home, 4.0)
	tap(m, ply)
	_row("Sable", "Bola, one foe against a wall", _watch(m, tgt, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	_clear_wall(m, home, r[5], 5)
	_reset(m, ply, tgt, home, 4.0)
	ply.ak.use_e()
	_row("Sable", "Shadow Knife", _watch(m, tgt, 3.5), {"slow": 2.5, "slow_k": 0.5})
	await done(m)


func _gil() -> void:
	var r := _kit("gil")
	var m: Match = r[0]
	var ply: Hunter = r[1]
	var tgt: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, ply, tgt, home, 2.2)
	var kit: GilKit = ply.ak
	kit.third_until = m.time + 5.0  # the third thrust's hits slow
	ply.inp["fire"] = true
	var thrust := _watch(m, tgt, 1.5, func(): ply.inp["fire"] = true)
	_row("Gil", "third thrust", thrust, {"slow": 0.5, "slow_k": 0.3}, dmg(tgt) > 0.0)
	ply.inp["fire"] = false
	_reset(m, ply, tgt, home, 4.0)
	ply.ak.use_e()
	_row("Gil", "E", _watch(m, tgt, 2.0), {"stun": 1.0})
	_reset(m, ply, tgt, home, 4.0)
	ply.ult = 1.0
	ply.ak.cast_ult()
	_row("Gil", "ult", _watch(m, tgt, 3.0), {"stun": 1.0, "slow": 3.0, "slow_k": 0.5})
	step(m, 2.0)
	_reset(m, ply, tgt, home, 3.0)
	ply.do_dash()
	_row("Gil", "Ground Swim dash", _watch(m, tgt, 1.5), {"stun": 0.5})
	await done(m)
