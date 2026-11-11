class_name WaysOutPins
extends RefCounted
## The Ways Out seats and the Blight's edge read from afar in the play view (decision 0051 "Seat looks"). The match
## camera frames about 15 m round the player, so a seat's beam or the Blight's wall farther off is out of frame
## whatever its height. Each seat still to be had (locked, open, in use) within REACH_M and off screen gets a pin on
## the edge of the play box toward it: its map badge (WaysOutMap: the state's shape and colour, the countdown arc,
## the squad's colour while in use) under a beam when open or in use, its word and the distance. The Heart ring's
## pin waits while the Gate is still to be had, unless the ring is open. The Blight's wall within WALL_M gets a
## crimson bar on that edge, heavier as it nears. Canvas draws only; once on screen the world looks (SeatBeacon,
## BlightWall) carry the read.

const REACH_M := 90.0      # m: seats farther off are left to the minimap's edge arrows
const WALL_M := 70.0       # m: the Blight's wall closer than this gets its bar
const BADGE_R := 12.0      # px, a pin's badge
const BEAM_W := 5.0        # px, the beam over an open or used seat's badge...
const BEAM_H := 24.0       # ...and its height
const GAP := 44.0          # px: a pin that would sit on an earlier one moves along the edge by this
const FS := 17             # px, a pin's line

static var _placed := PackedVector2Array()    # this frame's pins (cleared, not reallocated)

static func draw(hud) -> void:
	var m: Match = hud.m
	var p: Hunter = m.player
	if m.heart == null or m.heart.site == Vector3.INF or p == null or p.out or p.extracted:
		return
	_placed.clear()
	var c: Control = hud.c
	var at := WaysOutMap.sites(m)
	var sd := WaysOutHud.seats(m)
	for i in 4:
		var dir := seat_dir(m, c.size, i, sd, at[i])
		if dir == Vector2.ZERO:
			continue
		var e := _place(c.size, dir)
		var col := WaysOutMap.color_of(sd[i])
		WaysOutMap.badge(c, e, BADGE_R, i, sd[i], m.time)
		if int(sd[i]["st"]) != WaysOutHud.St.LOCKED:
			_beam(c, e, col)
		var tip := e + dir * (BADGE_R + 11.0)
		var back := tip - dir * 8.0
		var wing := Vector2(-dir.y, dir.x) * 6.0
		c.draw_colored_polygon(PackedVector2Array([tip, back + wing, back - wing]), col)
		_label(c, e, dir, "%s  %d m" % [WaysOutMap.word(i, sd[i]), int(p.flat_dist(at[i]))], col)
	var wd := wall_dir(m, c.size)
	if wd != Vector2.ZERO:
		var gap := wall_gap(m)
		var e := _place(c.size, wd)
		var side := Vector2(-wd.y, wd.x)
		var w := lerpf(4.0, 12.0, 1.0 - gap / WALL_M)
		c.draw_line(e - side * 36.0, e + side * 36.0, Color(0, 0, 0, 0.6), w + 4.0)
		c.draw_line(e - side * 34.0, e + side * 34.0, HeartHud.TIDE_COL, w)
		_label(c, e, wd, "Blight  %d m" % int(gap), HeartHud.NEXT_COL)

## The screen direction of seat `i`'s pin, or ZERO for none: the seat is gone (taken, lost), farther than REACH_M,
## on screen, or it is the Heart ring still locked while the Gate is to be had. `sd` is WaysOutHud.seats.
static func seat_dir(m: Match, sz: Vector2, i: int, sd: Array, at: Vector3) -> Vector2:
	var st := int(sd[i]["st"])
	if at == Vector3.INF or st > WaysOutHud.St.USE or m.player.flat_dist(at) > REACH_M:
		return Vector2.ZERO
	if i == 3 and st == WaysOutHud.St.LOCKED and int(sd[1]["st"]) <= WaysOutHud.St.USE:
		return Vector2.ZERO
	return MarkerDir.off_dir(m.cam, sz, at, m.player.pos)

## Metres from the player in to the Blight's wall, or -1: no ring yet, or the player is out past it (HeartHud
## tints the screen there).
static func wall_gap(m: Match) -> float:
	var tr := Heart.tide_r(m)
	var d := tr - m.player.flat_dist(m.heart.site)
	return d if tr > 0.0 and d >= 0.0 else -1.0

## The screen direction of the wall's bar, or ZERO for none (no wall within WALL_M, or its nearest stretch is on
## screen and draws itself).
static func wall_dir(m: Match, sz: Vector2) -> Vector2:
	var d := wall_gap(m)
	var p := m.player.pos
	var out := Vector2(p.x - m.heart.site.x, p.z - m.heart.site.z)
	if d < 0.0 or d > WALL_M or out.length() < 0.1:
		return Vector2.ZERO
	out = out.normalized() * d
	return MarkerDir.off_dir(m.cam, sz, p + Vector3(out.x, 0.0, out.y), p)

## An open or used seat's pin carries the world look's tall beam over its badge (a locked one is the stub: none).
static func _beam(c: Control, e: Vector2, col: Color) -> void:
	var r := Rect2(e.x - BEAM_W * 0.5, e.y - BADGE_R - 3.0 - BEAM_H, BEAM_W, BEAM_H)
	c.draw_rect(r.grow(2.0), Color(0, 0, 0, 0.6))
	c.draw_rect(r, col)

## Where a pin sits: the arrow box's edge toward `dir`, moved along the edge off the pins already drawn.
static func _place(sz: Vector2, dir: Vector2) -> Vector2:
	var e := MarkerDir.edge_point(sz, dir)
	for q in _placed:
		if e.distance_to(q) < GAP:
			e += Vector2(-dir.y, dir.x) * GAP
	_placed.append(e)
	return e

## A pin's line: beside its badge on the screen side at the left and right edges, under it at the top and bottom
## (the beam stands over it).
static func _label(c: Control, e: Vector2, dir: Vector2, s: String, col: Color) -> void:
	var w := TextCache.width(HudStyle.BIG, s, FS)
	var at := Vector2(e.x - w * 0.5, e.y + BADGE_R + 20.0)
	if absf(dir.x) > absf(dir.y):
		at = Vector2(e.x + BADGE_R + 8.0 if dir.x < 0.0 else e.x - BADGE_R - 8.0 - w, e.y + 6.0)
	HudStyle.text(c, at, s, FS, col, 3)
