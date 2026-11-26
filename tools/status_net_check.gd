extends "res://tools/displace_net_check.gd"
## --status-net-check: the kit statuses a host puts on a player reach that player's own game the same
## (scripts/arch/kit_status.gd, the Net "kst" event, and the hit's burn and slow). Two real games over the
## desktop relay, set up like --displace-net-check: the host applies each status through the kit that owns
## it, asks the guest what its own hunter carries, and compares kind, stacks and seconds left (within
## LEFT_TOL) and the look on the body. Cinder's Ignite levels and burn, Neve's Chill and Shatter, Sparkle's
## Static, Sable's Marks (and two Sables' Marks on one body, each kept per caster), Vex's Daze, Disoriented,
## Shred and Blight (stacks, seconds and strength), hit slows, Grounded.
## Lines: STATNET ok|FAIL <what>; the guest prints DISPNET guest pid=<pid> (the base class reads it).

const LEFT_TOL := 0.1  # s: the seconds a status has left may differ by this between the two games
const CLEAR_S := 0.3  # s: a clear rides the next Net flush, and the question may overtake it
const TAGS := ["ign", "chl", "sta", "mrk"]
const LOOKS := {"ign": "Tag_ign", "chl": "Tag_chl", "sta": "Tag_sta", "mrk": "Tag_mrk", "gnd": "", "rat": ""}
const GUEST_ARG := "--status-net-check=guest"

var st_at := 0.0  # host m.time when the running plain status was put on
var st_secs := 0.0  # and how long it was put on for


func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("STATNET %s %s  %s" % ["ok  " if cond else "FAIL", what, info])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == GUEST_ARG:
			guest = true
		if a.begins_with("--dn-port="):
			port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()


