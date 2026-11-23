extends RefCounted
## --hud-timeline-shots --shots-dir=<dir> [--size=WxH]: a fresh save's first real match (not the tutorial),
## the hunter standing at the first landing, one jpg every 10 s of game time for 90 s plus a line per
## shot in <dir>/timeline.txt (clock, health, level). The groups are counted from the pictures into
## docs/HUD.md ("First real match: the HUD over time"). --before plays the same save as a veteran
## (`matches` at HudGroups.NEW_PLAYER_MATCHES), which draws what origin/main drew.
## Never writes the save. Run on a GPU through jobq.

const SHOT_EVERY_S := 10.0      # s of game time between two shots
const SPAN_S := 90.0      # s of game time the run covers after landing
const SETTLE_FRAMES := 8      # frames before a shot: the panels canvas redraws at most 20 times a second
const STEPS_PER_FRAME := 4      # simulation steps per rendered frame (the fixed 60 Hz step)

var main: Node
var tree: SceneTree
var m: Match
var dir := "/tmp/hud_timeline"
var before := false
var lines: PackedStringArray = []

func run(main_node: Node) -> void:
	main = main_node
	tree = main.get_tree()
	var win := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		elif String(a) == "--before":
			before = true
		elif String(a).begins_with("--size="):
			var p := String(a).substr(7).split("x")
			win = Vector2i(int(p[0]), int(p[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	Save.d = Save.fresh()
	Save.d["look"] = Unmasked.default_look()
	Save.d["arch"] = "gunslinger"
	Save.d["cls"] = Arch.weight("gunslinger")
	Save.d["weapon"] = Arch.signature("gunslinger")
	var rec := Save.new_kin("cindle", "Ember")
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	for k in ["intro", "prologue", "hatched", "match", "home"]:
		Save.d["tutorial"][k] = true      # (as a save that finished the tutorial and the first farm visit)
	tree.root.size = win
	if before:
		Save.d["matches"] = HudGroups.NEW_PLAYER_MATCHES
	await _start()
	for k in int(SPAN_S / SHOT_EVERY_S) + 1:
		await _shot(k)
		for i in int(SHOT_EVERY_S / Match.DT):
			m.step(Match.DT)
			if i % STEPS_PER_FRAME == 0:
				await tree.process_frame
	var f := FileAccess.open(dir.path_join("timeline.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	tree.quit(0)

func _start() -> void:
	if main.current:
		main.current.queue_free()
	await tree.process_frame
	m = Match.new()
	main.add_child(m)
	main.current = m
	await m.start({"teams": Data.MATCH_PLAYERS, "squad": 1, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": 7})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var guard := 0
	while guard < 3000 and m.skydrop.planning:
		guard += 1
		m.step(Match.DT)
	m.ship_jump(m.player, true)
	m.player.teleport(m.world.spawns[0])      # (the drop itself is not under test: land on the first spawn)
	guard = 0
	while guard < 2400 and not (m.player.grounded and not m.player.dropping):
		guard += 1
		m.step(Match.DT)
		if guard % STEPS_PER_FRAME == 0:
			await tree.process_frame

func _shot(k: int) -> void:
	for i in SETTLE_FRAMES:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var t := int(k * SHOT_EVERY_S)
	main.get_viewport().get_texture().get_image().save_jpg(dir.path_join("t%03d.jpg" % t), 0.85)
	var p := m.player
	var at := "t=%ds clock=%.0f hp=%d/%d lv=%d" % [t, m.time, p.hp, p.max_hp, p.lvl]
	lines.append("%s ground=%s pos=%s" % [at, p.grounded, p.position.round()])
	print("TIMELINE ", lines[-1])
