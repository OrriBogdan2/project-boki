class_name ItemPreviewCard
extends RefCounted
## The hold-to-preview card (briefs/design/GARDEN_MODERN.md 1.3): an item held near a Boki, or hovered in its feed
## menu, slides this card in with every change the item would make drawn as a ghost. It does no preview math of its
## own: the numbers are GardenItems.preview (after caps), the path meter is EvoPath.pips on GardenItems.after, the
## budget is StatBudget's. ItemHold owns one card and shows or hides it.

const W := 420.0                              # px: card width
const EDGE := 18.0                            # px: gap to the right screen edge
const SLIDE_S := 0.18                         # s: slide in or out
const RING_PX := 46.0                         # px: budget and lean rings
const RING_W := 6.0                           # px: ring stroke
const GHOST_A := 0.45                         # alpha of a ghost (the part that would change)
const DOWN := Color("e07a6a")                 # a value that would drop

var host: Node                                # the screen layer the card sits on
var card: PanelContainer = null
var key := ""                                 # what it shows now: "<uid>:<item>:<pick>"

func _init(on: Node) -> void:
	host = on

## Shows the card for item `id` on rec (slides in; the same Boki and item again changes nothing).
func show_for(rec: Dictionary, id: String, pick := "") -> void:
	var want := "%s:%s:%s" % [rec.get("uid", ""), id, pick]
	if want == key and card != null:
		return
	close()
	key = want
	card = build(rec, id, pick)
	card.custom_minimum_size.x = W
	host.add_child(card)
	var view := host.get_viewport().get_visible_rect().size
	card.position = Vector2(view.x, maxf(EDGE, (view.y - card.get_combined_minimum_size().y) * 0.5))
	var to := view.x - W - EDGE
	var tw := card.create_tween()
	tw.tween_property(card, "position:x", to, SLIDE_S).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

## Slides the card out and frees it.
func close() -> void:
	key = ""
	if card == null:
		return
	var old := card
	card = null
	var tw := old.create_tween()
	tw.tween_property(old, "position:x", host.get_viewport().get_visible_rect().size.x, SLIDE_S)
	tw.tween_callback(old.queue_free)

func showing() -> bool:
	return card != null

## The card for item `id` on rec: head, the preview line, ghost stat bars, budget and lean rings, the path meter
## (branching lines only) and a Why? list of its pips.
static func build(rec: Dictionary, id: String, pick := "") -> PanelContainer:
	var pv := GardenItems.preview(rec, id, pick)
	var then := GardenItems.after(rec, pv)
	var p := UI.card()
	var v := UI.vbox(6)
	p.add_child(v)
	var kind := String(Data.KIN.get(String(rec["species"]), {}).get("name", String(rec["species"]).capitalize()))
	v.add_child(UI.label("%s  the %s   Lv %d" % [rec["name"], kind, int(rec["level"])], 16))
	var held := "Nature: %s     holding: %s" % [Care.nature(rec), GardenItems.item_name(id)]
	v.add_child(UI.label(held, UI.T_SMALL, UI.MUTED))
	v.add_child(UI.para(String(pv["text"]), 14, UI.INK if pv["ok"] else DOWN))
	for s in Care.STATS:
		v.add_child(_stat_row(rec, then, s, id))
	v.add_child(_rings(rec, then))
	if not EvoPath.line(rec).is_empty():
		_path(v, rec, then, id)
	return p

static func _stat_row(rec: Dictionary, then: Dictionary, s: String, id: String) -> Control:
	var info: Dictionary = Care.STATS[s]
	var top := float(StatBudget.rules()["cap_max"])
	var was := int(rec["stats"][s])
	var now := int(then["stats"][s])
	var r := UI.hbox(8)
	var l := UI.label(String(info["name"]), UI.T_SMALL, UI.MUTED)
	l.custom_minimum_size.x = 64.0
	r.add_child(l)
	r.add_child(ghost_bar(was / top, now / top, info["col"]))
	r.add_child(UI.label(_gain(was, now, id), 12, UI.MUTED if now == was else UI.INK, UI.semi))
	return r

## "46", or the change with the real number: "38 +2" and, when a cap took some, "(of +3, level cap)".
static func _gain(was: int, now: int, id: String) -> String:
	if now == was:
		return str(was)
	var t := "%d %+d" % [was, now - was]
	var asked := int(GardenItems.item(id)["effect"].get("n", 0))
	if now > was and now - was < asked:
		t += " (of +%d, level cap)" % asked
	return t

## A bar of `was` filled, with the part that would change drawn as a ghost (a drop dims the part that goes).
static func ghost_bar(was: float, now: float, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(170, 9)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var ghost := Color(col if now >= was else DOWN, GHOST_A)
		UI.draw_bar(c, r, maxf(was, now), ghost)
		UI.draw_bar(c, r, minf(was, now), col, Color(0, 0, 0, 0)))
	return c

