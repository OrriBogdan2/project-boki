class_name KnockFeed
extends RefCounted
## The kill feed (Match.feed), in its own lane at the top right under the counters. A knock reads at a glance:
## the knocker's face, the icon of the ability that landed it, the knocked Hunter's face, names beside them,
## each side ending in its squad's colour bar, and the row outlined in your side's colour when your squad is in
## it. Any other line (someone got out, a squad is gone) stays a text plate. At most ROWS rows, each fully
## shown HOLD_S then faded over FADE_S, none wider than LANE_W so the lane keeps clear of the message lane.

const ROWS := 4                # rows on show at most (a new one pushes the oldest out)
const HOLD_S := 5.0            # s a row is fully shown
const FADE_S := 0.5            # s it then takes to fade out
const LIFE_S := HOLD_S + FADE_S
const LANE_W := 300.0          # px: the widest row (on a 1240 px screen the widest message card ends at 911)
const RIGHT := 18.0            # px from the screen's right edge, lined up with the counters above
const GAP := 4.0               # px between rows
const KNOCK_H := 30.0          # px: a knock row's height
const TEXT_H := 24.0           # px: a one-line text row's height
const TEXT_BASE := 17.0        # px from a text row's top to its first baseline
const BASELINE := 5.0          # px below a knock row's middle where its names sit
const NAME_PX := 13            # font px for names and lines
const NAME_W := 84.0           # px: a longer name is cut with an ellipsis (two of them fit LANE_W)
const FACE := 24.0             # px: a face's side
const ICON_W := 24.0           # px: the icon's cell between the faces
const ICON_S := 8.5            # Icons.draw size of that icon
const SEP := 6.0               # px between a name, a face and the icon
const EDGE := 14.0             # px from a plate's end to its content: the bar's inset, the bar, padding
const BAR := 4.0               # px: a squad's colour bar
const BAR_IN := 2.0            # px from the plate's end to its bar
const TEXT_PAD := 12.0         # px after a text row's line
const RADIUS := 6              # px: plate corners
const PLATE := Color(0.04, 0.05, 0.08, 0.82)
const MINE_FILL := Color(0.08, 0.1, 0.15, 0.9)     # a row your squad is in: a little lifted
const FALLBACK_ICON := "knock"                      # nothing to credit (the Blight, a fall, a monster)
const ELLIPSIS := "…"
## A hit's "ab" (the slot that dealt it) -> the bar slot whose icon the row shows. Anything else (a plain shot
## or swing, a passive) shows the weapon's icon, as the weapon slot does.
const SLOT_OF := {"utility": "sec", "rmb": "sec", "k1": "k1", "e": "k1", "ult": "x", "ultimate": "x", "x": "x",
		"dodge": "dash"}

static var shown: Array[Dictionary] = []     # what the last draw put up, top to bottom (--knock-feed-check reads it)
static var _fitted := {}                     # name -> the name cut to NAME_W

## The icon of what landed a knock: the slot's icon on the knocker's own bar, the weapon's for a plain hit, the
## Boki's ability for a Boki's, else FALLBACK_ICON. `by` dealt the hit, `credit` is who the knock counts for.
static func icon_of(by: Ent, credit: Ent, o: Dictionary) -> String:
	var ab := String(o.get("ab", ""))
	if by is Kin:
		var k := by as Kin
		return KinText.icon(k.runner.def_of(ab)) if k.runner and ab in ["k1", "k2"] else "paw"
	if not credit is Hunter:
		return FALLBACK_ICON
	var h := credit as Hunter
	if SLOT_OF.has(ab):
		var icon := String(h.slot_info(SLOT_OF[ab]).get("icon", ""))
		if icon != "":
			return icon
	return h.wid if h.wid != "" else FALLBACK_ICON

## Puts a knock in the feed and the match log: `knocker` is the Hunter credited, null when nobody was.
static func add(m: Match, knocker: Hunter, who: Hunter, icon: String) -> void:
	m.add_feed(("%s knocked %s" % [knocker.pname, who.pname]) if knocker else "%s went down" % who.pname)
	m.feed.back().merge({"by": knocker, "who": who, "icon": icon if icon != "" else FALLBACK_ICON})

## Draws the feed down from Hud.feed_top at the screen's right edge, oldest on top.
static func draw(H, sz: Vector2) -> void:
	shown.clear()
	var y: float = H.feed_top
	var right := sz.x - RIGHT
	for f: Dictionary in H.m.feed:
		var a := snappedf(clampf((LIFE_S - float(f["t"])) / FADE_S, 0.0, 1.0), 0.125)
		var is_knock := is_instance_valid(f.get("who"))
		var row := _knock_row(H, f, right, y, a) if is_knock else _text_row(H, f, right, y, a)
		shown.append(row)
		y = (row["rect"] as Rect2).end.y + GAP

