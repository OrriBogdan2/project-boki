extends RefCounted
## --displace-net-check: abilities that move someone else's body move a player on ANOTHER game instance,
## on that player's own game, to the same place they move a bot (scripts/combat/displace.gd). Two real
## games over the desktop relay: this process is the host (it runs the relay in-process too) and starts a
## second headless game, the guest (--displace-net-check=guest), with CheckChild. Both build the
## same flat training strip; the host plays each ability first on a local bot, then on the guest's hunter,
## and the guest reports where its own game put it. Cinder's cloak pull, Grimble's reel, Motley's Trade,
## Sparkle's Skycall drag, Mossy's shield boop; Kael's Warchain pulls Kael to the player (not the player).
## A Boki's pull and spike (KinExec) move the player on their own game the same way, there by the next snapshot.
## Then the hit path: a hazard striking on both games hurts the player once; a knock's wall stun, a burn's
## length and a slow's strength reach the player's own game. Last, a dunk on a gliding player spikes them out
## of the air on their own game, with the landing stun a bot gets (GlideSpike), and a player diving under
## their glider (GlideDive) plunges in the dive pose on the host's screen too (hunter flag bit 28).
## Lines: DISPNET ok|FAIL <what>; the guest prints DISPNET guest pid=<pid>.

const DT := 1.0 / 60.0
const START_S := 240.0       # s for the guest to come up and build its match (a busy box boots it slowly)
const REPLY_S := 30.0        # s for the guest to answer, on its clock (CheckClock: a busy box starves it)
const TOL := 0.5             # m: the player's own game puts it within this of where the bot went
const VIEW_TOL := 0.4        # m: and the host's copy of it follows to within this
const SEED := 4242
const STEP_US := 16667       # µs of wall clock per DT step
const CATCH_UP_US := 100000  # µs the match clock may lag before it skips ahead (Match._process: 0.1 s a frame)
const PARK := Vector3(0, 0, -9.0)   # m from home: where the guest waits while the bot takes its turn
const SNAP_S := 0.12         # s: one snapshot send (Net.tick, 0.1 s, which also flushes the "ev" moves) and a frame

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
var building := false        # the guest is building its match (the host says start until it hears from it)
var stun_max := 0.0          # the longest stun seen on the watched body since its last place (guest: its own)
var stun_on: Ent = null
var watch: Ent = null         # the first tow on this body, as the host's mirror of it (seen)
var seen := {}
var paced_us := 0            # the wall clock (µs) the match clock has been stepped up to
var tag := "DISPNET"         # the prefix of every line (the remote-anim check reuses this host/guest harness)
var guest_flag := "--displace-net-check=guest"
var early := {}              # the guest's reply one snapshot after a Boki move on it
var door_gap := 0            # a check that puts a proxy on the guest's link keeps the port this far above free

func ok(cond: bool, what: String, info := "") -> void:
	n += 1
	print("%s %s %s  %s" % [tag, "ok  " if cond else "FAIL", what, info])
	if not cond: bad += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Engine.max_fps = 60
	RenderingServer.render_loop_enabled = false   # not looked at; slow frames stretch game time
	var guest := false
	for a in OS.get_cmdline_user_args():
		if a == guest_flag: guest = true
		if a.begins_with("--dn-port="): port = int(a.substr(10))
	Net.message.connect(_on_msg)
	if guest:
		await _guest()
	else:
		await _host()

# ------------------------------------------------------------------ the host
## Brings up the relay, the guest game and both matches; the guest's hunter as the host sees it, or null.
## The relay this check runs (a check with a bad line returns one that holds its packets).
func _relay() -> RelayServer:
	return RelayServer.new()

