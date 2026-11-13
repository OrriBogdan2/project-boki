extends RefCounted
## --relics-tab-check: the market's Relics tab (MarketRelics): a card per Hunter in the canonical order
## (Lace, Kael, Vex, Albert, then the rest), owned or locked, and for a locked one a plain line on how
## to open it, taken live from ClassUnlock (it changes with progress). No prices. With
## --shots-dir=<dir> also writes relics_new.png and relics_progress.png from the real
## market panel (needs a renderer). Prints RELICS ok/FAIL lines and "RELICS DONE, failures: n".

var bad := 0
var main: Node
var home = null
var dir := ""

func ok(cond: bool, what: String) -> void:
	print("RELICS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
	_save()
	var tab := _tab()
	_order_and_owned(tab)
	_how_lines(tab)
	_no_prices(tab)
	_live()
	ok(HomeMarket.TABS.any(func(t): return t[0] == "Relics" and int(t[1]) == 1), "a Relics tab from market level 1")
	ok(HomeMarket.OPEN_NAMES.get("relics", "") == "Relics", "--open=relics opens it")
	if dir != "":
		await _shots()
	print("RELICS DONE, failures: %d" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)

## A played save: Vex picked, nothing else open yet.
func _save() -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	ClassUnlock.choose_starters(["gunslinger"])

func _tab() -> VBoxContainer:
	var v := VBoxContainer.new()
	MarketRelics.build(v)
	main.add_child(v)
	return v

func _labels(n: Node, out: Array) -> Array:
	if n is Label: out.append((n as Label).text)
	for c in n.get_children(): _labels(c, out)
	return out

func _order_and_owned(tab: Node) -> void:
	var texts := _labels(tab, [])
	var last := -1
	var in_order := true
	for id in Arch.ids():
		var at := texts.find(HunterViewer.display_name(String(id)))
		in_order = in_order and at > last
		last = at
	ok(in_order, "one card per Hunter, in Arch.ORDER (%d Hunters)" % Arch.ids().size())
	ok(Arch.ids().slice(0, 4) == ["archer", "juggernaut", "gunslinger", "bulwark"], "it starts Lace, Kael, Vex, Albert")
	var yours := texts.count("Yours")
	ok(yours == ClassUnlock.open_ids().size(), "Yours on exactly the open Relics (%d)" % yours)
	ok(MarketRelics.summary().begins_with("1 of 13 Relics yours."), "the count line (%s)" % MarketRelics.summary())

func _how_lines(tab: Node) -> void:
	var texts := _labels(tab, [])
	var all_have := true
	for id in Arch.ids():
		if not ClassUnlock.is_open(String(id)):
			var line := ClassUnlock.requirement(String(id))
			all_have = all_have and line != "" and texts.has(line)
	ok(all_have, "every locked Relic shows its own how-to-open line")
	var kael := ClassUnlock.requirement("juggernaut")
	ok(kael != "" and texts.has(kael), "Kael's line is live data")

func _no_prices(tab: Node) -> void:
	var buttons := tab.find_children("*", "Button", true, false)
	var gems := _labels(tab, []).filter(func(t): return String(t).contains("gem"))
	ok(buttons.is_empty() and gems.is_empty(), "no prices or buy buttons yet")

## Progress changes the line; a fresh save's unpicked starters read as the first pick.
func _live() -> void:
	var before := ClassUnlock.requirement("thief")
	var c := ClassUnlock.state()
	c["hunters"] = {}
	c["stats"] = {}
	var stat := String(ClassUnlock.challenge("thief").get("stat", ""))
	var s: Dictionary = (c["stats"] as Dictionary)
	s[stat] = int(s.get(stat, 0)) + 1
	var after := ClassUnlock.requirement("thief")
	ok(after != before, "a line follows the challenge counter (%s)" % after)
	Save.d = Save.fresh()
	var lace := ClassUnlock.requirement("archer")
	ok(lace == "Pick it as your first Relic", "before the first pick Lace reads as a pick")

func _shot(shot_name: String) -> void:
	for i in 4: await main.get_tree().process_frame
	if main.fade: main.fade.reveal(0.05)
	await main.get_tree().create_timer(0.4).timeout
	var img := main.get_viewport().get_texture().get_image()
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()))
	img.save_png("%s/%s.png" % [dir, shot_name])
	print("RELICS shot %s" % shot_name)

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.hb != null and home.player != null: break
		await main.get_tree().process_frame
	home._close_panel()
	_save()
	home.hmk.open("Relics")
	await _shot("relics_new")
	var c := ClassUnlock.state()
	c["open"] = ["gunslinger", "archer", "juggernaut"]
	var stat := String(ClassUnlock.challenge("thief").get("stat", ""))
	(c["stats"] as Dictionary)[stat] = 1
	home.hmk.open("Relics")
	await _shot("relics_progress")
	home._close_panel()
