class_name BotLead
extends RefCounted
## Where a bot aims a cast that lands later than it is pressed (a wind-up, a travelling shot, a rise).
## It uses the ability's own delay and travel speed from its archetype json and the foe's velocity, and
## never aims past the ability's own range, so a bot gets no reach or damage a player has not.


## The foe's ground spot `delay` s from now plus the shot's flight at `speed` m/s (0: no travel), kept
## within `rng` m of the caster.
static func point(h: Hunter, tgt: Ent, delay: float, speed: float, rng: float) -> Vector3:
	var v := Vector3(tgt.vel.x, 0.0, tgt.vel.z)
	var p := tgt.pos
	for i in 2:
		var t := delay + (h.flat_dist(p) / speed if speed > 0.0 else 0.0)
		p = tgt.pos + v * t
	var off := Vector3(p.x - h.pos.x, 0.0, p.z - h.pos.z)
	if off.length() > rng:
		p = h.pos + off.normalized() * rng
	p.y = tgt.pos.y
	return p


## Aim there now, and keep re-aiming each step for `delay` s (a wind-up reads the aim when it lets go).
static func aim(k: ArchKit, tgt: Ent, delay: float, speed: float, rng: float, up := 0.9) -> void:
	k.bot_lead = {"tgt": tgt, "t": delay, "speed": speed, "rng": rng, "up": up}
	k.h.inp["aim"] = point(k.h, tgt, delay, speed, rng) + Vector3(0, up, 0)


## One step of the re-aim (ArchKit.tick).
static func hold(k: ArchKit, dt: float) -> void:
	var l: Dictionary = k.bot_lead
	var tgt: Ent = l["tgt"]
	l["t"] = float(l["t"]) - dt
	if float(l["t"]) < 0.0 or not is_instance_valid(tgt) or not tgt.hittable():
		k.bot_lead = {}
		return
	k.h.inp["aim"] = point(k.h, tgt, float(l["t"]), float(l["speed"]), float(l["rng"])) + Vector3(0, float(l["up"]), 0)
