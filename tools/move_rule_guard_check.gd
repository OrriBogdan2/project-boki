extends "res://tools/glide_hold_check.gd"
## --move-rule-guard-check: the owner's movement rules in briefs/DECISIONS.md, driven through every Hunter with
## a player's keys, one row per rule and Hunter, each row quoting the DECISIONS line it guards. These rules kept
## regressing across waves; the deeper numbers live in --move-feel-check, --air-control-check, --glide-hold-check
## and --glider-heat-check. The farm rows compare the farm avatar with the same Hunter in the Training Area.
## Prints "RULE ok|FAIL <hunter> | <DECISIONS line> | <what was measured>" and "RULE DONE, failures: N".

const RULES := {      # DECISIONS line (its date: [11-08], [11-11]; no date = "Movement and combat feel")
	"ledge": "Walking off ledges is ALWAYS allowed (never block it).",
	"hold": "Holding Space from the jump ... must never glide, no matter how long it is held. [11-08]",
	"double": "Glide opens only on a double press: jump, then press Space again in the air and hold. [11-08]",
	"start": "glide start adds no speed [11-08]",
	"shift": "Shift cancels into glide instantly for every Hunter. [11-08]",
	"heat": "An overheated glider still lifts you out of the abyss, at half strength, while it burns.",
	"fall": "falling never converts into horizontal momentum [11-11]",
	"air": "Match movement must have strong WASD air control [11-08]: accelerate toward input, strong counter-steer",
	"keep": "air control as SUPERVIVE (... never overwrite air velocity) [11-08]",
	"profile": "One shared movement profile for all modes [11-11]",
}
const HIGH_UP := 25.0          # m over the ground: room for a second of falling or gliding
const SHIFT_PRESSES := [2, 9]  # steps into an air Shift a fresh Space press lands (0.03 s, 0.15 s)
const AT_ONCE := 2             # steps: "instantly" = the glider is open on the press step or the next one
const JOLT := 2.0              # m/s in one step: the glide's own bleed sheds up to ~1.5 (Kael's 30 m/s), a snap more
const STILL := 0.05            # m/s: horizontal speed that counts as none

var heat = load("res://tools/glider_heat_check.gd").new()      # its abyss climb, on this check's match
var traces := {}       # arch -> the Training Area air/glide vx trace, compared with the farm's at the end

func row(arch: String, rule: String, cond: bool, what: String) -> void:
	print("RULE %s %s | %s | %s" % ["ok  " if cond else "FAIL", arch, RULES[rule], what])
	if not cond:
		bad += 1

func _hspeed() -> float:
	return Vector2(h.vel.x, h.vel.z).length()

## On the ground for 0.7 s, no keys: the last row's kit moves (a poof's kept speed, a cast) run out first.
func _settle() -> void:
	_reset(w.random_ground() + Vector3(0, 0.3, 0), Vector3.ZERO)
	h.inp["glide_press_only"] = true
	_steps(42)

## The player `up` m over open ground, moving `v`, no keys, one step taken.
func _air(up: float, v: Vector3) -> void:
	_reset(w.random_ground() + Vector3(0, up, 0), v)
	h.coyote = 0.0
	h.dash_buf = 0.0        # a Shift pressed by the last row fires no dash here
	h.inp["glide_press_only"] = true
	h.inp["aim"] = h.pos + Vector3(8, 0.9, 0)
	m.step(Match.DT)

## A fresh Space press (Space held after it); returns the steps until the glider was open (99 = not within 1 s).
func _press_glide() -> int:
	for i in 60:
		h.inp["jump"] = i == 0
		h.inp["glide"] = true
		m.step(Match.DT)
		if h.gliding:
			h.inp["jump"] = false
			return i + 1
	h.inp["jump"] = false
	return 99

func _steps(n: int) -> void:
	for i in n:
		m.step(Match.DT)

