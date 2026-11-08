extends RefCounted
## --pip-live-check: Pip's clips through the real match code: a Match, her Hunter, the kit's own
## presses and the render path (Hunter.render, HunterAnim, Sync). E plays its clip, the lantern
## hangs under her right hand, the gold constellations brighten while she heals and fall back.
## A knock-out plays the death clip on screen.
## Never touches the save.

const DT := 1.0 / 60.0

var A
var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _frame(m: Match, h: Hunter) -> void:
	m.step(DT)
	h.render(DT, 1.0)
	var sync: Node = h.model.get_node("Warden/Sync")
	sync.set_process(false)
	if h.visible or h.out:
		sync.call("_process", DT)

func _emit(h: Hunter) -> float:
	for x in h.model.get_meta("mats", []):
		if x is ShaderMaterial and (x as ShaderMaterial).get_shader_parameter("use_emit") == true:
			return float((x as ShaderMaterial).get_shader_parameter("emit"))
	return -1.0

func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("tender", 11.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	for f in 10:
		_frame(m, P)
	var sync: Node = P.model.get_node("Warden/Sync")
	var clips: WardenClips = sync.get("clips")
	ok(clips != null, "Pip wears her clips in a match")
	var K: TenderKit = P.ak
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	var seen := {}
	var rest := _emit(P)
	K.cast_e()
	var peak := rest
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var bi := sk.find_bone("spring_hanglantern_0")
	var lit := 0.0
	for f in 90:
		_frame(m, P)
		seen[clips.cur] = true
		peak = maxf(peak, _emit(P))
		if clips.cur == "hearth":
			lit = maxf(lit, sk.get_bone_pose_scale(bi).x)
		await main.get_tree().process_frame
	ok(seen.has("hearth"), "Hearthlight plays its clip (%s)" % str(seen.keys()))
	ok(rest > 0.0 and peak > rest * 1.5,
			"the constellations brighten while she heals (%.2f -> %.2f)" % [rest, peak])
	var a := sk.get_bone_global_pose(bi).origin
	var b := sk.get_bone_global_pose(sk.find_bone("spring_hanglantern_1")).origin
	var down := (b - a).normalized().dot(Vector3.DOWN)
	ok(down > 0.6, "the lantern hangs (%.2f of straight down)" % down)
	# standing she holds nothing yet: the idle keys the lantern out of view and breathes on x_breath
	# (docs/art/IDLE_AUDIT.md 7)
	ok(lit > 0.9, "the lantern shows in her Hearthlight (scale %.2f)" % lit)
	var hidden := 1.0
	var chest := Vector2(INF, -INF)
	var xb := sk.find_bone("x_breath")
	for f in 150:
		_frame(m, P)
		# (standing: the idle, or the stance)
		if clips.act_w < 0.01 and clips.up_w < 0.01 and clips.loco_pos.length() < 0.01:
			hidden = minf(hidden, sk.get_bone_pose_scale(bi).x)
			var s := sk.get_bone_pose_scale(xb).x if xb >= 0 else 1.0
			chest = Vector2(minf(chest.x, s), maxf(chest.y, s))
		await main.get_tree().process_frame
	ok(hidden < WardenGlb.Springs.HIDDEN, "standing, the lantern is out of view (scale %.3f)" % hidden)
	ok(chest.y - chest.x > 0.003, "she breathes while she stands (x_breath %.3f..%.3f)" % [chest.x, chest.y])
	P.lives = 1
	m.eliminate(P, T, "finished")
	var dead_seen := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or clips.cur == "death"
	ok(dead_seen, "a knock-out plays the death clip")
	print("PIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
