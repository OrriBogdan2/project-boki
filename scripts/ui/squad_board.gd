class_name SquadBoard
extends RefCounted
## The board you see while Tab is held: how many squads are left, then one row per hunter of YOUR squad
## (yours first and outlined): portrait, name and alive / downed / out, kills / deaths / assists, damage,
## the four gear slots worn, and the Boki (name, level and form, what it is doing). Rival squads get
## nothing but the count: no names, stats or who is still up (docs/TAB_BOARD_PARITY.md). Read only:
## it reads Match and Hunter (assists are counted by DashReset). HUD wiring is one call in Hud._draw.
## Look: Void & Masks (briefs/UI_STYLE.md), one panel, one strip per hunter.

enum Status { ALIVE, DOWNED, OUT, SAFE }

const STATUS_WORDS := ["alive", "downed", "out", "got out"]
const FACE_STATES := {Status.DOWNED: "down", Status.OUT: "dead", Status.SAFE: "out"}      # Portraits states
const KIN_WORDS := {"downed": "down", "reviving": "reviving", "fused": "merged", "bench": "benched", "away": "away"}

const VOID := Color(0.12, 0.08, 0.19, 0.92)      # black-violet panel
const STRIP := Color(0.17, 0.11, 0.26, 0.95)     # one hunter's row
const TEAL := Color("3fe0d0")                    # edge, alive, your row
const MAGENTA := Color("ff3fd0")                 # edge, the squads-left number
const AMBER := Color("ffb36a")                   # downed
const DIM := Color("5a5170")                     # out
const MINT := Color("8fe3c8")                    # got away
const W := 720.0         # px board width
const ROW_H := 58.0      # px per hunter row
const FACE := 46.0       # px portrait side
const CELL := 28.0       # px gear cell side
const TOP := 82.0        # px from the board's top to the first row
const X_KDA := 260.0     # px column starts from the board's left edge
const X_DMG := 350.0
const X_GEAR := 420.0
const X_BOKI := 560.0

## Everything the board shows, as plain data (the check reads this too).
static func snapshot(m: Match) -> Dictionary:
	var teams := {}
	for h: Hunter in m.hunters:
		teams[h.team] = true
	var left := 0
	for t in teams:
		left += int(Life.team_alive(m, t))
	var crew: Array = []
	if m.player:
		for h: Hunter in m.hunters:
			if h.team != m.player.team:
				continue
			var row := {"h": h, "name": h.pname, "me": h == m.player, "status": status_of(h),
				"k": h.kills, "d": h.deaths, "a": h.assists, "dmg": int(h.dmg_done), "gear": h.gear, "boki": boki_of(h)}
			if row["me"]: crew.push_front(row)
			else: crew.append(row)
	return {"left": left, "crew": crew}

static func status_of(h: Hunter) -> int:
	if h.extracted: return Status.SAFE
	if h.out: return Status.OUT
	return Status.DOWNED if h.downed else Status.ALIVE

## The Boki line: {name, lvl, form ("" when it is still its base form), state, col}; {} with no Boki.
static func boki_of(h: Hunter) -> Dictionary:
	var k: Kin = h.kin
	if k == null:
		return {}
	var base := String(Data.KIN[k.species]["name"])
	var form := String(k.rec.get("form_name", ""))
	var state: String = KIN_WORDS.get(k.state, "fighting" if k.target else "ready")
	return {"name": String(k.rec.get("name", base)), "lvl": int(k.rec.get("level", 1)),
		"form": form if form != base else "", "state": state, "col": Data.KIN[k.species]["color"]}

static func status_col(s: int) -> Color:
	match s:
		Status.ALIVE: return TEAL
		Status.DOWNED: return AMBER
		Status.SAFE: return MINT
	return DIM

## Draws the board centred on the screen. `hud` is the HUD, for its panel, text and portrait helpers.
static func draw(hud, sz: Vector2) -> void:
	var s := snapshot(hud.m)
	var c: CanvasItem = hud.c
	var r := Rect2(Vector2((sz.x - W) * 0.5, sz.y * 0.14), Vector2(W, TOP + s["crew"].size() * ROW_H + 10.0))
	hud._rounded(r, VOID, 14, Color(TEAL, 0.55), 2)
	c.draw_line(r.position + Vector2(14, 2), r.position + Vector2(W * 0.5, 2), Color(MAGENTA, 0.8), 3.0)
	hud._text(r.position + Vector2(20, 36), "SQUADS LEFT", 16, HudStyle.MUTED, hud.big)
	hud._text(r.position + Vector2(168, 40), str(s["left"]), 28, MAGENTA, hud.big)
	var head_y := r.position.y + TOP - 8.0
	hud._text(Vector2(r.position.x + 20, head_y), "YOUR SQUAD", 13, TEAL, hud.big)
	hud._text(Vector2(r.position.x + X_KDA, head_y), "K / D / A", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + X_DMG, head_y), "DMG", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + X_GEAR, head_y), "GEAR", 12, HudStyle.MUTED, hud.big)
	hud._text(Vector2(r.position.x + X_BOKI, head_y), "BOKI", 12, HudStyle.MUTED, hud.big)
	for i in s["crew"].size():
		_draw_row(hud, Rect2(r.position + Vector2(12, TOP + i * ROW_H), Vector2(W - 24, ROW_H - 6)), s["crew"][i])

static func _draw_row(hud, rr: Rect2, e: Dictionary) -> void:
	var h: Hunter = e["h"]
	var st: int = e["status"]
	hud._rounded(rr, STRIP, 8, Color(TEAL, 0.85) if e["me"] else Color(0, 0, 0, 0), 2)
	var face := Rect2(rr.position + Vector2(6, (rr.size.y - FACE) * 0.5), Vector2(FACE, FACE))
	hud._draw_portrait(face, h, String(FACE_STATES.get(st, "")), SideColor.of(hud.m, h))
	var x0 := rr.position.x - 12.0
	var y1 := rr.position.y + 22.0
	var y2 := rr.position.y + 40.0
	hud._text(Vector2(face.end.x + 10, y1), e["name"], 15, HudStyle.GOLD if e["me"] else HudStyle.INK, hud.big)
	hud._text(Vector2(face.end.x + 10, y2), STATUS_WORDS[st], 12, status_col(st), hud.big)
	hud._text(Vector2(x0 + X_KDA, y1 + 8), "%d / %d / %d" % [e["k"], e["d"], e["a"]], 16, HudStyle.INK, hud.big)
	hud._text(Vector2(x0 + X_DMG, y1 + 8), str(e["dmg"]), 15)
	for j in Gear.SLOTS.size():
		var at := Vector2(x0 + X_GEAR + j * (CELL + 4.0), rr.get_center().y - CELL * 0.5)
		GearPanel.cell(hud, Rect2(at, Vector2(CELL, CELL)), e["gear"][j], j)
	var b: Dictionary = e["boki"]
	if b.is_empty():
		hud._text(Vector2(x0 + X_BOKI, y1 + 8), "none", 13, DIM)
		return
	hud._text(Vector2(x0 + X_BOKI, y1), b["name"], 14, b["col"], hud.big)
	var lv := "Lv %d %s" % [b["lvl"], b["form"]] if b["form"] != "" else "Lv %d" % b["lvl"]
	var ink: Color = AMBER if b["state"] == "down" else HudStyle.MUTED
	hud._text(Vector2(x0 + X_BOKI, y2), "%s  ·  %s" % [lv, b["state"]], 12, ink)
