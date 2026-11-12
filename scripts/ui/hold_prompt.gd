class_name HoldPrompt
extends RefCounted
## The one hold widget: a dark disc with the key glyph in it and a ring around it that fills while
## the key is held. Every "Hold F ..." prompt draws it (the match prompt bar, the home prompt row) and
## the glider shows it beside you for a tapped Space. A tap (HoldTeach) flashes the ring part-full and
## drains it, and pops a small "Hold" above it. docs/HUD.md "Hold prompts".

const R_MIN := 13.0  # px: the ring around a one-letter key
const R_PAD := 7.0  # px between a wide key's glyph ("Space") and the ring
const RING_W := 3.0  # px ring thickness
const KEY_FS := 14  # key glyph size
const TEXT_FS := 16  # words beside the ring (the prompt bar's size)
const GAP := 7.0  # px between the words and the ring
const POP_RISE := 18.0  # px the "Hold" pop rises over its life
const TRACK := Color(1, 1, 1, 0.18)  # the empty ring
const FLASH := Color("fff3c4")  # a tap's flash (warmer white than the fill)
const PANEL := Color(0.06, 0.07, 0.1, 0.72)  # the prompt bar's panel (Hud.PANEL)
const EDGE := Color(1, 1, 1, 0.08)


## Does this prompt ask for a hold? Every hold prompt starts "Hold <key> ...".
static func is_hold(label: String) -> bool:
	return label.begins_with("Hold ")


## The ring radius for a key glyph.
static func radius(key: String) -> float:
	return maxf(R_MIN, HudStyle.BIG.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, KEY_FS).x * 0.5 + R_PAD)


## The ring with `key` inside, filled to `fill` (0..1); `action` (HoldTeach) adds a tap's flash and pop.
static func ring(c: CanvasItem, at: Vector2, key: String, fill: float, action := "", col := HudStyle.GOLD) -> void:
	var r := radius(key)
	var fl := HoldTeach.flash(action) if action != "" else 0.0
	c.draw_circle(at, r, HudStyle.KEY_BG)
	c.draw_arc(at, r, 0.0, TAU, 48, TRACK, RING_W, true)
	var shown := maxf(clampf(fill, 0.0, 1.0), fl)
	if shown > 0.0:
		var rc := FLASH if fl > fill else col
		c.draw_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * shown, 48, rc, RING_W + 0.5, true)
	HudStyle.ctext(c, at + Vector2(0, KEY_FS * 0.36), key, KEY_FS, HudStyle.INK if shown < 1.0 else col, 3)
	var pe := HoldTeach.pop(action) if action != "" else -1.0
	if pe >= 0.0:
		var a := 1.0 - pe * pe
		HudStyle.ctext(c, at + Vector2(0, -r - 8.0 - POP_RISE * pe), "Hold", 14, Color(FLASH, a), 4)


## The match prompt bar for a hold label: "Hold [ring F] to open the chest", centred on `center`
## (the text baseline). False (and nothing drawn) when the label isn't a hold.
static func row(c: CanvasItem, center: Vector2, label: String, fill: float, col: Color, action := "hold") -> bool:
	if not is_hold(label):
		return false
	var parts := label.split(" ", true, 2)
	var key: String = parts[1] if parts.size() > 1 else "?"
	var rest: String = parts[2] if parts.size() > 2 else ""
	var f := HudStyle.BODY
	var hw := f.get_string_size("Hold", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FS).x
	var rw := f.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_FS).x
	var r := radius(key)
	var w := hw + GAP + r * 2.0 + (GAP + rw if rest != "" else 0.0)
	var x := center.x - w * 0.5
	var h := maxf(32.0, r * 2.0 + 8.0)
	var mid_y := center.y - 6.0  # the text's visual middle, a little above its baseline
	c.draw_style_box(HudStyle.box(PANEL, 10, EDGE, 1), Rect2(Vector2(x - 16, mid_y - h * 0.5), Vector2(w + 32, h)))
	HudStyle.text(c, Vector2(x, center.y), "Hold", TEXT_FS, col, 3, f)
	ring(c, Vector2(x + hw + GAP + r, mid_y), key, fill, action, col)
	if rest != "":
		HudStyle.text(c, Vector2(x + hw + GAP * 2.0 + r * 2.0, center.y), rest, TEXT_FS, col, 3, f)
	return true


## A tapped Space in the air: the ring and its "Hold" pop beside you for a moment (hud, every frame).
static func air_tap(c: CanvasItem, cam: Camera3D, head: Vector3) -> void:
	if not HoldTeach.showing("glide") or cam == null or cam.is_position_behind(head):
		return
	ring(c, cam.unproject_position(head) + Vector2(-58, -6), HoldTeach.key_text("glide"), 0.0, "glide")


## UI.key_hints, with a ring in place of the plain caps for every pair whose key reads "Hold <key>".
## fill_fn(index) -> float gives that pair's ring fill; action_of(index) -> String its HoldTeach action.
static func key_hints(pairs: Array, size: int, col: Color, fill_fn: Callable, action_of: Callable) -> HBoxContainer:
	var row_box := UI.key_hints(pairs, size, col)
	for i in pairs.size():
		var k := String(pairs[i][0])
		if not is_hold(k):
			continue
		var one: HBoxContainer = row_box.get_child(i)
		for cap in one.get_children().slice(0, one.get_child_count() - 1):
			cap.free()
		var hold := UI.label("Hold", size + 4, col)
		hold.add_theme_font_override("font", UI.big)
		one.add_child(hold)
		one.move_child(hold, 0)
		var cap := Cap.new()
		cap.key = k.substr(5)
		cap.idx = i
		cap.fill_fn = fill_fn
		cap.action_of = action_of
		one.add_child(cap)
		one.move_child(cap, 1)
	return row_box


## The ring as a Control, for rows built from containers (the home prompt). Redraws every frame.
class Cap:
	extends Control
	var key := "F"
	var idx := 0
	var fill_fn: Callable
	var action_of: Callable

	func _ready() -> void:
		var r := HoldPrompt.radius(key)
		custom_minimum_size = Vector2(r * 2.0 + 4.0, r * 2.0 + 4.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f := float(fill_fn.call(idx)) if fill_fn.is_valid() else 0.0
		var a := String(action_of.call(idx)) if action_of.is_valid() else ""
		HoldPrompt.ring(self, size * 0.5, key, f, a)
