extends RefCounted
## Two desktop games share a clan through the real social store (the matchmaker's /social routes, a fresh
## sqlite file): this game starts the service and founds a clan, a second headless game (--social-net-peer)
## joins it, reads the member rows and leaves the founder a gift; then this game sees the new member's row
## and collects the gift. Each game has its own user dir, so each is its own player with its own token.

const MATCHMAKER := "res://server/matchmaker/matchmaker.py"
const FIRST_PORT := 18620  # TCP port the service is tried on first
const UP_S := 20.0  # s for the service to come up
const HELLO_S := 40.0  # s for a game to say hello (its first try can time out while the game loads)
const STEP_S := 15.0  # s for one store round trip (a clan join is a handful)
const PEER_S := 90.0  # s for the second game to start, join and send
const CLAN := "Ash Ring"

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		bad += 1


func run(main_node: Node, role := "") -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	RenderingServer.render_loop_enabled = false
	if role == "peer":
		await _peer()
		print("PEER me=%s failures=%d" % [Social.me, bad])
	else:
		await _host()
		print("SOCIAL NET DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _host() -> void:
	var dir := OS.get_user_data_dir().path_join("social_net")
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(dir.path_join("social.db"))
	var port := _free_tcp_port()
	var server_log := dir.path_join("server.log")
	var server_pid := CheckChild.run(_server_cmd(port, dir), server_log)
	var up := await _until(func(): return FileAccess.get_file_as_string(server_log).contains("matchmaker_up"), UP_S)
	ok(up, "the social service starts on port %d" % port)
	var url := "http://127.0.0.1:%d" % port
	Social.open(url)
	ok(await _until(Social.available, HELLO_S) and Social.me != "", "this game says hello and gets a player id")
	Save.d["name"] = "Ada"
	var made := []
	Social.create_guild(CLAN, "", "ASH", func(okk: bool): made.append(okk))
	await _until(func(): return not made.is_empty(), STEP_S)
	var gid := Social.my_guild_id()
	ok(made == [true] and gid != "", "the founder makes a clan")
	var peer_log := dir.path_join("peer.log")
	var peer_pid := CheckChild.start("--social-net-peer --social=%s" % url, peer_log)
	await _until(func(): return not OS.is_process_running(peer_pid), PEER_S)
	var said := FileAccess.get_file_as_string(peer_log)
	var peer_me := said.get_slice("PEER me=", 1).get_slice(" ", 0)
	ok(said.contains("failures=0") and peer_me != "" and peer_me != Social.me, "the second game joined and sent")
	var rows := []
	Social.clan_roster(gid, Social.guild, func(roll: Array, _gone: Dictionary): rows.append_array(roll))
	await _until(func(): return not rows.is_empty(), STEP_S)
	var ids := rows.map(func(r): return r["id"])
	ok(ids.has(Social.me) and ids.has(peer_me), "the founder sees both member rows: %s" % [ids])
	var lines := []
	Social.collect_gifts(func(got: Array): lines.append_array(got if not got.is_empty() else ["-"]))
	await _until(func(): return not lines.is_empty(), STEP_S)
	ok(
		lines.any(func(l): return String(l).begins_with("Bea left you a")),
		"the founder collects the gift: %s" % [lines]
	)
	OS.kill(server_pid)


func _peer() -> void:
	ok(await _until(Social.available, HELLO_S), "the second game says hello")
	Save.d["name"] = "Bea"
	var found := []
	Social.query("guilds", [["name", "==", CLAN]], "", "asc", 1, func(r: Array): found.append_array(r))
	await _until(func(): return not found.is_empty(), STEP_S)
	ok(found.size() == 1, "it finds the clan by name")
	if found.is_empty():
		return
	var gid: String = found[0]["id"]
	var founder := Social.txt_of(found[0]["data"].get("founder"))
	var joined := []
	Social.join_guild(gid, func(okk: bool): joined.append(okk))
	await _until(func(): return not joined.is_empty(), STEP_S)
	ok(joined == [true] and Social.my_guild_id() == gid, "it joins the clan")
	var rows := []
	Social.clan_roster(gid, Social.guild, func(roll: Array, _gone: Dictionary): rows.append_array(roll))
	await _until(func(): return not rows.is_empty(), STEP_S)
	var ids := rows.map(func(r): return r["id"])
	ok(ids.has(founder) and ids.has(Social.me), "it sees the founder's row and its own")
	var sent := []
	Social.send_gift(founder, "seed", Data.CROPS.keys()[0], func(okk: bool): sent.append(okk))
	await _until(func(): return not sent.is_empty(), STEP_S)
	ok(sent == [true], "it leaves the founder a seed")


## The matchmaker with only the store in use: a stand-in game server command, files in dir.
func _server_cmd(port: int, dir: String) -> String:
	var mm := ProjectSettings.globalize_path(MATCHMAKER)
	var env := (
		"SERVER_CMD='python3 %s' SERVER_VERSION=check HTTP_HOST=127.0.0.1 HTTP_PORT=%d SOCIAL_DB='%s' TOKENS_DIR='%s'"
		% [mm.get_base_dir().path_join("fake_server.py"), port, dir.path_join("social.db"), dir]
	)
	return "%s FEEDBACK_PATH='%s' exec python3 '%s' --env-file /dev/null" % [env, dir.path_join("fb.jsonl"), mm]


func _free_tcp_port() -> int:
	for port in range(FIRST_PORT, FIRST_PORT + 60):
		var probe := TCPServer.new()
		var free := probe.listen(port, "127.0.0.1") == OK
		probe.stop()
		if free:
			return port
	return FIRST_PORT


## Waits frames until cond() holds or secs of this game's own time pass; answers cond().
func _until(cond: Callable, secs: float) -> bool:
	var t0 := CheckClock.own_msec()
	while not cond.call() and CheckClock.own_msec() - t0 < secs * 1000.0:
		await main.get_tree().process_frame
	return cond.call()
