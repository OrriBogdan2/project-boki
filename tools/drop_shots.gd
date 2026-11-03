extends RefCounted
## --drop-shots --shots-dir=<dir>: screenshots of the opening drop (docs/decisions/0012) in a live
## match, run under xvfb with a renderer at 1280x720. The match runs on its own (its camera, DropFx);
## the keys are pressed through Input. <dir>/captions.txt gets "file: caption" per file.
##   drop_comet_sweep*.png   the squad's comet high over the Hollow Crown (recording mode, and with the HUD)
##   drop_dive_float.png     a solo diver floating, then diving (crops round the hunter), and the dive's full view
##   drop_clouds.png         punching through the cloud layer
##   drop_glider.png         the glider opening by itself near the ground, then the landing kick
##   drop_burst.png          a squad comet bursting near the ground and landing its squad, spread out

const CROP := Vector2i(220, 220)       # px round the hunter for a strip frame (scaled 1.4x)
const BURST_CROP := Vector2i(400, 300)  # px round the comet's ground point (a 3-frame strip at 1260 px)
const CAPTIONS := {
	"drop_comet_sweep.png":
		"Recording mode, 1.5 s off the ship: the squad's comet heading in over the Hollow Crown, its trail "
		+ "behind it, the islands spread out below through the cloud layer",
	"drop_comet_sweep2.png":
		"Recording mode, a moment later: the jumpmaster turned the comet (A held), the trail shows the sweep",
	"drop_comet_hud.png":
		"The same drop as the jumpmaster, with the HUD: 'Jumpmaster · 2 in your comet', Space to break away, "
		+ "P to pass the lead",
	"drop_burst.png":
		"The comet near the ground, bursting, and the squad landed together on their own spots (spread out, on solid "
		+ "ground)",
	"drop_dive_full.png":
		"Solo, diving (W held): speed lines and rising wind, the camera turned with your heading, the islands "
		+ "coming up",
	"drop_dive_float.png":
		"Close-ups (the camera pulled in): float, no keys: spread flat, belly down; dive, W: head down, arms swept "
		+ "back, legs together",
	"drop_clouds.png":
		"Diving into the cloud layer: the clouds part round you so you're never hidden; punching through "
		+ "flashes white with a whoosh",
	"drop_glider.png":
		"Floating down; the glider opens by itself 12 m over the ground; the landing kick (dust rings, squash); the "
		+ "Boki leaps off your back",
}

var main: Node
var m: Match
var P: Hunter
var dir := ""
var lines: Array = []

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var d := Save.fresh()
	var rec := Save.new_kin("zapple", "Pip")
	d["roster"].append(rec)
	d["active"] = rec["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "home": true, "day1_done": true}
	Save.d = d
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	Settings.v["tips"] = false
	await _squad()
	await _solo()
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for l in lines:
		f.store_line(l)
	f.close()
	print("DROPSHOTS %d in %s" % [lines.size(), dir])
	main.get_tree().quit(0)

func _start(opts: Dictionary) -> void:
	if m:
		m.queue_free()
		await main.get_tree().process_frame
	m = Match.new()
	main.add_child(m)
	await m.start(opts)
	P = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	main.get_viewport().warp_mouse(Vector2(1260, 160))      # (no hover tooltips over the hunter)

func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

## Waits (rendering) until `cond` holds, or `secs` of match time pass.
func _until(cond: Callable, secs := 60.0) -> void:
	var t0 := m.time
	var frames := 0
	while not cond.call() and m.time - t0 < secs and frames < secs * 240.0:
		frames += 1
		await main.get_tree().process_frame

func _shot(file: String) -> void:
	var img := main.get_viewport().get_texture().get_image()
	if img.get_width() > 1280:
		img.resize(1280, int(img.get_height() * 1280.0 / img.get_width()), Image.INTERPOLATE_BILINEAR)
	img.save_png(dir.path_join(file))
	lines.append("%s: %s" % [file, CAPTIONS[file]])

func _crop(at: Vector3, px: Vector2i, zoom: float) -> Image:
	var img := main.get_viewport().get_texture().get_image()
	var c := main.get_viewport().get_camera_3d().unproject_position(at)
	var corner := Vector2i(int(c.x) - px.x / 2, int(c.y) - px.y / 2)
	var rg := Rect2i(corner, px).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rg)
	crop.resize(int(px.x * zoom), int(px.y * zoom), Image.INTERPOLATE_BILINEAR)
	return crop

