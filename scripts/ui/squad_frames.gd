class_name SquadFrames
extends RefCounted
## Your squad down the left edge, one row per Hunter, you last (team modes only; nothing in solo).
## A row: a round portrait with the run level on its lower-left, a state label over the name, and a thin
## armour bar over the health bar in one slanted frame. Knocked: a red label, the portrait tinted red,
## the bleed-out in the health row, and a marker beside the row whose tail points at them (their world
## ping is DownedMarks.ally_ping). Dead: the portrait greyed and cracked, no bars.
## Every size here is measured off the reference capture (scripts/ui/SQUAD_FRAMES_SPEC.md), in HUD
## units (the HUD is laid out at 1280x720 and scaled: 1 unit = 1.5 px at 1920x1080).

const FIRST_DROP := 39.0       # units from the minimap's bottom to the first row's portrait centre
const PITCH := 46.0            # units between rows
const X := 35.0                # units: the portrait centre's distance from the left edge
const R := 13.2                # units: portrait radius
const LABEL_X := 17.5          # units right of the portrait centre: label, name and bar start
const LABEL_Y := -6.6          # units: the state label's baseline, from the portrait centre
const NAME_Y := 3.4            # units: the name's baseline
const LABEL_PX := 10           # font px: the state label (condensed, leaning)
const NAME_PX := 8             # font px: the name (the body sans, semibold, like the ref's plain name face)
const LVL_PX := 11             # font px: the level number
const BAR_Y := 6.6             # units: the bar frame's top, from the portrait centre
const BAR_W := 43.6            # units: the frame's width along its top
const BAR_H := 9.2             # units: the frame's height
const BAR_SKEW := 4.6          # units: how far the frame's bottom edge sits left of its top
const ARMOR_H := 2.3           # units: the armour row
const HP_H := 3.5              # units: the health row (1.1 under the armour row)
const LEAN := -0.22            # the label's lean (x shear per unit up)
const CONDENSE := 0.82         # the label's width squeeze
const MARK_DX := 106.0         # units from the portrait centre to the knocked marker's centre
const MARK_R := 13.0           # units: the marker's round body (its tail reaches 2x further)
const FRAME := Color(0.01, 0.0, 0.02, 0.92)
const NAME_COL := Color("eef4f2")
const HP_COL := Color("f2ef10")      # health (yours and theirs)
const ARMOR_COL := Color("2d71d5")
const BLEED_COL := Color("23a5f4")   # a knocked Hunter's bleed-out, in the health row
const KNOCK_COL := Color("ff6fb4")   # the KNOCKED label
const DEAD_COL := Color("bbc0c6")
const TINT_KNOCK := Color(0.95, 0.2, 0.32, 0.5)
const TINT_DEAD := Color(0.82, 0.82, 0.85, 0.6)    # the dead portrait goes light grey, not dark
const SHADE := Color(0, 0, 0, 0.38)              # each bar's lower half, darker: the ref's two-tone fill
const MARK_FILL := Color("e2faeb")
const MARK_X := Color("e84b5b")
const PORTRAIT_PX := 64        # px: the round portrait's texture cut

## nid -> {"state", "row", "hp", "armor", "bleed"}: what the last draw showed (checks read it)
static var shown := {}
## nid -> the level number on that row
static var levels := {}
static var _ring := PackedVector2Array()
static var name_font := _semibold()   # the name's face
static var _uv := PackedVector2Array()

## The body sans at weight 600.
static func _semibold() -> FontVariation:
	var f := FontVariation.new()
	f.base_font = HudStyle.BODY
	f.variation_opentype = UI.weight(600)
	return f

## The rows, in draw order: your teammates, then you. Empty when you have no teammate.
static func rows(m: Match, p: Hunter) -> Array:
	var out: Array = m.hunters.filter(func(h): return h != p and h.team == p.team)
	if out.is_empty():
		return out
	out.append(p)
	return out

## The centre of row `i`'s portrait.
static func centre(hud, i: int) -> Vector2:
	return Vector2(X, float(hud.mm_bottom) + FIRST_DROP + PITCH * i)

static func draw(hud, sz: Vector2, p: Hunter) -> void:
	shown.clear()
	levels.clear()
	var all := rows(hud.m, p)
	for i in all.size():
		_row(hud, centre(hud, i), all[i], i)
	hud._draw_squad_markers(sz, p)