static func _rings(rec: Dictionary, then: Dictionary) -> Control:
	var row := UI.hbox(10)
	var total := float(StatBudget.rules()["total_cap"])
	var spent := [StatBudget.total(rec), StatBudget.total(then)]
	row.add_child(_ring(spent[0] / total, spent[1] / total, UI.GOLD))
	var words := "Budget %d of %d" % [spent[0], int(total)]
	if spent[1] != spent[0]:
		words = "Budget %d to %d of %d" % [spent[0], spent[1], int(total)]
	row.add_child(UI.label(words, UI.T_SMALL, UI.MUTED))
	var t := _lean_type(rec, then)
	if t == "":
		row.add_child(UI.label("Lean: none", UI.T_SMALL, UI.FAINT))
		return row
	var full := Evo.LEAN_FULL
	var face := Lean.face(t)
	var was := float(rec.get("lean", {}).get(t, 0.0))
	var now := float(then.get("lean", {}).get(t, 0.0))
	row.add_child(_ring(was / full, now / full, face["tint"]))
	var lw := "Lean %s %d%%" % [face["name"], roundi(100.0 * was / full)]
	if absf(now - was) > 0.01:
		lw += " to %d%%" % roundi(100.0 * now / full)
	row.add_child(UI.label(lw + (" (full)" if now >= full else ""), UI.T_SMALL, UI.MUTED))
	return row

## The lean the card speaks of: the type that would change most, else the strongest one ("" when none).
static func _lean_type(rec: Dictionary, then: Dictionary) -> String:
	var a: Dictionary = rec.get("lean", {})
	var b: Dictionary = then.get("lean", {})
	var best := ""
	var most := -1.0
	for t in a.keys() + b.keys():
		var change := absf(float(b.get(t, 0.0)) - float(a.get(t, 0.0)))
		var score := change * 1000.0 + float(b.get(t, a.get(t, 0.0)))
		if Lean.rules()["types"].get(t, {}).has("tint") and score > most:
			most = score
			best = t
	return best

static func _ring(was: float, now: float, col: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(RING_PX, RING_PX)
	c.draw.connect(func():
		var mid := c.size * 0.5
		var rad := RING_PX * 0.5 - RING_W
		var top := -PI * 0.5
		c.draw_arc(mid, rad, 0.0, TAU, 40, Color(0, 0, 0, 0.35), RING_W)
		c.draw_arc(mid, rad, top, top + TAU * clampf(maxf(was, now), 0.0, 1.0), 40, Color(col, GHOST_A), RING_W)
		c.draw_arc(mid, rad, top, top + TAU * clampf(minf(was, now), 0.0, 1.0), 40, col, RING_W))
	return c

## The path meter after the item: both finals as silhouettes, the tug bar, each end's pips before and after, the
## one-line verdict and a Why? button that opens the pip list.
static func _path(v: VBoxContainer, rec: Dictionary, then: Dictionary, id: String) -> void:
	var ends: Array = EvoPath.line(rec)["ends"]
	var was := EvoPath.pips(rec)
	var now := EvoPath.pips(then)
	var tug := UI.hbox(8)
	tug.add_child(EvoPathView.sil(ends[0]["form"], ends[0]["name"]))
	tug.add_child(EvoPathView.tug_bar(EvoPath.total(now[0]), EvoPath.total(now[1])))
	tug.add_child(EvoPathView.sil(ends[1]["form"], ends[1]["name"]))
	v.add_child(tug)
	var counts := []
	for i in 2:
		var a := EvoPath.total(was[i])
		var b := EvoPath.total(now[i])
		counts.append("%s %d" % [_end(ends[i]), a] + (" to %d" % b if b != a else ""))
	v.add_child(UI.label("    |    ".join(counts), UI.T_SMALL, UI.MUTED))
	v.add_child(UI.para(verdict(rec, then, id), 13, UI.INK))
	var why := UI.vbox(2)
	why.visible = false
	for i in 2:
		for line in why_lines(was[i], now[i], ends[i]):
			why.add_child(UI.label(line, 12, EvoPathView.SIDES[i]))
	v.add_child(UI.ghost("Why?", func(): why.visible = not why.visible, 80))
	v.add_child(why)

## "With this Keepstone Pip keeps growing toward Ringrove (6 to 3)." (unknown forms are '?').
static func verdict(rec: Dictionary, then: Dictionary, id: String) -> String:
	var ends: Array = EvoPath.line(rec)["ends"]
	var w0 := EvoPath.winner(rec)
	var w1 := EvoPath.winner(then)
	var head := "With this %s %s" % [GardenItems.item_name(id), rec["name"]]
	if w1 < 0:
		return "%s stays undecided." % head
	var p := EvoPath.pips(then)
	var score := "(%d to %d)" % [EvoPath.total(p[w1]), EvoPath.total(p[1 - w1])]
	var how := "keeps growing" if w0 == w1 else "turns"
	return "%s %s toward %s %s." % [head, how, _end(ends[w1]), score]

## One line per pip source of an end, with the change: "Ringrove: tokens 1 to 2".
static func why_lines(was: Array, now: Array, e: Dictionary) -> Array:
	var out := []
	for s in EvoPath.SOURCES:
		var a := _count(was, s)
		var b := _count(now, s)
		if a == 0 and b == 0:
			continue
		var what := String(EvoPathView.SOURCE_NAMES[s])
		if s == "stat":
			what += " (%s)" % Care.STATS[e["stat"]]["name"]
		elif s == "lean":
			what += " (%s)" % Lean.face(String(e["type"]))["name"]
		out.append("%s: %s %d" % [_end(e), what, a] + (" to %d" % b if b != a else ""))
	if out.is_empty():
		out.append("%s: no pips yet" % _end(e))
	return out

static func _count(list: Array, source: String) -> int:
	for p in list:
		if p["source"] == source:
			return int(p["count"])
	return 0

static func _end(e: Dictionary) -> String:
	return String(e["name"]) if EvoPath.known(String(e["form"])) else "?"
