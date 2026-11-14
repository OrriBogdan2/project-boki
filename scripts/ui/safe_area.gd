class_name SafeArea
extends RefCounted
## The screen's safe margin and the HUD's rect registry (--safe-area-check). The interface is laid out in
## logical pixels (Settings._apply_ui_scale keeps the window near 1240-1706 x 720-775 at every size), so one
## fixed margin is about 2% of the height everywhere. HUD panels are drawn each frame, so while a check
## records, each draw is tagged with a group (`begin`) and the rects drawn under that tag are merged (`note`).

const MARGIN := 12.0      # logical px kept clear on every side

static var recording := false
static var seen := {}      # group -> Array of the Rect2s that group drew
static var group := ""

static func inner(sz: Vector2) -> Rect2:
	return Rect2(Vector2(MARGIN, MARGIN), sz - Vector2(MARGIN, MARGIN) * 2.0)

## `r` moved the least that puts it inside the margin (anchoring a panel to the corner it hangs from).
static func keep(r: Rect2, sz: Vector2) -> Rect2:
	var box := inner(sz)
	r.position = r.position.clamp(box.position, box.end - r.size)
	return r

static func begin(group_name: String) -> void:
	group = group_name

static func note(r: Rect2) -> void:
	if recording and group != "":
		if not seen.has(group):
			seen[group] = []
		seen[group].append(r)

## The groups (name -> Array of Rect2) found under `root`: its visible controls, looking inside any that fill the
## screen (a full-rect backdrop or container) for the real ones.
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
		if c is CenterContainer or (r.size.x >= sz.x * 0.9 and r.size.y >= sz.y * 0.9):
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
	for line in s.split("\n"):      # (a plain label with line breaks is as wide as its longest line)
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")).x)
	return w > room + 1.0
