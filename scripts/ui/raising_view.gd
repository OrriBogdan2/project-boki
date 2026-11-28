class_name RaisingView
extends RefCounted
## The Boki card's "Raising" block (what raising has made of it): the food lean it
## leads with, each raised axis (BaseAxes, rec["raised"]) as a word pair with a marker, and its best friend and
## rival (rec["bonds"], BaseLife). It only reads what is saved; the rules stay in BaseAxes and base_life.json.

const PORTRAIT := 36.0  # px: a friend's or rival's face
const TRACK_W := 110.0  # px: the width of an axis marker's track
const TRACK_H := 14.0  # px
const WORD_W := 46.0  # px: the room for an axis word (the widest is "gentle")
const DOT_R := 5.0  # px: the marker's radius


## The Boki you own that rec likes most (best) or least, with a bond past friend_at or rival_at; {} if none.
static func bond_pick(rec: Dictionary, best: bool) -> Dictionary:
	var rules := Content.rules("base_life")
	var pick := {}
	var top := float(rules["friend_at"]) if best else float(rules["rival_at"])
	var bonds: Dictionary = rec.get("bonds", {})
	for uid in bonds:
		var other := Save.kin(String(uid))
		var bond := float(bonds[uid])
		if other.is_empty() or other == rec:
			continue
		if (bond >= top) if best else (bond <= top):
			pick = other
			top = bond
	return pick


## The raising block: lean, the three axes, then best friend and rival.
static func block(rec: Dictionary, parent: Control, tree: SceneTree) -> void:
	parent.add_child(UI.section("Raising", UI.FAINT.lightened(0.2)))
	var ln := Evo.lean(rec)
	if String(ln[0]) == "":
		parent.add_child(UI.label("No leaning meals yet", UI.T_SMALL, UI.FAINT))
	else:
		var face := Lean.face(ln[0])
		parent.add_child(
			UI.label("Leans %s  ·  %d%%" % [face["name"], int(100.0 * float(ln[1]))], UI.T_SMALL, face["tint"])
		)
	var tune := Content.rules("base_axes")
	for axis in BaseAxes.AXES:
		parent.add_child(_axis_row(rec, axis, tune))
	var row := UI.hbox(14)
	row.add_child(_who("Best friend", bond_pick(rec, true), tree))
	row.add_child(_who("Rival", bond_pick(rec, false), tree))
	parent.add_child(row)


static func _axis_row(rec: Dictionary, axis: String, tune: Dictionary) -> Control:
	var at := float(rec.get("raised", {}).get(axis, 0.0))
	var ends: Array = tune["ends"][axis]
	var leaning := absf(at) >= float(tune["band"])
	var row := UI.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var side := 1 if at > 0.0 else 0
	row.tooltip_text = ("Leans %s" % ends[side]) if leaning else "Not leaning either way yet"
	for i in 2:
		var word := UI.label(String(ends[i]), UI.T_SMALL, UI.INK if leaning and side == i else UI.FAINT)
		word.custom_minimum_size.x = WORD_W
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 0 else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(word)
		if i == 0:
			row.add_child(Marker.new(at / float(tune["cap"]), leaning))
	return row


static func _who(caption: String, other: Dictionary, tree: SceneTree) -> Control:
	var cell := UI.hbox(8)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not other.is_empty():
		cell.add_child(KinPortrait.view(other, tree, PORTRAIT))
	var text := UI.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UI.label(caption, 12, UI.FAINT))
	text.add_child(
		UI.label(
			String(other["name"]) if not other.is_empty() else "nobody yet",
			UI.T_SMALL,
			UI.INK if not other.is_empty() else UI.FAINT
		)
	)
	cell.add_child(text)
	return cell


## An axis' marker: a track with a centre tick and a dot where the Boki sits (at -1..1, the cap at the ends).
class Marker:
	extends Control
	var at: float
	var lit: bool

	func _init(pos: float, on: bool) -> void:
		at = clampf(pos, -1.0, 1.0)
		lit = on
		custom_minimum_size = Vector2(RaisingView.TRACK_W, RaisingView.TRACK_H)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid := size.y * 0.5
		draw_rect(Rect2(0.0, mid - 1.5, size.x, 3.0), Color(0, 0, 0, 0.35))
		draw_line(Vector2(size.x * 0.5, mid - 4.0), Vector2(size.x * 0.5, mid + 4.0), Color(1, 1, 1, 0.25), 1.0)
		var x := lerpf(RaisingView.DOT_R, size.x - RaisingView.DOT_R, (at + 1.0) * 0.5)
		draw_circle(Vector2(x, mid), RaisingView.DOT_R, UI.ACCENT_HI if lit else UI.MUTED)
