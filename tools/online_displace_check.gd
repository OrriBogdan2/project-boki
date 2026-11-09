extends "res://tools/displace_net_check.gd"
## --online-displace-check[=<delay ms>]: abilities that move a Hunter look the same online as offline, with
## added network delay. Three real processes on one machine: a headless relay server (it logs every position
## snapshot it forwards), and two games (this one is the host, the other the guest) that connect to it through
## tools/udp_delay.py (default 100 ms each way, so 200 ms of round trip; `=0` goes straight to the relay).
## Each move is played first on a bot (the offline reference), then on the guest's hunter. The moved Hunter's
## path is recorded on the server, on its own game and on the other game, and compared with the offline path:
## largest step in one frame (a snap), where it ends, and whether it moved twice as far (a double move).
## Lines: ODISP row|ok|FAIL ...; the table is written to <user dir>/online_displace/table.md.

const OD_DIR := "user://online_displace"
const SETTLE_VIEW := 1.2     # s after a move: the other views (delay each way, 10 Hz snapshots) have caught up
const PORT_GAP := 200        # the delay proxy listens this far above the relay's port
const MOVE_MIN := 0.8        # m: a move shorter than this missed (its row is flagged)
const END_TOL := 0.75        # m: a view ends this close to the offline end and to the mover's own end (Kael: 0.56)
const DOUBLE := 1.5          # a path or displacement this many times the offline one is a double move
const SNAP := 4.0            # m in one frame on the mover's own game: no move here is that fast (Ent.net_follow's jump)
const BOT_AT := Vector3(-6.0, 0, 9.0)   # m from home: where the bot waits

var role := ""
var delay_ms := 100
var relay_port := 0
var peer_id := ""
var pids: Array = []
var lines := PackedStringArray()
var rows: Array = []         # {"name", "who": [..], "off": [t0, t1], "on": [t0, t1], "note"}
var note := ""

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--online-displace-check="): role = a.get_slice("=", 1)
		if a.begins_with("--dn-port="): port = int(a.substr(10))
		if a.begins_with("--od-port="): relay_port = int(a.substr(10))
		if a.begins_with("--od-dir="): dir = a.substr(9)
		if a.begins_with("--od-delay="): delay_ms = int(a.substr(11))
	if role.is_valid_int():
		delay_ms = int(role)
		role = ""
	Net.message.connect(_on_msg)
	match role:
		"server": await _server()
		"guest": await _guest()
		_: await _host()

# ------------------------------------------------------------------ the server
## The relay itself (scripts/server/relay.gd) in a headless game, listening on every packet it gets: each
## position snapshot is logged with the time the server saw it. It quits when the host writes "stop".
func _server() -> void:
	var relay := RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	if relay.start(PackedStringArray(["--port=%d" % relay_port])) != OK:
		main.get_tree().quit(1)
		return
	relay.api.peer_packet.connect(_tap)
	FileAccess.open(dir.path_join("server.ready"), FileAccess.WRITE).close()
	while not FileAccess.file_exists(dir.path_join("stop")):
		await main.get_tree().create_timer(0.25).timeout
	_dump("server")
	main.get_tree().quit(0)

func _tap(_from: int, bytes: PackedByteArray) -> void:
	var d = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or d.get("k", "") != "memit" or d.get("t", "") != "st":
		return
	var now := Time.get_unix_time_from_system()
	for it in d["d"]:
		if typeof(it) == TYPE_ARRAY and it.size() > 4 and it[0] == "h":
			lines.append("%.3f,%s,%.3f,%.3f,%.3f" % [now, it[1], it[2], it[3], it[4]])

