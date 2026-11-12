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
const DIRS := preload("res://tools/move_feel_dirs.gd")      # the W A S D and diagonal rows
const LEDGE := preload("res://tools/move_feel_ledge.gd")     # the ground dash off a ledge, every kit
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
	"ground_stop_dist":        ["~", [0.27, 0.4], "m", "[game data] UE's walking brake: 0.28-0.39m at 30-144 fps"],
	"brake_vs_ue_err":         ["<=", 0.0001, "m/s", "HunterMove.brake against UE's ApplyVelocityBraking"],
	"ground_reverse_t":        ["<=", 0.19, "s", "[game data] a full reverse at 47-54 m/s2"],
	"ground_turn90_t":         ["<=", 0.13, "s", "[game data] a 90-degree turn at 47-54 m/s2"],
	"ground_shed_dist":        ["~", [1.25, 1.55], "m", "[game data] brake 2/s + 22.2 m/s2: 10 m/s slides 1.44m"],
	"ground_shed_keys_m":      ["~", [0.95, 1.2], "m", "[game data] the same brake down to the run, keys held: 1.07m"],
	"face_turn180_t":          ["~", [0.12, 0.17], "s", "[game data] RotationRate yaw 1280 deg/s: a 180 in 0.14s"],
	"face_turn20_t":           ["<=", 0.04, "s", "[game data] the same fixed rate: a 20-degree flick lands in ~0.02s"],
	"speed_light":             ["~", [4.4, 4.9], "m/s",
		"[game data] per-hunter MoveSpeed 445-485 uu/s (content/rules/hunter_move.json)"],
	"speed_medium":            ["~", [4.4, 4.9], "m/s", "[game data] per hunter"],
	"speed_heavy":             ["~", [4.4, 4.9], "m/s", "[game data] per hunter"],
	# (move-speed bonuses: one MoveSpeed attribute in the data, so they add; slows multiply the total)
	"haste_two_bonus_x":       ["~", [1.49, 1.51], "x", "haste 0.35 + kin buff 0.15 add (1.55 if stacked)"],
	"haste_bonus_slow_x":      ["~", [0.80, 0.82], "x", "haste 0.35 under a 40% slow: 1.35 x 0.6"],
	"haste_cap_mps":           ["~", [6.95, 7.0], "m/s", "[game data] MaxMoveSpeed 700 uu/s"],
	"jump_input_frames":       ["<=", 1.0, "frames", "press to lift-off, same sim step"],
	"jump_apex":               ["~", [1.2, 1.6], "m",
		"[game data] 1.9m; under 1.6 so jump + mantle stays below 4 terraces"],
	"jump_speed_vs_source":    ["~", [0.85, 1.0], "x", "[game data] JumpZVelocity 7.5; ours 6.8 (terraces)"],
	"jump_airtime":            ["~", [0.85, 1.05], "s", "[game data] JumpZVelocity 750 at gravity 1470 uu/s2: 1.02s"],
	"air_carry_m":             [">=", 3.0, "m", "[game data] FallingLateralFriction 0.375: the run-up carries"],
	"air_reverse_dv":          [">=", 5.0, "m/s", "[owner 11-08] strong WASD air control"],
	"dash_exit_run":           ["~", [0.95, 1.05], "x", "[game data] no hard stop: hands over at run speed"],
	"brake_cast_gap_m":        ["<=", 0.05, "m",
		"[game data] UE brakes a let-go the same under a cast: the widest cast stop vs plain stop gap over the 12"],
	"dash_exit_slide_m":       ["~", [0.2, 0.5], "m", "[game data] then the walking stop"],
	# the fitted ground dash curves (docs/SUPERVIVE_FEEL.md "Dash speed curves"): peak share of the dash, peak
	# speed against the mean, distance kept, hand-over to the walk at or under run speed
	"dash_curve_gunslinger_peak_u":   ["~", [0.04, 0.18], "", "[footage] Ghost slide peaks 0.04-0.06s into 0.47s"],
	"dash_curve_gunslinger_peak_k":   ["~", [1.65, 1.9], "x", "[footage] Ghost peak 18.4 m/s, mean 10.2 (fit 1.81)"],
	"dash_curve_juggernaut_peak_u":   ["~", [0.2, 0.36], "", "[footage] Brall Quick Dash peaks 0.13s into 0.47s"],
	"dash_curve_juggernaut_peak_k":   ["~", [1.6, 1.8], "x", "[footage] Brall peak 17.1 m/s, mean 9.8 (fit 1.73)"],
	"dash_curve_archer_peak_u":       ["~", [0.36, 0.52], "", "[footage] Myth roll peaks 0.15s into 0.33s"],
	"dash_curve_archer_peak_k":       ["~", [1.7, 1.95], "x", "[footage] Myth peak 18.4 m/s, mean 9.9 (fit 1.86)"],
	"dash_curve_bulwark_peak_u":      ["~", [0.4, 0.6], "", "[footage] Oath Smash peaks 0.17s into 0.33s"],
	"dash_curve_bulwark_peak_k":      ["~", [1.12, 1.3], "x", "[footage] Oath peak 530 px/s, mean 436"],
	"dash_curve_bulwark_exit_k":      ["~", [0.62, 0.8], "x", "[footage] Oath slides on into the spin (fit 0.66)"],
	"dash_curve_tender_air_dist":     ["~", [0.9, 1.1], "x", "Meeko's glide: dash.air.dist 13.3m (footage 11-15)"],
	"dash_curve_tender_air_time":     ["~", [0.9, 1.08], "x", "[footage] Elluna air dash 0.8-1.1s (0.95)"],
	"dash_curve_tender_air_exit_k":   ["~", [0.4, 0.65], "x", "[footage] floats out at 40-65% of the burst"],
	"dash_curve_dist":                ["~", [0.95, 1.05], "x", "the curve's mean is 1: the kit distance holds"],
	"dash_curve_time":                ["~", [0.95, 1.08], "x", "the curve runs in the kit's own (feel-scaled) time"],
	"dash_curve_exit_run":            ["<=", 1.05, "x",
		"[footage] the skid falls through run speed, the walk takes it"],
	"coyote_frames":           [">=", 7.0, "frames",
		"coyote_s 0.12s: latest press after a walk-off (none in the source)"],
	"jump_buffer_frames":      [">=", 7.0, "frames",
		"jump_buffer_s 0.12s: earliest press before landing (source silent)"],
	"jump_buffer_dash_frames": [">=", 7.0, "frames", "the same window across the end of an air dash that lands"],
	"dash_jump_eaten":         ["<=", 0.0, "frames", "a jump pressed on any frame of a ground dash fires that step"],
	"slow_land_0p1s":          ["~", [0.69, 0.71], "x",
		"[game data] the cap steps at once; the body brakes to it (22.2 m/s2 + 2/s x v): ~0.05s"],
	"slow_land_0p3s":          ["~", [0.69, 0.71], "x", "[game data] and holds there"],
	"slow_end_0p1s":           ["~", [0.99, 1.01], "x", "[game data] back up at MaxAcceleration 47-54 m/s2 (~0.03s)"],
	"slow_end_0p3s":           ["~", [0.99, 1.01], "x", "[game data] and holds there"],
	"haste_land_0p1s":         ["~", [0.99, 1.01], "x", "[game data] a haste lands as a Slow ends: MaxAcceleration"],
	"haste_end_0p1s":          ["~", [0.99, 1.01], "x", "[game data] and ends as a Slow lands: the walking brake"],
	"jump_hold_dv":            ["<=", 0.01, "m/s", "JumpMaxHoldTime undecoded: a hold rises like a tap"],
	"rejump_frames":           ["<=", 1.0, "frames", "JumpCooldown undecoded: no re-jump delay"],
	"freefall_1s_depth":       ["~", [6.8, 8.0], "m", "[game data] gravity 1470 uu/s2, cap 1200 uu/s: 7.1m"],
	"abyss_fall_vy_deep":      ["~", [10.0, 10.8], "m/s", "[game data] AbyssFallSlowSpeedLimit 12 to 10 m/s"],
	"abyss_fall_t":            [">=", 1.8, "s", "[game data] off the lip to AbyssHeight (17.5m) in ~2s"],
	"glide_open_press_frames": ["<=", 1.0, "frames",
		"[wiki/guide] hold jump in the air to glide; a second press opens at once"],
	"glide_press_held_s":      [">=", 1.0, "s", "owner 11-08: jump, let go, press and hold: it opens, stays open"],
	"glide_hold_opens":        ["<=", 0.0, "", "owner 11-08: Space held 2 s from the jump never opens the glider"],
	"albert_lmb_hold_glides":  ["<=", 0.0, "", "owner 11-08: Albert holding LMB and Space never glides"],
	"glide_open_button_frames": ["<=", 1.0, "frames", "dedicated glide button: no tap/hold ambiguity"],
	"glide_catch_t":           ["<=", 0.20, "s", "[guide] opens 'instantly'; the catch rate is ours (max locked)"],
	"glide_start_vy":          ["~", [0.85, 1.4], "m/s", "[game data] GlideStartFallSpeedMin: opened rising, it falls"],
	"glide_speed":             ["~", [4.5, 5.5], "m/s", "[game data] MaxGlide 500 uu/s +-10% (item 163)"],
	"glide_sink":              ["~", [1.2, 1.6], "m/s",
		"floatier than [spec] 2-4 eyeball / [est] 2.2 (owner: sank too fast)"],
	"glide_turn90_t":          ["~", [0.3, 0.6], "s",
		"[game data] GlideTargetXYForce 162,500 / Mass 100: turn inertia"],
	"glide_reverse_t":         ["~", [0.45, 0.8], "s", "[game data] the same 16.25 m/s^2 brakes a reversal in ~0.6 s"],
	"glide_brake_ratio":       ["<=", 0.80, "x", "steering against heading brakes momentum (speed vs letting go)"],
	"glide_high_sink":         ["~", [3.3, 3.6], "m/s", "[game data] GlideDownwardForce: above 8.5m"],
	"glide_swoop_speed":       ["<=", 5.3, "m/s",
		"[owner 11-08 item 8] a high glide's pull-down never turns into speed"],
	"dive_vy":                 ["~", [32.0, 32.5], "m/s", "[game data] GlideDiveZTargetSpeed -3250 uu/s, crouch held"],
	"dive_vy_t":               ["~", [0.6, 0.9], "s", "[game data] GlideDiveZForceMax 350,000 / Mass 100 = 35 m/s^2"],
	"dive_steer_ratio":        ["~", [0.2, 0.3], "x", "[game data] GlideDiveXYForceMultiplier 0.25 of the glide steer"],
	"dive_cancel_h":           ["~", [2.9, 3.5], "m", "[game data] GlideDiveCancelDistance 350 uu, the glide catches"],
	"dive_timeout_s":          ["~", [9.9, 10.1], "s", "[game data] GlideDiveTimeout 10 s of holding ends the plunge"],
	"dive_swoop_speed":        ["<=", 6.0, "m/s", "[owner 11-08 item 8] pulling out of a dive adds no speed"],
	"dive_land_vy":            ["<=", 4.0, "m/s", "[game data] held down: catches 3.5 m up, lands at the sink"],
	"dive_release_glide_t":    ["~", [0.3, 0.7], "s", "[game data] let go high up: the usual catch, back gliding"],
	"dashglide_open_speed":    [">=", 12.0, "m/s",
		"[wiki] gliding right after a lateral impulse keeps momentum and increases glide speed"],
	"dashglide_1s_speed":      ["<=", 9.0, "m/s",
		"[owner 11-08 item 9] glide drag: dash speed bleeds back toward cruise"],
	"dashglide_2s_speed":      ["<=", 6.5, "m/s", "[owner 11-08 item 9] ...within 1-2 s"],
	"dashglide_reopen_frames": ["<=", 1.0, "frames", "glider is back the step the dash ends while glide is held"],
	"reglide_frames":          ["<=", 1.0, "frames", "glide-cancel then re-hold reopens at once"],
	"abyss_lift_t":            ["<=", 1.0, "s",
		"[footage] back at island level (balloon line, 0.5m under the lip) ~1s after opening 4m deep"],
	"abyss_bounce_m":          [">=", 1.5, "m", "[est] a bouncy lift from 6m deep"],
	"abyss_kill_depth":        ["~", [17.0, 18.0], "m", "[game data] AbyssHeight -1750 uu: 17.5m under ground level"],
	"abyss_recover_depth":     [">=", 15.0, "m", "deepest a terminal fall can still glide out"],
	"abyss_tint_lip":          ["<=", 0.02, "", "no tint gliding at island level"],
	"abyss_tint_half":         [">=", 0.6, "", "[footage] tint deepens as you sink; owner: unmistakable early"],
	"abyss_tint_end":          [">=", 0.95, "", "full dark/red right before the point of no return"],
	"abyss_tint_rising":       ["<=", 0.02, "",
		"[footage D1] off while the glider lifts you back up, even below the lip"],
	"feather_toggle_frames":   ["<=", 1.0, "frames",
		"feathering: glider closes and reopens the step you let go / press again, no toggle penalty"],
	"feather_hold_m":          [">=", 0.0, "m", "holding glide over the abyss until the heat runs out (reference)"],
	"feather_m":               [">=", 0.0, "m",
		"tap-feathering over the abyss (lift taps, coast the gaps) until the heat runs out"],
	"feather_gain":            [">=", 1.15, "x",
		"[est] skilled feathering covers more ground than holding when heat is the limit"],
	"ledge_rise_t":            ["<=", 0.45, "s",
		"[game data] a 1.6m wall from a jump: jump-paced, suction lifts the rest"],
	"ledge_rise_vy_max":       ["<=", 7.0, "m/s", "[game data] suction cap 2.5 m/s: a rise never outruns the jump"],
	"ledge_rise_peak_m":       [">=", 0.2, "m", "no jump: you clear the lip with a small pop (height over the top)"],
	"ledge_fling_early_m":     [">=", 0.0, "m",
		"a jump as the rise starts: a weak fling (distance onto the top, reference)"],
	"ledge_fling_timed_m":     [">=", 1.5, "m", "[est] a jump in the window near the top: a real fling onto the top"],
	# a glider on a cliff face, a ruin wall or a Tenzo rock (UE CharacterMovementComponent slide, no source row
	# for the glider itself [?]): the part of its speed into the wall is dropped, the part along it kept, no
	# bounce, and the canopy stays open; the glide force then holds the along-wall speed at cruise x sin(angle)
	"glide_wall_tangent_lo":   [">=", 0.9, "x", "along-wall speed over the 1 s after a 30/60 degree hit, as a share"
		+ " of the tangent speed it hit with (worst case)"],
	"glide_wall_tangent_hi":   ["<=", 1.1, "x", "...and the best case: the wall neither brakes nor speeds the slide"],
	"glide_wall_speed_min":    [">=", 1.0, "m/s", "slowest frame while the keys push along the wall: no dead stop"],
	"glide_wall_flips":        ["<=", 0.0, "n", "along-wall speed sign flips over 1 s, every angled hit: no jitter"],
	"glide_wall_bounce_mps":   ["<=", 0.3, "m/s", "fastest frame moving away from the wall after any hit: no rebound"],
	"ledge_fling_timed_up_m":  [">=", 0.7, "m", "[est] ...and it goes higher than topping out with no jump"],
	"ledge_fling_gain":        [">=", 1.5, "x",
		"[est] timed fling distance vs no jump: a well-timed one is clearly rewarding"],
	"ledge_window_s":          [">=", 0.08, "s",
		"[est] the fling window lasts long enough to hit on purpose (~5+ steps)"],
	# three ledge heights x walk / jump / glide (docs/MOVEMENT_FEEL.md "Ledge mantle timing"): the rise from
	# the catch to the top, and the speed over the lip against the source's floor
	"ledge_jump_1.6_t":        ["<=", 0.35, "s", "[footage] rim to top ~0.2s; two terraces from a running jump"],
	"ledge_jump_2.4_t":        ["<=", 0.35, "s", "[footage] rim to top ~0.2s; three terraces from a running jump"],
	"ledge_glide_1.6_t":       ["<=", 0.35, "s", "[footage] rim to top ~0.2s; two terraces from a glide"],
	"ledge_glide_2.4_t":       ["<=", 0.35, "s", "[footage] rim to top ~0.2s; three terraces from a glide"],
	"ledge_glide_3.2_t":       ["<=", 0.35, "s",
		"[footage] rim to top ~0.2s; four terraces from a glide (a jump never catches them)"],
	"ledge_jump_1.6_keep":     [">=", 1.0, "x",
		"[game data] over the lip at least max(0.6x the approach, 3.5 m/s): MiniMantleXYSpeedTarget"],
	"ledge_jump_2.4_keep":     [">=", 1.0, "x", "[game data] the same floor, three terraces from a running jump"],
	"ledge_glide_1.6_keep":    [">=", 1.0, "x", "[game data] the same floor, two terraces from a glide"],
	"ledge_glide_2.4_keep":    [">=", 1.0, "x", "[game data] the same floor, three terraces from a glide"],
	"ledge_glide_3.2_keep":    [">=", 1.0, "x", "[game data] the same floor, four terraces from a glide"],
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
	"cam_glide_zoom_05":       ["~", [1.12, 1.25], "x", "[spec] glider opens the view +15..25%, mostly by +0.5 s"],
	"cam_dive_zoom_hold":      [">=", 0.98, "x", "plunge keeps the view open (min / start zoom)"],
	"cam_dive_land_view":      ["<=", 0.3, "x", "ground under a plunge, screens below centre"],
	"cam_land_step":           ["<=", 0.1, "x", "zoom-out lost on landing's first step: no pop"],
	"cam_land_left_05":        ["<=", 0.35, "x", "zoom-out left 0.5 s after landing: eased back"],
	"view_across_m":           ["~", [22.0, 25.0], "m",
		"ground across a 16:9 screen at the focus (camcal: ~17 hunter silhouettes across, as in gameplay frames)"],
	# (the reference body is the plain medium hunter since Vex took her own proportions: at the same camera it
	# measures 6.56% where the old reference, the default medium Warden at plain size, measured 6.07%, so the
	# range moved up by that 0.46; the camera did not change)
	"hunter_screen_pct":       ["~", [5.45, 6.65], "%",
		"medium hunter, feet to head straight up, as a share of screen height (camcal: its on-screen silhouette ~10.5%, as in gameplay frames; feelfix leans characters back 20 deg toward the camera, which shortens the straight-up measure from ~6.9% to ~5.5%)"],
	"hunter_feet_below_pct":   ["~", [1.5, 5.0], "%",
		"feet below the screen centre, as a share of screen height (camcal: ~3% in gameplay frames)"],
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
	for k in ["sec", "sig", "ult", "util1", "util2", "util3", "util4", "gear1", "gear2", "glide", "glide_btn", "glide_press_only", "jump", "dash", "fire", "crouch", "throw", "reload", "skill", "swap"]:
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

