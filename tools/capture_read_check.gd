extends RefCounted
## --capture-read-check: a scan reads at a glance for people watching it (docs/decisions/0002).
##   1. a rival's scan, seen from here: a beam in their Hunter's ability colour, the fill in the foe colour
##   2. the same scan by a teammate: the fill is in the ally colour; your own scan is in yours
##   3. the finish pops in the ability colour and a capsule flies; an interruption is one dull ring instead
##   4. an interruption (a rival's stop, your own dash) leaves no beam, hum or scanner behind
## Everything is driven from the net events a remote client gets, so no sync shape changed.
## With --shots-dir=<dir> (GPU) it also saves scan_foe / scan_ally / pop / fizzle, seen from 20 m at match zoom.

var bad := 0
var base: RefCounted
var m: Match

func ok(cond: bool, what: String) -> void:
	print("CAPTURE-READ %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _last_ring_col() -> Color:
	return m.fx.rings[-1]["col"] if not m.fx.rings.is_empty() else Color.BLACK

func _same_rgb(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02

func _fill_col(k: Kin) -> Color:
	var f := CaptureHud.scan_fill(m, k)
	return f[1] if not f.is_empty() else Color.BLACK

func _gone(n) -> bool:
	return not is_instance_valid(n) or n.is_queued_for_deletion()

func run(main: Node) -> void:
	Save.no_write = true
	base = load("res://tools/capture_check.gd").new()
	base.main = main
	m = base._fresh()
	var P := m.player
	var rival: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			rival = h
			break
	rival.teleport(P.pos + Vector3(20.0, 0, 0))      # the distance the beam has to read from
	var k: Kin = base.wild()
	var col := Capture.beam_col(rival)
	ok(not col.is_equal_approx(Color.WHITE), "the rival's ability colour is a real colour (%s)" % col.to_html(false))

	Capture.on_net(m, rival, "scan_start", "%s|0.50" % k.nid)
	base.run_for(0.1)
	var beam = Capture.state(rival).get("beam")
	var remote: bool = Capture.state(rival).get("remote", false)
	ok(beam is Node3D and is_instance_valid(beam) and remote, "an observer gets the rival's beam from the net event")
	var mat := ((beam as Node3D).get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	ok(_same_rgb(mat.get_shader_parameter("color"), col), "...in the rival's ability colour")
	var fill := CaptureHud.scan_fill(m, k)
	ok(not fill.is_empty() and absf(float(fill[0]) - 0.5) < 0.1, "...the fill on the Boki follows their progress")
	ok(_fill_col(k).is_equal_approx(SideColor.FOE), "...in the foe colour")
	rival.team = P.team
	ok(_fill_col(k).is_equal_approx(SideColor.ALLY), "a teammate's scan fills in the ally colour")
	rival.team = P.team + 1

	Capture.on_net(m, rival, "scan_stop", "%s|0.00" % k.nid)
	var fizzle := _last_ring_col()
	base.run_for(0.1)
	ok(_gone(beam), "an interrupted scan frees the beam")
	var left: bool = Capture.state(rival).is_empty() and k.scan_by == null and CaptureHud.scan_fill(m, k).is_empty()
	ok(left, "...and the scanner, the hold on the Boki and the fill")
	ok(not Sfx.loops.has("scanhum" + rival.nid), "...and the hum")
	ok(_same_rgb(fizzle, Capture.FIZZLE_COL), "...leaving one dull ring")

	Capture.on_net(m, rival, "scan_start", "%s|0.90" % k.nid)
	base.run_for(0.1)
	var rings0: int = m.fx.rings.size()
	var kids0 := m.get_child_count()
	Capture.on_net(m, rival, "scan_done", "%s|1.00" % k.nid)
	var pop := _last_ring_col()
	ok(_same_rgb(pop, col) and not _same_rgb(pop, fizzle), "a finished scan pops a ring in the ability colour")
	ok(m.fx.rings.size() == rings0 + 1 and m.get_child_count() == kids0 + 1, "...with a capsule flying")
	ok(Capture.state(rival).is_empty() and k.scan_by == null, "...and nothing is left scanning")

	rival.teleport(P.pos + Vector3(30.0, 0, 0))
	base.begin(P)
	ok(Capture.active(P) and _fill_col(k).is_equal_approx(SideColor.YOU), "your own scan fills in your colour")
	var mine = Capture.state(P).get("beam")
	P.inp["dash"] = true
	base.run_for(0.2)
	P.inp["dash"] = false
	ok(not Capture.active(P) and k.scan_by == null, "your own dash stops the scan")
	ok(not Sfx.loops.has("scanhum" + P.nid) and _gone(mine), "...and its hum and beam")

	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			await _shots(main, String(a).substr(12))
	print("CAPTURE-READ DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## The four moments, framed on the scanner with you standing 20 m away.
func _shots(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	m = base._fresh()
	var P := m.player
	var rival: Hunter = m.hunters.filter(func(h): return h.team != P.team)[0]
	var at := P.pos + Vector3(20.0, 0, 0)
	rival.teleport(at)
	var k: Kin = base.wild()
	k.teleport(at + Vector3(2.5, 0, 1.0))
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	var id := "%s|0.55" % k.nid
	Capture.on_net(m, rival, "scan_start", id)
	await _frames(main, at, 0.5)
	await _snap(main, dir, "scan_foe")
	rival.team = P.team
	await _frames(main, at, 0.1)
	await _snap(main, dir, "scan_ally")
	rival.team = P.team + 1
	Capture.on_net(m, rival, "scan_stop", id)
	await _frames(main, at, 0.12)
	await _snap(main, dir, "fizzle")
	Capture.on_net(m, rival, "scan_start", id)
	Capture.on_net(m, rival, "scan_done", id)
	await _frames(main, at, 0.2)
	await _snap(main, dir, "pop")

func _frames(main: Node, focus: Vector3, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(Match.DT)
		t += Match.DT
		m.cam.snap(focus)
		for h in m.hunters: h.render(Match.DT, 1.0)
		await main.get_tree().process_frame

func _snap(main: Node, dir: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
