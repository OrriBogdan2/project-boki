extends RefCounted
## --hob-work-shots=<dir>: the house going up under Hob's own hammer after Skip tutorial (run with a real
## renderer). Writes 1_start.png (his first swings) and 2_later.png (the walls risen, the bar fuller).
## His pace is sped up to HURRY_S per swing so the pair needs seconds, not minutes. Never touches the real save.

const HURRY_S := 1.5  # s: seconds between his swings while shooting
const LATER_AT := 9  # swings done when the second shot is taken

var main: Node
var dir := ""
var home = null


func run(m: Node) -> void:
	main = m
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--hob-work-shots="):
			dir = String(a).substr(17)
	DirAccess.make_dir_recursive_absolute(dir)
	Save.no_write = true
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true}
	Save.d = d
	HomeLayout.ensure(Save.d)
	d["tutorial"]["home"] = true
	Work.set_prio("craft", 0)
	home = await main._hb_home()
	for i in 1200:
		if home.hob != null and is_instance_valid(home.hob.node) and home.player != null:
			break
		await main.get_tree().process_frame
	home._close_panel()
	home.guide.skip()
	home.hob.rules()["swing_s"] = HURRY_S
	for kk in home.kins:
		kk["pos"] = Vector3(-500, 0, -500)
	var u := int(FarmHob.house_entry()["u"])
	await _until(func(): return _got(u) >= 1)
	await _shot("1_start", u)
	await _until(func(): return _got(u) >= LATER_AT)
	await _shot("2_later", u)
	main.get_tree().quit(0)


func _got(u: int) -> int:
	var e := FarmSites.entry(u)
	return int(e["site"]["got"]) if FarmSites.has_site(e) else 99


func _until(cond: Callable) -> void:
	for i in 6000:
		if cond.call():
			return
		await main.get_tree().process_frame


func _shot(shot_name: String, u: int) -> void:
	var at := HomeLayout.deco_center(FarmSites.entry(u))
	var stand := at + Vector3(0.0, 0.0, 7.0)
	home.ppos = stand
	home.player.position = stand
	home.cam.zoom_to = 0.9
	home.cam.zoom = 0.9
	home.cam.snap(at + Vector3(2.0, 0.0, 1.5))
	if main.fade:
		main.fade.reveal(0.05)
		for i in 600:
			if main.fade.rect.color.a <= 0.01:
				break
			await main.get_tree().process_frame
	await main.get_tree().create_timer(0.4).timeout
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, shot_name])
	var e := FarmSites.entry(u)
	var swings := "%d/%d" % [int(e["site"]["got"]), int(e["site"]["need"])]
	print("HOBWORKSHOT %s swings %s pose %s" % [shot_name, swings, home.hob.node.pose])
