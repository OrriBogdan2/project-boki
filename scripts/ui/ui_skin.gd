class_name UiSkin
extends RefCounted
## The field-kit identity's pieces beyond the Theme: which section a panel belongs to (its colour
## and emblem), the tab icons, the brass-rimmed emblem, the section eyebrow's ornament, stat
## numbers, and the WCAG contrast sum --uipolish-check runs over the colour tokens.
## docs/UI_DESIGN.md has the rules.

## Section colours: each family of panels wears one on its emblem, its picked tab and the light
## along its top, so you know where you are at a glance. All read on the leather at AA.
const EXPEDITION := Color("7fdcc4")
const KIN := Color("ffa3c0")
const GEAR := Color("94bcff")
const MARKET := Color("f5cd55")
const FARM := Color("aedc6e")
const SYSTEM := Color("c7b0ff")

## [colour, emblem icon, words in the title that put a panel in this section]. First match wins;
## anything unmatched is SYSTEM with the compass.
const SECTIONS := [
	[SYSTEM, "gear", ["Settings"]],
	[GEAR, "shield", ["Armory", "Try-on", "kit", "Kit", "Hero", "Glider", "Sparring"]],
	[MARKET, "coin", ["Market", "Exchange", "Guild", "Job Board", "Trophy", "Challenge"]],
	[EXPEDITION, "portal", ["Expedition", "Ferry", "Islands", "Bridge", "Notice", "online", "match", "Spawn"]],
	[KIN, "paw", ["Boki", "Kin", "Feed", "Train", "Dress", "Nesting", "hatched", "Burrow", "Pens", "gift",
		"Ransom", "Graveyard", "Shrine", "Cooking", "Field Book", "hungry"]],
	[FARM, "sprout", ["Grow", "Build", "Plant", "house", "home", "away", "Gramophone", "Music"]],
]

## Icons on tabs, by tab name (the name before any count).
const TAB_ICONS := {
	"Gameplay": "compass", "Controls": "pad", "Camera": "camera", "Audio": "speaker", "Video": "monitor",
	"Accessibility": "access", "Demo": "film",
	"Armor": "shield", "Boots": "boot", "Gloves": "glove", "Kits": "kit", "Treasure": "chest",
	"Seeds": "seed", "Kin food": "bowl", "Wear": "hat", "Home": "home", "Farm": "sprout", "Sell": "coin",
	"Boki": "paw", "Exchange": "swap",
}

## {"col", "icon"} for a panel titled `title_txt`.
static func section_of(title_txt: String) -> Dictionary:
	for sec in SECTIONS:
		for word in sec[2]:
			if title_txt.contains(String(word)):
				return {"col": sec[0], "icon": sec[1]}
	return {"col": SYSTEM, "icon": "compass"}

## The icon for a tab (by its bare name), or "".
static func tab_icon(tab_name: String) -> String:
	return String(TAB_ICONS.get(tab_name, ""))

## A brass-rimmed medallion with an icon: a panel's section emblem and the confirm box's badge.
static func emblem(icon: String, col: Color, px := 40.0) -> Control:
	var e := Emblem.new()
	e.icon = icon
	e.col = col
	e.custom_minimum_size = Vector2(px, px)
	e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e

## Draws the eyebrow's ornament on a section label: a brass diamond before the words and a hairline
## after them to the end of the row.
static func ornament(l: Label, col: Color) -> void:
	var gap := StyleBoxEmpty.new()
	gap.content_margin_left = 16.0
	l.add_theme_stylebox_override("normal", gap)
	l.draw.connect(func():
		var mid := l.size.y * 0.5
		var d := PackedVector2Array([Vector2(5, mid - 4), Vector2(9, mid), Vector2(5, mid + 4), Vector2(1, mid)])
		l.draw_colored_polygon(d, UI.BRASS)
		var f := l.get_theme_font("font")
		var tw := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		var x := 16.0 + tw + 10.0
		if x < l.size.x:
			l.draw_line(Vector2(x, mid + 1.0), Vector2(l.size.x, mid + 1.0), Color(col, 0.22), 1.0))

## A stitched rule across a panel under its header: a groove with a row of stitches in it.
static func seam_rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 6.0
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var y := 3.0
		c.draw_line(Vector2(0, y + 1.5), Vector2(c.size.x, y + 1.5), Color(1, 0.9, 0.75, 0.05), 1.0)
		c.draw_line(Vector2(0, y - 0.5), Vector2(c.size.x, y - 0.5), Color(0.03, 0.01, 0.0, 0.35), 1.0)
		var x := 2.0
		while x + UiFrame.DASH < c.size.x:
			c.draw_line(Vector2(x, y), Vector2(x + UiFrame.DASH, y), UI.STITCH, 1.6, true)
			x += UiFrame.DASH + UiFrame.GAP)
	return c

## A big stat number (Lilita, tabular) over a small caps name, for results and counters.
static func stat(value_txt: String, what: String, icon := "", col := UI.INK) -> VBoxContainer:
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var num := UI.label(value_txt, UI.T_STAT, col, UI.big)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_constant_override("outline_size", 6)
	num.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.0, 0.5))
	v.add_child(num)
	var row := UI.hbox(5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if icon != "":
		row.add_child(UI.IconDot.new(icon, UI.BRASS, 13.0))
	row.add_child(UI.label(what.to_upper(), UI.T_CAPS, UI.MUTED, UI.caps))
	v.add_child(row)
	return v

## WCAG contrast ratio of `fg` (alpha blended over `bg`) against opaque `bg`.
static func contrast(fg: Color, bg: Color) -> float:
	var solid := Color(bg.r, bg.g, bg.b).lerp(Color(fg.r, fg.g, fg.b), fg.a)
	var a := _lum(solid)
	var b := _lum(Color(bg.r, bg.g, bg.b))
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

static func _lum(c: Color) -> float:
	var ch := func(x: float) -> float: return x / 12.92 if x <= 0.03928 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)

## The medallion: a soft shadow, a brass ring with a lit top edge, a deep disc in the section
## colour with light falling across it, and the icon.
class Emblem extends Control:
	var icon := ""
	var col := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c + Vector2(0, 1.6), r + 0.6, Color(0.03, 0.01, 0.0, 0.5))
		draw_circle(c, r, UI.BRASS.darkened(0.45))
		draw_circle(c, r - 1.2, UI.BRASS)
		draw_arc(c, r - 1.6, PI * 1.1, PI * 1.9, 16, UI.BRASS_HI, 1.4, true)
		draw_circle(c, r - 3.6, col.darkened(0.62))
		draw_circle(c - Vector2(0, r * 0.18), r - 5.4, Color(col.darkened(0.45), 0.9))
		UI.draw_icon(self, icon, c, r * 0.5, col.lightened(0.12))
