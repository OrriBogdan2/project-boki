extends RefCounted
## --airdash-glide-check: for every hunter, a fresh glide press in the air opens the glider (briefs/DECISIONS.md
## 2026-11-08: Shift cancels into glide instantly for every Hunter). Pressed during an air dash it ends the dash that
## step and the glider opens within DASH_OPEN steps with at least KEEP of the dash's speed (counted only up to the
## fastest a dash can hand the glider, Hunter.GLIDE_BOOST_MAX). Pressed after each ability (tap) it opens once the
## move's own keys end (AirLimits, item 162b). The delays, and the glide pressed during each hold, print as notes:
## docs/heroes/dash_interactions.md has them per hunter.

const KEEP := 0.7
const HEIGHT := 40.0
const DASH_OPEN := 2       # steps: a glide press during an air dash opens the glider this fast
const WATCH := 180         # steps after a glide press the glider has to open within (the longest cast: Broadside)
const HOLD_STEPS := 18     # steps a slot is held before glide is pressed during the hold
## Tapped abilities that keep the glider shut by an owner note: Tenzo's Quakefall (162b), Neve's Rimelock (item 65).
const SHUT := [["dolm", "rmb"], ["rimewright", "x"]]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("AIRGLIDE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch`, high above a flat, empty patch of ground.
func _match(main: Node, arch: String) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true,
		"cls": Arch.weight(arch), "arch": arch, "weapon": Arch.signature(arch),
	})
	m.set_process(false)
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()
	var hunter: Hunter = m.player
	hunter.set_arch(arch)
	hunter.unlock_all()
	hunter.lvl = 10
	hunter.gear[0] = {"id": "barrier", "rar": 1}     # Q: a glove that goes off in the air
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

func _speed(hunter: Hunter) -> float:
	return Vector2(hunter.vel.x, hunter.vel.z).length()

## Back up in the air with the kit fresh, nothing held and no glider.
func _sky(m: Match) -> void:
	var hunter: Hunter = m.player
	hunter.teleport(hunter.pos + Vector3(0, HEIGHT, 0))
	hunter.inp["move"] = Vector2(1, 0)
	hunter.inp["aim"] = hunter.pos + Vector3(8, 0.9, 0)
	for i in 12:
		m.step(Match.DT)

## What a press leaves behind, to tell whether it went off.
func _marks(hunter: Hunter) -> int:
	return [hunter.used, hunter.ak.cd, hunter.gear_cd[0], hunter.fire_cd, hunter.ammo, hunter.ak.e_t, hunter.ak.r_t,
			hunter.ak.rmb_down, hunter.ak.ult_running()].hash()

func _press_slot(hunter: Hunter, slot: String, down: bool) -> void:
	match slot:
		"lmb":
			hunter.inp["fire"] = down
		"x":
			if down:
				HunterKeys.ult_pressed(hunter)
		_:
			hunter.inp[DashFlow.KEY_OF[slot]] = down
			if slot == "rmb":
				hunter.inp["sec_hold"] = down

## Presses glide afresh (up last step, down now) and steps until the glider is open; returns the steps (-1: never).
## `held` runs each step (a hold keeps its key down).
func _glide_press(m: Match, held: Callable) -> int:
	var hunter: Hunter = m.player
	hunter.inp["glide"] = true
	hunter.inp["glide_btn"] = true
	for i in WATCH:
		held.call()
		m.step(Match.DT)
		if hunter.gliding:
			return i + 1
	return -1

## Air dash, then a fresh glide press three steps in: {steps, kept} (kept: the glider's opening speed over the dash's).
func _dash_case(m: Match) -> Dictionary:
	var hunter: Hunter = m.player
	_sky(m)
	hunter.do_dash()
	for i in 3:
		m.step(Match.DT)
	var dash_speed := minf(_speed(hunter), Hunter.GLIDE_BOOST_MAX)
	var steps := _glide_press(m, func() -> void: hunter.inp["move"] = Vector2(1, 0))
	return {"steps": steps, "kept": _speed(hunter) / maxf(0.01, dash_speed), "dash": dash_speed}

## Slot pressed in the air (tapped, or held HOLD_STEPS) and glide pressed after it (during the hold): steps until
## the glider opens, -1 never, -2 when the press did nothing in this setup.
func _slot_case(m: Match, slot: String, held: bool) -> int:
	var hunter: Hunter = m.player
	_sky(m)
	var before := _marks(hunter)
	_press_slot(hunter, slot, true)
	for i in (HOLD_STEPS if held else 1):
		m.step(Match.DT)
	if not held:
		_press_slot(hunter, slot, false)
		m.step(Match.DT)
	if _marks(hunter) == before:
		return -2
	return _glide_press(m, func() -> void: _press_slot(hunter, slot, held))

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		var d := _dash_case(m)
		m.queue_free()
		var slow := []
		var notes := []
		for slot in DashFlow.SLOTS:
			for held in [false, true]:
				var m2 := _match(main, arch)
				var steps := _slot_case(m2, slot, held)
				m2.queue_free()
				await main.get_tree().process_frame
				var shown := str(steps) if steps != -2 else "n/a"
				notes.append("%s %s %s" % ["hold" if held else "tap", slot, shown])
				if not held and steps == -1 and not [arch, slot] in SHUT:
					slow.append(slot)
		ok(int(d["steps"]) >= 1 and int(d["steps"]) <= DASH_OPEN and float(d["kept"]) >= KEEP and slow.is_empty(),
			"%s: glide press in an air dash opens in %d step(s) at %.0f%% of %.1f m/s%s" % [arch, d["steps"],
			100.0 * float(d["kept"]), d["dash"], "; shut after tap: %s" % slow if not slow.is_empty() else ""])
		print("AIRGLIDE note %s steps to glide after: %s" % [arch, ", ".join(notes)])
	print("AIRGLIDE DONE, failures: %d" % bad)
	main.get_tree().quit()
