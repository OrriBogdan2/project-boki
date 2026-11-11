extends RefCounted
## --lagcomp-check: do shots that hit on the shooter's screen still land over a slow line? Two real games
## over the desktop relay, like --remote-smooth-check: this process runs the relay (sim-free, as the
## dedicated --relay server) and the shooter's game; the target (--lagcomp-check=guest) is a second
## headless game. The relay adds SHOOTER_RTT_MS of round trip to the shooter and TARGET_RTT_MS to the
## target, half each way. The target strafes (left and right at random 0.3-0.7 s turns) 12 m from the
## shooter, who tracks its drawn body and fires Vex's rifle (LMB), Lace's Heavy Shot and Sparkle's Storm Rod.
## Online hits are the shooter's: its game flies the shot against its view of the target and sends the hit
## to the target's owner, which applies it (Match.net_send_hit, Match._net_hit_in). So the check counts
##   shooter    hits on the shooter's screen
##   applied    hits the target's own game applied (must equal shooter: nothing is lost on the way)
##   copy       hits the target's copy of each shot would make on the target's true path, spawned when it
##              arrives (what a server resolving shots at the current tick, no catch-up, would score)
##   copy+ff    the same, fast-forwarded by the shot's measured age, capped at FF_CAP_S (the standard
##              projectile catch-up), for comparison only: nothing in the game resolves hits this way
## Lines: LAGCOMP ok|FAIL <what>, LAGCOMP row <case> <numbers>; the guest prints LAGCOMP guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0        # s for the guest to come up and build its match
const SHOOTER_RTT_MS := 100   # ms the relay adds to the shooter's round trip
const TARGET_RTT_MS := 150    # ms the relay adds to the target's round trip
const FF_CAP_S := 0.15        # s: the most a copy is fast-forwarded in the copy+ff column
const RANGE := 12.0           # m between the shooter and the strafe lane
const STRAFE_X := 5.0         # m: the target turns back at this far either side of the lane's middle
const HOLD_S := {"archer": 1.25, "mage": 1.1}   # s of RMB hold: past the full draw (1.1) / the rod (1.0)
const VOLLEYS := 12           # Heavy Shots and Storm Rods per case
const RIFLE_S := 6.0          # s of LMB held for Vex's case
const DN := preload("res://tools/displace_net_check.gd")
const CASES := [["Vex LMB", "gunslinger"], ["Lace Heavy Shot", "archer"], ["Sparkle RMB", "mage"]]

## The relay on a slow line: each peer's packets wait half its added round trip in, and half out.
class LagRelay extends RelayServer:
	var rtt := {}                 # peer id -> added round trip (ms), the first peer is the shooter
	var held: Array = []          # [due msec, peer id, bytes or message, inbound, fast]
	var due_last := {}            # [peer id, inbound, fast] -> due of its last held packet (order kept)

	func _half(id: int) -> int:
		if not rtt.has(id):
			rtt[id] = SHOOTER_RTT_MS if rtt.is_empty() else TARGET_RTT_MS
		return int(rtt[id]) / 2

	func _hold(id: int, x, inbound: bool, fast: bool) -> void:
		var key := [id, inbound, fast]
		var due := maxi(Time.get_ticks_msec() + _half(id), int(due_last.get(key, 0)))
		due_last[key] = due
		held.append([due, id, x, inbound, fast])

	func _on_packet(id: int, bytes: PackedByteArray) -> void:
		_hold(id, bytes, true, false)

	func _send(id: int, d: Dictionary, fast := false) -> void:
		_hold(id, d, false, fast)

	func _process(dt: float) -> void:
		super._process(dt)
		var now := Time.get_ticks_msec()
		var keep: Array = []
		for x in held:
			if int(x[0]) > now:
				keep.append(x)
			elif x[3]:
				super._on_packet(x[1], x[2])
			elif clients.has(x[1]):
				super._send(x[1], x[2], x[4])
		held = keep

var main: Node
var bad := 0
var dn                         # the --displace-net-check helper that builds the shared match
var m: Match = null
var stop := false
var guest_pid := 0
var dir := ""
var rng := RandomNumberGenerator.new()
var shots: Array = []          # host: [wall s, sid] of each shot the shooter fires
var hits: Array = []           # host: wall s of each hit on the shooter's screen; guest: of each applied hit
var path: Array = []           # guest: [wall s, x, z] of its own body each frame
var copies: Array = []         # guest: [wall s, x, z, vx, vz, life, r] of each copy of the shooter's shots
var seen_sid := {}
var dumped := false
var turn_t := 0.0              # guest: s until the strafe turns

