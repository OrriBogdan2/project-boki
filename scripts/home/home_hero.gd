class_name HomeHero
extends RefCounted
## The Hero panel on the farm (J or the Hero button): the six heroes, their kits, and swapping your
## hunter in place. Moved out of home.gd; static functions that take the Home screen.

## Whether an archetype can be picked yet, and what it takes if not. Everything is open for now;
## the class-unlock system plugs in here (return false and a requirement line for locked ones).
static func unlocked(_arch: String) -> bool:
	return true
static func requirement(_arch: String) -> String:
	return ""

## The six heroes (two per weight class): portrait, name, weight class; hover for the kit, K or the
## Kit button for the full kit card. Picking one swaps your hunter in place and saves it as your
## expedition default (the expedition panel and the Training Grounds start on it).
static func open(home: Node) -> void:
	var v: VBoxContainer = home._new_panel("Hero", 860)
	UI.subtitle(v, "Who you play. Saved as your expedition pick. Hover a hero for its kit, %s to open the full kit card." % "K")
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var cur := Arch.of_save()
	for cls in ["light", "medium", "heavy"]:
		for a in Arch.of_class(cls):
			var ak: String = a
			var can := unlocked(ak)
			var card := UI.tile_card(ak == cur, func(): if can: pick(home, ak), 10, Arch.color(ak))
			card.custom_minimum_size = Vector2(258, 0)
			var row := UI.hbox(10)
			card.add_child(row)
			var vp := Portraits.make(cls, Data.TEAM_COLORS[0], Arch.signature(ak), Save.d.get("look", {}), ak)
			card.add_child(vp)
			var tex := TextureRect.new()
			tex.texture = vp.get_texture()
			tex.custom_minimum_size = Vector2(84, 84)
			tex.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tex)
			var col := UI.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(col)
			col.add_child(UI.label(Arch.name_of(ak), 18, Arch.color(ak) if can else UI.FAINT, UI.big))
			var cd: Dictionary = Data.CLASSES[cls]
			col.add_child(UI.label("%s  ·  %d health  ·  %d dash%s" % [String(cd["name"]), int(cd["hp"]), int(cd["dashes"]), "es" if int(cd["dashes"]) > 1 else ""], 12, UI.MUTED))
			var adf := Arch.def(ak)
			var fan := UI.para(String(adf.get("fantasy", "")), 12, UI.INK if can else UI.FAINT)
			fan.custom_minimum_size.x = 150
			col.add_child(fan)
			if ak == cur:
				col.add_child(UI.label("Playing", 12, UI.GOOD, UI.semi))
			elif not can:
				col.add_child(UI.label("Locked: " + requirement(ak), 12, UI.FAINT, UI.semi))
			var kitb := UI.ghost("Kit (K)", func(): kit(home, ak), 0)
			kitb.focus_mode = Control.FOCUS_NONE
			col.add_child(kitb)
			card.tooltip_text = "%s  ·  %s class\nDash: %s  ·  Passive: %s\nRMB: %s  ·  E: %s  ·  R: Boki Merge" % [Arch.name_of(ak), String(cd["name"]), String(adf["dash"]["name"]), String(adf["passive"]["name"]), String(adf["rmb"]["name"]), String(adf["e"]["name"])]
			card.set_meta("arch", ak)
			card.mouse_entered.connect(func(): home.set_meta("hero_hover", ak))
			if not can:
				card.modulate = Color(0.55, 0.55, 0.6, 0.8)
			grid.add_child(card)
	home.set_meta("hero_grid", grid)

static func kit(home: Node, ak: String) -> void:
	var v: VBoxContainer = home._new_panel("Kit: %s" % Arch.name_of(ak), KitCard.SIZE.x + 40, true)
	v.add_child(KitCard.make(ak, String(Save.active_kin().get("species", ""))))
	UI.footer_left(v).add_child(UI.ghost("Back to heroes", func(): open(home), 0))

## Plays `ak` from now on: saved as the expedition pick (class, archetype, its weapon family), and the
## hunter on the farm turns into it with a flash, a puff and a sound.
static func pick(home: Node, ak: String) -> void:
	if not Arch.exists(ak) or not unlocked(ak):
		return
	var same := ak == Arch.of_save()
	Save.d["cls"] = Arch.weight(ak)
	Save.d["arch"] = ak
	Save.d["weapon"] = Arch.signature(ak)
	Save.save_game()
	home._close_panel()
	if same:
		return
	home._refresh_player_model()
	# the flourish: a burst of the hero's colour, a white flash on the new body, a pop of scale
	var col := Arch.color(ak)
	if home.fx:
		home.fx.burst(home.ppos + Vector3(0, home.py + 1.0, 0), col, 28, 4.0, 0.6)
		home.fx.burst(home.ppos + Vector3(0, home.py + 0.3, 0), Color.WHITE, 12, 2.5, 0.4)
	Sfx.play("unlock", null, -6.0, 0.0, 1.15)
	Sfx.play("whoosh", null, -10.0, 0.0, 1.3)
	var pl: Node3D = home.player
	var tw: Tween = home.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: Vector3): if is_instance_valid(pl): pl.set_meta("pop", v), Vector3(0.6, 1.35, 0.6), Vector3.ONE, 0.35)
	home._toast("Now playing %s (%s). Your expeditions start with it." % [Arch.name_of(ak), String(Data.CLASSES[Arch.weight(ak)]["name"])])

