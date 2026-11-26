extends RefCounted
## --sparkle-r-spread-check: owner ruling 11-26 on Sparkle's Kitefall (R). The foe the strike lands on (the most
## Static, the nearest on a tie) gains the ult's own stack; every other foe in the strike gains that foe's Static
## + spread_add (3 -> +4, 0 -> +1), capped at the max, the counters set the frame of the strike; a foe outside the
## strike keeps its count. Target at 0/1/2/3 Static with three foes in range and one out, then one in-range foe
## that already has Static (it adds, not raises). Prints SPREAD ok/FAIL lines and a DONE line.

const OUT_STATIC := 2           # the out-of-range foe's Static before every strike (it must not change)
const MAX_FALL_FRAMES := 120    # frames after the second press to wait for the strike (the drop is 0.2 s)

var ac: RefCounted
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SPREAD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("mage", 4.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var home: Vector3 = r[4]
	var K: MageKit = P.ak
	var spot := home + Vector3(5, 0, 0)
	var foes: Array = [r[2], r[3]]
	for i in 3:
		var f: Hunter = m.make_hunter("T%d" % (i + 3), 5, "medium", "Target", "idle", {}, home, {"arch": "none"})
		f.max_hp = 10000.0
		f.hp = f.max_hp
		foes.append(f)
	var xd := K.x_def()
	var mx := int(K.res_def()["max"])
	for n in [0, 1, 2, 3]:
		var got := _strike(m, P, K, foes, spot, [n, 0, 0, 0])
		var want := mini(mx, n + int(xd["spread_add"]))
		ok(got[0] == mini(mx, n + int(xd["stacks"])), "target %d -> %d (its own ult stack)" % [n, got[0]])
		var near: Array = got.slice(1, 4)
		ok(near == [want, want, want], "target %d -> the three in range at %s (want %d)" % [n, near, want])
		ok(got[4] == OUT_STATIC, "target %d -> the one out of range keeps %d (%d)" % [n, OUT_STATIC, got[4]])
	var got := _strike(m, P, K, foes, spot, [2, 1, 0, 0])
	ok(got.slice(0, 4) == [3, mx, 3, 3], "target 2, a foe in range at 1 -> it adds to 4 (%s)" % [got])
	var hit_n: int = K.ult.last.get("hits", 0)
	ok(K.ult.spreads == 15 and hit_n == 4, "arcs drawn %d (3 a strike, 5 strikes), strike hit %d" % [K.ult.spreads, hit_n])
	print("SPREAD CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## One Kitefall at `spot`: foes[0] (the target) nearest the landing, foes[1..3] round it inside the radius, foes[4]
## outside it. `stacks` is the Static on foes[0..3] before the strike; returns every foe's count right after it.
func _strike(m: Match, P: Hunter, K: MageKit, foes: Array, spot: Vector3, stacks: Array) -> Array:
	var xd := K.x_def()
	var r := float(xd["radius"])
	var at := [Vector3(0.3, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3(0, 0, -1.2), Vector3(r + 3.0, 0, 0)]
	K.cd["x"] = 0.0
	P.ult = 0.0
	P.teleport(spot - Vector3(5, 0, 0))
	K.sparks.clear()
	for i in foes.size():
		ac.fresh(foes[i])
		foes[i].teleport(spot + at[i])
	for i in stacks.size():
		if stacks[i] > 0:
			K.add_spark(foes[i], stacks[i])
	K.add_spark(foes[4], OUT_STATIC)
	ac.aim_at(P, spot)
	HunterKeys.ult_pressed(P)
	ac.step(m, float(xd["windup"]) + float(xd["rise"]) + float(xd["min_air"]) + 0.05, func(): ac.aim_at(P, spot))
	HunterKeys.ult_pressed(P)
	var hits: int = K.ult.hits
	for _frame in MAX_FALL_FRAMES:      # stop on the strike's own frame: the counters must be set by then
		if K.ult.hits != hits:
			break
		ac.step(m, 1.0 / 60.0)
	var got := foes.map(func(f): return K.spark_n(f))
	ac.step(m, float(xd["after"]) + 0.2)
	return got
