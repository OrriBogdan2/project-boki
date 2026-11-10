class_name Spike
extends RefCounted
## The spike (docs/SPIKE_SLAM.md): a downward strike that catches a foe in the air drives it to the ground.
## One path for every ability whose data carries a `spike` block ({"bonus": extra damage share, optional "stun":
## s on the hit itself}): the hit is
## a payoff (hit stop tier 4, no lift), the glider folds, the body falls at FALL_VY, Grounded (no dash, jump or
## glide) until it lands, and the landing stuns it (Hunter.SPIKE_STUN, the same landing as a glider run dry).
## Dives, leaps and dashes (the caster's own body travels to the hit) never carry one.

const FALL_VY := -20.0             # m/s: the forced fall (a 6m glide height in about 0.3s)
const AIR_GAP := 0.35              # m: off the ground by more than this counts as in the air
const GND_T := 0.8                 # s: Grounded, longer than a fall from glide height, so the landing comes first
const STREAK := Color(1.0, 0.86, 0.62, 0.7)   # the downward streak: a thin pale line, there and gone

## True when `f` is in the air: off its feet and gliding, or off the ground.
static func airborne(f: Ent) -> bool:
	return not f.grounded and ((f is Hunter and (f as Hunter).gliding) or f.pos.y > f.ground() + AIR_GAP)

## Before the hit: when `sp` is set and `f` is in the air, marks the hit's opts as a spike (no lift, the payoff
## hit stop) and returns the damage factor; 1.0 and the opts untouched otherwise. Call drive() after the hit.
static func arm(f: Ent, sp: Dictionary, o: Dictionary) -> float:
	if sp.is_empty() or not airborne(f):
		return 1.0
	o.erase("lift")
	o["spiked"] = true
	if sp.has("stun"):
		o["stun"] = maxf(float(o.get("stun", 0.0)), float(sp["stun"]))
	return 1.0 + float(sp.get("bonus", 0.0))

## For a hit already dealt (a stage's on_foe): spikes `f` when `sp` is set and it is still in the air.
static func after(m: Match, f: Ent, by: Ent, sp: Dictionary) -> bool:
	if sp.is_empty() or not airborne(f):
		return false
	Feel.hitstop(m, by, f, 0.0, {"spiked": true})
	drive(m, f, by)
	return true

## Drives `f` down: the fall (through Displace, so it reaches the game that owns the body), Grounded, the streak,
## a small word and a low knock. The landing stun comes from Hunter's landing (shot_down, set by fall()).
static func drive(m: Match, f: Ent, by: Ent) -> void:
	if f is Hunter:
		# out of a glide it counts toward the spike stat (the "shoot gliders out of the sky" goal)
		if by is Hunter and (f as Hunter).gliding: (by as Hunter).add_stat("spikes")
		KitStatus.apply(f, "gnd", GND_T, 0.0, true, "spiked: no dash, jump or glide")
	m.displace.spike(f, FALL_VY)
	m.fx.beam(f.pos + Vector3(0, 2.8, 0), f.pos + Vector3(0, 0.9, 0), STREAK, 0.1, 0.16)
	m.fx.word(f.pos + Vector3(0, 2.0, 0), "SPIKED", STREAK, false)
	m.sfx("knock", f.pos, -6.0, 0.8)

## The fall itself, on the game that owns the body: at least `vy` down, the glider folded, and the landing stun
## armed (Hunter.shot_down).
static func fall(e: Ent, vy: float) -> void:
	e.vel.y = minf(e.vel.y, vy)
	if e is Hunter:
		var h := e as Hunter
		h.gliding = false
		h.shot_down = true