func _ledge(arch: String, edge: Dictionary) -> void:
	var out: Vector2 = edge["dir"]
	for crouched in [false, true]:
		_reset(Vector3(edge["ex"] - out.x * 1.2, edge["top"], edge["ez"] - out.y * 1.2), Vector3.ZERO)
		h.grounded = true
		h.last_gy = edge["top"]
		var t := 0.0
		var went := false
		while t < 1.6 and not went:
			h.inp["move"] = out
			h.inp["crouch"] = crouched
			m.step(Match.DT)
			t += Match.DT
			went = w.is_void(h.pos.x, h.pos.z) and not h.grounded and h.pos.y < float(edge["top"]) - 0.5
		h.inp["move"] = Vector2.ZERO
		h.inp["crouch"] = false
		var how := "crouched" if crouched else "walking"
		row(arch, "ledge", went, "%s at the rim: %s" % [how, "over it in %.2f s" % t if went else "held at %s" % h.pos])

func _space(arch: String) -> void:
	var held := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["jump"] = i == 0
	var t := float(_scenario(held)["t"])
	row(arch, "hold", t == 0.0, "jump and hold Space 2 s: glided %.2f s" % t)
	var double := func(i: int) -> void:
		h.inp["glide"] = i == 0 or i >= 12
		h.inp["jump"] = i == 0 or i == 12
	t = float(_scenario(double)["t"])
	row(arch, "double", t > 0.5, "jump, let go, press again and hold: glided %.2f s" % t)

## Opens the glider from a real jump in place (rising, D held from the jump, the second press 0.1 s in),
## a real fall (0.7 s from rest) and at rest in the air.
func _glide_start(arch: String) -> void:
	for how in ["jumping", "falling", "at rest"]:
		_settle()
		if how == "jumping":
			h.inp["move"] = Vector2(1, 0)
			for i in 6:          # Space down for the jump and held 0.1 s (a full jump), then let go a step
				h.inp["jump"] = i == 0
				h.inp["glide"] = i < 5
				m.step(Match.DT)
		else:
			_air(HIGH_UP, Vector3(3, 0, 0) if how == "falling" else Vector3.ZERO)
			_steps(42 if how == "falling" else 0)
		var hv := _hspeed()
		var vy := h.vel.y
		var steps := _press_glide()
		var ok_open := steps < 99 and _hspeed() <= hv + STILL and h.vel.y <= maxf(vy, 0.0) + STILL
		row(arch, "start", ok_open, "glider opened %s: h %.2f -> %.2f m/s, vy %.2f -> %.2f (open after %s steps)"
			% [how, hv, _hspeed(), vy, h.vel.y, "no" if steps == 99 else str(steps)])
		h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false

func _shift_glide(arch: String) -> void:
	var said := []
	var worst := 0
	var jolt := 0.0
	for at in SHIFT_PRESSES:
		_settle()
		_air(HIGH_UP, Vector3(0, Hunter.JUMP_V, 0))
		h.dashes = h.max_dashes()
		h.ex_cd = 0.0
		h.inp["move"] = Vector2(1, 0)
		h.inp["dash"] = true
		m.step(Match.DT)
		h.inp["dash"] = false
		_steps(at - 1)
		var moving := h.roll_t > 0.0 or (h.ak != null and h.ak.in_dash())
		var steps := _press_glide()
		worst = maxi(worst, steps)
		said.append("press %d steps in (%s): open after %s" % [at, h.move_kind if moving else "move over",
			"never" if steps == 99 else str(steps)])
		jolt = maxf(jolt, _glide_jolt() if steps < 99 else 0.0)
		h.inp["move"] = Vector2.ZERO
		h.inp["glide"] = false
	row(arch, "shift", worst <= AT_ONCE, "; ".join(said))
	row(arch, "keep", jolt <= JOLT,
		"the glide out of the Shift, D and Space held 0.6 s: largest change in one step %.2f m/s" % jolt)

