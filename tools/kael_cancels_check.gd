extends RefCounted
## Kael's second-press pairs re-walked 11-11 against the source (docs/heroes/juggernaut.md "Cancels"): the rows
## that changed, each pressed through the player's own keys (one step per press, only a fresh press opens the
## glider). Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck
var m: Match
var P: Hunter
var K: JuggernautKit
var T: Hunter
var home: Vector3

func run(a) -> void:
	A = a
	var r := A.setup("juggernaut", 6.0)
	m = r[0]
	P = r[1]
	T = r[2]
	home = r[4]
	K = P.ak
	P.inp["glide_press_only"] = true
	_cleave_jump()
	_cleave_lmb()
	_lunge_shift()
	_lunge_jump()
	_drop_glide()
	_wind_down_glide()
	_slam_jump()
	await A.done(m)

func _reset() -> void:
	for k in ["fire", "sec", "sec_hold", "sig", "dash", "jump", "glide"]:
		P.inp[k] = false
	K.riposte.drop()
	K.warchain.snap("")
	A.step(m, 0.6)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.gliding = false
	P.glide_cd = 0.0
	P.dashes = P.max_dashes()
	for s in ["rmb", "e", "x", "air"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	A.fresh(T)
	T.teleport(home + Vector3(0, 0, 9.0))       # (out of every lane: the rows are about the presses)
	A.aim_at(P, home + Vector3(6.0, 0, 0))
	A.step(m, 0.1)

## One step with `key` down (Space also holds glide, as the key does), then up.
func _press(key: String) -> void:
	P.inp[key] = true
	if key == "jump":
		P.inp["glide"] = true
	m.step(A.DT)
	P.inp[key] = false

func _ult_phase() -> String:
	return String(K.riposte.st.get("phase", ""))

func _to_strike() -> void:
	HunterKeys.ult_pressed(P)
	var t := 0.0
	while _ult_phase() != "strike" and t < 1.5:
		m.step(A.DT)
		t += A.DT

## Source: "Brall can no longer jump while using Volcanic Rebuke"; the cleave was letting a jump through.
func _cleave_jump() -> void:
	_reset()
	_to_strike()
	_press("jump")
	var air := false
	var t := 0.0
	while _ult_phase() == "strike" and t < 0.5:
		air = air or not P.grounded
		m.step(A.DT)
		t += A.DT
	P.inp["glide"] = false
	A.ok("jug cancel: Space in the Riposte's cleave: no jump, the cleave lands planted",
			not air and P.grounded and _ult_phase() == "recover",
			"air %s phase %s" % [air, _ult_phase()])

func _cleave_lmb() -> void:
	_reset()
	_to_strike()
	var n0 := K.slash_at
	_press("fire")
	var waited := K.slash_at == n0
	A.step(m, 0.3, func(): P.inp["fire"] = false)      # (DashFlow replays the held press as one step down)
	A.ok("jug cancel: LMB in the cleave waits and swings as it lands", waited and K.slash_at != n0,
			"waited %s slashed %s" % [waited, K.slash_at != n0])

## A full Lunge let go (`jump`: a jump in the charge, so it flings from the air).
func _fling(jump := false) -> void:
	P.inp["sec_hold"] = true
	_press("sec")
	A.step(m, 0.6, func(): P.inp["sec_hold"] = true)
	if jump:
		_press("jump")
		A.step(m, 0.15, func(): P.inp["sec_hold"] = true)
		P.inp["glide"] = false
	P.inp["sec_hold"] = false
	m.step(A.DT)

## A Lunge is a dash of its own: Shift early in it (outside the hunter's 0.18s buffer) goes the step it ends.
func _lunge_shift() -> void:
	_reset()
	_fling()
	var flinging := not K.lunge.is_empty()
	var d0 := P.dashes
	_press("dash")
	var t := 0.0
	while not K.lunge.is_empty() and t < 0.6:
		m.step(A.DT)
		t += A.DT
	A.step(m, 0.05)
	A.ok("jug cancel: Shift early in the Lunge's fling drives a Rampage as it ends (not lost)",
			flinging and t > Hunter.DASH_BUFFER and P.dashes < d0 and P.roll_t > 0.0,
			"fling %.2f dashes %.1f -> %.1f" % [t, d0, P.dashes])

func _lunge_jump() -> void:
	_reset()
	_fling()
	var cd0 := float(K.cd["rmb"])
	_press("jump")
	m.step(A.DT)
	A.ok("jug cancel: Space in the Lunge's fling jumps out and ends it (a miss: the cooldown doubles)",
			K.lunge.is_empty() and not P.grounded and float(K.cd["rmb"]) > cd0 * 1.5,
			"cd %.2f -> %.2f" % [cd0, float(K.cd["rmb"])])

## The Meteor Drop's hang and dive: Space held from a press in them never opens the glider mid-slam.
func _drop_glide() -> void:
	var opened := false
	for phase in ["hang", "dive"]:
		_reset()
		_press("jump")
		A.step(m, 0.25)
		P.inp["glide"] = false
		_press("sec")
		var t := 0.0
		while K.meteor.phase != phase and t < 0.5:
			m.step(A.DT)
			t += A.DT
		_press("jump")
		while K.meteor.airborne() and t < 1.0:
			P.inp["glide"] = true
			opened = opened or P.gliding
			m.step(A.DT)
			t += A.DT
		P.inp["glide"] = false
	A.ok("jug cancel: Space in the Meteor Drop's hang or dive never opens the glider", not opened)

## Patch 05.02.25's wind-down (no glider straight out of it) stays on the Lunge; owner 11-11 took it off the
## Rampage, whose drive glides off on Space.
func _wind_down_glide() -> void:
	_reset()
	_fling(true)
	var t := 0.0
	while not K.lunge.is_empty() and t < 0.6:
		m.step(A.DT)
		t += A.DT
	_press("jump")
	m.step(A.DT)
	var lunge_shut := not P.gliding and P.glide_cd > 0.2
	_reset()
	_press("jump")
	A.step(m, 0.2)
	P.inp["glide"] = false
	_press("dash")
	_press("jump")
	m.step(A.DT)
	A.ok("jug cancel: no glider straight out of a Lunge (0.35s wind-down); Space in an air Rampage glides at once",
			lunge_shut and P.gliding, "lunge shut %s rampage glide %s" % [lunge_shut, P.gliding])
	P.inp["glide"] = false

func _slam_jump() -> void:
	_reset()
	T.teleport(home + Vector3(3.6, 0, 0))
	_press("sec")
	A.step(m, 0.2)
	_press("jump")
	var air := false
	var t := 0.0
	while not K.slam_w.is_empty() and t < 0.8:
		air = air or not P.grounded
		m.step(A.DT)
		t += A.DT
	P.inp["glide"] = false
	A.step(m, 0.1)
	A.ok("jug cancel: Space in the Slam's wind-up jumps, the Slam still strikes down its locked lane",
			air and A.dmg(T) > 0.0, "air %s took %.0f" % [air, A.dmg(T)])
