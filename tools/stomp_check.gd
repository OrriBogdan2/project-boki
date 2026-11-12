extends RefCounted
## --stomp-check: the stomp (docs/decisions/0061-stomp-lock.md, Owner 2026-11-11).
##  1. Holding interact on an enemy wisp for Stomp.COMMIT commits you; letting go, moving, dashing or
##     firing does nothing after that, and neither stomper nor wisp moves, shoves and knocks included.
##  2. The stomper takes damage as usual while locked, and it doesn't break the stomp.
##  3. A stun on the stomper cancels it at once; the wisp lives and can drift again.
##  4. Left alone, the stomp kills the wisp at Stomp.TIME, not before.
##  5. Online: the stomper's game sends "go" and how it ended; a "go" from another game pins this
##     game's wisp, "broken" lets it go, "done" eliminates it here.
##  6. Styles: every Hunter has its own default (owned, all different); the unlockable can't be worn
##     until bought with gems, then the local player stomps with it and bots keep their own; a save
##     with no stomp keys reads as "wearing your own".
##  7. Sounds (StompSfx), counted at the spot in this game, the stomper's and the wisp's alike: one
##     commit, one strike per beat and each louder than the last, the wisp's hum straining while
##     pinned, a crush on "done" and a crack on "broken" (never both); the saved wisp's squad hears
##     the crack from anywhere, a rival's stays at the spot; a strike's pitch falls and its body grows
##     from light to heavy.
## Never touches the save.

var bad := 0
var m: Match
var foe: Hunter
var W: Hunter

