extends RefCounted
## Grimble's scattergun by range, for --dredge-combo-check (docs/heroes/dredge.md, "Scattergun by range"):
## one rested volley at a dummy 2 m, 6 m and at the slugs' stop range. The source has 7 slugs and no damage
## falloff with range (only the fixed stop range), so a volley is the same total whatever the distance, shared
## by the pellet rule (the first slug on a target does `pellet_floor` of the volley, the rest split the
## remainder); only how many slugs land changes.

const FACE_TOWARD := -PI / 2.0      # a target east of Grimble facing this way shows him its front

var ak = null
var ok_fn: Callable

func _init(arch_check, ok_cb: Callable) -> void:
	ak = arch_check
	ok_fn = ok_cb

func run() -> void:
	var r: Array = ak.setup("dredge", 2.0, "", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	P.wpn = P.wpn.duplicate()
	P.wpn["aimed_first"] = false      # the fan itself: the opening volley is aimed (aimed_first), the rest fan
	var w: Dictionary = P.wpn
	var pel := int(w["pellets"])
	var full: float = float(w["dmg"]) * pel * m.dmg_mult(P)
	var stop: float = float(w["range"])
	var hit_r: float = T.r + float(w["size"])
	var fan: float = float(w["fan_deg"])
	var shape_ok: bool = pel == 7 and absf(stop - 6.3) < 0.01 and absf(fan - 20.0) < 0.01
	shape_ok = shape_ok and absf(fan + float(w["bloom_max_deg"]) - 30.0) < 0.01
	var shape := "%d slugs, stop %.1f m, fan %.0f degrees" % [pel, stop, fan]
	ok_fn.call("gun range: 7 slugs, stop 6.3 m, a fan of 20 degrees at rest, 30 at most", shape_ok, shape)
	for d: float in [2.0, 6.0, stop - 0.1]:
		var landed := 0                   # the slugs whose line passes within the dummy's reach at this distance
		for i in pel:
			var off := deg_to_rad(fan) * (float(i) / float(pel - 1) - 0.5)
			if absf(d * tan(off)) <= hit_r: landed += 1
		var floor_k: float = float(w["pellet_floor"])
		var want := full * (floor_k + (landed - 1) * (1.0 - floor_k) / float(pel - 1))
		ak.fresh(T)
		T.teleport(home + Vector3(d, 0, 0))
		T.face = FACE_TOWARD
		P.wbloom = 0.0
		P.fire_cd = 0.0
		ak.aim_at(P, T.pos)
		P.inp["fire"] = true
		ak.step(m, ak.DT)
		P.inp["fire"] = false
		ak.step(m, 0.8)
		var got: float = ak.dmg(T)
		var label := "gun range: a volley at %.1f m lands %d of 7 slugs for %.1f of the %.1f volley, no falloff"
		ok_fn.call(label % [d, landed, want, full], landed >= 1 and absf(got - want) < 0.15, "got %.2f" % got)
	await ak.done(m)
