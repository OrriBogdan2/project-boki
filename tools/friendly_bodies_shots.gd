extends RefCounted
## --friendly-bodies-shots --shots-dir=<dir> [--before]: Hem's Heavy Shot into a wall with her own Boki
## beside the target, and a Fused Dredge hooking a dummy at 0, 45 and 90 degrees (xvfb, a renderer).

var main: Node
var ak
var dir := ""
const DT := 1.0 / 60.0

func run(main_node: Node) -> void:
	main = main_node
	ak = load("res://tools/archetype_check.gd").new()
	ak.main = main
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var before := "--before" in OS.get_cmdline_user_args()
	await _impale("before_impale_boki_beside.png" if before else "after_impale_boki_beside.png")
	if not before:
		for ang in [0, 45, 90]:
			await _hook(float(ang))
	main.get_tree().quit(0)

func _frame(m: Match, P: Hunter, secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid():
			each.call()
		m.step(DT)
		t += DT
		m.cam.zoom = 0.4
		m.cam.zoom_to = 0.4
		m.cam.snap(P.pos + Vector3(2.5, 0, 0.8))
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame

func _save(m: Match, file: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))

func _impale(file: String) -> void:
	var r: Array = ak.setup("archer", 6.0, "pebbit", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var f = main.get("fade")
	if f != null:
		await f.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	var W: World = m.world
	var wk: PackedByteArray = W.kind
	var wl: PackedByteArray = W.level
	for dz in range(-3, 4):
		for dx in range(0, 3):
			var i: int = W.idx(int(T.pos.x) + dx, int(T.pos.z) + dz)
			wk[i] = World.T_GROUND
			wl[i] = int(r[5]) if dx < 2 else int(r[5]) + 3
	W.kind = wk
	W.level = wl
	var k: Kin = P.kin
	var spot := home + Vector3(1.0, 0, 2.5)
	var park := func():
		k.teleport(spot)
		k.state = "active"
		k.fly = {}
		k.brain.think_t = 1e9
	ak.aim_at(P, T.pos)
	P.ak.res = 0.0
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	var hold := func():
		P.inp["sec_hold"] = true
		park.call()
	await _frame(m, P, 1.15, hold)
	P.inp["sec_hold"] = false
	await _frame(m, P, 0.5, park)
	await _save(m, file)
	print("SHOTS %s T at %s" % [file, str(T.pos - home)])
	await ak.done(m)

func _hook(ang: float) -> void:
	var r: Array = ak.setup("dredge", 7.0, "zephyrak", false)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	if m.hud:
		m.hud.visible = false
	P.kin.trust = 95.0
	ak.merge_now(P)
	await _frame(m, P, 0.9)
	var dir3 := Vector3(1, 0, 0).rotated(Vector3.UP, -deg_to_rad(ang))
	T.teleport(home + dir3 * 7.0)
	ak.fresh(T)
	ak.aim_at(P, T.pos)
	P.ak.cd["rmb"] = 0.0
	P.ak.ch_rmb = 1.0
	ak.tap(m, P)
	await _frame(m, P, 0.7)
	await _save(m, "fused_dredge_hook_%d.png" % int(ang))
	print("SHOTS hook %d T at %s" % [int(ang), str(T.pos - home)])
	await ak.done(m)
