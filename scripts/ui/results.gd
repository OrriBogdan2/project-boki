extends Control
## After a match: what you brought home, what your kin thinks, and the way back to the farm.
## The first view shows only what's needed (briefs/DECISIONS.md 2026-11-08): the outcome and how, your Boki,
## the loot you kept, any Hunter news, and More next to the way home. The match's numbers and every note are
## behind More (--results-first-check).

const FOES_TIP := "Enemy hunters you put on the ground this match."      # hover on "Foes downed"
const SAD := Color("ffb36a")      # trust that went down

var groups: VBoxContainer      # the first view: one child per group
var more: VBoxContainer        # behind More: the numbers and the notes
var more_btn: Button
var home_btn: Button
var scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_result(r: Dictionary) -> void:
	Sfx.play_music("title")
	Sfx.play_ambience("")
	shown_at = Time.get_ticks_msec()
	var s := Game.apply_result(r)
	s["kin_say"] = String(r.get("kin_say", ""))     # what your Boki said as the run ended
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_stage(r, s)
	var won: bool = r.get("extracted", false)
	add_child(_wash())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 340.0   # leave the left side for the island
	add_child(center)
	var panel := UI.sheet(600)
	center.add_child(panel)
	UI.pop_in(panel, 0.1)
	var outer := UI.vbox(14)
	panel.add_child(outer)
	outer.add_child(_scroller())
	groups.add_child(_outcome(r, s, won))
	for g in [_boki(s), _loot(s, won), ClassCard.results_strip(s)]:
		if g != null:
			groups.add_child(g)
	_fill_more(r, s)
	outer.add_child(_bottom(r))
	home_btn.grab_focus()
	if won:
		Sfx.play("bond", null, -6.0, 0.0, 1.0)
	else:
		Sfx.play("fall", null, -6.0, 0.0, 0.8)

## A dark wash from the right so the card sits apart from the island.
func _wash() -> TextureRect:
	var gr := Gradient.new()
	gr.set_color(0, Color(0.03, 0.02, 0.07, 0.0))
	gr.set_color(1, Color(0.03, 0.02, 0.07, 0.82))
	gr.set_offset(0, 0.25)
	gr.set_offset(1, 0.7)
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_to = Vector2(1, 0)
	gt.width = 256
	gt.height = 4
	var wash := TextureRect.new()
	wash.texture = gt
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return wash

## The first view and More scroll if they're taller than the window; the way home stays below them.
func _scroller() -> ScrollContainer:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var v := UI.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(v)
	groups = UI.vbox(10)
	v.add_child(groups)
	more = UI.vbox(6)
	more.visible = false
	v.add_child(more)
	var sc := scroll      # (a local, so a fit still queued after the screen is gone sees it freed)
	var fit := func() -> void:
		if is_instance_valid(sc) and sc.is_inside_tree():
			var room := sc.get_viewport_rect().size.y - 200.0
			sc.custom_minimum_size.y = minf(pad.get_combined_minimum_size().y, room)
	v.minimum_size_changed.connect(func(): fit.call_deferred())
	sc.tree_entered.connect(func(): fit.call_deferred())
	return scroll

## Made it out or not, then how: the Heart, an exit, or where your squad placed and what that paid.
func _outcome(r: Dictionary, s: Dictionary, won: bool) -> Control:
	var head := UI.vbox(4)
	var hunter := String(Save.d.get("name", "Hunter")).substr(0, 16)
	head.add_child(UI.title("%s made it out" % hunter if won else _lost_title(r.get("why", "")), 46, UI.INK))
	_line(head, WaysResult.how_line(r).strip_edges(), UI.MUTED)
	if int(s.get("place_gems", 0)) > 0:
		_line(head, "Placement pay: %d gems" % int(s["place_gems"]), UI.GOLD)
	_line(head, WaysResult.hid_line(r), UI.MUTED)
	if won and s.has("heart"):
		_line(head, WaysResult.reward_line(s["heart"]), UI.GOLD)
	if r.get("tutorial", false):
		_line(head, "That's the basics. Now come see your home.", UI.ACCENT_HI)
	return head

## One plain line on the first view; nothing when `txt` is empty.
func _line(box: Control, txt: String, col: Color) -> void:
	if txt != "":
		box.add_child(UI.label(txt, UI.T_BODY, col))

