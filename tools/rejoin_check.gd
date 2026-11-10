extends RefCounted
## --rejoin-check: a player who drops out of an online match gets the same Hunter back within the relay's
## hold time, and not after it (docs/decisions/0022-rejoin.md). This process is the headless relay server;
## it starts two headless games, the host (--rejoin-check=host) and the guest (--rejoin-check=guest), and
## plays the guest's crash by killing it. The relayed guest keeps its own data folder, so the relaunched
## game finds its rejoin file and save there, like a player restarting after a crash.
## Lines: REJOIN ok|FAIL <what>; the games print REJOIN pid=, REJOIN guest/back/late/host lines.

const GODOT := "/usr/local/bin/godot"
const START_S := 240.0       # s for a game to come up and build its match (a busy machine may hold it)
const DROP_S := 60.0         # s for the relay to notice a killed game (ENet's timeout is at most 30 s)
const SEED := 4242
const TOL := 0.5             # hp / m: the rejoined Hunter matches the relay's copy to within this

var main: Node
var bad := 0
var n := 0
var port := 0
var dir := ""
var relay: RelayServer
var pids: Array = []
var m: Match = null

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("REJOIN %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Engine.max_fps = 60
	var role := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rejoin-check="): role = a.substr(15)
	if role == "":
		await _server()
		return
	print("REJOIN pid=%d" % OS.get_process_id())
	if role == "host":
		await _host()
	elif role == "late":
		await _late()
	else:
		await _guest()

# ------------------------------------------------------------------ the server (this process)
func _server() -> void:
	port = 7990 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://rejoin_check/%d" % OS.get_process_id())      # fresh data folders
	DirAccess.make_dir_recursive_absolute(dir.path_join("guest"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("host"))
	relay = RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	_spawn("host", "host")
	var g1 := _spawn("guest", "guest1")
	var nid := String(await _line("guest1", "REJOIN guest nid=", START_S)).get_slice("=", 1).get_slice(" ", 0)
	ok(nid != "", "the guest is in the match", nid)
	if nid == "":
		return _finish()
	await _wait(func(): return _live(nid).has("P%sk" % nid), 20.0)
	var rows := _live(nid)
	ok(rows.has("P" + nid) and rows.has("P%sk" % nid), "the relay keeps the guest's Hunter and Boki rows")
	await _wait(func(): return false, 2.0)
	OS.kill(g1)
	var t_drop := Time.get_ticks_msec()
	await _wait(func(): return not relay.held.is_empty(), DROP_S)
	var drop_s := (Time.get_ticks_msec() - t_drop) / 1000.0
	ok(relay.held.size() == 1, "the dropped Hunter's slot is held", "after %.1fs" % drop_s)
	if relay.held.is_empty():
		return _finish()
	var slot: Dictionary = relay.held.values()[0]
	var h: Array = slot["st"]["P" + nid]
	var k: Array = slot["st"]["P%sk" % nid]
	var hp := float(h[9])
	ok(hp < float(h[10]), "the held Hunter is hurt (the guest's copy, not a fresh one)", "hp %s/%s" % [hp, h[10]])
	await _wait(func(): return false, 2.0)
	var seen := _last("host", "REJOIN host sees")
	ok(seen.contains("v=0.00") and seen.contains("hp=%.1f" % hp), "the host shows it standing still", seen)
	# the crashed game restarts: same data folder, its title offers the match back
	var g2 := _spawn("guest", "guest2")
	var got := String(await _line("guest2", "REJOIN back", START_S))
	ok(got.contains("nid=%s " % nid), "the rejoined game drives the same Hunter", got)
	ok(absf(_num(got, "hp") - hp) < TOL, "its health comes back", "%s vs %s" % [_num(got, "hp"), hp])
	var khp := float(k[6])
	ok(absf(_num(got, "khp") - khp) < TOL, "its Boki's health comes back", "%s vs %s" % [_num(got, "khp"), khp])
	ok(got.contains("uid=" + _last("guest1", "REJOIN guest nid=").get_slice("uid=", 1)), "the same Boki", got)
	var off := Vector2(_num(got, "x") - float(h[2]), _num(got, "z") - float(h[4]))
	ok(off.length() < TOL, "where it stood, no drop", "%.2fm off" % off.length())
	ok(relay.held.is_empty(), "the slot is taken back")
	await _wait(func(): return false, 2.0)
	seen = _last("host", "REJOIN host sees")
	ok(seen.contains("net=new"), "the host hears the guest again", seen)
	# a second drop, and this time nobody comes back in time
	OS.kill(g2)
	await _wait(func(): return not relay.held.is_empty(), DROP_S)
	var t_held := Time.get_ticks_msec()
	await _wait(func(): return relay.held.is_empty(), RelayServer.HOLD_S + 10.0)
	var held_s := (Time.get_ticks_msec() - t_held) / 1000.0
	ok(relay.held.is_empty() and held_s > RelayServer.HOLD_S - 2.0, "the slot is let go after the hold",
		"%.1fs" % held_s)
	_spawn("late", "guest3")
	var late := String(await _line("guest3", "REJOIN late", START_S))
	var refused := late.contains("file=true") and late.contains("title=false") and late.contains("back=false")
	ok(refused, "after the hold the title offers no rejoin and the relay says no", late)
	_finish()

func _spawn(role: String, log_name: String) -> int:
	var data := dir.path_join("host" if role == "host" else "guest")
	var cmd := "cd '%s' && exec env XDG_DATA_HOME='%s' %s --headless -- --rejoin-check=%s --server=127.0.0.1:%d"
	cmd = cmd + " > '%s' 2>&1"
	cmd = cmd % [ProjectSettings.globalize_path("res://"), data, GODOT, role, port, dir.path_join(log_name + ".log")]
	var pid := OS.create_process("/bin/sh", ["-c", cmd])
	pids.append(pid)
	return pid

func _live(nid: String) -> Dictionary:
	for c in relay.clients.values():
		if c["nid"] == nid: return c["st"]
	return {}

func _wait(done: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not done.call() and Time.get_ticks_msec() - t0 < secs * 1000.0:
		await main.get_tree().create_timer(0.2).timeout

## The last line of a game's log that starts with `head`, or "".
func _last(log_name: String, head: String) -> String:
	var out := ""
	for line in FileAccess.get_file_as_string(dir.path_join(log_name + ".log")).split("\n"):
		if line.begins_with(head): out = line
	return out

func _line(log_name: String, head: String, secs: float) -> String:
	await _wait(func(): return _last(log_name, head) != "", secs)
	return _last(log_name, head)

func _num(line: String, key: String) -> float:
	var i := line.find(" %s=" % key)
	return float(line.substr(i + key.length() + 2).get_slice(" ", 0).get_slice(",", 0)) if i >= 0 else -1.0

func _finish() -> void:
	for pid in pids:
		if OS.is_process_running(pid): OS.kill(pid)
	print("REJOIN DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the games
func _connect() -> bool:
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "rj"})
	return Net.mode == "server"

func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	await nm.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": SEED,
		"no_drop": true, "cls": "medium", "net": d})
	m = nm

