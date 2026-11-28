extends RefCounted
## --clip-shots --states helpers for `hunter-proof` (live vs candidate hunter proofs; see the tool's header):
## --fig-h=<m>: the three cameras sized to the figure (it fills FILL of the panel), FIGURE_FRAC <view> <share> printed
## from the idle frame's pixels; --measure: print FIGURE_H <m> (the figure's height counted in pixels) and quit;
## --all-clips: every clip the Hunter plays (not only the six states), <dir>/clip_<name>/f###.png at the film's fps.
## Needs a renderer (a headless run draws nothing).

const FILL := 0.6  # share of the panel's height the figure fills (hunter-proof refuses under 0.4)
const EYE_DIST := 5.6  # m from the figure to the eye and knee cameras
const GAME_CAM := Vector3(0.0, 21.0, 9.4)  # the match camera (clip_shots STATE_VIEWS)
const FOOT := 0.9  # m of depth the match camera sees on top of the height (arms, weapon)
const MAX_CLIP_S := 6.0  # s a long clip is filmed for
const DIFF := 0.08  # luminance a pixel must differ from the empty stage to count as the figure
const STATES := ["idle", "walk", "run", "jump", "attack", "crouch"]

var shots: RefCounted  # the clip_shots run (its _grab, tree, frame_px)


func _init(run: RefCounted) -> void:
	shots = run


static func arg_float(prefix: String, fallback: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return fallback


## [fov, camera, looks at] for a view that frames a figure `h` m tall at FILL of the panel.
static func view(v: String, h: float) -> Array:
	if v == "match":
		var pitch := atan(GAME_CAM.y / GAME_CAM.z)
		var vis := (h * cos(pitch) + FOOT * sin(pitch)) / FILL
		return [rad_to_deg(2.0 * atan(vis * 0.5 / GAME_CAM.length())), GAME_CAM, Vector3(0.0, h * 0.5, 0.0)]
	var y := 1.6 if v == "eye" else 0.45
	return [rad_to_deg(2.0 * atan(h / FILL * 0.5 / EYE_DIST)), Vector3(0.0, y, EYE_DIST), Vector3(0.0, h * 0.5, 0.0)]


func poser(model: Node3D) -> Node:
	var p := model.get_node_or_null("Warden/Native")
	return p if p else model.get_node("Warden/Sync")


## The Hunter standing (idle state), a few frames in.
func pose_idle(model: Node3D, fps: float) -> void:
	var p := poser(model)
	p.set_process(false)
	for k in 6:
		model.set_meta(WardenClips.STATE, {"grounded": true, "face": model.rotation.y, "cast": 99.0})
		p.call("_process", 1.0 / fps)


## Pixel rows the figure covers: the stage with the Hunter vs without. 0 when nothing differs.
func figure_rows(model: Node3D) -> int:
	var ring := model.get_node_or_null("TeamRing") as Node3D
	var ring_was := ring != null and ring.visible
	if ring:
		ring.visible = false
	model.visible = false
	var empty := await _shot()
	model.visible = true
	var full := await _shot()
	if ring:
		ring.visible = ring_was
	var top := -1
	var bottom := -1
	for y in range(0, full.get_height(), 2):
		for x in range(0, full.get_width(), 2):
			if absf(full.get_pixel(x, y).get_luminance() - empty.get_pixel(x, y).get_luminance()) > DIFF:
				if top < 0:
					top = y
				bottom = y
				break
	return 0 if top < 0 else bottom - top + 2


## --measure: FIGURE_H <m> from the eye camera's pixels (the frame holds 2 * dist * tan(fov / 2) m at the figure).
func measure(model: Node3D, cam: Camera3D, fps: float) -> void:
	cam.fov = 30.0
	cam.position = Vector3(0.0, 0.95, EYE_DIST)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	pose_idle(model, fps)
	var rows := await figure_rows(model)
	var frame_m := 2.0 * EYE_DIST * tan(deg_to_rad(cam.fov * 0.5))
	print("FIGURE_H %.3f" % (float(rows) / shots.frame_px * frame_m))


## FIGURE_FRAC <view> <the figure's share of the panel's height> for the camera as set.
func report_fraction(model: Node3D, view_name: String, fps: float) -> void:
	pose_idle(model, fps)
	var rows := await figure_rows(model)
	print("FIGURE_FRAC %s %.3f" % [view_name, float(rows) / shots.frame_px])


## Every clip the Hunter plays beyond the six states and the kit moves (those are filmed by --states).
func all_clips(model: Node3D, fps: float, dir: String) -> void:
	var p := poser(model)
	p.set_process(false)
	if p is WardenNative:
		await _native_clips(p as WardenNative, fps, dir)
		return
	var clips := p.get("clips") as WardenClips
	for nm in clips.lib.get_animation_list():
		var length := minf(clips.lib.get_animation(nm).length, MAX_CLIP_S)
		clips.force = {"clip": nm, "t": 0.0}
		for k in 8:
			p.call("_process", 1.0 / 30.0)
		var sub := dir.path_join("clip_%s" % nm)
		DirAccess.make_dir_recursive_absolute(sub)
		for i in int(ceil(length * fps)) + 1:
			clips.force = {"clip": nm, "t": minf(i / fps, length - 0.001)}
			p.call("_process", 1.0 / fps)
			await shots.call("_grab", sub.path_join("f%03d.png" % i))
	clips.force = {}


func _native_clips(native: WardenNative, fps: float, dir: String) -> void:
	var skip := []
	for st in STATES:
		skip.append(String(native.plays.get(st, "")))
	for km in native.moves.clips():
		skip.append(String(native.plays[km]))
	var seen := []
	for key in native.plays:
		var nm := String(native.plays[key])
		if nm in skip or nm in seen or not native.player.has_animation(nm):
			continue
		seen.append(nm)
		var length := minf(native.player.get_animation(nm).length, MAX_CLIP_S)
		var sub := dir.path_join("clip_%s" % nm)
		DirAccess.make_dir_recursive_absolute(sub)
		native.player.play(nm, 0.0)
		native.player.pause()
		for i in int(ceil(length * fps)) + 1:
			native.player.seek(minf(i / fps, length - 0.001), true)
			await shots.call("_grab", sub.path_join("f%03d.png" % i))


func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return shots.tree.root.get_texture().get_image()
