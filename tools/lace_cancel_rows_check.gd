extends RefCounted
## Lace's Cancels table (docs/heroes/archer.md, "Cancels"), one assert per row the 11-09 pass left unsettled.
## No data, frame or wiki line shows these pairs, so each follows DECISIONS 11-07 "every interaction is chainable"
## and DashFlow's default (a missing row combines): the second press goes now and the first runs on. Run inside
## --archer-combo-check (tools/archer_bulwark_combo_check.gd).
const LIFT := 4.0            # m she is lifted before opening a glider, so it stays open through a row
const DRAW_S := 0.4          # s of draw before the second press (past the tap, short of Empowered)
var C                        # the combo check (ok, step, aim_at)
var m: Match
var P: Hunter
var K: ArcherKit
var home: Vector3


func _init(check) -> void:
	C = check


func run(match_: Match, p: Hunter, at: Vector3) -> void:
	m = match_
	P = p
	K = p.ak
	home = at
	P.lvl = maxi(P.lvl, int(Hunter.ULT_AT[0]))
	_draw_then_e()
	_ult_then()
	_glide_lmb()
	_glide_then()
	_ready_all()


## Back on her spot, every slot ready, nothing held, no wall or window left from the row before.
func _ready_all() -> void:
	P.inp["fire"] = false
	P.inp["sec_hold"] = false
	P.inp["glide"] = false
	P.gliding = false
	K.rmb_down = false
	K.ult.end()
	P.teleport(home)
	C.step(m, 0.6)
	C.aim_at(P, home + Vector3(5.0, 0, 0))
	P.ammo = maxi(P.ammo, 3)
	P.fire_cd = 0.0
	P.reload_t = 0.0
	for sl in ["rmb", "e", "x"]:
		K.cd[sl] = 0.0
	K.ch_rmb = 1.0
	K.rain = {}
	K.e_t = 0.0


func _open_glide() -> void:
	_ready_all()
	P.do_jump()
	C.step(m, 0.08)
	P.pos.y += LIFT
	P.inp["glide"] = true
	P.do_jump()
	C.step(m, 0.05)


func _hold_fire(secs: float) -> void:
	C.step(m, secs, func(): P.inp["fire"] = true)


func _draw_then_e() -> void:
	_ready_all()
	_hold_fire(DRAW_S)
	var d0 := P.draw_t
	K.use_e()
	var wall := K.in_e()
	_hold_fire(0.2)
	C.ok("Lace cancel LMB draw + E: both (rule), the wall goes up and the draw keeps charging",
			d0 > 0.0 and wall and P.draw_t > d0 + 0.1, "draw %.2f -> %.2f wall %s" % [d0, P.draw_t, wall])
	P.inp["fire"] = false
	C.step(m, 0.1)


func _ult_then() -> void:
	_ready_all()
	HunterKeys.ult_pressed(P)
	m.step(C.DT)
	var window := K.ult.active()
	K.press_rmb()
	var rmb := K.rmb_down
	K.rmb_down = false
	K.use_e()
	var e := K.in_e()
	C.ok("Lace cancel X window + RMB, E: both (rule), each goes and the three shots stay",
			window and rmb and e and K.ult.left == 3, "window %s RMB %s E %s left %d" % [window, rmb, e, K.ult.left])


func _glide_lmb() -> void:
	_open_glide()
	var gliding := P.gliding
	_hold_fire(DRAW_S)
	C.ok("Lace cancel glide + LMB: both (rule), the bow draws from the open glider, which stays open",
			gliding and P.gliding and P.draw_t > 0.2, "gliding %s -> %s draw %.2f" % [gliding, P.gliding, P.draw_t])
	P.inp["fire"] = false


func _glide_then() -> void:
	var g := []                # the glider before the press and 0.1 s after it, per slot
	_open_glide()
	g.append(P.gliding)
	K.press_rmb()
	var rmb := K.rmb_down
	C.step(m, 0.1)
	g.append(P.gliding)
	K.rmb_down = false
	_open_glide()
	g.append(P.gliding)
	K.use_e()
	var e := K.in_e()
	C.step(m, 0.1)
	g.append(P.gliding)
	_open_glide()
	g.append(P.gliding)
	HunterKeys.ult_pressed(P)
	var x := K.ult.active()
	C.step(m, 0.1)
	g.append(P.gliding)
	C.ok("Lace cancel glide + RMB, E, X: both (rule), each goes and the glider stays open",
			not g.has(false) and rmb and e and x, "gliding %s RMB %s E %s X %s" % [g, rmb, e, x])
