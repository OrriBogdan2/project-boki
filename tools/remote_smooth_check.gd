extends RefCounted
## --remote-smooth-check: another player's Hunter glides on your screen (NetInterp). Two real games over a
## desktop relay that holds every message LAG_S and drops LOSS of the "st" snapshots: this process is the
## host (it runs that relay in-process) and starts a second headless game, the guest
## (--remote-smooth-check=guest). The guest plays Kael (juggernaut) and walks circles, dashes, takes knocks,
## pulls itself in on its Warchain and is teleported; the host watches the guest's Hunter frame by frame.
## Asserts: the largest per-frame move of that Hunter on the host stays under JUMP_MAX (no snap on a walk,
## dash, knock or pull), and a teleport is a clean hard reset that lands within TP_LAND_S.
## Lines: SMOOTH ok|FAIL <what>; SMOOTH metric ... ; the guest prints SMOOTH guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for the guest to come up and build its match (the queue may hold it)
const SEED := 4243
const LAG_S := 0.1           # s: the relay holds every message this long (the simulated latency)
const JITTER_S := 0.02       # s: and the snapshots up to this much more (kept in order, as ENet's sequenced channel)
const LOSS := 0.02           # share of "st" snapshots the relay drops
const JUMP_MAX := 0.45       # m: the largest per-frame move of the remote Hunter allowed outside a teleport
                             # (27 m/s; the guest's fastest move here, the Warchain haul, is 22 m/s); more is a snap
const WINDOW_S := 1.2        # s after an action's notice the host counts frames against that action
const TP_LAND_S := 0.5       # s after the last teleport's notice the remote Hunter stands at the new spot
const TP_FAR := 8.0          # m: that teleport (past what anything travels between two snapshots)
const TP_SETTLE_S := 0.3     # s after a teleport lands its frames still don't count as jumps (a short one
                             # glides over one snapshot interval; that is the teleport, not a snap)
const CENTER := Vector3(2.5, 0, -2.0)   # m from home: the middle of the guest's walking circle
const RADIUS := 3.0          # m
const KNOCK := 12.0          # m/s: the knocks the guest takes (a heavy hit's shove)
const KNOCK_LIFT := 3.5      # m/s up with each

## The relay with a slow, lossy line: sends wait in a queue and go out in order once due.
class LaggyRelay extends RelayServer:
	var rng := RandomNumberGenerator.new()
	var due: Array = []      # [time, id, msg, fast]
	var last_due := 0.0

	func _send(id: int, d: Dictionary, fast := false) -> void:
		if fast and rng.randf() < LOSS:
			return
		var now := Time.get_ticks_msec() / 1000.0
		var at := now + LAG_S + (rng.randf() * JITTER_S if fast else 0.0)
		last_due = maxf(last_due, at)
		due.append([last_due, id, d, fast])

	func _process(dt: float) -> void:
		super._process(dt)
		var now := Time.get_ticks_msec() / 1000.0
		while not due.is_empty() and float(due[0][0]) <= now:
			var q: Array = due.pop_front()
			if clients.has(q[1]):
				super._send(q[1], q[2], q[3])

