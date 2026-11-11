extends "res://tools/displace_net_check.gd"
## --status-net-check: the kit statuses a host puts on a player reach that player's own game the same
## (scripts/arch/kit_status.gd, the Net "kst" event, and the hit's burn and slow). Two real games over the
## desktop relay, set up like --displace-net-check: the host applies each status through the kit that owns
## it, asks the guest what its own hunter carries, and compares kind, stacks and seconds left (within
## LEFT_TOL) and the look on the body. Cinder's Ignite levels and burn, Neve's Chill and Shatter, Sparkle's
## Static, Sable's Marks, Vex's Daze, Disoriented and hit slows, Grounded.
## Lines: STATNET ok|FAIL <what>; the guest prints DISPNET guest pid=<pid> (the base class reads it).

const LEFT_TOL := 0.1            # s: the seconds a status has left may differ by this between the two games
const TAGS := ["ign", "chl", "sta", "mrk"]
const LOOKS := {"ign": "Tag_ign", "chl": "Tag_chl", "sta": "Tag_sta", "mrk": "Tag_mrk",
	"gnd": "Grounded", "rat": "Rattled"}
const GUEST_ARG := "--status-net-check=guest"

var st_at := 0.0                 # host m.time when the running plain status was put on
var st_secs := 0.0               # and how long it was put on for

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("STATNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == GUEST_ARG: guest = true
		if a.begins_with("--dn-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
func _host() -> void:
	port = 7930 + OS.get_process_id() % 60
	dir = ProjectSettings.globalize_path("user://status_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	var cmd := "cd '%s' && %s --headless -- %s --dn-port=%d > '%s' 2>&1" % [
		ProjectSettings.globalize_path("res://"), GODOT, GUEST_ARG, port, dir.path_join("guest.log")]
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
		return _end()
	var d := {"mid": "sn%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
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
		return _end()
	await _cinder(G)
	await _neve(G)
	await _sparkle(G)
	await _sable(G)
	await _plain(G)
	_end()

func _end() -> void:
	Net.lobby_emit("dn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	_read_pid()
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("STATNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## The guest stands 4 m from the host's hunter, clean, and the host plays `arch`.
func _start(G: Hunter, arch: String) -> void:
	_kit(arch)
	await _place(G, home + Vector3(4.0, 0, 0))

func _cinder(G: Hunter) -> void:
	await _start(G, "ashwick")
	var K: AshwickKit = m.player.ak
	var ign := func():
		var e: Dictionary = K.ignites.get(G.get_instance_id(), {})
		var on := not e.is_empty() and float(e["until"]) > float(m.time)
		var row := [int(e["lvl"]), float(e["until"]) - float(m.time)] if on else [0, 0.0]
		return {"ign": row, "burn": [1 if on else 0, row[1]]}
	K.stoke(G)
	await _run(0.3)
	await _same("Cinder Ignite 1 (Ablaze)", ign)
	await _run(1.0)
	K.stoke(G)
	await _run(0.3)
	await _same("Cinder Ignite 2 (Flashover)", ign)

func _neve(G: Hunter) -> void:
	await _start(G, "rimewright")
	var K: RimewrightKit = m.player.ak
	var key := G.get_instance_id()
	var chl := func(): return {"chl": [1 if K.chilled(G) else 0, float(K.chill.get(key, {}).get("left", 0.0))]}
	K.add_chill(G)
	await _run(0.5)
	await _same("Neve Chill", chl)
	var hp := G.hp
	G.hp = 0.0
	K.on_deal(G, 1.0, {"src": "abil"})
	G.hp = hp
	await _run(0.1)
	await _same("Neve Shatter: the Chill is spent", chl)
	await _run(0.6)
	await _same("Neve Shatter: the splinters Chill them again", chl)
	ok(K.splinter_log >= 1, "Neve's Shatter went off", "splinters %d" % K.splinter_log)

func _sparkle(G: Hunter) -> void:
	await _start(G, "mage")
	var K: MageKit = m.player.ak
	var key := G.get_instance_id()
	var sta := func(): return {"sta": [K.spark_n(G), float(K.sparks.get(key, {}).get("t", 0.0))]}
	for i in 3: K.add_spark(G, 1)
	await _run(0.5)
	await _same("Sparkle Static x3", sta)
	K.add_spark(G, 1)
	await _run(0.3)
	await _same("Sparkle Static x4 (Live)", sta)
	K.clear_sparks(G)
	await _run(0.1)
	await _same("Sparkle Static spent", sta)

func _sable(G: Hunter) -> void:
	await _start(G, "thief")
	var K: ThiefKit = m.player.ak
	var mrk := func(): return {"mrk": [K.marks_on(G), float(G.get_meta("marks", {}).get(K.h.nid, [0, 0.0])[1])]}
	K.add_mark(G, 2, true)
	await _run(0.5)
	await _same("Sable Marks x2", mrk)
	K.add_mark(G, 1, true)
	await _run(0.2)
	await _same("Sable Marks x3", mrk)
	K.clear_marks(G)
	await _run(0.1)
	await _same("Sable Marks cleared", mrk)

## Plain statuses: the host's expected seconds left are what it put on less what has gone by.
func _plain(G: Hunter) -> void:
	await _start(G, "gunslinger")
	var left := func(k: String, extra := {}):
		return {k: [1, maxf(0.0, st_secs - (float(m.time) - st_at))]}.merged(extra)
	st_at = m.time
	st_secs = 4.0
	KitStatus.apply(G, "rat", st_secs)
	await _run(0.4)
	await _same("Vex Daze", left.bind("rat"))
	await _start(G, "dredge")
	st_at = m.time
	st_secs = 3.0
	KitStatus.apply(G, "gnd", st_secs)
	await _run(0.4)
	await _same("Grounded", left.bind("gnd"))
	await _start(G, "ostra")
	st_at = m.time
	st_secs = 3.0
	KitStatus.apply(G, "dsr", st_secs, 0.4)
	await _run(0.4)
	await _same("Disoriented slow", left.bind("dsr", {"slow": [1, st_secs - (float(m.time) - st_at)]}))
	await _start(G, "bulwark")
	st_at = m.time
	st_secs = 2.0
	G.hurt(1.0, m.player, {"slow": st_secs, "slow_k": 0.3, "src": "abil"})
	await _run(0.4)
	await _same("a hit's slow", func(): return {"slow": [1, maxf(0.0, st_secs - (float(m.time) - st_at))]})

# ------------------------------------------------------------------ compare
## Asks the guest for what its hunter carries and holds it to `want`, which gives {kind: [stacks, seconds left]}
## and is read the moment the question goes out, so the two games are compared at the same instant.
func _same(what: String, want: Callable) -> void:
	var w: Dictionary = want.call()
	replies.clear()
	Net.lobby_emit("dn", {"c": "ask"})
	await _reply()
	var got: Dictionary = replies[0].get("st", {}) if not replies.is_empty() else {}
	for k in w:
		var g: Array = got.get(k, [0, 0.0, false])
		var stacks := int(w[k][0])
		var secs := float(w[k][1])
		ok(int(g[0]) == stacks and snappedf(absf(float(g[1]) - secs), 0.01) <= LEFT_TOL,
			"%s: %s on the player's own game is %d stack(s), %.2f s left" % [what, k, stacks, secs],
			"guest %d, %.2f s" % [int(g[0]), float(g[1])])
		if LOOKS.has(k) and k != "burn":
			var word := "shows" if stacks > 0 else "is gone"
			ok(bool(g[2]) == (stacks > 0), "%s: %s look on the body %s" % [what, k, word])

# ------------------------------------------------------------------ the guest
func _fresh(T: Hunter) -> void:
	super._fresh(T)
	for k in TAGS:
		T.remove_meta("tag_" + k)
	for k in ["rat_until", "dsr_until"]:
		T.set_meta(k, 0.0)
	for k in ["burn_t", "slow_k"]:
		T.set(k, 0.0)
	for node in LOOKS.values():
		var old := T.get_node_or_null(node)
		if old:
			old.queue_free()
			old.name = "Gone_" + node

func _say() -> void:
	if m == null or m.player == null:
		return
	var P := m.player
	var st := {}
	for k in TAGS:
		st[k] = [KitStatus.tag_n(P, k), KitStatus.tag_left(P, k), _look(P, k)]
	st["rat"] = [1 if KitStatus.rattled(P) else 0, KitStatus.rattled_left(P), _look(P, "rat")]
	var gl := maxf(0.0, float(P.get_meta("gnd_until", 0.0)) - float(m.time))
	st["gnd"] = [1 if gl > 0.0 else 0, gl, _look(P, "gnd")]
	var dl := maxf(0.0, float(P.get_meta("dsr_until", 0.0)) - float(m.time))
	st["dsr"] = [1 if dl > 0.0 else 0, dl, false]
	st["slow"] = [1 if P.slow_t > 0.0 else 0, P.slow_t, false]
	st["burn"] = [1 if P.burn_t > 0.0 else 0, P.burn_t, false]
	Net.lobby_emit("dn_r", {"pos": [P.pos.x, P.pos.y, P.pos.z], "st": st})

## Whether the body carries the look for `kind`: the pips of a stack show one per stack.
func _look(P: Hunter, kind: String) -> bool:
	var node := P.get_node_or_null(LOOKS[kind])
	if node == null:
		return false
	return not kind in TAGS or node.get_child_count() == KitStatus.tag_n(P, kind)
