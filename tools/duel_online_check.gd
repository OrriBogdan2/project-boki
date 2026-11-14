extends RefCounted
## --duel-online-check: the duel ring's Duel online between two real games. This process is the host
## (it runs the relay in-process) and starts a second headless game, the guest (--duel-online-check=guest).
##  1. The lobby's duel line pairs hunters two by two in id order; its start message opens the duel room
##     with both players and no bot.
##  2. Both games put the two hunters on the same two marks, facing each other across the island.
##  3. The guest falls off: its own game counts a knock against it and the host's game the knock for the host.
##  4. Both games stand the guest back up on its mark, and the next round starts on both.
##  5. The host is knocked: the guest's game counts it, and the host is back on its mark after the beat.
## Lines: DUELNET ok|FAIL <what>; the guest prints DUELNET guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for the guest to come up and build its match
const LobbyScreen := preload("res://scripts/ui/lobby.gd")

var main: Node
var bad := 0
var n := 0
var port := 0
var dir := ""
var guest_pid := 0
var m: Match = null
var replies: Array = []
var stop := false

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("DUELNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--duel-online-check=guest": guest = true
		if a.begins_with("--do-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	_line_case()
	port = 7930 + OS.get_process_id() % 50
	dir = ProjectSettings.globalize_path("user://duel_online")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --duel-online-check=guest --do-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, port, dir.path_join("guest.log")]
	OS.create_process("/bin/sh", ["-c", cmd])
	var line: Array = [Net.me]
	var t0 := Time.get_ticks_msec()
	while line.size() < 2 and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		line = LobbyScreen.duel_line(Net.peers, Net.me)
		_read_pid()
	ok(line.size() == 2, "the guest joins the duel line over the relay", str(line))
	if line.size() < 2:
		return _finish()
	var other := String(line[1])
	var host_pairs := LobbyScreen.duel_partner(line, Net.me) == other
	ok(host_pairs == (Net.me < other), "the lower id hosts the pair")
	if not host_pairs:
		ok(LobbyScreen.duel_partner(line, other) == Net.me, "the guest's id is the lower: it would host")
	var them: Dictionary = Net.peers[other].duplicate()
	them["peer"] = other
	var d := LobbyScreen.duel_start({"peer": Net.me, "name": "Host", "duel": 1}, them)
	Net.lobby_emit("do", {"c": "start", "d": d})
	await _build(d)
	var G: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null and G.remote, "the guest's hunter is here, driven by the guest's game")
	if G == null:
		return _finish()
	await _room_case(G)
	await _fall_case(G)
	await _knock_case(G)
	_finish()

func _line_case() -> void:
	var line := ["c", "a", "b"]
	var pairs := ["a", "b", "c"].map(func(id): return LobbyScreen.duel_partner(line, id))
	ok(pairs == ["b", "", ""], "the line pairs the first two; the second waits, the third has no rival", str(pairs))
	var d := LobbyScreen.duel_start({"peer": "a", "name": "A"}, {"peer": "b", "name": "B"})
	var teams: Array = d["roster"].map(func(r): return int(r["team"]))
	ok(d["host"] == "a" and teams == [0, 1] and int(d["teams"]) == 2, "a duel is two teams of one, hosted by the first")
	var o := LobbyScreen.duel_match(d)
	ok(o.get("duel", false) and o.get("training", false) and o.has("net") and int(o["teams"]) == 2,
		"the start message opens the duel room online")

func _room_case(G: Hunter) -> void:
	var D := m.duel
	ok(D != null and D.bot == null and D.rival == G, "the duel room holds the two players and no bot")
	ok(m.hunters.size() == 2, "nobody else is in the room", "%d hunters" % m.hunters.size())
	var g: Dictionary = await _ask()
	var same := _v(g["home"]).distance_to(D.bot_at) < 0.1 and _v(g["bot_at"]).distance_to(D.home_at) < 0.1
	ok(same, "both games use the same two marks, one each")
	var gap := D.home_at.distance_to(D.bot_at)
	ok(gap > 4.0 and gap < 8.0, "the marks face each other a few steps apart", "%.1f m" % gap)

