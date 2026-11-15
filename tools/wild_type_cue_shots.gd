extends RefCounted
## --wild-type-cue-shots --shots-dir=<dir>: wild_type_cue.png, six wild Boki of six types standing round the
## player at the match camera. Needs a renderer (jobq --needs gpu). Never touches the save.

const TYPES := ["fire", "grass", "electric", "ice", "poison", "psychic"]
const RADIUS := 6.0       # m from the player
const FRAMES := 90        # frames to let the cue fade in and the camera settle

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var dir := "user://"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	var m := Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4243, "no_drop": true, "demo_kin": "cindle"}
	await m.start(opts)
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	var P: Hunter = m.player
	for o in m.hunters:
		if o != P:
			o.ctrl = "idle"
			o.teleport(P.pos + Vector3(60, 0, 60))
	var spots := TYPES.size()
	for i in spots:
		var sid := _species_of(TYPES[i])
		var a := TAU * float(i) / float(spots)
		var k := m.spawn_wild(Save.new_kin(sid, "Wild"), P.pos + Vector3(cos(a), 0, sin(a)) * RADIUS, true)
		k.dazed_t = 1e9
	for i in FRAMES:
		await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join("wild_type_cue.png"))
	print("WILDCUESHOT done")
	main.get_tree().quit()

func _species_of(type: String) -> String:
	for sid in Data.KIN:
		if WildTypeCue.type_of(Data.KIN[sid]) == type:
			return sid
	return "cindle"
