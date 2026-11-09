extends RefCounted
## --aimkit-check: the shared aiming kit (docs/AIMKIT.md, scripts/match/aim/). The aim-mode math
## (cursor clamped to range vs always max range, the per-shot override through Hunter._emit_shot, the
## boom default kept), every telegraph shape shown, updated, expired and hidden, who sees what, the
## membership tests, the cursor's ground at terrace lips and cliffs (AimMode.ray_ground), pooling (no node
## growth over 300 frames of every shape), the cursor states (charge ring, full flare, perfect star) and the
## merge-start cleanup through ArchKit.drop_holds().
## With --shots-dir=<dir>: one screenshot per telegraph and cursor state (aimkit_*.png), and the cursor at
## two terrace lips (aimkit_tier_*.png).

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
	_membership()
	_tiers(m, P)
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

func _all_shapes(P: Hunter, k: float, T: Hunter) -> void:
	AimKit.lane(P, "lane", {"len": 8.0, "len0": 2.0, "k": k, "width": 1.0, "width_to": 0.3, "chevrons": 3, "tip": true})
	AimKit.dotted(P, "dotted", {"len": 9.0})
	AimKit.vee(P, "vee", {"k": k, "glint": 0.4})
	AimKit.cone(P, "cone", {"from": T.pos, "dir": Vector2(-1, 0), "len": 6.0, "deg": 100.0, "fill": k})
	AimKit.circle(P, "circle", {"r": 1.35, "ticks": true, "star": true, "fill": k, "pointer": Vector2(0, 1)})
	AimKit.sweet(P, "sweet", {"self": true, "k": k})
	AimKit.arc_wall(P, "arc")
	AimKit.swap(P, "swap", {"fill": k})
	AimKit.line(P, "line")
	AimKit.span(P, "span", {"len": 10.0})
	AimKit.star(P, "star")

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

## The cursor's ray at the game camera's 66 degree pitch, aimed so it first touches `at`.
func _ray(at: Vector3) -> Array:
	var d := Vector3(0, -sin(deg_to_rad(66.0)), -cos(deg_to_rad(66.0)))
	return [at - d * 30.0, d]

## The strip north of z0 (rows z < z0) raised or lowered to `lv` (data only: the check runs headless).
func _terrace(m: Match, P: Hunter, z0: int, lv: int) -> void:
	var W = m.world
	var hx := int(floor(P.pos.x))
	for z in range(z0 - 6, z0):
		for x in range(hx - 4, hx + 5):
			W.level[W.idx(x, z)] = lv

## The cursor's ground at terraces: the first ground its ray meets, on that ground (the old cut at chest
## height, nudged twice by the ground there, put a cast on the wrong tier behind a lip, gave the upper tier
## the lower one's height just past a lip, and stopped looking more than 3 tiers away).
func _tiers(m: Match, P: Hunter) -> void:
	var W = m.world
	var lv := int(round(P.pos.y / World.LEVEL))
	var z0 := int(floor(P.pos.z)) - 2      # the lip: rows north of it are the other terrace
	var y0 := lv * World.LEVEL
	var x := P.pos.x + 0.3
	var flat := Vector3(x, y0, P.pos.z - 1.0)
	var g := AimMode.ray_ground(W, _ray(flat), P.pos.y)
	ok("tier: flat ground is the ground point under the cursor", g.distance_to(flat) < 0.05, str(g - flat))
	_terrace(m, P, z0, lv + 1)
	var up := Vector3(x, y0 + World.LEVEL, z0 - 0.2)
	g = AimMode.ray_ground(W, _ray(up), P.pos.y)
	ok("tier: one up, just past the lip: the upper tier at the cursor", g.distance_to(up) < 0.05, str(g - up))
	g = AimMode.ray_ground(W, _ray(Vector3(x, y0 + 0.4, z0)), P.pos.y)
	var on_lip := absf(g.y - up.y) < 0.01 and absf(g.z - z0) < 0.1
	ok("tier: on the cliff face: the top of that cliff, at its lip", on_lip, str(g))
	_terrace(m, P, z0, lv - 1)
	var down := Vector3(x, y0 - World.LEVEL, z0 - 0.6)
	g = AimMode.ray_ground(W, _ray(down), P.pos.y)
	ok("tier: one down, behind the lip you stand on: the lower tier", g.distance_to(down) < 0.05, str(g - down))
	g = AimMode.ray_ground(W, _ray(Vector3(x, y0 - World.LEVEL, z0 - 0.1)), P.pos.y)
	ok("tier: lower ground hidden by the lip: the lip you see", absf(g.y - y0) < 0.01 and g.z >= z0, str(g))
	_terrace(m, P, z0, lv + 4)
	var tall := Vector3(x, y0 + 4.0 * World.LEVEL, z0 - 1.0)
	g = AimMode.ray_ground(W, _ray(tall), P.pos.y)
	ok("tier: four up (past the old 3-tier cut): the top at the cursor", g.distance_to(tall) < 0.05, str(g - tall))
	P.inp["aim"] = Vector3(g.x, P.pos.y + 0.95, g.z)
	var at := AimMode.point(P, 12.0)
	ok("tier: a ground cast there lands on that top", at.distance_to(tall) < 0.05, str(at - tall))
	_terrace(m, P, z0, lv)
	ok("tier: over the abyss: none", AimMode.ray_ground(W, _ray(Vector3(-50, 0, -50)), P.pos.y) == Vector3.INF)

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
