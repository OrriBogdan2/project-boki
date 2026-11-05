extends "res://tools/hero_vfx_reel.gd"
## Kael's (juggernaut) reel parts for --hero-vfx-reel: every form of his Smash, the Warchain's states, the Rampage, the
## Gilded Riposte, Rage and the sounds with no key of their own.

func parts() -> Array:
	return ["lmb", "wave", "slam", "lunge", "drop", "dash", "e", "spin", "r", "rage", "voice"]

## (each part starts cool: Enraged from the last one would go off in this one)
func _reset(td: float, tz := 0.0) -> void:
	await super._reset(td, tz)
	(P.ak as JuggernautKit).enraged_t = 0.0

func _part_lmb() -> void:
	await _reset(3.3)
	var swing := func(t: float):
		P.inp["fire"] = fmod(t, 0.5) < DT * 2.0 and t < 1.9
		_aim(T.pos)
	await _go(2.1, swing, _sheet("lmb",
			"LMB Greatsword: a slash, the arc burning away, tip burst on the dummy; the next slash "
			+ "back the other way",
			[0.04, 0.09, 0.15, 0.22, 0.3, 0.54, 0.6, 0.68, 0.8]), 1.5)
	await _go(GAP)

func _part_wave() -> void:
	await _reset(8.5)
	var hold := func(t: float):
		P.inp["fire"] = t < 1.15
		_aim(T.pos)
	await _go(2.9, hold, _sheet("wave",
			"LMB hold, Searing Wave: the blade heating (AimKit's lane fills), the release, the wave "
			+ "burning a lane that cools to fissures",
			[0.5, 1.0, 1.2, 1.3, 1.4, 1.6, 1.9, 2.3, 2.8]), 3.0)
	await _go(GAP)

func _part_slam() -> void:
	await _reset(3.2)
	var K: JuggernautKit = P.ak
	var slam := func(t: float):
		if _at(t, 0.1):
			K.press_rmb()
		_aim(T.pos)
	await _go(2.5, slam, _sheet("slam",
			"RMB tap, Finishing Slam: the wind-up gathers at the blade, the strike opens a burning "
			+ "cone, debris, sweet spot on the dummy, fissures cool",
			[0.3, 0.6, 0.72, 0.76, 0.82, 0.92, 1.1, 1.5, 2.2]), 1.5)
	await _go(GAP)

func _part_lunge() -> void:
	await _reset(7.0)
	var K: JuggernautKit = P.ak
	var lunge := func(t: float):
		if _at(t, 0.1):
			P.inp["sec_hold"] = true
			K.press_rmb()
		if t >= 1.25:
			P.inp["sec_hold"] = false
		_aim(T.pos)
	await _go(2.8, lunge, _sheet("lunge",
			"RMB hold, Lunge: charging (the lane is AimKit's), full flash at the blade, the fling "
			+ "with its mesh trails, the impact, the scorched line",
			[0.5, 0.9, 1.2, 1.32, 1.4, 1.48, 1.6, 1.9, 2.6]), 3.0)
	await _go(GAP)

func _part_drop() -> void:
	await _reset(5.0)
	var K: JuggernautKit = P.ak
	var drop := func(t: float):
		P.inp["jump"] = t < DT
		if _at(t, 0.3):
			K.press_rmb()
		_aim(T.pos)
	await _go(3.0, drop, _sheet("drop",
			"RMB in the air, Meteor Drop: the gather over the marker, the comet dive, the ground "
			+ "breaking open, the wall of flame at the stun's edge, debris, cooling fissures",
			[0.34, 0.45, 0.55, 0.64, 0.7, 0.8, 1.0, 1.6, 2.6]), 2.0)
	await _go(GAP)

func _part_dash() -> void:
	await _reset(6.0)
	var dash := func(t: float):
		if _at(t, 0.15):
			P.inp["move"] = Vector2(1, 0)
			P.do_dash()
		if t > 0.3:
			P.inp["move"] = Vector2.ZERO
		_aim(T.pos)
	await _go(1.8, dash, _sheet("dash",
			"Shift, Rampage: the crouch, the drive with its trail, the tip's arc, the scorched "
			+ "line",
			[0.2, 0.33, 0.42, 0.5, 0.58, 0.66, 0.8, 1.1, 1.7]), 2.5)
	await _go(GAP)

