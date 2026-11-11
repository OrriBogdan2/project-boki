extends RefCounted
## The carry-slot looks (CarryWisps), run by --boki-wisp-check: in a match with Boki wisps on, one hunter
## carries all four (lead, second, a carry-out claim, a stolen wisp) and each reads apart from the top: the lead
## biggest and brightest with its type colour on the rim, the second smaller, dimmer and across the orbit, the
## carry-out small behind the belt on a tether, the stolen one in the thief's side colour. All on the one shared
## material, no lights. Off with wisps off; the carry-out wisp goes when the claim does.
## --carry-wisp-shots --shots-dir=<dir>: the four at match zoom and a close crop, as PNGs (GPU).

const DT := 1.0 / 60.0
const APART := 0.45      # m: the least top-down gap between any two of one hunter's wisps
const CROP := 320        # px square round the screen middle (the hunter) for the close shot

var bad := 0
var m: Match
var p: Hunter

func ok(cond: bool, what: String) -> void:
	print("BOKIWISP carry %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## Builds the four-wisp hunter; returns the number of failed asserts. Mode "shots" takes the shots instead.
func run(main: Node, mode := "") -> int:
	if mode == "shots":
		shots(main)
		return 0
	_setup(main, true)
	var four := _four()
	_frames(0.5)
	_looks(four)
	_apart(four)
	_cheap()
	_claim_gone()
	m.queue_free()
	_off(main)
	return bad

func shots(main: Node) -> void:
	var dir := "/tmp/carry_wisp_shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	_setup(main, true)
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	_four()
	_alone()
	main.get_viewport().warp_mouse(Vector2(40, main.get_viewport().get_visible_rect().size.y * 0.5))      # aim left
	for i in 3:
		var t := 0.0
		while t < 0.4 + i * 0.37:
			_frames(DT)
			m.cam.snap(p.pos)
			t += DT
			await main.get_tree().process_frame
		var img := main.get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("carry_wisps_%d.png" % i))
		var crop := img.get_region(Rect2i(img.get_size() / 2 - Vector2i(CROP, CROP) / 2, Vector2i(CROP, CROP)))
		crop.resize(CROP * 2, CROP * 2)
		crop.save_png(dir.path_join("carry_wisps_%d_close.png" % i))
	print("BOKIWISP carry shots in %s" % dir)
	main.get_tree().quit(0)

func _setup(main: Node, wisps: bool) -> void:
	Save.no_write = true
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "demo_kin": "cindle",
		"boki_wisps": wisps})
	m.set_process(false)
	p = m.player
	for h in m.hunters:
		h.ctrl = "idle" if h != p else h.ctrl
		h.inp["move"] = Vector2.ZERO

## The shots' hunter stands well away from the others, so nobody else's wisps or plates cover the four.
func _alone() -> void:
	var spot := m.world.random_ground()
	for i in 200:
		if m.hunters.all(func(h: Hunter): return h == p or h.pos.distance_to(spot) > 25.0):
			break
		spot = m.world.random_ground()
	p.teleport(spot)

## The player carries a lead, a second, a claimed Boki and a rival's stolen wisp. [lead, second, stolen Kin].
func _four() -> Array:
	var foe: Hunter = m.hunters.filter(func(h: Hunter): return h.team != p.team and h.kin != null)[0]
	var fk: Kin = foe.kin
	fk.loose_t = 5.0
	ok(KinSteal.grab(fk, p), "a rival's wisp can be grabbed")
	p.caught.append({"species": _other_species(), "name": "Claim"})
	return [p.kin, p.kin2, fk]

func _frames(secs: float) -> void:
	var t := 0.0
	while t < secs:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		for k in m.kins: k.render(DT, 1.0)
		t += DT

