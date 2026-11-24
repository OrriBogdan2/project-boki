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
func _watch(m: Match, t_v: Hunter, secs: float, each := Callable(), caster: Hunter = null) -> Dictionary:
	var pk := {"stun": 0.0, "root": 0.0, "slow": 0.0, "slow_k": 0.0, "gnd": 0.0, "rat": 0.0, "self_gnd": 0.0}
	var t := 0.0
	while t < secs:
		if each.is_valid():
			each.call()
		m.step(DT)
		Oomph.render_hit(t_v, DT)  # the stagger clock (Hunter.render runs it, and a headless run draws nothing)
		t += DT
		pk["stun"] = maxf(pk["stun"], t_v.stun_t)
		pk["root"] = maxf(pk["root"], t_v.root_t)
		var stagger := is_equal_approx(t_v.slow_k, Oomph.STAGGER_SLOW) and t_v.slow_t <= Oomph.STAGGER_T + 0.02
		if not stagger and t_v.slow_t > 0.0:  # (the hit stagger's own short slow is no rider)
			pk["slow"] = maxf(pk["slow"], t_v.slow_t)
			pk["slow_k"] = maxf(pk["slow_k"], t_v.slow_k)
		if caster != null:
			pk["self_gnd"] = maxf(pk["self_gnd"], KitStatus.grounded_left(caster))
		pk["gnd"] = maxf(pk["gnd"], KitStatus.grounded_left(t_v))
		pk["rat"] = maxf(pk["rat"], KitStatus.rattled_left(t_v))
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
	var p_v: Hunter = r[1]
	var k_v = p_v.ak
	for s in ["sec", "dash", "util"]:
		if p_v.slot_lv.has(s):
			p_v.slot_lv[s] = maxi(1, int(p_v.slot_lv[s]))
	return [r[0], p_v, r[2], k_v, r[4], r[5], r[3]]


func _reset(m: Match, p_v: Hunter, t_v: Hunter, home: Vector3, d: float) -> void:
	p_v.teleport(home)
	p_v.vel = Vector3.ZERO
	fresh(t_v)
	KitStatus.clear_rattled(t_v)
	t_v.teleport(home + Vector3(d, 0, 0))
	for k in p_v.ak.cd:
		p_v.ak.cd[k] = 0.0
	p_v.fire_cd = 0.0
	p_v.dashes = p_v.max_dashes()
	step(m, 0.3)
	fresh(t_v)
	KitStatus.clear_rattled(t_v)
	t_v.teleport(home + Vector3(d, 0, 0))
	aim_at(p_v, t_v.pos)


## Each kit's wall hit into a cliff (the kit's own number), and a plain knock (the body slam every kit shares).
func _walls() -> void:
	var w = WALLS.new()
	w.main = main
	for src: String in ["archer", "bulwark", "gunslinger", "dolm", "mage", "knock"]:
		var r: Array = w.setup(src if src != "knock" else "thief", 3.0, "", true)
		var t_v: Hunter = r[2]
		var spot := t_v.pos
		t_v.teleport(spot)
		var undo: Callable = w._build(r[0], t_v, r[3], "cliff", spot, r[5])
		var rec: Dictionary = w._knock(src, r[0], r[1], t_v)
		undo.call()
		var got := {"stun": rec["stun"]}
		var want := {"stun": WALL_NAMES[src][2]}
		if src == "gunslinger":  # the Daze it was left with, plus the frames the probe ran on
			got["rat"] = KitStatus.rattled_left(t_v) + float(WALLS.FRAMES) * DT
			want["rat"] = 2.0
		_row(String(WALL_NAMES[src][0]), String(WALL_NAMES[src][1]), got, want)
		await done(r[0])


# ------------------------------------------------------------------ one kit a function
func _vex() -> void:
	var r := _kit("gunslinger")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 4.0)
	tap(m, p_v)  # Burr Charge
	_row("Vex", "Burr Charge cone", _watch(m, t_v, 2.5), {"rat": 1.4})
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Vex", "Cinderfall zone", _watch(m, t_v, 3.0), {"slow": 0.6, "slow_k": 0.3})
	await done(m)


