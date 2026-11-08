class_name Reticle
extends RefCounted
## The aiming reticle at the cursor, in the player's own style (Settings > Gameplay > Reticle): shape,
## size, colour, opacity and a dark outline. The default is a small thin ring broken into four arcs with a
## centre dot; the ring opens with weapon bloom, and on a hit it flashes. With the "hunter" colour (the
## default) the ring stays pale and the dot and the aim arcs take the Hunter's own accent (Arch.reticle_color).
## ReticleHud draws it first each frame; the aim states (ammo ring, charge arcs, hit marker and the AimKit
## cursor states on their own layer) draw on top of it. Every number is in content/rules/tuning.json "reticle".

## Shape id -> its name in Settings.
const SHAPES := [
	["default", "Default"], ["dot", "Dot"], ["circle", "Small circle"], ["cross", "Cross"],
	["circle_dot", "Circle and dot"],
]
## Colour id -> [its name in Settings, the colour]. "hunter" is a pale ring with the Hunter's accent on the dot
## and arcs (draw's `accent`); "yellow" is the high-visibility one.
const COLORS := {
	"hunter": ["Hunter colour", Color("f4f1e6")],
	"white": ["White", Color("f4f1e6")],
	"yellow": ["High-vis yellow", Color("e4ff1f")],
	"cyan": ["Cyan", Color("4fe3ff")],
	"pink": ["Pink", Color("ff5cd1")],
	"green": ["Green", Color("63ff7f")],
	"red": ["Red", Color("ff4a3d")],
}
const TUNING_PATH := "res://content/rules/tuning.json"
static var _tune: Dictionary = {}

## The reticle's numbers (tuning.json "reticle"), read once.
static func tune() -> Dictionary:
	if _tune.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
		_tune = (parsed as Dictionary).get("reticle", {}) if typeof(parsed) == TYPE_DICTIONARY else {}
	return _tune

## One tuning number.
static func t(key: String) -> float:
	return float(tune()[key])

## One tuning colour (a hex string).
static func tc(key: String) -> Color:
	return Color(String(tune()[key]))

## The accent for the dot and the aim arcs of a Hunter: its own colour for the "hunter" setting, else the chosen colour.
static func accent(arch_id: String) -> Color:
	if Settings.get_v("reticle_col") == "hunter":
		return Arch.reticle_color(arch_id)
	return (style()["col"] as Color)

## The swatch colour of a colour id in Settings; "hunter" shows the colour of the Hunter you play.
static func swatch(id: String) -> Color:
	return Arch.reticle_color(String(Save.d.get("arch", ""))) if id == "hunter" else COLORS[id][1]

## The style in effect: {shape, k (size factor), col (with the opacity), outline, hunter (the accent colour mode)}.
static func style() -> Dictionary:
	var col_id := String(Settings.get_v("reticle_col"))
	var col: Color = (COLORS.get(col_id, COLORS["white"]) as Array)[1]
	col.a = clampf(float(Settings.get_v("reticle_alpha")), 0.1, 1.0)
	return {
		"shape": String(Settings.get_v("reticle_shape")),
		"k": clampf(float(Settings.get_v("reticle_size")), 0.5, 2.0),
		"col": col,
		"outline": bool(Settings.get_v("reticle_outline")),
		"hunter": col_id == "hunter",
	}

## Draws the reticle at `at` on `c`. `spread` (px) opens the ring or cross with weapon bloom; `accent` is the
## Hunter's colour (used when the colour setting is "hunter"); `flash` (alpha = strength) tints the ring on a hit.
static func draw(c: CanvasItem, at: Vector2, spread := 0.0, accent := Color.WHITE, flash := Color(0, 0, 0, 0)) -> void:
	var st := style()
	var k := float(st["k"])
	var col: Color = st["col"]
	var dot_col := Color(accent, col.a) if st["hunter"] else col
	var shape := String(st["shape"])
	var ring := t("ring_r") * k + minf(spread, t("spread_max"))
	var has_dot := shape in ["default", "dot", "circle_dot"]
	var dot := t("dot_r") * k * (1.6 if shape == "dot" else 1.0)
	var line_w := t("line_w") * k
	if bool(st["outline"]):
		var edge := Color(0, 0, 0, t("edge_a") * col.a)
		_shape(c, at, shape, ring, k, edge, line_w + t("edge_w") * 2.0)
		if has_dot:
			c.draw_circle(at, dot + t("edge_w"), edge)
	_shape(c, at, shape, ring, k, col.lerp(Color(flash, col.a), flash.a), line_w)
	if has_dot:
		c.draw_circle(at, dot * (1.0 + flash.a * 0.6), dot_col)

## The strokes of a shape (no dot): a broken ring, a full ring or a cross.
static func _shape(c: CanvasItem, at: Vector2, shape: String, ring: float, k: float, col: Color, width: float) -> void:
	match shape:
		"default":
			var gap := t("arc_gap_rad")
			for i in 4:
				var a0 := PI * 0.5 * i + gap * 0.5
				c.draw_arc(at, ring, a0, a0 + PI * 0.5 - gap, 8, col, width, true)
		"circle", "circle_dot":
			c.draw_arc(at, ring, 0.0, TAU, 28, col, width, true)
		"cross":
			var open := t("cross_gap") * k + (ring - t("ring_r") * k)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
				c.draw_line(at + d * open, at + d * (open + t("cross_len") * k), col, width, true)
