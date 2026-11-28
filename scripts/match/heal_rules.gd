class_name HealRules
extends RefCounted
## Healing parity (content/rules/combat.json): the healing cut on heals a Hunter gives another Hunter, the
## health every Hunter wins back on its own, Anti-Heal on the target, and no healing out in the Blight's tide.


static func rules() -> Dictionary:
	return Content.rules("combat")


## `n` as it lands: a heal from one Hunter to a different one is scaled by heal_given_k; a heal on yourself, or
## from no Hunter (a pickup, a Boki, a field), is whole.
static func given(n: float, from: Node, to: Hunter) -> float:
	if from is Hunter and from != to:
		return n * float(rules()["heal_given_k"])
	return n


## What share of a heal reaches `h` now: 0 outside the tide ring (the storm blocks all healing); under Anti-Heal
## 1 - blight_k with anti_heal_on, else nothing at all; otherwise 1.
static func target_k(h: Hunter) -> float:
	if in_storm(h):
		return 0.0
	if h.blight_t > 0.0:
		return 1.0 - h.blight_k if bool(rules()["anti_heal_on"]) else 0.0
	return 1.0


## Standing outside the Heart's tide ring (where the tide hurts, Heart._tide_tick).
static func in_storm(h: Hunter) -> bool:
	var hr: Heart = h.m.heart if h.m else null
	if hr == null or hr.site == Vector3.INF:
		return false
	return Vector2(h.pos.x - hr.site.x, h.pos.z - hr.site.z).length() > Heart.tide_r(h.m)


## Health recovery: every tick_s adds pct_per_tick of max health, from pause_s after the last hit taken. Local
## and bot Hunters only: a remote one's health comes from its own game (a local tick would be pulled back by
## the next snapshot and flash the bar as a hit). Silent: no number or glow, the bar just fills.
static func regen_tick(h: Hunter, dt: float) -> void:
	if h.remote:
		return
	var r: Dictionary = rules()["regen"]
	h.regen_acc += dt
	var tick_s := float(r["tick_s"])
	if h.regen_acc < tick_s:
		return
	var ticks := floorf(h.regen_acc / tick_s)
	h.regen_acc -= ticks * tick_s
	if h.downed or h.out or h.hp >= h.max_hp or h.m.time - h.hurt_at < float(r["pause_s"]):
		return
	h.hp = minf(h.max_hp, h.hp + h.max_hp * float(r["pct_per_tick"]) * ticks * target_k(h))
