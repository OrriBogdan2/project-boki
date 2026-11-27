<<<<<<< /tmp/r.3691459
extends "res://tools/archetype_check.gd"
## --kit-cc-scale-check: the wall-stun lengths of decision 0181. A plain knock's wall slam stuns longer the
## harder it hits (KnockWall.slam_stun, 0.4 -> 1.2 s), the Heavy Shot's pin and the Storm Rod's wall stun grow
## with their charge.
## Prints AKCHECK lines.

const EPS := 0.08  # s: a stun read off the body a frame after it lands


func run(main_node: Node) -> void:
	main = main_node
	_curve()
	await _knock()
	await _charged("archer")
	await _charged("mage")
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


func _curve() -> void:
	var lo := KnockWall.slam_stun(KnockWall.SLAM_V.x)
	var mid := KnockWall.slam_stun(12.0)
	var hi := KnockWall.slam_stun(KnockWall.SLAM_V.y)
	var past := KnockWall.slam_stun(40.0)
	ok("slam curve 0.4 -> 1.2 s", is_equal_approx(lo, 0.4) and is_equal_approx(hi, 1.2) and lo < mid and mid < hi)
	ok("slam curve caps at 1.2 s", is_equal_approx(past, 1.2), "%.2f %.2f %.2f %.2f" % [lo, mid, hi, past])


## A cliff one tile past the dummy (east); returns the undo.
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


func _knock() -> void:
	var r := setup("thief", 3.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var spot := t.pos
	var undo := _cliff(m, spot, r[5])
	var got := {}
	for kb: float in [10.0, 20.0]:
		fresh(t)
		t.teleport(spot)
		t.wslam_t = 0.0
		t.hurt(5.0, p, {"src": "abil", "ab": "lmb", "kb": Vector2(kb, 0.0), "lift": 0.5})
		got[kb] = _stun_over(m, t, 1.5)
	undo.call()
	var info := "kb 10: %.2f s, kb 20: %.2f s" % [got[10.0], got[20.0]]
	ok("slam: a harder knock stuns longer", got[10.0] > 0.3 and got[20.0] > got[10.0] + 0.2, info)
	ok("slam: never past 1.2 s", got[20.0] <= 1.2 + EPS, info)
	await done(m)


## The Heavy Shot (archer) or the Storm Rod (mage) into a cliff, uncharged and full: the stun follows the data's
## [low, high] pair.
func _charged(arch: String) -> void:
	var r := setup(arch, 3.0)
	var m: Match = r[0]
	var p: Hunter = r[1]
	var t: Hunter = r[2]
	var kit = p.ak
	var spot := t.pos
	var undo := _cliff(m, spot, r[5])
	var span: Array = kit.rmb_def()["pin" if arch == "archer" else "coil"]["stun"]
	var got := {}
	for k: float in [0.0, 1.0]:
		fresh(t)
		t.teleport(spot)
		t.wslam_t = 99.0  # the kit's own wall probe only, no body slam
		aim_at(p, t.pos)
		if arch == "archer":
			kit._pin(t.pos, k)
		else:
			kit._coil_hit(t, Vector2(1, 0), k)
		got[k] = _stun_over(m, t, 0.6)
	undo.call()
	var info := "uncharged %.2f s (want %.2f), full %.2f s (want %.2f)" % [got[0.0], span[0], got[1.0], span[1]]
	var near := absf(got[0.0] - float(span[0])) < EPS and absf(got[1.0] - float(span[1])) < EPS
	ok("%s: wall stun scales with the charge" % arch, near and got[1.0] > got[0.0], info)
	await done(m)
=======
>>>>>>> /tmp/o.3691459
