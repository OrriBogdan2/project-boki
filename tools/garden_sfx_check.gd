extends RefCounted
## --garden-sfx-check: the farm's reactions each play their own cue and `unlock` is left for real unlocks.
## Reads the sources: each garden function below must play its cue and no "unlock"; every cue is
## distinct, listed in the UI sound set and loads. The Boki eat and nap sounds play from the care states.
## Never touches the save.

## [file, function, sound it must play]; function "" = the whole file, where the one `unlock` left is the
## real Add-a-slot upgrade
const REACTIONS := [
	["scripts/home/home.gd", "_pet_kin", "garden_pet"],
	["scripts/home/home.gd", "_after_feed", "garden_feed"],
	["scripts/home/home.gd", "_play_with_kin", "garden_toy"],
	["scripts/home/home.gd", "_make_egg", "garden_egg"],
	["scripts/ui/incubator_view.gd", "", "garden_egg"],
	["scripts/home/home.gd", "_play_evolutions", "garden_trait"],
	["scripts/ui/results.gd", "_kin_card", "garden_trait"],
	["scripts/home/home.gd", "_move_kin", "garden_friend"],
	["scripts/home/home.gd", "_care_feed", "boki_eat"],
	["scripts/home/home_econ.gd", "feed_step", "boki_eat"],
	["scripts/home/home.gd", "_care_step", "boki_sleep"],
	["scripts/home/home.gd", "_care_nap", "boki_sleep"],
]
const CUES := ["garden_feed", "garden_pet", "garden_friend", "garden_trait", "garden_egg", "garden_toy"]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("GARDENSFX %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

## The text of one function (up to the next top-level func), or the whole file for "".
func _body(src: String, fn: String) -> String:
	if fn == "":
		return src
	var at := src.find("\nfunc %s(" % fn)
	if at < 0:
		at = src.find("\nstatic func %s(" % fn)
	if at < 0:
		return ""
	var end := src.find("\nfunc ", at + 5)
	return src.substr(at, (end if end > 0 else src.length()) - at)

func run(main: Node) -> void:
	var set_d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/sfx/ui.json"))
	var seen := {}
	for c in CUES:
		ok(not seen.has(c) and c != "unlock", "%s is its own cue" % c)
		seen[c] = true
		ok((set_d["sounds"] as Dictionary).has(c) and Sfx.ensure(c), "%s is in the UI set and loads" % c)
	for r in REACTIONS:
		var body := _body(FileAccess.get_file_as_string("res://" + String(r[0])), String(r[1]))
		var tag := "%s %s" % [String(r[0]).get_file(), String(r[1])]
		ok(body.contains('Sfx.play("%s"' % String(r[2])), "%s plays %s" % [tag, r[2]])
		var left := body.count('"unlock"')
		ok(left == (1 if String(r[1]) == "" else 0), "%s keeps no unlock for a reaction (%d left)" % [tag, left])
	ok(Sfx.ensure("boki_eat") and Sfx.ensure("boki_sleep"), "the Boki eat and nap sounds load")
	print("GARDENSFX DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
