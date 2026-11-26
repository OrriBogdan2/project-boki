extends RefCounted
## --wisp-summon-shots --shots-dir=<dir>: the player's path in frames. The Training Grounds opts from the title
## menu, the game's own loop and real C key events (no check opts, so the settings file decides as it does for
## a player; pass --settings-file=<a file with boki_wisps=false> for an old one). Writes 1_start.png (the wisp),
## 2_summoned.png (C: the full Boki out, its summon ring), 3_back.png (C again: the wisp again) and prints one
## SHOT line per frame with the Boki's state. Needs a renderer.

const SHOTS := [["1_start", 0.0], ["2_summoned", 1.2], ["3_back", 1.5]]  # name, s after the key (none first)

var dir := ""
var tree: SceneTree


func run(main: Node) -> void:
	tree = main.get_tree()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	if Save.d["roster"].is_empty():
		var rec: Dictionary = Save.new_kin("cindle", "", 7)
		Save.d["roster"].append(rec)
		Save.d["active"] = rec["uid"]
	print("SHOT settings file %s: boki_wisps %s" % [Settings.path, Settings.get_v("boki_wisps")])
	Game.start_match(Match.arena_opts(Arch.of_save()))
	var m: Match = await _match()
	if m == null:
		print("SHOT FAIL no match")
		tree.quit(1)
		return
	await _secs(2.0)
	_shot(m, SHOTS[0][0])
	for i in [1, 2]:
		await _press_c()
		await _secs(float(SHOTS[i][1]))
		_shot(m, SHOTS[i][0])
	tree.quit(0)


func _match() -> Match:
	for i in 3000:
		await tree.process_frame
		var s = Game.main.screen_node() if Game.main else null
		if s is Match and (s as Match).player and (s as Match).player.kin and (s as Match).time > 0.5:
			return s
	return null


func _secs(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await tree.process_frame


func _press_c() -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_C
		ev.physical_keycode = KEY_C
		ev.pressed = down
		Input.parse_input_event(ev)
		await _secs(0.1)


func _shot(m: Match, name_v: String) -> void:
	var k: Kin = m.player.kin
	var s := k.summon
	var ring: bool = k.get_node_or_null(SummonRing.NAME) != null
	print(
		(
			"SHOT %s wisp=%s state=%s window=%.1f cd=%.1f perks=%s summon_ring=%s"
			% [name_v, k.wisp, k.state, s.left, s.cd, m.player.kin_carry_on(), ring]
		)
	)
	tree.root.get_viewport().get_texture().get_image().save_png(dir.path_join(name_v + ".png"))