func _looks(four: Array) -> void:
	var lead: Kin = four[0]
	var second: Kin = four[1]
	var stolen: Kin = four[2]
	ok(CarryWisps.role(lead) == "lead" and CarryWisps.role(second) == "second" and CarryWisps.role(stolen) == "stolen",
		"slots: %s %s %s" % [CarryWisps.role(lead), CarryWisps.role(second), CarryWisps.role(stolen)])
	ok(second.visible, "the second shows as a wisp, not hidden in the satchel")
	ok(_bright(lead) > _bright(stolen) and _bright(stolen) > _bright(second), "the lead brightest, the second dimmest")
	ok(lead.model.scale.x > stolen.model.scale.x and stolen.model.scale.x > second.model.scale.x,
		"the lead biggest, the second smallest")
	var type_col := DexView.type_col(String(Data.KIN[lead.species].get("type", "")))
	ok(_rim(lead.model).is_equal_approx(type_col), "the lead's rim is its type colour")
	ok(_rim(stolen.model).is_equal_approx(SideColor.of(m, p)), "the stolen wisp's rim is the thief's side colour")
	ok(second.global_position.y < lead.global_position.y, "the second rides a little lower")
	var shown: Array = p.get_meta("carry_wisps", [])
	ok(shown.size() == 1 and shown[0]["tether"] != null, "the claim shows as one tethered wisp")
	if shown.size() != 1 or shown[0]["tether"] == null:
		return
	var w: Node3D = shown[0]["node"]
	var tether: MeshInstance3D = shown[0]["tether"]
	var behind := Vector3(sin(p.face), 0, cos(p.face))
	ok((w.global_position - p.position).dot(behind) > 0.4, "the carry-out wisp trails behind the hunter")
	var belt := p.position + Vector3(0, CarryWisps.BELT_Y, 0)
	var ends := tether.global_position.distance_to(belt) + tether.global_position.distance_to(w.global_position)
	ok(absf(ends - belt.distance_to(w.global_position)) < 0.01, "the tether runs from the belt to the wisp")
	ok(w.scale.x < second.model.scale.x + 0.01, "the carry-out wisp is the smallest")

## Top-down, no two of the four sit on top of each other.
func _apart(four: Array) -> void:
	var spots: Array = four.map(func(k: Kin): return Vector2(k.global_position.x, k.global_position.z))
	for w in p.get_meta("carry_wisps", []):
		var n: Node3D = w["node"]
		spots.append(Vector2(n.global_position.x, n.global_position.z))
	var least := INF
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			least = minf(least, (spots[i] as Vector2).distance_to(spots[j]))
	ok(spots.size() == 4 and least >= APART, "four wisps at least %.2f m apart from the top (%.2f)" % [APART, least])

## One shared material for every wisp body and the tether, and no lights in any of them.
func _cheap() -> void:
	var mats := {}
	var lights := 0
	var nodes: Array = []
	for k in m.kins:
		if k.owner_h == p and k.model:
			nodes.append(k.model)
	for w in p.get_meta("carry_wisps", []):
		nodes.append_array([w["node"], w["tether"]])
	while not nodes.is_empty():
		var n: Node = nodes.pop_back()
		nodes.append_array(n.get_children())
		lights += 1 if n is Light3D else 0
		if n is MeshInstance3D and (n.name == "Body" or n.name == "CarryTether"):
			mats[(n as MeshInstance3D).material_override] = true
	var one := mats.size() == 1 and mats.has(BokiWispLook.material())
	ok(one, "bodies and tether share one material (%d)" % mats.size())
	ok(lights == 0, "no lights (%d)" % lights)

func _claim_gone() -> void:
	p.caught = []
	_frames(DT)
	ok(not p.has_meta("carry_wisps"), "the carry-out wisp goes with the claim")

func _off(main: Node) -> void:
	_setup(main, false)
	p.caught.append({"species": _other_species()})
	_frames(0.2)
	ok(not p.has_meta("carry_wisps"), "wisps off: no carry-out wisp")
	m.queue_free()

func _bright(k: Kin) -> float:
	return float((k.model.get_node("Body") as GeometryInstance3D).get_instance_shader_parameter("bright"))

func _rim(w: Node3D) -> Color:
	return (w.get_node("Body") as GeometryInstance3D).get_instance_shader_parameter("rim_col")

## A species unlike the player's lead, so the claim reads as its own Boki.
func _other_species() -> String:
	for id in Data.KIN:
		if String(id) != p.kin.species and String(id) != p.kin2.species:
			return String(id)
	return p.kin.species
