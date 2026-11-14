class_name RecastHint
extends RefCounted
## The first recast window a save ever sees gets one hint line in the message lane, "<KEY> AGAIN to <verb>"
## (DECISIONS 2026-11-08: a two-step ability is a contextual hint, not a tutorial step). The key is the live
## binding (Settings.key_cap); the verb is the kit's own, read from its ability text ("press E again to blink
## to it" -> "blink"). The line lives as long as the window; the message lane never takes input. Seen once:
## Save.d["tutorial"]["recast_seen"], set for old saves that have played (migrate).
## Text: content/rules/tips.json "hints".

const FLAG := "recast_seen"
const FALLBACK_VERB := "finish it"
## "...again... to <verb>" in the ability text: the verb, with its particle ("land early", "pop it", "call it back").
const VERB_PATTERN := "(?:again|recast)\\b.*?\\bto (be \\w+|\\w+(?: (?:it|down|out|early|on|back))*)"
static var _verb_re := RegEx.create_from_string(VERB_PATTERN)

## The window `w` just opened on the local hunter's kit: says the hint if this save hasn't seen it. Returns the
## line ("" when nothing was said).
static func opened(k: ArchKit, w: Dictionary) -> String:
	var seen: Dictionary = Save.d["tutorial"]
	var m := k.m as Match
	if seen.get(FLAG, false) or m.tut != null or Record.clean() or not Settings.get_v("tips"):
		return ""
	seen[FLAG] = true
	var text := line(k, String(w["slot"]))
	if m.hud != null:
		m.hud.tip(text, "", maxf(float(w["left"]), 1.0))
	return text

## "<KEY> AGAIN to <verb>" for the kit's recast on `slot`.
static func line(k: ArchKit, slot: String) -> String:
	return String(TipPick.rules()["hints"]["recast"]).format({"key": RecastCue.key_of(slot), "verb": verb(k, slot)})

## The kit's own verb for the recast on `slot`, from its ability text (FALLBACK_VERB when the text has none).
static func verb(k: ArchKit, slot: String) -> String:
	var defs := {"e": k.e_def(), "x": k.x_def(), "dash": k.dash_def(), "lmb": k.lmb_def()}
	var text := String((defs.get(slot, k.rmb_def()) as Dictionary).get("desc", ""))
	if text == "":
		text = String((k.d.get("card", {}) as Dictionary).get(slot, ""))
	var found := _verb_re.search(text)
	return found.get_string(1) if found != null else FALLBACK_VERB

## Old saves: one that has played already has met two-step abilities; a new one is still to see the hint
## (keyed by its own field, like FirstMatchGuide).
static func migrate(data: Dictionary) -> void:
	if typeof(data.get("tutorial")) != TYPE_DICTIONARY:
		data["tutorial"] = {}
	if not data["tutorial"].has(FLAG):
		data["tutorial"][FLAG] = int(data.get("matches", 0)) > 0
