extends Node
# Autoload used only by tooling: when started with -- --shot=path.png --frames=N it saves a screenshot and quits.
# --shot-every=S with --frames=N also saves path_1.png, path_2.png ... every S seconds of game time.
var path := ""
var frames := 60
var every := 0.0
var n := 0
var t := 0.0
var k := 0
var at_time := -1.0      # --shot-time=S: shoot once the match clock reaches S seconds (same moment however slow the frames)
var at_times: Array = [] # --shot-times=a,b,c: path_1.png, path_2.png ... at those match times, then quit
func _ready():
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): path = a.substr(7)
		elif a.begins_with("--frames="): frames = int(a.substr(9))
		elif a.begins_with("--shot-every="): every = float(a.substr(13))
		elif a.begins_with("--shot-time="): at_time = float(a.substr(12)); frames = 1000000
		elif a.begins_with("--shot-times="):
			for x in a.substr(13).split(","): at_times.append(float(x))
			at_time = float(at_times.back())
	if path == "": set_process(false)
func _process(d):
	n += 1
	if at_time >= 0.0:
		var cur = get_tree().root.get_node_or_null("Main/Match")
		if cur == null:
			for c in get_tree().root.get_children():
				var mm = c.get_node_or_null("Match")
				if mm: cur = mm
		while cur and not at_times.is_empty() and float(cur.get("time")) >= float(at_times[0]):
			k += 1
			at_times.pop_front()
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % k))
			if at_times.is_empty():
				print("SHOT ", path, " x", k); get_tree().quit()
			return
		if cur and k == 0 and float(cur.get("time")) >= at_time:
			get_viewport().get_texture().get_image().save_png(path); print("SHOT ", path, " t=", cur.get("time")); get_tree().quit()
		return
	if every > 0.0:
		t += d
		if t >= every * (k + 1):
			k += 1
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % k))
	if n == frames:
		if "--overflow-check" in OS.get_cmdline_user_args():
			_overflow(get_tree().root)
		var img := get_viewport().get_texture().get_image()
		img.save_png(path); print("SHOT ", path); get_tree().quit()

## Tooling: lists visible controls that stick out of the window.
func _overflow(node: Node) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node is Control:
		var c := node as Control
		var vr := c.get_viewport_rect()
		var r := c.get_global_rect()
		if r.size.x > 2 and r.size.y > 2 and c.modulate.a > 0.05 and (r.end.y > vr.size.y + 2 or r.position.y < -2 or r.end.x > vr.size.x + 2 or r.position.x < -2):
			print("OVERFLOW ", c.get_path(), " ", r, " vp ", vr.size)
			return
	for ch in node.get_children():
		_overflow(ch)
