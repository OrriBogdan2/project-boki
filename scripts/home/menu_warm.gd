class_name MenuWarm
extends RefCounted
## The first menu of a session paid for its first draws on a GPU: the first Masks screen took a 190-200 ms frame
## for its panel (the fonts at the menu sizes, the panel's canvas shaders) and another as its turntable's 3D
## preview first drew (its pipelines). draw() shows a stand-in of both behind the farm's ink wipe until the
## preview has drawn, then frees it, so the first real menu draws from warm caches. Once a session.

const SIZES := [UI.T_CAPS, UI.T_SMALL, UI.T_BODY, UI.T_HEAD, UI.T_TITLE]
const SAMPLE := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 .,:;!?'\"()+-/%·"
const MAX_FRAMES := 30      # frames the stand-in waits for its model (its .glb may still be reading)

static var _done := false

## Draws the stand-in under `host` (behind a cover) and frees it once its preview has drawn.
static func draw(host: Control) -> void:
	if _done:
		return
	_done = true
	var pb := UI.scroll_panel(HomeClasses.TITLE, 520.0, func() -> void: pass)
	var box: VBoxContainer = pb[1]
	for font in [UI.big, UI.body, UI.semi, UI.caps]:
		for px in SIZES:
			box.add_child(UI.label(SAMPLE, px, UI.INK, font))
	var viewer := HunterViewer.make(Arch.of_save(), HomeClasses.STAGE, HomeClasses.CLIP, 3)
	box.add_child(viewer)
	host.add_child(pb[0])
	var tree := host.get_tree()
	for i in MAX_FRAMES:
		await tree.process_frame
		if viewer.model != null:
			break
	await tree.process_frame      # (the frame that draws the model)
	pb[0].queue_free()
