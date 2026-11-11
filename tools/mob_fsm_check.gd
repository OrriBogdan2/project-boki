extends RefCounted
## --mob-fsm-check: the monster and lair boss machines (Mob.S, Mob.TABLE, Boss.BOSS_TABLE; docs/decisions/0061).
## Tables: every edge names another state, every state is reachable from IDLE and can leave, each has a name and a
## snapshot look. Scripted fights, each ending with refused == 0 (a refusal in a scripted run is a bug in the table
## or the code): a Skitter sees the Hunter, chases, holds its wind-up for its data time with the tell up and only
## then lunges (no damage before the blow), recovers and chases again; a stun in its wind-up cuts it (the tell is
## out on the next step, STUNNED for CUT_HOLD at the least) and a stunned chaser can't start one; a Brute's stagger
## holds it STUNNED for the stagger; a camp monster pulled off its leash RETURNs and is IDLE once home; a proxy
## shows the host's state. A boss wakes (NOTICE, CHASE), winds up, strikes and recovers on its attack's clock; a
## stun in its wind-up cuts the attack (tells out, atk ""); laid down by Lairs it is IDLE (dormant) again.

const DT := Match.DT
const STAGGER_S := 3.0       # s a Brute's stagger lasts (Mob._stagger)
var fails := 0
var m: Match
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("MOBFSM %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: fails += 1

func run(main: Node) -> void:
	_tables()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)
	await main.get_tree().process_frame
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle" if h != P else "local"
		h.inp["move"] = Vector2.ZERO
	for k in [P.kin, P.kin2]:
		if k != null:
			_drop(k)
	for mb in m.mobs:
		if not (mb is Boss):
			_drop(mb)
	P.teleport(m.world.free_spot_near(P.pos, [], 1.0, 0.45, 20.0))
	_skitter()
	_brute()
	_return_home()
	_proxy()
	_boss()
	print("MOBFSM DONE, failures: %d" % fails)
	main.get_tree().quit(1 if fails > 0 else 0)

func _tables() -> void:
	for t in [Mob.TABLE, Boss.BOSS_TABLE]:
		var bad: Array = []
		for from in t:
			if (t[from] as Array).is_empty():
				bad.append("%s: no way out" % Mob.NAMES[from])
			for to in t[from]:
				if to == from or to < 0 or to >= Mob.NAMES.size():
					bad.append("%s>%s" % [Mob.NAMES[from], to])
		var seen := {Mob.S.IDLE: true}
		var todo: Array = [Mob.S.IDLE]
		while not todo.is_empty():
			for to in t.get(todo.pop_back(), []):
				if not seen.has(to):
					seen[to] = true
					todo.append(to)
		var which := "Mob" if t == Mob.TABLE else "Boss"
		ok(bad.is_empty() and t.size() == Mob.S.size() and seen.size() == Mob.S.size(),
			"%s table: %d states, %d reachable from idle, bad edges %s" % [which, t.size(), seen.size(), str(bad)])
	var looks_ok := Array(Mob.LOOKS).all(func(l): return Match.MOB_STATES.has(l))
	ok(Mob.NAMES.size() == Mob.S.size() and Mob.LOOKS.size() == Mob.S.size() and looks_ok,
		"every state has a name and a look the snapshot already carries %s" % str(Mob.LOOKS))

# ------------------------------------------------------------------ helpers
var hurt_at := -1.0      # match time of the first hit on the Hunter since it was last reset

## One step; the Hunter stays at full health (the first hit's time goes in hurt_at).
func _step() -> void:
	var h0 := P.hp + P.armor
	m.step(DT)
	if P.hp + P.armor < h0 - 0.01 and hurt_at < 0.0:
		hurt_at = m.time
	P.hp = P.max_hp
	P.armor = P.max_armor

## Steps until `cond` holds (true) or `secs` pass (false); `each` runs after every step.
func _until(cond: Callable, secs: float, each := Callable()) -> bool:
	var t := 0.0
	while t < secs and not cond.call():
		_step()
		t += DT
		if each.is_valid(): each.call()
	return cond.call()

