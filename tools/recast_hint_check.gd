extends "res://tools/hero_pair_check.gd"
## --recast-hint-check: the first-recast teaching line (RecastHint, DECISIONS 2026-11-08 two-step abilities). Over
## the 12 kits: each recast kit reports its window and the line carries the live key; once per Hunter per profile;
## held back one second when a rival is in range; and a real cast (Brimseed) raises it through the kit tick.

const NO_RECAST := ["archer", "dredge", "gunslinger"]     # no recast window today: always closed

func run(main_node: Node) -> void:
	main = main_node
	Settings.v["tips"] = true
	for arch in Arch.ids():
		_kit(String(arch))
	_gating()
	_real_cast()
	print("PAIRCHECK recast-hint DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

## Opens the kit's window by hand (state only: the match is not stepped), true when this kit has one to open.
func _open(K: ArchKit) -> bool:
	match K.id:
		"ashwick": K.jet.flight = {"t": 1.0}
		"bulwark":
			K.mace = {"st": "ground", "pos": K.h.pos, "t": 0.0}
			K.throw_at = -9.0
		"dolm": K.hop.st = {"n": 1, "phase": "air"}
		"juggernaut": K.warchain.state = "hooked"
		"mage": K.ult.leap = {"phase": MageUlt.AIR}
		"ostra": K.seed = {"pos": K.h.pos, "t": 1.0}
		"rimewright": K.wall = {"sliding": true}
		"tender": K.hearth = {"tossed": false}
		"thief": K.knife = {"pos": K.h.pos}
		_: return false
	return true

func _close(K: ArchKit) -> void:
	match K.id:
		"ashwick": K.jet.flight = {}
		"bulwark": K.mace = {}
		"dolm": K.hop.st = {}
		"juggernaut": K.warchain.state = "ready"
		"mage": K.ult.leap = {}
		"ostra": K.seed = {}
		"rimewright":
			K.wall = {}
			K.rime = {}
		"tender": K.hearth = {}
		"thief": K.knife = {}

func _kit(arch: String) -> void:
	var r := setup(arch, 40.0)
	var K: ArchKit = r[1].ak
	var opens := _open(K)
	var w := K.recast_open()
	var good := w.size() == 2 and Settings.key_cap(String(w[0])) != "?" and String(w[1]) != ""
	if opens:
		ok("%s: the open window reports a key and a verb" % arch, good)
	else:
		ok("%s: no recast window, stays closed" % arch, w.is_empty() and arch in NO_RECAST)
	if arch == "rimewright":
		_close(K)
		K.rime = {"t": 0.0}
		ok("rimewright: Rimelock's early window stays closed (X only breaks the shell)", K.recast_open().is_empty())
		K.rime = {"t": float(K.x_def()["hold"])}
		ok("rimewright: Rimelock's late window opens on X", K.recast_open().slice(0, 1) == ["hunter_ult"])
	_close(K)
	ok("%s: closed again once the window ends" % arch, K.recast_open().is_empty())
	r[0].queue_free()

func _gating() -> void:
	var r := setup("ostra", 40.0)
	var m: Match = r[0]
	var K: ArchKit = r[1].ak
	var seen: Dictionary = Save.d["tutorial"]
	seen.erase(RecastHint.seen_key(K))
	_open(K)
	RecastHint.track(K)
	var want := "Press %s again to pop the seed" % Settings.key_cap("signature")
	ok("a rival out of range: the line shows at once, with the live key",
		seen.get("recast_ostra", false) and RecastHint.line(K.recast_open()) == want)
	seen.erase("recast_ostra")
	r[2].teleport(r[1].pos + Vector3(10, 0, 0))
	RecastHint.track(K)
	ok("a rival in range at the moment the window opens: held back", not seen.get("recast_ostra", false))
	m.time += RecastHint.FIGHT_GRACE * 0.5
	RecastHint.track(K)
	ok("... still held back half a second in", not seen.get("recast_ostra", false))
	m.time += RecastHint.FIGHT_GRACE * 0.6
	RecastHint.track(K)
	ok("... shown once the first second of the fight is over", seen.get("recast_ostra", false))
	m.queue_free()

func _real_cast() -> void:
	var r := setup("ostra", 40.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var seen: Dictionary = Save.d["tutorial"]
	seen.erase("recast_ostra")
	aim_at(P, P.pos + Vector3(5, 0, 0))
	P.ak.use_e()
	step(m, 1.5)
	ok("Brimseed cast for real: the kit tick raises the line", seen.get("recast_ostra", false))
	m.queue_free()
