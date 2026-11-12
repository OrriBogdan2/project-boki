extends RefCounted
## --aimkit-check: the shared aiming kit (docs/AIMKIT.md, scripts/match/aim/). The aim-mode math
## (cursor clamped to range vs always max range, the per-shot override through Hunter._emit_shot, the
## boom default kept), every telegraph shape shown, updated, expired and hidden, who sees what, the
## membership tests, pooling (no node growth over 300 frames of every shape), the cursor states (charge
## ring, full flare, perfect star) and the merge-start cleanup through ArchKit.drop_holds().
## With --shots-dir=<dir>: one screenshot per telegraph and cursor state (aimkit_*.png).

var main: Node
var fails := 0
var n := 0
var ak = null
const DT := 1.0 / 60.0

func ok(name: String, cond: bool, info := "") -> void:
	n += 1
	print("AIMKIT %-58s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): shots = String(a).substr(12)
	var r: Array = ak.setup("gunslinger", 6.0, "", true)
	var m: Match = r[0]; var P: Hunter = r[1]; var T: Hunter = r[2]
	_aim_modes(m, P, T)
	ak.step(m, 0.5)        # the rounds _aim_modes fired: Vex's firing brackets lapse, so only the shapes below show
	_shapes(m, P, T)
	_seen(m, P, T)
	_net(m, P, T)
	_soft(P)
	_membership()
	_pooling(m, P, T)
	await _reticle(m, P)
	_cleanup(m, P)
	if shots != "":
		m.queue_free()
		await main.get_tree().process_frame
		await load("res://tools/aimkit_shots.gd").new().take(main, shots)
	print("AIMKIT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _aim(P: Hunter, d: float) -> void:
	P.inp["aim"] = P.pos + Vector3(d, 0.9, 0); P.inp["aim_y"] = P.pos.y

## Fire one round and read back how far it will fly (life x speed).
func _shot_dist(m: Match, P: Hunter) -> float:
	var before := m.shots.size()
	P._emit_shot()
	if m.shots.size() <= before:
		return -1.0
	var s: Dictionary = m.shots.back()
	return float(s["life0"]) * (s["vel"] as Vector2).length()

func _aim_modes(m: Match, P: Hunter, _T: Hunter) -> void:
	var rng := float(P.wpn["range"])
	_aim(P, 5.0)
	ok("mode: cursor = the cursor distance inside range", is_equal_approx(AimMode.dist(P, 12.0), 5.0), "%.2f" % AimMode.dist(P, 12.0))
	_aim(P, 20.0)
	ok("mode: cursor past range clamps to range", is_equal_approx(AimMode.dist(P, 12.0), 12.0))
	_aim(P, 0.4)
	ok("mode: point-blank still travels the minimum", is_equal_approx(AimMode.dist(P, 12.0), AimMode.MIN_D))
	var near := AimMode.place(P, 12.0)
	var dx := near.x - P.pos.x
	ok("place: a zone at a 0.4 m cursor lands there, not 1.5 m out", absf(dx - 0.4) < 0.01, "%.2f" % dx)
	AimKit.circle(P, "pl", {"r": 1.0})
	var mark: Vector2 = AimKit.entry(P, "pl")["at"]
	ok("place: the default circle marker sits at the cursor too", absf(mark.x - P.pos.x - 0.4) < 0.01)
	_aim(P, 20.0)
	ok("place: past range clamps to range", absf(AimMode.place(P, 12.0).x - P.pos.x - 12.0) < 0.01)
	_aim(P, 5.0)
	ok("mode: max = always the full range", is_equal_approx(AimMode.dist(P, 12.0, AimMode.MAX), 12.0))
	var pt := AimMode.point(P, 12.0)
	ok("mode: the landing point sits on the aim line at the cursor", Vector2(pt.x - P.pos.x, pt.z - P.pos.z).distance_to(Vector2(5, 0)) < 0.01 and absf(pt.y - P.pos.y) < 0.01, str(pt - P.pos))
	# the weapon defaults stay as they were: a plain gun flies its range, a boom weapon lands at the cursor
	ok("default: a plain gun (quill rifle) is max range", AimMode.mode_of(P) == AimMode.MAX, AimMode.mode_of(P))
	var d0 := _shot_dist(m, P)
	ok("default: the rifle round flies its full range past a 5 m cursor", absf(d0 - rng) < 0.05, "%.2f of %.2f" % [d0, rng])
	P.shot_aim = AimMode.CURSOR
	var d1 := _shot_dist(m, P)
	ok("per shot: shot_aim = cursor lands it at the cursor", absf(d1 - 5.0) < 0.05, "%.2f" % d1)
	ok("per shot: the override is taken by that one shot", P.shot_aim == "" and absf(_shot_dist(m, P) - rng) < 0.05)
	_aim(P, 30.0)
	P.shot_aim = AimMode.CURSOR
	ok("per shot: cursor beyond range still stops at range", absf(_shot_dist(m, P) - rng) < 0.05)
	_aim(P, 5.0)
	var w0: Dictionary = P.wpn
	var wb := w0.duplicate(); wb["boom"] = 1.2; wb["boom_kb"] = 2.0
	wb.erase("aim")      # the default rule: a weapon with no "aim" of its own
	P.wpn = wb
	ok("default: a boom weapon is cursor-placed", AimMode.mode_of(P) == AimMode.CURSOR)
	var db := _shot_dist(m, P)
	var sx: Dictionary = m.shots.back()["x"]
	ok("default: the boom round lands at the cursor and keeps its blast", absf(db - 5.0) < 0.05 and float(sx.get("boom", 0.0)) == 1.2, "%.2f" % db)
	P.shot_aim = AimMode.MAX
	ok("per shot: shot_aim = max sends a boom round to full range", absf(_shot_dist(m, P) - rng) < 0.05)
	var wc := w0.duplicate(); wc["aim"] = "cursor"
	P.wpn = wc
	ok("per weapon: \"aim\": \"cursor\" in the weapon data", AimMode.mode_of(P) == AimMode.CURSOR and absf(_shot_dist(m, P) - 5.0) < 0.05)
	P.wpn = w0
	for s in m.shots: s["life"] = 0.0
	m.step(DT)

func _all_shapes(P: Hunter, k: float, T: Hunter, all := false) -> void:
	var a := {"all": all}
	var lp := {"len": 8.0, "len0": 2.0, "k": k, "width": 1.0, "width_to": 0.3, "chevrons": 3, "tip": true}
	AimKit.lane(P, "lane", a.merged(lp))
	AimKit.dotted(P, "dotted", a.merged({"len": 9.0}))
	AimKit.vee(P, "vee", a.merged({"k": k, "glint": 0.4}))
	AimKit.cone(P, "cone", a.merged({"from": T.pos, "dir": Vector2(-1, 0), "len": 6.0, "deg": 100.0, "fill": k}))
	AimKit.circle(P, "circle", a.merged({"r": 1.35, "ticks": true, "star": true, "fill": k, "pointer": Vector2(0, 1)}))
	AimKit.sweet(P, "sweet", a.merged({"self": true, "k": k}))
	AimKit.arc_wall(P, "arc", a)
	AimKit.swap(P, "swap", a.merged({"fill": k}))
	AimKit.line(P, "line", a)
	AimKit.span(P, "span", a.merged({"len": 10.0}))
	AimKit.star(P, "star", a)

const IDS := ["lane", "dotted", "vee", "cone", "circle", "sweet", "arc", "swap", "line", "span", "star"]

func _shapes(m: Match, P: Hunter, T: Hunter) -> void:
	var L := AimKit.layer(m)
	_aim(P, 6.0)
	_all_shapes(P, 0.5, T)
	L.rebuild()
	ok("show: every shape is up", IDS.all(func(i): return AimKit.shown(P, i)), str(IDS.filter(func(i): return not AimKit.shown(P, i))))
	ok("show: all %d draw for their own player, in one mesh" % IDS.size(), L.built == IDS.size() and L.mi.visible and L.mesh.get_surface_count() == 1, "built %d verts %d" % [L.built, L.geo.v.size()])
	var e := AimKit.entry(P, "lane")
	ok("lane: grows len0 -> len and narrows width -> width_to with k", is_equal_approx(float(e["len"]), 5.0) and is_equal_approx(float(e["width"]), 0.65), "len %.2f width %.2f" % [e["len"], e["width"]])
	var v := AimKit.entry(P, "vee")
	ok("vee: half open at k 0.5 (25 deg -> 6.25 deg a side), not merged", is_equal_approx(rad_to_deg(float(v["half"])), 6.25) and not v["merged"], "%.2f" % rad_to_deg(float(v["half"])))
	var sw := AimKit.entry(P, "sweet")
	ok("sweet: the sweet spot grows 0.5 -> 1 bh (0.9 -> 1.8 m)", is_equal_approx(float(sw["core"]), 1.35) and is_equal_approx(float(sw["r"]), 4.5), "core %.2f r %.2f" % [sw["core"], sw["r"]])
	ok("arc: radius defaults to the cursor distance", is_equal_approx(float(AimKit.entry(P, "arc")["radius"]), 6.0))
	var c := AimKit.entry(P, "circle")
	ok("circle: lands on the cursor point", (c["at"] as Vector2).distance_to(Vector2(P.pos.x + 6.0, P.pos.z)) < 0.01)
	ok("colour: the hero colour by default", (e["col"] as Color).is_equal_approx(AimKit.hero_col(P)) and AimKit.hero_col(P).is_equal_approx(Color(String(Arch.def("gunslinger")["color"]))))
	# update: the same id again replaces it
	_all_shapes(P, 1.0, T)
	e = AimKit.entry(P, "lane"); v = AimKit.entry(P, "vee")
	ok("update: the lane is full length, narrowest, hot at k 1", is_equal_approx(float(e["len"]), 8.0) and is_equal_approx(float(e["width"]), 0.3) and float(e["hot"]) == 1.0)
	ok("update: the V has closed into one line", v["merged"] and float(v["half"]) == 0.0)
	AimKit.lane(P, "lane", {"len": 3.0, "col": Color.RED})
	e = AimKit.entry(P, "lane")
	ok("update: a per-hero colour through col", (e["col"] as Color).is_equal_approx(Color.RED) and is_equal_approx(float(e["len"]), 3.0))
	ok("update: still one entry per id", L.entries.size() == IDS.size(), "%d" % L.entries.size())
	# hide now, or stop calling and it expires
	AimKit.hide(P, "lane")
	ok("hide: drops it at once", not AimKit.shown(P, "lane") and AimKit.shown(P, "vee"))
	AimKit.circle(P, "held", {"dur": 0.5})
	ak.step(m, 0.25)
	L.rebuild()
	ok("expire: not refreshed for 0.25 s, the per-step shapes are gone", IDS.all(func(i): return not AimKit.shown(P, i)) and L.entries.size() == 1)
	ok("expire: a dur 0.5 telegraph is still up at 0.25 s", AimKit.shown(P, "held"))
	ak.step(m, 0.35)
	L.rebuild()
	ok("expire: and gone after 0.5 s; nothing left drawn", not AimKit.shown(P, "held") and L.entries.is_empty() and not L.mi.visible and L.mesh.get_surface_count() == 0)
	# refreshed every step it stays up
	var t := 0.0
	while t < 0.5:
		AimKit.lane(P, "keep"); m.step(DT); t += DT
	ok("refresh: called every step, it stays up", AimKit.shown(P, "keep"))
	AimKit.hide(P, "keep")

func _seen(m: Match, P: Hunter, T: Hunter) -> void:
	var L := AimKit.layer(m)
	AimKit.lane(T, "aim")                              # a foe's own aim line: theirs only
	AimKit.circle(T, "slam", {"self": true, "all": true, "r": 2.0})
	L.rebuild()
	ok("seen: a foe's aim telegraph isn't drawn for you", AimKit.shown(T, "aim") and L.built == 1)
	var e: Dictionary = AimKit.entry(T, "slam")
	ok("seen: their \"all\" area is drawn, in their own colour", L.built == 1 and (e["col"] as Color).is_equal_approx(AimKit.hero_col(T)))
	AimKit.clear(T)
	L.rebuild()
	ok("clear: drops one hunter's set only", not AimKit.shown(T, "slam") and L.built == 0)

## Net (AimNet, event "tele"): every shape kind of a local hunter's `all` telegraph goes out once per
## SEND_GAP, crosses the wire as JSON and draws on the other game under its remote copy as the caster drew
## it; the caster's hide drops it there; aim reticles, echoes and events naming a local hunter stay put.
func _net(m: Match, P: Hunter, T: Hunter) -> void:
	var L := AimKit.layer(m)
	AimNet.capture = true
	AimNet.sent_log.clear()
	_aim(P, 6.0)
	_all_shapes(P, 0.5, T, true)
	AimKit.lane(P, "aim")
	var ids := {}
	for ev in AimNet.sent_log: ids[String(ev[2])] = ev
	ok("net: one \"tele\" event per all telegraph, none for the aim lane", AimNet.sent_log.size() == IDS.size()
		and ids.size() == IDS.size() and not ids.has("aim"), "%d sent" % AimNet.sent_log.size())
	var t := 0.0
	while t < 0.5 - 0.001:
		m.time += DT      # the clock only: a real step here moves the match the pool check counts
		t += DT
		_all_shapes(P, 0.5, T, true)
	var per := AimNet.sent_log.size() / float(IDS.size())
	var each := "%.1f sends each" % per
	ok("net: refreshed every step for 0.5 s, it goes out about every 0.1 s", per >= 4.0 and per <= 7.0, each)
	var wire: Array = []
	for id in ids:
		var ev: Array = (AimNet.sent_log.filter(func(x): return String(x[2]) == id) as Array).back().duplicate()
		ev[1] = T.nid
		wire.append(JSON.parse_string(JSON.stringify(ev)))
	AimNet.net_in(m, wire[0])
	ok("net: an event naming a hunter this game runs is ignored", not AimKit.shown(T, String(wire[0][2])))
	T.remote = true
	var before := AimNet.sent_log.size()
	for ev in wire: AimNet.net_in(m, ev)
	ok("net: the remote copy's entries are not sent back", AimNet.sent_log.size() == before)
	for id in IDS:
		var mine := AimKit.entry(P, id)
		var theirs := AimKit.entry(T, id)
		var off := _unlike(mine, theirs)
		ok("net %s: shows on the other game as the caster drew it" % String(mine.get("kind", id)), off == "", off)
	ok("net: a received one outlives its keep by AimNet.LAG", is_equal_approx(float(AimKit.entry(T, "lane")["keep"]),
		float(AimKit.entry(P, "lane")["keep"]) + AimNet.LAG))
	L.rebuild()
	ok("net: both sets draw, the caster's and the remote copy's", L.built == 2 * IDS.size(), "built %d" % L.built)
	AimNet.sent_log.clear()
	AimKit.hide(P, "lane")
	L.rebuild()
	var drop: Array = AimNet.sent_log.filter(func(x): return x.size() == 3 and String(x[2]) == "lane")
	ok("net: the caster's hide sends the drop", drop.size() == 1)
	if drop.size() == 1:
		AimNet.net_in(m, ["tele", T.nid, "lane"])
	ok("net: the drop takes it off the other game", not AimKit.shown(T, "lane") and AimKit.shown(T, "cone"))
	T.remote = false
	AimKit.clear(P)
	AimKit.clear(T)
	L.rebuild()
	AimNet.capture = false
	AimNet.sent_log.clear()

## "" when every drawn key of `b` matches `a` (to the wire's rounding), else the first that does not.
func _unlike(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return "missing (%s / %s)" % [a.size(), b.size()]
	for k in a:
		if k in AimNet.LOCAL or k == "keep":
			continue
		if not b.has(k):
			return "%s: missing" % k
		var x = a[k]
		var y = b[k]
		var same: bool
		match typeof(x):
			TYPE_VECTOR2: same = y is Vector2 and (x as Vector2).distance_to(y) < 0.002
			TYPE_COLOR: same = y is Color and (x as Color).to_html(true) == (y as Color).to_html(true)
			TYPE_FLOAT, TYPE_INT: same = absf(float(x) - float(y)) < 0.002
			_: same = x == y
		if not same:
			return "%s: %s vs %s" % [k, x, y]
	return ""

## "soft" lanes and cones: the inside stays at or under AimShapes.SOFT_A even fully filled; the rim is lit.
func _soft(P: Hunter) -> void:
	AimKit.lane(P, "soft_lane", {"len": 7.0, "width": 2.2, "k": 1.0, "fill": 1.0, "soft": true, "tip": true})
	AimKit.cone(P, "soft_cone", {"len": 4.0, "deg": 70.0, "inner": 0.0, "fill": 1.0, "soft": true, "all": true})
	var lane := measure(AimKit.entry(P, "soft_lane"), 0.6, 1.08)
	var cone := measure(AimKit.entry(P, "soft_cone"), 0.6, 3.98)
	ok("soft lane: inside <= %.2f at the centre, rim lit (%.2f / %.2f)" % [AimShapes.SOFT_A, lane[0], lane[1]],
			lane[0] > 0.0 and lane[0] <= AimShapes.SOFT_A + 0.001 and lane[1] >= 0.5)
	ok("soft cone: inside <= %.2f at the centre, arc lit (%.2f / %.2f)" % [AimShapes.SOFT_A, cone[0], cone[1]],
			cone[0] > 0.0 and cone[0] <= AimShapes.SOFT_A + 0.001 and cone[1] >= 0.5)
	AimKit.hide(P, "soft_lane")
	AimKit.hide(P, "soft_cone")

## [the drawn alpha at the shape's centre line `at` of the way along it, the alpha `edge` m out from the
## middle] for a lane or cone entry `e` (its sideways edge for a lane, along the aim for a cone).
static func measure(e: Dictionary, at: float, edge: float) -> Array:
	if e.is_empty():
		return [-1.0, -1.0]
	var g := AimGeo.new()
	AimShapes.build(g, e)
	var o: Vector2 = e["from"]
	var u: Vector2 = e["dir"]
	var mid := o + u * float(e["len"]) * at
	var rim := mid + Vector2(-u.y, u.x) * edge if e["kind"] == "lane" else o + u * edge
	return [alpha_at(g, mid), alpha_at(g, rim)]

## The alpha the triangles of `g` stack to over ground point `p` (each blended over the last).
static func alpha_at(g: AimGeo, at: Vector2) -> float:
	var p := at + Vector2(0.0013, 0.0007)        # off the shared triangle edges, so none counts twice
	var clear := 1.0
	for i in range(0, g.v.size(), 3):
		var a := Vector2(g.v[i].x, g.v[i].z)
		var b := Vector2(g.v[i + 1].x, g.v[i + 1].z)
		var c := Vector2(g.v[i + 2].x, g.v[i + 2].z)
		var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(den) < 1e-9:
			continue
		var wa := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / den
		var wb := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / den
		if wa < 0.0 or wb < 0.0 or wa + wb > 1.0:
			continue
		clear *= 1.0 - clampf(g.c[i].a * wa + g.c[i + 1].a * wb + g.c[i + 2].a * (1.0 - wa - wb), 0.0, 1.0)
	return 1.0 - clear

func _membership() -> void:
	var o := Vector3.ZERO
	ok("in_lane: inside / beside / past the end", AimMode.in_lane(o, Vector2(1, 0), 6.0, 1.0, Vector3(3, 0, 0.4)) and not AimMode.in_lane(o, Vector2(1, 0), 6.0, 1.0, Vector3(3, 0, 0.6)) and not AimMode.in_lane(o, Vector2(1, 0), 6.0, 1.0, Vector3(6.5, 0, 0)))
	ok("in_cone: inside the angle, outside it, past the length", AimMode.in_cone(o, Vector2(1, 0), 4.0, 60.0, Vector3(2, 0, 1.0)) and not AimMode.in_cone(o, Vector2(1, 0), 4.0, 60.0, Vector3(1, 0, 1.0)) and not AimMode.in_cone(o, Vector2(1, 0), 4.0, 60.0, Vector3(4.5, 0, 0)))
	ok("in_arc: on the band, inside it, beyond the ends", AimMode.in_arc(o, Vector2(1, 0), 5.0, 120.0, 0.9, Vector3(0, 0, 5.0).rotated(Vector3.UP, PI * 0.5 + 0.3)) and not AimMode.in_arc(o, Vector2(1, 0), 5.0, 120.0, 0.9, Vector3(3.8, 0, 0)) and not AimMode.in_arc(o, Vector2(1, 0), 5.0, 120.0, 0.9, Vector3(-5, 0, 0)))
	ok("in_circle", AimMode.in_circle(Vector3(2, 0, 0), 1.0, Vector3(2.5, 3, 0.5)) and not AimMode.in_circle(Vector3(2, 0, 0), 1.0, Vector3(3.2, 0, 0)))

func _count(nd: Node) -> int:
	var c := 1
	for ch in nd.get_children(): c += _count(ch)
	return c

func _pooling(m: Match, P: Hunter, T: Hunter) -> void:
	var L := AimKit.layer(m)
	_all_shapes(P, 0.0, T)
	L.rebuild(); m.step(DT)
	# the match's own growth over 300 steps with no telegraphs (effect pools filling, queued frees)
	var b0 := _count(m)
	for i in 300:
		_aim(P, 3.0 + 6.0 * absf(sin(i * 0.05)))
		m.step(DT)
	var base := _count(m) - b0
	var before := _count(m)
	var own := _count(L)
	var most := 0
	for i in 300:
		var k := float(i % 90) / 60.0
		_aim(P, 3.0 + 6.0 * absf(sin(i * 0.05)))
		_all_shapes(P, k, T)
		AimKit.charge(P, k)
		if i % 40 == 0: AimKit.perfect(P)
		m.step(DT)
		L.rebuild()
		L.tick_reticle(DT)
		most = maxi(most, L.mesh.get_surface_count())
	var after := _count(m)
	ok("pool: 300 frames of every shape add no nodes to the match", after - before <= maxi(0, base), "%d -> %d (the match alone: %+d)" % [before, after, base])
	ok("pool: the drawer is still its mesh and reticle layer (%d nodes)" % own, _count(L) == own and own <= 4)
	ok("pool: one surface at most, ever", most == 1)
	ok("pool: one drawer per match", m.get_children().filter(func(c): return c is AimDraw).size() == 1)
	AimKit.clear(P)

func _reticle(m: Match, P: Hunter) -> void:
	var L := AimKit.layer(m)
	AimKit.clear(P)
	ok("reticle: none to start", AimKit.reticle(P)["charge"] < 0.0)
	AimKit.charge(P, 0.4)
	var r := AimKit.reticle(P)
	ok("charge ring: holds the charge", is_equal_approx(float(r["charge"]), 0.4) and float(r["flare"]) == 0.0)
	m.step(DT)
	AimKit.charge(P, 1.0)
	r = AimKit.reticle(P)
	ok("full flare: reaching full fires the flare", float(r["flare"]) > 0.0 and is_equal_approx(float(r["charge"]), 1.0))
	L.tick_reticle(0.1)
	AimKit.charge(P, 1.0)
	ok("full flare: once, not again while held full", float(AimKit.reticle(P)["flare"]) < AimReticle.FLARE_T - 0.05)
	L.tick_reticle(AimReticle.FLARE_T)
	ok("full flare: fades out", float(AimKit.reticle(P)["flare"]) == 0.0)
	AimKit.perfect(P)
	ok("perfect: the star flashes", float(AimKit.reticle(P)["perfect"]) > 0.0)
	await main.get_tree().process_frame
	L.tick_reticle(AimReticle.PERFECT_T + 0.01)
	ok("perfect: gone after one footage frame (%.2f s)" % AimReticle.PERFECT_T, float(AimKit.reticle(P)["perfect"]) == 0.0)
	ok("perfect: the flash is short", AimReticle.PERFECT_T <= 0.15)
	ak.step(m, 0.2)
	L.tick_reticle(0.2)
	ok("charge ring: not refreshed, it goes", AimKit.reticle(P)["charge"] < 0.0)

func _cleanup(m: Match, P: Hunter) -> void:
	var L := AimKit.layer(m)
	_all_shapes(P, 0.5, P)
	AimKit.circle(P, "long", {"dur": 5.0})
	AimKit.charge(P, 0.7); AimKit.perfect(P)
	P.ak.drop_holds()
	L.rebuild()
	var r := AimKit.reticle(P)
	ok("drop_holds: every telegraph goes (dur ones too)", IDS.all(func(i): return not AimKit.shown(P, i)) and not AimKit.shown(P, "long") and L.built == 0)
	ok("drop_holds: and the cursor states", r["charge"] < 0.0 and float(r["perfect"]) == 0.0 and float(r["flare"]) == 0.0)
	# however a merge starts (KinMerge calls the kit's own _drop_holds on some paths), a merged hunter shows nothing
	_all_shapes(P, 0.5, P)
	AimKit.circle(P, "long", {"dur": 5.0})
	AimKit.charge(P, 0.7)
	P.merge_st = {"phase": "xform"}
	L.rebuild(); L.tick_reticle(0.0)
	var none: bool = IDS.all(func(i): return not AimKit.shown(P, i)) and not AimKit.shown(P, "long") and L.built == 0 and AimKit.reticle(P)["charge"] < 0.0
	AimKit.lane(P, "lane"); AimKit.perfect(P)
	L.rebuild()
	ok("merge: a merging hunter's telegraphs and cursor states go, and new ones don't show", none and not AimKit.shown(P, "lane") and float(AimKit.reticle(P)["perfect"]) == 0.0 and L.entries.is_empty())
	P.merge_st = {}
	# the base kit runs drop_holds every step while merged (ArchKit.tick); every kit's override runs first
	var src := FileAccess.get_file_as_string("res://scripts/arch/arch_kit.gd")
	ok("drop_holds: ArchKit's own merge paths call drop_holds, not _drop_holds", src.count("\t\tdrop_holds()") >= 2 and not src.contains("\t\t_drop_holds()"))
