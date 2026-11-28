extends RefCounted
## --quill-mag-check: Vex's quill rifle drum (content/weapons/quill_rifle.json). Holding fire drains the drum a round
## a shot; rounds fired with under `low_mag_at` of a drum left hit for `low_mag_dmg` of full; a rested drum refills,
## so a burst and a pause keeps full damage, and admin god mode no longer tops it up. Never touches the save.

const DT := 1.0 / 60.0
var ac
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("QUILLMAG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	ac = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("gunslinger", 6.0)
	var m: Match = r[0]
	var hunter: Hunter = r[1]
	var mag := int(hunter.wpn["mag"])
	var low_k := float(hunter.wpn["low_mag_dmg"])
	var edge := mag * float(hunter.wpn["low_mag_at"])
	var wait := float(hunter.wpn["refill_after"]) + float(mag) / float(hunter.wpn["refill_rate"]) + 0.2
	var held := _fire(m, hunter, 1.6)
	var full: float = held[0][1]
	ok(
		held.size() >= 8 and hunter.ammo < mag * 0.6,
		"hold fire 1.6 s: %d rounds, the drum falls from %d to %d" % [held.size(), mag, hunter.ammo]
	)
	ok(
		held.all(func(s: Array) -> bool: return is_equal_approx(s[1], full if s[0] >= edge else full * low_k)),
		"rounds with the drum at or over half deal %.1f, under half %.1f" % [full, full * low_k]
	)
	ok(held.any(func(s: Array) -> bool: return s[0] < edge), "the string reaches the low half")
	_fire(m, hunter, wait, false)
	ok(hunter.ammo == mag, "rest %.1f s with the trigger up: the drum is full again" % wait)
	var burst := _fire(m, hunter, 0.5)
	ok(
		burst.all(func(s: Array) -> bool: return is_equal_approx(s[1], full)),
		"a 0.5 s burst (%d rounds) stays at full damage" % burst.size()
	)
	ok(_fire(m, hunter, 0.3, false).is_empty(), "trigger up: nothing fires")
	_fire(m, hunter, wait, false)
	var god_was: bool = Game.god
	Game.god = true  # mod mode turns god mode on for the owner: it used to top the drum up every frame
	var god_run := _fire(m, hunter, 1.0)
	Game.god = god_was
	ok(
		god_run.size() >= 8 and hunter.ammo < mag - 6,
		"god mode (owner's mod mode), hold 1 s: the drum still falls to %d of %d" % [hunter.ammo, mag]
	)
	print("QUILLMAG_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Runs `secs` with the trigger held (or up); returns [drum after the round, damage] per round fired.
func _fire(m: Match, hunter: Hunter, secs: float, trigger := true) -> Array:
	var rounds: Array = []
	var seen: int = m.shot_n
	var t := 0.0
	hunter.inp["fire"] = trigger
	while t < secs:
		ac.step(m, DT)
		t += DT
		for s: Dictionary in m.shots:
			if s["by"] == hunter and int(s["sid"]) > seen:
				seen = int(s["sid"])
				rounds.append([hunter.ammo, float(s["dmg"])])
	hunter.inp["fire"] = false
	return rounds
