extends "res://tools/archetype_check.gd"
## --muzzle-check[=id,id]: every Hunter's shots are drawn out of the weapon or the hand that throws them, never the
## body's centre (docs/WEAPON_FIRING_DATA.md, "Where shots start"). For each of the 13, with the live model animating
## (run with --fixed-fps 60), LMB, RMB, E and X are fired at a dummy and each new shot's drawn start is measured
## against the model's weapon and hand points: the nearest one has to be within NEAR m. Prints MZCHECK rows
## "<hero> <slot> fwd side up -> <nearest point> <dist>" (m from the feet: along the aim, right of it, up) and
## "MZCHECK DONE, N checks, failures: F". --verbose adds every point of the model at each shot (MZPT rows).
## --shots-dir=<dir> (a renderer) films each slot that fires from a close camera: <dir>/<hero>_<slot>/NNNNN.jpg.

const IDS := [
	"archer",
	"ashwick",
	"bulwark",
	"dolm",
	"dredge",
	"gil",
	"gunslinger",
	"juggernaut",
	"mage",
	"ostra",
	"rimewright",
	"tender",
	"thief"
]
const SLOTS := ["lmb", "rmb", "e", "x"]
const NEAR := 0.4  # m: a shot this close to a weapon or hand point left it (a frame of the throw's motion)
const WATCH := 2.0  # s watched after each press (a wind-up, a held draw)
const FILM := 1.6  # s of each slot filmed
const BONES := ["hand.R", "hand.L"]
const NODES := ["weapon_muzzle", "weapon_muzzle_l"]
## Shots that leave a held prop of the kit's own, not a hand or weapon point (each one says where).
const HELD := {
	"rimewright rmb": "the Ice Spear leaves where her held spear is drawn (RimewrightKit._spear_at)",
	"juggernaut lmb": "the Searing Wave is a ground crescent where the swing ends, 0.6 m ahead",
	"dredge lmb": 'the blunderbuss mouth in content/weapons/shotgun.json ("muzzle"); DEBT: his model\'s point is off'
}
const CAM_SIDE := 4.2  # m: the film camera stands this far right of the aim line,
const CAM_FWD := 1.8  # ... this far ahead of the hunter,
const CAM_UP := 1.9  # ... this high, looking at a point LOOK_FWD ahead at LOOK_UP
const LOOK_FWD := 1.4
const LOOK_UP := 1.0
var verbose := false
var film_dir := ""
var film_n := 0  # frames saved for the slot being filmed
var film_cam: Camera3D