static func _row(hud, at: Vector2, h: Hunter, i: int) -> void:
	var c: CanvasItem = hud.c
	var m: Match = hud.m
	var st := "WISP" if h.downed else "ALIVE"
	if h != m.player:
		st = String(hud._mate_state(h)[0])
	var dead := st in ["DEAD", "DEATHBOX"]
	_portrait(hud, at, h, st)
	var rec := {"state": st, "row": i, "hp": 0.0, "armor": 0.0, "bleed": 0.0}
	if not dead and st != "EXTRACTED":
		levels[h.nid] = h.lvl
	HudStyle.text(c, at + Vector2(-R + 1.0, R - 0.5), str(h.lvl), LVL_PX,
		HudStyle.GOLD if h.lvl >= int(Hunter.ULT_AT[0]) else Color.WHITE, 3)
	var tx := at.x + LABEL_X
	var lbl := _label(m, h, st)
	if lbl[0] != "":
		_lean_text(c, Vector2(tx, at.y + LABEL_Y), String(lbl[0]), lbl[1])
	HudStyle.text(c, Vector2(tx, at.y + NAME_Y), h.pname.substr(0, 13), NAME_PX,
		NAME_COL if not dead else Color(NAME_COL, 0.75), 2, name_font)
	var top := Vector2(tx + BAR_SKEW, at.y + BAR_Y)
	match st:
		"ALIVE":
			rec["hp"] = clampf(h.hp / maxf(1.0, h.max_hp), 0.0, 1.0)
			rec["armor"] = clampf(h.armor / h.max_armor, 0.0, 1.0) if h.max_armor > 0.5 else 0.0
			_bars(c, top, rec["armor"], rec["hp"], HP_COL, hud._chip_of(h, rec["hp"]))
		"WISP":
			rec["bleed"] = DownedMarks.bleed_frac(h)
			var stp: bool = h.get_meta("stomped", false)
			var col := BLEED_COL.lerp(Color.WHITE, 0.5 + 0.5 * sin(m.time * 10.0)) if stp else BLEED_COL
			_bars(c, top, 0.0, rec["bleed"], col, 0.0)
			if h != m.player:
				_marker(hud, at + Vector2(MARK_DX, 0.0), h)
	hud.mates.draw_row(hud, Rect2(at - Vector2(R, R), Vector2(MARK_DX + MARK_R, 2.0 * R)), h)
	shown[h.nid] = rec

## The word over the name and its colour: KNOCKED, DEAD (with the time left to bring them back from
## their deathbox), EXTRACTED, or who leads the drop on the way in.
static func _label(m: Match, h: Hunter, st: String) -> Array:
	match st:
		"WISP":
			return ["KNOCKED", KNOCK_COL]
		"DEATHBOX":
			var b: Dictionary = Life.box_of(m, h)
			var left := maxf(0.0, float(b.get("soul_until", 0.0)) - m.time)
			return ["DEAD  %d:%02d" % [int(left) / 60, int(left) % 60], DEAD_COL]
		"DEAD":
			return ["DEAD", DEAD_COL]
		"EXTRACTED":
			return ["EXTRACTED", Color("8fe3c8")]
	if m.skydrop and (h.riding or h.dropping):
		if m.skydrop.is_lead(h):
			return ["LEAD", HudStyle.GOLD]
		if h.drop_solo:
			return ["SOLO", Color("8fd8ff")]
	return ["", Color.WHITE]

## Condensed, leaning text (the state label).
static func _lean_text(c: CanvasItem, at: Vector2, s: String, col: Color) -> void:
	c.draw_set_transform_matrix(Transform2D(Vector2(CONDENSE, 0.0), Vector2(LEAN, 1.0), at))
	HudStyle.text(c, Vector2.ZERO, s, LABEL_PX, col, 3)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## The slanted frame with the armour row over the health row; `top` is the frame's top-left corner.
static func _bars(c: CanvasItem, top: Vector2, armor: float, hp: float, col: Color, chip: float) -> void:
	_slant(c, top, BAR_W, BAR_H, FRAME)
	var inner := BAR_W - 2.5
	var ay := top.y + 1.1
	var hy := ay + ARMOR_H + 1.1
	var k := BAR_SKEW / BAR_H     # x shift per unit down
	if armor > 0.0:
		_fill(c, Vector2(top.x + 1.0 - k * 1.1, ay), inner * armor, ARMOR_H, ARMOR_COL)
	var hx := top.x + 1.0 - k * (hy - top.y)
	if chip > hp:
		_slant(c, Vector2(hx, hy), inner * chip, HP_H, HudStyle.CHIP)
	if hp > 0.0:
		_fill(c, Vector2(hx, hy), inner * hp, HP_H, col)

