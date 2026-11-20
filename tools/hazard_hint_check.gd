extends RefCounted
## --hazard-hint-check: the first-time hint about each terrain hazard kind (HazardHint). Per kind, on
## a fresh save, two players near it: a lead Boki that cannot cross it (the line says what it does and
## nothing about crossing) and one that can (names it and says cross). The line shows once per kind
## per save (also after a save round trip), not in the tutorial match, not with tips off. Never touches the save file.

const COUNTER := {"lava": "cindowary", "deep_water": "lilybara", "ice": "floenatee", "static": "kestrike",
	"bramble": "heatherhorn"}
const PLAIN := "cindle"
var m: Match
var tz: TerrainHazards
var n := 0
var fails := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("HAZHINT %-70s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	Settings.set_v("tips", true, false)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "demo_kin": PLAIN,
		"demo_kin_lv": "12:95"})
	m.set_process(false)
	tz = TerrainHazards.of(m)
	for kind in COUNTER:
		_kind(kind)
	_gates()
	print("HAZHINT CHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _species(k: Kin, species: String) -> void:
	k.species = species
	k.sp = Data.KIN[species]

## What the HUD shows when the player, with this lead Boki, walks up to the kind.
func _says(kind: String, lead: String) -> String:
	var P := m.player
	_species(P.kin as Kin, lead)
	for ai in tz.areas.size():
		if tz.areas[ai]["kind"] == kind:
			var c: Vector3 = tz.areas[ai]["centre"]
			P.teleport(Vector3(c.x, float(tz.areas[ai]["y"]), c.z))
			break
	Save.d["tutorial"].erase(HazardHint.FLAG + kind)
	m.hud.msgs.clear()
	tz.hinted.clear()
	tz._hint()
	var lines: Array = m.hud.msgs.texts()
	return String(lines[0]) if lines.size() == 1 else "<%d lines>" % lines.size()

func _kind(kind: String) -> void:
	var tip := String(TerrainHazards.kind_def(kind)["tip"])
	var safe: String = COUNTER[kind]
	var said := _says(kind, PLAIN)
	ok("%s, not immune: says what it does, nothing about crossing" % kind, said == tip, said)
	said = _says(kind, safe)
	var lead_ok := said.begins_with(tip) and said.ends_with("keeps you safe: cross it.")
	ok("%s, lead immune: names it and says cross" % kind, lead_ok, said)
	m.hud.msgs.clear()
	tz.hinted.clear()
	tz._hint()
	ok("%s: said once, not again" % kind, m.hud.msgs.texts().is_empty())

func _gates() -> void:
	Save.d["tutorial"].erase("hazard_lava")
	m.opts["tutorial"] = true
	var quiet := _says("lava", PLAIN).begins_with("<0")
	ok("no line in the tutorial match", quiet and not Save.d["tutorial"].has("hazard_lava"))
	m.opts["tutorial"] = false
	Settings.set_v("tips", false, false)
	ok("no line with tips off", _says("lava", PLAIN).begins_with("<0"))
	Settings.set_v("tips", true, false)
	var said := _says("lava", PLAIN)
	ok("with both back on, the line shows", said == String(TerrainHazards.kind_def("lava")["tip"]), said)
	Save.d = JSON.parse_string(JSON.stringify(Save.d))
	m.hud.msgs.clear()
	tz.hinted.clear()
	tz._hint()
	ok("after a save round trip it never shows again", m.hud.msgs.texts().is_empty())
