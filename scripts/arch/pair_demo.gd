class_name PairDemo
extends RefCounted
## Screenshot tooling for Tarek (dolm) and Ostra (used by ArenaDemo): --arena-demo=pair_<what> --arena-shot=<png>.
## Single moments (SHOTS): pair_<hero>_<ability>_<tele|key|hit>, the cards (pair_card_dolm / pair_card_ostra),
## and the before/after views pair_dolm_pay / pair_dolm_slam / pair_dolm_rocks / pair_ostra_orb /
## pair_ostra_fan / pair_ostra_trade (the same names exist on main, so both sides shoot the same moment).
## Strips (--arena-demo=anim_<move>, ANIM): 4-6 frames of every kit move, anticipation to recovery.

const ANIM := {
	"br_throw": ["dolm", "rubble_fists", [0.5, 0.56, 0.62, 0.7, 0.85, 1.0]],
	"br_punch": ["dolm", "rubble_fists", [0.7, 1.2, 1.44, 1.47, 1.52, 1.75]],
	"br_slam": ["dolm", "rubble_fists", [0.8, 0.98, 1.2, 1.4, 1.55, 1.9]],
	"br_leap": ["dolm", "rubble_fists", [0.85, 1.0, 1.12, 1.28, 1.5, 1.9]],
	"br_lunge": ["dolm", "rubble_fists", [0.85, 0.93, 0.98, 1.06, 1.25]],
	"br_dive": ["dolm", "rubble_fists", [0.5, 0.62, 0.75, 0.9, 1.05, 1.4]],
	"br_dash": ["dolm", "rubble_fists", [0.53, 0.63, 0.8, 0.98, 1.13, 1.3]],
	"br_exdash": ["dolm", "rubble_fists", [0.5, 0.56, 0.64, 0.76, 0.86, 1.1]],
	"br_raise": ["dolm", "rubble_fists", [0.5, 0.58, 0.7, 0.86, 1.05, 1.4]],
	"br_sense": ["dolm", "rubble_fists", [0.45, 0.62, 0.72, 0.85, 1.05]],
	"os_orb": ["ostra", "tether_lantern", [0.5, 0.54, 0.58, 0.64, 0.8]],
	"os_orb_hot": ["ostra", "tether_lantern", [1.56, 1.62, 1.67, 1.73, 1.85, 2.1]],
	"os_snap": ["ostra", "tether_lantern", [0.64, 0.8, 0.835, 0.86, 0.91]],
	"os_swap": ["ostra", "tether_lantern", [0.8, 0.96, 1.04, 1.25, 2.0]],
	"os_swap_air": ["ostra", "tether_lantern", [0.47, 0.58, 0.68, 0.95, 1.6]],
	"os_arrive": ["ostra", "tether_lantern", [2.68, 2.74, 2.78, 2.84, 3.1]],
	"os_seed": ["ostra", "tether_lantern", [0.5, 0.56, 0.62, 0.72, 0.9, 1.2]],
	"os_pop": ["ostra", "tether_lantern", [2.0, 2.06, 2.12, 2.2, 2.4, 2.65]],
	"os_empower": ["ostra", "tether_lantern", [0.5, 0.6, 0.75, 0.9, 1.05, 1.35]],
	"br_spine": ["dolm", "rubble_fists", [0.6, 0.78, 0.83, 1.1, 1.43, 1.8]],
	"os_well": ["ostra", "tether_lantern", [0.6, 0.8, 1.3, 1.56, 1.9, 2.5]],
}

static func at(t: float, dt: float, when: float) -> bool:
	return ArenaDemo._at(t, dt, when)

static func _rmb_hold(K: ArchKit, t: float, dt: float, from: float, secs: float) -> void:
	if at(t, dt, from):
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		K.bot_hold["rmb"] = secs
		K.press_rmb()

