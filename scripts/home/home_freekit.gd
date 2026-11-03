class_name HomeFreeKit
extends RefCounted
## The home screen's free-kit run (Loaner) and the stray notice (Lifeline), moved out of home.gd so it
## only has wiring: the expedition board's free-kit card and button, starting a free-kit run, and the
## "a stray wandered onto the farm" toast. All static; they take the Home screen where they need it.

## The card on the expedition board that says what a free-kit run is.
static func card(right: Control) -> void:
	if not Loaner.available():
		return
	var fkc := UI.card(Color(UI.GOLD, 0.08), 12, 10)
	var fkr := UI.hbox(10); fkc.add_child(fkr)
	fkr.add_child(UI.IconDot.new("egg", UI.GOLD, 20.0))
	var fkv := UI.vbox(1); fkv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fkv.add_child(UI.label("Or a free-kit run: nothing at risk", 15, UI.GOLD, UI.semi))
	var fkl := UI.para("A loaner Boki (a fresh starter, lent for one run), your Hunter's plain weapon and two tonics. Your Boki, armory and stash stay home. Keep whatever you extract with; an extract pays at least %d gems." % Loaner.MIN_PAY, 12, UI.MUTED)
	fkl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fkv.add_child(fkl)
	fkr.add_child(fkv)
	right.add_child(fkc)

## The footer button. With no Boki of your own it is the only way out, so it takes the primary slot
## and this returns true (the caller adds no "Start expedition").
static func buttons(footer_left: Control, v: Control, home: Node, no_boki: bool) -> bool:
	if Loaner.available():
		var fk := UI.ghost("Free-kit run", func(): start(home), 0, "egg")
		fk.tooltip_text = "A basic loadout and a loaner Boki (a fresh starter). Nothing of yours is at risk; whatever you bring out is yours. An extract pays at least %d gems." % Loaner.MIN_PAY
		footer_left.add_child(fk)
	if no_boki:
		var fb := UI.footer_primary(v, "Free-kit run", func(): start(home), 250, "egg")
		fb.grab_focus.call_deferred()
		return true
	return false

## A free-kit run (Loaner): a basic loadout and a loaner Boki, nothing of yours at risk.
## Reads the board's picks (exp_mode, exp_tier, exp_seed) from the Home screen.
static func start(home: Node) -> void:
	Save.d["cls"] = Data.class_of_save()
	Save.save_game()
	var o := {"teams": Data.MATCH_PLAYERS, "squad": 1}
	match String(home.exp_mode):
		"duo": o = {"teams": Data.MATCH_PLAYERS / 2, "squad": 2}
		"trio": o = {"teams": int(ceil(Data.MATCH_PLAYERS / 3.0)), "squad": 3}
	o["total"] = Data.MATCH_PLAYERS
	o["tier"] = home.exp_tier
	if home.exp_seed != 0: o["seed"] = home.exp_seed
	home.exp_seed = 0
	Game.start_match(Loaner.opts(o))

## The one-time toast when a stray turned up (Lifeline.check events).
static func toast_stray(home: Node, events: Array) -> void:
	for fe in events:
		if String(fe["kind"]) == "stray":
			var srec: Dictionary = fe["rec"]
			home.get_tree().create_timer(1.0).timeout.connect(func():
				if is_instance_valid(home) and home.is_inside_tree():
					home._show_when_free(["A stray %s wandered onto the farm. With no Boki of your own, it's decided to stay with you." % Data.KIN[String(srec["species"])]["name"],
						"You can always take a free-kit run (a loaner Boki, nothing at risk) or buy a Boki at %s's Drift Pens." % BokiPens.MERCHANT]))
