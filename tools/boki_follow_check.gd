extends RefCounted
## --boki-follow-check: the Boki walks with you and takes orders (docs/decisions/0002). Prints PASS/FAIL lines.
##   1. default: out at your side, following, its carried bonuses off; a visible ring under it
##   2. the leash: stuck or far, it leaps back with an arc (no teleport); no way on foot is the same
##   3. traversal: a glide or a drop takes it onto you, and it hops off once you are steady
##   4. Sic and Call back (G tap)
##   5. the wheel: pick by direction, no slow-motion; Chase, Guard, Return, Follow
##   6. carried bonuses are on only while it is on you (Return), and the tooltip says what you lose
##   7. a big Boki on Return guards at your side, never under or in you (run, jump, turn, blocked flank,
##      glide); Sic = it charges
##   8. in a fight it never refuses an order; out of one, its personality still can
##   9. bots use the orders; the net carries the order
##  10. Return ordered in the air still ends up on you; a giant-form merge from Follow is ridden
##  11. A* is throttled: an unreachable goal does not search every step
##  12. an explicit Follow in a fight sticks (disengage): it stays at your side with a foe 8m off, and goes back in only when
##      you hit something, a foe hits it or you from within 4m, or you Sic/Chase; out of a fight nothing changes
## (Merge from Return is instant and from out is a leap: --boki-system-check)

var bad := 0
var m: Match
var main: Node
var tags_seen: Dictionary = {}
var keep: Array = []

func ok(cond: bool, what: String) -> void:
	print("BOKIFOLLOW %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func _on_hit(_a: Node, _t: Node, _amt: float, tags: Array) -> void:
	for t in tags:
		tags_seen[String(t)] = int(tags_seen.get(String(t), 0)) + 1

func _fresh(species := "cindle") -> Match:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "demo_kin": species, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var W = m.world
	var hx := int(floor(P.pos.x)); var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-20, 21):
		for dx in range(-30, 41):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			W.stairs.erase(i); W.walls.erase(i); W.props.erase(i); W.bush.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	P.kin.teleport(P.pos + Vector3(1.0, 0, 0.7))
	for t in ["bravery", "loyalty", "temper", "curiosity"]:
		P.kin.traits[t] = 0.5
	P.kin.trust = 60.0
	P.slot_lv["ult"] = 1
	for h in m.hunters:
		if h.team != P.team:
			h.ctrl = "idle"
			h.teleport(Vector3(P.pos.x + 38.0, P.pos.y, P.pos.z + 18.0))
	keep = []
	for i in 40:
		_clear_mobs()
		m.step(Match.DT)
	tags_seen = {}
	return m

func _clear_mobs() -> void:
	for mb in m.mobs.duplicate():
		if not keep.has(mb):
			m.mobs.erase(mb)
			mb.queue_free()

func run_for(secs: float, each := Callable()) -> void:
	var t := 0.0
	while t < secs:
		if each.is_valid(): each.call()
		_clear_mobs()
		m.step(Match.DT); t += Match.DT

func aim_at(P: Hunter, p: Vector3) -> void:
	P.inp["aim"] = p + Vector3(0, 0.9, 0); P.inp["aim_y"] = p.y

