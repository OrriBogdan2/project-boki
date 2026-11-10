class_name AimFrame
extends RefCounted
## The local player's mouse aim (point, ray, height), read twice a frame so what is drawn comes from the
## same frame as the reticle: `read` at the start of the frame feeds the fixed steps (the camera as last
## drawn), `refresh` after the camera has moved re-reads it for everything drawn this frame (aim lines,
## AimKit cursor states) with the camera that is about to be drawn. The cursor confinement and every
## max-range clamp stay with the shot code (AimMode); this only says where the cursor points.

static func read(m: Match) -> void:
	var inp: Dictionary = m.player.inp
	var aim := m._mouse_aim()
	inp["aim"] = aim
	inp["aim_mouse"] = aim      # (what `refresh` checks, so a demo or tool that set its own aim keeps it)
	inp["aim_ray"] = m.cam.mouse_ray()
	inp["aim_y"] = m.aim_y      # the height of whatever you're pointing at (shots climb or dip to it)

## After the camera moved this frame: the same read, unless something else set the aim since `read`.
static func refresh(m: Match) -> void:
	if m.player == null or m.player.out or m.opts.get("tut_test", false):
		return
	var inp: Dictionary = m.player.inp
	if inp.get("aim") == inp.get("aim_mouse"):
		read(m)
