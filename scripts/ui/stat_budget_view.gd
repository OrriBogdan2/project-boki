class_name StatBudgetView
extends RefCounted
## The Boki card's Training tab, stats half (decision 0022): the budget ring (points spent of the total),
## one bar per stat on a 0 to 100 scale with marks where the gain bands change and the level cap, and the
## "next point: N more plays" line.

const RING_PX := 64.0
const RING_W := 7.0
const MARK := Color(1, 1, 1, 0.55)
const CAP_MARK := Color("e0b24a")

static func fill(box: Control, rec: Dictionary) -> void:
	var spent := StatBudget.total(rec)
	var total := int(StatBudget.rules()["total_cap"])
	var head := UI.hbox(12)
	var ring := Control.new()
	ring.custom_minimum_size = Vector2(RING_PX, RING_PX)
	ring.draw.connect(func(): _draw_ring(ring, float(spent) / float(total)))
	head.add_child(ring)
	var words := "Budget  %d of %d\nLevel cap %d a stat" % [spent, total, StatBudget.cap(rec)]
	head.add_child(UI.label(words, UI.T_SMALL, UI.MUTED))
	box.add_child(head)
	for s in Care.STATS:
		box.add_child(_row(rec, s))
	var tip := "Train at the yard to raise them. Past 50 points a gain counts half, past 80 a quarter."
	box.add_child(UI.para(tip, 12, UI.FAINT))

static func _row(rec: Dictionary, s: String) -> Control:
	var info: Dictionary = Care.STATS[s]
	var cap_max := float(StatBudget.rules()["cap_max"])
	var r := UI.hbox(10)
	var l := UI.label(String(info["name"]), UI.T_SMALL, UI.MUTED)
	l.custom_minimum_size.x = 92.0
	r.add_child(l)
	var bar := UI.bar(float(rec["stats"][s]) / cap_max, info["col"], 150, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func(): _draw_marks(bar, rec, cap_max))
	r.add_child(bar)
	var n := StatBudget.plays_to_next(rec, s)
	var next := "next: %d more" % n if n > 0 else "full"
	var right := UI.label("%d  ·  %s" % [int(rec["stats"][s]), next], 12, UI.MUTED, UI.semi)
	right.custom_minimum_size.x = 120.0
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(right)
	return r

static func _draw_marks(c: Control, rec: Dictionary, cap_max: float) -> void:
	for b in StatBudget.rules()["bands"]:
		if float(b[0]) < cap_max:
			var bx := c.size.x * float(b[0]) / cap_max
			c.draw_line(Vector2(bx, 0), Vector2(bx, c.size.y), MARK, 1.0)
	var x := c.size.x * float(StatBudget.cap(rec)) / cap_max
	c.draw_line(Vector2(x, 0), Vector2(x, c.size.y), CAP_MARK, 2.0)

static func _draw_ring(c: Control, frac: float) -> void:
	var mid := c.size * 0.5
	var rad := RING_PX * 0.5 - RING_W
	c.draw_arc(mid, rad, 0.0, TAU, 48, Color(0, 0, 0, 0.35), RING_W)
	c.draw_arc(mid, rad, -PI * 0.5, -PI * 0.5 + TAU * clampf(frac, 0.0, 1.0), 48, CAP_MARK, RING_W)
