class_name HunterStatsView
extends RefCounted
## The Stats tab beside Relics on the farm's Relics screen: one plain table, a row per Hunter you own
## or have played (most played first, never-played ones greyed) and the totals. Numbers: HunterStats.

const TABS := ["Relics", "Stats"]
const HEADS := ["Hunter", "Matches", "Knocks", "Revives", "Damage / match", "Got out"]
const NAME_W := 200.0       # px, the Hunter column
const COL_W := 120.0        # px, each number column

## The Relics | Stats tabs both pages show at the top.
static func tabs(home: Node, cur: String) -> Control:
	return UI.tabs(TABS, cur, func(nm): open(home) if nm == "Stats" else HomeClasses.open(home), {}, 110)

static func open(home: Node) -> void:
	var v: VBoxContainer = home._new_panel(HomeClasses.TITLE, 1210, true)
	v.add_child(tabs(home, "Stats"))
	UI.subtitle(v, "How you do with each Hunter, counted over every expedition.")
	var rs := HunterStats.rows()
	v.add_child(table(rs))
	if HunterStats.totals(rs)["matches"] == 0:
		v.add_child(UI.para("Play an expedition and its numbers show up here."))

static func table(rs: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = HEADS.size()
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for h in HEADS:
		_cell(grid, String(h), UI.MUTED, UI.caps, UI.T_CAPS)
	for r in rs:
		_row(grid, r, Arch.name_of(String(r["id"])), false)
	_row(grid, HunterStats.totals(rs), "Total", true)
	return grid

static func _row(grid: GridContainer, r: Dictionary, title: String, total: bool) -> void:
	var col := UI.INK if total or int(r["matches"]) > 0 else UI.FAINT
	var font: Font = UI.semi if total else null
	var dpm := HunterStats.per_match(r)
	var cells := [title, r["matches"], r["knocks"], r["revives"], "-" if dpm < 0 else str(dpm), r["outs"]]
	for c in cells:
		_cell(grid, str(c), col, font, UI.T_BODY)

static func _cell(grid: GridContainer, text: String, col: Color, font: Font, px: int) -> void:
	var l := UI.label(text, px, col, font)
	l.custom_minimum_size.x = NAME_W if grid.get_child_count() % grid.columns == 0 else COL_W
	grid.add_child(l)
