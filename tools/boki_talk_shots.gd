extends RefCounted
## --boki-talk-shots --shots-dir=<dir>: Boki talk review screenshots (item 105; run under xvfb with a
## renderer). Farm, at the normal farm camera: a grown Boki by a ready crop, a young Boki being petted
## (its name and an action), and two Boki in the rain at night left to the live FarmChatter tick (plus
## the friend's answer when the line was a chat). Match: the Boki's line when it uses its own ability,
## and when you level up (both through the real hooks in Hunter). <dir>/captions.txt gets "file:
## caption" per shot. Never touches the real save.

var main: Node
var dir := ""
var home = null
var captions: Array = []

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	await _farm()
	await _match()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for c in captions:
		f.store_line(c)
	f.close()
	print("BOKITALKSHOTS %d in %s" % [captions.size(), dir])
	main.get_tree().quit(0)

func _save(file: String, caption: String) -> void:
	await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file))
	captions.append("%s: %s" % [file, caption])
	print("BOKITALKSHOT %s | %s" % [file, caption])

# ------------------------------------------------------------------ farm
func _farm() -> void:
	var d := Save.fresh()
	var grown := _rec("zapple", "Pip", 12, 80.0)
	var young := _rec("cindle", "Ember", 1, 10.0)
	var friend := _rec("puddlet", "Drip", 12, 80.0)
	d["roster"] = [grown, young, friend]
	d["active"] = grown["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	d["layout"] = HomeLayout.fresh()      # the classic farm: its crop plots are out from the start
	Save.d = d
	FarmTutorial.skip()
	home = await main._hb_home()
	for i in 900:
		if home.root_ui != null and home.player != null and home.kins.size() == 3:
			break
		await main.get_tree().process_frame
	home._close_panel()
	if main.fade:
		main.fade.reveal(0.05)
	home.day_t = 0.5
	Save.d["plot_cap"] = 4
	home._build_plots()
	var crop := String(Data.CROPS.keys()[0])
	for i in 4:
		Save.d["plots"][i] = {"crop": crop, "stage": int(Data.CROPS[crop]["grow"]), "care": 1, "wt": 0.0}
		home._refresh_plot("plots", i)
	await main.get_tree().create_timer(0.6).timeout
	var plot_at: Vector3 = (home.plots[0] as Node3D).position
	var kg: Dictionary = home._kin_entry(grown)
	var ky: Dictionary = home._kin_entry(young)
	var kf: Dictionary = home._kin_entry(friend)
	# 1. a grown Boki by a ready crop
	_place(kg, plot_at + Vector3(0.9, 0, 0.4))
	_place(ky, plot_at + Vector3(-8, 0, 6))
	_place(kf, plot_at + Vector3(8, 0, -6))
	_look(plot_at + Vector3(0.5, 0, 3.0))
	home._say(kg, BokiLines.say(grown, "crop_ready"))
	await main.get_tree().create_timer(0.5).timeout
	await _save("farm_1_crop_ready.png", "A grown Boki (Echolop) beside a ripe crop: a crop_ready line")
	# 2. a young Boki being petted: its name in a tone, plus an action
	await main.get_tree().create_timer(BokiLines.bubble_s()).timeout
	_place(ky, plot_at + Vector3(-1.0, 0, 1.5))
	_look(ky["pos"] + Vector3(-0.5, 0, 2.5))
	home._say(ky, BokiLines.say(young, "petted"))
	await main.get_tree().create_timer(0.5).timeout
	await _save("farm_2_young_petted.png", "A just-hatched Boki (stage 0) petted: only its name and an action")
	# 3. rain at night: two Boki side by side chat, the second answers (FarmChatter, the live path)
	await main.get_tree().create_timer(BokiLines.bubble_s()).timeout
	home.day_t = 0.97
	home.raining = true
	home.rain_k = 1.0
	home.rain.emitting = true
	home.weather_t = 999.0
	_place(ky, plot_at + Vector3(-9, 0, 6))
	_place(kg, plot_at + Vector3(4.0, 0, 3.0))
	_place(kf, plot_at + Vector3(5.6, 0, 3.4))
	_look(kg["pos"] + Vector3(0.8, 0, 2.6))
	var first := await _chatter_until([kg, kf], 60.0)
	await _save("farm_3_rain_night.png", "Night and rain, the live FarmChatter tick: a Boki speaks up about it")
	if not first.is_empty():
		var other: Dictionary = kf if first == kg else kg
		if not (await _chatter_until([other], BokiLines.bubble_s() + 1.5)).is_empty():
			await _save("farm_4_chat_reply.png", "Its friend beside it answers (a chat line, then chat_reply)")
	home.queue_free()
	await main.get_tree().process_frame

## Lets FarmChatter run (the real tick) until one of these Boki is talking, for at most secs; returns it.
func _chatter_until(ks: Array, secs: float) -> Dictionary:
	var t := 0.0
	while t < secs:
		for k in ks:
			if float(k.get("say_t", 0.0)) > 0.0:
				await main.get_tree().create_timer(0.3).timeout
				return k
		await main.get_tree().create_timer(0.1).timeout
		t += 0.1
	return {}

func _place(k: Dictionary, at: Vector3) -> void:
	k["pos"] = at
	k["goal"] = at
	k["t"] = 30.0
	(k["node"] as Node3D).position = at

func _look(at: Vector3) -> void:
	home.ppos = at
	home.player.position = at
	home.cam.snap(at + Vector3(0, 0, -2.0))

func _rec(species: String, boki_name: String, level: int, trust: float) -> Dictionary:
	var rec := Save.new_kin(species, boki_name)
	rec["level"] = level
	rec["trust"] = trust
	return rec

# ------------------------------------------------------------------ match
func _match() -> void:
	var d := Save.fresh()
	var rec := _rec("wisplet", "Moth", 12, 80.0)
	d["roster"] = [rec]
	d["active"] = rec["uid"]
	Save.d = d
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true})
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	var k := m.player.kin as Kin
	await main.get_tree().create_timer(1.5).timeout
	# 4. its own ability (through CombatBus.ability_used and Hunter's hook)
	k.runner.slots["k1"]["cd"] = 0.0
	k.runner.slots["k1"]["charges"] = 1.0
	k.use_ability("k1", k.pos + Vector3(3, 0, 0))
	await main.get_tree().create_timer(0.4).timeout
	await _save("match_1_ability.png", "In a match: the Boki (Lunowl) calls out as it uses its own ability")
	# 5. a level-up (Hunter.gain_xp's hook)
	await main.get_tree().create_timer(BokiLines.tuning("cooldown_s")).timeout      # (a level-up line waits its turn)
	m.player.gain_xp(float(Hunter.XP_TO[m.player.lvl]) + 1.0)
	await main.get_tree().create_timer(0.4).timeout
	await _save("match_2_level_up.png", "In a match: the Boki cheers when you level up")
