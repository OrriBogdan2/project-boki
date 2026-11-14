extends RefCounted
## --result-card-shots --shots-dir=<dir>: the shared result card as each garden game ends on it
## (tumble.png, echo_steps.png, show_ring.png, relay_cup.png, glint_fishing.png). Needs a renderer (jobq --needs gpu).

const NavCheck := preload("res://tools/garden_nav_check.gd")
const SETTLE := 20        # frames to let the screen settle before a grab

func run(main: Node) -> void:
	var dir := "shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	FarmUnlocks.rules()["base_mode"] = true
	var nav := NavCheck.new()
	nav.main = main
	nav.zone = "glasswater"
	nav._save()
	var home = await nav._open_home()
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	while not is_instance_valid(home.root_ui):
		await main.get_tree().process_frame
	var recs: Array = Save.d["roster"].slice(0, 3)
	var cards := {
		"tumble": ["Tumble", "%s wins, out of the ring", [["+2 gems", UI.GOLD]], 1],
		"echo_steps": ["Echo Steps", "%s wins, 84 points to 61", [["+2 gems, best streak 6", UI.GOLD]], 2],
		"show_ring": ["Show Ring", "%s wins, 8.4 to 7.1", [["+2 gems for showing the winner", UI.GOLD],
				["Prize: Silk Ribbon", UI.GOLD], ["Cup: beat the Sprout round", UI.TEAL]], 2],
		"relay_cup": ["Relay Cup", "Your team wins by 0.8 s", [["+3 gems", UI.GOLD], ["Prize: Rope Toy", UI.GOLD],
				["Crown! The Relay Ribbon is yours", UI.ACCENT_HI]], 3],
		"glint_fishing": ["Glint Fishing", "3 of 5 landed", [["Glint Pearl", UI.GOLD], ["Glint Pearl", UI.GOLD],
				["Minnow Snack", UI.INK]], 1],
	}
	for id in cards:
		var c: Array = cards[id]
		var team := recs.slice(0, c[3])
		var before := GameResultCard.snap(team)
		Care.change(team[0], "joy", 8.0)
		team[0]["stats"]["speed"] = int(team[0]["stats"]["speed"]) + 1
		var place: String = c[1].replace("%s", team[0]["name"])
		var card := GameResultCard.open(home, {"game": c[0], "place": place, "prize": c[2], "before": before})
		for i in SETTLE:
			await main.get_tree().process_frame
		main.get_viewport().get_texture().get_image().save_png(dir.path_join(id + ".png"))
		card.queue_free()
	print("RESULTCARDSHOTS DONE")
	main.get_tree().quit()
