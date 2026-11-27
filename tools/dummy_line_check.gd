extends RefCounted
## --dummy-line-check: the Training Grounds' practice dummies draw no line, lane, beam or laser while idle
## (the dodge drill's red lane only shows once you have hit the Strafer). Boots the Training Grounds,
## stands you beside each dummy in turn, as several Hunters, and looks at every visible mesh for a long
## one (a line or a lane, not a body) that starts at a dummy. Prints DUMMYLINE PASS/FAIL.
## --shots-dir=<dir> (GPU, jobq submit --needs gpu): the start view, you beside each dummy, then the drill
## after you hit the Strafer.

const DT := 1.0 / 60.0
const STAND := 3.0             # m in front of a dummy you stand (inside the Strafer's drill reach)
const LONG := 2.5              # m: a mesh this long one way...
const THIN := 2.0              # m: ...and at most this the other two is a line or a lane
const FROM := 1.5              # m: an end this close to a dummy starts at it

var main: Node
var fails := 0
var shots := ""


func ok(name: String, cond: bool, info := "") -> void:
	printerr("DUMMYLINE %-52s %s  %s" % [name, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			shots = String(a).substr(12)
	var m := Match.new()
	main.add_child(m)
	m.start(Match.arena_opts("gunslinger"))
	if shots != "":
		await _shots(m)
		return
	m.set_process(false)
	var ds: Array = m.arena.dummies.map(func(x): return x["h"])
	ok("the Training Grounds has its three dummies", ds.size() == 3, "%d" % ds.size())
	for a in ["gunslinger", "juggernaut", "thief", "archer", "tender", "mage"]:
		m.arena.set_arch(a)
		for x in m.arena.dummies:
			var d_v: Hunter = x["h"]
			m.player.teleport(d_v.pos + Vector3(0, 0, STAND))
			var found := []
			for i in 4:      # 4 x 0.75 s: past the drill's first lane (DodgeDrill.FIRST_AT 1.5 s + its wind-up)
				await _run(m, 0.75)
				_scan(m, ds, found)
			ok("as %s beside the %s dummy: no line from a dummy" % [a, x["kind"]], found.is_empty(), ", ".join(found))
	ok("the dodge drill waits for a hit", not m.arena.drill.armed and m.arena.drill._shot.is_empty())
	print("DUMMYLINE DONE, failures: %d" % fails)
	m.queue_free()
	main.get_tree().quit()


func _run(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
	await main.get_tree().process_frame


## Long thin visible meshes (LONG one way, at most THIN the other two, in their own frame; a dummy's own body
## and any skinned body are skipped) with an end within FROM of a dummy.
func _scan(n: Node, ds: Array, out: Array) -> void:
	if n is GeometryInstance3D and n is VisualInstance3D and (n as Node3D).is_visible_in_tree():
		var vi := n as VisualInstance3D
		var lb: AABB = vi.get_aabb()
		var b: Basis = vi.global_transform.basis
		var ax := [b.x * lb.size.x, b.y * lb.size.y, b.z * lb.size.z]
		var ls: Array = ax.map(func(v): return (v as Vector3).length())
		var k := ls.find(ls.max())
		var thin := true
		for j in 3:
			if j != k and float(ls[j]) > THIN:
				thin = false
		var body := n.get_parent() is Skeleton3D or ds.any(func(d): return (d as Node).is_ancestor_of(n))
		if thin and float(ls[k]) >= LONG and not body:
			var mid: Vector3 = vi.global_transform * lb.get_center()
			var half: Vector3 = ax[k] * 0.5
			for d in ds:
				var p: Vector3 = (d as Hunter).global_position
				var e1 := Vector2(mid.x + half.x - p.x, mid.z + half.z - p.z).length()
				var e2 := Vector2(mid.x - half.x - p.x, mid.z - half.z - p.z).length()
				if minf(e1, e2) < FROM:
					out.append("%s %.1f m at %s" % [n.name, float(ls[k]), (d as Hunter).pname])
	for c in n.get_children():
		_scan(c, ds, out)


## The GPU stills: the start view, you beside each dummy (no lane), then the drill once you hit the Strafer.
func _shots(m: Match) -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	main.get_window().size = Vector2i(1280, 720)
	if main.fade:
		await main.fade.reveal(0.01)
	await _wait(4.0)
	_snap("01_start")
	for x in m.arena.dummies:
		m.player.teleport((x["h"] as Hunter).pos + Vector3(0, 0, STAND))
		await _wait(2.5)
		_snap("02_by_%s" % x["kind"])
	m.arena._on_hit(m.player, m.arena.drill.thrower, 10.0, [])
	await _wait(2.3)
	_snap("03_drill_after_hit")
	print("DUMMYLINE SHOTS DONE")
	main.get_tree().quit()


func _wait(secs: float) -> void:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		await main.get_tree().process_frame


func _snap(nm: String) -> void:
	main.get_viewport().get_texture().get_image().save_png(shots.path_join(nm + ".png"))
