class_name MenuWarm
extends RefCounted
## The first menu of a session paid for its first draws on a GPU: the first Relics screen took a 150-270 ms frame
## for its panel (the fonts at the menu sizes, the panel's canvas shaders) and more as its turntable and its clip
## first drew their 3D (their pipelines), the clip's effects worst (a 190-210 ms frame at its first hit). draw() shows
## a stand-in of both behind the farm's ink wipe until its models have drawn and its clip has run through its effects,
## then frees it, so the first real menu draws from warm caches. Once a session.

const SIZES := [11, UI.T_CAPS, UI.T_SMALL, 14, UI.T_BODY, UI.T_HEAD, UI.T_TITLE]      # px: the sizes menus draw
const SAMPLE := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 .,:;!?'\"()+-/%·"
const MAX_FRAMES := 45      # frames the stand-in waits for its models (built on a worker, the .glb read first)
const FX_STEP := 0.04       # s the clip is stepped on a frame, on top of the frame's own: under its shortest flash
const FX_FRAMES := 30       # frames that runs: past the clip's last hit (AbilityClip.ACT_AT + 1.35 s)

static var _done := false

## Draws the stand-in under `host` (behind a cover) and frees it once its models and its clip's effects have drawn.
static func draw(host: Control) -> void:
	if _done:
		return
	_done = true
	var pb := UI.scroll_panel(HomeClasses.TITLE, 520.0, func() -> void: pass)
	var box: VBoxContainer = pb[1]
	var viewer := HunterViewer.make(Arch.of_save(), HomeClasses.STAGE, HomeClasses.CLIP, 3)
	box.add_child(viewer)      # (first, on screen: a SubViewport off it never renders, so it would warm nothing)
	for font in [UI.big, UI.body, UI.semi, UI.caps]:
		for px in SIZES:
			box.add_child(UI.label(SAMPLE, px, UI.INK, font))
	host.add_child(pb[0])
	var tree := host.get_tree()
	for i in MAX_FRAMES:
		await tree.process_frame
		if _built(viewer):
			break
	var clip := _clip(viewer)
	for i in FX_FRAMES:
		if clip:
			clip.tick(FX_STEP)
		await tree.process_frame
	pb[0].queue_free()

## Whether the turntable and the clip in focus have their models.
static func _built(viewer: HunterViewer) -> bool:
	var clip := _clip(viewer)
	return viewer.model != null and (clip == null or clip.model != null)

## The clip in focus, null when the ability in focus has none.
static func _clip(viewer: HunterViewer) -> AbilityClip:
	return viewer.rows[viewer.slot_i] as AbilityClip if viewer.slot_i < viewer.rows.size() else null
