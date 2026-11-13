extends RefCounted
## --range-clamp-check: every ground-targeted RMB, E and X (plus Motley's Trade on Shift) with the cursor at twice
## its range (docs/heroes/range_clamp.md). The source clamps each one to the range edge on the cursor line: never
## refused, never a walk in. So the cast lands on that edge, and the aim preview, where the slot has one, shows the
## same spot. Grimble's Anchor Drop is the control: a cone at his feet that ignores the cursor's distance.

const DT := 1.0 / 60.0
const TOL := 0.2        # m: the widest allowed miss of the range edge (a ground snap, a step of drift)
const FIELD := preload("res://tools/dash_aim_check.gd")       # its _match: a flat cleared field round the player

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RANGECLAMP %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The cursor `k` x range east of P, at chest height.
func _aim_at(P: Hunter, rng: float, k := 2.0) -> void:
	P.inp["aim"] = P.pos + Vector3(rng * k, 0.9, 0)

## Does `p` (a Vector3, or a Vector2 on the flat) sit on the range edge east of `from`?
func _on_edge(p: Variant, from: Vector3, rng: float) -> bool:
	var q := Vector2(p.x, p.z) if p is Vector3 else p as Vector2
	return q.distance_to(Vector2(from.x + rng, from.z)) <= TOL

func _steps(m: Match, n: int) -> void:
	for i in n:
		m.step(DT)

## One slot: the cast point and the preview's spot (null = the slot shows none) against the edge.
func _row(tag: String, from: Vector3, rng: float, cast: Variant, preview: Variant) -> void:
	ok(cast != null and _on_edge(cast, from, rng), "%s: a cursor at 2x range casts on the %.1f m edge" % [tag, rng])
	if preview != null:
		ok(_on_edge(preview, from, rng), "%s: the preview shows the same edge" % tag)

func _at(P: Hunter, id: String, key := "at") -> Variant:
	return AimKit.entry(P, id).get(key)

