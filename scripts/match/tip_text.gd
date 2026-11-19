class_name TipText
extends RefCounted
## The first-time hints a match shows once each (Match._tip), built from the player's own keys
## (Settings.key_cap) at the moment they appear, so a rebind shows in the next hint.

## One short line each (about 60 characters, MAX_LEN at most), nothing blocking.
const MAX_LEN := 70

static func move() -> String:
	return "Hold %s to shoot  ·  %s dashes  ·  %s again in the air to glide" % [
			Settings.key_cap("fire"), Settings.key_cap("dash"), Settings.key_cap("jump")]

## How to glide: jump, then press jump again in the air and hold it (HoldTeach: a held glide).
static func glide_how() -> String:
	return "jump, then press %s again in the air and hold to glide" % Settings.key_cap("jump")

static func rings() -> String:
	return "Glide through the glowing rings for a burst of speed"

## A hunter with a kit sends the Boki on the Boki key; the others use their E ability.
static func ability(kit: bool, bond_ok := true) -> String:
	var bond := "  ·  full bond: %s" % Settings.key_cap("ultimate") if bond_ok and MergeForm.enabled() else ""
	if kit:
		return "%s sends your Boki%s" % [Settings.key_cap("throw"), bond + " fuses" if bond else ""]
	return "%s: your Boki's ability%s" % [Settings.key_cap("signature"), bond]

static func bond_full(fuse_name: String, next: bool) -> String:
	return "Bond full  ·  %s%s fuses: %s" % ["your next " if next else "", Settings.key_cap("ultimate"), fuse_name]

## A purple ring on a mob: an ability (E, R or Q) staggers it.
static func stagger() -> String:
	return "Purple ring: stagger it with %s, %s or %s" % [
			Settings.key_cap("signature"), Settings.key_cap("ultimate"), Settings.key_cap("gear1")]

static func skill(boki: String, ability_name: String) -> String:
	return "Stun a foe with %s's %s, then shoot it: combo" % [boki, ability_name]

static func exit_uplink() -> String:
	return "Start the uplink, hold the outpost, then take the lift"

## A downed Hunter is a Wisp (DEATH_AND_REVIVE): a teammate on it, or a loyal Boki's pull, revives it.
static func down() -> String:
	return "Down: a teammate on your wisp, or your Boki, revives you"

static func overheat_lift() -> String:
	return "Your glider is burning but still lifts. Keep holding %s." % Settings.key_cap("jump")

## Every hint with sample names, for the length check: [key, text].
static func all_lines() -> Array:
	return [["move", move()], ["rings", rings()], ["ability", ability(false)], ["ability (kit)", ability(true)],
			["ult", bond_full("Fuse", true)], ["skill", skill("Pip", "Spark Bolt")], ["exit_uplink", exit_uplink()],
			["down", down()], ["stagger", stagger()], ["overheat_lift", overheat_lift()]]

static func send(boki: String) -> String:
	return "%s sends %s: its hit stuns, and stunned foes take crits" % [Settings.key_cap("throw"), boki]

static func scan() -> String:
	return "Hold %s to scan  ·  4s, rivals hear it  ·  extract to keep it" % Settings.key_cap("interact")
