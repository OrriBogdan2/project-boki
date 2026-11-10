extends RefCounted
## --xp-hint-check: the two XP first-time lines (XpHints), each once per save.
##   1. the kill line: your squad's last hit on a monster shows it once; a second kill, and the same kill
##      after a save round trip, show nothing
##   2. the steal line: a rival's last hit on a monster your squad was hitting shows it once, never when
##      your squad had not touched it, and again never after the round trip
##   3. not before the match's first second, not with tips off
##   4. an old (v11) save loads with both flags unseen and its other flags kept
## Never touches the real save.

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("XPHINT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _run(sec: float) -> void:
	var t := 0.0
	while t < sec:
		m.step(Match.DT)
		t += Match.DT

## The match's tip clock (Match._process runs it; the check steps by hand, so it sets it).
func _clock(sec: float) -> void:
	m._tip_t = sec
	m._tips()

func _fresh_match() -> void:
	if m != null:
		m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true})
	m.set_process(false)

## Spawns a monster beside the player and lets `hitters` hit it in order; the last one kills it.
## Returns how many hint lines are showing afterwards.
func _kill(hitters: Array) -> int:
	m.hud.msgs.clear()
	var mb := m.spawn_mob("skitter", m.player.pos + Vector3(2, 0, 0))
	for i in hitters.size():
		var dmg := mb.hp + 1.0 if i == hitters.size() - 1 else 1.0
		mb.hurt(dmg, hitters[i])
	return m.hud.msgs.count()

func _seen(key: String) -> bool:
	return bool(Save.d["tutorial"].get(key, false))

func _rival() -> Hunter:
	for h in m.hunters:
		if h.team != m.player.team:
			return h
	return null

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	Save.d = Save.fresh()
	Settings.set_v("tips", true, false)
	_fresh_match()
	var rival := _rival()
	_run(0.5)
	_clock(0.5)
	ok(_kill([m.player]) == 0 and not _seen(XpHints.KILL_KEY), "no line in the match's first second")
	_run(1.5)
	_clock(2.0)
	ok(m.tips_live, "after that the tips are live")
	# the steal first: it needs your squad to have hit the monster, and a rival to finish it
	ok(_kill([rival]) == 0 and not _seen(XpHints.STEAL_KEY), "a rival kill your squad never touched: no steal line")
	ok(_kill([m.player, rival]) == 1 and _seen(XpHints.STEAL_KEY), "a rival's last hit after yours: the steal line")
	ok(not _seen(XpHints.KILL_KEY), "the steal did not use up the kill line")
	ok(_kill([m.player, rival]) == 0, "a second steal: nothing")
	ok(_kill([m.player]) == 1 and _seen(XpHints.KILL_KEY), "your last hit: the kill line")
	ok(_kill([m.player]) == 0, "a second kill: nothing")
	_round_trip()
	_fresh_match()
	_run(2.0)
	_clock(2.0)
	rival = _rival()
	ok(_kill([m.player]) == 0 and _kill([m.player, rival]) == 0, "after a save round trip neither line comes back")
	_old_save()
	print("XPHINT DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)

## Writes the save out and reads it back, as quitting and starting again would.
func _round_trip() -> void:
	var p := "user://xp_hint_check.json"
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(Save.d))
	f.close()
	Save.d = Save.fresh()
	Save.load_from(p)
	DirAccess.remove_absolute(p)
	ok(_seen(XpHints.KILL_KEY) and _seen(XpHints.STEAL_KEY), "the flags survive the round trip")

func _old_save() -> void:
	var p := "user://xp_hint_check_old.json"
	var old := Save.fresh()
	old["v"] = 11
	old["tutorial"] = {"move": true}
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Save.load_from(p)
	DirAccess.remove_absolute(p)
	var t: Dictionary = Save.d["tutorial"]
	ok(int(Save.d["v"]) == Save.VERSION and t.get("move", false), "an old save loads, upgraded, with its other flags")
	ok(Save.d["tutorial"].has(XpHints.KILL_KEY) and not _seen(XpHints.KILL_KEY) and not _seen(XpHints.STEAL_KEY),
		"both XP lines unseen in an old save")
