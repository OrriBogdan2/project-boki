class_name TeamBoki
extends RefCounted
## A Boki icon on each teammate's squad row (SquadFrames), past the end of its bars (DECISIONS Boki HUD, owner
## Nov 3: the left side stays teammates, each row carries its Boki so a squad sees whose Boki is down): the
## species portrait cut to a disc, ringed by a thin health arc from the top, clockwise.
##   alive    full colour; the arc is the ally's health colour, red under LOW
##   down     (knocked out or dead) grey face, no arc, a red X
##   rest     (after a merge) blue tint and arc
##   wisp     it rides as a wisp (KinWisp, or round its knocked owner): a pulsing glow in its colour behind a
##            see-through, violet-tinted face (the soul-linked look, DECISIONS 2026-11-09); the arc stays
## Online, a teammate's Boki is the Kin the snapshot already updates (hp, state, rest seconds, wisp flag), so it
## reads that and adds no net traffic. A teammate who carries stolen wisps (KinSteal) also wears a small count
## badge on the icon's corner, in the thief's side colour.

const R := 10.0  # units: the portrait radius (the arc sits outside it)
const C := Vector2(80.0, -1.0)  # units: row portrait centre to icon centre (past the bars, clear of the marker)
const ARC_W := 1.7             # units: the health arc's width
const LOW := 0.3               # health fraction under which a live arc turns red
const LOW_COL := Color("ff5a4a")
const TRACK := Color(0.01, 0.0, 0.02, 0.85)  # the arc's empty part
const TINT_REST := Color("6aa8ff")
const TINT_WISP := Color("b08cff")
const GREY := Color(0.62, 0.62, 0.66, 0.78)  # a downed Boki's face
const MARK_X := Color("e84b5b")
const WISP_A := 0.78           # the wisp face's opacity
const BADGE_FROM := Vector2(R, -R * 0.9)  # the stolen-wisp badge, from the icon's centre

## hunter nid -> {"state": "", "down", "rest" or "wisp", "frac": health 0..1}: what the last draw put on each row
static var shown := {}
## hunter nid -> how many stolen wisps the badge on their row says
static var stolen_shown := {}

## The icon's state for a teammate's Boki: "down", "rest", "wisp" (it rides as a wisp, or its owner is down) or "".
static func state_of(h: Hunter, k: Kin) -> String:
	if k.dead or k.state == "downed":
		return "down"
	if k.resting():
		return "rest"
	return "wisp" if h.downed or k.wisp or k.state == "wisp" else ""

static func draw(hud, p: Hunter) -> void:
	shown.clear()
	stolen_shown.clear()
	var all := SquadFrames.rows(hud.m, p)
	for i in all.size():
		var h: Hunter = all[i]
		if h == p or h.out or h.extracted:
			continue
		var at := SquadFrames.centre(hud, i) + C
		if h.kin != null:
			_icon(hud, at, h, h.kin)
			SafeArea.note(Rect2(at - Vector2.ONE * (R + ARC_W + 1.0), Vector2.ONE * (R + ARC_W + 1.0) * 2.0))
		var n := KinSteal.count(h)
		if n > 0:
			stolen_shown[h.nid] = n
			HudStyle.count_badge(hud.c, at + BADGE_FROM, n, SideColor.ally())

static func _icon(hud, at: Vector2, h: Hunter, k: Kin) -> void:
	var c: CanvasItem = hud.c
	var st := state_of(h, k)
	var frac := clampf(k.hp / maxf(1.0, k.max_hp), 0.0, 1.0)
	shown[h.nid] = {"state": st, "frac": frac}
	var sp: Dictionary = Data.KIN[k.species]
	var body: Color = sp["color"]
	var glow: Color = sp.get("glow", body)
	var pulse := 0.5 + 0.5 * sin(hud.m.time * 3.0)
	if st == "wisp":
		c.draw_circle(at, R + 4.5 + pulse, Color(glow, 0.14))
		c.draw_circle(at, R + 2.8, Color(glow, 0.22))
	c.draw_circle(at, R + 1.2, HudStyle.SHADE_EDGE)
	var tex := KinPortrait.tex(k.rec, hud.get_tree())
	var mod := Color(1, 1, 1, WISP_A) if st == "wisp" else Color.WHITE
	var pts := SquadFrames.disc(c, at, R, tex, body.darkened(0.3), mod)
	var arc: Color = HudStyle.hp_fill(SideColor.ally(), frac, hud.m.time)
	if frac < LOW:
		arc = LOW_COL
	match st:
		"down":
			c.draw_colored_polygon(pts, GREY)
		"rest":
			c.draw_colored_polygon(pts, Color(TINT_REST, 0.4))
			arc = TINT_REST
		"wisp":
			c.draw_colored_polygon(pts, Color(TINT_WISP.lightened(0.2), 0.3 + 0.12 * pulse))
	var ring := R + 0.9 + ARC_W * 0.5
	c.draw_arc(at, ring, 0.0, TAU, 28, TRACK, ARC_W, true)
	if st != "down" and frac > 0.0:
		c.draw_arc(at, ring, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, arc, ARC_W, true)
	if st == "down":
		var v := Vector2.ONE * R * 0.5
		c.draw_line(at - v, at + v, MARK_X, 2.2, true)
		c.draw_line(at + Vector2(-v.x, v.y), at + Vector2(v.x, -v.y), MARK_X, 2.2, true)
