class_name PreviewWarm
extends RefCounted
## Pays a Relic preview's one-time costs while a screen loads under the ink wipe, so the first preview a player
## opens does not hitch. A Hunter's first preview of a session is slow because its procedural meshes are made
## the first time one of each kind is asked for (Models, HeroKit and HeroGear keep them by kind), and the first
## Relics screen also pays for its fonts' glyphs, its styles and its preview's shaders. So under the wipe:
##   models(host, ids)          builds each Hunter's preview once and frees it; a frame is let through between
##                              them (PerfLog's slices), so the wipe's spinner keeps turning
##   rehearse(host, key, make)  builds a screen under everything else, lets it lay out, build its preview and
##                              draw for a few frames, then frees it
## The farm warms every Hunter and its Relics screen (`farm`, from Home's sliced build); the hatch island warms
## the three starters and their pick (`starters`, a new player's first pick). Each is paid once a session.

const BUDGET_MS := 1500.0        # ms one load may spend on models; the Hunters left wait for the next load
const REHEARSE_FRAMES := 8       # frames a rehearsed screen stays up: its layout, its previews' builds, a draw
const UNDER_LAYER := -8          # canvas layer of a rehearsed screen: under every real one
const RELICS := "relics"         # rehearsal keys
const STARTERS := "starters"

static var warm := {}            # Hunter id -> true: its preview model has been built once this session
static var rehearsed := {}       # screen key -> true: that screen has been built and drawn once
static var last_ms := 0.0        # ms the last models() took, its waits for frames and files included

## Stands in for the farm while its Relics screen is rehearsed: HomeClasses.open asks its host for a panel and
## keeps its notes in the host's metas, so the real farm's panel, sounds and notes are left alone.
class Stage extends Control:
	func _new_panel(title_txt: String, width := 520.0, scroll := false) -> VBoxContainer:
		var made := UI.scroll_panel(title_txt, width, func(): pass, "Close", scroll)
		add_child(made[0])
		return made[1]

## True while the loading wipe hides the window: the only time warming costs the player nothing.
static func hidden() -> bool:
	return Game.main != null and Game.main.fade != null and Game.main.fade.covered

## The farm's load: every Hunter's preview model (the one you wear first, then in the Relics screen's order)
## and the Relics screen itself.
static func farm(home: Node) -> void:
	var ids: Array = [Arch.of_save()]
	ids.append_array(HomeClasses.ordered())
	await models(home, ids)
	await rehearse(home, RELICS, func(stage: Control): HomeClasses.open(stage, Arch.of_save()))

## The hatch island's load, for a player with no Relic yet: the three starters' models and their pick.
static func starters(host: Node) -> void:
	var ids := ClassUnlock.starters()
	await models(host, ids)
	var offer := HobOffer.new(ids, FarmBuilder.rules()["talk"], "starter_title", func(_id): return false,
			func(_id): pass)
	await rehearse(host, STARTERS, func(_stage: Control): return offer.build())

## Builds each of these Hunters' preview models once and frees it, so every mesh a preview of theirs needs is
## made and their .glb files are read (off the main thread where the renderer allows). Stops when `host` leaves
## the tree or the load has spent BUDGET_MS; a Hunter already warm costs nothing.
static func models(host: Node, ids: Array) -> void:
	var start_us := Time.get_ticks_usec()
	for id in ids:
		WardenGlb.fetch(String(id))
	for raw in ids:
		var id := String(raw)
		if warm.has(id) or not Arch.exists(id):
			continue
		if (Time.get_ticks_usec() - start_us) / 1000.0 > BUDGET_MS:
			break
		while not WardenGlb.fetched(id):
			if not await _frame(host):
				return
		if not WardenGlb.has_rest(id):
			WardenGlb.neutral_rest(id)
		PreviewBuild.model(id).queue_free()
		warm[id] = true
		if PerfLog.slice_due() and not await _frame(host):
			return
	last_ms = (Time.get_ticks_usec() - start_us) / 1000.0

## Builds a screen once where nobody sees it: `make` gets a Stage to build on (or returns a Control to put on
## it). After REHEARSE_FRAMES the screen is freed and the keyboard focus goes back to whoever had it.
static func rehearse(host: Node, key: String, make: Callable) -> void:
	if rehearsed.has(key) or not is_instance_valid(host) or not host.is_inside_tree():
		return
	rehearsed[key] = true
	var layer := CanvasLayer.new()
	layer.layer = UNDER_LAYER
	var stage := Stage.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(stage)
	host.add_child(layer)
	var focused := host.get_viewport().gui_get_focus_owner()
	var made = make.call(stage)
	if made is Control and (made as Control).get_parent() == null:
		stage.add_child(made)
	for i in REHEARSE_FRAMES:
		if not await _frame(host):
			return
	layer.queue_free()
	if is_instance_valid(focused) and focused.is_inside_tree():
		focused.grab_focus()

## Lets one frame through (kept off the running load step's time); false once `host` has left the tree.
static func _frame(host: Node) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	PerfLog.wait_begin()
	await host.get_tree().process_frame
	PerfLog.wait_end()
	return is_instance_valid(host) and host.is_inside_tree()
