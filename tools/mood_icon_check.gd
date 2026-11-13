extends RefCounted
## --mood-icon-check: each mood change (hungry, sleepy, wants to play, sulky, happy, missed you)
## shows its one icon for about three seconds and not again; with six Boki changing at once no more
## than three icons show at a time, nearest to you first, and all six get their turn; the card
## words match the mood. Never touches the real save.

var bad := 0
var main: Node
var home
var now := 0.0

func ok(cond: bool, what: String) -> void:
	print("MOODICON %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var d := Save.fresh()
	var first := Save.new_kin("zapple", "Pip")
	first["starter"] = true
	d["roster"].append(first)
	d["active"] = first["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	for nm in ["Ember", "Drip", "Moss", "Fizz", "Bun"]:
		d["roster"].append(Save.new_kin("cindle", nm))
	Save.d = d
	HomeLayout.ensure(d)
	home = await main._hb_home()
	ok(home.kins.size() == 6, "six Boki on the farm (%d)" % home.kins.size())
	for i in home.kins.size():
		home.kins[i]["pos"] = home.ppos + Vector3(1.0 + i, 0, 0)
	_single_moods()
	_missed()
	_cap_of_three()
	print("MOODICON DONE, failures: %d" % bad)
	main.get_tree().quit()

func _calm() -> void:
	for k in home.kins:
		for n in Care.NEEDS:
			k["rec"]["needs"][n] = 60.0
		k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0
		k["gone_s"] = 0.0
	_run(1.0)

func _run(secs: float) -> void:
	for i in int(secs / 0.1):
		now += 0.1
		KinWants.update(home, 0.1, now)

func _icon(k: Dictionary) -> String:
	var bub: Node3D = k["bubble"]
	if not bub.visible:
		return ""
	for nm in KinWants.ICONS:
		if (bub.get_node(nm) as Node3D).visible:
			return nm
	return ""

## Watches one Boki for secs: how many separate times an icon appeared, which, and for how long.
func _watch(k: Dictionary, secs: float) -> Dictionary:
	var shows := 0
	var up := 0.0
	var icon := ""
	var was := false
	for i in int(secs / 0.1):
		_run(0.1)
		var ic := _icon(k)
		if ic != "":
			up += 0.1
			icon = ic
			if not was:
				shows += 1
		was = ic != ""
	return {"shows": shows, "up": up, "icon": icon}

func _single_moods() -> void:
	var cases := [
		["hungry", "bowl", "food", 10.0], ["sleepy", "zzz", "energy", 20.0], ["play", "ball", "joy", 30.0],
		["sulky", "cloud", "joy", 5.0], ["happy", "heart", "joy", 90.0]]
	var k: Dictionary = home.kins[0]
	for c in cases:
		_calm()
		ok(_icon(k) == "", "calm Boki: no icon")
		k["rec"]["needs"][c[2]] = c[3]
		var w := _watch(k, 6.0)
		ok(w["shows"] == 1 and w["icon"] == c[1] and absf(float(w["up"]) - KinMood.SHOW_S) < 0.35,
			"%s shows %s once for %.1f s" % [c[0], w["icon"], w["up"]])
		ok(KinMood.words(home, k["rec"]) == KinMood.WORDS[c[0]], "card says \"%s\"" % KinMood.words(home, k["rec"]))
	_calm()
	ok(KinMood.words(home, k["rec"]) == "Calm", "content Boki card says Calm")

func _missed() -> void:
	_calm()
	var k: Dictionary = home.kins[0]
	k["pos"] = home.ppos + Vector3(30.0, 0, 0)
	_run(KinMood.LONELY_S + 5.0)
	ok(_icon(k) == "", "you are away: nothing shown while it waits")
	k["pos"] = home.ppos + Vector3(1.0, 0, 0)
	var w := _watch(k, 6.0)
	ok(w["shows"] == 1 and w["icon"] == "miss", "you come back: the missed-you icon shows once")
	_run(1.0)
	ok(KinMood.words(home, k["rec"]) == "Calm", "and it calms down after (\"%s\")" % KinMood.words(home, k["rec"]))

func _cap_of_three() -> void:
	_calm()
	var moods := [["food", 10.0], ["energy", 10.0], ["joy", 30.0], ["joy", 5.0], ["joy", 90.0], ["food", 20.0]]
	for i in 6:
		var k: Dictionary = home.kins[i]
		k["pos"] = home.ppos + Vector3(6.0 - i, 0, 0.5)        # kins[5] is nearest
		k["rec"]["needs"][moods[i][0]] = moods[i][1]
	var nearest: Array = [home.kins[5], home.kins[4], home.kins[3]]
	var most := 0
	var first_set: Array = []
	var shows := {}
	var was := {}
	for i in 150:
		_run(0.1)
		var up: Array = home.kins.filter(func(k): return _icon(k) != "")
		most = maxi(most, up.size())
		if i == 5:
			first_set = up
		for k in home.kins:
			var uid := String(k["rec"]["uid"])
			if _icon(k) != "" and not was.get(uid, false):
				shows[uid] = int(shows.get(uid, 0)) + 1
			was[uid] = _icon(k) != ""
	ok(most == 3, "six Boki change at once: at most 3 icons show (most %d)" % most)
	ok(first_set.size() == 3 and nearest.all(func(k): return first_set.has(k)), "the three nearest show first")
	var once: bool = home.kins.all(func(k): return int(shows.get(String(k["rec"]["uid"]), 0)) == 1)
	ok(once, "every Boki gets its icon exactly once")
