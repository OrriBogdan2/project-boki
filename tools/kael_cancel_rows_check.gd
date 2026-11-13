extends RefCounted
## Kael's settled second-press rows: one assert per row of docs/heroes/juggernaut.md "Cancels" that was left
## unsettled (no frame, card or wiki line shows the pair; DECISIONS "every interaction is chainable" decides).
## Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck


func run(a) -> void:
	A = a
	var r := A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	P.lvl = maxi(P.lvl, 6)
	P.slot_lv["ult"] = 1
	var home: Vector3 = r[4]
	await slam_rows(m, P, home)
	await move_rows(m, P, home)
	await riposte_rows(m, P, home)
	await slash_rows(m, P, home)
	await A.done(m)


func _fresh(m: Match, P: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	A.step(m, 0.8)
	K.warchain.snap(true)
	K.riposte.drop()
	A.step(m, 0.1)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.fire_cd = 0.0
	for s in ["e", "rmb", "x", "air"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	A.aim_at(P, home + Vector3(9.0, 0, 0))
	m.step(A.DT)


## One frame of the attack key, let go the next.
func _slash_tap(m: Match, P: Hunter) -> void:
	P.inp["fire"] = true
	m.step(A.DT)
	P.inp["fire"] = false


func _ready_smash(K: JuggernautKit) -> void:
	K.cd["rmb"] = 0.0
	K.ch_rmb = float(K.rmb_charges())


# ------------------------------------------------------------------ the Finishing Slam's wind-up
func slam_rows(m: Match, P: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	var wind := float(K.rmb_def()["windup"])
	_fresh(m, P, home)
	A.tap(m, P)
	A.step(m, 0.15)
	var t0 := m.time
	_slash_tap(m, P)
	A.step(m, 0.05)
	A.ok("jug cancel: LMB in the Slam's wind-up slashes at once and the wind-up runs on (both)",
			K.slash_at > t0 and not K.slam_w.is_empty(), "slashed %s" % (K.slash_at > t0))
	# RMB again: early in the wind-up it is dropped, in its last BUFFER it winds up the next Slam as it strikes
	_fresh(m, P, home)
	A.tap(m, P)
	A.step(m, 0.1)
	_ready_smash(K)
	A.tap(m, P)
	A.step(m, wind)
	var early_dropped := K.slam_w.is_empty()
	_fresh(m, P, home)
	A.tap(m, P)
	A.step(m, wind - 0.08)
	_ready_smash(K)
	A.tap(m, P)
	A.step(m, 0.15)
	A.ok("jug cancel: RMB again in the Slam's wind-up waits: early dropped, in the last 0.12 s the next Slam goes",
			early_dropped and not K.slam_w.is_empty(), "early dropped %s" % early_dropped)
	_fresh(m, P, home)
	A.tap(m, P)
	A.step(m, 0.15)
	P.do_jump()
	A.step(m, 0.12)
	A.ok("jug cancel: a jump in the Slam's wind-up goes and the wind-up runs on (both)",
			not P.grounded and not K.slam_w.is_empty(), "grounded %s" % P.grounded)


# ------------------------------------------------------------------ the Lunge's fling and the Meteor Drop
func move_rows(m: Match, P: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	# the fling's length, then an LMB press in its last 0.06 s swings as it ends
	_fresh(m, P, home)
	A.hold(m, P, 0.5)
	var fling := 0.0
	while not K.lunge.is_empty() and fling < 1.0:
		m.step(A.DT)
		fling += A.DT
	_fresh(m, P, home)
	A.hold(m, P, 0.5)
	A.step(m, maxf(0.0, fling - 0.06))
	var t0 := m.time
	var in_fling := not K.lunge.is_empty()
	_slash_tap(m, P)
	A.step(m, 0.2)
	var late_lunge := in_fling and K.slash_at > t0
	# the Meteor Drop: a press in the dive is dropped (the 0.5 s recovery follows), one late in the recovery goes
	_fresh(m, P, home)
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	A.tap(m, P)
	t0 = m.time
	_slash_tap(m, P)
	var t := 0.0
	while K.meteor.running() and String(K.meteor.phase) != "recover" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	var rec0 := m.time
	while K.meteor.running() and m.time - rec0 < 1.0:
		m.step(A.DT)
	var rec := m.time - rec0
	var dive_dropped := K.slash_at < t0
	_fresh(m, P, home)
	P.teleport(home + Vector3(0, 1.8, 0))
	P.grounded = false
	A.tap(m, P)
	t = 0.0
	while K.meteor.running() and String(K.meteor.phase) != "recover" and t < 1.0:
		m.step(A.DT)
		t += A.DT
	A.step(m, maxf(0.0, rec - 0.06))
	t0 = m.time
	_slash_tap(m, P)
	A.step(m, 0.2)
	A.ok("jug cancel: LMB in a Lunge or a Meteor Drop waits: its last 0.12 s swings as it ends, a press in the dive "
			+ "is dropped", late_lunge and dive_dropped and K.slash_at > t0,
			"fling %.2f lunge %s dive dropped %s drop late %s" % [fling, late_lunge, dive_dropped, K.slash_at > t0])


# ------------------------------------------------------------------ the Gilded Riposte's guard and cleave
func riposte_rows(m: Match, P: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	var lock := float(K.x_def()["guard"]) + float(K.x_def()["strike_t"])
	# early in the guard: both presses dropped; in the cleave's last 0.12 s: both go as it lands
	_fresh(m, P, home)
	K.cast_ult()
	A.step(m, 0.2)
	var t0 := m.time
	_slash_tap(m, P)
	A.tap(m, P)
	A.step(m, lock + 0.1)
	var early_dropped := K.slash_at < t0 and K.slam_w.is_empty()
	_fresh(m, P, home)
	K.cast_ult()
	A.step(m, lock - 0.07)
	var locked := K.busy()
	t0 = m.time
	_slash_tap(m, P)
	A.step(m, 0.2)
	var late_slash := K.slash_at > t0
	_fresh(m, P, home)
	K.cast_ult()
	A.step(m, lock - 0.07)
	A.tap(m, P)
	var held := not K.rmb_down
	A.step(m, 0.15)
	var slam := not K.slam_w.is_empty()
	A.ok("jug cancel: LMB or RMB in the Riposte's guard or cleave waits: early dropped, the last 0.12 s goes as it "
			+ "lands (slash, Slam)", early_dropped and locked and late_slash and held and slam,
			"early dropped %s slash %s rmb held %s slam %s" % [early_dropped, late_slash, held, slam])


# ------------------------------------------------------------------ the slash recovery and the Searing Wave hold
func slash_rows(m: Match, P: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	var W := K.warchain
	_fresh(m, P, home)
	_slash_tap(m, P)
	A.step(m, float(K.lmb_def()["rate"]) - 0.15)
	var t0 := m.time
	var recovering := P.fire_cd > 0.0 and K.slash_at < t0
	_slash_tap(m, P)
	var waits := K.slash_at < t0
	A.step(m, 0.3)
	A.ok("jug cancel: LMB in the slash's recovery (its last 0.25 s) waits, then swings the next slash",
			recovering and waits and K.slash_at > t0, "recovering %s waits %s" % [recovering, waits])
	_fresh(m, P, home)
	_slash_tap(m, P)
	A.step(m, 0.05)
	recovering = P.fire_cd > 0.0
	A.tap(m, P)
	var slam := not K.slam_w.is_empty()
	var th0 := W.throws
	K.use_e()
	A.ok("jug cancel: RMB or E in the slash's recovery goes at once (both)",
			recovering and slam and W.throws == th0 + 1, "recovering %s slam %s" % [recovering, slam])
	_fresh(m, P, home)
	var hold := func(): P.inp["fire"] = true
	A.step(m, float(K.lmb_def()["tap"]) + 0.1, hold)
	var charging := K.lmb_t > float(K.lmb_def()["tap"])
	A.tap(m, P)
	slam = not K.slam_w.is_empty()
	th0 = W.throws
	K.use_e()
	A.step(m, 0.05, hold)
	A.ok("jug cancel: RMB or E with the Searing Wave held goes at once and the charge goes on (both)",
			charging and slam and W.throws == th0 + 1 and K.lmb_t > 0.0, "charging %s slam %s" % [charging, slam])
	P.inp["fire"] = false
