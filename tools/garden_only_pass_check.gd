extends "res://tools/garden_first15_check.gd"
## --garden-only-pass-check: 30 minutes of garden time for a player who never starts an expedition (the
## first-15 bot, run twice as long). Every second it reads what the player is shown: the tutorial line, the
## Goals rows (the whole list, not only the home ones), a Boki's speech. A line that tells the player to go
## on an expedition, or a Goals row only a match can fill, is a nag: each one is logged once with when it
## first showed. A nag fails the check unless it is listed in docs/GARDEN.md (open questions) as a gate that
## still needs a design call: ALLOWED_NAGS below.

const NAG := "\\b(expeditions?|extract\\w*|matches|raids?|skiff|Hunters?|lairs?)\\b"
## Match-only Goals sources: a row from one is a nag, whatever it says.
const MATCH_SOURCES := ["unlock", "mastery"]
## Nags that wait for a design call (docs/GARDEN.md, open questions) or are a choice, not a push.
## Each is a part of the "where: line" text.
const ALLOWED_NAGS := ["Goals row (unlock)", "head out, or press Stay"]

var nag_rx := RegEx.create_from_string("(?i)" + NAG)
var goals_seen := {}      # Goals row text -> source, every row the card showed
var nags := {}      # line -> [first second it showed, where]

func run(m: Node) -> void:
	sim_s = 1800.0
	await super.run(m)

func guidance() -> Array:
	_note(home.guide.hint_lbl.text if is_instance_valid(home.guide.hint_box) else "", "tutorial line")
	for r in GoalTracker.lines():
		goals_seen[String(r["text"])] = r["source"]
		_note(String(r["text"]), "Goals row (%s)" % r["source"], r["source"] in MATCH_SOURCES)
	for k in home.kins:
		if k.has("say") and is_instance_valid(k["say"]) and k["say"].visible:
			_note((k["say"] as Label3D).text, "speech")
	return super.guidance()

func _note(text: String, where: String, always := false) -> void:
	if text != "" and not nags.has(text) and (always or nag_rx.search(text) != null):
		nags[text] = [clock, where]
		print("G30 nag at %4.0f s (%s): %s" % [clock, where, text])

func _allowed(line: String) -> bool:
	var full: String = nags[line][1] + ": " + line
	return ALLOWED_NAGS.any(func(a): return full.contains(a))

func _verdicts() -> void:
	super._verdicts()
	for g in goals_seen:
		print("G30 goal shown: %s (%s)" % [g, goals_seen[g]])
	var loose := nags.keys().filter(func(l): return not _allowed(l))
	var what := "no line sends a garden-only player on an expedition (%d: %s)"
	ok(loose.is_empty(), what % [loose.size(), "; ".join(loose)])
	var open_n := GardenZones.ids().filter(func(z): return GardenZones.is_open(z)).size()
	print("G30 gate: Black Market placed %s, zones open %d of %d, matches %d" % [HomeLayout.placed("ransom", Save.d),
			open_n, GardenZones.ids().size(), int(Save.d["matches"])])
