extends RefCounted
## --airdash-glide-check: an air dash straight into a glide keeps its speed, for every hunter. The
## glider must open with at least KEEP of the dash's exit speed (its speed on the last step of the dash),
## pressed during the dash it glides that step at the dash's speed (playtest 11-08 item 4).

const KEEP := 0.7
const HEIGHT := 40.0

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
	for other in m.hunters:
		if other != hunter:
			other.ctrl = "idle"
			other.teleport(hunter.pos + Vector3(60, 0, 60))
	for i in 20:
		m.step(Match.DT)
	return m

func _speed(hunter: Hunter) -> float:
	return Vector2(hunter.vel.x, hunter.vel.z).length()

## Dashes east in the air with the glide key held; returns {exit, open}: the dash's last-step speed and the speed
## on the first frame the glider is open (-1 when it never opened).
func _air_dash(m: Match) -> Dictionary:
	var hunter: Hunter = m.player
	hunter.teleport(hunter.pos + Vector3(0, HEIGHT, 0))
	hunter.inp["move"] = Vector2(1, 0)
	hunter.inp["aim"] = hunter.pos + Vector3(8, 0.9, 0)
	for i in 12:
		m.step(Match.DT)
	hunter.dashes = hunter.max_dashes()
	hunter.ex_cd = 0.0
	hunter.do_dash()
	var exit_speed := 0.0
	for i in 150:
		hunter.inp["move"] = Vector2(1, 0)
		hunter.inp["glide"] = true
		hunter.inp["glide_btn"] = true
		m.step(Match.DT)
		if hunter.gliding:
			return {"exit": exit_speed, "open": _speed(hunter)}
		if hunter.roll_t > 0.0:
			exit_speed = _speed(hunter)
	return {"exit": exit_speed, "open": -1.0}

func run(main: Node) -> void:
	Save.no_write = true
	for arch in Arch.ORDER:
		var m := _match(main, arch)
		var r := _air_dash(m)
		var exit_speed: float = r["exit"]
		var open_speed: float = r["open"]
		ok(open_speed >= exit_speed * KEEP,
			"%s: dash exit %.1f m/s, glide opens at %.1f m/s (%.0f%%)" % [arch, exit_speed, open_speed,
			100.0 * open_speed / maxf(0.01, exit_speed) if exit_speed > 0.0 else 0.0])
		m.queue_free()
		await main.get_tree().process_frame
	print("AIRGLIDE DONE, failures: %d" % bad)
	main.get_tree().quit()
