class_name KillFeed
extends RefCounted
## The kill feed (Match.feed): top right under the counters, drawn like the squad frames. A row reads
##   [knocker's face] [icon of what did it] [victim's face], names beside the faces, a bar of each squad's colour at
## the ends. A knock tints the victim's face the squad frames' knocked red (they become a Wisp); a finish (a stomp, or
## a bleed-out) greys it and crosses it out. A Boki's kill shows its owner's face and a paw on the icon. A monster
## or the Blight with no Hunter to credit shows its name in place of the face. Rows with your squad in them are
## outlined in your side's colour. Any other line stays a text plate. At most ROWS rows, each fully shown HOLD_S then
## faded over FADE_S, none wider than LANE_W.

const ROWS := 4                # rows on show at most (a new one pushes the oldest out)
const HOLD_S := 5.0            # s a row is fully shown
const FADE_S := 0.5            # s it then takes to fade out
const LIFE_S := HOLD_S + FADE_S
const LANE_W := 280.0          # px: the widest row
const GAP := 4.0               # px between rows
const ROW_H := 30.0            # px: a face row's height
const TEXT_H := 24.0           # px: a one-line text row's height
const TEXT_BASE := 17.0        # px from a text row's top to its first baseline
const BASELINE := 5.0          # px below a face row's middle where its names sit
const NAME_PX := HudStyle.PLATE_NAME_FS      # font px for names and lines: the overhead plates'
const NAME_W := 84.0           # px: a longer name is cut with an ellipsis
const FACE_R := 11.5           # px: a face disc's radius (the squad frames' killer disc)
const RIM := 2.0               # px: the ring around a face, in its squad's colour
const ICON_W := 26.0           # px: the icon's cell between the faces
const ICON_S := 8.5            # Icons.draw size of that icon
const PAW_S := 4.5             # Icons.draw size of the paw on a Boki's icon
const SEP := 6.0               # px between a name, a face and the icon
const EDGE := 14.0             # px from a plate's end to its content: the bar's inset, the bar, padding
const BAR := 4.0               # px: a squad's colour bar
const BAR_IN := 2.0            # px from the plate's end to its bar
const TEXT_PAD := 12.0         # px after a text row's line
const RADIUS := 6              # px: plate corners
const MINE_FILL := Color(0.08, 0.1, 0.15, 0.9)     # a row your squad is in: a little lifted
const FALLBACK_ICON := "knock"                      # a knock nobody dealt (a fall, the zone)
const ELLIPSIS := "…"
## The finishes the feed draws as a row (Match.eliminate's why) and the icon each shows.
const FINISH_ICON := {"finished": "stomp", "executed": "stomp", "knocked out": "stomp", "bled out": "bleed"}
## A hit's "ab" (the slot that dealt it) -> the bar slot whose icon the row shows. Anything else (a plain shot
## or swing, a passive) shows the weapon's icon, as the weapon slot does.
const SLOT_OF := {"utility": "sec", "rmb": "sec", "k1": "k1", "e": "k1", "ult": "x", "ultimate": "x", "x": "x",
		"dodge": "dash"}

static var shown: Array[Dictionary] = []     # what the last draw put up, top to bottom (--kill-feed-check reads it)
static var _fitted := {}                     # name -> the name cut to NAME_W

## The icon of what landed a knock: the slot's icon on the knocker's own bar, the weapon's for a plain hit, the
## Boki's ability for a Boki's, a claw for a monster or the Blight, else FALLBACK_ICON.
static func icon_of(by: Ent, o: Dictionary) -> String:
	var ab := String(o.get("ab", ""))
	if by is Kin:
		var k := by as Kin
		return KinText.icon(k.runner.def_of(ab)) if k.runner and ab in ["k1", "k2"] else "paw"
	var h := owner_of(by)
	if h == null:
		return "claw" if by is Mob or by is Blight else FALLBACK_ICON
	if SLOT_OF.has(ab):
		var icon := String(h.slot_info(SLOT_OF[ab]).get("icon", ""))
		if icon != "":
			return icon
	return h.wid if h.wid != "" else FALLBACK_ICON

## The Hunter a hit counts for: the Hunter, or a Boki's owner; null for anything else.
static func owner_of(by: Ent) -> Hunter:
	if by is Kin and by.owner_h:
		return by.owner_h
	return by as Hunter

## Puts a knock in the feed and the match log (`by` dealt it; `icon` from icon_of, "" for the fallback).
static func knock(m: Match, who: Hunter, by: Ent, icon: String) -> void:
	var from := owner_of(by)
	if from == who:
		from = null
	m.add_feed(("%s knocked %s" % [from.pname, who.pname]) if from else "%s went down" % who.pname)
	m.feed.back().merge({"by": from, "who": who, "icon": icon if icon != "" else FALLBACK_ICON, "src": _src(by, from),
		"boki": by is Kin, "kind": "knock"})

