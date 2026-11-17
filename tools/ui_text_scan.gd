class_name UiTextScan
extends RefCounted
## The text rules of --ui-text-probe-check, on one UI tree (the screen that "name it" ran one letter per line on:
## a Label with autowrap in a column the layout squeezed to 1 px). Finds every visible Label, RichTextLabel and
## Button whose text is
##   narrow : wrapped into a column under NARROW_CHARS average characters wide
##   tall   : more than TALL_LINES lines for under TALL_TEXT_CHARS characters
##   outside: partly outside the viewport (what a scroll area or clip hides on purpose does not count)
##   overlap: drawn over another visible text (unless an opaque panel is drawn between the two)
## Text the HUD draws itself (TextCache.seen_at: [text, window rect, canvas item]) is judged by outside and overlap
## (path: the canvas item that drew it, text prefixed "drawn: ").
## Each hit is {rule, path, text, rect (the text's own box, px), detail}. Ignores controls that are not drawn
## (hidden, or faded out to alpha 0.1 or less).

const NARROW_CHARS := 3.0  # px/char multiple: a wrapped column narrower than this many average characters
const TALL_LINES := 6  # more lines than this ...
const TALL_TEXT_CHARS := 40  # ... for fewer characters than this is "one letter per line"
const MIN_TEXT_CHARS := 4  # shorter strings (an icon glyph, "x2") are not judged for narrow or drawn overlap
const OVERLAP_FRACTION := 0.3  # of the smaller text box that two boxes must share to count
const OVERLAP_MIN_PX := 3.0  # both sides of the shared box
const EDGE_PX := 2.0  # how far past the viewport edge counts as outside
const COVER_ALPHA := 0.85  # a panel or colour rect this opaque hides the text under it
const SCRIM_AREA := 0.9  # share of the window a dimmer must cover to count as a modal scrim
const SCRIM_ALPHA := 0.4  # a scrim this dark puts what is under it behind the dialog
const FADED := 0.1  # modulate alpha at or under which a subtree is not drawn

## Visible text controls the last scan() judged (a probe that sees none of a screen proves nothing).
static var texts := 0

var hits: Array[Dictionary] = []
var _root: Node
var _view := Rect2()
var _items: Array[Dictionary] = []
var _covers: Array[Dictionary] = []
var _order := 0
var _keys := {}  # Control -> its draw-order key (what it draws itself sits under its children)


## Scans `root` against a viewport of `view` px (logical), with the text drawn meanwhile (`drawn`, TextCache.seen_at).
static func scan(root: Node, view: Vector2, drawn: Array = []) -> Array[Dictionary]:
	var s := UiTextScan.new()
	s._root = root
	s._view = Rect2(Vector2.ZERO, view)
	s._walk(root, 0, 0, 1.0, Rect2(-Vector2.ONE * 1e6, Vector2.ONE * 2e6))
	s._add_drawn(drawn)
	s._overlaps()
	texts = s._items.size()
	return s.hits


func _walk(nd: Node, layer: int, z: int, alpha: float, clip: Rect2) -> void:
	_order += 1
	var lay := layer
	if nd is CanvasLayer:
		lay = (nd as CanvasLayer).layer
		if not (nd as CanvasLayer).visible:
			return
	var zz := z
	var a := alpha
	var cl := clip
	if nd is CanvasItem:
		var ci := nd as CanvasItem
		if not ci.visible:
			return
		a *= ci.modulate.a
		if ci.z_as_relative:
			zz += ci.z_index
		if a <= FADED:
			return
	if nd is Control:
		var c := nd as Control
		if c.clip_contents or c is ScrollContainer:
			cl = clip.intersection(c.get_global_rect())
		_note(c, lay, zz, cl, a)
	for ch in nd.get_children():
		_walk(ch, lay, zz, a, cl)


func _note(c: Control, layer: int, z: int, clip: Rect2, alpha: float) -> void:
	var key := (layer + 100) * 1000000000000 + (z + 1000) * 1000000000 + _order
	_keys[c] = key
	var r := c.get_global_rect()
	if c is Panel or c is PanelContainer:
		var sb := c.get_theme_stylebox("panel")
		if sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a * alpha >= COVER_ALPHA:
			_covers.append({"key": key, "rect": r})
	elif c is ColorRect:
		var scrim := r.get_area() >= SCRIM_AREA * _view.get_area() and (c as ColorRect).color.a * alpha >= SCRIM_ALPHA
		if scrim or (c as ColorRect).color.a * alpha >= COVER_ALPHA:
			_covers.append({"key": key, "rect": r})
	var text := _text_of(c)
	if text == "" or r.size.x < 1.0 or r.size.y < 1.0:
		return
	var box := _text_box(c, text)
	var seen := box.intersection(clip)
	if seen.size.x <= 0.0 or seen.size.y <= 0.0:
		return
	var item := {"c": c, "key": key, "text": text, "box": box, "seen": seen}
	_items.append(item)
	_judge(item)


func _add_drawn(drawn: Array) -> void:
	var done := {}
	for d: Array in drawn:
		var box: Rect2 = d[1]
		var text := String(d[0]).strip_edges()
		var ci: CanvasItem = d[2]
		var id := "%s|%s" % [text, box]
		if done.has(id) or not is_instance_valid(ci) or not _keys.has(ci) or not box.intersects(_view):
			continue
		done[id] = true
		var item := {"c": ci, "key": _keys[ci], "text": "drawn: " + text, "box": box, "seen": box, "drawn": true}
		if text.length() >= MIN_TEXT_CHARS:  # (an icon glyph or a count is drawn over things on purpose)
			_items.append(item)
		if not _view.grow(EDGE_PX).encloses(box):
			_hit("outside", ci, item["text"], box, "box %s outside %s" % [_fmt(box), _fmt(_view)])


