class_name SafeArea
extends RefCounted
## The screen's safe margin and the HUD's rect registry (--safe-area-check). The interface is laid out in
## logical pixels (Settings._apply_ui_scale keeps the window near 1240-2560 x 720-775 at every size), so one
## fixed margin is about 2% of the height everywhere. HUD panels are drawn each frame, so while a check
## records, each draw is tagged with a group (`begin`) and the rects drawn under that tag are merged (`note`).

const MARGIN := 12.0      # logical px kept clear on every side
const MAX_ASPECT := 16.0 / 9.0      # widest the HUD spreads: wider screens keep it in a centred frame this shape

static var recording := false
static var seen := {}      # group -> Array of the Rect2s that group drew
static var group := ""

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
				if (groups[names[j]] as Array).any(func(o: Rect2): return r.intersects(o)):
					bad.append("%s overlaps %s" % [names[i], names[j]])
	return bad
