class_name SquadBoard
extends RefCounted
## The board you see while Tab is held: how many squads are left, then one row per hunter in YOUR squad
## (yours first and lit): portrait, state, kills / deaths / assists, damage, the four gear pieces worn
## and their Boki (form, level, evolutions, state). Other squads show nothing but that count: no names,
## stats or who is still up (docs/TAB_BOARD_PARITY.md). Read only: it reads Match, Hunter and Exits and
## tracks nothing of its own. HUD wiring is one call in Hud._draw. Look: Void & Masks (briefs/UI_STYLE.md).

enum Pip { ALIVE, DOWNED, OUT, SAFE }

const VOID := Color(0.12, 0.08, 0.19, 0.92)      # black-violet panel
const STRIP := Color(0.17, 0.11, 0.26, 0.95)     # a hunter's row
const TEAL := Color("3fe0d0")                    # edge, your row, alive
const MAGENTA := Color("ff3fd0")                 # edge, the headline number
const AMBER := Color("ffb36a")                   # downed
const DIM := Color("5a5170")                     # out
const MINT := Color("8fe3c8")                    # got away
const STATE_WORDS := ["Alive", "Downed", "Out", "Got away"]   # by Pip
const ROW_H := 62.0      # px per hunter row
const PORT := 46.0       # px portrait side
const GEAR := 24.0       # px gear cell side
const W := 700.0         # px board width
const COL_K := 230.0     # px from the left edge: the K / D / A column
const COL_DMG := 330.0   # px: damage
const COL_GEAR := 392.0  # px: the four gear cells
const COL_BOKI := 512.0  # px: the Boki

## Everything the board shows, as plain data (the check reads this too).
static func snapshot(m: Match) -> Dictionary:
	var teams := {}
	for h: Hunter in m.hunters:
		teams[h.team] = true
	var left := 0
	for t in teams:
		left += int(Life.team_alive(m, t))
	var mine: int = m.player.team if m.player else -1
	var crew: Array = []
	for h: Hunter in m.hunters:
		if h.team != mine:
			continue
		var gear: Array = []
		for g: Dictionary in h.gear:
			gear.append({} if g.is_empty() else {"id": String(g["id"]), "rar": int(g["rar"])})
		var e := {"h": h, "name": HeroTitle.of_hunter(h), "me": h == m.player, "pip": pip_of(h),
			"k": h.kills, "d": h.deaths, "a": h.assists, "dmg": int(h.dmg_done), "gear": gear, "boki": boki_of(h)}
		if e["me"]: crew.push_front(e)
		else: crew.append(e)
	return {"left": left, "crew": crew, "ways": ways_text(m)}

static func pip_of(h: Hunter) -> int:
	if h.extracted: return Pip.SAFE
	if h.out: return Pip.OUT
	return Pip.DOWNED if h.downed else Pip.ALIVE

## A hunter's active Boki as {name, lvl, evo, state}; empty when they have none.
static func boki_of(h: Hunter) -> Dictionary:
	if h.kin == null:
		return {}
	var k: Kin = h.kin
	var state := "Up"
	if k.dead: state = "Out"
	elif k.state in ["downed", "reviving"]: state = "Down"
	elif k.state == "bench": state = "Resting"
	return {"name": Evo.form_name(k.rec), "lvl": int(k.rec.get("level", 1)),
		"evo": (k.rec.get("forms", []) as Array).size(), "state": state}

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