## A quiet match with one local hunter (P), everything unlocked, and the flat spot found.
func _begin(main: Node) -> void:
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

func run(main: Node) -> void:
	_begin(main)
	_ground()
	_face_turn()
	_haste()
	_jump()
	_glide()
	_glide_dive()
	_dash_glide()
	_dash_exit()
	_brake_exact()
	_dash_curves()
	_brake_cast()
	_slow_ramp()
	_plain_dash()
	_kit_dashes()
	LEDGE.new(self).run()
	_abyss_updraft()
	_feather()
	_ledge()
	_ledge_matrix()
	_glide_wall()
	_drop()
	_landing()
	_camera()
	_screen_scale()
	_e2e()
	load("res://tools/dash_refill_check.gd").run(self)
	bad += DIRS.new(m, flat, _reset).run()      # W A S D and the diagonals, on screen and in speed
	_standing_dash()          # last: it swaps the kit and model the framing rows measure
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
		P.inp["move"] = Vector2(1, 0)
		_steps(20)
		P.inp["move"] = Vector2(-1, 0)
		var tr := -1.0
		for i in 40:
			m.step(DT)
			if tr < 0.0 and P.vel.x <= -0.95 * top: tr = (i + 1) * DT
		rec("ground_reverse_t", tr)
		# 90 degree turn
		_reset(flat + Vector3(-2.5, 0, -2.5)); P.base_speed = top
		P.inp["move"] = Vector2(1, 0)
		_steps(20)
		P.inp["move"] = Vector2(0, 1)
		var t90 := -1.0
		for i in 40:
			m.step(DT)
			var hv := _hv(P)
			if t90 < 0.0 and hv.length() >= 0.9 * top and absf(hv.angle_to(Vector2(0, 1))) < deg_to_rad(10.0): t90 = (i + 1) * DT
		rec("ground_turn90_t", t90)
		# a shove over the run (a knock, a kit step) slides out under the same brake, keys held or not
		for keys in [Vector2.ZERO, Vector2(1, 0)]:
			_reset(flat + Vector3(-3.0, 0, 0))
			P.base_speed = top
			P.vel = Vector3(10.0, 0, 0)
			P.inp["move"] = keys
			var xs := P.pos.x
			for i in 90:
				m.step(DT)
				if _hv(P).length() <= (top + 0.02 if keys.x > 0.0 else 0.02): break
			rec("ground_shed_keys_m" if keys.x > 0.0 else "ground_shed_dist", P.pos.x - xs)
	P.cls = "medium"
	P.base_speed = float(Data.CLASSES["medium"]["speed"])

