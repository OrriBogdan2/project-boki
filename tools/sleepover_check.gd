extends RefCounted
## --sleepover-check (docs/decisions/0022-sleepovers.md): a Boki goes to a friend's garden and is off the roster;
## nothing happens before a day; then it comes home with a memory line, traits nudged toward the host's lead Boki,
## a seed from their patch and, for a trade species, its next form; the last/lead Boki cannot go; a v12 save
## upgrades with no Boki away. Never touches the real save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("SLEEPOVER %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	Save.no_write = true
	var old := Save.fresh()
	old["v"] = 13
	old.erase("sleepovers")
	var up := Save.migrate(old) and int(old["v"]) == Save.VERSION
	ok(up and old["sleepovers"] == [], "a v13 save upgrades with no Boki away")
	Save.d = Save.fresh()
	var lead := Save.new_kin("zapple", "Lead")
	var guest := Save.new_kin("kilnbadger", "Ember")
	var plain := Save.new_kin("burrlet", "Moss")
	for r in [lead, guest, plain]:
		Save.d["roster"].append(r)
	Save.d["active"] = lead["uid"]
	ok(Sleepover.why_not(lead) != "", "the lead Boki cannot go")
	var t0 := 1000.0
	guest["traits"]["bravery"] = 0.2
	var sent := Sleepover.send(guest, "friend1", "Pia", t0)
	ok(sent and Save.kin(guest["uid"]).is_empty(), "a Boki goes and leaves the roster")
	var early := Sleepover.due(t0 + Sleepover.DAY_SECS - 1.0)
	ok(early.is_empty() and Sleepover.due(t0 + Sleepover.DAY_SECS).size() == 1, "it is due after a day, not before")
	var crop: String = Data.CROPS.keys()[0]
	var wick := {"uid": "h", "species": "cindle", "name": "Wick", "level": 3}
	var host := Social.clean_island({"name": "Pia", "roster": [wick],
		"plots": [{"crop": "", "stage": 0}, {"crop": crop, "stage": 3}]})
	host["roster"][0]["traits"]["bravery"] = 0.9
	var seeds_before := int(Save.d["seeds"].get(crop, 0))
	var res := Sleepover.come_home(Sleepover.list()[0], host)
	var back := Save.kin(guest["uid"])
	ok(not back.is_empty() and Sleepover.list().is_empty(), "it comes home to the roster")
	var want := 0.2 + 0.7 * Sleepover.TRAIT_PULL
	ok(absf(float(back["traits"]["bravery"]) - want) < 0.001, "its bravery moved 10% toward the host's Boki")
	var kind := String(back["memory"][-1]["kind"])
	ok(kind == "sleepover" and "Wick" in String(res["line"]), "it has a memory line naming the host's Boki")
	ok(int(Save.d["seeds"].get(crop, 0)) == seeds_before + 1, "it brought a seed from their patch")
	ok(String(back["species"]) == "scaldamus", "a trade species evolved on coming home")
	Sleepover.send(plain, "friend1", "Pia", t0)
	Sleepover.come_home(Sleepover.list()[0], {})
	var stayed := String(Save.kin(plain["uid"])["species"])
	ok(stayed == "burrlet", "a non-trade species stays itself; an empty snapshot still brings it home")
	print("SLEEPOVER DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
