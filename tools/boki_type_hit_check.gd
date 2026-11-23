extends RefCounted
## --boki-type-hit-check: a Boki's hit lands in its own type colour (Juice.flash_col -> DexView.type_col, the
## Field Book colour), whatever it strikes: ember is orange, tempest teal, frost icy blue, and so on. A hit that
## is not a Boki's keeps the flash by target kind (a Hunter's white).
## Reads the flash and the spark (the type colour lightened as Fx.impact does) the hit started on the shared
## Fx pools, and that every species' type has a colour (not the grey fallback).
## --boki-type-hit-shots --shots-dir=<dir>: six types hitting a Hunter, one frame, one strip. Never touches the save.

const DT := 1.0 / 60.0
const SAMPLE := {  # species -> its theme, three of them are read in the check, all six in the strip
	"cindowary": "ember",
	"squalltross": "tempest",
	"floenatee": "frost",
	"heatherhorn": "bloom",
	"umbrathere": "ghost",
	"caecilith": "dark",
}
const READ := ["cindowary", "squalltross", "floenatee"]
const SPARK_WHITE := 0.3  # how far Fx.impact lightens the spark toward white
const STRIP_ASPECT := 0.3  # strip height over width
const SHOT_FRAME := 2  # frames after the hit the strip is taken at (the flash holds ~6)

var bad := 0
var main: Node
var m: Match
var P: Hunter


func ok(cond: bool, what: String) -> void:
	print("BOKITYPEHIT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(root: Node, mode: String = "check") -> void:
	main = root
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	P = m.player
	if mode == "shots":
		await _shots()
	else:
		_check()
	print("BOKITYPEHIT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _foe(at: Vector3) -> Hunter:
	var h := m.make_hunter("F%d" % m.hunters.size(), 2, "warden", "Foe", "idle", {}, at, {})
	h.ctrl = "idle"
	h.armor = 0.0  # (armor turns the flash blue: a different case)
	h.hp = 1e6
	return h


func _wild(sp: String, at: Vector3) -> Kin:
	return m.spawn_wild(Save.new_kin(sp, "T"), at, false)


## The colours of the hit `by` lands on `t`: [flash, last spark], both as the pools hold them.
func _hit(t: Ent, by: Ent, o: Dictionary, dmg := 12.0) -> Array:
	m.on_damage(t, by, dmg, o)
	var fx := m.fx
	var mi: MeshInstance3D = fx.flash_pool[(fx.fi - 1 + fx.flash_pool.size()) % fx.flash_pool.size()]
	var spark: CPUParticles3D = fx.sparks[(fx.si - 1 + fx.sparks.size()) % fx.sparks.size()]
	return [(mi.material_override as ShaderMaterial).get_shader_parameter("color"), spark.color]


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02


func _check() -> void:
	var foe := _foe(P.pos + Vector3(4, 0, 0))
	var mob := m.spawn_mob("skitter", P.pos + Vector3(0, 0, 4))
	var ability := {"src": "kin", "ab": "k1"}
	var seen: Array = []
	for sp in READ:
		var k := _wild(sp, P.pos + Vector3(-4, 0, float(seen.size())))
		var want := DexView.type_col(String(SAMPLE[sp]))
		var r := _hit(foe, k, ability)
		var glow := want.lerp(Color.WHITE, SPARK_WHITE)
		var what := "%s (%s): flash %s spark %s" % [sp, SAMPLE[sp], r[0].to_html(false), r[1].to_html(false)]
		ok(_near(r[0], want) and _near(r[1], glow), what)
		ok(not _near(r[0], Juice.HIT_COL), "%s's hit is not the generic spark" % sp)
		seen.append(r[0])
	ok(
		not _near(seen[0], seen[1]) and not _near(seen[1], seen[2]) and not _near(seen[0], seen[2]),
		"the three types differ"
	)
	var k := _wild("cindowary", P.pos + Vector3(-4, 0, 4))
	var ember := DexView.type_col("ember")
	ok(_near(_hit(mob, k, ability)[0], ember), "an ember Boki's hit on a mob is ember too")
	ok(_near(_hit(foe, k, {"src": "kin"})[0], ember), "its plain strike (no ability) is ember")
	ok(_near(_hit(foe, P, {"src": "primary"})[0], Juice.HIT_COL), "a Hunter's hit on a Hunter keeps the white flash")
	var grey := DexView.type_col("")
	var missing: Array = []
	for id in Data.KIN:
		if DexView.type_col(DexView.type_of(String(id))) == grey:
			missing.append(id)
	ok(missing.is_empty(), "every species' type has a colour (no grey fallback): %s" % str(missing))


func _shots() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	var home := P.pos
	var foes: Array = []
	var kins: Array = []
	var i := 0
	for sp in SAMPLE:
		var x := -5.0 + 2.0 * i
		foes.append(_foe(home + Vector3(x, 0, 6)))
		kins.append(_wild(sp, home + Vector3(x, 0, 8.4)))
		i += 1
	for k in 30:
		m.step(DT)
		for e in foes + kins:
			e.teleport(e.pos)
			e.vel = Vector3.ZERO
		m.cam.snap(home + Vector3(0, 0, 6))
		await main.get_tree().process_frame
	for j in foes.size():
		m.on_damage(foes[j], kins[j], 12.0, {"src": "kin", "ab": "k1"})
	for f in SHOT_FRAME:
		m.fx._process(DT)
		await main.get_tree().process_frame
	var img: Image = main.get_viewport().get_texture().get_image()
	var cam := main.get_viewport().get_camera_3d()
	var mid := cam.unproject_position(home + Vector3(0, 1.0, 6))
	var half := (cam.unproject_position(home + Vector3(6.5, 1.0, 6)) - mid).x
	var box := Vector2(half, half * STRIP_ASPECT)
	var rg := Rect2i(Vector2i(mid - box), Vector2i(box * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(1600, int(crop.get_height() * 1600.0 / crop.get_width()), Image.INTERPOLATE_LANCZOS)
	crop.save_png(dir.path_join("type_hits.png"))
	print("BOKITYPEHIT shots ", dir)