## A clean frame for the owner: no hover cards or dev text (recording mode), no hero caption toast, and
## the camera at --zoom=<z> when given (1.0 is the gameplay zoom; the default is a close-up), --slowmo=<k>.
static func stage(m: Node, t: float) -> void:
	if t > 0.1:
		return
	Record.set_level(maxi(Record.level, 1))
	if m.hud: m.hud.msgs.clear()
	var z := 0.0
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--zoom="): z = float(String(a).substr(7))
		# a slower clock so a short moment (a 0.2s wind-up, a bolt in flight) lands on a drawn frame
		if String(a).begins_with("--slowmo="): Engine.time_scale = float(String(a).substr(9))
	if z > 0.0 and m.cam:
		m.set_meta("zoom_hold", z)
		m.cam.zoom = z

## The scripted input of one strip (called every step).
static func trigger(P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	stage(P.m, t)
	match mv:
		"br_throw":
			P.inp["fire"] = t > 0.5 and t < 0.54
		"br_punch":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 2.4, P.pos.y, D.pos.z))
			P.inp["fire"] = t > 0.5 and t < 1.45
		"br_slam":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 3.6, P.pos.y, D.pos.z))
			_rmb_hold(K, t, dt, 0.5, 0.95)
		"br_leap":
			_rmb_hold(K, t, dt, 0.5, 1.4)
			if at(t, dt, 0.9): P.inp["jump"] = true
		"br_lunge":
			_rmb_hold(K, t, dt, 0.5, 1.0)
			P.inp["fire"] = t > 0.9 and t < 0.96
		"br_dive":
			if at(t, dt, 0.45):
				P.teleport(P.pos + Vector3(0, 3.0, 0))
				P.grounded = false
				P.vel = Vector3.ZERO
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.press_rmb()
		"br_dash":
			# one hop that lands just short of the dummy: the crash catches it at the edge, the rock rolls into it
			if t < 0.45: P.teleport(Vector3(D.pos.x - 4.2, P.pos.y, D.pos.z))
			P.inp["aim"] = D.pos + Vector3(-1.6, 0.9, 0.0)
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.do_dash()
		"br_exdash":
			P.inp["aim"] = P.pos + Vector3(4.0, 0.0, -4.0)      # (past the dummy's side, clear of the HUD)
			if at(t, dt, 0.45):
				P.teleport(P.pos + Vector3(0, 1.4, 0))
				P.grounded = false
				P.vel = Vector3.ZERO
			if at(t, dt, 0.5): P.do_dash()
		"br_raise":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
		"br_sense":
			P.inp["crouch"] = t > 0.4
		"os_orb":
			if t < 0.4: (K as OstraKit).last_shot_t = K.m.time
			P.inp["fire"] = t > 0.5 and t < 0.54
		"os_orb_hot":
			P.inp["fire"] = t > 1.58 and t < 1.62
		"os_snap":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 4.5, P.pos.y, D.pos.z))
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.press_rmb()
		"os_swap", "os_arrive":
			if at(t, dt, 0.5):
				K.bot_hold["dash"] = 0.42      # Shift held to aim, let go at 0.92 (the local keys would read up)
				P.dashes = P.max_dashes()
				P.do_dash()
		"os_swap_air":
			# lifted off the ground, then a tap: the Trade cast in the air
			if at(t, dt, 0.45):
				P.teleport(P.pos + Vector3(0, 1.6, 0))
				P.grounded = false
				P.vel = Vector3.ZERO
			if at(t, dt, 0.5):
				K.bot_hold["dash"] = 0.0
				P.dashes = P.max_dashes()
				P.do_dash()
		"os_seed":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
		"os_pop":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 2.0): K.use_e()
		"os_empower":
			if at(t, dt, 0.5): (K as OstraKit).add_swell(200.0)
		"br_spine":
			_spine_input(P, D, t, dt)
		"os_well":
			P.lvl = maxi(P.lvl, 6)
			P.inp["aim"] = D.pos + Vector3(1.6, 0.9, 1.4)
			if at(t, dt, 0.5):
				K.cd["x"] = 0.0
				HunterKeys.ult_pressed(P)
			# freed when it opens (1.5s): she walks out west, away from the well
			P.inp["move"] = Vector2(-1, 0) if t > 1.6 and t < 2.6 else Vector2.ZERO
	if P.ammo < 3: P.ammo = int(P.wpn["mag"])

