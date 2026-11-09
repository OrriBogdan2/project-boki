class_name TeamBoki
extends RefCounted
## A small Boki icon on each squad row (Hud._draw_squad): the species portrait with a thin health bar under it, so a
## squad sees whose Boki is down. It sits on the corner of the teammate's portrait and tints for a downed Boki (red),
## a resting one (blue) and an owner who is a wisp (violet). Online, a teammate's Boki is the Kin the snapshot
## already updates (hp, state, rest seconds), so it reads that and adds no net traffic.

const ROW_STEP := 66.0         # px between squad rows (Hud._draw_squad)
const ROW_X := 16.0            # px: squad row's left edge
const PORTRAIT_END := 54.0     # px from the row's left edge to the portrait's right edge (6 + 48)
const ROW_DROP := 54.0         # px from the row's top to the portrait's bottom edge
const ICON := 20.0             # px: the Boki icon's side
const BAR_H := 3.0             # px: its health bar
const TINT_DOWN := Color("ff4a3a")
const TINT_REST := Color("6aa8ff")
const TINT_WISP := Color("b08cff")
const TINT_ALPHA := 0.45       # how strongly a tint covers the icon

## hunter nid -> {"state": "", "down", "rest" or "wisp", "frac": health 0..1}: what the last draw put on each row
static var shown := {}

## The icon's state for a teammate's Boki: "down", "rest", "wisp" (its owner is down) or "".
static func state_of(h: Hunter, k: Kin) -> String:
	if k.dead or k.state == "downed" or k.state == "reviving":
		return "down"
	if k.resting():
		return "rest"
	return "wisp" if h.downed else ""

static func draw(hud, p: Hunter) -> void:
	shown.clear()
	var y: float = hud.mm_bottom + 10.0
	for h in hud.m.hunters:
		if h == p or h.team != p.team:
			continue
		var k: Kin = h.kin
		if k != null and not h.out and not h.extracted:
			_icon(hud, Vector2(ROW_X + PORTRAIT_END - ICON, y + ROW_DROP - ICON - BAR_H), h, k)
		y += ROW_STEP

static func _icon(hud, at: Vector2, h: Hunter, k: Kin) -> void:
	var st := state_of(h, k)
	var frac := clampf(k.hp / maxf(1.0, k.max_hp), 0.0, 1.0)
	shown[h.nid] = {"state": st, "frac": frac}
	var sp: Dictionary = Data.KIN[k.species]
	var r := Rect2(at, Vector2(ICON, ICON))
	hud._rounded(r.grow(2.0), Color(0.03, 0.03, 0.05, 0.92), 6)
	var tex := KinPortrait.tex(k.rec, hud.get_tree())
	if tex != null:
		hud.c.draw_texture_rect(tex, r, false)
	else:
		var body: Color = sp["color"]
		hud.c.draw_circle(r.get_center(), ICON * 0.5, Color(sp.get("glow", body), 0.6))
		hud.c.draw_circle(r.get_center(), ICON * 0.5 - 2.0, body)
	var fill: Color = HudStyle.hp_fill(HudStyle.ALLY, frac, hud.m.time)
	if st != "":
		fill = {"down": TINT_DOWN, "rest": TINT_REST, "wisp": TINT_WISP}[st]
		hud._rounded(r, Color(fill, TINT_ALPHA), 6)
	var bar := Rect2(Vector2(at.x, r.end.y + 1.0), Vector2(ICON, BAR_H))
	hud._bar(bar, 0.0 if st == "down" else frac, fill)
