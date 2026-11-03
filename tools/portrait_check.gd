extends RefCounted
## --portrait-check: every hero's portrait renders, is kept, and is framed alike. For each archetype
## (Arch.ORDER, as you'd play it): the portrait bakes within a few frames, the hunter covers a sane
## share of it (not empty, not a wall of coat), the face's centre (projected from the model's own head)
## lands inside Portraits.FACE_BOUNDS, the head's height is in Portraits.HEAD_RANGE, and asking again
## hands back the same cached texture. Needs a renderer: run it under xvfb-run, not --headless.
## With --portrait-shots=<dir> it also saves a contact sheet of all twelve, their states, and the
## hero picker with a kit card (screenshots for review).

const COVER := Vector2(0.15, 0.85)     # share of the frame the hunter may cover
const WAIT_FRAMES := 30

var main: Node
var fails := 0
var n := 0

func ok(what: String, cond: bool, info := "") -> void:
	n += 1
	printerr("PORTRAIT %-48s %s  %s" % [what, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1

func run(main_node: Node) -> void:
	main = main_node
	ok("a renderer is up (run under xvfb-run, not --headless)", Portraits.available())
	if Portraits.available():
		for ak in Arch.ORDER:
			await _check(String(ak))
		var dir := _shots_dir()
		if dir != "":
			await _shots(dir)
	print("PORTRAIT DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit(1 if fails > 0 else 0)

func _check(ak: String) -> void:
	var s := Portraits.spec_for(ak)
	var tree := main.get_tree()
	var tex := Portraits.texture(s, tree, Vector2i(112, 132))
	for i in WAIT_FRAMES:
		if Portraits.is_baked(s):
			break
		await tree.process_frame
	tex = Portraits.texture(s, tree, Vector2i(112, 132))
	var st := Portraits.stats_of(s)
	ok("%s: baked and cached" % ak, tex != null and tex == Portraits.texture(s, tree, Vector2i(112, 132)))
	if st.is_empty():
		return
	var cover: float = st["cover"]
	var face: Vector2 = st["face"]
	var head: float = st["head"]
	ok("%s: not empty" % ak, cover > COVER.x and cover < COVER.y, "covers %.2f" % cover)
	var face_ok := Portraits.FACE_BOUNDS.has_point(face)
	ok("%s: face inside the framing bounds" % ak, face_ok, "face at %.2f, %.2f" % [face.x, face.y])
	ok("%s: the face spot is on the model" % ak, float(st["solid"]) > 0.5, "alpha %.2f" % float(st["solid"]))
	var head_ok := head > Portraits.HEAD_RANGE.x and head < Portraits.HEAD_RANGE.y
	ok("%s: head and shoulders" % ak, head_ok, "head %.2f" % head)

func _shots_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--portrait-shots="):
			return a.substr(17)
	return ""

## The contact sheet (all twelve at the HUD's size, then one in every state at the HUD and squad sizes),
## then the hero picker's grid with a kit card.
func _shots(dir: String) -> void:
	var tree := main.get_tree()
	for ch in tree.root.find_children("*", "CanvasLayer", true, false):
		(ch as CanvasLayer).visible = false      # (the title and its splash stay out of the picture)
	var layer := CanvasLayer.new()
	layer.layer = 128
	tree.root.add_child(layer)
	var sheet := Sheet.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sheet)
	await _settle(tree)
	tree.root.get_texture().get_image().save_png(dir.path_join("contact_sheet.png"))
	sheet.queue_free()
	var bg := ColorRect.new()
	bg.color = UI.SURFACE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := HBoxContainer.new()
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 16)
	layer.add_child(box)
	HeroGrid.build(box, func(_ak: String): pass, func(_ak: String): pass, func(_ak: String): pass)
	box.add_child(KitCard.make("rimewright"))
	await _settle(tree)
	tree.root.get_texture().get_image().save_png(dir.path_join("hero_picker_kit_card.png"))

func _settle(tree: SceneTree) -> void:
	for i in 40:
		await tree.process_frame

## All twelve portraits as the HUD draws them, then a row of states.
class Sheet extends Control:
	const CELL := Vector2(112, 132)
	const STATES := [["alive", "", 0.0, 0.0], ["hit", "", 1.0, 0.0], ["low", "", 0.0, 1.0],
		["downed", "down", 0.0, 0.0], ["dead", "dead", 0.0, 0.0], ["out", "out", 0.0, 0.0]]

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.11))
		for i in Arch.ORDER.size():
			var ak: String = Arch.ORDER[i]
			var at := Vector2(24 + (i % 6) * (CELL.x + 40), 24 + (i / 6) * (CELL.y + 44))
			Portraits.draw(self, Rect2(at, CELL), Portraits.spec_for(ak), Arch.color(ak))
			HudStyle.text(self, at + Vector2(0, CELL.y + 22), Arch.name_of(ak).to_upper(), 14, Arch.color(ak))
		var s := Portraits.spec_for("gunslinger")
		for i in STATES.size():
			var row: Array = STATES[i]
			var at := Vector2(24 + i * (CELL.x + 40), 24 + 2 * (CELL.y + 44))
			Portraits.draw(self, Rect2(at, CELL), s, HudStyle.SELF, row[1], row[2], row[3], 0.2)
			var small := Rect2(at + Vector2(0, CELL.y + 34), Vector2(48, 48))
			Portraits.draw(self, small, s, HudStyle.ALLY, row[1], row[2], row[3], 0.2)
			HudStyle.text(self, at + Vector2(58, CELL.y + 66), String(row[0]).to_upper(), 13, HudStyle.INK)
