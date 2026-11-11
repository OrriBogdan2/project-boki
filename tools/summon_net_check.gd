extends RefCounted
## --summon-net-check: the Boki summon (KinSummon, decision 0039) seen from ANOTHER game. Two real games over the
## desktop relay, as --displace-net-check does: this process is client A and the relay (it starts a second headless
## game, B, through the shell). A's Boki (Cindle, a wisp) bursts out, uses its active (k1) and its auto skill (k2),
## B knocks it down (a kill: it turns back into a wisp), and a second summon runs out its window into the shrink.
## Both games log the same moments with the wall clock (the burst, each cast, the death, the shrink, the wisp
## back); B must see each within SEEN_S of A, and its copy of the summon timer must read A's.
## Lines: SUMMONNET ok|FAIL <what>; B prints SUMMONNET guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for B to come up and build its match (the queue may hold it)
const SEEN_S := 0.15         # s: B shows a moment within this of A
const SEED := 4242
const SPECIES := "cindle"    # small bruiser: active stinger_hook, auto flare_dash, window 8 s

var main: Node
var bad := 0
var n := 0
var port := 0
var dir := ""
var guest_pid := 0
var m: Match = null
var home := Vector3.ZERO
var replies: Array = []
var stop := false
var marks: Array = []        # this game's log of A's Boki: [name, wall-clock s]
var last := {}               # the previous frame's look at A's Boki
var samples: Array = []      # [wall-clock s, window left] of A's Boki, each frame

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("SUMMONNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	Net.message.connect(_on_msg)
	CombatBus.ability_used.connect(_on_cast)
	if "--summon-net-check=guest" in OS.get_cmdline_user_args():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--sn-port="): port = int(a.substr(10))
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ client A
func _host() -> void:
	port = 7990 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://summon_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "A is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --summon-net-check=guest --sn-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, port, dir.path_join("guest.log")]
	OS.create_process("/bin/sh", ["-c", cmd])
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
		_read_pid()
	ok(other != "", "B joins the relay", other)
	if other == "":
		return _finish()
	var d := {"mid": "sn%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "A", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "B", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("sn", {"c": "start", "d": d})
	await _build(d)
	var t1 := Time.get_ticks_msec()
	var hb: Hunter = null
	while (hb == null or hb.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		hb = m.ents_by_id.get("P" + other, null)
	ok(hb != null and hb.remote, "B's hunter is here, driven by B's game")
	if hb == null:
		return _finish()
	await _run(1.0)
	var a: Hunter = m.player
	var k: Kin = a.kin
	ok(k != null and k.wisp and k.summon != null, "A's Boki rides as a wisp")
	var theirs := await _ask()
	ok(bool(theirs.get("seen", false)) and bool(theirs.get("wisp", false)), "B sees it as a wisp too")
	# the first summon: burst, the active, the auto skill, then B knocks it down
	marks.clear()
	ok(KinSummon.press(a), "A summons")
	await _run(0.6)
	k.use_ability("k1", hb.pos)
	await _run(0.8)
	k.use_ability("k2", hb.pos)
	await _run(0.8)
	await _compare_timer("first summon")
	Net.lobby_emit("sn", {"c": "kill"})
	await _run(1.2)
	ok(k.wisp and k.summon.cd > 0.0, "the kill turned it back into a wisp, resting", "cd %.0f s" % k.summon.cd)
	var first := marks.duplicate()
	var first_b := await _marks_b()
	_same_moments("first summon", first, first_b, ["burst", "cast:k1", "cast:k2", "death"])
	# the second summon runs out its window
	k.summon.cd = 0.0
	marks.clear()
	ok(KinSummon.press(a), "A summons again")
	await _run(2.0)
	await _compare_timer("second summon")
	await _run(k.summon.left + 1.2)
	ok(k.wisp and k.summon.cd > 0.0, "the window ended: a wisp again, resting")
	_same_moments("second summon", marks.duplicate(), await _marks_b(), ["burst", "shrink", "wisp_back"])
	_finish()

func _finish() -> void:
	Net.lobby_emit("sn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("SUMMONNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _read_pid() -> void:
	var p := dir.path_join("guest.log")
	if guest_pid > 0 or not FileAccess.file_exists(p):
		return
	for line in FileAccess.get_file_as_string(p).split("\n"):
		if line.begins_with("SUMMONNET guest pid="):
			guest_pid = int(line.get_slice("=", 1))

## B asks for its look at A's Boki now; A reads its own timer at the same wall-clock instant.
func _compare_timer(what: String) -> void:
	for i in 2:
		var b := await _ask()
		var at := float(b.get("t", 0.0))
		var mine := _left_at(at)
		var diff := absf(float(b.get("left", -1.0)) - mine)
		ok(mine > 0.0 and diff <= SEEN_S, "%s: B's timer reads A's (%d)" % [what, i + 1],
			"A %.2f s, B %.2f s" % [mine, float(b.get("left", -1.0))])
		await _run(0.4)

func _left_at(t: float) -> float:
	var best := 1e9
	var left := -1.0
	for s in samples:
		if absf(float(s[0]) - t) < best:
			best = absf(float(s[0]) - t)
			left = float(s[1])
	return left

## Each moment A logged was logged by B within SEEN_S, and B logged no other.
func _same_moments(what: String, a: Array, b: Array, names: Array) -> void:
	for nm in names:
		var ta := _first(a, nm)
		var tb := _first(b, nm)
		var lag := "never" if tb < 0.0 else "%+d ms" % int((tb - ta) * 1000.0)
		var close := ta > 0.0 and tb > 0.0 and absf(tb - ta) <= SEEN_S
		ok(close, "%s: B sees the %s within %d ms of A" % [what, nm, int(SEEN_S * 1000.0)], "B %s" % lag)
	var count_a := a.filter(func(x): return String(x[0]).begins_with("cast:")).size()
	var count_b := b.filter(func(x): return String(x[0]).begins_with("cast:")).size()
	ok(count_a == count_b, "%s: B sees every cast, no more (%d)" % [what, count_a], "B %d" % count_b)

static func _first(log: Array, nm: String) -> float:
	for x in log:
		if String(x[0]) == nm:
			return float(x[1])
	return -1.0

func _marks_b() -> Array:
	replies.clear()
	Net.lobby_emit("sn", {"c": "marks"})
	var r := await _reply()
	return r.get("marks", [])

func _ask() -> Dictionary:
	replies.clear()
	Net.lobby_emit("sn", {"c": "ask"})
	return await _reply()

func _reply() -> Dictionary:
	var t := 0.0
	while replies.is_empty() and t < 10.0:
		await _run(0.05)
		t += 0.05
	return replies[0] if not replies.is_empty() else {}

# ------------------------------------------------------------------ client B
func _guest() -> void:
	print("SUMMONNET guest pid=%d" % OS.get_process_id())
	if not await _connect():
		print("SUMMONNET guest: no relay")
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
	if topic == "sn_r":
		replies.append(data)
		return
	if topic != "sn":
		return
	match String(data.get("c", "")):
		"start": _build(data["d"])
		"done": stop = true
		"ask":
			var k := _watched()
			var left: float = k.summon.left if k and k.summon else -1.0
			var now := Time.get_unix_time_from_system()
			var asked := {"t": now, "seen": k != null, "wisp": k != null and k.wisp, "left": left}
			Net.lobby_emit("sn_r", asked)
		"marks":
			Net.lobby_emit("sn_r", {"marks": marks})
			marks = []
		"kill":
			var k := _watched()
			if k and m.player:
				k.hurt(100000.0, m.player, {"src": "abil"})     # B's hit on A's Boki: A's game applies it

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "sn"})
	return Net.mode == "server"

## The same match on both games: the training island, one hunter each with a Cindle wisp, no monsters.
func _build(d: Dictionary) -> void:
	var rec := Save.new_kin(SPECIES)
	Save.d["roster"] = [rec]
	Save.d["active"] = rec["uid"]
	Models.kin(SPECIES, rec).free()      # warm the model: a cold first bloom stalls a frame ~0.2 s (not a sync matter)
	var nm := Match.new()
	main.add_child(nm)
	await nm.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": SEED, "no_drop": true,
		"cls": "medium", "net": d, "boki_wisps": true})
	nm.set_process(false)
	var P := nm.player
	P.max_hp = 10000.0
	P.hp = P.max_hp
	home = P.pos
	m = nm