func _spawn(kind: String, near: Vector3, dist: float) -> Mob:
	var at := m.world.free_spot_near(near + Vector3(dist, 0, 0), [near], 1.0, 0.6, 8.0)
	var mb := m.spawn_mob(kind, Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	mb.teleport(mb.pos)
	return mb

func _drop(e: Ent) -> void:
	e.dead = true
	e.visible = false

## The machine's transitions, oldest first: [time on its clock, "from>to"].
func _moves(f: Fsm) -> Array:
	var out: Array = []
	for line in f.history:
		var parts := line.strip_edges().split(" ", false)
		out.append([float(parts[0]), parts[1]])
	return out

## True when `want` ("from>to" each) shows up in order among the machine's transitions.
func _in_order(f: Fsm, want: Array) -> bool:
	var i := 0
	for mv in _moves(f):
		if i < want.size() and mv[1] == want[i]: i += 1
	return i == want.size()

## Seconds from the last `a` transition to the first `b` after it (on the machine's clock), -1 when missing.
func _span(f: Fsm, a: String, b: String) -> float:
	var t0 := -1.0
	var out := -1.0
	for mv in _moves(f):
		if mv[1] == a:
			t0 = mv[0]
			out = -1.0
		elif mv[1] == b and t0 >= 0.0 and out < 0.0:
			out = mv[0] - t0
	return out

func _near(a: float, b: float) -> bool:
	return absf(a - b) <= DT * 1.5

# ------------------------------------------------------------------ monsters
func _skitter() -> void:
	var sk := _spawn("skitter", P.pos, 3.0)
	sk.cd = 0.0
	var tell := [true]
	var struck := [-1.0]
	hurt_at = -1.0
	var watch := func():
		var winding: bool = sk.fsm.is_in(Mob.S.WINDUP)
		if winding and (sk.tele == null or (hurt_at >= 0.0 and struck[0] < 0.0)): tell[0] = false
		if sk.fsm.is_in(Mob.S.ATTACK) and struck[0] < 0.0: struck[0] = m.time
	var lunged := _until(func(): return sk.fsm.is_in(Mob.S.CHASE) and struck[0] >= 0.0, 8.0, watch)
	var want := ["idle>notice", "notice>chase", "chase>windup", "windup>attack", "attack>recover", "recover>chase"]
	ok(lunged and _in_order(sk.fsm, want), "a Skitter: %s (%s)" % [" ".join(want), sk.readout()])
	var wind := _span(sk.fsm, "chase>windup", "windup>attack")
	ok(_near(wind, float(sk.md["windup"])), "its wind-up ran %.2fs, its data says %.2fs" % [wind, sk.md["windup"]])
	ok(tell[0] and hurt_at > 0.0 and hurt_at >= struck[0] - 0.001,
		"the tell was up the whole wind-up, the first hit came with the blow (%.2f, %.2f)" % [hurt_at, struck[0]])
	var rec := _span(sk.fsm, "attack>recover", "recover>chase")
	ok(_near(rec, Mob.LUNGE_REC), "it recovered %.2fs after the lunge (LUNGE_REC %.2f)" % [rec, Mob.LUNGE_REC])
	# a short stun in the wind-up: cut on the next step, the tell gone, STUNNED for CUT_HOLD
	sk.cd = 0.0
	ok(_until(func(): return sk.fsm.is_in(Mob.S.WINDUP), 4.0), "it winds up again")
	sk.stun_t = 0.2
	_step()
	ok(sk.fsm.is_in(Mob.S.STUNNED) and sk.tele == null and sk.st == "recover",
		"a stun in the wind-up cuts it: %s, tell %s, shows as %s" % [sk.fsm.state_name(), str(sk.tele), sk.st])
	var calm := [true]
	var no_wind := func(): if sk.fsm.is_in(Mob.S.WINDUP) and sk.stun_t > 0.0: calm[0] = false
	_until(func(): return not sk.fsm.is_in(Mob.S.STUNNED), 2.0, no_wind)
	var held := _span(sk.fsm, "windup>stunned", "stunned>chase")
	ok(_near(held, Mob.CUT_HOLD), "a 0.2s stun cutting a wind-up holds it %.2fs (CUT_HOLD %.2f)" % [held, Mob.CUT_HOLD])
	# a long stun while it chases: no wind-up may start until the stun is over
	_until(func(): return sk.fsm.is_in(Mob.S.CHASE), 1.0)
	sk.cd = 0.0
	sk.stun_t = 1.0
	ok(not sk.fsm.can(Mob.S.WINDUP), "a stunned chaser can't start a wind-up (the guard)")
	_until(func(): return sk.stun_t <= 0.0, 1.5, no_wind)
	ok(calm[0] and _in_order(sk.fsm, ["chase>stunned", "stunned>chase"]), "no wind-up while stunned: %s" % sk.readout())
	ok(sk.fsm.refused == 0, "the Skitter's machine refused nothing (%d)" % sk.fsm.refused)
	_drop(sk)

func _brute() -> void:
	var br := _spawn("brute", P.pos, 6.0)
	br.cd = 9.0
	br.aggro(P, "check")
	_step()
	br.stag_open = 2.0
	br.hurt(5.0, P, {"ab": "check", "src": "ab"})
	ok(br.fsm.is_in(Mob.S.STUNNED) and br.stagger_t > 0.0, "an ability in its window staggers it: %s" % br.readout())
	ok(Mob.watched != null and Mob.watched.get_ref() == br, "the F7 readout follows the Brute (the monster last hit)")
	_until(func(): return not br.fsm.is_in(Mob.S.STUNNED), 4.0)
	var held := _span(br.fsm, "chase>stunned", "stunned>chase")
	ok(_near(held, STAGGER_S) and br.fsm.refused == 0,
		"STUNNED for the whole %.1fs stagger (%.2fs), refused %d" % [STAGGER_S, held, br.fsm.refused])
	_drop(br)

func _return_home() -> void:
	var rt := _spawn("skitter", P.pos, 20.0)
	rt.camp = rt.pos + Vector3(16, 0, 0)      # (dragged well off its leash)
	rt.aggro(P, "check")
	ok(rt.st == "chase", "NOTICE shows as a chase to the snapshot (%s)" % rt.st)
	_until(func(): return rt.fsm.is_in(Mob.S.RETURN), 0.5)
	ok(rt.fsm.is_in(Mob.S.RETURN) and rt.st == "idle", "off its leash and alone it RETURNs (shows as %s)" % rt.st)
	rt.camp = rt.pos + Vector3(1, 0, 0)
	_until(func(): return rt.fsm.is_in(Mob.S.IDLE), 0.5)
	ok(_in_order(rt.fsm, ["chase>return", "return>idle"]) and rt.fsm.refused == 0, "home: IDLE (%s)" % rt.readout())
	_drop(rt)

func _proxy() -> void:
	var px := _spawn("spitter", P.pos, 12.0)
	px.remote = true
	px.follow(Match.MOB_STATES.find("windup"), 0.3)
	ok(px.st == "windup" and is_equal_approx(px.st_t, 0.3) and px.fsm.is_in(Mob.S.IDLE),
		"a proxy shows the host's state (%s, %.2fs left), its own machine untouched" % [px.st, px.st_t])
	_drop(px)

# ------------------------------------------------------------------ a boss
func _boss() -> void:
	var L: Dictionary = {}
	for x in m.lairs.list:
		m.lairs.activate(x)
		if L.is_empty() and x["boss_mob"] != null:
			m.lairs.open(x, P, "check")      # (the quest seat may hold one shut: take the first that opens)
			if x["state"] == "open": L = x
	ok(not L.is_empty(), "setup: an open lair with its boss")
	if L.is_empty():
		return
	var b: Boss = L["boss_mob"]
	ok(b.dormant and b.st == "idle", "the boss sleeps (IDLE, shows idle)")
	P.teleport(L["c"] + Vector3(L["out"].x, 0, L["out"].y) * 3.0)
	ok(_until(func(): return b.attacking() and _cuttable(b), 12.0),
		"it wakes on the Hunter walking in and starts an attack: %s (lair %s)" % [b.readout(), L["state"]])
	ok(_in_order(b.fsm, ["idle>notice", "notice>chase", "chase>windup"]), "woken: notice, chase, windup (%s)" % b.atk)
	_until(func(): return b.fsm.is_in(Mob.S.CHASE), 6.0)
	var whole := ["chase>windup", "windup>attack", "attack>recover", "recover>chase"]
	ok(_in_order(b.fsm, whole), "the attack ran windup>attack>recover>chase")
	ok(_until(func(): return b.fsm.is_in(Mob.S.WINDUP), 8.0), "it winds up again (%s)" % b.atk)
	b.stun_t = 0.5
	_step()
	ok(b.fsm.is_in(Mob.S.STUNNED) and b.atk == "" and b.teles.is_empty(),
		"a stun in its wind-up cuts the attack: %s, atk '%s', tells %d" % [b.fsm.state_name(), b.atk, b.teles.size()])
	_until(func(): return not b.fsm.is_in(Mob.S.STUNNED), 1.0)
	ok(b.fsm.is_in(Mob.S.CHASE) or b.fsm.is_in(Mob.S.RETURN), "after the stun it hunts again (%s)" % b.fsm.state_name())
	m.lairs.reset_boss(b)
	ok(b.dormant and b.st == "idle" and b.fsm.refused == 0,
		"laid down by Lairs it sleeps again; refused %d (%s)" % [b.fsm.refused, b.readout()])

## A boss attack with a wind-up worth cutting (the phase roar's is a single step).
func _cuttable(b: Boss) -> bool:
	return b.fsm.is_in(Mob.S.WINDUP) and b.atk != "phase"
