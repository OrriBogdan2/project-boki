class_name IvView
extends RefCounted
## How a kin's IVs (Care.IVS: what it was born with, 0 to 31 a stat) look in menus: a five-point
## chart, rows of bars with the judge's word for each, a tiny strip for tight spots, and two
## parents side by side with what an egg of theirs could take from them.

const TRACK := Color(0, 0, 0, 0.35)

## The judge's verdict colour for one stat.
static func word_col(v: int) -> Color:
	if v >= 31: return UI.GOLD
	if v >= 26: return UI.GOOD
	if v >= 16: return UI.INK
	return UI.MUTED

static func grade_col(rec: Dictionary) -> Color:
	var t := Care.iv_total(rec)
	if t >= 126: return UI.GOLD
	if t >= 101: return UI.GOOD
	if t >= 76: return UI.INK
	return UI.MUTED

static func tip(stat: String, v: int) -> String:
	var inf: Dictionary = Care.IVS[stat]
	return "%s %d/31 (%s): +%.1f%% %s" % [inf["name"], v, Care.iv_word(v), (Care.iv_mult({"ivs": {stat: v}}, stat) - 1.0) * 100.0, inf["desc"]]

# ------------------------------------------------------------------ the chart
## A five-point chart of a kin's IVs (one point a stat, 31 at the rim). other: a second kin drawn
## as an outline over it (a parent to compare with).
static func radar(rec: Dictionary, px := 170.0, col := UI.ACCENT, other: Dictionary = {}, col2 := UI.TEAL) -> Control:
	return Radar.new(Care.ivs(rec), px, col, Care.ivs(other) if not other.is_empty() else {}, col2)

