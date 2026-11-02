class_name ArenaDemoPair
extends RefCounted
## Arena screenshot demos for Dredge and Linwick (id ashwick) (ArenaDemo hands over every "pr_*" demo and
## the two kit cards):
##   --arena-demo=pr_<move>          a strip of frames of one kit move (anticipation, release, follow-through,
##                                   recovery), cropped round the hunter
##   --arena-demo=pr_f_<move>@<t>    the same scene, the whole view at <t> seconds (telegraph, key frame, impact)
##   --arena-demo=pr_payoff_dr / pr_payoff_as   the payoff moments
##   moves: dr_shot dr_throw dr_reel dr_anchor dr_dive dr_barge dr_hop dr_flex
##          as_lance as_sweep as_shot as_leap lw_hop as_cloak lw_stoke

const MOVES := {
	"dr_shot": ["dredge", "shotgun", [0.5, 0.53, 0.56, 0.62, 0.7, 0.86]],
	"dr_throw": ["dredge", "shotgun", [0.5, 0.58, 0.64, 0.72, 0.84, 1.0]],
	"dr_reel": ["dredge", "shotgun", [0.9, 1.05, 1.2, 1.35, 1.5, 1.7]],
	"dr_anchor": ["dredge", "shotgun", [0.5, 0.64, 0.76, 0.88, 1.1, 1.4]],
	"dr_dive": ["dredge", "shotgun", [0.5, 0.56, 0.64, 0.72, 0.85, 1.2]],
	"dr_barge": ["dredge", "shotgun", [0.5, 0.56, 0.66, 0.84, 0.94, 1.15]],
	"dr_hop": ["dredge", "shotgun", [0.5, 0.56, 0.66, 0.78, 0.92, 1.1]],
	"dr_flex": ["dredge", "shotgun", [0.5, 0.6, 0.68, 0.8, 1.0]],
	"as_lance": ["ashwick", "flamethrower", [0.5, 0.6, 0.7, 0.85, 1.2, 1.7]],
	"as_sweep": ["ashwick", "flamethrower", [0.9, 1.0, 1.1, 1.2, 1.3, 1.45]],
	"as_shot": ["ashwick", "flamethrower", [0.5, 0.65, 0.92, 0.96, 1.05, 1.3]],
	"as_leap": ["ashwick", "flamethrower", [0.5, 0.55, 0.62, 0.72, 0.85, 1.1]],
	"lw_hop": ["ashwick", "flamethrower", [0.5, 0.55, 0.62, 0.72, 0.86, 1.05]],
	"as_cloak": ["ashwick", "flamethrower", [0.5, 0.62, 0.7, 0.78, 1.0, 1.35]],
	"lw_stoke": ["ashwick", "flamethrower", [0.5, 0.6, 0.7, 0.8, 1.0]],
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
	var full := key.begins_with("f_")
	var shot_t := 99.0
	if full:
		var parts := key.substr(2).split("@")
		key = parts[0]
		shot_t = float(parts[1]) if parts.size() > 1 else 1.0
	var mv := key.substr(7) if payoff else key
	var spec: Array = MOVES.get(mv, MOVES["dr_throw"])
	if payoff:
		spec = ["dredge", "shotgun", []] if mv == "dr" else ["ashwick", "flamethrower", []]
	var zoom := 0.62 if not full else 0.85
	if t < 0.05:
		if P.arch != String(spec[0]) or P.wid != String(spec[1]): A.set_arch(String(spec[0]), String(spec[1]))
		A.set_kin("")
		P.teleport(D.pos + Vector3(-4.0, 0, 0))
		A.home = P.pos
		if m.cam: m.cam.zoom = zoom
		m.set_meta("zoom_hold", zoom)
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp
	P.ak.cd["rmb"] = 0.0; P.ak.ch_rmb = float(P.ak.rmb_charges()); P.ak.cd["e"] = 0.0
	if payoff:
		return _payoff(A, P, D, mv, t, dt)
	_drive(A, P, D, mv, t, dt)
	if full:
		return shot_t
	var times: Array = spec[2]
	for i in times.size():
		if ArenaDemo._at(t, dt, float(times[i])):
			var last := i == times.size() - 1
			m.get_tree().process_frame.connect(func(): ArenaDemo._grab(A, P, last), CONNECT_ONE_SHOT)
	return 99.0

## Plays one move's scene: the input at `go` (0.5s), the dummy placed where the ability reads best.
static func _drive(A: Arena, P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var go := 0.5
	match mv:
		"dr_shot":
			P.inp["fire"] = t > go and t < go + 0.08
		"dr_throw", "dr_reel":
			if t < go: D.teleport(A.home + Vector3(8.0, 0, 0))
			if ArenaDemo._at(t, dt, go): P.ak.press_rmb()
		"dr_anchor":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(3.2, 0, 0)); P.ak.use_e()
		"dr_dive":
			if ArenaDemo._at(t, dt, go - 0.2):
				D.teleport(A.home + Vector3(1.6, 0, 0)); P.teleport(A.home + Vector3(0, 6.0, 0)); P.grounded = false; P.vel = Vector3.ZERO
			if t > go - 0.2 and t < go: P.vel = Vector3.ZERO; P.pos.y = A.home.y + 6.0
			if ArenaDemo._at(t, dt, go): P.ak.use_e()
		"dr_barge", "as_leap":
			if t < go: D.teleport(A.home + Vector3(3.6, 0, 0))
			if ArenaDemo._at(t, dt, go): P.dashes = P.max_dashes(); P.do_dash()
		"dr_hop", "lw_hop":
			if t < go: D.teleport(A.home + Vector3(0, 0, 7.0))
			if ArenaDemo._at(t, dt, go - 0.15): P.vel.y = 11.0; P.grounded = false
			if ArenaDemo._at(t, dt, go): P.ex_cd = 0.0; P.do_dash()
		"dr_flex":
			if ArenaDemo._at(t, dt, go): (P.ak as DredgeKit).add_stack(1)
		"as_lance":
			P.inp["fire"] = t > go and t < 1.9
		"as_sweep":
			# the hose swept from the dummy round to the side: the stream bends behind the nozzle
			P.inp["fire"] = t > go and t < 1.9
			if t > 0.9:
				var a := clampf((t - 0.9) * 2.2, 0.0, 1.4)
				P.inp["aim"] = P.pos + Vector3(cos(a) * 5.0, 0.9, -sin(a) * 5.0)
		"as_shot":
			if t < go: D.teleport(A.home + Vector3(9.0, 0, 0))
			if ArenaDemo._at(t, dt, go):
				P.ak.bot_hold["rmb"] = 0.42; P.ak.press_rmb()      # held 0.42s (the lane), then released
		"as_cloak":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(3.6, 0, 0)); P.ak.use_e()
		"lw_stoke":
			if ArenaDemo._at(t, dt, go):
				var K := P.ak as AshwickKit
				K.stoke(D); K.stoke(D)

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
