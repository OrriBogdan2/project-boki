extends RefCounted
## --wirerun-dist-check: Sparkle's (Ryzz, the mage) Wirerun covers a set distance: the owner's 11-10 playtest
## found it "goes way too far randomly" and "two in a row gives a super far dash". In a Training Area match on
## a levelled square it measures the press-to-rest distance of a tap, a full hold, one from a sprint, one off
## a jump, a diagonal one and at 30/60/120 Hz, then two back to back (the second pressed during the first and
## after it). Each must land within VAR_TOL of its own baseline, and a chain may not cover more than two runs
## plus a run's carry.

const VAR_TOL := 0.05             # share a case may differ from its baseline (or across tick rates)
const SETTLE := 3.0               # s after the press before the distance is read (the run, its exit, the fall)
const TAP := 1.0 / 30.0           # s the key is held on a tap (whole steps at 30, 60 and 120 Hz)
const FULL_HOLD := 1.0            # s held for a full lane (past the auto release)
const RUN_SPEED := 7.0            # m/s a sprint holds before the press (her base speed, rounded)

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WIRERUN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh Training Area match as Sparkle on a levelled square, the other Hunters and the monsters gone.
func _match(main: Node) -> Match:
	var m := Match.new()
	main.add_child(m)
	m.start({
		"training": true, "teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 1110, "no_drop": true,
		"cls": Arch.weight("mage"), "arch": "mage", "weapon": Arch.signature("mage"),
	})
	m.set_process(false)
	var hunter: Hunter = m.player
	hunter.set_arch("mage")
	hunter.unlock_all()
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(-90, 0, -90))
	var w: World = m.world
	var hx := int(floor(hunter.pos.x))
	var hz := int(floor(hunter.pos.z))
	var hi: int = w.idx(hx, hz)
	var lv: int = int(w.level[hi])
	for dz in range(-8, 70):
		for dx in range(-8, 70):
			if not w.inb(hx + dx, hz + dz):
				continue
			var i: int = w.idx(hx + dx, hz + dz)
			w.kind[i] = World.T_GROUND
			w.level[i] = lv
			w.island[i] = w.island[hi]
			w.stairs.erase(i)
			w.walls.erase(i)
			w.props.erase(i)
			w.bush.erase(i)
	hunter.teleport(Vector3(hx + 0.5, lv * World.LEVEL, hz + 0.5))
	return m

func _clear(m: Match) -> void:
	for mob in m.mobs:
		mob.queue_free()
	m.mobs.clear()

## Steps the match `secs` at `dt`, holding the dash key for the first `hold` steps of it.
func _steps(m: Match, secs: float, dt: float) -> void:
	for i in int(round(secs / dt)):
		m.step(dt)

## One press: hold the dash `hold` s at `dt`.
func _press(m: Match, hold: float, dt: float) -> void:
	var hunter: Hunter = m.player
	hunter.inp["dash_down"] = true
	hunter.do_dash()
	for i in maxi(1, int(round(hold / dt))):
		m.step(dt)
	hunter.inp["dash_down"] = false

## The distance (m, flat) from the press to where she comes to rest. `how`: {hold, dt, dir, sprint, jump,
## second: -1 none, else s after the first release the second press comes (0: buffered during the streak)}.
func _dash(main: Node, how: Dictionary) -> float:
	var m := _match(main)
	var hunter: Hunter = m.player
	var dt := float(how.get("dt", Match.DT))
	var dir: Vector2 = how.get("dir", Vector2(1, 0))
	var home := hunter.pos
	hunter.inp["move"] = Vector2.ZERO
	hunter.inp["aim"] = home + Vector3(dir.x, 0, dir.y) * 40.0 + Vector3(0, 0.9, 0)
	_steps(m, 0.6, dt)
	_clear(m)
	hunter.teleport(home)
	hunter.vel = Vector3.ZERO
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	if bool(how.get("sprint", false)):
		hunter.inp["move"] = dir
		_steps(m, 0.8, dt)
		hunter.inp["move"] = Vector2.ZERO
	if bool(how.get("jump", false)):
		hunter.do_jump()
		_steps(m, 0.2, dt)
	var from := hunter.pos
	hunter.inp["aim"] = from + Vector3(dir.x, 0, dir.y) * 40.0 + Vector3(0, 0.9, 0)
	_press(m, float(how.get("hold", TAP)), dt)
	var second := float(how.get("second", -1.0))
	if second >= 0.0:
		_steps(m, second, dt)
		hunter.dashes = hunter.max_dashes()      # a charge there for it (a second charge, or a reset)
		hunter.inp["aim"] = hunter.pos + Vector3(dir.x, 0, dir.y) * 40.0 + Vector3(0, 0.9, 0)
		_press(m, float(how.get("hold", TAP)), dt)
	_steps(m, SETTLE, dt)
	var d := Vector2(hunter.pos.x - from.x, hunter.pos.z - from.z).length()
	m.queue_free()
	await main.get_tree().process_frame
	return d

func _near(a: float, b: float) -> bool:
	return absf(a - b) <= VAR_TOL * b

func run(main: Node) -> void:
	Save.no_write = true
	var carry := RUN_SPEED * 0.6
	var tap: float = await _dash(main, {})
	var full: float = await _dash(main, {"hold": FULL_HOLD})
	var air: float = await _dash(main, {"jump": true})
	var air_full: float = await _dash(main, {"jump": true, "hold": FULL_HOLD})
	print("WIRERUN tap %.2f m, full hold %.2f m; off a jump %.2f m, %.2f m" % [tap, full, air, air_full])
	ok(air >= tap and air <= tap + carry, "a tap off a jump %.2f m: the tap's plus at most a run's carry" % air)
	ok(air_full >= full and air_full <= full + carry, "a full hold off a jump %.2f m: the same" % air_full)
	for hz in [30.0, 120.0]:
		var cases := [[{}, tap], [{"hold": FULL_HOLD}, full], [{"jump": true}, air]]
		for c: Array in cases:
			var how: Dictionary = c[0]
			var base: float = c[1]
			how["dt"] = 1.0 / hz
			var at: float = await _dash(main, how)
			ok(_near(at, base), "%s at %d Hz %.2f m (60 Hz %.2f m)" % [str(how.keys()), hz, at, base])
	var diag: float = await _dash(main, {"dir": Vector2(1, 1).normalized()})
	ok(_near(diag, tap), "a diagonal tap %.2f m" % diag)
	var sprint: float = await _dash(main, {"sprint": true})
	ok(sprint <= tap + carry, "a tap from a sprint %.2f m (tap %.2f + run carry %.2f)" % [sprint, tap, carry])
	for gap in [0.0, 0.25, 0.5]:
		for jump in [false, true]:
			var one: float = air if jump else tap
			var two: float = await _dash(main, {"second": gap, "jump": jump})
			ok(two <= 2.0 * one + carry, "two taps %.2fs apart%s %.2f m (max %.2f)" % [gap,
				" off a jump" if jump else "", two, 2.0 * one + carry])
	print("WIRERUN DONE, failures: %d" % bad)
	main.get_tree().quit()
