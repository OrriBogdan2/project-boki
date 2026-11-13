class_name SideColor
extends RefCounted
## One colour rule for the whole fight: you are one colour, your squad another,
## everyone else red, whatever team number they have. A Boki takes its Hunter's colour. Rings, tethers,
## shield shells, downed markers, nameplates, health bars, telegraphs, shots, markers and the map all
## ask here, so the rule lives in one place. The palette is the player's Settings > Accessibility >
## Colour vision pick; only these side colours change, never a Hunter's ability colours.

const KEY := "colour_vision"
const ORDER := ["default", "red_green", "tritan"]
const NAMES := {
	"default": "Standard", "red_green": "Red-green (deuteranopia, protanopia)", "tritan": "Blue-yellow (tritanopia)",
}
## Per palette: you, your squad, rivals; rim = the hostile tint on a rival's telegraphs and shots;
## mates = the squad's map and ping colours, in squad order (none close to the rival colour).
const PALETTES := {
	"default": {"you": Color("9be36e"), "ally": Color("63c7ff"), "foe": Color("ff5a4a"), "rim": Color("ff2d55"),
		"mates": [Color("ffd23f"), Color("5fd0ff"), Color("8ff0a0"), Color("ff9be8"), Color("ffa25f")]},
	"red_green": {"you": Color("f6f2dc"), "ally": Color("3d8bff"), "foe": Color("ff9a1f"), "rim": Color("ff9a1f"),
		"mates": [Color("5fd0ff"), Color("b9a0ff"), Color("ffffff"), Color("7fe0d0"), Color("7f9bff")]},
	"tritan": {"you": Color("fff0f4"), "ally": Color("30d8c8"), "foe": Color("ff3d5a"), "rim": Color("ff3d5a"),
		"mates": [Color("30d8c8"), Color("e6e6ff"), Color("8ff0a0"), Color("b9a0ff"), Color("ffd23f")]},
}
const WATCH := Color("e8f4ff")       # nobody to be relative to (a spectator, a menu scene)

static func palette() -> Dictionary:
	return PALETTES.get(String(Settings.get_v(KEY)), PALETTES["default"])

static func you() -> Color:
	return palette()["you"]

static func ally() -> Color:
	return palette()["ally"]

static func foe() -> Color:
	return palette()["foe"]

static func rim() -> Color:
	return palette()["rim"]

## The squad's `i`th map and ping colour.
static func mate(i: int) -> Color:
	var cols: Array = palette()["mates"]
	return cols[i % cols.size()]

## The colour of team `team` (and `is_you` for the viewer's own body) as seen by the viewer on `viewer_team`.
static func of_team(viewer_team: int, team: int, is_you := false) -> Color:
	if is_you:
		return you()
	if viewer_team < 0:
		return WATCH
	return ally() if team == viewer_team else foe()

## The colour of a Hunter or a Boki as the match's local player sees it. A Boki uses its Hunter's.
static func of(m: Node, e: Node) -> Color:
	var lp: Node = m.get("player") if m else null
	var body: Node = e
	if e is Kin and (e as Kin).owner_h != null:
		body = (e as Kin).owner_h
	var team := int(body.get("team")) if body else -1
	var viewer := int(lp.get("team")) if lp else -1
	return of_team(viewer, team, lp != null and body == lp)
