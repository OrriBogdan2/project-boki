class_name TipText
extends RefCounted
## The first-time hints a match shows once each (Match._tip), built from the player's own keys
## (Settings.key_cap) at the moment they appear, so a rebind shows in the next hint.


## The glide is jump, then jump again (held) in the air: the second press is what the line says.
static func move() -> String:
	var fire := Settings.key_cap("fire")
	return (
		"Hold %s to shoot  ·  %s dashes  ·  jump, then %s again to glide"
		% [fire, Settings.key_cap("dash"), Settings.key_cap("jump")]
	)


static func rings() -> String:
	return "Glide through the glowing rings between islands for a burst of speed."


## A hunter with a kit sends the Boki on the Boki key; the others use their E ability.
static func ability(kit: bool, bond_ok := true) -> String:
	var bond := "  ·  full bond: %s" % Settings.key_cap("ultimate") if bond_ok and MergeForm.enabled() else ""
	if kit:
		return "%s sends your Boki (hold: orders)%s" % [Settings.key_cap("throw"), bond + " fuses" if bond else ""]
	return "%s: your Boki's ability%s" % [Settings.key_cap("signature"), bond]


static func bond_full(fuse_name: String, next: bool) -> String:
	return "Bond full  ·  %s%s fuses: %s" % ["your next " if next else "", Settings.key_cap("ultimate"), fuse_name]


static func send(boki: String) -> String:
	return "%s sends %s: its hit stuns, and stunned foes take crits" % [Settings.key_cap("throw"), boki]


static func scan() -> String:
	return "Hold %s to scan  ·  4s, rivals hear it  ·  extract to keep it" % Settings.key_cap("interact")


static func stagger(mob: String) -> String:
	var keys := [Settings.key_cap("signature"), Settings.key_cap("ultimate"), Settings.key_cap("gear1")]
	return "Purple ring on %s: use %s, %s or %s for a big stun." % ([mob] + keys)
