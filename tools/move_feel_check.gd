extends RefCounted
## --move-feel-check: scripted inputs, measured responses. Every number below is compared with the
## target in docs/MOVEMENT_FEEL.md (each target names its source). It drives the real match step
## (Match.step, and Match._process for the end-to-end input/render path), never touches the save.
##
## Prints one "MFEEL <key> = <value> <unit>  target <op> <target>  ok|FAIL" line per measurement and
## "MOVE FEEL CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var w: World
var P: Hunter
var flat := Vector3.ZERO        # a flat open spot (6m clear all round)
const SOURCE_JUMP_V := 7.5      # m/s, [game data] JumpZVelocity 750 uu/s
const DT := 1.0 / 60.0
const WARDEN_SKIN := preload("res://tools/warden_skin.gd")
## The framing is measured on one fixed body: the plain medium hunter (no Warden's shape or class size, so it
## doesn't move when the default medium Warden's proportions do), holding the medium class's default rifle.
const REF_WEAPON := "quill_rifle"
## Heroes whose framing is printed beside it (the tallest on the branch): their feet must stay in frame too.
const FRAME_HEROES := ["bulwark", "gunslinger"]
const SPAN_SKIP := ["Glider", "Gun", "Shield"]

## key -> [op, target, unit, note]. Ops: "<=", ">=", "~" (within tol given as [lo, hi]).
const T := {
	"ground_input_frames":     ["<=", 1.0, "frames", "press to velocity change, same sim step"],
	"ground_t95":              ["<=", 0.10, "s", "[game data] MaxAcceleration 4700-5400 uu/s2: top speed in ~0.09s"],
	"ground_stop_t":           ["~", [0.12, 0.25], "s", "[game data] braking 2220 uu/s2, friction 1 x2: SV ~0.18s"],
	"ground_stop_dist":        ["~", [0.2, 0.5], "m", "[game data] SV slides ~0.38-0.49m"],
	"ground_reverse_t":        ["<=", 0.19, "s", "[game data] a full reverse at 47-54 m/s2"],
	"ground_turn90_t":         ["<=", 0.13, "s", "[game data] a 90-degree turn at 47-54 m/s2"],
	"speed_light":             ["~", [4.4, 4.9], "m/s", "[game data] per-hunter MoveSpeed 445-485 uu/s (content/rules/hunter_move.json)"],
	"speed_medium":            ["~", [4.4, 4.9], "m/s", "[game data] per hunter"],
	"speed_heavy":             ["~", [4.4, 4.9], "m/s", "[game data] per hunter"],
	"jump_input_frames":       ["<=", 1.0, "frames", "press to lift-off, same sim step"],
	"jump_apex":               ["~", [1.2, 1.6], "m", "[game data] 1.9m; under 1.6 so jump + mantle stays below 4 terraces"],
	"jump_speed_vs_source":    ["~", [0.85, 1.0], "x", "[game data] JumpZVelocity 7.5; ours 6.8 (terraces)"],
	"jump_airtime":            ["~", [0.85, 1.05], "s", "[game data] JumpZVelocity 750 at gravity 1470 uu/s2: 1.02s"],
	"air_carry_m":             [">=", 3.0, "m", "[game data] FallingLateralFriction 0.375: the run-up carries"],
	"air_reverse_dv":          ["~", [0.5, 1.1], "m/s", "[game data] AirControl 0.015: a jump keeps its run-up"],
	"dash_exit_run":           ["~", [0.95, 1.05], "x", "[game data] no hard stop: hands over at run speed"],
	"dash_exit_slide_m":       ["~", [0.2, 0.5], "m", "[game data] then the walking stop"],
	"coyote_frames":           [">=", 6.0, "frames", "FeelConfig coyote_time 0.1s (walked off a rim over the void)"],
	"jump_buffer_frames":      [">=", 7.0, "frames", "FeelConfig jump_buffer 0.12s (7 steps)"],
	"freefall_1s_depth":       ["~", [6.8, 8.0], "m", "[game data] gravity 1470 uu/s2, cap 1200 uu/s: 7.1m"],
	"abyss_fall_vy_deep":      ["~", [10.0, 10.8], "m/s", "[game data] AbyssFallSlowSpeedLimit 12 to 10 m/s"],
	"abyss_fall_t":            [">=", 1.8, "s", "[game data] off the lip to AbyssHeight (17.5m) in ~2s"],
	"glide_open_press_frames": ["<=", 1.0, "frames", "[wiki/guide] hold jump in the air to glide; a second press opens at once"],
	"glide_open_hold_s":       ["<=", 0.12, "s", "tap/hold split for Space; a tap is ~0.1s"],
	"glide_open_button_frames": ["<=", 1.0, "frames", "dedicated glide button: no tap/hold ambiguity"],
	"glide_catch_t":           ["<=", 0.20, "s", "glider opens 'instantly' on input; brakes a terminal fall to sink rate"],
	"glide_speed":             ["~", [4.5, 5.5], "m/s", "[game data] MaxGlide 500 uu/s +-10% (item 163)"],
	"glide_sink":              ["~", [1.2, 1.6], "m/s", "floatier than [spec] 2-4 eyeball / [est] 2.2 (owner: sank too fast)"],
	"glide_turn90_t":          ["~", [0.3, 0.6], "s", "[game data] the glide force: a turn has inertia (item 163)"],
	"glide_reverse_t":         ["~", [0.45, 0.8], "s", "[game data] the same force brakes a reversal (item 163)"],
	"glide_brake_ratio":       ["<=", 0.80, "x", "steering against heading brakes momentum (speed vs letting go)"],
	"glide_high_sink":         ["~", [3.3, 3.6], "m/s", "[game data] GlideDownwardForce: above 8.5m"],
	"glide_swoop_speed":       [">=", 9.0, "m/s", "[game data] SwoopSpeedTransferRatio 2.5: far over cruise"],
	"glide_swoop_faded":       ["<=", 10.0, "m/s", "[game data] SwoopSpeedFadeTime 1.5s, then the usual bleed"],
	"dive_vy":                 ["~", [32.0, 32.5], "m/s", "[game data] GlideDiveZTargetSpeed -3250 uu/s, crouch held"],
	"dive_vy_t":               ["~", [0.6, 0.9], "s", "[game data] GlideDiveZForceMax 350,000 / Mass 100 = 35 m/s^2"],
	"dive_steer_ratio":        ["~", [0.2, 0.3], "x", "[game data] GlideDiveXYForceMultiplier 0.25 of the glide steer"],
	"dive_cancel_h":           ["~", [2.9, 3.5], "m", "[game data] GlideDiveCancelDistance 350 uu, the glide catches"],
	"dive_timeout_s":          ["~", [9.9, 10.1], "s", "[game data] GlideDiveTimeout 10 s of holding ends the plunge"],
	"dive_swoop_speed":        ["~", [12.0, 15.0], "m/s", "[game data] swoop 2.5x the fall, capped at GLIDE_MAX"],
	"dive_land_vy":            ["<=", 4.0, "m/s", "[game data] held down: catches 3.5 m up, lands at the sink"],
	"dive_release_glide_t":    ["~", [0.3, 0.7], "s", "[game data] let go high up: the usual catch, back gliding"],
	"dashglide_open_speed":    [">=", 12.0, "m/s", "[wiki] gliding right after a lateral impulse keeps momentum and increases glide speed"],
	"dashglide_1s_speed":      [">=", 10.5, "m/s", "[wiki] momentum preserved while gliding"],
	"dashglide_2s_speed":      [">=", 9.0, "m/s", "[wiki] momentum preserved while gliding"],
	"dashglide_reopen_frames": ["<=", 1.0, "frames", "glider is back the step the dash ends while glide is held"],
	"reglide_frames":          ["<=", 1.0, "frames", "glide-cancel then re-hold reopens at once"],
	"abyss_lift_t":            ["<=", 1.0, "s", "[footage] back at island level (balloon line, 0.5m under the lip) ~1s after opening 4m deep"],
	"abyss_bounce_m":          [">=", 1.5, "m", "[est] a bouncy lift from 6m deep"],
	"abyss_kill_depth":        ["~", [17.0, 18.0], "m", "[game data] AbyssHeight -1750 uu: 17.5m under ground level"],
	"abyss_recover_depth":     [">=", 15.0, "m", "deepest a terminal fall can still glide out"],
	"abyss_tint_lip":          ["<=", 0.02, "", "no tint gliding at island level"],
	"abyss_tint_half":         [">=", 0.6, "", "[footage] tint deepens as you sink; owner: unmistakable early"],
	"abyss_tint_end":          [">=", 0.95, "", "full dark/red right before the point of no return"],
	"abyss_tint_rising":       ["<=", 0.02, "", "[footage D1] off while the glider lifts you back up, even below the lip"],
	"feather_toggle_frames":   ["<=", 1.0, "frames", "feathering: glider closes and reopens the step you let go / press again, no toggle penalty"],
	"feather_hold_m":          [">=", 0.0, "m", "holding glide over the abyss until the heat runs out (reference)"],
	"feather_m":               [">=", 0.0, "m", "tap-feathering over the abyss (lift taps, coast the gaps) until the heat runs out"],
	"feather_gain":            [">=", 1.15, "x", "[est] skilled feathering covers more ground than holding when heat is the limit"],
	"ledge_rise_t":            ["<=", 0.35, "s", "[footage] touching ground above you floats you up fast (~0.8s from a full second deep); here a 1.6m wall from a jump"],
	"ledge_rise_peak_m":       [">=", 0.2, "m", "no jump: you clear the lip with a small pop (height over the top)"],
	"ledge_fling_early_m":     [">=", 0.0, "m", "a jump as the rise starts: a weak fling (distance onto the top, reference)"],
	"ledge_fling_timed_m":     [">=", 1.5, "m", "[est] a jump in the window near the top: a real fling onto the top"],
	"ledge_fling_timed_up_m":  [">=", 0.7, "m", "[est] ...and it goes higher than topping out with no jump"],
	"ledge_fling_gain":        [">=", 1.5, "x", "[est] timed fling distance vs no jump: a well-timed one is clearly rewarding"],
	"ledge_window_s":          [">=", 0.08, "s", "[est] the fling window lasts long enough to hit on purpose (~5+ steps)"],
	"updraft_rise_t":          ["<=", 0.30, "s", "[est] updrafts feel powerful: 8 m/s climb within 0.3s"],
	"drop_dive_vy_t":          ["<=", 0.40, "s", "[est] punchy skydive: 90% of dive speed"],
	"drop_dive_steer_t":       ["<=", 0.30, "s", "[est] responsive steering in the dive: 90% of commanded speed"],
	"drop_deploy_frames":      ["<=", 1.0, "frames", "press jump: glider opens the same step"],
	"drop_deploy_settle_t":    ["<=", 0.30, "s", "[est] canopy catch to drop sink rate"],
	"drop_glide_steer_t":      ["<=", 0.30, "s", "[est] responsive steering under the canopy"],
	"drop_land_dead_frames":   ["<=", 1.0, "frames", "no input dead time on landing"],
	"land_dead_frames":        ["<=", 1.0, "frames", "no input dead time on landing"],
	"land_squash":             [">=", 0.05, "", "brief squash on a landing that reads"],
	"e2e_input_frames":        ["<=", 1.0, "frames", "key press to sim velocity, same rendered frame"],
	"e2e_render_frames":       ["<=", 1.0, "frames", "key press to the model moving on screen"],
	"render_lag_m":            ["<=", 0.03, "m", "local player drawn where the sim is (no interpolation lag)"],
	"cam_lag_m":               ["<=", 0.40, "m", "[footage] hunter stays roughly centred; [spec] follow 0.08-0.15s"],
	"cam_settle_t":            ["<=", 0.35, "s", "camera settles on you after a stop"],
	"cam_glide_lead_m":        [">=", 0.4, "m", "slight lead in glide direction"],
	"view_across_m":           ["~", [22.0, 25.0], "m", "ground across a 16:9 screen at the focus (camcal: ~17 hunter silhouettes across, as in gameplay frames)"],
	# (the reference body is the plain medium hunter since Vex took her own proportions: at the same camera it
	# measures 6.56% where the old reference, the default medium Warden at plain size, measured 6.07%, so the
	# range moved up by that 0.46; the camera did not change)
	"hunter_screen_pct":       ["~", [5.45, 6.65], "%", "medium hunter, feet to head straight up, as a share of screen height (camcal: its on-screen silhouette ~10.5%, as in gameplay frames; feelfix leans characters back 20 deg toward the camera, which shortens the straight-up measure from ~6.9% to ~5.5%)"],
	"hunter_feet_below_pct":   ["~", [1.5, 5.0], "%", "feet below the screen centre, as a share of screen height (camcal: ~3% in gameplay frames)"],
}

