extends RefCounted
## --cast-predict-check: online, your own ability starts the frame you press it, as it does offline. A listen
## server and a client over the desktop relay with test weather (100 ms round trip, 2% loss, RelayServer):
## this process is the host (relay in-process too) and starts a second headless game, the client
## (--cast-predict-check=guest). The client presses every slot of the four slice Wardens through the real input
## path (Input actions, Match._process) on an offline match first, then on the online one, and records the
## first tick the Hunter's animation state (what HunterAnim is told) and the first tick a VFX (a HeroVfx move,
## a burst or ring) changes. Tick 0 is the step run in the frame of the press. Target: online is never later
## than offline (the network adds under one frame). The match harness is --displace-net-check's.
## Lines: CASTPRED <hero> <slot> ...; CASTPRED rtt ...; CASTPRED DONE, failures: N.

const DT := 1.0 / 60.0
const LAG_MS := 50            # ms the relay holds each packet: a 100 ms round trip between the two games
const LOSS := 0.02            # share of packets lost
const RTT_MIN := 90.0         # ms: the measured round trip shows the weather is on
const PINGS := 10             # round trips timed
const START_S := 240.0        # s for the client to come up, run its baseline and build its match
const HOLD := 20              # ticks a press is held (so tap/hold kits see a hold too)
const WATCH := 45             # ticks watched after the press (0.75 s)
const SETTLE := 60            # ticks between presses, so the last move's looks are over
const WARDENS := ["gunslinger", "juggernaut", "archer", "ashwick"]     # Vex, Kael, Lace, Cinder
const NEAR := 6.0             # m: a look this close to the pressing Hunter is theirs (the other one stands 9 m off)
const FRESH := 0.05           # s: a HeroVfx look this young started this tick
const SLOTS := {"lmb": "fire", "rmb": "secondary", "e": "signature", "r": "ultimate", "dash": "dash"}

