extends RefCounted
## --scan-prompt-shots --shots-dir=<dir>: the scan prompt while a scan runs ("Scanning… 4s (SPACE to cancel)").
## Run under xvfb with a renderer. Writes <dir>/scan_prompt.png (the whole screen).

const DT := 1.0 / 60.0
const RUN_S := 1.5         # s into the scan before the picture
## A 1v1 with no drop and no end, the same seed as --capture-check.
const MATCH_OPTS := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true,
		"demo_kin": "cindle"}

func run(main: Node) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	await m.start(MATCH_OPTS)
	m.set_process(false)
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
	for mb in m.mobs:
		mb.dead = true
		mb.visible = false
	var P: Hunter = m.player
	var at := P.pos + Vector3(2.0, 0, 0.0)
	var rec := Save.new_kin("puddlet", "", 77)
	rec["level"] = 3
	m.spawn_wild(rec, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z), true)
	var t := 0.0
	var hold_s := float(Capture.rules()["hold_s"])
	while t < hold_s + RUN_S:
		P.inp["interact"] = t < hold_s + 0.15
		m.step(DT)
		for h in m.hunters: h.render(DT, 1.0)
		m.cam.snap(P.pos + Vector3(1.0, 0, 0.0))
		await main.get_tree().process_frame
		t += DT
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("scan_prompt.png"))
	print("SCANPROMPTSHOTS ", Capture.active(P), " ", dir)
	main.get_tree().quit(0)
