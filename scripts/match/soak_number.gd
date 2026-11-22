class_name SoakNumber
extends RefCounted
## The floating number for what a shield or a Fusion shell took off a hit (HudStyle.NUM_SHIELD / NUM_SHELL,
## Fx.Num.SHIELD): its own colour and a smaller size, so it never reads as armour or health. Like every damage
## number it shows only when the hit involves you, and obeys the damage-numbers setting. Hits the same
## shield soaks one after another add up (Fx.roll_key per colour).

static func at(h: Hunter, by: Ent, soaked: float, col: Color) -> void:
	var you: Hunter = h.m.player
	var credit: Ent = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else by
	if you == null or (credit != you and h != you):
		return
	var key := Fx.roll_key(by, h, Fx.Num.SHIELD) + col.to_html(false)
	h.m.fx.number(h.pos + Vector3(0, 1.6, 0), soaked, col, false, "", key, Fx.Num.SHIELD)