## The body turns to the cursor at the source's fixed yaw rate: a flick lands at once, a 180 in ~0.14s.
func _face_turn() -> void:
	var face0 := P.face
	var aim0: Vector3 = P.inp["aim"]
	for turn in [["face_turn180_t", PI], ["face_turn20_t", deg_to_rad(20.0)]]:
		_reset(flat)
		P.inp["aim"] = P.pos + Vector3(4, 0.9, 0)
		_steps(30)
		var a0 := atan2(-1.0, 0.0) + float(turn[1])
		P.inp["aim"] = P.pos + Vector3(-4.0 * sin(a0), 0.9, -4.0 * cos(a0))
		var t := -1.0
		for i in 30:
			m.step(DT)
			if t < 0.0 and absf(wrapf(P.face - a0, -PI, PI)) < deg_to_rad(1.0): t = (i + 1) * DT
		rec(turn[0], t)
	P.face = face0          # (the rows after read the body and the cursor as they were)
	P.inp["aim"] = aim0
# ---------------------------------------------------------------- move-speed bonuses (HunterMove.ground_speed)
## Top speed after a straight run with the bonuses and slows `setup` puts on.
func _run_speed(setup: Callable) -> float:
	_reset(flat + Vector3(-3, 0, 0))
	_clear_speed()
	setup.call()
	P.inp["move"] = Vector2(1, 0)
	_steps(30)
	return _hv(P).length()

func _haste() -> void:
	var plain := _run_speed(func() -> void: pass)
	var two := _run_speed(func() -> void:
		P.haste_t = 5.0
		P.add_buff("move_speed", 0.15, 5.0))
	rec("haste_two_bonus_x", two / plain)
	var slowed := _run_speed(func() -> void:
		P.haste_t = 5.0
		P.slow_t = 5.0
		P.slow_k = 0.4)
	rec("haste_bonus_slow_x", slowed / plain)
	var capped := _run_speed(func() -> void:
		P.haste_t = 5.0
		P.add_buff("move_speed", 1.0, 5.0))
	rec("haste_cap_mps", capped)
	_reset(flat)
	_clear_speed()

func _clear_speed() -> void:
	P.haste_t = 0.0
	P.slow_t = 0.0
	P.slow_k = 0.0
	P.kbuffs.erase("move_speed")

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
	# a tap against a held jump (Space down from the press on), 6 steps in, before the hold opens the glider
	var vy := [0.0, 0.0]
	for hold in 2:
		_reset(flat)
		P.inp["jump"] = true
		for i in 6:
			P.inp["glide"] = hold == 1
			m.step(DT)
		vy[hold] = P.vel.y
	rec("jump_hold_dv", absf(vy[1] - vy[0]))
	# two quick jumps: press again the step after the first one lands
	_reset(flat)
	P.inp["jump"] = true
	for i in 120:
		m.step(DT)
		if P.grounded and i > 2: break
	var again := -1
	for i in 10:
		P.inp["jump"] = i == 0
		m.step(DT)
		if P.vel.y > 0.0:
			again = i + 1
			break
	rec("rejump_frames", again)
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
	_dash_jump_windows(land_f)
	# free fall for 1s from rest
	_reset(flat + Vector3(0, 30.0, 0), false)
	var y0 := P.pos.y
	_steps(60)
	rec("freefall_1s_depth", y0 - P.pos.y)

