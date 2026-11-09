class_name HomeHero
extends RefCounted
## The farm's Hunter picker (J or the Hunters button) is the Hunters screen (HomeClasses): every
## Hunter, the viewer, and swapping your hunter in place. This file keeps the kit card page and the
## pick itself; static functions that take the Home screen.

## Opens the Hunters screen (on `sel`, else the last one looked at).
static func open(home: Node, sel := "") -> void:
	HomeClasses.open(home, sel)

static func kit(home: Node, ak: String) -> void:
	var v: VBoxContainer = home._new_panel("Kit: %s" % Arch.name_of(ak), KitCard.SIZE.x + 40, true)
	v.add_child(KitCard.make(ak, String(Save.active_kin().get("species", ""))))
	UiShell.footer_left(v).add_child(UiWidgets.ghost("Back to Relics", func(): open(home, ak), 0))

## Plays `ak` from now on: saved as the expedition pick (its weight, id and weapon family), and the
## hunter on the farm turns into it with a flash, a puff and a sound.
static func pick(home: Node, ak: String) -> void:
	var same := ak == Arch.of_save()
	if not Arch.exists(ak) or not HeroGrid.save_pick(ak):
		return
	home._close_panel()
	if same:
		return
	home._refresh_player_model()
	# the flourish: a burst of the Hunter's colour, a white flash on the new body, a pop of scale
	var col := Arch.color(ak)
	if home.fx:
		home.fx.burst(home.ppos + Vector3(0, home.py + 1.0, 0), col, 28, 4.0, 0.6)
		home.fx.burst(home.ppos + Vector3(0, home.py + 0.3, 0), Color.WHITE, 12, 2.5, 0.4)
	Sfx.play("unlock", null, -6.0, 0.0, 1.15)
	Sfx.play("whoosh", null, -10.0, 0.0, 1.3)
	var pl: Node3D = home.player
	var tw: Tween = pl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)      # (bound to the body: it stops if the body is swapped again)
	tw.tween_method(func(v: Vector3): if is_instance_valid(pl): pl.set_meta("pop", v), Vector3(0.6, 1.35, 0.6), Vector3.ONE, 0.35)
	home._toast("Now playing %s" % Arch.name_of(ak, true))

