extends RefCounted
## --glider-rack-check: the glider rack panel keeps its size whichever skin is picked (playtest 11-13: picking
## a mastery skin wrapped its how-to-earn footer one word per line and pushed the skins and Close off screen),
## and a save gliding on a skin it no longer owns, or one that is gone, loads back onto the Field Wing.

const SAME_PX := 8.0  # px: the panel's height may differ this much between skins (a tag, a button)

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("GLIDERRACK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	Care.ensure(k)
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	d["look"] = Unmasked.default_look()
	for stale in ["lantern_moth", "no_such_skin"]:
		d["look"]["glider"] = stale
		Save.d = d
		ok(Gliders.equipped() == "classic", "a save on %s glides on the Field Wing" % stale)
	Save.d = d
	HomeLayout.ensure(d)
	var home = await m._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null:
			break
		await m.get_tree().process_frame
	var screen: Rect2 = m.get_viewport().get_visible_rect()
	var first := -1.0
	for g in Gliders.LIST:
		home.rack_pick = String(g["id"])
		home._open_rack()
		await m.get_tree().process_frame
		await m.get_tree().process_frame
		var p: Control = home.panel_host.get_child(home.panel_host.get_child_count() - 1)
		var r := p.get_global_rect()
		if first < 0.0:
			first = r.size.y
		ok(
			absf(r.size.y - first) <= SAME_PX and screen.encloses(r),
			"%s: panel %dpx tall, on screen" % [g["id"], r.size.y]
		)
	home.queue_free()
	await m.get_tree().process_frame
	print("GLIDERRACK done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
