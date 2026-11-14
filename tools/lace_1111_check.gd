extends "res://tools/pin_bjorn_owner_check.gd"
## --lace-1111-check: the owner's 11-11 playtest on Lace, on the training strip of --archer-combo-check.
## RMB: the Heavy Shot's needle rides her nock point, its bar and the shot leave the bow's mouth (the model's
## bow anchor in the draw pose, not her middle), toward the cursor, and the copy other players' games spawn
## (the Net "s" event) starts there too. Shift: the roll goes 12.5% further in the same time (the felt
## distance is --move-feel-check's KIT_DASH row). E and her aim lines: her crimson, no pink anywhere in her
## kit's colours, and laced: the Hail Wall is red thread criss-crossing between its needle posts and across
## its ground (no glowing panels or band), the draw reticle, the Heavy Shot bar and the E arc are AimKit
## "lace" lines. Prints AKCHECK lines like --archetype-check.

const ROLL_WAS := 3.0          # m: the roll before the owner's note (the footage's 3 m)
const ROLL_K := 1.125          # owner 11-11: "10-15% further"
const ROLL_T := 0.27           # s: the roll's time, kept (the timing feel stays)

func run(main_node: Node) -> void:
	main = main_node
	main_node.set_meta("lace_1111_check", self)
	await lace()
	print("AKCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func lace() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: ArcherKit = P.ak
	P.equip("longbow", 0)
	step(m, 0.3)
	_heavy_from_the_bow(m, P, T, K, home)
	_roll(K)
	_no_pink(K)
	_reticle_laced(m, P, T, K)
	_hail_laced(m, P, T, K, home)
	await done(m)

## Pink: a magenta-to-rose hue, or a red washed pale (what lightening her crimson gives).
static func pinkish(c: Color) -> bool:
	if c.s < 0.15:
		return false
	var rose := c.h > 0.75 and c.h < 0.96
	var pale_red := (c.h >= 0.96 or c.h < 0.03) and c.s < 0.6 and c.v > 0.75
	return rose or pale_red

static func red(c: Color) -> bool:
	return (c.h >= 0.96 or c.h < 0.03) and c.s >= 0.6

# ------------------------------------------------------------------ RMB: from the bow
func _heavy_from_the_bow(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3) -> void:
	fresh(T)
	T.teleport(home + Vector3(7.0, 0, 0))
	K.cd["rmb"] = 0.0
	var hold := rmb_at.bind(P, T.pos)
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.5, hold)
	var n := K.needle
	var nock := HeroVfx.of(m).anchor_pos(P, "nock")
	ok("RMB needle: nocked on her nock point (the model's anchor) while it winds up",
		n.visible and n.eye.distance_to(nock) < 0.01, "eye %s nock %s" % [str(n.eye), str(nock)])
	var bow := K.bow_mouth()
	var bar := AimKit.entry(P, "rmb_bar")
	ok("RMB bar: starts at the bow's mouth, laced, in her red",
		AimKit.shown(P, "rmb_bar")
			and (bar.get("from", Vector2.ZERO) as Vector2).distance_to(Vector2(bow.x, bow.z)) < 0.05
			and bool(bar.get("lace", false)) and red(bar.get("col", Color.WHITE)),
		"from %s bow %s" % [str(bar.get("from")), str(bow)])
	step(m, 0.7, hold)
	bow = K.bow_mouth()
	m.net_on = true                # (only to read the event the other games get; no peer is connected)
	Net.out_events.clear()
	P.inp["sec_hold"] = false
	m.step(DT)
	m.net_on = false
	var sh: Dictionary = {}
	for i in range(m.shots.size() - 1, -1, -1):
		if m.shots[i]["by"] == P:
			sh = m.shots[i]
			break
	var start: Vector3 = sh.get("start", Vector3(999, 0, 999))
	var v: Vector2 = sh.get("vel", Vector2.ZERO)
	var to_cursor := Vector2(T.pos.x - bow.x, T.pos.z - bow.z).normalized()
	ok("RMB shot: leaves the bow's mouth at the release frame and flies bow -> cursor",
		start.distance_to(bow) < 0.05 and v.normalized().distance_to(to_cursor) < 0.03,
		"start %s bow %s" % [str(start), str(bow)])
	var bow_node := WardenGlb.anchor(P.model, "anchor_bow_root")
	ok("RMB shot: the bow's mouth is the model's own bow anchor (it rides the bow in the pose), at bow height",
		bow_node != null and bow_node.global_position.distance_to(bow) < 0.01
			and bow.y > P.pos.y + 0.7 and bow.y < P.pos.y + 1.8,
		"bow - body %s" % str(bow - P.pos))
	var sent := Vector3(999, 0, 999)
	for e in Net.out_events:
		if e is Array and String(e[0]) == "s":
			sent = Vector3(float(e[1]), float(e[2]), float(e[3]))
	Net.out_events.clear()
	# (Match's "s" receiver spawns the copy exactly at these numbers: what other players see)
	ok("RMB online: the shot other players' games spawn starts at the bow too",
		sent.distance_to(bow) < 0.05, "sent %s bow %s" % [str(sent), str(bow)])
	var moves: Dictionary = HeroVfx.data("archer")["moves"]
	var at_feet := ""
	for layer in (moves["heavy_go"] as Dictionary).get("fx", []):
		if String(layer.get("at", "")) == "h":
			at_feet += String(layer["p"]) + " "
	ok("RMB release: no burst sits on her body (heavy_go's bursts ride the bow)",
		at_feet == "", at_feet)
	step(m, 1.5)

