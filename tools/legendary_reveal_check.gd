extends RefCounted
## --legendary-reveal-check: the legendary Boki's reveal (LegendaryReveal). In a live match with a
## forced legendary:
##   1. nothing shows before it turns up
##   2. once it does: a beam over it in its type colour with no ground ring and no particles, the
##      minimap star (LegendaryReveal.kin is it), one banner line naming it, and the sting's sound file
##   3. caught: the beam is gone, the star is gone, the banner is cleared, and it never comes back
## With --shots-dir=<dir> (under a renderer, through jobq) it also saves two shots of the reveal:
## close by, and from across the map (the beam far off, the star's arrow at the minimap's edge).

var fails := 0
var n := 0
var dir := ""

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("REVEAL %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
			DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var plan := m.spawn_plan
	plan.legend = "hivara"          # forced: the roll's rate is --legendary-check's
	var rv := plan.reveal
	for i in 30:
		m.step(Match.DT)
	ok("nothing before it turns up", rv.kin == null and rv.beam == null and rv.banner == "")
	m.time = float(Legendary.rules()["delay_s"]) - 0.1
	for i in 30:
		m.step(Match.DT)
	var k := plan.legend_kin
	ok("forced spawn: the legendary is out", is_instance_valid(k))
	if not is_instance_valid(k):
		return _done(main)
	_shown(rv, k)
	if dir != "":
		await _shots(main, m, k)
	var beam := rv.beam
	m._catch(m.hunters[0], k)
	for i in 3:
		m.step(Match.DT)
	await main.get_tree().process_frame
	ok("caught: the beam is gone", not is_instance_valid(beam))
	ok("caught: the minimap star is gone", rv.kin == null)
	ok("caught: the banner is cleared", rv.banner == "")
	for i in 60:
		m.step(Match.DT)
	ok("caught: it doesn't come back", rv.done and rv.kin == null and rv.beam == null)
	m.queue_free()
	await main.get_tree().process_frame
	_done(main)

func _shown(rv: LegendaryReveal, k: Kin) -> void:
	var beam := rv.beam
	ok("beam: up, over it", is_instance_valid(beam) and beam.is_inside_tree() and beam.visible
		and _flat(beam.position, k.global_position) < 0.5)
	if not is_instance_valid(beam):
		return
	var want := DexView.type_col(DexView.type_of("hivara"))
	var shaft: MeshInstance3D = beam.get_node("Shaft")
	var got: Color = (shaft.material_override as ShaderMaterial).get_shader_parameter("color")
	ok("beam: in its type colour", got.is_equal_approx(Color(want, got.a)), "%s vs %s" % [got, want])
	ok("beam: no ground ring", beam.get_node_or_null("Ring") == null)
	ok("beam: no particles", beam.find_children("*", "GPUParticles3D").is_empty()
		and beam.find_children("*", "CPUParticles3D").is_empty())
	ok("minimap star: on it", rv.kin == k)
	ok("banner: one line naming it", rv.banner.contains("Hivara") and not rv.banner.contains("\n"), rv.banner)
	ok("sting: its sound is there", ResourceLoader.exists("res://audio/legendary_sting.wav"))

func _shots(main: Node, m: Match, k: Kin) -> void:
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)      # the boot splash stays up when a check starts the match by hand
	var start := m.player.pos           # 40+ m off (Legendary.pick_spot)
	m.player.teleport(k.global_position + Vector3(0, 0, 7))
	m.cam.snap(m.player.pos)
	await _save(main, m, "reveal_near.png")
	m.player.teleport(start)
	m.cam.snap(m.player.pos)
	await _save(main, m, "reveal_far.png")

func _save(main: Node, m: Match, file: String) -> void:
	for i in 20:
		m.step(Match.DT)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("REVEALSHOT %s" % dir.path_join(file))

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _done(main: Node) -> void:
	print("REVEAL DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)
