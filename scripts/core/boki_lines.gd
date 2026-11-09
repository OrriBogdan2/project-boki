class_name BokiLines
extends RefCounted
## What a Boki says out loud, at home and in a match: short lines by trigger (what's happening) from
## content/rules/boki_lines.json. Each Boki keeps its last few lines and never repeats one inside
## that window, and waits out a cooldown between lines unless it's answering something you did. A
## young Boki only says its name, in a tone, plus a little action (the stage comes from Care.speech;
## the name from KinSpeak.fill). See docs/BOKI_TALK.md.

const RULES_PATH := "res://content/rules/boki_lines.json"

static var _rules := {}
static var _recent := {}         # boki id -> Array of its last lines, oldest first
static var _quiet_until := {}    # boki id -> clock seconds before it may speak up again
static var _word_re: RegEx = null
static var _two_re: RegEx = null

## The whole rules file (read once).
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules = parsed if parsed is Dictionary else {"tuning": {}, "tones": {}, "alias": {}, "triggers": {}}
	return _rules

## A tuning number from the rules file (max_words, bubble_s, cooldown_s, no_repeat...).
static func tuning(key: String) -> float:
	return float(rules()["tuning"].get(key, 0.0))

## Seconds a speech bubble stays up.
static func bubble_s() -> float:
	return tuning("bubble_s")

## A trigger's data (an old name resolves through the alias table); empty if there is none.
static func trigger(id: String) -> Dictionary:
	var r := rules()
	var key := String(r["alias"].get(id, id))
	return r["triggers"].get(key, {})

## A species' element (its type, e.g. "venom"), which picks the extra flavour lines.
static func element_of(species: String) -> String:
	return String(Data.KIN.get(species, {}).get("type", ""))

## What this Boki (a save record) says for a trigger, at its own talking level; "" while it's on
## cooldown, or if the trigger is unknown. now_s: the clock in seconds (tests pass their own).
static func say(rec: Dictionary, trigger_id: String, now_s := -1.0) -> String:
	var species := String(rec.get("species", ""))
	var id := String(rec.get("uid", species))
	return line(id, trigger_id, species, Care.speech(rec), now_s)

## The line itself: boki_id keys its memory and cooldown; stage is its Care.speech level; extra are
## its own personal lines (used when they fit the word cap and are one sentence).
static func line(boki_id: String, trigger_id: String, species: String, stage: int, now_s := -1.0,
		extra: Array = []) -> String:
	var t := trigger(trigger_id)
	if t.is_empty():
		return ""
	var now := now_s if now_s >= 0.0 else Time.get_ticks_msec() / 1000.0
	if not bool(t.get("direct", false)) and now < float(_quiet_until.get(boki_id, -1.0)):
		return ""
	var pool: Array
	if stage >= int(tuning("grown_stage")):
		pool = grown_pool(t, element_of(species), extra)
	else:
		pool = young_pool(t, species, stage)
	if pool.is_empty():
		return ""
	var s := _fresh(boki_id, pool)
	_quiet_until[boki_id] = now + tuning("cooldown_s")
	var recent: Array = _recent.get(boki_id, [])
	recent.append(s)
	while recent.size() > int(tuning("no_repeat")):
		recent.pop_front()
	_recent[boki_id] = recent
	return s

## Everything a grown Boki might say for a trigger: the general lines, its element's, and its own.
static func grown_pool(t: Dictionary, element: String, extra: Array = []) -> Array:
	var lines: Dictionary = t.get("lines", {})
	var pool: Array = (lines.get("_", []) as Array).duplicate()
	if element != "":
		pool.append_array(lines.get(element, []))
	for e in extra:
		if fits(String(e)):
			pool.append(String(e))
	return pool

## Everything a young Boki might say: its name in the trigger's tone and one of its actions; from
## stage 1 also with the trigger's one word in front. A line over the word cap is left out.
static func young_pool(t: Dictionary, species: String, stage: int) -> Array:
	var tones: Array = rules()["tones"].get(String(t.get("feel", "content")), [])
	var word := String(t.get("word", ""))
	var pool: Array = []
	for tone in tones:
		var said := KinSpeak.fill(species, String(tone))
		for act in t.get("acts", []):
			pool.append("%s %s" % [said, act])
			if stage >= 1 and word != "":
				pool.append("%s! %s %s" % [word, said, act])
	return pool.filter(func(s): return words(s) <= int(tuning("max_words")))

## How many words a line has (bits with a letter or digit; punctuation and symbols don't count).
static func words(text: String) -> int:
	if _word_re == null:
		_word_re = RegEx.create_from_string("[\\p{L}\\p{N}]")
	var n := 0
	for part in text.split(" ", false):
		if _word_re.search(part) != null:
			n += 1
	return n

## Whether a line is a single sentence (an ellipsis inside it is a pause, not an end).
static func one_sentence(text: String) -> bool:
	if _two_re == null:
		_two_re = RegEx.create_from_string("([!?]+|(?<!\\.)\\.)\\s+[\\p{L}\\p{N}]")
	return _two_re.search(text.strip_edges()) == null

## Whether a line is short enough and one sentence.
static func fits(text: String) -> bool:
	return words(text) <= int(tuning("max_words")) and one_sentence(text)

## A line from the pool this Boki hasn't said lately; if it said them all, the one it said longest ago.
static func _fresh(boki_id: String, pool: Array) -> String:
	var recent: Array = _recent.get(boki_id, [])
	var unsaid := pool.filter(func(s): return not recent.has(s))
	if not unsaid.is_empty():
		return String(unsaid.pick_random())
	var oldest := String(pool[0])
	for s in pool:
		if recent.find(s) < recent.find(oldest):
			oldest = String(s)
	return oldest
