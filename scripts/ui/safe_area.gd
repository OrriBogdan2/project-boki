class_name SafeArea
extends RefCounted
## The screen's safe margin and the HUD's rect registry (--safe-area-check). The interface is laid out in
## logical pixels (Settings._apply_ui_scale keeps the window near 1240-1706 x 720-775 at every size), so one
## fixed margin is about 2% of the height everywhere. HUD panels are drawn each frame, so while a check
## records, each draw is tagged with a group (`begin`) and the rects drawn under that tag are merged (`note`).

const MARGIN := 12.0  # logical px kept clear on every side
const MAX_ASPECT := 16.0 / 9.0  # widest the HUD spreads: wider screens keep it in a centred frame this shape

const GAP := 8.0  # px kept between a popup and a reserved rect
const FPS_LINE := Vector2(96.0, 22.0)  # px: the one-line readout "123 fps" with its margin, top right
const FPS_KEY := "fps_counter"
const MINIMAP_KEY := "minimap"

static var recording := false
static var seen := {}  # group -> Array of the Rect2s that group drew
static var group := ""
static var origin := Vector2.ZERO  # the canvas being drawn: where it sits on screen (HudPanels), for screen-px rects


## The part of a screen of size `sz` the HUD and menus use: all of it up to MAX_ASPECT, a centred
## MAX_ASPECT frame on wider screens (21:9, 32:9), so no group sits out at the far edges.
static func frame(sz: Vector2) -> Rect2:
	var w := minf(sz.x, sz.y * MAX_ASPECT)
	return Rect2(Vector2((sz.x - w) * 0.5, 0.0), Vector2(w, sz.y))


static func inner(sz: Vector2) -> Rect2:
	return frame(sz).grow(-MARGIN)


## A Control under `parent` (one that fills the screen) kept on `parent`'s frame as the window resizes: a
## screen's corner groups go under it; things placed on the 3D world stay on `parent`.
static func framed(parent: Control) -> Control:
	var c := Control.new()
	c.name = "Frame"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var fit := func() -> void:
		var x := frame(parent.size).position.x
		c.offset_left = x
		c.offset_right = -x
	parent.resized.connect(fit)
	fit.call()
	return c


## The one list of screen rects no popup, panel or toast may cover (name -> Rect2, screen px): the frame-rate readout
## (its live rect while it shows, else the room of its one line) and the minimap, as large as the HUD size setting
## grows it. Every popup of a match is placed with `clear_of`, never with an offset of its own.
static func reserved(sz: Vector2) -> Dictionary:
	var fps: Control = Overlay.fps_lbl
	var room := Rect2(Vector2(sz.x - FPS_LINE.x - 8.0, 4.0), FPS_LINE)
	var out := {FPS_KEY: fps.get_global_rect() if fps.visible and fps.size.x > 0.0 else room}
	var box := inner(sz)
	var map := HudStyle.minimap_rect(sz)
	var grown := Rect2(box.position + (map.position - box.position) * HudScale.up(), map.size * HudScale.up())
	out[MINIMAP_KEY] = grown
	return out


## `r` moved the shortest way (right, left, below or above a reserved rect) that keeps it inside the margin and off
## every reserved rect; `r` itself when it is clear already or nowhere fits.
static func clear_of(r: Rect2, sz: Vector2) -> Rect2:
	var boxes: Array = []
	for b: Rect2 in reserved(sz).values():
		boxes.append(b.grow(GAP))
	var best := r
	var best_d := INF
	var field := inner(sz)
	for b: Rect2 in boxes:
		if not b.intersects(r):
			continue
		for at: Vector2 in [
			Vector2(b.end.x, r.position.y),
			Vector2(b.position.x - r.size.x, r.position.y),
			Vector2(r.position.x, b.end.y),
			Vector2(r.position.x, b.position.y - r.size.y)
		]:
			var moved := Rect2(at, r.size)
			var d := at.distance_to(r.position)
			if d < best_d and field.encloses(moved) and not boxes.any(func(o: Rect2): return o.intersects(moved)):
				best = moved
				best_d = d
	return best


## Puts `c` (a popup, at least as big as its content) at `want`, moved off every reserved rect (clear_of).
static func place(c: Control, want: Vector2, sz: Vector2) -> void:
	c.position = clear_of(Rect2(want, c.size.max(c.get_combined_minimum_size())), sz).position