## The largest one-step change of the horizontal velocity over 0.6 s of gliding (D and Space held).
func _glide_jolt() -> float:
	var most := 0.0
	var was := Vector2(h.vel.x, h.vel.z)
	for i in 36:
		m.step(Match.DT)
		var now := Vector2(h.vel.x, h.vel.z)
		most = maxf(most, (now - was).length())
		was = now
	return most

func _overheat(arch: String, edge: Dictionary) -> void:
	heat.m = m
	heat.w = w
	heat.h = h
	heat.marker = marker
	var full: Array = heat._climb(edge, 12.0, 1.0)
	var hot: Array = heat._climb(edge, 12.0, 0.0)
	var ratio := float(hot[0]) / maxf(0.01, float(full[0]))
	row(arch, "heat", float(hot[1]) > 0.0 and ratio > 0.4 and ratio < 0.62,
		"12 m under the lip: overheated lift %.1f m/s = %.2f of full (%.1f), back at the lip %s"
		% [hot[0], ratio, full[0], "in %.2f s" % hot[1] if float(hot[1]) > 0.0 else "never"])
	h.inp["glide"] = false

## Horizontal speed after `secs` of `drive` (called every step), stopping on the ground.
func _fall(secs: float, drive: Callable) -> float:
	for i in int(secs / Match.DT):
		drive.call(i)
		m.step(Match.DT)
		if h.grounded:
			break
	h.inp["glide"] = false
	h.inp["crouch"] = false
	h.inp["move"] = Vector2.ZERO
	return _hspeed()

func _falls(arch: String) -> void:
	_settle()
	var none := func(_i: int) -> void: pass
	var glide := func(_i: int) -> void: h.inp["glide"] = true
	var dive := func(i: int) -> void:
		h.inp["glide"] = true
		h.inp["crouch"] = i < 30
	_air(HIGH_UP, Vector3.ZERO)
	var dropped := _fall(1.0, none)
	_air(HIGH_UP, Vector3(0, -11, 0))
	_press_glide()
	var glided := _fall(1.0, glide)
	_air(HIGH_UP, Vector3.ZERO)
	_press_glide()
	var dived := _fall(1.0, dive)
	_air(2.5, Vector3(0, -15, 0))
	var landed := _fall(0.5, none)
	var worst := maxf(maxf(dropped, glided), maxf(dived, landed))
	row(arch, "fall", worst < STILL, "no keys, h-speed after: a 1 s fall %.2f, a glide opened falling 11 m/s %.2f, "
		% [dropped, glided] + "a dive and let go %.2f, landing at 15 m/s %.2f" % [dived, landed])
	var steer := []
	for vy in [0.0, -14.0]:
		_air(HIGH_UP, Vector3(0, vy, 0))
		_press_glide()
		steer.append(_fall(1.0, func(_i: int) -> void:
			h.inp["glide"] = true
			h.inp["move"] = Vector2(1, 0)))
	row(arch, "fall", absf(steer[0] - steer[1]) < 0.1,
		"glide holding D 1 s: h-speed %.2f opened at rest, %.2f opened falling 14 m/s" % [steer[0], steer[1]])

func _air_control(arch: String) -> void:
	var run := float(HunterMove.of(arch)["speed"])
	_settle()
	_air(HIGH_UP, Vector3.ZERO)
	h.inp["move"] = Vector2(1, 0)
	_steps(12)
	var quick := h.vel.x
	row(arch, "air", quick >= run * (1.0 - exp(-6.0 * 0.2)),
		"from rest in the air, D for 0.2 s: %.2f m/s (run %.2f, the old farm's exp 6/s %.2f)"
		% [quick, run, run * (1.0 - exp(-6.0 * 0.2))])
	_air(HIGH_UP, Vector3(-5, 0, 0))
	var t := 0.0
	while h.vel.x <= 0.0 and t < 1.0:
		h.inp["move"] = Vector2(1, 0)
		m.step(Match.DT)
		t += Match.DT
	row(arch, "air", t <= 0.2, "drifting back 5 m/s, D turns it forward in %.2f s (<= 0.2)" % t)
	_air(HIGH_UP, Vector3(0, 0, 8))
	var side := h.vel.z
	h.inp["move"] = Vector2(1, 0)
	m.step(Match.DT)
	var what := "a sideways %.2f m/s, a step of D held: %.2f m/s of it left" % [side, h.vel.z]
	row(arch, "keep", h.vel.z > side * 0.95, what)
	h.inp["move"] = Vector2.ZERO

