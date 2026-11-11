class_name CheckChild
extends RefCounted
## What the two-game checks share (displace-net, remote-anim, online-displace, revive-net, remote-smooth):
## a UDP port nothing holds, and child processes (the second game straight from this engine binary) that
## never outlive the check. So the children need no life span of their own, which a busy box outran.

const Watchdog := preload("res://tools/check_watchdog.gd")
const SPAN := 60      # ports tried from the first one
const WATCH_S := 2    # s between the watcher's looks at this game

## The first UDP port at or after `first` that nothing is bound to, with the port `gap` above it free too
## when a gap is given. Falls back to `first`, where the bind then fails loudly in the check.
static func free_port(first: int, gap := 0) -> int:
	for port in range(first, first + SPAN):
		if _is_free(port) and (gap == 0 or _is_free(port + gap)):
			return port
	return first

static func _is_free(port: int) -> bool:
	var probe := PacketPeerUDP.new()
	var bound := probe.bind(port) == OK
	probe.close()
	return bound

## Keeps the ENet links of `mp`, those open now and those that join later, through `secs` without an answer.
## A game that builds its match answers nothing meanwhile, and on a busy box that outlasts ENet's own 5 to
## 30 s, so the other game was dropped as dead and never got the start message.
static func hold(mp: ENetMultiplayerPeer, secs: float) -> void:
	var ms := int(secs * 1000.0)
	var set_all := func(_id := 0) -> void:
		for link: ENetPacketPeer in mp.host.get_peers():
			link.set_timeout(0, ms, ms)
	set_all.call()
	mp.peer_connected.connect(set_all)

## Starts a second headless game of this project with `user_args` and returns its pid. It keeps a user dir
## of its own beside `log_path`, so the two games never share a save. The watchdog leaves it alone.
static func start(user_args: String, log_path: String) -> int:
	return run("XDG_DATA_HOME='%s' exec '%s' --headless --path '%s' -- %s %s" % [
		log_path.get_basename() + "_data", OS.get_executable_path(), ProjectSettings.globalize_path("res://"),
		user_args, Watchdog.CHILD_FLAG], log_path)

## Starts the shell command `cmd` (one that execs its program) with its output in `log_path`, and returns the
## program's pid, so OS.kill ends it. A watcher beside it ends it within WATCH_S of this game's end,
## however this game ended: a check killed at its time limit leaves nothing running.
static func run(cmd: String, log_path: String) -> int:
	var watch := "(while kill -0 %d && kill -0 $$; do sleep %d; done; kill $$) >/dev/null 2>&1 </dev/null &" % [
		OS.get_process_id(), WATCH_S]
	return OS.create_process("/bin/sh", ["-c", "%s %s > '%s' 2>&1" % [watch, cmd, log_path]])