## Jump presses around a dash: during a ground dash (every frame must jump out of it) and before landing
## with an air dash still running (the landing buffer must hold the press).
func _dash_jump_windows(land_f: int) -> void:
	_reset(flat)
	P.inp["move"] = Vector2.RIGHT
	P.inp["dash"] = true
	m.step(DT)
	_clear_inp()
	var dash_f := int(ceil(P.roll_t / DT))
	var eaten := 0
	for k in range(1, dash_f + 2):
		_reset(flat)
		P.inp["move"] = Vector2.RIGHT
		P.inp["dash"] = true
		m.step(DT)
		_clear_inp()
		_steps(k - 1)
		P.inp["jump"] = true
		m.step(DT)
		if P.vel.y <= 1.0: eaten += 1
	rec("dash_jump_eaten", eaten)
	# an air dash a hair off the ground: it holds its height, ends, and the body drops the last bit (about
	# 5 frames), so presses 6-7 frames before the landing land inside the dash
	var hover := Vector3(0, 0.05, 0)
	var land2 := 0
	var dash_ran := 0
	for i in 120:
		if i == 0:
			_reset(flat + hover, false)
			P.inp["move"] = Vector2.RIGHT
			P.inp["dash"] = true
		m.step(DT)
		_clear_inp()
		if P.roll_t > 0.0: dash_ran += 1
		if P.grounded:
			land2 = i + 1
			break
	var bb := -1 if dash_ran == 0 else 0
	for k in range(1, 16):
		if dash_ran == 0: break
		var jumped := false
		for i in land2 + 4:
			if i == 0:
				_reset(flat + hover, false)
				P.inp["move"] = Vector2.RIGHT
				P.inp["dash"] = true
			P.inp["jump"] = (i + 1) == land2 - k
			m.step(DT)
			P.inp["dash"] = false
			if i + 1 >= land2 and P.vel.y > 1.0: jumped = true
		if jumped and not P.gliding: bb = k
		else: break
	rec("jump_buffer_dash_frames", bb)

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
	var held := 0.0
	for i in 70:
		m.step(DT)
		P.inp["glide"] = true
		if f < 0 and P.gliding: f = i + 1
		if P.gliding and i >= 10: held += DT
	rec("glide_open_press_frames", f)
	# opened while still rising from the jump: the canopy never carries the rise on
	_reset(flat)
	P.inp["jump"] = true
	m.step(DT)
	_steps(3)
	var rise := P.vel.y
	P.inp["jump"] = true
	P.inp["glide"] = true
	m.step(DT)
	ok(rise > 3.0 and P.gliding, "glide_start: opened while rising at %.1f m/s" % rise)
	rec("glide_start_vy", -P.vel.y)
	var ga := HunterMove.glide_accel
	var gv := HunterMove.glide_start_vy
	ok(is_equal_approx(ga, 16.25), "glide_accel = GlideTargetXYForce 162,500 / Mass 100 (%s)" % ga)
	ok(is_equal_approx(gv, 0.85), "glide_start_vy = GlideStartFallSpeedMin 85 uu/s (%s)" % gv)
	rec("glide_press_held_s", held)
	# hold Space from the jump press: never a glide (the hold only keeps an open glider open)
	_reset(flat)
	P.inp["glide_press_only"] = true      # as a player's keys are (Match._gather_input)
	P.inp["jump"] = true
	var opened := false
	for i in 120:
		P.inp["glide"] = true
		m.step(DT)
		opened = opened or P.gliding
	rec("glide_hold_opens", 1.0 if opened else 0.0)
	# Albert with the swing held (LMB) and Space from the jump: no glide either
	var kit_was := P.arch
	P.set_arch("bulwark")
	_reset(flat)
	P.inp["glide_press_only"] = true
	P.inp["jump"] = true
	opened = false
	for i in 120:
		P.inp["fire"] = true
		P.inp["glide"] = true
		m.step(DT)
		opened = opened or P.gliding
	rec("albert_lmb_hold_glides", 1.0 if opened else 0.0)
	P.set_arch(kit_was)
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

## Gliding high over flat ground: pulled down to the height target; the drop never becomes speed.
func _glide_high() -> void:
	_reset(flat + Vector3(0, HunterMove.glide_height + 8.0, 0), false)
	P.inp["jump"] = true
	var sink := 0.0
	var swoop := 0.0
	for i in 600:
		P.inp["glide"] = true
		P.inp["move"] = Vector2(1, 0)
		m.step(DT)
		if i == 60: sink = -P.vel.y
		if P.pos.y - flat.y <= HunterMove.glide_height:
			swoop = _hv(P).length()
			break
	rec("glide_high_sink", sink)
	rec("glide_swoop_speed", swoop)

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

# ---------------------------------------------------------------- the walking brake against UE's own
## UE's ApplyVelocityBraking (CharacterMovementComponent.cpp) written out with the source's rows, as the oracle
## HunterMove.brake must equal: friction 1/s (GroundFriction 1 x BrakingFrictionFactor 2), BrakingDeceleration-
## Walking m/s2, BrakingSubStepTime s, BRAKE_TO_STOP_VELOCITY m/s. Speeds only: a let-go keeps its direction.
const UE_FRICTION := 2.0
const UE_BRAKE := 22.2
const UE_SUBSTEP := 1.0 / 33.0
const UE_STOP := 0.1

static func ue_brake(v: float, dt: float) -> float:
	var left := dt
	while left >= 1e-6:
		var sub := minf(UE_SUBSTEP, left * 0.5) if left > UE_SUBSTEP else left
		left -= sub
		v += (-UE_FRICTION * v - UE_BRAKE) * sub
		if v <= 0.0:
			return 0.0
	return 0.0 if v <= UE_STOP else v

## Metres the source slides from a run at v0 m/s drawn at `fps` (PhysWalking: brake the frame, move at what is left).
static func ue_slide(v0: float, fps: float) -> float:
	var x := 0.0
	while v0 > 0.0:
		v0 = ue_brake(v0, 1.0 / fps)
		x += v0 / fps
	return x

## The source's slide band for a run at v0: drawn at 30 fps (shortest) to 144 fps (longest).
static func ue_band(v0: float) -> Vector2:
	return Vector2(ue_slide(v0, 30.0), ue_slide(v0, 144.0))

## The run speed of every Hunter row in content/rules/hunter_move.json: speed -> its ids.
static func run_speeds() -> Dictionary:
	var out := {}
	for id in HunterMove.rules():
		var row = HunterMove.rules()[id]
		if row is Dictionary and row.has("speed"):
			var v := float(row["speed"])
			out[v] = out.get(v, []) + [id]
	return out

## HunterMove.brake against the oracle at the source's frame times and longer (sub-steps), from a run and a knock,
## then every Hunter's let-go on the real match step inside the source's band.
func _brake_exact() -> void:
	var err := 0.0
	for dt in [1.0 / 144.0, DT, 1.0 / 30.0, 0.1, 0.2]:
		for v0 in [4.45, 4.85, 10.0]:
			var a := Vector2(v0, 0).rotated(0.7)
			var b: float = v0
			while b > 0.0:
				a = HunterMove.brake(a, 1.0, dt)
				b = ue_brake(b, dt)
				err = maxf(err, absf(a.length() - b))
	rec("brake_vs_ue_err", err)
	var speeds := run_speeds()
	for v in speeds:
		_reset(flat + Vector3(-2.0, 0, 0))
		P.base_speed = v
		P.inp["move"] = Vector2(1, 0)
		_steps(30)
		var x0 := P.pos.x
		P.inp["move"] = Vector2.ZERO
		_steps(30)
		var band := ue_band(v)
		var got := P.pos.x - x0
		var what := "stop slide %.3f m from %.2f m/s in the source's %.3f-%.3f m (%s)"
		ok(got >= band.x and got <= band.y, what % [got, v, band.x, band.y, ", ".join(speeds[v])])

# ---------------------------------------------------------------- abyss lift, updrafts
var _rim := {}
## A rim tile with open sky beyond it: {at: ground point, dir: outward}.
## The source numbers in content/rules/hunter_move.json, then a class dash on flat ground, let go once it
## starts: it hands over at run speed and the walking stop takes it from there.
func _dash_exit() -> void:
	var brake := HunterMove.brake_decel
	var fric := HunterMove.brake_friction
	ok(is_equal_approx(brake, UE_BRAKE), "brake = BrakingDecelerationWalking 2220 uu/s2 (%s)" % brake)
	ok(is_equal_approx(fric, UE_FRICTION), "brake_friction = GroundFriction 1.0 x BrakingFrictionFactor 2 (%s)" % fric)
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

