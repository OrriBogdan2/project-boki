extends "res://tools/displace_net_check.gd"
## --raid-boss-bar-online-check: a Heart Raid client gets the host's boss top bar (PVE_HEART_RAID.md, Risks).
## Two real games over the desktop relay (the --displace-net-check harness this extends), a raid squad of two.
## The host raises the boss; the guest's copy is a plain Mob fed by the snapshots (hp, max_hp). The guest's
## Lairs.boss_for must find it inside the boss square, and the HUD bar (name from the raid rules, phase from
## the synced hp, Boss.phase_at) must match the host's real Boss at full, 60%, 30% health, show nothing
## outside the square, and nothing once it is dead. No Net field: Net.VERSION is unchanged.
## Lines: RBAR ok|FAIL <what>.

const HP_TOL := 0.02         # of max health: the guest's hp is up to one snapshot (0.1 s) old
var home_at := Vector3.ZERO

func _init() -> void:
	tag = "RBAR"
	guest_flag = "--raid-boss-bar-online-check=guest"

## Both games build the raid (the lobby's start: one team of two, the raid's options), not the training strip.
func _build(d: Dictionary) -> void:
	d["teams"] = 1
	d["squad"] = 2
	d["heart_raid"] = true
	for r in d["roster"]:
		r["team"] = 0
	var o := HeartRaid.opts(2, "normal")
	o.merge({"net": d, "seed": SEED, "no_drop": true, "cls": "medium"}, true)
	var nm := Match.new()
	main.add_child(nm)
	await nm.start(o)
	nm.set_process(false)
	nm.player.max_hp = 1.0e6
	nm.player.hp = nm.player.max_hp
	m = nm

## No monster sweep (the base's _run frees every mob, the boss with them): just step the match.
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		m.step(DT)
		t += DT
		await main.get_tree().process_frame

func _on_msg(topic: String, data, from: String) -> void:
	if topic == "dn" and typeof(data) == TYPE_DICTIONARY and String(data.get("c", "")) == "bar":
		_say_bar()
		return
	super._on_msg(topic, data, from)

## The guest's own view of the bar: what boss_for finds, its numbers, the phase the bar would print.
func _say_bar() -> void:
	var P := m.player
	var b: Mob = m.lairs.boss_for(P)
	var rep := {"pos": [P.pos.x, P.pos.y, P.pos.z], "has": b != null, "plain": b != null and not (b is Boss),
		"name": String(HeartRaid.rules()["boss"]["name"]), "hud": m.hud != null}
	if b != null:
		rep["hp"] = b.hp
		rep["max"] = b.max_hp
		rep["phase"] = Boss.phase_at(b.hp, b.max_hp)
	Net.lobby_emit("dn_r", rep)

# ------------------------------------------------------------------ the host
func _host() -> void:
	var G := await _host_up()
	if G == null:
		return _finish()
	var rd := m.heart_raid
	ok(rd != null and rd.host(), "the host runs the raid")
	var site := m.heart.site
	home_at = m.world.free_spot_near(site + Vector3(-4, 0, 0), [], 1.0, 0.45, 4.0)
	m.player.teleport(home_at)
	await _place(G, m.world.free_spot_near(site + Vector3(-4, 0, 3), [], 1.0, 0.45, 4.0))
	rd._spawn_boss()
	var b := rd.boss as Boss
	ok(b != null and not b.dormant, "the host raises the boss")
	await _run(1.5)
	var r := await _bar()
	ok(bool(r["has"]) and bool(r["plain"]), "guest: in the square its boss is a plain Mob that boss_for finds", str(r))
	ok(String(r["name"]) == String(b.md["name"]), "guest: the bar's name is the host boss's name", String(r["name"]))
	ok(bool(r.get("hud", false)), "guest: it has a HUD to draw the bar on")
	for f in [1.0, 0.6, 0.3]:
		b.hp = b.max_hp * f
		await _run(1.5)
		r = await _bar()
		ok(bool(r["has"]) and absf(float(r["hp"]) / float(r["max"]) - f) < HP_TOL,
			"guest: the bar's health is %d%% like the host's" % int(f * 100.0), "%s / %s" % [r.get("hp"), r.get("max")])
		ok(int(r.get("phase", -1)) == b.phase, "guest: the bar's phase (%d) is the host boss's (%d) at %d%%" % [
			int(r.get("phase", -1)) + 1, b.phase + 1, int(f * 100.0)])
	ok(b.phase == 2, "the host boss reached its third phase")
	var away := m.world.free_spot_near(site + Vector3(float(rd.lair["half"]) + 14.0, 0, 0), [], 1.0, 0.45, 6.0)
	await _place(G, away)
	r = await _bar()
	ok(not bool(r["has"]), "guest: outside the boss's square no bar shows", str(r))
	await _place(G, home_at + Vector3(0, 0, 2))
	r = await _bar()
	ok(bool(r["has"]), "guest: back in the square the bar shows again")
	b.hurt(b.max_hp * 10.0, m.player, {})
	await _run(2.0)
	r = await _bar()
	ok(not bool(r["has"]), "guest: the boss down, the bar goes", str(r))
	_finish()

func _bar() -> Dictionary:
	replies.clear()
	Net.lobby_emit("dn", {"c": "bar"})
	await _reply()
	return replies[0] if not replies.is_empty() else {"has": false, "plain": false, "name": "", "hud": false}
