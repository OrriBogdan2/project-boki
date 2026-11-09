class_name ArenaDemoPair
extends RefCounted
## Arena screenshot demos for Dredge and Cinder (id ashwick) (ArenaDemo hands over every "pr_*" demo and
## the two kit cards):
##   --arena-demo=pr_<move>          a strip of frames of one kit move (anticipation, release, follow-through,
##                                   recovery), cropped round the hunter
##   --arena-demo=pr_f_<move>@<t>    the same scene, the whole view at <t> seconds at the default gameplay zoom
##                                   (telegraph, key frame, impact); pr_c_<move>@<t> the same as a close-up
##   --arena-demo=pr_payoff_dr / pr_payoff_as   the payoff moments
##   moves: dr_shot dr_throw dr_reel dr_anchor dr_dive dr_lunge dr_pounce dr_flex
##          as_lance as_sweep as_shot as_leap lw_hop as_cloak lw_stoke lw_stoke_lance
##          lw_jet dr_blast (the X ultimates), dr_rock (the Abyssal Hand hauling a foe over a rock)
## A move's optional fourth entry is its strip zoom (the hose and the rope need the wider gameplay view).

const MOVES := {
	"dr_shot": ["dredge", "shotgun", [0.5, 0.53, 0.56, 0.62, 0.7, 0.86]],
	"dr_throw": ["dredge", "shotgun", [0.5, 0.58, 0.64, 0.72, 0.84, 1.0]],
	"dr_reel": ["dredge", "shotgun", [0.9, 1.05, 1.2, 1.35, 1.5, 1.7]],
	"dr_rock": ["dredge", "shotgun", [0.55, 0.75, 0.95, 1.15, 1.4, 1.7], 1.0],
	"dr_anchor": ["dredge", "shotgun", [0.52, 0.66, 0.8, 0.885, 1.0], 1.0],
	"dr_dive": ["dredge", "shotgun", [0.5, 0.56, 0.64, 0.72, 0.85, 1.2]],
	"dr_lunge": ["dredge", "shotgun", [0.5, 0.535, 0.58, 0.63, 0.75]],
	"dr_barge_run": ["dredge", "shotgun", [0.53, 0.6, 0.98, 1.05, 1.43, 1.5], 1.0],
	"dr_pounce": ["dredge", "shotgun", [0.5, 0.54, 0.6, 0.66, 0.8]],
	"dr_flex": ["dredge", "shotgun", [0.5, 0.6, 0.68, 0.8, 1.0]],
	"as_lance": ["ashwick", "flamethrower", [0.5, 0.6, 0.7, 0.78, 0.9, 1.2], 1.0],
	"as_sweep": ["ashwick", "flamethrower", [0.9, 1.0, 1.1, 1.2, 1.3, 1.45], 1.0],
	"as_shot": ["ashwick", "flamethrower", [0.5, 0.65, 0.92, 0.96, 1.05, 1.3]],
	"as_leap": ["ashwick", "flamethrower", [0.5, 0.56, 0.66, 0.8, 0.95]],
	"lw_hop": ["ashwick", "flamethrower", [0.5, 0.55, 0.62, 0.78, 1.0], 1.0],
	"as_cloak": ["ashwick", "flamethrower", [0.5, 0.62, 0.7, 0.78, 1.0, 1.35]],
	"lw_stoke": ["ashwick", "flamethrower", [0.5, 0.6, 0.7, 0.8, 1.0]],
	"lw_stoke_lance": ["ashwick", "flamethrower", [0.98, 1.06, 1.12, 1.2, 1.32, 1.5], 1.0],
	"lw_jet": ["ashwick", "flamethrower", [0.5, 0.56, 0.62, 1.1, 1.92, 2.15]],
	"dr_blast": ["dredge", "shotgun", [0.5, 1.0, 1.55, 1.62, 2.22, 2.6]],
}

