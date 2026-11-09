extends RefCounted
## --hit-class-shots --shots-dir=<dir>: a Vex LMB (the gunslinger's gun) into each kind of target, one
## crop each, side by side in hit_class_strip.png: armour, body, Boki, monster, wall (HitClass).
## Run under xvfb with a renderer.

const ARCH := "gunslinger"
const RANGE := 6.0               # m from the Hunter to the target
const AFTER_HIT := 3             # frames drawn after the shot ends, so the look is at its brightest
const MAX_STEPS := 90
const CROP := Vector2i(300, 220) # px round the screen centre, shown 2x
const NAMES := ["armour", "body", "boki", "monster", "wall"]

var m: Match
var main: Node

func run(main_node: Node) -> void:
	main = main_node
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts(ARCH), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	var crops: Array = []
	for cls in NAMES:
		crops.append(await _shot(cls))
	var strip := Image.create(CROP.x * 2 * crops.size(), CROP.y * 2, false, Image.FORMAT_RGBA8)
	for i in crops.size():
		strip.blit_rect(crops[i], Rect2i(Vector2i.ZERO, crops[i].get_size()), Vector2i(i * CROP.x * 2, 0))
	strip.save_png(out.path_join("hit_class_strip.png"))
	print("HITCLASS shots: %s in %s" % [NAMES, out])
	m.queue_free()
	main.get_tree().quit()

func _step(n: int) -> void:
	for i in n:
		m.step(Match.DT)
		for h in m.hunters:
			h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _target(cls: String, spot: Vector3) -> Vector3:
	var P := m.player
	if cls == "wall":
		m.verbs.add_wall(P, spot, Vector2(1, 0), {"length": 6.0, "block": "all", "hp": 9999.0, "time": 30.0}, 1.0)
		return spot + Vector3(0, 1.0, 0)
	if cls == "monster":
		var mb := m.spawn_mob("sentinel", spot)
		mb.hp = 1e6
		mb.max_hp = 1e6
		await _step(2)
		return mb.pos + Vector3(0, 0.8, 0)
	var rec := {} if cls != "boki" else Save.new_kin("cindle", "Spare", 5)
	var t := m.make_hunter("T" + cls, 5, "medium", "Target", "idle", rec, spot, {"arch": "none"})
	t.hp = 1e6
	t.max_hp = 1e6
	t.armor = 80.0 if cls == "armour" else 0.0
	await _step(40)           # (a Boki walks to its owner's side first)
	if cls == "boki":
		return t.kin.pos + Vector3(0, 0.7, 0)
	return t.pos + Vector3(0, 0.95, 0)

func _shot(cls: String) -> Image:
	var P := m.player
	var spot := P.pos + Vector3(RANGE, 0, 0)
	var at: Vector3 = await _target(cls, spot)
	P.inp["aim"] = at
	P.inp["aim_y"] = at.y
	P.face = atan2(-(at.x - P.pos.x), -(at.z - P.pos.z))
	P.ammo = int(P.wpn["mag"])
	P.fire_cd = 0.0
	m.cam.snap(at)
	P.fire()
	var n := 0
	while not m.shots.is_empty() and n < MAX_STEPS:
		await _step(1)
		n += 1
	await _step(AFTER_HIT)
	var img := main.get_viewport().get_texture().get_image()
	var mid := img.get_size() / 2
	var crop := img.get_region(Rect2i(mid - CROP / 2, CROP))
	crop.resize(CROP.x * 2, CROP.y * 2, Image.INTERPOLATE_NEAREST)
	print("HITCLASS shot %s: %d steps" % [cls, n])
	return crop