## `r` moved the least that puts it inside the margin (anchoring a panel to the corner it hangs from).
static func keep(r: Rect2, sz: Vector2) -> Rect2:
	var box := inner(sz)
	r.position = r.position.clamp(box.position, box.end - r.size)
	return r


static func begin(group_name: String) -> void:
	group = group_name


static func note(r: Rect2) -> void:
	if group != "":
		HudScale.grow(r)
	_record(group, r)


## `r` under a group of its own: for widgets drawn outside the panel pass (the Ways Out strip, markers, prompts).
## It is recorded where it ends up: under the HUD size scale of the group being drawn (none outside the panel pass).
## The camera's lean keeps clear of it too (HudScale.drawn).
static func note_as(group_name: String, r: Rect2) -> void:
	HudScale.overlay(group_name, r)
	_record(group_name, r)


static func _record(group_name: String, r: Rect2) -> void:
	if recording and group_name != "":
		if not seen.has(group_name):
			seen[group_name] = []
		var on_screen := HudScale.xf * r
		on_screen.position += origin
		seen[group_name].append(on_screen)


## The groups (name -> Array of Rect2) found under `root`: its visible controls, looking inside any that fill the
## screen or its frame (a full-rect backdrop or container, `framed`) for the real ones.
static func groups_of(root: Node, sz: Vector2) -> Dictionary:
	var out := {}
	_collect(root, sz, out)
	return out


static func _collect(node: Node, sz: Vector2, out: Dictionary) -> void:
	for ch in node.get_children():
		var c := ch as Control
		if c == null or not c.visible or c.size.x <= 0.0 or c.size.y <= 0.0:
			continue
		var r := c.get_global_rect()
		if c is CenterContainer or (r.size.x >= frame(sz).size.x * 0.9 and r.size.y >= sz.y * 0.9):
			_collect(c, sz, out)
		else:
			out["%s#%d" % [_label(c), out.size()]] = [r]


## A readable name for a control: its own, or the first text under it (generated names are "@Class@12").
static func _label(c: Control) -> String:
	if not String(c.name).begins_with("@"):
		return c.name
	for l in c.find_children("*", "Label", true, false):
		if (l as Label).text != "":
			return "%s '%s'" % [c.get_class(), (l as Label).text.left(24)]
	return c.get_class()


## Problems with `groups` on a screen of size `sz`: "<name> outside <rect>" or "<a> overlaps <b>".
static func problems(groups: Dictionary, sz: Vector2) -> Array:
	var bad: Array = []
	var safe := inner(sz).grow(0.5)
	var names: Array = groups.keys()
	for i in names.size():
		for r: Rect2 in groups[names[i]]:
			if not safe.encloses(r):
				bad.append("%s outside %s" % [names[i], r])
			for j in range(i + 1, names.size()):
				for o: Rect2 in groups[names[j]]:
					if r.intersects(o):
						bad.append("%s %s overlaps %s %s" % [names[i], r, names[j], o])
	return bad


## Text cut off under `root`: a label or button that is narrower than its text and neither wraps nor
## elides, or a wrapped label with lines that don't show. The fix is wrapping or eliding, never a smaller font.
static func clipped(root: Node) -> Array:
	var bad: Array = []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x <= 0.0:
			continue
		if c is Label:
			var l := c as Label
			var plain := l.autowrap_mode == TextServer.AUTOWRAP_OFF
			plain = plain and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING
			if plain and wider(l, l.text, l.size.x):
				bad.append("clipped '%s'" % l.text.left(24))
			elif l.get_line_count() > l.get_visible_line_count():
				bad.append("hidden lines '%s'" % l.text.left(24))
		elif c is Button:
			var b := c as Button
			var room := b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
			if b.clip_text and b.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and wider(b, b.text, room):
				bad.append("clipped '%s'" % b.text.left(24))
	return bad


static func wider(c: Control, s: String, room: float) -> bool:
	var font := c.get_theme_font("font")
	var w := 0.0
	for line in s.split("\n"):  # (a plain label with line breaks is as wide as its longest line)
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x)
	return w > room + 1.0