## A's Boki on this game (A's own, or B's copy of it).
func _watched() -> Kin:
	if m == null:
		return null
	for k in m.kins:
		if k.owner_h != null and k.owner_h.team == 0 and not k.dead:
			return k
	return null

func _on_cast(caster: Node, ability: String, slot: String) -> void:
	var k := _watched()
	if k and (caster == k or caster == k.owner_h) and slot in ["k1", "k2"]:
		marks.append(["cast:" + slot, Time.get_unix_time_from_system(), ability])

## One frame of A's Boki's story: log the moment each thing first shows on this game.
func _watch() -> void:
	var k := _watched()
	if k == null or k.summon == null:
		return
	var now := Time.get_unix_time_from_system()
	var s := k.summon
	var cur := {"wisp": k.wisp, "shrink": s.shrink > 0.0, "left": s.left}
	if not last.is_empty():
		if last["wisp"] and not cur["wisp"]:
			marks.append(["burst", now])
		if not last["shrink"] and cur["shrink"]:
			marks.append(["shrink", now])
		if not last["wisp"] and cur["wisp"]:
			marks.append(["death" if float(last["left"]) > 0.0 and not last["shrink"] else "wisp_back", now])
	last = cur
	samples.append([now, s.left])
	if samples.size() > 600:
		samples.pop_front()

## Runs the match `secs` in real time (one step a frame at 60 fps), with no monsters about.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		if m:
			for mb in m.mobs: mb.queue_free()
			m.mobs.clear()
			m.step(DT)
			_watch()
		t += DT
		await main.get_tree().process_frame
