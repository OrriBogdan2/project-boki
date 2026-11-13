extends RefCounted
## --tutorial-clean-check: the tutorial course has nothing random on it. After the build there is no
## chest, and no crates, pots, shrines, wild kin or mobs are out; the world makes no spots for them
## (the course's glove lies on the ground). Then a scripted run of the whole course: it never brings
## any wild kin, chest or breakable. And the tutorial's cooldowns run four times
## quicker, while a real match's and a training match's do not. And the tutorial, hint and kit-drill
## text never names a cut feature (DECISIONS 2026-11-07: Albert's Guard meter and Shield Slam, Lace's Focus
## and Deadeye, Neve's Chill slow, Sable's empowered Shred, Meeko's carrier shield).

## Cut features and their old names (matched in any case); none may be in the tutorial, hint or drill text.
const CUT_WORDS := [
	"shield slam", "guard (meter|pips?|bar)", "deadeye", "focus (meter|pips?|bar|points?)",
	"chill\\w*[^.]{0,20}slow", "slow[^.]{0,20}chill", "empowered shred", "shred[^.]{0,12}empower", "carrier shield"]
const TEXT_FILES := ["res://content/rules/tutorial.json", "res://content/rules/first_match_guide.json"]

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("TUTCLEAN %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	var m := Match.new()
	main.add_child(m)
	m.start({"tutorial": true, "teams": 1, "squad": 1, "tier": 0, "length": 1500.0, "demo_kin": "cindle"})
	m.set_process(false)
	_built(m)
	_cut_text()
	var tut_cd := _cd_after(m, 1.0)
	ok(tut_cd < 6.5, "tutorial: a 10 s air-dash cooldown has %.1f s left after 1 s" % tut_cd)
	_run_course(m)
	for kind in ["real", "training"]:
		var other := Match.new()
		main.add_child(other)
		var o := {"training": kind == "training", "no_drop": true, "teams": 1, "squad": 1, "tier": 0}
		other.start(o)
		other.set_process(false)
		var cd := _cd_after(other, 1.0)
		ok(cd > 8.9, "%s match: the same cooldown has %.1f s left after 1 s" % [kind, cd])
		other.queue_free()
	print("TUTCLEAN DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

func _built(m: Match) -> void:
	var w := m.world
	ok(w.chest_spots.is_empty() and w.break_spots.is_empty() and w.wild_spots.is_empty() and w.shrine_spots.is_empty(),
			"the world makes no chest, breakable, wild or shrine spots")
	ok(m.chests.is_empty(), "no chests (%d)" % m.chests.size())
	ok(m.breaks.is_empty(), "no crates, pots or kegs (%d)" % m.breaks.size())
	ok(m.shrines.is_empty(), "no shrines (%d)" % m.shrines.size())
	var wild := m.kins.filter(func(k): return k.is_wild()).size()
	ok(wild == 0, "no wild kin (%d)" % wild)
	ok(m.mobs.is_empty(), "no mobs before the course asks for them (%d)" % m.mobs.size())

## No cut feature's name in the tutorial and guide text, nor in any Hunter's drill lines or ability tip.
func _cut_text() -> void:
	var re := RegEx.create_from_string("(?i)" + "|".join(CUT_WORDS))
	var hits: Array = []
	for f: String in TEXT_FILES:
		var hit := re.search(FileAccess.get_file_as_string(f))
		if hit: hits.append("%s: %s" % [f.get_file(), hit.get_string()])
	for id: String in Arch.ids():
		var lines: Array = KitDrill.steps(id).map(func(s): return String(s["line"]))
		for line: String in lines:
			var hit := re.search(line)
			if hit: hits.append("%s drill: %s" % [id, hit.get_string()])
	ok(hits.is_empty(), "no cut feature in the tutorial, guide or kit-drill text %s" % [hits])

## Seconds left on a 10 s air-dash cooldown after `secs` of play.
func _cd_after(m: Match, secs: float) -> float:
	if m.tut:
		m.tut.ack()          # (past the intro card, where the match waits, and the first step's own reset)
		m.step(Match.DT)
	m.player.ex_cd = 10.0
	for i in int(secs / Match.DT):
		m.step(Match.DT)
	return m.player.ex_cd

func _run_course(m: Match) -> void:
	var t := 0.0
	var chests := 0
	var extra_breaks := 0
	var wild := 0
	while t < 600.0 and not m.player.extracted:
		TutorialDrive.drive(m)
		m.step(Match.DT)
		t += Match.DT
		chests = maxi(chests, m.chests.size())
		extra_breaks = maxi(extra_breaks, m.breaks.size())
		wild = maxi(wild, m.kins.filter(func(k): return k.is_wild()).size())
	ok(m.player.extracted, "the course runs to the exit (%.0fs)" % t)
	ok(chests == 0 and extra_breaks == 0, "no chest or breakable ever appeared")
	ok(wild == 0, "no wild kin ever appeared (%d)" % wild)