# ------------------------------------------------------------------ the host
func _host() -> void:
	port = CheckChild.free_port(7930 + OS.get_process_id() % 60)
	dir = ProjectSettings.globalize_path("user://status_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := RelayServer.new()
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	CheckChild.hold(relay.peer, START_S)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	guest_pid = CheckChild.start("%s --dn-port=%d" % [GUEST_ARG, port], dir.path_join("guest.log"))
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me:
				other = String(id)
	ok(other != "", "the guest joins the relay", other)
	if other == "":
		return _end()
	var d := {
		"mid": "sn%d" % port,
		"seed": SEED,
		"host": Net.me,
		"teams": 2,
		"squad": 1,
		"tier": 0,
		"roster":
		[
			{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
			{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}
		]
	}
	Net.lobby_emit("dn", {"c": "start", "d": d})
	_build(d)
	var g: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := CheckClock.own_msec(guest_pid)
	while (
		(g == null or g.net_t < 0.0)
		and CheckClock.own_msec(guest_pid) - t1 < START_S * 1000.0
		and OS.is_process_running(guest_pid)
	):
		await _run(0.2)
		g = m.ents_by_id.get("P" + other, null)
	ok(g != null and g.remote, "the guest's hunter is here, driven by the guest's game")
	if g == null:
		return _end()
	await _cinder(g)
	await _neve(g)
	await _sparkle(g)
	await _sable(g)
	await _plain(g)
	_end()


func _end() -> void:
	Net.lobby_emit("dn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("STATNET DONE, %d checks, failures: %d" % [n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)


## The guest stands 4 m from the host's hunter, clean, and the host plays `arch`.
func _start(g: Hunter, arch: String) -> void:
	_kit(arch)
	await _place(g, home + Vector3(4.0, 0, 0))


func _cinder(g: Hunter) -> void:
	await _start(g, "ashwick")
	var k: AshwickKit = m.player.ak
	var ign := func():
		var e: Dictionary = k.ignites.get(g.get_instance_id(), {})
		var on := not e.is_empty() and float(e["until"]) > float(m.time)
		var row := [int(e["lvl"]), float(e["until"]) - float(m.time)] if on else [0, 0.0]
		return {"ign": row, "burn": [1 if on else 0, row[1]]}
	k.stoke(g)
	await _run(0.3)
	await _same("Cinder Ignite 1 (Ablaze)", ign)
	await _run(1.0)
	k.stoke(g)
	await _run(0.3)
	await _same("Cinder Ignite 2 (Flashover)", ign)


func _neve(g: Hunter) -> void:
	await _start(g, "rimewright")
	var k: RimewrightKit = m.player.ak
	var key := g.get_instance_id()
	var chl := func(): return {"chl": [1 if k.chilled(g) else 0, float(k.chill.get(key, {}).get("left", 0.0))]}
	k.add_chill(g)
	await _run(0.5)
	await _same("Neve Chill", chl)
	var hp := g.hp
	g.hp = 0.0
	k.on_deal(g, 1.0, {"src": "abil"})
	g.hp = hp
	await _run(0.1)
	await _same("Neve Shatter: the Chill is spent", chl)
	await _run(0.6)
	await _same("Neve Shatter: the splinters Chill them again", chl)
	ok(k.splinter_log >= 1, "Neve's Shatter went off", "splinters %d" % k.splinter_log)


func _sparkle(g: Hunter) -> void:
	await _start(g, "mage")
	var k: MageKit = m.player.ak
	var key := g.get_instance_id()
	var sta := func(): return {"sta": [k.spark_n(g), float(k.sparks.get(key, {}).get("t", 0.0))]}
	for i in 3:
		k.add_spark(g, 1)
	await _run(0.5)
	await _same("Sparkle Static x3", sta)
	k.add_spark(g, 1)
	await _run(0.3)
	await _same("Sparkle Static x4 (Live)", sta)
	k.clear_sparks(g)
	await _run(0.1)
	await _same("Sparkle Static spent", sta)


func _sable(g: Hunter) -> void:
	await _start(g, "thief")
	var k: ThiefKit = m.player.ak
	var mrk := func(): return {"mrk": [k.marks_on(g), float(g.get_meta("marks", {}).get(k.h.nid, [0, 0.0])[1])]}
	k.add_mark(g, 2, true)
	await _run(0.5)
	await _same("Sable Marks x2", mrk)
	k.add_mark(g, 1, true)
	await _run(0.2)
	await _same("Sable Marks x3", mrk)
	k.clear_marks(g)
	await _run(CLEAR_S)
	await _same("Sable Marks cleared", mrk)
	await _two_sables(g, k)


## A second Sable on the host's side (a kit on a body of its own, with its own nid) marks the same player:
## the player's game keeps each Sable's stack apart, as meta "marks" does on the casters' game.
func _two_sables(g: Hunter, k: ThiefKit) -> void:
	var s2 := Hunter.new()
	s2.m = m
	s2.nid = "P_sable2"
	s2.team = m.player.team
	var k2 := ArchKit.make(s2, "thief") as ThiefKit
	var dur := float(k.res_def().get("dur", 4.0))
	var mine := func(): return float(g.get_meta("marks", {}).get(k.h.nid, [0, 0.0])[1])
	var t2 := float(m.time)
	var both := func():
		var a: int = k.marks_on(g)
		var b2: int = int(g.get_meta("marks", {}).get(s2.nid, [0, 0.0])[0])
		var lb := maxf(0.0, dur - (float(m.time) - t2)) if b2 > 0 else 0.0
		var w := {"mrk": [a + b2, maxf(mine.call(), lb)]}
		w["mrk@" + k.h.nid] = [a, mine.call()]
		w["mrk@" + s2.nid] = [b2, lb]
		return w
	k2.add_mark(g, 3, true)
	await _run(0.2)
	k.add_mark(g, 2, true)
	await _run(0.4)
	await _same("two Sables' Marks on one body (3 + 2)", both)
	k.add_mark(g, 1, true)
	await _run(0.2)
	await _same("two Sables: one Sable's new Mark leaves the other's stack", both)
	k.clear_marks(g)
	await _run(CLEAR_S)
	await _same("two Sables: one Sable's Marks spent, the other's stay", both)
	k2.clear_marks(g)
	await _run(CLEAR_S)
	await _same("two Sables: both spent", both)
	s2.free()


## Plain statuses: the host's expected seconds left are what it put on less what has gone by.
func _plain(g: Hunter) -> void:
	await _start(g, "gunslinger")
	var left := func(k: String, extra := {}):
		return {k: [1, maxf(0.0, st_secs - (float(m.time) - st_at))]}.merged(extra)
	st_at = m.time
	st_secs = 4.0
	KitStatus.apply(g, "rat", st_secs)
	await _run(0.4)
	await _same("Vex Daze", left.bind("rat"))
	await _start(g, "dredge")
	st_at = m.time
	st_secs = 3.0
	KitStatus.apply(g, "gnd", st_secs)
	await _run(0.4)
	await _same("Grounded", left.bind("gnd"))
	await _start(g, "ostra")
	st_at = m.time
	st_secs = 3.0
	KitStatus.apply(g, "dsr", st_secs, 0.4)
	await _run(0.4)
	await _same("Disoriented slow", left.bind("dsr", {"slow": [1, st_secs - (float(m.time) - st_at)]}))
	await _start(g, "dolm")
	var rd: Dictionary = (m.player.ak as DolmKit).rock_def()
	st_at = m.time
	st_secs = float(rd.get("shred_t", 3.0))
	var shred := float(rd.get("shred", 0.2))
	KitStatus.apply(g, "vul", st_secs, shred)
	await _run(0.4)
	await _same("Shred", left.bind("vul", {"vul_k": [roundi(shred * 100.0), 0.0]}))
	await _start(g, "ashwick")
	st_at = m.time
	st_secs = 3.0
	KitStatus.apply(g, "blt", st_secs)
	await _run(0.4)
	await _same("Blight", left.bind("blt", {"blt_k": [60, 0.0]}))
	await _start(g, "bulwark")
	st_at = m.time
	st_secs = 2.0
	g.hurt(1.0, m.player, {"slow": st_secs, "slow_k": 0.3, "src": "abil"})
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
		ok(
			int(g[0]) == stacks and snappedf(absf(float(g[1]) - secs), 0.01) <= LEFT_TOL,
			"%s: %s on the player's own game is %d stack(s), %.2f s left" % [what, k, stacks, secs],
			"guest %d, %.2f s" % [int(g[0]), float(g[1])]
		)
		if LOOKS.has(k) and k != "burn":
			var word := "shows" if stacks > 0 else "is gone"
			ok(bool(g[2]) == (stacks > 0), "%s: %s look on the body %s" % [what, k, word])


# ------------------------------------------------------------------ the guest
func _fresh(t: Hunter) -> void:
	super._fresh(t)
	for k in TAGS:
		t.remove_meta("tag_" + k)
	for k in ["rat_until", "dsr_until"]:
		t.set_meta(k, 0.0)
	for k in ["burn_t", "slow_k", "vuln_t", "vuln_k", "blight_t", "blight_k"]:
		t.set(k, 0.0)
	for node in LOOKS.values():
		var old := t.get_node_or_null(node) if node != "" else null
		if old:
			old.queue_free()
			old.name = "Gone_" + node


func _say() -> void:
	if m == null or m.player == null:
		return
	var p := m.player
	var st := {}
	for k in TAGS:
		st[k] = [KitStatus.tag_n(p, k), KitStatus.tag_left(p, k), _look(p, k)]
		for by in p.get_meta("tag_" + k, {}):
			st[k + "@" + String(by)] = [KitStatus.tag_n(p, k, by), KitStatus.tag_left(p, k, by), false]
	st["vul"] = [1 if p.vuln_t > 0.0 else 0, p.vuln_t, false]
	st["vul_k"] = [roundi(p.vuln_k * 100.0) if p.vuln_t > 0.0 else 0, 0.0, false]
	st["blt"] = [1 if p.blight_t > 0.0 else 0, p.blight_t, false]
	st["blt_k"] = [roundi(p.blight_k * 100.0) if p.blight_t > 0.0 else 0, 0.0, false]
	st["rat"] = [1 if KitStatus.rattled(p) else 0, KitStatus.rattled_left(p), _look(p, "rat")]
	var gl := maxf(0.0, float(p.get_meta("gnd_until", 0.0)) - float(m.time))
	st["gnd"] = [1 if gl > 0.0 else 0, gl, _look(p, "gnd")]
	var dl := maxf(0.0, float(p.get_meta("dsr_until", 0.0)) - float(m.time))
	st["dsr"] = [1 if dl > 0.0 else 0, dl, false]
	st["slow"] = [1 if p.slow_t > 0.0 else 0, p.slow_t, false]
	st["burn"] = [1 if p.burn_t > 0.0 else 0, p.burn_t, false]
	Net.lobby_emit("dn_r", {"pos": [p.pos.x, p.pos.y, p.pos.z], "st": st})


## Whether the body carries the look for `kind`: the pips of a stack show one per stack.
func _look(p: Hunter, kind: String) -> bool:
	if kind == "gnd" or kind == "rat":  # (StatusLooks draws these from the body's own timers, no word node)
		return StatusLooks.carries(p, "gnd" if kind == "gnd" else "daze")
	var node := p.get_node_or_null(LOOKS[kind])
	if node == null:
		return false
	return not kind in TAGS or node.get_child_count() == KitStatus.tag_n(p, kind)
