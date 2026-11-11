class_name MixingBowl
extends RefCounted
## The Mixing Bowl screen (GardenRecipes, briefs/design/GARDEN_MODERN.md 1.4): every recipe is listed from the
## start with what it asks for and what comes out; when you hold what it takes, the card says exactly what
## will go in and the Mix button confirms it.

## Fills v with the recipe cards. changed() runs after a mix (the caller redraws).
static func fill(v: VBoxContainer, changed: Callable) -> void:
	v.add_child(UI.para("Put in what a recipe asks for and the bowl shows what it will use. Nothing ever fails.", 13))
	for r in GardenRecipes.all():
		var plan := GardenRecipes.plan(r)
		var card := UI.card(UI.CARD, 12, 12)
		var cv := UI.vbox(4)
		card.add_child(cv)
		var gives := String(r["gives"])
		var have := int(Save.d["items"].get(gives, 0))
		cv.add_child(UI.label("%s  (you have %d)" % [GardenItems.item_name(gives), have], 16, UI.GOLD))
		cv.add_child(UI.para("Needs: " + GardenRecipes.need_line(r), 12))
		cv.add_child(UI.para("Gives: " + GardenRecipes.result_line(r), 12))
		if plan["ok"]:
			cv.add_child(UI.label("Will use: %s" % plan["text"], 13, UI.GOOD))
			cv.add_child(UI.button("Mix", func():
				GardenRecipes.mix(r)
				Save.save_game()
				changed.call(), 120))
		v.add_child(card)
