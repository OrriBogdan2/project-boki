extends "res://tools/move_feel_check.gd"
## --cinder-shift-check (playtest: "Cinder's Shift is too fast and goes about 2x as far as it should"):
## one Cinder Shift measured in the real match step with W held, as a player holds it. The Soot Ram on the ground
## and the poof in the air each go the ram's 3.4 m (docs/heroes/ashwick.md), within
## 5%, and a Shift in a running jump adds no more than the ram's length to where he lands (it added 7.7 m).
## Ends with "CINDER SHIFT CHECK DONE, failures: N".

const TOL := 0.05  # share of the target distance
const GROUND := [3.4, 0.33]  # [footage] Felix's ram, m and s
const AIR := [3.4, 0.28]  # the ram's length (it was 6.8 m); the lw_hop clip's 0.28 s kept
const FOE_AT := 2.0  # m ahead: inside the ram's 3.4 m, so the first foe stops it
const STUN := [0.9, 1.1]  # s: the reference dash stuns about 1 s (docs/KIT_PARITY.md "Crowd control")
const KNOCK := [1.8, 2.2]  # m at rest: the push 7 row of "Knock distances" (2.01 m)
const PEAK_MAX := 18.0  # m/s: the ram's own fitted peak (17.3); the poof was 24.3


func run(main: Node) -> void:
	_begin(main)
	p_v.reclass(Arch.weight("ashwick"), "ashwick")
	_one("ground", false, GROUND)
	_one("air", true, AIR)
	_hit_foe()
	var plain := _jump_land(false)
	var with := _jump_land(true)
	var cap := float(GROUND[0]) * (1.0 + TOL)
	ok(
		with - plain <= cap,
		(
			"Cinder jump + Shift lands %.2f m further than the same jump (%.2f vs %.2f m), want <= %.2f m"
			% [with - plain, with, plain, cap]
		)
	)
	print("CINDER SHIFT CHECK DONE, failures: %d" % bad)
	main.get_tree().quit()


## One Shift from a run (W held): the metres and seconds of the dash itself, and its top speed.
func _one(tag: String, air: bool, want: Array) -> void:
	_steps(30)
	_reset(flat + Vector3(-4.0, 6.0 if air else 0.0, 0), not air)
	p_v.inp["move"] = Vector2(1, 0)
	_steps(1 if air else 20)  # up to run speed (the air one straight from the hover)
	p_v.inp["dash"] = true
	var dash_m := 0.0
	var dash_t := 0.0
	var peak := 0.0
	for i in 60:
		var before := Vector2(p_v.pos.x, p_v.pos.z)
		var left := minf(p_v.roll_t, DT)
		m.step(DT)
		p_v.inp["dash"] = false
		var step := Vector2(p_v.pos.x, p_v.pos.z).distance_to(before)
		if p_v.roll_t > 0.0 or i == 0:
			peak = maxf(peak, _hv(p_v).length())
			dash_m += step
			dash_t += DT
			continue
		if left > 0.0:
			dash_m += step * (left / DT)  # the step it ends in: only its dash share
			dash_t += left
		break
	var hit := absf(dash_m / float(want[0]) - 1.0) <= TOL and absf(dash_t - float(want[1])) <= 0.035
	ok(
		hit and peak <= PEAK_MAX,
		(
			"Cinder Shift %-6s %.2f m in %.3f s (peak %.1f m/s), want %.2f m in %.2f s, peak <= %.0f"
			% [tag, dash_m, dash_t, peak, float(want[0]), float(want[1]), PEAK_MAX]
		)
	)


## The ram on a foe two metres ahead: the shared stun lands at about 1 s and the knock carries it as the table says.
func _hit_foe() -> void:
	_steps(30)
	_reset(flat + Vector3(-4.0, 0, 0))
	var foe: Hunter = m.hunters[1] if m.hunters[0] == p_v else m.hunters[0]
	foe.reclass(Arch.weight("gunslinger"), "gunslinger")  # a medium body, as the knock table measures
	foe.out = false
	foe.teleport(p_v.pos + Vector3(FOE_AT, 0, 0))
	foe.stun_t = 0.0
	var x0 := foe.pos.x
	p_v.inp["move"] = Vector2(1, 0)
	p_v.inp["dash"] = true
	var stun := 0.0
	for i in 120:
		m.step(DT)
		p_v.inp["dash"] = false
		if stun <= 0.0 and foe.stun_t > 0.0:
			stun = foe.stun_t + DT
		if i > 30 and _hv(foe).length() < 0.05:
			break
	var knock := foe.pos.x - x0
	ok(
		stun >= STUN[0] and stun <= STUN[1] and knock >= KNOCK[0] and knock <= KNOCK[1],
		(
			"Cinder Shift hit: stun %.2f s (want %.1f to %.1f), knock %.2f m (want %.1f to %.1f)"
			% [stun, STUN[0], STUN[1], knock, KNOCK[0], KNOCK[1]]
		)
	)
	foe.out = true
	foe.teleport(Vector3(-500, 50, -500))


## A running jump (W held), Shift 0.2 s in when `shift`: the metres from take-off to landing.
func _jump_land(shift: bool) -> float:
	_steps(30)
	_reset(flat + Vector3(-6.0, 0, 0))
	p_v.inp["move"] = Vector2(1, 0)
	_steps(20)
	var p0 := Vector2(p_v.pos.x, p_v.pos.z)
	p_v.inp["jump"] = true
	for i in 240:
		m.step(DT)
		p_v.inp["jump"] = false
		p_v.inp["dash"] = shift and i == 12
		if i > 3 and p_v.grounded:
			break
	return Vector2(p_v.pos.x, p_v.pos.z).distance_to(p0)
