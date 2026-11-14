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
## The way-out colours (the Heart, its Gate and calls, the Blight's tide, the seat states on the maps and as beams)
## are neutral, so a palette lists one only where the default's would sit on its rival red: see tone().
const PALETTES := {
	"default": {"you": Color("9be36e"), "ally": Color("63c7ff"), "foe": Color("ff5a4a"), "rim": Color("ff2d55"),
		"heart": Color("ff5d78"), "gate": Color("ff9aa8"), "call": Color("ffb4c0"),
		"tide": Color(0.75, 0.2, 0.35, 0.8), "tide_next": Color(0.95, 0.55, 0.65, 0.7),
		"seat_open": Color("fff4d0"), "seat_locked": Color("9fb0d8"), "seat_lost": Color("8a3a4a"),
		"beam_open": Color("f4fbff"), "beam_locked": Color("6f7a9c"), "beam_dark": Color("3a3a44"),
		"beam_lost": Color("2c1638"),
		"mates": [Color("ffd23f"), Color("5fd0ff"), Color("8ff0a0"), Color("ff9be8"), Color("ffa25f")]},
	"red_green": {"you": Color("f6f2dc"), "ally": Color("3d8bff"), "foe": Color("ff9a1f"), "rim": Color("ff9a1f"),
		"mates": [Color("5fd0ff"), Color("b9a0ff"), Color("ffffff"), Color("7fe0d0"), Color("7f9bff")]},
	"tritan": {"you": Color("fff0f4"), "ally": Color("30d8c8"), "foe": Color("ff3d5a"), "rim": Color("ff3d5a"),
		"mates": [Color("30d8c8"), Color("e6e6ff"), Color("8ff0a0"), Color("b9a0ff"), Color("ffd23f")],
		"heart": Color("d94fff"), "gate": Color("ff7ad9"), "call": Color("f0c8ff")},
}
const WATCH := Color("e8f4ff")       # nobody to be relative to (a spectator, a menu scene)

static func palette() -> Dictionary:
	return PALETTES.get(String(Settings.get_v(KEY)), PALETTES["default"])

static func you() -> Color:
	return palette()["you"]

static func ally() -> Color:
	return palette()["ally"]

## A neutral colour of the Ways Out (`heart`, `gate`, `call`, `tide`, `tide_next`, `seat_open`, `seat_locked`,
## `seat_lost`, `beam_open`, `beam_locked`, `beam_dark`, `beam_lost`): the pick's own row, else the standard one.
static func tone(key: String) -> Color:
	var p := palette()
	return p[key] if p.has(key) else PALETTES["default"][key]

## The team the local player belongs to (-1: nobody to be relative to).
static func viewer(m: Node) -> int:
	var lp: Node = m.get("player") if m else null
	return int(lp.get("team")) if lp else -1

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