func _dump(who: String) -> void:
	var f := FileAccess.open(dir.path_join(who + ".csv"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()

## Every step, where each hunter this game knows of is (its own, and the others' copies).
func _sample() -> void:
	var now := Time.get_unix_time_from_system()
	for h in m.hunters:
		lines.append("%.3f,%s,%.3f,%.3f,%.3f" % [now, h.nid, h.pos.x, h.pos.y, h.pos.z])

func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		_sample()
		await main.get_tree().process_frame

func _on_msg(topic: String, data, from: String) -> void:
	if topic == "dn" and typeof(data) == TYPE_DICTIONARY:
		match String(data.get("c", "")):
			"mate":
				m.player.team = int(data["team"])
				if bool(data["down"]):
					m.train_t = -1e9          # (a training match stands the player up two seconds after a knock)
					m.knock(m.player, null, {})
				else:
					m.player.downed = false
			"done":
				_dump("guest")
	super._on_msg(topic, data, from)

# ------------------------------------------------------------------ the host
func _spawn(cmd: String) -> int:
	return OS.create_process("/bin/sh", ["-c", "cd '%s' && exec %s" % [ProjectSettings.globalize_path("res://"), cmd]])

func _host() -> void:
	relay_port = 7930 + OS.get_process_id() % 60
	port = relay_port + (PORT_GAP if delay_ms > 0 else 0)
	dir = ProjectSettings.globalize_path(OD_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in ["stop", "server.csv", "guest.csv", "host.csv", "server.ready"]:
		DirAccess.remove_absolute(dir.path_join(f))
	var common := "%s --headless -- --od-dir='%s' --od-port=%d --dn-port=%d --od-delay=%d" % [
		GODOT, dir, relay_port, port, delay_ms]
	pids.append(_spawn("%s --online-displace-check=server > '%s' 2>&1" % [common, dir.path_join("server.log")]))
	var t0 := Time.get_ticks_msec()
	while not FileAccess.file_exists(dir.path_join("server.ready")) and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
	ok(FileAccess.file_exists(dir.path_join("server.ready")), "the headless relay server listens on %d" % relay_port)
	if delay_ms > 0:
		pids.append(_spawn("python3 -I tools/udp_delay.py %d %d %d > '%s' 2>&1" % [
			port, relay_port, delay_ms, dir.path_join("proxy.log")]))
		await main.get_tree().create_timer(0.5).timeout
	ok(await _connect(), "the host is on the server as %s (%d ms each way)" % [Net.me, delay_ms])
	pids.append(_spawn("%s --online-displace-check=guest > '%s' 2>&1" % [common, dir.path_join("guest.log")]))
	t0 = Time.get_ticks_msec()
	while peer_id == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: peer_id = String(id)
	ok(peer_id != "", "the guest joins the server", peer_id)
	if peer_id == "":
		await _finish()
		return
	var d := {"mid": "od%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": peer_id, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("dn", {"c": "start", "d": d})
	await _build(d)
	var G: Hunter = m.ents_by_id.get("P" + peer_id, null)
	t0 = Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await _run(0.2)
		G = m.ents_by_id.get("P" + peer_id, null)
	ok(G != null and G.remote, "the guest's hunter is here, driven by the guest's game")
	if G == null:
		await _finish()
		return
	var B: Hunter = m.make_hunter("B", 1, "medium", "Bot", "idle", {}, home + BOT_AT, {"arch": "none"})
	await _move("Kael Warchain self-pull", "juggernaut", Vector3(6, 0, 0), _kael, 1.8, G, B, ["self"])
	await _move("Kael Warchain sling", "juggernaut", Vector3(6, 0, 0), _sling, 1.8, G, B, ["self"])
	await _move("Grimble Abyssal Hand reel", "dredge", Vector3(6, 0, 0), _dredge, 2.0, G, B, ["guest"])
	await _move("Motley swap dash", "ostra", Vector3(8, 0, 0), _ostra, 2.2, G, B, ["guest", "self"], {"tp": true})
	await _move("Meeko Hearth Call pull", "tender", Vector3(8, 0, 0), _meeko, 5.4, G, B, ["guest"],
		{"mates": true, "tp": true})
	await _move("Sparkle Kitefall launch and crash", "mage", Vector3(6, 0, 0), _sparkle, 4.8, G, B, ["self", "guest"])
	await _move("Knock into a wall", "mage", Vector3(4, 0, 2), _knock, 1.4, G, B, ["guest"])
	await _finish()

## One move: the same ability on a bot (the offline reference), then on the guest's hunter from the same spot.
## `who` lists whose path is measured: "self" (the caster, on the host) and/or "guest" (the one it moves).
func _move(
	name: String, arch: String, off: Vector3, act: Callable, settle: float, G: Hunter, B: Hunter, who: Array,
	opt := {}
) -> void:
	var P := m.player
	note = ""
	_kit(arch)
	_fresh(B)
	B.teleport(home + off)
	await _run(0.2)
	if opt.has("mates"): await _mate(B, true)
	var off_a := Time.get_unix_time_from_system()
	await act.call(B)
	await _run(settle + SETTLE_VIEW)
	var off_b := Time.get_unix_time_from_system()
	if opt.has("mates"): await _mate(B, false)
	B.teleport(home + BOT_AT)
	_kit(arch)
	await _place(G, home + off)
	if opt.has("mates"): await _mate(G, true)
	var on_a := Time.get_unix_time_from_system()
	await act.call(G)
	await _run(settle + SETTLE_VIEW)
	var on_b := Time.get_unix_time_from_system()
	rows.append({"name": name, "who": who, "off": [off_a, off_b], "on": [on_a, on_b], "tp": opt.has("tp"),
		"note": "a teleport" if opt.has("tp") else note})
	if opt.has("mates"): await _mate(G, false)
	P.teleport(home)
	await _place(G, home + PARK)

## Meeko's target is on her team and down (on the guest's game its own hunter goes down) or back to normal.
func _mate(t: Hunter, on: bool) -> void:
	var team := m.player.team if on else 1
	t.team = team
	if t.remote:
		Net.lobby_emit("dn", {"c": "mate", "team": team, "down": on})
		await _run(0.6)
	elif on:
		m.knock(t, null, {})
	else:
		t.downed = false

func _kael(t: Hunter) -> void:
	_aim(t.pos)
	m.player.ak.use_e()
	await _run(0.3)
	m.player.ak.use_e()

## Backing away from the hook first: the pull starts with a slingshot.
func _sling(t: Hunter) -> void:
	var P := m.player
	_aim(t.pos)
	P.ak.use_e()
	await _run(0.3)
	P.inp["move"] = Vector2(-1, 0)
	await _run(0.3)
	note = "speed away %.1f m/s" % -P.vel.x
	P.ak.use_e()
	P.inp["move"] = Vector2.ZERO

func _meeko(t: Hunter) -> void:
	_aim(t.pos)
	m.player.ak.cast_ult()
	await _run(DT)

func _sparkle(t: Hunter) -> void:
	_aim(t.pos + Vector3(-1.5, 0, 0))
	m.player.ak.cast_ult()
	await _run(DT)
	m.player.ak.ult_recast()          # pressed in the crouch: she comes down after the hang

func _knock(t: Hunter) -> void:
	t.hurt(1.0, m.player, {"kb": Vector2(0, 16.0), "wallstun": 1.0, "src": "abil", "ab": "lmb", "melee": true})
	await _run(DT)

func _finish() -> void:
	Net.lobby_emit("dn", {"c": "done"})
	await main.get_tree().create_timer(1.5).timeout
	_dump("host")
	FileAccess.open(dir.path_join("stop"), FileAccess.WRITE).close()
	await main.get_tree().create_timer(1.5).timeout
	if rows.size() > 0:
		_report()
	for p in pids:
		if OS.is_process_running(p): OS.kill(p)
	print("DISPNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the numbers
## {nid: [[t, Vector3], ...]} from a log file.
func _load(who: String) -> Dictionary:
	var out := {}
	var p := dir.path_join(who + ".csv")
	if not FileAccess.file_exists(p):
		return out
	for line in FileAccess.get_file_as_string(p).split("\n", false):
		var f := line.split(",")
		if f.size() < 5: continue
		if not out.has(f[1]): out[f[1]] = []
		out[f[1]].append([float(f[0]), Vector3(float(f[2]), float(f[3]), float(f[4]))])
	return out

## A path inside [a, b]: its largest step between samples, its length, where it starts and ends.
static func _walk(log: Array, a: float, b: float) -> Dictionary:
	var r := {"max": 0.0, "len": 0.0, "start": Vector3.INF, "end": Vector3.INF}
	var prev := Vector3.INF
	for s in log:
		if s[0] < a or s[0] > b: continue
		if prev != Vector3.INF:
			var step: float = prev.distance_to(s[1])
			r["max"] = maxf(r["max"], step)
			r["len"] += step
		else:
			r["start"] = s[1]
		prev = s[1]
		r["end"] = s[1]
	return r

func _report() -> void:
	var host_log := _load("host")
	var guest_log := _load("guest")
	var server_log := _load("server")
	var me := "P" + Net.me
	var gu := "P" + peer_id
	var md := "| Move | Mover | Step/frame own (offline) | Step/frame other | Step/snapshot server | "
	md += "End: own vs offline | End: other vs own | End: server vs own | Moved vs offline | Note |\n"
	md += "|---|---|---|---|---|---|---|---|---|---|\n"
	for r in rows:
		for w in r["who"]:
			var nid: String = me if w == "self" else gu
			var own := _walk((host_log if w == "self" else guest_log).get(nid, []), r["on"][0], r["on"][1])
			var other := _walk((guest_log if w == "self" else host_log).get(nid, []), r["on"][0], r["on"][1])
			var srv := _walk(server_log.get(nid, []), r["on"][0], r["on"][1])
			var ref := _walk(host_log.get(me if w == "self" else "B", []), r["off"][0], r["off"][1])
			var what := "%s (%s)" % [r["name"], "Hunter " + ("self" if w == "self" else "moved")]
			var e_own: float = own["end"].distance_to(ref["end"]) if own["end"] != Vector3.INF else INF
			var e_oth: float = other["end"].distance_to(own["end"]) if other["end"] != Vector3.INF else INF
			var e_srv: float = srv["end"].distance_to(own["end"]) if srv["end"] != Vector3.INF else INF
			var d_own: float = own["start"].distance_to(own["end"]) if own["end"] != Vector3.INF else 0.0
			var d_ref: float = ref["start"].distance_to(ref["end"]) if ref["end"] != Vector3.INF else 0.0
			var ratio: float = d_own / maxf(d_ref, 0.01)
			var lratio: float = own["len"] / maxf(ref["len"], 0.01)
			md += "| %s | %s | %.2f (%.2f) | %.2f | %.2f | %.2f | %.2f | %.2f | %.1f vs %.1f m (x%.2f) | %s |\n" % [
				r["name"], "caster" if w == "self" else "moved Hunter", own["max"], ref["max"], other["max"],
				srv["max"], e_own, e_oth, e_srv, d_own, d_ref, ratio, r["note"]]
			var tag: String = "%s, %s" % [r["name"], w]
			ok(d_ref > MOVE_MIN and d_own > MOVE_MIN, "%s: moved (%.1f m online, %.1f offline)" % [tag, d_own, d_ref])
			ok(own["max"] < SNAP or r["tp"], "%s: no snap on its own game (step %.2f m)" % [tag, own["max"]])
			var ends := "%s: the ends agree (%.2f offline, %.2f other)" % [tag, e_own, e_oth]
			ok(e_own < END_TOL and e_oth < END_TOL, ends)
			ok(ratio < DOUBLE and lratio < DOUBLE, "%s: no double move (x%.2f, path x%.2f)" % [tag, ratio, lratio])
	print("ODISP table\n" + md)
	var f := FileAccess.open(dir.path_join("table.md"), FileAccess.WRITE)
	f.store_string(md)
	f.close()
