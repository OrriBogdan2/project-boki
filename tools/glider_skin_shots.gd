extends "res://tools/warden_shots.gd"
## --glider-skin-shots --shots-dir=<dir>: every glider skin's canopy open over a Hunter, so a change to how
## canopies are built or coloured can be laid over the shots from before it. Per team colour, rows of
## SKINS_PER_ROW skins: <team>_row<N>_game.png at the match camera (true pixels, then enlarged) and
## <team>_row<N>_close.png from above and behind, plus captions.txt. Trails are hidden (their particles are
## random). Needs a renderer.

const SKINS_PER_ROW := 6
const SKIN_GAP := 2.6               # m between Hunters: an open canopy is 2.1-2.3 m across
const TEAMS := {"red": 0, "blue": 1}  # file prefix -> Data.TEAM_COLORS index (the "team" canopy colours)
const WARDEN := "gunslinger"        # any Warden: the canopy is the same over every body
const OPEN_TILT := 0.25             # rad: the open canopy's pitch in flight (Hunter's glide pop at full open)
const CLOSE_PITCH := 50.0           # degrees: the close camera looks down on the canopies' tops

func run(main: Node) -> void:
	tree = main.get_tree()
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	if main.get("fade") != null:
		main.fade.reveal(0.01)
	_stage(main)
	var ids: Array = Gliders.LIST.map(func(g): return String(g["id"]))
	var captions := PackedStringArray()
	for team in TEAMS:
		for r in ceili(ids.size() / float(SKINS_PER_ROW)):
			var skins := ids.slice(r * SKINS_PER_ROW, (r + 1) * SKINS_PER_ROW)
			var row := _open_row(skins, int(TEAMS[team]))
			var stem := "%s_row%d" % [team, r + 1]
			(await _game_strip(row, false)).save_png(out.path_join(stem + "_game.png"))
			(await _top_strip(row)).save_png(out.path_join(stem + "_close.png"))
			captions.append("%s: %s" % [stem, ", ".join(skins)])
			_clear()
	FileAccess.open(out.path_join("captions.txt"), FileAccess.WRITE).store_string("\n".join(captions) + "\n")
	print("GLIDER_SKIN_SHOTS_DONE")
	tree.quit()

## A row of Hunters in one team's colours, each with its glider open in one of `skins`.
func _open_row(skins: Array, team: int) -> Array:
	var row: Array = []
	for i in skins.size():
		var look := PlayerLook.neutral()
		look["glider"] = skins[i]
		var h := Models.hunter(Arch.weight(WARDEN), Data.TEAM_COLORS[team], Arch.signature(WARDEN), "", look, WARDEN)
		h.position = Vector3((i - (skins.size() - 1) * 0.5) * SKIN_GAP, 0, 0)
		var glider := h.get_node("Rig/Torso/Glider") as Node3D
		glider.visible = true
		glider.rotation.x = OPEN_TILT
		var trail := glider.get_node_or_null("Trail") as Node3D
		if trail:
			trail.visible = false
		holder.add_child(h)
		anims.append([HunterAnim.new(h), h])
		row.append(h)
	return row

## The row near, from above and behind, framed to its width.
func _top_strip(row: Array) -> Image:
	var span := (row.size() - 1) * SKIN_GAP + 2.4
	cam.fov = 30.0
	var half_h := atan(tan(deg_to_rad(cam.fov * 0.5)) * 16.0 / 9.0)
	var p := deg_to_rad(CLOSE_PITCH)
	cam.position = Vector3(0, 2.4, 0) + Vector3(0, sin(p), cos(p)) * (span * 0.5 / tan(half_h))
	cam.rotation = Vector3(-p, 0, 0)
	await _settle(4, false)
	return _fit(await _grab())
