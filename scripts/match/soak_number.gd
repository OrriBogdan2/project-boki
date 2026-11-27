class_name SoakNumber
extends RefCounted
## The floating number for what a shield or a Fusion shell took off a hit (HudStyle.NUM_SHIELD / NUM_SHELL,
## Fx.Num.SHIELD): its own colour and a smaller size, so it never reads as armour or health. Like every damage
## number it shows only when the hit involves you, and obeys the damage-numbers setting. Hits the same
## shield soaks one after another add up (Fx.roll_key per colour).
## Ent.hurt calls before() and after() around _mitigate, so Hunter._mitigate itself stays free of it: the
## shield and kin shield are read as what they lost, the shell as opts["shell_soaked"] (MergeShell.absorb).


## What the hunter's shield and kin shield hold now (x shield, y kin shield); zero for anything else.
static func before(e: Ent) -> Vector2:
	var h := e as Hunter
	return Vector2(h.shield, h.kin_shield) if h else Vector2.ZERO


## The hit went through _mitigate: print a number for each defence that lost something.
static func after(e: Ent, by: Ent, was: Vector2, opts: Dictionary) -> void:
	var h := e as Hunter
	if h == null:
		return
	at(h, by, float(opts.get("shell_soaked", 0.0)), HudStyle.NUM_SHELL)
	at(h, by, was.x - h.shield, HudStyle.NUM_SHIELD)
	at(h, by, was.y - h.kin_shield, HudStyle.NUM_SHIELD)



static func at(h: Hunter, by: Ent, soaked: float, col: Color) -> void:
	if soaked <= 0.0:
		return
	var you: Hunter = h.m.player
	var credit: Ent = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h else by
	if you == null or (credit != you and h != you):
		return
	var key := Fx.roll_key(by, h, Fx.Num.SHIELD) + col.to_html(false)
	h.m.fx.number(h.pos + Vector3(0, 1.6, 0), soaked, col, false, "", key, Fx.Num.SHIELD)