func _host_up() -> Hunter:
	port = CheckChild.free_port(7930 + OS.get_process_id() % 60, door_gap)
	dir = ProjectSettings.globalize_path("user://displace_net")
	DirAccess.make_dir_recursive_absolute(dir)
	var relay := _relay()
	relay.name = "Relay"
	main.add_child(relay)
	ok(relay.start(PackedStringArray(["--port=%d" % port])) == OK, "the relay listens on %d" % port)
	CheckChild.hold(relay.peer, START_S)
	ok(await _connect(), "the host is on the relay as %s" % Net.me)
	guest_pid = _start_guest()
	var other := ""
	var t0 := Time.get_ticks_msec()
	while other == "" and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.5).timeout
		for id in Net.peers:
			if String(id) != Net.me: other = String(id)
	ok(other != "", "the guest joins the relay", other)
	if other == "":
		return null
	var d := {"mid": "dn%d" % port, "seed": SEED, "host": Net.me, "teams": 2, "squad": 1, "tier": 0, "roster": [
		{"peer": Net.me, "team": 0, "name": "Host", "cls": "medium", "weapon": "", "kin": {}},
		{"peer": other, "team": 1, "name": "Guest", "cls": "medium", "weapon": "", "kin": {}}]}
	Net.lobby_emit("dn", {"c": "start", "d": d})
	await _build(d)
	var g: Hunter = m.ents_by_id.get("P" + other, null)
	var t1 := CheckClock.own_msec(guest_pid)
	var said := t1
	while ((g == null or g.net_t < 0.0) and CheckClock.own_msec(guest_pid) - t1 < START_S * 1000.0
			and OS.is_process_running(guest_pid)):
		await _run(0.2)
		g = m.ents_by_id.get("P" + other, null)
		if CheckClock.own_msec(guest_pid) - said > 3000:      # a slow guest may have missed it: say again
			said = CheckClock.own_msec(guest_pid)
			Net.lobby_emit("dn", {"c": "start", "d": d})
	ok(g != null and g.remote and g.net_t >= 0.0, "the guest's hunter is here, driven by the guest's game")
	return g if g != null and g.net_t >= 0.0 else null

## The guest game, headless (a subclass that screenshots on the guest starts it drawing).
func _start_guest() -> int:
	return CheckChild.start("%s --dn-port=%d" % [guest_flag, _guest_door()], dir.path_join("guest.log"))


## The port the guest joins the relay on (a check with a proxy on the guest's link returns the proxy's).
func _guest_door() -> int:
	return port

func _host() -> void:
	var g := await _host_up()
	if g == null:
		return _finish()
	var b: Hunter = m.make_hunter("B", 1, "medium", "Bot", "idle", {}, home + Vector3(-6.0, 0, 9.0), {"arch": "none"})
	await _case(g, b, "ashwick", Vector3(3.8, 0, 0), _cinder, 1.0, "Cinder's cloak pull", "step")
	await _case(g, b, "dredge", Vector3(6.0, 0, 0), _dredge, 2.0, "Grimble's reel", "haul")
	var dk: DredgeKit = m.player.ak
	ok(dk.arrivals == 2 and dk.pull.is_empty(),
		"Grimble's reel: on the player too it ends as an arrival (HAULED), reel let go", "arrivals %d" % dk.arrivals)
	await _case(g, b, "ostra", Vector3(8.0, 0, 0), _ostra, 2.2, "Motley's Trade")
	await _case(g, b, "mage", Vector3(7.0, 0, 0), _vireo, 2.4, "Sparkle's Skycall drag", "slide")
	await _case(g, b, "bulwark", Vector3(1.7, 0, 0), _bjorn, 1.2, "Mossy's shield push", "push")
	await _case(g, b, "bulwark", Vector3(8.0, 0, 0), _boki_pull, 1.2, "a Boki pull")
	ok(_v(early.get("pos", [0, 0, 0])).x < home.x + 7.9 or float(early.get("vx", 0.0)) < -1.0,
		"a Boki pull: the player's own game moves them within one snapshot",
		"x %.2f vx %.1f" % [_v(early.get("pos", [0, 0, 0])).x - home.x, float(early.get("vx", 0.0))])
	await _zedran(g)
	await _hazard(g, b)
	await _knock_extras(g, b)
	await _glide_spike(g, b, func(t: Hunter): m.displace.spike(t, -16.0, m.player), "a dunk")
	await _glide_spike(g, b, _boki_spike, "a Boki spike")
	ok(bool(early.get("shot", false)), "a Boki spike: the player is spiked on their own game within one snapshot",
		"vy %.1f" % float(early.get("vy", 0.0)))
	await _meeko_bar(g)
	await _ally_safe(g)
	await _glide_dive(g)
	_finish()