## Basalt Spine: X held from 0.4s at the dummy, the cursor dragged to swing the ridge, let go at 0.72s.
static func _spine_input(P: Hunter, D: Hunter, t: float, dt: float) -> void:
	P.lvl = maxi(P.lvl, 6)
	P.inp["x_down"] = t > 0.38 and t < 0.72
	if t > 0.38:
		var swing := clampf((t - 0.45) / 0.2, 0.0, 1.0)
		P.inp["aim"] = D.pos + Vector3(0.9, 0.9, 0.0) + Vector3(2.2, 0, 2.6) * swing
	if at(t, dt, 0.4):
		P.ak.cd["x"] = 0.0
		HunterKeys.ult_pressed(P)

## Single moments: name -> [the strip move whose input it replays, the time to save the frame at,
## where the hunter starts (x offset from the dummy)].
const SHOTS := {
	"pair_breah_throw_key": ["br_throw", 0.58, -5.0], "pair_breah_throw_hit": ["br_throw", 0.76, -5.0],
	"pair_breah_punch_tele": ["br_punch", 1.2, -2.4], "pair_breah_punch_key": ["br_punch", 1.45, -2.4],
	"pair_breah_punch_hit": ["br_punch", 1.49, -2.4],
	"pair_breah_slam_tele": ["br_slam", 0.85, -3.6], "pair_breah_slam_key": ["br_slam", 1.55, -3.6],
	"pair_breah_slam_hit": ["br_slam", 1.7, -3.6],
	"pair_breah_leap_key": ["br_leap", 1.15, -5.0], "pair_breah_lunge_key": ["br_lunge", 0.98, -5.0],
	"pair_breah_dash_tele": ["br_dash", 0.62, -6.0], "pair_breah_dash_key": ["br_dash", 0.82, -6.0],
	"pair_breah_dash_hit": ["br_dash", 1.12, -6.0], "pair_breah_dash_rock": ["br_dash", 1.3, -6.0],
	"pair_breah_row_tele": ["br_raise", 0.6, -6.0], "pair_breah_row_key": ["br_raise", 0.78, -6.0],
	"pair_breah_row_hit": ["br_raise", 1.2, -6.0],
	"pair_breah_sense_tele": ["br_sense", 1.4, -6.0], "pair_breah_sense_hit": ["br_sense", 0.75, -6.0],
	"pair_ostra_aim_tele": ["os_orb", 0.45, -4.5], "pair_ostra_orb_key": ["os_orb", 0.52, -9.0],
	"pair_ostra_orb_hit": ["os_orb", 0.62, -9.0],
	"pair_ostra_hot_key": ["os_orb_hot", 1.6, -8.0], "pair_ostra_hot_hit": ["os_orb_hot", 1.75, -8.0],
	"pair_ostra_snap_tele": ["os_snap", 0.6, -4.5], "pair_ostra_snap_key": ["os_snap", 0.73, -4.5],
	"pair_ostra_snap_hit": ["os_snap", 1.0, -4.5],
	"pair_ostra_swap_tele": ["os_swap", 0.85, -4.5], "pair_ostra_swap_key": ["os_swap", 1.75, -4.5],
	"pair_ostra_swap_hit": ["os_arrive", 2.76, -4.5],
	"pair_ostra_seed_tele": ["os_seed", 1.3, -4.5], "pair_ostra_seed_key": ["os_pop", 1.95, -4.5],
	"pair_ostra_seed_hit": ["os_pop", 2.1, -4.5],
	"pair_ostra_swollen_key": ["os_empower", 0.8, -4.2],
	"pair_ostra_seed_full": ["os_seed", 5.2, -4.5], "pair_ostra_seed_collapse": ["os_seed", 7.56, -4.5],
	"pair_breah_spine_tele": ["br_spine", 0.58, -3.0], "pair_breah_spine_key": ["br_spine", 0.82, -3.0],
	"pair_breah_spine_hit": ["br_spine", 1.45, -3.0],
	"pair_ostra_well_tele": ["os_well", 1.0, -2.5], "pair_ostra_well_key": ["os_well", 1.56, -2.5],
	"pair_ostra_well_hit": ["os_well", 2.5, -2.5],
}

