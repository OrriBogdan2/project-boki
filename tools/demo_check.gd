extends RefCounted
## --demo-check: every recording preset (docs/DEMO_PRESETS.md) boots from its flag and runs a few
## seconds: the farm and care presets land at home with the demo save, the match presets in a match
## (the full bot lobby, the Hollow for tier2, the --hunter pick), the demo save is never written and
## the player's own save file is left byte for byte as it was. Errors show as SCRIPT ERROR lines.

const RUN_SECS := 3.0       # how long each preset plays once it is up
const BOOT_SECS := 40.0     # the most a screen may take to come up (a match builds a world)

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("DEMOCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _wait(secs: float) -> void:
	await main.get_tree().create_timer(secs).timeout

## True once the preset's screen is up (a home built, or a match with its hunters).
func _up(preset: String) -> bool:
	var c: Node = main.current
	if not is_instance_valid(c): return false
	if preset in ["farm", "care"]: return c.get("building") == false and not (c.get("kins") as Array).is_empty()
	return c is Match and c.player != null and not c.hunters.is_empty()

func _boot(preset: String, args: PackedStringArray) -> bool:
	Demo.setup(preset)
	Demo.open(main, preset, args)
	var t := 0.0
	while not _up(preset) and t < BOOT_SECS:
		await _wait(0.25)
		t += 0.25
	await _wait(RUN_SECS)
	return _up(preset)

func run(m: Node) -> void:
	main = m
	var real := FileAccess.get_file_as_string(Save.path_for(Save.slot))
	for preset in Demo.NAMES:
		var args := PackedStringArray(["--demo=" + preset, "--hunter=mage"])
		ok(Demo.name_in(args) == preset, "%s: the flag names the preset" % preset)
		ok(await _boot(preset, args), "%s: boots and runs %.0f s" % [preset, RUN_SECS])
		ok(Save.no_write and Record.clean(), "%s: demo save never written, overlays hidden" % preset)
		if preset in ["farm", "care"]:
			var roster: Array = Save.d["roster"]
			var hungry: bool = roster.all(func(r): return float(r["needs"]["food"]) < Econ.HUNGRY_AT)
			ok(roster.size() >= 6 and hungry == (preset == "care"), "%s: six grown Boki, hungry only in care" % preset)
			ok(HomeGather.has_tool("axe") and HomeGather.has_tool("pickaxe"), "%s: tools unlocked" % preset)
		elif main.current is Match:
			var p: Hunter = main.current.player
			ok(p.arch == "mage", "%s: --hunter=mage picked" % preset)
			if preset in ["match", "tier2"]:
				var n: int = main.current.hunters.size()
				ok(n == Data.MATCH_PLAYERS, "%s: the full bot lobby (%d)" % [preset, n])
	ok(Demo.name_in(PackedStringArray(["--demo=nope"])) == "", "an unknown preset is ignored")
	ok(FileAccess.get_file_as_string(Save.path_for(Save.slot)) == real, "the player's own save file is untouched")
	print("DEMO CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