## Puts someone going out in the feed: a stomp or a bleed-out as a row, any other reason as its text line.
static func out(m: Match, who: Hunter, by: Ent, why: String) -> void:
	if not FINISH_ICON.has(why):
		m.add_feed(Match.out_text(who.pname, why))
		return
	var from := owner_of(by)
	if from == who:
		from = null
	m.add_feed(("%s finished %s" % [from.pname, who.pname]) if from else "%s %s" % [who.pname, why])
	m.feed.back().merge({"by": from, "who": who, "icon": FINISH_ICON[why], "src": _src(by, from),
		"boki": by is Kin, "kind": "finish"})

## The name shown where a face would be when no Hunter is credited: the Blight, a monster; "" for nothing.
static func _src(by: Ent, from: Hunter) -> String:
	if from or by == null:
		return ""
	return "Blight" if by is Blight else String(by.kind).capitalize().replace("_", " ")

## Draws the feed down from Hud.feed_top at the safe margin's right edge, oldest on top.
static func draw(H, sz: Vector2) -> void:
	shown.clear()
	var pad := HudStyle.safe_pad(sz)
	var y: float = maxf(H.feed_top, pad.y)
	for f: Dictionary in H.m.feed:
		var a := snappedf(clampf((LIFE_S - float(f["t"])) / FADE_S, 0.0, 1.0), 0.125)
		var right := sz.x - pad.x
		var row := _face_row(H, f, right, y, a) if is_instance_valid(f.get("who")) else _text_row(H, f, right, y, a)
		shown.append(row)
		y = (row["rect"] as Rect2).end.y + GAP

## [bar] knocker (name, face) | icon | victim (face, name) [bar]. With no knocker face the monster's name, or
## nothing, stands in for it.
static func _face_row(H, f: Dictionary, right: float, y: float, a: float) -> Dictionary:
	var m: Match = H.m
	var who: Hunter = f["who"]
	var by: Hunter = f["by"] if is_instance_valid(f.get("by")) else null
	var src := String(f.get("src", ""))
	var finish: bool = f.get("kind", "") == "finish"
	var right_name := _fit(H.big, who.pname)
	var left_name := _fit(H.big, by.pname) if by else _fit(H.big, src)
	var left_w := 0.0
	if by:
		left_w = _w(H, left_name) + SEP * 2.0 + FACE_R * 2.0
	elif src != "":
		left_w = _w(H, left_name) + SEP
	var w := EDGE * 2.0 + left_w + ICON_W + SEP * 2.0 + FACE_R * 2.0 + _w(H, right_name)
	var r := Rect2(right - w, y, w, ROW_H)
	var hl := Color.TRANSPARENT
	if _mine(m, by) or _mine(m, who):
		hl = SideColor.of(m, m.player)
	_plate(H, r, a, hl)
	var mid := y + ROW_H * 0.5
	var x := r.position.x + EDGE
	if by:
		_bar(H, r.position.x + BAR_IN, r, _squad(by), a)
		x = _side(H, by, left_name, x, mid, a, true, "")
	elif src != "":
		H._text(Vector2(x, mid + BASELINE), left_name, NAME_PX, Color(HudStyle.HURT, a), H.big)
		x += left_w
	var icon := String(f["icon"])
	var at := Vector2(x + ICON_W * 0.5, mid)
	Icons.draw(H.c, icon, at, ICON_S, Color(HudStyle.INK, a))
	if f.get("boki", false):
		Icons.draw(H.c, "paw", at + Vector2(-ICON_S, -ICON_S) * 0.8, PAW_S, Color(HudStyle.GOLD, a))
	_side(H, who, right_name, x + ICON_W, mid, a, false, "finish" if finish else "knock")
	_bar(H, r.end.x - BAR_IN - BAR, r, _squad(who), a)
	return {"kind": String(f.get("kind", "knock")), "rect": r, "a": a, "left": left_name if by or src != "" else "",
		"right": right_name, "icon": icon, "boki": f.get("boki", false), "src": src, "mine": hl.a > 0.0,
		"left_col": _squad(by) if by else Color.TRANSPARENT, "right_col": _squad(who)}

## One side of a row from `x`: the name then the face (the knocker), or the face then the name (the victim).
## Your squad's names wear your side's colour. `fate`: "knock" tints the face knocked red, "finish" greys and
## crosses it out. Returns where the side ends.
static func _side(H, h: Hunter, label: String, x: float, mid: float, a: float, name_first: bool, fate: String) -> float:
	var col := SideColor.of(H.m, h) if _mine(H.m, h) else HudStyle.INK
	var w := _w(H, label)
	var face_x := x + w + SEP + FACE_R if name_first else x + SEP + FACE_R
	var text_x := x if name_first else x + SEP * 2.0 + FACE_R * 2.0
	H._text(Vector2(text_x, mid + BASELINE), label, NAME_PX, Color(col, a), H.big)
	_face(H, Vector2(face_x, mid), h, a, fate)
	return x + w + SEP * 2.0 + FACE_R * 2.0