func ok(cond: bool, what: String) -> void:
	print("STOMPCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		m.step(Match.DT)
		t += Match.DT

func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(at)
	h.vel = Vector3.ZERO

## Solid ground well away from `at`.
func _far_from(at: Vector3) -> Vector3:
	var g := m.world.random_ground()
	while g.distance_to(at) < 20.0:
		g = m.world.random_ground()
	return g

## A fresh wisp at `at` with no Boki to pull it up, the stomper beside it, everyone else far away.
func _setup(at: Vector3) -> void:
	for h in m.hunters:
		if h != foe and h != W and not h.out:
			_spot(h, _far_from(at))
	if W.downed:
		m.revive_hunter(W, null)
	for kk in [W.kin, W.kin2]:
		if kk: (kk as Kin).dead = true
	foe.hp = foe.max_hp
	foe.armor = 0.0
	foe.shield = 0.0
	foe.stun_t = 0.0
	foe.launched_at = -9.0
	_spot(W, at)
	_spot(foe, at + Vector3(0.6, 0, 0))
	m.knock(W, foe, {})
	Sfx.listener = at
	Sfx.last_played.clear()
	Sfx.recent.clear()

## Whether `sname` played since the last ask; forgets it, so the next one counts on its own.
func _heard(sname: String) -> bool:
	var was := Sfx.last_played.has(sname)
	Sfx.last_played.erase(sname)
	Sfx.recent.erase(sname)
	return was

## The level (dB) the newest `sname` started at in a pool voice; the voice is cleared so the next
## read finds the next one.
func _level(sname: String) -> float:
	var takes = Sfx.streams.get(sname)
	if not takes is Array:
		takes = [takes]
	for p in Sfx.players:
		if p.stream != null and (takes as Array).has(p.stream):
			p.stop()
			p.stream = null
			return p.volume_db
	return NAN

## Hold interact until the stomp commits; the seconds it took.
func _commit() -> float:
	var t0 := m.time
	while foe.stomp.is_empty() and m.time - t0 < 2.0:
		foe.inp["interact"] = true
		_run(Match.DT)
	foe.inp["interact"] = false
	return m.time - t0

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
	foe = m.hunters.filter(func(x): return x.team != m.player.team)[0]
	W = m.hunters.filter(func(x): return x.team == m.player.team and x != m.player)[0]
	var home := m.world.random_ground()
	_check_lock(home)
	_check_stun(home + Vector3(6, 0, 0))
	_check_finish(home + Vector3(-6, 0, 0))
	_check_net(home + Vector3(0, 0, 6))
	_check_styles()
	_check_weights()
	print("STOMP CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _check_lock(at: Vector3) -> void:
	_setup(at)
	var took := _commit()
	ok(not foe.stomp.is_empty() and took <= Stomp.COMMIT + 0.1, "a %.2fs hold commits the stomp" % took)
	var f0 := foe.pos
	var w0 := W.pos
	for i in 40:
		foe.inp["move"] = Vector2(1, 0)
		foe.inp["dash"] = true
		foe.inp["fire"] = true
		W.inp["move"] = Vector2(-1, 0)
		if i == 10: foe.impulse(Vector2(6, 0))       # a hit's shove
		if i == 20: W.impulse(Vector2(0, 12))        # a knock on the wisp
		_run(Match.DT)
	ok(not foe.stomp.is_empty(), "letting go, moving, dashing and firing don't end it")
	ok(foe.pos.distance_to(f0) < 0.05, "the stomper stays on the spot (moved %.3f m)" % foe.pos.distance_to(f0))
	ok(W.pos.distance_to(w0) < 0.05, "the wisp stays on the spot (moved %.3f m)" % W.pos.distance_to(w0))
	ok(foe.roll_t <= 0.0, "no dodge mid-stomp")
	var hp0 := foe.hp
	foe.hurt(20.0, m.player, {})
	_run(Match.DT)
	ok(foe.hp < hp0 - 10.0 and not foe.stomp.is_empty(),
		"damage lands on the stomper (%.0f -> %.0f) and the stomp holds" % [hp0, foe.hp])
	Stomp.end(m, foe, "gone")

func _check_stun(at: Vector3) -> void:
	_setup(at)
	_commit()
	_run(1.0)
	Sfx.listener = at + Vector3(80, 0, 0)      # past the crack's reach: the squad hears it anyway
	foe.hurt(5.0, m.player, {"stun": 0.6})
	_run(Match.DT)
	ok(foe.stomp.is_empty(), "a stun cancels the stomp")
	ok(_heard("stomp_crack") and not _heard("stomp_crush"), "the break cracks (no crush), heard by the squad 80 m off")
	ok(W.downed and not W.out and not W.has_meta("stomped_by"), "the wisp survives the cancelled stomp and is let go")
	_spot(foe, at + Vector3(30, 0, 0))
	var w0 := W.pos
	for i in 30:
		W.inp["move"] = Vector2(1, 0)
		_run(Match.DT)
	ok(W.downed and not W.out and W.pos.distance_to(w0) > 0.2, "...and drifts again (%.2f m)" % W.pos.distance_to(w0))

func _check_finish(at: Vector3) -> void:
	_setup(at)
	_commit()
	ok(_heard("stomp_commit"), "the commit plays its sound")
	var t0 := m.time
	var strikes := 0
	var levels := []
	while not is_nan(_level("stomp_strike")):      # clear the strikes the earlier stomps left in the pool
		pass
	var strain := 0.0
	while not W.out and m.time - t0 < Stomp.TIME + 1.0:
		_run(Match.DT)
		if _heard("stomp_strike"):
			strikes += 1
			levels.append(_level("stomp_strike"))
		HunterWisp.tick(W, Match.DT)      # the hum is held from the render pass, which the check doesn't run
		if Sfx.loop_on(HunterWisp.hum_key(W)):
			strain = maxf(strain, (Sfx.loops[HunterWisp.hum_key(W)]["p"] as AudioStreamPlayer).pitch_scale)
	var took := m.time - t0
	ok(strikes == Stomp.BEATS, "a strike per beat (%d of %d)" % [strikes, Stomp.BEATS])
	var rising := levels.size() == Stomp.BEATS
	for i in range(1, levels.size()):
		rising = rising and levels[i] > levels[i - 1]
	ok(rising, "each strike lands louder than the last (%s dB)" % [levels])
	ok(strain > 1.3, "the pinned wisp's hum strains (pitch up to %.2f)" % strain)
	ok(_heard("stomp_crush") and not _heard("stomp_crack"), "the finish crushes (no crack)")
	ok(W.out and String(W.get_meta("died_why", "")) == "executed", "left alone the stomp executes the wisp")
	ok(absf(took - Stomp.TIME) <= 0.05, "at %.2fs (Stomp.TIME %.1fs)" % [took, Stomp.TIME])
	ok(foe.stomp.is_empty(), "and the stomper is free again")

func _check_net(at: Vector3) -> void:
	# the last wisp was executed (a knock now would wipe its team): the player stomps a rival instead
	W = m.hunters.filter(func(x): return x.team != m.player.team and x != foe)[0]
	foe = m.player
	_setup(at)
	# this game's stomper tells the others
	m.net_on = true
	Net.out_events.clear()
	Stomp.start(m, foe, W)
	Sfx.listener = at + Vector3(80, 0, 0)
	_heard("stomp_crack")
	Stomp.end(m, foe, "broken")
	ok(not _heard("stomp_crack"), "a rival wisp's break cracks at the spot, unheard 80 m off")
	Sfx.listener = at
	var sent: Array = Net.out_events.filter(func(e): return e[0] == "stomp")
	m.net_on = false
	ok(sent.size() == 2 and sent[0][3] == "go" and sent[0][4] == StompLook.style_id(foe) and sent[1][3] == "broken",
		"a stomp sends \"go\" with its style and how it ended (%s)" % [sent])
	Net.out_events.clear()
	# another game's stomper on this game's wisp
	foe.remote = true
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "go", "thunder_stomp"])
	ok(_heard("stomp_commit"), "the wisp's game hears another game's commit")
	var w0 := W.pos
	for i in 20:
		W.inp["move"] = Vector2(1, 0)
		_run(Match.DT)
	var pinned: bool = W.has_meta("stomped_by") and W.get_meta("stomped_by") == foe and W.pos.distance_to(w0) < 0.05
	ok(pinned and foe.stomp["style"] == "thunder_stomp",
		"a \"go\" from another game pins this game's wisp, in the sender's style")
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "broken"])
	ok(foe.stomp.is_empty() and W.downed and not W.out and not W.has_meta("stomped_by"),
		"a \"broken\" lets it go alive")
	ok(_heard("stomp_crack"), "...with the crack")
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "go", ""])
	_run(1.0)
	ok(_heard("stomp_strike"), "another game's stomp strikes here on its beat")
	Stomp.net_in(m, ["stomp", foe.nid, W.nid, "done"])
	ok(W.out and String(W.get_meta("died_why", "")) == "executed", "a \"done\" executes this game's wisp")
	ok(_heard("stomp_crush"), "...with the crush")
	foe.remote = false

