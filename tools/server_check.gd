extends RefCounted
## --server-check: a dedicated match server end to end, as the matchmaker would run it. Starts a
## `--server` duel process on a test port with a tokens file, joins two headless players
## (tools/join_client.gd) with their tokens, and asserts the duel starts (both play), one player
## dropping out ends it for the other, the server prints its end line and exits 0. Then the
## refusals: a bad token, a third valid token on a full match, and a client on a server that runs
## another version (BOKI_VERSION). Every process goes through the queue wrapper's godot.

const GODOT := "/usr/local/bin/godot"
const PORT := 7877               # a test port outside the matchmaker's 7777-7799
const READY_S := 120.0           # s for a server to say ready (the queue may hold it)
const START_S := 180.0           # s for two players to be in the match (two world builds)
const END_S := 90.0
const LEAVE_AFTER_S := 20.0      # s into the match before the first player drops out
const TOKENS := {"tokens": {"tok-a": {"name": "Ada", "slot": 0, "team": 0},
		"tok-b": {"name": "Bo", "slot": 1, "team": 1}, "tok-c": {"name": "Cy", "slot": 1, "team": 1}},
	"match_id": "chk", "mode": "duel", "slots": 2, "team_size": 1}

var main: Node
var bad := 0
var dir := ""
var pids := {}       # process tag -> pid the process printed, killed at the end if still up

func ok(cond: bool, what: String) -> void:
	print("SERVER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	dir = ProjectSettings.globalize_path("user://server_check")
	DirAccess.make_dir_recursive_absolute(dir)
	var tokens_path := dir.path_join("tokens.json")
	var f := FileAccess.open(tokens_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(TOKENS))
	f.close()
	_spawn("srv", _server_args(PORT, "chk", tokens_path))
	ok(await _wait("srv", "BOKI_SERVER ready port=%d" % PORT, READY_S), "the server comes up and says ready")
	_spawn("a", _join_args(PORT, "tok-a", "Ada") + " --join-leave-after=%d" % int(LEAVE_AFTER_S))
	_spawn("b", _join_args(PORT, "tok-b", "Bo"))
	var joined := await _wait("srv", "BOKI_SERVER joined slot=0", READY_S)
	joined = await _wait("srv", "BOKI_SERVER joined slot=1", READY_S) and joined
	ok(joined, "both tokens are accepted: joined slot=0 and slot=1")
	_spawn("z", _join_args(PORT, "tok-nope", "Zed"))
	ok(await _wait("z", "BOKI_CLIENT refused reason=bad_token", READY_S), "a made-up token is refused: bad_token")
	_spawn("w", _join_args(PORT, "tok-c", "Wren"))
	ok(await _wait("w", "BOKI_CLIENT refused reason=full", READY_S), "a valid token on a full match is refused: full")
	var playing := await _wait("a", "BOKI_CLIENT playing team=0", START_S)
	playing = await _wait("b", "BOKI_CLIENT playing team=1", START_S) and playing
	ok(playing, "the duel starts: both players are in the match, on their own teams")
	ok(await _wait("a", "BOKI_CLIENT left", START_S), "the first player drops out %d s in" % int(LEAVE_AFTER_S))
	ok(await _wait("srv", "BOKI_SERVER end result=win team=1", END_S), "the server calls it for the team left standing")
	ok(await _wait("b", "BOKI_CLIENT end won=true", END_S), "the other player's match ends as a win")
	ok(await _wait_rc("srv", END_S) == 0, "the server process exits 0")
	await _version_case(tokens_path)
	_kill_all()
	print("SERVER CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()

## A server that runs another version refuses this build with reason version.
func _version_case(tokens_path: String) -> void:
	_spawn("srv2", _server_args(PORT + 1, "chk2", tokens_path), "BOKI_VERSION=0.0.1")
	ok(await _wait("srv2", "BOKI_SERVER ready port=%d" % (PORT + 1), READY_S), "a server on version 0.0.1 comes up")
	_spawn("v", _join_args(PORT + 1, "tok-a", "Vi"))
	ok(await _wait("v", "BOKI_CLIENT refused reason=version", READY_S), "this build is refused: version")
	ok(await _wait("v", "0.0.1", 5.0), "the refusal names the server's version")

func _server_args(port: int, match_id: String, tokens_path: String) -> String:
	return "--server --port %d --mode duel --match-id %s --tokens-file %s --idle-exit 60" % [
		port, match_id, tokens_path]

func _join_args(port: int, token: String, who: String) -> String:
	return "--join-server=127.0.0.1:%d --join-token=%s --join-name=%s" % [port, token, who]

## Starts a game process through the wrapper; its output goes to <dir>/<tag>.log, its exit code to <tag>.rc.
func _spawn(tag: String, args: String, env := "") -> void:
	var log_path := dir.path_join(tag + ".log")
	var rc_path := dir.path_join(tag + ".rc")
	var cmd := "cd '%s' && %s %s --headless -- %s > '%s' 2>&1; echo $? > '%s'" % [
		ProjectSettings.globalize_path("res://"), env, GODOT, args, log_path, rc_path]
	OS.create_process("/bin/sh", ["-c", cmd])

## True once the process's log holds `needle` (and remembers its pid line); false after `for_s`.
func _wait(tag: String, needle: String, for_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < for_s * 1000.0:
		var txt := _log(tag)
		if not pids.has(tag):
			for line in txt.split("\n"):
				if line.begins_with("BOKI_SERVER pid=") or line.begins_with("BOKI_CLIENT pid="):
					pids[tag] = int(line.get_slice("=", 1))
		if txt.contains(needle):
			return true
		if txt.contains("SCRIPT ERROR"):
			print(txt)
			return false
		await main.get_tree().create_timer(0.5).timeout
	print("SERVER ... %s never printed %s; its log:\n%s" % [tag, needle, _log(tag).right(1500)])
	return false

func _wait_rc(tag: String, for_s: float) -> int:
	var t0 := Time.get_ticks_msec()
	var path := dir.path_join(tag + ".rc")
	while Time.get_ticks_msec() - t0 < for_s * 1000.0:
		if FileAccess.file_exists(path):
			return int(FileAccess.get_file_as_string(path).strip_edges())
		await main.get_tree().create_timer(0.5).timeout
	return -1

func _log(tag: String) -> String:
	var path := dir.path_join(tag + ".log")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _kill_all() -> void:
	for tag in pids:
		if not FileAccess.file_exists(dir.path_join(tag + ".rc")):
			OS.kill(int(pids[tag]))