## Your Boki's outcome: the one you took (trust, a level, a new form), then any left behind, taken back,
## waiting on the farm or let go on credit. Null when there is no Boki news.
func _boki(s: Dictionary) -> Control:
	var lines: Array = []      # [text, colour]
	for ln in s.get("lost_news", []):
		lines.append([WaysResult.boki_line(ln), UI.BAD if String(ln["fate"]) == "rival" else UI.GOOD])
	for back in s.get("rescued", []):
		lines.append(["You took %s back. It's home again." % back["name"], UI.GOOD])
	for fe in s.get("floor", []):
		if String(fe.get("kind", "")) == "stray":
			var sp := String(Data.KIN[String(fe["rec"]["species"])]["name"])
			lines.append(["A stray %s is waiting on your farm. It's yours." % sp, UI.GOOD])
	if s.get("kin_stranded", false):
		lines.append(["%s let one of your Boki go on credit. It trusts you less." % Ransom.BROKER, UI.BAD])
	if not s.has("kin") and lines.is_empty():
		return null
	var card := UI.card(UI.CARD, 14, 14)
	var kv := UI.vbox(6)
	card.add_child(kv)
	if s.has("kin"):
		_kin_rows(kv, s)
	for ln in lines:
		kv.add_child(UI.label(String(ln[0]), UI.T_BODY, ln[1]))
	return card