func _check_styles() -> void:
	var seen := {}
	for f in DirAccess.get_files_at("res://content/archetypes"):
		var arch := String(f).get_basename()
		var sid := StompLook.default_for(arch)
		var st := StompLook.style(sid)
		var key := JSON.stringify(st.duplicate().merged({"name": "", "hunter": ""}, true))
		ok(sid != "" and StompLook.owned(sid) and not seen.has(key), "%s stomps its own way: %s" % [arch, sid])
		seen[key] = true
	ok(StompLook.equipped() == "" and StompLook.style_id(m.player) == StompLook.default_for(m.player.arch),
		"a save with no stomp keys wears the Hunter's own")
	ok(not StompLook.owned("thunder_stomp") and not StompLook.equip("thunder_stomp"), "the unlockable isn't yours yet")
	Save.d["gems"] = 100
	ok(not StompLook.buy("thunder_stomp"), "it can't be bought without the gems")
	Save.d["gems"] = 1000
	ok(StompLook.buy("thunder_stomp") and int(Save.d["gems"]) == 700 and StompLook.equip("thunder_stomp"),
		"bought for 300 gems and worn")
	m.player.ctrl = "local"
	ok(StompLook.style_id(m.player) == "thunder_stomp" and StompLook.style_id(W) == StompLook.default_for(W.arch),
		"the player stomps in it; a bot keeps its own")
	var a := StompLook.legs(StompLook.style("thunder_stomp"), 0.4)
	var b := StompLook.legs(StompLook.style(StompLook.default_for("archer")), 0.4)
	ok(a.distance_to(b) > 0.2, "styles pose differently mid-lift")

## Every weight class has a strike row; lighter Hunters strike higher, and only medium and heavy ones
## carry the body sound under it.
func _check_weights() -> void:
	var rows: Dictionary = StompLook.rules()["sound"]["strike"]
	var unrowed := Arch.ids().filter(func(id): return not rows.has(Arch.weight(id)))
	ok(unrowed.is_empty(), "every Hunter's weight class has a strike row (missing %s)" % [unrowed])
	var pitch := func(w): return float(rows[w]["pitch"])
	ok(pitch.call("light") > pitch.call("medium") and pitch.call("medium") > pitch.call("heavy"),
		"strike pitch falls light > medium > heavy")
	var arch0 := foe.arch
	Sfx.listener = foe.pos
	for w in ["light", "medium", "heavy"]:
		foe.arch = Arch.ids().filter(func(id): return Arch.weight(id) == w)[0]
		_heard("stomp_strike")
		_heard(String(rows["body"]))
		StompSfx.strike(m, foe, 0)
		var body := _heard(String(rows["body"]))
		ok(_heard("stomp_strike") and body == rows[w].has("body_db"),
			"a %s Hunter's strike (%s, body %s)" % [w, foe.arch, body])
	foe.arch = arch0
