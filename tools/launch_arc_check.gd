extends RefCounted
## --launch-arc-check: a Hunter launched off a Spring pad (content/utility/jump_pad.json) and up a map
## updraft, measured against the source table in docs/MOVEMENT_FEEL.md ("Launch arcs"). Drives the real
## match step, never touches the save. Prints one "LARC <key> = <value>  target ... ok|FAIL" line per
## measurement and "LAUNCH ARC CHECK DONE, failures: N" at the end.

var bad := 0
var m: Match
var w: World
var P: Hunter
var pad: Dictionary
var dir := Vector2(1, 0)           # the way every pad run heads (the open side of the pad spot)
const DT := 1.0 / 60.0

## key -> [op, target, unit, note]. Ops: "<=", ">=", "~" (target [lo, hi]).
const T := {
	"pad_vy":              ["~", [16.9, 17.1], "m/s", "[?] no source number: ours, UtilityUse.PAD_VY"],
	"pad_apex_m":          ["~", [9.0, 10.5], "m", "[?] PAD_VY^2 / 2g at [game data] gravity 14.7"],
	"pad_apex_t":          ["~", [1.05, 1.25], "s", "PAD_VY / g"],
	"pad_walk_hv":         ["~", [5.9, 6.1], "m/s", "[?] a walk-on leaves at the PAD_MIN_HV floor"],
	"pad_still_hv":        ["~", [5.9, 6.1], "m/s", "[?] standing on it: the floor, toward your aim"],
	"pad_walk_travel_m":   ["~", [8.5, 10.5], "m", "to pad height: [game data] FallingLateralFriction 0.375/s"],
	"pad_dash_carry":      [">=", 0.97, "x", "[wiki] a dash into a pad keeps its momentum (off / into)"],
	"pad_dash_apex_m":     ["~", [9.0, 10.5], "m", "a dash onto the pad still launches (it ends the dash)"],
	"pad_dash_travel_x":   [">=", 1.5, "x", "the dash speed carries the whole arc (over a walk-on)"],
	"pad_reverse_dv":      ["~", [1.5, 2.6], "m/s", "[game data] AirControl 0.015: reversed keys barely bend it"],
	"pad_side_m":          ["~", [0.5, 2.0], "m", "[game data] AirControl 0.015: sideways keys drift a little"],
	"pad_glide_auto":      ["<=", 0.0, "", "[wiki] no auto glide: you open it after a pad if you want to"],
	"pad_glide_press":     ["<=", 1.0, "frames", "a second press in the arc opens it at once (it is your call)"],
	"up_rise_t":           ["<=", 0.3, "s", "[est] to the 8 m/s climb (move-feel updraft_rise_t)"],
	"up_vy":               ["~", [8.9, 9.1], "m/s", "[?] GlideUpdraftMinZVel not decoded: ours 9 m/s"],
	"up_apex_over_top":    ["~", [2.2, 3.2], "m", "thrown past the top: 9^2 / 2g = 2.8 m"],
	"up_heat_used":        ["<=", 0.0, "", "[wiki] currents stop glider heat (in the column)"],
	"up_glide_kept":       [">=", 1.0, "", "the glider stays open the whole climb"],
	"up_cross_speed":      ["~", [4.5, 5.5], "m/s", "crossing keeps glide speed: it lifts, never shoves"],
	"up_no_glide_lift_m":  ["<=", 0.05, "m", "no glider, no lift: a fall through the column is a plain fall"],
}

func rec(key: String, v: float) -> void:
	var t: Array = T[key]
	var pass_ := false
	var tgt := ""
	match String(t[0]):
		"<=":
			pass_ = v <= float(t[1]) + 1e-6
			tgt = "<= %s" % str(t[1])
		">=":
			pass_ = v >= float(t[1]) - 1e-6
			tgt = ">= %s" % str(t[1])
		"~":
			var r: Array = t[1]
			pass_ = v >= float(r[0]) - 1e-6 and v <= float(r[1]) + 1e-6
			tgt = "in [%s, %s]" % [str(r[0]), str(r[1])]
	print("LARC %-20s = %7.3f %-6s target %-14s %s   (%s)" % [key, v, t[2], tgt, "ok" if pass_ else "FAIL", t[3]])
	if not pass_: bad += 1

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
		if h != P:
			h.teleport(Vector3(-500, 50, -500))
			h.out = true
	if P.kin: (P.kin as Kin).stow()
	P.ctrl = "local"
	P.unlock_all()
	_pad_arcs()
	_updraft()
	print("LAUNCH ARC CHECK DONE, failures: ", bad)
	main.get_tree().quit()