## Each fitted hero's plain ground dash, keys held the way it goes: the speed of every step on the curve, where
## it peaks, the distance against the kit's, and the speed it hands the walk.
func _dash_curves() -> void:
	var kit_was := P.arch
	var cls_was := P.cls
	for id in ["gunslinger", "juggernaut", "archer", "bulwark"]:
		P.reclass(Arch.weight(id), id)
		_reset(flat + Vector3(-3.0, 0, 0))
		P.inp["move"] = Vector2(1, 0)
		P.inp["dash"] = true
		var speeds: Array[float] = []
		var x0 := 0.0
		for i in 90:
			var x_was := P.pos.x
			var was_rolling := P.roll_t > 0.0
			m.step(DT)
			P.inp["dash"] = false
			if P.ak.curved.is_empty() and speeds.is_empty():
				continue
			if speeds.is_empty(): x0 = x_was
			speeds.append(P.roll_speed)
			if was_rolling and P.roll_t <= 0.0:
				break
		print("MFEEL dash curve: %s, %d steps" % [id, speeds.size()])
		var dd := P.ak.dash_def()
		var feel := P.ak.dash_feel()
		var mean := 0.0
		for v in speeds: mean += v / speeds.size()
		var peak := speeds.max() as float
		rec("dash_curve_%s_peak_u" % id, (speeds.find(peak) + 0.5) / speeds.size())
		rec("dash_curve_%s_peak_k" % id, peak / mean)
		var want := float(dd.get("whirl", dd.get("roll", dd.get("dist")))) * float(feel["dist"])
		rec("dash_curve_dist", (P.pos.x - x0) / want)
		rec("dash_curve_exit_run", _hv(P).length() / P.base_speed)
		if id == "bulwark":
			# the kit's own time and the speed the curve ends on (its last step against the dash's mean)
			var t := float(dd["whirl"]) / float(dd["whirl_speed"])
			t *= float(feel["time"])
			rec("dash_curve_time", speeds.size() * DT / t)
			rec("dash_curve_%s_exit_k" % id, float(speeds[-1]) / (want / t))
	_tender_glide()
	P.reclass(cls_was, kit_was)

## Meeko's air dash is her kit's own measured curve (tender.json dash.air: ramp, burst, float-out): from a
## height, so it ends on time rather than on a touchdown; its distance, time and the speed it floats out at.
func _tender_glide() -> void:
	P.reclass(Arch.weight("tender"), "tender")
	_reset(flat + Vector3(-6.0, 4.0, 0), false)
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	var speeds: Array[float] = []
	var x0 := P.pos.x
	for i in 120:
		var was_rolling := P.roll_t > 0.0
		m.step(DT)
		P.inp["dash"] = false
		if P.roll_t > 0.0: speeds.append(P.roll_speed)
		if was_rolling and P.roll_t <= 0.0:
			break
	var air: Dictionary = P.ak.dash_def()["air"]
	print("MFEEL dash curve: tender air, %d steps, top %.1f" % [speeds.size(), speeds.max()])
	rec("dash_curve_tender_air_dist", (P.pos.x - x0) / float(air["dist"]))
	rec("dash_curve_tender_air_time", speeds.size() * DT / float(air["time"]))
	rec("dash_curve_tender_air_exit_k", float(speeds[-1]) / float(speeds.max()))

## Let go of the keys and press RMB in the same frame at full speed, all 12 Hunters: the source brakes a let-go
## the same under a cast (UE CalcVelocity brakes whenever the keys are off; a cast's move scale only caps the
## walk, a CastHold hover steers like the ground), so the stop slide must match the plain stop. A tap that
## moves the Hunter itself (a step, a hop, a knock, leaving the ground) is printed and not compared.
func _brake_cast() -> void:
	var kit_was := P.arch
	var gap := 0.0
	for id in Arch.ids():
		P.cls = Arch.weight(id)          # (set_arch swaps a kit from another class for the class's default)
		P.set_arch(id)
		var plain := _cast_stop(false)
		var cast := _cast_stop(true)
		var row := "brake_cast %-11s plain %.3f m %.3f s, cast %.3f m %.3f s" % [id, plain["dist"], plain["t"], cast["dist"], cast["t"]]
		if cast["moved"]:
			print("MFEEL note %s: RMB moves him itself, no stop compare" % row)
			continue
		var d := absf(float(cast["dist"]) - float(plain["dist"]))
		gap = maxf(gap, d)
		ok(d <= 0.05 and float(cast["t"]) > 0.0, row)
	rec("brake_cast_gap_m", gap)
	P.cls = "medium"
	P.set_arch(kit_was)
	P.base_speed = float(Data.CLASSES["medium"]["speed"])

## A run to full speed, then the keys off (and RMB pressed the same frame when cast): the stop's distance
## and time, and whether the kit moved him (a dash, a knock, leaving the ground).
func _cast_stop(cast: bool) -> Dictionary:
	_reset(flat + Vector3(-3.0, 0, 0))
	P.inp["move"] = Vector2(1, 0)
	_steps(30)
	var x0 := P.pos.x
	P.inp["move"] = Vector2.ZERO
	P.inp["sec"] = cast
	var moved := false
	var ts := -1.0
	for i in 60:
		m.step(DT)
		moved = moved or P.roll_t > 0.0 or P.fly_t > 0.0 or P.knock_t > 0.0 or not P.grounded
		if ts < 0.0 and _hv(P).length() < 0.05: ts = (i + 1) * DT
	return {"dist": P.pos.x - x0, "t": ts, "moved": moved}
# ---------------------------------------------------------------- slow and haste ramp
## Speed 0.1 s and 0.3 s after a 30% Slow lands on a run and after it ends, as a share of the run speed
## before it, one kit per weight class; then a haste landing and ending on the medium kit. Every Slow and
## haste source moves the one cap, so this is the ramp rule for all of them (HunterMove.brake_rate).
func _slow_ramp() -> void:
	var kit_was := P.arch
	var cls_was := P.cls
	for id in ["thief", "gunslinger", "juggernaut"]:
		P.cls = Arch.weight(id)
		P.set_arch(id)
		var top := _run_up()
		print("MFEEL slow ramp on %s (%s), run %.2f m/s" % [id, P.cls, top])
		P.slow_t = 1.0
		P.slow_k = 0.3
		_steps(6)
		rec("slow_land_0p1s", _hv(P).length() / top)
		_steps(12)
		rec("slow_land_0p3s", _hv(P).length() / top)
		P.slow_t = 0.0
		_steps(6)
		rec("slow_end_0p1s", _hv(P).length() / top)
		_steps(12)
		rec("slow_end_0p3s", _hv(P).length() / top)
	P.cls = "medium"
	P.set_arch("gunslinger")
	P.haste_t = 9.0
	var hasted := _run_up()
	P.haste_t = 0.0
	var run := _run_up()
	P.haste_t = 9.0
	_steps(6)
	rec("haste_land_0p1s", _hv(P).length() / hasted)
	P.haste_t = 0.0
	_steps(6)
	rec("haste_end_0p1s", _hv(P).length() / run)
	P.slow_k = 0.0
	P.cls = cls_was
	P.set_arch(kit_was)

## A clean start on the flat, then half a second of running right: the settled run speed.
func _run_up() -> float:
	_reset(flat)
	P.inp["move"] = Vector2(1, 0)
	_steps(30)
	return _hv(P).length()

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

## Per-kit felt dash (KIT_PARITY gap 4): [metres, seconds] each plain dash really travels, ground and air.
## A sourced kit runs its source numbers as-is (no dash feel); the owner's x0.85 / x1.15 stays only on the
## kits with no source dash (content/rules/dash_feel.json). Claire's Skate and Ostra's Lantern Trade never
## pass through it. Tarek's hop is an arc, so his row is its reach and flight time, not a measured travel.
const KIT_DASH := {
	"gunslinger": {"ground": [4.8, 0.45], "src": "[footage] Combat Slide tap 4.8 m in 0.47 s"},
	# owner item 9 (6503f4fa8): her dash slower and lower, tuning.json dash_speed archer 0.7, so 0.27 s / 0.7
	"archer": {"ground": [3.0, 0.386], "src": "[footage] Phase Walk roll 3 m in 0.27 s, owner item 9: x0.7 speed"},
	"ashwick": {"ground": [3.4, 0.33], "air": [6.8, 0.28], "src": "[footage] Felix ram 3.4 m in 0.33 s, poof 6.8 m"},
	"tender": {"ground": [3.6, 0.2], "src": "[footage] Elluna 2 bh in 0.2 s (air glide: tender's own check)"},
	"bulwark": {"ground": [3.5, 0.17], "src": "[footage] Oath Spin Dash ~3.5 m in ~0.17 s"},
	# owner item 183 (bdb7703bd): with a charge her air cartwheel is the ground one (the sheet's 8.4 m / 0.95 s retired)
	"thief": {"ground": [4.5, 0.48], "air": [4.5, 0.48], "src": "[footage] Shiv Cartwheel 4.5 m in 0.48 s"},
	"juggernaut": {"ground": [3.825, 0.266], "src": "owner 113.8: a 0.07 s dip, then 4.5 m / 0.17 s x0.85 / x1.15"},
	"dredge": {"ground": [2.72, 0.184], "air": [3.672, 0.184],
			"src": "owner 23:40: 3.2 m / 0.16 s x0.85 / x1.15, air x1.35"},
	"dolm": {"ground": [2.38, 0.299], "src": "owner item 111: hop 2.8 m / 0.26 s x0.85 / x1.15"},
	# owner playtest 11-10 (754d177a0): the lane cut to 5.6-9.75 m, still at 40 m/s, so 5.6 / 40 x1.15
	"mage": {"ground": [5.6, 0.161], "src": "owner 11-10: shortest lane 5.6 m at 40 m/s, time x1.15"},
}
const DASH_TOL := [0.05, 0.035]      # share of the distance, s: about a step either side (frame-quantised travel)

