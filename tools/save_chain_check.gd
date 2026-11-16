extends RefCounted
## --save-chain-check (docs/SAVE_CHAIN_0245.md): the save chain is one unbroken line. Every version from 1
## up to Save.VERSION has exactly one step, named for its numbers, and the doc lists every step from v11 on.
## A played v11 save (the last tagged release's, v0.24.3) runs every step in order and comes out with each
## step's change; running the chain again from v11 changes nothing (every step only adds what is missing);
## a dev save from the line that used v13 for first-time hints still gets the garden half; a newer save is
## refused. Never touches the real save.

const DOC := "res://docs/SAVE_CHAIN_0245.md"
const FIRST := 11  # the last released save version (v0.24.3); the doc's chain starts here

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SAVE-CHAIN %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	Save.no_write = true
	_steps()
	_from_v11()
	_clash_v13()
	_chain_v18()
	var newer := {"v": Save.VERSION + 1, "roster": []}
	ok(not Save.migrate(newer) and int(newer["v"]) == Save.VERSION + 1, "a save from a newer game is refused")
	print("SAVE-CHAIN DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)


## One step per version, named for its numbers, each one listed in the doc.
func _steps() -> void:
	var keys := Save.MIGRATIONS.keys()
	keys.sort()
	var want := range(1, Save.VERSION)
	ok(keys == want, "one step for every version 1..%d (%s)" % [Save.VERSION - 1, str(keys)])
	var named := keys.all(func(v): return Save.MIGRATIONS[v] == "_migrate_%d_to_%d" % [v, v + 1])
	ok(named, "each step is named _migrate_<n>_to_<n+1>")
	var doc := FileAccess.get_file_as_string(DOC)
	var missing: Array = []
	for v in range(FIRST, Save.VERSION):
		if not doc.contains("| v%d -> v%d |" % [v, v + 1]):
			missing.append(v)
	ok(not doc.is_empty() and missing.is_empty(), "the doc lists every step from v%d (missing %s)" % [FIRST, missing])


## A played v11 save: a Boki past the level cap, a guild, a played tutorial, nothing a later step adds.
func _v11() -> Dictionary:
	var data := Save.fresh()
	var rec := Save.new_kin("cindle", "Old")
	rec["level"] = 999
	for key in ["was", "bonds", "zone", "needs", "needs_t"]:
		rec.erase(key)
	data["roster"] = [rec]
	for key in ["sleepovers", "drills", "clan", "zones"]:
		data.erase(key)
	data["v"] = FIRST
	data["guild_id"] = "g42"
	data["profile"] = {"id": "p7"}
	data["matches"] = 3
	data["tutorial"] = {"hatched": true}
	return data


func _from_v11() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_v11()))
	ok(Save.migrate(data) and int(data["v"]) == Save.VERSION, "a v11 save upgrades to v%d" % Save.VERSION)
	var rec: Dictionary = data["roster"][0]
	var capped := int(rec["level"]) == Evo.cap() and rec.has("was")
	ok(capped, "v11 -> v12: Evo (level capped at %d, old form kept)" % Evo.cap())
	ok(rec["bonds"] == {}, "v11 -> v12: base life (no friends or rivals yet)")
	var zoned: bool = data["zones"] is Dictionary and rec["zone"] == GardenZones.start()
	ok(zoned, "v12 -> v13: garden zones, the Boki in the start zone")
	ok(rec.has("needs") and rec.has("needs_t"), "v12 -> v13: shaping items (Care.ensure on every Boki)")
	ok(data["active2"] == "", "v13 -> v14: carry 2, the second starts empty")
	ok(data["drills"] == {}, "v14 -> v15: no drill times yet")
	ok(bool(data["tutorial"].get("match", false)), "v15 -> v16: a played save is past the combat tutorial")
	var clan := Social.clan_for("g42", "p7", "member", 0.0)
	ok(data["clan"] == clan, "v16 -> v17: the guild becomes its clan, as a member")
	var keys := [XpHints.KILL_KEY, XpHints.STEAL_KEY, XpHints.SHARE_KEY]
	var hints := keys.all(func(k): return data["tutorial"][k] == false)
	ok(hints, "v17 -> v18: the XP first-time lines are unseen")
	ok(data["sleepovers"] == [], "v18 -> v19: no Boki away on a sleepover")
	data["clan"]["role"] = "elder"
	var once := JSON.stringify(data)
	data["v"] = FIRST
	var same := Save.migrate(data) and JSON.stringify(data) == once
	ok(same, "the chain again from v11 changes nothing (the clan role stays)")


## A dev save from this chain before main took v14 (drills v14 .. sleepovers v18, no carry 2) gets its empty second.
func _chain_v18() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_v11()))
	data.erase("active2")
	data["v"] = 18
	ok(Save.migrate(data) and data.get("active2", null) == "", "a v18 dev save from the old chain gets carry 2")


## The other line's v13: Evo and first-time hints, no base life or zones. It must still get them.
func _clash_v13() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_v11()))
	Evo.migrate(data)
	data["v"] = 13
	var rec: Dictionary = data["roster"][0]
	ok(
		Save.migrate(data) and rec["bonds"] == {} and rec.has("zone") and data["zones"] is Dictionary,
		"a first-time-hints v13 dev save still gets base life and zones"
	)
