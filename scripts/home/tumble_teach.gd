class_name TumbleTeach
extends RefCounted
## Tumble's first-time teach (scripts/home/base_tumble.gd): the first time a player starts a Tumble, one slow
## practice exchange runs before the bout, its rules overridden by base_tumble.json "teach" (one exchange, honest
## tells, longer windows). A card shows the Rush/Brace/Dodge triangle as three icons and a line for each beat:
## read the rival's 'probably' tell, pick, press on the bar. Skip (the button or the menu key) goes straight to
## the bout. No prize; never repeats (Save.d.tutorial.first_tumble, set when it starts).

var card: Control = null
var line: Label = null

## True until the player has started a Tumble once.
static func due() -> bool:
	return not bool(Save.d.get("tutorial", {}).get("first_tumble", false))

static func mark() -> void:
	if not Save.d.has("tutorial"):
		Save.d["tutorial"] = {}
	Save.d["tutorial"]["first_tumble"] = true

## The practice run's rules: Tumble's own, with the teach block over them.
static func rules() -> Dictionary:
	var R: Dictionary = BaseTumble.rules().duplicate(true)
	R.merge(R["teach"]["rules"], true)
	return R

## Each move's pick key, from Settings (Controls), in the order of base_tumble.json "moves".
static func pick_key(i: int) -> String:
	return Settings.key_cap("util%d" % (i + 1))

func open(root: Control, skip: Callable) -> void:
	card = UI.card(Color(0.06, 0.07, 0.1, 0.92), 12, 14)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 80
	var col := UI.vbox(8)
	card.add_child(col)
	col.add_child(UI.label("Practice Tumble: one slow exchange, no prize", 16, UI.ACCENT_HI))
	col.add_child(Triangle.new())
	line = UI.label("", 14, UI.INK)
	col.add_child(line)
	col.add_child(UI.ghost("Skip practice (%s)" % Settings.key_cap("menu"), skip))
	root.add_child(card)

## The line for the run's state.
func sync(run: BaseTumble.Run) -> void:
	var moves: Dictionary = run.R["moves"]
	var theirs: String = run.recs[1]["name"]
	match run.state:
		"intro":
			line.text = "Each move beats one other. Watch your rival's tell first."
		"tell", "pick":
			var keys: Array = []
			for i in moves.size():
				keys.append("%s %s" % [pick_key(i), moves[moves.keys()[i]]["name"]])
			line.text = "%s will probably %s. Pick what beats it: %s" % [theirs, moves[run.tell]["name"],
					", ".join(keys)]
		"resolve":
			line.text = "Press %s when the marker is in the gold to hit harder" % Settings.key_cap("interact")
		"push":
			line.text = "The winner pushes the loser back. Out of the ring loses. Now the real bout!"

func close() -> void:
	if is_instance_valid(card):
		card.queue_free()
	card = null

## Rush, Brace and Dodge at the corners of a triangle, an arrow from each to the move it beats.
class Triangle extends Control:
	const SIZE := Vector2(260, 150)   # px
	const ICON := 16.0                # px, icon radius
	const CORNERS := [Vector2(0.5, 0.18), Vector2(0.84, 0.72), Vector2(0.16, 0.72)]   # of SIZE

	func _init() -> void:
		custom_minimum_size = SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var moves: Dictionary = BaseTumble.rules()["moves"]
		var font := get_theme_default_font()
		var at := {}
		var ids: Array = moves.keys()
		for i in ids.size():
			at[ids[i]] = (CORNERS[i] as Vector2) * size
		for m in ids:
			var a: Vector2 = at[m]
			var b: Vector2 = at[moves[m]["beats"]]
			var dir := (b - a).normalized()
			var tip := b - dir * ICON * 1.6
			draw_line(a + dir * ICON * 1.6, tip, UI.MUTED, 2.0, true)
			var side := dir.orthogonal() * 5.0
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + side, tip - dir * 9.0 - side]), UI.MUTED)
		for m in ids:
			var p: Vector2 = at[m]
			UI.draw_icon(self, String(moves[m]["icon"]), p, ICON, UI.ACCENT_HI)
			var word := String(moves[m]["name"])
			var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, p + Vector2(-w * 0.5, ICON + 15.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.INK)
