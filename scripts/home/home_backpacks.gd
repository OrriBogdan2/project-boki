class_name HomeBackpacks
extends RefCounted
## Backpacks on the farm (Backpacks): the expedition panel's backpack row (‹ › through the ones you
## own, capped by the difficulty) and the armory's Backpacks tab, where you buy them.

## The expedition panel row: which backpack comes next time.
static func row(parent: VBoxContainer, reopen: Callable, diff_tier: int) -> void:
	parent.add_child(UI.section("Backpack"))
	var choices: Array = [Backpacks.POUCH]
	for tier in range(1, Backpacks.cap(diff_tier) + 1):
		if Backpacks.owned(tier) > 0:
			choices.append(tier)
	var now := Backpacks.pick(diff_tier)
	var card := UI.card(UI.CARD, 6, 10)
	var line := UI.hbox(8)
	card.add_child(line)
	line.add_child(Icons.Glyph.new("satchel", Backpacks.COL, 22.0))
	var slots_now := Equal.base_pack() + Backpacks.slots(now)
	var nm := UI.label("%s:  %d slots" % [Backpacks.name_of(now), slots_now], 14, Backpacks.COL, UI.semi)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(nm)
	var at := maxi(0, choices.find(now))
	for dir in [-1, 1]:
		var step: int = dir
		var arrow := "‹" if dir < 0 else "›"
		var b := UI.button(arrow, func():
			Backpacks.set_pick(int(choices[(at + step + choices.size()) % choices.size()]))
			Save.save_game()
			reopen.call(), 36)
		b.disabled = choices.size() <= 1
		line.add_child(b)
	parent.add_child(card)
	var note_text := "Up to a %s on this difficulty. A bigger one is lost if you go down; " % Backpacks.name_of(
		Backpacks.cap(diff_tier))
	note_text += "the Pouch is always yours."
	var note := UI.label(note_text, 12, UI.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)

## The armory's Backpacks tab: what you own, and a Buy button for each bigger tier.
static func tab(v: VBoxContainer, reopen: Callable) -> void:
	for tier in range(1, Backpacks.tiers().size()):
		var card := UI.card(UI.CARD, 10)
		var r := UI.hbox(10)
		card.add_child(r)
		r.add_child(Icons.Glyph.new("satchel", Backpacks.COL, 26.0))
		var info := UI.vbox(1)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := "%s  ×%d" % [Backpacks.label(tier), Backpacks.owned(tier)]
		info.add_child(UI.label(title, 16, Backpacks.COL, UI.semi))
		var caps: Array = []
		for t in Data.TIERS.size():
			if Backpacks.cap(t) >= tier:
				caps.append(String(Data.TIERS[t]["name"]))
		info.add_child(UI.label("Can come to: " + ", ".join(caps), 12, UI.MUTED))
		r.add_child(info)
		var cost := Backpacks.price(tier)
		var bt: int = tier
		var buy := UI.button("Buy  %d gems, %d scrap" % [cost[0], cost[1]], func():
			if Backpacks.buy(bt) == "":
				Sfx.play("pickup")
				Save.save_game()
			reopen.call(), 0, "plus")
		buy.disabled = int(Save.d.get("gems", 0)) < cost[0] or int(Save.d.get("scrap", 0)) < cost[1]
		r.add_child(buy)
		v.add_child(card)
	var tip_text := "Everyone has the Pouch for free. A bigger backpack is brought into a match and lost in your "
	tip_text += "deathbox if you go down; in a match you can take a bigger one from a deathbox or buy one at a shop."
	v.add_child(UI.para(tip_text, 12, UI.FAINT))

## How many bigger backpacks you own (the tab's count).
static func count() -> int:
	var n := 0
	for tier in range(1, Backpacks.tiers().size()):
		n += Backpacks.owned(tier)
	return n
