extends SceneTree
# Rasterize SVGs: godot --headless --script svg_render.gd -- in.svg out.png [scale]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i + 1 < a.size():
		var sc := 1.0
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(a[i]), sc)
		if err != OK:
			push_error("svg fail " + a[i])
		else:
			img.save_png(a[i + 1])
		i += 2
	quit()
