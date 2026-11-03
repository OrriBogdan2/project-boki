class_name UiTour
extends RefCounted
## Screenshots of the menu kit in one run (tooling): at home with --armory-test, --ui-tour=<prefix>
## saves <prefix>_<step>.png for the armory, the kit card, a toast, the menu, every settings tab, a
## tooltip and a confirm box, then quits. One run instead of a dozen, on a slow shared machine.

const SETTLE_S := 1.2      # seconds each step gets to fade in before its picture

## Walks the steps on the home screen `home`, saving each to `prefix`_<name>.png.
static func run(home: Node, prefix: String) -> void:
	var tree := home.get_tree()
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
	await tree.create_timer(3.0).timeout
	for step in steps:
		(step[1] as Callable).call()
		await tree.create_timer(SETTLE_S).timeout
		var png := "%s_%s.png" % [prefix, step[0]]
		home.get_viewport().get_texture().get_image().save_png(png)
		print("TOUR ", png)
	tree.quit()
