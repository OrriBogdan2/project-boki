extends "res://tools/archetype_check.gd"
## One bow, one arrow, run from --archer-combo-check (tools/archer_bulwark_combo_check.gd adds the counts): Lace's
## LMB draw and Heavy Shot hold never run at once. The newer press drops the held draw with no arrow, either order
## (docs/heroes/archer.md, Cancels). Prints AKCHECK lines.

## Both press orders, each against a fresh range.
func pin() -> void:
	await _lmb_then_rmb()
	await _rmb_then_lmb()

func _ready_bow(P: Hunter, K: ArcherKit) -> void:
	P.equip("longbow", 0)
	P.fire_cd = 0.0
	P.ammo = maxi(P.ammo, 1)
	K.ch_rmb = 2.0
	K.cd["rmb"] = 0.0

## One frame's keys: LMB and RMB held or not, aim kept on the target.
func _keys(P: Hunter, T: Hunter, lmb: bool, rmb: bool) -> void:
	P.inp["fire"] = lmb
	P.inp["sec_hold"] = rmb
	aim_at(P, T.pos)

## LMB held, then RMB: the draw drops (no arrow, its pose gone), the bow rests while the Heavy Shot is held, a
## release of LMB then looses nothing, and RMB's release looses the one Heavy Shot.
func _lmb_then_rmb() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArcherKit = P.ak
	_ready_bow(P, K)
	step(m, 0.5, func(): _keys(P, T, true, false))
	ok("one bow LMB>RMB: the bow is drawn first", P.draw_t > 0.3 and K.anim_id == "arc_draw", K.anim_id)
	var loosed0 := K.draw.loosed_at
	var ch0 := K.ch_rmb
	var kicks0 := K.heavy_kicks
	P.inp["sec_hold"] = true
	K.press_rmb()
	m.step(DT)
	ok(
		"one bow LMB>RMB: the RMB press drops the draw with no arrow",
		P.draw_t < 0.0 and K.rmb_down and K.draw.loosed_at == loosed0 and K.anim_id != "arc_draw",
		"draw %.2f rmb %s anim %s" % [P.draw_t, K.rmb_down, K.anim_id]
	)
	step(m, 0.6, func(): _keys(P, T, true, true))
	ok(
		"one bow LMB>RMB: a still-held LMB doesn't draw while the Heavy Shot is held",
		P.draw_t < 0.0 and K.pin_aim and K.anim_id == "arc_heavy_wind",
		"draw %.2f aim %s anim %s" % [P.draw_t, K.pin_aim, K.anim_id]
	)
	step(m, 0.1, func(): _keys(P, T, false, true))
	ok("one bow LMB>RMB: letting LMB go looses nothing", K.draw.loosed_at == loosed0 and K.rmb_down)
	P.inp["sec_hold"] = false
	step(m, 0.1)
	ok(
		"one bow LMB>RMB: RMB's release looses the one Heavy Shot, no bow arrow",
		K.heavy_kicks == kicks0 + 1 and K.ch_rmb < ch0 and K.draw.loosed_at == loosed0,
		"kicks %d charges %.1f -> %.1f" % [K.heavy_kicks - kicks0, ch0, K.ch_rmb]
	)
	await done(m)

## RMB held into the Heavy Shot's draw, then LMB: the hold drops (no shot, no charge spent, its bar and pose
## gone), the bow draws, a still-held RMB starts nothing, and LMB's release looses one bow arrow.
func _rmb_then_lmb() -> void:
	var r := setup("archer", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var K: ArcherKit = P.ak
	_ready_bow(P, K)
	aim_at(P, T.pos)
	P.inp["sec_hold"] = true
	K.press_rmb()
	step(m, 0.6, func(): _keys(P, T, false, true))
	ok("one bow RMB>LMB: the Heavy Shot is held first", K.rmb_down and K.pin_aim, K.anim_id)
	var ch0 := K.ch_rmb
	var kicks0 := K.heavy_kicks
	var loosed0 := K.draw.loosed_at
	step(m, 0.5, func(): _keys(P, T, true, true))
	ok(
		"one bow RMB>LMB: the LMB press drops the Heavy Shot with no shot and no charge spent",
		not K.rmb_down and not K.pin_aim and not AimKit.shown(P, "rmb_bar") and K.ch_rmb == ch0
			and K.heavy_kicks == kicks0 and K.anim_id != "arc_heavy_wind",
		"rmb %s aim %s charges %.1f -> %.1f anim %s" % [K.rmb_down, K.pin_aim, ch0, K.ch_rmb, K.anim_id]
	)
	ok("one bow RMB>LMB: the bow draws in its place", P.draw_t > 0.3 and K.anim_id == "arc_draw", K.anim_id)
	step(m, 0.1, func(): _keys(P, T, false, true))
	P.inp["sec_hold"] = false
	step(m, 0.1)
	ok(
		"one bow RMB>LMB: LMB's release looses one bow arrow; the still-held RMB loosed nothing",
		K.draw.loosed_at > loosed0 and K.heavy_kicks == kicks0 and K.ch_rmb == ch0,
		"kicks %d charges %.1f -> %.1f" % [K.heavy_kicks - kicks0, ch0, K.ch_rmb]
	)
	await done(m)