func _kael() -> void:
	var r := _kit("juggernaut")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: JuggernautKit = p_v.ak
	var drop := func(dx: float) -> Dictionary:
		_reset(m, p_v, t_v, home, 6.0)
		k_v.ch_rmb = 1.0
		p_v.teleport(t_v.pos + Vector3(dx, 3.0, 0))
		p_v.grounded = false
		aim_at(p_v, t_v.pos + Vector3(6.0, 0, 0))
		m.step(DT)
		p_v.ak.press_rmb()
		return _watch(m, t_v, 2.0)
	_row("Kael", "Meteor Drop, core", drop.call(-1.0), {"stun": 0.8})
	_row("Kael", "Meteor Drop, ring edge", drop.call(-2.6), {"stun": 0.45})
	var hook := func() -> void:
		_reset(m, p_v, t_v, home, 6.0)
		k_v.haul = {}
		k_v.ch_rmb = 1.0
		p_v.ak.use_e()
		step(m, 0.3)
	hook.call()
	hold(m, p_v, 0.95)
	_row("Kael", "Chain Lunge (E, hold RMB)", _watch(m, t_v, 1.0), {}, k_v.chain_lunges == 1 and dmg(t_v) > 0.0)
	step(m, 1.0)
	hook.call()
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	step(m, 0.5, func(): p_v.inp["sec_hold"] = true)
	p_v.ak.use_e()
	_row(
		"Kael",
		"Haul Slam (E, hold RMB, E)",
		_watch(m, t_v, 1.5, func(): p_v.inp["sec_hold"] = true),
		{},
		k_v.haul_slams == 1 and dmg(t_v) > 0.0
	)
	p_v.inp["sec_hold"] = false
	_reset(m, p_v, t_v, home, 3.0)
	p_v.inp["fire"] = true  # Searing Wave: LMB held, then let go
	step(m, 1.2, func(): p_v.inp["fire"] = true)
	p_v.inp["fire"] = false
	_row("Kael", "Fireblast wave", _watch(m, t_v, 1.5), {}, k_v.waves >= 1 and dmg(t_v) > 0.0)
	await done(m)


func _lace() -> void:
	var r := _kit("archer")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ak.use_e()
	_row("Lace", "Rain of Arrows", _watch(m, t_v, 3.0), {"slow": 0.8, "slow_k": 0.35})
	await done(m)


func _cinder() -> void:
	var r := _kit("ashwick")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 5.0)
	tap(m, p_v)  # Cinder Shot
	_row("Cinder", "Cinder Shot", _watch(m, t_v, 3.0), {"slow": 1.5, "slow_k": 0.3})
	_reset(m, p_v, t_v, home, 5.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Cinder", "Flue Flight carpet", _watch(m, t_v, 4.0), {"slow": 0.5, "slow_k": 0.3})
	await done(m)


func _meeko() -> void:
	var r := _kit("tender")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 4.0)
	tap(m, p_v)
	_row("Meeko", "Burrseed", _watch(m, t_v, 5.0), {"root": 1.1})
	_reset(m, p_v, t_v, home, 4.0)
	p_v.slot_lv["sec"] = 3
	tap(m, p_v)
	_row("Meeko", "Burrseed, rank 3", _watch(m, t_v, 5.0), {"root": 1.4})
	await done(m)


func _tenzo() -> void:
	var r := _kit("dolm")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 2.2)
	tap(m, p_v)
	_row("Tenzo", "Volcano slam centre, tap", _watch(m, t_v, 2.0), {"stun": 0.5})
	_reset(m, p_v, t_v, home, 2.2)
	hold(m, p_v, 0.7)  # the charge is full at 0.45 s
	_row("Tenzo", "Volcano slam centre, full charge", _watch(m, t_v, 2.0), {"stun": 1.2})
	_reset(m, p_v, t_v, home, 3.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Tenzo", "Basalt Spine", _watch(m, t_v, 3.0), {"slow": 1.0, "slow_k": 0.35})
	_reset(m, p_v, t_v, home, 3.0)
	p_v.do_dash()
	_row("Tenzo", "Rock Hop", _watch(m, t_v, 3.0), {"slow": 1.5, "slow_k": 0.3})
	await done(m)


func _grimble() -> void:
	var r := _kit("dredge")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 3.0)
	p_v.ak.use_e()
	_row("Grimble", "Anchor Drop", _watch(m, t_v, 2.5), {"stun": 1.1})
	_reset(m, p_v, t_v, home, 3.0)
	p_v.slot_lv["kin"] = 3
	p_v.ak.use_e()
	_row("Grimble", "Anchor Drop, rank 3", _watch(m, t_v, 2.5), {"stun": 1.5})
	p_v.slot_lv["kin"] = 1
	_reset(m, p_v, t_v, home, 8.0)
	tap(m, p_v)
	_row("Grimble", "Hook reel", _watch(m, t_v, 3.0, Callable(), p_v), {"stun": 0.2, "self_gnd": [0.5, 3.0]})
	await done(m)