func _clear_inp() -> void:
	for k in ["sec", "sig", "ult", "glide", "glide_btn", "jump", "dash", "fire", "crouch", "throw"]:
		P.inp[k] = false
	P.inp["move"] = Vector2.ZERO

func _reset(p: Vector3, grounded := true) -> void:
	P.teleport(p)
	P.vel = Vector3.ZERO
	P.grounded = grounded
	P.pad = {}
	P.roll_t = 0.0
	P.knock_t = 0.0
	P.fly_t = 0.0
	P.dash_buf = 0.0
	P.dashes = P.max_dashes()
	P.gliding = false
	P.glide_fuel = 1.0
	P.glide_cd = 0.0
	P.air_t = 0.0
	P.coyote = 0.0
	P.jump_buf = 0.0
	P.inp["aim"] = p + Vector3(dir.x, 0.9, dir.y) * 3.0
	_clear_inp()

## A pad on flat ground with open ground (or open air) for 30 m along +x: the arcs fly clear.
func _place_pad() -> void:
	var at := Vector3.ZERO
	for k in 4000:
		var g: Vector3 = w.random_ground()
		var clear := true
		for d in range(-4, 31):
			var x := g.x + float(d)
			if (d <= 1 and (w.is_void(x, g.z) or absf(w.ground_at(x, g.z) - g.y) > 0.01)) or w.is_block(x, g.z) \
					or (not w.is_void(x, g.z) and w.ground_at(x, g.z) > g.y + 0.01):
				clear = false
				break
		if clear:
			at = Vector3(floor(g.x) + 0.5, g.y, floor(g.z) + 0.5)
			break
	var n := Node3D.new()
	m.add_child(n)
	pad = {"pos": at, "t": 1e9, "node": n, "cd": {}}
	m.gpads.append(pad)
	print("LARC pad at %s" % str(at))

## Run onto the pad from `back` metres behind it (dash: dash on the way), with `keys` held from the
## launch on (glide_f: a second jump press that many frames after the launch, then glide held). Returns
## {hv_in, hv0, hv_end, vy, apex, apex_t, travel, side, glided, open_f} from the launch until the arc is
## back down at pad height.
func _arc(back: float, dash: bool, keys: Vector2, glide_f := -1) -> Dictionary:
	var c: Vector3 = pad["pos"]
	(pad["cd"] as Dictionary).clear()
	_reset(Vector3(c.x - dir.x * back, c.y, c.z - dir.y * back))
	var r := {"hv_in": 0.0, "hv_end": 0.0, "vy": 0.0, "hv0": 0.0, "apex": 0.0, "apex_t": 0.0,
		"travel": 0.0, "side": 0.0, "glided": false, "open_f": -1}
	var f0 := -1
	for i in 600:
		if f0 < 0:
			P.inp["move"] = dir if back > 0.0 else Vector2.ZERO
			P.inp["dash"] = dash and i == 0
		else:
			P.inp["move"] = keys
			P.inp["dash"] = false
			P.inp["jump"] = i - f0 == glide_f
			P.inp["glide"] = glide_f >= 0 and i - f0 >= glide_f
		var hv_was := Vector2(P.vel.x, P.vel.z).length()
		m.step(DT)
		if f0 < 0:
			if P.vel.y > 10.0:
				r["hv_in"] = hv_was
				f0 = i
				r["vy"] = P.vel.y
				r["hv0"] = Vector2(P.vel.x, P.vel.z).length()
			continue
		var up := P.pos.y - c.y
		if up > float(r["apex"]):
			r["apex"] = up
			r["apex_t"] = (i - f0) * DT
		if P.gliding and not bool(r["glided"]):
			r["glided"] = true
			r["open_f"] = i - f0 - glide_f
		r["hv_end"] = Vector2(P.vel.x, P.vel.z).length()
		if i - f0 > 6 and (up <= 0.0 or P.grounded):
			break
	r["travel"] = (P.pos.x - c.x) * dir.x + (P.pos.z - c.z) * dir.y
	r["side"] = absf((P.pos.x - c.x) * dir.y - (P.pos.z - c.z) * dir.x)
	return r