func ok(cond: bool, what: String, info := "") -> void:
	print("LAGCOMP %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	dn = DN.new()
	dn.main = main
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--lagcomp-check=guest": guest = true
		if a.begins_with("--lc-port="): dn.port = int(a.substr(10))
	dir = ProjectSettings.globalize_path("user://lagcomp")
	DirAccess.make_dir_recursive_absolute(dir)
	Net.message.connect(_on_msg)
	CombatBus.hit_landed.connect(_on_hit)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the shooter (and the relay)
func _host() -> void:
	dn.port = 7870 + OS.get_process_id() % 40
	var relay := LagRelay.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % dn.port])) == OK, "the lag relay listens on %d" % dn.port)
	ok(await dn._connect(), "the shooter is on the relay")
	var cmd := "cd '%s' && %s --headless -- --lagcomp-check=guest --lc-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, dn.port, dir.path_join("guest.log")]
	OS.create_process("/bin/sh", ["-c", cmd])
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
	ok(other != "", "the target joins the relay")
	if other == "":
		return _finish()
	var d := {"mid": "lc%d" % dn.port, "seed": DN.SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Shooter", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Target", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("lc", {"c": "start", "d": d})
	await dn._build(d)
	m = dn.m
	var G: Hunter = null
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _host_run(0.2, null)
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null, "the target's game is sending")
	if G == null:
		return _finish()
	await _host_run(2.0, null)
	print("LAGCOMP line: shooter +%d ms round trip, target +%d ms; ff cap %d ms" % [
		SHOOTER_RTT_MS, TARGET_RTT_MS, int(FF_CAP_S * 1000.0)])
	print("LAGCOMP row case             shots  shooter  applied  lost  copy  copy+ff  mean age ms")
	for c in CASES:
		await _case(G, String(c[0]), String(c[1]))
	_finish()

## One weapon: the target strafes, the shooter fires, then both records are compared.
func _case(G: Hunter, what: String, arch: String) -> void:
	dn._kit(arch)
	var P := m.player
	P.teleport(dn.home + Vector3(0, 0, RANGE * 0.5))
	shots.clear()
	hits.clear()
	seen_sid.clear()
	dumped = false
	Net.lobby_emit("lc", {"c": "strafe", "at": _lane()})
	await _host_run(1.5, G)
	if arch == "gunslinger":
		P.inp["fire"] = true
		await _host_run(RIFLE_S, G)
		P.inp["fire"] = false
	else:
		for i in VOLLEYS:
			for k in P.ak.cd: P.ak.cd[k] = 0.0
			P.inp["sec_hold"] = true
			P.ak.press_rmb()
			await _host_run(float(HOLD_S[arch]), G)
			P.inp["sec_hold"] = false
			await _host_run(0.9, G)
	await _host_run(1.0, G)
	Net.lobby_emit("lc", {"c": "dump"})
	var t0 := Time.get_ticks_msec()
	while not dumped and Time.get_ticks_msec() - t0 < 20000:
		await _host_run(0.1, G)
	ok(dumped, "%s: the target wrote its record" % what)
	if dumped:
		_report(what, JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("target.json"))))

func _lane() -> Array:
	var c: Vector3 = dn.home + Vector3(0, 0, -RANGE * 0.5)
	return [c.x, c.y, c.z]

func _host_run(secs: float, G: Hunter) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		if G:
			m.player.inp["aim"] = G.pos + Vector3(0, 0.9, 0)
			m.player.inp["aim_y"] = G.pos.y
		m.step(DT)
		t += DT
		for s in m.shots:
			if s["by"] == m.player and not seen_sid.has(s["sid"]) and not s["x"].get("cos", false):
				seen_sid[s["sid"]] = true
				shots.append([Time.get_unix_time_from_system(), s["sid"]])
		await main.get_tree().process_frame

func _on_hit(by: Node, target: Node, _amount: float, _tags: Array) -> void:
	if m == null or not (target is Hunter):
		return
	var mine := target == m.player
	var shooter_saw := Net.is_host() and by == m.player and not mine
	var target_took := not Net.is_host() and mine and by is Hunter and by != m.player
	if shooter_saw or target_took:
		hits.append(Time.get_unix_time_from_system())