func _host() -> void:
	Save.no_write = true
	await _connect()
	var other := ""
	while other == "":
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
	var d := {"mid": "rj%d" % OS.get_process_id(), "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0,
		"roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("rj", d)
	await _build(d)
	while true:      # the server stops this game
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		var G: Hunter = m.ents_by_id.get("P" + other, null)
		if G:
			var fresh := "new" if m.time - G.net_t < 0.5 else "old"
			print("REJOIN host sees P%s hp=%.1f v=%.2f net=%s" % [other, G.hp, G.net_vel.length(), fresh])
		await main.get_tree().create_timer(0.5).timeout

## A guest's first run, or (with a rejoin file from the run before) its restart after the crash.
func _guest() -> void:
	Save.no_write = false      # this game's own data folder: the Boki has to outlive the crash
	if Net.can_rejoin():
		var o: Dictionary = await Net.rejoin_match()
		if o.is_empty():
			print("REJOIN back refused")
			return
		await _build(o["net"])
		var P := m.player
		var khp := P.kin.hp if P.kin else -1.0
		var uid: String = P.kin.rec.get("uid", "") if P.kin else ""
		print("REJOIN back nid=%s hp=%.1f khp=%.1f x=%.2f z=%.2f uid=%s" % [Net.me, P.hp, khp, P.pos.x, P.pos.z, uid])
		return
	if Save.active_kin().is_empty():
		var rec := Save.new_kin("cindle")
		Save.d["roster"].append(rec)
		Save.d["active"] = rec["uid"]
		Save.save_game()
	var start := {}
	Net.message.connect(func(t, data, _f):
		if t == "rj": start.merge(data))
	await _connect()
	while start.is_empty():
		await main.get_tree().create_timer(0.2).timeout
	await _build(start)
	var P := m.player
	P.teleport(P.pos + Vector3(2.0, 0, 1.5))
	P.hp = P.max_hp * 0.61
	if P.kin:
		P.kin.hp = P.kin.max_hp * 0.4
	print("REJOIN guest nid=%s uid=%s" % [Net.me, P.kin.rec.get("uid", "") if P.kin else ""])

## The guest restarting after the hold ran out: the title doesn't offer the match, and asking anyway fails.
func _late() -> void:
	var file := not Net.rejoin.is_empty()
	var title := Net.can_rejoin()
	var o := {}
	if file:
		o = await Net.rejoin_match()
	print("REJOIN late file=%s title=%s back=%s" % [file, title, not o.is_empty()])
