class_name BokiHit
extends RefCounted
## How a Hunter's kit lands on a Boki, summoned (out for a Hunter) or wild: the one place that says it
## (docs/decisions/0047, numbers in content/rules/boki_hit.json).
##   damage    every hit times dmg_k for the Boki's kind (source parity: 1.0, the card's number)
##   control   only the statuses listed in "cc" land; a stunned Boki doesn't move, bite or cast, a
##             rooted one doesn't move, a slowed one moves slower (wild ones too)
##   knock     as a Hunter takes one (sets its speed along the shove, never stacks, no pop-up unless the
##             attack lifts), divided by Kin.mass() (body mass x giant scale squared; a Hunter is 1)
##   execute   execute hits finish a Boki under the same share of health as a Hunter
## Damage doesn't end a summon early; only the hit that empties it does (the owner's summon rule).

const CC := ["stun", "root", "slow", "burn", "blight"]

static func rules() -> Dictionary:
	return Content.rules("boki_hit")

static func kind(k: Kin) -> String:
	return "wild" if k.is_wild() else "summoned"

static func dmg_k(k: Kin) -> float:
	return float((rules().get("dmg_k", {}) as Dictionary).get(kind(k), 1.0))

## The damage and options a hit on `k` really carries.
static func take(k: Kin, d: float, opts: Dictionary) -> Array:
	var allowed: Array = rules().get("cc", CC)
	var out := opts
	for st in CC:
		if opts.has(st) and not allowed.has(st):
			if out == opts: out = opts.duplicate()
			out.erase(st)
	return [d * dmg_k(k), out]

## Stunned: no step, bite or cast this tick.
static func held(k: Kin) -> bool:
	return k.stun_t > 0.0

## How much of its walk a Boki keeps under control (0 when rooted or stunned).
static func move_k(k: Kin, usual_slow: float) -> float:
	if k.stun_t > 0.0 or k.root_t > 0.0:
		return 0.0
	return k.slow_mult(usual_slow)

## A shove on `k` (Hunter.impulse's model at the Boki's mass).
static func knock(k: Kin, kb: Vector2, lift: float) -> void:
	var ms := k.mass()
	var s := kb.length() / ms
	if s >= 0.05:
		if s > 4.0: k.kb_time = k.m.time
		var dir := kb / kb.length()
		var hv := Vector2(k.vel.x, k.vel.z)
		var along := hv.dot(dir)
		hv += dir * (maxf(along, s) - along)
		k.vel.x = hv.x
		k.vel.z = hv.y
	if lift >= 0.0:
		k.vel.y = maxf(k.vel.y, minf(9.0, lift / ms))
		k.grounded = false

static func executes() -> bool:
	return bool(rules().get("execute", true))
