class_name MapCover
extends RefCounted
## The drop-planning map covers the whole screen (FullMap.draw: a 0.92 shade, the painted map on top), while the ride
## camera behind it sees every island at once: 34k objects a frame, 2.4k draws, the costliest view of the match.
## While it covers the screen the 3D world is not drawn (like under the loading screen, Main.show_screen); the
## last frame the player saw stays under the shade as a still, so what shows through is unchanged.
## Closing the map or the ship setting off draws the 3D again. (docs/MATCH_PERF.md, the 11-27 load-in pass)

var still: ImageTexture  # the last frame before the map covered it
var _vp: Viewport


## The planning map has opened over the match. The still is copied off the GPU without waiting for it (a plain
## read waits for every frame in flight: a 0.5 s frame on a 4090 pod), so the world draws on until it arrives.
func cover(vp: Viewport) -> void:
	if _vp != null:
		return
	_vp = vp
	var rd := RenderingServer.get_rendering_device()
	if DisplayServer.get_name() == "headless":
		vp.disable_3d = true
	elif rd == null:  # (Compatibility: no RenderingDevice; its read is a plain GL read)
		_hide(vp.get_texture().get_image())
	else:
		var tex := RenderingServer.texture_get_rd_texture(vp.get_texture().get_rid())
		var f := rd.texture_get_format(tex)
		var rgba8 := [RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_SRGB]
		if not tex.is_valid() or f == null or not f.format in rgba8:
			_hide(null)
			return
		var w := f.width
		var h := f.height
		var asked := vp
		rd.texture_get_data_async(
			tex,
			0,
			func(data: PackedByteArray) -> void:
				if _vp == asked and data.size() == w * h * 4:
					_hide(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data))
				elif _vp == asked:
					_hide(null)
		)


## The still under the shade, and the 3D off.
func _hide(img: Image) -> void:
	still = ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null
	if _vp != null and is_instance_valid(_vp):
		_vp.disable_3d = true


## The map has closed (or the match goes): the world draws again.
func uncover() -> void:
	if _vp == null:
		return
	if is_instance_valid(_vp):
		_vp.disable_3d = false
	_vp = null
	still = null


## Under the shade: the still of the world, filling the screen. A map opened by hand stays open when the ship sets
## off: the world draws again then.
func draw(c: Control, sz: Vector2, planning: bool) -> void:
	if not planning:
		uncover()
	elif still != null:
		c.draw_texture_rect(still, Rect2(Vector2.ZERO, sz), false)