func mob_at(kind: String, at: Vector3) -> Mob:
	var mb := m.spawn_mob(kind, at)
	mb.teleport(at)
	keep.append(mb)
	return mb

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	CombatBus.hit_landed.connect(_on_hit)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bokifollow-only="): only = a.substr(18)
	var parts := ["default", "leash", "traverse", "sic_call", "wheel", "carried", "guard_side", "no_refusal", "bots", "net",
		"air_orders", "path_cost", "disengage"]
	for part in parts:
		if only == "" or only.split(",").has(part):
			call("_" + part)
	CombatBus.hit_landed.disconnect(_on_hit)
	print("BOKIFOLLOW DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

# ------------------------------------------------------------------ 1. default
func _default() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	ok(k.state == "active" and k.cmd == "follow", "a new match: the Boki is out and following (state %s, order %s)" % [k.state, k.cmd])
	ok(k.flat_dist(P) < 4.0, "...at your side (%.1fm)" % k.flat_dist(P))
	ok(not P.kin_carry_on(), "...and its carried bonuses are off while it is out")
	var path := KinPath.find(m.world, P.pos, P.pos + Vector3(12.0, 0, 5.0))
	ok(path.size() >= 12 and (path[path.size() - 1] as Vector2).distance_to(Vector2(P.pos.x + 12.0, P.pos.z + 5.0)) < 1.5, "A* finds a path on the tile grid (%d tiles)" % path.size())
	var st := {"worst": 0.0}
	P.inp["move"] = Vector2(1, 0)
	run_for(4.0, func(): st["worst"] = maxf(float(st["worst"]), k.flat_dist(P)))
	P.inp["move"] = Vector2.ZERO
	run_for(1.5)
	ok(float(st["worst"]) > 0.5 and float(st["worst"]) < 7.0 and k.flat_dist(P) < 3.5 and k.state == "active", "you walk off: it keeps pace and settles at your side again (worst %.1fm, now %.1fm)" % [float(st["worst"]), k.flat_dist(P)])
	k.render(0.016, 1.0)
	ok(k.ring != null and k.ring.visible, "a team-coloured ring sits under every out Boki")

# ------------------------------------------------------------------ 2. the leash
func _leash() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	# far beyond the leash: a leap with an arc, never an invisible jump
	k.teleport(P.pos + Vector3(30.0, 0, 0))
	var s := {"step": 0.0, "y": 0.0, "leap": false, "last": k.pos}      # (a lambda copies plain locals, so the state lives in a dictionary)
	run_for(2.5, func():
		s["step"] = maxf(float(s["step"]), k.pos.distance_to(s["last"]))
		s["y"] = maxf(float(s["y"]), k.pos.y - P.pos.y)
		s["leap"] = bool(s["leap"]) or k.state == "flying_home"
		s["last"] = k.pos)
	ok(bool(s["leap"]) and k.state == "active" and k.flat_dist(P) < 4.0, "beyond the leash it leaps back to your side (state %s, %.1fm)" % [k.state, k.flat_dist(P)])
	ok(float(s["y"]) > 0.4 and float(s["step"]) < 2.0, "...in a visible arc, not a teleport (peak %.1fm up, biggest step %.2fm)" % [float(s["y"]), float(s["step"])])
	# stuck in a pocket of blocks
	_fresh()
	P = m.player
	k = P.kin
	var W = m.world
	var c := Vector2i(int(floor(P.pos.x)) + 8, int(floor(P.pos.z)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				W.kind[W.idx(c.x + dx, c.y + dz)] = World.T_BLOCK
	k.teleport(Vector3(c.x + 0.5, P.pos.y, c.y + 0.5))
	var t_hop := -1.0
	var t := 0.0
	while t < 3.5 and t_hop < 0.0:
		_clear_mobs()
		m.step(Match.DT); t += Match.DT
		if k.state == "flying_home":
			t_hop = t
	ok(t_hop > 0.5 and t_hop < 2.6, "boxed in, it hops out after being stuck (about 1s: %.2fs)" % t_hop)
	run_for(1.2)
	ok(k.state == "active" and k.flat_dist(P) < 4.5, "...to your side (%.1fm)" % k.flat_dist(P))
	# a wall between you: it walks round it (A*), no hop needed
	_fresh()
	P = m.player
	k = P.kin
	W = m.world
	var wx := int(floor(P.pos.x)) + 3
	var wz := int(floor(P.pos.z))
	for dz in range(-4, 5):
		W.kind[W.idx(wx, wz + dz)] = World.T_BLOCK
	k.teleport(Vector3(wx + 3.5, P.pos.y, P.pos.z + 0.5))
	var hop := {"v": false}
	run_for(4.0, func(): hop["v"] = bool(hop["v"]) or k.state == "flying_home")
	ok(not bool(hop["v"]) and k.flat_dist(P) < 4.5, "behind a wall it walks round (%.1fm, hop %s)" % [k.flat_dist(P), hop["v"]])

# ------------------------------------------------------------------ 3. glide and drop
func _traverse() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	P.gliding = true
	for i in 90:
		k.sim(Match.DT)
	ok(k.state == "shoulder" and k.cmd == "follow", "you glide: it hops onto you (state %s)" % k.state)
	ok(not P.kin_carry_on(), "...carried over the glide, but its bonuses stay off (not an order)")
	P.gliding = false
	P.grounded = true
	for i in 90:
		k.sim(Match.DT)
	ok(k.state == "active" and k.flat_dist(P) < 3.5, "you land: it hops off to your side (state %s, %.1fm)" % [k.state, k.flat_dist(P)])
	# a drop off a ledge
	var W = m.world
	var lx := int(floor(P.pos.x)) + 6
	var lz := int(floor(P.pos.z))
	var lv: int = int(W.level[W.idx(lx, lz)])
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			W.level[W.idx(lx + dx, lz + dz)] = lv - 3
	var low := Vector3(lx + 0.5, (lv - 3) * World.LEVEL + 1.5, lz + 0.5)
	P.teleport(low)
	P.grounded = false
	P.air_t = 1.0
	ok(KinFollow.need_carry(k), "you drop off a ledge it cannot walk down: it will hop on")
	P.grounded = true
	P.air_t = 0.0
	ok(not KinFollow.need_carry(k), "...and not once you are standing again")

# ------------------------------------------------------------------ 4. Sic and Call back
func _sic_call() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var land := P.pos + Vector3(6.0, 0, 0)
	var mb := mob_at("skitter", land + Vector3(0, 0, 1.3))
	var stun := {"v": false}
	aim_at(P, land)
	KinCommand.tap(P)
	ok(k.state == "flying", "G tap with the Boki beside you: Sic, it leaps at the cursor (state %s)" % k.state)
	run_for(1.2, func(): stun["v"] = bool(stun["v"]) or (is_instance_valid(mb) and mb.stun_t > 0.0))
	ok(int(tags_seen.get("land", 0)) >= 1 and bool(stun["v"]), "...and its landing staggers what it lands on (land hits %d)" % int(tags_seen.get("land", 0)))
	ok(k.cmd == "follow", "...and it stays under the Follow order (%s)" % k.cmd)
	# close by but sent out or fighting: a second tap brings it back (G toggles)
	k.teleport(P.pos + Vector3(3.0, 0, 0))
	k.state = "active"
	k.fly = {}
	k.disengaged = false
	k.target = mob_at("skitter", P.pos + Vector3(4.0, 0, 0))
	KinCommand.tap(P)
	ok(k.state == "flying_home", "G tap while it fights close by: Call back, not another Sic (state %s)" % k.state)
	# away: Call back
	_fresh()
	P = m.player
	k = P.kin
	k.cmd = "guard"; k.hold_at = P.pos + Vector3(12.0, 0, 0)
	k.teleport(k.hold_at)
	var skit := mob_at("skitter", P.pos + Vector3(6.0, 0, 0.2))
	var hp0 := skit.hp
	KinCommand.tap(P)
	ok(k.state == "flying_home" and k.fly.get("dest", "") == "side", "G tap while it is away: Call back, a leap to your side (state %s)" % k.state)
	var land_d := {"d": -1.0}
	run_for(1.5, func():
		if float(land_d["d"]) < 0.0 and k.state == "active": land_d["d"] = k.flat_dist(P))
	ok(float(land_d["d"]) >= 0.0 and float(land_d["d"]) < 3.5 and k.cmd == "follow", "...it lands beside you and follows again (%.1fm, %s)" % [float(land_d["d"]), k.cmd])
	ok(int(tags_seen.get("recall", 0)) >= 1 and (not is_instance_valid(skit) or skit.hp < hp0), "...hitting what was on its path (recall hits %d)" % int(tags_seen.get("recall", 0)))
	k.teleport(P.pos + Vector3(40.0, 0, 0)); k.state = "active"; k.fly = {}
	KinCommand.call_back(P)
	ok(k.state == "active", "...but not from beyond the recall range")

# ------------------------------------------------------------------ 5. the wheel
func _wheel() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	ok(KinWheel.pick(Vector2(0, -80)) == 0 and KinWheel.pick(Vector2(80, 0)) == 1 and KinWheel.pick(Vector2(0, 80)) == 2 and KinWheel.pick(Vector2(-80, 0)) == 3 and KinWheel.pick(Vector2(5, 5)) == -1, "a flick up/right/down/left picks Chase/Guard/Return/Follow; a small move picks nothing")
	var ts := Engine.time_scale
	KinWheel.open(P, Vector2(300, 300))
	KinWheel.update(P, Vector2(300, 220), 0.05)
	ok(KinWheel.is_open(P) and Engine.time_scale == ts and not m.paused, "the wheel is open and the game keeps running (time scale %.1f)" % Engine.time_scale)
	ok(KinWheel.close(P) == "chase" and not KinWheel.is_open(P), "releasing picks the segment under the flick")
	# chase
	var mb := mob_at("skitter", P.pos + Vector3(7.0, 0, 0))
	aim_at(P, mb.pos)
	ok(KinCommand.order(P, "chase") and k.cmd == "chase" and k.chase_target == mb, "Chase sticks to the foe under the cursor")
	run_for(3.0)
	ok(not is_instance_valid(mb) or mb.hp < mb.max_hp or k.flat_dist(mb) < 2.5, "...and it goes for it")
	# guard
	KinCommand.order(P, "follow")
	run_for(1.0)
	ok(KinCommand.order(P, "guard") and k.cmd == "guard" and k.hold_at != Vector3.INF, "Guard holds the spot")
	# return
	ok(KinCommand.order(P, "return"), "Return is accepted")
	run_for(1.8)
	ok(k.state == "shoulder" and k.cmd == "return" and k.carried(), "...it goes back onto you (state %s)" % k.state)
	ok(not k.hittable(), "...safe from damage while it is on you")
	# follow
	ok(KinCommand.order(P, "follow"), "Follow is accepted")
	run_for(1.3)
	ok(k.state == "active" and k.cmd == "follow" and k.flat_dist(P) < 3.5, "...it hops off to your side (state %s, %.1fm)" % [k.state, k.flat_dist(P)])
	# no foe: Chase does nothing
	var P2 := m.player
	for f in m.foes_of(P2.team):
		if f is Hunter: f.teleport(P2.pos + Vector3(200.0, 0, 0))
	for mb2 in m.mobs.duplicate():
		mb2.queue_free(); m.mobs.erase(mb2)
	keep = []
	ok(not KinCommand.order(P, "chase") and k.cmd == "follow", "Chase with nothing to chase changes nothing")

# ------------------------------------------------------------------ 6. carried bonuses only on you
func _carried() -> void:
	_fresh("puddlet")
	var P := m.player
	var k: Kin = P.kin
	var stat := String(k.ks.carry_passives[0]["stat"]) if k.ks and not k.ks.carry_passives.is_empty() else ""
	ok(stat != "", "setup: this Boki's carry gives a bonus (%s)" % stat)
	P.kin_bonus = {}
	P._refresh_kin_stats()
	ok(P.owner_stat(stat) == 0.0, "following: no carried bonus (%s = %.2f)" % [stat, P.owner_stat(stat)])
	KinCommand.order(P, "return")
	run_for(1.8)
	P._refresh_kin_stats()
	ok(k.carried() and P.owner_stat(stat) > 0.0, "returned: the bonus is on (%s = %.2f)" % [stat, P.owner_stat(stat)])
	KinCommand.order(P, "follow")
	run_for(1.5)
	P._refresh_kin_stats()
	ok(P.owner_stat(stat) == 0.0, "out again: it is off")
	var off := KinText.carry_off(k.ks)
	ok(off.begins_with("Off you: no "), "the tooltip lists what you lose (\"%s\")" % off)
	# on_shot riders are carried-only too
	_fresh("cindle")
	P = m.player
	k = P.kin
	ok(not k.ks.carry_on_shot.is_empty() and not P.kin_carry_on(), "its shot rider is off while it is out")
	k.stow()
	ok(P.kin_carry_on(), "...and on while it is on you")

# ------------------------------------------------------------------ 7. a big Boki guards at your side
## Owner 11-08: on the Return order a Boki too big for your shoulder is never under or in you. Every step
## of a run, a jump, a turn and a glide: on its flank it stays at least guard_min_m from you with its feet
## never below yours; off its flank it is up on your back. A blocked flank sends it to the other one.
func _guard_watch(P: Hunter, k: Kin, st: Dictionary) -> void:
	var near := KinFollow._r("guard_min_m")
	if k.state != "shoulder":
		return
	st["n"] += 1
	if k.beside:
		st["side"] += 1
		st["min"] = minf(st["min"], P.flat_dist(k))
		if P.flat_dist(k) < near - 0.01 or k.pos.y < P.pos.y - 0.01:
			st["bad"] += 1
	elif k.seen_pos().y < P.pos.y + 1.0:
		st["bad"] += 1

func _guard_run(P: Hunter, dir: Vector2, secs: float, watch: Callable) -> void:
	run_for(secs, func() -> void:
		P.inp["move"] = dir
		watch.call())

func _guard_side() -> void:
	_fresh("pebbit")
	var P := m.player
	var k: Kin = P.kin
	ok(k.big() and not P.mounted(), "setup: a big Boki, following")
	KinCommand.order(P, "return")
	run_for(1.8)
	var guarding := k.state == "shoulder" and k.beside and not P.mounted() and P.kin_carry_on()
	ok(guarding, "Return: it guards at your side, its carried bonuses on (state %s, %.1f m)" % [k.state, P.flat_dist(k)])
	var st := {"n": 0, "side": 0, "bad": 0, "min": 99.0}
	var watch := func() -> void: _guard_watch(P, k, st)
	_guard_run(P, Vector2(1, 0), 1.2, watch)
	var side0 := k.guard_side
	P.do_jump()
	_guard_run(P, Vector2(1, 0), 1.0, watch)
	_guard_run(P, Vector2(0, 1), 1.0, watch)
	_guard_run(P, Vector2(-1, 0), 0.6, watch)
	var seen := "%d of %d steps beside you, closest %.2f m, %d bad" % [st["side"], st["n"], st["min"], st["bad"]]
	ok(st["bad"] == 0 and st["side"] >= st["n"] - 6, "running, jumping, turning: never under or in you (%s)" % seen)
	ok(k.guard_side == side0, "it keeps its flank while you move")
	P.inp["move"] = Vector2.ZERO
	run_for(0.4)
	var fwd := Vector2(-sin(P.face), -cos(P.face))
	var flank := Vector2(-fwd.y, fwd.x) * k.guard_side * KinFollow._r("guard_side_m")
	var W: World = m.world
	var bi: int = W.idx(int(floor(P.pos.x + flank.x)), int(floor(P.pos.z + flank.y)))
	W.kind[bi] = World.T_BLOCK
	run_for(0.4, watch)
	ok(k.beside and k.guard_side == -side0, "its flank blocked: it takes the other one (side %d)" % int(k.guard_side))
	W.kind[bi] = World.T_GROUND
	P.gliding = true
	for i in 20:
		k.sim(Match.DT)
		watch.call()
	var on_back := not k.beside and k.seen_pos().y > P.pos.y + 1.0
	ok(on_back and st["bad"] == 0, "gliding: it curls up on your back, above your feet (%d bad)" % st["bad"])
	P.gliding = false
	_fresh("zapple")
	KinCommand.order(m.player, "return")
	run_for(1.8)
	var small: Kin = m.player.kin
	ok(not small.big() and not small.beside and small.state == "shoulder", "a small Boki rides your shoulder")
	_fresh("pebbit")
	P = m.player
	k = P.kin
	KinCommand.order(P, "return")
	run_for(1.8)
	var land := P.pos + Vector3(6.0, 0, 0)
	var rad: float = float(KinCommand.rules()["land_stagger"]["radius"])
	var mb := mob_at("skitter", land)
	mb.teleport(land + Vector3(rad + mb.r + 0.3, 0, 0))     # outside a plain landing's reach, inside a charge's
	aim_at(P, land)
	KinCommand.tap(P)
	ok(k.state == "flying" and k.fly.get("charge", false), "Sic: it leaves your side and charges (state %s)" % k.state)
	run_for(1.2)
	ok(int(tags_seen.get("land", 0)) >= 1, "...its charge lands harder than a throw: it reached a foe just past a plain landing's reach (hits %d)" % int(tags_seen.get("land", 0)))

# ------------------------------------------------------------------ 8. no refusal in a fight
func _no_refusal() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	k.trust = 5.0
	for t in ["bravery", "loyalty"]:
		k.traits[t] = 0.0
	k.hp = k.max_hp * 0.1
	var spot := P.pos + Vector3(6.0, 0, 0)
	# out of a fight: its personality still counts
	ok(k.consider_throw(spot) == "refuse", "outside a fight a hurt, timid Boki can still say no")
	# in a fight: never
	for i in 3:
		mob_at("brute", spot + Vector3(0.5 * i, 0, 0.4))
	ok(KinFollow.in_combat(k, spot) and k.consider_throw(spot) == "refuse", "setup: the same order into a fight it dislikes")
	aim_at(P, spot)
	KinCommand.tap(P)
	ok(k.hesitate_t > 0.0 and k.hesitate_t <= 0.3 + 0.001 and not k.events.any(func(e): return e["kind"] == "refused"), "in a fight it hesitates (%.2fs) instead of refusing" % k.hesitate_t)
	var went := {"v": false}
	run_for(0.8, func(): went["v"] = bool(went["v"]) or k.state == "flying")
	ok(bool(went["v"]), "...and then goes")

# ------------------------------------------------------------------ 9. bots
func _bots() -> void:
	_fresh()
	var P := m.player
	var R: Hunter = null
	for h in m.hunters:
		if h.team != P.team:
			R = h
	ok(R != null and R.kin != null, "setup: a bot with a Boki")
	if R == null or R.kin == null:
		return
	var k: Kin = R.kin
	R.ai["throw_cd"] = 0.0
	R.teleport(P.pos + Vector3(7.0, 0, 0))
	k.teleport(R.pos + Vector3(1.0, 0, 0.7)); k.state = "active"; k.fly = {}
	R.hp = R.max_hp * 0.2
	BotKin.fight(m, R, P, 7.0, 1.0)
	ok(k.cmd == "return" or k.state == "flying_home", "a hurt bot sends its Boki back onto it (Return)")
	run_for(1.0, func(): R.hp = maxf(R.hp, R.max_hp * 0.2))      # (hurt, not killed: the player's Boki is next to it)
	ok(k.state == "shoulder" and k.cmd == "return", "...and it is on the bot (state %s)" % k.state)
	R.hp = R.max_hp
	R.ai["throw_cd"] = 0.0
	BotKin.upkeep(R)
	ok(k.cmd == "follow", "healthy again, the bot brings it back out")
	run_for(1.0)
	R.ai["throw_cd"] = 0.0
	k.teleport(R.pos + Vector3(1.0, 0, 0.7)); k.state = "active"; k.fly = {}; k.throw_cd = 0.0
	BotKin.fight(m, R, P, 7.0, 1.0)
	ok(k.state == "flying" or k.hesitate_t > 0.0, "at a rival it Sics (state %s)" % k.state)
	R.ult = 1.0; R.slot_lv["ult"] = 1
	k.teleport(R.pos + Vector3(20.0, 0, 0)); k.state = "active"; k.fly = {}
	ok(KinMerge.plan(R) == "leap", "setup: the Boki is away but in leap range")
	BotKin.merge(R, P, 5.0)
	ok(R.inp.get("ult", false), "...so the bot goes for the merge (it leaps back and merges)")

# ------------------------------------------------------------------ 10. net
func _net() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var snap: Array = []
	snap.resize(KinNet.KIN_AT)
	var seen := {}
	for c in KinFollow.CMD_IDS:
		k.cmd = c
		var arr := snap + KinNet.kin_extra(k)
		k.cmd = "follow" if c != "follow" else "guard"
		KinNet.apply_kin(k, arr)
		seen[c] = k.cmd
	ok(seen == {"guard": "guard", "follow": "follow", "chase": "chase", "return": "return"}, "the order rides the kin snapshot and comes back out %s" % [seen])
	ok(Net.VERSION.naturalnocasecmp_to("0.11.0") >= 0, "Net.VERSION is at least 0.11.0 (merge forms moved it past 0.10.0) (%s)" % Net.VERSION)

# ------------------------------------------------------------------ 10. orders in the air, the giant merge
func _air_orders() -> void:
	# Return while it is mid-Sic: it lands, then goes up onto you
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	aim_at(P, P.pos + Vector3(6.0, 0, 0))
	KinCommand.tap(P)
	ok(k.state == "flying", "setup: sent out (state %s)" % k.state)
	ok(KinCommand.order(P, "return"), "Return is accepted mid-flight")
	run_for(2.5)
	ok(k.state == "shoulder" and k.cmd == "return" and k.carried(), "...it lands and goes onto you (state %s, order %s)" % [k.state, k.cmd])
	# Return while it is on a Call back leap
	_fresh()
	P = m.player
	k = P.kin
	k.cmd = "guard"; k.hold_at = P.pos + Vector3(12.0, 0, 0)
	k.teleport(k.hold_at)
	KinCommand.tap(P)
	ok(k.state == "flying_home", "setup: on a Call back leap")
	KinCommand.order(P, "return")
	run_for(2.0)
	ok(k.state == "shoulder" and k.cmd == "return", "Return on a leap carries on up onto you (state %s)" % k.state)
	# a giant-form stat merge started from Follow is ridden (Cairnback has no form of its own yet; Pebbit's Heavy Star hides the Boki inside you)
	_fresh("cairnback")
	P = m.player
	k = P.kin
	ok(k.carry_style() == "mount" and k.cmd == "follow" and k.state == "active", "setup: a mount, following")
	P.ult = 1.0; P.slot_lv["ult"] = 1
	ok(KinMerge.press(P), "R with the Boki out starts the merge")
	run_for(1.5)
	ok(not P.merge_st.is_empty() and bool(P.merge_st.get("giant", false)) and k.cmd == "return" and P.mounted(), "...the giant form is ridden (order %s, mounted %s)" % [k.cmd, P.mounted()])

# ------------------------------------------------------------------ 11. what the path search costs
func _path_cost() -> void:
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var W = m.world
	# a goal sealed inside a ring of blocks: the straight line is blocked and no way on foot exists
	var c := Vector2i(int(floor(P.pos.x)) + 10, int(floor(P.pos.z)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				W.kind[W.idx(c.x + dx, c.y + dz)] = World.T_BLOCK
	var goal := Vector3(c.x + 0.5, P.pos.y, c.y + 0.5)
	k.path_searches = 0
	k.path_t = 0.0
	for i in 120:                                     # 2 seconds of steering
		KinFollow.steer(k, goal, Match.DT, 5.0, false)
	ok(k.path_searches >= 1 and k.path_searches <= 2, "an unreachable goal searches %d times in 2s (a failed search backs off), not every step" % k.path_searches)
	# a goal that keeps moving: still a search per timer, not one per tile
	k.path_searches = 0
	k.path_t = 0.0
	for i in 120:
		var g := Vector3(c.x + 0.5, P.pos.y, c.y + 0.5 + float(i) * 0.1)      # (sliding 12 tiles along the wall)
		KinFollow.steer(k, g, Match.DT, 5.0, false)
	ok(k.path_searches <= 10, "a goal sliding 12 tiles in 2s costs %d searches (about one per 0.2s at most, not one per tile)" % k.path_searches)
	# the heap returns the same path length as before for an open trip
	# (west unless the spawn is near the west edge: the cleared strip runs 30 tiles west, 40 east)
	var across := -12.0 if P.pos.x > 14.0 else 12.0
	var path := KinPath.find(W, P.pos, P.pos + Vector3(across, 0, 5.0))
	ok(path.size() == 12, "the heap-based A* still finds the shortest path (%d tiles)" % path.size())

# ------------------------------------------------------------------ 12. Follow sticks in a fight
## A brute held 8m from you (it is pinned each step so only the Boki's choices matter) and the Boki beside it.
func _hold_brute(P: Hunter, k: Kin) -> Mob:
	var mb := mob_at("brute", P.pos + Vector3(8.0, 0, 0))
	k.teleport(mb.pos - Vector3(1.8, 0, 0))
	return mb

func _pin(mb: Mob, at: Vector3) -> void:
	mb.teleport(at)
	mb.vel = Vector3.ZERO

func _disengage() -> void:
	# control: with no order it fights what is near (the behaviour Follow used to have in a fight)
	_fresh()
	var P := m.player
	var k: Kin = P.kin
	var mb := _hold_brute(P, k)
	var at := mb.pos
	run_for(2.0, func(): _pin(mb, at))
	ok(not k.disengaged and (mb.hp < mb.max_hp or k.flat_dist(mb) < 3.0), "control: with no order it goes for the foe (foe %.0f/%.0f hp, %.1fm from it)" % [mb.hp, mb.max_hp, k.flat_dist(mb)])
	# the order, mid-fight: back to your side and it stays for 5s with the foe 8m away
	_fresh()
	P = m.player
	k = P.kin
	mb = _hold_brute(P, k)
	at = mb.pos
	aim_at(P, mb.pos)
	ok(KinCommand.order(P, "follow") and k.disengaged and KinFollow.is_disengaged(k), "Follow in a fight disengages it")
	run_for(2.0, func(): _pin(mb, at))
	var st := {"worst": 0.0}
	run_for(5.0, func():
		_pin(mb, at)
		st["worst"] = maxf(float(st["worst"]), k.flat_dist(P)))
	ok(float(st["worst"]) < 3.0 and k.state == "active" and k.target == null and mb.hp >= mb.max_hp, "...and for 5s it stays within 3m of you with the foe 8m away (worst %.1fm, foe hp %.0f/%.0f)" % [float(st["worst"]), mb.hp, mb.max_hp])
	# (a) you hit the foe: it joins you
	mb.hurt(3.0, P, {"src": "primary"})
	ok(not k.disengaged, "(a) you deal damage: it is free to fight again")
	run_for(2.5, func(): _pin(mb, at))
	ok(mb.hp < mb.max_hp - 3.0 or k.flat_dist(mb) < 3.0, "...and it joins your target (foe %.0f/%.0f hp, %.1fm from it)" % [mb.hp, mb.max_hp, k.flat_dist(mb)])
	# (b) a hit up close, not one from afar
	_fresh()
	P = m.player
	k = P.kin
	mb = _hold_brute(P, k)
	KinCommand.order(P, "follow")
	var far := mob_at("skitter", P.pos + Vector3(-8.0, 0, 0))
	k.hurt(2.0, far, {"src": "mob"})
	P.hurt(2.0, far, {"src": "mob"})
	ok(k.disengaged, "(b) a hit on it or you from 8m (ranged) does not end it")
	mb.teleport(k.pos + Vector3(2.5, 0, 0))
	k.hurt(2.0, mb, {"src": "mob"})
	ok(not k.disengaged, "(b) a foe hits it from 2.5m: it fights back")
	k.disengaged = true
	mb.teleport(P.pos + Vector3(3.0, 0, 0))
	P.hurt(2.0, mb, {"src": "mob"})
	ok(not k.disengaged, "(b) a foe hits you from 3m: it fights back")
	# (c) Sic and Chase
	k.disengaged = true
	aim_at(P, mb.pos)
	KinFollow.sic(k, mb.pos)
	ok(not k.disengaged, "(c) Sic ends it")
	k.disengaged = true
	k.state = "active"; k.fly = {}
	ok(KinCommand.order(P, "chase") and not k.disengaged, "(c) Chase ends it")
	# Call back in a fight is the same order; out of a fight nothing changes
	_fresh()
	P = m.player
	k = P.kin
	mb = _hold_brute(P, k)
	k.cmd = "guard"; k.hold_at = k.pos
	KinCommand.call_back(P)
	ok(k.disengaged, "Call back in a fight disengages it too")
	_fresh()
	P = m.player
	k = P.kin
	KinCommand.order(P, "follow")
	ok(not k.disengaged, "out of a fight a plain Follow changes nothing")
