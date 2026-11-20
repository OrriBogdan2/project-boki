class_name NameStep
extends VBoxContainer
## The naming line under a new Boki: a suggested name (KinNames, from its species' name), a dice for another,
## the text box, and Keep. Leaving without Keep keeps the suggestion. A rude name is not kept: a plain line
## says so and the suggestion comes back. Used by the first hatch, a hatch at home and your first caught Boki.

## The name it ends with: kept is true from Keep (or Enter), false when the line was left without it.
signal named(nm: String, kept: bool)

var suggestion := ""
var box: LineEdit
var note: Label
var _species := ""
var _rng := RandomNumberGenerator.new()
var _done := false

## keep_text "" leaves the Keep button out (the caller's own button finishes; read chosen()).
func _init(species: String, keep_text := "Keep") -> void:
	_species = species
	_rng.randomize()
	add_theme_constant_override("separation", 4)
	var row := UI.hbox(8)
	row.add_child(UI.icon_button("dice", reroll, "Another name", 18.0))
	box = LineEdit.new()
	box.max_length = int(KinNames.rules()["max_len"])
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.text_changed.connect(func(_t): note.visible = false)
	row.add_child(box)
	if keep_text != "":
		row.add_child(UI.primary(keep_text, keep, 120))
		box.text_submitted.connect(func(_t): keep())
	add_child(row)
	note = UI.label("That name can't be used. Try another.", UI.T_SMALL, UI.BAD)
	note.visible = false
	add_child(note)
	reroll()
	tree_exiting.connect(func():
		if not _done:
			_done = true
			named.emit(suggestion, false))

## A new suggestion, into the box.
func reroll() -> void:
	suggestion = KinNames.suggest(_species, _rng)
	box.text = suggestion
	box.caret_column = suggestion.length()
	note.visible = false

## The name as it stands: what was typed, or the suggestion for an empty or rude one.
func chosen() -> String:
	return KinNames.pick(box.text, suggestion)

func keep() -> void:
	if _done:
		return
	if KinNames.is_rude(box.text):
		box.text = suggestion
		note.visible = true
		return
	_done = true
	box.editable = false
	named.emit(chosen(), true)
