extends "res://tools/hero_vfx_reel.gd"
## Gil's reel (tools/hero_vfx_reel.gd): the generic thrusts, Tide Lunge (hold) and Ground Swim (dash); the bag's
## potions in a fixed order (Thunder held, then Slime, Air, Fire and a Super Zeep tapped onto one dummy: three
## different marks Beach it); the slime's puddle to its end; the Riptide spin sent off as a spout; the Tidal Wave
## followed down its line.

const BAG := ["slime", "air", "fire", "zeep"]   # the "bag" part's throws, in order
const BAG_EVERY := 1.4                          # s between the bag part's throws
const BREAK_AT := 0.5                           # s from a throw's press to its break at 4 m (0.35 + 0.03/m flight,
                                                # and the release frame)
const WAVE_BACK := -3.0                         # m behind home the wave starts: its 14 m surf ends on the flat
                                                # ground the reel's spot guarantees (3 m back to 14 m ahead)

func parts() -> Array:
	return ["lmb", "hold", "rmb", "bag", "puddle", "dash", "e", "r"]

## The next throw takes potion `v`, with a charge ready.
func _load(v: String) -> void:
	(P.ak as GilKit).bag = [v]
	P.ak.cd["rmb"] = 0.0
	P.ak.ch_rmb = float(P.ak.rmb_charges())

func _part_rmb() -> void:
	await _reset(4.0)
	_load("thunder")
	var cast := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		P.inp["sec_hold"] = t > 0.1 and t < 0.5
		_aim(T.pos)
	await _go(2.4, cast, _sheet("rmb", "RMB held, Thunder: the landing circle, the throw, the break",
		[0.15, 0.25, 0.35, 0.5, 0.65, 0.8, 1.0, 1.4, 2.0]), 2.0)
	await _go(GAP)

func _part_bag() -> void:
	await _reset(4.0)
	var marks: Array = []
	for i in BAG.size():
		var at := 0.1 + BAG_EVERY * i + BREAK_AT
		marks.append_array(_sheet("bag", "RMB taps: Slime, Air, Fire (Beached), Super Zeep", [at, at + 0.15, at + 0.8]))
	var throw := func(t: float):
		P.inp["sec"] = false
		for i in BAG.size():
			if _at(t, 0.1 + BAG_EVERY * i):
				_load(BAG[i])
				P.inp["sec"] = true
		_aim(T.pos)
	await _go(0.1 + BAG_EVERY * BAG.size() + 0.5, throw, marks, 2.0)
	await _go(GAP)

func _part_puddle() -> void:
	await _reset(4.0)
	_load("slime")
	var throw := func(t: float):
		P.inp["sec"] = _at(t, 0.1)
		_aim(T.pos)
	var at := 0.1 + BREAK_AT
	var life := float((P.ak as GilKit).vial_def("slime")["puddle_t"])
	await _go(at + life + 0.6, throw, _sheet("puddle", "RMB Slime: its puddle from the landing to the end of its slow",
		[at, at + 0.03, at + 0.3, at + 1.5, at + 2.5, at + life - 0.6, at + life - 0.25, at + life - 0.1,
			at + life + 0.3]), 2.0)
	await _go(GAP)

func _part_e() -> void:
	await _reset(5.0)
	var cast := func(t: float):
		P.inp["sig"] = _at(t, 0.1)
		if _at(t, 1.1):
			P.ak.e_recast()
		_aim(T.pos)
	await _go(2.4, cast, _sheet("e", "E, Riptide: a 1 s spin, then E again: the spout down the line",
		[0.2, 0.45, 0.7, 1.0, 1.15, 1.25, 1.4, 1.7, 2.2]), 2.5)
	await _go(GAP)

func _part_r() -> void:
	await _reset(5.0)
	P.teleport(home + Vector3(WAVE_BACK, 0, 0))
	var down_line := home + Vector3(20.0, 0, 0)
	var cast := func(t: float):
		if _at(t, 0.1):
			P.ak.cd["x"] = 0.0
			P.ak.cast_ult()
		_aim(down_line)
	await _go(2.6, cast, _sheet("r", "R, Tidal Wave: the lane, the surf over the dummy, the landing",
		[0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.15, 1.4, 2.0], func(): return P.position + Vector3(2.0, 0.9, 0)), 2.5)
	await _go(GAP)
