extends RefCounted
## --turn-cost-check[=<arch>]: a chained dash that turns back loses speed, one that goes on the same way
## keeps it, for every hunter (scripts/match/turn_cost.gd, docs/decisions/0083). On the ground a dash pressed the
## moment the last one ends goes at least SAME_KEEP of a fresh dash's distance the same way and at most
## REV_KEEP of it straight back; in the air a dash straight back hands over no more than the run speed
## (+ RUN_SLACK), the same way at least SAME_KEEP of a fresh air dash's carry. A hunter whose second press is
## not a new dash (a recast) is skipped.

const SAME_KEEP := 0.95
const REV_KEEP := 0.9
const RUN_SLACK := 1.1      # m/s over the run an air dash straight back may still carry
const HEIGHT := 40.0

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("TURNCOST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## A fresh match as `arch` on a flat, empty patch of ground.
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
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

func _keys(hunter: Hunter, dir: Vector2) -> void:
	hunter.inp["move"] = dir
	hunter.inp["aim"] = hunter.pos + Vector3(dir.x, 0, dir.y) * 8.0 + Vector3(0, 0.9, 0)

func _refill(hunter: Hunter) -> void:
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.air_dashed = false
	hunter.dash_buf = 0.0
	if hunter.ak and hunter.ak.cd.has("dash"):
		hunter.ak.cd["dash"] = 0.0

## Presses dash along `dir` and runs it out: {dist: metres along dir while it lasts, carry: speed 0.1 s after it
## ends}, or {} when no new dash started within 0.3 s.
func _dash(m: Match, dir: Vector2) -> Dictionary:
	var hunter: Hunter = m.player
	var at0 := hunter.dash_at
	_keys(hunter, dir)
	_refill(hunter)
	hunter.do_dash()
	var wait := 0
	while hunter.dash_at == at0 and wait < 18:
		_keys(hunter, dir)
		m.step(Match.DT)
		wait += 1
	if hunter.dash_at == at0:
		return {}
	var p0 := hunter.pos
	var steps := 0
	while hunter.roll_t > 0.0 and steps < 120:
		_keys(hunter, dir)
		m.step(Match.DT)
		steps += 1
	var d := hunter.pos - p0
	var dist := Vector2(d.x, d.z).dot(dir)
	return {"dist": dist}

func _carry(m: Match, dir: Vector2) -> float:
	var hunter: Hunter = m.player
	for i in 6:
		_keys(hunter, dir)
		m.step(Match.DT)
	return Vector2(hunter.vel.x, hunter.vel.z).length()

## Settles the hunter: on the ground (or HEIGHT up in the air), standing still for a second.
func _settle(m: Match, home: Vector3, air: bool) -> void:
	var hunter: Hunter = m.player
	hunter.teleport(home + Vector3(0, HEIGHT if air else 0.0, 0))
	hunter.vel = Vector3.ZERO
	hunter.turn_cost = TurnCost.new()
	for foe in m.foes_of(hunter.team):
		foe.pos = home + Vector3(-60, 0, 60)     # a foe's Boki in the lane would stop a ram
	for i in (6 if air else 60):
		_keys(hunter, Vector2.ZERO)
		m.step(Match.DT)

## A first dash east, then at once a second along `dir2`: the second's row.
func _chain(m: Match, home: Vector3, dir2: Vector2, air: bool) -> Dictionary:
	_settle(m, home, air)
	if _dash(m, Vector2(1, 0)).is_empty():
		return {}
	var r := _dash(m, dir2)
	if not r.is_empty():
		r["carry"] = _carry(m, dir2)
	return r

func _fresh(m: Match, home: Vector3, air: bool) -> Dictionary:
	_settle(m, home, air)
	var r := _dash(m, Vector2(-1, 0))
	if not r.is_empty():
		r["carry"] = _carry(m, Vector2(-1, 0))
	return r

func run(main: Node) -> void:
	Save.no_write = true
	var only := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--turn-cost-check="):
			only = String(a).substr(18)
	for arch in Arch.ORDER:
		if only != "" and arch != only:
			continue
		var m := _match(main, arch)
		var home: Vector3 = m.player.pos
		var run_speed: float = m.player.base_speed
		var fresh := _fresh(m, home, false)
		var same := _chain(m, home, Vector2(1, 0), false)
		var back := _chain(m, home, Vector2(-1, 0), false)
		if fresh.is_empty() or same.is_empty() or back.is_empty():
			print("TURNCOST skip %s: the second press is not a new dash" % arch)
		else:
			var f: float = fresh["dist"]
			var same_d: float = same["dist"]
			var back_d: float = back["dist"]
			ok(same_d >= f * SAME_KEEP, "%s ground: fresh %.2f m, same way %.2f m" % [arch, f, same_d])
			ok(back_d <= f * REV_KEEP, "%s ground: fresh %.2f m, straight back %.2f m" % [arch, f, back_d])
		var fresh_air := _fresh(m, home, true)
		var same_air := _chain(m, home, Vector2(1, 0), true)
		var back_air := _chain(m, home, Vector2(-1, 0), true)
		var no_air := fresh_air.is_empty() or same_air.is_empty() or back_air.is_empty()
		if no_air or float(fresh_air["carry"]) <= run_speed + RUN_SLACK:
			print("TURNCOST skip %s air: no second air dash or no carry to lose" % arch)
		else:
			var c: float = fresh_air["carry"]
			var same_c: float = same_air["carry"]
			var back_c: float = back_air["carry"]
			ok(same_c >= c * SAME_KEEP, "%s air: fresh carry %.1f m/s, same way %.1f" % [arch, c, same_c])
			ok(back_c <= run_speed + RUN_SLACK,
				"%s air: run %.2f m/s, straight back carries %.3f" % [arch, run_speed, back_c])
		m.queue_free()
		await main.get_tree().process_frame
	print("TURNCOST DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
