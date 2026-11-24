extends RefCounted
## --hatch-flow-shots=<dir>: screenshots of every step of the hatch -> reveal -> name flow, for both
## ways a Boki hatches (the first egg on the hatch screen, and an egg on the farm). Run under xvfb
## with --rendering-driver opengl3 --resolution WxH. Writes <name>.png and prints "HSHOT <name>".
## Never touches the real save.

var main: Node
var dir := ""

func _shot(shot_name: String, settle := 0.4) -> void:
	await main.get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	print("HSHOT %s" % shot_name)

func _until(cond: Callable, cap := 1800) -> bool:
	for _i in cap:
		if cond.call():
			return true
		await main.get_tree().process_frame
	return false

func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hatch-flow-shots="):
			dir = String(a).substr(19)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	await _first_egg()
	await _farm_egg()
	print("HSHOT DONE")
	main.get_tree().quit()

func _first_egg() -> void:
	Save.d = Save.fresh()
	Save.d["tutorial"] = {"intro": true}
	Save.d["look"] = Unmasked.default_look()
	main.show_screen("hatch", {})
	await _until(func(): return main.current != null and main.current.get_script() == load("res://scripts/ui/hatch.gd"))
	var hx = main.current
	await main.fade.reveal(0.01)
	hx._end_intro()
	hx._pick(0)
	hx._pick(0)
	hx.auto_warm = true
	await _until(func(): return hx.reveal != null and is_instance_valid(hx.reveal))
	await _shot("a1_reveal_start", 0.9)
	await _until(func(): return hx.reveal.met)
	await _shot("a2_reveal_card", 0.9)
	hx.reveal._go()
	await _until(func(): return hx.stage == "name")
	await _shot("a3_name", 1.0)
	hx.queue_free()
	await main.get_tree().process_frame

func _farm_egg() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	var home = await main._hb_home()
	await _until(func(): return home.root_ui != null and home.hb != null and home.player != null)
	home._close_panel()
	await _shot("b0_farm", 2.0)
	var baby := Save.new_kin("puddlet", "")
	home._hatch_play(baby, false, "", home.NEST_AT, null)
	await _until(func(): return home.panel_open == "reveal")
	await _shot("b1_reveal_start", 0.9)
	var rv: KinReveal = null
	for ch in home.get_children():
		if ch is KinReveal:
			rv = ch
	await _until(func(): return rv.met)
	await _shot("b2_reveal_card", 0.9)
	rv._go()
	await _until(func(): return home.panel_open == "It hatched!")
	await _shot("b3_name", 1.0)
