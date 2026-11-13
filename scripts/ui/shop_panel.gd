class_name ShopPanel
extends RefCounted
## The shop window: the vendor's name with its fixed set under it and your run gems, then one row per
## item: icon, name, one plain line from live data (ShopStock.line_of) and the price as a Buy button.
## A row you can't buy is greyed and says why in the price slot ("Need 35" gems, "Sold out", ...).
## The rows scroll when they don't fit; the panel stays inside the safe margin at every window size
## and clear of the belt. The row flashes green on a sale. The use key (or walking off) closes it.

const WIDTH := 540.0
const SIDE := 60.0          # px right of the screen centre the panel starts (the hunter stays in view)
const TOP := 60.0           # px kept free at the top for the match bar
const BELT_CLEAR := 170.0   # px kept free at the bottom for the belt and weapon slots
const SAFE_MARGIN := 12.0   # px kept clear on every side (the same margin as ext/ui-safe-area's SafeArea)
const FLASH_S := 0.5        # seconds a bought row glows
const GREY := Color(0.62, 0.62, 0.66, 0.6)      # modulate of a row you can't buy
const SHORT_COL := Color("ff9a7a")

## Builds the panel on the HUD, beside the screen centre, and returns it.
static func open(m, v: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.custom_minimum_size.x = WIDTH
	var col := Color(String(ShopStock.theme(String(v["theme"]))["col"]))
	var frame := UiFrame.raised(Color(0.06, 0.065, 0.1, 0.96), UI.R_PANEL, 18, col)
	pc.add_theme_stylebox_override("panel", frame.padded(16, 14))
	m.hud.add_child(pc)
	m.hud.ui_extra.append(pc)
	_fill(m, pc, v, -1)
	UI.pop_in(pc)
	return pc

## Redraws the rows (after a sale, or a sale by another game).
static func refresh(m, pc: PanelContainer, v: Dictionary) -> void:
	_fill(m, pc, v, -1)

## Where the panel goes for this screen size, and how tall its list may be.
static func place(pc: PanelContainer, scroll: ScrollContainer, list: Control) -> void:
	var vs := pc.get_viewport_rect().size
	var room := vs.y - TOP - BELT_CLEAR
	scroll.custom_minimum_size.y = 0.0
	var chrome := pc.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(list.get_combined_minimum_size().y, room - chrome)
	pc.size = pc.get_combined_minimum_size()
	var x := clampf(vs.x * 0.5 + SIDE, SAFE_MARGIN, vs.x - SAFE_MARGIN - pc.size.x)
	var y := clampf(vs.y * 0.5 - 170.0, TOP, vs.y - BELT_CLEAR - pc.size.y)
	pc.position = Vector2(x, maxf(SAFE_MARGIN, y))

static func _fill(m, pc: PanelContainer, v: Dictionary, flash: int) -> void:
	for c in pc.get_children():
		pc.remove_child(c)
		c.queue_free()
	var box := UI.vbox(8)
	pc.add_child(box)
	box.add_child(_head(m, v))
	var list := UI.vbox(6)
	for i in (v["rows"] as Array).size():
		list.add_child(_row(m, pc, v, i, i == flash))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	box.add_child(scroll)
	var foot := UI.hbox(12)
	foot.add_child(UI.key_hints([[Settings.key_cap("interact"), "close"]], 12))
	foot.add_child(UI.label("Gems you spend here don't go home.", 12, HudStyle.MUTED))
	box.add_child(foot)
	place(pc, scroll, list)

## The vendor's icon and name, its fixed set under the name, and the hunter's run gems.
static func _head(m, v: Dictionary) -> Control:
	var th := ShopStock.theme(String(v["theme"]))
	var col := Color(String(th["col"]))
	var head := UI.hbox(10)
	head.add_child(Icons.Glyph.new(String(th["icon"]), col, 26.0))
	var names := UI.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UI.title(String(th["name"]), 22, HudStyle.INK))
	names.add_child(UI.label("%s, the same every match" % String(th["tag"]), 13, col.lightened(0.15)))
	head.add_child(names)
	head.add_child(Icons.Glyph.new("gem", HudStyle.GOLD, 18.0))
	head.add_child(UI.title("%d" % int(m.player.gems), 22, HudStyle.GOLD))
	return head

static func _row(m, pc: PanelContainer, v: Dictionary, i: int, flash: bool) -> Control:
	var row: Dictionary = v["rows"][i]
	var h = m.player
	var col := ShopStock.col_of(row)
	var why := Shops.why_not(h, row)
	var card := UI.card(Color(col, 0.2 if flash else 0.07), 6, UI.R_SMALL)
	card.name = "Row%d" % i
	var line := UI.hbox(10)
	card.add_child(line)
	var icon := Icons.Glyph.new(ShopStock.icon_of(row), col, 26.0)
	line.add_child(icon)
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(ShopStock.name_of(row), 15, HudStyle.INK, UI.semi))
	var plain := ShopStock.line_of(h, row)
	var info := UI.label(plain, 12, HudStyle.MUTED)
	info.name = "Line"
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.tooltip_text = plain
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_child(info)
	line.add_child(text)
	line.add_child(_price(m, pc, v, i, why, flash))
	if why != "":
		icon.modulate = GREY
		text.modulate = GREY
	return card

## The price slot: a Buy button with the price, "Bought!" for a moment after a sale, or (greyed row)
## the missing gem count or the reason it can't be bought.
static func _price(m, pc: PanelContainer, v: Dictionary, i: int, why: String, flash: bool) -> Control:
	var row: Dictionary = v["rows"][i]
	var cost := ShopStock.price(m.player, row)
	var slot: Control
	if flash:
		slot = UI.button("Bought!", Callable(), 92.0)
	elif why == ShopStock.NO_GEMS:
		slot = UI.chip("gem", "Need %d" % (cost - int(m.player.gems)), SHORT_COL, why, 13)
		slot.gui_input.connect(func(e: InputEvent):      # a click here answers with the refused tick
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				buy_row(m, pc, v, i))
	elif why != "":
		slot = UI.chip("", why, HudStyle.MUTED, "", 13)
	else:
		slot = UI.button("%d" % cost, Callable(), 92.0, "gem")
		(slot as Button).pressed.connect(func(): buy_row(m, pc, v, i))      # no click: the buy is the sound
	slot.name = "Price"
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.custom_minimum_size.x = 92.0
	return slot

## One Buy click: the sale, the feedback and a green flash on the row.
static func buy_row(m, pc: PanelContainer, v: Dictionary, i: int) -> void:
	var why := Shops.buy(m, m.player, v, i)
	if why != "":
		ShopSfx.refused()
		m.hud.toast_small(why, Color("ff8a6a"))
		return
	_fill(m, pc, v, i)
	var tw := pc.create_tween()      # dies with the panel, so closing it mid-flash calls nothing
	tw.tween_interval(FLASH_S)
	tw.tween_callback(func(): _fill(m, pc, v, -1))
