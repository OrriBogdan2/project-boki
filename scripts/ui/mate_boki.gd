class_name MateBoki
extends RefCounted
## A squad row's Boki icon (DECISIONS Boki HUD, owner Nov 3): the hunter's Boki as a small species portrait at the
## row's right end, ringed by a thin health arc, so the squad sees whose Boki is down.
##   alive    portrait in full colour, the arc runs clockwise from the top (yellow, red under LOW)
##   wisp     it rides as a wisp (KinWisp, or round its knocked hunter): a pulsing glow in its colour behind a
##            see-through, tinted portrait (the soul-linked look, DECISIONS 2026-11-09); the arc stays
##   down     knocked out (state "downed") or dead: grey, no arc, a red X
## It reads the Kin the match already holds (online that is the snapshot's state, hp and wisp flag, KinNet), so
## teammates' icons need no extra net data. Sizes are HUD units, like SquadFrames.

const DX := 80.0  # units right of the row's portrait centre (the bar ends at 66)
const R := 8.2  # units: the portrait's radius (the arc sits just outside it)
const ARC_W := 1.7  # units: the health arc's width
const LOW := 0.3  # health fraction under which the arc turns red
const LOW_COL := Color("ff5a4a")
const TRACK := Color(0.01, 0.0, 0.02, 0.85)  # the arc's empty part
const TINT_DOWN := Color(0.78, 0.78, 0.82, 0.72)  # a downed Boki's face goes grey
const WISP_A := 0.78  # the wisp portrait's opacity
const MARK_X := Color("e84b5b")

## nid of the hunter -> {"state", "hp", "species"}: what the last draw showed (checks read it)
static var shown := {}


## The hunter's own Boki (null when they have none or it is gone from the world).
static func of(h: Hunter) -> Kin:
	var k := h.kin as Kin
	return k if k != null and is_instance_valid(k) and k.owner_h == h else null


## "alive", "wisp" or "down" for a Boki.
static func state_of(k: Kin) -> String:
	if k.dead or k.state == "downed":
		return "down"
	if k.wisp or k.state == "wisp":
		return "wisp"
	return "alive"


## The icon's centre for the row whose portrait is at `at`.
static func centre(at: Vector2) -> Vector2:
	return at + Vector2(DX, 0.0)


## The area the icon takes (SafeArea).
static func rect(at: Vector2) -> Rect2:
	var c := centre(at)
	return Rect2(c - Vector2.ONE * (R + 2.0), Vector2.ONE * (R + 2.0) * 2.0)


## Draws row `h`'s Boki icon at `at` (the row's portrait centre) and records it in `shown`.
static func draw(hud, at: Vector2, h: Hunter) -> void:
	var k := of(h)
	if k == null:
		return
	var c: CanvasItem = hud.c
	var st := state_of(k)
	var ctr := centre(at)
	var glow: Color = k.sp.get("glow", k.sp.get("color", Color.WHITE))
	var pulse := 0.5 + 0.5 * sin(hud.m.time * 3.0)
	if st == "wisp":
		c.draw_circle(ctr, R + 4.5 + pulse, Color(glow, 0.14))
		c.draw_circle(ctr, R + 2.8, Color(glow, 0.22))
	c.draw_circle(ctr, R + 1.2, HudStyle.SHADE_EDGE)
	var tex := KinPortrait.tex(k.rec, hud.get_tree())
	var blank := Color(k.sp.get("color", Color.WHITE)).darkened(0.3)
	var mod := Color(1, 1, 1, WISP_A) if st == "wisp" else Color.WHITE
	var pts := SquadFrames.disc(c, ctr, R, tex, blank, mod)
	if st == "wisp":
		c.draw_colored_polygon(pts, Color(glow.lightened(0.4), 0.28 + 0.12 * pulse))
	elif st == "down":
		c.draw_colored_polygon(pts, TINT_DOWN)
	var frac := clampf(k.hp / maxf(1.0, k.max_hp), 0.0, 1.0) if st != "down" else 0.0
	var ring := R + 0.9 + ARC_W * 0.5
	c.draw_arc(ctr, ring, 0.0, TAU, 28, TRACK, ARC_W, true)
	if frac > 0.0:
		var col := LOW_COL if frac < LOW else SquadFrames.HP_COL
		c.draw_arc(ctr, ring, -PI * 0.5, -PI * 0.5 + TAU * frac, 28, col, ARC_W, true)
	if st == "down":
		var v := Vector2.ONE * R * 0.5
		c.draw_line(ctr - v, ctr + v, MARK_X, 2.2, true)
		c.draw_line(ctr + Vector2(-v.x, v.y), ctr + Vector2(v.x, -v.y), MARK_X, 2.2, true)
	shown[h.nid] = {"state": st, "hp": frac, "species": k.species}