## A still moment; returns the time to save the frame at.
static func tick(A: Arena, P: Hunter, D: Hunter, t: float, dt: float, w: String) -> float:
	var who := "ostra" if "ostra" in w else "dolm"
	var sh: Array = SHOTS.get(w, [])
	var at_t := 1.2
	if t < 0.05 and P.arch != who:
		A.set_arch(who)
		A.set_kin("puddlet")
		if not w.begins_with("pair_card"):
			P.teleport(D.pos + Vector3(float(sh[2]) if not sh.is_empty() else -4.2, 0, 0))
			A.home = P.pos
			D.max_hp = 900.0
			D.hp = D.max_hp
			A.m.set_meta("zoom_hold", 0.5)
			if A.m.cam: A.m.cam.zoom = 0.5
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	var K: ArchKit = P.ak
	stage(A.m, t)
	if not sh.is_empty():
		var mv := String(sh[0])
		if not (mv in ["br_punch", "br_slam", "br_dash"] and t < 0.45):
			trigger(P, D, mv, t, dt)      # (the strip's own start teleport is skipped; the shot keeps its start)
		if w == "pair_breah_row_hit" and t > 1.0:
			_climb(P, K as DolmKit)
		return float(sh[1])
	match w:
		"pair_card_dolm", "pair_card_ostra":
			if at(t, dt, 0.3):
				A.toggle_card()
				ArenaDemo._shot_later(A, 0.7)
			return 99.0
		"pair_dolm_rocks":
			if at(t, dt, 0.3):
				K.cd["e"] = 0.0
				K.use_e()
			at_t = 0.9
		"pair_dolm_pay":
			if at(t, dt, 0.3):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 0.8):
				P.teleport(D.pos + Vector3(-3.0, 0, 0))
				ArenaDemo._aim(P, D)
			P.inp["fire"] = t > 0.9 and t < 1.9
			if int(K.get("launch_pay")) > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
			at_t = float(A.get_meta("pay_at", 9.0)) + 0.1
		"pair_dolm_slam":
			if at(t, dt, 0.3):
				K.ch_rmb = float(K.rmb_charges())
				K.bot_hold["rmb"] = 0.9
				K.press_rmb()
			at_t = 1.35
		"pair_ostra_orb":
			P.inp["fire"] = t > 0.3 and t < 0.36
			at_t = 0.6
		"pair_ostra_fan":
			if at(t, dt, 0.3):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.press_rmb()
			at_t = 0.5
		"pair_ostra_trade":
			if at(t, dt, 0.3):
				P.dashes = P.max_dashes()
				P.do_dash()
			at_t = 1.6
		"pair_ostra_pay":
			if at(t, dt, 0.3):
				K.cd["e"] = 0.0
				K.use_e()
			if int(K.get("collapses")) > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
			at_t = float(A.get_meta("pay_at", 9.0)) + 0.3
	return at_t

## Puts Tarek on top of the first rock of her row (verticality, for the row's last frame).
static func _climb(P: Hunter, K: DolmKit) -> void:
	var rs := K.my_rocks()
	if rs.size() < 3 or P.has_meta("climbed"):
		return
	P.set_meta("climbed", true)
	var w: Dictionary = rs[0]
	var mid := K.rock_mid(w)
	P.teleport(Vector3(mid.x, mid.y + float(w["top"]) + 0.05, mid.z))
	P.grounded = false
	P.vel = Vector3.ZERO