var main: Node
var bad := 0
var n := 0
var port := 0
var dir := ""
var guest_pid := 0
var m: Match = null
var home := Vector3.ZERO
var stop := false
var go := false
var notes: Array = []        # host: [local time, what, data] from the guest
var own_max := 0.0           # guest: its own fastest per-frame move

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("SMOOTH %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--remote-smooth-check=guest": guest = true
		if a.begins_with("--rs-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	port = 7990 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://remote_smooth")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := LaggyRelay.new()
	relay.rng.seed = SEED
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --remote-smooth-check=guest --rs-port=%d > '%s' 2>&1" % [
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
	var d := {"mid": "rs%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("rs", {"c": "start", "d": d})
	await _build(d)
	var G: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null and G.remote, "the guest's Hunter is here, driven by the guest's game")
	if G == null:
		return _finish()
	await _run(1.0)
	Net.lobby_emit("rs", {"c": "go"})
	await _watch(G)
	_finish()

## Records the guest's Hunter every frame until the guest says it is done, then judges each action.
func _watch(G: Hunter) -> void:
	var steps: Array = []    # [local time, metres moved this frame, position]
	var last := G.pos
	var t0 := Time.get_ticks_msec()
	while not notes.any(func(x): return x[1] == "done") and Time.get_ticks_msec() - t0 < 90000:
		await _run(DT)
		var now := Time.get_ticks_msec() / 1000.0
		steps.append([now, G.pos.distance_to(last), G.pos])
		last = G.pos
	var tps := notes.filter(func(x): return x[1] == "tp")
	for x in tps:
		x.append(_landed(steps, x))
	var tp_land := INF
	var tp_hop := 0.0        # m: the landing frame's move (a hard reset covers the whole teleport in one)
	if tps.size() > 0:
		tp_land = float(tps[-1][3]) - float(tps[-1][0])
		for s in steps:
			if s[0] == tps[-1][3]: tp_hop = s[1]
	var worst := 0.0
	var jerk := 0.0          # m: the largest change of the per-frame move between two frames
	var was := 0.0
	for s in steps:
		if tps.any(func(x): return s[0] >= x[0] - 0.1 and s[0] <= x[3] + TP_SETTLE_S):
			s[1] = -1.0      # (a teleport's frames are judged by its landing, not as jumps)
		worst = maxf(worst, s[1])
		if s[1] >= 0.0 and was >= 0.0: jerk = maxf(jerk, absf(s[1] - was))
		was = s[1]
	var tally := {}
	for x in notes:
		if not x[1] in ["walk", "dash", "knock", "pull"]:
			continue
		var big := 0.0
		for s in steps:
			if s[0] >= x[0] and s[0] < x[0] + WINDOW_S: big = maxf(big, s[1])
		var t: Array = tally.get(x[1], [0, 0, 0.0])
		tally[x[1]] = [t[0] + 1, t[1] + (1 if big > JUMP_MAX else 0), maxf(t[2], big)]
	var own := -1.0
	for x in notes:
		if x[1] == "done": own = float(x[2])
	print("SMOOTH metric frames %d, largest per-frame jump %.3f m (guest's own fastest frame %.3f m)" % [
		steps.size(), worst, own])
	print("SMOOTH metric largest change of the per-frame move between frames %.3f m" % jerk)
	var snaps := 0
	for k in tally:
		print("SMOOTH metric %s: %d of %d snapped (> %.2f m in a frame), largest frame %.3f m" % [
			k, tally[k][1], tally[k][0], JUMP_MAX, tally[k][2]])
		snaps += int(tally[k][1])
	ok(tally.size() == 4, "every action was seen: walk, dash, knock, pull", str(tally.keys()))
	ok(worst <= JUMP_MAX, "the remote Hunter never moves more than %.2f m in a frame" % JUMP_MAX, "%.3f m" % worst)
	ok(snaps == 0, "no dash, knock or Warchain pull snaps", "%d snaps" % snaps)
	ok(tp_land <= TP_LAND_S and tp_hop > TP_FAR * 0.8,
		"an %.0f m teleport lands in one frame (a hard reset, not a slide)" % TP_FAR,
		"%.2f s after the notice, %.2f m in the landing frame" % [tp_land, tp_hop])

func _finish() -> void:
	Net.lobby_emit("rs", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("SMOOTH DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _read_pid() -> void:
	if guest_pid > 0:
		return
	var p := dir.path_join("guest.log")
	if not FileAccess.file_exists(p):
		return
	for line in FileAccess.get_file_as_string(p).split("\n"):
		if line.begins_with("SMOOTH guest pid="):
			guest_pid = int(line.get_slice("=", 1))

# ------------------------------------------------------------------ the guest
func _guest() -> void:
	print("SMOOTH guest pid=%d" % OS.get_process_id())
	if not await _connect():
		print("SMOOTH guest: no relay")
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while not go and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
		if m: await _run(0.2)
	if go and m:
		await _routine()
	while m != null and not stop and Time.get_ticks_msec() - t0 < 600000:
		await _run(DT)
	main.get_tree().quit(0)

## What the guest's own player does, each action announced to the host as it starts.
func _routine() -> void:
	var P := m.player
	P.reclass(Arch.weight("juggernaut"), "juggernaut")
	P.unlock_all()
	P.lvl = 6
	P.teleport(home + CENTER + Vector3(RADIUS, 0, 0))
	await _run(0.5)
	_note("walk")
	await _circle(3.0, [])
	_note("walk")
	await _circle(3.0, [0.5, 1.5, 2.5])
	for i in 3:
		await _calm(home + CENTER)
		_note("knock")
		P.impulse(Vector2.from_angle(i * 2.1) * KNOCK * P.mass(), KNOCK_LIFT * P.mass())
		await _run(1.4)
	for i in 2:
		await _calm(home + Vector3(8.0, 0, -2.0 - i))
		_pull()
		await _run(2.0)
	await _calm(home + CENTER)
	_note("tp", home + CENTER + Vector3(0, 0, TP_FAR))
	P.teleport(home + CENTER + Vector3(0, 0, TP_FAR))
	await _run(1.5)
	_note("done", own_max)

## Walks a circle round CENTER for `secs`, dashing at the given seconds.
func _circle(secs: float, dash_at: Array) -> void:
	var P := m.player
	var t := 0.0
	while t < secs:
		var r := Vector2(P.pos.x - home.x - CENTER.x, P.pos.z - home.z - CENTER.z)
		var tangent := Vector2(-r.y, r.x).normalized()
		P.inp["move"] = (tangent - r.normalized() * (r.length() - RADIUS) * 0.3).normalized()
		P.inp["aim"] = P.pos + Vector3(tangent.x, 0.9, tangent.y) * 4.0
		for a in dash_at:
			if t <= a and t + DT > a:
				P.dashes = P.max_dashes()
				P.inp["dash"] = true
				_note("dash")
		await _run(DT)
		P.inp["dash"] = false
		t += DT
	P.inp["move"] = Vector2.ZERO

## Kael's Warchain on the host's Hunter, then the haul in to it.
func _pull() -> void:
	var P := m.player
	var K: JuggernautKit = P.ak
	var H: Hunter = m.ents_by_id.get("P" + Net.host, null)
	if H == null:
		return
	P.inp["aim"] = H.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = H.pos.y
	for k in K.cd: K.cd[k] = 0.0
	K.use_e()
	await _run(0.3)
	if K.warchain.hooked():
		_note("pull")
		K.use_e()

## Puts the guest at `at`, at rest, and gives the host's view time to settle.
func _calm(at: Vector3) -> void:
	var P := m.player
	P.inp["move"] = Vector2.ZERO
	P.vel = Vector3.ZERO
	P.stun_t = 0.0
	_note("tp", at)
	P.teleport(at)
	await _run(1.0)

func _note(what: String, d = null) -> void:
	if d is Vector3: d = [d.x, d.y, d.z]
	Net.lobby_emit("rs_n", {"w": what, "d": d})

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "rs_n":
		notes.append([Time.get_ticks_msec() / 1000.0, String(data["w"]), data.get("d")])
		return
	if topic != "rs":
		return
	match String(data.get("c", "")):
		"start": _build(data["d"])
		"go": go = true
		"done": stop = true

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "rs"})
	return Net.mode == "server"

## The same match on both games: the training island with the same seed, one Hunter each, a flat
## strip round the first spawn, no Boki, monsters or crates in the way.
func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	await nm.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": SEED, "no_drop": true,
		"cls": "medium", "net": d})
	nm.set_process(false)
	var W: World = nm.world
	var sp: Vector3 = W.spawns[0]
	var hx := int(floor(sp.x))
	var hz := int(floor(sp.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-14, 15):
		for dx in range(-12, 18):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for tiles in [W.stairs, W.walls, W.props, W.bush]:
				tiles.erase(i)
	for b in nm.breaks: b["dead"] = true
	home = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	for h in nm.hunters:
		if h.kin:
			h.kin.dead = true
			nm.kins.erase(h.kin)
			h.kin.queue_free()
			h.kin = null
	var P := nm.player
	P.max_hp = 100000.0
	P.hp = P.max_hp
	P.teleport(home if Net.is_host() else home + CENTER)
	m = nm

## Runs the match `secs` in real time (one step a frame at 60 fps), with no monsters about.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		var was := m.player.pos if m.player else Vector3.ZERO
		m.step(DT)
		if m.player and not Net.is_host():
			own_max = maxf(own_max, m.player.pos.distance_to(was))
		t += DT
		await main.get_tree().process_frame

## When the remote Hunter first stands within 0.3 m of a teleport's spot (INF: never).
static func _landed(steps: Array, tp: Array) -> float:
	for s in steps:
		if s[0] >= tp[0] and (s[2] as Vector3).distance_to(_v(tp[2])) < 0.3:
			return s[0]
	return INF

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
