class_name GardenCard
extends RefCounted
## The Boki card's top in base mode (farm_build.json "base_mode"), as one glance: a portrait, its species and
## lean as two chips, its mood today, its best friend and rival (small portraits: tap to find them in the
## garden) and the last two journal lines. The stats, traits and the rest are behind "More" (the old tabs).
## It only reads the Boki's record: bonds, lean, needs and journal are written elsewhere. Void & Masks look
## (briefs/UI_STYLE.md): a void window for the portrait, parchment strips for the lines, ink on parchment.

const PORTRAIT := 104.0         # px, the big void window
const SMALL := 52.0             # px, a friend's or rival's window
const LOOK_S := 3.0             # seconds the camera rests on a Boki you tapped
const JOURNAL_LINES := 2
const VOID_BG := Color("1e1430")
const PARCHMENT := Color("d9c9a3")
const INK_DARK := Color("2a1c40")
const FRIEND_EDGE := Color("3fe0d0")
const RIVAL_EDGE := Color("ff3fd0")

## True while the card shows "More" (the old tabs) instead of the glance. Opening the card again keeps it.
static var more := false
static var _look := {}          # the home's kin entry the camera is resting on
static var _look_t := 0.0

static func on() -> bool:
	return FarmUnlocks.base_mode()

static func glance() -> bool:
	return on() and not more

## How it feels today, from its condition (Care.condition): one word and a colour. Never harsher than "Glum".
static func mood(rec: Dictionary) -> Array:
	var c := Care.condition(rec)
	if c >= 75.0: return ["Happy", Color("ffd79a")]
	if c >= 50.0: return ["Content", UI.TEAL]
	if c >= 28.0: return ["Quiet", UI.MUTED]
	return ["Glum", Color("b8a6ff")]

## The roster Boki it likes best and the one it likes least, as [friend, rival] (each {} when none): a bond
## at or past the base life's friend_at / rival_at.
static func pair(rec: Dictionary) -> Array:
	var rules := Content.rules("base_life")
	var best := {}
	var worst := {}
	var hi := float(rules["friend_at"])
	var lo := float(rules["rival_at"])
	for other in Save.d["roster"]:
		if other["uid"] == rec["uid"]:
			continue
		var b := BaseLife.bond(rec, other)
		if b >= hi:
			best = other
			hi = b
		elif b <= lo:
			worst = other
			lo = b
	return [best, worst]

static func _chip(txt: String, col: Color) -> Control:
	var p := UI.chip("", txt, col.lerp(UI.INK, 0.35), "", 13)
	p.add_theme_stylebox_override("panel", UI.frame(Color(col, 0.18), UI.R_PILL, Color(col, 0.7), 1, 10, 3, 0.0))
	return p

## A Boki's picture in a dark void window with a coloured crack-edge.
static func _window(rec: Dictionary, px: float, edge: Color, tree: SceneTree) -> PanelContainer:
	var w := PanelContainer.new()
	w.add_theme_stylebox_override("panel", UI.frame(VOID_BG, UI.R_CARD, Color(edge, 0.85), 2, 3, 3, 0.0))
	w.add_child(KinPortrait.view(rec, tree, px))
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

## A friend or a rival: a small window and a name; tapping it finds them in the garden.
static func _bond_tile(home, label_txt: String, other: Dictionary, edge: Color) -> Control:
	var v := UI.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(label_txt, UI.T_CAPS, Color(edge, 0.9), UI.caps))
	if other.is_empty():
		v.add_child(UI.label("none yet", UI.T_SMALL, UI.FAINT))
		return v
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Find %s in the garden" % other["name"]
	b.pressed.connect(func(): find(home, other))
	var row := UI.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_window(other, SMALL, edge, home.get_tree()))
	var nm := UI.label(String(other["name"]), UI.T_BODY, UI.INK, UI.semi)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(nm)
	b.add_child(row)
	b.custom_minimum_size = row.get_combined_minimum_size()
	v.add_child(b)
	return v

## A journal line on a parchment strip, dark ink.
static func _strip(txt: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.frame(PARCHMENT, UI.R_SMALL, Color(0, 0, 0, 0), 0, 10, 5, 0.0))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.label(txt, UI.T_SMALL, INK_DARK, UI.semi))
	return p

## The newest `n` journal lines in words, newest first.
static func journal(rec: Dictionary, n: int) -> Array:
	var lines: Array = rec.get("journal", [])
	var out: Array = []
	for i in range(lines.size() - 1, maxi(lines.size() - 1 - n, -1), -1):
		out.append(CareJournal.text(lines[i]))
	return out

## The glance, added to the card body `v`.
static func build(home, rec: Dictionary, v: Control) -> void:
	var tree: SceneTree = home.get_tree()
	var top := UI.hbox(14)
	v.add_child(top)
	top.add_child(_window(rec, PORTRAIT, FRIEND_EDGE, tree))
	var who := UI.vbox(6)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	who.add_child(UI.label(String(rec["name"]), UI.T_TITLE, UI.INK, UI.big))
	who.add_child(UI.label(String(Data.KIN[rec["species"]].get("name", rec["species"])), UI.T_SMALL, UI.MUTED))
	var chips := UI.hbox(6)
	var el := DexView.type_of(rec["species"])
	chips.add_child(_chip(DexView.type_name(el), DexView.type_col(el)))
	var ln := Evo.lean(rec)
	if String(ln[0]) == "":
		chips.add_child(_chip("No lean yet", UI.FAINT))
	else:
		chips.add_child(_chip("Leans %s" % Lean.face(ln[0])["name"], Lean.face(ln[0])["tint"]))
	who.add_child(chips)
	var md := mood(rec)
	var mood_row := UI.hbox(8)
	mood_row.add_child(UI.label("Today", UI.T_SMALL, UI.FAINT))
	mood_row.add_child(UI.tag(String(md[0]), md[1]))
	who.add_child(mood_row)
	var bonds := UI.hbox(14)
	var fr := pair(rec)
	bonds.add_child(_bond_tile(home, "BEST FRIEND", fr[0], FRIEND_EDGE))
	bonds.add_child(_bond_tile(home, "RIVAL", fr[1], RIVAL_EDGE))
	v.add_child(UI.spacer(4))
	v.add_child(bonds)
	v.add_child(UI.spacer(4))
	var lines := journal(rec, JOURNAL_LINES)
	if lines.is_empty():
		v.add_child(_strip("Nothing yet: feed it and play with it."))
	for l in lines:
		v.add_child(_strip(String(l)))

## Close the card and let the camera rest on `other` for a moment, with its name over its head.
static func find(home, other: Dictionary) -> void:
	for k in home.kins:
		if k["rec"]["uid"] == other["uid"]:
			_look = k
			_look_t = LOOK_S
			home._close_panel()
			return

## The camera's focus: where the player stands, or the Boki a tap asked to find, for LOOK_S seconds.
static func framed(focus: Vector3, dt: float) -> Vector3:
	if _look_t <= 0.0 or not is_instance_valid(_look.get("node")):
		return focus
	_look_t -= dt
	var lbl: Label3D = _look["emote"]
	lbl.text = String(_look["rec"]["name"])
	lbl.modulate = FRIEND_EDGE
	_look["emote_t"] = 1.6
	return Vector3(_look["pos"].x, focus.y, _look["pos"].z)