var results := {}

func ok(cond: bool, what: String) -> void:
	print("MFEEL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func rec(key: String, v: float) -> void:
	results[key] = v
	var t: Array = T[key]
	var pass_ := false
	var tgt := ""
	match String(t[0]):
		"<=": pass_ = v <= float(t[1]) + 1e-6; tgt = "<= %s" % str(t[1])
		">=": pass_ = v >= float(t[1]) - 1e-6; tgt = ">= %s" % str(t[1])
		"~":
			var r: Array = t[1]
			pass_ = v >= float(r[0]) - 1e-6 and v <= float(r[1]) + 1e-6
			tgt = "in [%s, %s]" % [str(r[0]), str(r[1])]
	print("MFEEL %-26s = %7.3f %-6s target %-14s %s   (%s)" % [key, v, t[2], tgt, "ok" if pass_ else "FAIL", t[3]])
	if not pass_: bad += 1

func _steps(n: int) -> void:
	for i in n: m.step(DT)

func _hv(h: Hunter) -> Vector2:
	return Vector2(h.vel.x, h.vel.z)

func _clear_inp() -> void:
	for k in ["sec", "sig", "ult", "util1", "util2", "util3", "util4", "gear1", "gear2", "glide", "glide_btn", "jump", "dash", "fire", "crouch", "throw", "reload", "skill", "swap"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO

## A clean, standing hunter at p.
func _reset(p: Vector3, grounded := true) -> void:
	P.out = false; P.gone = false; P.downed = false
	P.teleport(p)
	P.vel = Vector3.ZERO
	P.grounded = grounded
	P.pad = {}; P.grap = {}; P.grap_cd = 0.0; P.roll_t = 0.0; P.knock_t = 0.0; P.fly_t = 0.0
	P.gliding = false; P.glide_fuel = 1.0; P.glide_cd = 0.0; P.dropping = false; P.diving = false
	P.stun_t = 0.0; P.root_t = 0.0; P.kb_t = -9.0; P.mantle_cd = 0.0; P.shot_down = false; P.air_t = 0.0
	P.coyote = 0.0; P.jump_buf = 0.0; P.reload_t = 0.0; P.ammo = int(P.wpn["mag"]); P.idle_fire = 0.0
	P.dashes = P.max_dashes(); P.ex_cd = 0.0; P.dash_buf = 0.0; P.drink_t = 0.0; P.kit_t = 0.0
	P.squash = 0.0; P.hp = P.max_hp
	P.drop_follow = null
	if "lfloat" in P: P.set("lfloat", {})
	if "glide_off_t" in P: P.set("glide_off_t", 9.0)
	_clear_inp()

## A spot with flat, open ground `r` metres all round, on low ground (2m or less) when the map has one:
## the view's focus sits at 0.6x your height (cam.gd), so the framing numbers are calibrated near island level.
## The framing numbers also shift a little with the spot (the pose settles differently), so the spot the
## targets were calibrated on is tried first, and a map change can't move it.
const CALIB_SPOT := Vector3(99.5, 1.6, 163.5)
func _flat_spot(r: float) -> Vector3:
	for k in 4001:
		var g: Vector3 = w.random_ground()
		if k == 0:
			g = Vector3(CALIB_SPOT.x, w.ground_at(CALIB_SPOT.x, CALIB_SPOT.z), CALIB_SPOT.z)
		if g.y > 2.0 and k < 3000:
			continue
		var okk := not w.is_void(g.x, g.z) and not w.is_block(g.x, g.z)
		for i in 16:
			var a := TAU * i / 16.0
			for d in [r * 0.33, r * 0.66, r]:
				var x: float = g.x + cos(a) * d; var z: float = g.z + sin(a) * d
				if w.is_void(x, z) or w.is_block(x, z) or absf(w.ground_at(x, z) - g.y) > 0.01:
					okk = false
		if okk:
			return Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
	return w.random_ground()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": true})
	m.set_process(false)
	w = m.world
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	P = m.player
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		if h != P: h.teleport(Vector3(-500, 50, -500)); h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	flat = _flat_spot(6.5)
	print("MFEEL flat spot %s" % str(flat))
	_ground()
	_jump()
	_glide()
	_glide_dive()
	_dash_glide()
	_dash_exit()
	_plain_dash()
	_abyss_updraft()
	_feather()
	_ledge()
	_drop()
	_landing()
	_camera()
	_screen_scale()
	_e2e()
	print("MOVE FEEL CHECK DONE, failures: ", bad)
	main.get_tree().quit()

# ---------------------------------------------------------------- ground
func _ground() -> void:
	for c in ["light", "medium", "heavy"]:
		_reset(flat)
		P.cls = c
		P.base_speed = float(Data.CLASSES[c]["speed"])
		P.inp["move"] = Vector2(1, 0)
		var first := -1; var t95 := -1.0
		for i in 40:
			m.step(DT)
			var s := _hv(P).length()
			if first < 0 and s > 0.01: first = i + 1
			if t95 < 0.0 and s >= 0.95 * P.base_speed: t95 = (i + 1) * DT
		rec("speed_" + c, _hv(P).length())
		if c != "medium":
			continue
		rec("ground_input_frames", first)
		rec("ground_t95", t95)
		var top := _hv(P).length()
		# stop
		var x0 := P.pos.x
		P.inp["move"] = Vector2.ZERO
		var ts := -1.0
		for i in 30:
			m.step(DT)
			if ts < 0.0 and _hv(P).length() < 0.05: ts = (i + 1) * DT
		rec("ground_stop_t", ts)
		rec("ground_stop_dist", P.pos.x - x0)
		# reversal
		_reset(flat + Vector3(-2.5, 0, 0)); P.base_speed = top
		P.inp["move"] = Vector2(1, 0); _steps(20)
		P.inp["move"] = Vector2(-1, 0)
		var tr := -1.0
		for i in 40:
			m.step(DT)
			if tr < 0.0 and P.vel.x <= -0.95 * top: tr = (i + 1) * DT
		rec("ground_reverse_t", tr)
		# 90 degree turn
		_reset(flat + Vector3(-2.5, 0, -2.5)); P.base_speed = top
		P.inp["move"] = Vector2(1, 0); _steps(20)
		P.inp["move"] = Vector2(0, 1)
		var t90 := -1.0
		for i in 40:
			m.step(DT)
			var hv := _hv(P)
			if t90 < 0.0 and hv.length() >= 0.9 * top and absf(hv.angle_to(Vector2(0, 1))) < deg_to_rad(10.0): t90 = (i + 1) * DT
		rec("ground_turn90_t", t90)
	P.cls = "medium"
	P.base_speed = float(Data.CLASSES["medium"]["speed"])

# ---------------------------------------------------------------- jump
func _jump() -> void:
	_reset(flat)
	var g0 := P.pos.y
	P.inp["jump"] = true
	var first := -1; var apex := 0.0; var air := 0.0; var v0 := 0.0
	for i in 120:
		m.step(DT)
		if first < 0 and P.vel.y > 0.0:
			first = i + 1
			v0 = P.vel.y
		apex = maxf(apex, P.pos.y - g0)
		if not P.grounded: air += DT
		elif i > 2: break
	rec("jump_input_frames", first)
	rec("jump_apex", apex)
	rec("jump_speed_vs_source", v0 / SOURCE_JUMP_V)
	rec("jump_airtime", air)
	_air_control()
	# coyote time: step off over open air (the walk-off path sets coyote), press jump k frames later
	var best := 0
	var rim := _find_rim()
	for k in range(1, 16):
		if rim.is_empty(): break
		var rg: Vector3 = rim["at"]; var rd: Vector2 = rim["dir"]
		# just past the rim over open air, still flagged grounded: the walk-off path (a step with
		# nothing underfoot) starts the coyote window
		_reset(Vector3(rg.x + rd.x * 2.0, rg.y, rg.z + rd.y * 2.0))
		P.last_gy = rg.y
		m.step(DT)          # this step notices there's nothing underfoot
		_steps(k - 1)
		P.inp["jump"] = true
		m.step(DT)
		if P.vel.y > 1.0: best = k
		else: break
	rec("coyote_frames", best)
	# jump buffer: fall from 3m, press k frames before the landing frame; a jump should follow
	_reset(flat + Vector3(0, 3.0, 0), false)
	var land_f := 0
	for i in 120:
		m.step(DT)
		if P.grounded: land_f = i + 1; break
	var bb := 0
	for k in range(1, 16):
		_reset(flat + Vector3(0, 3.0, 0), false)
		var jumped := false
		for i in land_f + 4:
			P.inp["jump"] = (i + 1) == land_f - k
			m.step(DT)
			if i + 1 >= land_f and P.vel.y > 1.0: jumped = true
		if jumped and not P.gliding: bb = k
		else: break
	rec("jump_buffer_frames", bb)
	# free fall for 1s from rest
	_reset(flat + Vector3(0, 30.0, 0), false)
	var y0 := P.pos.y
	_steps(60)
	rec("freefall_1s_depth", y0 - P.pos.y)

## A running jump: let go at take-off (how far the run-up carries), or reverse the keys (how long the
## turn takes in the air).
func _air_control() -> void:
	var land_vx := 0.0
	for mode in ["let_go", "reverse"]:
		_reset(flat + Vector3(-3.0, 0, 0))
		P.inp["move"] = Vector2(1, 0)
		_steps(20)
		var x0 := P.pos.x
		P.inp["jump"] = true
		P.inp["move"] = Vector2.ZERO if mode == "let_go" else Vector2(-1, 0)
		for i in 90:
			m.step(DT)
			if P.grounded and i > 2: break
		if mode == "let_go":
			rec("air_carry_m", P.pos.x - x0)
			land_vx = P.vel.x
		else:
			rec("air_reverse_dv", land_vx - P.vel.x)

# ---------------------------------------------------------------- glide
func _glide_at(h: float) -> void:
	_reset(flat + Vector3(0, minf(h, HunterMove.glide_height - 0.3), 0), false)

func _glide() -> void:
	# a second press in the air opens the glider
	_reset(flat)
	P.inp["jump"] = true; m.step(DT)
	_steps(8)
	P.inp["jump"] = true; P.inp["glide"] = true
	var f := -1
	for i in 10:
		m.step(DT)
		P.inp["glide"] = true
		if f < 0 and P.gliding: f = i + 1
	rec("glide_open_press_frames", f)
	# hold Space from the jump press
	_reset(flat)
	P.inp["jump"] = true
	var th := -1.0
	for i in 60:
		P.inp["glide"] = true
		m.step(DT)
		if th < 0.0 and P.gliding: th = (i + 1) * DT
	rec("glide_open_hold_s", th)
	# the dedicated glide button held while you're airborne (stepping off, falling)
	_reset(flat + Vector3(0, 6.0, 0), false)
	_steps(3)
	var fb := -1
	for i in 30:
		P.inp["glide"] = true; P.inp["glide_btn"] = true
		m.step(DT)
		if fb < 0 and P.gliding: fb = i + 1
	rec("glide_open_button_frames", fb)
	# open at terminal fall speed: how fast the canopy catches you
	_reset(flat + Vector3(0, 16.0, 0), false)
	_steps(60)
	P.inp["jump"] = true
	var tc := -1.0
	var sink: float = Hunter.GLIDE_SINK
	for i in 90:
		P.inp["glide"] = true
		m.step(DT)
		if P.gliding and tc < 0.0 and absf(P.vel.y + sink) < 0.3: tc = (i + 1) * DT
	rec("glide_catch_t", tc)
	# cruise
	_glide_at(25.0)
	P.inp["jump"] = true
	for i in 150:
		P.inp["glide"] = true; P.inp["move"] = Vector2(1, 0)
		m.step(DT)
	rec("glide_speed", _hv(P).length())
	rec("glide_sink", -P.vel.y)
	var cruise := _hv(P).length()
	# turn 90
	var t90 := -1.0
	for i in 60:
		P.inp["glide"] = true; P.inp["move"] = Vector2(0, 1)
		m.step(DT)
		var hv := _hv(P)
		if t90 < 0.0 and absf(hv.angle_to(Vector2(0, 1))) < deg_to_rad(10.0) and hv.length() > cruise * 0.8: t90 = (i + 1) * DT
	rec("glide_turn90_t", t90)
	# reverse (brake through zero and back up the other way)
	var trv := -1.0
	for i in 90:
		P.inp["glide"] = true; P.inp["move"] = Vector2(0, -1)
		m.step(DT)
		if trv < 0.0 and P.vel.z <= -0.9 * cruise: trv = (i + 1) * DT
	rec("glide_reverse_t", trv)
	# braking momentum: at 10 m/s, steer against vs let go, 0.4s
	var sp := []
	for mode in ["let_go", "against"]:
		_glide_at(25.0)
		P.inp["jump"] = true
		for i in 10:
			P.inp["glide"] = true; m.step(DT)
		P.vel.x = 10.0; P.vel.z = 0.0
		for i in 24:
			P.inp["glide"] = true; P.inp["move"] = Vector2(-1, 0) if mode == "against" else Vector2.ZERO
			m.step(DT)
		sp.append(maxf(0.0, P.vel.x))
	rec("glide_brake_ratio", float(sp[1]) / maxf(0.01, float(sp[0])))
	_glide_high()
	# cancel and re-glide by holding again
	_glide_at(25.0)
	P.inp["jump"] = true
	for i in 30:
		P.inp["glide"] = true; m.step(DT)
	for i in 8:
		P.inp["glide"] = false; m.step(DT)
	var fr := -1
	for i in 10:
		P.inp["glide"] = true; P.inp["glide_btn"] = true
		m.step(DT)
		if fr < 0 and P.gliding: fr = i + 1
	rec("reglide_frames", fr)

## Gliding high over flat ground: pulled down to the height target, and the swoop becomes speed.
func _glide_high() -> void:
	_reset(flat + Vector3(0, HunterMove.glide_height + 8.0, 0), false)
	P.inp["jump"] = true
	var sink := 0.0
	var swoop := 0.0
	var t_low := -1.0
	var faded := 0.0
	for i in 600:
		P.inp["glide"] = true
		P.inp["move"] = Vector2(1, 0)
		m.step(DT)
		if i == 60: sink = -P.vel.y
		if t_low < 0.0 and P.pos.y - flat.y <= HunterMove.glide_height:
			t_low = i * DT
			swoop = _hv(P).length()
		if t_low > 0.0 and absf(i * DT - t_low - 2.0) < DT * 0.5:
			faded = _hv(P).length()
			break
	rec("glide_high_sink", sink)
	rec("glide_swoop_speed", swoop)
	rec("glide_swoop_faded", faded)

# ---------------------------------------------------------------- glide dive
## Crouch held under the glider plunges: its fall speed and ramp, the keys at a quarter of their force,
## the cancel height, the timeout, and the speed a pull-out high up gives.
func _glide_dive() -> void:
	_reset(flat + Vector3(0, 60.0, 0), false)
	P.inp["jump"] = true
	var t90 := -1.0
	var peak := 0.0
	var cancel_h := -1.0
	var was_on := false
	var land_vy := 0.0
	for i in 300:
		P.inp["glide"] = true
		P.inp["crouch"] = i >= 30
		var h_before := P.pos.y - flat.y
		m.step(DT)
		if i >= 30 and t90 < 0.0 and -P.vel.y >= HunterMove.dive_vy * 0.9:
			t90 = (i - 29) * DT
		if P.glide_dive.on:
			peak = maxf(peak, -P.vel.y)
		elif was_on and cancel_h < 0.0:
			cancel_h = h_before
		was_on = P.glide_dive.on
		if P.grounded:
			break
		land_vy = -P.vel.y        # the fall speed the landing step starts from
	rec("dive_vy", peak)
	rec("dive_vy_t", t90)
	rec("dive_cancel_h", cancel_h)
	# held to the ground: the glide catches you at the cancel height and you land under it, at its sink
	ok(P.grounded and not P.gliding, "dive_held_lands: a dive held to the ground reaches it under the glider")
	rec("dive_land_vy", land_vy)
	ok(P.land_t <= 0.0, "dive_land_soft: no hard-land beat after a dive held to the ground")
	# the keys in the plunge against the keys under the glider, from a standstill
	var side := []
	for diving in [true, false]:
		_reset(flat + Vector3(0, 60.0, 0), false)
		P.inp["jump"] = true
		for i in 72:
			P.inp["glide"] = true
			P.inp["crouch"] = diving
			m.step(DT)
			if i == 0:
				P.vel.x = 0.0     # drop the opening push: both runs steer from a standstill
				P.vel.z = 0.0
		for i in 12:
			P.inp["glide"] = true
			P.inp["crouch"] = diving
			P.inp["move"] = Vector2(1, 0)
			m.step(DT)
		side.append(_hv(P).length())
	rec("dive_steer_ratio", float(side[0]) / maxf(0.01, float(side[1])))
	# let go of crouch high up: the glide catches you and the drop becomes speed
	_reset(flat + Vector3(0, 60.0, 0), false)
	P.inp["jump"] = true
	var swoop := 0.0
	var t_glide := -1.0
	for i in 132:
		P.inp["glide"] = true
		P.inp["crouch"] = i < 72
		P.inp["move"] = Vector2(1, 0)
		m.step(DT)
		if i >= 72:
			swoop = maxf(swoop, _hv(P).length())
			if t_glide < 0.0 and -P.vel.y <= HunterMove.glide_pull_vy + 0.2:
				t_glide = (i - 71) * DT
	rec("dive_swoop_speed", swoop)
	rec("dive_release_glide_t", t_glide if t_glide > 0.0 else 9.0)
	ok(P.gliding and not P.grounded and not P.glide_dive.on, "dive_release_glides: back under the glider, not landed")
	# holding on: the plunge times out, and stays off until a fresh press
	_reset(flat + Vector3(0, 360.0, 0), false)
	P.inp["jump"] = true
	var t_off := -1.0
	for i in 690:
		P.inp["glide"] = true
		P.inp["crouch"] = true
		P.glide_fuel = 1.0
		var was := P.glide_dive.on
		m.step(DT)
		if was and not P.glide_dive.on and t_off < 0.0:
			t_off = i * DT
	rec("dive_timeout_s", t_off)
	ok(not P.glide_dive.on, "dive_timeout_holds: a timed-out plunge stays off while crouch stays held")
	_clear_inp()

# ---------------------------------------------------------------- dash into glide
func _dash_glide() -> void:
	var kit_was := P.arch
	P.set_arch("")      # the class dash: core physics (each kit's own air dash is its combo check's job)
	_glide_at(30.0)
	P.inp["jump"] = true
	for i in 90:
		P.inp["glide"] = true; P.inp["move"] = Vector2(1, 0); m.step(DT)
	P.ex_cd = 0.0; P.dashes = P.max_dashes()
	P.inp["dash"] = true
	var dash_end := -1; var reopen := -1; var open_v := 0.0
	var v1 := 0.0; var v2 := 0.0
	for i in 200:
		P.inp["glide"] = true; P.inp["move"] = Vector2(1, 0)
		var was_rolling := P.roll_t > 0.0 or i == 0
		m.step(DT)
		if dash_end < 0 and was_rolling and P.roll_t <= 0.0 and i > 0: dash_end = i
		if dash_end >= 0 and reopen < 0 and P.gliding:
			reopen = i - dash_end + 1
			open_v = _hv(P).length()
		if reopen >= 0:
			var since := (i - (dash_end + reopen - 1)) * DT
			if absf(since - 1.0) < DT * 0.5: v1 = _hv(P).length()
			if absf(since - 2.0) < DT * 0.5: v2 = _hv(P).length()
	rec("dashglide_reopen_frames", reopen)
	rec("dashglide_open_speed", open_v)
	rec("dashglide_1s_speed", v1)
	rec("dashglide_2s_speed", v2)
	P.set_arch(kit_was)

# ---------------------------------------------------------------- abyss lift, updrafts
var _rim := {}
## A rim tile with open sky beyond it: {at: ground point, dir: outward}.
## The source numbers in content/rules/hunter_move.json, then a class dash on flat ground, let go once it
## starts: it hands over at run speed and the walking stop takes it from there.
func _dash_exit() -> void:
	var brake := HunterMove.brake_decel
	var fric := HunterMove.ground_friction
	ok(is_equal_approx(brake, 22.2), "brake = BrakingDecelerationWalking 2220 uu/s2 (%s)" % brake)
	ok(is_equal_approx(fric, 2.0), "ground_friction = GroundFriction 1.0 x2 (%s)" % fric)
	ok(is_equal_approx(HunterMove.air_control, 0.015), "air_control = AirControl 0.015 (%s)" % HunterMove.air_control)
	var kit_was := P.arch
	P.set_arch("")
	_reset(flat + Vector3(-3.0, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	var x_end := 0.0
	for i in 120:
		var was_rolling := P.roll_t > 0.0
		m.step(DT)
		P.inp["dash"] = false
		if P.roll_t > 0.0: P.inp["move"] = Vector2.ZERO
		if was_rolling and P.roll_t <= 0.0:
			rec("dash_exit_run", _hv(P).length() / P.base_speed)
			x_end = P.pos.x
	rec("dash_exit_slide_m", P.pos.x - x_end)
	P.set_arch(kit_was)

## Owner rule: explosions are for blasts that do something. A plain dash on the ground and one in the air spawn
## no particle burst and no ring (Fx.radial), only a dust puff and after-images.
func _plain_dash() -> void:
	var biomes := m.biomes
	m.biomes = null          # (the map's own hazards spark and ring on their own clock)
	for airborne in [false, true]:
		_reset(flat + Vector3(0, 2.0 if airborne else 0.0, 0), not airborne)
		m.fields.clear()      # (a Boki's patch sparkles on its own clock)
		P.xp = 0.0            # (the long glide-dive rows feed the xp trickle: no level-up ring mid-dash)
		var radial0: int = m.fx.radial
		P.inp["move"] = Vector2(1, 0)
		P.inp["dash"] = true
		var dashed := false
		for i in 30:
			m.step(DT)
			P.inp["dash"] = false
			dashed = dashed or P.roll_t > 0.0
		var spawned: int = m.fx.radial - radial0
		var where := "air" if airborne else "ground"
		ok(dashed and spawned == 0, "a plain %s dash spawns no burst or ring (%d)" % [where, spawned])
	m.biomes = biomes

func _find_rim() -> Dictionary:
	if not _rim.is_empty(): return _rim
	var edge := {}
	for k in 6000:
		var g := w.random_ground()
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var open := true
			for dd in [1.6, 2.4, 3.2, 4.0, 5.0, 6.0]:
				for s in [-0.8, 0.0, 0.8]:
					if not w.is_void(g.x + d.x * dd + d.y * s, g.z + d.y * dd + d.x * s): open = false
			if open and not w.is_void(g.x, g.z):
				edge = {"at": g, "dir": d}
				break
		if not edge.is_empty(): break
	_rim = edge
	return edge

func _abyss_updraft() -> void:
	var edge := _find_rim()
	if edge.is_empty():
		print("MFEEL (no open rim found, abyss lift skipped)")
	else:
		var g: Vector3 = edge["at"]; var d: Vector2 = edge["dir"]
		_reset(Vector3(g.x + d.x * 4.0, g.y - 4.0, g.z + d.y * 4.0), false)
		P.last_gy = g.y
		P.vel.y = -8.0
		P.update_lip()
		var lip := P.lip_y
		P.inp["jump"] = true
		var tl := -1.0
		for i in 150:
			P.inp["glide"] = true
			m.step(DT)
			if tl < 0.0 and P.pos.y >= lip - 0.6: tl = (i + 1) * DT
			if P.out: break
		rec("abyss_lift_t", tl if tl > 0.0 else 9.0)
		_reset(Vector3(g.x + d.x * 4.0, g.y - 6.0, g.z + d.y * 4.0), false)
		P.last_gy = g.y
		P.vel.y = -8.0
		var bounce := -9.0
		for i in 100:
			P.inp["glide"] = true
			m.step(DT)
			bounce = maxf(bounce, P.pos.y - lip)
		rec("abyss_bounce_m", bounce)
		_abyss_depths(g, d)
	if w.updrafts.is_empty():
		print("MFEEL (no updrafts on this map, skipped)")
		return
	var u: Dictionary = w.updrafts[0]
	var c: Vector3 = u["pos"]
	_reset(Vector3(c.x, c.y + 1.0, c.z), false)
	P.inp["jump"] = true
	for i in 2:
		P.inp["glide"] = true; m.step(DT)
	P.vel.y = -2.0
	var tu := -1.0
	for i in 60:
		P.inp["glide"] = true
		m.step(DT)
		if tu < 0.0 and P.vel.y >= 8.0: tu = (i + 1) * DT
	rec("updraft_rise_t", tu if tu > 0.0 else 9.0)

## The point of no return, how deep you can still glide out from, and the screen's danger tint.
func _kill_y() -> float:
	if P.has_method("abyss_kill_y"): return P.call("abyss_kill_y")
	var fl: float = w.abyss_floor(P.pos.x, P.pos.z, P.last_gy)
	return fl - (Hunter.ABYSS_GLIDE_ROOM if P.gliding and P.glide_fuel > 0.001 else 0.0)

func _abyss_depths(g: Vector3, d: Vector2) -> void:
	var out := Vector3(g.x + d.x * 4.0, g.y, g.z + d.y * 4.0)
	_reset(out, false); P.last_gy = g.y
	var lip: float = w.abyss_floor(out.x, out.z, g.y) + World.ABYSS_DEPTH
	rec("abyss_kill_depth", lip - _kill_y())
	# deepest recoverable: falling at terminal, open the glider (full heat), get back to the balloon line
	var best := 0.0
	var dd := 3.0
	while dd <= 20.0:
		_reset(Vector3(out.x, lip - dd, out.z), false); P.last_gy = g.y
		P.vel.y = -HunterMove.fall_max
		P.inp["jump"] = true
		var okk := false
		var y0 := P.pos.y
		for i in 300:
			P.inp["glide"] = true
			var yb := P.pos.y
			m.step(DT)
			if P.out or P.pos.y - yb > 2.0: break         # lost (god mode puts you back on land)
			if P.pos.y >= lip - 0.6: okk = true; break
		if not okk: break
		best = dd
		dd += 0.5
	rec("abyss_recover_depth", best)
	# step off the lip and fall: the slow-fall band, and how long until the point of no return
	_reset(Vector3(out.x, lip - 0.6, out.z), false)
	P.last_gy = g.y
	var kill_y := _kill_y()
	var t_fall := 0.0
	var vy_deep := 0.0
	for i in 300:
		var yb := P.pos.y
		m.step(DT)
		if P.out or P.pos.y - yb > 2.0 or P.pos.y < kill_y: break
		t_fall += DT
		if lip - P.pos.y <= HunterMove.abyss_slow_to: vy_deep = -P.vel.y
	rec("abyss_fall_vy_deep", vy_deep)
	rec("abyss_fall_t", t_fall)
	var fx_path := "res://scripts/match/abyss_fx.gd"
	if not ResourceLoader.exists(fx_path):
		print("MFEEL (no AbyssFx on this build: danger tint not measured)")
		return
	var FX = load(fx_path)
	_reset(Vector3(out.x, lip - 0.47, out.z), false); P.last_gy = g.y
	P.gliding = true
	rec("abyss_tint_lip", FX.danger(P))
	P.gliding = false
	var kill := _kill_y()
	P.pos.y = lerpf(lip - 0.5, kill, 0.5)
	rec("abyss_tint_half", FX.danger(P))
	P.pos.y = kill + 0.5
	rec("abyss_tint_end", FX.danger(P))
	P.pos.y = lerpf(lip - 0.5, kill, 0.5); P.vel.y = 4.0
	rec("abyss_tint_rising", FX.danger(P))
	P.vel.y = 0.0

# ---------------------------------------------------------------- feathering
## Far out over the open abyss (off the map's edge), heading further out at the island-level line
## with a full glider: hold glide until it overheats, or feather it (a tap that lifts you out of a
## dip, let go to coast on the lift and the kept glide speed, tap again when you've dropped ~1.5m).
## Distance flown before the heat runs out.
func _feather() -> void:
	if not "glide_off_t" in P:
		print("MFEEL (no feathering on this build)")
		return
	var lip := flat.y
	var start := Vector3(-30.0, lip - 0.45, w.h * 0.5)
	var dist := {}
	for mode in ["hold", "feather"]:
		_reset(start, false)
		P.last_gy = lip
		P.air_t = 1.0
		P.gliding = true
		P.vel = Vector3(-Hunter.GLIDE_SPEED, 0.0, 0.0)
		var x0 := P.pos.x
		var holding := true
		for i in 60 * 60:
			P.inp["move"] = Vector2(-1, 0)
			if mode == "feather":
				var depth: float = lip - P.pos.y
				if P.gliding and (P.vel.y >= 9.0 or (depth < 0.5 and P.vel.y >= 0.0)):
					holding = false          # let go: coast on the lift
				elif not P.gliding and depth > 1.5:
					holding = true           # dipped: tap it open again
			P.inp["glide"] = holding
			m.step(DT)
			if P.out or P.grounded or P.glide_fuel <= 0.01:
				break
		dist[mode] = absf(P.pos.x - x0)
	rec("feather_hold_m", dist["hold"])
	rec("feather_m", dist["feather"])
	rec("feather_gain", dist["feather"] / maxf(1.0, dist["hold"]))
	# toggling: let go, then press again the very next step
	_reset(start, false)
	P.last_gy = lip; P.air_t = 1.0; P.gliding = true; P.glide_fuel = 0.5
	P.inp["glide"] = true
	m.step(DT)
	P.inp["glide"] = false
	m.step(DT)
	var closed := not P.gliding
	P.inp["glide"] = true
	var fr := 0
	for i in 5:
		m.step(DT); fr += 1
		if P.gliding: break
	rec("feather_toggle_frames", fr if closed else 9.0)

# ---------------------------------------------------------------- the ledge rise and fling
## A straight wall two terraces (1.6m) high with level open ground in front: jump at it pushing in.
func _wall2() -> Dictionary:
	for z in range(3, w.h - 3):
		for x in range(3, w.w - 3):
			var i := w.idx(x, z)
			if w.kind[i] != World.T_GROUND: continue
			var l0 := int(w.level[i])
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var hi: Vector2i = Vector2i(x, z) + d
				var good := true
				var side := Vector2i(int(d.y), int(d.x))
				for sd in range(-2, 3):
					var hs: Vector2i = hi + side * sd
					for k in range(0, 3):
						var hk: Vector2i = hs + d * k
						if not w.inb(hk.x, hk.y) or w.kind[w.idx(hk.x, hk.y)] != World.T_GROUND or int(w.level[w.idx(hk.x, hk.y)]) != l0 + 2 or w.sheer.has(w.idx(hk.x, hk.y)): good = false
					for back in range(0, 4):
						var lb: Vector2i = Vector2i(x, z) + side * sd - d * back
						if not w.inb(lb.x, lb.y) or w.kind[w.idx(lb.x, lb.y)] != World.T_GROUND or int(w.level[w.idx(lb.x, lb.y)]) != l0 or w.stairs.has(w.idx(lb.x, lb.y)): good = false
				if not good: continue
				var n := Vector2(d)
				var face := Vector2(hi.x + 0.5, hi.y + 0.5) - n * 0.5
				return {"at": face - n * (P.r + 0.6), "n": n, "low": l0 * World.LEVEL, "top": (l0 + 2) * World.LEVEL}
	return {}

func _ledge() -> void:
	if not P.has_method("mantling") or not "lfloat" in P:
		print("MFEEL (no ledge rise on this build)")
		return
	var wl := _wall2()
	var carved := []      # [index, old level] to put back afterwards (later sections use the flat spot)
	if wl.is_empty():
		# carve one beside the flat test spot: a 5x3 block two terraces high, 3m east of it
		var x0 := int(floor(flat.x)); var z0 := int(floor(flat.z))
		var lv := int(w.level[w.idx(x0, z0)])
		for dz in range(-2, 3):
			for dx in range(3, 6):
				var ci := w.idx(x0 + dx, z0 + dz)
				carved.append([ci, w.level[ci]])
				w.level[ci] = lv + 2
		var face := Vector2(x0 + 3.0, z0 + 0.5)
		wl = {"at": face - Vector2(1, 0) * (P.r + 0.6), "n": Vector2(1, 0), "low": lv * World.LEVEL, "top": (lv + 2) * World.LEVEL}
	var n: Vector2 = wl["n"]
	var top: float = wl["top"]
	var out := {}
	for mode in ["none", "early", "timed"]:
		_reset(Vector3(wl["at"].x, wl["low"], wl["at"].y))
		var rising := 0; var t_rise := -1.0; var peak := -1e9; var lip_at := Vector2.INF; var jumped := false
		var win_steps := 0
		for i in 150:
			P.inp["move"] = n
			var jump := i == 2
			if P.call("mantling"):
				rising += 1
				if bool(P.get("lfloat").get("win", false)): win_steps += 1
				if not jumped and mode == "early" and rising == 2: jump = true; jumped = true
				if not jumped and mode == "timed" and bool(P.get("lfloat").get("win", false)): jump = true; jumped = true
			P.inp["jump"] = jump
			m.step(DT)
			P.inp["jump"] = false
			if rising > 0 and t_rise < 0.0 and P.pos.y >= top: t_rise = rising * DT
			if rising > 0 and not P.call("mantling"):
				peak = maxf(peak, P.pos.y)
				if lip_at == Vector2.INF: lip_at = Vector2(P.pos.x, P.pos.z)
			if rising > 0 and P.grounded and not P.call("mantling"):
				break
		out[mode] = {"t": t_rise, "peak": peak - top, "dist": (Vector2(P.pos.x, P.pos.z) - lip_at).dot(n) if lip_at != Vector2.INF else 0.0, "win": win_steps * DT}
	rec("ledge_rise_t", out["none"]["t"] if out["none"]["t"] > 0.0 else 9.0)
	rec("ledge_rise_peak_m", out["none"]["peak"])
	rec("ledge_fling_early_m", out["early"]["dist"])
	rec("ledge_fling_timed_m", out["timed"]["dist"])
	rec("ledge_fling_timed_up_m", out["timed"]["peak"])
	rec("ledge_fling_gain", out["timed"]["dist"] / maxf(0.1, out["none"]["dist"]))
	rec("ledge_window_s", out["none"]["win"])
	print("MFEEL ledge: no jump +%.2fm then %.2fm on; early jump +%.2fm %.2fm; timed +%.2fm %.2fm" % [out["none"]["peak"], out["none"]["dist"], out["early"]["peak"], out["early"]["dist"], out["timed"]["peak"], out["timed"]["dist"]])
	for cv in carved:
		w.level[int(cv[0])] = cv[1]

# ---------------------------------------------------------------- the opening drop
func _drop() -> void:
	_reset(flat + Vector3(0, 40.0, 0), false)
	P.dropping = true; P.diving = true; P.gliding = true; P.glide_k = 1.0
	P.vel = Vector3.ZERO
	var tvy := -1.0; var tst := -1.0
	for i in 60:
		P.inp["move"] = Vector2(1, 0)
		m.step(DT)
		if tvy < 0.0 and -P.vel.y >= 0.9 * Hunter.DIVE_FALL: tvy = (i + 1) * DT
		if tst < 0.0 and P.vel.x >= 0.9 * Hunter.DIVE_SPEED: tst = (i + 1) * DT
		if not P.diving: break
	rec("drop_dive_vy_t", tvy if tvy > 0.0 else 9.0)
	rec("drop_dive_steer_t", tst if tst > 0.0 else 9.0)
	# deploy on a press (well above the auto height)
	_reset(flat + Vector3(0, 40.0, 0), false)
	P.dropping = true; P.diving = true; P.gliding = true; P.glide_k = 1.0
	P.vel = Vector3(0, -Hunter.DIVE_FALL, 0)
	_steps(5)
	P.inp["jump"] = true
	var fd := -1; var ts := -1.0
	for i in 60:
		m.step(DT)
		if fd < 0 and not P.diving: fd = i + 1
		if ts < 0.0 and not P.diving and absf(-P.vel.y - Hunter.DROP_FALL) <= 0.1 * Hunter.DROP_FALL: ts = (i + 1) * DT
	rec("drop_deploy_frames", fd)
	rec("drop_deploy_settle_t", ts if ts > 0.0 else 9.0)
	# steer under the canopy
	P.vel.x = 0.0; P.vel.z = 0.0
	var tg := -1.0
	for i in 60:
		P.inp["move"] = Vector2(0, 1)
		m.step(DT)
		if tg < 0.0 and P.vel.z >= 0.9 * Hunter.DROP_SPEED: tg = (i + 1) * DT
	rec("drop_glide_steer_t", tg if tg > 0.0 else 9.0)
	# land and move off straight away
	_reset(flat + Vector3(0, 3.0, 0), false)
	P.dropping = true; P.diving = false; P.gliding = true
	P.vel = Vector3(0, -Hunter.DROP_FALL, 0)
	var landed := false
	for i in 120:
		m.step(DT)
		if P.grounded: landed = true; break
	var dead := 99
	if landed:
		P.inp["move"] = Vector2(-1, 0)
		for i in 10:
			m.step(DT)
			if P.vel.x < -0.5: dead = i + 1; break
	rec("drop_land_dead_frames", dead)

# ---------------------------------------------------------------- normal landings
func _landing() -> void:
	_reset(flat + Vector3(0, 6.0, 0), false)
	var sq := 0.0
	for i in 120:
		m.step(DT)
		if P.grounded: sq = P.squash; break
	P.inp["move"] = Vector2(1, 0)
	var dead := 99
	for i in 10:
		m.step(DT)
		if P.vel.x > 0.5: dead = i + 1; break
	rec("land_dead_frames", dead)
	rec("land_squash", sq)

# ---------------------------------------------------------------- camera
func _render_pos() -> Vector3:
	if P.has_method("render_pos"):
		return P.call("render_pos", 0.0)
	return P.prev.lerp(P.pos, 0.0)

func _camera() -> void:
	var cam: CamRig = m.cam
	if cam == null:
		print("MFEEL (no camera, skipped)")
		return
	_reset(flat + Vector3(-3.0, 0, 0))
	cam.snap(P.pos)
	P.inp["move"] = Vector2(1, 0)
	for i in 30:
		m.step(DT)
		P.render(DT, 0.0)
		cam.follow(P.position, DT, false)
	var lag := Vector2(cam.base.x - P.pos.x, cam.base.z - P.pos.z).length()
	rec("cam_lag_m", lag)
	P.inp["move"] = Vector2.ZERO
	var tset := -1.0
	for i in 60:
		m.step(DT)
		P.render(DT, 0.0)
		cam.follow(P.position, DT, false)
		if tset < 0.0 and Vector2(cam.base.x - P.pos.x, cam.base.z - P.pos.z).length() < 0.05: tset = (i + 1) * DT
	rec("cam_settle_t", tset if tset > 0.0 else 9.0)
	# glide lead: where the view sits relative to you while gliding along +x
	_glide_at(25.0)
	cam.snap(P.pos)
	P.inp["jump"] = true
	for i in 120:
		P.inp["glide"] = true; P.inp["move"] = Vector2(1, 0)
		m.step(DT)
		P.render(DT, 0.0)
		if m.has_method("cam_lead_vel"): cam.set("lead_vel", m.call("cam_lead_vel"))
		cam.follow(P.position, DT, false)
	rec("cam_glide_lead_m", cam.focus.x - P.pos.x)

# ---------------------------------------------------------------- framing: how big you are on screen
func _screen_scale() -> void:
	var cam: CamRig = m.cam
	if cam == null or P.model == null:
		return
	cam.use_style("supervive")
	cam.zoom = 1.0; cam.zoom_to = 1.0; cam.top = 0.0; cam.top_to = 0.0; cam.chase = 0.0; cam.chase_to = 0.0
	cam.yaw = 0.0; cam.yaw_to = 0.0;
	if "lead_vel" in cam: cam.set("lead_vel", Vector3.ZERO)
	if "pull" in cam: cam.set("pull", 0.0)
	_reset(flat)
	P.glide_k = 0.0
	for i in 3:
		m.step(DT)
		P.render(DT, 1.0)
	cam.snap(P.pos)
	for i in 120:
		cam.follow(P.position, DT, false)
	var vh := cam.get_viewport().get_visible_rect().size.y
	var vw := cam.get_viewport().get_visible_rect().size.x
	var aspect := 16.0 / 9.0
	var hfov := 2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) * aspect)
	# (Camera3D keeps the vertical FOV, so a share of screen HEIGHT doesn't depend on the window shape)
	var ref := _stand_in("", MantleLook.at_home(PlayerLook.neutral()))
	var now := _model_span(cam, ref)
	print("MFEEL framing: style supervive pitch %.0f dist %.1f fov %.0f, viewport %dx%d, model scale %.2f, model %.2fm tall" % [rad_to_deg(cam.pitch), cam.dist, cam.fov, int(vw), int(vh), ref.scale.y, now[2]])
	rec("view_across_m", 2.0 * cam.dist * tan(hfov * 0.5))
	rec("hunter_screen_pct", now[1] / vh * 100.0)
	rec("hunter_feet_below_pct", (float(now[3]) - vh * 0.5) / vh * 100.0)
	for id in FRAME_HEROES:
		var hm := _stand_in(id, PlayerLook.neutral())
		var hs := _model_span(cam, hm)
		var kind := "3D" if hm.has_node("Warden") else "procedural"
		var feet := (float(hs[3]) - vh * 0.5) / vh * 100.0
		print("MFEEL framing %s (%s model): %.2f%% of screen height, feet %.2f%% below the centre"
				% [id, kind, hs[1] / vh * 100.0, feet])
		hm.free()
	# the same measure for the framing before movefeel (25m, hunters at their plain size), for the doc
	var d0 := cam.dist
	var vs: float = Hunter.VIS_SCALE
	cam.dist = 25.0
	ref.scale /= vs
	cam.snap(P.pos)
	var was := _model_span(cam, ref)
	print("MFEEL framing before (dist 25.0, scale /%.2f): %.1fm across, hunter %.1f%% of screen height (silhouette %.1f%%); now silhouette %.1f%%" % [vs, 2.0 * 25.0 * tan(hfov * 0.5), was[1] / vh * 100.0, was[0] / vh * 100.0, now[0] / vh * 100.0])
	ref.free()
	cam.dist = d0
	cam.snap(P.pos)

## A model of Warden `id` ("" with an at-home look: the plain hunter) standing where the player does, at
## the match's size, leaned toward the camera as the player's model is (Hunter.render), standing at idle.
func _stand_in(id: String, look: Dictionary) -> Node3D:
	var cls := Arch.weight(id) if id != "" else "medium"
	var weapon := Arch.signature(id) if id != "" else REF_WEAPON
	var h := Models.hunter(cls, Data.TEAM_COLORS[0], weapon, "", look, id)
	m.add_child(h)
	var at_scale := h.scale * Hunter.VIS_SCALE
	var lean := P.model.global_basis.orthonormalized()
	h.global_transform = Transform3D(lean * Basis.from_scale(at_scale), P.model.global_position)
	h.set_meta("anim_seed", 1)      # one stance for every measure (HunterAnim seeds it per node otherwise)
	var an := HunterAnim.new(h)
	for i in 30:
		an.update(DT, {"fired": 99.0, "face": 0.0, "grounded": true})
	var sync := h.get_node_or_null("Warden/Sync") as WardenGlb.Sync
	if sync:
		sync.apply()
	return h

## [silhouette px (every corner on screen, so depth counts too), standing px (feet to the top of the
## head, straight up at the hunter), model height m] for a hunter's body (no glider, ring, weapon or shield:
## a stand-in holds its weapon in the rest pose, not aimed as the player's is). A 3D
## Warden's skinned mesh counts its posed vertices (its box is the rest pose's).
func _model_span(cam: CamRig, model: Node3D) -> Array:
	var lo := 1e9; var hi := -1e9
	var ylo := 1e9; var yhi := -1e9
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name in SPAN_SKIP:
			continue
		for c in n.get_children(): stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree() and n.name != "TeamRing":
			var mi := n as MeshInstance3D
			var ab := mi.get_aabb()
			if OS.has_environment("MFEEL_DEBUG"):
				print("MFEEL   mesh %s size %s" % [str(model.get_path_to(mi)), str((mi.global_transform.basis * ab.size).abs().snapped(Vector3(0.01, 0.01, 0.01)))])
			var pts := PackedVector3Array()
			if mi.skin:
				pts = WARDEN_SKIN.points(mi)
			else:
				for k in 8:
					pts.append(mi.global_transform * ab.get_endpoint(k))
			for wp in pts:
				var sp := cam.unproject_position(wp)
				lo = minf(lo, sp.y); hi = maxf(hi, sp.y)
				ylo = minf(ylo, wp.y); yhi = maxf(yhi, wp.y)
	var c := model.global_position
	var feet := cam.unproject_position(Vector3(c.x, ylo, c.z))
	var head := cam.unproject_position(Vector3(c.x, yhi, c.z))
	return [hi - lo, absf(feet.y - head.y), yhi - ylo, feet.y]

# ---------------------------------------------------------------- end to end: key -> sim -> screen
func _e2e() -> void:
	_reset(flat + Vector3(-3.0, 0, 0))
	m.acc = 0.0
	m.paused = false
	for i in 3: m._process(DT)
	var x_sim := P.pos.x
	var x_vis := P.position.x
	Input.action_press("right")
	var fi := -1; var fr := -1
	for i in 6:
		m._process(DT)
		if fi < 0 and P.pos.x > x_sim + 0.001: fi = i + 1
		if fr < 0 and P.position.x > x_vis + 0.001: fr = i + 1
	rec("e2e_input_frames", fi if fi > 0 else 99)
	rec("e2e_render_frames", fr if fr > 0 else 99)
	for i in 20: m._process(DT)
	rec("render_lag_m", absf(P.pos.x - P.position.x))
	Input.action_release("right")
	for i in 10: m._process(DT)
