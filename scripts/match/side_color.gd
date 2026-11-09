class_name SideColor
extends RefCounted
## One colour rule for the whole fight: you are one colour, your squad another,
## everyone else red, whatever team number they have. A Boki takes its Hunter's colour. Rings, tethers,
## shield shells, downed markers and nameplates all ask here, so the rule lives in one place (the HUD's
## health colours in HudStyle are the source).

const YOU := HudStyle.SELF
const ALLY := HudStyle.ALLY
const FOE := HudStyle.FOE
const WATCH := Color("e8f4ff")       # nobody to be relative to (a spectator, a menu scene)

## The colour of team `team` (and `is_you` for the viewer's own body) as seen by the viewer on `viewer_team`.
static func of_team(viewer_team: int, team: int, is_you := false) -> Color:
	if is_you:
		return YOU
	if viewer_team < 0:
		return WATCH
	return ALLY if team == viewer_team else FOE

## The colour of a Hunter or a Boki as the match's local player sees it. A Boki uses its Hunter's.
static func of(m: Node, e: Node) -> Color:
	var lp: Node = m.get("player") if m else null
	var body: Node = e
	if e is Kin and (e as Kin).owner_h != null:
		body = (e as Kin).owner_h
	var team := int(body.get("team")) if body else -1
	var viewer := int(lp.get("team")) if lp else -1
	return of_team(viewer, team, lp != null and body == lp)
