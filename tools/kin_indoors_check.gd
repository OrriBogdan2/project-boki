extends RefCounted
## --kin-indoors-check: a new player's second Boki comes out onto the farm (a repeat only goes to the
## Burrow once one is built), a Boki only goes indoors when there is a house and never for long
## while you are around, with no house it naps outside, and every Boki that isn't visible says where
## it is. Also the wants display: one bubble per Boki with its icon, the most urgent first, the
## interact prompt naming the want, and a happy answer when it is met. Never touches the real save.

var bad := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	print("KININDOORS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func _home():
	return await main._hb_home()

func _new_save() -> void:
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(d)

func _step(home, secs: float, force_choice := false) -> void:
	for i in int(secs / 0.25):
		if force_choice:
			for k in home.kins:
				k["t"] = 0.0
		home._move_kin(0.25)

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	_new_save()
	var second := Save.new_kin("zapple", "Mochi")
	Save.d["roster"].append(second)
	var went := KinBox.route_new(second)
	ok(went == "farm" and not KinBox.is_boxed(second),
		"a new save's second Boki (same kind) goes out on the farm: no Burrow to hide it in (%s)" % went)
	var home = await _home()
	ok(home.fs and home.kins.size() == 2, "both Boki are on the farm-start island (%d)" % home.kins.size())
	# ------------------------------------------------ no house: nobody goes indoors, they nap outside
	home.day_t = 0.75
	var ins := 0
	var naps := 0
	for i in 160:
		_step(home, 0.25, true)
		for k in home.kins:
			ins += 1 if k.has("indoors") else 0
			naps += 1 if float(k.get("nap_t", 0.0)) > 0.0 else 0
	ok(not KinIndoors.has_house(home.spots) and ins == 0, "with no house nobody goes indoors")
	ok(naps > 0, "with no house a Boki curls up and naps outside (%d nap frames)" % naps)
	# ------------------------------------------------ a house: short naps, out when you walk up
	home.spots["house"] = Vector3(38.0, 0, 26.5)
	var k: Dictionary = home.kins[1]
	var door: Vector3 = home._house_door()
	var enter := func():
		k.erase("nap_t")
		k["pos"] = door
		k["going_in"] = true
		k["goal"] = door
		home.ppos = door + Vector3(30, 0, 0)
		home.day_t = 0.75
		home._move_kin(0.05)
	enter.call()
	ok(k.has("indoors") and not k["node"].visible and float(k["indoors"]) <= KinIndoors.NAP_NIGHT.y,
		"with a house it goes in for a short nap (%.0f s)" % float(k.get("indoors", -1)))
	ok(KinIndoors.status(k["rec"]).begins_with("Inside, out in"),
		"the Boki list says \"%s\"" % KinIndoors.status(k["rec"]))
	home._update_bubbles(0.1)
	var badge: Label3D = home.get_node_or_null(KinIndoors.BADGE)
	ok(badge != null and badge.visible and badge.text.contains("Mochi"),
		"an icon by the door names it (\"%s\")" % (badge.text if badge else ""))
	home.ppos = door + Vector3(1.2, 0, 0)
	home._update_bubbles(0.1)
	ok(badge.text == "Mochi is napping inside", "close up the badge reads \"%s\"" % badge.text)
	_step(home, 0.5)
	ok(k.has("indoors"), "it settles for a moment before it comes out")
	_step(home, 1.5)
	ok(not k.has("indoors") and k["node"].visible, "walking up to the house brings it out")
	ok(KinIndoors.status(k["rec"]) == "", "and the list no longer says inside")
	enter.call()
	var t0 := float(k["indoors"])
	home.ppos = door + Vector3(5.0, 0, 0)
	_step(home, 2.0)
	ok(float(k["indoors"]) < t0 - 2.0 * 3.0,
		"with you nearby the nap runs several times faster (%.1f -> %.1f)" % [t0, float(k["indoors"])])
	enter.call()
	home.ppos = door + Vector3(30, 0, 0)
	_step(home, 45.0)
	ok(not k.has("indoors"), "even with you away it is out within %d s" % int(KinIndoors.NAP_NIGHT.y + 5))
	enter.call()
	home.spots["house"] = home.FAR
	_step(home, 0.5)
	ok(not k.has("indoors"), "a Boki inside when the house goes comes straight out")
	var boxed := Save.new_kin("cindle", "Ember")
	boxed["boxed"] = true
	ok(KinIndoors.status(boxed) == "In the Burrow", "a Boki in the Burrow says so in the list")
	home.queue_free()
	await main.get_tree().process_frame
	await _wants()
	print("KININDOORS DONE, failures: %d" % bad)
	main.get_tree().quit()

func _wants() -> void:
	_new_save()
	Save.d["roster"].append(Save.new_kin("cindle", "Ember"))
	Save.d["roster"].append(Save.new_kin("puddlet", "Drip"))
	var home = await _home()
	var a: Dictionary = home.kins[0]
	var b: Dictionary = home.kins[1]
	var c: Dictionary = home.kins[2]
	for k in home.kins:
		k["pos"] = home.ppos + Vector3(2.0, 0, 0)
		for n in Care.NEEDS:
			k["rec"]["needs"][n] = 80.0
		k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0
	home._update_bubbles(0.5)
	ok(home.kins.all(func(k): return not k["bubble"].visible), "nothing needed: no bubbles")
	a["rec"]["needs"]["food"] = 10.0
	b["rec"]["needs"]["energy"] = 30.0
	b["pos"] = a["pos"] + Vector3(0.6, 0, 0)
	c["rec"]["needs"]["clean"] = 5.0
	c["pos"] = home.ppos + Vector3(-3.0, 0, 0)
	for i in 30:
		home._update_bubbles(0.1)
	ok(a["bubble"].visible and a["bubble"].get_node("bowl").visible and not a["bubble"].get_node("zzz").visible,
		"a hungry Boki shows a food bowl, and only that")
	ok(not b["bubble"].visible, "a second want right beside it adds no second bubble")
	ok(c["bubble"].visible and c["bubble"].get_node("bath").visible, "a dirty Boki further away shows a bath")
	ok(c["bubble"].scale.x > b["bubble"].scale.x and KinWants.urgency(c["rec"]) > KinWants.urgency(a["rec"]) - 0.5,
		"the more urgent want is bigger (%.2f)" % c["bubble"].scale.x)
	ok(KinWants.line(a["rec"], true).contains("hungry"), "the prompt names it: \"%s\"" % KinWants.line(a["rec"], true))
	a["rec"]["likes"]["food"] = "kibble"
	Save.d["items"]["kibble"] = 2
	ok(KinWants.line(a["rec"], true) == "%s is hungry: give food" % a["rec"]["name"]
		and KinWants.action(a["rec"], true) == "feed",
		"with food on you the prompt is \"%s\"" % KinWants.line(a["rec"], true))
	ok(KinWants.action(c["rec"], false) == "brush" and KinWants.action(c["rec"], true) == "bath",
		"a dirty Boki gets a bath, or a brush with no pond")
	a["rec"]["needs"]["food"] = 90.0
	home._update_bubbles(0.1)
	ok(float(a.get("joy_t", 0.0)) > 0.0 and a["emote"].text == "♥",
		"a Boki that gets what it wanted answers with a heart")
	for i in 30:
		home._update_bubbles(0.1)
	ok(not a["bubble"].visible, "and its bubble is gone")
	home.queue_free()
