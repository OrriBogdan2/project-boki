extends "res://tools/archetype_check.gd"
## --vex-daze-check: Vex's Daze team and her burst rifle. Daze adds its rattle_k to Coin Blast (hit and cone) and
## Cinderfall's impact as it does to Palm Lance; a foe the cone slams into terrain is stunned the data's wall_stun
## (1.2 s); the rifle's string starts over at full damage after a short rest, and a dry drum refills in about 1.1 s.
## Prints AKCHECK lines.

const EPS := 0.08  # s: a stun read off the body a frame after it lands
const DAZE_T := 4.0  # s of Daze put on a dummy, past every window read here


func run(main_node: Node) -> void:
	main = main_node
	await _coin()
	await _cinderfall()
	await _rifle()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## Two dummies the same hit away, one Dazed: the Dazed one takes 1 + rattle_k as much.
func _pair(foe: Hunter, t2: Hunter) -> void:
	fresh(foe)
	fresh(t2)
	KitStatus.clear_rattled(t2)
	KitStatus.apply(foe, "rat", DAZE_T)
	foe.inv_t = 0.0
	t2.inv_t = 0.0


func _ratio_ok(what: String, foe: Hunter, t2: Hunter, k: float) -> void:
	var info := "Dazed %.1f, not %.1f (want x%.2f)" % [dmg(foe), dmg(t2), 1.0 + k]
	ok(what, dmg(t2) > 1.0 and absf(dmg(foe) - dmg(t2) * (1.0 + k)) < 0.3, info)


func _coin() -> void:
	var r := setup("gunslinger", 6.0, "", true)
	var m: Match = r[0]
	var foe: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var gk: GunslingerKit = (r[1] as Hunter).ak
	var bd: Dictionary = gk.rmb_def()["burr"]
	var k := float(bd["rattle_k"])
	ok("Coin Blast: the data's Daze bonus is 20%", is_equal_approx(k, 0.2), str(k))
	# a direct hit on each
	foe.teleport(home + Vector3(6, 0, 1.5))
	t2.teleport(home + Vector3(6, 0, -1.5))
	step(m, 0.05)
	_pair(foe, t2)
	for f: Hunter in [foe, t2]:
		gk._direct_hit({"node": null, "dir": Vector2(1, 0)}, f, f.pos)
	_ratio_ok("Coin Blast hit: a Dazed foe takes 20% more", foe, t2, k)
	# the wall cone over both, out on open ground (no slam)
	var at := home + Vector3(9.5, 0, 0)
	_pair(foe, t2)
	gk._cone(at, Vector2(-1, 0), bd)
	_ratio_ok("Coin Blast cone: a Dazed foe takes 20% more", foe, t2, k)
	# the cone shoves foe into a cliff one tile behind it: stunned wall_stun
	t2.teleport(home + Vector3(30, 0, 8))
	var spot := foe.pos
	var undo := _cliff(m, spot, r[5])
	fresh(foe)
	KitStatus.clear_rattled(foe)
	foe.inv_t = 0.0
	foe.teleport(spot)
	gk._cone(spot - Vector3(3, 0, 0), Vector2(1, 0), bd)
	var most := _stun_over(m, foe, 1.6)
	undo.call()
	var want := float(bd["wall_stun"])
	ok(
		"Coin Blast wall slam: stunned %.1f s" % want,
		is_equal_approx(want, 1.2) and absf(most - want) < EPS,
		"%.2f s" % most
	)
	await done(m)


func _cinderfall() -> void:
	var r := setup("gunslinger", 6.0, "", true)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var foe: Hunter = r[2]
	var t2: Hunter = r[3]
	var home: Vector3 = r[4]
	var gk: GunslingerKit = p.ak
	var xd := gk.x_def()
	foe.teleport(home + Vector3(6, 0, 2.0))
	t2.teleport(home + Vector3(6, 0, -2.0))
	step(m, 0.05)
	aim_at(p, home + Vector3(6, 0, 0))
	_pair(foe, t2)
	gk.ult.cast()
	step(m, float(xd["delay"]) + 0.05)
	ok("Cinderfall: both off the hot centre, the impact landed", int(gk.ult.last.get("centre", -1)) == 0)
	_ratio_ok("Cinderfall impact: a Dazed foe takes 20% more", foe, t2, float(xd["rattle_k"]))
	await done(m)


## Rounds landing on foe while `secs` of fire is held: each step's damage, in order.
func _string(m: Match, p: Hunter, foe: Hunter, secs: float) -> Array:
	var got := []
	var t := 0.0
	while t < secs:
		var hp0 := foe.hp
		p.inp["fire"] = true
		m.step(DT)
		t += DT
		if hp0 - foe.hp > 0.01:
			got.append(hp0 - foe.hp)
	p.inp["fire"] = false
	return got


func _rifle() -> void:
	var r := setup("gunslinger", 5.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var foe: Hunter = r[2]
	var mag := int(p.wpn["mag"])
	fresh(foe)
	aim_at(p, foe.pos)
	var first := _string(m, p, foe, 2.0)
	ok(
		"rifle: past half a drum every round hits for 80% (the half-drum rule)",
		first.size() > 20 and absf(float(first[-1]) / float(first[0]) - 0.8) < 0.02,
		"%d rounds, %.2f -> %.2f" % [first.size(), first[0], first[-1]]
	)
	step(m, float(p.wpn["refill_after"]) + 0.8)  # long enough to top the drum up from below half
	fresh(foe)
	var again := _string(m, p, foe, 0.3)
	ok(
		"rifle: a rest and the next string starts at full damage",
		not again.is_empty() and is_equal_approx(float(again[0]), float(first[0])),
		str(again)
	)
	p.ammo = 0
	var waited := 0.0
	while p.ammo < mag and waited < 3.0:
		m.step(DT)
		waited += DT
	ok(
		"rifle: a dry drum refills in about 1.1 s with the trigger at rest",
		p.ammo == mag and waited < 1.2,
		"%.2f s" % waited
	)
	await done(m)


## A cliff one tile past `spot` (east); returns the undo.
func _cliff(m: Match, spot: Vector3, lv: int) -> Callable:
	var w: World = m.world
	var tx := int(floor(spot.x)) + 1
	var tz := int(floor(spot.z))
	for dz in range(-3, 4):
		w.level[w.idx(tx, tz + dz)] = lv + 3
	return func():
		for dz in range(-3, 4):
			w.level[w.idx(tx, tz + dz)] = lv


## The longest stun on `t` over `secs`.
func _stun_over(m: Match, t: Hunter, secs: float) -> float:
	var most := 0.0
	var waited := 0.0
	while waited < secs:
		m.step(DT)
		waited += DT
		most = maxf(most, t.stun_t)
	return most
