extends RefCounted
## --remote-smooth-check: how smoothly another player's Hunter moves on your screen over a bad line.
## Two real games over the desktop relay, like --displace-net-check (whose match builder it reuses): this
## process runs the relay and the host game; the guest (--remote-smooth-check=guest) is a second headless
## game. The relay here holds every packet 40 ms +-20 ms one way (80 ms ping, 20 ms jitter each way)
## and drops 2% of snapshots, keeping ENet's unreliable-ordered rule (a late snapshot behind a newer one
## is dropped). The host's Hunter runs, stops, turns, dashes, is lifted 5 m (a teleport), glides and is
## knocked; the guest records where its game puts that Hunter every frame. Both clocks are the wall clock.
## Numbers (the drawn path against the true one, shifted by the best-fit delay):
##   snaps      frames where the drawn body jumps more than SNAP_STEP; only the one teleport may
##   jerks      frames where the drawn speed changes by more than JERK_DV while the true one doesn't
##   backsteps  frames where the drawn body steps back against the way the true one moves
##   overshoot  frames where the drawn body is more than OFF_PATH from anywhere on the true path
## Lines: RSMOOTH ok|FAIL <what>, RSMOOTH <phase> <numbers>; the guest prints RSMOOTH guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0        # s for the guest to come up and build its match
const ONE_WAY_MS := 40        # ms: half the 80 ms ping
const JITTER_MS := 20         # ms: each packet's one-way time is ONE_WAY_MS +- this
const LOSS := 0.02            # share of snapshots the line loses
const SNAP_STEP := 0.75       # m in one frame (45 m/s): faster than any run, dash or knock on screen
const JERK_DV := 1.5          # m/s change of the drawn speed in one frame that the true path doesn't make
const OFF_PATH := 0.3         # m from the true path that counts as an overshoot
const LIFT := 5.0             # m the glide phase teleports the Hunter up
const DN := preload("res://tools/displace_net_check.gd")

## The relay with a bad line: every send waits its one-way time; snapshots may be lost or overtaken.
class LagRelay extends RelayServer:
	var rng := RandomNumberGenerator.new()
	var held: Array = []          # [due msec, peer id, message, fast, seq]
	var seq := 0
	var last_fast := {}           # peer id -> seq of the newest snapshot it got
	var last_due := {}            # peer id -> due msec of its last reliable message (they stay in order)
	var lost := 0

	func _send(id: int, d: Dictionary, fast := false) -> void:
		seq += 1
		if fast and rng.randf() < LOSS:
			lost += 1
			return
		var due := Time.get_ticks_msec() + ONE_WAY_MS + rng.randi_range(-JITTER_MS, JITTER_MS)
		if not fast:
			due = maxi(due, int(last_due.get(id, 0)))
			last_due[id] = due
		held.append([due, id, d, fast, seq])

	func _process(dt: float) -> void:
		super._process(dt)
		var now := Time.get_ticks_msec()
		held.sort_custom(func(a, b): return a[0] < b[0])
		while not held.is_empty() and int(held[0][0]) <= now:
			var x: Array = held.pop_front()
			if x[3]:
				if int(x[4]) < int(last_fast.get(x[1], 0)):
					lost += 1
					continue
				last_fast[x[1]] = x[4]
			super._send(x[1], x[2], x[3])

var main: Node
var bad := 0
var dn                         # the --displace-net-check helper that builds the shared match
var m: Match = null
var stop := false
var dumped := false
var rec: Array = []            # guest: [wall s, x, y, z] of the host's Hunter each frame
var guest_pid := 0
var dir := ""

func ok(cond: bool, what: String, info := "") -> void:
	print("RSMOOTH %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	dn = DN.new()
	dn.main = main
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--remote-smooth-check=guest": guest = true
		if a.begins_with("--rs-port="): dn.port = int(a.substr(10))
	dir = ProjectSettings.globalize_path("user://remote_smooth")
	DirAccess.make_dir_recursive_absolute(dir)
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	dn.port = 7990 + OS.get_process_id() % 40
	var relay := LagRelay.new()
	relay.rng.seed = 80
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % dn.port])) == OK, "the lag relay listens on %d" % dn.port)
	ok(await dn._connect(), "the host is on the relay")
	var cmd := "cd '%s' && %s --headless -- --remote-smooth-check=guest --rs-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, dn.port, dir.path_join("guest.log")]
	OS.create_process("/bin/sh", ["-c", cmd])
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
	ok(other != "", "the guest joins the relay")
	if other == "":
		return _finish()
	var d := {"mid": "rs%d" % dn.port, "seed": DN.SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("rs", {"c": "start", "d": d})
	await dn._build(d)
	m = dn.m
	var G: Hunter = null
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _host_run(0.2, "", [])
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null, "the guest's game is sending")
	await _host_run(2.0, "", [])      # the guest settles its clock and buffer
	var truth: Array = []
	await _script(truth)
	Net.lobby_emit("rs", {"c": "dump"})
	var t2 := Time.get_ticks_msec()
	while not dumped and Time.get_ticks_msec() - t2 < 20000:
		await _host_run(0.1, "", [])
	ok(dumped, "the guest wrote its record")
	if dumped:
		_report(truth, JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("drawn.json"))), relay.lost)
	_finish()

