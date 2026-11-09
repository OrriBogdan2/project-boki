extends RefCounted
## --displace-net-check: abilities that move someone else's body move a player on ANOTHER game instance,
## on that player's own game, to the same place they move a bot (scripts/combat/displace.gd). Two real
## games over the desktop relay: this process is the host (it runs the relay in-process too) and starts a
## second headless game, the guest (--displace-net-check=guest), through the queue wrapper. Both build the
## same flat training strip; the host plays each ability first on a local bot, then on the guest's hunter,
## and the guest reports where its own game put it. Cinder's cloak pull, Grimble's reel, Motley's Trade,
## Sparkle's Skycall drag, Mossy's shield push; Kael's Warchain pulls Kael to the player (not the player).
## Then the hit path: a hazard striking on both games hurts the player once; a knock's wall stun, a burn's
## length and a slow's strength reach the player's own game.
## Lines: DISPNET ok|FAIL <what>; the guest prints DISPNET guest pid=<pid>.

const GODOT := "/usr/local/bin/godot"
const DT := 1.0 / 60.0
const START_S := 240.0       # s for the guest to come up and build its match (the queue may hold it)
const TOL := 0.5             # m: the player's own game puts it within this of where the bot went
const VIEW_TOL := 0.4        # m: and the host's copy of it follows to within this
const SEED := 4242
const PARK := Vector3(0, 0, -9.0)   # m from home: where the guest waits while the bot takes its turn