func _finish() -> void:
	Net.lobby_emit("dn", {"c": "done"})
	await main.get_tree().create_timer(1.0).timeout
	if guest_pid > 0 and OS.is_process_running(guest_pid):
		OS.kill(guest_pid)
	print("%s DONE, %d checks, failures: %d" % [tag, n, bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## One ability, on the bot and then on the guest from the same spot: the guest's own game puts it where
## the bot went, it really moved there, and the host's copy of it follows.
func _case(
	g: Hunter, b: Hunter, arch: String, off: Vector3, act: Callable, settle: float, what: String, mode := ""
) -> void:
	var p_v := m.player
	_kit(arch)
	_fresh(b)
	b.teleport(home + off)
	await _run(0.2)
	await act.call(b)
	await _run(settle)
	var bot_at := b.pos
	var bot_moved := Vector2(bot_at.x - home.x - off.x, bot_at.z - home.z - off.z).length()
	b.teleport(home + Vector3(-6.0, 0, 9.0))
	_kit(arch)
	var start := home + off
	var g0: Vector3 = await _place(g, start)
	ok(g0.distance_to(start) < 0.1 and g.pos.distance_to(start) < VIEW_TOL, "%s: the guest stands at the start" % what,
		"own %s here %s" % [_s(g0 - home), _s(g.pos - home)])
	watch = g
	seen = {}
	await act.call(g)
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
	ok(g.pos.distance_to(own) < VIEW_TOL, "%s: the host's copy of the player follows" % what,
		"here %s, own %s" % [_s(g.pos - home), _s(own - home)])
	p_v.teleport(home)
	await _place(g, home + PARK)

func _cinder(_t: Hunter) -> void:
	var p_v := m.player
	_aim(p_v.pos + Vector3(-12.0, 0, 9.0))
	p_v.inp["sig"] = true
	await _run(DT)
	p_v.inp["sig"] = false

func _dredge(t: Hunter) -> void:
	var p_v := m.player
	_aim(t.pos)
	p_v.inp["sec_hold"] = false
	p_v.ak.press_rmb()
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
	var p_v := m.player
	_aim(t.pos)
	p_v.inp["sec_hold"] = true
	p_v.ak.press_rmb()
	for i in 30:
		p_v.inp["sec_hold"] = true
		# owner 11-11: touching the aegis pushes nobody; LMB with it up is the boop (BjornBoop)
		p_v.inp["fire"] = i >= 10 and i < 13
		await _run(DT)
	p_v.inp["fire"] = false
	p_v.inp["sec_hold"] = false
	await _run(DT)

## A Boki's pull (KinExec, a pull with no gap) from 8 m, short of the caster (a body in the way stops it); on
## the guest, what its game says a snapshot later.
func _boki_pull(t: Hunter) -> void:
	var st := StageSpec.parse({"delivery": {"type": "burst", "origin": "here", "radius": 4.0},
		"effects": [{"type": "pull", "strength": 8.0, "to": "center"}]}, "", GrammarReport.new())
	await _boki(st, t)

## A Boki's spike (KinExec's spike modifier) on an airborne body.
func _boki_spike(t: Hunter) -> void:
	var st := StageSpec.parse({"delivery": {"type": "burst", "origin": "here", "radius": 2.5},
		"effects": [{"type": "damage", "amount": 1.0}], "modifiers": [{"type": "spike"}]}, "", GrammarReport.new())
	await _boki(st, t)

func _boki(st: StageSpec, t: Hunter) -> void:
	var cx := {"m": m, "caster": m.player, "power": 1.0, "k": 1.0, "_radius": 4.0}
	KinExec.apply_foe(st.effects, t, cx, m.player.pos, st)
	await _run(DT)
	if t.remote:
		await _run(SNAP_S)
		await _ask()
		early = replies[0] if not replies.is_empty() else {}

## Kael's Warchain hooks the player and pulls Kael to them; the player stays put (a self-pull).
func _zedran(g: Hunter) -> void:
	var p_v := m.player
	_kit("juggernaut")
	var start := home + Vector3(6.0, 0, 0)
	await _place(g, start)
	_aim(g.pos)
	var k_v: JuggernautKit = p_v.ak
	Displace.capture = true
	Displace.sent.clear()
	p_v.ak.use_e()
	await _run(0.3)
	var hooked := k_v.warchain.hooked() and k_v.warchain.target == g
	p_v.ak.use_e()
	await _run(1.2)
	Displace.capture = false
	var moves := Displace.sent.filter(func(e): return String(e[2]) == g.nid).size()
	await _ask()
	ok(hooked and k_v.warchain.arrivals == 1, "Kael's Warchain: it hooks the player and pulls Kael in",
		"hooked %s arrivals %d" % [hooked, k_v.warchain.arrivals])
	ok(p_v.flat_dist(g) < 2.6 and moves == 0,
		"Kael's Warchain: he lands beside the player; the chain sends no move for them",
		"gap %.1f, moves %d" % [p_v.flat_dist(g), moves])

## A hazard strikes on both games (each game runs its own hazards): the player is hurt once, by
## their own game, exactly as much as a bot beside them is hurt by the host's.
func _hazard(g: Hunter, b: Hunter) -> void:
	var at := home + Vector3(4.0, 0, -3.0)
	_fresh(b)
	b.teleport(at + Vector3(0, 0, 0.6))
	await _run(0.2)
	var b_hp := b.hp
	_strike(at)          # one strike on one game: what a strike does
	await _run(0.8)
	var single := b_hp - b.hp
	_fresh(b)
	await _place(g, at + Vector3(0, 0, -0.6))
	await _ask()
	var hp0 := _got("hp")
	var bot0 := b.hp
	Net.lobby_emit("dn", {"c": "strike", "at": [at.x, at.y, at.z]})
	await _run(0.7)          # (each game's hazards keep their own clock: the host's goes off a little later)
	_strike(at)
	await _run(0.8)
	await _ask()
	var lost := hp0 - _got("hp")
	var bot_lost := bot0 - b.hp
	ok(single > 1.0 and absf(lost - single) < 0.5 and absf(bot_lost - single) < 0.5,
		"hazard: a strike on both games hurts the player and the bot once each (no hit from the other game)",
		"player %.1f, bot %.1f, one strike %.1f" % [lost, bot_lost, single])
	b.teleport(home + Vector3(-6.0, 0, 9.0))
	await _place(g, home + PARK)

## Meeko's Hearth Call on the guest: its own game shows the protection bar (her nid, the seconds left from the
## snapshot) while she channels, and not once she is stunned out of it.
func _meeko_bar(g: Hunter) -> void:
	var p_v := m.player
	_kit("tender")
	g.team = p_v.team
	Net.lobby_emit("dn", {"c": "team", "team": p_v.team})
	await _place(g, home + Vector3(6.0, 0, 0))
	await _ask()
	var before: Array = replies[0].get("chan", [0]) if not replies.is_empty() else [0]
	_aim(g.pos)
	p_v.ak.cast_ult()
	await _run(1.0)
	await _ask()
	var chan: Array = replies[0].get("chan", []) if not replies.is_empty() else []
	var left := float(chan[1]) if chan.size() == 2 else -1.0
	ok(before.is_empty() and chan.size() == 2 and chan[0] == p_v.nid and left > 2.5 and left < 4.5,
		"Meeko's channel on the guest: its game draws her bar, ~4 s of 5 left (before %s, then %s)" % [before, chan])
	p_v.stun_t = 1.0
	await _run(1.0)
	await _ask()
	var after: Array = replies[0].get("chan", [0]) if not replies.is_empty() else [0]
	ok(after.is_empty(), "she is stunned out of it: the bar is gone on the guest's game (%s)" % [after])
	p_v.stun_t = 0.0
	await _place(g, home + PARK)

## Hit options beyond damage and the impulse travel with a hit on a player: a knock into a wall with a long
## wall stun stuns them that long on their own game; a burn's length and a slow's strength hold.
func _knock_extras(g: Hunter, b: Hunter) -> void:
	var p_v := m.player
	var at := home + Vector3(4.0, 0, 5.0)
	var o := {"kb": Vector2(0, 16.0), "wallstun": 2.0, "src": "abil", "ab": "lmb", "melee": true}
	_fresh(b)
	b.teleport(at)
	await _run(0.2)
	stun_on = b
	stun_max = 0.0
	b.hurt(1.0, p_v, o.duplicate())
	await _run(1.0)
	var bot_stun := stun_max
	stun_on = null
	b.teleport(home + Vector3(-6.0, 0, 9.0))
	await _place(g, at)
	g.hurt(1.0, p_v, o.duplicate())
	await _run(1.2)
	await _ask()
	ok(bot_stun >= 1.9 and absf(_got("stun_max") - bot_stun) < 0.15,
		"knock: a wall stun of 2 s slams the player into the cliff for 2 s on their own game, like the bot",
		"player %.2f, bot %.2f" % [_got("stun_max"), bot_stun])
	await _place(g, home + PARK)
	g.hurt(1.0, p_v, {"burn": 5.0, "burn_for": 4.0, "slow": 2.0, "slow_k": 0.4, "src": "abil"})
	await _run(0.3)
	await _ask()
	ok(_got("burn") > 3.3 and absf(_got("slow_k") - 0.4) < 0.01,
		"hit: the burn's length and the slow's strength reach the player (4 s, 40%)",
		"burn %.2f slow_k %.2f" % [_got("burn"), _got("slow_k")])

## `spike` (a dunk: Displace.spike at 16 m/s, or a Boki's spike) on a glider 10 m up: the bot and the player
## are both spiked, fall and land stunned for GlideSpike.land_stun; unspiked, a glider would still be in the air.
func _glide_spike(g: Hunter, b: Hunter, spike: Callable, what: String) -> void:
	var at := home + Vector3(4.0, 10.0, -3.0)
	_fresh(b)
	_glide(b, at)
	await _run(0.2)
	stun_on = b
	stun_max = 0.0
	await spike.call(b)
	await _run(1.6)
	var bot_stun := stun_max
	stun_on = null
	ok(b.grounded and bot_stun >= GlideSpike.land_stun - 0.05, "glide spike: %s spikes a gliding bot" % what,
		"stun %.2f grounded %s" % [bot_stun, b.grounded])
	b.teleport(home + Vector3(-6.0, 0, 9.0))
	Net.lobby_emit("dn", {"c": "glide", "at": [at.x, at.y, at.z]})
	var t := 0.0
	while not g.gliding and t < 5.0:
		await _run(0.1)
		t += 0.1
	ok(g.gliding, "glide spike: the host sees the player gliding")
	await spike.call(g)
	await _run(1.8)
	await _ask()
	ok(_got("air") == 0.0 and absf(_got("stun_max") - bot_stun) < 0.15,
		"glide spike: %s spikes the player out of the air on their own game, like the bot" % what,
		"player stun %.2f air %.0f, bot %.2f" % [_got("stun_max"), _got("air"), bot_stun])
	await _place(g, home + PARK)

## The guest holds crouch under its glider 30 m up: the host's copy of it plunges (GlideDive.on from the
## flag bit), is posed in the dive and not the glide, and comes out of it when the guest's dive ends.
func _glide_dive(g: Hunter) -> void:
	Net.lobby_emit("dn", {"c": "dive", "at": [home.x + 4.0, home.y + 30.0, home.z - 3.0]})
	var plunged := false
	var posed := 0.0
	var t := 0.0
	while not (plunged and not g.plunging()) and t < 6.0:
		await _run(DT)
		t += DT
		g.render(DT, 1.0)      # (Match's own render pass is off in the checks)
		plunged = plunged or g.plunging()
		if g.plunging() and g.anim and not g.anim_s.get("gliding", true): posed = maxf(posed, g.anim.dive_k)
	ok(plunged, "glide dive: the host sees the player plunge (the dive's flag bit)")
	ok(posed > 0.5, "glide dive: the host draws the player in the dive pose, not the glide", "dive_k %.2f" % posed)
	ok(not g.plunging(), "glide dive: the pose ends when the player's dive ends", "%.1f s" % t)
	await _place(g, home + PARK)

## A body gliding at `at` with a cool glider and the glide held.
static func _glide(t_v: Hunter, at: Vector3) -> void:
	t_v.teleport(at)
	t_v.grounded = false
	t_v.gliding = true
	t_v.inp["glide"] = true
	t_v.glide_fuel = 1.0
	t_v.glide_cd = 0.0
	t_v.shot_down = false

## The same moves aimed at a teammate (the host's view of the guest is moved to its own team): no move is sent
## over the relay and the guest's own game leaves it standing.
func _ally_safe(g: Hunter) -> void:
	var p_v := m.player
	g.team = p_v.team
	var moves := [["ashwick", Vector3(3.8, 0, 0), _cinder, 1.0, "Cinder's cloak pull"],
		["mage", Vector3(7.0, 0, 0), _vireo, 2.4, "Sparkle's Skycall drag"],
		["bulwark", Vector3(1.7, 0, 0), _bjorn, 1.2, "Albert's shield push"]]
	for c in moves:
		_kit(c[0])
		var start: Vector3 = home + c[1]
		await _place(g, start)
		Displace.capture = true
		Displace.sent.clear()
		await c[2].call(g)
		await _run(float(c[3]) + 0.6)
		Displace.capture = false
		var sent := Displace.sent.filter(func(e): return String(e[2]) == g.nid).size()
		var own: Vector3 = await _ask()
		var moved := Vector2(own.x - start.x, own.z - start.z).length()
		ok(sent == 0 and moved < 0.3, "%s: a teammate on the guest's game is left alone" % c[4],
			"sent %d, moved %.1f m" % [sent, moved])
		p_v.teleport(home)
		await _place(g, home + PARK)

func _kit(arch: String) -> void:
	var p_v := m.player
	if p_v.arch != arch:
		p_v.reclass(Arch.weight(arch), arch)
		p_v.unlock_all()
		p_v.lvl = 6
	p_v.teleport(home)
	p_v.vel = Vector3.ZERO
	p_v.face = PI * 0.5
	p_v.stun_t = 0.0
	p_v.dashes = p_v.max_dashes()
	for k in p_v.ak.cd: p_v.ak.cd[k] = 0.0
	p_v.ak.ch_rmb = 1.0
	p_v.inp["move"] = Vector2.ZERO

func _aim(p: Vector3) -> void:
	m.player.inp["aim"] = p + Vector3(0, 0.9, 0)
	m.player.inp["aim_y"] = p.y

## Asks the guest to stand at `at`, and waits until it says so and the host's copy is there too.
func _place(g: Hunter, at: Vector3) -> Vector3:
	replies.clear()
	Net.lobby_emit("dn", {"c": "place", "at": [at.x, at.y, at.z]})
	var own: Vector3 = await _reply()
	var t := 0.0
	while g.pos.distance_to(at) > 0.1 and t < 3.0:
		await _run(0.1)
		t += 0.1
	await _run(0.3)
	return own

func _ask() -> Vector3:
	replies.clear()
	Net.lobby_emit("dn", {"c": "ask"})
	return await _reply()

func _reply() -> Vector3:
	var t0 := CheckClock.own_msec(guest_pid)
	while (replies.is_empty() and CheckClock.own_msec(guest_pid) - t0 < REPLY_S * 1000.0
			and OS.is_process_running(guest_pid)):
		await _run(0.1)
	if replies.is_empty():
		return Vector3.INF
	return _v(replies[0]["pos"])

## The guest's own numbers from its last reply (hp, stun_max, burn, slow_k).
func _got(k: String) -> float:
	return float(replies[0].get(k, -1.0)) if not replies.is_empty() else -1.0

# ------------------------------------------------------------------ the guest
func _guest() -> void:
	if not await _connect():
		print("%s guest: no relay" % tag)
		main.get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	while m == null and not stop and Time.get_ticks_msec() - t0 < START_S * 1000.0:
		await main.get_tree().create_timer(0.2).timeout
	if m == null:        # what the guest lacked (a GPU worker's guest.log is all we see of it)
		print("%s guest: no match after %.0f s: %s, peers seen %s" % [tag, (Time.get_ticks_msec() - t0) / 1000.0,
			"still building" if building else "no start heard", Net.peers.keys()])
	else:
		print("%s guest: match up after %.1f s" % [tag, (Time.get_ticks_msec() - t0) / 1000.0])
	while m != null and not stop:
		await _run(0.1)
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
		"start":
			if m == null and not building:
				building = true
				print("%s guest: start heard" % tag)
				_build(data["d"])
		"done": stop = true
		"place":
			if m and m.player:
				var a: Array = data["at"]
				_fresh(m.player)
				m.player.inp["crouch"] = false
				m.player.teleport(Vector3(a[0], a[1], a[2]))
				_say()
		"ask": _say()
		"team":
			if m and m.player:
				m.player.team = int(data["team"])
				for h in m.hunters:      # (a lobby roster would name the host's arch; this match only reclasses)
					if h != m.player:
						h.reclass(Arch.weight("tender"), "tender")
		"glide":
			if m and m.player:
				_fresh(m.player)
				_glide(m.player, _v(data["at"]))
		"dive":
			if m and m.player:
				_fresh(m.player)
				_glide(m.player, _v(data["at"]))
				m.player.inp["crouch"] = true
		"strike": _strike(_v(data["at"]))

func _say() -> void:
	if m and m.player:
		var p_v := m.player
		Net.lobby_emit("dn_r", {
			"pos": [p_v.pos.x, p_v.pos.y,
					p_v.pos.z], "hp": p_v.hp, "stun_max": stun_max, "burn": p_v.burn_t, "slow_k": p_v.slow_k,
			"air": 0.0 if p_v.grounded else 1.0, "vx": p_v.vel.x, "vy": p_v.vel.y, "shot": p_v.shot_down,
			"chan": _chan(p_v)})

## The protection bar this game would draw for its player: [Meeko's nid, seconds left], or [] when none.
func _chan(p_v: Hunter) -> Array:
	var from := ChannelBar.caster_on(m, p_v)
	return [] if from == null else [from.nid, ChannelBar.read(from)[1]]

# ------------------------------------------------------------------ both
func _connect() -> bool:
	Net.server_addr = "127.0.0.1:%d" % port
	Net.start()
	var t0 := Time.get_ticks_msec()
	while Net.mode != "server" and Time.get_ticks_msec() - t0 < 30000:
		await main.get_tree().create_timer(0.2).timeout
	if Net.enet:
		CheckChild.hold(Net.enet.peer, START_S)
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
	var w: World = nm.world
	var sp: Vector3 = w.spawns[0]
	var hx := int(floor(sp.x))
	var hz := int(floor(sp.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi]) if w.kind[hi] != World.T_VOID else 0
	for dz in range(-10, 11):
		for dx in range(-8, 14):
			if not w.inb(hx + dx, hz + dz): continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			for tiles in [w.stairs, w.walls, w.props, w.bush]:
				tiles.erase(i)
	for b in nm.breaks: b["dead"] = true
	home = Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5)
	for dx in range(1, 8):      # a cliff face along z = home + 7: a knock north slams into it
		for dz in range(7, 10):
			w.level[w.idx(hx + dx, hz + dz)] = lv + 3
	m = nm
	_clear_wild()
	for h in nm.hunters:
		if h.kin:
			h.kin.dead = true
			nm.kins.erase(h.kin)
			h.kin.queue_free()
			h.kin = null
	for k: Kin in nm.kins.duplicate():  # the wild ones too: the roster moves which species rolls onto the strip
		if k.owner_h == null:
			k.dead = true
			nm.kins.erase(k)
			k.queue_free()
	var p_v := nm.player
	p_v.max_hp = 10000.0
	p_v.hp = p_v.max_hp
	p_v.teleport(home if Net.is_host() else home + PARK)
	m = nm

func _fresh(t_v: Hunter) -> void:
	stun_max = 0.0
	t_v.max_hp = 10000.0
	t_v.hp = t_v.max_hp
	t_v.armor = 0.0
	for k in ["stun_t", "root_t", "slow_t", "knock_t", "cc_immune_t"]:
		t_v.set(k, 0.0)
	t_v.vel = Vector3.ZERO
	t_v.dr = {}
	t_v.dr_stun = false
	t_v.set_meta("marks", {})
	t_v.set_meta("gnd_until", 0.0)

## Runs the match `secs` of its own time with no monsters about (a check's lair boss stays), stepped by the wall clock
## as Match._process
## steps a game: as many DT steps a frame as real time asks, never more than CATCH_UP behind. (One step a
## frame ran a host drawing ~35 fps under xvfb at ~0.6x the headless guest's clock, so the guest's copy of
## a pull ran on past its end and its body shoved the guest's own hunter away: not something two games do.)
func _run(secs: float) -> void:
	var t := 0.0
	while t < secs - 0.0001:
		var now := Time.get_ticks_usec()
		paced_us = maxi(paced_us, now - CATCH_UP_US)
		while paced_us + STEP_US <= now and t < secs - 0.0001:
			paced_us += STEP_US
			t += DT
			for mb in m.mobs.duplicate():
				if not mb is Boss:
					mb.queue_free()
					m.mobs.erase(mb)
			_clear_wild()
			m.step(DT)
			_stepped()
		await main.get_tree().process_frame

## No wild Boki about either: one standing on the strip shoves the player's body off its mark (which wild
## Bokis a seed puts near the strip shifts with every change to what the match builds first).
func _clear_wild() -> void:
	for k in m.kins.duplicate():
		if k.is_wild():
			k.dead = true
			m.kins.erase(k)
			m.ents_by_id.erase(k.nid)
			k.queue_free()

## After each match step: the host's mirror of the watched tow, and the longest stun seen.
func _stepped() -> void:
	if watch and seen.is_empty(): seen = m.displace.towing(watch)
	var sb: Ent = stun_on if stun_on else m.player
	if sb: stun_max = maxf(stun_max, sb.stun_t)

## A lightning rod's strike (BiomeRun._hit_area) at `at` on this game. Hazards run on every game.
func _strike(at: Vector3) -> void:
	var b := BiomeRun.new(m)
	b._hit_area(at, 1.8, 14.0, {"stun": 0.4, "sky": true})
	b.free_up()

static func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func _s(v: Vector3) -> String:
	return "(%.1f, %.1f)" % [v.x, v.z]
