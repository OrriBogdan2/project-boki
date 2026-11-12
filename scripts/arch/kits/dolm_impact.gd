class_name DolmImpact
extends RefCounted
## The weight of Tenzo's hits: one blue-white flash, a ground shock and a spray of chips, all sized by the
## damage the hit deals. Laid on top of each hit's own fire and dust.
## Tenzo's ability colour is blue (DECISIONS 2026-11-08).

const BLUE := Color("4aa8ff")
const CORE := Color("d8ecff")
const DMG_FULL := 30.0         # damage that reads as a full-size impact (the slam's top damage)
const RISE_RING := 1.4         # m: radius of the ring a rising rock throws
const RISE_FLASH := 1.1        # m: size of the flash at its foot
const FLASH_A := 0.75         # the flash's strength (it adds over the hit's own fire)
const DMG_MIN := 0.25          # smallest weight: even the boulder's 9 shows a flash and a ring

## Weight 0.25..1 for a hit of `dmg`.
static func weight(dmg: float) -> float:
	return clampf(dmg / DMG_FULL, DMG_MIN, 1.0)

## A hit of `dmg` damage at `at` (a point on the ground); `dir` is the way the blow travels, or zero for a
## blow that goes every way (a slam).
static func hit(m: Match, at: Vector3, dmg: float, dir := Vector2.ZERO) -> void:
	var w := weight(dmg)
	var up := at + Vector3(0, 0.5, 0)
	# one flash: the shader already draws a white-hot core and adds over the hit's own flash, so a second
	# (white) flash here blew the slam's first frames out
	m.fx.flash(up, Color(BLUE, FLASH_A), 0.8 + 1.2 * w, 0.16)
	m.fx.ring(at, 1.0 + 3.0 * w, BLUE, 0.32)
	m.fx.ring(at, 0.5 + 1.4 * w, CORE, 0.18)
	var fwd := Vector3(dir.x, 0.35, dir.y) if dir != Vector2.ZERO else Vector3.UP
	var spread := 55.0 if dir != Vector2.ZERO else 80.0
	m.fx.spark(up, fwd, BLUE, int(8 + 14 * w), 7.0 + 5.0 * w, spread, 0.3, 9.0, 1.3)
	m.fx.burst(up, BLUE, int(8 + 12 * w), 3.5 + 3.0 * w, 0.45, 10.0, 1.2, fwd, spread)

## A Stone Row or Tetraform rock breaking the ground at `at`: a blue ring and flash at its foot, so each rock's rise
## reads. (The Rock Hop's rocks are a dash's, and a dash draws no ring.)
static func rise(m: Match, at: Vector3) -> void:
	m.fx.ring(at, RISE_RING, BLUE, 0.3)
	m.fx.flash(at + Vector3(0, 0.4, 0), BLUE, RISE_FLASH, 0.12)
