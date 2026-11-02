class_name PairDemo
extends RefCounted
## Screenshot tooling for Dolm and Ostra (used by ArenaDemo): --arena-demo=pair_<what> --arena-shot=<png>.
##   pair_card_dolm / pair_card_ostra     the kit card
##   pair_dolm_rocks / pair_dolm_pay      Stone Row up (rocks beside the dummy) / the ROCKFALL payoff
##   pair_ostra_swollen / pair_ostra_seed / pair_ostra_pay    Swollen, a growing seed, the COLLAPSE payoff
## and --arena-demo=anim_<move> strips (ANIM): dol_boulder dol_punch dol_dash dol_slam dol_wave
## ost_dash ost_snap ost_seed ost_orb.

const ANIM := {
	"dol_boulder": ["dolm", "rubble_fists", [0.45, 0.52, 0.58, 0.66, 0.78, 1.0]],
	"dol_punch": ["dolm", "rubble_fists", [0.55, 0.85, 1.2, 1.5, 1.57, 1.66, 1.95]],
	"dol_dash": ["dolm", "rubble_fists", [0.45, 0.55, 0.62, 0.7, 0.8, 1.0]],
	"dol_slam": ["dolm", "rubble_fists", [0.55, 0.9, 1.35, 1.55, 1.64, 1.75, 2.1]],
	"dol_wave": ["dolm", "rubble_fists", [0.45, 0.55, 0.62, 0.72, 0.9, 1.3]],
	"ost_dash": ["ostra", "tether_lantern", [0.45, 0.6, 0.8, 1.0, 1.45, 1.6]],
	"ost_snap": ["ostra", "tether_lantern", [0.45, 0.52, 0.6, 0.7, 0.85, 1.1]],
	"ost_seed": ["ostra", "tether_lantern", [0.45, 0.6, 0.9, 1.8, 3.0, 3.1, 3.3]],
	"ost_orb": ["ostra", "tether_lantern", [0.45, 0.55, 0.65, 0.8, 1.0, 1.3]],
}

static func at(t: float, dt: float, when: float) -> bool:
	return ArenaDemo._at(t, dt, when)

## The scripted input of one strip (called every step).
static func trigger(P: Hunter, _D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	match mv:
		"dol_boulder":
			P.inp["fire"] = t > 0.5 and t < 0.54
		"dol_punch":
			P.inp["fire"] = t > 0.5 and t < 1.45
			if t < 0.45: P.teleport(Vector3(_D.pos.x - 2.2, P.pos.y, _D.pos.z))
		"dol_dash":
			if at(t, dt, 0.5): P.dashes = P.max_dashes(); P.do_dash()
		"dol_slam":
			if t < 0.45: P.teleport(Vector3(_D.pos.x - 2.8, P.pos.y, _D.pos.z))
			if at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.bot_hold["rmb"] = 1.0; K.press_rmb()
		"dol_wave":
			if at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
		"ost_dash":
			if at(t, dt, 0.5): P.dashes = P.max_dashes(); P.do_dash()
		"ost_snap":
			if at(t, dt, 0.5): K.ch_rmb = 1.0; K.cd["rmb"] = 0.0; K.press_rmb()
		"ost_seed":
			if at(t, dt, 0.5): K.cd["e"] = 0.0; K.use_e()
			if at(t, dt, 3.0): K.use_e()
		"ost_orb":
			P.inp["fire"] = t > 0.5 and t < 0.56
			if P.ammo < 3: P.ammo = int(P.wpn["mag"])

## A still moment; returns the time to save the frame at.
static func tick(A: Arena, P: Hunter, D: Hunter, t: float, dt: float, w: String) -> float:
	var who := "dolm" if "dolm" in w else "ostra"
	var at_t := 1.2
	if t < 0.05:
		A.set_arch(who)
		A.set_kin("puddlet")
		if not w.begins_with("pair_card"):
			P.teleport(D.pos + Vector3(-4.2, 0, 0))
			A.home = P.pos
			D.max_hp = 900.0; D.hp = D.max_hp
			A.m.set_meta("zoom_hold", 0.5)
			if A.m.cam: A.m.cam.zoom = 0.5
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	var K: ArchKit = P.ak
	match w:
		"pair_card_dolm", "pair_card_ostra":
			if at(t, dt, 0.3):
				A.toggle_card()
				ArenaDemo._shot_later(A, 0.7)
			return 99.0
		"pair_dolm_rocks":
			if at(t, dt, 0.3): K.cd["e"] = 0.0; K.use_e()
			at_t = 0.9
		"pair_dolm_pay":
			if at(t, dt, 0.3): K.cd["e"] = 0.0; K.use_e()
			if at(t, dt, 0.8): P.teleport(D.pos + Vector3(-3.0, 0, 0)); ArenaDemo._aim(P, D)
			P.inp["fire"] = t > 0.9 and t < 1.9
			if int(K.get("launch_pay")) > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
			at_t = float(A.get_meta("pay_at", 9.0)) + 0.1
		"pair_ostra_swollen":
			if at(t, dt, 0.3): K.add_swell(100.0)
			at_t = 0.9
		"pair_ostra_seed":
			if at(t, dt, 0.3): K.cd["e"] = 0.0; K.use_e()
			at_t = 3.2
		"pair_ostra_pay":
			if at(t, dt, 0.3): K.cd["e"] = 0.0; K.use_e()
			if int(K.get("collapses")) > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
			at_t = float(A.get_meta("pay_at", 9.0)) + 0.1
	return at_t