var main: Node
var dn                        # tools/displace_net_check.gd: the relay match harness
var relay: RelayServer
var bad := 0
var guest_pid := 0
var start_d := {}
var pongs := {}               # ping n -> msec it came back
var result := {}              # the client's report

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	Settings.set_v("cast_on_press", true, false)    # the default: an ability goes off on the press
	dn = load("res://tools/displace_net_check.gd").new()
	dn.main = main
	Net.message.connect(_on_msg)
	if "--cast-predict-check=guest" in OS.get_cmdline_user_args():
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host (listen server)
func _host() -> void:
	dn.port = 7870 + OS.get_process_id() % 60
	relay = RelayServer.new()
	main.add_child(relay)
	var args := ["--port=%d" % dn.port, "--lag-ms=%d" % LAG_MS, "--loss=%s" % LOSS]
	if relay.start(PackedStringArray(args)) != OK or not await dn._connect():
		return _finish("the relay or the host's connection didn't come up")
	var dir := ProjectSettings.globalize_path("user://cast_predict")
	DirAccess.make_dir_recursive_absolute(dir)
	var log_path := dir.path_join("guest.log")
	var cmd := "cd '%s' && %s --headless -- --cast-predict-check=guest --dn-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), dn.GODOT, dn.port, log_path]
	guest_pid = OS.create_process("/bin/sh", ["-c", cmd])
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
	if other == "":
		return _finish("the client never joined the relay (log: %s)" % log_path)
	var d := {"mid": "cp%d" % dn.port, "seed": dn.SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Client", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("cp", {"c": "start", "d": d})
	await dn._build(d)
	var t1 := Time.get_ticks_msec()
	while result.is_empty() and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await dn._run(DT)        # the listen server keeps running its match while the client plays
	if result.is_empty():
		return _finish("the client never reported (log: %s)" % log_path)
	for row in result["rows"]:
		print(row)
	bad += int(result["bad"])
	var rtt := float(result["rtt"])
	if rtt < RTT_MIN:
		bad += 1
	print("CASTPRED rtt %.0f ms (client, %d pings), relay lost %d packets, weather %s" % [
		rtt, PINGS, relay.lost, "ok" if rtt >= RTT_MIN else "FAIL (no lag)"])
	_finish("")

func _finish(why: String) -> void:
	if why != "":
		print("CASTPRED FAIL " + why)
		bad += 1
	Net.lobby_emit("cp", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	print("CASTPRED DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ the client
func _guest() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dn-port="): dn.port = int(a.substr(10))
	var offline := {}
	await dn._build({})
	_still(dn.m)
	for hero in WARDENS:
		for slot in SLOTS:
			offline[hero + slot] = await _trial(hero, slot)
	dn.m.queue_free()
	if not await dn._connect():
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while start_d.is_empty() and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	await dn._build(start_d)
	var rtt := await _rtt()
	var rows: Array = []
	var fails := 0
	for hero in WARDENS:
		for slot in SLOTS:
			var off: Array = offline[hero + slot]
			var on: Array = await _trial(hero, slot)
			var ok_ := _not_later(on[0], off[0]) and _not_later(on[1], off[1])
			fails += 0 if ok_ else 1
			rows.append("CASTPRED %-10s %-4s anim off %2s on %2s  vfx off %2s on %2s  %s" % [
				hero, slot, _t(off[0]), _t(on[0]), _t(off[1]), _t(on[1]), "ok" if ok_ else "FAIL"])
	Net.lobby_emit("cp_r", {"c": "result", "rows": rows, "bad": fails, "rtt": rtt})
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 30000:
		await dn._run(DT)
	main.get_tree().quit(0)

## The offline match like the online one: the other Hunter stands idle and no Boki run about, so nothing
## else rolls the dice the press's looks roll.
static func _still(m: Match) -> void:
	for h in m.hunters:
		if h != m.player:
			h.ctrl = "idle"
	for k in m.kins:
		k.dead = true
		k.queue_free()
	m.kins.clear()

## Online a first frame comes no later than offline, and never goes missing.
static func _not_later(on: int, off: int) -> bool:
	return (off < 0 and on < 0) or (on >= 0 and (off < 0 or on <= off))

## Mean round trip, client -> host -> client, through the relay's weather (ms).
func _rtt() -> float:
	var sent := {}
	for n in PINGS:
		sent[n] = Time.get_ticks_msec()
		Net.lobby_emit("cp", {"c": "ping", "n": n})
		await dn._run(0.1)
	var t0 := Time.get_ticks_msec()
	while pongs.size() < PINGS and Time.get_ticks_msec() - t0 < 5000:
		await dn._run(DT)
	var sum := 0.0
	for n in pongs:
		sum += float(pongs[n]) - float(sent[n])
	return sum / maxf(1.0, pongs.size())

## One press of `slot` from standing still: [first animation tick, first VFX tick] (-1 = none).
func _trial(hero: String, slot: String) -> Array:
	var m: Match = dn.m
	dn._kit(hero)
	var P := m.player
	P.teleport(dn.home + dn.PARK)
	for i in SETTLE:
		await _frame(m)
	var anim0 := _anim_sig(m)
	var pools := [m.fx.bi, m.fx.si, m.fx.fi]
	var held := HeroVfx.of(m).holds.keys()
	var first := [-1, -1]
	seed(hash(hero + slot))     # the same dice offline and online (Kael's charge sparks are a coin flip a tick)
	Input.action_press(SLOTS[slot])
	for tick in WATCH:
		if tick == HOLD:
			Input.action_release(SLOTS[slot])
		_no_mobs(m)
		m._process(DT)              # in the press's own frame, so the press is "just pressed" here
		if first[0] < 0 and _anim_sig(m) != anim0: first[0] = tick
		if _new_vfx(m, pools, held) and first[1] < 0: first[1] = tick
		await main.get_tree().process_frame
	Input.action_release(SLOTS[slot])
	return first

## One frame of the match through its real _process, exactly one step (no hitstop or slow-mo stretch).
func _frame(m: Match) -> void:
	m.hitstop = 0.0
	m.slowmo = 0.0
	m.acc = DT * 0.5
	_no_mobs(m)
	m._process(DT)
	await main.get_tree().process_frame

## The training camp's monsters out of the way: their hits and deaths would read as this press's VFX.
static func _no_mobs(m: Match) -> void:
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()

## What HunterAnim is told this frame that a press can change (Hunter._anim_state).
func _anim_sig(m: Match) -> Array:
	var s: Dictionary = m.player.anim_s
	return [s.get("rolling"), s.get("grounded"), s.get("gliding"), s.get("swing_n"), s.get("kmove", ""),
			snappedf(m.time - float(s.get("kmove_t", 0.0)), 0.001), snappedf(m.time - float(s.get("cast", 0.0)), 0.001),
			snappedf(m.time - float(s.get("fired", 0.0)), 0.001), float(s.get("charge", 0.0)) > 0.0,
			float(s.get("flash", 0.0)) > 0.0, s.get("act")]

## A look started this tick at the pressing Hunter (within NEAR): a shared burst, spark or flash (muzzle
## flashes, impacts), or a HeroVfx layer, trail or new hold of theirs. `pools` is the Fx pool cursors seen last,
## `held` the holds running before the press (Lace's bow string idles all the time).
func _new_vfx(m: Match, pools: Array, held: Array) -> bool:
	var P := m.player
	var fx := m.fx
	var got := false
	var now := [fx.bi, fx.si, fx.fi]
	var nodes := [fx.bursts, fx.sparks, fx.flash_pool]
	for k in 3:
		var i: int = pools[k]
		while i != now[k]:
			got = got or (nodes[k][i] as Node3D).global_position.distance_to(P.pos) < NEAR
			i = (i + 1) % nodes[k].size()
		pools[k] = now[k]
	var hv := HeroVfx.of(m)
	for e: Dictionary in hv.live + hv.motes:
		got = got or (float(e["t"]) < FRESH and (e["node"] as Node3D).global_position.distance_to(P.pos) < NEAR)
	for e: Dictionary in hv.ribbons:
		got = got or (e["h"] == P and float(e["t"]) < FRESH)
	for key in hv.holds:
		got = got or (hv.holds[key]["h"] == P and key not in held)
	return got

static func _t(tick: int) -> String:
	return str(tick) if tick >= 0 else "-"

func _on_msg(topic: String, data, _from: String) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	if topic == "cp_r":
		match String(data.get("c", "")):
			"pong": pongs[int(data["n"])] = Time.get_ticks_msec()
			"result": result = data
		return
	if topic != "cp":
		return
	match String(data.get("c", "")):
		"start": start_d = data["d"]
		"ping": Net.lobby_emit("cp_r", {"c": "pong", "n": data["n"]})
		"done": main.get_tree().quit(0)
