extends RefCounted
## --hud-groups-check: the new-player HUD holds two groups back until they matter (HudGroups,
## docs/HUD.md "First real match"). A fresh save in a real match shows neither the top-right counters nor the
## "Your kit" card; the first kill, knock or gem, or holding Tab, brings the counters back; a save that has played
## NEW_PLAYER_MATCHES expeditions sees both as before, and the training room keeps its kit card.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("HUDGROUPS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond: bad += 1

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": Data.MATCH_PLAYERS, "squad": 1, "total": Data.MATCH_PLAYERS, "tier": 0, "seed": 7})
	m.set_process(false)
	var p: Hunter = m.player
	ok(HudGroups.new_player(), "a fresh save is a new player")
	ok(not HudGroups.counters_shown(p, false), "counters: hidden before the first kill, knock or gem")
	ok(HudGroups.counters_shown(p, true), "counters: shown while Tab is held")
	for stat in ["kills", "knocks", "gems"]:
		p.set(stat, 1)
		ok(HudGroups.counters_shown(p, false), "counters: shown once %s is 1" % stat)
		p.set(stat, 0)
	ok(not HudGroups.kit_card_shown(m), "kit card: not shown to a new player")
	m.opts["training"] = true
	ok(HudGroups.kit_card_shown(m), "kit card: the training room keeps it")
	m.opts["training"] = false
	Save.d["matches"] = HudGroups.NEW_PLAYER_MATCHES
	ok(not HudGroups.new_player(), "a save with %d expeditions is not new" % HudGroups.NEW_PLAYER_MATCHES)
	ok(HudGroups.counters_shown(p, false) and HudGroups.kit_card_shown(m), "veterans: counters and kit card as before")
	print("HUDGROUPS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)