func _text_of(c: Control) -> String:
	var t := ""
	if c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	elif c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	return t.strip_edges()


func _wrap_on(c: Control) -> bool:
	if c is Label:
		return (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
	if c is RichTextLabel:
		return (c as RichTextLabel).autowrap_mode != TextServer.AUTOWRAP_OFF
	return c is Button and (c as Button).autowrap_mode != TextServer.AUTOWRAP_OFF


func _font_size(c: Control) -> int:
	var n := "normal_font_size" if c is RichTextLabel else "font_size"
	return c.get_theme_font_size(n)


func _font(c: Control) -> Font:
	return c.get_theme_font("normal_font" if c is RichTextLabel else "font")


## Room for the text inside the control: its width less a button's frame.
func _room_w(c: Control) -> float:
	if c is Button:
		return c.size.x - c.get_theme_stylebox("normal").get_minimum_size().x
	return c.size.x


func _lines(c: Control, text: String, width: float) -> int:
	if c is Label:
		return (c as Label).get_line_count()
	if c is RichTextLabel:
		return (c as RichTextLabel).get_line_count()
	var w := width if _wrap_on(c) else -1.0
	var sz := _font(c).get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w, _font_size(c))
	return roundi(sz.y / _font(c).get_height(_font_size(c)))


## The box the text really covers, in px: the longest line wide and the lines tall, placed by the alignment,
## and allowed to run past the control unless it is trimmed or clipped (that is the "outside" hit).
func _text_box(c: Control, text: String) -> Rect2:
	var r := c.get_global_rect()
	if c is RichTextLabel:
		return r
	var fs := _font_size(c)
	var font := _font(c)
	var wrap := _room_w(c) if _wrap_on(c) else -1.0
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap, fs)
	sz.y = maxf(sz.y, font.get_height(fs) * _lines(c, text, wrap))
	var trimmed := c is Label and (c as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	trimmed = trimmed or (c is Label and (c as Label).clip_text) or (c is Button and (c as Button).clip_text)
	if trimmed:
		sz.x = minf(sz.x, r.size.x)
	var x := r.position.x
	var al := HORIZONTAL_ALIGNMENT_CENTER
	if c is Label:
		al = (c as Label).horizontal_alignment
	elif c is Button:
		al = (c as Button).alignment
	if al == HORIZONTAL_ALIGNMENT_CENTER:
		x += (r.size.x - sz.x) * 0.5
	elif al == HORIZONTAL_ALIGNMENT_RIGHT:
		x += r.size.x - sz.x
	var y := r.position.y + (r.size.y - sz.y) * 0.5
	if c is Label and (c as Label).vertical_alignment == VERTICAL_ALIGNMENT_TOP:
		y = r.position.y
	return Rect2(x, y, sz.x, sz.y)


func _judge(item: Dictionary) -> void:
	var c: Control = item["c"]
	var text: String = item["text"]
	var box: Rect2 = item["box"]
	var n := text.length()
	var lines := _lines(c, text, _room_w(c))
	if _wrap_on(c) and n >= MIN_TEXT_CHARS:
		var avg := _font(c).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(c)).x / float(n)
		if _room_w(c) < NARROW_CHARS * avg:
			_hit("narrow", c, text, box, "%d px wide, %.1f px per char, %d lines" % [_room_w(c), avg, lines])
	if lines > TALL_LINES and n < TALL_TEXT_CHARS:
		_hit("tall", c, text, box, "%d lines for %d chars" % [lines, n])
	var seen: Rect2 = item["seen"]
	var cut := not seen.is_equal_approx(box)  # a scroll area or clip hides part of it on purpose
	if not cut and not _view.grow(EDGE_PX).encloses(box) and box.intersects(_view):
		_hit("outside", c, text, box, "box %s outside %s" % [_fmt(box), _fmt(_view)])


func _overlaps() -> void:
	for i in _items.size():
		for j in range(i + 1, _items.size()):
			var a: Dictionary = _items[i]
			var b: Dictionary = _items[j]
			var family: bool = a["c"].is_ancestor_of(b["c"]) or b["c"].is_ancestor_of(a["c"])
			if family and not (a.has("drawn") or b.has("drawn")):  # (a button and its own label)
				continue
			var sa: Rect2 = a["seen"]
			var sb: Rect2 = b["seen"]
			var both := sa.intersection(sb)
			if both.size.x < OVERLAP_MIN_PX or both.size.y < OVERLAP_MIN_PX:
				continue
			var small := minf(sa.get_area(), sb.get_area())
			if both.get_area() < OVERLAP_FRACTION * small or _covered(a["key"], b["key"], both):
				continue
			var top: Dictionary = b if int(b["key"]) > int(a["key"]) else a
			var under: Dictionary = a if top == b else b
			var why := "over '%s' (%s)" % [String(under["text"]).left(24), _fmt(both)]
			_hit("overlap", top["c"], top["text"], both, why)


## True when an opaque panel is drawn after the lower text and before the upper one and covers the shared box.
func _covered(ka: int, kb: int, both: Rect2) -> bool:
	var lo := mini(ka, kb)
	var hi := maxi(ka, kb)
	for cv in _covers:
		var k: int = cv["key"]
		if k > lo and k <= hi and (cv["rect"] as Rect2).encloses(both):
			return true
	return false


func _hit(rule: String, c: Node, text: String, box: Rect2, detail: String) -> void:
	(
		hits
		. append(
			{
				"rule": rule,
				"path": str(_root.get_path_to(c)),
				"class": c.get_class(),
				"text": text.left(40).replace("\n", " "),
				"rect": box,
				"detail": detail,
			}
		)
	)


func _fmt(r: Rect2) -> String:
	return "%d,%d %dx%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
