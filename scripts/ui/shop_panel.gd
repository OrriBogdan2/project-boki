class_name ShopPanel
extends RefCounted
## The shop window: a vendor's stock as rows (icon, name, what it does, how many you own, price and
## a Buy button), under a header with the vendor's name and your run gems. Click Buy to purchase;
## the row flashes green on a sale and the button says why when you can't. The use key closes it.

const WIDTH := 520.0
const BELT_CLEAR := 170.0      # px kept free at the bottom for the belt and weapon slots
const FLASH_S := 0.5      # seconds a bought row glows

## Builds the panel on the HUD, beside the screen centre, and returns it.
static func open(m, v: Dictionary) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme = UI.theme()
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.custom_minimum_size.x = WIDTH
	var th := ShopStock.theme(String(v["theme"]))
	var col := Color(String(th["col"]))
	var frame := UiFrame.raised(Color(0.06, 0.065, 0.1, 0.96), UI.R_PANEL, 18, col)
	pc.add_theme_stylebox_override("panel", frame.padded(16, 14))
	m.hud.add_child(pc)
	m.hud.ui_extra.append(pc)
	_fill(m, pc, v, -1)
	var vs := pc.get_viewport_rect().size
	var top := minf(vs.y * 0.5 - 170.0, vs.y - BELT_CLEAR - pc.get_combined_minimum_size().y)
	pc.position = Vector2(vs.x * 0.5 + 90.0, maxf(60.0, top))
	UI.pop_in(pc)
	return pc

## Redraws the rows (after a sale, or a sale by another game) keeping the panel where it is.
static func refresh(m, pc: PanelContainer, v: Dictionary) -> void:
	_fill(m, pc, v, -1)

static func _fill(m, pc: PanelContainer, v: Dictionary, flash: int) -> void:
	for c in pc.get_children():
		c.queue_free()
	var th := ShopStock.theme(String(v["theme"]))
	var col := Color(String(th["col"]))
	var h = m.player
	var box := UI.vbox(8)
	pc.add_child(box)
	var head := UI.hbox(10)
	box.add_child(head)
	head.add_child(Icons.Glyph.new(String(th["icon"]), col, 26.0))
	var names := UI.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UI.title(String(th["name"]), 22, HudStyle.INK))
	names.add_child(UI.label(String(th["tag"]), 13, HudStyle.MUTED))
	head.add_child(names)
	head.add_child(Icons.Glyph.new("gem", HudStyle.GOLD, 18.0))
	head.add_child(UI.title("%d" % int(h.gems), 22, HudStyle.GOLD))
	box.add_child(UI.label("Spending gems here means fewer to extract.", 12, HudStyle.MUTED))
	for i in (v["rows"] as Array).size():
		box.add_child(_row(m, pc, v, i, i == flash))

static func _row(m, pc: PanelContainer, v: Dictionary, i: int, flash: bool) -> Control:
	var row: Dictionary = v["rows"][i]
	var h = m.player
	var col := ShopStock.col_of(row)
	var why := Shops.why_not(h, row)
	var cost := ShopStock.price(h, row)
	var card := UI.card(Color(col, 0.2 if flash else 0.07), 8, UI.R_SMALL)
	var line := UI.hbox(10)
	card.add_child(line)
	line.add_child(Icons.Glyph.new(ShopStock.icon_of(row), col, 28.0))
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(ShopStock.name_of(row), 15, HudStyle.INK, UI.semi))
	var info := UI.label(ShopStock.desc_of(row), 12, HudStyle.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 300.0
	text.add_child(info)
	var count := "%s  ·  %d left" % [ShopStock.owned_text(h, row), int(row["left"])]
	text.add_child(UI.label(count, 12, col.lightened(0.2)))
	line.add_child(text)
	var label := why if why != "" else "%d" % cost
	if flash:
		label = "Bought!"
	var buy := UI.button(label, Callable(), 96.0, "" if why != "" or flash else "gem")
	buy.pressed.connect(func(): buy_row(m, pc, v, i))      # no click: the buy or refusal is the sound
	buy.disabled = why != "" and why != ShopStock.BROKE      # short of gems stays clickable for the tick
	buy.tooltip_text = why
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(buy)
	return card

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
