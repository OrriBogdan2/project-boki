extends RefCounted
## --pip-live-check: Meeko's clips through the real match code: a Match, her Hunter, the kit's own
## presses and the render path (Hunter.render, HunterAnim, Sync). E plays its clip, the lantern
## hangs under her right hand. A knock-out plays the death clip on screen.
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
	ok(clips != null, "Meeko wears her clips in a match")
	var K: TenderKit = P.ak
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	var seen := {}
	K.cast_e()
	for f in 90:
		_frame(m, P)
		seen[clips.cur] = true
		await main.get_tree().process_frame
	ok(seen.has("hearth"), "Hearthlight plays its clip (%s)" % str(seen.keys()))
	# No "constellations brighten" row: the owner-approved appeal3 look (2e0c6ac47) painted the
	# constellations into the atlas, so Meeko has no emission layer and PipStars.pulse finds none.
	var sk := WardenGlb.skeleton(P.model.get_node("Warden"))
	var bi := sk.find_bone("spring_hanglantern_0")
	var a := sk.get_bone_global_pose(bi).origin
	var b := sk.get_bone_global_pose(sk.find_bone("spring_hanglantern_1")).origin
	var down := (b - a).normalized().dot(Vector3.DOWN)
	ok(down > 0.6, "the lantern hangs (%.2f of straight down)" % down)
	P.lives = 1
	m.eliminate(P, T, "finished")
	var dead_seen := false
	for f in 60:
		_frame(m, P)
		dead_seen = dead_seen or clips.cur == "death"
	ok(dead_seen, "a knock-out plays the death clip")
	print("PIP_LIVE_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
