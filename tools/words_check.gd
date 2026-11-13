extends RefCounted
## --words-check: the Words page (WordsView, content/rules/words.json). Every canon term is there with one
## short plain line inside the text budget; a fresh save shows only the first two (Relic, Hunter); the terms
## the match tutorial teaches appear once a Boki has hatched, the rest after an expedition; and the page
## opens from the pause menu and from the title. Never touches the real save.

const TERMS := [
	"Relic", "Hunter", "Boki wisp", "Summon", "Extract",
	"Wisp", "Fusion", "The Blight", "The Heart", "Heartspark"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("WORDS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _terms() -> Array:
	var out: Array = []
	for w in WordsView.visible():
		out.append(String(w["term"]))
	return out

func run(m: Node) -> void:
	Save.no_write = true
	var r := WordsView.rules()
	var all: Array = []
	var budget_ok := true
	for w in r["words"]:
		all.append(String(w["term"]))
		var line := String(w["line"])
		var words := line.split(" ", false).size()
		if words > int(r["max_words"]) or line.length() > int(r["max_chars"]) or line.contains("\n"):
			budget_ok = false
			print("WORDS over budget: %s (%d words, %d chars)" % [w["term"], words, line.length()])
	ok(all == TERMS, "every canon term has a line, in order (%s)" % [all])
	ok(budget_ok, "each line is one short line (<= %d words, <= %d chars)" % [int(r["max_words"]), int(r["max_chars"])])
	Save.d = Save.fresh()
	ok(_terms() == ["Relic", "Hunter"], "a fresh save shows only Relic and Hunter (%s)" % [_terms()])
	Save.d["tutorial"]["hatched"] = true
	ok(_terms() == TERMS.slice(0, 5), "after hatching: the tutorial's terms (%s)" % [_terms()])
	Save.d["matches"] = 1
	ok(_terms() == TERMS, "after an expedition: every term")
	Save.d = Save.fresh()
	Overlay.ctx = "home"
	Overlay.open_pause("home")
	var pause_help := false
	for b in Overlay.host.find_children("*", "Button", true, false):
		if (b as Button).text.contains("Help"): pause_help = true
	ok(pause_help, "the pause menu has Help")
	Overlay.open_words()
	var shown := 0
	for l in Overlay.host.find_children("*", "Label", true, false):
		if TERMS.has((l as Label).text): shown += 1
	ok(Overlay.page == "words" and shown == 2, "Help opens the Words page with 2 terms on a fresh save (%d)" % shown)
	Overlay.close()
	print("WORDS CHECK DONE, failures: %d" % bad)
	m.get_tree().quit()
