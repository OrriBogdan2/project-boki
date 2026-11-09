class_name Palette
extends RefCounted
## The one home of every colour that carries a meaning the player has to read at a glance: you, your
## squad and rivals, low health, damage, and good news (revive progress, hidden), the rarity tiers
## (gear, armour) and the crowd-control icons. Each role has four colours, one per colour
## filter (Settings > Accessibility > Colour filter): Off is the game's own look; the other three are
## pairs tested against a simulation of that kind of colour blindness by tools/palette_check.gd
## (minimum contrast between ally and rival, between rarity tiers, and among the CC icons).
## Hunters' ability colours are never filtered.
## HudStyle and SideColor read the roles here, so nothing else needs to know which filter is on.

enum { YOU, ALLY, FOE, LOW, GOOD, HURT, STUN, ROOT, SLOW, BURN, WEAK }

## Filter ids as saved in settings.cfg ("cvd_filter"), and their menu names. The index is the column
## of every table below.
const MODES := ["off", "deuteranopia", "protanopia", "tritanopia"]
const MODE_NAMES := ["Off", "Deuteranopia", "Protanopia", "Tritanopia"]

## Role -> [Off, Deuteranopia, Protanopia, Tritanopia].
const ROLES := {
	YOU: [Color("9be36e"), Color("f2f0c8"), Color("f2f0c8"), Color("f4f0d8")],
	ALLY: [Color("63c7ff"), Color("4aa8ff"), Color("4aa8ff"), Color("28d8d0")],
	FOE: [Color("ff5a4a"), Color("ff7a1c"), Color("ff7a1c"), Color("ff4a4a")],
	LOW: [Color("ffa13c"), Color("ffffff"), Color("ffffff"), Color("ffffff")],
	HURT: [Color("ff6a5a"), Color("ff8a3a"), Color("ff8a3a"), Color("ff5a5a")],
	GOOD: [Color("8fe0a0"), Color("6ad8ff"), Color("6ad8ff"), Color("40e0d0")],
	STUN: [Color("fff27a"), Color("f1f441"), Color("e7e64a"), Color("fdfa41")],
	ROOT: [Color("8fe0a0"), Color("a5ffc7"), Color("57fdb0"), Color("57fb4d")],
	SLOW: [Color("9ae8ff"), Color("439df3"), Color("43f1ff"), Color("81a4c7")],
	BURN: [Color("ff9a5a"), Color("f47a4b"), Color("eb6a2a"), Color("fc7337")],
	WEAK: [Color("ffb36a"), Color("d7a6e1"), Color("e75ac4"), Color("de90c7")],
}

## Rarity tier (Common .. Legendary) -> [Off, Deuteranopia, Protanopia, Tritanopia]. Gear, armour
## tiers and anything else with a rarity colour read it through rarity().
const RARITY := [
	[Color("d6d2c8"), Color("d6d2c8"), Color("d6d2c8"), Color("d6d2c8")],
	[Color("8fe0a0"), Color("6bb860"), Color("dbf8ab"), Color("30f060")],
	[Color("6ab8ff"), Color("4c8df0"), Color("5194f9"), Color("3b95d1")],
	[Color("c08aff"), Color("fb97fe"), Color("c3779d"), Color("f051c3")],
	[Color("ffb64a"), Color("ffb64a"), Color("ffb64a"), Color("ffb64a")],
]

## The filter in effect, as an index into MODES.
static func mode() -> int:
	return maxi(0, MODES.find(String(Settings.get_v("cvd_filter"))))

static func col(role: int) -> Color:
	return col_in(role, mode())

static func rarity(tier: int) -> Color:
	return rarity_in(tier, mode())

## The same colours for a given filter (the palette check walks every one).
static func col_in(role: int, filter: int) -> Color:
	return ROLES[role][filter]

static func rarity_in(tier: int, filter: int) -> Color:
	return RARITY[clampi(tier, 0, RARITY.size() - 1)][filter]
