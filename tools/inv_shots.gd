extends RefCounted
## --inv-shots --shots-dir=<dir>: the in-match inventory at whatever resolution the window has (run
## under xvfb with a renderer, --resolution WxH). inv_pack: the backpack window with a full loadout;
## inv_loot: a deathbox with gear beside it; inv_tip: the compare tooltip on a hovered backpack piece
## (only when the window is a LoadoutPanel). --shots-size=WxH resizes the window first. Files carry the height.
## --inv-drag instead saves <dir>/drag/NNNNN.jpg, a frame each, of the press-and-hold drags (SlotDrag) played
## with real input: armor onto its slot, a glove refused by the armor slot, the gloves swapped, then the pad
## swapping two belt slots. Encode: ffmpeg -framerate 30 -i <dir>/drag/%05d.jpg -pix_fmt yuv420p drag.mp4

const REEL_W := 960              # px wide, each --inv-drag frame

var main: Node
var captions: Array = []
var dir := "/tmp/inv_shots"
var reel := 0                    # --inv-drag: frames saved so far
var pointer: Label               # --inv-drag: the drawn pointer (the OS cursor is not in the frame)

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--shots-size="):
			var wh := String(a).substr(13).split("x")
			main.get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(dir)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	if main.fade:
		await main.fade.reveal(0.01)
	var p: Hunter = m.player
	var q: Hunter = m.hunters.filter(func(x): return x != p)[0]
	dress(p)
	m.hud.toggle_pack()
	await _frames(8)
	if OS.get_cmdline_user_args().has("--inv-drag"):
		await _drag_reel(m)
		print("INVSHOTS drag reel: %d frames in %s" % [reel, dir.path_join("drag")])
		main.get_tree().quit(0)
		return
	var tag := "%dp" % int(main.get_viewport().get_visible_rect().size.y)
	await _shot("inv_pack_" + tag, "Backpack window with a full loadout")
	var found: Array = m.hud.pack_panel.find_children("*", "LoadoutPanel", true, false)
	if not found.is_empty():
		found[0].call("hover_demo", "pack", 0)
		await _frames(8)
		await _shot("inv_tip_" + tag, "Compare tooltip on a backpack piece: only the changed numbers")
	m.hud.toggle_pack()
	var bx: Dictionary = load("res://tools/loot_full_check.gd").make_box(q, p.pos + Vector3(1.0, 0, 0), [])
	bx["gear"] = [{"id": "vest", "rar": 3}, {"id": "skylark_boots", "rar": 2}]
	bx["pack"] = [Loot.valuable("old_coin")]
	bx["gems"] = 14
	m.boxes.append(bx)
	m.hud.open_loot(bx)
	await _frames(10)
	await _shot("inv_loot_" + tag, "A deathbox with your loadout beside it")
	var f := FileAccess.open(dir.path_join("captions.txt"), FileAccess.WRITE)
	for c in captions:
		f.store_line(c)
	f.close()
	print("INVSHOTS %d in %s" % [captions.size(), dir])
	main.get_tree().quit(0)

## A hunter in a full loadout: two gloves, armor, boots, belt items, a few perks and a half-full pack.
static func dress(p: Hunter) -> void:
	p.gear = [{"id": "power_core", "rar": 2}, {"id": "frost", "rar": 1}, {"id": "quilted_coat", "rar": 1},
		{"id": "boots", "rar": 1}]
	p.perks = ["keen", "keen", "toughskin", "fleet"]
	UtilityBelt.grant(p, "medkit", 2)
	UtilityBelt.grant(p, "smoke", 1)
	p.refresh_gear()
	p.pack_cap = 6
	p.pack = [Loot.gear("vest", 3), Loot.gear("blink", 2), Loot.gear("windstep_boots", 1), Loot.valuable("kin_idol"),
		Loot.valuable("sky_pearl")]

func _frames(k: int) -> void:
	for i in k:
		await main.get_tree().process_frame

func _shot(file: String, caption: String) -> void:
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))
	captions.append("%s.png: %s" % [file, caption])

# ------------------------------------------------------------------ --inv-drag
func _drag_reel(m: Match) -> void:
	DirAccess.make_dir_recursive_absolute(dir.path_join("drag"))
	var layer := CanvasLayer.new()
	layer.layer = 120
	main.add_child(layer)
	pointer = UI.label("➤", 26, UI.INK, UI.big)
	pointer.rotation = -2.0
	layer.add_child(pointer)
	var lp := _panel(m)
	pointer.position = _at(lp, "pack", 0) + Vector2(-60, 40)
	await _hold(12)
	await _mouse_drag(_at(lp, "pack", 0), _at(lp, "worn", 2))
	lp = _panel(m)
	await _hold(12)
	await _mouse_drag(_at(lp, "pack", 1), _at(lp, "worn", 2))
	await _hold(40)
	await _mouse_drag(_at(lp, "worn", 0), _at(lp, "worn", 1))
	lp = _panel(m)
	await _hold(12)
	pointer.visible = false
	var belt := _slot(lp, "belt", 0)
	belt.grab_focus()
	await _hold(15)
	_push_pad(true)
	await _hold(20)
	_slot(lp, "belt", 2).grab_focus()
	await _hold(14)
	_push_pad(false)
	await _hold(24)

func _panel(m: Match) -> LoadoutPanel:
	return m.hud.pack_panel.find_children("*", "LoadoutPanel", true, false)[0]

func _slot(lp: LoadoutPanel, inv: String, i: int) -> Control:
	for c in lp._drag._slots:
		var key: Dictionary = lp._drag._slots[c]["key"]
		if is_instance_valid(c) and key["inv"] == inv and int(key["i"]) == i:
			return c
	return null

func _at(lp: LoadoutPanel, inv: String, i: int) -> Vector2:
	return SlotDrag._rect(_slot(lp, inv, i)).get_center()

## Press, move over 20 frames, let go: the pointer drawn the whole way.
func _mouse_drag(a: Vector2, b: Vector2) -> void:
	for k in 8:
		pointer.position = pointer.position.lerp(a, 0.4)
		await _hold(1)
	_push_mouse(true, a)
	await _hold(6)
	for k in 20:
		var at := a.lerp(b, (k + 1) / 20.0)
		pointer.position = at
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		main.get_viewport().push_input(mv, true)
		await _hold(1)
	_push_mouse(false, b)
	await _hold(10)

func _push_mouse(down: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	main.get_viewport().push_input(ev, true)

func _push_pad(down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = down
	main.get_viewport().push_input(ev, true)

## Saves k frames of the reel.
func _hold(k: int) -> void:
	for i in k:
		await RenderingServer.frame_post_draw
		var img := main.get_viewport().get_texture().get_image()
		img.resize(REEL_W, int(img.get_height() * float(REEL_W) / img.get_width()))
		img.save_jpg(dir.path_join("drag/%05d.jpg" % reel), 0.85)
		reel += 1
