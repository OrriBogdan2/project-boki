class_name ArenaDemoPair
extends RefCounted
## Arena screenshot demos for Dredge and Linwick (id ashwick) (ArenaDemo hands over every "pr_*" demo and the two
## kit cards): --arena-demo=pr_<move> makes a strip of frames of one kit move (the ability, its
## anticipation, impact and follow-through), pr_payoff_dr / pr_payoff_as the payoff moments.
##   moves: dr_throw dr_reel dr_anchor dr_barge as_lance as_shot as_leap as_cloak

const MOVES := {
	"dr_throw": ["dredge", "shotgun", [0.5, 0.58, 0.66, 0.74, 0.84, 1.0]],
	"dr_reel": ["dredge", "shotgun", [0.5, 0.7, 0.9, 1.1, 1.3, 1.6]],
	"dr_anchor": ["dredge", "shotgun", [0.5, 0.62, 0.72, 0.76, 0.84, 1.0, 1.3]],
	"dr_barge": ["dredge", "shotgun", [0.5, 0.58, 0.66, 0.72, 0.8, 1.0]],
	"as_lance": ["ashwick", "flamethrower", [0.5, 0.6, 0.75, 1.0, 1.3, 1.7]],
	"as_shot": ["ashwick", "flamethrower", [0.5, 0.58, 0.64, 0.7, 0.8, 1.0]],
	"as_leap": ["ashwick", "flamethrower", [0.5, 0.56, 0.62, 0.7, 0.78, 1.0]],
	"as_cloak": ["ashwick", "flamethrower", [0.5, 0.62, 0.7, 0.8, 1.0, 1.3]],
}

## Returns the time to save the single frame at (99: not a single-frame demo).
static func tick(A: Arena, w: String, t: float, dt: float) -> float:
	var m := A.m
	var P: Hunter = m.player
	var D: Hunter = A.dummies[0]["h"]
	if w in ["card_dredge", "card_ashwick"]:
		if t < 0.05:
			A.set_arch(w.substr(5))
			A.set_kin("cindle")
		if ArenaDemo._at(t, dt, 0.3):
			A.toggle_card()
			ArenaDemo._shot_later(A, 0.7)
		return 99.0
	var key := w.substr(3)
	var payoff := key.begins_with("payoff_")
	var mv := key.substr(7) if payoff else key
	var spec: Array = MOVES.get(mv, MOVES["dr_throw"])
	if payoff:
		spec = ["dredge", "shotgun", []] if mv == "dr" else ["ashwick", "flamethrower", []]
	if t < 0.05:
		if P.arch != String(spec[0]) or P.wid != String(spec[1]): A.set_arch(String(spec[0]), String(spec[1]))
		A.set_kin("")
		P.teleport(D.pos + Vector3(-4.0, 0, 0))
		A.home = P.pos
		if m.cam: m.cam.zoom = 0.42 if not payoff else 0.6
		m.set_meta("zoom_hold", 0.42 if not payoff else 0.6)
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = float(P.ak.rmb_charges()); P.ak.cd["e"] = 0.0
	if payoff:
		return _payoff(A, P, D, mv, t, dt)
	var go := 0.5
	match mv:
		"dr_throw", "dr_reel":
			if ArenaDemo._at(t, dt, go): P.ak.press_rmb()
		"dr_anchor":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(2.0, 0, 0)); P.ak.use_e()
		"dr_barge", "as_leap":
			if ArenaDemo._at(t, dt, go): P.dashes = P.max_dashes(); P.do_dash()
		"as_lance":
			P.inp["fire"] = t > go and t < 1.9
		"as_shot":
			if ArenaDemo._at(t, dt, go): P.ak.press_rmb()
		"as_cloak":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(3.0, 0, 0)); P.ak.use_e()
	var times: Array = spec[2]
	for i in times.size():
		if ArenaDemo._at(t, dt, float(times[i])):
			var last := i == times.size() - 1
			m.get_tree().process_frame.connect(func(): ArenaDemo._grab(A, P, last), CONNECT_ONE_SHOT)
	return 99.0

static func _payoff(A: Arena, P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> float:
	if mv == "dr":
		if ArenaDemo._at(t, dt, 0.4): P.ak.press_rmb()
		var K := P.ak as DredgeKit
		if K.arrivals > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
		return float(A.get_meta("pay_at", 9.0)) + 0.1
	P.inp["fire"] = t > 0.3
	var K2 := P.ak as AshwickKit
	if K2.upgrades > 0 and not A.has_meta("pay_at"): A.set_meta("pay_at", t)
	return float(A.get_meta("pay_at", 9.0)) + 0.1
