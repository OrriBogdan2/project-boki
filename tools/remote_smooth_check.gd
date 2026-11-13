extends RefCounted
## --remote-smooth-check: how smoothly another player's Hunter moves on your screen over a bad line.
## Two real games over the desktop relay, like --displace-net-check (whose match builder it reuses): this
## process runs the relay and the host game; the guest (--remote-smooth-check=guest) is a second headless
## game. The relay here holds every packet 40 ms +-20 ms one way (80 ms ping, 20 ms jitter each way)
## and drops 2% of snapshots, keeping ENet's unreliable-ordered rule (a late snapshot behind a newer one
## is dropped). The host's Hunter runs, stops, turns, dashes, is lifted 5 m (a teleport), glides and is
## knocked, then becomes Sparkle and casts Kitefall (its scripted 0.2 s fall onto a spot 12 m off, numbered
## on its own); the guest records where its game draws that Hunter every frame. Both clocks are the wall clock:
## each game steps its match the way Match._process does (the frame's real time, at most 0.1 s, in whole
## DT steps) and draws the body between its last two steps, so a loaded machine's slow frames don't make
## the two match clocks drift apart (they don't in the game; one DT per frame did, and the gate's reds
## under load were that drift, not the line).
## Numbers (the drawn path against the true one, shifted by the best-fit delay):
##   snaps      frames where the drawn body moves faster than SNAP_STEP a DT; only the lift may (one jump, or
##              a sweep of at most LIFT_SWEEP when the line lost the snapshot before it)
##   jerks      frames where the drawn speed changes by more than JERK_DV while the true one doesn't
##              (snaps and jerks skip a frame longer than HITCH: that stutter is the game's own, not the line's)
##   backsteps  frames where the drawn body steps back against the way the true one moves
##   overshoot  frames where the drawn body is more than OFF_PATH from anywhere on the true path
##   max step   the drawn body's biggest step in one frame (the fall: under NET_CAP, no jump)
## Lines: RSMOOTH ok|FAIL <what>, RSMOOTH <phase> <numbers>; the guest prints RSMOOTH guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0        # s for the guest to come up and build its match
const ONE_WAY_MS := 40        # ms: half the 80 ms ping
const JITTER_MS := 20         # ms: each packet's one-way time is ONE_WAY_MS +- this
const LOSS := 0.02            # share of snapshots the line loses
const SNAP_STEP := 0.75       # m in one DT (45 m/s): faster than any run, dash or knock on screen
const MIN_FPS := 20.0         # frames a second the guest draws at least (a loaded gate machine runs ~40, not 60)
const HITCH := 0.1            # s: a frame longer than this is clipped by the match's own step cap
const JERK_DV := 1.5          # m/s change of the drawn speed in one frame that the true path doesn't make
const OFF_PATH := 0.3         # m from the true path that counts as an overshoot
const LIFT_SWEEP := 0.25      # s the lift may be swept over when the snapshot before it was lost (two gaps)
const LIFT := 5.0             # m the glide phase teleports the Hunter up
const NET_CAP := 4.0          # m in one frame: Ent.net_follow's snap distance, NetSmooth's SNAP_SPEED x 0.1 s
const KITE_OFF := Vector3(12.0, 0, 0)   # m from the take-off to the Kitefall landing, inside the flat strip
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
var acc := 0.0                 # s of real time the match hasn't stepped yet (Match.acc)
var fsteps := 0                # steps taken in this frame (Match steps at most 6)
var fw := 0.0                  # wall s of this frame
var last_us := 0

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
	var relay := LagRelay.new()
	relay.rng.seed = 80
	relay.name = "Relay"
	main.add_child(relay)
	var up := false
	for i in 40:       # the next port if another check's relay holds this one (a gate runs them side by side)
		dn.port = 7990 + (OS.get_process_id() + i) % 40
		up = relay.start(PackedStringArray(["--port=%d" % dn.port])) == OK
		if up: break
	ok(up, "the lag relay listens on %d" % dn.port)
	ok(await dn._connect(), "the host is on the relay")
	var cmd := "cd '%s' && timeout -k 5 300 %s --headless -- --remote-smooth-check=guest --rs-port=%d > '%s' 2>&1" % [
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
	await _kitefall(truth)

## Sparkle's Kitefall: crouch, rise, hang, then the scripted fall the snapshot reports a velocity for.
## "move" (the reset to the strip's start and its settle) is left out of the numbers.
func _kitefall(truth: Array) -> void:
	var P := m.player
	P.reclass("light", "mage")
	P.teleport(dn.home + Vector3(-5.0, 0, 0))
	await _host_run(0.8, "move", truth)
	var U: MageUlt = (P.ak as MageKit).ult
	P.inp["aim"] = P.pos + KITE_OFF
	ok(U.cast(), "Kitefall goes off on the host")
	await _host_run(0.9, "fall", truth)
	ok(U.phase() == MageUlt.AIR, "Kitefall hangs", U.phase())
	U.recast()
	await _host_run(1.0, "fall", truth)

## Runs the host's match for `secs` of match time on the wall clock. A frame can end mid-call: the next
## call (new inputs) takes the rest of its steps, and that call records the frame.
func _host_run(secs: float, phase: String, truth: Array) -> void:
	var n := maxi(1, roundi(secs / DT))
	while true:
		while acc >= DT and n > 0 and fsteps < 6:
			acc -= DT
			fsteps += 1
			n -= 1
			for mb in m.mobs: mb.queue_free()
			m.mobs.clear()
			m.step(DT)
		if n == 0:
			return
		if phase != "":
			var p := _drawn(m.player)
			truth.append([fw, p.x, p.y, p.z, phase])
		await _frame()

## Waits one frame and adds its real time to the match's (Match._process: at most 0.1 s).
func _frame() -> void:
	await main.get_tree().process_frame
	var us := Time.get_ticks_usec()
	if last_us > 0:
		acc += minf((us - last_us) / 1000000.0, HITCH)
	last_us = us
	fsteps = 0
	fw = Time.get_unix_time_from_system()

## Where the screen draws e this frame: between its last two steps (Ent.render's alpha).
func _drawn(e: Ent) -> Vector3:
	return e.prev.lerp(e.pos, acc / DT)

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
	var move_w := w1                 # wall time of the reset before Kitefall, and of its cast
	var fall_w := w1
	for x in truth:
		if x[4] == "move": move_w = minf(move_w, x[0])
		if x[4] == "fall": fall_w = minf(fall_w, x[0])
	var lag := _best_lag(truth, drawn, w0, move_w - 0.3)
	var tele_w := 0.0                # wall time of the lift on the true path
	for i in range(1, truth.size()):
		var lift: bool = truth[i][4] == "glide" and _p(truth[i]).distance_to(_p(truth[i - 1])) > LIFT * 0.8
		if lift: tele_w = truth[i][0]
	var tot := {}
	var phases := ["idle", "run", "dash", "glide", "knock", "all", "fall"]
	for ph in phases:
		tot[ph] = {"n": 0, "snaps": 0, "big": 0, "jerks": 0, "backsteps": 0, "overshoot": 0, "max_off": 0.0, "err": 0.0,
			"stray": 0, "top": 0.0, "true_top": 0.0, "max_step": 0.0}
	var j := 0
	for i in range(2, drawn.size()):
		var w: float = float(drawn[i][0]) - lag
		if w < w0 + 0.2 or w > w1:
			continue
		while j < truth.size() - 2 and truth[j + 1][0] < w: j += 1
		var ph: String = truth[j][4]
		if w > move_w - 0.3 and w < fall_w:
			continue
		var q := _p(drawn[i])
		var step := q - _p(drawn[i - 1])
		var dt1 := float(drawn[i][0]) - float(drawn[i - 1][0])
		var dt0 := float(drawn[i - 1][0]) - float(drawn[i - 2][0])
		var hitch := dt1 > HITCH or dt0 > HITCH or dt1 <= 0.0 or dt0 <= 0.0
		var dv := 0.0 if hitch else (step / dt1 - (_p(drawn[i - 1]) - _p(drawn[i - 2])) / dt0).length()
		var near_tele := absf(w - tele_w) < 0.35
		var tv := _true_vel(truth, j)
		var off := _off_path(truth, j, q)
		for k in ([ph] if ph == "fall" else [ph, "all"]):
			var r: Dictionary = tot[k]
			r["n"] += 1
			r["max_step"] = maxf(r["max_step"], step.length())
			r["err"] += q.distance_to(_true_at(truth, j, w))
			if step.length() > LIFT * 0.8:
				r["big"] += 1          # (the lift counts on any frame, a hitched one too)
				r["snaps"] += 1
			elif not hitch and step.length() > SNAP_STEP * dt1 / DT:
				r["snaps"] += 1
				if not near_tele: r["stray"] += 1
			if near_tele: continue
			if not hitch:
				r["top"] = maxf(r["top"], step.length() / dt1)
			r["true_top"] = maxf(r["true_top"], tv.length())
			if not hitch and dv > JERK_DV and _true_dv(truth, j) < JERK_DV: r["jerks"] += 1
			if tv.length() > 1.0 and step.dot(tv.normalized()) < -0.01: r["backsteps"] += 1
			if off > OFF_PATH: r["overshoot"] += 1
			r["max_off"] = maxf(r["max_off"], off)
	print("RSMOOTH line: %d ms +-%d ms one way, %.0f%% loss (%d snapshots lost or overtaken); drawn %.0f ms behind" % [
		ONE_WAY_MS, JITTER_MS, LOSS * 100.0, lost, lag * 1000.0])
	for ph in phases:
		var r: Dictionary = tot[ph]
		var head := "RSMOOTH %-5s frames %4d  snaps %2d  jerks %3d" % [ph, r["n"], r["snaps"], r["jerks"]]
		var err: float = r["err"] / maxf(1.0, r["n"])
		print(head + "  backsteps %3d  overshoot %3d (max %.2f m)  mean err %.2f m  top %.0f m/s (true %.0f)  max step %.2f m" % [
			r["backsteps"], r["overshoot"], r["max_off"], err, r["top"], r["true_top"], r["max_step"]])
	var a: Dictionary = tot["all"]
	var fps: float = a["n"] / maxf(0.001, w1 - w0 - 0.2)
	ok(a["n"] > 0 and fps >= MIN_FPS and float(drawn[-1][0]) >= w1, "the guest drew the whole run",
		"%d frames, %.0f a second" % [a["n"], fps])
	var sweep := _lift_sweep(drawn, lag, tele_w)
	ok(a["stray"] == 0 and sweep <= LIFT_SWEEP, "the lift is one jump or one quick sweep and nothing else snaps",
		"%d snaps, %d away from the lift; the lift drawn in %.2f s" % [a["snaps"], a["stray"], sweep])
	ok(a["jerks"] <= 15, "the drawn speed changes only where the true one does", "%d jerks" % a["jerks"])
	ok(a["backsteps"] == 0, "the drawn body never steps back", "%d backsteps" % a["backsteps"])
	ok(a["overshoot"] == 0, "the drawn body stays on the true path", "max %.2f m off" % a["max_off"])
	ok(lag < 0.25, "drawn at most 250 ms behind", "%.0f ms" % (lag * 1000.0))
	var f: Dictionary = tot["fall"]
	ok(f["n"] > 60 and f["max_step"] < NET_CAP, "Kitefall's fall is drawn as a drop, not a jump",
		"%d frames, max step %.2f m" % [f["n"], f["max_step"]])

## How long the drawn body took to rise through the lift: 0 when it went in one frame (however long the frame).
## With the snapshot before the lift lost, two snapshots 0.2 s apart and 5 m apart with both ends at rest read
## the same at 10 a second as a standing dash between them (18 m/s), so NetSmooth sweeps it; it must not take
## longer than those two gaps.
static func _lift_sweep(drawn: Array, lag: float, tele_w: float) -> float:
	var lo := -1
	for i in drawn.size():
		var w: float = float(drawn[i][0]) - lag
		if absf(w - tele_w) > 0.5:
			continue
		var y := float(drawn[i][2])
		if y < 0.5:
			lo = i
		elif y > LIFT - 0.5 and lo >= 0:
			return 0.0 if i == lo + 1 else float(drawn[i][0]) - float(drawn[lo][0])
	return INF

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
		var dt1 := maxf(0.001, float(truth[i][0]) - float(truth[i - 1][0]))
		var dt0 := maxf(0.001, float(truth[i - 1][0]) - float(truth[i - 2][0]))
		var v1 := (_p(truth[i]) - _p(truth[i - 1])) / dt1
		var v0 := (_p(truth[i - 1]) - _p(truth[i - 2])) / dt0
		top = maxf(top, (v1 - v0).length())
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
		while acc >= DT and fsteps < 6:
			acc -= DT
			fsteps += 1
			for mb in m.mobs: mb.queue_free()       # (as on the host: nothing shoves the bodies)
			m.mobs.clear()
			m.step(DT)
		var H: Ent = m.ents_by_id.get("P" + Net.host, null)
		if H:
			var p := _drawn(H)
			rec.append([fw, p.x, p.y, p.z])
		await _frame()
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