func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	print("MZCHECK %-34s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	var only := ""
	for a in OS.get_cmdline_user_args():
		verbose = verbose or a == "--verbose"
		if a.begins_with("--muzzle-check="):
			only = a.substr(15)
		if a.begins_with("--shots-dir="):
			film_dir = a.substr(12)
	if film_dir != "":
		Save.no_write = true
		if main.get("fade") != null:
			main.fade.reveal(0.01)
	for id in IDS:
		if only == "" or id in only.split(","):
			await _hero(id)
	print("MZCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)


## One frame of the match, its hunters drawn (turned to their facing) and the model's own animation run after it
## (the rig steps on the process frame); saved into `dir` when one is given.
func _frame(m: Match, hero: Hunter, dir := "") -> void:
	m.step(DT)
	for e in m.hunters:
		e.render(DT, 1.0)
	if dir == "":
		await main.get_tree().process_frame
		return
	var f := hero.aim_dir()
	var fwd := Vector3(f.x, 0, f.y)
	var right := Vector3(-f.y, 0, f.x)
	film_cam.look_at_from_position(
		hero.pos + right * CAM_SIDE + fwd * CAM_FWD + Vector3.UP * CAM_UP,
		hero.pos + fwd * LOOK_FWD + Vector3.UP * LOOK_UP
	)
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_jpg(dir.path_join("%05d.jpg" % film_n), 0.9)
	film_n += 1


func _hero(id: String) -> void:
	var r := setup(id, 7.0)
	var m: Match = r[0]
	var hero: Hunter = r[1]
	var dummy: Hunter = r[2]
	if film_dir != "":
		film_cam = Camera3D.new()
		film_cam.fov = 45.0
		m.add_child(film_cam)
		film_cam.make_current()
		m.hud.visible = false
		for g in m.find_children("*", "GeometryInstance3D", true, false):  # grass and props off the strip
			var gi := g as GeometryInstance3D
			if (
				not m.hunters.any(func(e: Node) -> bool: return e.is_ancestor_of(gi))
				and (gi.global_position.y > hero.pos.y + 0.2 or gi is MultiMeshInstance3D)
			):
				gi.visible = false
	for i in 30:
		await _frame(m, hero)
	for slot in SLOTS:
		await _slot(m, hero, dummy, id, slot)
		for i in 90:
			await _frame(m, hero)
	await done(m)


func _slot(m: Match, hero: Hunter, dummy: Hunter, id: String, slot: String) -> void:
	fresh(dummy)
	hero.fire_cd = 0.0
	hero.ammo = maxi(hero.ammo, 3)
	for k in hero.ak.cd:
		hero.ak.cd[k] = 0.0
	hero.ak.ch_rmb = maxf(hero.ak.ch_rmb, 1.0)
	hero.ult = 1.0
	var seen := {}
	for s in m.shots:
		seen[s["sid"]] = true
	var dir := film_dir.path_join("%s_%s" % [id, slot]) if film_dir != "" else ""
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	film_n = 0
	var rows: Array = []
	var melee := 0
	var t := 0.0
	var fresh_shots: Array = []  # [shot, its drawn start, that measured]
	while t < WATCH:
		aim_at(hero, dummy.pos)
		_press(hero, slot, t)
		await _frame(m, hero, dir if t < FILM else "")
		t += DT
		for f in fresh_shots:  # a kit that dresses its shot on its own tick moves its muzzle a frame later
			var s: Dictionary = f[0]
			var mz: Vector3 = s.get("muzzle", f[1])
			rows.append(_measure(hero, mz) if mz != f[1] else f[2])
		fresh_shots.clear()
		for s in m.shots:
			if s["by"] != hero or seen.has(s["sid"]):
				continue
			seen[s["sid"]] = true
			if s["x"].get("melee", false):
				melee += 1
			elif not s["x"].get("cos", false) and not s["x"].get("drawn", false):
				var at: Vector3 = s.get("muzzle", s["start"])
				fresh_shots.append([s, at, _measure(hero, at)])
	hero.inp["fire"] = false
	hero.inp["sec_hold"] = false
	var what := "%s %s" % [id, slot]
	if rows.is_empty():
		print("MZCHECK %s: no shot (%d melee strikes)" % [what, melee])
		if dir != "":
			for f in DirAccess.get_files_at(dir):
				DirAccess.remove_absolute(dir.path_join(f))
			DirAccess.remove_absolute(dir)
		return
	var w: Dictionary = rows[0]
	var off: Vector3 = w["off"]
	var info := (
		"fwd %.2f side %.2f up %.2f -> %s %.2f m (%d shots)" % [off.x, off.z, off.y, w["near"], w["d"], rows.size()]
	)
	if HELD.has(what):
		print("MZCHECK %s: %s (%s)" % [what, HELD[what], info])
		return
	ok(what, float(w["d"]) <= NEAR, info)


## Holds the slot's key the way a player does: LMB held, RMB held 1.2 s (a hold-only charge), E and X pressed once.
func _press(hero: Hunter, slot: String, t: float) -> void:
	match slot:
		"lmb":
			hero.inp["fire"] = t < 0.3
		"rmb":
			if t == 0.0:
				hero.ak.press_rmb()
			hero.inp["sec_hold"] = t < 1.2
		"e":
			if t == 0.0:
				hero.ak.use_e()
		"x":
			if t == 0.0:
				hero.ak.cast_ult()


## A shot's drawn start `at` against the model's weapon and hand points: {"off": (fwd, up, side), "near", "d"}.
func _measure(hero: Hunter, at: Vector3) -> Dictionary:
	var pts := {}
	for an in (HeroVfx.data(hero.arch).get("fire_from", {}) as Dictionary).values():
		pts[an] = HeroVfx.of(hero.m).anchor_pos(hero, String(an))
	var sk := WardenGlb.skeleton(hero.model.get_node_or_null("Warden")) if hero.model else null
	for b in BONES:
		var bi := WardenSkeleton.find(sk, b) if sk else -1
		if bi >= 0:
			pts[b] = sk.global_transform * sk.get_bone_global_pose(bi).origin
	var names: Array = NODES.duplicate()
	for a in (HeroVfx.data(hero.arch).get("anchors", {}) as Dictionary).values():
		names.append_array(a.get("nodes", []))
	for nd in names:
		var an := WardenGlb.anchor(hero.model, nd) if hero.model else null
		if an != null:
			pts[nd] = an.global_position
	var best := "none"
	var bd := INF
	for k in pts:
		var d: float = (pts[k] as Vector3).distance_to(at)
		if d < bd:
			bd = d
			best = k
	if verbose:
		for k in pts:
			var o := _local(hero, pts[k])
			print("MZPT %s %s fwd %.2f side %.2f up %.2f" % [hero.arch, k, o.x, o.z, o.y])
	return {"off": _local(hero, at), "near": best, "d": bd}


## `p` as (m along the aim, m above the feet, m right of the aim line) from the hunter's feet.
func _local(hero: Hunter, p: Vector3) -> Vector3:
	var dir := hero.aim_dir()
	var lead := Vector2(p.x - hero.pos.x, p.z - hero.pos.z)
	return Vector3(lead.dot(dir), p.y - hero.pos.y, dir.x * lead.y - dir.y * lead.x)
