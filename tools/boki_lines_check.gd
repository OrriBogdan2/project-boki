extends RefCounted
## --boki-lines-check: Boki talk (BokiLines, content/rules/boki_lines.json, docs/BOKI_TALK.md).
##   1. the data: every trigger has at least min_lines general lines; every line is at most max_words
##      words and one sentence; every action is at most act_words; every tone is a known feeling and
##      just the name; aliases point at real triggers
##   2. every category a caller passes (Kin.bark, KinCompanion callouts, recall kinds) has a trigger
##   3. no Boki repeats a line within its last no_repeat lines, over PICKS picks of every trigger, for
##      every species grown (and three young), and over a mixed run of all triggers
##   4. the cooldown: a Boki that just spoke stays quiet until it ends, unless it's answering you
##   5. a young Boki (stage 0) says only its name, a sound and an action; at stage 1 sometimes the
##      trigger's word too; from grown_stage, real lines

const PICKS := 200
const YOUNG_SPECIES := ["cindle", "puddlet", "zapple"]      # names of different lengths (young pools are names)

var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("BOKILINES %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main: Node) -> void:
	Save.no_write = true
	_data()
	_coverage()
	_no_repeat()
	_cooldown()
	_stages()
	print("BOKILINES DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ 1. the data
func _data() -> void:
	var r := BokiLines.rules()
	var cap := int(BokiLines.tuning("max_words"))
	var act_cap := int(BokiLines.tuning("act_words"))
	var bad_lines: Array = []
	var bad_acts: Array = []
	var thin: Array = []
	var feels_ok := true
	for id in r["triggers"]:
		var t: Dictionary = r["triggers"][id]
		if (t["lines"]["_"] as Array).size() < int(BokiLines.tuning("min_lines")):
			thin.append(id)
		for el in t["lines"]:
			for s in t["lines"][el]:
				if not BokiLines.fits(String(s)):
					bad_lines.append("%s: %s" % [id, s])
		for a in t["acts"]:
			if BokiLines.words(String(a)) > act_cap or not String(a).begins_with("("):
				bad_acts.append("%s: %s" % [id, a])
		feels_ok = feels_ok and r["tones"].has(String(t["feel"]))
	ok("every trigger has >= min_lines general lines", thin.is_empty(), str(thin))
	ok("every line is <= %d words and one sentence" % cap, bad_lines.is_empty(), str(bad_lines))
	ok("every action is <= %d words, in brackets" % act_cap, bad_acts.is_empty(), str(bad_acts))
	ok("every trigger's feeling has tones", feels_ok)
	var tones_ok := true
	for feel in r["tones"]:
		for tone in r["tones"][feel]:
			tones_ok = tones_ok and _name_only(KinSpeak.fill("cindle", String(tone)), "cindle", "")
	ok("every tone is only the name (and a sound)", tones_ok)
	var alias_ok := true
	for a in r["alias"]:
		alias_ok = alias_ok and r["triggers"].has(String(r["alias"][a]))
	ok("aliases point at real triggers", alias_ok)
	ok("a line over the cap or two sentences is caught",
			not BokiLines.fits("One two three four five six seven") and not BokiLines.fits("Hi! You're back!")
			and BokiLines.fits("Hmm... okay, fine.") and BokiLines.fits("That tickles! ♥"))

# ------------------------------------------------------------------ 2. the old banks are covered
## The categories the callers pass (Kin.bark, the KinCompanion callouts, Home's recall as back_<kind>):
## each must resolve to a trigger with lines.
const OLD_NAMES := ["throw", "refuse", "hesitate", "ignore", "scared", "revive", "revive_low", "callout", "wild",
	"kill", "owner_down", "caught", "extract", "behind", "hunter", "sniper", "pack", "boss", "egg", "loot", "exit",
	"collapse", "low_hp", "tonic", "cover", "goad", "yelp", "relief", "boss_kill", "comfort", "back_carried_out",
	"back_boss_kill", "back_revived", "back_stood_over", "back_comforted", "back_knock_together", "back_escaped"]

func _coverage() -> void:
	var missing := OLD_NAMES.filter(func(cat): return BokiLines.trigger(String(cat)).is_empty())
	ok("every match category and recall kind a caller passes has a trigger", missing.is_empty(), str(missing))

# ------------------------------------------------------------------ 3. no repeats
func _no_repeat() -> void:
	var window := int(BokiLines.tuning("no_repeat"))
	var cd := BokiLines.tuning("cooldown_s")
	var cap := int(BokiLines.tuning("max_words"))
	for stage in [3, 1, 0]:
		var worst := ""
		var over := ""
		var empty := ""
		var species: Array = Data.KIN.keys() if stage == 3 else YOUNG_SPECIES
		for sp in species:
			for id in BokiLines.rules()["triggers"]:
				var said: Array = []
				for i in PICKS:
					var s := BokiLines.line("rep_%d_%s_%s" % [stage, sp, id], id, sp, stage, 1000.0 + i * (cd + 0.1))
					if s == "" and empty == "":
						empty = "%s/%s" % [sp, id]
					if BokiLines.words(s) > cap and over == "":
						over = s
					if said.slice(maxi(0, said.size() - window)).has(s) and worst == "":
						worst = "%s/%s: %s" % [sp, id, s]
					said.append(s)
		var lbl := "stage %d: %d picks per trigger, %d species" % [stage, PICKS, species.size()]
		ok(lbl + ": no repeat within %d" % window, worst == "", worst)
		ok(lbl + ": always a line, <= %d words" % cap, empty == "" and over == "", empty + over)
	var ids: Array = BokiLines.rules()["triggers"].keys()
	var said: Array = []
	var worst := ""
	for i in PICKS * 5:
		var s := BokiLines.line("rep_mixed", String(ids[i % ids.size()]), "puddlet", 3, 5000.0 + i * (cd + 0.1))
		if said.slice(maxi(0, said.size() - window)).has(s):
			worst = s
		said.append(s)
	ok("a mixed run of every trigger never repeats within %d" % window, worst == "", worst)

# ------------------------------------------------------------------ 4. the cooldown
func _cooldown() -> void:
	var cd := BokiLines.tuning("cooldown_s")
	var rec := _rec("zapple", 12, 80.0)
	var first := BokiLines.say(rec, "rain", 100.0)
	var early := BokiLines.say(rec, "rain", 100.0 + cd - 0.1)
	var answer := BokiLines.say(rec, "petted", 100.0 + cd - 0.1)
	var after := BokiLines.say(rec, "night", 100.0 + cd + 0.01 + cd)
	ok("it speaks, then stays quiet for cooldown_s (%.1f s)" % cd, first != "" and early == "",
			"%s | %s" % [first, early])
	ok("an answer to you (direct) skips the wait", answer != "", answer)
	ok("after the cooldown it speaks again", after != "", after)
	ok("a cooldown is per Boki", BokiLines.say(_rec("pebbit", 12, 80.0), "rain", 100.0 + 1.0) != "")
	ok("an unknown trigger says nothing", BokiLines.say(rec, "no_such_trigger", 900.0) == "")
	ok("old names share lines (yelp -> hurt)", BokiLines.say(rec, "yelp", 1000.0) in BokiLines.grown_pool(
			BokiLines.trigger("hurt"), "echo"))

# ------------------------------------------------------------------ 5. speech stages
func _stages() -> void:
	var young := _rec("cindle", 1, 0.0)
	var mid := _rec("cindle", 5, 40.0)
	var grown := _rec("cindle", 12, 80.0)
	ok("Care.speech gives stages 0, 1 and 3 for these", Care.speech(young) == 0 and Care.speech(mid) == 1
			and Care.speech(grown) == 3)
	var young_ok := true
	var mid_ok := true
	var mid_words := 0
	var sample := ""
	var t := 2000.0
	for id in BokiLines.rules()["triggers"]:
		var word := String(BokiLines.trigger(id)["word"])
		for i in 12:
			t += 20.0
			var s := BokiLines.say(young, id, t)
			sample = s
			young_ok = young_ok and _name_only(s, "cindle", "")
			var said := BokiLines.say(mid, id, t)
			mid_ok = mid_ok and _name_only(said, "cindle", word)
			mid_words += 1 if said.begins_with(word + "!") else 0
	ok("a young Boki only says its name, in a tone, plus an action", young_ok, sample)
	ok("at stage 1 it sometimes adds the trigger's one word", mid_ok and mid_words > 0, "%d with it" % mid_words)
	var grown_line := BokiLines.say(grown, "crop_ready", t + 20.0)
	ok("a grown Boki says real lines", BokiLines.grown_pool(BokiLines.trigger("crop_ready"),
			BokiLines.element_of("cindle")).has(grown_line), grown_line)
	ok("its element adds flavour lines", BokiLines.grown_pool(BokiLines.trigger("rain"), "lunar").size()
			> BokiLines.grown_pool(BokiLines.trigger("rain"), "").size())

## True if, outside the action in brackets, every word is a piece of the species' name, a sound, or
## the allowed word.
func _name_only(s: String, species: String, word: String) -> bool:
	var spoken := s.get_slice("(", 0)
	var allowed := ["kin"]
	for piece in KinSpeak.SYL.get(species, []):
		allowed.append(String(piece).to_lower())
	allowed.append(String(Data.KIN[species]["name"]).to_lower())
	for snd in BokiLines.rules()["sounds"]:
		allowed.append(String(snd))
	if word != "":
		allowed.append(word.to_lower())
	var re := RegEx.create_from_string("[\\p{L}]+")
	for m in re.search_all(spoken):
		if not allowed.has(m.get_string().to_lower()):
			return false
	return true

func _rec(species: String, level: int, trust: float) -> Dictionary:
	var rec := Save.new_kin(species)
	rec["level"] = level
	rec["trust"] = trust
	return rec