## A knock: [squad bar] the knocker's name and face, the icon, the knocked Hunter's face and name [squad bar].
## With nobody credited only the icon and the knocked side show.
static func _knock_row(H, f: Dictionary, right: float, y: float, a: float) -> Dictionary:
	var m: Match = H.m
	var who: Hunter = f["who"]
	var by: Hunter = f["by"] if is_instance_valid(f["by"]) else null
	var right_name := _fit(H.big, who.pname)
	var left_name := ""
	var left_w := 0.0
	if by:
		left_name = _fit(H.big, by.pname)
		left_w = TextCache.width(H.big, left_name, NAME_PX) + SEP * 2.0 + FACE
	var w := EDGE * 2.0 + left_w + ICON_W + SEP * 2.0 + FACE + TextCache.width(H.big, right_name, NAME_PX)
	var r := Rect2(right - w, y, w, KNOCK_H)
	var hl := Color.TRANSPARENT
	if _on_your_squad(m, by):
		hl = SideColor.of(m, by)
	elif _on_your_squad(m, who):
		hl = SideColor.of(m, who)
	_plate(H, r, a, hl)
	var mid := y + KNOCK_H * 0.5
	var x := r.position.x + EDGE
	if by:
		_bar(H, r.position.x + BAR_IN, r, _squad(by), a)
		x = _side(H, by, left_name, x, mid, a, true)
	Icons.draw(H.c, String(f["icon"]), Vector2(x + ICON_W * 0.5, mid), ICON_S, Color(HudStyle.INK, a))
	_side(H, who, right_name, x + ICON_W, mid, a, false)
	_bar(H, r.end.x - BAR_IN - BAR, r, _squad(who), a)
	return {"kind": "knock", "rect": r, "a": a, "left": left_name, "right": right_name, "icon": String(f["icon"]),
		"left_col": _squad(by) if by else Color.TRANSPARENT, "right_col": _squad(who), "mine": hl.a > 0.0}

## One side of a knock row from `x`: the name then the face (the knocker), or the face then the name (the
## knocked). Your squad's names wear your side's colour. Returns where the side ends.
static func _side(H, h: Hunter, label: String, x: float, mid: float, a: float, name_first: bool) -> float:
	var col := SideColor.of(H.m, h) if _on_your_squad(H.m, h) else HudStyle.INK
	var w := TextCache.width(H.big, label, NAME_PX)
	var face_x := x + w + SEP if name_first else x + SEP
	var text_x := x if name_first else x + SEP * 2.0 + FACE
	H._text(Vector2(text_x, mid + BASELINE), label, NAME_PX, Color(col, a), H.big)
	_face(H, Rect2(face_x, mid - FACE * 0.5, FACE, FACE), h, _squad(h), a)
	return x + w + SEP * 2.0 + FACE

## A face in a frame of its squad's colour, faded by `a`: the painted portrait once a worker has cut it to size
## (a Hunter's first knock never stalls a frame reading art), or the rendered model for one with no painting.
static func _face(H, r: Rect2, h: Hunter, edge: Color, a: float) -> void:
	var rad := Portraits.corner(r.size)
	var shade := Color(HudStyle.SHADE_EDGE, HudStyle.SHADE_EDGE.a * a)
	H.c.draw_style_box(HudStyle.box(shade, rad + 2, Color(edge, 0.9 * a), 2), r.grow(2.0))
	var ak := Portraits.arch_of(h)
	var path := Portraits.art_path(ak)
	var tex: Texture2D = H.portrait(h) if path == "" else Portraits.cut_soon(ak, path, Vector2i(r.size.round()))
	if tex:
		H.c.draw_texture_rect(tex, r, false, Color(1, 1, 1, a))

## Any other line: a plate with a bar in your side's colour when the line starts with one of your squad, else
## gold. A line too long for the lane wraps inside it.
static func _text_row(H, f: Dictionary, right: float, y: float, a: float) -> Dictionary:
	var s := String(f["text"])
	var room := LANE_W - EDGE - TEXT_PAD
	var wide := TextCache.width(H.big, s, NAME_PX)
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

## The row's plate. `hl` (your side's colour; transparent when your squad isn't in the row) outlines and lifts it.
static func _plate(H, r: Rect2, a: float, hl: Color) -> void:
	if hl.a > 0.0:
		H._rounded(r, Color(MINE_FILL, MINE_FILL.a * a), RADIUS, Color(hl, 0.9 * a), 2)
	else:
		H._rounded(r, Color(PLATE, PLATE.a * a), RADIUS)

## A colour bar at `x` down row `r`, inset from its rounded corners.
static func _bar(H, x: float, r: Rect2, col: Color, a: float) -> void:
	H.c.draw_rect(Rect2(x, r.position.y + BAR_IN * 2.0, BAR, r.size.y - BAR_IN * 4.0), Color(col, a))

## A squad's colour, the one the scoreboard shows beside its names.
static func _squad(h: Hunter) -> Color:
	return Data.TEAM_COLORS[h.team % Data.TEAM_COLORS.size()]

static func _on_your_squad(m: Match, h: Hunter) -> bool:
	return h != null and m.player != null and h.team == m.player.team

## A text row's bar: your side's colour when the line starts with one of your squad's names.
static func _line_colour(m: Match, s: String) -> Color:
	for h: Hunter in m.hunters:
		if _on_your_squad(m, h) and s.begins_with(h.pname):
			return SideColor.of(m, h)
	return HudStyle.GOLD

## `s` cut to NAME_W with an ellipsis, kept once worked out (names repeat row after row).
static func _fit(font: Font, s: String) -> String:
	if not _fitted.has(s):
		var cut := s
		if _width(font, s) > NAME_W:
			while cut.length() > 1 and _width(font, cut + ELLIPSIS) > NAME_W:
				cut = cut.left(-1)
			cut += ELLIPSIS
		_fitted[s] = cut
	return _fitted[s]

## `s` measured once, uncached (only _fit's trimming: TextCache keeps what is drawn).
static func _width(font: Font, s: String) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_PX).x
