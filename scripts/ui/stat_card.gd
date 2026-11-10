class_name StatCard
## The four trained stats on the Boki card: a bar each with the level cap marked, and under it the
## last change with its cause (StatCause.last). Plain numbers, no grades.

const CAP_ROOM := 1.25         # the track runs this far past the cap, so the cap mark sits inside it
const MARK_COL := Color(1, 1, 1, 0.85)

static func add(rec: Dictionary, parent: Control) -> void:
	var cap := float(Care.stat_cap(rec))
	var title := "Stats  ·  cap %d at level %d" % [int(cap), int(rec.get("level", 1))]
	parent.add_child(UI.section(title, UI.FAINT.lightened(0.2)))
	for st in Care.STATS:
		var info: Dictionary = Care.STATS[st]
		var pts := float(rec["stats"][st])
		var head := UI.hbox(10)
		var name_l := UI.label(String(info["name"]), UI.T_SMALL, UI.MUTED)
		name_l.custom_minimum_size.x = 92.0
		head.add_child(name_l)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(150, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.draw.connect(_draw_bar.bind(bar, pts / (cap * CAP_ROOM), info["col"], 1.0 / CAP_ROOM))
		head.add_child(bar)
		var num := UI.label("%d of %d" % [int(pts), int(cap)], 12, UI.MUTED, UI.semi)
		num.custom_minimum_size.x = 64
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(num)
		parent.add_child(head)
		var why := StatCause.last(rec, st)
		var line := UI.label(why, 12, UI.MUTED)
		if why == "":
			line.text = "No training yet"
			line.add_theme_color_override("font_color", UI.FAINT)
		line.name = "Cause_" + st
		parent.add_child(line)

static func _draw_bar(bar: Control, frac: float, col: Color, cap_at: float) -> void:
	UI.draw_bar(bar, Rect2(Vector2.ZERO, bar.size), frac, col)
	var x := bar.size.x * cap_at
	bar.draw_line(Vector2(x, -2), Vector2(x, bar.size.y + 2), MARK_COL, 2.0)
