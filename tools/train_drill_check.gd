extends RefCounted
## --train-drill-check: Train from a Boki's stat list (Training tab -> Train -> a stat's Train button) never
## errors. On a fresh farm with no Training post the drill is refused with a toast (playtest 11-13: it crashed
## on yard.get_node), and with the post built every stat's drill starts.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("TRAINDRILL %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["level"] = 5
	Care.ensure(k)
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(d)
	var home = await m._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null:
			break
		await m.get_tree().process_frame
	home._close_panel()
	var ke: Dictionary = home._kin_entry(k)
	ok(home.yard == null, "a fresh farm has no Training post")
	for s in Care.STATS:
		home._open_train(k)
		home._start_drill(k, s)
		ok(home.train.is_empty() and not ke.get("busy", false), "no post: %s drill refused, Boki not left busy" % s)
	home.yard = Models.training_yard()
	home.yard.position = home.YARD_AT
	home.add_child(home.yard)
	for s in Care.STATS:
		home._open_train(k)
		home._start_drill(k, s)
		ok(not home.train.is_empty(), "with a post: the %s drill starts" % s)
		home.train["bar"].close()
		home.train = {}
		ke["busy"] = false
	home.queue_free()
	await m.get_tree().process_frame
	print("TRAINDRILL done, %d failed" % bad)
	m.get_tree().quit(1 if bad > 0 else 0)