class Radar extends Control:
	var v: Dictionary
	var v2: Dictionary
	var col: Color
	var col2: Color
	func _init(vals: Dictionary, px: float, c: Color, vals2: Dictionary, c2: Color) -> void:
		v = vals; v2 = vals2; col = c; col2 = c2
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_PASS
		var lines: Array = []
		for k in Care.IV_KEYS: lines.append(IvView.tip(k, int(v[k])))
		tooltip_text = "\n".join(lines)
	func _pt(i: int, frac: float, c: Vector2, r: float) -> Vector2:
		var a := -PI * 0.5 + TAU * float(i) / float(Care.IV_KEYS.size())
		return c + Vector2(cos(a), sin(a)) * r * frac
	func _poly(vals: Dictionary, c: Vector2, r: float) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in Care.IV_KEYS.size():
			p.append(_pt(i, maxf(0.06, float(vals[Care.IV_KEYS[i]]) / 31.0), c, r))
		return p
	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 4)
		var r := minf(size.x, size.y) * 0.5 - 30.0
		var n := Care.IV_KEYS.size()
		# rings at a third, two thirds and full, and the spokes
		for f in [1.0 / 3.0, 2.0 / 3.0, 1.0]:
			var ring := PackedVector2Array()
			for i in n + 1: ring.append(_pt(i % n, f, c, r))
			if f == 1.0:
				var fillp := ring.duplicate(); fillp.remove_at(n)
				draw_colored_polygon(fillp, Color(0, 0, 0, 0.22))
			draw_polyline(ring, Color(1, 1, 1, 0.16 if f == 1.0 else 0.07), 1.0, true)
		for i in n:
			draw_line(c, _pt(i, 1.0, c, r), Color(1, 1, 1, 0.07), 1.0, true)
		if not v2.is_empty():
			var p2 := _poly(v2, c, r)
			draw_colored_polygon(p2, Color(col2, 0.14))
			var l2 := p2.duplicate(); l2.append(p2[0])
			draw_polyline(l2, Color(col2, 0.85), 1.5, true)
		var p := _poly(v, c, r)
		draw_colored_polygon(p, Color(col, 0.32))
		var l := p.duplicate(); l.append(p[0])
		draw_polyline(l, Color(col, 0.95), 2.0, true)
		for i in n:
			var k: String = Care.IV_KEYS[i]
			var iv := int(v[k])
			var dot := _pt(i, maxf(0.06, float(iv) / 31.0), c, r)
			draw_circle(dot, 3.5 if iv >= 31 else 2.5, UI.GOLD if iv >= 31 else Color(Care.IVS[k]["col"]))
			# the stat's name and number outside the rim
			var at := _pt(i, 1.0, c, r + 14.0)
			var f: Font = UI.semi if UI.semi else get_theme_default_font()
			var nm := String(Care.IVS[k]["name"])
			var sz := 11
			var tw := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var dx := -tw * 0.5
			if at.x > c.x + 4.0: dx = -tw * 0.2
			elif at.x < c.x - 4.0: dx = -tw * 0.8
			var dy := -2.0 if at.y < c.y else 10.0
			draw_string(f, at + Vector2(dx, dy), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(Care.IVS[k]["col"]).lerp(UI.INK, 0.35))
			var num := str(iv)
			var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(f, at + Vector2(dx + (tw - nw) * 0.5, dy + 13.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, IvView.word_col(iv))

# ------------------------------------------------------------------ bars
## One stat as a bar from 0 to 31; a full one wears a gold edge.
static func iv_bar(v: int, col: Color, w := 120.0, h := 8.0, flip := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := int(minf(c.size.y * 0.5, 4.0))
		c.draw_style_box(UiWidgets.bar_box(TRACK, r), Rect2(Vector2.ZERO, c.size))
		var fw := c.size.x * clampf(float(v) / 31.0, 0.0, 1.0)
		if fw > 1.0:
			var bw := maxf(fw, r * 2.0)
			var fill := Rect2(Vector2(c.size.x - bw if flip else 0.0, 0), Vector2(bw, c.size.y))
			c.draw_style_box(UiWidgets.bar_box(col, r), fill)
			if v >= 31:
				c.draw_rect(fill.grow(-0.5), UI.GOLD, false, 1.0)
		# faint marks at the judge's steps (16 pretty good, 26 very good)
		for m in [16, 26]:
			var x := c.size.x * float(m) / 31.0
			if flip: x = c.size.x - x
			c.draw_line(Vector2(x, 1), Vector2(x, c.size.y - 1), Color(1, 1, 1, 0.12), 1.0))
	return c

## A row a stat: name, bar, number and the judge's word.
static func rows(rec: Dictionary, words := true, name_w := 62.0, bar_w := 110.0) -> VBoxContainer:
	var v := UI.vbox(5)
	var vals := Care.ivs(rec)
	for k in Care.IV_KEYS:
		var iv := int(vals[k])
		var r := UI.hbox(8)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = tip(k, iv)
		var nl := UiText.label(String(Care.IVS[k]["name"]), UI.T_SMALL, UI.MUTED)
		nl.custom_minimum_size.x = name_w
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(nl)
		var b := iv_bar(iv, Care.IVS[k]["col"], bar_w, 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(b)
		var nv := UiText.label(str(iv), UI.T_SMALL, word_col(iv), UI.semi)
		nv.custom_minimum_size.x = 22
		nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(nv)
		if words:
			var wl := UiText.label(Care.iv_word(iv), 12, word_col(iv))
			wl.custom_minimum_size.x = 74
			r.add_child(wl)
		v.add_child(r)
	return v

## A cell a stat side by side: its name, the number with a little bar under it, the judge's word.
## Compact enough for the kin card.
static func cells(rec: Dictionary) -> HBoxContainer:
	var h := UI.hbox(6)
	var vals := Care.ivs(rec)
	for k in Care.IV_KEYS:
		var iv := int(vals[k])
		var c := UI.vbox(1)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		c.tooltip_text = tip(k, iv)
		var nl := UiText.label(String(Care.IVS[k]["name"]), 12, Color(Care.IVS[k]["col"]).lerp(UI.INK, 0.35))
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(nl)
		var nv := UiText.label(str(iv), UI.T_HEAD, word_col(iv), UI.big)
		nv.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(nv)
		var b := iv_bar(iv, Care.IVS[k]["col"], 56, 5)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(b)
		var wl := UiText.label(Care.iv_word(iv), 11, word_col(iv))
		wl.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(wl)
		h.add_child(c)
	return h

## The judge's word for each stat, no bars: a compact list to sit beside the chart.
static func word_list(rec: Dictionary) -> VBoxContainer:
	var v := UI.vbox(3)
	var vals := Care.ivs(rec)
	for k in Care.IV_KEYS:
		var iv := int(vals[k])
		var r := UI.hbox(6)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = tip(k, iv)
		var nl := UiText.label(String(Care.IVS[k]["name"]), UI.T_SMALL, Color(Care.IVS[k]["col"]).lerp(UI.INK, 0.35))
		nl.custom_minimum_size.x = 52
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(nl)
		var nv := UiText.label(str(iv), UI.T_SMALL, word_col(iv), UI.semi)
		nv.custom_minimum_size.x = 22
		nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(nv)
		r.add_child(UiText.label(Care.iv_word(iv), UI.T_SMALL, word_col(iv)))
		v.add_child(r)
	return v

## The total and the overall grade on one line.
static func grade_line(rec: Dictionary, size := UI.T_SMALL) -> HBoxContainer:
	var h := UI.hbox(8)
	var g := Care.iv_grade(rec)
	h.add_child(UiWidgets.tag(String(g[0]), grade_col(rec)))
	var tl := UiText.label("%d / 155" % Care.iv_total(rec), size, UI.MUTED, UI.semi)
	h.add_child(tl)
	return h

## The heading for an IV block, with the explainer as its tooltip.
static func heading(col := UI.FAINT.lightened(0.2)) -> Control:
	var s := UiText.section("Inborn  ·  IVs", col)
	s.tooltip_text = Care.IV_EXPLAIN
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s

## The one-line explainer, shown while you first get to know IVs (the play session you first see
## them in); after that it lives on as the heading's tooltip.
static var _shown_now := false
static func first_view_line(parent: Control) -> void:
	if Save.d.get("tutorial", {}).get("ivs_seen", false) and not _shown_now:
		return
	var l := UiText.para(Care.IV_EXPLAIN, 12, UI.ACCENT_HI)
	parent.add_child(l)
	_shown_now = true
	if Save.d.has("tutorial"): Save.d["tutorial"]["ivs_seen"] = true

## The kin card's block: heading with the grade, then a cell a stat (the explainer is the heading's tooltip).
static func block(rec: Dictionary, parent: Control) -> void:
	var hr := UI.hbox(8)
	hr.add_child(heading())
	hr.add_child(UI.fill())
	hr.add_child(grade_line(rec))
	parent.add_child(hr)
	parent.add_child(cells(rec))

## Five little upright bars and the total, for a tight spot (the Kin Burrow's side panel, tiles).
static func mini(rec: Dictionary, h := 20.0, show_total := true) -> HBoxContainer:
	var row := UI.hbox(6)
	var strip := Mini.new(Care.ivs(rec), h)
	row.add_child(strip)
	if show_total:
		var tl := UiText.label("IVs %d/155  ·  %s" % [Care.iv_total(rec), Care.iv_grade(rec)[0]], 12, grade_col(rec), UI.semi)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tl)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var lines: Array = ["%s  ·  %d/155" % [Care.iv_grade(rec)[0], Care.iv_total(rec)]]
	for k in Care.IV_KEYS: lines.append(tip(k, Care.iv(rec, k)))
	row.tooltip_text = "\n".join(lines)
	return row

class Mini extends Control:
	var v: Dictionary
	func _init(vals: Dictionary, h: float) -> void:
		v = vals
		custom_minimum_size = Vector2(Care.IV_KEYS.size() * 6.0 - 2.0, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in Care.IV_KEYS.size():
			var k: String = Care.IV_KEYS[i]
			var x := i * 6.0
			draw_rect(Rect2(x, 0, 4, size.y), Color(0, 0, 0, 0.35))
			var f := clampf(float(v[k]) / 31.0, 0.0, 1.0)
			var hh := maxf(1.5, size.y * f)
			draw_rect(Rect2(x, size.y - hh, 4, hh), UI.GOLD if int(v[k]) >= 31 else Color(Care.IVS[k]["col"]))

# ------------------------------------------------------------------ two parents
## The pair's IVs side by side: a's bar grows left, b's grows right, the stat between; the better
## of the two is lit. Then what an egg could take from them.
static func compare(a: Dictionary, b: Dictionary, bar_w := 120.0) -> VBoxContainer:
	var v := UI.vbox(6)
	var va := Care.ivs(a); var vb := Care.ivs(b)
	var ca: Color = Shiny.body(a).lerp(UI.INK, 0.3)
	var cb: Color = Shiny.body(b).lerp(UI.INK, 0.3)
	var hd := UI.hbox(8)
	var an := UiText.label(String(a["name"]), UI.T_SMALL, ca, UI.semi); an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hd.add_child(an)
	var mid := UiText.label("", 12, UI.MUTED); mid.custom_minimum_size.x = 64
	hd.add_child(mid)
	var bn := UiText.label(String(b["name"]), UI.T_SMALL, cb, UI.semi); bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(bn)
	v.add_child(hd)
	for k in Care.IV_KEYS:
		var x := int(va[k]); var y := int(vb[k])
		var r := UI.hbox(8)
		var xl := UiText.label(str(x), UI.T_SMALL, word_col(x), UI.semi); xl.custom_minimum_size.x = 22
		xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(xl)
		var ba := iv_bar(x, Color(Care.IVS[k]["col"], 1.0 if x >= y else 0.45), bar_w, 8, true)     # grows toward the middle
		ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(ba)
		var nm := UiText.label(String(Care.IVS[k]["name"]), 12, Color(Care.IVS[k]["col"]).lerp(UI.INK, 0.3))
		nm.custom_minimum_size.x = 64
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(nm)
		var bb := iv_bar(y, Color(Care.IVS[k]["col"], 1.0 if y >= x else 0.45), bar_w, 8)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(bb)
		var yl := UiText.label(str(y), UI.T_SMALL, word_col(y), UI.semi); yl.custom_minimum_size.x = 22
		r.add_child(yl)
		r.tooltip_text = "%s: %s %d, %s %d. An egg takes this from one of them %d%% of the time (either parent equally), otherwise it's a fresh roll." % [Care.IVS[k]["name"], a["name"], x, b["name"], y, int(round(100.0 * Care.IV_INHERIT / Care.IV_KEYS.size()))]
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(r)
	var tr := UI.hbox(8)
	var ta := UiText.label("%d" % Care.iv_total(a), UI.T_SMALL, grade_col(a), UI.semi); ta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(ta)
	var tm := UiText.label("Total", 12, UI.MUTED); tm.custom_minimum_size.x = 64; tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr.add_child(tm)
	var tb := UiText.label("%d" % Care.iv_total(b), UI.T_SMALL, grade_col(b), UI.semi); tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(tb)
	v.add_child(tr)
	return v

## What an egg of these two could get: the best it could take from them, and the odds.
static func pass_on(a: Dictionary, b: Dictionary) -> VBoxContainer:
	var v := UI.vbox(4)
	var va := Care.ivs(a); var vb := Care.ivs(b)
	var best: Array = []
	var top_k := ""
	var top_v := -1
	for k in Care.IV_KEYS:
		var m := maxi(int(va[k]), int(vb[k]))
		if m >= 26: best.append("%s %d" % [Care.IVS[k]["name"], m])
		if m > top_v: top_v = m; top_k = k
	var pct := int(round(100.0 * Care.IV_INHERIT / Care.IV_KEYS.size()))
	v.add_child(UiText.para("An egg takes %d of these 5 from its parents (each from either one) and rolls %d fresh: every stat has a %d%% chance to come from them." % [Care.IV_INHERIT, Care.IV_KEYS.size() - Care.IV_INHERIT, pct], 12, UI.MUTED))
	if not best.is_empty():
		v.add_child(UiText.para("Could pass on: %s." % ", ".join(best), 12, UI.GOOD))
	else:
		v.add_child(UiText.para("Could pass on at best: %s %d." % [Care.IVS[top_k]["name"], top_v], 12, UI.INK))
	return v
