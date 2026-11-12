extends RefCounted
## --guardian-stance-check: how the guardian Boki carries itself (KinGuardStance). For one species of each body
## plan (quad, biped, flyer, serpent, blob) it bursts out facing the threat within 0.3 s, turns to a threat that
## moves to its other side within 0.3 s, never leaves the 6 m leash, stands low and wide on KinPuppet's and
## BokiRig's Flex node while it holds still, drops the stance to strike with its attack clip, and folds back
## into the wisp when the window ends. Prints PASS/FAIL.

const DT := 1.0 / 60.0
const PLANS := {"quad": "cindle", "biped": "zapple", "flyer": "wisplet", "serpent": "zephyrak", "blob": "gloamshell"}
const FACE_S := 0.3       # s: it faces the threat within this
const FACE_TOL := 0.3     # rad
const LEASH_SLACK := 0.6  # m past the 6 m leash: it is walking back, not teleporting

var bad := 0
var m: Match
var main: Node
var p: Hunter
var k: Kin
var foe: Hunter

func run(main_node: Node) -> void:
	main = main_node
	for plan in PLANS:
		var sp: String = PLANS[plan]
		_start(sp)
		_facing(plan)
		_standing(plan)
		_striking(plan)
		_folding(plan)
	m.queue_free()
	print("GUARDSTANCE %s (%d fail)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

func ok(cond: bool, what: String) -> void:
	print("STANCE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _start(species: String) -> void:
	if m:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 79, "no_drop": true, "demo_kin": species,
		"boki_wisps": true})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle" if h != m.player else h.ctrl
		h.inp["move"] = Vector2.ZERO
	p = m.player
	k = p.kin
	foe = m.hunters.filter(func(x): return x.team != p.team)[0]
	_frames(0.3)

func _frames(secs: float) -> float:
	var worst := 0.0
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		worst = maxf(worst, k.flat_dist(p))
	for h in m.hunters:
		h.render(DT, 1.0)
	k.render(DT, 1.0)
	return worst

func _foe_to(offset: Vector3) -> void:
	foe.pos = p.pos + offset
	foe.prev = foe.pos

func _off_by(at: Vector3) -> float:
	return absf(angle_difference(k.face, KinGuardStance.yaw_to(k, at)))

func _facing(plan: String) -> void:
	_foe_to(Vector3(5.0, 0, 0))
	m.knock(p, foe, {})
	p.down_hp = 1e6
	var off := _off_by(foe.pos)
	ok(k.summon.guardian and off < 0.05, "%s: it lands facing the threat (%.2f rad off)" % [plan, off])
	var worst := _frames(FACE_S)
	off = _off_by(foe.pos)
	ok(off < FACE_TOL, "%s: still on it after %.1f s (%.2f rad)" % [plan, FACE_S, off])
	_foe_to(Vector3(-5.0, 0, 0))
	worst = maxf(worst, _frames(FACE_S))
	off = _off_by(foe.pos)
	ok(off < FACE_TOL, "%s: it turns to the other side within %.1f s (%.2f rad)" % [plan, FACE_S, off])
	worst = maxf(worst, _frames(2.0))
	var leash := float(KinGuardian.rules()["leash"])
	ok(worst < leash + LEASH_SLACK, "%s: it stays on the %.0f m leash (%.1f m at most)" % [plan, leash, worst])

## A threat it watches but cannot reach (it gave up on it: Kin.ignore_until; Kin._wisp_threat fights inside
## 3 m): it holds the stance, low and wide on Flex; a plain summon has its normal pose.
func _standing(plan: String) -> void:
	_foe_to(Vector3(6.0, 0, 0))
	k.target = null
	k.ignore_until[foe] = m.time + 99.0
	_frames(2.0)      # back at its side spot and still
	ok(k.model.get_meta("pose") == "stance", "%s: standing guard, the pose is stance" % plan)
	var flex := k.model.get_node("Body/Flex") as Node3D
	var low := _settle(flex)
	k.summon.guardian = false
	_frames(0.2)
	var normal := _settle(flex)
	ok(low.y < normal.y - 0.04, "%s: low (Flex height %.2f against %.2f)" % [plan, low.y, normal.y])
	ok(low.x > normal.x + 0.04, "%s: wide (Flex width %.2f against %.2f)" % [plan, low.x, normal.x])
	k.summon.guardian = true
	k.ignore_until.erase(foe)

## The pose springs run on frames: step them by hand and read Flex.
func _settle(flex: Node3D) -> Vector3:
	var puppet := k.model.find_children("*", "KinPuppet", true, false)[0] as KinPuppet
	var rig := flex.get_node_or_null("BokiRig") as BokiRig
	for i in 90:
		puppet._process(DT)
		if rig:
			rig._keep_flex(DT)
	return flex.scale

## A foe within reach: it strikes with its attack clip and the stance is dropped for the strike.
func _striking(plan: String) -> void:
	_foe_to(Vector3(1.4, 0, 0))
	var struck := false
	for i in 180:
		m.step(DT)
		if k.lunge_t > 0.0:
			k.render(DT, 1.0)
			struck = k.model.get_meta("kstate") == "attack" and k.model.get_meta("pose") != "stance"
			break
	ok(struck, "%s: it lunges (the attack clip) with the stance dropped" % plan)

## The window ends: the summon's own shrink, then it is a wisp again.
func _folding(plan: String) -> void:
	_foe_to(Vector3(40.0, 0, 0))
	var s := k.summon
	s.left = 0.05
	_frames(0.2)
	var folding := s.shrink > 0.0 and not s.guardian and k.scale.x < 1.0
	ok(folding, "%s: the window ends, it shrinks (%.2f of full size)" % [plan, k.scale.x])
	_frames(1.0)
	ok(k.wisp and s.cd > 0.0, "%s: folded back into the wisp, the cooldown running" % plan)
