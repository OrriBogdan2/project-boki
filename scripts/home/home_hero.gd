class_name HomeHero
extends RefCounted
## The Hero panel on the farm (J or the Hero button): every class, its kit, and swapping your
## hunter in place. Moved out of home.gd; static functions that take the Home screen.

## Every class (Arch.ORDER, four per weight): portrait, name, weight; locked ones are greyed with their goal.
## Hover for the kit, K or the Kit button for the full kit card. Picking one swaps your hunter in place and saves it as your
## expedition default (the expedition panel and the Training Grounds start on it).
static func open(home: Node) -> void:
	var v: VBoxContainer = home._new_panel("Hero", 860)
	UI.subtitle(v, "Who you play. Saved as your expedition pick. Hover a class for its kit, %s to open the full kit card. Greyed classes open through play: click one for the goals." % "K")
	var grid := HeroGrid.build(v, func(ak: String): pick(home, ak), func(ak: String): kit(home, ak), func(ak: String): home.set_meta("hero_hover", ak), true, func(_ak: String): HomeClasses.open(home))
	home.set_meta("hero_grid", grid)
	UI.footer_left(v).add_child(UI.ghost("Classes and goals", func(): HomeClasses.open(home), 0))

static func kit(home: Node, ak: String) -> void:
	var v: VBoxContainer = home._new_panel("Kit: %s" % Arch.name_of(ak), KitCard.SIZE.x + 40, true)
	v.add_child(KitCard.make(ak, String(Save.active_kin().get("species", ""))))
	UI.footer_left(v).add_child(UI.ghost("Back to heroes", func(): open(home), 0))

## Plays `ak` from now on: saved as the expedition pick (weight, class, its weapon family), and the
## hunter on the farm turns into it with a flash, a puff and a sound.
static func pick(home: Node, ak: String) -> void:
	var same := ak == Arch.of_save()
	if not Arch.exists(ak) or not HeroGrid.save_pick(ak):
		return
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
	home._toast("Now playing %s (%s weight). Your expeditions start with it." % [Arch.name_of(ak), String(Data.CLASSES[Arch.weight(ak)]["name"])])

