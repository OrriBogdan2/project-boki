extends RefCounted
## --mood-bubble-check: a six-Boki base (base_mode on) where each feeling shows the right icon in the
## mood bubble (hungry, sleepy, wants to play, happy, sulking, cross), no number anywhere on it, it
## fades after 3 s and comes back on hover or when you walk near, a changed feeling shows again, and
## with base_mode off the old wants bubble is all there is. --mood-bubble-shots --shots-dir=<dir>
## saves the same garden as screenshots (GPU). Never touches the real save.

const FEELINGS := ["hungry", "sleepy", "play", "happy", "sulk", "cross"]
const SPECIES := ["zapple", "cindle", "puddlet", "zapple", "cindle", "puddlet"]

var bad := 0
var main: Node
var home
var dir := "user://mood_bubble_shots"

func ok(cond: bool, what: String) -> void:
	print("MOODBUBBLE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(m: Node, mode := "check") -> void:
	main = m
	Save.no_write = true
	Content.rules("farm_build")["base_mode"] = true
	await _garden()
	if mode == "shots":
		await _shots()
	else:
		_check()
	Content.rules("farm_build")["base_mode"] = false
	print("MOODBUBBLE DONE, failures: %d" % bad)
	main.get_tree().quit()

## Six Boki in a row, five tiles in front of you, each set up for one feeling.
func _garden() -> void:
	var d := Save.fresh()
	for i in 6:
		d["roster"].append(Save.new_kin(SPECIES[i], "Boki%d" % i))
	d["active"] = d["roster"][0]["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()
	Save.d = d
	FarmTutorial.skip()
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null and home.kins.size() == 6:
			break
		await main.get_tree().process_frame
	home._close_panel()
	if main.fade:
		main.fade.reveal(0.05)
	home.day_t = 0.5
	var centre: Vector3 = home.ppos + Vector3(-1.5, 0, 5.0)
	for i in 6:
		var k: Dictionary = home.kins[i]
		var at := centre + Vector3((i - 2.5) * 1.7, 0, 0)
		k["pos"] = at
		k["goal"] = at
		k["t"] = 600.0
		(k["node"] as Node3D).position = at
		for n in Care.NEEDS:
			k["rec"]["needs"][n] = 80.0
		k["rec"]["needs_t"] = Time.get_unix_time_from_system() + 9999.0
	home.kins[0]["rec"]["needs"]["food"] = 5.0
	home.kins[1]["rec"]["needs"]["energy"] = 5.0
	home.kins[2]["rec"]["needs"]["joy"] = 5.0
	KinMood.react(home.kins[3], true)
	KinMood.react(home.kins[4], false)
	var a: Dictionary = home.kins[4]["rec"]
	var b: Dictionary = home.kins[5]["rec"]
	a["bonds"] = {String(b["uid"]): -0.8}
	b["bonds"] = {String(a["uid"]): -0.8}

func _step(secs: float) -> void:
	for i in int(secs / 0.1):
		home._update_bubbles(0.1)

## The one feeling icon showing on a Boki's bubble ("" when the bubble is hidden or shows two).
func _icon(k: Dictionary) -> String:
	var bub: Node3D = k.get("mood_bub")
	if bub == null or not bub.visible:
		return ""
	var up: Array = []
	for f in FEELINGS:
		if (bub.get_node(f) as Node3D).visible:
			up.append(f)
	return String(up[0]) if up.size() == 1 else ""

## How many digits are written on a Boki's bubble (-1 when it has none yet).
func _numbers(k: Dictionary) -> int:
	if not k.has("mood_bub"):
		return -1
	var n := 0
	for l in (k["mood_bub"] as Node).find_children("*", "Label3D", true, false):
		for c in (l as Label3D).text:
			n += 1 if c >= "0" and c <= "9" else 0
	return n

func _check() -> void:
	_step(0.6)
	for i in 6:
		var k: Dictionary = home.kins[i]
		ok(_icon(k) == FEELINGS[i], "%s shows the %s icon (%s)" % [k["rec"]["name"], FEELINGS[i], _icon(k)])
		ok(_numbers(k) == 0, "%s's bubble has no numbers" % k["rec"]["name"])
	_step(3.8)
	ok(home.kins.all(func(k): return _icon(k) == ""), "after 3 s every bubble has faded")
	home.ppos = home.kins[0]["pos"] + Vector3(-1.5, 0, 0)
	_step(0.6)
	ok(_icon(home.kins[0]) == "hungry" and _icon(home.kins[1]) == "", "walking up to a Boki shows its feeling again")
	home.ppos = home.kins[0]["pos"] + Vector3(0, 0, -5.0)
	_step(0.8)
	home.hover_k = home.kins[1]
	_step(0.6)
	ok(_icon(home.kins[1]) == "sleepy", "hovering a Boki shows its feeling again")
	home.hover_k = {}
	_step(0.8)
	home.kins[0]["rec"]["needs"]["food"] = 90.0
	_step(0.6)
	ok(_icon(home.kins[0]) == "happy", "a Boki that is fed answers happy")
	home.kins[1]["rec"]["needs"]["food"] = 4.0
	_step(0.8)
	ok(_icon(home.kins[1]) == "hungry", "a changed feeling pops up by itself (sleepy to hungry)")
	var plain: Array = home.kins.filter(func(k): return k.has("bubble") and k["bubble"].visible)
	ok(plain.is_empty(), "base_mode on: the old wants bubble stays away")
	Content.rules("farm_build")["base_mode"] = false      # the rule is read live; hide the bubbles made so far
	for k in home.kins:
		k["mood_bub"].visible = false
	_step(3.0)
	ok(home.kins.all(func(k): return not k["mood_bub"].visible), "base_mode off: no mood bubble")
	ok(home.kins.any(func(k): return k.has("bubble") and k["bubble"].visible),
		"base_mode off: the plain wants bubble shows")

func _shots() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	var mid: Vector3 = home.kins[2]["pos"] + Vector3(0.85, 0, 0)
	home.player.position = mid + Vector3(0, 0, -5.0)
	home.ppos = home.player.position
	home.cam.snap(mid)
	await _hold(2.0)
	await _save("garden_1_six_moods.png")
	home.player.position = mid + Vector3(0, 0, -1.2)      # the camera follows the player: stand by the row
	home.ppos = home.player.position
	home.cam.zoom_to = 0.55
	home.cam.zoom = 0.55
	home.cam.snap(mid)
	await _hold(0.3)
	await _save("garden_2_close.png")
	home.cam.zoom_to = 1.0
	home.cam.zoom = 1.0
	home.player.position = mid + Vector3(0, 0, -5.0)
	home.ppos = home.player.position
	home.cam.snap(mid)
	await _hold(4.0)
	await _save("garden_3_faded.png")
	home.ppos = home.kins[0]["pos"] + Vector3(-1.5, 0, 0)
	home.player.position = home.ppos
	await _hold(0.8)
	await _save("garden_4_walk_near.png")

## Lets the garden run for `secs` while the six Boki stay on their marks, free and in their feeling
## (the shots show the bubbles, not the wandering).
func _hold(secs: float) -> void:
	var marks: Array = home.kins.map(func(k): return k["pos"])
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		for i in 6:
			var k: Dictionary = home.kins[i]
			k["pos"] = marks[i]
			k["goal"] = marks[i]
			k["t"] = 600.0
			(k["node"] as Node3D).position = marks[i]
			for busy in ["nap_t", "say_t", "hold_t"]:
				k[busy] = 0.0
			if i in [3, 4]:
				k["mood_ev_t"] = KinMood.EVENT_S
		await main.get_tree().process_frame

func _save(file: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	print("MOODBUBBLE SHOT %s" % file)
