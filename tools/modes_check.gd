extends RefCounted
## --modes-check: the expedition modes (docs/decisions/0084-modes-solos-play-space.md). Never touches the save.
##   1. Data.mode_opts: trios are 10 squads of three (30 hunters), solos 20 hunters on their own.
##   2. every expedition map has a play space per mode: solos smaller than trios, both inside the closing
##      ring's first radius (Heart.start_r_of).
##   3. a trios match starts with 30 hunters in 10 squads of three, on the trios play space.
##   4. a solos match starts with 20 hunters each on their own, the tide already in on the solos play space with
##      land left outside it, every hunter on land inside it, and no squad cues (Life.has_mates, no beacons).
##   5. the expedition panel offers Trios and Solos cards and no rolling session.
##   6. the solo results line reads "You placed", and the solo kill-XP hint names no squad.

const MAPS := ["hollowcrown", "skyreach"]

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("MODES %s %s" % ["PASS" if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	_mode_opts()
	_play_space()
	_results()
	await _trios()
	await _solos()
	await _panel()
	print("MODES DONE, failures: ", bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _mode_opts() -> void:
	ok(Data.MODES == ["trios", "solos"], "the modes a player can queue for: trios and solos")
	ok(Data.mode_opts("trios") == {"teams": 10, "squad": 3, "total": 30}, "trios: 10 squads of three")
	ok(Data.mode_opts("solos") == {"teams": 20, "squad": 1, "total": 20}, "solos: 20 hunters on their own")


func _play_space() -> void:
	for id in MAPS:
		var layout := World.load_layout(id)
		var first := Heart.r("tide_r0") * float(layout.get("ways_scale", 1.0))
		var trios := Heart.start_r_of(layout, Data.mode_opts("trios"))
		var solos := Heart.start_r_of(layout, Data.mode_opts("solos"))
		ok(solos < trios and trios < first, "%s: solos %.0f m, trios %.0f m, first ring %.0f m" % [id, solos, trios, first])


func _results() -> void:
	var lone := {"place": 3, "squads": 20, "solo": true}
	var squad := {"place": 3, "squads": 10, "solo": false}
	ok(WaysResult.how_line(lone).begins_with("You placed 3rd of 20"), "a solo result: You placed 3rd of 20")
	ok(WaysResult.how_line(squad).begins_with("Your squad placed 3rd of 10"), "a squad result: Your squad placed")
	var words := XpHints.SOLO_KILL_TEXT.to_lower()
	ok(not words.contains("squad") and not words.contains("teammate"), "the solo kill-XP hint names no squad")


## A match in a mode, built and paused at the start (every hunter a bot, the player on land).
func _start(mode: String, seed_v: int) -> Match:
	var m := Match.new()
	main.add_child(m)
	var o := {"tier": 0, "seed": seed_v, "autoplay": true}
	o.merge(Data.mode_opts(mode))
	await m.start(o)
	m.set_process(false)
	return m


func _done(m: Match) -> void:
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame


func _trios() -> void:
	var m := await _start("trios", 4101)
	var squads := {}
	for h in m.hunters:
		squads[h.team] = int(squads.get(h.team, 0)) + 1
	ok(m.hunters.size() == 30 and squads.size() == 10 and squads.values().all(func(n): return n == 3),
		"trios: %d hunters in %d squads of three" % [m.hunters.size(), squads.size()])
	var want := float(m.layout["play_space"]["trios"])
	ok(is_equal_approx(m.heart.start_r, want), "trios: the tide starts on the trios play space (%.0f m)" % m.heart.start_r)
	ok(Life.has_mates(m, m.player), "trios: the player has squadmates")
	await _done(m)


func _solos() -> void:
	var m := await _start("solos", 4102)
	var heart: Heart = m.heart
	var teams := {}
	for h in m.hunters:
		teams[h.team] = true
	ok(m.hunters.size() == 20 and teams.size() == 20, "solos: %d hunters, %d squads" % [m.hunters.size(), teams.size()])
	var want := float(m.layout["play_space"]["solos"])
	ok(is_equal_approx(Heart.tide_r(m), want) and is_equal_approx(Heart.next_r(m), want),
		"solos: the tide is in at the start, on the solos play space (%.0f m)" % Heart.tide_r(m))
	var outside := 0
	for z in range(0, m.world.h, 4):
		for x in range(0, m.world.w, 4):
			if not m.world.is_void(x, z) and Vector2(x - heart.site.x, z - heart.site.z).length() > heart.start_r:
				outside += 1
	ok(outside > 0, "solos: part of the map starts inside the Blight (%d land samples out)" % outside)
	var lands: Array = m.hunters.map(func(h): return h.ai.get("land", h.pos))      # (bots on the ship plan their landing)
	var in_play := lands.filter(func(p): return Vector2(p.x - heart.site.x, p.z - heart.site.z).length() <= heart.start_r)
	ok(in_play.size() == 20, "solos: %d of 20 hunters start or land inside the play space" % in_play.size())
	ok(not Life.has_mates(m, m.player) and m.beacons.is_empty(), "solos: no squadmates and no revive beacons")
	await _done(m)


func _panel() -> void:
	var d := Save.fresh()      # a farm past the first-run steps, so the portal opens the expedition panel
	var kin := Save.new_kin("zapple", "Pip")
	d["roster"].append(kin)
	d["active"] = kin["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	d["arch"] = "gunslinger"
	d["cls"] = Arch.weight("gunslinger")
	Save.d = d
	ClassUnlock.choose_starters(["gunslinger"])
	var home = await main._hb_home()
	for i in 30:
		await main.get_tree().process_frame
	home._open_expedition()
	await main.get_tree().process_frame
	var texts := _texts(home.panel_host)
	ok(texts.has("Trios") and texts.has("Solos"), "the expedition panel: a Trios card and a Solos card")
	ok(not texts.any(func(t): return String(t).to_lower().contains("rolling")), "no rolling session on the panel")
	ModeCards.pick("solos", home._open_expedition)
	await main.get_tree().process_frame
	ok(Data.saved_mode() == "solos" and Data.mode_opts(Data.saved_mode())["squad"] == 1, "picking Solos queues solos")
	home.queue_free()


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out
