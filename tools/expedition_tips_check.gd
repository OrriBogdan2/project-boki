extends RefCounted
## --expedition-tips-check: the one-time expedition tips (ExpeditionTips through Match._tip). In a real
## match: no tip at the start; the Blight tip only once the ring closes within BLIGHT_M of you; the camp
## tip after your first monster kill; the deathbox tip with the live interact key at a lootable box; each
## once per save (a seen tip never comes back, the next one is not held behind it). The tutorial match and
## the Training Grounds show none.
var bad := 0


func ok(cond: bool, what: String) -> void:
	print("EXTIPS %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	Save.no_write = true
	for k in ["blight", "camp", "deathbox"]:
		Save.d["tutorial"].erase(k)
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 4242, "demo_kin": "cindle"})
	m.set_process(false)
	var p: Hunter = m.player
	m.time = 0.0
	m.interact = {}
	p.stats.erase("mobs")
	ok(m.heart != null and ExpeditionTips.next(m).is_empty(), "a fresh match: no tip before anything happens")
	m.time = 200.0
	var tr := Heart.tide_r(m)
	p.pos = m.heart.site + Vector3(maxf(tr - ExpeditionTips.BLIGHT_M - 8.0, 0.0), 0, 0)
	ok(tr > 0.0 and ExpeditionTips.next(m).is_empty(), "the ring is closing but its edge is far: no Blight tip")
	p.pos = m.heart.site + Vector3(tr - ExpeditionTips.BLIGHT_M + 5.0, 0, 0)
	ok(_due(m) == "blight", "the ring's edge within %d m: the Blight tip" % int(ExpeditionTips.BLIGHT_M))
	m._tip("blight", ExpeditionTips.next(m)[1])
	ok(Save.d["tutorial"].get("blight", false) and ExpeditionTips.next(m).is_empty(), "shown once, then never")
	p.add_stat("mobs")
	ok(_due(m) == "camp", "the first monster kill: the camp tip (behind a seen Blight tip, not blocked)")
	Save.d["tutorial"]["camp"] = true
	m.interact = {"kind": "loot"}
	var line := String(ExpeditionTips.next(m)[1]) if _due(m) == "deathbox" else ""
	ok(line.contains(Settings.key_cap("interact")), "a lootable deathbox: the tip with the interact key")
	Save.d["tutorial"]["deathbox"] = true
	ok(ExpeditionTips.next(m).is_empty(), "all three seen: nothing more on this save")
	m.queue_free()
	ok(_via_tips(main, "") == true, "a real match: Match._tips shows the camp tip")
	for k in ["tutorial", "arena"]:
		ok(_via_tips(main, k) == false, "%s match: Match._tips shows none of them" % k)
	print("EXTIPS DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _due(m: Match) -> String:
	var t := ExpeditionTips.next(m)
	return String(t[0]) if t else ""


## Whether Match._tips marks the camp tip after a kill at a lootable box (practice key: tutorial or arena).
func _via_tips(main: Node, key: String) -> bool:
	for k in ["blight", "camp", "deathbox"]:
		Save.d["tutorial"].erase(k)
	var o := {"teams": 2, "squad": 1, "tier": 0, "seed": 4242}
	if key != "":
		o[key] = true
	var m := Match.new()
	main.add_child(m)
	m.start(o)
	m.set_process(false)
	var shown := false
	if m.player:
		m.player.dropping = false
		m.player.riding = false  # off the sky train, so only the match kind holds the tips back
		m.player.add_stat("mobs")
		m._tip_t = 20.0
		m._tips()
		shown = Save.d["tutorial"].get("camp", false)
	m.queue_free()
	return shown
