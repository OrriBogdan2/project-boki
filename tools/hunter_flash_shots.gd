extends RefCounted
## --hunter-flash-shots --shots-dir=<dir>: every Hunter (Arch.ids, its current model) in both team colours takes
## one hit at the match camera. <dir>/strip.png: per team a row before the hit and a row on the flash's full frame.
## Prints per Hunter how much the body brightens (mean luminance gain over the body's pixels) and what share of its
## room to white that is; fails when any Hunter's flash closes less than REL_MIN of that room, so a pale model's flash
## reads as clearly as a dark one's (a dark body has more room, so the raw gain alone would favour it).
## The impact sparks and numbers (Fx), the hit's shove and the idle motion are held off: this measures the body
## flash alone. Needs a renderer. Never touches the save.

const DT := 1.0 / 60.0
const HIT := 12.0  # damage of the test hit
const WARM := 20  # frames the model settles before the shots
const FULL_STEPS := 1  # steps after the hit to the flash's full frame (it holds full for 3)
const FADE_STEPS := 4  # steps after the hit to a fading frame
const REL_MIN := 0.5  # the least share of the body's room to white (1 - its luminance) the full flash closes
const BODY_DIFF := 0.08  # a pixel is the body's when the before frame differs this much from the empty frame
const CELL := Vector2i(150, 210)  # px of one Hunter in the strip

var bad := 0
var main: Node
var m: Match
var player: Hunter


func ok(cond: bool, what: String) -> void:
	print("HUNTERFLASH %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(root: Node) -> void:
	main = root
	Save.no_write = true
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 4242, "no_drop": true, "god": false})
	m.set_process(false)
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	player = m.player
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
	if m.hud:
		m.hud.visible = false
	m.fx.visible = false
	for h in m.hunters:
		h.visible = false
	var spot := player.pos + Vector3(0, 0, 5)
	var ids: Array = Arch.ids()
	var teams: Array = [player.team, 2 if player.team != 2 else 1]
	var strip := Image.create_empty(CELL.x * ids.size(), CELL.y * teams.size() * 2, false, Image.FORMAT_RGBA8)
	var gains: Array = []
	for ti in teams.size():
		for i in ids.size():
			var h := m.make_hunter(
				"HF%d_%d" % [ti, i],
				teams[ti],
				Arch.weight(ids[i]),
				String(ids[i]),
				"idle",
				{},
				spot,
				{"arch": ids[i], "weapon": "?"}
			)
			h.armor = 0.0  # (armour turns the flash cyan: a different case)
			h.face = PI
			var shots := await _shoot(h, spot)
			var g := _gain(shots[0], shots[1], shots[2])
			var gf := _gain(shots[0], shots[1], shots[3])
			var rel: float = g[0] / maxf(1.0 - g[1], 0.05)
			gains.append([rel, ids[i], teams[ti]])
			var row := [ids[i], teams[ti], g[1], g[0], rel, gf[0]]
			print("HUNTERFLASH %-12s team %d base %.2f gain %.2f rel %.2f fade %.2f" % row)
			for r in 2:
				var cell: Image = shots[1 + r]
				cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
				strip.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(i * CELL.x, (ti * 2 + r) * CELL.y))
			h.visible = false
	strip.save_png(dir.path_join("strip.png"))
	var worst: Array = gains.reduce(func(a, b): return a if a[0] <= b[0] else b)
	ok(
		worst[0] >= REL_MIN,
		(
			"every Hunter's flash closes >= %.2f of its room to white (least: %s team %d, %.2f)"
			% [REL_MIN, worst[1], worst[2], worst[0]]
		)
	)
	print("HUNTERFLASH DONE, failures: %d, strip %s" % [bad, dir.path_join("strip.png")])
	main.get_tree().quit(1 if bad > 0 else 0)


## [empty, before, full flash, fading flash]: crops of the frame around h at the match camera.
func _shoot(h: Hunter, spot: Vector3) -> Array:
	h.hp = 1e6
	m.cam.snap(spot)
	await _frames(h, WARM)
	var cam := main.get_viewport().get_camera_3d()
	var foot := cam.unproject_position(spot)
	var head := cam.unproject_position(spot + Vector3(0, 2.4, 0))
	var px := Vector2(absf(foot.y - head.y) * 1.3 * CELL.x / CELL.y, absf(foot.y - head.y) * 1.3)
	var mid := (foot + head) * 0.5
	var size := main.get_viewport().get_texture().get_image().get_size()
	var rg := Rect2i(Vector2i(mid - px * 0.5), Vector2i(px)).intersection(Rect2i(Vector2i.ZERO, size))
	Engine.time_scale = 0.0  # (the idle pose holds still, so the frames differ by the flash alone)
	h.visible = false
	await _frames(h, 2)
	var out: Array = [_grab(rg)]
	h.visible = true
	await _frames(h, 2)
	out.append(_grab(rg))
	h.inv_t = 0.0
	h.dropping = false
	h.hurt(HIT, player, {"src": "primary"})
	ok(h.flash_t > 0.0, "%s takes the hit (its flash runs)" % h.arch)
	h.flinch = Vector3.ZERO  # (nor the hit's shove)
	await _frames(h, FULL_STEPS)
	out.append(_grab(rg))
	await _frames(h, FADE_STEPS - FULL_STEPS)
	out.append(_grab(rg))
	Engine.time_scale = 1.0
	return out


func _frames(h: Hunter, n: int) -> void:
	for k in n:
		if h.flash_t > 0.0:
			h.flash_t -= DT
		h.render(DT, 1.0)
		await main.get_tree().process_frame


func _grab(rg: Rect2i) -> Image:
	var img := main.get_viewport().get_texture().get_image().get_region(rg)
	img.convert(Image.FORMAT_RGBA8)
	return img


## [mean luminance gain from before to after over the body's pixels, the body's mean luminance before].
func _gain(empty: Image, before: Image, after: Image) -> Array:
	var n := 0
	var gain := 0.0
	var base := 0.0
	for y in before.get_height():
		for x in before.get_width():
			var b := before.get_pixel(x, y)
			var e := empty.get_pixel(x, y)
			if maxf(absf(b.r - e.r), maxf(absf(b.g - e.g), absf(b.b - e.b))) < BODY_DIFF:
				continue
			n += 1
			base += b.get_luminance()
			gain += after.get_pixel(x, y).get_luminance() - b.get_luminance()
	return [gain / maxi(n, 1), base / maxi(n, 1)]
