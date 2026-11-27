class_name HealRules
extends RefCounted
## Healing parity (content/rules/combat.json): the healing cut on heals a Hunter gives another Hunter, and the
## health every Hunter wins back on its own. Anti-Heal (Ent.blight_k) cuts both like any heal.


static func rules() -> Dictionary:
	return Content.rules("combat")


## `n` as it lands: a heal from one Hunter to a different one is scaled by heal_given_k; a heal on yourself, or
## from no Hunter (a pickup, a Boki, a field), is whole.
static func given(n: float, from: Node, to: Hunter) -> float:
	if from is Hunter and from != to:
		return n * float(rules()["heal_given_k"])
	return n


## Health recovery: every tick_s adds pct_per_tick of max health, from pause_s after the last hit taken. Local
## and bot Hunters only (a remote one runs its own game). Silent: no number or glow, the bar just fills.
static func regen_tick(h: Hunter, dt: float) -> void:
	var r: Dictionary = rules()["regen"]
	h.regen_acc += dt
	var tick_s := float(r["tick_s"])
	if h.regen_acc < tick_s:
		return
	var ticks := floorf(h.regen_acc / tick_s)
	h.regen_acc -= ticks * tick_s
	if h.downed or h.out or h.hp >= h.max_hp or h.m.time - h.hurt_at < float(r["pause_s"]):
		return
	var cut := 1.0 - h.blight_k if h.blight_t > 0.0 else 1.0
	h.hp = minf(h.max_hp, h.hp + h.max_hp * float(r["pct_per_tick"]) * ticks * cut)