func _neve() -> void:
	var r := _kit("rimewright")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	var k_v: RimewrightKit = p_v.ak
	_reset(m, p_v, t_v, home, 5.0)
	tap(m, p_v)
	_row("Neve", "Ice Spear", _watch(m, t_v, 3.0), {"slow": 0.8, "slow_k": 0.35})
	_reset(m, p_v, t_v, home, 3.0)
	p_v.ak.use_e()
	_row("Neve", "Rink Wall", _watch(m, t_v, 3.0), {"slow": 1.0, "slow_k": 0.3})
	_reset(m, p_v, t_v, home, 3.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Neve", "Rimelock rink zone", _watch(m, t_v, 2.0), {"slow": [0.15, 0.2], "slow_k": 0.35})
	_row("Neve", "Rimelock crash", _watch(m, t_v, 8.0), {"stun": 0.75, "slow": [0.15, 0.2], "slow_k": 0.35})
	_reset(m, p_v, t_v, home, 3.0)
	k_v.splinter(t_v.pos, 10.0, 2.0)
	_row("Neve", "Shatter splinter", _watch(m, t_v, 2.0), {"slow": 1.2, "slow_k": 0.3})
	await done(m)


func _motley() -> void:
	var r := _kit("ostra")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 5.0)
	tap(m, p_v)
	_row("Motley", "Void Snap", _watch(m, t_v, 3.0), {"stun": [0.8, 1.8]})
	_reset(m, p_v, t_v, home, 5.0)
	p_v.inp["fire"] = true
	_row("Motley", "orb", _watch(m, t_v, 3.0, func(): p_v.inp["fire"] = true), {"slow": 1.5, "slow_k": 0.06})
	p_v.inp["fire"] = false
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Motley", "Nightwell", _watch(m, t_v, 4.0), {"stun": 3.5})
	await done(m)


func _albert() -> void:
	var r := _kit("bulwark")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_wall_at(m, home, r[5], 3)
	_reset(m, p_v, t_v, home, 2.2)
	p_v.ak.cd["rmb"] = 0.0
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	step(m, 0.3, func(): p_v.inp["sec_hold"] = true)
	p_v.do_dash()
	p_v.inp["sec_hold"] = false
	_row("Albert", "Shield Charge into a wall (Crush)", _watch(m, t_v, 1.5), {"stun": 1.0})
	_reset(m, p_v, t_v, home, 5.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Albert", "Faultline lane", _watch(m, t_v, 2.5), {"stun": 0.5, "slow": 1.5, "slow_k": 0.5})
	await done(m)


func _sparkle() -> void:
	var r := _kit("mage")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ak.use_e()
	_row("Sparkle", "Skycall", _watch(m, t_v, 2.5), {"gnd": 1.5})
	await done(m)


func _sable() -> void:
	var r := _kit("thief", 4.0, true)
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	r[6].teleport(home + Vector3(0, 0, 8.0))  # the second dummy waits off to the side
	_reset(m, p_v, t_v, home, 4.0)
	tap(m, p_v)  # Bola
	_row("Sable", "Bola, one foe", _watch(m, t_v, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	var t2_v: Hunter = r[6]
	var pairs0: int = p_v.ak.bola_pairs
	_reset(m, p_v, t_v, home, 4.0)
	fresh(t2_v)
	KitStatus.clear_rattled(t2_v)
	t2_v.teleport(t_v.pos + Vector3(1.2, 0, 0))
	tap(m, p_v)
	_row(
		"Sable",
		"Bola, a pair",
		_watch(m, t_v, 2.5),
		{"gnd": 1.5, "slow": 1.5, "slow_k": 0.3, "stun": 0.9},
		p_v.ak.bola_pairs == pairs0 + 1
	)
	_wall_at(m, home, r[5], 5)
	t2_v.teleport(home + Vector3(0, 0, 8.0))
	_reset(m, p_v, t_v, home, 4.0)
	tap(m, p_v)
	_row("Sable", "Bola, one foe against a wall", _watch(m, t_v, 2.5), {"gnd": 1.5, "slow": 1.5, "slow_k": 0.3})
	_clear_wall(m, home, r[5], 5)
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ak.use_e()
	_row("Sable", "Shadow Knife", _watch(m, t_v, 3.5), {"slow": 2.5, "slow_k": 0.5})
	await done(m)


func _gil() -> void:
	var r := _kit("gil")
	var m: Match = r[0]
	var p_v: Hunter = r[1]
	var t_v: Hunter = r[2]
	var home: Vector3 = r[4]
	_reset(m, p_v, t_v, home, 2.2)
	var k_v: GilKit = p_v.ak
	k_v.third_until = m.time + 5.0  # the third thrust's hits slow
	p_v.inp["fire"] = true
	var thrust := _watch(m, t_v, 1.5, func(): p_v.inp["fire"] = true)
	_row("Gil", "third thrust", thrust, {"slow": 0.5, "slow_k": 0.3}, dmg(t_v) > 0.0)
	p_v.inp["fire"] = false
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ak.use_e()
	_row("Gil", "E", _watch(m, t_v, 2.0), {"stun": 1.0})
	_reset(m, p_v, t_v, home, 4.0)
	p_v.ult = 1.0
	p_v.ak.cast_ult()
	_row("Gil", "ult", _watch(m, t_v, 3.0), {"stun": 1.0, "slow": 3.0, "slow_k": 0.5})
	step(m, 2.0)
	_reset(m, p_v, t_v, home, 3.0)
	p_v.do_dash()
	_row("Gil", "Ground Swim dash", _watch(m, t_v, 1.5), {"stun": 0.5})
	await done(m)
