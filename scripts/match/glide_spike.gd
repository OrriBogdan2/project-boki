class_name GlideSpike
extends RefCounted
## A spiked glider (docs/decisions/0022): knocked out of the glide, plunging, and stunned when it lands.
## Two hit kinds spike, as the source has it (wiki Spike and Dunk, data SpikeSlamForce*):
##   heat  a player's hit that fills the glider's heat, or any player hit on an overheated glider
##         (Hunter._mitigate drains the heat and calls shoot_down)
##   slam  a hit that drives the glider down at slam_min m/s or more (a dunk: Displace.spike), whatever
##         the heat; the glider is left overheated
## Stuns, knock-ups and knockbacks don't spike by themselves: their damage heats the glider like any hit.
## Numbers: content/rules/hunter_move.json "glide_spike".

static var _r: Dictionary = HunterMove.rules()["glide_spike"]
static var land_stun: float = _r["land_stun"]
static var land_dmg: float = _r["land_dmg"]
static var air_stun: float = _r["air_stun"]
static var fall_vy: float = _r["fall_vy"]
static var keep_hv: float = _r["keep_hv"]
static var reopen_cd: float = _r["reopen_cd"]
static var slam_min: float = _r["slam_min"]
static var cool_by: float = _r["cool_by"]

## A heat spike: the glider folds, the body plunges and is stunned in the air.
static func shoot_down(h: Hunter) -> void:
	h.gliding = false
	h.glide_cd = reopen_cd
	h.shot_down = true
	h.stun_t = maxf(h.stun_t, air_stun)
	h.vel = Vector3(h.vel.x * keep_hv, minf(h.vel.y, -fall_vy), h.vel.z * keep_hv)
	h.m.fx.burst(h.pos + Vector3(0, 1.8, 0), Color("ff9a5a"), 14, 3.0, 0.45, 6.0, 0.8)
	h.m.sfx("knock", h.pos, -2.0, 1.3)
	if h.is_local() and h.m.hud:
		h.m.hud.toast_small("GLIDER SHOT DOWN", Color("ff9a5a"))

## A slam on a body this game owns: it falls at least `vy` (negative) fast, and a glider driven down at
## slam_min or more is spiked (its heat goes full).
static func slam(e: Ent, vy: float) -> void:
	if spikes(e, vy):
		(e as Hunter).glide_fuel = 0.0
		shoot_down(e as Hunter)
	e.vel.y = minf(e.vel.y, vy)

## True when a slam down at `vy` spikes this body: a glider (not in the opening drop) driven down at
## slam_min or more. Read on any game (the snapshot carries `gliding`), so the caster can credit it.
static func spikes(e: Ent, vy: float) -> bool:
	return e is Hunter and (e as Hunter).gliding and not (e as Hunter).dropping and -vy >= slam_min

## The spiker's reward [wiki]: a gliding Hunter's own glider cools, and the spike counts in its (or its
## Boki's owner's) stats.
static func credit(by: Ent) -> void:
	if by is Hunter and (by as Hunter).gliding:
		(by as Hunter).glide_fuel = minf(1.0, (by as Hunter).glide_fuel + cool_by)
	if by is Hunter:
		(by as Hunter).add_stat("spikes")
	elif by is Kin and (by as Kin).owner_h:
		(by as Kin).owner_h.add_stat("spikes")

## A spiked body touches the ground: the landing stun and the extra damage.
static func land(h: Hunter) -> void:
	h.shot_down = false
	h.stun_t = maxf(h.stun_t, land_stun)
	h.hurt(land_dmg, h.last_hit_by, {"src": "fall"})
	h.m.fx.dust(h.pos, 12)
	h.m.fx.ring(h.pos + Vector3(0, 0.05, 0), 1.6, Color(1.0, 0.6, 0.4, 0.6), 0.3)
