class_name HomeBelt
extends RefCounted
## The utility belt on the farm: choosing what goes on keys 1, 2 and 3 for the next expedition (rows in
## the expedition panel), and the armory's Utility tab that lists your stash. What you pick leaves the
## stash when you set out (Equal.take_belt), up to the cap for the difficulty tier; everyone also gets
## the everyday issue (two tonics, two armor kits). Gloves and boots are chosen in HomeEcon.

## Items you could put in a slot: the issued ones and anything you have in the stash.
static func choices() -> Array:
	var out: Array = [""]
	var iss: Dictionary = Equal.rules().get("issue", {})
	for id in UtilityBelt.stock_ids():
		if int(iss.get(id, 0)) > 0 or Equal.stash_of(id) > 0:
			out.append(id)
	return out

static func _pick_at(i: int) -> String:
	return String(Equal.picks()[i])

static func _set_pick(i: int, id: String) -> void:
	var p: Array = Equal.picks()
	for k in p.size():
		if k != i and String(p[k]) == id and id != "":
			p[k] = ""          # an item sits in one slot only
	p[i] = id
	Save.d["belt_pick"] = p

## What a slot will hold at this tier: "Tonic ×5" (issued plus brought).
static func slot_text(id: String, tier: int) -> String:
	if id == "":
		return "empty"
	var issued := int((Equal.rules().get("issue", {}) as Dictionary).get(id, 0))
	var n := issued + clampi(UtilityBelt.bring_cap(id, tier) - issued, 0, Equal.stash_of(id))
	return "%s ×%d" % [UtilityBelt.name_of(id), n]

## "Utility belt" rows for the expedition panel: one per slot, ‹ › to change what it holds.
static func rows(parent: VBoxContainer, reopen: Callable, tier: int) -> void:
	var first := Settings.key_cap(UtilityBelt.KEYS[0])
	var last := Settings.key_cap(UtilityBelt.KEYS[UtilityBelt.SLOTS - 1])
	parent.add_child(UI.section("Utility belt  (keys %s-%s)" % [first, last]))
	var ch := choices()
	for i in UtilityBelt.SLOTS:
		var id := _pick_at(i)
		var card := UI.card(UI.CARD, 6, 10)
		var row := UI.hbox(8)
		card.add_child(row)
		if id != "":
			row.add_child(Icons.Glyph.new(UtilityBelt.icon_of(id), UtilityBelt.col_of(id), 22.0))
		var nm := UI.label("%d:  %s" % [i + 1, slot_text(id, tier)], 14,
				UtilityBelt.col_of(id) if id != "" else UI.MUTED, UI.semi)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.tooltip_text = String(UtilityBelt.def(id).get("desc",
				"")) if id != "" else "Leave this slot for something you find"
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nm)
		var at := maxi(0, ch.find(id))
		for dir in [-1, 1]:
			var dd: int = dir
			var b := UI.button("‹" if dir < 0 else "›", func():
				_set_pick(i, String(ch[(at + dd + ch.size()) % ch.size()]))
				Save.save_game()
				reopen.call(), 36)
			b.disabled = ch.size() <= 1
			row.add_child(b)
		parent.add_child(card)
	var cap_line := "You can bring up to %s on this difficulty; " % _cap_text(tier)
	cap_line += "what you bring is lost if you go down."
	var note := UI.label(cap_line, 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)

static func _cap_text(tier: int) -> String:
	return "%d tonics and %d armor kits" % [UtilityBelt.bring_cap("tonic", tier),
			UtilityBelt.bring_cap("armor_kit", tier)]

## The armory's Utility tab: your stash, and the most each item can be brought at each difficulty.
static func stash(v: VBoxContainer) -> void:
	for id in UtilityBelt.stock_ids():
		var r := UI.hbox(10)
		r.add_child(Icons.Glyph.new(UtilityBelt.icon_of(id), UtilityBelt.col_of(id), 26.0))
		var info := UI.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label("%s  ×%d" % [UtilityBelt.name_of(id), Equal.stash_of(id)], 16, UtilityBelt.col_of(id),
				UI.semi))
		var d := UI.label(String(UtilityBelt.def(id).get("desc", "")), 12, UI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)
		r.add_child(info)
		var caps: Array = []
		for t in Data.TIERS.size():
			caps.append(str(UtilityBelt.bring_cap(id, t)))
		r.add_child(UI.label("brings up to " + " / ".join(caps), 12, UI.FAINT))
		v.add_child(r)
	var tip_text := "Pick what goes on the belt on the expedition board. Buy more at the market; what you find "
	tip_text += "and bring home is kept."
	var tip := UI.para(tip_text, 12, UI.FAINT)
	v.add_child(tip)
