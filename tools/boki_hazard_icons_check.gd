extends RefCounted
## --boki-hazard-icons-check: the hazard icons on the Boki box (BokiHazardIcons, GripHud) on the Hollow Crown, seed 5.
## The lead is an ember Boki (counters lava), the second a storm one (counters static). Asserts what the box shows
## (BokiHazardIcons.view: [kind, lit] for the lead then the second): each icon is for the hazard its Boki counters,
## dim off the hazard, only the matching one lit while you stand in lava or static, a Boki that counters nothing
## here or a solo run with no second Boki shows nothing for that slot, a downed lead's icon is not lit.
## With --shots-dir=<dir> (real renderer, 1280x720) it saves the HUD before (no hazard kinds on the map, so no
## icons: the old box), with the icons dim, in lava and in static as <dir>/<WxH>_NN_<state>.png.
## Prints "BOKIHAZ ..." lines and "BOKIHAZ CHECK DONE, N checks, failures: F".

var main: Node
var m: Match
var tz: TerrainHazards
var P: Hunter
var n := 0
var fails := 0
var dir := ""

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("BOKIHAZ %-70s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": "cindowary"})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var fade = main.get("fade")
	if dir != "" and fade != null:
		await fade.reveal(0.01)
	tz = TerrainHazards.of(m)
	P = m.player
	ok("the map has hazards and the player carries two Boki", tz != null and P.kin != null and P.kin2 != null)
	if tz != null and P.kin2 != null:
		_species(P.kin, "cindowary")
		_species(P.kin2, "kestrike")
		await _rows()
		_species(P.kin2, "cindle")
		ok("a second that counters nothing here: no icon", BokiHazardIcons.view(tz, P)[1][0] == "")
		_species(P.kin, "cindle")
		ok("a lead that counters nothing here: no icon", BokiHazardIcons.view(tz, P)[0][0] == "")
		P.kin2 = null
		ok("no second Boki (a solo run): that slot is empty", BokiHazardIcons.view(tz, P)[1] == ["", false])
	print("BOKIHAZ CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _species(k: Kin, species: String) -> void:
	k.species = species
	k.sp = Data.KIN[species]

func _first(kind: String) -> int:
	for ai in tz.areas.size():
		if tz.areas[ai]["kind"] == kind:
			return ai
	return -1

## Stands the player on the area's middle tile for a few steps so the hazard has registered.
func _stand(kind: String) -> void:
	var ai := _first(kind)
	var cells: Array = tz.areas[ai]["cells"]
	var c: Vector3 = tz.areas[ai]["centre"]
	var mid := Vector2(c.x - 0.5, c.z - 0.5)
	var best: Vector2i = cells[0]
	for q in cells:
		if Vector2(q).distance_to(mid) < Vector2(best).distance_to(mid):
			best = q
	P.teleport(Vector3(best.x + 0.5, float(tz.areas[ai]["y"]), best.y + 0.5))
	P.vel = Vector3.ZERO
	P.hp = P.max_hp
	_frames(0.3)

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		P.hp = P.max_hp
		P.render(Match.DT, 1.0)
		t += Match.DT

func _rows() -> void:
	var lava := _first("lava")
	var spot: Vector3 = P.pos
	ok("the map has lava and static", lava >= 0 and _first("static") >= 0)
	_frames(0.3)
	var v := BokiHazardIcons.view(tz, P)
	ok("off the hazards: lava icon (lead) and static icon (second), both dim",
		v == [["lava", false], ["static", false]], str(v))
	await _shot("icons_dim")
	_stand("lava")
	v = BokiHazardIcons.view(tz, P)
	ok("in lava: the lead's icon is lit, the second's is not", v == [["lava", true], ["static", false]], str(v))
	await _shot("icons_in_lava")
	_stand("static")
	v = BokiHazardIcons.view(tz, P)
	ok("in static: the second's icon is lit, the lead's is not", v == [["lava", false], ["static", true]], str(v))
	await _shot("icons_in_static")
	_stand("lava")
	(P.kin as Kin).state = "downed"
	ok("a downed lead's icon is not lit", BokiHazardIcons.view(tz, P)[0] == ["lava", false])
	(P.kin as Kin).state = "active"
	P.teleport(spot)
	_frames(0.3)
	ok("back off the hazard: both dim again", BokiHazardIcons.view(tz, P) == [["lava", false], ["static", false]])
	var kinds := tz.kinds.duplicate()
	tz.kinds.clear()
	await _shot("before_no_icons")
	tz.kinds = kinds

func _shot(what: String) -> void:
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(dir)
	m.hud.visible = true
	for i in 3:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	var sz := img.get_size()
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [sz.x, sz.y, n, what]))
