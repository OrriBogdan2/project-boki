extends RefCounted
## --follower-check: tamed Boki follow you (Follow, ROADMAP §2 owner decisions).
##   1. a fresh tame becomes a follower beside you, not a bag entry; a second tame goes in the bag
##   2. it trots after you, and rides in your satchel while you glide or cross the abyss
##   3. it can be knocked out; nobody else can tame it while you're in the map (downed or dead and
##      waiting on a revive included); you pick it back up
##   4. extract with it close: it comes home (apply_result puts it on the roster)
##   5. leave the map without it: steal windows by tier (Meadow none, Dusk Isles 10 s, Hollow 30 s);
##      a teammate can't take it; a rival's tame is slower and a hit starts it over; a rival tames
##      it in time -> theirs; nobody does -> it goes home
##   6. bots: a bot picks its knocked-out follower back up, and a bot goes and tames a rival's stray
##   7. online: follower ids belong to their hunter's game, the snapshot carries role and window
##   8. the results/save: a follower you lost to a rival never reaches the roster
## Prints FOLLOW ok/FAIL lines and "FOLLOW DONE, failures: N".

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("FOLLOW %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(host: Node) -> void:
	main = host
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var st := Save.new_kin("cindle", "Pip")
	st["starter"] = true
	Save.d["roster"] = [st]
	Save.d["active"] = st["uid"]
	_basics()
	_knockout()
	_extract_home()
	await _windows()
	_steal_rules()
	_bots_pick()
	_bots_steal()
	_net()
	_results_save()
	if m: m.queue_free()
	print("FOLLOW DONE, failures: %d" % bad)
	host.get_tree().quit(1 if bad > 0 else 0)

func _fresh(tier := 0, squad := 1, teams := 3) -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": teams, "squad": squad, "tier": tier, "length": 1e9, "seed": 31, "no_drop": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	if m.blight: m.blight.set("enabled", false)
	for h in m.hunters:
		if h != m.player: h.ctrl = "idle"; h.inp["move"] = Vector2.ZERO

## An open patch of ground near the player.
func _open_spot(from: Vector3, r := 2) -> Vector3:
	var w := m.world
	for rad in range(0, 40):
		for i in 16:
			var q := from + Vector3(cos(TAU * i / 16.0), 0, sin(TAU * i / 16.0)) * float(rad)
			var okk := true
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if w.is_void(q.x + dx, q.z + dz) or w.is_block(q.x + dx, q.z + dz) or absf(w.ground_at(q.x + dx, q.z + dz) - w.ground_at(q.x, q.z)) > 0.3:
						okk = false
			if okk:
				return Vector3(q.x, w.ground_at(q.x, q.z), q.z)
	return from

func _put(h: Ent, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

func _steps(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		for mb in m.mobs: mb.queue_free()
		m.mobs.clear()
		m.step(Match.DT); t += Match.DT

## A dazed wild Boki at `at`, ready to tame.
func _wild(at: Vector3, sp := "puddlet") -> Kin:
	var rec := Save.new_kin(sp, "", 99)
	return m.spawn_wild(rec, at, true)

## h holds interact on k until it's tamed (or `secs` run out). Returns true if it was.
func _tame(h: Hunter, k: Kin, secs := 6.0, each := Callable()) -> bool:
	var t := 0.0
	while t < secs and not k.dead:
		h.inp["interact"] = true
		if each.is_valid(): each.call()
		m.step(Match.DT); t += Match.DT
	h.inp["interact"] = false
	return k.dead

func _basics() -> void:
	_fresh()
	var P := m.player
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	var w := _wild(at + Vector3(1.0, 0, 0))
	ok(_tame(P, w), "a dazed wild Boki is tamed with a hold")
	var f := Follow.of(P)
	ok(f != null and f.role == "follow" and f.state == "follow", "the tame becomes a follower (%s)" % (f.state if f else "none"))
	ok(P.caught.is_empty(), "a follower isn't in the bag (bag %d)" % P.caught.size())
	ok(f != null and f.owner_h == P and f.team == P.team, "it's on your team")
	# a second tame goes in the bag
	var w2 := _wild(P.pos + Vector3(-1.0, 0, 0.3), "burrlet")
	_tame(P, w2)
	ok(P.caught.size() == 1 and Follow.of(P) == f, "a second tame goes in the bag, one follower at a time")
	# it trots after you
	var far := _open_spot(P.pos + Vector3(8, 0, 0), 2)
	_put(P, far)
	_steps(4.0)
	ok(f.flat_dist(P) < 4.0 and not f.tucked, "it trots after you (%.1f m behind)" % f.flat_dist(P))
	# tucked into the satchel while you glide / over the abyss
	P.gliding = true
	_steps(0.1, func(): P.gliding = true)
	ok(f.tucked and not f.hittable(), "it rides in your satchel while you glide (tucked %s)" % f.tucked)
	P.gliding = false
	_put(P, far)
	_steps(0.5)
	ok(not f.tucked and f.hittable(), "and hops out when you land")
	ok(int(m.kstat.get("follow", 0)) >= 1, "counted (kstat follow %d)" % int(m.kstat.get("follow", 0)))

func _knockout() -> void:
	_fresh(2)
	var P := m.player
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	var w := _wild(at + Vector3(1.0, 0, 0))
	_tame(P, w)
	var f := Follow.of(P)
	if f == null:
		ok(false, "no follower to knock out")
		return
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	_put(R, f.pos + Vector3(0.6, 0, 0))
	f.hurt(9999.0, R, {})
	ok(f.state == "ko" and not f.dead, "a big hit knocks it out (%s)" % f.state)
	ok(Follow.of(P) == f, "it's still yours while knocked out")
	# a rival standing on it can't tame it
	R.inp["interact"] = true
	_steps(4.0, func(): R.inp["interact"] = true; _put(R, f.pos + Vector3(0.4, 0, 0)))
	R.inp["interact"] = false
	ok(not f.dead and Follow.of(P) == f and R.caught.is_empty(), "a rival can't tame it while you're in the map")
	# you're downed: still not
	m.knock(P, R, {})
	_steps(2.0, func(): R.inp["interact"] = true; _put(R, f.pos + Vector3(0.4, 0, 0)); P.down_hp = maxf(P.down_hp, 50.0))
	ok(not f.dead and R.caught.is_empty(), "nor while you're downed")
	m.revive_hunter(P, P)
	R.inp["interact"] = false
	_put(R, m.world.random_ground())
	# you pick it back up
	_put(P, f.pos + Vector3(0.5, 0, 0))
	var t := 0.0
	while t < 2.0 and f.state == "ko":
		P.inp["interact"] = true
		m.step(Match.DT); t += Match.DT
	P.inp["interact"] = false
	ok(f.state == "follow" and f.hp > 0.0, "you pick it back up in about %.1f s" % t)
	# knocked into the abyss: it scrambles back into the satchel, never lost that way
	f.fall_out()
	ok(not f.dead and f.tucked and f.state == "follow", "falling off is never how you lose it")

func _extract_home() -> void:
	_fresh(1)
	var P := m.player
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	_tame(P, _wild(at + Vector3(1.0, 0, 0)))
	var f := Follow.of(P)
	m._extract(P, "hatch", "test")
	ok(f != null and f.dead and Follow.watch(m) == null, "extracting with it beside you: it comes along (no steal window)")
	var res := Follow.result(m)
	ok(String(res.get("fate", "")) == "home", "results: home (%s)" % str(res.get("fate", "")))
	var n0: int = Save.d["roster"].size()
	var out := Game.apply_result({"extracted": true, "tier": 1, "caught": [], "follower": res, "kin_runs": []})
	ok(Save.d["roster"].size() == n0 + 1 and String((out.get("follower", {}) as Dictionary).get("fate", "")) == "home", "apply_result puts it on the roster (%d -> %d)" % [n0, Save.d["roster"].size()])
	var nk: Dictionary = Save.d["roster"][Save.d["roster"].size() - 1]
	ok(String((nk.get("origin", {}) as Dictionary).get("how", "")) == "wild" and nk.has("serial"), "with its provenance: tamed in the wild, serial %s" % str(nk.get("serial", "")))

## Leaves the map without the follower in each tier and measures the window.
func _windows() -> void:
	for tier in [0, 1, 2]:
		_fresh(tier, 1, 3)
		var P := m.player
		var at := _open_spot(P.pos, 3)
		_put(P, at)
		_tame(P, _wild(at + Vector3(1.0, 0, 0)))
		var f := Follow.of(P)
		if f == null:
			ok(false, "tier %d: no follower" % tier)
			continue
		# you go out for good, far from it
		_put(P, _open_spot(at + Vector3(20, 0, 0), 1))
		P.lives = 1
		m.eliminate(P, null, "knocked out", true)
		Life.make_gone(m, P)
		var want: float = [0.0, 10.0, 30.0][tier]
		var w := Follow.watch(m)
		if want <= 0.0:
			ok(w == null and f.dead, "%s: no steal window, it goes home" % Data.TIERS[tier]["name"])
			ok(String(Follow.result(m).get("fate", "")) == "home", "%s: results say home" % Data.TIERS[tier]["name"])
			continue
		ok(w != null and absf(w.steal_t - want) < 0.05 and w.state == "dazed", "%s: a %.0f s window (%.1f)" % [Data.TIERS[tier]["name"], want, w.steal_t if w else -1.0])
		var t := 0.0
		while Follow.watch(m) != null and t < want + 5.0:
			m.step(Match.DT); t += Match.DT
		ok(absf(t - want) < 0.3, "%s: nobody tames it, it goes home after %.1f s" % [Data.TIERS[tier]["name"], t])
		ok(String(Follow.result(m).get("fate", "")) == "home", "%s: results say home" % Data.TIERS[tier]["name"])
		await main.get_tree().process_frame

func _steal_rules() -> void:
	_fresh(1, 2, 3)
	var P := m.player
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var R: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	_tame(P, _wild(at + Vector3(1.0, 0, 0)))
	var f := Follow.of(P)
	# extracted without it: it was off on its own, far away
	_put(P, _open_spot(at + Vector3(24, 0, 0), 1))
	_put(f, at); f.tucked = false
	m._extract(P, "hatch", "test")
	var w := Follow.watch(m)
	ok(w == f and w.role == "stray", "extracting without it: it's a stray, with a window")
	# a teammate can't take it
	_put(mate, w.pos + Vector3(0.4, 0, 0))
	_tame(mate, w, 2.0)
	ok(not w.dead and mate.caught.is_empty(), "your teammate can't tame it (it's going home anyway)")
	_put(mate, m.world.random_ground())
	# a rival's tame is slow, and a hit starts it over
	_put(R, w.pos + Vector3(0.4, 0, 0))
	var t := 0.0
	var reset := false
	while t < 1.6:
		R.inp["interact"] = true
		if absf(t - 1.5) < Match.DT * 0.5:
			R.hurt_at = m.time
			var before := w.catch_prog
			m.step(Match.DT); t += Match.DT
			reset = before > 0.3 and w.catch_prog == 0.0
			continue
		m.step(Match.DT); t += Match.DT
	ok(reset, "a hit on the tamer starts the tame over")
	var t2 := 0.0
	while t2 < 6.0 and not w.dead:
		R.inp["interact"] = true
		m.step(Match.DT); t2 += Match.DT
	R.inp["interact"] = false
	ok(w.dead and R.caught.size() == 1, "a rival tames it in %.1f s (capture time %.1f)" % [t2, float(m.T.get("capture_time", 3.0))])
	ok(t2 >= float(m.T.get("capture_time", 3.0)) - 0.1, "taming a stray is slower than a wild Boki (1.3 s)")
	var rc: Dictionary = R.caught[0] if not R.caught.is_empty() else {}
	ok(String(rc.get("lost_from", "")) == P.pname, "the rival's bag knows whose it was (%s)" % str(rc.get("lost_from", "")))
	ok(Follow.of(R) == null, "a stolen stray goes in the thief's bag, not at their side")
	var res := Follow.result(m)
	ok(String(res.get("fate", "")) == "stolen" and String(res.get("holder", "")) == R.pname, "results: stolen by %s" % str(res.get("holder", "")))

func _bots_pick() -> void:
	_fresh(1, 1, 3)
	var B: Hunter = m.hunters.filter(func(x): return x != m.player)[0]
	B.ctrl = "bot"
	B.ai = m.bot_brain.new_mind(m.rng, 0.7, m.bot_cfg)
	var at := _open_spot(B.pos, 3)
	_put(B, at)
	for h in m.hunters:
		if h != B: _put(h, m.world.random_ground()); h.ctrl = "idle"
	var w := _wild(at + Vector3(1.0, 0, 0))
	var t := 0.0
	while t < 8.0 and not w.dead:
		m.step(Match.DT); t += Match.DT
	var f := Follow.of(B)
	ok(f != null, "a bot tames a dazed Boki and it follows them (%.1f s)" % t)
	if f == null: return
	f.hurt(9999.0, null, {})
	ok(f.state == "ko", "the bot's follower is knocked out")
	_put(B, f.pos + Vector3(5.0, 0, 0))
	t = 0.0
	while t < 12.0 and f.state == "ko":
		m.step(Match.DT); t += Match.DT
	ok(f.state == "follow", "the bot goes back and picks it up (%.1f s)" % t)

func _bots_steal() -> void:
	_fresh(2, 1, 3)
	var P := m.player
	var B: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	_tame(P, _wild(at + Vector3(1.0, 0, 0)))
	var f := Follow.of(P)
	for h in m.hunters:
		if h != P and h != B: _put(h, m.world.random_ground()); h.ctrl = "idle"
	B.ctrl = "bot"
	B.ai = m.bot_brain.new_mind(m.rng, 0.7, m.bot_cfg)
	_put(B, _open_spot(at + Vector3(-9, 0, 0), 1))
	_put(P, _open_spot(at + Vector3(25, 0, 0), 1))
	P.lives = 1
	m.eliminate(P, null, "knocked out", true)
	Life.make_gone(m, P)
	var t := 0.0
	while t < 30.0 and Follow.watch(m) != null:
		m.step(Match.DT); t += Match.DT
	var got: bool = B.caught.any(func(r): return String(r.get("lost_from", "")) == P.pname)
	ok(got, "a bot goes and tames a rival's stray in the window (%.1f s, kind %s)" % [t, str(B.ai.get("goal_kind", ""))])
	ok(String(Follow.result(m).get("fate", "")) == "stolen", "the owner's results say stolen")

func _net() -> void:
	ok(Net.VERSION == "0.5.2", "Net.VERSION bumped for the follower sync (%s)" % Net.VERSION)
	var me0 := Net.me
	var host0 := Net.host
	Net.me = "abc"; Net.host = "hst"
	ok(Net.owner_of("Pabc|f1") == "abc" and Net.owns("Pabc|f2"), "a player's follower belongs to their game")
	ok(Net.owner_of("Pabck") == "abc" and Net.owner_of("Pabc") == "abc", "hunter and kin ids still resolve")
	ok(Net.owner_of("b3|f1") == "hst", "a bot's follower belongs to the host")
	Net.me = me0; Net.host = host0
	_fresh(2)
	var P := m.player
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	_tame(P, _wild(at + Vector3(1.0, 0, 0)))
	var f := Follow.of(P)
	var row: Array = m._ser(f)
	ok(row.size() >= 25 and int(row[19]) == 1 and m.KIN_STATES[int(row[8])] == "follow", "the snapshot carries role and state (%d fields)" % row.size())
	# a remote copy of it is built as that hunter's follower, not their own Boki
	var R: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var row2 := row.duplicate()
	row2[1] = R.nid + "|f9"; row2[10] = R.nid
	var own := R.kin
	var rk: Kin = m._net_make(row2)
	m._net_apply(rk, row2)
	ok(rk != null and rk.role == "follow" and R.follower == rk and R.kin == own, "a remote follower is built as a follower")
	# it turns stray from the snapshot
	row2[19] = 2; row2[8] = m.KIN_STATES.find("dazed"); row2[21] = 9.5; row2[22] = R.nid; row2[23] = R.pname; row2[24] = R.team
	m._net_apply(rk, row2)
	ok(rk.role == "stray" and rk.owner_h == null and absf(rk.steal_t - 9.5) < 0.01 and R.follower == null, "and becomes a stray with its window from the snapshot")

func _results_save() -> void:
	# a follower lost to a rival never reaches the roster
	Save.d = Save.fresh()
	var st := Save.new_kin("cindle", "Pip"); st["starter"] = true
	Save.d["roster"] = [st]; Save.d["active"] = st["uid"]
	var lost := Save.new_kin("puddlet", "", 5)
	var out := Game.apply_result({"extracted": false, "why": "knocked out", "tier": 2, "follower": {"rec": lost, "fate": "stolen", "holder": "Vexa"}, "kin_runs": []})
	ok(Save.d["roster"].size() == 1 and String((out.get("follower", {}) as Dictionary).get("holder", "")) == "Vexa", "a stolen follower doesn't come home")
	# one that went home on its own does, even though you went down
	var home := Save.new_kin("burrlet", "", 6)
	out = Game.apply_result({"extracted": false, "why": "knocked out", "tier": 2, "follower": {"rec": home, "fate": "home", "why": "waited out the rivals and went home"}, "kin_runs": []})
	ok(Save.d["roster"].size() == 2, "a follower nobody tamed goes home even if you went down")
	# an old save (no follower in the result) is untouched
	var n0: int = Save.d["roster"].size()
	Game.apply_result({"extracted": true, "tier": 0, "caught": [], "kin_runs": []})
	ok(Save.d["roster"].size() == n0, "a result without a follower changes nothing")
	# tutorial: nothing follows
	_fresh()
	m.opts["tutorial"] = true
	var P := m.player
	var at := _open_spot(P.pos, 3)
	_put(P, at)
	var w := _wild(at + Vector3(1.0, 0, 0))
	m.opts["tutorial"] = false
	m.opts["no_follow"] = true
	_tame(P, w)
	ok(Follow.of(P) == null and P.caught.size() == 1, "with following off (tutorial, loaner runs), a tame goes in the bag as before")