func _pad_arcs() -> void:
	_place_pad()
	var walk := _arc(2.5, false, dir)
	rec("pad_vy", walk["vy"])
	rec("pad_apex_m", walk["apex"])
	rec("pad_apex_t", walk["apex_t"])
	rec("pad_walk_hv", walk["hv0"])
	rec("pad_walk_travel_m", walk["travel"])
	rec("pad_glide_auto", 1.0 if walk["glided"] else 0.0)
	rec("pad_still_hv", float(_arc(0.0, false, Vector2.ZERO)["hv0"]))
	var dash := _arc(1.5, true, dir)
	print("LARC dash: %.2f m/s into the pad, %.2f m/s off it" % [dash["hv_in"], dash["hv0"]])
	rec("pad_dash_carry", float(dash["hv0"]) / maxf(0.01, float(dash["hv_in"])))
	rec("pad_dash_apex_m", dash["apex"])
	rec("pad_dash_travel_x", float(dash["travel"]) / maxf(0.01, float(walk["travel"])))
	rec("pad_reverse_dv", float(walk["hv_end"]) - float(_arc(2.5, false, -dir)["hv_end"]))
	rec("pad_side_m", float(_arc(2.5, false, Vector2(dir.y, -dir.x))["side"]))
	rec("pad_glide_press", float(_arc(2.5, false, dir, 36)["open_f"]))

## A map updraft: a glider in the column climbs with no heat and is thrown past its top; one crossing it
## keeps glide speed; a fall with no glider gets no lift.
func _updraft() -> void:
	if w.updrafts.is_empty():
		print("LARC (no updrafts on this map, skipped)")
		return
	var u: Dictionary = w.updrafts[0]
	var c: Vector3 = u["pos"]
	var top := float(u["top"])
	_reset(Vector3(c.x, c.y + 1.0, c.z), false)
	P.gliding = true
	var rise_t := -1.0
	var vy := 0.0
	var apex := -INF
	var kept := 1.0
	var heat := -1.0
	for i in 600:
		P.inp["glide"] = true
		m.step(DT)
		vy = maxf(vy, P.vel.y)
		apex = maxf(apex, P.pos.y)
		if rise_t < 0.0 and P.vel.y >= 8.0: rise_t = (i + 1) * DT
		if not P.gliding: kept = 0.0
		if heat < 0.0 and w.updraft_at(P.pos).is_empty():
			heat = 1.0 - P.glide_fuel      # out of the top of the column
		if i > 10 and P.vel.y <= 0.0:
			break      # the top of the climb
	rec("up_rise_t", rise_t if rise_t > 0.0 else 9.0)
	rec("up_vy", vy)
	rec("up_apex_over_top", apex - top)
	rec("up_heat_used", heat)
	rec("up_glide_kept", kept)
	var r := float(u["r"])
	_reset(Vector3(c.x - dir.x * (r + 1.5), top - 3.0, c.z - dir.y * (r + 1.5)), false)
	P.gliding = true
	P.vel = Vector3(dir.x, 0.0, dir.y) * 5.0
	var cross := INF
	for i in 120:
		P.inp["glide"] = true
		P.inp["move"] = dir
		m.step(DT)
		if w.updraft_at(P.pos).size() > 0:
			cross = minf(cross, Vector2(P.vel.x, P.vel.z).length())
	rec("up_cross_speed", cross)
	_reset(Vector3(c.x, top - 3.0, c.z), false)
	var n := 20
	_steps(n)
	var plain_y := top - 3.0 - 0.5 * Hunter.H_GRAV * pow(n * DT, 2.0)
	rec("up_no_glide_lift_m", P.pos.y - plain_y)

func _steps(n: int) -> void:
	for i in n: m.step(DT)