const GAME_ZOOM := 1.0         # the camera's default gameplay zoom
# the scene runs slowed, so a slow render frame steps only a sliver of the match and the saved frame lands on
# the moment it was asked for (the shot is saved two frames after its time comes)
const DEMO_TIME_SCALE := 0.3

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
	# the scene runs on the match's own clock: a first-use hitch (a shader compiling) can jump the frame
	# clock past a whole move while the match only steps part of it, and the shot would miss the moment
	if not A.has_meta("pr_t0"): A.set_meta("pr_t0", float(m.time) - t)
	var game_t := float(m.time) - float(A.get_meta("pr_t0"))
	var game_dt := game_t - float(A.get_meta("pr_prev", game_t - dt))
	A.set_meta("pr_prev", game_t)
	var at := _tick_move(A, w, game_t, game_dt)
	return at if at >= 99.0 else t - game_t + at

## One move's scene on the match clock `t`; returns the time to save the single frame at (99: none).
static func _tick_move(A: Arena, w: String, t: float, dt: float) -> float:
	var m := A.m
	var P: Hunter = m.player
	var D: Hunter = A.dummies[0]["h"]
	var key := w.substr(3)
	var payoff := key.begins_with("payoff_")
	var close := key.begins_with("c_")
	var full := key.begins_with("f_") or close
	var shot_t := 99.0
	if full:
		var parts := key.substr(2).split("@")
		key = parts[0]
		shot_t = float(parts[1]) if parts.size() > 1 else 1.0
	var mv := key.substr(7) if payoff else key
	var spec: Array = MOVES.get(mv, MOVES["dr_throw"])
	if payoff:
		spec = ["dredge", "shotgun", []] if mv == "dr" else ["ashwick", "flamethrower", []]
	var zoom := 0.62 if close or not full else GAME_ZOOM
	if not full and spec.size() > 3: zoom = float(spec[3])
	if t < 0.05:
		Engine.time_scale = DEMO_TIME_SCALE
		_warm_looks(m, D.pos)
		if P.arch != String(spec[0]) or P.wid != String(spec[1]): A.set_arch(String(spec[0]), String(spec[1]))
		A.set_kin("")
		P.teleport(D.pos + Vector3(-4.0, 0, 0))
		A.home = P.pos
		if m.cam: m.cam.zoom = zoom
		m.set_meta("zoom_hold", zoom)
	ArenaDemo._aim(P, D)
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp
	P.ak.cd["rmb"] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())
	P.ak.cd["e"] = 0.0
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
		"dr_rock":
			if t < go: _behind_rock(A, D)
			if ArenaDemo._at(t, dt, go): P.ak.press_rmb()
		"dr_throw", "dr_reel":
			if t < go: D.teleport(A.home + Vector3(8.0, 0, 0))
			if ArenaDemo._at(t, dt, go): P.ak.press_rmb()
		"dr_anchor":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(3.2, 0, 0))
				P.ak.use_e()
		"dr_dive":
			if ArenaDemo._at(t, dt, go - 0.2):
				D.teleport(A.home + Vector3(1.6, 0, 0))
				P.teleport(A.home + Vector3(0, 6.0, 0))
				P.grounded = false
				P.vel = Vector3.ZERO
			if t > go - 0.2 and t < go:
				P.vel = Vector3.ZERO
				P.pos.y = A.home.y + 6.0
			if ArenaDemo._at(t, dt, go): P.ak.use_e()
		"dr_barge_run":
			# three barges in a row, a beat apart
			if t < go: D.teleport(A.home + Vector3(3.0, 0, 3.5))
			P.inp["aim"] = A.home + Vector3(14.0, 0.9, 0)
			if ArenaDemo._at(t, dt, go): P.dashes = P.max_dashes()
			for k in 3:
				if ArenaDemo._at(t, dt, go + 0.45 * k): P.do_dash()
		"dr_lunge", "as_leap":
			# Cinder's ram runs free (footage 0159: the lunge, then upright at once); the lunge hits the dummy
			var gap := 12.0 if mv == "as_leap" else 3.6
			if t < go: D.teleport(A.home + Vector3(gap, 0, 0))
			if t < go and mv == "as_leap":
				for e in A.dummies:
					if e["h"] != D: (e["h"] as Hunter).teleport(A.home + Vector3(0, 0, 14.0))
			if ArenaDemo._at(t, dt, go):
				P.dashes = P.max_dashes()
				P.do_dash()
		"dr_pounce", "lw_hop":
			# toward the middle of the island, so the hop never carries him off the edge into the void
			if t < go: D.teleport(A.home + Vector3(12.0, 0, 0.5))
			if ArenaDemo._at(t, dt, go - 0.15):
				P.vel.y = 11.0
				P.grounded = false
			if ArenaDemo._at(t, dt, go):
				P.ex_cd = 0.0
				P.do_dash()
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
			if t < go: D.teleport(A.home + Vector3(7.0, 0, 0))
			if ArenaDemo._at(t, dt, go):
				# held 0.42s (the lane), then released
				P.ak.bot_hold["rmb"] = 0.42
				P.ak.press_rmb()
		"as_cloak":
			if ArenaDemo._at(t, dt, go):
				D.teleport(P.pos + Vector3(3.6, 0, 0))
				P.ak.use_e()
		"lw_jet":
			# fly past the dummy, then steer off to the side so the carpet curves
			if t < go: D.teleport(A.home + Vector3(6.0, 0, 0.4))
			if t > 1.0: P.inp["aim"] = P.pos + Vector3(4.0, 0.9, 6.0)
			if ArenaDemo._at(t, dt, go): _ult(P)
		"dr_blast":
			if t <= go: P.teleport(D.pos - Vector3(1.8, 0, 0))       # point blank, where every slug lands
			if ArenaDemo._at(t, dt, go): _ult(P)
		"lw_stoke_lance":
			# a Flashover mid-roar: the fist pump plays over the braced hose
			P.inp["fire"] = t > go and t < 1.8
			if t < go: D.teleport(A.home + Vector3(3.5, 0, 0))
			if ArenaDemo._at(t, dt, go + 0.45):
				(P.ak as AshwickKit).stoke(D)
				(P.ak as AshwickKit).stoke(D)
		"lw_stoke":
			if ArenaDemo._at(t, dt, go):
				var K := P.ak as AshwickKit
				K.stoke(D)
				K.stoke(D)

