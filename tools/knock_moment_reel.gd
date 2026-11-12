extends RefCounted
## --knock-moment-reel --shots-dir=<dir>: the knock moment (Juice.knock_landed) at the game camera, for a short
## video. Your dash is spent, then a lethal hit knocks a rival beside you: the freeze, the slow-mo, the white
## flash and the dash coming back on the Shift icon; a second rival goes down the same way. The match runs live
## (slow-mo lives in Match._process); every 2nd frame goes to <dir>/frames/NNNNN.jpg. Run it on a GPU worker:
##   jobq submit --needs gpu --out <dir> -- xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720
##     --path . --fixed-fps 60 -- --knock-moment-reel --shots-dir=<dir>
## then ffmpeg -framerate 30 -i <dir>/frames/%05d.jpg -c:v libx264 -crf 24 -pix_fmt yuv420p knock.mp4.
## Never writes the save.

const LEAD_S := 1.0          # s before the first knock (the spent Shift icon reads first)
const GAP_S := 2.2           # s between the two knocks
const TAIL_S := 1.6          # s after the second knock
const SIDE := 2.6            # m from you to each rival

var main: Node
var dir := "/tmp/knock_reel"
var frame := 0

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir.path_join("frames"))
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 4, "squad": 1, "tier": 0, "length": 1e9, "seed": 91, "no_drop": true, "god": false})
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var P: Hunter = m.player
	var foes: Array = m.hunters.filter(func(o): return o.team != P.team)
	for o in m.hunters:
		if o != P: o.ctrl = "idle"
	var spot := m.world.free_spot_near(P.pos, [], 1.0, 0.45, 6.0)
	P.teleport(spot)
	foes[0].teleport(spot + Vector3(SIDE, 0, 0))
	foes[1].teleport(spot + Vector3(-SIDE, 0, 0))
	for o in foes.slice(2): o.teleport(m.world.random_ground())
	for f in [foes[0], foes[1]]:
		P.dashes = 0.0
		P.ex_cd = 5.0
		await _secs(LEAD_S if f == foes[0] else GAP_S)
		f.hurt(f.hp + f.armor + 50.0, P, {"src": "shot"})
		print("KNOCKREEL knock at %.2f s match time, down %s, dash %.1f" % [m.time, f.downed, P.dashes])
	await _secs(TAIL_S)
	print("KNOCKREEL DONE")
	main.get_tree().quit()

func _secs(s: float) -> void:
	for i in int(s * 60.0):
		await main.get_tree().process_frame
		if i % 2 == 1:
			continue
		var img := main.get_viewport().get_texture().get_image()
		if img != null:       # (null headless: nothing is drawn)
			img.save_jpg(dir.path_join("frames/%05d.jpg" % frame), 0.9)
			frame += 1
