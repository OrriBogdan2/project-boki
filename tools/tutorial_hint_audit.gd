extends RefCounted
## What every tutorial step said to one starter (--tutorial-playthrough-check): per step the banner line and the
## plain-words line, then the audit: a kit step names THIS Hunter's ability and the key that fires it, no step names
## another starter's ability, and no banner assumes Vex's rifle. Prints one "TUTPLAY hint" row per step.

## step id -> [the Settings action that fires it, the kit slot whose ability name the line shows ("" = no name)]
const KIT_STEPS := {
	"shoot": ["fire", ""],
	"pick_sec": ["secondary", "rmb"],
	"sec": ["secondary", "rmb"],
	"pick_dash": ["dash", "dash"],
	"dash": ["dash", ""],  # (a movement lesson: the pick line names the ability)
	"pick_kin": ["signature", "e"],
	"kin": ["signature", "e"],
}
const STARTER_ARCHS := ["archer", "juggernaut", "gunslinger"]
## Vex's gun: no banner of another Hunter says these
const RIFLE_WORDS := ["ammo", "reload", "rifle", "bullet", "magazine"]

var ak: ArchKit  # the Hunter being played
var lines := {}  # step id -> {"text": ..., "detail": ...} as last shown, plus every distinct line in "all"


## One call per sim step with the step's current banner and plain-words lines.
func note(sid: String, text: String, detail: String, kit: ArchKit) -> void:
	ak = kit
	var rec: Dictionary = lines.get(sid, {"all": []})
	for l in [text, detail]:
		if l != "" and not rec["all"].has(l):
			rec["all"].append(l)
	rec["text"] = text
	lines[sid] = rec


## The failures for this starter (an array of plain sentences) after printing every step's lines.
func audit(starter: String) -> Array:
	var out: Array = []
	var foreign := _foreign_names(starter)
	for sid: String in lines:
		var all: Array = lines[sid]["all"]
		print("TUTPLAY hint %s | %s" % [sid, " / ".join(all)])
		var joined := " ".join(all)
		for n: String in foreign:
			if joined.contains(n):
				out.append("step '%s' names %s's '%s' for %s: %s" % [sid, foreign[n], n, starter, joined])
		if starter != "gunslinger":
			var banner := String(lines[sid]["text"]).to_lower()  # (a plain-words line may quote the kit's own card)
			for w: String in RIFLE_WORDS:
				if banner.contains(w):
					out.append("step '%s' talks about '%s' for %s: %s" % [sid, w, starter, banner])
		if KIT_STEPS.has(sid):
			out.append_array(_kit_step(sid, String(lines[sid]["text"])))
	return out


func _kit_step(sid: String, text: String) -> Array:
	var out: Array = []
	var want: Array = KIT_STEPS[sid]
	var cap := Settings.key_cap(String(want[0]))
	if not text.contains(cap):
		out.append("step '%s' does not show the %s key (%s): %s" % [sid, want[0], cap, text])
	if want[1] != "":
		var def: Dictionary = {"rmb": ak.rmb_def(), "dash": ak.dash_def(), "e": ak.e_def()}[want[1]]
		var ab := String(def.get("name", ""))
		if ab == "" or not text.contains(ab):
			out.append("step '%s' does not name this Hunter's ability '%s': %s" % [sid, ab, text])
	return out


## Every ability name of the other two starters -> whose it is (a name two Hunters share is not foreign).
func _foreign_names(starter: String) -> Dictionary:
	var mine := _names(starter)
	var out := {}
	for a: String in STARTER_ARCHS:
		if a == starter:
			continue
		for n in _names(a):
			if not mine.has(n):
				out[n] = a
	return out


func _names(arch: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/archetypes/%s.json" % arch))
	var out := {}
	for slot in ["dash", "rmb", "e", "x"]:
		var n := String(d.get(slot, {}).get("name", ""))
		if n != "":
			out[n] = true
	return out
