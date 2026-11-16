class_name ItemPages
extends RefCounted
## The Field Book's pages for shaping items (GardenItems): a grid of tiles under the Boki, one per item.
## An item you have owned shows its picture and name and opens its page (what it nudges, where it comes
## from, which Boki took it and what changed); one you haven't is a silhouette with no text. A family
## gets a star once every item of it has been owned. Reads GardenItems only; writes nothing.

const STAR := Color("f2c84a")
const PICTURE := 40.0

## The item's icon (Icons ids): its painted icon, else its family's glyph.
static func icon_of(id: String) -> String:
	if Icons.art("garden_" + id):
		return "garden_" + id
	var fam: String = GardenItems.item(id)["family"]
	return String(GardenItems.rules()["families"].get(fam, {}).get("icon", "gem"))

## The tiles, under a "Shaping items" heading. on_open(id) opens an item's page.
static func grid(v: VBoxContainer, on_open: Callable) -> void:
	v.add_child(UI.section("Shaping items", UI.FAINT.lightened(0.2)))
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for id in GardenItems.ids():
		g.add_child(tile(id, on_open))

## One tile in the Field Book's tile shape.
static func tile(id: String, on_open: Callable) -> Control:
	var have := GardenItems.owned(id)
	var t: PanelContainer
	if have:
		t = UI.tile_card(false, func(): on_open.call(id), 8)
		t.tooltip_text = GardenItems.item_name(id)
	else:
		t = UI.card(Color(1, 1, 1, 0.025), 8)
	t.custom_minimum_size = DexView.TILE
	var col := UI.vbox(2)
	t.add_child(col)
	var pic := CenterContainer.new()
	pic.custom_minimum_size = Vector2(0, DexView.PORTRAIT + 4)
	pic.add_child(UI.IconDot.new(icon_of(id), UI.GOLD if have else Color(0.05, 0.06, 0.1, 0.92), PICTURE))
	col.add_child(pic)
	if have:
		var nl := UI.label(GardenItems.item_name(id), UI.T_SMALL, UI.INK, UI.semi)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		col.add_child(nl)
	return t

## The page for one owned item, in the Boki page's layout: picture left, notes right.
static func detail(v: VBoxContainer, id: String) -> void:
	var it: Dictionary = GardenItems.item(id)
	var fam := String(it["family"])
	var row := UI.hbox(UI.GAP_BIG + 6)
	v.add_child(row)
	var stage := UI.card(Color(0, 0, 0, 0.22), 0, 16)
	stage.custom_minimum_size = Vector2(250, 290)
	stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var dc := CenterContainer.new()
	dc.add_child(UI.IconDot.new(icon_of(id), UI.GOLD, 120.0))
	stage.add_child(dc)
	row.add_child(stage)
	var info := UI.vbox(7)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var nrow := UI.hbox(10)
	nrow.add_child(UI.title(String(it["name"]), 26, UI.INK))
	info.add_child(nrow)
	var frow := UI.hbox(8)
	frow.add_child(UI.tag(GardenItems.family_name(fam), UI.MUTED))
	if GardenItems.family_done(fam):
		var star := UI.label("★", UI.T_HEAD, STAR)
		star.tooltip_text = "Every %s item found" % GardenItems.family_name(fam).to_lower()
		frow.add_child(star)
	info.add_child(frow)
	DexView._fact(info, "burst", "Nudges", GardenItems.nudge(id))
	DexView._fact(info, "pin", "Found", ", ".join(it["sources"]))
	var ul := UI.vbox(4)
	ul.add_child(UI.section("Taken by", UI.FAINT.lightened(0.2)))
	var uses: Array = GardenItems.uses(id)
	if uses.is_empty():
		ul.add_child(UI.label("Not used yet.", UI.T_SMALL, UI.MUTED))
	for u in uses:
		var line := UI.label("%s: %s" % [u["boki"], u["text"]], UI.T_SMALL, UI.INK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.add_child(line)
	info.add_child(ul)
