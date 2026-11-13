extends RefCounted
## --board-check: the Games board (scripts/home/base_board.gd, briefs/design/GARDEN.md section 5).
##   1. results: a recorded win names the best Boki (most wins) and the last winner; no games reads plain
##   2. on the base: no board with base_mode off; with it on it lists the four built games
##   3. for each listed game, a key press on the board opens that game's own start path, the game
##      is played out and the board records its result (a Boki wins, the last winner is theirs)
##   4. a game that is already on is not started a second time
## --board-shot=<dir> (real renderer) also saves board.png: the board with its list open after those games.
## Never touches the real save.

const DT := 0.1                  # s per step while a game plays out
const SETTLE_FRAMES := 600       # frames to wait at most for the home to finish building
const PLAY_S := 60.0             # s a game may take before the check gives up on it
const SEEK_HIDE := 7.0           # m from the Boki to hide the scent

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOARD %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	Save.d = Save.fresh()
	_results()
	await _on_base()
	print("BOARD DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kin(sp: String, kname: String) -> Dictionary:
	var k := Save.new_kin(sp, kname)
	k["level"] = 5
	Care.ensure(k)
	k["needs"]["joy"] = 70.0
	k["needs"]["energy"] = 90.0
	k["trust"] = 50.0
	return k

func _results() -> void:
	ok(MinigameHub.summary("race") == "No games yet", "results: nothing played reads 'No games yet'")
	MinigameHub.record("race", "Pip")
	MinigameHub.record("race", "Pip")
	MinigameHub.record("race", "Ash")
	var line := "Best Pip, 2 wins · last Ash"
	ok(MinigameHub.summary("race") == line, "results: best is the most wins, last is the latest")
	ok(MinigameHub.summary("seek") == "No games yet", "results: another game keeps its own record")

func _key(home, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	home.hboard.input(ev)

## Plays the started game out; true when it ended within PLAY_S.
func _play(home, game) -> bool:
	if game == home.hseek:
		home.ppos = home.kins[0]["pos"] + Vector3(SEEK_HIDE, 0, 0)
		game.use()
	var t := 0.0
	while game.running() and not (game == home.hseek and game.state == BaseSeek.S.RESULT) and t < PLAY_S:
		game.tick(DT)
		t += DT
	return t < PLAY_S

func _on_base() -> void:
	var rules: Dictionary = FarmUnlocks.rules()
	var d := Save.fresh()
	for i in 3:
		var k := _kin(["zapple", "cindle", "zapple"][i], ["Pip", "Ash", "Bo"][i])
		d["roster"].append(k)
		if i == 0:
			k["starter"] = true
			d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	HomeLayout.ensure(Save.d)
	var off = await main._hb_home()
	ok(off.hboard == null, "off: no board on the farm")
	off.queue_free()
	await main.get_tree().process_frame
	rules["base_mode"] = true
	var home = await main._hb_home()
	for f in SETTLE_FRAMES:
		if is_instance_valid(home.root_ui):
			break
		await main.get_tree().process_frame
	home._close_panel()
	ok(home.hboard != null, "on: the base has the Games board")
	if home.hboard != null:
		await _games(home)
		await _shot(home)
	rules["base_mode"] = false
	home.queue_free()
	await main.get_tree().process_frame

func _games(home) -> void:
	var board: BaseBoard = home.hboard
	var at := Vector2(board.board.position.x, board.board.position.z)
	var far: Dictionary = board.find(at + Vector2(30, 0))
	ok(board.find(at) == {"kind": "board"} and far.is_empty(), "on: the board offers itself up close only")
	var ids: Array = board.games().map(func(g): return g[0])
	ok(ids == ["race", "shove", "seek", "volley"], "on: it lists the built games %s" % [ids])
	for i in ids.size():
		var game = board.games()[i][2]
		for k in home.kins:
			k.erase("indoors")
			k["rec"]["needs"]["energy"] = 90.0
		board.use()
		ok(is_instance_valid(board.panel), "%s: the key opens the list" % ids[i])
		for n in i:
			_key(home, "down")
		_key(home, "interact")
		ok(game.running(), "%s: the key opens its start path" % ids[i])
		if ids[i] == "race":
			_key_while_running(home, board)
		ok(_play(home, game), "%s: the game plays out" % ids[i])
		var wins: Dictionary = Save.d["game_board"].get(ids[i], {}).get("wins", {})
		var total := 0
		for n in wins:
			total += int(wins[n])
		var last: String = Save.d["game_board"].get(ids[i], {}).get("last", "")
		ok(total == 1 and wins.has(last), "%s: one result recorded, last winner is the winner" % ids[i])
		ok(not MinigameHub.summary(ids[i]).begins_with("No games"), "%s: the list shows it" % ids[i])
		game.tick(60.0)

## With a game on, the board starts nothing on top of it.
func _key_while_running(home, board: BaseBoard) -> void:
	var busy := 0
	for k in home.kins:
		busy += 1 if k.get("busy", false) else 0
	board.start(1)
	var after := 0
	for k in home.kins:
		after += 1 if k.get("busy", false) else 0
	ok(home.hshove.run == null and after == busy, "race: a second game is not started on top")

func _shot(home) -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--board-shot="):
			dir = String(a).trim_prefix("--board-shot=")
	if dir == "":
		return
	var at: Vector3 = home.hboard.board.position
	var me := at + Vector3(1.0, 0, 1.2)
	home.ppos = me
	home.player.position = me
	home.cam.zoom_to = 5.0
	home.cam.zoom = 5.0
	home.cam.snap(me)
	home.hboard.use()
	for i in 5:
		await main.get_tree().process_frame
	if main.fade:
		main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.4).timeout
	home.set_process(false)
	home.prompt_box.visible = false
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png("%s/board.png" % dir)
	home.set_process(true)
