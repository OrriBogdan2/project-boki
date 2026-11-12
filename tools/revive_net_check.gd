extends RefCounted
## --revive-net-check: deathboxes and revives between two real games (docs/decisions/0018). This process
## is the host (it runs the relay in-process) and starts a second headless game, the guest
## (--revive-net-check=guest). Both are squad-mates in the same seeded match.
##  1. The guest dies on its own game: a box drops there, nothing ends for it, and the host sees it out
##     with a soul marker at the same spot.
##  2. The host holds interact at that marker for BoxRevive.time_for seconds: the guest's own game
##     brings it back at the box with its carried keys, and the host's copy of it stands up.
##  3. The guest dies again: a revive beacon the host stands on brings it back at the beacon, full
##     health with resurrection sickness, and both games have the beacon used.
##  4. The guest dies a third time and is gone for good: the host's marker no longer takes a revive.
## Lines: RVNET ok|FAIL <what>; the guest prints RVNET guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for the guest to come up and build its match
const SEED := 4242
const KEYS := 1              # rift keys the guest carries into its first death (the belt holds one)

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
	print("RVNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--revive-net-check=guest": guest = true
		if a.begins_with("--rn-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	port = 7990 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://revive_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --revive-net-check=guest --rn-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, port, dir.path_join("guest.log")]
	OS.create_process("/bin/sh", ["-c", cmd])
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
		_read_pid()
	ok(other != "", "the guest joins the relay", other)
	if other == "":
		return _finish()
	var d := {"mid": "rn%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 2, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 0, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("rn", {"c": "start", "d": d})
	await _build(d)
	var G: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null and G.remote, "the guest's hunter is here, driven by the guest's game")
	if G == null:
		return _finish()
	await _box_case(G)
	await _beacon_case(G)
	await _gone_case(G)
	_finish()

func _box_case(G: Hunter) -> void:
	var P := m.player
	var g: Dictionary = await _ask()
	var same: bool = m.beacons.size() > 0 and int(g.get("beacons", -1)) == m.beacons.size()
	ok(same and _v(g["b0"]).distance_to(m.beacons[0]["pos"]) < 0.1,
		"both games place the same beacons", "%d here, %d there" % [m.beacons.size(), int(g.get("beacons", -1))])
	g = await _say_do("die", 1.0)
	ok(bool(g["out"]) and not bool(g["gone"]) and not bool(g["ended"]),
		"the guest's death waits for its squad (no match end, not gone)")
	ok(int(g["boxes"]) == 1, "the guest's own game dropped one deathbox")
	await _run(0.5)
	var b := Life.box_of(m, G)
	ok(G.out and not G.gone and not b.is_empty(), "the host sees the guest out, with a soul marker",
		"boxes here %d" % m.boxes.size())
	if b.is_empty():
		return
	ok((b["pos"] as Vector3).distance_to(_v(g["box"])) < 0.1, "the marker stands where the guest's box is")
	P.teleport(b["pos"])
	var need := BoxRevive.time_for(G)
	var t := await _hold(P, G, need + 4.0)
	g = await _say_do("ask", 0.5)
	ok(absf(t - need) < 0.6, "the host's channel brings the guest back in the box-revive time",
		"%.1f s, want %.1f" % [t, need])
	ok(not bool(g["out"]) and not G.out, "the guest is up on its own game and on the host's copy")
	var frac := float(g["hp"]) / float(g["max"])
	ok(absf(frac - float(Life.R["box_revive_hp"])) < 0.05, "back at box-revive health", "%.2f" % frac)
	ok(int(g["keys"]) == KEYS, "the box gave back what the guest carried", "%d keys" % int(g["keys"]))
	ok(_v(g["pos"]).distance_to(b["pos"]) < 4.0, "back at the box")

func _beacon_case(G: Hunter) -> void:
	var P := m.player
	var g: Dictionary = await _say_do("die", 1.0)
	await _run(0.5)
	ok(bool(g["out"]) and G.out, "the guest dies again, both games agree")
	var bc: Dictionary = m.beacons[0]
	P.teleport(bc["pos"])
	P.vel = Vector3.ZERO
	var t0 := m.time
	while G.out and m.time - t0 < Beacons.time_s() + 6.0:
		await _run(0.1)
	g = await _say_do("ask", 0.5)
	ok(not bool(g["out"]) and not G.out, "the beacon brings the guest back on its own game", "%.1f s" % (m.time - t0))
	ok(bool(bc["used"]) and bool(g["used"]), "the beacon is used on both games")
	ok(float(g["hp"]) >= float(g["max"]) * 0.99 and float(g["sick"]) > 0.0, "full health with resurrection sickness")
	ok(_v(g["pos"]).distance_to(bc["pos"]) < 4.0, "back at the beacon")

func _gone_case(G: Hunter) -> void:
	var P := m.player
	await _say_do("die", 1.0)
	await _run(0.5)
	var b := Life.box_of(m, G)
	ok(G.out and not b.is_empty() and Life.soul_here(m, b), "dead again: the marker takes a revive")
	await _say_do("gone", 0.5)
	await _run(0.5)
	ok(G.gone and not Life.soul_here(m, b), "gone for good on the guest: the host's marker stops taking revives")
	P.teleport(b["pos"])
	await _hold(P, G, 2.0)
	ok(G.out, "holding at it brings nobody back")

## Holds interact on `C` until `B` is up or `cap` seconds pass; returns the seconds taken.
func _hold(C: Hunter, B: Hunter, cap: float) -> float:
	var t0 := m.time
	while B.out and m.time - t0 < cap:
		C.inp["interact"] = true
		await _run(DT)
	C.inp["interact"] = false
	await _run(DT * 2.0)
	return m.time - t0

func _finish() -> void:
	Net.lobby_emit("rn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("RVNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _read_pid() -> void:
	if guest_pid > 0:
		return
	var p := dir.path_join("guest.log")
	if not FileAccess.file_exists(p):
		return
	for line in FileAccess.get_file_as_string(p).split("\n"):
		if line.begins_with("RVNET guest pid="):
			guest_pid = int(line.get_slice("=", 1))

## Tells the guest to do `c`, lets both games run `secs`, and returns what the guest says back.
func _say_do(c: String, secs: float) -> Dictionary:
	replies.clear()
	Net.lobby_emit("rn", {"c": c})
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
	print("RVNET guest pid=%d" % OS.get_process_id())
	if not await _connect():
		print("RVNET guest: no relay")
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
	if topic == "rn_r":
		replies.append(data)
		return
	if topic != "rn":
		return
	match String(data.get("c", "")):
		"start": _build(data["d"])
		"done": stop = true
		"die":
			if m and m.player:
				m.player.rift_keys = KEYS
				m.eliminate(m.player, null, "test")
			_say()
		"gone":
			if m and m.player: Life.make_gone(m, m.player)
			_say()
		"ask": _say()

func _say() -> void:
	if m == null or m.player == null:
		return
	var P := m.player
	var b := Life.box_of(m, P)
	Net.lobby_emit("rn_r", {
		"out": P.out, "gone": P.gone, "hp": P.hp, "max": P.max_hp, "sick": P.sick_t, "keys": P.rift_keys,
		"pos": [P.pos.x, P.pos.y, P.pos.z], "boxes": m.boxes.size(), "ended": m.result.get("ending", false),
		"box": [b["pos"].x, b["pos"].y, b["pos"].z] if not b.is_empty() else [0, 0, 0],
		"beacons": m.beacons.size(), "b0": [m.beacons[0]["pos"].x, m.beacons[0]["pos"].y, m.beacons[0]["pos"].z],
		"used": m.beacons[0]["used"]})

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "rn"})
	return Net.mode == "server"

## The same match on both games: the same seed, squad-mates of one team, the bots idle, no Boki.
func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	await nm.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": SEED, "no_drop": true, "cls": "medium",
		"net": d})
	nm.set_process(false)
	for h in nm.hunters:
		if h.ctrl == "bot": h.ctrl = "idle"
		h.lives = 1
		h.max_hp = 10000.0
		h.hp = h.max_hp
		if h.kin:
			h.kin.dead = true
			nm.kins.erase(h.kin)
			h.kin.queue_free()
			h.kin = null
	m = nm

## Runs the match `secs` in real time (one step a frame at 60 fps), with no monsters about.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		await main.get_tree().process_frame

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