## Draws the board centred on the screen. `hud` is the HUD, for its panel, portrait and text helpers.
static func draw(hud, sz: Vector2) -> void:
	var s := snapshot(hud.m)
	var h: float = 92.0 + s["crew"].size() * ROW_H + (26.0 if s["ways"] != "" else 0.0)
	var r := Rect2(Vector2((sz.x - W) * 0.5, sz.y * 0.14), Vector2(W, h))
	hud._rounded(r, VOID, 14, Color(TEAL, 0.55), 2)
	hud.c.draw_line(r.position + Vector2(14, 2), r.position + Vector2(W * 0.5, 2), Color(MAGENTA, 0.8), 3.0)
	hud._text(r.position + Vector2(20, 36), "SQUADS LEFT", 16, HudStyle.MUTED, hud.big)
	hud._text(r.position + Vector2(168, 40), str(s["left"]), 28, MAGENTA, hud.big)
	var head_y := r.position.y + 70.0
	hud._text(Vector2(r.position.x + COL_K, head_y), "K / D / A", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + COL_DMG, head_y), "DMG", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + COL_GEAR, head_y), "GEAR", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + COL_BOKI, head_y), "BOKI", 12, HudStyle.MUTED, hud.big)
	for i in s["crew"].size():
		_row(hud, Rect2(r.position + Vector2(14, 80.0 + i * ROW_H), Vector2(W - 28.0, ROW_H - 6.0)), s["crew"][i])
	if s["ways"] != "":
		hud._text(Vector2(r.position.x + 20, r.end.y - 14), "WAYS OUT  " + s["ways"], 13, MINT, hud.big)

static func _row(hud, rr: Rect2, e: Dictionary) -> void:
	var pip: int = e["pip"]
	if e["me"]: hud._rounded(rr, STRIP, 8, Color(TEAL, 0.9), 2)
	else: hud._rounded(rr, STRIP, 8)
	var port := Rect2(rr.position + Vector2(5, (rr.size.y - PORT) * 0.5), Vector2(PORT, PORT))
	var look: String = ["", "down", "out", ""][pip]
	hud._draw_portrait(port, e["h"], look, pip_col(pip))
	var x := rr.position.x
	var mid := rr.position.y + rr.size.y * 0.5
	hud._text(Vector2(x + 62, mid - 3), e["name"], 15, HudStyle.GOLD if e["me"] else HudStyle.INK, hud.big)
	hud._text(Vector2(x + 62, mid + 15), STATE_WORDS[pip], 12, pip_col(pip), hud.big)
	hud._text(Vector2(x + COL_K - 14, mid + 6), "%d / %d / %d" % [e["k"], e["d"], e["a"]], 16, HudStyle.INK, hud.big)
	hud._text(Vector2(x + COL_DMG - 14, mid + 6), str(e["dmg"]), 15, HudStyle.MUTED)
	for j in e["gear"].size():
		var cell := Rect2(Vector2(x + COL_GEAR - 14 + j * (GEAR + 4), mid - GEAR * 0.5), Vector2(GEAR, GEAR))
		var g: Dictionary = e["gear"][j]
		if g.is_empty() or not Gear.ALL.has(g["id"]):
			hud._rounded(cell, Color(0, 0, 0, 0.35), 5, Color(1, 1, 1, 0.1), 1)
			continue
		var rc: Color = Data.RARITY[clampi(g["rar"], 0, Data.RARITY.size() - 1)]["color"]
		hud._rounded(cell, Color(0, 0, 0, 0.55), 5, rc, 1)
		Icons.draw(hud.c, Gear.icon_of(g["id"]), cell.get_center(), GEAR * 0.3, Gear.ALL[g["id"]]["col"])
	var b: Dictionary = e["boki"]
	if b.is_empty():
		hud._text(Vector2(x + COL_BOKI - 14, mid + 6), "no Boki", 13, DIM)
		return
	hud._text(Vector2(x + COL_BOKI - 14, mid - 3), b["name"], 14, HudStyle.INK, hud.big)
	var evo := "  ·  evo %d" % b["evo"] if b["evo"] > 0 else ""
	var ink: Color = {"Down": AMBER, "Out": DIM}.get(b["state"], HudStyle.MUTED)
	hud._text(Vector2(x + COL_BOKI - 14, mid + 15), "Lv %d%s  ·  %s" % [b["lvl"], evo, b["state"]], 12, ink)