## A bar's fill: the colour, with its lower half shaded darker.
static func _fill(c: CanvasItem, at: Vector2, w: float, h: float, col: Color) -> void:
	_slant(c, at, w, h, col)
	var half := h * 0.5
	_slant(c, at + Vector2(-BAR_SKEW * half / BAR_H, half), w, half, SHADE)

## A parallelogram `w` wide and `h` tall whose top-left is `at`, leaning like the frame.
static func _slant(c: CanvasItem, at: Vector2, w: float, h: float, col: Color) -> void:
	var d := BAR_SKEW * h / BAR_H
	var quad := PackedVector2Array([at, at + Vector2(w, 0), at + Vector2(w - d, h), at + Vector2(-d, h)])
	c.draw_colored_polygon(quad, col)

## The round portrait: alive as it is, knocked tinted red, dead gone light grey under a white burst.
static func _portrait(hud, at: Vector2, h: Hunter, st: String) -> void:
	var c: CanvasItem = hud.c
	var dead := st in ["DEAD", "DEATHBOX"]
	c.draw_circle(at, R + 1.5, HudStyle.SHADE_EDGE)
	var pts := disc(c, at, R, face(hud, h, dead), SideColor.of(hud.m, h).darkened(0.4))
	if st == "WISP":
		c.draw_colored_polygon(pts, TINT_KNOCK)
	elif dead:
		c.draw_colored_polygon(pts, TINT_DEAD)
		_burst(c, at)
	c.draw_arc(at, R + 0.5, 0.0, TAU, 32, Color(0, 0, 0, 0.75), 1.2, true)

## The dead portrait's white burst: four soft rays on the diagonals, past the rim, a dark crack between.
static func _burst(c: CanvasItem, at: Vector2) -> void:
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var d := Vector2.from_angle(a)
		var side := d.orthogonal()
		var tip := at + d * R * 1.3
		c.draw_colored_polygon(PackedVector2Array([at + side * 4.5, tip, at - side * 4.5]), Color(1, 1, 1, 0.4))
		c.draw_colored_polygon(PackedVector2Array([at + side * 1.4, tip, at - side * 1.4]), Color(1, 1, 1, 0.95))
	var crack := Color(0.1, 0.1, 0.12, 0.8)
	c.draw_line(at + Vector2(-R * 0.7, -R * 0.75), at + Vector2(R * 0.6, R * 0.8), crack, 1.2, true)

## A face cut to a disc of radius `r` at `at` (`blank` where there is no texture); returns the disc's outline
## for tints over it.
static func disc(c: CanvasItem, at: Vector2, r: float, tex: Texture2D, blank: Color,
		mod := Color.WHITE) -> PackedVector2Array:
	if _ring.is_empty():
		for i in 28:
			var v := Vector2.from_angle(TAU * i / 28.0)
			_ring.append(v)
			_uv.append(Vector2(0.5, 0.5) + v * 0.5)
	var pts := PackedVector2Array()
	for v in _ring:
		pts.append(at + v * r)
	if tex != null:
		c.draw_colored_polygon(pts, mod, _uv, tex)
	else:
		c.draw_colored_polygon(pts, Color(blank, mod.a))
	return pts

## The face texture: the Warden's painted art cut square, or the rendered model; greyed for the dead.
static func face(hud, h: Hunter, grey: bool) -> Texture2D:
	var ak := Portraits.arch_of(h)
	if Portraits.has_art(ak):
		return Portraits.cut(ak, Portraits.art_path(ak), Vector2i(PORTRAIT_PX, PORTRAIT_PX), grey)
	return hud.portrait_grey(h) if grey else hud.portrait(h)

## Beside a knocked teammate's row: a pale burst with a red X, its long point toward where they lie.
static func _marker(hud, at: Vector2, h: Hunter) -> void:
	var c: CanvasItem = hud.c
	var cam: Camera3D = hud.m.cam
	var to := Vector2.LEFT
	if not cam.is_position_behind(h.pos):
		to = (cam.unproject_position(h.pos) - at).normalized()
	for a: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := to.rotated(a)
		var lead := a == 0.0                         # the long point leads to the ally; the rest are short
		var side := d.orthogonal() * MARK_R * (0.55 if lead else 0.3)
		var reach := 2.0 if lead else 1.3
		c.draw_colored_polygon(PackedVector2Array([at + side, at + d * MARK_R * reach, at - side]), MARK_FILL)
	c.draw_circle(at, MARK_R, MARK_FILL)
	for a in [PI * 0.25, PI * 0.75]:
		var v := Vector2.from_angle(a) * MARK_R * 0.62
		c.draw_line(at - v, at + v, MARK_X, 2.6, true)
