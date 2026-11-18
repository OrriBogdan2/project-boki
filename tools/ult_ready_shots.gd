extends RefCounted
## --ult-ready-shots --shots-dir=<dir>: the ability row with the ultimate tile (HunterUltTile) in each state, on a
## real renderer (jobq --needs gpu): locked, cooling, the shine just after it comes back, steady ready, and
## blocked (stunned), then every hero's tile ready on one sheet. The --hudref-demo=plates scene, the match paused
## so each state holds still. Files are <dir>/ult_NN_<state>.png (crops of the row) and ult_heroes.png.
## Never touches the save.

const SHINE_AT := 0.18      # s into the shine for its picture (of HunterUltTile.SHINE_T)

var main: Node
var m: Match
var dir := "/tmp/ult_ready_shots"
var n := 0

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	m = Match.new()
	main.add_child(m)
	var opts := HudRefDemo.opts("--hudref-demo=plates")
	opts.merge({"tier": 0, "length": 1e9, "seed": 5, "arch": "thief", "cls": Arch.weight("thief"),
		"weapon": Arch.signature("thief")})
	m.start(opts)
	if main.fade:
		await main.fade.reveal(0.01)
	while m.time < 1.0:
		await main.get_tree().process_frame
	m.set_process(false)      # match time stops: the shine and the stun hold for the picture
	var P: Hunter = m.player
	P.lvl = 1
	await _shot("locked")
	P.lvl = int(Hunter.ULT_AT[0])
	P.ak.cd["x"] = 17.4
	await _shot("cooling")
	P.ak.cd["x"] = 0.0
	await _redraw()
	HunterUltTile.shine_from = m.time - SHINE_AT
	await _shot("shine")
	HunterUltTile.shine_from = -INF
	await _shot("ready")
	P.stun_t = 3.0
	await _shot("blocked")
	P.stun_t = 0.0
	var tiles: Array[Image] = []
	for id in Arch.ids():
		P.reclass(Arch.weight(id), id)
		await _redraw()
		tiles.append(_tile(await _grab()))
	_sheet(tiles).save_png(dir.path_join("ult_heroes.png"))
	print("ULTREADYSHOTS %d + heroes sheet (%d) in %s" % [n, tiles.size(), dir])
	main.get_tree().quit(0)

func _redraw() -> void:
	await m.hud.panels.draw
	await main.get_tree().process_frame

func _grab() -> Image:
	await _redraw()
	await RenderingServer.frame_post_draw
	return main.get_viewport().get_texture().get_image()

## Where the tile was drawn this frame (its hover spot) in the pixels of `img` (the HUD is laid out at the
## viewport's size and the window scales it), or an empty rect.
func _x_rect(img: Image) -> Rect2:
	var k := float(img.get_width()) / m.get_viewport().get_visible_rect().size.x
	for spot in m.hud.hover_spots:
		if String(spot[1]) == "x":
			var r: Rect2 = spot[0]
			return Rect2(r.position * k, r.size * k)
	return Rect2()

## The row from the right click to past the ultimate, with room for the tags over it and the key pills under it.
func _shot(what: String) -> void:
	var img := await _grab()
	var xr := _x_rect(img)
	var u := xr.size.x      # one slot, in screen pixels
	var crop := Rect2i(Rect2(xr.position - Vector2(u * 4.6, u * 0.7), Vector2(u * 6.8, u * 2.1)))
	n += 1
	img.get_region(crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))).save_png(
			dir.path_join("ult_%02d_%s.png" % [n, what]))

## Just the ultimate tile, with its halo and key pill.
func _tile(img: Image) -> Image:
	var xr := _x_rect(img)
	xr = xr.grow(xr.size.x * 0.28)
	xr.size.y += xr.size.x * 0.12
	return img.get_region(Rect2i(xr).intersection(Rect2i(Vector2i.ZERO, img.get_size())))

## The hero tiles side by side, in roster order (every hero has one, so `tiles` is never empty).
func _sheet(tiles: Array[Image]) -> Image:
	var w := 0
	var h := 0
	for t in tiles:
		w += t.get_width()
		h = maxi(h, t.get_height())
	var out := Image.create(maxi(1, w), maxi(1, h), false, tiles[0].get_format())
	var x := 0
	for t in tiles:
		out.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i(x, 0))
		x += t.get_width()
	return out
