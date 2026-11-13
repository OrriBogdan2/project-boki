class_name QuestRace
extends RefCounted
## Who is winning a quest race (docs/decisions/0051-limited-ways-out.md): under a quest seat's badge, on the
## Ways Out strip and the full map, two rows of pips: your squad's progress on top (discs), the best rival's
## below (diamonds, so the two never read by colour alone), in the squad colours of SideColor.
## Progress: the Sealed Lair is the damage done to its boss, the Uplink its charge. One squad holds a quest at a
## time, so a row is that squad's bout (it falls back to empty when the bout is lost); a taken seat is full for
## the squad that took it. Locked and shut seats show no rows. Reads the QuestSeat states the host mirrors
## ("xc" "seat"), the boss's hp and the outpost's charge, so it updates for every player online.

const PIPS := 5
const PIP_R := 2.5         # px, a pip's radius
const STEP := 7.0          # px between pips
const ROW_GAP := 8.0       # px between the two rows
const EMPTY_A := 0.28      # alpha of a pip not reached yet

static var _read := {"mine": 0.0, "rival": 0.0, "rival_team": -1}    # reused every frame

## The two rows for the quest at badge `i` (0 Sealed Lair, 2 Uplink): `mine`, `rival` 0..1 and the rival's team.
## Empty when that seat has none (not a quest badge, no seats, locked or shut).
static func read(m: Match, i: int) -> Dictionary:
	var seats: QuestSeats = m.exits.seats if m.exits else null
	if seats == null or not i in [0, 2]:
		return {}
	var s: QuestSeat = seats.lair if i == 0 else seats.uplink
	if s == null:
		return {}
	var p := 0.0
	var team := -1      # (an open seat: nobody on it yet)
	match s.state:
		QuestSeat.S.OPEN:
			pass
		QuestSeat.S.IN_USE:
			p = _progress(m, s)
			team = s.team
		QuestSeat.S.TAKEN:
			p = 1.0
			team = s.team
		_:
			return {}
	var mine := team >= 0 and team == SideColor.viewer(m)
	_read["mine"] = p if mine else 0.0
	_read["rival"] = 0.0 if mine or team < 0 else p
	_read["rival_team"] = -1 if mine else team
	return _read

## 0..1: a lair's boss hurt, an uplink's charge.
static func _progress(m: Match, s: QuestSeat) -> float:
	if s.kind == "uplink":
		return clampf(float(s.ref["prog"]), 0.0, 1.0)
	var b := _boss(m, s.ref)
	if b == null:
		return 0.0
	return clampf(1.0 - b.hp / maxf(b.max_hp, 1.0), 0.0, 1.0)

## The rows with their top-left pip centred on `at.x` and the first row at `at.y`.
static func draw(m: Match, c: Control, at: Vector2, rd: Dictionary) -> void:
	if rd.is_empty():
		return
	var viewer := SideColor.viewer(m)
	var rival_team: int = rd["rival_team"]
	var rival_col := SideColor.of_team(viewer, rival_team) if rival_team >= 0 else SideColor.foe()
	_row(c, at, float(rd["mine"]), SideColor.of_team(viewer, viewer), false)
	_row(c, at + Vector2(0, ROW_GAP), float(rd["rival"]), rival_col, true)

static func _row(c: Control, mid: Vector2, p: float, col: Color, diamond: bool) -> void:
	var x0 := mid.x - STEP * (PIPS - 1) * 0.5
	for k in PIPS:
		var f := clampf(p * PIPS - k, 0.0, 1.0)
		var pv := Vector2(x0 + STEP * k, mid.y)
		WaysOutHud.pip(c, pv, PIP_R + 1.0, Color(0, 0, 0, 0.6), diamond, true)
		WaysOutHud.pip(c, pv, PIP_R, Color(col, lerpf(EMPTY_A, 1.0, f)), diamond, true)

## The lair's boss: the host's own reference, else (a client builds none) the mirrored Boss mob in the lair.
static func _boss(m: Match, L: Dictionary) -> Boss:
	var b: Boss = m.lairs.boss_of(L)
	if b != null:
		return b
	for mb in m.mobs:
		if mb is Boss and m.lairs.inside(L, mb.pos):
			return mb
	return null
