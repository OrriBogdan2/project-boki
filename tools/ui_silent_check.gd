extends RefCounted
## --ui-silent-check: opens every menu and panel reachable from the title, the Esc menu, the hunter pick, the
## results screen, the farm and garden panels and the Black Market, points at and presses each Button (a tab is a
## Button too), and fails on any that plays no sound through Sfx. A button that is meant to be silent says so with
## Ui.sounding(b, ""); a hover only counts for buttons that are not disabled. Never touches the real save.
## --ui-silent-list prints every silent control; the count it ends on is the number this check holds at zero.

const SETTLE := 2  # frames for a screen or panel to build
const MAX_BUTTONS := 400  # per scenario: a runaway list is a bug in the walker
const NO_PRESS := ["Quit", "Save and quit", "Quit game", "Exit", "Leave game"]  # their action ends the process

var main: Node
var home: Node
var silent: Array = []
var seen := 0
var skipped := 0
var scenarios := 0


func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	Save.d["roster"].append(k)
	Save.d["active"] = k["uid"]
	Save.d["tutorial"] = {"hatched": true, "intro": true}
	Save.d["matches"] = 3
	Save.d["gems"] = 1000
	for sc in _scenarios():
		await _walk(sc[0], sc[1], sc[2])
	for s in silent:
		print("UISILENT ", s)
	print("UISILENT DONE, %d scenarios, %d buttons, %d skipped, silent: %d" % [scenarios, seen, skipped, silent.size()])
	main.get_tree().quit(1 if not silent.is_empty() else 0)


## [name, open: Callable (may await), root: Callable returning the Node to search]
func _scenarios() -> Array:
	var out: Array = []
	out.append(["title", func(): await _screen("title", {}), func(): return main.current])
	var over := func(): return Overlay.host
	for where in ["home", "title"]:
		out.append(["pause %s" % where, func(): await _overlay(func(): Overlay.open_pause(where)), over])
	for page in ["open_more", "open_controls", "open_words", "open_saves", "open_inventory", "open_sfx_tester"]:
		out.append([page, func(): await _overlay(Callable(Overlay, page)), over])
	for t in Overlay.SETTINGS_TABS:
		out.append(
			[
				"settings > %s" % t,
				func():
					await _overlay(
						func():
							Overlay.tab = t
							Overlay.open_settings()
					),
				over,
			]
		)
	out.append(["results", func(): await _screen("results", _result()), func(): return main.current])
	out.append(["prematch", func(): await _screen("prematch", {}), func(): return main.current])
	out.append(["hatch", func(): await _screen("hatch", {}), func(): return main.current])
	for opener in [
		"_open_kitchen",
		"_open_challenges",
		"open_job_board",
		"open_build",
		"_open_hall",
		"_open_music",
		"_open_house",
		"_open_settings",
		"open_kin_box",
		"_open_burrow",
		"_open_nook",
		"_open_loadout",
		"_open_expedition",
		"_open_kit_card",
		"_open_rack",
		"_open_ferry",
	]:
		out.append(["home %s" % opener, func(): await _home_panel(opener), func(): return home.panel_host])
	for tab in HomeBlackMarket.TABS.keys():
		out.append(["black market %s" % tab, func(): await _home_panel("", tab), func(): return home.panel_host])
	return out


func _result() -> Dictionary:
	return {"extracted": true, "gems": 40, "seeds": {"sunroot": 2}, "kills": 3, "placement": 2, "xp": 120}


func _frames(n := SETTLE) -> void:
	for i in n:
		await main.get_tree().process_frame


func _screen(screen: String, opts: Dictionary) -> void:
	Overlay.close()
	main.show_screen(screen, opts)
	await _frames(8)


func _overlay(open: Callable) -> void:
	Overlay.close()
	await _frames()
	open.call()
	await _frames()


func _home_panel(opener: String, market_tab := "") -> void:
	if not is_instance_valid(home) or main.current != home:
		Overlay.close()
		main.show_screen("home", {})
		await _frames(12)
		home = main.current
	home._close_panel()
	if market_tab != "":
		home.hbm.open(market_tab)
	else:
		Callable(home, opener).call()
	await _frames()


## A fresh copy of the scenario for every control: pressing one may leave the screen or change it.
func _walk(name: String, open: Callable, root: Callable) -> void:
	scenarios += 1
	await open.call()
	var count := _buttons(root.call()).size()
	for i in mini(count, MAX_BUTTONS):
		if i > 0:
			await open.call()
		var list := _buttons(root.call())
		if i >= list.size():
			break
		await _press(name, list[i])
	Overlay.close()


func _buttons(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.is_queued_for_deletion():
			out.append(b)
	return out


func _label(b: Button) -> String:
	var tip := b.tooltip_text.split("\n")[0]
	return b.text.strip_edges() if b.text.strip_edges() != "" else ("[%s] %s" % [b.name, tip])


func _press(name: String, b: Button) -> void:
	seen += 1
	var what := "%s | %s" % [name, _label(b)]
	if b.disabled:
		skipped += 1
		return
	if b.has_meta("snd") and String(b.get_meta("snd")) == "" and b.has_meta(UI.SFX_META):
		skipped += 1  # declared silent: its action plays its own cue (Ui.sounding(b, ""))
		return
	var plain := b.get_class() == "Button"  # a toggle or dropdown sounds from UiSfx, not from hovering it
	if plain and not _heard(func(): b.mouse_entered.emit()):
		silent.append("%s | hover" % what)
	if b.text.strip_edges() in NO_PRESS:
		skipped += 1
		return
	if not _heard(func(): _act(b)):
		silent.append("%s | press" % what)
	await _frames(1)


func _heard(trigger: Callable) -> bool:
	Sfx.cue_log = []
	Sfx.cue_log.clear()
	trigger.call()
	var heard := false
	for c in Sfx.cue_log:
		heard = heard or bool(c[2])
	Sfx.cue_log = null
	return heard


## What pressing it does: a toggle flips, a dropdown picks, anything else is pressed.
func _act(b: Button) -> void:
	if b is OptionButton:
		if b.item_count > 0:
			b.item_selected.emit(0)
	elif b is CheckButton or b is CheckBox:
		var was := b.button_pressed
		b.button_pressed = not was
		b.set_pressed_no_signal(was)
	else:
		b.pressed.emit()
