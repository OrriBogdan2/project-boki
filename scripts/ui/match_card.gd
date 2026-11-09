class_name MatchCard
extends RefCounted
## The match summary on the results screen: your place big, four numbers, your Boki's summons, and
## (once the loot is in) your squadmates in a row. Numbers come from MatchSummary.fill.

const NUMBERS := [["burst", "Damage", "damage"], ["knock", "Knocks", "knocks"],
		["bond", "Assists", "assists"], ["heart", "Healing", "healing"]]   # icon, label, key in the result

## Place, the four numbers and your Boki, at the top of `cv`.
static func head(cv: VBoxContainer, r: Dictionary, boki: Dictionary) -> void:
	var place := int(r.get("place", 0))
	if place > 0:
		var secs := int(r.get("time", 0))
		var pr := UI.hbox(10)
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		pr.add_child(UI.title("#%d" % place, 56, UI.GOLD if place == 1 else UI.INK))
		var of := UI.label("of %d teams  ·  %d:%02d" % [int(r["places"]), secs / 60, secs % 60], UI.T_BODY, UI.MUTED)
		of.size_flags_vertical = Control.SIZE_SHRINK_END
		pr.add_child(of)
		cv.add_child(pr)
	var strip := UI.card(Color(0, 0, 0, 0.2), 14, 14)
	var sh := UI.hbox(0)
	strip.add_child(sh)
	for i in NUMBERS.size():
		if i > 0:
			var sep := ColorRect.new()
			sep.color = UI.LINE
			sep.custom_minimum_size = Vector2(1, 0)
			sh.add_child(sep)
		var n: Array = NUMBERS[i]
		sh.add_child(_tile(n[0], n[1], float(r.get(n[2], 0)), 0.35 + i * 0.08))
	cv.add_child(strip)
	if not boki.is_empty():
		var n := int(r.get("summons", 0))
		var line := "%s was sent out %d time%s" % [String(boki["name"]), n, "" if n == 1 else "s"]
		var bl := UI.label(line, UI.T_BODY, UI.MUTED)
		bl.set_meta("boki_summons", n)
		cv.add_child(bl)

## Your squadmates, one small card each, in a row.
static func squad(cv: VBoxContainer, r: Dictionary) -> void:
	var mates: Array = r.get("squad", [])
	if mates.is_empty():
		return
	cv.add_child(UI.section("Your team"))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for m in mates:
		var c := UI.card(Color(0, 0, 0, 0.2), 10, 10)
		var v := UI.vbox(2)
		c.add_child(v)
		v.add_child(UI.label(String(m["name"]), UI.T_BODY, UI.INK, UI.semi))
		var nums := "%d damage  ·  %d knocks  ·  %d assists  ·  %d healing"
		v.add_child(UI.label(nums % [m["damage"], m["knocks"], m["assists"], m["healing"]], UI.T_SMALL, UI.MUTED))
		row.add_child(c)
	cv.add_child(row)

## One number that counts up from zero, with what it is under it.
static func _tile(icon: String, what: String, value: float, delay: float) -> Control:
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var num := UI.title("0", 30)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(num)
	var lr := UI.hbox(5)
	lr.alignment = BoxContainer.ALIGNMENT_CENTER
	lr.add_child(Icons.Glyph.new(icon, Color(1, 0.86, 0.6, 0.8), 13.0))
	var lab := UI.label(what.to_upper(), 11, UI.MUTED, UI.caps)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lr.add_child(lab)
	col.add_child(lr)
	col.tree_entered.connect(_count_up.bind(col, num, value, delay), CONNECT_ONE_SHOT)
	return col

static func _count_up(col: Control, num: Label, value: float, delay: float) -> void:
	var tw := col.create_tween()
	tw.tween_interval(delay)
	var set_text := func(x: float) -> void: num.text = str(int(round(x)))
	var secs := clampf(0.4 + value * 0.01, 0.5, 1.1)
	tw.tween_method(set_text, 0.0, value, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
