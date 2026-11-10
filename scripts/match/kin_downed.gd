class_name KinDowned
extends RefCounted
## A knocked-out Boki (docs/decisions/0001, 0022): it falls back to its hunter as a dim wisp orbiting them (KinWisp)
## and CANNOT be summoned (no throw, no E, no Merge, no carry passives) until it recovers: after recover_s, or as soon
## as the fight is over (its owner calm_s out of combat), whichever comes first. It comes back with recover_hp of its
## health. No rescue, no carrying, no marker on the ground: it is safe on you while it recovers.
## Numbers: content/rules/boki_system.json "down". State on the Kin: down_t, down_total, down_calm.

static func rules() -> Dictionary:
	return KinCommand.rules()["down"]

## It went down (where it stood, or into the abyss: the same): a burst where it fell, and it is a dim wisp on you.
static func begin(k: Kin, _fell: bool) -> void:
	k.m.fx.burst(k.pos + Vector3(0, 0.4, 0), k.sp["color"], 16, 3.0)
	k.state = "downed"
	k.hp = 0.0
	k.target = null
	k.chase_target = null
	k.fly = {}
	k.hold_at = Vector3.INF
	k.pend_skill = Vector3.INF
	k.pend_slot = ""
	k.vel = Vector3.ZERO
	k.ride = false
	k.summoned = false
	k.down_total = float(rules()["recover_s"])
	k.down_t = k.down_total
	k.down_calm = 0.0
	if k.owner_h:
		KinWisp.follow(k)

static func tick(k: Kin, dt: float) -> void:
	var h := k.owner_h
	if h == null or h.out or h.extracted:
		return
	KinWisp.follow(k)
	k.down_t -= dt
	k.down_calm = 0.0 if KinFollow.in_combat(k, h.pos) else k.down_calm + dt
	if k.down_t <= 0.0 or k.down_calm >= float(rules()["calm_s"]):
		come_round(k)

## Recovered: back to a full wisp on you with a share of health, ready to summon.
static func come_round(k: Kin) -> void:
	k.hp = k.max_hp * float(rules()["recover_hp"])
	k.down_t = 0.0
	k.down_calm = 0.0
	k._hop_on()
	k.cmd = "return"
	KinLoss.reclaimed(k)
	k.m.fx.burst(k.pos, k.sp.get("glow", k.sp["color"]), 8, 2.5)
	k.m.sfx("recall", k.owner_h.pos, -4.0)
	k.m.on_kin_up(k)

## What the hunter hears when they try to summon a knocked-out Boki.
static func deny_text(k: Kin) -> String:
	return "%s is a dim wisp: back in %ds" % [k.rec.get("name", "Your Boki"), ceili(maxf(0.0, k.down_t))]
