class_name IncubatorView
extends RefCounted
## The Nesting Nook's Incubator tab: every cradle with its Rare Egg and how warm it is, what's left
## (expeditions or minutes), what's warming them (an Ember kin, Ember Coals), the cradles you can
## still buy, and the eggs on the shelf waiting for one. Built inside the home screen's Nook panel
## (home.gd _open_nook), in the game's menu style.

const CARD_W := 222.0

## Fills the Nook panel body v. reopen rebuilds the panel; hatch(id) hatches one ready egg.
static func build(home: Node, v: VBoxContainer, reopen: Callable, hatch: Callable) -> void:
	Incubator.ensure()
	var q := Incubator.shelf()
	UI.subtitle(v, "Rare Eggs from boss lairs warm here side by side. Each hatches after %d expeditions or about %d minutes warm." % [Incubator.TRIPS, int(Incubator.HEAT_NEED / 60.0)])
	var coals := int(Save.d["items"].get("coals", 0))
	UI.head_extra(v).add_child(UI.chip("dash", "%d Ember Coals" % coals, Color("ff9a4a"), "Stoke them into the brazier: every egg warms faster for %d minutes. The market stall sells them." % int(Incubator.COAL_SECS / 60.0)))
	if Incubator.count() == 0 and Incubator.slots() == Incubator.SLOTS:
		v.add_child(UI.empty_state("egg", "No Rare Eggs yet", "Beat a boss in its lair and carry its egg home: it comes to the Incubator to hatch into a rare Boki. It has %d cradles to start with." % Incubator.SLOTS))
		return
	# what's warming them
	var warm := _warmer(home)
	var hb := UI.hbox(12)
	var rate := Incubator.rate(home.hinc.warmed() if home.hinc else false)
	var why: Array = []
	if not warm.is_empty(): why.append("%s at the brazier" % warm["name"])
	if Incubator.coal_left() > 0.0: why.append("Ember Coals, %d:%02d left" % [int(Incubator.coal_left()) / 60, int(Incubator.coal_left()) % 60])
	var rl := UI.label(("Warming at %sx: %s" % [str(snappedf(rate, 0.1)).trim_suffix(".0"), ", ".join(why)]) if not why.is_empty() else "Warming at 1x", UI.T_BODY, Color("ffb07a") if rate > 1.0 else UI.INK, UI.semi)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(rl)
	var st := UI.button("Stoke Ember Coals", func():
		var w := Incubator.stoke()
		if w != "": home._toast(w)
		else:
			Sfx.play("unlock"); Save.save_game()
			if home.hinc: home.fx.burst(home.INCUB_AT + Vector3(0, 1.0, -0.45), Color("ff9a3a"), 22, 2.6)
		reopen.call(), 0, "dash")
	st.disabled = coals <= 0 or not Incubator.any_warming()
	st.tooltip_text = ("Every egg warms faster for %d more minutes (stacks with an Ember Boki)" % int(Incubator.COAL_SECS / 60.0)) if coals > 0 else "No Ember Coals: the market stall sells them (Farm tab)"
	hb.add_child(st)
	v.add_child(hb)
	if warm.is_empty():
		var embers: Array = (Save.d["roster"] as Array).filter(func(r): return Work.level(r, "ember") > 0 and not KinBox.is_boxed(r))
		var line := "An Ember Boki on the farm warms them twice as fast (an Ember job on the Job Board)."
		if not embers.is_empty(): line += " %s can do it." % ", ".join(embers.slice(0, 3).map(func(r): return String(r["name"])))
		else: line += " You don't have one out on the farm."
		v.add_child(UI.para(line, 12, UI.MUTED))
	# the cradles
	v.add_child(UI.section("Cradles  ·  %d/%d" % [Incubator.eggs().size(), Incubator.slots()]))
	var grid := GridContainer.new(); grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for i in Incubator.slots():
		grid.add_child(_slot_card(Incubator.in_slot(i), hatch))
	var cost := Incubator.slot_cost()
	if cost >= 0:
		var lc := UI.card(Color(UI.NIGHT_HI, 0.7), 12, 12)
		lc.custom_minimum_size = Vector2(CARD_W, 0)
		var lv := UI.vbox(6); lv.alignment = BoxContainer.ALIGNMENT_CENTER
		lc.add_child(lv)
		var li := UI.IconDot.new("lock", UI.FAINT, 26.0); li.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lv.add_child(li)
		var lt := UI.label("Another cradle", UI.T_SMALL, UI.MUTED, UI.semi); lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_child(lt)
		var lp := UI.para("Warm one more egg at a time (up to %d)." % Incubator.MAX_SLOTS, 12, UI.FAINT); lp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_child(lp)
		var bb := UI.button("Add  ·  %d gems" % cost, func():
			var w := Incubator.expand()
			if w != "": home._toast(w); return
			Sfx.play("unlock"); Save.save_game()
			if home.hinc: home.hinc.refresh()
			if home.has_method("_refresh_top"): home._refresh_top()
			reopen.call(), 0, "gem")
		bb.disabled = int(Save.d["gems"]) < cost and not Game.modding()
		bb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lv.add_child(bb)
		grid.add_child(lc)
	# the shelf
	v.add_child(UI.section("Waiting on the shelf  ·  %d" % q.size()))
	if q.is_empty():
		v.add_child(UI.para("Nothing waiting. Eggs beyond your cradles wait here and go in as soon as one is free.", UI.T_SMALL, UI.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14); flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	for i in q.size():
		var e: Dictionary = q[i]
		var r := UI.hbox(8)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = "%s, from %s" % [Incubator.egg_name(e), Incubator.boss_name(e)]
		var ei := EggIcon.new(Incubator.spot_col(e), 36.0, -1.0, false)
		ei.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(ei)
		var tv := UI.vbox(0)
		tv.add_child(UI.label(Incubator.egg_name(e), UI.T_SMALL, UI.INK, UI.semi))
		tv.add_child(UI.label(("Next  ·  " if i == 0 else "") + "from %s" % Incubator.boss_name(e), 12, UI.MUTED))
		r.add_child(tv)
		if i > 0:
			var id := String(e.get("id", ""))
			r.add_child(UI.ghost("Next up", func(): Incubator.next_up(id); Save.save_game(); reopen.call()))
		flow.add_child(r)
	var rd := Incubator.ready_eggs()
	var hp := UI.footer_primary(v, "Hatch" if rd.size() <= 1 else "Hatch one (%d ready)" % rd.size(), func(): if not Incubator.ready_eggs().is_empty(): hatch.call(String(Incubator.ready_eggs()[0]["id"])), 180, "egg")
	hp.disabled = rd.is_empty()
	hp.tooltip_text = "" if not rd.is_empty() else "Nothing's ready yet"

## One cradle: its egg, a warmth ring round it, how long it has left, and Hatch when it's ready.
static func _slot_card(e: Dictionary, hatch: Callable) -> Control:
	var rd := Incubator.egg_ready(e)
	var c := UI.card(UI.CARD if not e.is_empty() else Color(0.12, 0.13, 0.18, 0.6), 12, 12)
	c.custom_minimum_size = Vector2(CARD_W, 0)
	if rd: UI.set_card_border(c, Color(UI.GOLD, 0.8), 2)
	var cv := UI.vbox(4)
	c.add_child(cv)
	if e.is_empty():
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		var el := UI.label("Empty cradle", UI.T_SMALL, UI.FAINT); el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(UI.spacer(30))
		cv.add_child(el)
		return c
	var top := UI.hbox(10)
	var icon := EggIcon.new(Incubator.spot_col(e), 74.0, Incubator.progress(e), rd)
	icon.tooltip_text = "%s, from %s" % [Incubator.egg_name(e), Incubator.boss_name(e)]
	top.add_child(icon)
	var tv := UI.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UI.label(Incubator.egg_name(e), UI.T_SMALL, Color("ffe08a"), UI.semi)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(nm)
	tv.add_child(UI.label("%d%%  ·  %d/%d trips" % [int(Incubator.progress(e) * 100.0), mini(Incubator.trips(e), Incubator.TRIPS), Incubator.TRIPS], 12, UI.MUTED))
	top.add_child(tv)
	cv.add_child(top)
	if rd:
		var id := String(e["id"])
		var hb := UI.button("Hatch", func(): hatch.call(id), 0, "egg")      # (the footer has the one primary)
		cv.add_child(hb)
	else:
		var sl := UI.label(Incubator.status_text(e), 12, UI.INK)
		cv.add_child(sl)
	return c

static func _warmer(home: Node) -> Dictionary:
	for k in home.kins:
		if k.has("job") and String(k["job"]["kind"]) == "warm":
			return k["rec"]
	return {}

## A gold Rare Egg drawn flat, spotted in the colour of the kin inside, with the warmth ring round
## it (prog 0..1; below 0 for no ring).
class EggIcon extends Control:
	var spot: Color
	var prog := -1.0
	var done := false
	func _init(c: Color, px: float, p: float, rd: bool) -> void:
		spot = c; prog = p; done = rd
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if prog >= 0.0:
			var w := maxf(3.0, r * 0.09)
			draw_arc(c, r - w * 0.7, 0, TAU, 64, Color(0, 0, 0, 0.35), w, true)
			if prog > 0.0:
				draw_arc(c, r - w * 0.7, -PI * 0.5, -PI * 0.5 + TAU * prog, 64, UI.GOLD if done else Color("ff9a4a"), w, true)
			r -= w * 2.2
		# the egg: an upright ellipse, lit from the upper left
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			var ry := r * 0.86
			var rx := r * 0.66 * (1.0 - 0.12 * sin(a))      # narrower at the top
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry + r * 0.04))
		draw_colored_polygon(pts, Color("e8b84a"))
		var hi := PackedVector2Array()
		for p in pts: hi.append(c + (p - c) * 0.8 + Vector2(-r * 0.08, -r * 0.1))
		draw_colored_polygon(hi, Color("ffd36a"))
		draw_circle(c + Vector2(-r * 0.25, -r * 0.42), r * 0.12, Color(1, 1, 0.9, 0.55))
		var rng := RandomNumberGenerator.new(); rng.seed = int(spot.r * 991 + spot.g * 113 + spot.b * 7)
		for i in 6:
			var a := rng.randf_range(-PI, PI)
			var d := rng.randf_range(0.15, 0.5)
			draw_circle(c + Vector2(cos(a) * r * 0.5 * d * 1.6, sin(a) * r * 0.7 * d * 1.3 + r * 0.1), r * rng.randf_range(0.07, 0.12), spot)
		var ol := pts.duplicate(); ol.append(pts[0])
		draw_polyline(ol, Color(0.35, 0.22, 0.08, 0.8), 1.5, true)