var main: Node
var bad := 0
var n := 0
var port := 0
var dir := ""
var guest_pid := 0
var m: Match = null
var home := Vector3.ZERO
var replies: Array = []      # what the guest said back: {"c", "pos"}
var stop := false
var stun_max := 0.0          # the longest stun seen on the watched body since its last place (guest: its own)
var stun_on: Ent = null
var watch: Ent = null         # the first tow on this body, as the host's mirror of it (seen)
var seen := {}

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("DISPNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == "--displace-net-check=guest": guest = true
		if a.begins_with("--dn-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	port = 7930 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://displace_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- --displace-net-check=guest --dn-port=%d > '%s' 2>&1" % [
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
	var d := {"mid": "dn%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("dn", {"c": "start", "d": d})
	await _build(d)
	var G: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := Time.get_ticks_msec()
	while (G == null or G.net_t < 0.0) and Time.get_ticks_msec() - t1 < START_S * 1000.0:
		await _run(0.2)
		G = m.ents_by_id.get("P" + other, null)
	ok(G != null and G.remote, "the guest's hunter is here, driven by the guest's game")
	if G == null:
		return _finish()
	var B: Hunter = m.make_hunter("B", 1, "medium", "Bot", "idle", {}, home + Vector3(-6.0, 0, 9.0), {"arch": "none"})
	await _case(G, B, "ashwick", Vector3(3.8, 0, 0), _cinder, 1.0, "Cinder's cloak pull", "step")
	await _case(G, B, "dredge", Vector3(6.0, 0, 0), _dredge, 2.0, "Grimble's reel", "haul")
	var DK: DredgeKit = m.player.ak
	ok(DK.arrivals == 2 and DK.pull.is_empty(),
		"Grimble's reel: on the player too it ends as an arrival (HAULED), reel let go", "arrivals %d" % DK.arrivals)
	await _case(G, B, "ostra", Vector3(8.0, 0, 0), _ostra, 2.2, "Motley's Trade")
	await _case(G, B, "mage", Vector3(7.0, 0, 0), _vireo, 2.4, "Sparkle's Skycall drag", "slide")
	await _case(G, B, "bulwark", Vector3(1.7, 0, 0), _bjorn, 1.2, "Mossy's shield push", "push")
	await _zedran(G)
	await _hazard(G, B)
	await _knock_extras(G, B)
	_finish()

func _finish() -> void:
	Net.lobby_emit("dn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("DISPNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func _read_pid() -> void:
	if guest_pid > 0:
		return
	var p := dir.path_join("guest.log")
	if not FileAccess.file_exists(p):
		return
	for line in FileAccess.get_file_as_string(p).split("\n"):
		if line.begins_with("DISPNET guest pid="):
			guest_pid = int(line.get_slice("=", 1))

## One ability, on the bot and then on the guest from the same spot: the guest's own game puts it where
## the bot went, it really moved there, and the host's copy of it follows.
func _case(
	G: Hunter, B: Hunter, arch: String, off: Vector3, act: Callable, settle: float, what: String, mode := ""
) -> void:
	var P := m.player
	_kit(arch)
	_fresh(B)
	B.teleport(home + off)
	await _run(0.2)
	await act.call(B)
	await _run(settle)
	var bot_at := B.pos
	var bot_moved := Vector2(bot_at.x - home.x - off.x, bot_at.z - home.z - off.z).length()
	B.teleport(home + Vector3(-6.0, 0, 9.0))
	_kit(arch)
	var start := home + off
	var g0: Vector3 = await _place(G, start)
	ok(g0.distance_to(start) < 0.1 and G.pos.distance_to(start) < VIEW_TOL, "%s: the guest stands at the start" % what,
		"own %s here %s" % [_s(g0 - home), _s(G.pos - home)])
	watch = G
	seen = {}
	await act.call(G)
	await _run(settle + 0.6)
	watch = null
	var mirror := seen
	var own: Vector3 = await _ask()
	if mode != "":
		# the host keeps a mirror of the tow; the guest's game says how it ended ("time" only for the slide)
		var want := "time" if mode == "slide" else "arrived"
		ok(mirror.get("p", {}).get("mode", "") == mode and String(mirror.get("end", "")) == want,
			"%s: the host's mirror of the tow ends when the guest's game says (%s)" % [what, mirror.get("end", "-")])
	var moved := Vector2(own.x - start.x, own.z - start.z).length()
	ok(bot_moved > 0.8, "%s: the bot is moved (%.1f m)" % [what, bot_moved])
	ok(
		moved > 0.8 and Vector2(own.x - bot_at.x, own.z - bot_at.z).length() < TOL,
		"%s: the player is moved on their own game, where the bot went" % what,
		"moved %.1f m to %s, the bot to %s" % [moved, _s(own - home), _s(bot_at - home)])
	ok(G.pos.distance_to(own) < VIEW_TOL, "%s: the host's copy of the player follows" % what,
		"here %s, own %s" % [_s(G.pos - home), _s(own - home)])
	P.teleport(home)
	await _place(G, home + PARK)

func _cinder(_t: Hunter) -> void:
	var P := m.player
	_aim(P.pos + Vector3(-12.0, 0, 9.0))
	P.inp["sig"] = true
	await _run(DT)
	P.inp["sig"] = false

func _dredge(t: Hunter) -> void:
	var P := m.player
	_aim(t.pos)
	P.inp["sec_hold"] = false
	P.ak.press_rmb()
	await _run(DT)

func _ostra(t: Hunter) -> void:
	_aim(t.pos)
	m.player.ak.on_dash(false)
	await _run(DT)

func _vireo(t: Hunter) -> void:
	var at := t.pos
	_aim(at)
	m.player.ak.use_e()
	await _run(0.05)
	_aim(at + Vector3(-3.0, 0, 0))          # the flick: back toward Sparkle
	await _run(0.1)

func _bjorn(t: Hunter) -> void:
	var P := m.player
	_aim(t.pos)
	P.inp["sec_hold"] = true
	P.ak.press_rmb()
	for i in 30:
		P.inp["sec_hold"] = true
		await _run(DT)
	P.inp["sec_hold"] = false
	await _run(DT)

## Kael's Warchain hooks the player and pulls Kael to them; the player stays put (a self-pull).
func _zedran(G: Hunter) -> void:
	var P := m.player
	_kit("juggernaut")
	var start := home + Vector3(6.0, 0, 0)
	await _place(G, start)
	_aim(G.pos)
	var K: JuggernautKit = P.ak
	Displace.capture = true
	Displace.sent.clear()
	P.ak.use_e()
	await _run(0.3)
	var hooked := K.warchain.hooked() and K.warchain.target == G
	P.ak.use_e()
	await _run(1.2)
	Displace.capture = false
	var moves := Displace.sent.filter(func(e): return String(e[2]) == G.nid).size()
	await _ask()
	ok(hooked and K.warchain.arrivals == 1, "Kael's Warchain: it hooks the player and pulls Kael in",
		"hooked %s arrivals %d" % [hooked, K.warchain.arrivals])
	ok(P.flat_dist(G) < 2.6 and moves == 0,
		"Kael's Warchain: he lands beside the player; the chain sends no move for them",
		"gap %.1f, moves %d" % [P.flat_dist(G), moves])

## A hazard strikes on both games (each game runs its own hazards): the player is hurt once, by
## their own game, exactly as much as a bot beside them is hurt by the host's.
func _hazard(G: Hunter, B: Hunter) -> void:
	var at := home + Vector3(4.0, 0, -3.0)
	_fresh(B)
	B.teleport(at + Vector3(0, 0, 0.6))
	await _run(0.2)
	var b_hp := B.hp
	_strike(at)          # one strike on one game: what a strike does
	await _run(0.8)
	var single := b_hp - B.hp
	_fresh(B)
	await _place(G, at + Vector3(0, 0, -0.6))
	await _ask()
	var hp0 := _got("hp")
	var bot0 := B.hp
	Net.lobby_emit("dn", {"c": "strike", "at": [at.x, at.y, at.z]})
	await _run(0.7)          # (each game's hazards keep their own clock: the host's goes off a little later)
	_strike(at)
	await _run(0.8)
	await _ask()
	var lost := hp0 - _got("hp")
	var bot_lost := bot0 - B.hp
	ok(single > 1.0 and absf(lost - single) < 0.5 and absf(bot_lost - single) < 0.5,
		"hazard: a strike on both games hurts the player and the bot once each (no hit from the other game)",
		"player %.1f, bot %.1f, one strike %.1f" % [lost, bot_lost, single])
	B.teleport(home + Vector3(-6.0, 0, 9.0))
	await _place(G, home + PARK)

## Hit options beyond damage and the impulse travel with a hit on a player: a knock into a wall with a long
## wall stun stuns them that long on their own game; a burn's length and a slow's strength hold.
func _knock_extras(G: Hunter, B: Hunter) -> void:
	var P := m.player
	var at := home + Vector3(4.0, 0, 5.0)
	var o := {"kb": Vector2(0, 16.0), "wallstun": 2.0, "src": "abil", "ab": "lmb", "melee": true}
	_fresh(B)
	B.teleport(at)
	await _run(0.2)
	stun_on = B
	stun_max = 0.0
	B.hurt(1.0, P, o.duplicate())
	await _run(1.0)
	var bot_stun := stun_max
	stun_on = null
	B.teleport(home + Vector3(-6.0, 0, 9.0))
	await _place(G, at)
	G.hurt(1.0, P, o.duplicate())
	await _run(1.2)
	await _ask()
	ok(bot_stun >= 1.9 and absf(_got("stun_max") - bot_stun) < 0.15,
		"knock: a wall stun of 2 s slams the player into the cliff for 2 s on their own game, like the bot",
		"player %.2f, bot %.2f" % [_got("stun_max"), bot_stun])
	await _place(G, home + PARK)
	G.hurt(1.0, P, {"burn": 5.0, "burn_for": 4.0, "slow": 2.0, "slow_k": 0.4, "src": "abil"})
	await _run(0.3)
	await _ask()
	ok(_got("burn") > 3.3 and absf(_got("slow_k") - 0.4) < 0.01,
		"hit: the burn's length and the slow's strength reach the player (4 s, 40%)",
		"burn %.2f slow_k %.2f" % [_got("burn"), _got("slow_k")])

func _kit(arch: String) -> void:
	var P := m.player
	if P.arch != arch:
		P.reclass(Arch.weight(arch), arch)
		P.unlock_all()
		P.lvl = 6
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.face = PI * 0.5
	P.stun_t = 0.0
	P.dashes = P.max_dashes()
	for k in P.ak.cd: P.ak.cd[k] = 0.0
	P.ak.ch_rmb = 1.0
	P.inp["move"] = Vector2.ZERO

func _aim(p: Vector3) -> void:
	m.player.inp["aim"] = p + Vector3(0, 0.9, 0)
	m.player.inp["aim_y"] = p.y

## Asks the guest to stand at `at`, and waits until it says so and the host's copy is there too.
func _place(G: Hunter, at: Vector3) -> Vector3:
	replies.clear()
	Net.lobby_emit("dn", {"c": "place", "at": [at.x, at.y, at.z]})
	var own: Vector3 = await _reply()
	var t := 0.0
	while G.pos.distance_to(at) > 0.1 and t < 3.0:
		await _run(0.1)
		t += 0.1
	await _run(0.3)
	return own

func _ask() -> Vector3:
	replies.clear()
	Net.lobby_emit("dn", {"c": "ask"})
	return await _reply()

func _reply() -> Vector3:
	var t := 0.0
	while replies.is_empty() and t < 10.0:
		await _run(0.1)
		t += 0.1
	if replies.is_empty():
		return Vector3.INF
	return _v(replies[0]["pos"])

## The guest's own numbers from its last reply (hp, stun_max, burn, slow_k).
func _got(k: String) -> float:
	return float(replies[0].get(k, -1.0)) if not replies.is_empty() else -1.0

# ------------------------------------------------------------------ the guest
func _guest() -> void:
	print("DISPNET guest pid=%d" % OS.get_process_id())
	if not await _connect():
		print("DISPNET guest: no relay")
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
	if topic == "dn_r":
		replies.append(data)
		return
	if topic != "dn":
		return
	match String(data.get("c", "")):
		"start": _build(data["d"])
		"done": stop = true
		"place":
			if m and m.player:
				var a: Array = data["at"]
				_fresh(m.player)
				m.player.teleport(Vector3(a[0], a[1], a[2]))
				_say()
		"ask": _say()
		"strike": _strike(_v(data["at"]))

func _say() -> void:
	if m and m.player:
		var P := m.player
		Net.lobby_emit("dn_r", {
			"pos": [P.pos.x, P.pos.y, P.pos.z], "hp": P.hp, "stun_max": stun_max, "burn": P.burn_t, "slow_k": P.slow_k})

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	Net.set_presence({"name": "dn"})
	return Net.mode == "server"

## The same match on both games: the training island with the same seed, one hunter each, a flat strip
## at its first spawn, no Boki, monsters or crates in the way. An empty `d` builds it offline
## (--cast-predict-check's baseline).
func _build(d: Dictionary) -> void:
	var nm := Match.new()
	main.add_child(nm)
	var o := {"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": SEED, "no_drop": true,
		"cls": "medium"}
	if not d.is_empty():
		o["net"] = d
	await nm.start(o)
	nm.set_process(false)
	var W: World = nm.world
	var sp: Vector3 = W.spawns[0]
	var hx := int(floor(sp.x))
	var hz := int(floor(sp.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-10, 11):
		for dx in range(-8, 14):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for tiles in [W.stairs, W.walls, W.props, W.bush]:
				tiles.erase(i)
	for b in nm.breaks: b["dead"] = true
	home = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	for dx in range(1, 8):      # a cliff face along z = home + 7: a knock north slams into it
		for dz in range(7, 10):
			W.level[W.idx(hx + dx, hz + dz)] = lv + 3
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

func _fresh(T: Hunter) -> void:
	stun_max = 0.0
	T.max_hp = 10000.0
	T.hp = T.max_hp
	T.armor = 0.0
	for k in ["stun_t", "root_t", "slow_t", "knock_t", "cc_immune_t"]:
		T.set(k, 0.0)
	T.vel = Vector3.ZERO
	T.dr = {}
	T.dr_stun = false
	T.set_meta("marks", {})
	T.set_meta("gnd_until", 0.0)

## Runs the match `secs` in real time (one step a frame at 60 fps), with no monsters about.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(DT)
		t += DT
		if watch and seen.is_empty(): seen = m.displace.towing(watch)
		var sb: Ent = stun_on if stun_on else m.player
		if sb: stun_max = maxf(stun_max, sb.stun_t)
		await main.get_tree().process_frame

## A lightning rod's strike (BiomeRun._hit_area) at `at` on this game. Hazards run on every game.
func _strike(at: Vector3) -> void:
	var b := BiomeRun.new(m)
	b._hit_area(at, 1.8, 14.0, {"stun": 0.4, "sky": true})
	b.free_up()

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _s(v: Vector3) -> String:
	return "(%.1f, %.1f)" % [v.x, v.z]
