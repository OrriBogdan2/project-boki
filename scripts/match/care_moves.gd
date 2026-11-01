class_name CareMoves
## Cast animations for the support pair, layered on HunterAnim's cast lean: for each ability an
## anticipation pose, a strong impact pose timed to the hitbox and a follow-through. t is seconds
## since the cast went off (HunterAnim's "cast"); the ability slots are the CombatBus ones
## ("secondary" = RMB, "kin" = E). pose() returns body deltas {p: pitch (negative leans forward),
## y: yaw, r: roll}, and hand() the free hand's offset from its shoulder.

static func has(arch: String) -> bool:
	return arch == "tender" or arch == "rimewright"

static func _k(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)

## Weight of a pose that rises by `a`, holds to `b` and falls away by `c` (all seconds).
static func _env(t: float, a: float, b: float, c: float) -> float:
	return _k(t, 0.0, a) * (1.0 - _k(t, b, c))

static func pose(arch: String, slot: String, t: float) -> Dictionary:
	match [arch, slot]:
		["tender", "secondary"]:
			# wind back with the seed cupped by the ear, then a flick forward
			var wind := _env(t, 0.09, 0.1, 0.12)
			var fling := _k(t, 0.1, 0.17) * (1.0 - _k(t, 0.2, 0.5))
			return {"p": 0.14 * wind - 0.38 * fling, "y": -0.3 * wind + 0.35 * fling, "r": -0.06 * wind + 0.05 * fling}
		["tender", "kin"]:
			# crouch to gather the light, then rise and lift the lantern hand high
			var gather := _env(t, 0.1, 0.14, 0.2)
			var rise := _k(t, 0.14, 0.24) * (1.0 - _k(t, 0.34, 0.6))
			return {"p": -0.2 * gather + 0.22 * rise, "y": 0.05 * rise, "r": 0.0}
		["rimewright", "secondary"]:
			# a javelin throw: shoulders wound back, then whipped through with a step
			var coil := _env(t, 0.1, 0.12, 0.14)
			var thr := _k(t, 0.12, 0.19) * (1.0 - _k(t, 0.22, 0.5))
			return {"p": 0.08 * coil - 0.3 * thr, "y": -0.55 * coil + 0.65 * thr, "r": -0.1 * coil + 0.1 * thr}
		["rimewright", "kin"]:
			# hands together low, then both pushed out and down onto the ice
			var low := _env(t, 0.12, 0.15, 0.2)
			var slam := _k(t, 0.15, 0.22) * (1.0 - _k(t, 0.3, 0.6))
			return {"p": -0.15 * low - 0.42 * slam, "y": 0.0, "r": 0.0}
	return {}

static func hand(arch: String, slot: String, t: float) -> Vector3:
	match [arch, slot]:
		["tender", "secondary"]:
			return Vector3(-0.1, 0.3, 0.15).lerp(Vector3(0.08, 0.12, -0.52), _k(t, 0.09, 0.17))
		["tender", "kin"]:
			return Vector3(0.05, 0.0, -0.15).lerp(Vector3(0.02, 0.58, -0.1), _k(t, 0.12, 0.24))
		["rimewright", "secondary"]:
			return Vector3(0.12, 0.15, 0.35).lerp(Vector3(0.06, 0.1, -0.55), _k(t, 0.1, 0.19))
		["rimewright", "kin"]:
			return Vector3(0.0, -0.1, -0.2).lerp(Vector3(0.02, -0.12, -0.55), _k(t, 0.14, 0.22))
	return Vector3(0.06, 0.02, -0.4)
