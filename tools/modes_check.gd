extends RefCounted
## --modes-check: the expedition modes (docs/decisions/0084-modes-solos-play-space.md). Never touches the save.
##   1. Data.mode_opts: trios are 10 squads of three (30 hunters), solos 20 hunters on their own.
##   2. every expedition map has a play space per mode: solos smaller than trios, both inside the closing
##      ring's first radius (Heart.start_r_of).
##   3. a trios match starts with 30 hunters in 10 squads of three on the trios play space.
##   4. a solos match (real skyship drop, every hunter a bot) starts with 20 hunters each on their own, the
##      tide already in on the solos play space with land left outside it, every bot planning to land
##      inside it; it runs on to the end (sim_keep: after the player is out too) and every hunter is out by then.
##   5. the expedition panel offers Trios and Solos and no rolling session.

const MAPS := ["hollowcrown", "skyreach"]
const SOLO_LEN := 150.0  # s: the solos run is cut short (the islands fall then), so the check stays quick

var bad := 0
var main: Node


func ok(cond: bool, what: String) -> void:
	print("MODES %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	_mode_opts()
	_play_space()
	await _trios()
	await _solos()
	await _panel()
	print("MODES ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)


func _mode_opts() -> void:
	ok(Data.MODES == ["trios", "solos"], "the modes a player can queue for: trios and solos")
	ok(Data.mode_opts("trios") == {"teams": 10, "squad": 3, "total": 30}, "trios: 10 squads of three")
	ok(Data.mode_opts("solos") == {"teams": 20, "squad": 1, "total": 20}, "solos: 20 hunters on their own")


func _play_space() -> void:
	for id in MAPS:
		var L := World.load_layout(id)
		var first := Heart.r("tide_r0") * float(L.get("ways_scale", 1.0))
		var trios := Heart.start_r_of(L, Data.mode_opts("trios"))
		var solos := Heart.start_r_of(L, Data.mode_opts("solos"))
		ok(
			solos < trios and trios < first,
			"%s: solos start on %.0f m, trios on %.0f m, the first closing ring is %.0f m" % [id, solos, trios, first]
		)


## A match in a mode, built and paused at the start.
func _start(mode: String, o: Dictionary) -> Match:
	var m := Match.new()
	main.add_child(m)
	o.merge(Data.mode_opts(mode))
	await m.start(o)
	m.set_process(false)
	return m


func _done(m: Match) -> void:
	m.queue_free()
	for i in 3:
		await main.get_tree().process_frame


func _trios() -> void:
	var m := await _start("trios", {"tier": 0, "seed": 4101, "autoplay": true})
	var squads := {}
	for h in m.hunters:
		squads[h.team] = int(squads.get(h.team, 0)) + 1
	ok(
		m.hunters.size() == 30 and squads.size() == 10 and squads.values().all(func(n): return n == 3),
		"trios: %d hunters in %d squads of three" % [m.hunters.size(), squads.size()]
	)
	ok(
		is_equal_approx(m.heart.start_r, float(World.load_layout(m.world.layout_id)["play_space"]["trios"])),
		"trios: the tide starts on the map's trios play space (%.0f m)" % m.heart.start_r
	)
	await _done(m)


func _solos() -> void:
	var m := await _start("solos", {"tier": 0, "seed": 4102, "autoplay": true, "length": SOLO_LEN, "sim_keep": true})
	var H: Heart = m.heart
	var teams := {}
	for h in m.hunters:
		teams[h.team] = true
	ok(m.hunters.size() == 20 and teams.size() == 20, "solos: %d hunters, %d squads" % [m.hunters.size(), teams.size()])
	var want := float(World.load_layout(m.world.layout_id)["play_space"]["solos"])
	ok(
		is_equal_approx(H.start_r, want) and is_equal_approx(Heart.tide_r(m), want),
		"solos: the tide is already in at the start, on the solos play space (%.0f m)" % Heart.tide_r(m)
	)
	var outside := 0
	for z in range(0, m.world.h, 2):
		for x in range(0, m.world.w, 2):
			if not m.world.is_void(x, z) and Vector2(x - H.site.x, z - H.site.z).length() > H.start_r:
				outside += 1
	ok(outside > 0, "solos: part of the map starts inside the Blight (%d land samples out)" % outside)
	var lands: Array = m.hunters.filter(func(h): return h.riding).map(func(h): return h.ai.get("land", Vector3.INF))
	var inside := lands.filter(func(p): return Vector2(p.x - H.site.x, p.z - H.site.z).length() <= H.start_r)
	ok(
		lands.size() == 20 and inside.size() == lands.size(),
		"solos: all %d aboard the skyship, %d plan to land inside the play space" % [lands.size(), inside.size()]
	)
	var n := 0
	while m.time < SOLO_LEN + 3.0:
		m.step(Match.DT)
		n += 1
		if n % 120 == 0:
			await main.get_tree().process_frame  # (freed nodes go between frames)
	var landed := m.hunters.filter(func(h): return not h.riding).size()
	var left := m.hunters.filter(func(h): return not h.out and not h.extracted).size()
	ok(
		m.result.get("ending", false) and landed == 20 and left == 0,
		(
			"solos: everyone came down, the islands fell at %.0f s with %d left, the player's end: %s"
			% [SOLO_LEN, left, String(m.result.get("why", "-"))]
		)
	)
	await _done(m)


func _panel() -> void:
	var hm = await main._hb_home()
	hm._open_expedition()
	await main.get_tree().process_frame
	var texts := _texts(hm.panel_host)
	ok(texts.has("Trios") and texts.has("Solos"), "the expedition panel: a Trios tab and a Solos tab")
	ok(not texts.any(func(t): return String(t).to_lower().contains("rolling")), "no rolling session on the panel")
	var solos_tab: Button = _button(hm.panel_host, "Solos")
	solos_tab.pressed.emit()
	await main.get_tree().process_frame
	ok(hm._exp_mode() == "solos", "picking Solos queues a solos expedition")
	hm.queue_free()


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	if n is Control and String((n as Control).tooltip_text) != "":
		out.append((n as Control).tooltip_text)
	for c in n.get_children():
		out.append_array(_texts(c))
	return out


func _button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _button(c, text)
		if b:
			return b
	return null
