extends RefCounted
## --tut-first-evolve-check: the first-evolution card (EvolveCard). The first form change on a save shows
## one centred card (old and new form, one line on why, stat bars with the gain, a "See its page" link);
## later ones show a toast; a Boki held back by missing art is told once that it will change when its form
## arrives. Test lines are put into the loaded rules and taken out again; the save is never written.

var bad := 0
var _added: Array = []

## A stand-in farm screen: records the toasts and the panels EvolveCard asks for.
class FakeHome extends Control:
	var toasts: Array = []
	var panels: Array = []
	var closed := 0

	func _toast(txt: String) -> void:
		toasts.append(txt)

	func _new_panel(title: String, _width := 520.0) -> VBoxContainer:
		var v := VBoxContainer.new()
		add_child(v)
		panels.append({"title": title, "box": v})
		return v

	func _close_panel() -> void:
		closed += 1

func ok(cond: bool, what: String) -> void:
	print("TUTEVO %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _line(sp: String, line: Dictionary) -> void:
	var lines: Dictionary = Evo.rules()["lines"]
	_added.append([sp, lines.get(sp)])
	lines[sp] = line

func _kin(sp: String, lv: int) -> Dictionary:
	var rec := Save.new_kin(sp, "Pip")
	rec["level"] = lv
	Evo.ensure(rec)
	return rec

func _labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out

func _has_text(n: Node, part: String) -> bool:
	for t: String in _labels(n):
		if t.contains(part):
			return true
	return false

func run(main: Node) -> void:
	Save.no_write = true
	var old := Save.d
	Save.d = Save.fresh()
	_words()
	_stats()
	_flow(main)
	_waiting(main)
	var lines: Dictionary = Evo.rules()["lines"]
	for a in _added:
		if a[1] == null: lines.erase(a[0])
		else: lines[a[0]] = a[1]
	Save.d = old
	print("TUTEVO %s (%d failed)" % ["PASS" if bad == 0 else "FAIL", bad])
	main.get_tree().quit(1 if bad > 0 else 0)

## The why line for each way of changing, in plain words.
func _words() -> void:
	var by_level := {"how": "level", "from_id": "cindle", "to_id": "zapple", "lv": 16}
	var l := EvolveCard.why(by_level)
	ok(l.begins_with("Level 16: ") and l.contains(" grew into "), "why by level: '%s'" % l)
	var by_ink := {"how": "item", "item": "ink_ember", "from_id": "cindle", "to_id": "zapple"}
	ok(EvolveCard.why(by_ink) == "The Ember Ink did it.", "why by Ink: '%s'" % EvolveCard.why(by_ink))
	ok(EvolveCard.why({"how": "trade", "from_id": "cindle", "to_id": "zapple"}).contains("keeper"), "why by trade")
	ok(not EvolveCard.can_card({"kind": "form", "to": "X"}), "an older queued event without species ids gets no card")

## The stat bars: three rows, the gain as plain text.
func _stats() -> void:
	var rows := EvolveCard.stat_rows("cindle", "zapple")
	ok(rows.size() == 3 and rows[0]["name"] == "Health" and rows[2]["name"] == "Speed",
		"three stat rows: Health, Strength, Speed")
	var fits := true
	for r: Dictionary in rows:
		fits = fits and float(r["max"]) >= float(r["old"]) and float(r["max"]) >= float(r["new"])
	ok(fits, "every bar fits inside the biggest value any species has")
	ok(EvolveCard.gain_text(40.0, 52.0) == "+12", "gain +12: %s" % EvolveCard.gain_text(40.0, 52.0))
	ok(EvolveCard.gain_text(52.0, 40.0) == "-12", "loss -12")
	ok(EvolveCard.gain_text(5.0, 5.0) == "same", "no change reads 'same'")
	ok(EvolveCard.gain_text(6.0, 6.5) == "+0.5", "speed gain keeps a decimal: %s" % EvolveCard.gain_text(6.0, 6.5))

## First change: the card (once); later ones: a toast; a part growing: the plain panel.
func _flow(main: Node) -> void:
	_line("hivara", {"level": 8, "into": [{"id": "cindle"}]})
	var rec := _kin("hivara", 8)
	var ev := Evo.on_level(rec)
	ok(rec["species"] == "cindle" and ev["from_id"] == "hivara" and ev["to_id"] == "cindle" and int(ev["lv"]) == 8,
		"the evolve event carries both species and the level")
	var home := FakeHome.new()
	main.add_child(home)
	EvolveCard.show(home, rec, [ev])
	ok(home.panels.size() == 1 and home.toasts.is_empty(), "first evolution: one card, no toast")
	var box: VBoxContainer = home.panels[0]["box"]
	ok(home.panels[0]["title"] == "Pip evolved", "the card is titled with the Boki's name")
	ok(_has_text(box, "Level 8:") and _has_text(box, "Health") and _has_text(box, "Strength")
		and _has_text(box, "Speed"),
		"the card has the why line and the three stat names")
	ok(_has_text(box, "Before") and _has_text(box, "Now") and _has_text(box, "See its page"),
		"old and new form and the link")
	ok(bool(Save.d["tutorial"].get("first_evolve", false)), "the save remembers the first evolution")
	var link: Button = null
	for c in _buttons(box):
		if c.text == "See its page": link = c
	link.pressed.emit()
	ok(home.closed == 1 and Overlay.dex_open == "cindle",
		"'See its page' closes the card and opens the new form's Field Book page")
	Overlay.close()
	var rec2 := _kin("hivara", 8)
	var ev2 := Evo.on_level(rec2)
	EvolveCard.show(home, rec2, [ev2])
	ok(home.panels.size() == 1 and home.toasts.size() == 1,
		"later evolution: a toast, no second card (%s)" % str(home.toasts))
	var grow := {"kind": "grow", "aff": "fierce", "part": "horns", "lv": 2}
	EvolveCard.show(home, rec2, [grow])
	ok(home.panels.size() == 2 and home.panels[1]["title"] == "Pip is changing", "a grown part keeps the plain panel")
	home.queue_free()

func _buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out

## A Boki at its level whose new form has no art: told once, one per visit, and it evolves later.
func _waiting(main: Node) -> void:
	var no_art := ""
	for id in Data.KIN:
		if no_art == "" and not Evo.has_art(id):
			no_art = id
	_line("hivara", {"level": 8, "into": [{"id": no_art}]})
	var a := _kin("hivara", 9)
	var b := _kin("hivara", 9)
	a["name"] = "Pip"
	b["name"] = "Dot"
	ok(Evo.on_level(a).is_empty() and Evo.waiting(a) == no_art, "past its level with no art it waits for %s" % no_art)
	ok(Evo.waiting(_kin("hivara", 7)) == "", "below its level it isn't waiting")
	var home := FakeHome.new()
	main.add_child(home)
	var kins: Array = [{"rec": a}, {"rec": b}]
	EvolveCard.tell_waiting(home, kins)
	ok(home.toasts.size() == 1 and home.toasts[0].contains("Pip is ready")
		and home.toasts[0].contains("new form arrives"),
		"the line says it is ready and will change when its form arrives: %s" % str(home.toasts))
	EvolveCard.tell_waiting(home, kins)
	EvolveCard.tell_waiting(home, kins)
	ok(home.toasts.size() == 2 and home.toasts[1].contains("Dot"), "each Boki is told once, one per visit")
	EvolveCard.tell_waiting(home, kins)
	ok(home.toasts.size() == 2, "nobody is told twice")
	_line("hivara", {"level": 8, "into": [{"id": "cindle"}]})      # the art lands
	Save.d["roster"] = [a]
	var evs := Evo.catch_up(Save.d["roster"])
	ok(evs.size() == 1 and not a.has("wait_told") and EvolveCard.can_card(evs[0]),
		"once the form arrives it evolves, with a card-ready event")
	Save.d["roster"] = []
	home.queue_free()
