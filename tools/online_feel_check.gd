extends RefCounted
## --online-feel-check: how an online game feels with 100 ms of added delay each way (docs/ONLINE_FEEL.md).
## Two real headless games over the desktop relay, like --displace-net-check. This process is the host: it
## runs the relay in-process and watches. The actor (--online-feel-check=guest) connects through
## tools/online_feel_proxy.py, a userspace stand-in for `tc netem delay 100ms` (every packet held 100 ms
## each way, so 200 ms round trip). The actor presses dash, LMB, E and a recast as Vex, Kael and Neve; all
## clocks are this machine's wall clock, so one press can be followed on both games and at the relay.
## Lines: OFEEL ok|FAIL <what>, OFEEL row ... (ms from the press), OFEEL smooth ... (remote Hunter in a dash).

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for the actor to come up and build its match
const LAG_MS := 100.0        # added delay each way on the actor's link
const SEED := 4242
const REPS := 5             # presses per hero and case: the table shows the median and the range
const PARK := Vector3(0, 0, -9.0)       # m from home: where the actor stands
const HEROES := ["gunslinger", "juggernaut", "rimewright"]      # Vex, Kael, Neve
const CASES := ["dash", "lmb", "e", "recast"]
const NET_SLACK_MS := 60.0   # ms: what the game may add on top of the line's delay before the relay hears a press
const STAGES := ["local", "moved", "relay", "seen"]      # the table columns, ms from the press
const MOVED := 0.05          # m: a position that moved less than this has not moved
const SIG_AT := [2, 3, 4, 5, 6, 7, 8, 11, 31]      # hunter snapshot fields that change when it moves, turns or casts
const AGE_AT := 32          # the kit move's age: a drop in it is the same move cast again

var main: Node
var bad := 0
var port := 0
var dir := ""
var pids: Array = []
var m: Match = null
var home := Vector3.ZERO
var stop := false
var req := {}                # the actor: the case it was asked to run
var replies: Array = []      # the host: what the actor said back
var gid := ""                # the actor's peer id
var sniff: Array = []        # [wall time, what changed] in the actor's packets as the relay gets them
var last_sig: Array = []
var smooth := {}            # hero -> worst remote-dash numbers (see _smooth)
var rows := {}              # "hero case" -> {stage: [ms]}
var copy_trace: Array = []   # the host: [wall time, x, z] of its copy of the actor, every step

