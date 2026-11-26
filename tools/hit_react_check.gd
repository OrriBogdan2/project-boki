extends RefCounted
## --hit-react-check: how hard a hit flinches a Hunter is read from the hit (Oomph.react, hit_flinch.json):
## a chip hit flinches lightly, damage share and knock make it heavier, a big hit staggers (the heaviest
## flinch and the stagger clock), and a damage tick does not flinch. The additive flinch layer plays the
## strength as its weight. Prints HITREACT lines; the clip side (legs keep the run, arms flinch more with
## a harder hit) is --clip-check.

const HEAVY := Oomph.HEAVY_FLINCH
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("HITREACT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var ac: RefCounted = load("res://tools/archetype_check.gd").new()
	ac.main = main
	var r: Array = ac.setup("mage", 30.0)
	var m: Match = r[0]
	var target: Hunter = r[1]
	var by: Hunter = r[2]
	target.fortify_t = 0.0
	var mh := target.max_hp
	var chip := _hit(m, target, by, mh * 0.03, {})
	var solid := _hit(m, target, by, mh * 0.09, {})
	var knocked := _hit(m, target, by, mh * 0.03, {"kb": Vector2(9.0, 0.0)})
	ok(chip < solid and solid < HEAVY, "chip %.2f < solid %.2f < stagger %.2f" % [chip, solid, HEAVY])
	ok(knocked > chip, "knock makes the same damage flinch harder (%.2f > %.2f)" % [knocked, chip])
	ok(target.stagger_t <= 0.0, "a hit under the stagger share does not stagger")
	var big := _hit(m, target, by, mh * 0.20, {})
	ok(is_equal_approx(big, HEAVY) and target.stagger_t > 0.0, "a big hit flinches the heaviest and staggers")
	var blow := _hit(m, target, by, mh * 0.03, {"heavy": true})
	ok(is_equal_approx(blow, HEAVY), "a heavy blow staggers whatever its damage")
	target.hit_k = 1.0
	Oomph.react(m, target, by, mh * 0.2, {"tick": true})
	ok(is_equal_approx(target.hit_k, 1.0), "a damage tick does not flinch")
	var light := float(Oomph.rules()["light"])
	var chip_k := float(Oomph.rules()["chip_k"])
	var w_chip := Oomph.flinch_weight(chip)
	var w_solid := Oomph.flinch_weight(solid)
	var want := lerpf(light, 1.0, inverse_lerp(chip_k, HEAVY, chip))
	var rises := w_chip < w_solid and w_solid < 1.0 and is_equal_approx(Oomph.flinch_weight(HEAVY), 1.0)
	ok(
		is_equal_approx(w_chip, want) and rises,
		"layer weight rises with strength: chip %.2f < solid %.2f < stagger 1.0" % [w_chip, w_solid]
	)
	_hit_slow(m, target, by)
	main.get_tree().quit(1 if bad > 0 else 0)


## The slow when hit (hit_flinch.json hit_slow): a big hit, a quick second big hit, small hits adding up
## (with and without armour), the small cooldown, the sum reset, the walking floor, and no slow from monsters.
func _hit_slow(m: Match, t: Hunter, by: Hunter) -> void:
	var hs: Dictionary = Oomph.rules()["hit_slow"]
	var mh := t.max_hp
	var fl := float(hs["floor_ms"]) / t.base_speed
	t.armor = 0.0
	m.time = 100.0
	_slow_hit(m, t, by, mh * 0.2, 0.0)
	var k := 1.0 - t.slow_k
	ok(
		is_equal_approx(k, maxf(float(hs["big_mult"]), fl)) and is_equal_approx(t.slow_t, float(hs["big_s"])),
		"a big hit slows x%.3f for %.2f s" % [k, t.slow_t]
	)
	_slow_hit(m, t, by, mh * 0.2, 0.5)
	k = 1.0 - t.slow_k
	ok(
		is_equal_approx(k, maxf(float(hs["big_repeat_mult"]), fl)),
		"a second big hit within 1 s: x%.3f (floor x%.3f)" % [k, fl]
	)
	ok(
		fl > float(hs["big_repeat_mult"]),
		"the walking floor holds the repeat slow above x%.2f" % float(hs["big_repeat_mult"])
	)
	m.time = 200.0
	_slow_hit(m, t, by, mh * 0.03, 0.0)
	ok(t.slow_t <= 0.0, "one small hit under the sum does not slow")
	_slow_hit(m, t, by, mh * 0.03, 0.3)
	k = 1.0 - t.slow_k
	ok(
		is_equal_approx(k, float(hs["small_mult"])) and is_equal_approx(t.slow_t, float(hs["small_s"])),
		"small hits adding up slow x%.3f for %.2f s" % [k, t.slow_t]
	)
	_slow_hit(m, t, by, mh * 0.06, 0.5)
	ok(t.slow_t <= 0.0, "no new small slow inside the cooldown")
	m.time = 300.0
	_slow_hit(m, t, by, mh * 0.03, 0.0)
	_slow_hit(m, t, by, mh * 0.03, 1.0)
	ok(t.slow_t <= 0.0, "the sum resets after a pause")
	t.armor = 10.0
	_slow_hit(m, t, by, mh * 0.03, 0.2)
	k = 1.0 - t.slow_k
	ok(
		is_equal_approx(k, float(hs["small_mult_armor"])) and is_equal_approx(t.slow_t, float(hs["small_s_armor"])),
		"with armour: x%.3f for %.2f s" % [k, t.slow_t]
	)
	m.time = 400.0
	_slow_hit(m, t, null, mh * 0.2, 0.0, {"src": "mob"})
	ok(t.slow_t <= 0.0, "a monster's big hit does not slow")


## Advances the clock by `dt`, clears the current slow and lands a hit.
func _slow_hit(m: Match, t: Hunter, by: Hunter, d: float, dt: float, o := {}) -> void:
	m.time += dt
	t.slow_t = 0.0
	t.slow_k = 0.0
	Oomph.react(m, t, by, d, o)


## Lands a hit of `d` and returns the flinch strength it set.
func _hit(m: Match, target: Hunter, by: Hunter, d: float, o: Dictionary) -> float:
	target.hit_k = 0.0
	target.stagger_t = 0.0
	Oomph.react(m, target, by, d, o)
	return target.hit_k
