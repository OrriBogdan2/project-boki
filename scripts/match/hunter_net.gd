class_name HunterNet
extends RefCounted
## Extra hunter fields in the "st" snapshot that the HUD shows to everyone: the run level, so every
## player sees every hunter's level on their overhead plate (HudPlate.level_badge) and the badge
## pulses when it goes up. Appended as a tagged pair at the very end of the hunter row (after
## KinNet's fields) so it never shifts anything already there; an older row without it is ignored.
## Two bits of the hunter flags carry the owner's stun and knockback, so a remote copy's clips show the stun
## clip and hold the hit pose while it slides when the owner's do (visual only: the copy's stun_t stays zero).

const TAG := "lv"
const STUNNED := 1 << 25       # hunter flags: stunned on its own game
const KNOCKED := 1 << 26       # hunter flags: sliding under a knockback on its own game

static func extra(h: Hunter) -> Array:
	return [TAG, h.lvl]

static func apply(h: Hunter, it: Array) -> void:
	var i := it.rfind(TAG)
	if i >= 0 and i == it.size() - 2:
		h.lvl = maxi(1, int(it[i + 1]))

static func cc_bits(h: Hunter) -> int:
	return (STUNNED if h.stun_t > 0.0 else 0) | (KNOCKED if h.knock_t > 0.0 else 0)

static func apply_cc(h: Hunter, f: int) -> void:
	if f & KNOCKED != 0 and h.net_cc & KNOCKED == 0:
		h.kb_t = h.m.time       # the knock starts on the copy as the snapshot shows it (the clips play the hit from here)
	h.net_cc = f & (STUNNED | KNOCKED)
