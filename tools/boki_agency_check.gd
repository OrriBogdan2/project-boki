extends RefCounted
## --boki-agency-check: the runtime half of the agency fence (KinFence, docs/BOKI_AGENCY_AUDIT.md, OWNER_REVIEW
## 184b). Every Boki ability (E and auto, one species per ability) is cast 20 times near its idle hunter, with
## the Boki on him and with the Boki out beside him, a foe in front; then every Fusion runs its start and
## pulses. The hunter's position and velocity never change, except the abyss rescue (an owner_falling cue).

const CASTS := 20
const STEP_S := 0.25             # s simulated after each cast
const POS_TOL := 0.02            # m the idle hunter may drift
const VEL_TOL := 0.05            # m/s

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("BOKIAGENCY %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

## A training match with `species` bonded, on a levelled strip; a foe 6 m in front, the rest far off.
func _fresh(species: String) -> Hunter:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 1840, "no_drop": true,
		"demo_kin": species, "weapon": "rifle", "cls": "medium"})
	m.set_process(false)
	var P: Hunter = m.player
	var W: World = m.world
	var hx := int(floor(P.pos.x))
	var hz := int(floor(P.pos.z))
	var hi: int = W.idx(hx, hz)
	var lv: int = int(W.level[hi]) if W.kind[hi] != World.T_VOID else 0
	for dz in range(-12, 13):
		for dx in range(-12, 16):
			if not W.inb(hx + dx, hz + dz): continue
			var i: int = W.idx(hx + dx, hz + dz)
			W.kind[i] = World.T_GROUND
			W.level[i] = lv
			W.island[i] = W.island[hi]
			for tiles: Dictionary in [W.stairs, W.walls, W.props, W.bush]:
				tiles.erase(i)
	P.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	P.vel = Vector3.ZERO
	P.slot_lv["kin"] = 1
	P.slot_lv["ult"] = 1
	var foe_set := false
	for h in m.hunters:
		if h.team != P.team:
			h.ctrl = "idle"
			h.teleport(P.pos + (Vector3(6.0, 0, 0) if not foe_set else Vector3(40.0, 0, 30.0)))
			h.max_hp = 1e5
			h.hp = h.max_hp
			# a foe hooked into you is not a Boki moving you: only you are under test
			h.cdat = h.cdat.duplicate()
			h.cdat["mass"] = 0.001
			foe_set = true
	for q: Kin in m.kins:
		if q.owner_h != P:
			q.state = "bench"          # the foes' Boki stay out of it: only your own Boki is under test
	_settle()
	return P

func _settle() -> void:
	for i in 30:
		_step()

func _step() -> void:
	for mb in m.mobs.duplicate():
		m.mobs.erase(mb)
		mb.queue_free()
	m.step(Match.DT)

func _foe(P: Hunter) -> Hunter:
	for h in m.hunters:
		if h.team != P.team and h.flat_dist(P) < 10.0:
			return h
	return null

## Casts `slot` CASTS times; returns the worst drift of the hunter's position and speed [m, m/s].
func _casts(P: Hunter, k: Kin, slot: String, carried: bool) -> Vector2:
	var home := P.pos
	var worst := Vector2.ZERO
	for n in CASTS:
		if carried:
			k.stow()
		else:
			k.runner.reset()
			k.teleport(P.pos + Vector3(-2.0, 0, 2.0))
			k.state = "active"
			k.fly = {}
			k.cmd = "follow"
		k.brain.think_t = 1e9
		k.runner.reset()
		k.rest_t = 0.0
		P.inp["move"] = Vector2.ZERO
		var foe := _foe(P)
		var aim: Vector3 = foe.pos if foe else P.pos + Vector3(6, 0, 0)
		P.inp["aim"] = aim + Vector3(0, 0.9, 0)
		if slot != "none": k.use_ability(slot, aim)
		var t := 0.0
		while t < STEP_S:
			_step()
			t += Match.DT
			worst.x = maxf(worst.x, Vector2(P.pos.x - home.x, P.pos.z - home.z).length())
			worst.y = maxf(worst.y, P.vel.length())
	return worst

func _drift(w: Vector2) -> String:
	return "drift %.3f m, speed %.2f m/s" % [w.x, w.y]

func _abilities() -> void:
	var P0 := _fresh("zapple")
	var w0 := _casts(P0, P0.kin, "none", false)
	ok(w0.x <= POS_TOL and w0.y <= VEL_TOL, "control, no cast: the idle hunter stays put (%s)" % _drift(w0))
	var seen := {}
	var ids: Array = Data.KIN.keys()
	ids.sort()
	for sp: String in ids:
		var ks: KinSpec = KinLib.kin(sp)
		if ks == null: continue
		for slot in ["k1", "k2"]:
			var ab_id: String = ks.active if slot == "k1" else ks.auto
			if ab_id == "" or seen.has(ab_id): continue
			seen[ab_id] = true
			var ab := KinLib.ability(ab_id)
			if ab.cue != null and ab.cue.type == "owner_falling":
				ok(true, "%s (%s) is the abyss rescue: whitelisted" % [ab_id, sp])
				continue
			for carried in [true, false]:
				var P := _fresh(sp)
				var w := _casts(P, P.kin, slot, carried)
				var where := "on you" if carried else "out"
				var what := "%s (%s, Boki %s) x%d" % [ab_id, sp, where, CASTS]
				ok(w.x <= POS_TOL and w.y <= VEL_TOL, "%s: you never move (%s)" % [what, _drift(w)])

func _fusions() -> void:
	var seen := {}
	var ids: Array = Data.KIN.keys()
	ids.sort()
	for sp: String in ids:
		var ks: KinSpec = KinLib.kin(sp)
		if ks == null or ks.merge == "" or seen.has(ks.merge): continue
		seen[ks.merge] = true
		var P := _fresh(sp)
		P.kin.stow()
		_settle()
		var home := P.pos
		P.ult = 1.0
		P.merge_cd = 0.0
		var started := KinMerge.press(P)
		var worst := 0.0
		for i in 150:
			P.inp["move"] = Vector2.ZERO
			_step()
			worst = maxf(worst, Vector2(P.pos.x - home.x, P.pos.z - home.z).length())
		var what := "Fusion %s (%s): its start and pulses never move you" % [ks.merge, sp]
		ok(started and worst <= POS_TOL, "%s (started %s, drift %.3f m)" % [what, started, worst])

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_abilities()
	_fusions()
	if m: m.queue_free()
	print("BOKIAGENCY DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
