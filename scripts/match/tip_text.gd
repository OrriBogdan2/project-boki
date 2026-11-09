class_name TipText
extends RefCounted
## The first-time hints a match shows once each (Match._tip), built from the player's own keys
## (Settings.key_cap) at the moment they appear, so a rebind shows in the next hint.

static func move() -> String:
	var fire := Settings.key_cap("fire")
	return "Hold %s to shoot  ·  %s dashes  ·  %s" % [fire, Settings.key_cap("dash"), glide_how()]

## How to glide: jump, then press jump again in the air and hold.
static func glide_how() -> String:
	return "jump, then press %s again in the air and hold to glide" % Settings.key_cap("jump")

static func rings() -> String:
	return ("Glowing rings in the air between islands: jump off the edge, then %s and fly through them for a burst "
			+ "of speed. Fast gliders barely sink.") % glide_how()

## A hunter with a kit sends the Boki on the Boki key; the others use their E ability.
static func ability(kit: bool) -> String:
	var fuse := Settings.key_cap("ultimate")
	if kit:
		return "%s sends your Boki (hold: orders)  ·  full bond: %s fuses" % [Settings.key_cap("throw"), fuse]
	return "%s: your Boki's ability  ·  full bond: %s" % [Settings.key_cap("signature"), fuse]

static func bond_full(fuse_name: String, next: bool) -> String:
	return "Bond full  ·  %s%s fuses: %s" % ["your next " if next else "", Settings.key_cap("ultimate"), fuse_name]

static func send(boki: String) -> String:
	return "%s sends %s: its hit stuns, and stunned foes take crits" % [Settings.key_cap("throw"), boki]

static func scan() -> String:
	return "Hold %s to scan  ·  4s, rivals hear it  ·  extract to keep it" % Settings.key_cap("interact")

static func hatch() -> String:
	return "A Rift Key opens this hatch (%s)  ·  three can drop through" % Settings.key_cap("interact")

static func stagger(mob: String) -> String:
	var keys := [Settings.key_cap("signature"), Settings.key_cap("ultimate"), Settings.key_cap("gear1")]
	return ("A purple ring means %s can be staggered. Hit it with an ability (%s, %s or %s) for a big hit, a long "
			+ "stun and your cooldown back.") % ([mob] + keys)