## The run the host's Hunter makes, recorded as [wall s, x, y, z, phase].
func _script(truth: Array) -> void:
	var P := m.player
	var home: Vector3 = dn.home
	P.teleport(home + Vector3(-5.0, 0, -5.0))
	await _host_run(0.5, "idle", truth)
	P.inp["move"] = Vector2(1, 0)
	await _host_run(1.4, "run", truth)
	P.inp["move"] = Vector2.ZERO
	await _host_run(0.5, "run", truth)       # let go: a quick stop
	P.inp["move"] = Vector2(0, 1)
	await _host_run(0.8, "run", truth)
	P.inp["move"] = Vector2(-1, 0)          # a hard turn
	await _host_run(0.3, "run", truth)
	P.inp["dash"] = true
	await _host_run(DT, "dash", truth)
	P.inp["dash"] = false
	await _host_run(0.7, "dash", truth)
	P.inp["move"] = Vector2.ZERO
	await _host_run(0.5, "dash", truth)
	P.teleport(P.pos + Vector3(0, LIFT, 0))
	P.inp["move"] = Vector2(1, 0)
	P.inp["glide"] = true
	P.inp["glide_btn"] = true
	await _host_run(2.5, "glide", truth)
	P.inp["glide"] = false
	P.inp["glide_btn"] = false
	P.inp["move"] = Vector2.ZERO
	await _host_run(1.0, "glide", truth)
	m.displace.knock(P, Vector2(0, -9.0) * P.mass())      # 9 m/s: a solid hit, lifts it off its feet
	await _host_run(1.2, "knock", truth)

func _host_run(secs: float, phase: String, truth: Array) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		if phase != "":
			var p := m.player.pos
			truth.append([Time.get_unix_time_from_system(), p.x, p.y, p.z, phase])
		await main.get_tree().process_frame

