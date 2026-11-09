extends RefCounted
## --shot-size-shots --shots-dir=<dir> [--res=720|1080]: each Hunter's LMB projectile in flight at the default
## camera, with its measured on-screen size. Writes <dir>/shotsize_<hero>_<res>.png (a 3x crop round the shot)
## and <dir>/MANIFEST.txt lines "shotsize|<hero>|<res>|<look px wide x long>|<beacon core px>". "look" is the
## shot's own drawn mesh (its sphere or skin, tails left out); the beacon is ShotFloor's floor (docs/HERO_VFX.md).
## Run under xvfb with a renderer.

const HEROES := ["gunslinger", "tender", "dolm", "archer", "dredge", "rimewright", "mage", "thief", "ostra"]
const DT := 1.0 / 60.0
const HOLD := {"archer": 0.7}      # s of LMB held before the release (a drawn bow); the rest tap

var main: Node
var m: Match
var lines: Array = []

func run(main_node: Node, _mode: String) -> void:
	main = main_node
	var res := 720
	var out := "shots"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--res="): res = int(String(a).substr(6))
		if String(a).begins_with("--shots-dir="): out = String(a).substr(12)
	main.get_window().size = Vector2i(res * 16 / 9, res)
	DirAccess.make_dir_recursive_absolute(out)
	var o := {"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true}
	o.merge(Match.arena_opts("gunslinger"), true)
	m = Match.new()
	main.add_child(m)
	await m.start(o)
	m.set_process(false)      # stepped by hand: the live input would overwrite the scripted trigger
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	var P: Hunter = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var spot = load("res://tools/aimkit_shots.gd").new()
	spot.main = main
	spot.m = m
	var home: Vector3 = spot._spot(P.pos)
	if m.hud: m.hud.visible = false
	for hero in HEROES:
		await _hero(hero, P, home, out, res)
	var f := FileAccess.open(out.path_join("MANIFEST.txt"), FileAccess.WRITE)
	for l in lines: f.store_line(l)
	f.close()
	var vp := main.get_viewport().get_visible_rect().size
	print("SHOTSIZE shots: %d in %s at %dp (viewport %s)" % [lines.size(), out, res, vp])
	m.queue_free()
	await main.get_tree().process_frame
	main.get_tree().quit()

func _hero(hero: String, P: Hunter, home: Vector3, out: String, res: int) -> void:
	for x in m.hunters:
		if x != P: x.teleport(home + Vector3(-30, 0, 30))
	P.set_arch(hero)
	P.unlock_all()
	P.teleport(home)
	P.vel = Vector3.ZERO
	var T: Hunter = m.make_hunter("T", 5, "medium", "Target", "idle", {}, home + Vector3(9.0, 0, 0), {"arch": "none"})
	T.max_hp = 10000.0
	T.hp = T.max_hp
	P.inp["aim"] = T.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = T.pos.y
	var found := {}
	var t := 0.0
	while t < 1.6 and found.is_empty():
		P.inp["fire"] = t < float(HOLD.get(hero, 0.1))
		m.step(DT)
		t += DT
		for s in m.shots:
			if s["by"] == P and ShotFloor.wants(s):
				found = s
	P.inp["fire"] = false
	if found.is_empty():
		lines.append("shotsize|%s|%d|no projectile|" % [hero, res])
	else:
		for i in 4:
			m.step(DT)
		await _measure(hero, found, out, res)
	m.hunters.erase(T)
	T.queue_free()
	await main.get_tree().process_frame

func _measure(hero: String, s: Dictionary, out: String, res: int) -> void:
	var cam: Camera3D = m.cam
	var p: Vector3 = s["pos"]
	cam.snap(p + Vector3(2.0, 0, 0))
	for h in m.hunters:
		h.render(DT, 1.0)
	if s["node"]:
		(s["node"] as Node3D).global_position = p
	m.shot_floor.sync(1.0)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var look := _look_box(p)
	var core := ShotFloor.floor_r()
	var right := cam.global_transform.basis.x
	var core_px := (cam.unproject_position(p + right * core) - cam.unproject_position(p)).length() * 2.0
	var mid := look.get_center()
	var wpx := _px(cam, mid, right * look.size.z * 0.5)
	var lpx := _px(cam, mid, Vector3.RIGHT * look.size.x * 0.5)
	var img := main.get_viewport().get_texture().get_image()
	var c := cam.unproject_position(p)
	var want := Rect2i(Vector2i(int(c.x) - 80, int(c.y) - 50), Vector2i(160, 100))
	var rg := want.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(rg.size.x * 3, rg.size.y * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(out.path_join("shotsize_%s_%d.png" % [hero, res]))
	lines.append("shotsize|%s|%d|%.1f x %.1f|%.1f" % [hero, res, wpx, lpx, core_px])
	print("SHOTSIZE %-10s %dp look %.1f x %.1f px, beacon core %.1f px" % [hero, res, wpx, lpx, core_px])

## Screen pixels between the two points `half` either side of `mid`.
func _px(cam: Camera3D, mid: Vector3, half: Vector3) -> float:
	return (cam.unproject_position(mid + half) - cam.unproject_position(mid - half)).length()

## The union box of the shot's own drawn meshes within a metre of it: tails (cones) and the beacon left out.
func _look_box(p: Vector3) -> AABB:
	var box := AABB(p, Vector3.ZERO)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var beacon: bool = mi in m.shot_floor.pool or mi.get_parent() in m.shot_floor.pool
		if not mi.is_visible_in_tree() or mi.mesh is CylinderMesh or beacon or mi.global_position.distance_to(p) > 1.0:
			continue
		if mi.mesh is SphereMesh and (mi.mesh as SphereMesh).radius * mi.global_basis.get_scale().x > 1.0:
			continue
		box = box.merge(mi.global_transform * mi.get_aabb())
	return box