func vex_r(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var rng := float(K.x_def()["range"])
	_aim_at(P, rng)
	var from := P.pos
	ok(K.cast_ult(), "Vex R: the press casts")
	_steps(m, 2)
	var s: Dictionary = K.ult.shells[-1]
	_row("Vex R Cinderfall", from, rng, s["at"], _at(P, "x%d" % int(s["n"])))

func sparkle(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var reach := float(K.e_def()["reach"])
	_aim_at(P, reach)
	var from := P.pos
	K.use_e()
	_steps(m, 2)
	_row("Sparkle E Skycall", from, reach, K.strikes[0]["at"] if not K.strikes.is_empty() else null, _at(P, "e0"))
	_steps(m, 120)
	var rng := float(K.x_def()["range"])
	_aim_at(P, rng)
	ok(K.cast_ult(), "Sparkle R: the press takes off")
	_steps(m, 40)
	_aim_at(P, rng)
	from = K.ult.leap.get("from", P.pos)
	_steps(m, 2)
	_row("Sparkle R Kitefall", from, rng, K.ult.leap.get("land"), _at(P, "x_aim"))

func kael_rmb_air(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var reach := float(K.rmb_def()["drop"]["reach"])
	P.teleport(P.pos + Vector3(0, 4.0, 0))
	P.grounded = false
	_aim_at(P, reach)
	m.step(DT)
	_aim_at(P, reach)
	var from := P.pos
	var preview: Variant = _at(P, "drop_aim")
	K.press_rmb()
	_row("Kael RMB (air) Meteor Drop", from, reach, K.meteor.land if K.meteor.running() else null, preview)

func lace_e(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var reach := float(K.e_def()["reach"])
	_aim_at(P, reach)
	var from := P.pos
	K.use_e()
	m.step(DT)
	var r: Dictionary = K.rain
	var cast: Variant = null
	if not r.is_empty():
		cast = (r["center"] as Vector3) + Vector3((r["d"] as Vector2).x, 0, (r["d"] as Vector2).y) * float(r["radius"])
	var e := AimKit.entry(P, "e")
	var preview: Variant = null
	if not e.is_empty():
		preview = (e["center"] as Vector2) + (e["dir"] as Vector2) * float(e["radius"])
	_row("Lace E Hail Wall", from, reach, cast, preview)

func meeko_e(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var reach := float(K.e_def()["reach"])
	K.use_e()
	_steps(m, 20)
	_aim_at(P, reach)
	var from := P.pos
	K.use_e()
	_row("Meeko E Hearthlight (thrown)", from, reach, K.hearth.get("to"), null)

func neve(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var rng := float(K.rmb_def()["lance"]["range"])
	_aim_at(P, rng)
	var from := P.pos
	P.inp["sec_hold"] = true
	K.press_rmb()
	_steps(m, 30)
	var preview: Variant = _at(P, "rmb")
	P.inp["sec_hold"] = false
	for i in 120:
		m.step(DT)
		if not K.zones.is_empty():
			break
	_row("Neve RMB Ice Spear", from, rng, K.zones[-1]["at"] if not K.zones.is_empty() else null, preview)
	_steps(m, 200)
	var ed: Dictionary = K.e_def()
	var span := float(ed["reach"]) + float(ed["travel"])
	_aim_at(P, span)
	from = P.pos
	K.use_e()
	m.step(DT)
	var lane := AimKit.entry(P, "e")
	var preview_e: Variant = null
	if not lane.is_empty():
		preview_e = (lane["from"] as Vector2) + (lane["dir"] as Vector2) * float(lane["len"])
	var wall: Variant = null
	if not K.wall_cast.is_empty():
		var d: Vector2 = K.wall_cast["dir"]
		wall = from + Vector3(d.x, 0, d.y) * (float(ed["reach"]) + float(K.wall_cast["travel"]))
	_row("Neve E Rink Wall (where it stops)", from, span, wall, preview_e)

func tenzo_r(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var rng := float(K.x_def()["range"])
	_aim_at(P, rng)
	var from := P.pos
	P.inp["x_down"] = true
	ok(K.cast_ult(), "Tenzo R: the press starts the aim")
	_steps(m, 3)
	_row("Tenzo R Basalt Spine", from, rng, K.spine.center, _at(P, "x"))
	P.inp["x_down"] = false
	_steps(m, 3)

func motley(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var reach := float(K.e_def()["reach"])
	_aim_at(P, reach)
	var from := P.pos
	K.use_e()
	_steps(m, 3)
	_row("Motley E Brimseed", from, reach, K.seed.get("pos"), _at(P, "seed"))
	var rng := float(K.x_def()["range"])
	_aim_at(P, rng)
	ok(K.cast_ult(), "Motley R: the press casts")
	_steps(m, 3)
	_row("Motley R Nightwell", from, rng, K.well.center, _at(P, "x"))
	_steps(m, 400)
	var trade := float(K.dash_def()["reach"])
	_aim_at(P, trade)
	from = P.pos
	P.dashes = P.max_dashes()
	P.inp["dash_down"] = true
	P.do_dash()
	_steps(m, 5)
	var preview: Variant = _at(P, "swap", "b")
	P.inp["dash_down"] = false
	m.step(DT)
	_row("Motley Shift Trade", from, trade, K.swap.get("land"), preview)

func sable_e(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var rng := float(K.e_def()["range"])
	_aim_at(P, rng)
	var from := P.pos
	K.use_e()
	for i in 120:
		m.step(DT)
		if not K.knife.is_empty():
			break
	m.step(DT)
	_row("Sable E Shadow Knife (where it lies)", from, rng, K.knife.get("pos"), _at(P, "knife"))

## The control: Anchor Drop slams a fixed cone from his feet, the cursor only turns it.
func grimble_e(m: Match) -> void:
	var P := m.player
	var K = P.ak
	var r := float(K.e_def()["radius"])
	_aim_at(P, r)
	K.use_e()
	_steps(m, 2)
	var cone := AimKit.entry(P, "e_tell")
	var at_feet: bool = not cone.is_empty() and (cone["from"] as Vector2).distance_to(Vector2(P.pos.x, P.pos.z)) <= TOL
	var what := "Grimble E Anchor Drop: a %.1f m cone at his feet, not at the cursor" % r
	ok(at_feet and is_equal_approx(float(cone["len"]), r), what)

func run(main: Node) -> void:
	Save.no_write = true
	var field = FIELD.new()
	var probes := {
		"gunslinger": vex_r, "mage": sparkle, "juggernaut": kael_rmb_air, "archer": lace_e, "tender": meeko_e,
		"rimewright": neve, "dolm": tenzo_r, "ostra": motley, "thief": sable_e, "dredge": grimble_e,
	}
	for arch in probes:
		var m: Match = field._match(main, arch)
		(probes[arch] as Callable).call(m)
		m.queue_free()
		await main.get_tree().process_frame
	print("RANGECLAMP DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
