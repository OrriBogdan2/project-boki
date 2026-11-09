extends RefCounted
## --tip-text-check: glide wording. The glider opens on a jump and then a second press in the air,
## held; nothing player-facing says "hold Space/jump to glide", and the tutorial and loading tips
## name the key through Settings.key_cap, never a letter.

var bad := 0

const FILES := ["res://content/rules/tutorial.json", "res://scripts/ui/loading.gd", "res://scripts/core/settings.gd",
	"res://README.md", "res://docs/KINFALL_CLASSES.md", "res://docs/wiki/Controls.md", "res://docs/wiki/Expeditions.md"]
const KEYED := ["res://content/rules/tutorial.json", "res://scripts/ui/loading.gd"]

func ok(cond: bool, what: String) -> void:
	print("TIPTEXT %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	var old := RegEx.create_from_string("(?i)hold[^.\\n]*glide|glide[^.\\n]*hold")
	var letter := RegEx.create_from_string("\\b(Space|Mouse 5)\\b")
	for f: String in FILES:
		var s := FileAccess.get_file_as_string(f)
		ok(s != "", f + " is readable")
		var wrong := ""
		for line in s.split("\n"):
			if old.search(line) and not "again" in line and not "heat" in line:
				wrong = line.strip_edges().left(70)
		ok(wrong == "", f + " has no hold-to-glide wording: " + wrong)
		if f in KEYED:
			ok(letter.search(s) == null, f + " names no key by letter")
	print("TIPTEXT DONE, failures: ", bad)
	mn.get_tree().quit(1 if bad > 0 else 0)
