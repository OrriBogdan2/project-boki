extends RefCounted
## --results-first-check: the results screen shows only what's needed (briefs/DECISIONS.md 2026-11-08).
## The first view has at most MAX_GROUPS groups (the outcome, your Boki, the loot you kept, Hunter news, and
## More beside the way home); every line on it is one plain line at a readable size, and it all fits the
## 1280x720 window without scrolling. The match's numbers are not on it: each one is behind More, next to its
## label, and More scrolls into view. A rich Heart win, a loss with a vault, and the tutorial. No save written.

const MAX_GROUPS := 5
const WINDOW := Vector2i(1280, 720)      # 720p, UI scale 1 (Settings._apply_ui_scale)
## Words a new player hasn't been taught (docs/UI_FIRST15.md section 4) that the first view must not use.
const JARGON := ["Knocks", "Tier", "Into your armory", "Details"]
const SMG := {"t": "weapon", "wid": "smg", "rar": 3, "el": "fire", "uq": "", "uid": "rf1"}
const HEART := {"egg": {"sp": "zapple"}, "goods": {"heartwood": 2, "starstone": 2}, "seeds": {}, "gems": 150,
	"trust": 20.0}

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("RESULTSFIRST %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	await _rich_win(main)
	await _loss(main)
	await _tutorial(main)
	print("RESULTSFIRST DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## A Heart win with everything on: a Boki that came along, a caught one, gems, seeds, a weapon, the Heart's
## reward, a mastery goal and a Relic challenge done. All five groups show.
func _rich_win(main: Node) -> void:
	_save_with_boki()
	var stats := {}
	for g in [ClassUnlock.challenge("juggernaut"), ClassUnlock.mastery("juggernaut")[0]]:
		stats[g["stat"]] = maxi(int(stats.get(g["stat"], 0)), int(g["target"]))
	var r := {"extracted": true, "why": "extracted", "how": "heart_final", "where": "the Heart", "arch": "juggernaut",
		"gems": 42, "seeds": {"sunroot": 2}, "caught": [Save.new_kin("zapple", "Mo")], "haul": [SMG.duplicate()],
		"heart": HEART.duplicate(true), "knocks": 7, "damage": 1234, "taken": 388, "kills": 4, "downs": 2,
		"revives": 5, "time": 201.0, "kin_trust": 64.0, "kin_say": "We made it out!", "stats": stats}
	var scr := await _show(main, r)
	var shown := _first_view(scr, "win")
	ok(scr.groups.get_children().size() + 1 == MAX_GROUPS, "win: the rich win shows all %d groups" % MAX_GROUPS)
	ok(
		shown.has("Vex made it out") and shown.has("You held the Heart ring and left.") and shown.has("Pip")
				and shown.has("BROUGHT HOME") and shown.has(_mastery_line()),
		"win: leads with the outcome, how, your Boki, the loot and the news"
	)
	await _more(scr, "win", r, ["Pip said: “We made it out!”"])
	scr.get_viewport().queue_free()

## A loss: placed 3rd, a vault that kept some gems, a weapon left in the deathbox.
func _loss(main: Node) -> void:
	_save_with_boki()
	Save.d["buildings"] = ["vault"]
	var r := {"extracted": false, "why": "abyss", "place": 3, "squads": 10, "lost_gems": 30,
		"lost_items": [SMG.duplicate()], "knocks": 2, "damage": 300, "taken": 500, "kills": 1, "downs": 1,
		"revives": 0, "time": 95.0}
	var scr := await _show(main, r)
	var shown := _first_view(scr, "loss")
	ok(
		shown.has("You fell") and shown.has("Your squad placed 3rd of 10.") and shown.has("Placement pay: 35 gems")
				and shown.has("Everything you carried stays out in the islands.") and shown.has(Loot.name_of(SMG)),
		"loss: leads with the outcome, the placing and its pay, and what stays out there"
	)
	await _more(scr, "loss", r, ["Your vault kept 10 of the gems you dropped."])
	scr.get_viewport().queue_free()

func _tutorial(main: Node) -> void:
	Save.d = Save.fresh()
	var r := {"extracted": true, "why": "extracted", "tutorial": true, "knocks": 1, "time": 300.0}
	var scr := await _show(main, r)
	var shown := _first_view(scr, "tutorial")
	ok(
		shown.has("That's the basics. Now come see your home.") and scr.home_btn.text == "Go home",
		"tutorial: the next step in the outcome, Go home beside More"
	)
	await _more(scr, "tutorial", r, [])
	scr.get_viewport().queue_free()

## The news line for the Juggernaut's first mastery goal.
func _mastery_line() -> String:
	var g: Dictionary = ClassUnlock.mastery("juggernaut")[0]
	var rw: Dictionary = g["reward"]
	return "New: %s mastery: %s (%s %s)" % [Arch.name_of("juggernaut"), g["text"],
			ClassUnlock.reward_kind_name(String(rw["kind"])), rw["name"]]

func _save_with_boki() -> void:
	Save.d = Save.fresh()
	var pip := Save.new_kin("zapple", "Pip")
	Save.d["roster"] = [pip]
	Save.d["active"] = pip["uid"]
	Save.d["name"] = "Vex"

## The results screen for `r` in a 1280x720 window, laid out and done popping in.
func _show(main: Node, r: Dictionary) -> Control:
	var window := SubViewport.new()
	window.size = WINDOW
	main.add_child(window)
	var scr: Control = load("res://scripts/ui/results.gd").new()
	window.add_child(scr)
	scr.show_result(r)
	await main.get_tree().create_timer(0.6).timeout
	return scr

## Checks the first view and returns its texts: the group count, one readable line each, all of it in the
## window without scrolling, plain words, none of the match's numbers, and More closed beside the way home.
func _first_view(scr: Control, tag: String) -> Array:
	var count: int = scr.groups.get_children().size() + 1      # + the bottom row: More and the way home
	ok(count <= MAX_GROUPS, "%s: %d groups on the first view (at most %d)" % [tag, count, MAX_GROUPS])
	var view: Rect2 = scr.scroll.get_global_rect().grow(1.0)
	var labels: Array = scr.groups.find_children("*", "Label", true, false)
	var long: Array = []
	var small: Array = []
	var hidden: Array = []
	for l: Label in labels:
		if l.get_line_count() > 1:
			long.append(l.text)
		if l.get_theme_font_size("font_size") < (UI.T_CAPS if l.has_meta("pg_head") else UI.T_SMALL):
			small.append(l.text)
		if not view.encloses(l.get_global_rect()):
			hidden.append(l.text)
	var shown: Array = labels.map(func(l): return (l as Label).text)
	ok(long.is_empty(), "%s: every line is one line %s" % [tag, long])
	ok(small.is_empty(), "%s: every line is %d px or more at 720p %s" % [tag, UI.T_SMALL, small])
	var window := Rect2(Vector2.ZERO, scr.get_viewport_rect().size).grow(1.0)
	var bottom: Rect2 = scr.home_btn.get_parent().get_global_rect()
	ok(
		hidden.is_empty() and window.encloses(view) and window.encloses(bottom),
		"%s: all of it in the %s window without scrolling %s" % [tag, scr.get_viewport_rect().size, hidden]
	)
	var jargon := JARGON.filter(func(w): return shown.any(func(t): return String(t).contains(w)))
	var stats := _numbers_of({}).keys().filter(func(w): return shown.has(w))
	ok(jargon.is_empty() and stats.is_empty(), "%s: plain words and no match numbers %s" % [tag, jargon + stats])
	ok(
		scr.more_btn.is_visible_in_tree() and scr.home_btn.is_visible_in_tree() and not scr.more.visible,
		"%s: More and the way home on screen, More closed" % tag
	)
	return shown

## Opens More: each of the match's numbers is there next to its label, with every one of `notes`, and its
## first line scrolls into view.
func _more(scr: Control, tag: String, r: Dictionary, notes: Array) -> void:
	scr.more_btn.pressed.emit()
	for i in 3:
		await scr.get_tree().process_frame
	ok(scr.more.is_visible_in_tree(), "%s: More opens" % tag)
	var head: Control = scr.more.get_child(0)
	ok(scr.scroll.get_global_rect().grow(1.0).encloses(head.get_global_rect()), "%s: and scrolls into view" % tag)
	var grid: GridContainer = scr.more.find_children("*", "GridContainer", true, false)[0]
	var cells: Array = grid.get_children()
	var pairs := {}
	for i in range(0, cells.size() - 1, 2):
		pairs[(cells[i] as Label).text] = (cells[i + 1] as Label).text
	var want := _numbers_of(r)
	var missing: Array = want.keys().filter(func(w): return pairs.get(w, "") != want[w])
	ok(missing.is_empty() and pairs.size() == want.size(), "%s: More has every number %s" % [tag, pairs])
	var texts: Array = scr.more.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	for nt in notes:
		ok(texts.has(nt), "%s: More has '%s'" % [tag, nt])

## The match's numbers the way More shows them, by label.
func _numbers_of(r: Dictionary) -> Dictionary:
	var secs := int(r.get("time", 0))
	return {"Foes downed": str(int(r.get("knocks", 0))), "Kills": str(int(r.get("kills", 0))),
		"Damage dealt": str(int(r.get("damage", 0))), "Damage taken": str(int(r.get("taken", 0))),
		"Time": "%d:%02d" % [secs / 60, secs % 60], "Times downed": str(int(r.get("downs", 0))),
		"Where": String(Data.TIERS[clampi(Game.last_tier, 0, Data.TIERS.size() - 1)]["name"]),
		"Revives": str(int(r.get("revives", 0)))}