## Shows each effect shader once, tiny, before the move, so their first-use compile hitch can't jump the clock
## of the frames that matter.
static func _warm_looks(m: Node, at: Vector3) -> void:
	var fx := LDFx.of(m)
	fx.anchor_drop(at, 0.0, 0.05)
	fx.orb(at, Color.BLACK, Color.BLACK, 0.01, 0.05)
	fx.wave(at, 0.01, Color.BLACK, 0.05)

## Puts the dummy behind the nearest rock or prop round the hunter, on the far side along the same line,
## so the Abyssal Hand has to fly over it and drag the dummy back across it.
static func _behind_rock(A: Arena, D: Hunter) -> void:
	var W = A.m.world
	for ring in range(3, 10):
		for k in 24:
			var ang := TAU * float(k) / 24.0
			var q := A.home + Vector3(cos(ang), 0, sin(ang)) * float(ring)
			if W.occupy(q.x, q.z, 0.3, A.home.y, false) == 0.0 or W.is_void(q.x, q.z):
				continue
			var mid := _rock_middle(W, q, A.home.y)
			var dir := Vector3(mid.x - A.home.x, 0, mid.z - A.home.z).normalized()
			var spot := mid + dir * 3.5
			if not W.is_void(spot.x, spot.z) and W.occupy(spot.x, spot.z, 0.4, A.home.y, false) == 0.0:
				D.teleport(Vector3(spot.x, A.home.y, spot.z))
				return

## The middle of the blocked cells round q (a rock's footprint).
static func _rock_middle(W, q: Vector3, y: float) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for ix in range(-6, 7):
		for iz in range(-6, 7):
			var p := q + Vector3(ix, 0, iz) * 0.25
			if W.occupy(p.x, p.z, 0.05, y, false) != 0.0:
				sum += p
				n += 1
	return sum / maxf(1.0, n)

## X at level 6 with the cooldown cleared.
static func _ult(P: Hunter) -> void:
	P.lvl = maxi(P.lvl, 6)
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)

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