## A face disc in a ring of its squad's colour, faded by `a`: the painted portrait once a worker has cut it (a
## Hunter's first row never stalls a frame reading art), or the rendered model for one with no painting.
static func _face(H, at: Vector2, h: Hunter, a: float, fate: String) -> void:
	var c: CanvasItem = H.c
	c.draw_circle(at, FACE_R + RIM, Color(_squad(h), 0.9 * a))
	var ak := Portraits.arch_of(h)
	var path := Portraits.art_path(ak)
	var px := Vector2i(SquadFrames.PORTRAIT_PX, SquadFrames.PORTRAIT_PX)
	var tex: Texture2D = H.portrait(h) if path == "" else Portraits.cut_soon(ak, path, px)
	var pts := SquadFrames.disc(c, at, FACE_R, tex, SquadFrames.FRAME, Color(1, 1, 1, a))
	if fate == "knock":
		c.draw_colored_polygon(pts, Color(SquadFrames.TINT_KNOCK, SquadFrames.TINT_KNOCK.a * a))
	elif fate == "finish":
		c.draw_colored_polygon(pts, Color(SquadFrames.TINT_DEAD, SquadFrames.TINT_DEAD.a * a))
		var v := Vector2(1, 1) * FACE_R * 0.5
		for d in [v, Vector2(v.x, -v.y)]:
			c.draw_line(at - d, at + d, Color(SquadFrames.MARK_X, a), 2.6, true)

## Any other line: a plate with a bar in your side's colour when the line starts with one of your squad, else
## gold. A line too long for the lane wraps inside it.
static func _text_row(H, f: Dictionary, right: float, y: float, a: float) -> Dictionary:
	var s := String(f["text"])
	var room := LANE_W - EDGE - TEXT_PAD
	var wide := _w(H, s)
	var tall := TEXT_H
	if wide > room:
		tall = H.big.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, room, NAME_PX).y + TEXT_H - NAME_PX
	var w := minf(wide, room) + EDGE + TEXT_PAD
	var r := Rect2(right - w, y, w, tall)
	_plate(H, r, a, Color.TRANSPARENT)
	_bar(H, r.position.x + BAR_IN, r, _line_colour(H.m, s), a)
	var at := Vector2(r.position.x + EDGE, y + TEXT_BASE)
	if wide > room:
		var shadow := Color(0, 0, 0, 0.55 * a)
		H.c.draw_multiline_string_outline(H.big, at, s, HORIZONTAL_ALIGNMENT_LEFT, room, NAME_PX, -1, 4, shadow)
		H.c.draw_multiline_string(H.big, at, s, HORIZONTAL_ALIGNMENT_LEFT, room, NAME_PX, -1, Color(HudStyle.INK, a))
	else:
		H._text(at, s, NAME_PX, Color(HudStyle.INK, a), H.big)
	return {"kind": "text", "rect": r, "a": a, "text": s}

## The row's plate: the HUD's frame shade. `hl` (your side's colour; transparent when your squad isn't in the
## row) outlines and lifts it.
static func _plate(H, r: Rect2, a: float, hl: Color) -> void:
	if hl.a > 0.0:
		H._rounded(r, Color(MINE_FILL, MINE_FILL.a * a), RADIUS, Color(hl, 0.9 * a), 2)
	else:
		H._rounded(r, Color(HudStyle.SHADE, HudStyle.SHADE.a * a), RADIUS)

## A colour bar at `x` down row `r`, inset from its rounded corners.
static func _bar(H, x: float, r: Rect2, col: Color, a: float) -> void:
	H.c.draw_rect(Rect2(x, r.position.y + BAR_IN * 2.0, BAR, r.size.y - BAR_IN * 4.0), Color(col, a))

## A squad's colour, the one the scoreboard shows beside its names.
static func _squad(h: Hunter) -> Color:
	return Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]

static func _mine(m: Match, h: Hunter) -> bool:
	return h != null and m.player != null and h.team == m.player.team

## A text row's bar: your side's colour when the line starts with one of your squad's names.
static func _line_colour(m: Match, s: String) -> Color:
	for h: Hunter in m.hunters:
		if _mine(m, h) and s.begins_with(h.pname):
			return SideColor.of(m, h)
	return HudStyle.GOLD

static func _w(H, s: String) -> float:
	return TextCache.width(H.big, s, NAME_PX)

## `s` cut to NAME_W with an ellipsis, kept once worked out (names repeat row after row).
static func _fit(font: Font, s: String) -> String:
	if not _fitted.has(s):
		var cut := s
		if _raw(font, s) > NAME_W:
			while cut.length() > 1 and _raw(font, cut + ELLIPSIS) > NAME_W:
				cut = cut.left(-1)
			cut += ELLIPSIS
		_fitted[s] = cut
	return _fitted[s]

## `s` measured once, uncached (only _fit's trimming: TextCache keeps what is drawn).
static func _raw(font: Font, s: String) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX).x