## Holding D from a 3 m/s backward drift 6 m up, a glide-button press at 0.3 s: vx every 0.1 s and the open step.
func _trace() -> Array:
	_settle()
	_air(6.0, Vector3(-3, 0, 0))
	h.vel = Vector3(-3, 0, 0)
	h.inp["move"] = Vector2(1, 0)
	var vx := []
	var open := -1
	for i in 36:
		h.inp["glide"] = i >= 18
		h.inp["glide_btn"] = i >= 18
		m.step(Match.DT)
		if h.gliding and open < 0:
			open = i
		if i % 6 == 5:
			vx.append(h.vel.x)
	h.inp["move"] = Vector2.ZERO
	h.inp["glide"] = false
	h.inp["glide_btn"] = false
	return [vx, open]

func _hunter(arch: String) -> void:
	var edges := _edges(1)
	if edges.is_empty():
		row(arch, "ledge", false, "no open rim found on this map to test on")
	else:
		_ledge(arch, edges[0])
		_overheat(arch, edges[0])
	_space(arch)
	_glide_start(arch)
	_shift_glide(arch)
	_falls(arch)
	_air_control(arch)
	traces[arch] = _trace()

## The farm avatar as each Hunter, the same keys as _trace: the same vx samples and the same open step.
func _farm(main: Node) -> void:
	Save.d = Save.fresh()
	var pk := Save.new_kin("zapple", "Pip")
	Save.d["roster"].append(pk)
	Save.d["active"] = pk["uid"]
	Save.d["tutorial"]["home"] = true
	Save.d["tutorial"]["day1_done"] = true
	Econ.ensure()
	var hm = load("res://scripts/home/home.gd").new()
	main.add_child(hm)
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	while hm.building:
		await main.get_tree().process_frame
	hm.set_process(false)
	var spot: Vector3 = hm.ppos
	for arch in Arch.ORDER:
		Save.d["arch"] = arch
		hm.ppos = spot
		hm.py = hm._ground_h(hm.ppos.x, hm.ppos.z) + 6.0
		hm.pvy = 0.0
		hm.pvel = Vector3(-3, 0, 0)
		hm.gliding = false
		hm.dash_t = 0.0
		var vx := []
		var open := -1
		_press(Vector2(1, 0))
		for i in 36:
			if i == 18:
				Input.action_press("glide")
			hm._move_player(Match.DT)
			if hm.gliding and open < 0:
				open = i
			if i % 6 == 5:
				vx.append(hm.pvel.x)
			await main.get_tree().process_frame
		Input.action_release("glide")
		_press(Vector2.ZERO)
		var game: Array = traces[arch]
		var same: bool = open == game[1] and vx.size() == game[0].size()
		for i in mini(vx.size(), game[0].size()):
			same = same and absf(float(vx[i]) - float(game[0][i])) < 0.05
		var said := "farm vs Training Area, D from a 3 m/s drift, then a glide press: vx %s open %d | %s open %d" \
			% [_fmt(vx), open, _fmt(game[0]), game[1]]
		row(arch, "profile", same, said)
	hm.queue_free()

func _fmt(a: Array) -> String:
	return " ".join(a.map(func(x): return "%.2f" % x))

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		_start(main, arch)
		marker = w.random_ground()
		h.ai["land"] = marker
		_hunter(arch)
		m.queue_free()
		await main.get_tree().process_frame
	await _farm(main)
	print("RULE DONE, failures: ", bad)
	main.get_tree().quit()
