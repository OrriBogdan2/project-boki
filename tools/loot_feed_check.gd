extends RefCounted
## --loot-feed-check: the bottom-right pickup rows (LootFeed).
##   1. the same thing again within MERGE_S adds to its row; after it, or a different thing, is a new row
##   2. at most MAX_ROWS rows: a new one pushes the oldest out
##   3. a row fades from LIFE - FADE and is gone at LIFE; a merge starts its time again
##   4. in a fight only rare things tick
##   5. real pickups (gems, a belt item, gear into the pack) land in the player's feed, not the message lane
##   6. the HUD's group count (HudGroups.on_screen, as --hud-groups-check counts it) does not grow while
##      nothing is picked up; a pickup adds the one "loot" group, gone once its rows fade
## Never touches the save.

const GROUPS := preload("res://tools/hud_groups_check.gd")

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("LOOTFEED %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(main: Node) -> void:
	_rows()
	var m: Match = await GROUPS.make_match(main)
	_pickups(m)
	await _groups(m, main)
	m.queue_free()
	print("LOOTFEED DONE, failures: %d" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

func _rows() -> void:
	var f := LootFeed.new()
	f.add("gem", "Gems", 3, Color.GOLD)
	f.tick(LootFeed.MERGE_S - 0.5)
	f.add("gem", "Gems", 4, Color.GOLD)
	ok(f.rows.size() == 1 and int(f.rows[0]["n"]) == 7, "1. Gems twice within %.0f s: one row of 7" % LootFeed.MERGE_S)
	f.tick(LootFeed.MERGE_S + 0.1)
	f.add("gem", "Gems", 1, Color.GOLD)
	ok(f.rows.size() == 2, "1. Gems again after %.0f s: a new row" % LootFeed.MERGE_S)
	f.add("tonic", "Tonic", 1, Color.RED)
	ok(f.rows.size() == 3, "1. a different thing: its own row")
	for nm in ["A", "B", "C"]:
		f.add("gem", nm, 1, Color.WHITE)
	ok(f.rows.size() == LootFeed.MAX_ROWS, "2. six rows in: %d on show" % LootFeed.MAX_ROWS)
	var names: Array = f.rows.map(func(r): return r["name"])
	ok(names == ["Tonic", "A", "B", "C"], "2. the two oldest went, the newest is last: %s" % ", ".join(names))
	f.rows.clear()
	f.add("gem", "Gems", 1, Color.GOLD)
	f.tick(1.0)
	f.add("gem", "Gems", 1, Color.GOLD)
	ok(f.rows.size() == 1 and float(f.rows[0]["t"]) == 0.0, "3. a merge starts the row's time again")
	f.tick(LootFeed.LIFE - LootFeed.FADE - 0.1)
	ok(LootFeed.alpha(float(f.rows[0]["t"])) == 1.0, "3. whole until %.1f s" % (LootFeed.LIFE - LootFeed.FADE))
	f.tick(LootFeed.FADE * 0.5)
	var a := LootFeed.alpha(float(f.rows[0]["t"]))
	ok(a > 0.0 and a < 1.0, "3. fading after that (alpha %.2f)" % a)
	f.tick(LootFeed.LIFE + 0.01)
	ok(f.rows.is_empty(), "3. gone at %.0f s" % LootFeed.LIFE)
	f.free()
	ok(LootFeed.audible(false, 0), "4. out of a fight a common pickup ticks")
	ok(not LootFeed.audible(true, LootFeed.RARE - 1), "4. in a fight a common pickup is silent")
	ok(LootFeed.audible(true, LootFeed.RARE), "4. in a fight a rare one still ticks")

func _pickups(m: Match) -> void:
	var p: Hunter = m.player
	var feed: LootFeed = m.hud.loot
	feed.rows.clear()
	m.hud.msgs.clear()
	LootFeed.ground(m, p, {"kind": "gem"}, 5)
	UtilityBelt.pickup(p, "tonic", 1)
	var it := Loot.gear(String(Gear.ALL.keys()[0]), 2)
	Pack.spawn_item(m, it, p.pos)
	Pack.stash(m, p, m.wpicks[m.wpicks.size() - 1])
	var names: Array = feed.rows.map(func(r): return r["name"])
	var want := ["Gems", UtilityBelt.name_of("tonic"), Loot.name_of(it)]
	ok(names == want, "5. gems, a tonic, gear: %s" % ", ".join(names))
	ok(m.hud.msgs.count() == 0, "5. nothing went to the message lane")
	var bot: Hunter = m.hunters.filter(func(h): return h != p)[0]
	UtilityBelt.pickup(bot, "tonic", 1)
	ok(feed.rows.size() == 3, "5. a bot's pickup is not in your feed")
	feed.rows.clear()

func _groups(m: Match, main: Node) -> void:
	var feed: LootFeed = m.hud.loot
	GROUPS.set_moment(m, "landing")
	var before: int = HudGroups.on_screen(m.hud).size()
	for i in 10:
		await main.get_tree().process_frame
	ok(HudGroups.on_screen(m.hud).size() == before, "6. nothing picked up: %d groups, no more" % before)
	feed.add("gem", "Gems", 1, Color.GOLD)
	var g: Array = HudGroups.on_screen(m.hud)
	ok(g.size() == before + 1 and g.has("loot"), "6. a pickup: the one loot group")
	feed.tick(LootFeed.LIFE + 0.01)
	ok(HudGroups.on_screen(m.hud).size() == before, "6. its rows faded: back to %d" % before)