func _fall_case(G: Hunter) -> void:
	var D := m.duel
	var g: Dictionary = await _say_do("fall", 0.8)
	ok(bool(g["took"]) and bool(g["down"]), "the guest's fall is a knock on its own game")
	g = await _ask()
	ok(int(g["knocked"]) == 1 and int(D.stats["knocks"]) == 1, "the round is the host's on both games",
		"guest knocked %d, host knocks %d" % [int(g["knocked"]), int(D.stats["knocks"])])
	await _run(2.5)
	g = await _ask()
	ok(not bool(g["down"]) and not G.downed and not G.out, "the guest is back up on both games")
	ok(_v(g["pos"]).distance_to(D.bot_at) < 1.0, "back on its mark")
	ok(int(g["round"]) == 2 and D.round_n == 2, "round 2 on both games")

func _knock_case(G: Hunter) -> void:
	var D := m.duel
	m.knock(m.player, G, {})
	await _run(0.8)
	var g: Dictionary = await _ask()
	ok(int(g["knocks"]) == 1 and int(D.stats["knocked"]) == 1, "the host's knock counts for the guest",
		"guest knocks %d" % int(g["knocks"]))
	await _run(2.5)
	ok(not m.player.downed and m.player.pos.distance_to(D.home_at) < 1.0, "the host is up on its mark")
	ok(not m.over and not m.player.out, "the match goes on")

func _finish() -> void:
	Net.lobby_emit("do", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("DUELNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _read_pid() -> void:
	if guest_pid > 0:
		return
	var p := dir.path_join("guest.log")
	if not FileAccess.file_exists(p):
		return
	for line in FileAccess.get_file_as_string(p).split("\n"):
		if line.begins_with("DUELNET guest pid="):
			guest_pid = int(line.get_slice("=", 1))

## Tells the guest to do `c`, lets both games run `secs`, and returns what the guest says back.
func _say_do(c: String, secs: float) -> Dictionary:
	replies.clear()
	Net.lobby_emit("do", {"c": c})
	var g: Dictionary = await _reply()
	await _run(secs)
	return g

func _ask() -> Dictionary:
	return await _say_do("ask", 0.0)

func _reply() -> Dictionary:
	var t := 0.0
	while replies.is_empty() and t < 10.0:
		await _run(0.1)
		t += 0.1
	return replies[0] if not replies.is_empty() else {}

# ------------------------------------------------------------------ the guest
func _guest() -> void:
	print("DUELNET guest pid=%d" % OS.get_process_id())
	if not await _connect():
		print("DUELNET guest: no relay")
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while m == null and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	while m != null and not stop and Time.get_ticks_msec() - t0 < 600000:
		await _run(DT)
	main.get_tree().quit(0)

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "do_r":
		replies.append(data)
		return
	if topic != "do":
		return
	match String(data.get("c", "")):
		"start": _build(data["d"])
		"done": stop = true
		"fall":
			var took := m != null and m.duel.on_fell(m.player)
			_say({"took": took})
		"ask": _say({})

func _say(extra: Dictionary) -> void:
	if m == null or m.player == null or m.duel == null:
		return
	var P := m.player
	var D := m.duel
	var r := {"down": P.downed, "pos": [P.pos.x, P.pos.y, P.pos.z], "round": D.round_n,
		"home": [D.home_at.x, D.home_at.y, D.home_at.z], "bot_at": [D.bot_at.x, D.bot_at.y, D.bot_at.z],
		"knocks": int(D.stats["knocks"]), "knocked": int(D.stats["knocked"])}
	r.merge(extra)
	Net.lobby_emit("do_r", r)

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "do", "duel": 1})      # in the duel line, as the lobby announces it
	return Net.mode == "server"

## The match the lobby's start message opens, on both games.
func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	await nm.start(LobbyScreen.duel_match(d))
	nm.set_process(false)
	m = nm

## Runs the match `secs` in real time (one step a frame at 60 fps).
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		m.step(DT)
		t += DT
		await main.get_tree().process_frame

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