func _part_e() -> void:
	await _reset(10.0)
	var K: JuggernautKit = P.ak
	var chain := func(t: float):
		if _at(t, 0.1):
			K.use_e()
		if _at(t, 1.2):
			K.use_e()
		P.inp["move"] = Vector2(-1, 0) if t > 0.5 and t < 1.2 else Vector2.ZERO
		_aim(T.pos)
	var on_action := func() -> Vector3:
		var at_foe: bool = K.warchain.state == "hooked"
		return (T.position if at_foe else P.position) + Vector3(0, 0.9, 0)
	await _go(2.6, chain, _sheet("e",
			"E, Warchain: the throw from the hand, the hook biting the dummy (sparks, a scorch), the "
			+ "chain straining as he backs off, E again: the haul with sparks off his feet, the arrival",
			[0.13, 0.3, 0.38, 0.5, 0.9, 1.24, 1.32, 1.5, 1.8], on_action), 4.5)
	await _go(GAP)

func _part_spin() -> void:
	await _reset(9.0)
	var K: JuggernautKit = P.ak
	var spin := func(t: float):
		if _at(t, 0.1):
			K.use_e()
		if _at(t, 0.55):
			K.use_e()
		if _at(t, 0.8):
			K.press_rmb()
		_aim(T.pos)
	await _go(2.0, spin, _sheet("spin",
			"Smash in the Warchain's pull, Cinder Spin: the full arc, the low wall of flame, the "
			+ "burn under him",
			[0.75, 0.82, 0.88, 0.96, 1.05, 1.15, 1.3, 1.5, 1.8]), 4.0)
	await _go(GAP)

func _part_r() -> void:
	await _reset(3.0)
	var K: JuggernautKit = P.ak
	var ult := func(t: float):
		if _at(t, 0.1):
			K.cd["x"] = 0.0
			K.cast_ult()
		if _at(t, 0.4):
			K.riposte.block(T, {})
		_aim(T.pos)
	await _go(2.7, ult, _sheet("r",
			"R, Gilded Riposte: the gold guard, a blocked hit, the cleave up through the strip, the "
			+ "gold scorch and embers",
			[0.2, 0.42, 0.6, 0.77, 0.84, 0.92, 1.05, 1.5, 2.5]), 1.5)
	await _go(GAP)

func _part_rage() -> void:
	await _reset(3.3)
	var K: JuggernautKit = P.ak
	var rage := func(t: float):
		if _at(t, 0.1):
			K.gain_rage(K.res_max())
		P.inp["fire"] = t > 0.8 and fmod(t, 0.5) < DT * 2.0
		_aim(T.pos)
	await _go(2.4, rage, _sheet("rage", "Enraged: the flare as Rage fills, the body burning, slashes keeping it fed",
			[0.13, 0.2, 0.3, 0.6, 0.86, 1.0, 1.4, 1.9, 2.3]), 1.5)
	K.enraged_t = 0.0
	await _go(GAP)

## The sounds with no key of their own: footsteps by surface, the hurt grunts and the downed grunt.
func _part_voice() -> void:
	await _reset(12.0)
	var step_k := 0
	var walk := func(t: float):
		P.inp["move"] = Vector2(0, -1) if t < 2.2 else Vector2.ZERO
		if fmod(t, 0.32) < DT:
			var surface: String = ["grass", "stone", "snow", "wood"][int(t / 0.56) % 4]
			Sfx.play(HeroVfx.step_sound("juggernaut", surface), P.pos, -13.0, 0.08)
			step_k += 1
		if _at(t, 2.5) or _at(t, 2.9) or _at(t, 3.3):
			P.ak.vfx("hurt")
		if _at(t, 3.8):
			P.ak.vfx("downed")
		_aim(T.pos)
	await _go(5.0, walk)
