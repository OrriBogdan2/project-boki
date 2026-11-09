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
const DT := 1.0 / 60.0

## key -> [op, target, unit, note]. Ops: "<=", ">=", "~" (within tol given as [lo, hi]).
const T := {
	"ground_input_frames":     ["<=", 1.0, "frames", "press to velocity change, same sim step"],
	"ground_t95":              ["<=", 0.07, "s", "[spec] near-instant 0.05-0.1s ramp"],
	"ground_stop_t":           ["<=", 0.06, "s", "[spec] near-instant stop"],
	"ground_stop_dist":        ["<=", 0.20, "m", "[spec] no floaty slide"],
	"ground_reverse_t":        ["<=", 0.12, "s", "[spec] crisp direction change"],
	"ground_turn90_t":         ["<=", 0.09, "s", "[spec] crisp direction change"],
	"speed_light":             ["~", [5.15, 5.25], "m/s", "class data (wiki band 4.15-4.9 m/s +- class spread)"],
	"speed_medium":            ["~", [4.95, 5.05], "m/s", "class data"],
	"speed_heavy":             ["~", [4.68, 4.78], "m/s", "class data"],
	"jump_input_frames":       ["<=", 1.0, "frames", "press to lift-off, same sim step"],
	"jump_apex":               ["~", [1.2, 1.6], "m", "[est] one terrace (World.LEVEL) + mantle reach"],
	"jump_airtime":            ["<=", 0.60, "s", "[est] tight arc (FeelConfig jump ~0.6s)"],
	"coyote_frames":           [">=", 6.0, "frames", "FeelConfig coyote_time 0.1s (walked off a rim over the void)"],
	"jump_buffer_frames":      [">=", 7.0, "frames", "FeelConfig jump_buffer 0.12s (7 steps)"],
	"freefall_1s_depth":       ["~", [7.5, 9.0], "m", "[footage] 1s off an edge is ~8m deep (SUPERVIVE_FEEL)"],
	"glide_open_press_frames": ["<=", 1.0, "frames", "[wiki/guide] hold jump in the air to glide; a second press opens at once"],
	"glide_open_hold_s":       ["<=", 0.12, "s", "tap/hold split for Space; a tap is ~0.1s"],
	"glide_open_button_frames": ["<=", 1.0, "frames", "dedicated glide button: no tap/hold ambiguity"],
	"glide_catch_t":           ["<=", 0.20, "s", "glider opens 'instantly' on input; brakes a terminal fall to sink rate"],
	"glide_speed":             ["~", [6.2, 6.8], "m/s", "between [footage] ~5-5.5 and [spec] 7-10, leaning stronger (owner)"],
	"glide_sink":              ["~", [1.2, 1.6], "m/s", "floatier than [spec] 2-4 eyeball / [est] 2.2 (owner: sank too fast)"],
	"glide_turn90_t":          ["<=", 0.30, "s", "responsive steering [est]"],
	"glide_reverse_t":         ["<=", 0.45, "s", "brake by steering against heading [est]"],
	"glide_brake_ratio":       ["<=", 0.80, "x", "steering against heading brakes momentum (speed vs letting go)"],
	"dashglide_open_speed":    [">=", 12.0, "m/s", "[wiki] gliding right after a lateral impulse keeps momentum and increases glide speed"],
	"dashglide_1s_speed":      [">=", 10.5, "m/s", "[wiki] momentum preserved while gliding"],
	"dashglide_2s_speed":      [">=", 9.0, "m/s", "[wiki] momentum preserved while gliding"],
	"dashglide_reopen_frames": ["<=", 1.0, "frames", "glider is back the step the dash ends while glide is held"],
	"reglide_frames":          ["<=", 1.0, "frames", "glide-cancel then re-hold reopens at once"],
	"abyss_lift_t":            ["<=", 1.0, "s", "[footage] back at island level (balloon line, 0.5m under the lip) ~1s after opening 4m deep"],
	"abyss_kill_depth":        [">=", 12.0, "m", "[footage] ~1.5s of free fall before it's fatal (FeelConfig abyss_death_depth note); owner: 'needs to be a bit lower'"],
	"abyss_recover_depth":     [">=", 11.0, "m", "deepest a terminal fall can open the glider and still lift back to the lip"],
	"abyss_tint_lip":          ["<=", 0.02, "", "no tint gliding at island level"],
	"abyss_tint_half":         [">=", 0.6, "", "[footage] tint deepens as you sink; owner: unmistakable early"],
	"abyss_tint_end":          [">=", 0.95, "", "full dark/red right before the point of no return"],
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
	"hunter_screen_pct":       ["~", [6.4, 7.6], "%", "medium hunter, feet to head straight up, as a share of screen height (camcal: its on-screen silhouette ~10.5%, as in gameplay frames)"],
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
	for k in ["sec", "sig", "ult", "tonic", "kit", "gear1", "gear2", "glide", "glide_btn", "jump", "dash", "dash_hold", "fire", "crouch", "throw", "reload", "skill", "swap"]:
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

## A spot with flat, open ground `r` metres all round.
func _flat_spot(r: float) -> Vector3:
	for k in 4000:
		var g := w.random_ground()
		var okk := true
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
	if P.kin: (P.kin as Kin).state = "shoulder"
	P.ctrl = "local"
	P.unlock_all()
	flat = _flat_spot(6.5)
	print("MFEEL flat spot %s" % str(flat))
	_ground()
	_jump()
	_glide()
	_dash_glide()
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
	var first := -1; var apex := 0.0; var air := 0.0
	for i in 120:
		m.step(DT)
		if first < 0 and P.vel.y > 0.0: first = i + 1
		apex = maxf(apex, P.pos.y - g0)
		if not P.grounded: air += DT
		elif i > 2: break
	rec("jump_input_frames", first)
	rec("jump_apex", apex)
	rec("jump_airtime", air)
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

# ---------------------------------------------------------------- glide
func _glide_at(h: float) -> void:
	_reset(flat + Vector3(0, h, 0), false)

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
	_reset(flat + Vector3(0, 40.0, 0), false)
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

# ---------------------------------------------------------------- dash into glide
func _dash_glide() -> void:
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

# ---------------------------------------------------------------- abyss lift, updrafts
var _rim := {}
## A rim tile with open sky beyond it: {at: ground point, dir: outward}.
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
		P.vel.y = -Hunter.TERMINAL
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
	cam.yaw = 0.0; cam.yaw_to = 0.0; cam.kick = 0.0
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
	var now := _model_span(cam)
	print("MFEEL framing: style supervive pitch %.0f dist %.1f fov %.0f, viewport %dx%d, model scale %.2f, model %.2fm tall" % [rad_to_deg(cam.pitch), cam.dist, cam.fov, int(vw), int(vh), P.model.scale.y, now[2]])
	rec("view_across_m", 2.0 * cam.dist * tan(hfov * 0.5))
	rec("hunter_screen_pct", now[1] / vh * 100.0)
	rec("hunter_feet_below_pct", (float(now[3]) - vh * 0.5) / vh * 100.0)
	# the same measure for the framing before movefeel (25m, hunters at their plain size), for the doc
	var d0 := cam.dist
	var vs: float = Hunter.VIS_SCALE
	cam.dist = 25.0
	P.model.scale /= vs
	cam.snap(P.pos)
	var was := _model_span(cam)
	print("MFEEL framing before (dist 25.0, scale /%.2f): %.1fm across, hunter %.1f%% of screen height (silhouette %.1f%%); now silhouette %.1f%%" % [vs, 2.0 * 25.0 * tan(hfov * 0.5), was[1] / vh * 100.0, was[0] / vh * 100.0, now[0] / vh * 100.0])
	P.model.scale *= vs
	cam.dist = d0
	cam.snap(P.pos)

## [silhouette px (every corner on screen, so depth counts too), standing px (feet to the top of the
## head, straight up at the hunter), model height m] for the player's model (no glider, no ring).
func _model_span(cam: CamRig) -> Array:
	var lo := 1e9; var hi := -1e9
	var ylo := 1e9; var yhi := -1e9
	var stack: Array = [P.model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.name == "Glider":
			continue
		for c in n.get_children(): stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).is_visible_in_tree() and n.name != "TeamRing":
			var mi := n as MeshInstance3D
			var ab := mi.get_aabb()
			if OS.has_environment("MFEEL_DEBUG"):
				print("MFEEL   mesh %s size %s" % [str(P.model.get_path_to(mi)), str((mi.global_transform.basis * ab.size).abs().snapped(Vector3(0.01, 0.01, 0.01)))])
			for k in 8:
				var wp: Vector3 = mi.global_transform * ab.get_endpoint(k)
				var sp := cam.unproject_position(wp)
				lo = minf(lo, sp.y); hi = maxf(hi, sp.y)
				ylo = minf(ylo, wp.y); yhi = maxf(yhi, wp.y)
	var c := P.model.global_position
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
