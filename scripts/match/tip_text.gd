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


## The Summon key's one line, once the wisp can be called out ("" when it can't): the window and the rest, in seconds.
static func summon(k: Kin) -> String:
	var s := k.summon
	if s == null or not k.wisp or s.cd > 0.0 or k.owner_h != k.m.player:
		return ""
	return (
		"Press %s to call %s out for %d s, then it rests %d s"
		% [Settings.key_cap("summon"), k.rec.get("name", "your Boki"), roundi(s.dur), roundi(s.cd_base)]
	)


static func bond_full(fuse_name: String, next: bool) -> String:
	return "Bond full  ·  %s%s fuses: %s" % ["your next " if next else "", Settings.key_cap("ultimate"), fuse_name]


static func send(boki: String) -> String:
	return "%s sends %s: its hit stuns, and stunned foes take crits" % [Settings.key_cap("throw"), boki]


static func scan() -> String:
	return "Hold %s to scan  ·  4s, rivals hear it  ·  extract to keep it" % Settings.key_cap("interact")


static func stagger(mob: String) -> String:
	var keys := ["secondary", "signature", "hunter_ult", "gear1"].map(func(a: String): return Settings.key_cap(a))
	return "Purple ring on %s: use %s, %s, %s or %s for a big stun." % ([mob] + keys)