## A table row. A volley weapon (one shot a press) counts a shot as hit once, whatever it set off after.
func _report(what: String, rec) -> void:
	if typeof(rec) != TYPE_DICTIONARY:
		ok(false, "%s: a record to compare" % what)
		return
	var applied: Array = rec["hits"]
	var cps: Array = rec["copies"]
	var volley := what != "Vex LMB"
	var n_shooter := _per_shot(hits, volley)
	var n_applied := _per_shot(applied, volley)
	var n_copy := 0
	var n_ff := 0
	var age_sum := 0.0
	var n := mini(shots.size(), cps.size())
	for i in n:
		var cp: Array = cps[i]
		var age := float(cp[0]) - float(shots[i][0])
		age_sum += age
		if _copy_hits(cp, rec["path"], float(rec["r"]), 0.0): n_copy += 1
		if _copy_hits(cp, rec["path"], float(rec["r"]), clampf(age, 0.0, FF_CAP_S)): n_ff += 1
	print("LAGCOMP row %-16s %5d  %7d  %7d  %4d  %4d  %7d  %11.0f" % [
		what, shots.size(), n_shooter, n_applied, n_shooter - n_applied, n_copy, n_ff, 1000.0 * age_sum / maxf(1.0, n)])
	ok(shots.size() > 0 and cps.size() == shots.size(), "%s: every shot reaches the target's game" % what,
		"%d fired, %d copies" % [shots.size(), cps.size()])
	ok(n_shooter > 0, "%s: some shots hit on the shooter's screen" % what, "%d" % n_shooter)
	ok(n_applied == n_shooter, "%s: every hit on the shooter's screen lands on the target's game" % what,
		"%d of %d" % [n_applied, n_shooter])

## Hits grouped by shot: in a volley case each shot's window holds at most one hit.
func _per_shot(ws: Array, volley: bool) -> int:
	if not volley:
		return ws.size()
	var n := 0
	for i in shots.size():
		var w0: float = shots[i][0]
		var w1: float = shots[i + 1][0] if i + 1 < shots.size() else INF
		for w in ws:
			if float(w) >= w0 and float(w) < w1:
				n += 1
				break
	return n

## Whether a copy, flown from where and when it arrived (ff s ahead), passes over the target's true body.
static func _copy_hits(cp: Array, pth: Array, body_r: float, ff: float) -> bool:
	var w0 := float(cp[0])
	var reach := body_r + float(cp[6]) + Match.HIT_SLACK
	for q in pth:
		var t := float(q[0]) - w0 + ff
		if t < ff or t > float(cp[5]):
			continue
		var at := Vector2(float(cp[1]) + float(cp[3]) * t, float(cp[2]) + float(cp[4]) * t)
		if at.distance_to(Vector2(float(q[1]), float(q[2]))) < reach:
			return true
	return false

func _finish() -> void:
	Net.lobby_emit("lc", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	var p := dir.path_join("guest.log")
	if FileAccess.file_exists(p):
		for line in FileAccess.get_file_as_string(p).split("\n"):
			if line.begins_with("LAGCOMP guest pid="): guest_pid = int(line.get_slice("=", 1))
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("LAGCOMP DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the target
func _guest() -> void:
	print("LAGCOMP guest pid=%d" % OS.get_process_id())
	rng.seed = 1110
	if not await dn._connect():
		print("LAGCOMP guest: no relay")
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while m == null and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	while m != null and not stop and Time.get_ticks_msec() - t0 < 900000:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		_strafe()
		m.step(DT)
		_record()
		await main.get_tree().process_frame
	main.get_tree().quit(0)

## Left and right along the lane, turning at random, and back at its ends; never dies.
func _strafe() -> void:
	var P := m.player
	P.hp = P.max_hp
	var mv: Vector2 = P.inp["move"]
	if mv == Vector2.ZERO:
		return
	turn_t -= DT
	var off := P.pos.x - float(_lane()[0])
	if turn_t <= 0.0 or (off > STRAFE_X and mv.x > 0.0) or (off < -STRAFE_X and mv.x < 0.0):
		P.inp["move"] = Vector2(-signf(mv.x), 0)
		turn_t = rng.randf_range(0.3, 0.7)

func _record() -> void:
	var w := Time.get_unix_time_from_system()
	path.append([w, m.player.pos.x, m.player.pos.z])
	for s in m.shots:
		if s["x"].get("cos", false) and s["team"] != m.player.team and not seen_sid.has(s["sid"]):
			seen_sid[s["sid"]] = true
			var v: Vector2 = s["vel"]
			copies.append([w, s["pos"].x, s["pos"].z, v.x, v.y, s["life"], s["r"]])

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "lc_r":
		dumped = true
		return
	if topic != "lc":
		return
	match String(data.get("c", "")):
		"start":
			await dn._build(data["d"])
			m = dn.m
		"strafe":
			if m:
				dn._fresh(m.player)
				m.player.teleport(DN._v(data["at"]))
				m.player.inp["move"] = Vector2(1, 0)
				path.clear()
				copies.clear()
				hits.clear()
		"dump":
			var f := FileAccess.open(dir.path_join("target.json"), FileAccess.WRITE)
			f.store_string(JSON.stringify({"path": path, "copies": copies, "hits": hits, "r": m.player.r}))
			f.close()
			Net.lobby_emit("lc_r", {"n": copies.size()})
		"done": stop = true