func _strip(file: String, frames: Array) -> void:
	var w := 0
	var hh := 0
	for fr in frames:
		w += (fr as Image).get_width() + 4
		hh = maxi(hh, (fr as Image).get_height())
	var out := Image.create(w - 4, hh, false, (frames[0] as Image).get_format())
	out.fill(Color(0.05, 0.05, 0.07))
	var x := 0
	for fr in frames:
		out.blit_rect(fr, Rect2i(Vector2i.ZERO, (fr as Image).get_size()), Vector2i(x, 0))
		x += (fr as Image).get_width() + 4
	if out.get_width() > 1280:
		out.resize(1280, int(out.get_height() * 1280.0 / out.get_width()), Image.INTERPOLATE_BILINEAR)
	out.save_png(dir.path_join(file))
	lines.append("%s: %s" % [file, CAPTIONS[file]])

func _press(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)

## A close-up round the hunter for a pose (the camera pulled in, no HUD), then the view as it was.
func _pose() -> Image:
	var level := Record.level
	Record.set_level(2)
	m.cam.dist_mul = 0.3
	await _frames(12)
	var img := _crop(P.position + Vector3(0, 0.7, 0), Vector2i(300, 300), 1.0)
	m.cam.dist_mul = 1.0
	Record.set_level(level)
	await _frames(6)
	return img

## Off the ship `before` m short of the middle of the map, heading for it.
func _jump_mid(before := 40.0) -> void:
	var mid := Vector3(m.world.w * 0.5, 0, m.world.h * 0.5)
	await _until(func(): return Vector2(m.ship_pos().x - mid.x, m.ship_pos().z - mid.z).length() < before, 40.0)
	m.ship_jump(P)

# ------------------------------------------------------------------ the squad comet
func _squad() -> void:
	await _start({"teams": 3, "squad": 3, "tier": 0, "seed": 4101, "no_plan": true, "raid": "clear"})
	Record.set_level(2)
	await _jump_mid(90.0)
	for f in m.skydrop.comet.riders(P.team):
		f.ai["break_y"] = -1.0
	await _until(func(): return P.pos.y < SkyFall.SKY_Y - 12.0)
	_shot("drop_comet_sweep.png")
	_press("left", true)
	await _until(func(): return P.pos.y < SkyFall.SKY_Y - 30.0)
	_press("left", false)
	_shot("drop_comet_sweep2.png")
	Record.set_level(0)
	await _until(func(): return P.pos.y < SkyFall.SKY_Y - 40.0)
	_shot("drop_comet_hud.png")
	# down to the burst (no HUD over the crops)
	var squad: Array = m.hunters.filter(func(x): return x.team == P.team)
	var frames: Array = []
	await _until(func(): return SkyFall.height_over(m.world, P.pos) < DropComet.BURST_H + 5.0, 30.0)
	Record.set_level(2)
	frames.append(_crop(P.position + Vector3(0, 0.9, 0), BURST_CROP, 1.05))
	await _until(func(): return not m.skydrop.comet.comets.has(P.team), 5.0)
	await _frames(5)
	frames.append(_crop(P.position + Vector3(0, 0.9, 0), BURST_CROP, 1.05))
	await _until(func(): return squad.all(func(x): return x.grounded), 5.0)
	await _frames(4)
	var mid := Vector3.ZERO
	for x in squad:
		mid += x.position / squad.size()
	frames.append(_crop(mid, BURST_CROP, 1.05))
	Record.set_level(0)
	_strip("drop_burst.png", frames)

# ------------------------------------------------------------------ a solo dive
func _solo() -> void:
	await _start({"teams": 2, "squad": 1, "tier": 0, "seed": 4103, "no_plan": true, "raid": "clear"})
	await _jump_mid()
	await _until(func(): return P.pos.y < SkyFall.SKY_Y - 12.0)
	var poses: Array = [await _pose()]
	_press("up", true)
	await _until(func(): return P.pos.y < DropFx.CLOUD_Y + 9.0, 10.0)
	_shot("drop_clouds.png")
	await _frames(4)
	poses.append(await _pose())
	_shot("drop_dive_full.png")
	_strip("drop_dive_float.png", poses)
	_press("up", false)
	var glide: Array = []
	Record.set_level(2)      # (no HUD over the crops)
	await _until(func(): return SkyFall.height_over(m.world, P.pos) < SkyFall.DEPLOY_H + 3.0 or not P.dropping, 20.0)
	glide.append(_crop(P.position + Vector3(0, 0.9, 0), CROP, 1.4))
	await _until(func(): return not P.dropping, 3.0)
	await _frames(4)
	glide.append(_crop(P.position + Vector3(0, 0.9, 0), CROP, 1.4))
	await _until(func(): return P.grounded, 15.0)
	await _frames(2)
	glide.append(_crop(P.position + Vector3(0, 0.9, 0), CROP, 1.4))
	await _frames(20)
	glide.append(_crop(P.position + Vector3(0, 0.9, 0), CROP, 1.4))
	Record.set_level(0)
	_strip("drop_glider.png", glide)