# ------------------------------------------------------------------ Shift
func _roll(K: ArcherKit) -> void:
	var dd := K.dash_def()
	var what := "Shift: the roll goes 12.5%% further (%.3f -> %.3f m) in the same %.2f s"
	ok(what % [ROLL_WAS, ROLL_WAS * ROLL_K, ROLL_T],
		is_equal_approx(float(dd["roll"]), ROLL_WAS * ROLL_K) and is_equal_approx(float(dd["roll_t"]), ROLL_T),
		"roll %.3f roll_t %.2f" % [float(dd["roll"]), float(dd["roll_t"])])

# ------------------------------------------------------------------ no pink
func _no_pink(K: ArcherKit) -> void:
	var bad: Array = []
	var pal: Dictionary = HeroVfx.data("archer")["palette"]
	for key in pal:
		if pinkish(Color(String(pal[key]))): bad.append("palette %s %s" % [key, pal[key]])
	var d := Arch.def("archer")
	if pinkish(Color(String(d["color"]))): bad.append("color " + String(d["color"]))
	for slot in ["dash", "rmb", "e", "x"]:
		var col := String((d[slot] as Dictionary).get("col", "#ffffff"))
		if pinkish(Color(col)): bad.append("%s col %s" % [slot, col])
	for c in [PinFx.THREAD, PinFx.PALE, PinFx.DEEP]:
		if pinkish(c): bad.append("PinFx " + c.to_html(false))
	ok("colours: nothing of her kit is pink (palette, ability colours, PinFx)", bad.is_empty(), str(bad))
	ok("colours: her thread is her laces' crimson, set by the kit (not the model's tint)",
		red(PinFx.THREAD) and Color(String(d["color"])) == PinFx.THREAD and red(K.col_of(K.e_def())),
		PinFx.THREAD.to_html(false))

# ------------------------------------------------------------------ the draw reticle
func _reticle_laced(m: Match, P: Hunter, T: Hunter, K: ArcherKit) -> void:
	step(m, 0.2, func(): aim_at(P, T.pos))
	var rest := AimKit.entry(P, "draw_rest")
	ok("aim: the resting aim line is laced, in her red", AimKit.shown(P, "draw_rest")
		and bool(rest.get("lace", false)) and red(rest.get("col", Color.WHITE)), str(rest.get("col")))
	step(m, 0.35, press_at.bind(P, T.pos))
	var thin := AimKit.entry(P, "draw")
	var fill := AimKit.entry(P, "draw_fill")
	ok("aim: drawing, the line and its fill are laced and red (no pale pink)",
		bool(thin.get("lace", false)) and bool(fill.get("lace", false))
			and red(thin.get("col", Color.WHITE)) and red(fill.get("col", Color.WHITE)),
		"%s %s" % [str(thin.get("col")), str(fill.get("col"))])
	var geo := AimGeo.new()
	var plain := thin.duplicate()
	plain["lace"] = false
	AimShapes.build(geo, plain)
	var plain_v := geo.v.size()
	geo.reset()
	AimShapes.build(geo, thin)
	ok("aim: a laced line is two crossing strands (more than the plain ribbon, under 12x its triangles)",
		geo.v.size() > plain_v and geo.v.size() < plain_v * 12, "%d vs %d vertices" % [geo.v.size(), plain_v])
	P.inp["fire"] = false
	step(m, 1.0)

# ------------------------------------------------------------------ E: laces
func _hail_laced(m: Match, P: Hunter, T: Hunter, K: ArcherKit, home: Vector3) -> void:
	cast_e_at(P, K, home + Vector3(5.0, 0, 0))
	m.step(DT)
	var arc := AimKit.entry(P, "e")
	ok("E arc: the cast's arc is laced, in her red", bool(arc.get("lace", false)) and red(arc.get("col", Color.WHITE)),
		str(arc.get("col")))
	ok("E: no glowing panels or ground band left on the wall (her laces instead)",
		not "panels" in K.fx and not "glow" in K.fx)
	step(m, float(K.e_def()["tell"]) + 0.1)
	for i in 30:                   # (PinFx draws on the frame clock: step it with the match)
		m.step(DT)
		K.fx._process(DT)
	var shown := 0
	var reds := 0
	for l in K.fx.laces:
		var node: MeshInstance3D = l["node"]
		if node.visible and node.scale.z > 0.3: shown += 1
		var mat := node.material_override as ShaderMaterial
		var c: Color = mat.get_shader_parameter("albedo") if mat != null else Color.WHITE
		if red(c) and not pinkish(c): reds += 1
	ok("E laces: every gap between the needle posts laced (an upright X and a ground X), all drawn across",
		shown == K.fx.laces.size() and shown == (PinFx.POSTS - 1) * 4, "%d of %d" % [shown, K.fx.laces.size()])
	ok("E laces: red thread, none of it pink", reds == K.fx.laces.size(), "%d red" % reds)
	var up_a: Dictionary = K.fx.laces[0]
	var up_b: Dictionary = K.fx.laces[1]
	ok("E laces: the upright pair crosses (one climbs as the other falls)",
		(up_a["b"] as Vector3).y > (up_a["a"] as Vector3).y and (up_b["b"] as Vector3).y < (up_b["a"] as Vector3).y)
	for i in int((float(K.e_def()["time"]) + 0.3) / DT):
		m.step(DT)
		K.fx._process(DT)
	ok("E laces: gone when the wall ends", not K.fx.laces.any(func(l): return (l["node"] as Node3D).visible))
