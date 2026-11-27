class_name MapCover
extends RefCounted
## The drop-planning map covers the whole screen (FullMap.draw: a 0.92 shade, the painted map on top), while the ride
## camera behind it sees every island at once: 34k objects a frame, 2.4k draws, the costliest view of the match.
## While it covers the screen the 3D world is not drawn (like under the loading screen, Main.show_screen); the
## last frame of the world stays where the world was, as a still under every canvas layer, so the HUD and the
## shade draw over it as they drew over the world. Closing the map or the ship setting off draws the 3D again.
## (docs/MATCH_PERF.md, the 11-27 load-in pass)

const LAYER := -128  # under every other canvas layer: where the 3D world draws

var _host: Node  # the match the still hangs under
var _layer: CanvasLayer


## The planning map has opened over `host` (the match). The still is copied off the GPU without waiting for it (a
## plain read waits for every frame in flight), so the world draws on until it arrives, a frame or two.
func cover(host: Node) -> void:
	if _host != null:
		return
	_host = host
	var vp := host.get_viewport()
	var rd := RenderingServer.get_rendering_device()
	if DisplayServer.get_name() == "headless":
		vp.disable_3d = true
	elif rd == null:  # (Compatibility: no RenderingDevice; its read is a plain GL read)
		_hide(vp.get_texture().get_image())
	else:
		var tex := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid())
		var f := rd.texture_get_format(tex) if tex.is_valid() else null
		var rgba8 := [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]
		if f == null or not f.format in rgba8:
			_hide(null)
			return
		var w := f.width
		var h := f.height
		var asked := host
		rd.texture_get_data_async(
			tex,
			0,
			func(data: PackedByteArray) -> void:
				if _host == asked:
					var ok := data.size() == w * h * 4
					_hide(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data) if ok else null)
		)


## The map has closed (or the ship has set off under a map opened by hand): the world draws again.
func uncover() -> void:
	if _host == null:
		return
	if is_instance_valid(_host) and _host.is_inside_tree():
		_host.get_viewport().disable_3d = false
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_host = null


## The still where the world was, and the 3D off.
func _hide(img: Image) -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	if img != null and not img.is_empty():
		_layer = CanvasLayer.new()
		_layer.layer = LAYER
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.add_child(tr)
		_host.add_child(_layer)
	_host.get_viewport().disable_3d = true
