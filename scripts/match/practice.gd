class_name Practice
extends Node
## What every practice area shares (the Training Area, the tutorial and the Duel room;
## never a real match): a bottom bar like the farm's hub (Hero, the area's own menu, Leave), J for
## the hero picker (PracticeHero), and the mouse wheel zooming the camera. One node under the Match,
## attached by Match.start with a single call.

const NAME := "Practice"
const LEFT_PAD := 560          # px, the bar starts right of the HUD's portrait and ability row
const BOTTOM_PAD := 8          # px, under the bar
const ZOOM_STEP := 0.08        # per wheel notch (the farm's step)
const ZOOM_MIN := 0.55         # closest (the farm's range)
const ZOOM_MAX := 1.6          # furthest

var m: Match
var bar: PanelContainer = null
var bar_btns := {}             # id -> Button
var picker: CanvasLayer = null # the hero picker, while open
var picker_page := ""          # "heroes" | "kit"
var hover_arch := ""           # the card under the mouse (K opens its kit)
var _layer: CanvasLayer = null

static func is_practice(opts: Dictionary) -> bool:
	return opts.get("training", false) or opts.get("tutorial", false) or opts.get("arena", false) or opts.get("duel", false)

static func of(match_node: Match) -> Practice:
	return match_node.get_node_or_null(NAME) as Practice

## Adds the practice kit to a practice-area Match (does nothing in a real match).
static func attach(match_node: Match) -> Practice:
	if not is_practice(match_node.opts) or match_node.player == null:
		return null
	var p := Practice.new()
	p.name = NAME
	p.process_mode = Node.PROCESS_MODE_ALWAYS      # J and Esc work while a menu has the game paused
	p.m = match_node
	match_node.add_child(p)
	p._build_bar()
	return p

## The bar's entries: [id, label, icon, open, key cap]. The Arena and the training area share a loadout
## menu (L), the Duel room has its setup menu (B).
func items() -> Array:
	var out: Array = [["hero", "Relics", "swap", func(): PracticeHero.toggle(self), Settings.key_cap("hero")]]
	if m.arena:
		out.append(["menu", "Loadout", "bag", func(): if not m.paused: m.arena.open_menu(), "L"])
	elif m.duel:
		out.append(["menu", "Duel", "gear", func(): if not m.paused: m.duel.open_menu(), "B"])
	out.append(["leave", "Leave", "back", func(): leave(m, true), ""])
	return out

func _build_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 4          # under the HUD (5), so its pointer draws over the bar
	add_child(_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var mc := MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override("margin_left", LEFT_PAD)
	mc.add_theme_constant_override("margin_bottom", BOTTOM_PAD)
	root.add_child(mc)
	bar = HubBar.build(items(), func(cb: Callable, _id: String): cb.call(), bar_btns)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	mc.add_child(bar)
	mc.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE)
	mc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if m.hud:
		m.hud.ui_extra.append(bar)       # the mouse is over UI here: no shooting, the pointer shows

## Ends the practice session and goes back (the bar's Leave and the Esc menu's).
static func leave(match_node: Match, extracted: bool) -> void:
	match_node.paused = false
	if match_node.player and match_node.player.out:
		Life.make_gone(match_node, match_node.player)
	match_node.result = {"extracted": extracted, "why": "left"}
	match_node._finish()

func _unhandled_input(event: InputEvent) -> void:
	if m == null or m.over:
		return
	if picker != null:
		if event.is_action_pressed("menu"):
			if picker_page == "kit": PracticeHero.open(self)
			else: PracticeHero.close(self)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_K and hover_arch != "":
			PracticeHero.kit(self, hover_arch)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("hero"):
			PracticeHero.close(self)
			get_viewport().set_input_as_handled()
		return
	if m.paused or Overlay.is_open():
		return
	if event.is_action_pressed("hero"):
		PracticeHero.open(self)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and m.cam:
		var z := m.cam.user_zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: z -= ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: z += ZOOM_STEP
		else: return
		m.cam.user_zoom = clampf(z, ZOOM_MIN, ZOOM_MAX)
		get_viewport().set_input_as_handled()
