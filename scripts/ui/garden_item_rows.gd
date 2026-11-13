class_name GardenItemRows
extends RefCounted
## The feed menu's rows for shaping items (GardenItems): what is in the bag with its exact effect on this
## Boki, what it wears now with a Take off button, and the Inks with the form each would take it to.

## Adds a row for each shaping item in the bag. feed(id) gives the item to the Boki. A sweet gets a row per
## lean type it can be eaten for and a Twinbun one for the Boki's closest friend of `mates` (other Boki's
## records); both are used directly and used(result) runs after.
static func add_bag(v: VBoxContainer, rec: Dictionary, mates: Array, feed: Callable, used: Callable) -> bool:
	var any := false
	for id in GardenItems.ids():
		var n := int(Save.d["items"].get(id, 0))
		if n <= 0 or not GardenItems.fed(id):
			continue
		any = true
		var title := "%s  ×%d" % [GardenItems.item_name(id), n]
		var e: Dictionary = GardenItems.item(id)["effect"]
		if e["kind"] == "sweet":
			for t in e["types"]:
				var line := String(GardenItems.preview(rec, id, t)["text"])
				var head := "%s: %s" % [title, Lean.face(t)["name"]]
				_row(v, head, line, "Feed", func(): used.call(GardenItems.use(rec, id, t)))
		elif e["kind"] == "twin":
			_twin(v, rec, id, title, mates, used)
		else:
			_row(v, title, String(GardenItems.preview(rec, id)["text"]), "Feed", feed.bind(id))
	return any

static func _twin(v: VBoxContainer, rec: Dictionary, id: String, title: String, mates: Array, used: Callable) -> void:
	if mates.is_empty():
		v.add_child(UI.label("%s: needs a second Boki at home to share it." % title, 13, UI.MUTED))
		return
	var mate: Dictionary = mates[0]
	for m in mates:
		if BaseLife.bond(rec, m) > BaseLife.bond(rec, mate):
			mate = m
	_row(v, "%s with %s" % [title, mate["name"]], String(GardenItems.preview_share(rec, mate, id)["text"]), "Share",
			func(): used.call(GardenItems.share(rec, mate, id)))

## Adds a row for each Ink in the market goods: the form it would take this Boki to (its picture and name),
## "no effect" when its line has no such branch, or that the form waits for its art (Evo.ink_preview).
## Only a form gets a Use button: the event goes on rec.pending_evo and each of `after` runs (the home closes
## the menu and plays the change).
static func add_inks(v: VBoxContainer, rec: Dictionary, after: Array) -> bool:
	var any := false
	var goods: Dictionary = Goods.rules()["goods"]
	for ink in goods:
		var n := Goods.have("good:" + String(ink))
		if String(goods[ink].get("kind", "")) != "ink" or n <= 0:
			continue
		any = true
		var pv := Evo.ink_preview(rec, ink)
		var pic: Control = UI.IconDot.new("gem", Goods.col_of("good:" + String(ink)), 44.0)
		if pv["state"] == "form":
			pic = KinPortrait.view({"species": pv["to"], "level": rec.get("level", 1)}, v.get_tree(), 44.0)
		var title := "%s  ×%d" % [Goods.name_of("good:" + String(ink)), n]
		var key := String(ink)
		var use := func():
			var ev := Evo.use_ink(rec, key)
			if ev.is_empty():
				return
			rec.get_or_add("pending_evo", []).append(ev)
			for cb in after:
				(cb as Callable).call()
		var b := _row(v, title, String(pv["text"]), "Use", use, pic)
		b.disabled = pv["state"] != "form"
	return any

## The menu's tail: the Inks (add_inks; true when there is one), then what it wears (add_worn).
static func add_inks_and_worn(v: VBoxContainer, rec: Dictionary, changed: Callable, after_ink: Array) -> bool:
	var any := add_inks(v, rec, after_ink)
	add_worn(v, rec, changed)
	return any

## Adds a row for each token and Stayleaf the Boki wears. changed() runs after one comes off.
static func add_worn(v: VBoxContainer, rec: Dictionary, changed: Callable) -> void:
	var on: Array = GardenItems.worn(rec).duplicate()
	if rec.get("stay", false):
		on.append("stayleaf")
	for id in on:
		_row(v, "wearing %s" % GardenItems.item_name(id), "Take it off: it goes back in the bag.", "Take off",
				func():
					GardenItems.take_off(rec, id)
					changed.call())

static func _row(v: VBoxContainer, title: String, desc: String, btn: String, act: Callable,
		pic: Control = null) -> Button:
	var row := UI.hbox(10)
	if pic != null:
		row.add_child(pic)
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(title, 16))
	info.add_child(UI.label(desc, 12, UI.MUTED))
	row.add_child(info)
	var b := UI.button(btn, act, 100)
	row.add_child(b)
	v.add_child(row)
	return b
