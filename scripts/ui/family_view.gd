class_name FamilyView
extends RefCounted
## The Family tab of the Boki card (briefs/design/GARDEN_MODERN.md section 5 rank 8): parents and grandparents
## with portrait, name and type, the mentor's gift and the nest items used at the breeding. It only reads what
## is saved: rec["lineage"] (parent uids and names, "nest"), rec["gift"] and the roster. A Boki with no
## recorded parents was caught wild; a parent you no longer have shows by name only.

const WILD := "wild"      # no parents recorded: caught in the wild
const GONE := "gone"      # a parent that is no longer in the roster
const OWNED := "owned"
const VISITOR := "visitor"    # a wild visitor that left the egg (lineage["visitor"]: species, zone, day)
const PORTRAIT := 44.0    # px
const CELL_W := 210.0     # px

## The two parents of rec as slots {"state", "name", "rec", "type"}.
static func parents(rec: Dictionary) -> Array:
	var lin: Dictionary = rec.get("lineage", {})
	var uids: Array = lin.get("parents", [])
	var names: Array = lin.get("names", [])
	if uids.is_empty() and names.is_empty():
		var v: Dictionary = lin.get("visitor", {})
		return [_slot(WILD), _slot(WILD)] if v.is_empty() else [_visitor_slot(v), _slot(WILD)]
	var out: Array = []
	for i in 2:
		var uid := String(uids[i]) if i < uids.size() else ""
		var nm := String(names[i]) if i < names.size() else "?"
		var owned: Dictionary = Save.kin(uid) if uid != "" else _by_name(nm)
		out.append(_slot(OWNED, owned) if not owned.is_empty() else _slot(GONE, {"name": nm}))
	return out

## The grandparents through each parent: [[slot, slot], ...] in the order of parents(rec). A wild parent has
## none to show; a parent you no longer have leaves its parents unknown.
static func grandparents(rec: Dictionary) -> Array:
	var out: Array = []
	for p in parents(rec):
		match String(p["state"]):
			OWNED: out.append(parents(p["rec"]))
			GONE: out.append([_slot(GONE, {"name": "unknown"}), _slot(GONE, {"name": "unknown"})])
			_: out.append([])
	return out

## What was passed down besides looks: the mentor's gift line, then the nest items used at the egg.
static func passed(rec: Dictionary) -> Array:
	var out: Array = []
	if rec.has("gift"):
		out.append(Mentor.line(rec["gift"]))
	var nest: Dictionary = (rec.get("lineage", {}) as Dictionary).get("nest", {})
	if int(nest.get("gifts", 0)) > 0:
		out.append("%s ×%d" % [NestItems.item_of("gifts")["name"], int(nest["gifts"])])
	for kind in ["species", "habit"]:
		if nest.get(kind, false):
			out.append(String(NestItems.item_of(kind)["name"]))
	return out

static func _visitor_slot(v: Dictionary) -> Dictionary:
	var sp := String(v["sp"])
	var slot := _slot(VISITOR, {"species": sp, "name": "Wild " + String(Data.KIN[sp]["name"])})
	slot["note"] = "wild visitor, %s, day %d" % [GardenVisitor.zone_name(String(v["zone"])), int(v["day"])]
	return slot

static func _slot(state: String, rec := {}) -> Dictionary:
	var sp: Dictionary = Data.KIN.get(String(rec.get("species", "")), {})
	return {"state": state, "rec": rec, "name": String(rec.get("name", state)),
		"type": String(sp.get("type", "")).capitalize()}

## An older record has parent names but no uids: take the one Boki of that name, if just one.
static func _by_name(nm: String) -> Dictionary:
	var hits: Array = Save.d["roster"].filter(func(k): return String(k["name"]) == nm)
	return hits[0] if hits.size() == 1 else {}

## The tab: parents and what was passed down on the left, grandparents on the right. open(rec) is called when
## you click an ancestor you still have.
static func fill(rec: Dictionary, left: Control, right: Control, tree: SceneTree, open: Callable) -> void:
	left.add_child(UI.section("Parents", UI.FAINT.lightened(0.2)))
	for p in parents(rec):
		left.add_child(_cell(p, tree, open))
	left.add_child(UI.spacer(4))
	left.add_child(UI.section("Passed down", UI.FAINT.lightened(0.2)))
	var lines := passed(rec)
	if lines.is_empty():
		left.add_child(UI.para("No mentor's gift or nest items.", 12, UI.FAINT))
	for line in lines:
		left.add_child(UI.para(String(line), 13, UI.INK))
	right.add_child(UI.section("Grandparents", UI.FAINT.lightened(0.2)))
	var via := parents(rec)
	var grand := grandparents(rec)
	for i in via.size():
		right.add_child(UI.label("Through %s" % via[i]["name"], UI.T_SMALL, UI.MUTED))
		if grand[i].is_empty():
			right.add_child(UI.para("A wild parent: nothing further back.", 12, UI.FAINT))
		for g in grand[i]:
			right.add_child(_cell(g, tree, open))

## One ancestor: portrait, name and type; a click opens the card when you still own it.
static func _cell(slot: Dictionary, tree: SceneTree, open: Callable) -> Control:
	var b := UI.ghost("", func(): open.call(slot["rec"]))
	b.custom_minimum_size = Vector2(CELL_W, PORTRAIT + 8.0)
	b.disabled = slot["state"] != OWNED
	b.focus_mode = Control.FOCUS_NONE if b.disabled else Control.FOCUS_ALL
	var h := UI.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	if slot["state"] == OWNED or slot["state"] == VISITOR:
		h.add_child(KinPortrait.view(slot["rec"], tree, PORTRAIT))
	else:
		var gap := Control.new()
		gap.custom_minimum_size.x = PORTRAIT
		h.add_child(gap)
	var t := UI.vbox(0)
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim: bool = slot["state"] != OWNED
	t.add_child(UI.label(String(slot["name"]), UI.T_BODY, UI.MUTED if dim else UI.INK))
	if slot["type"] != "":
		t.add_child(UI.label(String(slot["type"]), UI.T_SMALL, UI.MUTED))
	if slot.has("note"):
		t.add_child(UI.label(String(slot["note"]), UI.T_SMALL, UI.FAINT))
	elif slot["state"] == GONE and slot["name"] != "unknown":
		t.add_child(UI.label("no longer here", UI.T_SMALL, UI.FAINT))
	h.add_child(t)
	b.add_child(h)
	return b