func _kit_dashes() -> void:
	var was := [P.cls, P.arch]
	for id in KIT_DASH:
		var row: Dictionary = KIT_DASH[id]
		P.reclass(Arch.weight(id), id)
		for where in ["ground", "air"]:
			if not row.has(where): continue
			var want: Array = row[where]
			var got := _dolm_hop() if id == "dolm" else _felt_dash(where == "air")
			var hit := absf(got[0] / float(want[0]) - 1.0) <= DASH_TOL[0]
			hit = hit and absf(got[1] - float(want[1])) <= DASH_TOL[1]
			ok(hit, "felt dash %-10s %-6s %.2f m in %.3f s, want %.2f m in %.3f s  (%s)"
					% [id, where, got[0], got[1], want[0], want[1], row["src"]])
		var src := String(row["src"]).begins_with("[footage]")
		var feel: Dictionary = P.ak.dash_feel()
		var off := float(feel["dist"]) == 1.0 and float(feel["time"]) == 1.0
		ok(not src or off, "felt dash %s: a sourced dash is off the dash feel" % id)
	P.reclass(was[0], was[1])

## One plain dash the way you move: the distance and time of the travel itself (move keys let go during it),
## to the moment the dash ends. The step it ends in runs the dash for the `left` it had, then the hand-over
## (the run, or in the air the dash's speed carried on, owner 11-08) for the rest: that tail isn't the dash.
func _felt_dash(air: bool) -> Array:
	_steps(30)          # past any chain gap from the dash before (Grimble's Barge refuses a press inside it)
	_reset(flat + Vector3(-3.0, 6.0 if air else 0.0, 0), not air)
	P.inp["move"] = Vector2(1, 0)
	P.inp["dash"] = true
	var start := Vector3.INF
	var n := 0
	for i in 150:
		var before := P.pos
		var left := minf(P.roll_t, DT)
		m.step(DT)
		P.inp["dash"] = false
		if P.roll_t > 0.0:
			P.inp["move"] = Vector2.ZERO
			if start == Vector3.INF: start = before
			n += 1
		elif start != Vector3.INF:
			var end := Vector2(P.pos.x, P.pos.z) - _hv(P) * (DT - left)
			return [end.distance_to(Vector2(start.x, start.z)), n * DT + left]
	return [0.0, 0.0]

## Tarek's Rock Hop is an arc off a rock: its reach and flight as the hop reads them.
func _dolm_hop() -> Array:
	var dd := P.ak.dash_def()
	var feel: Dictionary = P.ak.dash_feel()
	return [float(dd["dist"]) * float(feel["dist"]), float(dd["time"]) * float(feel["time"])]

## A dash pressed standing still (no move keys) goes toward the cursor for every Hunter, never the way the
## body faces: the cursor-aimed sources (Oath, Tetra, Kingpin, Brall, Felix, Void, Joule; Myth tested in
## supervive_kits.md) do; the move-direction ones (Shiv, Elluna, Celeste, Ghost) were never filmed standing
## (briefs/hero-ref, rows marked [?]), so they keep the shared rule (ArchKit.dash_dir). Shift is held
## STAND_HOLD so the hold kits (Swap, Wirerun, Skate, Slide) release too.
const STAND_HOLD := 18           # frames (0.3 s) Shift is held down
const STAND_AIM := Vector2(0.6, -0.8)   # the cursor's direction from the hunter
const STAND_DEG := 20.0          # widest allowed miss of the cursor, degrees
func _standing_dash() -> void:
	var cls_was := P.cls
	var arch_was := P.arch
	var wid_was := P.wid
	for a in Arch.ids():
		P.reclass(Arch.weight(a), a)
		_reset(flat)
		P.face = PI / 2.0         # the body faces -x, away from the cursor
		P.inp["aim"] = flat + Vector3(STAND_AIM.x, 0, STAND_AIM.y) * 5.0
		P.inp["dash"] = true
		P.inp["dash_down"] = true
		for i in 150:             # 2.5 s: Lantern Trade's 1.8 s lob lands after the hold
			m.step(DT)
			P.inp["dash"] = false
			P.inp["dash_down"] = i < STAND_HOLD
		var moved := Vector2(P.pos.x - flat.x, P.pos.z - flat.z)
		var miss := rad_to_deg(absf(moved.angle_to(STAND_AIM)))
		ok(moved.length() > 0.5 and miss < STAND_DEG, "%s standing dash goes to the cursor (%.2f m, %.0f deg off)" % [a, moved.length(), miss])
		P.inp["dash_down"] = false
	P.reclass(cls_was, arch_was, wid_was)

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
			P.inp["jump"] = i == 0     # (the press opens it: a held Space never does)
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
			P.inp["jump"] = holding and not P.inp["glide"]     # (a fresh press opens it: a held Space never does)
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
	P.inp["jump"] = true     # (the press opens it: a held Space never does)
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
						if not w.inb(hk.x, hk.y) \
								or w.kind[w.idx(hk.x, hk.y)] != World.T_GROUND \
								or int(w.level[w.idx(hk.x, hk.y)]) != l0 + 2 \
								or w.sheer.has(w.idx(hk.x, hk.y)): good = false
					for back in range(0, 4):
						var lb: Vector2i = Vector2i(x, z) + side * sd - d * back
						if not w.inb(lb.x, lb.y) \
								or w.kind[w.idx(lb.x, lb.y)] != World.T_GROUND \
								or int(w.level[w.idx(lb.x, lb.y)]) != l0 \
								or w.stairs.has(w.idx(lb.x, lb.y)): good = false
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
	if wl.is_empty():
		wl = _carve_wall(2)
	var n: Vector2 = wl["n"]
	var top: float = wl["top"]
	var out := {}
	for mode in ["none", "early", "timed"]:
		_reset(Vector3(wl["at"].x, wl["low"], wl["at"].y))
		var rising := 0; var t_rise := -1.0; var peak := -1e9; var lip_at := Vector2.INF; var jumped := false
		var win_steps := 0
		var vy_max := 0.0
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
			if P.call("mantling"): vy_max = maxf(vy_max, P.vel.y)
			if rising > 0 and not P.call("mantling"):
				peak = maxf(peak, P.pos.y)
				if lip_at == Vector2.INF: lip_at = Vector2(P.pos.x, P.pos.z)
			if rising > 0 and P.grounded and not P.call("mantling"):
				break
		out[mode] = {"t": t_rise, "peak": peak - top, "dist": (Vector2(P.pos.x, P.pos.z) - lip_at).dot(n) if lip_at != Vector2.INF else 0.0, "vy": vy_max, "win": win_steps * DT}
	rec("ledge_rise_t", out["none"]["t"] if out["none"]["t"] > 0.0 else 9.0)
	rec("ledge_rise_peak_m", out["none"]["peak"])
	rec("ledge_rise_vy_max", out["none"]["vy"])
	rec("ledge_fling_early_m", out["early"]["dist"])
	rec("ledge_fling_timed_m", out["timed"]["dist"])
	rec("ledge_fling_timed_up_m", out["timed"]["peak"])
	rec("ledge_fling_gain", out["timed"]["dist"] / maxf(0.1, out["none"]["dist"]))
	rec("ledge_window_s", out["none"]["win"])
	print("MFEEL ledge: no jump +%.2fm then %.2fm on; early jump +%.2fm %.2fm; timed +%.2fm %.2fm" % [out["none"]["peak"], out["none"]["dist"], out["early"]["peak"], out["early"]["dist"], out["timed"]["peak"], out["timed"]["dist"]])
	_uncarve(wl)

