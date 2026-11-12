class_name SquadBoard
extends RefCounted
## The board you see while Tab is held: how many squads are left out of the start, every squad as a
## row of pips (alive, downed, out), and your own squad's levels, knocks and Boki. Rivals stay
## anonymous ("Squad 4"): the source shows no one's name outside your own squad. Read only: it reads
## Match, Hunter and Exits and tracks nothing of its own. HUD wiring is one call in Hud._draw.
## Look: Void & Masks (briefs/UI_STYLE.md), kept compact and static over the game.

enum Pip { ALIVE, DOWNED, OUT, SAFE }

const VOID := Color(0.12, 0.08, 0.19, 0.92)      # black-violet panel
const STRIP := Color(0.17, 0.11, 0.26, 0.95)     # a row of the board
const TEAL := Color("3fe0d0")                    # edge, alive pips, your squad
const MAGENTA := Color("ff3fd0")                 # edge, the headline number
const AMBER := Color("ffb36a")                   # downed
const DIM := Color("5a5170")                     # out
const MINT := Color("8fe3c8")                    # got away
const PIP_R := 6.0       # px radius of one pip
const PIP_GAP := 18.0    # px between pip centres
const ROW_H := 30.0      # px per squad row
const MINE_H := 24.0     # px per hunter line in your squad's block
const W := 620.0         # px board width
const COLS := 2          # squad rows are laid out in this many columns

## Everything the board shows, as plain data (the check reads this too).
static func snapshot(m: Match) -> Dictionary:
	var teams: Array = []
	var by_team := {}
	for h: Hunter in m.hunters:
		if not by_team.has(h.team):
			by_team[h.team] = []
			teams.append(h.team)
		by_team[h.team].append(h)
	teams.sort()
	var mine: int = m.player.team if m.player else -1
	var squads: Array = []
	var left := 0
	for t in teams:
		var pips: Array = []
		for h: Hunter in by_team[t]:
			pips.append(pip_of(h))
		var live: bool = Life.team_alive(m, t)
		left += int(live)
		squads.append({"team": t, "mine": t == mine, "alive": live, "pips": pips})
	var crew: Array = []
	for h: Hunter in by_team.get(mine, []):
		crew.append({"name": h.pname, "lvl": h.lvl, "knocks": h.knocks, "pip": pip_of(h),
			"boki": String(Data.KIN[h.kin.species]["name"]) if h.kin else "", "me": h == m.player})
	return {"total": teams.size(), "left": left, "squads": squads, "crew": crew, "ways": ways_text(m)}

static func pip_of(h: Hunter) -> int:
	if h.extracted: return Pip.SAFE
	if h.out: return Pip.OUT
	return Pip.DOWNED if h.downed else Pip.ALIVE

## The Ways Out line: the exit your squad has going, else how many can be started now.
static func ways_text(m: Match) -> String:
	if m.exits == null or m.exits.list.is_empty() or m.player == null:
		return ""
	var mine: Dictionary = m.exits.active_for(m.player.team)
	var line := ""
	if not mine.is_empty():
		line = "%s: %s" % [mine["name"], mine["state"]]
	else:
		var open := 0
		for x in m.exits.list:
			open += int(m.exits.callable(x) or m.exits.startable(x) or x["state"] == "open")
		line = "%d open to you" % open
	return line + ("  ·  last squad standing: exits are quicker" if m.exits.rush else "")

static func pip_col(p: int) -> Color:
	match p:
		Pip.ALIVE: return TEAL
		Pip.DOWNED: return AMBER
		Pip.SAFE: return MINT
	return DIM

static func _pip(c: CanvasItem, at: Vector2, p: int) -> void:
	if p == Pip.ALIVE or p == Pip.DOWNED:
		c.draw_circle(at, PIP_R, pip_col(p))
	else:
		c.draw_arc(at, PIP_R - 1.0, 0.0, TAU, 16, pip_col(p), 2.0, true)
		if p == Pip.OUT:
			c.draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), DIM, 2.0)

## Draws the board centred on the screen. `hud` is the HUD, for its panel and text helpers.
static func draw(hud, sz: Vector2) -> void:
	var s := snapshot(hud.m)
	var c: CanvasItem = hud.c
	var rows := ceili(float(s["squads"].size()) / COLS)
	var h: float = 76.0 + rows * ROW_H + 30.0 + s["crew"].size() * MINE_H + (26.0 if s["ways"] != "" else 0.0)
	var r := Rect2(Vector2((sz.x - W) * 0.5, sz.y * 0.14), Vector2(W, h))
	hud._rounded(r, VOID, 14, Color(TEAL, 0.55), 2)
	c.draw_line(r.position + Vector2(14, 2), r.position + Vector2(W * 0.5, 2), Color(MAGENTA, 0.8), 3.0)
	hud._text(r.position + Vector2(20, 36), "SQUADS LEFT", 16, HudStyle.MUTED, hud.big)
	hud._text(r.position + Vector2(168, 40), "%d / %d" % [s["left"], s["total"]], 28, MAGENTA, hud.big)
	var colw := (W - 40.0) / COLS
	for i in s["squads"].size():
		var q: Dictionary = s["squads"][i]
		var at := r.position + Vector2(20.0 + (i / rows) * colw, 62.0 + (i % rows) * ROW_H)
		var rr := Rect2(at, Vector2(colw - 10.0, ROW_H - 4.0))
		var edge := Color(TEAL, 0.8) if q["mine"] else Color(0, 0, 0, 0)
		hud._rounded(rr, STRIP, 6, edge, 1)
		var tag := "You" if q["mine"] else "Squad %d" % (int(q["team"]) + 1)
		var ink := TEAL if q["mine"] else DIM
		if q["alive"] and not q["mine"]: ink = HudStyle.INK
		hud._text(rr.position + Vector2(10, 19), tag, 14, ink, hud.big)
		var n: int = q["pips"].size()
		for j in n:
			_pip(c, Vector2(rr.end.x - 20.0 - (n - 1 - j) * PIP_GAP, rr.get_center().y), q["pips"][j])
	var y := r.position.y + 62.0 + rows * ROW_H + 18.0
	hud._text(Vector2(r.position.x + 20, y), "YOUR SQUAD", 13, TEAL, hud.big)
	hud._text(Vector2(r.position.x + 330, y), "LV", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + 380, y), "KNOCKS", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + 460, y), "BOKI", 12, HudStyle.MUTED, hud.big)
	for e in s["crew"]:
		y += MINE_H
		_pip(c, Vector2(r.position.x + 28, y - 5), e["pip"])
		hud._text(Vector2(r.position.x + 44, y), e["name"], 15, HudStyle.GOLD if e["me"] else HudStyle.INK, hud.big)
		hud._text(Vector2(r.position.x + 330, y), str(e["lvl"]), 15, HudStyle.GOLD, hud.big)
		hud._text(Vector2(r.position.x + 392, y), str(e["knocks"]), 15)
		hud._text(Vector2(r.position.x + 460, y), e["boki"], 14, HudStyle.MUTED)
	if s["ways"] != "":
		hud._text(Vector2(r.position.x + 20, r.end.y - 14), "WAYS OUT  " + s["ways"], 13, MINT, hud.big)
