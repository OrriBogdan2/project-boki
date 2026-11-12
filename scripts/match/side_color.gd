class_name SideColor
extends RefCounted
## One colour rule for the whole fight: you are one colour, your squad another,
## everyone else red, whatever team number they have. A Boki takes its Hunter's colour. Rings, tethers,
## shield shells, downed markers and nameplates all ask here, so the rule lives in one place (the HUD's
## health colours in HudStyle are the source). The same rule leans other people's ability looks (fx(): ground areas,
## telegraphs, shot halos) and edges their bodies (SideRings), so whose it is reads without anything on the HUD.

const YOU := HudStyle.SELF
const ALLY := HudStyle.ALLY
const FOE := HudStyle.FOE
const WATCH := Color("e8f4ff")       # nobody to be relative to (a spectator, a menu scene)
const HOSTILE := Color("ff2d55")     # a rival's ability looks lean to this (docs/DASHES_AND_ABILITY_FEEL.md 5.2)
const FX_FOE_K := 0.45               # share of HOSTILE in a rival's ground areas, telegraphs and shot halos
const FX_ALLY_K := 0.3               # share of ALLY in a teammate's (yours stay as made)

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

## The colour `by`'s ability look `col` (a ground area, a telegraph, a shot's halo) takes for the local player: yours
## as made, a teammate's leaning to the cool ally colour, a rival's leaning hostile. A Boki's goes by its Hunter.
static func fx(m: Node, by: Node, col: Color) -> Color:
	var lp: Node = m.get("player") if m else null
	var body: Node = (by as Kin).owner_h if by is Kin and (by as Kin).owner_h != null else by
	if lp == null or body == null or body == lp:
		return col
	if int(body.get("team")) == int(lp.get("team")):
		return Color(col.lerp(ALLY, FX_ALLY_K), col.a)
	return Color(col.lerp(HOSTILE, FX_FOE_K), col.a)
