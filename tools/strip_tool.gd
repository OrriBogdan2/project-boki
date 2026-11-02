extends SceneTree
## Tooling: joins screenshots into one frame strip. godot --headless -s tools/strip_tool.gd -- <out.png> <crop> <in1.png> <in2.png> ...
## Each frame is cropped to a <crop> px square around the screen centre (where the hunter stands) and laid out left to right.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out := String(a[0]); var crop := int(a[1])
	var frames: Array = []
	for i in range(2, a.size()):
		var img := Image.load_from_file(String(a[i]))
		if img == null or img.is_empty(): continue
		var c := Vector2i(img.get_width() / 2, img.get_height() / 2 + 20)
		frames.append(img.get_region(Rect2i(c.x - crop / 2, c.y - crop / 2, crop, crop)))
	var sheet := Image.create(crop * frames.size(), crop, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, crop, crop), Vector2i(i * crop, 0))
	sheet.save_png(out)
	print("STRIP ", out, " x", frames.size())
	quit()