## Carves a straight wall `terraces` high beside the flat test spot: a 5x3 block 3m east of it, with
## the spot's level ground in front. The wall (face point, normal, low and top heights) and the tiles
## to put back (_uncarve: later sections use the flat spot).
func _carve_wall(terraces: int) -> Dictionary:
	var x0 := int(floor(flat.x)); var z0 := int(floor(flat.z))
	var lv := int(w.level[w.idx(x0, z0)])
	var carved := []
	for dz in range(-2, 3):
		for dx in range(3, 6):
			var ci := w.idx(x0 + dx, z0 + dz)
			carved.append([ci, w.level[ci]])
			w.level[ci] = lv + terraces
	var face := Vector2(x0 + 3.0, z0 + 0.5)
	return {"at": face - Vector2(1, 0) * (P.r + 0.6), "n": Vector2(1, 0), "low": lv * World.LEVEL,
		"top": (lv + terraces) * World.LEVEL, "carved": carved}

func _uncarve(wl: Dictionary) -> void:
	for cv in wl.get("carved", []):
		w.level[int(cv[0])] = cv[1]

## Two, three and four terraces (1.6, 2.4, 3.2m; one is a walk-up ramp, LAYOUT_RULES) x walk / jump /
## glide, keys into the face: a walk never climbs (as in the source: jump, and you mantle at the top), a running
## jump tops two and three but never four (the wall tier), a glide tops all three. Caught ledges rise
## in the footage's time and send you over the lip at the source's speed floor.
func _ledge_matrix() -> void:
	for terraces in [2, 3, 4]:
		var wl := _carve_wall(terraces)
		var h: float = float(wl["top"]) - float(wl["low"])
		for mode in ["walk", "jump", "glide"]:
			var r := _ledge_run(wl, mode)
			var tag := "ledge_%s_%.1f" % [mode, h]
			var expect: bool = mode == "glide" or (mode == "jump" and terraces < 4)
			ok(bool(r["top"]) == expect, "%s %s the top" % [tag, "reaches" if expect else "never reaches"])
			if expect and bool(r["top"]):
				rec(tag + "_t", r["t"])
				var floor_v := maxf(float(r["v_in"]) * HunterMove.mantle_launch_keep, HunterMove.mantle_launch_min)
				rec(tag + "_keep", float(r["v_out"]) / floor_v)
			print("MFEEL ledge %.1fm %-5s: %s, in %.2f m/s, catch to top %.3fs, over the lip %.2f m/s" % [
				h, mode, "top" if r["top"] else "no", r["v_in"], r["t"], r["v_out"]])
		_uncarve(wl)

## One approach at the carved wall: whether you reach its top, the time from the catch to the top,
## and the horizontal speed you came in with and leave the lip with.
func _ledge_run(wl: Dictionary, mode: String) -> Dictionary:
	var n: Vector2 = wl["n"]
	var at: Vector2 = wl["at"]
	var top: float = wl["top"]
	if mode == "glide":
		# gliding in 3m back, aimed at the face's upper half (the sink takes a little off on the way)
		var st := at - n * 3.0
		_reset(Vector3(st.x, top - 0.3 + 0.6 * Hunter.GLIDE_SINK, st.y), false)
		P.last_gy = wl["low"]
		P.gliding = true
		P.vel = Vector3(n.x, 0.0, n.y) * Hunter.GLIDE_SPEED
	else:
		# running in from half a metre back (a jump at the face from a standstill catches it too, at ~2 m/s)
		var st := at - n * 0.5
		_reset(Vector3(st.x, wl["low"], st.y))
		P.vel = Vector3(n.x, 0.0, n.y) * P.base_speed
	var out := {"top": false, "t": 0.0, "v_in": 0.0, "v_out": 0.0}
	var rising := 0
	for i in 150:
		P.inp["move"] = n
		P.inp["glide"] = mode == "glide"
		P.inp["glide_btn"] = mode == "glide"
		P.inp["jump"] = mode == "jump" and i == 2
		m.step(DT)
		if P.call("mantling"):
			if rising == 0: out["v_in"] = float(P.get("lfloat").get("v_in", 0.0))
			rising += 1
		elif rising > 0 and float(out["v_out"]) == 0.0:
			out["v_out"] = _hv(P).length()
		if rising > 0 and float(out["t"]) == 0.0 and P.pos.y >= top: out["t"] = rising * DT
		if P.grounded and P.pos.y >= top - 0.05:
			out["top"] = true
			break
	return out

# ---------------------------------------------------------------- the opening drop
# ---------------------------------------------------------------- glider on a wall
## The glider flown into a wall at 0, 30 and 60 degrees off its normal, keys held the same way: a 7-terrace
## cliff and a one-tile ruin wall carved east of the flat spot, and a Tenzo rock placed turned 30 degrees
## off the grid (long enough to slide along for the whole second). Reads the 60 frames after the hit.
const GLIDE_WALL_DEG := [0.0, 30.0, 60.0]
const GLIDE_WALL_H := 2.5          # m up the glider starts: under a ruin wall's top, airborne a second after the hit
const GLIDE_WALL_ROCK_H := 1.85    # m: a rock blocks a body within 1.9 m of its base (Verbs.wall_blocks), so lower
const GLIDE_WALL_ROCK_LEN := 12.0  # m: a test rock long enough to slide along (a real one is 1.3 m)
const GLIDE_WALL_OUT := 1.0        # m in front of the face the glider starts
func _glide_wall() -> void:
	var x0 := int(floor(flat.x))
	var z0 := int(floor(flat.z))
	var lv := int(w.level[w.idx(x0, z0)])
	var gy := lv * World.LEVEL
	var tan := [9.0, 0.0]          # worst and best along-wall share over the angled hits
	var speed_min := 99.0
	var flips := 0
	var bounce := 0.0
	for what in ["cliff", "ruin wall", "tenzo rock"]:
		var carved := []           # [index, old level, old kind] to put back afterwards
		var rock := {}
		var n := Vector2(-1, 0)    # out of the wall
		var mid := Vector2(x0 + 3.0, z0 + 0.5)
		if what == "tenzo rock":
			n = n.rotated(deg_to_rad(30.0))      # off the grid, as an aimed rock lands
			mid = Vector2(x0 + 4.0, z0 + 0.5)
			# (someone else's rock, so it is a full wall; it faces the glider and outlasts the try)
			var at := Vector3(mid.x, gy, mid.y)
			rock = HeroZones.rock(m, m.hunters[1], at, -n, "gwall", GLIDE_WALL_ROCK_LEN, 30.0, 999.0, false)
		else:
			for dz in range(-5, 6):
				for dx in range(3, 6 if what == "cliff" else 4):
					var ci := w.idx(x0 + dx, z0 + dz)
					carved.append([ci, w.level[ci], w.kind[ci]])
					if what == "cliff":
						w.level[ci] = lv + 7
					else:
						w.kind[ci] = World.T_BLOCK
						w.walls[ci] = true
		var t := (-n).rotated(PI / 2.0)      # along the wall, the way a positive angle slides
		var h0 := GLIDE_WALL_ROCK_H if what == "tenzo rock" else GLIDE_WALL_H
		for deg in GLIDE_WALL_DEG:
			var r := _glide_wall_hit(mid, n, t, gy + h0, deg)
			var tag := "glide_wall %s %d deg" % [what, int(deg)]
			ok(r["hit"], "%s: the glider met the wall" % tag)
			ok(r["open"], "%s: the glider stays open on the wall" % tag)
			ok(r["into"] < 0.5, "%s: it stays pressed on the wall (%.2f m/s into it at most)" % [tag, r["into"]])
			bounce = maxf(bounce, r["out"])
			if deg > 0.0 and r["hit"]:
				var row := [tag, r["tan"], r["tan0"], r["slow"]]
				print("MFEEL %s: along-wall %.2fx of %.2f m/s, slowest %.2f m/s" % row)
				tan[0] = minf(tan[0], r["tan"])
				tan[1] = maxf(tan[1], r["tan"])
				speed_min = minf(speed_min, r["slow"])
				flips += int(r["flips"])
		if not rock.is_empty():
			HeroZones.remove_rock(m, rock, false)
		for c in carved:
			w.level[c[0]] = c[1]
			w.kind[c[0]] = c[2]
			w.walls.erase(c[0])
	rec("glide_wall_tangent_lo", tan[0])
	rec("glide_wall_tangent_hi", tan[1])
	rec("glide_wall_speed_min", speed_min)
	rec("glide_wall_flips", float(flips))
	rec("glide_wall_bounce_mps", bounce)

