extends "res://tools/hero_vfx_reel.gd"
## Ryzz's reel (--hero-vfx-reel --reel-hero=mage): the generic set plus her Static payoff, a dummy driven to Live
## by finger bolts (the pink crackles, then the bolt out of the sky).

func parts() -> Array:
	return ["lmb", "live", "rmb", "dash", "e", "r"]

func _part_live() -> void:
	await _reset(4.5)
	var K: MageKit = P.ak
	K.add_spark(T, 2)
	var shoot := func(t: float):
		P.inp["fire"] = (_at(t, 0.6) or _at(t, 1.4)) and t < 1.5
		_aim(T.pos)
	var focus := func() -> Vector3: return T.position + Vector3(0, 1.0, 0)
	var times := [0.3, 0.75, 0.9, 1.0, 1.55, 1.62, 1.7, 1.85, 2.2]
	await _go(2.4, shoot, _sheet("live", "LMB to Live: crackles, then the sky bolt", times, focus), 1.5)
	await _go(GAP)
