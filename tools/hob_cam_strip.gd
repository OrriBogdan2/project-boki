extends RefCounted
## --hob-cam-strip[=<dir>]: the home camera through the Hob tutorial conversation (it should hold one
## gentle framing: no zoom or swing per line or per step). A new farm (hob_check's), then: the first
## arrival (he waves and calls), the first talk line by line, a short walk-off, and a later talk at the
## next tutorial step. Every 0.25 s it prints "HOBCAM <t> <phase> zoom=<z> dx=<m> dz=<m>" (the camera's
## focus against you) and, with a dir and a renderer, saves cam_<NN>_<phase>.png every 0.5 s. Ends with
## the zoom range and the largest focus offset.
## Never touches the real save.

const STEP_S := 0.25

var main: Node
var dir := ""
var home = null
var t := 0.0
var n := 0
var zmin := 99.0
var zmax := 0.0
var off_max := 0.0

func run(m: Node, out_dir: String) -> void:
	main = m
	dir = out_dir
	Save.no_write = true
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	main.get_tree().root.size = Vector2i(1280, 720)
	var hc = load("res://tools/hob_check.gd").new()
	hc.main = m
	await hc._new_farm()
	home = hc.home
	if main.fade:
		main.fade.reveal(0.05)
	var hob = home.hob
	var near: Vector3 = hob.node.position + Vector3(2.2, 0, 2.2)
	home.ppos = near
	home.player.position = near
	home.cam.snap(near)
	await _run_for(4.0, "arrive")      # (the first-arrival wave and call)
	hob.talk()
	var lines := 0
	while hob.chat.talking() and lines < 12:
		await _run_for(1.25, "talk%d" % lines)
		for k in 2:      # (one click finishes typing the line, the next moves on)
			if hob.chat.talking():
				hob.chat.box.advance()
		lines += 1
	await _run_for(2.0, "after")
	hob.talk()                         # a later step: what to do next
	await _run_for(1.5, "step")
	while hob.chat.talking():
		hob.chat.box.advance()
		await main.get_tree().process_frame
	await _run_for(2.0, "closed")
	print("HOBCAM SUMMARY zoom %.3f..%.3f (span %.3f), focus offset max %.2f m, %d frames"
			% [zmin, zmax, zmax - zmin, off_max, n])
	main.get_tree().quit()

func _run_for(secs: float, phase: String) -> void:
	var end := t + secs
	while t < end - 0.001:
		await main.get_tree().create_timer(STEP_S).timeout
		t += STEP_S
		var c = home.cam
		var d: Vector3 = c.focus - home.ppos
		zmin = minf(zmin, c.zoom)
		zmax = maxf(zmax, c.zoom)
		off_max = maxf(off_max, Vector2(d.x, d.z).length())
		print("HOBCAM %5.2f %-7s zoom=%.3f dx=%+.2f dz=%+.2f" % [t, phase, c.zoom, d.x, d.z])
		if dir != "" and DisplayServer.get_name() != "headless" and int(round(t / STEP_S)) % 2 == 0:
			main.get_viewport().get_texture().get_image().save_png("%s/cam_%02d_%s.png" % [dir, n, phase])
			n += 1
