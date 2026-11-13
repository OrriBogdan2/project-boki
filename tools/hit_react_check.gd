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
	if not cond: bad += 1

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
	ok(is_equal_approx(w_chip, want) and rises,
			"layer weight rises with strength: chip %.2f < solid %.2f < stagger 1.0" % [w_chip, w_solid])
	main.get_tree().quit(1 if bad > 0 else 0)

## Lands a hit of `d` and returns the flinch strength it set.
func _hit(m: Match, target: Hunter, by: Hunter, d: float, o: Dictionary) -> float:
	target.hit_k = 0.0
	target.stagger_t = 0.0
	Oomph.react(m, target, by, d, o)
	return target.hit_k