## One glide at the wall whose face passes `mid` with normal `n` (out of it) and tangent `t`, `deg` off the
## normal, from `y` up: {hit, open, into (max m/s into the wall after it), out (max m/s away), tan (mean
## along-wall share of tan0 over the second), tan0, slow (slowest frame), flips (along-wall sign flips)}.
func _glide_wall_hit(mid: Vector2, n: Vector2, t: Vector2, y: float, deg: float) -> Dictionary:
	var dir := (-n).rotated(deg_to_rad(deg))
	var start := mid + n * GLIDE_WALL_OUT - t * GLIDE_WALL_OUT * sin(deg_to_rad(deg))
	_reset(Vector3(start.x, y, start.y), false)
	P.gliding = true
	P.inp["glide"] = true
	P.inp["move"] = dir
	P.vel = Vector3(dir.x * Hunter.GLIDE_SPEED, 0.0, dir.y * Hunter.GLIDE_SPEED)
	var into0 := Hunter.GLIDE_SPEED * cos(deg_to_rad(deg))
	var r := {"hit": false, "open": true, "into": 0.0, "out": 0.0, "tan": 0.0, "slow": 99.0, "flips": 0,
		"tan0": Hunter.GLIDE_SPEED * sin(deg_to_rad(deg))}
	var since := 0           # frames since the hit
	var last_sign := 0.0
	for i in 120:
		m.step(DT)
		var hv := _hv(P)
		if not r["hit"]:
			r["hit"] = hv.dot(-n) < into0 * 0.5      # (the wall took the speed into it)
			if not r["hit"]:
				continue
		since += 1
		if since > 60:
			break
		r["open"] = r["open"] and P.gliding
		r["out"] = maxf(r["out"], hv.dot(n))
		r["into"] = maxf(r["into"], hv.dot(-n))
		if deg <= 0.0:
			continue
		var tv := hv.dot(t)
		r["tan"] += tv / 60.0 / r["tan0"]
		r["slow"] = minf(r["slow"], hv.length())
		if absf(tv) > 0.05:
			if last_sign != 0.0 and signf(tv) != last_sign:
				r["flips"] += 1
			last_sign = signf(tv)
	return r

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
	_glide_cam(cam)

## One step of play with the camera driven the way Match drives it (zoom, glide lead, follow).
func _cam_step(cam: CamRig) -> void:
	m.step(DT)
	P.render(DT, 0.0)
	cam.zoom_to = cam.air_zoom(P, m.player_altitude())
	cam.lead_vel = m.cam_lead_vel()
	cam.follow(P.position, DT, false)

## The view opens up under the glider, stays open through a plunge (so you see where you'll land), and
## eases back on landing, with no shake and no change of lens.
func _glide_cam(cam: CamRig) -> void:
	var lens := cam.fov
	cam.shake_left = 0.0
	cam.pull = 0.0
	# glide start: a jump from the ground, the glider opened at the top
	_reset(flat)
	cam.snap(P.pos)
	cam.zoom = 1.0
	P.inp["jump"] = true
	_cam_step(cam)
	P.inp["jump"] = false
	for i in 20: _cam_step(cam)
	var z0 := cam.zoom
	for i in 30:
		P.inp["glide"] = true
		_cam_step(cam)
	ok(P.gliding, "glide_cam: the glider is open")
	rec("cam_glide_zoom_05", cam.zoom / z0)
	# the plunge: steady glide high up, then crouch held to the cancel height
	_reset(flat + Vector3(0, 20.0, 0), false)
	P.inp["jump"] = true
	cam.snap(P.pos)
	for i in 90:
		P.inp["glide"] = true
		_cam_step(cam)
	cam.zoom = cam.zoom_to
	var z_dive := cam.zoom
	var z_min := z_dive
	var lead := 0.0
	var n_on := 0
	var land_y := -1.0
	for i in 240:
		P.inp["glide"] = true
		P.inp["crouch"] = true
		_cam_step(cam)
		if not P.glide_dive.on:
			break
		n_on += 1
		z_min = minf(z_min, cam.zoom)
		lead = maxf(lead, Vector2(cam.focus.x - P.pos.x, cam.focus.z - P.pos.z).length())
		var vh := cam.get_viewport().get_visible_rect().size.y
		var to16 := tan(deg_to_rad(cam.fov) * 0.5) / tan(deg_to_rad(cam.lens) * 0.5)      # (as on a 16:9 screen)
		land_y = maxf(land_y, (cam.unproject_position(Vector3(P.pos.x, P.ground(), P.pos.z)).y / vh - 0.5) * to16)
	ok(n_on > 10, "glide_cam: the plunge ran (%d steps)" % n_on)
	rec("cam_dive_zoom_hold", z_min / z_dive)
	rec("cam_dive_land_view", land_y)
	print("MFEEL glide_cam dive lead %.2fm, zoom at dive start %.2f" % [lead, z_dive])
	# landing: let the glide set you down, then 0.5 s on the ground
	P.inp["crouch"] = false
	for i in 600:
		P.inp["glide"] = true
		_cam_step(cam)
		if P.grounded: break
	ok(P.grounded, "glide_cam: landed")
	var z_land := cam.zoom
	P.inp["glide"] = false
	_cam_step(cam)
	rec("cam_land_step", (z_land - cam.zoom) / maxf(0.001, z_land - 1.0))
	for i in 29: _cam_step(cam)
	rec("cam_land_left_05", (cam.zoom - 1.0) / maxf(0.001, z_land - 1.0))
	print("MFEEL glide_cam zoom at landing %.2f, 0.5 s on %.2f" % [z_land, cam.zoom])
	ok(cam.fov == lens, "glide_cam: no lens change (fov %.1f)" % cam.fov)
	ok(cam.shake_left == 0.0 and cam.pull == 0.0, "glide_cam: no shake or pull-back")
	_clear_inp()

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
	var hfov := 2.0 * atan(tan(deg_to_rad(cam.lens) * 0.5) * CamRig.FRAME_ASPECT)
	# shares of a 16:9 screen's height: this view's shape widens or narrows the vertical lens (CamRig.frame_fov),
	# and a share from the centre scales with the tangent of half the lens
	var h16 := vh * tan(deg_to_rad(cam.lens) * 0.5) / tan(deg_to_rad(cam.fov) * 0.5)
	var ref := _stand_in("", MantleLook.at_home(PlayerLook.neutral()))
	var now := _model_span(cam, ref)
	print("MFEEL framing: style supervive pitch %.0f dist %.1f fov %.0f, viewport %dx%d, model scale %.2f, model %.2fm tall" % [rad_to_deg(cam.pitch), cam.dist, cam.fov, int(vw), int(vh), ref.scale.y, now[2]])
	rec("view_across_m", 2.0 * cam.dist * tan(hfov * 0.5))
	rec("hunter_screen_pct", now[1] / h16 * 100.0)
	rec("hunter_feet_below_pct", (float(now[3]) - vh * 0.5) / h16 * 100.0)
	for id in FRAME_HEROES:
		var hm := _stand_in(id, PlayerLook.neutral())
		var hs := _model_span(cam, hm)
		var kind := "3D" if hm.has_node("Warden") else "procedural"
		var feet := (float(hs[3]) - vh * 0.5) / h16 * 100.0
		print("MFEEL framing %s (%s model): %.2f%% of screen height, feet %.2f%% below the centre"
				% [id, kind, hs[1] / h16 * 100.0, feet])
		hm.free()
	# the same measure for the framing before movefeel (25m, hunters at their plain size), for the doc
	var d0 := cam.dist
	var vs: float = Hunter.VIS_SCALE
	cam.dist = 25.0
	ref.scale /= vs
	cam.snap(P.pos)
	var was := _model_span(cam, ref)
	print("MFEEL framing before (dist 25.0, scale /%.2f): %.1fm across, hunter %.1f%% of screen height (silhouette %.1f%%); now silhouette %.1f%%" % [vs, 2.0 * 25.0 * tan(hfov * 0.5), was[1] / h16 * 100.0, was[0] / h16 * 100.0, now[0] / h16 * 100.0])
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
