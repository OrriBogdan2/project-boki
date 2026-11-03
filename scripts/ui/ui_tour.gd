class_name UiTour
extends RefCounted
## Screenshots of the menu kit in one run (tooling): at home with --armory-test, --ui-tour=<prefix>
## saves <prefix>_<step>.png for the armory, the kit card, a toast, the menu, every settings tab, a
## tooltip, a confirm box, the hub, the hero picker, the market, the loading screen, the results and
## the title screen, then quits. One run instead of a dozen, on a slow shared machine.

const SETTLE_S := 1.2      # seconds each step gets to fade in before its picture
const SCREEN_S := 3.5      # ... and a whole screen (results, title) to build and fade in

## Walks the steps on the home screen `home`, saving each to `prefix`_<name>.png.
static func run(home: Node, prefix: String) -> void:
	var tree := home.get_tree()
	var vp := home.get_viewport()
	var steps: Array = [["armory", func(): home.hecon.open_armory()]]
	steps.append(["kit_card", func(): home.call("_open_kit_card")])
	steps.append(["toast", func():
		home.call("_close_panel")
		home.call("_toast", "Bramble Isle is open")])
	steps.append(["pause", func(): Overlay.shot_demo(PackedStringArray(["pause"]))])
	for tab_name in Overlay.SETTINGS_TABS:
		var open_tab := func(): Overlay.shot_demo(PackedStringArray(["settings", tab_name]))
		steps.append(["settings_" + tab_name.to_lower(), open_tab])
	steps.append(["tooltip", func(): Overlay.shot_demo(PackedStringArray(["tooltip"]))])
	steps.append(["confirm", func(): Overlay.shot_demo(PackedStringArray(["confirm"]))])
	steps.append(["hub", func(): Overlay.close()])
	steps.append(["hero", func(): HomeHero.open(home)])
	steps.append(["shop", func(): home.call("_open_shop")])
	await tree.create_timer(3.0).timeout
	for step in steps:
		(step[1] as Callable).call()
		await tree.create_timer(SETTLE_S).timeout
		_save(vp, prefix, step[0])
	await _loading(tree, vp, prefix)
	Game.goto("results", _result())
	await tree.create_timer(SCREEN_S + 2.0).timeout
	_save(vp, prefix, "results")
	Game.goto("title")
	await tree.create_timer(SCREEN_S + 3.0).timeout
	_save(vp, prefix, "title")
	tree.quit()

static func _save(vp: Viewport, prefix: String, step: String) -> void:
	var png := "%s_%s.png" % [prefix, step]
	vp.get_texture().get_image().save_png(png)
	print("TOUR ", png)

## The loading screen on its own, half way, over whatever is up.
static func _loading(tree: SceneTree, vp: Viewport, prefix: String) -> void:
	var ld: CanvasLayer = load("res://scripts/ui/loading.gd").new()
	ld.setup({"tier": 1, "teams": 6, "squad": 1, "seed": 7})
	tree.root.add_child(ld)
	ld.set("want", 0.55)
	ld.set_stage("map")
	await tree.create_timer(SETTLE_S + 0.6).timeout
	_save(vp, prefix, "loading")
	ld.queue_free()

static func _result() -> Dictionary:
	return {"extracted": true, "gems": 42, "seeds": {"sunroot": 1}, "caught": [Save.new_kin("zapple")], "knocks": 3,
		"damage": 512, "taken": 388, "kills": 1, "downs": 1, "deaths": 0, "revives": 2, "armor_tier": 3,
		"time": 201.0, "kin_trust": 57.0, "tonics": 1,
		"kin_events": [{"kind": "refused", "trust": -1.0,
			"text": "refused to jump into a fight that looked too dangerous"}]}