## The Boki you took: name and level (or the level it just grew to), trust sliding to where it ended up,
## and a new form.
func _kin_rows(kv: VBoxContainer, s: Dictionary) -> void:
	var k: Dictionary = s["kin"]
	var sp: Dictionary = Data.KIN.get(String(k.get("species", "")), {})
	var top := UI.hbox(10)
	kv.add_child(top)
	top.add_child(Icons.Glyph.new("paw", sp.get("color", UI.ACCENT), 22.0))
	top.add_child(UI.title(String(k["name"]), 24, UI.INK))
	var lvl := UI.label("level %d %s" % [int(k["level"]), String(sp.get("name", ""))], UI.T_BODY, UI.MUTED)
	if s["levelup"]:
		lvl.text = "grew to level %d!" % int(k["level"])
		lvl.add_theme_color_override("font_color", UI.GOLD)
	lvl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lvl)
	var td: float = s.get("trust_delta", 0.0)
	var trow := UI.hbox(10)
	kv.add_child(trow)
	var tl := UI.label("Trust", UI.T_SMALL, UI.MUTED)
	tl.custom_minimum_size.x = 46
	trow.add_child(tl)
	var now := clampf(float(k["trust"]) / 100.0, 0.0, 1.0)
	var was := clampf((float(k["trust"]) - td) / 100.0, 0.0, 1.0)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(240, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frac := {"v": was}
	var fill_col := UI.GOOD if td >= 0.0 else SAD
	bar.draw.connect(func():
		var full := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(full, Color(0, 0, 0, 0.4))
		bar.draw_rect(Rect2(full.position, Vector2(full.size.x * float(frac["v"]), full.size.y)), fill_col))
	trow.add_child(bar)
	var mood := _mood(td)
	trow.add_child(UI.label(String(mood[0]), UI.T_BODY, mood[1]))
	var slide := func(x: float) -> void:
		frac["v"] = x
		bar.queue_redraw()
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_method(slide, was, now, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if s["levelup"]:
		tw.tween_callback(func():
			Sfx.play("unlock", null, -4.0)
			UI.pop_in(lvl))
	for et in s.get("evo", []):
		kv.add_child(UI.label(et, UI.T_BODY, Color("c9a0ff")))

## How the Boki feels about you after the run, from the trust change: [words, colour].
static func _mood(td: float) -> Array:
	if td > 0.5:
		return ["trusts you more  (%+d)" % roundi(td), UI.GOOD]
	if td < -0.5:
		return ["trusts you less  (%+d)" % roundi(td), SAD]
	return ["feels the same about you", UI.MUTED]

## The loot you kept as one row of chips. After a loss: that it stays out there, and what your deathbox
## holds. Null when you made it out with nothing.
func _loot(s: Dictionary, won: bool) -> Control:
	var chips := _kept(s) if won else _lost(s)
	if won and chips.is_empty():
		return null
	var box := UI.vbox(8)
	box.add_child(UI.section("Brought home" if won else "Lost"))
	if not won:
		box.add_child(UI.label("Everything you carried stays out in the islands.", UI.T_BODY, UI.MUTED))
	if not chips.is_empty():
		box.add_child(_chip_row(chips))
	var gear := (s.get("haul", []) as Array).any(func(it): return not Loot.is_rare_egg(it))
	if won and gear and not Save.has_building("armory"):
		box.add_child(UI.label("Build an armory on your farm to use them.", UI.T_SMALL, UI.MUTED))
	return box

## Chips that pop in one after another, wrapping onto more rows if they need to.
func _chip_row(chips: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for i in chips.size():
		var spec: Array = chips[i]
		var ch := _chip(spec[0], spec[1], spec[2], 0.75 + i * 0.12)
		var krec: Dictionary = spec[3]
		if not krec.is_empty():
			# a Boki you brought home: where it went
			var boxed := KinBox.is_boxed(krec)
			var went := UI.label("·  Boki Burrow" if boxed else "·  farm", UI.T_SMALL, UI.GOOD)
			if boxed:
				went.add_theme_color_override("font_color", Color("bfa6ff"))
			(ch.get_child(0) as HBoxContainer).add_child(went)
		flow.add_child(ch)
	return flow

## What came home with you as chips, [icon, text, colour, the Boki record or {}]: a Rare Egg first, then
## gems, seeds, the Boki you caught, weapons and gloves.
func _kept(s: Dictionary) -> Array:
	var chips: Array = []
	var haul: Array = s.get("haul", [])
	for it in haul.filter(func(e): return Loot.is_rare_egg(e)):
		chips.append(["egg", Loot.name_of(it), Color("ffd36a"), {}])
	if int(s["gems"]) > 0:
		chips.append(["gem", "%d gems" % s["gems"], UI.GOLD, {}])
	for sd in s["seeds"]:
		var crop: Dictionary = Data.CROPS[sd]
		var n := int(s["seeds"][sd])
		var what := "%d %s %s to plant" % [n, crop["name"], "seed" if n == 1 else "seeds"]
		chips.append(["seed", what, crop["color"], {}])
	for k in s["caught"]:
		var sp: Dictionary = Data.KIN[k["species"]]
		var rare := " ".join(Mutations.tags(k))
		var what := Data.kin_title(String(k["name"]), String(sp["name"]))
		if rare != "":
			what = "%s the %s %s" % [k["name"], rare, sp["name"]]
		chips.append(["egg", what, sp["color"], k])
	for it in haul.filter(func(e): return not Loot.is_rare_egg(e)):
		chips.append([Loot.icon_of(it), Loot.name_of(it) + _fate_note(it), Loot.col_of(it), {}])
	return chips

## What a loss left in your deathbox, as chips.
func _lost(s: Dictionary) -> Array:
	var lost: Array = s.get("lost_items", [])
	return lost.map(func(it): return [Loot.icon_of(it), Loot.name_of(it), Color("ffb0a0"), {}])

## Behind More: the match's numbers, then what your Boki made of it, then every note.
func _fill_more(r: Dictionary, s: Dictionary) -> void:
	more.add_child(UI.section("Your match"))
	more.add_child(_numbers(r))
	if s.has("kin"):
		var k: Dictionary = s["kin"]
		if String(s.get("trust_why", "")) != "":
			more.add_child(_note(String(s["trust_why"]), UI.GOOD))
		if String(s["kin_say"]) != "":
			more.add_child(_note("%s said: “%s”" % [k["name"], s["kin_say"]], UI.INK))
		var mem: Array = k["memory"]
		if not mem.is_empty():
			more.add_child(_note("Remembers: " + String(mem[-1]["text"]), Color(UI.MUTED, 0.9)))
	if s.has("heart") and WaysResult.other_line(String(r.get("how", ""))) != "":
		more.add_child(_note(WaysResult.other_line(String(r["how"])), UI.MUTED))
	for nt in _notes(s):
		more.add_child(_note(String(nt[0]), nt[1]))

## The match's numbers as label and value pairs, two pairs to a row.
func _numbers(r: Dictionary) -> GridContainer:
	var secs := int(r.get("time", 0))
	var where := String(Data.TIERS[clampi(Game.last_tier, 0, Data.TIERS.size() - 1)]["name"])
	var rows := [["Foes downed", int(r.get("knocks", 0))], ["Kills", int(r.get("kills", 0))],
		["Damage dealt", int(r.get("damage", 0))], ["Damage taken", int(r.get("taken", 0))],
		["Time", "%d:%02d" % [secs / 60, secs % 60]], ["Times downed", int(r.get("downs", 0))],
		["Where", where], ["Revives", int(r.get("revives", 0))]]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for row in rows:
		var what := UI.label(String(row[0]), UI.T_BODY, UI.MUTED)
		if row[0] == "Foes downed":
			what.tooltip_text = FOES_TIP
			what.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(what)
		grid.add_child(UI.label(str(row[1]), UI.T_BODY, UI.INK, UI.semi))
	return grid

## Every note for More, [text, colour]: where caught Boki and Rare Eggs went, what was salvaged or sold,
## the ransom, market and Exchange news, the vault, the crops.
func _notes(s: Dictionary) -> Array:
	var out: Array = []
	var boxed: Array = (s["caught"] as Array).filter(func(k): return KinBox.is_boxed(k))
	if not boxed.is_empty():
		var why := "You already have that kind out on the farm."
		if not boxed.all(func(k): return KinBox.dup_on_farm(k)):
			why = "The farm is full (%d/%d)." % [KinBox.farm_cap() - KinBox.farm_room(), KinBox.farm_cap()]
		var names := ", ".join(boxed.map(func(k): return String(k["name"])))
		out.append(["Sent to the Boki Burrow: %s. %s" % [names, why], Color("cdb8ff")])
	var eggs := (s.get("haul", []) as Array).filter(func(it): return Loot.is_rare_egg(it)).size()
	if eggs == 1:
		out.append(["Your Rare Egg went to the Incubator by the Nesting Nook, to hatch into a rare Boki.", UI.GOLD])
	elif eggs > 1:
		out.append(["Your %d Rare Eggs went to the Incubator by the Nesting Nook and hatch one at a time." % eggs,
				UI.GOLD])
	if int(s.get("salvage_gems", 0)) > 0:
		out.append(["Armor isn't kept: what you found salvaged for %d gems." % int(s["salvage_gems"]), UI.GOLD])
	if int(s.get("arm_sold", 0)) > 0:
		out.append(["Your armory was full: what didn't fit sold for %d gems." % int(s["arm_sold"]), UI.GOLD])
	for nw in s.get("ransom_news", []):
		out.append([String(nw), Color("ffd58a")])
	for line in s.get("market_news", []):
		out.append([String(line), UI.GOLD])
	var fills: Array = s.get("exchange_fills", [])
	if not fills.is_empty():
		out.append(["%d of your Exchange offers filled while you were out." % fills.size(), UI.GOLD])
	if int(s.get("vault_gems", 0)) > 0:
		out.append(["Your vault kept %d of the gems you dropped." % int(s["vault_gems"]), UI.GOLD])
	var crops := int(s["crops_ready"])
	if crops > 0:
		out.append(["%d crop%s ready to harvest on your farm." % [crops, "s" if crops > 1 else ""], UI.GOOD])
	return out

## Always on screen under the card: More, then the way home.
func _bottom(r: Dictionary) -> HBoxContainer:
	var row := UI.hbox(14)
	more_btn = UI.button("More ▾", _toggle_more)
	more_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(more_btn)
	row.add_child(UI.fill())
	var go_txt := "Go home" if r.get("tutorial", false) else "Back to the farm"
	home_btn = UI.with_key(UI.primary(go_txt, func(): Game.goto("home"), 250, "home"), "Enter")
	row.add_child(home_btn)
	return row

## More opens under the first view and scrolls its first line to the top; pressed again it closes.
func _toggle_more() -> void:
	more.visible = not more.visible
	more_btn.text = "Less ▴" if more.visible else "More ▾"
	if more.visible:
		await get_tree().process_frame
		scroll.scroll_vertical = int(more.global_position.y - groups.global_position.y)

## One thing you brought home, as a little pill that pops in with a sound.
func _chip(icon: String, txt: String, col: Color, delay: float) -> Control:
	var c := UI.card(Color(col, 0.14), 8, 999)
	var h := UI.hbox(7)
	c.add_child(h)
	h.add_child(Icons.Glyph.new(icon, col.lightened(0.15), 18.0))
	var l := UI.label(txt, UI.T_BODY, UI.INK, UI.semi)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		Sfx.play("pickup", null, -8.0, 0.08, 1.0 + delay * 0.1)
		UI.pop_in(c))
	return c

func _note(txt: String, col: Color) -> Label:
	var l := UI.label(txt, UI.T_BODY, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

var shown_at := 0
## Enter, Space or Esc also takes you home, so you can never get stuck on this screen.
func _unhandled_input(e: InputEvent) -> void:
	if Time.get_ticks_msec() - shown_at < 900:
		return
	if e.is_action_pressed("ui_accept") or e.is_action_pressed("menu") or e.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		Game.goto("home")

var hunter_node: Node3D
var h_anim: HunterAnim
var kin_node: Node3D
var won_k := false
var t := 0.0

## Behind the card: your hunter and kin on a little island, cheering if you made it out,
## sitting it out if you didn't.
func _stage(r: Dictionary, s: Dictionary) -> void:
	won_k = r.get("extracted", false)
	var svc := SubViewportContainer.new(); svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	var w3 := Node3D.new(); vp.add_child(w3)
	var env := WorldEnvironment.new(); env.environment = Look.environment({}); w3.add_child(env)
	if not won_k:
		Look.night(env.environment, 0.6)
	Look.lights(w3, Color("fff1d8") if won_k else Color("b9c4ff"), 1.05 if won_k else 0.7)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var isl := Models.float_island(rng, 2.6, 5.0, Color("6aa64a"), Color("9a7a5a"), Color("3a2f48"))
	w3.add_child(isl)
	var tr := Models.tree(rng, Color("5a9a4f"), "round"); tr.position = Vector3(-1.4, 0, -1.2); w3.add_child(tr)
	var rk := Models.rock(rng, 0.7); rk.position = Vector3(1.5, 0, -0.9); w3.add_child(rk)
	hunter_node = Models.hunter(Data.class_of_save(), Data.TEAM_COLORS[0], Arch.weapon_for(Arch.of_save(), Data.class_of_save(), String(Save.d.get("weapon", ""))), "", Unmasked.mask_look(), Arch.of_save())
	hunter_node.position = Vector3(-0.3, 0, 0.3); hunter_node.rotation.y = PI + 0.5
	var ring := hunter_node.get_node_or_null("TeamRing") as Node3D
	if ring: ring.visible = false
	w3.add_child(hunter_node)
	h_anim = HunterAnim.new(hunter_node)
	if s.has("kin") and won_k:
		kin_node = Models.kin(String(s["kin"]["species"]), s["kin"])
		kin_node.position = Vector3(0.75, 0, 0.6); kin_node.rotation.y = PI + 0.9
		kin_node.set_meta("happy", true)
		w3.add_child(kin_node)
	var cam := Camera3D.new(); cam.fov = 40
	# the island sits left of the results card
	cam.position = Vector3(4.6, 2.6, 8.4)
	w3.add_child(cam)
	cam.look_at(Vector3(3.3, 0.6, 0))

func _process(dt: float) -> void:
	t += dt
	if h_anim:
		var vy := 0.0
		if won_k:
			# a little victory hop every couple of seconds
			var ph := fmod(t, 2.2)
			hunter_node.position.y = maxf(0.0, sin(ph / 0.5 * PI)) * 0.35 if ph < 0.5 else 0.0
			vy = cos(ph / 0.5 * PI) * 2.0 if ph < 0.5 else 0.0
		h_anim.update(dt, {"grounded": hunter_node.position.y < 0.01, "vel": Vector3(0, vy, 0), "crouch": 0.0 if won_k else 0.7, "downed": false})
	if kin_node:
		kin_node.get_node("Body").position.y = absf(sin(t * 5.0)) * 0.25

func _lost_title(why: String) -> String:
	match why:
		"abyss": return "You fell"
		"train": return "Hit by the Sky Train"
		"left": return "You left the match"
	return "Knocked out"

## What happened to a hauled piece on arrival: sold (the armory was full), salvaged (armor), or kept.
func _fate_note(it: Dictionary) -> String:
	if it.get("sold", false):
		return "  (sold)"
	if it.get("salvaged", false):
		return "  (salvaged)"
	return ""
