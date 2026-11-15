extends RefCounted
## The glider ends Sparkle's states (source patch 05.03.25: "Stuns, Roots, Grounds, and Glider cancel the
## state"): a fresh press of the glide key in the air ends the Wirerun's charge or streak and Kitefall's hang the
## way a stun ends the charge. The charge stays spent, the glider opens that step, nothing hits after the cancel.
## Holding Space never does it (DECISIONS 11-08). Runs inside --mage-combo-check and reports through its ok().

const DT := 1.0 / 60.0
const UP := 1.2                  # m off the ground: low enough that a Wirerun pass would reach a foe standing below

var hc: RefCounted
var ac: RefCounted
var m: Match
var P: Hunter
var T: Hunter
var K: MageKit
var home: Vector3

func ok(what: String, cond: bool, info := "") -> void:
	hc.ok(what, cond, info)

func run(combo_check: RefCounted, archetype_check: RefCounted) -> void:
	hc = combo_check
	ac = archetype_check
	var r: Array = ac.setup("mage", 4.0, "", true)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[4]
	K = P.ak
	(r[3] as Hunter).teleport(home + Vector3(30, 0, 0))
	_control()
	_charge()
	_streak()
	_hang()
	await ac.done(m)

## Up in the air, still, with Wirerun ready and the foe in its lane.
func _lift() -> void:
	_keys(false, false)
	P.inp["dash_down"] = false
	ac.step(m, 0.5)
	ac.fresh(T)
	P.teleport(home + Vector3(0, UP, 0))
	P.vel = Vector3.ZERO
	P.grounded = false
	P.gliding = false
	P.dashes = P.max_dashes()
	T.teleport(home + Vector3(4, 0, 0))
	T.inv_t = 0.0
	ac.aim_at(P, T.pos)

## Space (glide) and the glide key (glide_btn), the way match.gd reads real keys.
func _keys(space: bool, glide_key: bool) -> void:
	P.inp["glide_press_only"] = true
	P.inp["glide"] = space or glide_key
	P.inp["glide_btn"] = glide_key

## The same streak with no glide press hits the foe in its lane (so the rows below can see a missed hit).
func _control() -> void:
	_release()
	ac.step(m, 0.5)
	ok("glider: with no glide press the streak hits the foe below its lane", ac.dmg(T) > 0.0,
			"took %.0f" % ac.dmg(T))

## A short Wirerun charge in the air, let go: the streak starts.
func _release() -> void:
	_lift()
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, 0.1, func(): P.inp["dash_down"] = true)
	P.inp["dash_down"] = false

func _charge() -> void:
	_lift()
	P.inp["dash_down"] = true
	P.do_dash()
	ac.step(m, 0.15, func(): P.inp["dash_down"] = true)
	_keys(true, false)
	ac.step(m, 0.1, func(): P.inp["dash_down"] = true)
	ok("glider: Space held mid-charge leaves the Wirerun charging", not K.wire.is_empty() and not P.gliding)
	_keys(false, false)
	m.step(DT)
	_keys(false, true)
	m.step(DT)
	ok("glider: the glide key mid-charge ends the Wirerun and opens the glider, the charge stays spent",
			K.wire.is_empty() and K.run_t <= 0.0 and P.gliding and P.dashes < 1.0,
			"wire %s glide %s dashes %.2f" % [not K.wire.is_empty(), P.gliding, P.dashes])
	ac.step(m, 0.5, func(): _keys(false, true))
	ok("glider: no streak and no hit after the charge's cancel", K.run_t <= 0.0 and ac.dmg(T) == 0.0,
			"took %.0f" % ac.dmg(T))

func _streak() -> void:
	_release()
	m.step(DT)
	var streaking := K.run_t > 0.0
	_keys(false, true)
	m.step(DT)
	var hv := Vector2(P.vel.x, P.vel.z).length()
	ok("glider: the glide key mid-streak ends the Wirerun and opens the glider, the charge stays spent",
			streaking and K.run_t <= 0.0 and P.roll_t <= 0.0 and P.gliding and P.dashes < 1.0 and P.model.visible,
			"was streaking %s run_t %.2f glide %s dashes %.2f" % [streaking, K.run_t, P.gliding, P.dashes])
	ok("glider: the glide after the streak goes on at most at run speed (the streak's own hand-over)",
			hv <= P.base_speed * HunterMove.dash_exit_run + 0.01, "%.1f m/s" % hv)
	ac.step(m, 0.5, func(): _keys(false, true))
	ok("glider: no hit and no landing after the streak's cancel",
			ac.dmg(T) == 0.0 and K.anim_id != "mage_dash_land" and P.gliding,
			"took %.0f anim %s" % [ac.dmg(T), K.anim_id])

func _hang() -> void:
	_lift()
	P.teleport(home)
	P.grounded = true
	K.cd["x"] = 0.0
	var U := K.ult
	T.teleport(home + Vector3(3, 0, 0))
	ac.aim_at(P, T.pos)
	var hits0 := U.hits
	ok("glider: Kitefall goes off", HunterKeys.ult_pressed(P))
	ac.step(m, 0.6, func(): ac.aim_at(P, T.pos))
	var hanging := U.phase() == MageUlt.AIR
	_keys(true, false)
	ac.step(m, 0.1)
	ok("glider: Space held in the hang leaves Kitefall hanging", hanging and U.phase() == MageUlt.AIR and not P.gliding,
			U.phase())
	_keys(false, false)
	m.step(DT)
	var y0 := P.pos.y
	_keys(false, true)
	m.step(DT)
	ok("glider: the glide key in the hang ends Kitefall into a glide from up there, the cooldown stays spent",
			not U.running() and P.gliding and P.pos.y > y0 - 0.2 and float(K.cd["x"]) > 0.0,
			"phase '%s' glide %s y %.1f -> %.1f cd %.1f" % [U.phase(), P.gliding, y0, P.pos.y, float(K.cd["x"])])
	ac.step(m, 1.0, func(): _keys(false, true))
	ok("glider: no strike after Kitefall's cancel", U.hits == hits0 and ac.dmg(T) == 0.0 and P.gliding,
			"hits %d took %.0f" % [U.hits - hits0, ac.dmg(T)])
