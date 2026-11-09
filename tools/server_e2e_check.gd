extends RefCounted
## --server-e2e-check: the whole online path on this machine. Starts the matchmaker
## (server/matchmaker/matchmaker.py, python3) on a test port with SERVER_CMD pointing at this
## worktree's game, queues two headless players (tools/join_client.gd) for a duel through it, and
## asserts the match server starts, both get in with their tokens, the duel ends when one drops out,
## and the matchmaker frees the match. Then the refusals the matchmaker is part of: a client on the
## wrong version at /queue (both versions named), a made-up token at the match server, an unknown
## ticket answering gone. (A full match can't happen through the matchmaker, which hands out exactly
## one token per seat; --server-check covers that refusal at the server.)

const GODOT := "/usr/local/bin/godot"
const HTTP_PORT := 18080          # the matchmaker's test port (8080 is the real one)
const PORT_MIN := 7880            # match ports for the test, outside the real 7777-7799
const PORT_MAX := 7882
const UP_S := 30.0                # s for the matchmaker to answer /health
const START_S := 240.0            # s for a match server and two world builds (the queue may hold them)
const END_S := 90.0
const LEAVE_AFTER_S := 20.0

var main: Node
var bad := 0
var dir := ""
var base := "http://127.0.0.1:%d" % HTTP_PORT
var mm: MatchmakerClient
var pids := {}

func ok(cond: bool, what: String) -> void:
	print("E2E %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	dir = ProjectSettings.globalize_path("user://server_e2e")
	DirAccess.make_dir_recursive_absolute(dir.path_join("tokens"))
	mm = MatchmakerClient.new()
	main.add_child(mm)
	_start_matchmaker()
	ok(await _health_up(), "the matchmaker is up on %d and serves version %s" % [HTTP_PORT, Net.VERSION])
	_spawn("a", "--join-queue=%s --join-mode=duel --join-name=Ada --join-leave-after=%d" % [base, int(LEAVE_AFTER_S)])
	_spawn("b", "--join-queue=%s --join-mode=duel --join-name=Bo" % base)
	var queued := await _wait("a", "state=queue", START_S)      # (a player process can wait in the Godot queue first)
	queued = await _wait("b", "state=queue", START_S) and queued
	ok(queued, "both players get a ticket")
	var playing := await _wait("a", "BOKI_CLIENT playing team=0", START_S)
	playing = await _wait("b", "BOKI_CLIENT playing team=1", START_S) and playing
	ok(playing, "the matchmaker started a match server and both players are in the duel with their tokens")
	ok(await _wait("mm", "match_ready", 5.0), "the matchmaker saw the server's ready line")
	ok((await _health())["matches"] == 1, "/health counts the running match")
	await _refusals()
	ok(await _wait("a", "BOKI_CLIENT left", START_S), "the first player drops out")
	ok(await _wait("b", "BOKI_CLIENT end won=true", END_S), "the other player's match ends as a win")
	ok(await _wait("mm", "server_exit", END_S), "the matchmaker reaps the server process")
	ok((await _health())["matches"] == 0, "the match is gone from /health: its port is free again")
	_kill_all()
	print("E2E CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

func _refusals() -> void:
	var old := {"mode": "duel", "name": "Old", "version": "0.0.1"}
	var res := await mm.request(base.path_join("queue"), HTTPClient.METHOD_POST, old)
	var j = res["json"] if typeof(res["json"]) == TYPE_DICTIONARY else {}
	var refused: bool = String(j.get("error", "")) == "version" and String(j.get("server_version", "")) == Net.VERSION
	ok(refused, "an old build is refused at /queue with error version and the server's version (%s)" % [j])
	var gone := await mm.poll(base, "no-such-ticket")
	var gj = gone["json"] if typeof(gone["json"]) == TYPE_DICTIONARY else {}
	ok(String(gj.get("state", "")) == "gone", "an unknown ticket answers gone")
	_spawn("z", "--join-server=127.0.0.1:%d --join-token=made-up --join-name=Zed" % PORT_MIN)
	ok(await _wait("z", "BOKI_CLIENT refused reason=bad_token", UP_S), "a made-up token at the match server: bad_token")

## The matchmaker with a test env file: this worktree's game as SERVER_CMD, test ports, no version probe.
func _start_matchmaker() -> void:
	var proj := ProjectSettings.globalize_path("res://")
	var env := "REGION=test\nPUBLIC_HOST=127.0.0.1\nHTTP_HOST=127.0.0.1\nHTTP_PORT=%d\n" % HTTP_PORT
	env += "SERVER_CMD=%s --headless --path %s --\nSERVER_VERSION=%s\n" % [GODOT, proj, Net.VERSION]
	env += "PORT_MIN=%d\nPORT_MAX=%d\nTOKENS_DIR=%s\n" % [PORT_MIN, PORT_MAX, dir.path_join("tokens")]
	env += "READY_TIMEOUT_S=%d\n" % int(START_S)
	var f := FileAccess.open(dir.path_join("test.env"), FileAccess.WRITE)
	f.store_string(env)
	f.close()
	var cmd := "cd '%s' && python3 server/matchmaker/matchmaker.py --env-file '%s' > '%s' 2>&1 & echo $! > '%s'; wait"
	cmd = cmd % [proj, dir.path_join("test.env"), dir.path_join("mm.log"), dir.path_join("mm.pid")]
	OS.create_process("/bin/sh", ["-c", cmd])

func _health() -> Dictionary:
	var res := await mm.request(base.path_join("health"))
	return res["json"] if typeof(res["json"]) == TYPE_DICTIONARY else {}

func _health_up() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < UP_S * 1000.0:
		var h := await _health()
		if h.get("ok", false) and String(h.get("version", "")) == Net.VERSION:
			return true
		await main.get_tree().create_timer(0.5).timeout
	print("E2E ... the matchmaker never answered; its log:\n%s" % _log("mm"))
	return false

func _spawn(tag: String, args: String) -> void:
	var log_path := dir.path_join(tag + ".log")
	var proj := ProjectSettings.globalize_path("res://")
	var cmd := "cd '%s' && %s --headless -- %s > '%s' 2>&1" % [proj, GODOT, args, log_path]
	OS.create_process("/bin/sh", ["-c", cmd])

func _wait(tag: String, needle: String, for_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < for_s * 1000.0:
		var txt := _log(tag)
		if not pids.has(tag):
			for line in txt.split("\n"):
				if line.begins_with("BOKI_CLIENT pid="):
					pids[tag] = int(line.get_slice("=", 1))
		if txt.contains(needle):
			return true
		if txt.contains("SCRIPT ERROR"):
			print(txt)
			return false
		await main.get_tree().create_timer(0.5).timeout
	print("E2E ... %s never printed %s; its log:\n%s" % [tag, needle, _log(tag).right(1500)])
	return false

func _log(tag: String) -> String:
	var path := dir.path_join(tag + ".log")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

## The matchmaker (it stops its match servers on SIGTERM) and any player still up.
func _kill_all() -> void:
	var pid_path := dir.path_join("mm.pid")
	if FileAccess.file_exists(pid_path):
		OS.kill(int(FileAccess.get_file_as_string(pid_path).strip_edges()))
	for tag in pids:
		OS.kill(int(pids[tag]))
