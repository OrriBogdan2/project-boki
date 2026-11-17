extends RefCounted
## --quill-mag-check: Vex's quill rifle drum (content/weapons/quill_rifle.json). Holding fire drains the drum a round
## a shot; rounds fired with under `low_mag_at` of a drum left hit for `low_mag_dmg` of full; a rested drum refills,
## so a burst and a pause keeps full damage. Never touches the save.

const DT := 1.0 / 60.0
var A
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("QUILLMAG %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	A = load("res://tools/archetype_check.gd").new()
	A.main = main
	var r: Array = A.setup("gunslinger", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var mag := int(P.wpn["mag"])
	var low_k := float(P.wpn["low_mag_dmg"])
	var edge := mag * float(P.wpn["low_mag_at"])
	var wait := float(P.wpn["refill_after"]) + float(mag) / float(P.wpn["refill_rate"]) + 0.2
	var held := _fire(m, P, 1.2)
	var full: float = held[0][1]
	ok(held.size() >= 8 and P.ammo < mag * 0.6, "hold fire 1.2 s: %d rounds, the drum falls from %d to %d" % [held.size(), mag, P.ammo])
	ok(held.all(func(s: Array) -> bool: return is_equal_approx(s[1], full if s[0] >= edge else full * low_k)),
			"rounds with the drum at or over half deal %.1f, under half %.1f" % [full, full * low_k])
	ok(held.any(func(s: Array) -> bool: return s[0] < edge), "the string reaches the low half")
	_fire(m, P, wait, false)
	ok(P.ammo == mag, "rest %.1f s with the trigger up: the drum is full again" % wait)
	var burst := _fire(m, P, 0.5)
	ok(burst.all(func(s: Array) -> bool: return is_equal_approx(s[1], full)),
			"a 0.5 s burst (%d rounds) stays at full damage" % burst.size())
	ok(_fire(m, P, 0.3, false).is_empty(), "trigger up: nothing fires")
	print("QUILLMAG_DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## Runs `secs` with the trigger held (or up); returns [drum after the round, damage] per round fired.
func _fire(m: Match, P: Hunter, secs: float, trigger := true) -> Array:
	var rounds: Array = []
	var seen: int = m.shot_n
	var t := 0.0
	P.inp["fire"] = trigger
	while t < secs:
		A.step(m, DT)
		t += DT
		for s: Dictionary in m.shots:
			if s["by"] == P and int(s["sid"]) > seen:
				seen = int(s["sid"])
				rounds.append([P.ammo, float(s["dmg"])])
	P.inp["fire"] = false
	return rounds
