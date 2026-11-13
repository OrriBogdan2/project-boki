extends "res://tools/hero_pair_check.gd"
## Motley's Brimseed globe (for --ostra-combo-check; docs/heroes/ostra.md): at 0, 25, 50 and 100% growth the drawn
## globe's radius equals the radius the pop hits at (rmax at that share of its 6.5 s): a hunter just inside the drawn
## rim is caught and one just outside is not.

const GROWTH := [0.0, 0.25, 0.5, 1.0]      # share of the grow time
const EDGE := 0.1                          # m inside / outside a foe's reach, to tell caught from missed

## Every globe assertion; returns when done (the caller prints the totals).
func globe(main_node: Node) -> void:
	main = main_node
	var r := setup("ostra", 8.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[3]
	var K: OstraKit = P.ak
	var ed: Dictionary = K.e_def()
	var rmax := float(ed["rmax"])
	var grow := float(ed["grow"])
	for g in GROWTH:
		for side in [-1.0, 1.0]:
			if not K.seed.is_empty(): K._pop(false)
			K.cd["e"] = 0.0
			T.teleport(home + Vector3(8.0, 0, 0))
			fresh(T)
			aim_at(P, T.pos)
			K.cast_e()
			# (a recast before min_recast is eaten; 0.3 s is still the starting speck)
			step(m, maxf(grow * g, float(ed["min_recast"])) + DT)
			var vis: Node3D = K.seed["vis"]
			var want := HeroZones.seed_r(rmax, grow, float(K.seed["t"]))
			if side < 0.0:
				var shown := vis.scale.x
				ok(
					"globe %d%%: drawn radius %.2f = hit radius %.2f" % [g * 100.0, shown, K.seed_radius()],
					absf(shown - K.seed_radius()) < 0.001 and absf(want - K.seed_radius()) < 0.001
					and is_equal_approx(vis.scale.y, shown) and is_equal_approx(vis.scale.z, shown),
					"vis %s" % vis.scale
				)
			var reach: float = K.seed_radius() + float(T.r) + EDGE * side
			T.teleport(K.seed["pos"] + Vector3(reach, 0, 0))
			K.e_recast()
			step(m, 0.1)
			var inside: bool = side < 0.0
			var where := "inside" if inside else "outside"
			var verdict := "hit" if inside else "missed"
			ok(
				"globe %d%%: a hunter %.1fm %s the rim is %s" % [g * 100.0, EDGE, where, verdict],
				(dmg(T) > 0.0) == inside, "dmg %.1f" % dmg(T)
			)
	ok("globe: full growth is the full rmax", absf(HeroZones.seed_r(rmax, grow, grow) - rmax) < 0.001)
	ok("globe: a fresh seed is a speck, not nothing", HeroZones.seed_r(rmax, grow, 0.0) > 0.0)
