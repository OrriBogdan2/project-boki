class_name HunterPickRow
extends RefCounted
## The expedition panel's Hunter pick: big cards with the portrait, the Hunter's name and its role, nothing
## else (the abilities are on the Hunters screen, the codex and the tutorial). A locked Hunter is
## desaturated with a lock on its portrait, can't be picked, and says how to unlock it on hover.
## Picking saves it as your expedition Hunter (its weight and weapon family follow) and turns the farm hunter
## into it (docs/decisions/0005: no weight labels).

const PORTRAIT_PX := 72.0     # px: the Hunter's portrait on its card
const LOCK_PX := 26.0         # px: the lock icon over a locked portrait
const NAME_SIZE := 22         # pt: the Hunter's name on its card
const COLUMNS := 2            # cards per row

static var _grey: ShaderMaterial

## Adds the section to `parent` and returns the Hunter you are taking.
static func add(home: Node, parent: Control) -> String:
	var cur := Arch.of_save()
	parent.add_child(UI.section("Hunter"))
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for a in Arch.ids():
		grid.add_child(_card(home, String(a), cur))
	parent.add_child(grid)
	return cur

static func _card(home: Node, id: String, cur: String) -> PanelContainer:
	var open := ClassUnlock.is_open(id)
	var card := UI.tile_card(id == cur, (func(): _pick(home, id)) if open else Callable(), 10, Arch.color(id))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("arch", id)
	var row := UI.hbox(12)
	card.add_child(row)
	row.add_child(_portrait(id, open))
	var col := UI.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var nm := UI.label(name_of(id), NAME_SIZE, Arch.color(id) if open else UI.FAINT, UI.big)
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(nm)
	col.add_child(UI.label(role_of(id), UI.T_SMALL, UI.MUTED if open else UI.FAINT))
	if not open:
		card.tooltip_text = ClassUnlock.requirement(id)
		card.focus_mode = Control.FOCUS_NONE
		card.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return card

## The portrait; locked, it is grey with a lock on it.
static func _portrait(id: String, open: bool) -> Control:
	var pic := ClassCard.portrait(id, PORTRAIT_PX)
	if open:
		return pic
	if _grey == null:
		_grey = ShaderMaterial.new()
		_grey.shader = load("res://shaders/ui_grey.gdshader")
	pic.material = _grey
	var lock := UI.IconDot.new("lock", UI.INK, LOCK_PX)
	lock.position = Vector2.ONE * (PORTRAIT_PX - LOCK_PX) * 0.5
	pic.add_child(lock)
	return pic

## "Lace": the Hunter's own name, not its title ("Red Stitch").
static func name_of(id: String) -> String:
	var base := HeroTitle.base_name(id)
	return base if base != "" else Arch.name_of(id)

## "Ranged marksman": the role, the part of the kit card's one-line loop before the colon.
static func role_of(id: String) -> String:
	return String(Arch.def(id).get("card", {}).get("loop", "")).get_slice(":", 0)

static func _pick(home: Node, id: String) -> void:
	if not HeroGrid.save_pick(id):
		return
	home._refresh_player_model()
	home._open_expedition()