func ok(cond: bool, what: String, info := "") -> void:
	print("OFEEL %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

static func now() -> float:
	return Time.get_unix_time_from_system()

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--of-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if "--online-feel-check=guest" in OS.get_cmdline_user_args():
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	port = 7900 + OS.get_process_id() % 50
	dir = ProjectSettings.globalize_path("user://online_feel")
	DirAccess.make_dir_recursive_absolute(dir)
	var root := ProjectSettings.globalize_path("res://")
	var relay := RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	relay.api.peer_packet.connect(func(id: int, bytes: PackedByteArray): _sniff(str(id), bytes))
	var proxy := root.path_join("tools/online_feel_proxy.py")
	pids.append(OS.create_process("python3", [proxy, str(port + 100), str(port), str(LAG_MS)]))
	ok(await _connect(port), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --online-feel-check=guest --of-port=%d > '%s' 2>&1" % [
		root, GODOT, port + 100, dir.path_join("guest.log")]
	pids.append(OS.create_process("/bin/sh", ["-c", cmd]))
	var t0 := Time.get_ticks_msec()
	while gid == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: gid = String(id)
	ok(gid != "", "the actor joins the relay", gid)
	if gid == "":
		return _finish()
	var d := {"mid": "of%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": gid, "team": 1, "name": "Actor", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("of", {"c": "start", "d": d})
	await _build(d)
	var A: Hunter = m.ents_by_id.get("P" + gid, null)
	var t1 := Time.get_ticks_msec()
	while (A == null or A.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		A = m.ents_by_id.get("P" + gid, null)
	ok(A != null and A.remote, "the actor's hunter is here, driven by the actor's game")
	if A == null:
		return _finish()
	for arch in HEROES:
		for what in CASES:
			for rep in REPS:
				await _measure(A, arch, what)
	_table()
	_finish()

func _finish() -> void:
	Net.lobby_emit("of", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	for p in pids:
		if OS.is_process_running(p): OS.kill(p)
	print("OFEEL DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## One press on the actor, followed to its own first reaction, the relay, this game's wire, and this game's copy.
func _measure(A: Hunter, arch: String, what: String) -> void:
	replies.clear()
	sniff.clear()
	copy_trace.clear()
	Net.lobby_emit("of", {"c": "case", "a": arch, "w": what})
	var tw := 0.0
	while replies.is_empty() and tw < 15.0:
		await _run(0.1)
		tw += 0.1
	await _run(1.0)
	if replies.is_empty():
		return ok(false, "%s %s: the actor answered" % [arch, what])
	var r: Dictionary = replies[0]
	var t_press := float(r["t_press"])
	if not r["can"]:
		if rows.has(arch + " " + what): return
		_row(arch + " " + what)
		print("OFEEL table %-20s  n/a (this kit has nothing to recast right now)" % [arch + " " + what])
		return
	var local := _ms(float(r["t_local"]), t_press) if float(r["t_local"]) > 0.0 else -1.0
	var moved := _ms(float(r["t_move"]), t_press) if float(r["t_move"]) > 0.0 and what in ["dash", "recast"] else -1.0
	var t_from := t_press + (LAG_MS - 10.0) / 1000.0      # (nothing sent after the press arrives sooner than the delay)
	var relay := _first(sniff, t_from, t_press)
	var seen := -1.0
	var base := Vector2.INF
	for s in copy_trace:
		if float(s[0]) <= t_press: base = Vector2(s[1], s[2])
		elif what == "dash" and base != Vector2.INF and Vector2(s[1], s[2]).distance_to(base) > MOVED:
			seen = _ms(float(s[0]), t_press)
			break
	var row := _row(arch + " " + what)
	var got := {"local": local, "moved": moved, "relay": relay, "seen": seen}
	for stage in got: row[stage].append(got[stage])
	ok(relay < 0.0 or relay >= LAG_MS - 10.0, "%s %s: the delay is on (relay at %.0f ms)" % [arch, what, relay])
	if what == "dash":
		_smooth(arch, r, t_press)

## The remote Hunter in a dash, as this game draws it, worst case over the presses: its biggest step in one
## frame (a snap if it beats the actor's own step), how far it trails the real path, how far it runs past its end.
func _smooth(arch: String, r: Dictionary, t_press: float) -> void:
	var truth: Array = r["trace"]
	var end_x := float(truth[truth.size() - 1][1])
	var own_step := 0.0
	for i in range(1, truth.size()):
		own_step = maxf(own_step, Vector2(truth[i][1] - truth[i - 1][1], truth[i][2] - truth[i - 1][2]).length())
	var top := 0.0
	var trail := 0.0
	var over := 0.0
	var prev := Vector2.INF
	for s in copy_trace:
		var t := float(s[0])
		if t < t_press or t > t_press + 1.0: continue
		var p := Vector2(s[1], s[2])
		if prev != Vector2.INF: top = maxf(top, p.distance_to(prev))
		prev = p
		var want := _true_at(truth, t)
		if want != Vector2.INF: trail = maxf(trail, p.distance_to(want))
		over = maxf(over, p.x - end_x)
	var w: Dictionary = smooth.get(arch, {"step": 0.0, "own": 0.0, "trail": 0.0, "over": 0.0})
	smooth[arch] = {"step": maxf(w["step"], top), "own": maxf(w["own"], own_step),
		"trail": maxf(w["trail"], trail), "over": maxf(w["over"], over)}
	ok(top < 4.0, "%s dash: the remote copy never teleports (max step %.2f m)" % [arch, top])

## ms from the press, median (min-max) over the presses; -1 means that stage never showed.
func _table() -> void:
	for key in rows:
		var line := ""
		for stage in STAGES:
			var v: Array = rows[key][stage].filter(func(x): return x >= 0.0)
			v.sort()
			var span := "-" if v.is_empty() else "%.0f (%.0f-%.0f)" % [_median(v), v[0], v[-1]]
			line += "  %s %s" % [stage, span]
		print("OFEEL table %-20s%s" % [key, line])
		var lag := _median(rows[key]["relay"]) - _median(rows[key]["local"])
		if _median(rows[key]["relay"]) >= 0.0:
			ok(lag <= LAG_MS + NET_SLACK_MS, "%s: the game adds %.0f ms to the line's %.0f (budget %.0f)" % [
				key, lag - LAG_MS, LAG_MS, NET_SLACK_MS])
	for arch in smooth:
		var w: Dictionary = smooth[arch]
		print("OFEEL smooth %-10s remote dash (worst of %d): step %.2f m (own %.2f), trails %.2f m, over %.2f m" % [
			arch, REPS, w["step"], w["own"], w["trail"], w["over"]])

func _row(key: String) -> Dictionary:
	if not rows.has(key):
		rows[key] = {}
		for stage in STAGES: rows[key][stage] = []
	return rows[key]

static func _median(v: Array) -> float:
	var w: Array = v.filter(func(x): return x >= 0.0)
	w.sort()
	return -1.0 if w.is_empty() else float(w[w.size() / 2])

static func _ms(t: float, t0: float) -> float:
	return (t - t0) * 1000.0

func _first(log: Array, t_from: float, t_press: float) -> float:
	for e in log:
		if float(e[0]) >= t_from: return _ms(float(e[0]), t_press)
	return -1.0

static func _true_at(trace: Array, t: float) -> Vector2:
	for i in range(1, trace.size()):
		if float(trace[i][0]) >= t:
			return Vector2(trace[i][1], trace[i][2])
	return Vector2.INF

## Notes each change in the actor's own hunter, or event, in the packets the relay gets from it.
func _sniff(from: String, bytes: PackedByteArray) -> void:
	if from != gid: return
	var d = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or String(d.get("t", "")) == "" or typeof(d.get("d")) != TYPE_ARRAY:
		return
	if d["t"] == "ev":
		for e in d["d"]:
			if typeof(e) == TYPE_ARRAY and e.size() > 0:
				sniff.append([now(), "ev:" + String(e[0])])
		return
	if d["t"] != "st":
		return
	for it in d["d"]:
		if typeof(it) != TYPE_ARRAY or it.size() < 34 or String(it[0]) != "h" or String(it[1]) != "P" + gid:
			continue
		var sig: Array = SIG_AT.map(func(i): return it[i])
		sig.append(float(it[AGE_AT]))
		var old: Array = last_sig
		if not old.is_empty() and old.slice(0, -1) != sig.slice(0, -1):
			var field := 0
			while sig[field] == old[field]: field += 1
			sniff.append([now(), "st:field %d" % SIG_AT[field]])
		elif not old.is_empty() and sig[-1] < old[-1] - 0.01:
			sniff.append([now(), "st:same move again"])
		last_sig = sig

# ------------------------------------------------------------------ the actor
func _guest() -> void:
	print("OFEEL actor pid=%d" % OS.get_process_id())
	if not await _connect(port):
		print("OFEEL actor: no relay")
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while m == null and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	while m != null and not stop and Time.get_ticks_msec() - t0 < 900000:
		if req.is_empty():
			await _run(DT)
		else:
			var c := req
			req = {}
			await _play(String(c["a"]), String(c["w"]))
	main.get_tree().quit(0)

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "of_r":
		replies.append(data)
	elif topic == "of":
		match String(data.get("c", "")):
			"start": _build(data["d"])
			"case": req = data
			"done": stop = true

## Presses `what` as `arch` and reports when the actor's own game first reacted.
func _play(arch: String, what: String) -> void:
	var P := m.player
	if P.arch != arch:
		P.reclass(Arch.weight(arch), arch)
		P.unlock_all()
		P.lvl = 6
	P.teleport(home + PARK)
	P.vel = Vector3.ZERO
	P.face = PI * 0.5
	P.dashes = P.max_dashes()
	for k in P.ak.cd: P.ak.cd[k] = 0.0
	P.fire_cd = 0.0
	P.inp["aim"] = home + Vector3(0, 0.9, 0)       # at the host's hunter: Kael's chain has something to hook
	P.inp["aim_y"] = P.pos.y
	await _run(2.0)
	var can := true
	if what == "recast":
		P.inp["sig"] = true
		await _run(DT)
		P.inp["sig"] = false
		await _run(0.8)
		can = P.ak.e_recastable()
	var base := _probe(P)
	var cd0: float = P.ak.cd["e"] + P.ak.cd["rmb"]
	var trace: Array = []
	var t_press := now()
	match what:
		"dash":
			P.inp["move"] = Vector2(1, 0)
			P.inp["dash"] = true
		"lmb": P.inp["fire"] = true
		_: P.inp["sig"] = true
	var t_local := -1.0
	var t_move := -1.0
	var from := P.pos
	for i in 90:
		m.step(DT)
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		trace.append([now(), P.pos.x, P.pos.z])
		if t_move < 0.0 and P.pos.distance_to(from) > MOVED: t_move = now()
		if t_local < 0.0 and (_probe(P) != base or P.ak.cd["e"] + P.ak.cd["rmb"] > cd0 + 0.001): t_local = now()
		if i == 0:
			P.inp["dash"] = false
			P.inp["move"] = Vector2.ZERO
			P.inp["sig"] = false
		if i == 8: P.inp["fire"] = false
		await main.get_tree().process_frame
	Net.lobby_emit("of_r", {"can": can, "t_press": t_press, "t_local": t_local, "t_move": t_move, "trace": trace})

## What a player would see change at once: where it is, its kit animation, a shot going off.
func _probe(P: Hunter) -> Array:
	return [snappedf(P.pos.x, MOVED), snappedf(P.pos.z, MOVED), P.ak.anim_at, P.fire_cd > 0.0]

# ------------------------------------------------------------------ both
func _connect(on_port: int) -> bool:
	Net.server_addr = "127.0.0.1:%d" % on_port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "of"})
	return Net.mode == "server"

## The same flat match on both games (as --displace-net-check): one hunter each, no Boki, no monsters.
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
	for dz in range(-12, 13):
		for dx in range(-8, 30):
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
	P.max_hp = 10000.0
	P.hp = P.max_hp
	P.teleport(home if Net.is_host() else home + PARK)
	m = nm

## Runs the match `secs` in real time (one step a frame at 60 fps), with no monsters about; the host also
## records where its copy of the actor is, every step.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		var A: Ent = m.ents_by_id.get("P" + gid, null) if gid != "" else null
		if A: copy_trace.append([now(), A.pos.x, A.pos.z])
		await main.get_tree().process_frame
