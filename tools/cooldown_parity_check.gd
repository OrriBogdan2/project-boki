extends RefCounted
## --cooldown-parity-check: every kit's cooldowns are the source's level-1 values (docs/KIT_PARITY.md, 1.0x of data).
## Rows: hero id, slot path in the archetype JSON, source seconds.
const SOURCE := [
	["gunslinger", "rmb", 9.0], ["gunslinger", "e", 12.0], ["gunslinger", "x", 55.0],
	["gunslinger", "dash", 11.5],
	["juggernaut", "rmb", 2.5], ["juggernaut", "rmb.drop", 9.0], ["juggernaut", "e", 16.0],
	["juggernaut", "x", 45.0], ["juggernaut", "dash", 13.0],
	["ashwick", "rmb", 9.0], ["ashwick", "e", 13.0], ["ashwick", "x", 45.0], ["ashwick", "dash", 9.0],
	["tender", "rmb", 11.5], ["tender", "e", 12.0], ["tender", "x", 60.0], ["tender", "dash", 7.0],
	["tender", "dash.air", 14.0],
	["dredge", "rmb", 18.0], ["dredge", "e", 12.0], ["dredge", "x", 36.0], ["dredge", "dash", 7.0],
	["mage", "rmb", 10.0], ["mage", "e", 12.0], ["mage", "x", 60.0], ["mage", "dash", 9.0],
	["rimewright", "rmb", 12.0], ["rimewright", "e", 20.0], ["rimewright", "x", 80.0],
	["rimewright", "dash", 13.0],
	["thief", "rmb", 13.0], ["thief", "e", 28.0], ["thief", "x", 50.0], ["thief", "dash", 5.0],
	["bulwark", "rmb", 6.0], ["bulwark", "x", 50.0], ["bulwark", "dash", 8.0],
	["archer", "rmb", 16.0], ["archer", "e", 15.0], ["archer", "x", 60.0], ["archer", "dash", 9.5],
	["dolm", "rmb", 11.0], ["dolm", "e", 12.5], ["dolm", "x", 45.0], ["dolm", "dash", 12.0],
	["ostra", "rmb", 10.0], ["ostra", "e", 10.0], ["ostra", "x", 70.0], ["ostra", "dash", 9.5],
]
var bad := 0

func run(main: Node) -> void:
	for row in SOURCE:
		var slot: Dictionary = Arch.def(row[0])
		for key in String(row[1]).split("."):
			slot = slot.get(key, {})
		var got := float(slot.get("cd", slot.get("cooldown", -1.0)))
		var good := is_equal_approx(got, row[2])
		if not good:
			bad += 1
		print("COOLDOWN %s %s.%s %.1f s (source %.1f)" % ["ok  " if good else "FAIL", row[0], row[1], got, row[2]])
	print("COOLDOWN CHECK DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
