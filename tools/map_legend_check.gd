extends RefCounted
## --map-legend-check: the full map's key (MapLegend) names every icon the maps draw.
##   1. every kind has a distinct id and one plain word
##   2. every glyph function in the map code belongs to a kind in the key (a new icon fails until it has one)
##   3. in a match the key lists what the match has: its spawn categories, exits, places, squad
##   4. what a match does not have is not listed; shops and the Heart appear when they exist
##   5. every glyph draws, and the key fits inside the map at 1280x720, 1920x1080 and 2560x1080
## Never touches the save.

## Map glyph function -> the key kinds it draws. A function matching *_glyph, *_icon or *marker that is
## not listed here (or listed with a kind the key lacks) fails.
const GLYPHS := {
	"shrine_glyph": ["shrine"], "_exit_glyph": ["dock", "outpost", "hatch"],
	"_draw_exit_icon": ["dock", "outpost", "hatch"],
	"beacon_glyph": ["beacon"], "box_glyph": ["box"], "_lair_icon": ["lair"], "bounty_marker": ["bounty"],
	"marker": ["boss", "vault", "rare_kin", "cache"], "wisp_glyph": ["wisp"], "place_glyph": ["perch", "rail", "choke"],
	"heart_glyph": ["heart"], "gate_glyph": ["gate"], "spark_glyph": ["spark"], "crown": ["lead"],
}
const MAP_FILES := ["full_map", "hud", "revive_hud", "boki_hud", "outpost_glyph", "map_legend", "heart_hud"]
const SIZES := [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1080)]

var bad := 0
var _drew := 0

func ok(cond: bool, what: String) -> void:
	print("MAPLEGEND %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	_kinds()
	_source()
	await _match(main)
	print("MAP LEGEND CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _kinds() -> void:
	var ids: Array = MapLegend.KINDS.map(func(k): return k[0])
	var plain := RegEx.create_from_string("^[A-Za-z]{2,8}$")
	ok(ids.size() == MapLegend.KINDS.size() and not ids.has(""), "%d kinds in the key" % ids.size())
	var dup: Array = ids.filter(func(i): return ids.count(i) > 1)
	ok(dup.is_empty(), "every kind id is unique %s" % str(dup))
	var words: Array = MapLegend.KINDS.map(func(k): return k[1])
	ok(words.all(func(w): return plain.search(String(w)) != null), "every kind has one plain word")
	var same: Array = words.filter(func(w): return words.count(w) > 1)
	ok(same.is_empty(), "no two kinds share a word %s" % str(same))

func _source() -> void:
	var re := RegEx.create_from_string("(?m)^(?:static )?func (\\w*_glyph|\\w*_icon|\\w*_marker|marker)\\(")
	var found: Array = []
	for f in MAP_FILES:
		var src := FileAccess.get_file_as_string("res://scripts/ui/%s.gd" % f)
		for hit in re.search_all(src):
			found.append(hit.get_string(1))
	var ids: Array = MapLegend.KINDS.map(func(k): return k[0])
	var unlisted: Array = found.filter(func(n): return not GLYPHS.has(n))
	var covered: bool = not found.is_empty() and unlisted.is_empty()
	ok(covered, "every map glyph function has a kind (%d found) %s" % [found.size(), str(unlisted)])
	var lost: Array = []
	for n in GLYPHS:
		for k in GLYPHS[n]:
			if not ids.has(k):
				lost.append(k)
	ok(lost.is_empty(), "every kind a glyph function draws is in the key %s" % str(lost))

func _match(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	m.set_process(false)
	var ids: Array = MapLegend.present(m)
	print("MAPLEGEND this match: ", ", ".join(ids))
	var want: Array = ["you", "squad", "rival", "ping"]
	for cat in m.spawn_plan.shown_cats():
		want.append(cat)
	for x in m.exits.list:
		want.append(String(x["kind"]))
	for lb in m.world.labels:
		if lb["kind"] in ["perch", "rail", "choke"]:
			want.append(String(lb["kind"]))
	var missing: Array = want.filter(func(k): return not ids.has(k))
	ok(missing.is_empty(), "the key lists the squad, spawns, exits, places %s" % str(missing))
	var extra: Array = ids.filter(func(k): return not MapLegend.has(m, k) and not m.spawn_plan.shown_cats().has(k))
	ok(extra.is_empty(), "nothing is listed that the match lacks %s" % str(extra))
	ok(m.get("heart") != null or not ids.has("heart"), "no Heart, no Heart icon")
	ok(m.get("hot") != null or not ids.has("hot"), "no hot zone, no hot zone icon")
	ok(not ids.has("shop"), "no shops, no shop icon")
	m.set_meta("shops", {"list": [{"theme": "x"}]})
	ok(MapLegend.has(m, "shop"), "a match with shops lists them")
	m.remove_meta("shops")
	var fm: FullMap = m.hud.full_map
	var all: Array = MapLegend.KINDS.map(func(k): return String(k[0]))
	for cat in m.spawn_plan.cats:
		if not all.has(cat):
			all.append(cat)
	for sz in SIZES:
		fm._layout(sz)
		var inside: bool = fm.rect.grow(-1.0).encloses(MapLegend.panel(fm, all.size()))
		var box: Vector2 = MapLegend.panel(fm, all.size()).size
		var small: bool = box.x <= fm.rect.size.x * 0.6 and box.y <= fm.rect.size.y * 0.4
		ok(inside and small, "the full key (%d) sits inside the map in a corner at %dx%d" % [all.size(), sz.x, sz.y])
	m.hud.c.draw.connect(func():
		fm._layout(SIZES[0])
		MapLegend.draw(fm, all)
		_drew += 1)
	for i in 3:
		await main.get_tree().process_frame
	ok(_drew > 0, "every glyph in the key draws (%d frames)" % _drew)
	m.queue_free()
