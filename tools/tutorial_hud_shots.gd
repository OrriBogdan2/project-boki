extends RefCounted
## --tutorial-hud-shots --shots-dir=<dir>: the Trial Expedition and a first real expedition as screenshots
## (run with a real renderer, e.g. xvfb-run --rendering-driver opengl3 --resolution 1280x720): the
## lesson cards (with their clips), a pill in play, the pause menu's Skip the Trial, the expedition
## panel's Trial Expedition replay, then a real expedition's clean HUD, a first-time tip and the
## reminder card. Files are <dir>/<WxH>_NN_<what>.png.

var main: Node
var m: Match
var dir := "/tmp/tuthud_shots"
var n := 0

## The lessons whose cards are shot, and the ones whose pill is shot a moment into play.
const CARDS := ["land", "move", "dash", "glide", "crouch", "shoot", "sig", "gkey", "rank", "key", "chest", "goexit",
		"extract"]
const PILLS := ["glide", "gkey"]

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	_new_save()
	await _trial()
	await _expedition_panel()
	await _first_expedition()
	print("TUTHUDSHOTS %d in %s" % [n, dir])
	main.get_tree().quit(0)

func _new_save() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d

func _trial() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start(Tutorial.opts().merged({"demo_kin": "cindle"}))
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var shot := {}
	var guard := 0
	while guard < 30000 and not m.player.extracted:
		guard += 1
		var tu: Tutorial = m.tut
		var sid := tu.id()
		if tu.card and sid in CARDS and not shot.has(sid):
			shot[sid] = true
			for i in 30:
				m.step(Match.DT)      # (the card is up: the world waits, the clip plays)
				m.cam.snap(m.player.pos)
				await _frames(1)
			await _shot("card_%s" % sid)
			if sid == "land":
				await _pause_menu()
		if not tu.card and sid in PILLS and tu.t >= 1.0 and not shot.has("pill_" + sid):
			shot["pill_" + sid] = true
			await _shot("pill_%s" % sid)
		TutorialDrive.drive(m)
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		if guard % 8 == 0:
			await _frames(1)
	m.queue_free()
	m = null
	await _frames(3)

## The Esc menu during the Trial: Skip the Trial, and the Tips log.
func _pause_menu() -> void:
	var was = main.current
	main.current = m
	Overlay.open_pause("match")
	await _shot("pause_skip_trial")
	Overlay.close()
	main.current = was
	await _frames(2)

## The expedition panel on the farm: the Trial Expedition button beside the training area and the duel room.
func _expedition_panel() -> void:
	var hm = await main._hb_home()
	await _frames(20)
	hm._open_expedition()
	await _frames(10)
	await _shot("expedition_panel_replay")
	hm._close_panel()
	hm.queue_free()
	main.current = null
	await _frames(3)

## A real expedition after the Trial: the normal HUD alone, then a first-time tip, then the reminder card.
func _first_expedition() -> void:
	Save.d["tutorial"]["match"] = true
	Save.d["tips"] = []
	Settings.v["tips"] = true
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1500.0, "seed": 4242, "demo_kin": "cindle",
			"big": false})
	m.set_process(false)
	await _settle(360)      # (the drop, then a few seconds on the ground)
	await _shot("expedition_clean_hud")
	m.tips.show("skill")
	await _settle(40)
	await _shot("expedition_first_tip")
	var c := {"pos": m.player.pos, "node": Models.chest()}
	m.add_child(c["node"])
	(c["node"] as Node3D).position = m.player.pos + Vector3(1.5, 0, 0)
	KeyChest.dress(c["node"])
	KeyChest.deny(m, m.player, c)
	await _settle(20)
	await _shot("expedition_reminder_card")

## Steps the match a few frames with the camera on the player (the HUD and the lane catch up).
func _settle(frames: int) -> void:
	for i in frames:
		m.step(Match.DT)
		m.cam.snap(m.player.pos)
		await _frames(1)

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shot(what: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := main.get_viewport().get_texture().get_image()
	n += 1
	var sz := img.get_size()
	img.save_png(dir.path_join("%dx%d_%02d_%s.png" % [sz.x, sz.y, n, what]))