func _finish() -> void:
	Net.lobby_emit("rs", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	var p := dir.path_join("guest.log")
	if FileAccess.file_exists(p):
		for line in FileAccess.get_file_as_string(p).split("\n"):
			if line.begins_with("RSMOOTH guest pid="): guest_pid = int(line.get_slice("=", 1))
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("RSMOOTH DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the numbers
func _report(truth: Array, drawn, lost: int) -> void:
	if typeof(drawn) != TYPE_ARRAY or truth.size() < 60:
		ok(false, "records to compare")
		return
	var w0: float = truth[0][0]
	var w1: float = truth[-1][0]
	var lag := _best_lag(truth, drawn, w0, w1)
	var tele_w := 0.0                # wall time of the lift on the true path
	for i in range(1, truth.size()):
		if _p(truth[i]).distance_to(_p(truth[i - 1])) > LIFT * 0.8: tele_w = truth[i][0]
	var tot := {}
	var phases := ["idle", "run", "dash", "glide", "knock", "all"]
	for ph in phases:
		tot[ph] = {"n": 0, "snaps": 0, "big": 0, "jerks": 0, "backsteps": 0, "overshoot": 0, "max_off": 0.0, "err": 0.0}
	var j := 0
	for i in range(2, drawn.size()):
		var w: float = float(drawn[i][0]) - lag
		if w < w0 + 0.2 or w > w1:
			continue
		while j < truth.size() - 2 and truth[j + 1][0] < w: j += 1
		var ph: String = truth[j][4]
		var q := _p(drawn[i])
		var step := q - _p(drawn[i - 1])
		var dv := (step - (_p(drawn[i - 1]) - _p(drawn[i - 2]))).length() / DT
		var near_tele := absf(w - tele_w) < 0.35
		var tv := _true_vel(truth, j)
		var off := _off_path(truth, j, q)
		for k in [ph, "all"]:
			var r: Dictionary = tot[k]
			r["n"] += 1
			r["err"] += q.distance_to(_true_at(truth, j, w))
			if step.length() > SNAP_STEP: r["snaps"] += 1
			if step.length() > LIFT * 0.8: r["big"] += 1
			if near_tele: continue
			if dv > JERK_DV and _true_dv(truth, j) < JERK_DV: r["jerks"] += 1
			if tv.length() > 1.0 and step.dot(tv.normalized()) < -0.01: r["backsteps"] += 1
			if off > OFF_PATH: r["overshoot"] += 1
			r["max_off"] = maxf(r["max_off"], off)
	print("RSMOOTH line: %d ms +-%d ms one way, %.0f%% loss (%d snapshots lost or overtaken); drawn %.0f ms behind" % [
		ONE_WAY_MS, JITTER_MS, LOSS * 100.0, lost, lag * 1000.0])
	for ph in phases:
		var r: Dictionary = tot[ph]
		var head := "RSMOOTH %-5s frames %4d  snaps %2d  jerks %3d" % [ph, r["n"], r["snaps"], r["jerks"]]
		var err: float = r["err"] / maxf(1.0, r["n"])
		print(head + "  backsteps %3d  overshoot %3d (max %.2f m)  mean err %.2f m" % [
			r["backsteps"], r["overshoot"], r["max_off"], err])
	var a: Dictionary = tot["all"]
	ok(a["n"] > 400, "the guest drew the whole run", "%d frames" % a["n"])
	ok(a["big"] == 1 and a["snaps"] == 1, "the lift is one snap and nothing else snaps", "%d snaps" % a["snaps"])
	ok(a["jerks"] <= 15, "the drawn speed changes only where the true one does", "%d jerks" % a["jerks"])
	ok(a["backsteps"] == 0, "the drawn body never steps back", "%d backsteps" % a["backsteps"])
	ok(a["overshoot"] == 0, "the drawn body stays on the true path", "max %.2f m off" % a["max_off"])
	ok(lag < 0.25, "drawn at most 250 ms behind", "%.0f ms" % (lag * 1000.0))

## The delay (s) that best lines the drawn path up with the true one.
func _best_lag(truth: Array, drawn: Array, w0: float, w1: float) -> float:
	var best := 0.0
	var best_err := INF
	for ms in range(0, 400, 5):
		var lag := ms / 1000.0
		var err := 0.0
		var j := 0
		for x in drawn:
			var w: float = float(x[0]) - lag
			if w < w0 + 0.2 or w > w1: continue
			while j < truth.size() - 2 and truth[j + 1][0] < w: j += 1
			err += _p(x).distance_to(_true_at(truth, j, w))
		if err < best_err:
			best_err = err
			best = lag
	return best

static func _p(x: Array) -> Vector3:
	return Vector3(float(x[1]), float(x[2]), float(x[3]))

static func _true_at(truth: Array, j: int, w: float) -> Vector3:
	var a: Array = truth[j]
	var b: Array = truth[j + 1]
	var k := clampf((w - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
	return _p(a).lerp(_p(b), k)

static func _true_vel(truth: Array, j: int) -> Vector3:
	var a: Array = truth[maxi(0, j - 3)]
	var b: Array = truth[mini(truth.size() - 1, j + 3)]
	return (_p(b) - _p(a)) / maxf(0.001, float(b[0]) - float(a[0]))

## The biggest one-step speed change the true path makes within 0.1 s of sample j.
static func _true_dv(truth: Array, j: int) -> float:
	var top := 0.0
	for i in range(maxi(2, j - 6), mini(truth.size(), j + 7)):
		var v1 := _p(truth[i]) - _p(truth[i - 1])
		var v0 := _p(truth[i - 1]) - _p(truth[i - 2])
		top = maxf(top, (v1 - v0).length() / DT)
	return top

## How far q is from the true path within half a second of sample j.
static func _off_path(truth: Array, j: int, q: Vector3) -> float:
	var best := INF
	for i in range(maxi(1, j - 30), mini(truth.size(), j + 31)):
		var c := Geometry3D.get_closest_point_to_segment(q, _p(truth[i - 1]), _p(truth[i]))
		best = minf(best, q.distance_to(c))
	return best

# ------------------------------------------------------------------ the guest
func _guest() -> void:
	print("RSMOOTH guest pid=%d" % OS.get_process_id())
	if not await dn._connect():
		print("RSMOOTH guest: no relay")
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while m == null and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	while m != null and not stop and Time.get_ticks_msec() - t0 < 600000:
		for mb in m.mobs: mb.queue_free()       # (as on the host: nothing shoves the bodies)
		m.mobs.clear()
		m.step(DT)
		var H: Ent = m.ents_by_id.get("P" + Net.host, null)
		if H:
			rec.append([Time.get_unix_time_from_system(), H.pos.x, H.pos.y, H.pos.z])
		await main.get_tree().process_frame
	main.get_tree().quit(0)

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "rs_r":
		dumped = true
		return
	if topic != "rs":
		return
	match String(data.get("c", "")):
		"start":
			await dn._build(data["d"])
			m = dn.m
		"dump":
			var f := FileAccess.open(dir.path_join("drawn.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(rec, "", true, true))
			f.close()
			Net.lobby_emit("rs_r", {"n": rec.size()})
		"done": stop = true
