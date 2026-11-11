class_name KinRegen
extends RefCounted
## A Boki mends on its own in a match (numbers: content/rules/boki_system.json "regen"):
##   - on you by the Return order, settled: carried_pct_s of max health per second
##   - out beside you: out_pct_s per second, while it is out of combat (InCombat)
##   - downed (or dazed, benched, fused, away): none. A downed Boki has to be rescued (KinDowned).
## Every Boki starts a match at full health (Kin._init builds it from its stats), so nothing carries over.
## Called from Kin's tick. A little green + mote rises while it mends.
## It also refills the owner_shield points on you (owner_shield_tick); Hunters have no regen of their own.

const MOTE_EVERY := 0.7          # s between motes while healing
const MOTE_COL := Color("8fffc0")

static func rules() -> Dictionary:
	return KinCommand.rules()["regen"]

## Health per second this Boki is winning back right now (0: not mending), as a share of max health.
static func rate(k: Kin) -> float:
	if k.dead or k.hp <= 0.0 or k.hp >= k.max_hp:
		return 0.0
	var r := rules()
	if k.carried():
		return float(r["carried_pct_s"])
	if k.state == "active" and not InCombat.is_in(k):
		return float(r["out_pct_s"])
	return 0.0

## One step. A Boki in combat (InCombat) waits; one that just came round starts its wait again.
static func tick(k: Kin, dt: float) -> void:
	if k.state in ["downed", "reviving", "dazed", "fused", "shoulder"]:
		k.combat_at = k.m.time
	var pct := rate(k)
	if pct > 0.0:
		var heal := k.max_hp * pct * dt
		if k.blight_t > 0.0:
			heal *= 1.0 - k.blight_k
		k.hp = minf(k.max_hp, k.hp + heal)
		k.regen_fx -= dt
		if k.regen_fx <= 0.0:
			k.regen_fx = MOTE_EVERY
			motes(k.m.fx, k.pos + Vector3(0, 0.9, 0), MOTE_COL)
	k.mending = pct > 0.0

## The little rising motes of mending (also the stat glint at home, StatGlint, in the stat's colour).
static func motes(fx: Fx, at: Vector3, col: Color) -> void:
	fx.burst(at, col, 3, 0.9, 0.7, -1.5, 0.5)

## The soft green wash over a Boki's health bar while it mends (HUD: one pulse per ~1.2 s).
static func pulse(k: Kin, now: float) -> float:
	return (0.35 + 0.35 * sin(now * 5.0)) if k.mending else 0.0

## Your Boki's owner_shield points on you: the small shield refills owner_shield_pct_s of its size a
## second while you are out of combat (InCombat). Hunter tick.
static func owner_shield_tick(h: Hunter, dt: float) -> void:
	var cap := h.kin_pt("owner_shield")
	if cap <= 0.0 or InCombat.is_in(h) or h.kin_shield >= cap:
		return
	h.kin_shield = minf(cap, h.kin_shield + cap * float(rules()["owner_shield_pct_s"]) * dt)
